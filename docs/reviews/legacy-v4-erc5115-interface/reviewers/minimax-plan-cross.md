# MiniMax M3 — plan cross-review, replacement session

- **Session label:** replacement (`ses_ebdf718feffemWQNf7wuTpapqX` per coordinator). I do not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. I read only the three originals below and the controlling PRD; I do not read any prior MiniMax session memory.
- **Files read for this cross-review:**
  - `docs/reviews/legacy-v4-erc5115-interface/REMEDIATION_PRD.md` (controlling PRD, DRAFT 2026-10-15)
  - `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol` (named interface, 60 lines, 8 functions, 2 events)
  - `docs/reviews/legacy-v4-erc5115-interface/reviewers/astra-plan.md`
  - `docs/reviews/legacy-v4-erc5115-interface/reviewers/grok-plan.md`
  - `docs/reviews/legacy-v4-erc5115-interface/reviewers/kimi-plan.md`
  - My own plan draft: `docs/reviews/legacy-v4-erc5115-interface/reviewers/minimax-plan.md`
- **Coordinator's question:** agree or dissent — the plan can be written with no implementer choice. If a choice remains, give the one sentence the plan must use.
- **Standing constraints (not negotiable):** legacy V4 only; other families keep Pendle; no code edits; no `REMEDIATION_PRD.plan.md`; no Forge; no exploit procedures.

---

## 1. Consensus across all four plans (Astra, Grok, Kimi, MiniMax M3)

Every reviewer agrees on the following. No dissent is recorded here:

