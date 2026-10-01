# Open Items — Uniswap V4 FullSpread Proportional Zap-In PRD (MINIMAX)

Date / access date: 2026-09-27
Author: MiniMax M3 (independent first pass; no peer artifacts read)
Target PRD: `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` (Updated 2026-09-27)
Scope: distinguished remaining human policy decisions from engineering specifications, verification gates, and documentation reconciliation. Do not reopen settled policies.

---

## 0. Frame for the answer

The PRD's two new clauses — D17 ("supports an exact-output operation when an applicable closed-form equation exists") and D19 ("If no applicable combined closed-form quotation exists... forgo interleaved rebalancing on that specific route") — are not "do everything." They are an owner direction **to inspect the existing Crane math** and **inspect the existing FullSpread implementation**, then route precisely what the source supports. The PRD also fixes the engineering substrate (D22–D26: two family implementations under exact prefixes, ROBINHOOD_MAIN.POOL_MANAGER, ROBINHOOD_MAIN.PONS_V2_MEME_HOOK, fixed 25/50/10/1 bp constants, gated legacy removal). What remains is **engineering inventory**, **verification gates**, and **documentation reconciliation**. No further owner policy decision is required to ship the work.

Three observations shape the open items:

1. The "two family trees" called for by D22 do not exist in the repository (`v4/fullSpread/hookless/` and `v4/fullSpread/ponsFamilyV2Hook/` are absent; only `v4/UniswapV4FullSpreadStandardExchange…` exists). The gating is structural.
2. The "combined closed-form quotation" called for by D17/D18 implicitly requires enumerating the existing math in `lib/crane/contracts/utils/math/` plus the current unsegmented `v4/UniswapV4FullSpreadStandardExchangeVault{Common,InBase,OutBase}.sol`. That **inventory** is a precondition for any engineering plan, and the inventory result determines whether the engineering work is small (use existing formula) or new (derive a new exact-output inverse).
3. The PRD forbids a mutable hook whitelist (D14, D25). It also forbids mutating execution-protection constants or layering the sleeve target with them (D25). Owner policy is **frozen** for the technical variables; remaining decisions are procedure-level, not technical.

---

## 1. Distinguishing open items by kind

| Kind | Definition |
|---|---|
| **Human policy decision** | A choice the owner makes that sets a non-derivable fact (a number, a name, a privilege, a scope boundary, a release timing). |
| **Engineering specification** | A design choice the implementer must finalize on a code/architecture question that has multiple valid answers but is not externally constrained. |
| **Verification gate** | An acceptance test, runtime invariant check, or evidence requirement whose pass/fail determines whether a future permission can be granted. |
| **Documentation reconciliation** | An owner-blessed update to existing doc/family-PRD text that contradicts the new PRD without changing any policy. |

The four kinds are NOT interchangeable. Engineering cannot replace a human policy decision; a verification gate cannot replace an engineering spec; documentation reconciliation cannot change a settled decision. Misclassifying a "human policy decision" as "engineering" leads to scope drift; misclassifying an "engineering" decision as "policy" reopens settled questions.

---

## 2. Remaining human policy decisions

I see **none** that bind or restrict shipping the plan below. The PRD has fixed every technical lever the owner is willing to fix (D20 constants, D25 immutability of those constants, D14 admission rule, D22 family path names, D23 PoolManager identity and Pons source generation, D26 Pons hook address and codehash). The following are the **only** items that the owner might still choose to ratify or leave to engineering; they are optional and the plan can proceed without them.

### 2.1 Optional items (no policy change required to ship)

