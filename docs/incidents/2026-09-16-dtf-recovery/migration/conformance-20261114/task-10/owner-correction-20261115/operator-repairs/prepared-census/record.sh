#!/bin/bash
set -u
set -C
cd /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1 || exit 98
root=docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/operator-repairs/prepared-census
name="$1"
shift
mkdir "$root/$name" || exit 97
path="$root/$name"
printf '%s\0' "$@" > "$path/argv.nul"
printf '%q ' "$@" > "$path/command.txt"
printf '\n' >> "$path/command.txt"
pwd > "$path/cwd.txt"
date -u '+%Y-%m-%dT%H:%M:%SZ' > "$path/started.txt"
shasum -a 256 scripts/recovery/dtf-migration/*.ts "$root"/*.ts > "$path/source-before.sha256"
"$@" > "$path/stdout.log" 2> "$path/stderr.log"
code=$?
printf '%s\n' "$code" > "$path/exit.txt"
shasum -a 256 scripts/recovery/dtf-migration/*.ts "$root"/*.ts > "$path/source-after.sha256"
date -u '+%Y-%m-%dT%H:%M:%SZ' > "$path/finished.txt"
printf 'PREPARED_CENSUS_RESULT %s exit=%s\n' "$name" "$code"
exit "$code"
