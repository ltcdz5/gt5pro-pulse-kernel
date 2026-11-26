#!/bin/bash
# Verify the built cert list carries both OEM build-time public keys.
# Usage: cert_gate.sh <build-output-dir> <src-tree>
set -u
OUT=${1:?out dir}
SRC=${2:-/home/builder/kwork/mc/common}
LIST="$OUT/certs/x509_certificate_list"
PEM="$SRC/certs/oem_build_time_key.pem"
BAK="$SRC/certs/oem_build_time_key.pem.bak-1key-20261125"

[ -f "$LIST" ] || { echo "FAIL: missing $LIST"; exit 2; }
[ -f "$BAK" ] || { echo "FAIL: missing old-key backup $BAK"; exit 2; }
size=$(stat -c %s "$LIST")
[ "$size" -eq 2714 ] || { echo "FAIL: cert list size $size != 2714"; exit 3; }

python3 - "$LIST" "$BAK" "$PEM" <<'PY'
import subprocess, sys
lst = open(sys.argv[1], 'rb').read()
def der(p):
    return subprocess.run(['openssl','x509','-in',p,'-outform','DER'],capture_output=True).stdout
# split the combined PEM: take every certificate separately
def ders(p):
    out=[]; buf=b''
    for line in open(p,'rb'):
        buf+=line
        if b'END CERTIFICATE' in line:
            out.append(subprocess.run(['openssl','x509','-inform','PEM','-outform','DER'],
                                      input=buf,capture_output=True).stdout)
            buf=b''
    return [d for d in out if d]
old = ders(sys.argv[2]); new = ders(sys.argv[3])
miss = [i for i,d in enumerate(old) if d not in lst] + ['new%d'%i for i,d in enumerate(new) if d not in lst]
print("old_keys=%d new_keys=%d certlist=%d bytes" % (len(old), len(new), len(lst)))
if miss:
    print("FAIL: not embedded:", miss); sys.exit(4)
print("CERT_GATE PASS")
PY