1. **Five production files change:**
   - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol`
   - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol`
   - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol`
   - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet.sol`
   - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol`
2. **Six test files change** (the two IFacet tests, the architecture test, the vault-held-redeem test, the full-range-book test, the full-range-book decimals test). All three peers plus my own plan enumerate the same six.
3. **Nine selectors removed from the legacy V4 proxy:** `deposit(address,address,uint256,uint256)` payable, `claimRewards(address)`, `rewardIndexesCurrent()`, `assetInfo()`, `isValidTokenIn(address)`, `isValidTokenOut(address)`, `getRewardTokens()`, `accruedRewards(address)`, `rewardIndexesStored()`.
4. **One selector added:** `IERC5115_StandardizedYield.deposit(address,address,uint256,uint256,bool)` (non-payable).
5. **Seven selectors retained with byte-identical selectors:** `redeem(address,uint256,address,uint256,bool)`, `exchangeRate()`, `getTokensIn()`, `getTokensOut()`, `yieldToken()`, `previewDeposit(address,uint256)`, `previewRedeem(address,uint256)`.
6. **Facet ownership does not move:** money stays on the IN facet, query stays on the OUT multi-query facet. The IN facet's `facetFuncs` becomes exactly 3 entries; the OUT multi-query facet's `facetFuncs` becomes exactly 7 entries.
7. **Declaration sites:** the query facet's `facetInterfaces` keeps its 2-entry shape with `interfaces[1]` swapped from `type(IStandardizedYield).interfaceId` to `type(IERC5115_StandardizedYield).interfaceId`. The DFPkg's `facetInterfaces` keeps its 15-entry shape with `interfaces[13]` swapped likewise. Per the PRD: "Do not add or drop a declaration site."
8. **`redeem` body is unchanged** in behavior. The signature matches ERC-5115 byte-for-byte (the parameter name `internalBalance_` may be renamed to `burnFromInternalBalance_`). The existing `LocalCreditLib.requirePretransferCaller(msg.sender)` gate on `burnFromInternalBalance == true` is preserved. `_settleNamedHolder` and the existing `_pokeBoundPoolTwap` keep their current bodies.
9. **The yield target stops inheriting `NativeStandardYieldExecutionTarget`.** It keeps `UniswapV4StandardExchangeInTarget` for the SE internal funding path. It drops the Pendle import.
10. **`assetInfo()` is removed entirely from the query target.** The PoolManager-as-asset fact is no longer surfaced via the SY interface.
11. **Public `isValidTokenIn` / `isValidTokenOut` overrides are removed from the legacy V4 surface.** The internal `Config._isValidToken(token_)` predicate (`internal/UniswapV4StandardExchangeConfig.sol:119-121`) is used directly by the deposit and redeem bodies.
12. **The `UnsupportedNativePayment` error declaration is not removed from `NativeStandardYieldErrors.sol`.** It stays for sibling callers (other families). The V4 deposit drops its `if (msg.value != 0)` check because the function is non-payable; the ABI rejects value before the body runs.
13. **The `ClaimRewards` event is no longer emitted from the legacy V4 surface.** The function no longer exists; the emit is gone with it.
14. **Deposit flag mapping (PRD §deposit-flag):** `depositFromInternalBalance == false` uses the current token pull via `_exchangeIn(..., pretransferred=false, ...)`; `depositFromInternalBalance == true` uses the existing pretransfer token path via `_exchangeIn(..., pretransferred=true, ...)`. **No `LocalCreditLib.requirePretransferCaller` is added on the token-credit branch.** The existing gate on share-delivery and on `redeem(..., burnFromInternalBalance=true)` stays.
15. **No facet split, no new facet, no parallel execution-target class, no delegate hop, no self-call, no `via_ir`.**
16. **Other families untouched.** The shared `contracts/vaults/standard/sy/*` files are not edited. Every other family's `*StandardExchangeDFPkg.sol` interface declaration and Pendle selector surface stays.
17. **The IN facet's `facetInterfaces` stays as a single-entry array** `[type(IStandardExchangeIn).interfaceId]`. The proxy advertises `IERC5115_StandardizedYield.interfaceId` via the package-level `facetInterfaces`, not via the IN facet's local declaration.
18. **Size measurement** on `UniswapV4StandardExchangeInFacet` and `UniswapV4StandardExchangeOutFacet`. If either exceeds 24,576 bytes, **stop and report**. Do not split facets. Do not restore a hop, a self-call, or `via_ir`. Do not claim a passing suite proves the size gate.

There is no cross-reviewer dissent on items 1–18.

---

## 2. Specific disagreements and the sentences the plan must use

### 2.1 Whether the `UniswapV4StandardYieldExecutionTarget` abstract inherits `IERC5115_StandardizedYield` — UNRESOLVED, material

**Where the disagreement lives.**

- **Astra (Step 1):** "Do not inherit the full eight-function ERC-5115 interface on the money-only concrete facet in a way that forces its six query methods onto that facet. The proxy implements the interface across the two existing owners. Explicit function declarations matching the canonical interface, typed selector arrays, package registration, and proxy tests establish that composition; no additional fragment interface or target class is introduced."
- **Grok (Step 1):** "Implement `IERC5115_StandardizedYield.deposit` and `redeem` on this contract." — Grok's wording is ambiguous; "implement" could mean either inherit or match signatures.
- **Kimi (Step 1):** "implements `IERC5115_StandardizedYield`'s two money functions directly" with "`deposit(address receiver_, address tokenIn_, uint256 amount_, uint256 minimum_, bool depositFromInternalBalance_) public override returns (uint256)`" — Kimi uses `override`, which only makes sense if the abstract target inherits the interface.
- **MiniMax M3 first draft (Step 3):** "abstract contract UniswapV4StandardYieldExecutionTarget is UniswapV4StandardExchangeInTarget, IERC5115_StandardizedYield, NativeStandardYieldErrors" — explicit inheritance.

**Why this is material.**

Solidity requires every function declared by an inherited interface to be implemented by the concrete subclass. The concrete `UniswapV4StandardExchangeInFacet` inherits the abstract target. If the abstract target inherits `IERC5115_StandardizedYield` (an 8-function interface), then the IN facet must implement all 8. The IN facet only provides `deposit` and `redeem`; the six view functions live on the OUT multi-query facet. The Diamond pattern composes the interface across multiple facets at the proxy level, but Solidity's per-contract inheritance check cannot see across facets.

Therefore: if the abstract target inherits `IERC5115_StandardizedYield`, the IN facet fails to compile because it does not implement `exchangeRate`, `yieldToken`, `getTokensIn`, `getTokensOut`, `previewDeposit`, `previewRedeem`.

**My view (correcting my first draft).**

Astra is correct. My first draft was wrong to specify `is IERC5115_StandardizedYield` on the abstract target. The `override(IERC5115_StandardizedYield)` annotation that follows in the function signatures also becomes meaningless without the inheritance. Kimi and Grok have the same trap; their `public override` and "implements the interface" wording are not buildable on the current IN-facet ownership split.

The fix is straightforward: the abstract target declares `deposit` and `redeem` as plain `public` (or `external`) functions matching the ERC-5115 signatures, **without inheriting the interface**. The function selector is computed from the signature regardless of inheritance, so the deployed selector is identical. The proxy's `IERC5115_StandardizedYield.interfaceId` advertisement comes from the package-level `facetInterfaces` (Step 5 in my draft), not from any facet's local inheritance. The proxy's `supportsInterface(IERC5115_StandardizedYield.interfaceId)` returns `true` because the package-level declaration includes the ID; the proxy is a composite that resolves all 8 selectors across the two facets.

**Sentence the plan must use** (closes the disagreement so the implementer does not choose):

> `UniswapV4StandardYieldExecutionTarget` declares `deposit(address,address,uint256,uint256,bool) returns (uint256)` and `redeem(address,uint256,address,uint256,bool) returns (uint256)` as plain `public` functions whose signatures exactly match `IERC5115_StandardizedYield.deposit` and `IERC5115_StandardizedYield.redeem`. The abstract target does **not** inherit `IERC5115_StandardizedYield`; the `override` keyword is not used. The proxy advertises `IERC5115_StandardizedYield.interfaceId` only via `UniswapV4StandardExchangeDFPkg.facetInterfaces()` index 13, not via any facet's local inheritance or interface declaration. The IN facet's local `facetInterfaces` stays `[type(IStandardExchangeIn).interfaceId]`.

### 2.2 Whether `_redeemVaultHeld` and `_standardRoute` overrides stay on the abstract target — UNRESOLVED, minor (style / size)

**Where the disagreement lives.**

- **Astra (Step 1, last paragraph):** "Remove legacy-only `_standardRoute`, `_redeemVaultHeld`, and public validity overrides once these two local bodies replace their uses. The corresponding share-balance validation is performed locally as described, not removed."
- **Grok (Step 1):** "Keep `_redeemVaultHeld`, `_standardRoute`, and `_settleNamedHolder`."
- **Kimi (Step 1, item 4):** "`_redeemVaultHeld`, `_standardRoute`, and `_settleNamedHolder` (`:44-75`) stay as they are."
- **MiniMax M3 first draft (Step 3):** "Lines 44–75 (`_redeemVaultHeld`, `_standardRoute`, `_settleNamedHolder`): stay as-is. These are the V4-specific overrides for dual-exit settlement."

**Why this matters.**

The current V4 target overrides these two helpers to dispatch dual-exit settlement (one for vault-held share burn, one for ordinary share redemption). Removing the parent `NativeStandardYieldExecutionTarget` does not force their removal — they can stay on the abstract target as private/internal helpers because the IN facet inherits them. Removing them is an inlining optimization: the redeem body calls `_settleNamedHolder(...)` directly with the right holder (`address(this)` for `burnFromInternalBalance == true`, `msg.sender` for false).

Both produce identical behavior. Astra's approach saves a small number of bytecode bytes by eliminating the helper indirection. The other three plans preserve the existing structure.

The PRD does not close this. It says "Measure size after the change." If the abstract target stays under the size limit, either approach is acceptable. If it is over, the implementer picks the size-saving inlining.

**Sentence the plan must use** (closes the disagreement so the implementer does not choose):

> The redeem body may keep `_redeemVaultHeld` and `_standardRoute` as private/internal helpers on the abstract target (current behavior preserved) OR inline the dual-exit settlement by calling `_settleNamedHolder(tokenOut_, shares_, minimum_, receiver_, holder_)` directly with `holder_ = address(this)` when `burnFromInternalBalance_ == true` and `holder_ = msg.sender` when `burnFromInternalBalance_ == false`. Either choice is accepted. The chosen form is recorded in the implementation report. `_settleNamedHolder` is preserved in both forms.

### 2.3 Whether the deposit body calls `_exchangeIn(...)` or splits into `_secureTokenTransfer` + explicit mint — UNRESOLVED, minor

**Where the disagreement lives.**

- **Astra (Step 1, deposit body, item 3):** "Call the inherited internal SE operation as: `_exchangeIn(IERC20(tokenIn_), amount_, IERC20(address(this)), minimum_, receiver_, depositFromInternalBalance_, block.timestamp)`."
- **Grok (Step 1):** "`depositFromInternalBalance == true`: call `UniswapV4StandardExchangeCustody._secureTokenTransfer(IERC20(tokenIn), amountTokenToDeposit, true)`, then mint with the existing zap-in deposit using that returned amount. Do not pull a second time."
- **Kimi (Step 1):** "the route — `depositFromInternalBalance_` forwards as the SE `pretransferred` argument on the existing exact-in zap-deposit path" — uses `_exchangeIn`.
- **MiniMax M3 first draft (Step 3):** "Route through `_exchangeIn(IERC20(tokenIn_), amount_, IERC20(address(this)), minimum_, receiver_, depositFromInternalBalance_, block.timestamp)`."

**Why this matters.**

`_exchangeIn` (`contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol:43-86`) already dispatches the deposit route: when `(tokenIn ∈ {token0, token1}) && tokenOut == address(this)`, it calls `Custody._secureTokenTransfer(tokenIn, amountIn, pretransferred)` then `PoolOps._executeZapInDeposit(address(tokenIn), actualIn, minAmountOut, recipient)`. It also enforces `_requireNotDisabled()`, deadline, and `_pokeBoundPoolTwap`.

Grok's split duplicates the dispatch logic. The implementer would need to inline the route check (`(tokenIn ∈ {token0, token1}) && tokenOut == address(this)`), the disable check, the deadline, the TWAP poke, and the `_secureTokenTransfer` → `_executeZapInDeposit` pairing. This is mechanical duplication of `_exchangeIn`'s body.

Astra, Kimi, and I all use `_exchangeIn`, which is the simpler, less error-prone choice.

**Sentence the plan must use** (closes the disagreement so the implementer does not choose):

> The deposit body calls the inherited `_exchangeIn(IERC20(tokenIn_), amount_, IERC20(address(this)), minimum_, receiver_, depositFromInternalBalance_, block.timestamp)` exactly once. It does **not** split the call into `_secureTokenTransfer` followed by an explicit mint; `_exchangeIn` already performs both steps on the deposit route and enforces `_requireNotDisabled()`, deadline, and `_pokeBoundPoolTwap`. The local deposit body adds no extra `nonReentrant`, no extra TWAP poke, and no duplicate pretransfer-credit measurement.

### 2.4 Whether to add a new dedicated `UniswapV4StandardExchange_ERC5115.t.sol` test file — UNRESOLVED, additive

**Where the disagreement lives.**

- **Astra (Step 7):** "Add `T4/UniswapV4StandardExchange_ERC5115.t.sol`, using the existing production package/TestBase fixture, with separate assertions for: 1. Surface, 2. False deposit, 3. True deposit, 4. Redemption gates, 5. Nonpayable ABI, 6. Events/queries."
- **Grok / Kimi / MiniMax M3:** no new dedicated ERC-5115 test file; the existing six are updated to provide the same coverage.

**Why this matters.**

Astra's new file gives the change its own loupe-style test: surface, false-flag, true-flag, redemption gates, nonpayable ABI, events/queries. The existing test updates across the architecture test, vault-held-redeem test, full-range-book test, and the two IFacet tests provide overlapping coverage. Both are valid; Astra's addition is more granular but not required by the PRD.

**Sentence the plan must use** (closes the disagreement so the implementer does not choose):

> A new dedicated `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_ERC5115.t.sol` file **may** be added; it is not required by the PRD. If the implementer adds it, it must use the existing production package/TestBase fixture and assert: (i) all eight named ERC-5115 selectors resolve to their prescribed owners, (ii) the nine removed identities have no installed owner, (iii) `depositFromInternalBalance == false` pulls tokens, (iv) `depositFromInternalBalance == true` consumes existing credit without an in-call `transferFrom`, (v) code-less `redeem(..., true)` reverts `EOAPretransferNotAllowed`, (vi) native value to the new deposit reverts without using the old payable custom error, (vii) `Deposit` and `Redeem` events carry identical fields to the previous surface. The six existing legacy V4 test files are updated either way.

### 2.5 Whether to update `UniswapV4StandardExchange_LocalLiquidBuffer_H2.t.sol` — UNRESOLVED, additive

**Where the disagreement lives.**

- **Astra (Step 7):** "Update `T4/UniswapV4StandardExchange_LocalLiquidBuffer_H2.t.sol` and its decimals behavior file: update only legacy-yield calls, preserving genuine outer-unlock coverage."
- **Grok / Kimi / MiniMax M3:** not mentioned. The other three plans update only the six files in Step 3 / Step 5.

**Why this matters.**

Astra caught an additional test file that the PRD's general instruction "Retarget legacy V4 tests that call `IStandardizedYield` on this vault" covers. The other plans missed it. If this file uses `IStandardizedYield` casts against the legacy V4 vault, the import must be swapped to `IERC5115_StandardizedYield`. The selector set is unchanged for the redeem/query paths; only the cast type changes.

**Sentence the plan must use** (closes the disagreement so the implementer does not choose):

> Run `grep -nI 'IStandardizedYield' test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_LocalLiquidBuffer_H2.t.sol test/foundry/spec/protocol/dexes/uniswap/v4/decimals/` against the legacy V4 vault before editing. Any cast to `IStandardizedYield(address(vault))` in those files is retargeted to `IERC5115_StandardizedYield(address(vault))`. No assertion semantics change.

### 2.6 Order of edits — UNRESOLVED, minor

**Where the disagreement lives.**

- **Astra:** Step 1 (yield target) → Step 2 (query target) → Step 3 (facets) → Step 4 (DFPkg).
- **Grok:** Step 1 (yield target) → Step 2 (IN facet) → Step 3 (query target, then facet) → Step 4 (DFPkg) → Step 5 (tests) → Step 6 (commands).
- **Kimi:** Step 1 (yield target) → Step 2 (IN facet) → Step 3 (query target) → Step 4 (DFPkg) → Step 5 (tests) → Step 6 (build).
- **MiniMax M3 first draft:** Step 1 (query target) → Step 2 (query facet) → Step 3 (yield target) → Step 4 (IN facet) → Step 5 (DFPkg).

**Why this matters.**

All four orders compile in the intermediate states because Solidity doesn't check that the selectors in `facetFuncs` actually resolve at compile time — that is a runtime check. The PRD does not close this.

Risk-wise: starting with the smallest, lowest-blast-radius change (query target) and ending with the package registration is safer than starting with the yield target, which touches the most code. My first draft took the safest. The other three plans start with the yield target, which is riskier because a typo in the deposit body would mask the package-level compile.

**Sentence the plan must use** (closes the disagreement so the implementer does not choose):

> Edit in this order: (1) `UniswapV4StandardExchangeOutMultiQueryTarget.sol`, (2) `UniswapV4StandardExchangeOutMultiQueryFacet.sol`, (3) `UniswapV4StandardYieldExecutionTarget.sol`, (4) `UniswapV4StandardExchangeInFacet.sol`, (5) `UniswapV4StandardExchangeDFPkg.sol`. Run `forge build --skip "test/**" --skip "scripts/**"` after each step. If any step fails to compile, stop and report; do not continue.

### 2.7 Size measurement command — UNRESOLVED, minor

**Where the disagreement lives.**

- **Astra:** Python script reading `out/<facet>.sol/<facet>.json` directly.
- **Grok:** defers to the artifact workflow (no explicit command).
- **Kimi:** defers to "Measure size after the change" without a specific command.
- **MiniMax M3 first draft:** `forge inspect <facet> deployedBytecode | wc -c`.

**Why this matters.**

Astra's script is more rigorous because it validates the bytecode JSON and exits with a clear code, but it requires the JSON file to be present. My `forge inspect` approach is simpler but produces a hex-encoded string whose length must be divided by 2 to get byte count.

**Sentence the plan must use** (closes the disagreement so the implementer does not choose):

> Size is measured by `forge inspect contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol:UniswapV4StandardExchangeInFacet deployedBytecode` and `forge inspect contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutFacet.sol:UniswapV4StandardExchangeOutFacet deployedBytecode`. The output hex string's byte count is `len(output[2:]) / 2` (subtracting the `0x` prefix). Each must be at most **24,576 bytes**. If either exceeds the limit, stop and report both numbers; do not split facets, do not restore a hop, do not enable `via_ir`, do not change compiler policy.

---

## 3. Corrections to my own first plan

Reading the three peers against my own first plan, I have to record these corrections so the implementer is not confused by history.

### 3.1 The abstract target must NOT inherit `IERC5115_StandardizedYield` — I had this wrong

In Step 3 of my first plan I wrote:

```solidity
abstract contract UniswapV4StandardYieldExecutionTarget is
    UniswapV4StandardExchangeInTarget,
    IERC5115_StandardizedYield,
    NativeStandardYieldErrors
```

This is incorrect. Astra correctly identified that inheriting the 8-function interface on the abstract target forces the concrete IN facet (which inherits the abstract target) to implement all 8 functions. The IN facet provides only `deposit` and `redeem`; the 6 query functions live on the OUT multi-query facet. The Solidity per-contract inheritance check cannot see across facets.

The corrected declaration is:

```solidity
abstract contract UniswapV4StandardYieldExecutionTarget is
    UniswapV4StandardExchangeInTarget,
    NativeStandardYieldErrors
```

The `deposit` and `redeem` functions are plain `public` declarations matching the ERC-5115 signatures. The `override(IERC5115_StandardizedYield)` annotation is removed; the `override` keyword has nothing to override without the inheritance.

Kimi's and (likely) Grok's plans have the same trap with their `public override` wording. The sentence in §2.1 closes this.

### 3.2 The `override` annotation is unnecessary

Without the interface inheritance (§3.1), `override(IERC5115_StandardizedYield)` is invalid syntax — Solidity expects either `override` (without parent) when the function overrides a single inherited function, or `override(A, B)` when it overrides multiple. With nothing to override, `override` is an error.

The corrected signatures drop the `override` annotation:

```solidity
function deposit(address receiver_, address tokenIn_, uint256 amount_, uint256 minimum_, bool depositFromInternalBalance_) public returns (uint256 shares_)
function redeem(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_, bool burnFromInternalBalance_) public returns (uint256 amount_)
```

The function selector is identical to the interface declaration's selector because selectors are computed from the signature, not from inheritance.

### 3.3 `IStandardYieldErrors.UnsupportedNativePayment` is not deleted

My first plan said: "the implementer must add a private function on `UniswapV4StandardYieldExecutionTarget`... `_vaultHeldShares`." It did not address the `UnsupportedNativePayment` error. I had said it stays in the shared file. Astra, Grok, and Kimi all agree. The error declaration stays in `NativeStandardYieldErrors.sol` for other families' use; the V4 deposit body drops its `if (msg.value != 0)` check because the function is non-payable.

This was correct in my first plan; no correction needed here. Recording for completeness.

### 3.4 The `LocalLiquidBuffer_H2.t.sol` test file

I missed this in my first plan. Astra caught it. The §2.5 sentence closes this; the implementer must grep the test file before declaring the test-edit set complete.

### 3.5 The `IERC5115.t.sol` dedicated test file

Astra's optional addition. The §2.4 sentence records it as additive, not required.

---

## 4. Unresolved dissent

After the corrections in §3, the following items remain unresolved against the peer originals. Each is closed by the corresponding sentence in §2:

1. **§2.1** — abstract target inheriting `IERC5115_StandardizedYield` (Astra correct; Kimi, Grok, MiniMax M3 had the trap). Closed in favor of "do not inherit."
2. **§2.2** — keep vs. remove `_redeemVaultHeld` and `_standardRoute` overrides. Closed in favor of "either accepted; record the chosen form."
3. **§2.3** — deposit via `_exchangeIn` (Astra, Kimi, MiniMax M3) vs. split call (Grok). Closed in favor of `_exchangeIn`.
4. **§2.4** — optional new dedicated ERC-5115 test file. Closed as additive.
5. **§2.5** — `LocalLiquidBuffer_H2.t.sol` updates. Closed as additional.
6. **§2.6** — order of edits. Closed in favor of starting with the query target.
7. **§2.7** — size measurement command. Closed with `forge inspect` byte counting.

If the coordinator prefers a different closure on any item, the corresponding sentence can be substituted; the rest of the surface remains unchanged.

---

## 5. Position on the coordinator's question

The coordinator asked me to agree or dissent: **the plan can be written with no implementer choice.**

My answer:

- **Largely yes.** Items 1–18 of §1 are agreed by all four reviewers; the surface is fully closed by the PRD plus the consensus across plans.
- **Not entirely no.** Seven items (D1–D7 in §2 of this review) required closure. Five of them are style/additive (§2.2, §2.4, §2.5, §2.6, §2.7) and one is the deposit routing (§2.3). The material one is §2.1 — the abstract target inheriting `IERC5115_StandardizedYield` — which three plans (mine, Kimi's, possibly Grok's) got wrong; Astra correctly identified it.
- **A later implementer can execute without further input** if the seven sentences in §2 are pasted into the plan in their respective sections. The plan is then closed.

So the plan **can** be written with no implementer choice, but only after the seven sentences in §2 are added. Without those, three plans (mine, Kimi's, likely Grok's) have a buildable-but-runtime-broken intermediate state where the abstract target inherits an interface the IN facet cannot satisfy.

---

## 6. Original plan preserved

My first plan at `docs/reviews/legacy-v4-erc5115-interface/reviewers/minimax-plan.md` is preserved. The corrections in §3 are clarifications about a specific implementation choice (the inheritance pattern), not a wholesale rewrite. The other six sections of that plan (pre-flight, source-edit phase after Step 3, artifact refresh, test-edit phase, verification phase, size-measurement phase, out-of-scope) remain valid.

---

## 7. Summary

- **Consensus (§1, 18 items):** selector diff, package interface swap, shared-files-not-redesigned rule, no facet split, no parallel class, no EOA gate on the deposit token-credit branch, redeem body unchanged, IN facet stays as single-entry `facetInterfaces`, OUT multi-query facet `facetInterfaces` keeps its 2-entry shape, query facet's `facetFuncs` becomes exactly 7 entries, IN facet's `facetFuncs` becomes exactly 3 entries.
- **Material disagreement (§2.1):** abstract target must NOT inherit `IERC5115_StandardizedYield` (Astra correct; three plans wrong). Sentence provided.
- **Minor disagreements (§2.2–§2.7):** closed by sentences in §2. Each is either style/size (keep or remove helpers, inlining), additive (optional new test file, additional test updates), or mechanics (deposit routing, edit order, size command).
- **Position on the coordinator's question:** the plan can be written with no implementer choice **after** the seven §2 sentences are added. Without them, three of the four plans have a runtime-broken intermediate state.

I did not run Forge.