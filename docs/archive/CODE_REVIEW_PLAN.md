# IndexedEx Targeted Code Review Plan (Task-Aligned)

This document defines a repeatable, task-aligned code review process for the IndexedEx ecosystem.
Task definitions and acceptance criteria are tracked in task-specific `PROMPT.md` files within feature worktrees (see `scripts/wt-create.sh` for worktree workflow).

## Goals

- Catch correctness, safety, and upgradeability issues early.
- Ensure implementations match repo conventions (Diamond pattern; deterministic CREATE3 deployments).
- Ensure Foundry specs/fork tests actually validate behavior (not just compilation).
- Make reviews “targeted”: each review is scoped to a specific task/worktree and its risks.
- Finish with a holistic audit pass across IndexedEx **and** active in-repo submodules (Crane/daosys/etc.).

## Review Rules (Repo Conventions)

- **No contract deployments via `new`.** Use the CREATE3 factory / FactoryService patterns everywhere.
- **Diamond architecture discipline:** Repos hold storage, Targets implement logic, Facets expose it + metadata.
- **Testing discipline:** Specs should be runnable `test*` functions and assert meaningful guarantees.
- **Keep previews exact where required:** where tasks specify 0 tolerance, previews must match actual outcomes exactly.

## Where Review Notes Live

All review findings should be recorded as Markdown files under `docs/reviews/`.

Naming convention (suggested):
- `docs/reviews/YYYY-MM-DD_task-<N>_<short-title>.md`

For reviews not tied to a task number, use:
- `docs/reviews/YYYY-MM-DD_area-<slug>_<short-title>.md`

Each file should use the “Findings Template” below.

## Standard Review Workflow (Per Task)

1. **Identify scope**
   - Worktree/branch name (if applicable).
   - Files changed vs `main`.
   - Any new external dependencies / remappings.

2. **Reproduce acceptance criteria**
   - Run the smallest relevant `forge test --match-path` / `--match-contract` suite first.
   - Confirm revert-path tests exist for the task’s constraints.

3. **Code review pass (structured)**
   - API surface: interfaces, selectors, visibility, parameter validation.
   - State/storage: Repo slot correctness, layout safety, upgrade safety.
   - Access control: owner/operator/keeper roles; protected flows.
   - External calls & tokens: approvals, transfers, pull vs push, reentrancy boundaries.
   - Economic correctness: math, rounding, fees, thresholds, slippage/deadlines.
   - Observability: events (where expected), revert reasons/errors.

4. **Write down findings**
   - Link findings to a task’s acceptance criteria.
   - Categorize: **Blocker / High / Medium / Low / Nit**.
   - Propose concrete fixes or follow-up tasks.

## Findings Template (Copy/Paste Per Review)

Use the following template to record review results in a local review note under `docs/reviews/`.

### Review Header

- **Task/Worktree:**
- **Reviewer:**
- **Date:**
- **Scope (files/dirs):**
- **Tests run (exact commands):**
- **Environment:** (fork? chain? anvil? mainnet addresses?)

### Severity Rubric

- **Blocker**: likely loss of funds, permanent lock, broken upgrade/storage, broken access control, or clearly violates a hard repo rule (e.g., contract deployments via `new`).
- **High**: serious correctness/economic bug or missing safety check; could plausibly be exploited or cause major user harm.
- **Medium**: correctness edge case, griefing/DoS potential, or missing revert-path coverage that could mask future regressions.
- **Low**: polish, maintainability, non-critical inefficiency, missing events, minor footguns with low impact.
- **Nit**: naming/style consistency, minor refactors, tiny readability issues.

#### Preview Exactness (Special Rule)

For tasks that require preview/actual exactness (0 tolerance):

- Any mismatch is a defect.
- If the mismatch is **> 1 wei** (in either direction): **Blocker**.
- If the mismatch is **exactly 1 wei**: **High** by default.
  - It may be resolved by adjusting rounding behavior.
  - It may be accepted only if the discrepancy is consistent and in a demonstrably safe direction (route-dependent; see below).