- **A.** Owner ratifies that D24's "readiness for audit submission" gate is the literal production release (i.e., D24's gate means "submit for audit; record source, validation evidence, readiness checklist"). The PRD §3.1 already records this. Status: **already a policy choice in D24/§3.1**; not open.
- **B.** Owner accepts that `MAX_LP_FEE = 1_000_000` pips (100%) is admitted at the protocol layer (V4 core). The previous cross-review flagged whether to reject 100%-fee as a product error. The PRD does not state a preference here; my recommendation is **accept and rely on closed-form infeasibility**, which is the engineering default. Status: **engineering default**, no policy needed.
- **C.** Owner accepts the "static-fee structural validation" (reject `isDynamicFee(fee)`, `isValid(fee)`) inherited from R1 of the static-fee round. The PRD does not mention it explicitly, but it is consistent with D14 (admission-by-construction) and D22 (family paths). Status: **engineering default**, no policy needed.

### 2.2 Items that are NOT remaining policy decisions

- "Which factories/facets to reuse across families" — engineering, not policy.
- "Whether `info[0] == 1` is the right version sentinel" — engineering.
- "What happens if a Pons pool's `LaunchInfo` mutates" — engineering (covered by D13 + D8/D11 + per-launch frozen snapshot in `PonsV2MemeHook.sol:389–403`).
- "Whether to retain the legacy single-package or deprecate it" — D24 fixes this (gated deprecation). Not policy.

---

## 3. Engineering specifications still open

These are decisions the implementer makes. They are not policy. They block engineering work but they do not block ownership decisions.

### 3.1 E-1. Existing-formula inventory (PRD §6.4)

Required: enumerate which existing closed-form helper in `lib/crane/contracts/utils/math/` (or in `v4/UniswapV4FullSpreadStandardExchangeVaultCommon.sol`) satisfies which of the four exact-output branches:

- swap-exact-output **token0 → token1** (no maintenance)
- swap-exact-output **token1 → token0** (no maintenance)
- swap-exact-output token0 → token1 **+** holder-funded sleeve/placement
- swap-exact-output token1 → token0 **+** holder-funded sleeve/placement

Why the inventory matters: the PRD's D17/D18 branch on the existence of an applicable formula. Without the inventory, the plan cannot declare which branches are `InvalidRoute` (D19), which require the route-preservation exception (D19 #3), and which are fully supported without exception. Concretely:

- `StandardExchangeConstantProduct.sol` already contains `_amountInForShares(...)` (ConstantProduct:78–96, used by `OutBase.sol:49–62`) and `_singleExit(...)` (ConstantProduct:98–111). These are exact formulas for the share-side legs.
- `UniswapV4Quoter.quoteExactOutput` (Crane) gives an exact-output swap quote, but does **not** compose a maintenance leg.
- The combination (swap + maintenance) is the open question. The PRD says: do not invent a quote. Verify the existing helpers.

**Observation:** the existing `UniswapV4FullSpreadStandardExchangeVaultOutBase.sol:49–62` uses `_amountInForZapMint` which **reads `prepaidCredit` as a state argument** — i.e., the existing helper accepts pre-paid prepaid credit. PRD §6.1 explicitly credits exactly `amountIn` (no prepaid-credit scaling). This is a self-state-mismatch between the PRD's funding model and the existing helper's input contract. Engineering must re-derive an exact-formula that uses `max(pulled) == used`, not "prepaid minus credit". This is **not new math** — the arithmetic is still `K = ceil(sqrt(reserveIn * reserveOther))`, `A = K + ceil(shares * K / supply)`, `amountIn = ceil(A^2 / reserveOther) - reserveIn` (ConstantProduct:78–96); it is a contract-shape update.

### 3.2 E-2. Quote-surface alignment per branch

Required: produce a **route matrix** per the PRD §6.4 instruction and PRD §13 item 20. The matrix must enumerate:

- token direction (token0 → token1 vs token1 → token0)
- share direction (token → shares vs shares → token)
- mode (exact-in vs exact-out)
- state (idle vs blocked)
- family (Hookless vs PonsV2)
- selected existing closed-form formula (if any)
- interleaved maintenance: yes/no
- supported / `InvalidRoute` / route-preservation exception
- early-`InvalidRoute` gate (PRD §6.4 final paragraph)

