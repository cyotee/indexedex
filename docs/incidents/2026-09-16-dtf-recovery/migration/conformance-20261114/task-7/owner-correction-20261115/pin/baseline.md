# Pin-removal lane baseline

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`

Starting state: the four owned product files matched the retained task-13
`witness-preexisting-audit.json` hashes. The exact starting SHA-256 values were:

| File | SHA-256 |
| --- | --- |
| `scripts/recovery/dtf-migration/claimed-sy-witness.ts` | `d45bd8b41a5feef7dc7d86c68e8d085ed6babffadf5e13a6703c7d2a84feac5c` |
| `scripts/recovery/dtf-migration/claimed-sy-member.ts` | `8e0e4366c0fa89b6d34438653eb551ac14795b3d2364cebbab2d3336b4da2207` |
| `scripts/recovery/dtf-migration/rehearsal-claimed-sy-witness.ts` | `583558715dae13f2c405655ab18b5dd0a44b54fbd294de73472e3b8080b7c4d8` |
| `scripts/recovery/dtf-migration/claimed-sy-witness.test.ts` | `3ef41ca2e5004fd43a721bea7e146604bc18501d6ff1acf4ebd299bd66ed0231` |

The retained task-13 operator run was `bun test --timeout 15000
./scripts/recovery/dtf-migration/*.test.ts`, exit 1, with 240 passing and one
failing test. Task 13 independently recorded the failure as the fixed router
runtime hash mismatch: actual
`0x33a0fe038a5d441aa3d9fe48b841bcfc0d0f00f0b085e44b9c41b9b0a7aab2bc`,
expected
`0x4ae06bcb278766df6529bcd60e05453fee6c853f6536b9f18d2a4d0dac8fd899`.
This is retained historical evidence, not a current test result.

The worktree initially contained unrelated untracked evidence, TypeScript
tests, and Foundry tests. They are outside this lane and were left untouched.
