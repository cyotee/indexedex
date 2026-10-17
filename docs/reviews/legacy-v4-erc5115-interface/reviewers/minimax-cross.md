# MiniMax M3 — cross-review, replacement session

- **Session label:** replacement (`ses_ebdf718feffemWQNf7wuTpapqX` per coordinator). I do not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. I read only the three originals below; I do not read any prior MiniMax session memory and I do not edit code.
- **Files read for this cross-review:**
  - `docs/reviews/legacy-v4-erc5115-interface/reviewers/astra-original.md` (Astra)
  - `docs/reviews/legacy-v4-erc5115-interface/reviewers/grok-original.md` (Grok)
  - `docs/reviews/legacy-v4-erc5115-interface/reviewers/kimi-original.md` (Kimi)
  - My own first pass: `docs/reviews/legacy-v4-erc5115-interface/reviewers/minimax-original.md`
- **Standing constraints (not negotiable):** legacy V4 only; other families keep Pendle unless the owner separately rules otherwise; no code edits; no `REMEDIATION_PRD.md`; no Forge; no exploit procedures.
- **My earlier findings are kept under that heading at the bottom; this cross-review is purely about agreements, objections, and resolved/unresolved dissent versus the three peer originals.**

---

## 1. Consensus across all four reviews (Astra, Grok, Kimi, MiniMax M3)

Every reviewer agrees on the following surface changes; no dissent is recorded here:

1. **Pendle → Neuer-1 selector additions:** exactly one new selector on the legacy V4 proxy: `IERC5115_StandardizedYield.deposit(address,address,uint256,uint256,bool)` (non-payable, fifth argument `depositFromInternalBalance`), installed on `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol`.
2. **Pendle selectors removed from the legacy V4 IN facet** (currently four, dropping to three once `deposit` is re-added):
   - `IStandardizedYield.deposit(address,address,uint256,uint256)` payable — replaced by the ERC-5115 5-arg form. No alias retained.
   - `IStandardizedYield.rewardIndexesCurrent()`
   - `IStandardizedYield.claimRewards(address)`
3. **Pendle selectors removed from the legacy V4 OutMultiQueryFacet** (currently twelve in the SY view folder, dropping to six once the ERC-5115 view set is installed):
   - `IStandardizedYield.assetInfo()`
   - `IStandardizedYield.isValidTokenIn(address)`
   - `IStandardizedYield.isValidTokenOut(address)`
   - `IStandardizedYield.getRewardTokens()`
   - `IStandardizedYield.accruedRewards(address)`
   - `IStandardizedYield.rewardIndexesStored()`
