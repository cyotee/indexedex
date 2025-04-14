# Unified Review Plan — IndexedEx (DEPRECATED)

This file has been superseded by the main backlog in `UNIFIED_PLAN.md`.
Use `UNIFIED_PLAN.md` Task 15+ for review execution.

This document defines **review tasks** (correctness + test coverage/quality) for the IndexedEx repo.
It intentionally does **not** include Crane tasks; Crane review tasks live in `lib/daosys/lib/crane/UNIFIED_REVIEW_PLAN.md`.

## How to run in parallel
- Each task is written to be executed by an independent agent in its own worktree/branch.
- Tasks may depend on Crane review tasks, but **task execution must not modify Crane code** (that belongs to Crane tasks).

## Gates (must-pass for any change)
- `indexedex`: `forge build` and `forge test`

## Worktree Status

| Task | Worktree | Status |
|------|----------|--------|
| 1 | `review/idx-test-harness-and-quality` | 🔧 Ready for agent |
| 2 | `review/idx-seigniorage-vaults-review` | 🔧 Ready for agent |
| 3 | `review/idx-slipstream-vault-review` | 🔧 Ready for agent |
| 4 | `review/idx-uniswap-v2-vault-review` | 🔧 Ready for agent |
| 5 | `review/idx-uniswap-v3-vault-review` | 🔧 Ready for agent |
| 6 | `review/idx-uniswap-v4-vault-review` | 🔧 Ready for agent |
| 7 | `review/idx-aerodrome-vault-review` | 🔧 Ready for agent |
| 8 | `review/idx-camelot-v2-vault-review` | 🔧 Ready for agent |
| 9 | `review/idx-deployments-and-create3-usage` | 🔧 Ready for agent |
| 10 | `review/idx-spec-coverage-gap-audit` | 🔧 Ready for agent |
| 11 | `review/idx-protocol-detf-review` | 🔧 Ready for agent |

---

## Task 1: IndexedEx Test Harness & Test Quality Audit

**Layer:** IndexedEx
**Worktree:** `review/idx-test-harness-and-quality`
**Status:** Ready for Agent

### Scope
Review test foundations and ensure tests are trustworthy (not just numerous).

In-scope areas (examples):
- Base test scaffolding under `test/foundry/` (especially `spec/` helpers and any `TestBase_*` patterns)
- Shared vault test helpers under `contracts/vaults/TestBase_VaultComponents.sol`
- Any global fixtures, cheatcodes, fork configuration, and determinism assumptions

Out-of-scope
- Any modifications inside Crane.

### Deliverables
- A short review memo written to `docs/review/test-harness.md`.
- A concrete checklist of changes (tests to add/improve/remove or refactors) to make tests more meaningful.

### Inventory checks
- Identify how forks are configured: `test/foundry/fork/`.
- Identify how “spec” tests are organized: `test/foundry/spec/`.
- Identify the most reused helpers (search for `TestBase_` and common imports).

### Completion criteria
- Review memo exists with:
  - What the harness does well
  - What failure modes exist (false positives, missing assertions, flaky forks, etc.)
  - Top 5 highest-impact improvements
- At least 3 concrete test improvements proposed, each tied to a specific file/module.

---

## Task 2: Seigniorage Vaults Correctness + Coverage Review

**Layer:** IndexedEx
**Worktree:** `review/idx-seigniorage-vaults-review`
**Status:** Ready for Agent

### Scope
- `contracts/vaults/seigniorage/**`
- Associated tests (search for `Seigniorage` in `test/foundry/`)

### Deliverables
- Review memo: `docs/review/seigniorage-vaults.md`
- Test-gap list with prioritized additions (unit/spec/fuzz)

### Inventory checks
- Identify state transitions and privileged actions.
- Identify external integrations (DEX pools, token behaviors, NFT vault semantics).

### Completion criteria
- Memo documents invariants and threat model assumptions.
- At least one “must add” spec test and one fuzz/invariant test idea recorded.

---

## Task 3: Slipstream Vault Correctness + Coverage Review

**Layer:** IndexedEx
**Worktree:** `review/idx-slipstream-vault-review`
**Status:** Ready for Agent

### Dependencies
- Depends on Crane review task: **Crane Task 4 (DEX utilities: Slipstream quoting + tests)**

### Scope
- `contracts/protocols/dexes/aerodrome/` (Slipstream-related)
- Any `Slipstream*` contracts under `contracts/` and corresponding `test/foundry/spec/protocol/dexes/**`

### Deliverables
- Review memo: `docs/review/slipstream-vault.md`
- A prioritized “trust checklist” of tests needed to rely on the vault (quotes, accounting, rebalances, edge cases)

### Completion criteria
- Memo includes:
  - Key invariants (accounting, price bounds, slippage, NFT position handling)
  - List of missing tests and which suite they belong to

---

## Task 4: Uniswap V2 Vault Correctness + Coverage Review