##### “Safe Direction” (Route-Dependent)

Preview rounding should be ERC4626-style conservative and favor the vault/user-safety by construction:

- **Never overpromise outputs**: if a preview returns an amount the user would *receive* (e.g., `sharesOut`, `amountOut`), then `preview` must be **≤ actual**.
- **Never understate required inputs**: if a preview returns an amount the user must *provide* (e.g., `sharesInRequired`, `amountInRequired`), then `preview` must be **≥ actual**.

Examples (map based on what the preview returns):

- Deposit-style routes (e.g., `exchangeIn(tokenIn, amountIn, vaultToken, ...)`) typically preview `sharesOut` → preview should be **≤ actual shares minted**.
- Withdrawal/redemption-style routes (e.g., `exchangeIn(vaultToken, sharesIn, tokenOut, ...)`) may preview either:
  - `amountOut` → preview should be **≤ actual token out**, or
  - `amountInRequired` → preview should be **≥ actual required input**.

If a 1-wei mismatch is consistently in an unsafe direction for the route, escalate to **Blocker**.

#### Missing Revert-Path Tests

If acceptance criteria calls for revert-path tests (slippage/deadline/caller restriction) and they are missing, record as **Medium**.
Downstream tasks may proceed while revert coverage is added.

### Findings Table

| ID | Severity | Area | Summary | Evidence | Recommendation | Fix Now? |
|----|----------|------|---------|----------|----------------|----------|
| 1  |          |      |         |          |                | Yes/No   |

**Evidence** should be concrete: a failing test name, a specific trace, a reproduction step, or a precise code-path description.

### “Deferred Debt” (Explicitly Parked Items)

Use this for work that’s intentionally postponed (so it doesn’t keep reappearing as review churn).

| ID | Category | Description | Rationale for Deferring | Suggested Deadline/Trigger |
|----|----------|-------------|--------------------------|----------------------------|
| D1 | NatSpec  |             |                          | e.g., “before audit pass”  |

### Review Summary

- **Blockers:**
- **High:**
- **Medium:**
- **Low/Nits:**
- **Recommended next action:** (merge / fix-first / add tests / follow-up ticket)

### Prioritization Rules (Default)

- Fix **Blocker** and **High** before merging.
- Fix **Medium** before merging if it affects core flows, upgrade safety, or test correctness; otherwise it can be scheduled without blocking dependent work.
- Record **Low/Nit** but prefer batching.
- Treat NatSpec/documentation gaps as **Deferred Debt** by default (to avoid churn while code is still evolving), unless they block correctness, audits, or downstream tasks.

---

## Targeted Review Checklists (By Task)

### Task 5 — Protocol DETF (CHIR) + Fee Distribution

**Review focus:** complex multi-protocol flows (Aerodrome + Balancer + vaults), peg gating, rebasing redemption claim token, and donation paths.

**Primary risks**
- Peg-oracle manipulation/gating bypass.
- Incorrect proportional accounting across: reserve pool → vault tokens → LP unwind → WETH.
- Rebasing token semantics breaking assumptions (intended) but still must be internally consistent.
- Unbounded slippage paths or missing deadline/MEV protections in swaps/zaps.
- Reentrancy or callback hazards during multi-step unwinds.

**Checklist**
- Peg computation matches spec: `synthetic_price = (St / G) * (CHIR_gas / CHIR_static)` (check for precision/rounding).
- Mint/burn gates enforce thresholds with hysteresis semantics (no inverted comparisons).
- Donation flow:
  - `donate(WETH)` does **not** mint CHIR; it routes value to reserve via the specified “pretransferred” pattern.
  - `donate(CHIR)` burns CHIR only.
- RICH token is static supply at deployment; no mint capability exists.
- RICHIR:
  - Shares model (`sharesOf`, `totalShares`) is the only mutable supply accounting.
  - `balanceOf()` and `totalSupply()` are computed live from a redemption-rate quote.
  - Partial redemptions behave correctly (no underflow, correct rounding).