4. **Selectors retained with unchanged signatures** (seven, identical byte-identical selectors):
   - `redeem(address,uint256,address,uint256,bool)` (same selector as Pendle's)
   - `exchangeRate()`
   - `getTokensIn()`
   - `getTokensOut()`
   - `yieldToken()`
   - `previewDeposit(address,uint256)`
   - `previewRedeem(address,uint256)`
5. **Package-level interface swap:** `UniswapV4StandardExchangeDFPkg.sol` `facetInterfaces()` index 13 changes from `type(IStandardizedYield).interfaceId` to `type(IERC5115_StandardizedYield).interfaceId`. The 15-entry shape of `facetInterfaces()` and the 16-entry shape of `facetCuts()`/`facetAddresses()` are unchanged.
6. **`UniswapV4StandardExchangeOutMultiQueryTarget.sol` drops `assetInfo()` and the `IStandardizedYield.AssetType` enum.** The `yieldToken()` body keeps returning `address(0)`; `exchangeRate()` math and `getTokensIn/Out()` arrays keep their current pool-relative content.
7. **The legacy V4 yield execution target stops inheriting `NativeStandardYieldExecutionTarget`.** All four reviewers agree the new `deposit` lives against `IERC5115_StandardizedYield` directly; the old 4-arg payable `deposit` cannot remain on the proxy.
8. **`NativeStandardYieldSelectors._appendExecution` and `_appendQuery` are not called by the legacy V4 facets after this change.** All four reviewers agree the appenders themselves are not edited (other families depend on them).
9. **Other families keep Pendle.** All four reviewers agree the shared `contracts/vaults/standard/sy/*` files, every `StandardYieldFacet.sol` outside the legacy V4 family, every other family's `*StandardExchangeDFPkg.sol` interface declaration, and every other Pendle-targeted test stay as-is.
10. **Size is measured after the change; no facet split is decided here.** All four reviewers agree the implementer is not given discretion to split facets or restore an execution delegate in this item.
11. **`ERC20Facet`, `ERC5267Facet`, `ERC2612Facet`, the multi-asset vault facets, the position-import facet, the liquid-reserve facet, and the callback facet are not touched.** All four reviewers agree these facets carry no SY surface and remain byte-identical.
12. **ERC-5115 events `Deposit(caller, receiver, tokenIn, amountDeposited, amountSyOut)` and `Redeem(caller, receiver, tokenOut, amountSyToRedeem, amountTokenOut)` are byte-identical to Pendle's.** All four reviewers agree the emit sites keep their arguments and re-type to `IERC5115_StandardizedYield`; the `ClaimRewards` event is gone with its function.
13. **`name`/`symbol`/`decimals`/`totalSupply`/`balanceOf`/`allowance`/`approve`/`transfer`/`transferFrom`/`permit`/`EIP-712` selectors stay on the existing shared facets.** All four reviewers agree these are not part of the interface switch.

There is no cross-reviewer dissent on items 1–13.

---

## 2. Specific disagreements and the sentence the PRD must use

### 2.1 EOA / bytecode gate on the deposit path when `depositFromInternalBalance == true` — UNRESOLVED

**Where the disagreement lives.**

- **Astra (original §5, bullet 2):** "Authenticate the external starter through `LocalCreditLib.requirePretransferCaller` before credit-sensitive work." Then explicitly: "The current token credit helper (`V4/internal/UniswapV4StandardExchangeCustody.sol:23-41`) does not itself contain the starter-bytecode gate. The new ERC-5115 true-flag entry must explicitly enforce that gate."
- **Kimi (original §4):** "when `true`, the deposit follows the vault's existing pretransfer rule for the same economic route ... `LocalCreditLib.requirePretransferCaller(msg.sender)` first (a code-less caller reverts `EOAPretransferNotAllowed`)."
- **Grok (original, "Behavior the implementer does not choose"):** "`depositFromInternalBalance == false` uses the current pull path. `true` uses the existing true-flag pretransfer credit path. Do not add a credit rule." Grok is silent on the EOA gate but is consistent with the existing custody layer not adding one.
- **MiniMax M3 first pass (§5, rule 3):** "The code-less caller check (`requirePretransferCaller(msg.sender)` from `LocalCreditLib`) is **not** applied to the `deposit` path because the deposit's `tokenIn` is a pool currency, not vault-held shares. (The redeem path keeps the existing EOA gate from `NativeStandardYieldMoneyTarget.redeem`/`NativeStandardYieldExecutionTarget.redeem`, which is unchanged.)"

**What the actual code does today.**

`UniswapV4StandardExchangeCustody._secureTokenTransfer(tokenIn, amountIn, pretransferred)` (`contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangeCustody.sol:23-42`) on the `pretransferred == true` branch:

```solidity
uint256 deployed = _deployedFaceOf(address(tokenIn));
uint256 faceBooked = R > deployed ? R - deployed : 0;
uint256 U = B0 > faceBooked ? B0 - faceBooked : 0;
if (amountIn > U) {
    revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, U);
}
return amountIn;
```

No `LocalCreditLib.requirePretransferCaller(msg.sender)` call. By contrast, `_secureShareDelivery` at line 72 of the same file does call `LocalCreditLib.requirePretransferCaller(msg.sender)` on its pretransfer branch. The asymmetry is by design: vault-held *shares* are a privileged resource (an EOA could otherwise time-arbitrage the book's residual liquidity), while *tokens* are fungible ERC-20 balance that anyone can already top up directly.

**My view (changes from the first pass).**

The owner ruling is an interface replacement, not a behavior change. ERC-5115 introduces `depositFromInternalBalance` but does not require an EOA gate on the deposit's token-side credit path. The existing SE pretransfer convention accepts EOAs on `IStandardExchangeIn.exchangeIn(..., pretransferred=true, ...)`, and the ERC-5115 deposit's economic route is the same SE pretransfer credit path. Adding the EOA gate would tighten a previously-accepted caller surface on the *token* path, which is a separate decision the owner has not made.

Astra's note itself flags this: "The current token credit helper ... does not itself contain the starter-bytecode gate. The new ERC-5115 true-flag entry must explicitly enforce that gate." The word "must" is the implementer instruction Astra is providing. Without an owner ruling that authorizes the tightening, the PRD should not introduce it.

Kimi's wording in §4 is internally inconsistent: it claims "the vault's existing pretransfer rule for the same economic route" but cites `requirePretransferCaller` as the first step, while the existing token-route pretransfer rule does not contain that gate. Kimi appears to have conflated the share-delivery rule (which has the gate) with the token-transfer rule (which does not).

**Sentence the PRD must use** (closes the disagreement so the implementer does not choose):

> When `depositFromInternalBalance == true`, the legacy V4 deposit MUST forward the boolean as `pretransferred == true` to the existing `Custody._secureTokenTransfer` path and MUST NOT add `LocalCreditLib.requirePretransferCaller(msg.sender)` to the token-credit branch. The existing `_secureTokenTransfer` pretransfer behavior (unbooked-surplus `U` credit, `TransferDeltaInsufficient` on shortfall, no refund) is preserved exactly. The redeem path's existing `requirePretransferCaller` on `burnFromInternalBalance == true` is unchanged. Any change to the EOA-gate policy on the token-credit branch is out of scope for this interface replacement and requires a separate owner ruling.

### 2.2 `UniswapV4StandardExchangeOutMultiQueryFacet.facetInterfaces()` second slot — UNRESOLVED

**Where the disagreement lives.**

- **Astra (original §3, "OutMultiQueryFacet"):** "In OutMultiQueryFacet `:17-20`, replace the Pendle declaration with the ERC-5115 interface ID while retaining the existing multi-output interface declaration."
- **Kimi (original §3, item 4):** "`facetInterfaces` swaps `type(IStandardizedYield).interfaceId` (`:20`) for `type(IERC5115_StandardizedYield).interfaceId`." — actually says swap, which matches Astra. But Kimi's §2 "Added or signature-changed" table says "advertised at `OutMultiQueryFacet.sol:20` and `DFPkg.sol:162` in place of `type(IStandardizedYield).interfaceId`" — also swap.
- **Grok (original "Remove from the legacy V4 package"):** "Also remove `type(IStandardizedYield).interfaceId` from `UniswapV4StandardExchangeDFPkg.sol:162` and from `UniswapV4StandardExchangeOutMultiQueryFacet.sol:20`." — drop it.
- **MiniMax M3 first pass (§3.2 and §4.2):** drop the second slot; the query facet's `facetInterfaces()` becomes a single-entry array `[type(IStandardExchangeOutMulti).interfaceId]`. Argument: the query facet only implements 6 of the 8 ERC-5115 selectors and does not strictly satisfy `supportsInterface(IERC5115_StandardizedYield.interfaceId)`.

**What the actual IFacet test expects.**

`TestBase_IFacet.areValid_IFacet_facetInterfaces` validates that the facet's `facetInterfaces()` matches the test's `controlFacetInterfaces()`. There is no semantic check on `supportsInterface(...)` in the IFacet test — only a structural check. So the implementer is free to declare either way and the test will pass either way, as long as the test's `controlFacetInterfaces()` mirrors the implementer's choice.

The package-level `facetInterfaces()` in `UniswapV4StandardExchangeDFPkg.sol` is what the proxy advertises; the per-facet `facetInterfaces()` is the facet's local declaration. Today the IN facet declares only `IStandardExchangeIn` even though it provides the `deposit`/`redeem` money selectors; the package level declares `IStandardizedYield`. The query facet declares both `IStandardExchangeOutMulti` and `IStandardizedYield` even though it doesn't provide the money selectors.

This is a "facet-local interface declaration" convention question, not a semantic one. Both options preserve ERC-165 correctness on the proxy (the proxy advertises the full `IERC5115_StandardizedYield` via the package-level list either way).

**My view.**

I agree with Grok and my first pass that the second slot in the query facet's local `facetInterfaces()` should be dropped. Rationale: the query facet implements only 6 of the 8 ERC-5115 selectors and does not satisfy `supportsInterface(IERC5115_StandardizedYield.interfaceId)` strictly. Astra and Kimi propose keeping the local declaration for parallelism with the existing Pendle declaration; the existing declaration is itself non-strict (the facet doesn't implement the ERC-20 metadata surface either), so the precedent is mixed.

**Sentence the PRD must use** (closes the disagreement):

> `UniswapV4StandardExchangeOutMultiQueryFacet.facetInterfaces()` becomes a single-entry array `[type(IStandardExchangeOutMulti).interfaceId]`. The ERC-5115 interface is declared once at the package level via `UniswapV4StandardExchangeDFPkg.facetInterfaces()` index 13, where the composite proxy answers all eight ERC-5115 selectors via the IN and query facets together. The query facet's local declaration mirrors the convention used by `UniswapV4StandardExchangeInFacet` (which declares only `IStandardExchangeIn` even though it provides money selectors).

### 2.3 Whether `redeem`'s body is unchanged — CONSENSUS, no dissent

All four reviewers agree `redeem(address,uint256,address,uint256,bool)` keeps the same body — receiver/amount validation, token-out validity, internal-balance branch with `LocalCreditLib.requirePretransferCaller` on `burnFromInternalBalance == true`, `_redeemVaultHeld` for vault-held share burn, `_standardRoute` fallback for ordinary redemption, `SYMinimumNotMet` on shortfall, and the existing `Config._requireNotDisabled()` guard before any state-affecting call (REQ-V4-02). The `internalBalance_` parameter name in the V4 source can be renamed to `burnFromInternalBalance_` to match the ERC-5115 declaration; the selector is unchanged.

This is recorded here to confirm cross-reviewer consensus, not as a dissent.

### 2.4 Whether `yieldToken()` keeps its `address(0)` return — CONSENSUS

All four reviewers agree `yieldToken()` continues to return `address(0)` in the legacy V4 family. The legacy V4 vault does not have an underlying-yield-token model; the LIQUIDITY/PoolManager fact previously surfaced via `assetInfo()` is no longer surfaced via the SY interface (it remains available via the existing liquid-reserve and TWAP-oracle selectors). No dissent.

### 2.5 Whether `exchangeRate()` and the two `getTokens*()` arrays are unchanged — CONSENSUS

All four reviewers agree `exchangeRate()`, `getTokensIn()`, `getTokensOut()`, `previewDeposit()`, and `previewRedeem()` keep their current bodies and selectors on the legacy V4 query facet. The internal `_previewExchangeIn` path is preserved. No dissent.

### 2.6 Other families — CONSENSUS

All four reviewers agree every file under `contracts/vaults/standard/sy/*`, every other family's `StandardYieldFacet.sol` / `StandardYieldTarget.sol` / `*StandardExchangeDFPkg.sol`, the Pendle `IStandardizedYield.sol` vendored under `lib/crane`, and the corresponding test suites remain unchanged. This includes:

- V3 FullSpread (`UniswapV3FullSpread*`)
- V4 hookless (`UniswapV4FullSpreadHookless*`)
- V4 Pons (`UniswapV4FullSpreadPonsFamily*`)
- V4 hooks (`UniswapV4*BufferHook*`)
- V4 Wings (`UniswapV4UpperLowerWings*`)
- ConstantProduct (UniV2, Camelot V2, Aerodrome)
- Staking (Lido wstETH, Rocket rETH, EtherFi weETH)
- Lending (Aave v3.6 Stata, Morpho Blue)
- Rebasing (`RebasingAwareERC4626*`)
- ERC-4626 (`ERC4626Standard*`)
- Balancer V3 pools

None of these is touched. The local Pendle search would find ~75 production files and ~70 test files using `IStandardizedYield`; none of those 145 files changes in this PRD. No dissent.

### 2.7 Size — CONSENSUS

All four reviewers agree the implementer does not decide a facet split in this item. Sizes are measured after the change and reported; if any facet remains above the 24,576-byte hard limit, the implementer stops and reports. No exploit, no restriction-by-deed, no `via_ir`, no execution delegate, no self-call. No dissent.

### 2.8 No-emit ClaimRewards — CONSENSUS

All four reviewers agree the `ClaimRewards` event emission (currently in `NativeStandardYieldRewardsTarget.claimRewards` at `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:79-82`) is removed from the legacy V4 surface because the function that emitted it is removed. The shared `NativeStandardYieldRewardsTarget` continues to emit `ClaimRewards` for other families. No dissent.

---

## 3. Cross-reviewer's corrections to my own first pass

Reading the three peers against my own first pass, I have to record these corrections so the implementer is not confused by the history.

### 3.1 The query facet's second interface slot — I should soften, not reverse

In §3.2 / §4.2 of my first pass I asserted the query facet's `facetInterfaces()` drops the second slot because the facet only implements 6 of 8 ERC-5115 selectors. The IFacet test is structural, not semantic, so the assertion is correct under a strict reading of ERC-165 but not the only correct answer. The package-level declaration is what the proxy answers. Both Astra/Kimi's "keep `type(IERC5115_StandardizedYield).interfaceId`" and my "drop the slot" are valid; the PRD must pick one to close the choice. The sentence in §2.2 of this cross-review does so.

### 3.2 The EOA gate on deposit — I held my first-pass position against Astra and Kimi

I do not retract. The current `_secureTokenTransfer` does not gate EOA callers on the pretransfer branch, and the owner ruling is an interface replacement, not a behavior tightening. Astra's note explicitly admits this introduces a new behavior ("The new ERC-5115 true-flag entry must explicitly enforce that gate"). The PRD must not introduce the gate without a separate owner ruling. The sentence in §2.1 of this cross-review does so.

### 3.3 The IFacet test's `controlFacetInterfaces()` is the truth source

I should have noted in my first pass that the implementer writes the test's `controlFacetInterfaces()` along with the facet's `facetInterfaces()`. The two must agree; the structural IFacet test enforces it. Astra, Grok, and Kimi all implicitly assumed this. My §2.2 sentence keeps the convention.

### 3.4 The shared `NativeStandardYieldMoneyTarget.redeem` 5-arg signature

I noted in my first pass that the redeem signature is unchanged between Pendle and ERC-5115. Grok and Kimi make the same observation. Astra notes the same. This is a load-bearing fact — it is the reason the V4 can keep most of its existing redeem body unchanged. I am restating it here so the implementer does not waste time re-checking.

### 3.5 The implementer must remove `_appendExecution` and `_appendQuery` calls — not just edit them

My first pass said the implementer "replaces" the calls. Grok's note ("Do not edit `NativeStandardYieldSelectors.sol`. The two legacy V4 facets list their own selectors.") is sharper: the implementer removes the calls and inlines the selector arrays. I am correcting my wording to match Grok's: the legacy V4 facets list their own selectors inline; the shared appenders are not edited. This is a clarification, not a dissent.

### 3.6 The test file `decimals/UniswapV4StandardExchange_FullRangeBook_Decimals.sol` line 9

I noted in my first pass that the import is at line 9 and a cast is at line 234. Kimi's review does not explicitly call out this test. I am not retracting the §6 entry but flagging that the three peer reviews do not all enumerate every legacy V4 test file. The test-update set is the union of: `UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol`, `UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol`, `UniswapV4StandardExchange_Architecture.t.sol`, `UniswapV4StandardExchangeVaultHeldRedeem.t.sol`, `UniswapV4StandardExchange_FullRangeBook.t.sol`, and `UniswapV4StandardExchange_FullRangeBook_Decimals.sol`. The first five are mentioned by all three peers; the sixth I called out independently and is consistent with the same mechanical rule.

### 3.7 No dissent on the DFPkg swap target

All three peers and my first pass agree: `interfaces[13]` is the swap target. The slot count stays at 15. No correction.

---

## 4. Unresolved dissent

After the corrections in §3, two items remain unresolved against the peer originals:

1. **EOA gate on deposit when `depositFromInternalBalance == true`** (§2.1) — Astra and Kimi say apply; my position (and the existing code) says don't. The sentence in §2.1 closes this in favor of "don't."
2. **`OutMultiQueryFacet.facetInterfaces()` second slot** (§2.2) — Astra and Kimi say swap; Grok and my position say drop. The sentence in §2.2 closes this in favor of "drop."

If the coordinator prefers Astra's or Kimi's position on either item, the PRD can substitute the corresponding sentence; the rest of the surface remains unchanged.

---

## 5. Position on the three questions the cross-review is asked to address

The coordinator asked me to agree or dissent on:

1. **The selector changes.** I agree with the implementer's surface diff (nine Pendle selectors removed, one new ERC-5115 `deposit` selector added, seven selectors unchanged). My first pass and the three peer originals agree. No dissent on items 1–13 of §1.
2. **The `depositFromInternalBalance` mapping.** I agree with the high-level mapping structure (`false` = pull from caller; `true` = consume pre-transferred balance with no refund, `TransferDeltaInsufficient` on shortfall, no synthetic-transfer-and-pull flow). I disagree with Astra and Kimi on whether the EOA gate applies on the `true` branch; I hold that the existing custody convention does not gate the token-credit branch and the owner ruling is an interface replacement, not a behavior change. The sentence in §2.1 closes this.
3. **Whether other families stay on Pendle.** I agree with all three peers that other families stay on Pendle. No dissent.

---

## 6. Original findings retained

For traceability, my first-pass findings are preserved at `docs/reviews/legacy-v4-erc5115-interface/reviewers/minimax-original.md`. The corrections in §3 of this cross-review are not retroactive edits — they are clarifications about which reviewer position the PRD must adopt where two outstanding choices existed. The findings labeled F1–F6 in the first pass stand.

---

## 7. Summary

- **Consensus:** selector diff (9 removed, 1 added, 7 retained), package interface swap, shared-files-not-redesigned rule, redeem body unchanged, no facet split decided here. All three peers and my first pass agree.
- **Unresolved dissent (closed by PRD sentences in §2):** EOA gate on deposit (§2.1 — closed in favor of "do not add"); query-facet second interface slot (§2.2 — closed in favor of "drop").
- **Position on the coordinator's three questions:** agree on selector changes; agree on the pretransfer mapping structure with one divergence on the EOA gate (closed by §2.1); agree that other families stay on Pendle.

I did not run Forge.