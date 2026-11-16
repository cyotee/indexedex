#!/bin/bash
set -u
set -o pipefail
cd /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1 || exit 98
evidence=docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-7/owner-correction-20261115/integration
export LC_ALL=C
overall=0
record() {
  local name="$1"
  shift
  printf '%s\0' "$@" > "$evidence/$name.argv.nul"
  printf '%q ' "$@" > "$evidence/$name.command.txt"
  printf '\n' >> "$evidence/$name.command.txt"
  pwd > "$evidence/$name.cwd.txt"
  date -u '+%Y-%m-%dT%H:%M:%SZ' > "$evidence/$name.started.txt"
  "$@" > "$evidence/$name.stdout.log" 2> "$evidence/$name.stderr.log"
  local code=$?
  printf '%s\n' "$code" > "$evidence/$name.exit.txt"
  date -u '+%Y-%m-%dT%H:%M:%SZ' > "$evidence/$name.finished.txt"
  printf 'QA_RESULT %s exit=%s\n' "$name" "$code"
  if [ "$code" -ne 0 ]; then overall=1; fi
}
record environment-bun-path /bin/bash -c 'command -v bun'
record environment-bun-version bun --version
record environment-bun-revision bun --revision
record environment-ts-version bun node_modules/typescript/bin/tsc --version
record environment-platform uname -a
record git-branch env GIT_MASTER=1 git branch --show-current
record git-head env GIT_MASTER=1 git rev-parse HEAD
record git-status-before env GIT_MASTER=1 git status --short --untracked-files=all
record git-diff-before env GIT_MASTER=1 git diff --binary
record git-staged-before env GIT_MASTER=1 git diff --cached --binary
record git-check-before env GIT_MASTER=1 git diff --check
record 01-tests bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
record 02-operator-types bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts
record 03-helper-types bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/record-verification.ts docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts
record git-status-after env GIT_MASTER=1 git status --short --untracked-files=all
record git-diff-after env GIT_MASTER=1 git diff --binary
record git-staged-after env GIT_MASTER=1 git diff --cached --binary
record git-check-after env GIT_MASTER=1 git diff --check
printf '%s\n' "$overall" > "$evidence/overall.exit.txt"
printf 'QA_COMPLETE exit=%s\n' "$overall"
exit "$overall"