- Redemption unwind path:
  - Uses minimum-output / deadline protections where applicable.
  - Ensures CHIR is actually burned at the end of the unwind.
- Balancer reserve pool integration:
  - Correct pool math and correct asset ordering.
  - Correct handling of unbalanced deposits/withdrawals.
- Any keeper/feeTo restricted hooks are correctly access-controlled.
- Fork tests against Base mainnet cover all user stories and critical revert cases.

**Review artifacts to produce**
- A table of invariants (e.g., conservation across unwind, burn guarantees, share accounting).
- A list of critical MEV/slippage assumptions per external interaction.

---

### Task 6 — Spec Coverage for Package-Deployed Protocol Instances (DFPkgs)

**Review focus:** tests are runnable, meaningful, and aligned with deterministic deployment conventions.

**Primary risks**
- Tests that compile/deploy but don’t assert behavior.
- Harnesses using `new` (diverges from production deployment patterns).
- Preview-vs-actual mismatches.

**Checklist**
- Uniswap V2, Camelot V2, Balancer constant-product-vault packages each have:
  - At least one runnable suite with successful path assertions.
  - Explicit revert-path coverage (slippage, deadline, caller restrictions).
- `StandardExchangeRateProviderDFPkg` has direct (unit-ish) specs beyond integration.
- Preview functions:
  - Where required, preview output matches actual exactly (0 tolerance).
- Deployment in tests uses factory/CREATE3 helpers (or has a documented, reviewed exception).

---

### Task 7 — Slipstream Standard Exchange Vault (Concentrated Liquidity)

**Review focus:** multi-position NFT management, state transitions, volatility-based range calculation, and consolidation.

**Primary risks**
- State transition bugs causing deposits into wrong positions.
- Range calculation producing invalid ticks (tick spacing / bounds).
- Stack-too-deep / overly complex stack usage leading to fragile refactors.
- Fee accounting inaccuracies (fees included/excluded inconsistently across preview vs actual).

**Checklist**
- Exactly 3 logical slots (above/in/below) enforced; behavior defined when all slots occupied.
- State transitions update bookkeeping consistently (no orphaned position references).
- Range calculator:
  - Uses TWAP when available; uses spot fallback only as specified.
  - Produces tick ranges aligned to tick spacing and within min/max ticks.
- Consolidation merges only adjacent ranges; skips when not beneficial.
- Preview functions include uncollected fees where required and match actual semantics.
- Access control: keeper-only functions restricted; user flows permissionless.
- **External NFT transfer handling:** vault must gracefully handle positions transferred away (either prevent transfers, track ownership changes, or document expected failure modes).
- Fork tests on Base cover single-sided deposits, transitions, consolidation, compound, withdrawal, previews.

**Review artifacts to produce**
- A table of invariants (position-slot correctness, conservation across deposit/withdraw, fee accounting consistency, preview vs actual semantics).

---

### Task 8 — Uniswap V3 Standard Exchange Vault

**Review focus:** Slipstream-derived logic adapted to V3 periphery (NPM), multi-chain configuration injection.

**Primary risks**
- Incorrect handling of NPM callbacks / approvals.
- Tick spacing mistakes per fee tier.
- Configuration injection mistakes (wrong addresses per chain).

**Checklist**
- Vault config includes correct chain-specific addresses (NPM, factory, wrapped native).
- Tick alignment enforced per pool’s tick spacing.
- Fee collection and compounding via NPM `collect()` is correct.
- Preview paths use Crane’s quoter/zap quoter consistently.
- Fork tests on Ethereum mainnet cover the same behaviors as Task 7 (minus rewards).

**Review artifacts to produce**
- A table of invariants (position-slot correctness, conservation across deposit/withdraw, fee accounting consistency, preview vs actual semantics).

---

### Task 9 — Uniswap V4 Standard Exchange Vault

