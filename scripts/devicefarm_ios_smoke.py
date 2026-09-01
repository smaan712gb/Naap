#!/usr/bin/env python3
"""AWS Device Farm smoke gate for the Naap iOS client.

Mirrors Tern's scripts/devicefarm_client_run.py: uploads the UNSIGNED ipa
from CI (Device Farm re-signs it), schedules the built-in fuzz test on ONE
rented physical iPhone — which installs the app, launches it, and drives
random UI events — then downloads the screen-recording video as proof the
UI rendered. Fuzz FAILED = crash under monkey input; ERRORED = install or
launch failure; a PASS with no video is treated as a failure.

Get the ipa (built by .github/workflows/ios-build.yml):
    https://nightly.link/smaan712gb/Naap/workflows/ios-build/main/naap-ios-unsigned.zip
    -> extract to build/ios-artifact/naap-unsigned.ipa

Usage:
    python scripts/devicefarm_ios_smoke.py [--ipa PATH]
                                           [--poll-only RUN_ARN]
"""

import argparse
import os
import ssl
import sys
import time
import urllib.request

import boto3

REGION = "us-west-2"
# Shared tern Device Farm project (same as devicefarm_smoke.py).
PROJECT_ARN = (
    "arn:aws:devicefarm:us-west-2:334856751405:project:"
    "c34a7911-ca52-4893-87dc-686ae905e508"
)
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_IPA = os.path.join(REPO, "build", "ios-artifact",
                           "naap-unsigned.ipa")
OUT_DIR = os.path.join(REPO, "devicefarm-results")

# Modest fuzz: enough taps to exercise the home screen without burning
# device minutes. Fixed seed keeps reruns comparable.
FUZZ_PARAMS = {"event_count": "60", "throttle": "1000", "seed": "1958"}

_ca = os.environ.get("AWS_CA_BUNDLE") or os.path.expanduser(
    "~/.gcloud-ca-bundle.pem")
SSL_CTX = ssl.create_default_context(
    cafile=_ca if os.path.exists(_ca) else None)
SSL_CTX.verify_flags &= ~ssl.VERIFY_X509_STRICT


def http(url, data=None, method="GET", timeout=300):
    req = urllib.request.Request(url, data=data, method=method)
    if data is not None:
        req.add_header("Content-Type", "application/octet-stream")
    return urllib.request.urlopen(req, context=SSL_CTX, timeout=timeout)


def upload(df, path, upload_type):
    name = os.path.basename(path)
    u = df.create_upload(
        projectArn=PROJECT_ARN, name=name, type=upload_type)["upload"]
    with open(path, "rb") as f:
        http(u["url"], data=f.read(), method="PUT", timeout=1800).read()
    for _ in range(60):
        got = df.get_upload(arn=u["arn"])["upload"]
        if got["status"] == "SUCCEEDED":
            print(f"  uploaded {name} ({os.path.getsize(path)} bytes)")
            return got["arn"]
        if got["status"] == "FAILED":
            sys.exit(f"FATAL: upload failed for {name}: "
                     f"{got.get('metadata') or got.get('message')}")
        time.sleep(5)
    sys.exit(f"FATAL: upload processing timed out for {name}")


def poll_run(df, run_arn):
    last = None
    while True:
        run = df.get_run(arn=run_arn)["run"]
        state = f"{run['status']} counters={run['counters']}"
        if state != last:
            print(f"  [{time.strftime('%H:%M:%S')}] {state}")
            last = state
        if run["status"] == "COMPLETED":
            return run
        time.sleep(30)


def fetch_and_verify(df, run_arn):
    os.makedirs(OUT_DIR, exist_ok=True)
    failed = False
    any_device = False
    for job in df.list_jobs(arn=run_arn)["jobs"]:
        any_device = True
        device = job["device"]["name"]
        slug = device.replace(" ", "_")
        result = job["result"]
        print(f"\n{device}: {result}")
        if result != "PASSED":
            print(f"VERIFY FAIL: job result {result} on {device}")
            failed = True
        video_bytes = 0
        for suite in df.list_suites(arn=job["arn"])["suites"]:
            for test in df.list_tests(arn=suite["arn"])["tests"]:
                for a in df.list_artifacts(
                        arn=test["arn"], type="FILE")["artifacts"]:
                    if a["type"] == "VIDEO":
                        fn = os.path.join(OUT_DIR, f"{slug}.fuzz.mp4")
                        body = http(a["url"]).read()
                        with open(fn, "wb") as f:
                            f.write(body)
                        video_bytes = len(body)
                        print(f"  video: {fn} ({video_bytes} bytes)")
        if video_bytes <= 0:
            print(f"VERIFY FAIL: no screen-recording video from {device} "
                  f"— cannot confirm the UI rendered")
            failed = True
    if not any_device:
        sys.exit("FATAL: no jobs in the run")
    if failed:
        sys.exit("FATAL: Naap iOS on-device smoke FAILED")
    print("\nVERIFY OK: Naap installed, launched, and ran under fuzz input "
          "on a real rented iPhone (screen recording in devicefarm-results/).")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ipa", default=DEFAULT_IPA)
    ap.add_argument("--poll-only", metavar="RUN_ARN")
    args = ap.parse_args()

    df = boto3.client("devicefarm", region_name=REGION)
    if args.poll_only:
        run_arn = args.poll_only
    else:
        if not os.path.exists(args.ipa):
            sys.exit(f"FATAL: missing {args.ipa} — download the CI artifact "
                     f"(see module docstring)")
        app_arn = upload(df, args.ipa, "IOS_APP")
        run = df.schedule_run(
            projectArn=PROJECT_ARN, appArn=app_arn,
            name=f"naap-ios-smoke-{time.strftime('%Y%m%d-%H%M')}",
            test={"type": "BUILTIN_FUZZ", "parameters": FUZZ_PARAMS},
            # ONE rented iPhone keeps a run around a dollar.
            deviceSelectionConfiguration={
                "filters": [
                    {"attribute": "PLATFORM", "operator": "EQUALS",
                     "values": ["IOS"]},
                    {"attribute": "AVAILABILITY", "operator": "EQUALS",
                     "values": ["HIGHLY_AVAILABLE"]},
                ],
                "maxDevices": 1,
            },
            executionConfiguration={"jobTimeoutMinutes": 20},
        )["run"]
        run_arn = run["arn"]
        print(f"run scheduled: {run_arn}")

    print("polling (checks every 30s)...")
    run = poll_run(df, run_arn)
    print(f"run finished: result={run['result']} "
          f"minutes={run.get('deviceMinutes', {})}")
    fetch_and_verify(df, run_arn)


if __name__ == "__main__":
    main()