Without this matrix, previews and execution can disagree. The matrix is engineering but its structure is owner-mandated (PRD §13 item 20). Owner input: none.

### 3.3 E-3. Proportional zap-in (composition swap) math

Required: implement the bounded swap that aligns the caller's basket with the post-swap incumbent whole-book ratio (PRD §1 step 2; §6.2 steps 2–7). The PRD fixes the **ordering** (composition → allocation → mint) but not the **solver**. Engineering must decide:

- Step-size selection (closed-form vs bounded iteration).
- Where to do the composition swap and the deposit (single `_executeUnlock` vs two).
- How to read `info[2]`/`info[3]` from Pons `LaunchInfo` (already verified at `FullSpreadStandardExchangeVaultQuoteService.sol:37–38` for currency orientation). This is the one source of orientation truth for the Pons family.

### 3.4 E-4. Holder-funded repair under §6.4

Required: PRD §8 explicitly authorizes swap-and-LP-interleaved rebalance with the §6.4 closed-form constraint. Engineering must prove each route's combined closed-form, not assume numerical search. Specifically:

- **For token0 → token1 swap-only** (idle, no rebalance): present in `UniswapV4Quoter.quoteExactOutput` (Crane). Supported.
- **For token1 → token0 swap-only** (idle): same. Supported.
- **For token0 → token1 + rebalance**: closed form exists only if the post-swap incumbent reserves close-form a target-free deployment (i.e., `LiquidityAmounts.getLiquidityForAmounts(sqrtPriceAfter, lower, upper, excess0, excess1)` is closed-form). Per Liquidity math at `lib/crane/contracts/dexes/uniswap/v4/utils/LiquidityAmounts.sol`, this IS closed form (Crane library). Therefore the combined route on a vanilla pool is closed-form when the post-swap reserve ratio aligns with `free_i → targetFree_i`. **Inference**: the closed form exists. Engineering must **document** it (citing the helpers used) and bind the alignment metric at `ε = 1bp` (PRD §7).
- **For token1 → token0 + rebalance**: same logic, mirror.

If engineering's verification step rejects any of these because the existing math does not actually compose cleanly (e.g., because the swap comes out of incumbent position dollars while the deployment uses sleeve dollars), then that route becomes `InvalidRoute` per PRD §6.4 #1, and the other mode (or the route-preservation exception under §6.4 #3) applies. The plan must record this evidence explicitly.

### 3.5 E-5. Hook-aware `unlockCallback` execution

Required: the family tree's `_executeSwap`/`_executeAddLiquidity`/`_executeRemoveLiquidity` (currently in `UniswapV4FullSpreadStandardExchangeVaultCommon.sol:954–1021`) must be duplicated, not shared. The Common file is the bridge legacy; the new Hookless and Pons family trees each compile their own. Per D22: "Separate package wrappers over a combined Hookless/Pons quote or execution dispatcher do not satisfy this requirement." Engineering must produce two independent `_unlockCallback` implementations sharing only the v4-call primitives.

### 3.6 E-6. Family-specific `QuoteService` libraries

Required: per D22 "Hookless components use prefix `UniswapV4FullSpreadHooklessStandardExchangeVault`" and "Pons components use prefix `UniswapV4FullSpreadPonsFamilyHook`" the libraries are separated. Engineering must produce:

- `UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol` — vanilla only; reverts on any non-zero hook.
- `UniswapV4FullSpreadPonsFamilyHookQuoteService.sol` — Pins Pons V2 hook per D26; calls `info[0]` etc.; removes the `_adjustHookSwap` "return amount" fallback at `QuoteService.sol:55` (which is the arbitrary-hook quote path) per PRD §10 last bullet.

The Pon's `info[0]` test (`if (info[0] != 1)` at `QuoteService.sol:35`) is a **registration-existence check** at the byte level (because `LaunchInfo.registered` is the first struct field per `PonsV2MemeHook.sol:48–67`, and ABI-encoded `true → 1`). It is NOT a version sentinel in the version sense; the actual identity binding is the codehash pin per D26. If the PRD is read as requiring a separately versioned `info[0]`, that is a doc clarity gap; engineering should add an explicit comment to that effect.