**Review focus:** PoolManager unlock callback pattern, ERC-6909 balance handling, and V4-specific accounting.

**Scope limitation:** This vault explicitly supports **hookless pools only** (pools where `hooks` address is `address(0)`). Pools with custom hooks introduce reentrancy, fee extraction, and delta manipulation risks that are out of scope.

**Primary risks**
- Incorrect lock/unlock callback flow causing stuck balances.
- ERC-6909 vs ERC20 input detection edge cases.
- Mis-handling PoolKey ordering and deltas.
- **Accidental hook pool usage:** vault must reject pools with non-zero hook addresses.

**Checklist**
- **Hookless pool enforcement:** vault reverts if `PoolKey.hooks != address(0)` during initialization or deposit.
- `unlockCallback()`:
  - Validates caller is PoolManager.
  - Correctly settles/takes balances and handles deltas.
- ERC-6909 support:
  - Correct token-id derivation / stored ERC-6909 config.
  - Deposits and previews work for both ERC20 and ERC-6909 inputs.
  - Withdrawals return ERC20 as specified.
- Position identification uses PoolKey + tick range and remains stable across upgrades.
- Fork tests on Ethereum mainnet cover ERC-6909 scenario plus core flows.
- Fork tests verify rejection of hook-enabled pools.

**Review artifacts to produce**
- A table of invariants (unlockCallback safety, delta settlement, conservation across deposit/withdraw, preview vs actual semantics).

---

### Task 11 — Aerodrome V1 DFPkg `deployVault` (Pool Creation + Initial Deposit)

**Review focus:** safe pool creation, proportional deposit math, and LP-to-vault deposit flow.

**Primary risks**
- Incorrect proportional math leading to unexpected token pulls.
- Minting LP to wrong recipient or leaving approvals behind.
- Incorrect handling of “new pool” reserves=0 scenario.

**Checklist**
- Pool existence check uses `getPool(tokenA, tokenB, false)` and creates only when needed.
- Proportional calculation:
  - Uses reserves correctly and never exceeds user-provided max amounts.
  - Leaves excess tokens with caller (never pulled).
- Initial deposit conditions match spec (both amounts > 0 and recipient != 0).
- LP tokens minted to the package and then deposited into the vault using `pretransferred=true`.
- `previewDeployVault()` exists and matches on-chain calculation.
- Tests cover:
  - new pool no-deposit,
  - new pool with deposit,
  - existing pool proportional deposit,
  - existing pool no-deposit.

---

### Task 12 — Camelot V2 DFPkg `deployVault` (Pair Creation + Initial Deposit)

**Review focus:** identical to Task 11, but with Camelot factory/pair semantics.

**Checklist**
- Factory integration uses `getPair()` / `createPair()`.
- Proportional math and mint flow match the spec.
- Tests cover the same scenarios as Task 11.

---

### Task 13 — Uniswap V2 DFPkg `deployVault` (Pair Creation + Initial Deposit)

**Review focus:** identical to Task 12 but for Uniswap V2; confirm factory already exists in init.

**Checklist**
- Factory in PkgInit is present and immutable use is correct.
- Proportional math and mint flow match the spec.
- `previewDeployVault()` exists and matches the calculation.
- Tests cover the same scenarios as Task 11.

---

### Task 14 — Deployment Scripts (Factories → Core → Packages → Vaults)

**Review focus:** idempotent staged scripts, deterministic salt usage, JSON state persistence, and correct per-chain configuration.

**Primary risks**
- Non-idempotent scripts that redeploy unexpectedly.
- Incorrect salt derivation producing non-deterministic addresses.
- Missing Foundry fs permissions or unsafe file IO.

**Checklist**
- Scripts are staged and independently runnable.
- Each stage reads JSON state and skips already-complete work.
- Deterministic salts are derived from type names (or a consistent repo convention).
- JSON write/read usage is safe and chain-specific.
- Per-network package selection matches plan:
  - Base: Aerodrome V1, Uniswap V2, Balancer V3 Router
  - Ethereum: Uniswap V2, Balancer V3 Router
  - Camelot excluded
