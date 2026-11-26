#!/usr/bin/env bash
set -euo pipefail

output=${1:?Specify the build output directory}
source=${2:?Specify the kernel source directory}
python3 - "$output" "$source" <<'PY'
from pathlib import Path
import re
import subprocess
import sys

output, source = map(Path, sys.argv[1:])
pem = (source / "certs/oem_build_time_key.pem").read_bytes()
certs = [
    subprocess.run(["openssl", "x509", "-outform", "DER"], input=match,
                   stdout=subprocess.PIPE, check=True).stdout
    for match in re.findall(rb"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", pem, re.S)
]
if len(certs) != 2 or len(set(certs)) != 2 or any(len(cert) != 1357 for cert in certs):
    sys.exit("FAIL: expected two distinct 1357-byte OEM certificates")
for path in ("certs/x509_certificate_list", "arch/arm64/boot/Image"):
    data = (output / path).read_bytes()
    if any(cert not in data for cert in certs):
        sys.exit(f"FAIL: missing OEM certificate in {path}")
print("CERT_GATE PASS: both OEM certificates are in the certificate list and Image")
PY
