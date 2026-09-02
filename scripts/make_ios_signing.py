"""Create the Naap iOS distribution certificate + App Store profile via the
App Store Connect API, using the CSR in c:/Projects/NAAP/signing/.

Outputs into c:/Projects/NAAP/signing/:
    naap_dist.cer            (DER certificate)
    Naap_AppStore.mobileprovision
Run from C:/Projects/Tern (pyjwt lives there) with ASC_* env set.
"""
import base64
import json
import os
import subprocess
import sys

sys.path.insert(0, r"C:\Projects\Tern\scripts")
os.environ.setdefault("ASC_KEY_ID", "6LXF7UJC2L")
os.environ.setdefault("ASC_ISSUER_ID", "1cf6af64-6d6c-4008-9dcc-81b66de04c65")

import urllib.request
import asc_api  # noqa: E402  (Tern's minimal client; we reuse its token())

BASE = "https://api.appstoreconnect.apple.com"
SIGNING = r"c:\Projects\NAAP\signing"


def call(method: str, path: str, body: dict | None = None) -> dict:
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(body).encode() if body else None,
        headers={"Authorization": "Bearer " + asc_api.token(),
                 "Content-Type": "application/json"},
        method=method)
    try:
        with urllib.request.urlopen(req, timeout=30, context=asc_api._CTX) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        print(f"{method} {path} -> HTTP {e.code}\n{e.read().decode()}")
        raise SystemExit(1)


csr = open(os.path.join(SIGNING, "naap_dist.csr")).read()

print("1/4 creating distribution certificate...")
cert = call("POST", "/v1/certificates", {
    "data": {"type": "certificates",
             "attributes": {"certificateType": "IOS_DISTRIBUTION",
                            "csrContent": csr}}})
cert_id = cert["data"]["id"]
open(os.path.join(SIGNING, "naap_dist.cer"), "wb").write(
    base64.b64decode(cert["data"]["attributes"]["certificateContent"]))
print("   cert", cert_id, cert["data"]["attributes"]["displayName"])

print("2/4 looking up bundle id com.naap.naap...")
bid = call("GET", "/v1/bundleIds?filter%5Bidentifier%5D=com.naap.naap")
bundle_res_id = bid["data"][0]["id"]
print("   bundleId resource", bundle_res_id)

print("3/4 creating App Store profile...")
prof = call("POST", "/v1/profiles", {
    "data": {"type": "profiles",
             "attributes": {"name": "Naap AppStore",
                            "profileType": "IOS_APP_STORE"},
             "relationships": {
                 "bundleId": {"data": {"type": "bundleIds",
                                        "id": bundle_res_id}},
                 "certificates": {"data": [{"type": "certificates",
                                             "id": cert_id}]}}}})
open(os.path.join(SIGNING, "Naap_AppStore.mobileprovision"), "wb").write(
    base64.b64decode(prof["data"]["attributes"]["profileContent"]))
print("   profile", prof["data"]["id"], prof["data"]["attributes"]["name"])

print("4/4 packaging .p12 (password: naap)...")
subprocess.run(
    ["openssl", "x509", "-inform", "DER",
     "-in", os.path.join(SIGNING, "naap_dist.cer"),
     "-out", os.path.join(SIGNING, "naap_dist.pem")], check=True)
subprocess.run(
    ["openssl", "pkcs12", "-export",
     "-inkey", os.path.join(SIGNING, "naap_dist.key"),
     "-in", os.path.join(SIGNING, "naap_dist.pem"),
     "-out", os.path.join(SIGNING, "naap_dist.p12"),
     "-passout", "pass:naap"], check=True)
print("DONE: signing/naap_dist.p12 + signing/Naap_AppStore.mobileprovision")