- Scripts deploy via factory helpers (no `new`).
- A “full deployment” run produces a complete summary of addresses.

---

## Fuzz/Invariant Testing Requirements

Beyond unit and fork tests, critical mathematical and state-management logic requires fuzz and invariant testing.

### Required Fuzz Tests by Area

| Area | Fuzz Target | Invariant to Verify |
|------|-------------|---------------------|
| **Peg Oracle** | Reserve ratios (0 < ratio < type(uint256).max) | No division by zero; result bounded |
| **Rebasing Math** | Share ↔ balance conversions | `shares * rate / PRECISION` round-trips correctly |
| **Proportional Deposits** | Amounts vs reserves | Never pulls more than user-specified max |
| **LP Math** | Mint/burn amounts | Conservation: `tokenA_in * tokenB_in ≥ lpOut²` (constant product) |
| **Fee Calculations** | Fee basis points, amounts | Fees never exceed principal; no underflow |
| **Tick/Range Calculations** | Tick values, spacing | Output ticks aligned to spacing; within MIN/MAX_TICK |

### Invariant Test Suites

Each major component should have an invariant test contract:

```solidity
// Example: ProtocolDETF_Invariants.t.sol
contract ProtocolDETF_Invariants is Test {
    function invariant_totalSharesMatchesSupply() public {
        // totalShares * redemptionRate ≈ totalSupply (within rounding)
    }

    function invariant_noUnbackedMints() public {
        // CHIR supply ≤ theoretical max from reserve backing
    }

    function invariant_pegOracleNeverReverts() public {
        // Peg oracle returns valid price for any non-zero reserves
    }
}
```

### Minimum Fuzz Runs

| Environment | Runs | Notes |
|-------------|------|-------|
| Local development | 256 | Fast iteration |
| CI pipeline | 1,000 | Catch edge cases |
| Pre-audit | 10,000+ | Deep exploration |

---

## Gas Budget Table

Track gas costs for critical user-facing operations. Update "Actual" column after implementation.

### Core Vault Operations

| Operation | Target Gas | Actual | Status | Notes |
|-----------|------------|--------|--------|-------|
| `exchangeIn` (single-sided deposit) | < 200,000 | TBD | ⏳ | Excludes external DEX calls |
| `exchangeOut` (withdrawal) | < 250,000 | TBD | ⏳ | |
| `previewExchangeIn` | < 50,000 | TBD | ⏳ | View function |
| `previewExchangeOut` | < 50,000 | TBD | ⏳ | View function |

### Protocol DETF Operations

| Operation | Target Gas | Actual | Status | Notes |
|-----------|------------|--------|--------|-------|
| `mint` (WETH → CHIR) | < 400,000 | TBD | ⏳ | Multi-step: LP + vault + reserve |
| `bond` (WETH) | < 500,000 | TBD | ⏳ | Includes NFT mint |
| `bond` (RICH) | < 500,000 | TBD | ⏳ | |
| `sellNFT` | < 300,000 | TBD | ⏳ | |
| `redeem` (RICHIR → WETH) | < 600,000 | TBD | ⏳ | Complex unwind path |
| `donate` (WETH) | < 350,000 | TBD | ⏳ | |
| `donate` (CHIR) | < 100,000 | TBD | ⏳ | Just burns |

### Concentrated Liquidity Vaults (Slipstream/V3/V4)

| Operation | Target Gas | Actual | Status | Notes |
|-----------|------------|--------|--------|-------|
| `exchangeIn` (new position) | < 350,000 | TBD | ⏳ | Mint new NFT position |
| `exchangeIn` (existing position) | < 250,000 | TBD | ⏳ | Add to existing |
| `compound` | < 300,000 | TBD | ⏳ | Collect + reinvest fees |
| `consolidate` | < 400,000 | TBD | ⏳ | Merge adjacent positions |
| State transition (rebalance) | < 500,000 | TBD | ⏳ | Move liquidity between ranges |