**Layer:** IndexedEx
**Worktree:** `review/idx-uniswap-v2-vault-review`
**Status:** Ready for Agent

### Dependencies
- Depends on Crane review task: **Crane Task 4 (DEX utilities: Uniswap V2/V3/V4 quoting + tests)**

### Scope
- `contracts/protocols/dexes/uniswap/v2/`
- `test/foundry/spec/protocol/dexes/uniswap/v2/`

### Deliverables
- Review memo: `docs/review/uniswap-v2-vault.md`
- Test-gap list + recommended spec cases

---

## Task 5: Uniswap V3 Vault Correctness + Coverage Review

**Layer:** IndexedEx
**Worktree:** `review/idx-uniswap-v3-vault-review`
**Status:** Ready for Agent

### Dependencies
- Depends on Crane review task: **Crane Task 4**

### Scope
- `contracts/protocols/dexes/uniswap/v3/`
- `test/foundry/spec/protocol/dexes/uniswap/v3/`

### Deliverables
- Review memo: `docs/review/uniswap-v3-vault.md`

---

## Task 6: Uniswap V4 Vault Correctness + Coverage Review

**Layer:** IndexedEx
**Worktree:** `review/idx-uniswap-v4-vault-review`
**Status:** Ready for Agent

### Dependencies
- Depends on Crane review task: **Crane Task 4**

### Scope
- `contracts/protocols/dexes/uniswap/v4/`
- `test/foundry/spec/protocol/dexes/uniswap/v4/`

### Deliverables
- Review memo: `docs/review/uniswap-v4-vault.md`

---

## Task 7: Aerodrome Vault Correctness + Coverage Review

**Layer:** IndexedEx
**Worktree:** `review/idx-aerodrome-vault-review`
**Status:** Ready for Agent

### Dependencies
- Depends on Crane review task: **Crane Task 4**

### Scope
- `contracts/protocols/dexes/aerodrome/`
- `test/foundry/spec/protocol/dexes/aerodrome/`

### Deliverables
- Review memo: `docs/review/aerodrome-vault.md`

---

## Task 8: Camelot V2 Vault Correctness + Coverage Review

**Layer:** IndexedEx
**Worktree:** `review/idx-camelot-v2-vault-review`
**Status:** Ready for Agent

### Dependencies
- Depends on Crane review task: **Crane Task 4 (DEX utilities)**

### Scope
- `contracts/protocols/dexes/camelot/`
- `test/foundry/spec/protocol/dexes/camelot/`

### Deliverables
- Review memo: `docs/review/camelot-v2-vault.md`

---

## Task 9: Deployments, CREATE3 Usage, and Script/Test Coverage

**Layer:** IndexedEx
**Worktree:** `review/idx-deployments-and-create3-usage`
**Status:** Ready for Agent

### Dependencies
- Depends on Crane review tasks: **Crane Task 1 (CREATE3)** and **Crane Task 2 (Diamond pkg/proxy)**

### Scope
- `contracts/script/**` and any deployment-related services (search `deploy`, `create3`, `factory().create3`)
- Validation that IndexedEx does not violate CREATE3-only deployment rules

### Deliverables
- Review memo: `docs/review/deployments-and-create3.md`
- Checklist of missing deployment tests (e.g., determinism, idempotency, address collisions)

---

## Task 10: Spec Coverage Gap Audit (IndexedEx)

**Layer:** IndexedEx
**Worktree:** `review/idx-spec-coverage-gap-audit`
**Status:** Ready for Agent

### Scope
- Compare implementation surfaces to spec tests:
  - `contracts/**` vs `test/foundry/spec/**`
- Identify “untested but critical” code paths.

### Deliverables
- A coverage gap report: `docs/review/spec-coverage-gaps.md`
- A prioritized list of new spec tests (by file/module)

### Completion criteria
- Report includes a ranked Top 10 gap list with rationale.

---

## Task 11: Protocol DETF Correctness + Coverage Review

NOTE: Canonical tracking is in `UNIFIED_PLAN.md` as **Task 25**.

**Layer:** IndexedEx
**Worktree:** `review/idx-protocol-detf-review`
**Status:** Ready for Agent

### Dependencies
- IndexedEx Task 5 (Protocol DETF implementation) should be in a reviewable state
- Depends on Crane review tasks: **Crane Task C-2 (Diamond pkg/proxy)**, **Crane Task C-5 (token standards / EIP-712 / permit)**, and **Crane Task C-6 (ConstProdUtils/bonding math)**

### Scope
- All Protocol DETF contracts/facets/repos and their test surfaces (search for `ProtocolDETF`, `RICHIR`, and related bonding/exchange facets)
- Validate accounting invariants (shares/mints/burns), authorization, and external-call assumptions

### Deliverables
- Review memo: `docs/review/protocol-detf.md`
- Prioritized missing-test list + at least one concrete test improvement proposal

### Completion criteria
- Memo exists and lists key invariants + top risks
- At least one high-signal test improvement is implemented (or a concrete blocker is recorded)