### 3.7 E-7. Family file-tree layout

Required paths (PRD §10, first table):
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/`

Both **currently empty** (verified by directory enumeration). Engineering must populate them, naming components with their exact prefixes per PRD §10:

- Hookless: `UniswapV4FullSpreadHooklessStandardExchangeVault*`
- Pons: `UniswapV4FullSpreadPonsFamilyHook*`

### 3.8 E-8. Generation of 25/50/10/1 bp constants as immutables

Required: PRD §9 last paragraph mandates "fixed constants in each implementation, with no setter or new administrative tuning privilege." Engineering must declare these as `internal constant` in each family's `Common.sol` (mirroring `LIQUID_RESERVE_RELATIVE_TOL_WAD = 0.05e18` at `Common.sol:319` of the bridge legacy). The existing infrastructure (`UniswapV4StandardExchangeVaultCommon.sol`) already uses `internal constant` for `LIQUID_RESERVE_RELATIVE_TOL_WAD`; the new families must follow.

### 3.9 E-9. Rehome of shared generic infrastructure

Required: PRD §10 final bullet permits "reuse of genuinely hook-independent protocol math, token/accounting primitives, generic vault facets and deployment infrastructure." The bridge legacy contains:

- `ERC20Repo`, `ERC5267Facet`, `ERC2612Facet`, `MultiAssetBasicVaultFacet`, `MultiAssetStandardVaultFacet`, `PositionImportFacet`, `LiquidReserveFacet` — hooks-agnostic; reuse.
- `InFacet`, `OutFacet`, `InQueryFacet`, `OutQueryFacet`, `InMultiFacet`, `InMultiQueryFacet`, `OutMultiFacet`, `OutMultiQueryFacet`, `InExecutionDelegate`, `OutExecutionDelegate` — wire to `QuoteService`; per-family duplication.
- `StandardExchangeConstantProduct.sol` — shared math; reuse.

Engineering must enumerate which generic facets share by `ArtifactCreationCode` salt (existing CREATE3 address) and which are family-specific. This is **engineering specification** but with a doc deliverable: PRD §13 item 24 requires the plan to enumerate "two family component sets and identify any generic infrastructure they reuse."

---

## 4. Verification gates

These are tests/evidence whose pass/fail releases a permission.

### 4.1 V-1. Production-path identity equivalence gate

Required (PRD §13 item 25 / §10): "Record source/runtime identity and separately label hermetic fixtures versus production deployment evidence." Concretely:

- The Pons hook codehash pinned at `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK` must match a deterministic on-chain `eth_getCode` reading (the in-tree file path `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol` is a SOURCE path, not a binary pin; PRD §10 paragraph says so explicitly: "The source path alone is not proof that deployed bytecode matches the local port.").
- The PoolManager binding (`0x8366a39CC670B4001A1121B8F6A443A643e40951` at `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol:169`) must match `poolManager()` on the live Pons V2 hook.
- The generated bytecode hash of the constructed Pons package must match the live on-chain byte at `PONS_V2_MEME_HOOK`.

**Status:** unverified per PRD §15 — "Upstream `main` sources are not deployed-version pins." This is the highest-confidence-impact item the user flagged as "deployed-runtime equivalence remains unproven."

### 4.2 V-2. Closed-form derivation gates per branch

Required (PRD §6.4 / §13 item 17 / §13 item 18): an engineering claim per branch that the "applicable existing closed-form equation exists". The gate is:

- Pointer to existing helper by name + path + lines.
- Witness: a reference test that runs the helper against random state and checks the resulting inverse, against a reference Python/Z3 harness or documented derivation.
- Numerical-tolerance bounds on integer arithmetic overflow at production state sizes.

### 4.3 V-3. Route-preservation exception gate

Required (PRD §6.4 #3 / §13 item 19): a route where requiring interleaving would eliminate both exact-in and exact-out **must** demonstrate that interleaving it would in fact eliminate both branches. The gate is:

- Pick a route (e.g., token0 → token1 swap-only).
- Construct the closed-form claim and demonstrate it removes both modes if interleaving is forced.
- Construct the in/ext exception claim and demonstrate which mode survives.

### 4.4 V-4. Family-mismatch gate

Required (PRD §13 item 23, §10): Hookless rejects non-zero hook; Pons rejects wrong hook, wrong codehash, same-flags impostor, wrong manager. Each rejection is a separate test case with explicit evidence at the family package boundary.

### 4.5 V-5. Legacy removal gate

Required (PRD §3.1): both new families implemented and tested, applicable PRD acceptance criteria satisfied, recorded determination "ready to submit for a security audit." Audit submission ≠ audit completion. The gate is **engineered to a checklist**, not a fixed slot. PRD §3.1 item 4 lists required artifacts.

### 4.6 V-6. Identity/bookkeeping gate

Required (PRD §13 items 14, 23, 28): tests must verify "same-flags/ABI impostors, independent vault state, correct generic-infrastructure reuse and occupied deployment-identity behavior." This is the salt-return idempotency test: two `deployPkg` calls with the same `salt = abi.encode(type(...DFPkg).name)._hash()` return the same address; two deployments of the same DFPkg with different `PkgArgs` constructor encoding produce distinct addresses only when `PonyPkg.calcSalt(...)` returns distinct inputs.

### 4.7 V-7. Frozen-state under owner mutation gate

Required (PRD §13 item 14, §10): the Pons V2 hook's `setHookFeeBps`, `setCreatorFeeRecipient`, `setBuybackEnabled` (and others at `PonsV2MemeHook.sol:239–285`) only affect **future** registrations or distribution routing, not per-pool `LaunchInfo` (frozen at registration per `PonsV2MemeHook.sol:389–403`). Test must demonstrate that mutating these between preview and execution does not alter quote correctness **for the registered pool** (it can alter it for unregistered pools, which are then `InvalidRoute` per the no-trade rejection).

### 4.8 V-8. DOS / stack-too-deep / runtime-byte fits gate

PRD constraints per `README.md` line 65 (`validate.md` historical): "every deployed facet, delegate, and package must fit 24,576 runtime bytes." Required test and assertion. Note: this is a per-component gate, not a per-package gate.

---

## 5. Documentation reconciliation

PRD §3 final paragraph and PRD §15 record that older PRDs remain unedited and that a "separately authorized documentation task must reconcile conflicting clauses." No new policy decision required; reconciliation is a doc-only work item.

### 5.1 R-1. Co-located V4 SE PRDs still authoritative

Per PRD §3 final paragraph: "Co-located older Uniswap V4 Standard Exchange PRDs remain unedited by this document." This means any text in `contracts/vaults/standard/exchange/protocols/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_CONSTANT_PRODUCT_ACCOUNTING_PRD.md`, the local liquid-buffer PRD, the full-range PRD, or any other unedited PRD may reference symbols that the new PRD no longer uses (e.g., D14 was changed by this PRD; D17 was changed by this PRD). The reconciler must catalog these stale references and update them.

### 5.2 R-2. `contracts/protocols/dexes/uniswap/v4/` removal docs

PRD §3.1 disposition: this tree is removed after the gate. Per PRD §3.1 items 1–5 the removal is gated and reversible, but the doc trail must:

- Reference the preserved source revision (git SHA / `PRESERVED_SOURCE_SHA256.json`).
- Update active implementation references to the new subtrees.
- Not imply the old source remains present.

### 5.3 R-3. Re-numbering / re-prefixing of identifiers

PRD §10 first table fixes the name stems. Existing files in the bridge legacy do NOT use those stems. Doc reconciler must:

- Update cross-references from the bridge legacy to the new trees **only if** the bridge legacy remains (gated by §3.1).
- Update the `VERSION_SOURCE_MAP.json` and `PRESERVED_SOURCE_SHA256.json` only if the old tree is removed.

### 5.4 R-4. PRD supersession map

PRD §14 last paragraph: "The former blanket exact-output prohibition is superseded." Doc reconciler must sweep older docs to remove the blanket-prohibition language (where present) and replace with the route-matrix-based admission language.

### 5.5 R-5. Family-PRD `DETF_ALIGNMENT_PRD.md` cross-reference

PRD §3 penultimate paragraph re-asserts `DETF_ALIGNMENT_PRD` D57–D59 and §24.7.1 as current release authority, alongside `CLAUDE.md`. No change needed; verification that any **new** hook-binding rules do not contradict DETF §24.7.1 is the gate. (DETF §24.7.1 mandates "exact finite-range position math"; the new PRD §10 retains this.)

---

## 6. Owner requirements still open? — answer: **no**

I checked each PRD clause against the open-item kinds above. The list of D1–D26 plus the §3.1 readiness gate and §13 acceptance list is, taken together, complete:

- D1–D13, D15, D16, D17–D19, D20–D21, D25: engineering or already-settled requirements.
- D14, D22, D23, D24, D26: ownership policy already fixed in this PRD text.
- §3.1, §13: verification gates expressed in PRD; engineering must produce the evidence.

Nothing in D1–D26 or §3.1 leaves a question that the owner must still answer to ship the implementation plan. The "highest-priority next step" (Section 8) is engineering work, not a question back to the owner.

---

## 7. Genuine contradictions between PRD and existing artifacts

The PRD asks for things the codebase does not yet contain or contradicts:

### 7.1 X-1. Two family trees do not exist

Observed: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/{hookless,ponsFamilyV2Hook}/` are absent. Only the unsegmented `v4/UniswapV4FullSpreadStandardExchangeVault*` exists. PRD §10 mandates both. Resolution: engineering creates both trees under the listed paths with the listed prefixes. **Not a doc gap — a missing implementation.**