### Deployment Operations

| Operation | Target Gas | Actual | Status | Notes |
|-----------|------------|--------|--------|-------|
| `deployVault` (new pool + deposit) | < 800,000 | TBD | ⏳ | Pool creation expensive |
| `deployVault` (existing pool) | < 400,000 | TBD | ⏳ | |
| Diamond proxy deployment | < 500,000 | TBD | ⏳ | Via CREATE3 |

**Status Legend:** ✅ Met | ⚠️ Over budget | ⏳ Not measured | ❌ Failed

---

## Storage Layout Verification

Ensure storage slot safety across upgrades and Diamond cuts.

### Pre-Change Verification

Before modifying any Repo contract:

```bash
# Capture current storage layout
forge inspect <RepoContract> storage-layout --pretty > storage_before.json
```

### Post-Change Verification

After modifications:

```bash
# Capture new storage layout
forge inspect <RepoContract> storage-layout --pretty > storage_after.json

# Diff the layouts
diff storage_before.json storage_after.json
```

### Verification Rules

| Rule | Description | Severity if Violated |
|------|-------------|---------------------|
| **No slot changes** | Existing fields must keep their slot numbers | Blocker |
| **No type changes** | Existing fields must keep their types | Blocker |
| **Append-only** | New fields must be added after existing fields | Blocker |
| **No reordering** | Field order must be preserved | Blocker |
| **Namespace isolation** | Different Repos must use different namespace hashes | Blocker |

### Storage Slot Collision Checks (Diamond Safety)

This repo’s facets all share the same proxy storage, so **slot collisions are catastrophic**.

Guidance:

- Each `*Repo.sol` should define a unique `STORAGE_SLOT` constant.
- The repo currently uses string/abi-encoded keccak slots (not ERC-7201 masking). That’s fine—just ensure **uniqueness**.
- During review, ensure no two Repos (across the whole monorepo, including in-repo libs used by IndexedEx) share the same `STORAGE_SLOT` value.

Practical reviewer checklist:

- Search for `STORAGE_SLOT` definitions and scan for duplicate namespace strings.
- If a new Repo is introduced, require a reviewer note that records the namespace string used.

---

## Cross-Cutting Review Checklist (Applies to All Tasks)

- **CREATE3-only deployments:** no stray `new` in packages/scripts/tests.
- **Facet metadata:** selectors and interface IDs are correct; no accidental omissions.
- **Repo slot safety:** unique storage slots; no collisions across features. **Run storage layout verification (see above).**
- **Preview ↔ actual consistency:** preview outputs match actual semantics (exact where required).
- **Deadline/slippage:** user-facing swaps/zaps have explicit protections.
- **Approvals:** minimal approvals; reset/avoid infinite approvals unless justified.
- **External calls:** validate assumptions about callbacks/reentrancy and ordering.
- **Events/errors:** consistent error surfaces and useful events.
- **Fuzz coverage:** critical math paths have fuzz tests with minimum run counts (see Fuzz/Invariant Testing Requirements).
- **Gas budget:** user-facing operations meet gas targets (see Gas Budget Table).

---

## Final Step — Holistic Ecosystem Review (Including Active Submodules)

When targeted reviews for active tasks are complete, do a final cross-repo pass:

1. **IndexedEx root review**
   - Re-scan all touched areas under `contracts/`, `test/foundry/`, and `scripts/foundry/`.
   - Run the broadest feasible `forge build` + `forge test` suite for confidence.

