#!/bin/bash
set -u
set -C
cd '/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1' || exit 90
export GIT_MASTER=1
E='/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1/docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/final/owner-correction-20261115/boundary'
run() { local n="$1"; shift; mkdir -p "$E/probes/$n" || exit 91; printf '%s\0' "$@" > "$E/probes/$n/argv.nul"; pwd > "$E/probes/$n/cwd.txt"; date -u '+%Y-%m-%dT%H:%M:%SZ' > "$E/probes/$n/started.txt"; "$@" > "$E/probes/$n/stdout.log" 2> "$E/probes/$n/stderr.log"; local c=$?; printf '%s\n' "$c" > "$E/probes/$n/exit.txt"; date -u '+%Y-%m-%dT%H:%M:%SZ' > "$E/probes/$n/finished.txt"; printf 'BOUNDARY_PROBE %s exit=%s\n' "$n" "$c"; }
run status git status --porcelain=v1 -z --untracked-files=all
run diff git diff --stat
run paths git diff --name-only -z
run staged git diff --staged --name-only -z
run head git rev-parse HEAD
run bun bun --revision