### 7.2 X-2. PRD's `info[0] != 1` reads as version check but is registration check

Observed at `UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol:35`: `if (info[0] != 1)`. PRD §10 paragraph "It is the current-stack singleton" implicitly treats Pons Family V2 as a bounded version. The full review must clarify that `info[0]` is the bytes32 ABI-encoded `bool registered` of `LaunchInfo` (per `PonsV2MemeHook.sol:48`, where field 0 is `bool registered`). The actual identity binding is the codehash pin per D26. Doc clarification: add an inline comment in the new Pons package's QuoteService mirror.

### 7.3 X-3. PRD references the "current unsegmented V4 implementation" as baseline

Observed: PRD §6.4 second bullet points to `contracts/vaults/standard/exchange/protocols/uniswap/v4/` (the bridge legacy). PRD §3.1 dispositions this directory as REMOVED after the gate. The brief "before removal" period uses this tree as the seed for splitting. No contradiction; the PRD is internally consistent. But engineering must NOT delete the bridge legacy tree until the gate.

### 7.4 X-4. Bridge legacy QuoteService has a "return amount" fallback

Observed at `UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol:55`: `if (!supported) return amount; // Retain the existing quote path for other hooks.` PRD §10 last bullet ("Remove... unknown-hook vanilla-quote fallback") mandates removing this for the **new** family packages. The bridge legacy retains it (gate-bound). No contradiction; documented.