2. **Active submodule review** (parallel development projects)
   - Review local diffs and ensure pinned refs are intentional for:
     - `lib/daosys`
     - `lib/daosys/lib/crane`
     - `lib/daosys/lib/wagmi-declare`
     - `lib/daosys/lib/daosys_frontend`
     - `lib/daosys/lib/cyotee-claude-plugins`
   - Also consider root-level protocol/dependency submodules as candidates for **separate targeted review tasks** when they’re updated or when their code is relied on directly:
     - `lib/forge-std`
     - `lib/v2-core` / `lib/v2-periphery`
     - `lib/core` / `lib/periphery` (Camelot)
     - `lib/frontend-monorepo` (Balancer frontend)
   - For any submodule we rely on in production paths, create a follow-up review note/task scoped to:
     - what we import/use,
     - what commit we’ve pinned to,
     - and what invariants/assumptions IndexedEx makes about it.
   - Confirm remappings and `foundry.toml` remain consistent with the submodule layout.

   **Preliminary: submodules that may be removable (revisit later)**

   These are **candidates** for removal from IndexedEx (to reduce repo weight), based on current usage patterns:

   - `lib/frontend-monorepo` (Balancer frontend)
     - Appears to be a standalone frontend codebase; no evidence it’s imported by IndexedEx contracts/tests.
   - `lib/v2-core` / `lib/v2-periphery` (Uniswap V2)
     - IndexedEx appears to rely on Uniswap V2 primarily via Crane abstractions; these repos look unused as direct Solidity dependencies.
   - `lib/core` / `lib/periphery` (Camelot AMM v2)
     - Similar story: present as vendored upstream, but not obviously used by IndexedEx build graph.
   - `lib/forge-std` (root)
     - Remappings currently point to Crane’s `forge-std` path under `lib/daosys/lib/crane/...`, so the root copy may be redundant.

   Before removing anything, create a small targeted review task/note for each candidate and record:

   - **Usage proof:** repo-wide search shows it is not imported/used by `contracts/`, `test/`, or `scripts/`.
   - **Remappings proof:** `remappings.txt` and `foundry.toml` do not map imports into that submodule.
   - **Lockfile/config proof:** removing it won’t break `foundry.lock` resolution or any CI scripts.
   - **Build proof:** `forge build` and a representative `forge test --match-path ...` still run after removal.
   - **If removed:** record the deletion in a dedicated change (avoid mixing with protocol logic changes).

3. **Dependency sanity**
   - Spot-check that major in-repo libs (OpenZeppelin, Balancer, Permit2, Solady) are unchanged or updated intentionally.

4. **Report**
   - Summarize findings across all tasks, with a short list of:
     - Must-fix blockers,
     - Follow-up tickets,
     - Residual risks / assumptions.

---

## Codebase Coverage Beyond Tasks (Area Reviews)

The task list will not cover every part of the repository. To ensure full coverage:

1. **Partition the remaining codebase into review areas**
  - Examples of areas: core diamond/factory plumbing, vault registries, fee collector/oracles, shared token packages, scripts infrastructure, test harnesses.

2. **Write an area review plan**
  - For each area, define scope, risks, and acceptance criteria using the same structure as task reviews.
  - Store plans as notes in `docs/reviews/` (use the `area-<slug>` naming convention).

3. **Iterate**
  - Execute the targeted review for the area.
  - Record findings using the Findings Template.
  - Convert repeated findings into follow-up tasks (especially invariant tests and coverage gaps).

4. **Completion**
  - The repository is considered “reviewed” when all task reviews are complete *and* all defined area reviews are complete, followed by the holistic ecosystem review above.

---

## Indeterminate / Recovery Reviews (e.g., Task 5)

Some tasks may be in an indeterminate state (e.g., an agent crash left a worktree partially implemented).
In these cases, the *review itself* is responsible for determining what remains.

Required outputs for an indeterminate-task review note:

- **Inventory:** list the files added/modified and the intended feature surface.
- **Build status:** does it compile? (and if not, where/why)
- **Test status:** which tests exist, which pass, and which are missing.
- **Delta to acceptance:** a checklist mapping acceptance criteria → implemented/not implemented.
- **Follow-ups:** concrete next steps (missing code, missing tests, missing wiring/scripts).
