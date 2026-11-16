#!/usr/bin/env bash
set -euo pipefail
grep -Eq '^\[PASS\] test_MigrationSnapshot_RealProxyCaptureAndFreeze\(\) \(gas: [0-9]+\)' "$1"
grep -Eq '^Suite result: ok\. 1 passed; 0 failed; 0 skipped;' "$1"