### 7.5 X-5. `_amountInForShares` prepaid-credit scaling vs PRD exact-input

Observed at `UniswapV4FullSpreadStandardExchangeVaultOutBase.sol:49–62`: `_amountInForZapMint(address tokenIn, uint256 sharesOut, uint256 prepaidCredit)` reads a third argument. PRD §6.1 says pretransfer credits `amountIn` exactly (no prepaid-credit scaling). The new family's `_amountInForShares` must be the closed-form derivation against `reserveIn` (free pool money) rather than `reserveIn - prepaidCredit` (scaled). This is the "contract-shape update" called out in E-1.

---

## 8. Highest-priority next step

**V-1 (production-path identity equivalence gate) — confirmed as highest priority by the user prompt**. Without V-1, no plan item can be defensibly finalized because the binding target is itself unverified. After V-1:

**E-1 (existing-formula inventory) is second priority**. Without E-1, the engineering cannot finalize any branch's exact-output support or `InvalidRoute` decision. PRD §6.4 explicitly directs the engineering to inventory first.

**V-2 (closed-form derivation gates per branch) is third**. After the inventory, each branch needs the witness test.

**Engineering can begin E-1 immediately and in parallel with the V-1 verification.** They are not blocked by each other.

The user asked for "highest-priority next step." Confidence:

