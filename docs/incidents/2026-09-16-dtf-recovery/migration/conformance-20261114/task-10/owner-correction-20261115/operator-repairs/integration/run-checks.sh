#!/bin/bash
set -u
set -o pipefail
cd /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1 || exit 98
evidence=docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/operator-repairs/integration
export LC_ALL=C
export GIT_PAGER=cat
overall=0
owned=(
  scripts/recovery/dtf-migration/execution-domain.ts
  scripts/recovery/dtf-migration/execution-state.ts
  scripts/recovery/dtf-migration/execution-domain.test.ts
  scripts/recovery/dtf-migration/execution-state.test.ts
  scripts/recovery/dtf-migration/rehearsal-data.ts
  scripts/recovery/dtf-migration/execution.ts
  scripts/recovery/dtf-migration/execution.test.ts
)
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
  printf 'REPAIR_QA_RESULT %s exit=%s\n' "$name" "$code"
  if [ "$code" -ne 0 ]; then overall=1; fi
}
record environment-bun-path /bin/bash -c 'command -v bun'
record environment-bun-version bun --version
record environment-bun-revision bun --revision
record environment-ts-version bun node_modules/typescript/bin/tsc --version
record environment-platform uname -a
record git-branch env GIT_MASTER=1 git branch --show-current
record git-head env GIT_MASTER=1 git rev-parse HEAD
record git-owned-status-before env GIT_MASTER=1 git status --short --untracked-files=no -- "${owned[@]}"
record git-owned-diff-before env GIT_MASTER=1 git --no-pager diff --binary -- "${owned[@]}"
record git-owned-staged-before env GIT_MASTER=1 git --no-pager diff --cached --binary -- "${owned[@]}"
record git-owned-check-before env GIT_MASTER=1 git diff --check -- "${owned[@]}"
record 01-tests bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
record 02-operator-types bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts
record 03-helper-types bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/record-verification.ts docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts
record git-owned-status-after env GIT_MASTER=1 git status --short --untracked-files=no -- "${owned[@]}"
record git-owned-diff-after env GIT_MASTER=1 git --no-pager diff --binary -- "${owned[@]}"
record git-owned-staged-after env GIT_MASTER=1 git --no-pager diff --cached --binary -- "${owned[@]}"
record git-owned-check-after env GIT_MASTER=1 git diff --check -- "${owned[@]}"
printf '%s\n' "$overall" > "$evidence/overall.exit.txt"
printf 'REPAIR_QA_COMPLETE exit=%s\n' "$overall"
exit "$overall"
