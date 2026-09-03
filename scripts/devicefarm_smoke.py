#!/usr/bin/env python3
"""AWS Device Farm smoke gate for the Naap Android client.

Adapted from Tern's scripts/devicefarm_android_client.py (same account).
Uploads the debug APK + instrumentation APK, runs com.naap.naap.LaunchTest on
ONE rented physical phone (maxDevices=1 keeps a run around a dollar), pulls
the device log, and verifies the markers.

What a green run proves on real hardware:
  * NAAPSMOKE_LAUNCH     — MainActivity reached RESUMED (APK installs, the
                           Flutter engine + ML Kit native libs resolve for
                           the device's ABI).
  * NAAPSMOKE_BOOT_OK    — the Dart side booted and painted the first frame.
  * NAAPSMOKE_LAUNCH_OK  — the activity survived 10s in the foreground.

What it cannot prove: measurement accuracy — a farm phone's camera cannot
photograph a real person. That loop runs on family phones via the APK.

Usage:
    python scripts/devicefarm_smoke.py
    python scripts/devicefarm_smoke.py --poll-only <RUN_ARN>
    python scripts/devicefarm_smoke.py --self-test   # parser only, no AWS
"""

import argparse
import os
import ssl
import sys
import time
import urllib.request

import boto3

REGION = "us-west-2"
# Same Device Farm project as Tern (per the user, 2026-09-01) — Naap runs
# appear under it, named naap-smoke-*. One rented device per run.
PROJECT_ARN = (
    "arn:aws:devicefarm:us-west-2:334856751405:project:"
    "c34a7911-ca52-4893-87dc-686ae905e508"
)
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(REPO, "build", "app", "outputs", "flutter-apk",
                   "app-debug.apk")
TEST = os.path.join(REPO, "build", "app", "outputs", "apk", "androidTest",
                    "debug", "app-debug-androidTest.apk")
OUT_DIR = os.path.join(REPO, "devicefarm-results")

REQUIRED = [
    "NAAPSMOKE_LAUNCH: activity=RESUMED",
    "NAAPSMOKE_BOOT_OK",
    "NAAPSMOKE_LAUNCH_OK",
]

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


def upload(df, proj, path, upload_type):
    name = os.path.basename(path)
    u = df.create_upload(projectArn=proj, name=name, type=upload_type)["upload"]
    # Big APKs over a slow uplink need a generous write timeout.
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


def verify_log(text, device):
    ok = True
    for marker in REQUIRED:
        if marker not in text:
            print(f"  VERIFY FAIL [{device}]: missing {marker}")
            ok = False
    for line in text.splitlines():
        if "NAAPSMOKE" in line or "NAAPSMOKE_BOOT_OK" in line:
            print(f"    {line.strip()[-160:]}")
    return ok


def fetch_and_verify(df, run_arn):
    os.makedirs(OUT_DIR, exist_ok=True)
    failed = False
    any_device = False
    for job in df.list_jobs(arn=run_arn)["jobs"]:
        any_device = True
        device = job["device"]["name"]
        slug = device.replace(" ", "_")
        print(f"\n{device}: job result {job['result']}")
        # Each test method gets its own device log; concatenate them all
        # before parsing (Tern's pipeline learned this the hard way).
        blob = []
        for suite in df.list_suites(arn=job["arn"])["suites"]:
            for test in df.list_tests(arn=suite["arn"])["tests"]:
                for a in df.list_artifacts(arn=test["arn"],
                                           type="LOG")["artifacts"]:
                    try:
                        blob.append(http(a["url"]).read().decode(
                            "utf-8", "replace"))
                    except Exception as e:      # noqa: BLE001
                        print(f"  (could not fetch a log artifact: {e})")
        text = "\n".join(blob)
        path = os.path.join(OUT_DIR, f"{slug}.logcat.txt")
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"  log: {path} ({len(text)} bytes)")
        if job["result"] != "PASSED":
            print(f"  VERIFY FAIL [{device}]: job result {job['result']}")
            failed = True
        if not verify_log(text, device):
            failed = True
    if not any_device:
        sys.exit("FATAL: no jobs in the run")
    if failed:
        sys.exit("FATAL: Naap on-device smoke FAILED")
    print("\nVERIFY OK: Naap installed, the Flutter engine + ML Kit libs "
          "loaded, and the first frame rendered on a real rented phone.")


SELF_TEST_LOG = """
09-01 01:00:00.000  I NAAPSMOKE: NAAPSMOKE_LAUNCH: activity=RESUMED
09-01 01:00:01.000  I flutter : NAAPSMOKE_BOOT_OK: first frame rendered
09-01 01:00:11.000  I NAAPSMOKE: NAAPSMOKE_LAUNCH_OK
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--app", default=APP)
    ap.add_argument("--test", default=TEST)
    ap.add_argument("--model", help="target a specific device model "
                    "(MODEL CONTAINS match), e.g. 'A13' for the arm32 "
                    "budget-class Galaxy A13 5G")
    ap.add_argument("--os-min", default="12",
                    help="minimum Android version (default 12)")
    ap.add_argument("--poll-only", metavar="RUN_ARN")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        assert verify_log(SELF_TEST_LOG, "self-test"), "parser rejects good log"
        bad = SELF_TEST_LOG.replace("NAAPSMOKE_BOOT_OK", "X_BOOT")
        assert not verify_log(bad, "self-test-bad"), "parser accepts bad log"
        print("SELF_TEST_OK")
        return

    df = boto3.client("devicefarm", region_name=REGION)
    proj = PROJECT_ARN
    if args.poll_only:
        run_arn = args.poll_only
    else:
        for p in (args.app, args.test):
            if not os.path.exists(p):
                sys.exit(f"FATAL: missing {p} — run `flutter build apk "
                         f"--debug` then `gradlew app:assembleDebugAndroidTest`")
        app_arn = upload(df, proj, args.app, "ANDROID_APP")
        test_arn = upload(df, proj, args.test, "INSTRUMENTATION_TEST_PACKAGE")
        # ONE device keeps a run ~1 dollar. Default filters pick any healthy
        # modern Android handset; --model pins a specific device (e.g. the
        # armeabi-v7a Galaxy A13 5G as the Tecno/Infinix budget proxy).
        filters = [
            {"attribute": "PLATFORM", "operator": "EQUALS",
             "values": ["ANDROID"]},
            {"attribute": "OS_VERSION", "operator": "GREATER_THAN_OR_EQUALS",
             "values": [args.os_min]},
            {"attribute": "AVAILABILITY", "operator": "EQUALS",
             "values": ["HIGHLY_AVAILABLE"]},
        ]
        if args.model:
            filters.append({"attribute": "MODEL", "operator": "CONTAINS",
                            "values": [args.model]})
        run = df.schedule_run(
            projectArn=proj, appArn=app_arn,
            name=f"naap-smoke-{time.strftime('%Y%m%d-%H%M')}",
            test={"type": "INSTRUMENTATION", "testPackageArn": test_arn},
            deviceSelectionConfiguration={
                "filters": filters,
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