- **HIGH** confidence that V-1 is the priority (user flagged it explicitly).
- **HIGH** confidence that no owner-policy decision blocks work.
- **MEDIUM** confidence on the engineering inventory outcome (E-1): I cannot predict whether each branch's existing closed form will be acceptable without re-deriving it. The investment risk is in the formula-vs-shape conformance (X-5), which is bounded but real.

---

## 9. Verified facts and confidence

### 9.1 Direct file-line evidence (research only)

- PRD `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md:1–528` — source of every D1–D26.
- `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol:439–441` — defines `PONS_V2_MEME_HOOK = 0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044`. Matches PRD D26 verbatim.
- `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol:169` — `UNISWAP_V4_POOL_MANAGER = 0x8366a39CC670B4001A1121B8F6A443A643e40951`. Matches PRD D23.
- `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol:422–427` — Pons V2 factory/hook/launchlocker/buyback addresses, all pinned in tree.
- `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol:48–67` — `LaunchInfo` struct layout with `bool registered` at field 0.
- `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol:184–201` — hook permissions `beforeInitialize|afterSwap|afterSwapReturnsDelta`.
- `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol:212–216` — `setFactory` one-time guard (`AlreadySet`).
- `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol:355–407` — `_registerPool` validates hook equality and snapshot freezes per-pool fees.
- `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol:415–437` — onlyFactory gates `setCreatorFeeRecipient` / `setBuybackEnabled`.
- `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol:239–285` — owner-settable globals bounded by `MAX_HOOK_FEE_BPS=1000`, `MAX_PROTOCOL_FEE_SHARE_BPS=5000`, `MAX_TOTAL_TRADE_FEE_BPS=2000`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol:21–42` — `_ponsHookFees` decode with `info[0] != 1`, `info[10] + info[7] <= 2000`, currency-orientation check.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultCommon.sol:319` — `LIQUID_RESERVE_RELATIVE_TOL_WAD = 0.05e18` is `internal constant` (model for fixed-constant adoption).
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultCommon.sol:432–434` — `_slot0()` destructures live `lpFee`/`protocolFee` but neither is consumed downstream.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultOutBase.sol:49–62` — `_amountInForZapMint` uses `prepaidCredit` argument (PRD mismatch X-5).
- `contracts/vaults/standard/exchange/StandardExchangeConstantProduct.sol:30–35` (initial shares), `:37–65` (`_sharesForDeposit`), `:78–96` (`_amountInForShares` exact-out), `:98–111` (`_singleExit`), `:113–129` (`_sharesForSingleExit`).
- `lib/crane/contracts/utils/math/` directory (12 files): `AerodromeUtils.sol`, `BetterMath.sol`, `CamelotV2Utils.sol`, `ConstProdUtils.sol`, `SignedMath.sol`, `SlipstreamQuoter.sol`, `SlipstreamUtils.sol`, `SlipstreamZapQuoter.sol`, `UniswapV2Utils.sol`, `UniswapV3Quoter.sol`, `UniswapV3Utils.sol`, `UniswapV3ZapQuoter.sol`. **There is no `UniswapV4Math.sol`** in this directory. The V4 math lives in `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/` (`Hooks.sol`, `LPFeeLibrary.sol`, `ProtocolFeeLibrary.sol`, `Pool.sol` library), `utils/UniswapV4Quoter.sol`, `utils/UniswapV4ZapQuoter.sol`. PRD §6.4 says inspect `lib/crane/contracts/utils/math/` "and" the current unsegmented implementation; both must be inventoried.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/` — does not exist; the bridge legacy `v4/UniswapV4FullSpreadStandardExchange*` is what currently occupies the path.
- `README.md:65` — "every deployed facet, delegate, and package must fit 24,576 runtime bytes" (gate constraint carried forward).

### 9.2 External checks (Context7 not strictly required here; primary sources already read)

- No external V4 library claims introduced. PRD's external references (Uniswap universal router / V3ToV4Migrator / V4 Hooks / V4 PositionManager) match `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md:522–524`. No new claim.

### 9.3 Confidence summary

- **HIGH**: PRD read; D-numbers enumerated; file paths verified; Pons identity constants verified.
- **HIGH**: no remaining owner policy decision blocks shipping the engineering plan.
- **MEDIUM**: the existing-formula inventory outcome (whether each branch's existing helper passes the conform check) cannot be predicted without re-derivation.
- **LOW (informational only)**: PRD §10 paragraph about "current-stack singleton" slightly conflates version semantics with `info[0]` — a doc clarity fix is small.

---

## 10. Distinguishing observation from inference

- **Observations** (verified by direct file:line read or unaltered PRD text):
  - PRD D1–D26, §3.1, §6.4, §13 acceptance items are explicit.
  - `PONS_V2_MEME_HOOK`, `UNISWAP_V4_POOL_MANAGER` addresses match PRD text.
  - Existing Closed-form helpers exist at `StandardExchangeConstantProduct.sol` lines 30, 37, 78, 98, 113.
  - Two family tree paths in PRD §10 do not exist on disk.
  - `info[0]` is the ABI-encoded `bool registered` (struct field 0).
  - `LIQUID_RESERVE_RELATIVE_TOL_WAD` is `internal constant` (model for fixed constants).
  - Pons hook permissions are exactly the PRD-relevant mask (BEFORE_INIT, AFTER_SWAP, AFTER_SWAP_RETURNS_DELTA).
  - Pons owner setters are bounded by immutable caps.
  - Pons per-launch mutable fields: `setCreatorFeeRecipient`, `setBuybackEnabled` (both onlyFactory).

- **Inference** (mechanically derivable from observations, marked):
  - **MIR-1**: Combined exact-output + rebalance closed-form on vanilla full-range pools — the math supports it because `LiquidityAmounts.getLiquidityForAmounts` is closed-form on sqrtPriceX96 + lower + upper. **Marked as inference, not observation**, because the run-time alignment with the post-swap incumbent ratio still requires engineering verification.
  - **MIR-2**: PRD's blanket exact-output prohibition intent (without D17–D19) was mistaken because the existing helpers already support the share-side exact-out legs (ConstantProduct.sol:78–96); PRD §6.4 #1 enables recovering those without changes.
  - **MIR-3**: Gated legacy removal at the §3.1 readiness gate provides the owner an explicit checkpoint; without V-1 (deployed-runtime equivalence), that gate is non-defensible.

- **Spec (engineering must decide, no claim)**:
  - Exact step-size selection for bounded solver iteration (D4 / §6.2): bounded 4–8 iter or closed-form; the latter is preferred per PRD §6.4 #2.
  - Ordering of pricing-and-mint across the unlockCallback (single unlock vs. multiple): preferred single `_executeUnlock` to keep settlement atomic.

---

## 11. Saved path

**Saved:** `docs/research/uniswap-v4-open-items-2026-09-27/MINIMAX_ORIGINAL.md`
**Preserved unchanged:** original (this file is the original).
No code, shell, test, config, or delegation performed. No peer artifacts read.
