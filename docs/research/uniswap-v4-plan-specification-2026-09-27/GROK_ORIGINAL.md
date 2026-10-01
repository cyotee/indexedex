# Grok — FullSpread zap-in plan specification

**Date:** 2026-09-27. **Author:** Grok (xai/grok-4.7). Independent specification. No peer artifacts. No tests, shell, or edits. **Law:** `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` D1–D26. This document specifies the plan. It does not authorize implementation or deletion.

**Derivation confidence** is marked per formula. Future tests must still validate. Nothing here is a proof of security or economic soundness. `LiquidityAmounts` is not treated as a combined closed form. `UniswapV4FullSpreadClosedFormCandidate.sol` is not adopted and is not repaired here.

**Pons evidence rule for this specification:** official Pons documentation plus graduated pools that use `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK` are accepted as sufficient to bind that constant. No additional runtime-bytecode equivalence gate is required. This does **not** claim the deployed runtime was proven equal to the local port.

## 0. Phased handoff

| Phase | Work | Stop |
|---|---|---|
| A | Build both family trees and the route matrix below. Do not delete legacy trees. | Families compile and the parity tests in §5 pass on registry-deployed proxies. |
| B | Record audit-submission readiness: revision, commands, and checklist against PRD acceptance 1–28. | Human sign-off that the record is complete. Not an audit. |
| C | Execute the §6 removal manifest. Rebuild artifacts. Rerun replacement and consumer suites. | No active import of a deleted vault type. |
| D | Mark the §7 PRDs deprecated in the same revision as the deletion. Do not rewrite them into current law. | Historical citations name the pre-removal git revision. |

## 1. Route and formula matrix

Selectors are the Solidity signatures already on the unsegmented vault. Do not invent new money selectors. `InvalidRoute` is `IStandardExchangeErrors.InvalidRoute` if that error exists on the shared interface; otherwise the family common error `InvalidRoute(bytes32)` with the reason constants below. Preview and execution use the same cell.

Reasons: `NO_CLOSED_FORM`, `TICK_DOMAIN`, `BLOCKED_COVER`, `HOOK_MISMATCH`.

Fee domain for a **pool** leg is Uniswap v4 pips (`1_000_000`), not `ConstProdUtils` PPHK (`FEE_DENOMINATOR` 100000, `ConstProdUtils.sol` 149–191). `ConstProdUtils._purchaseQuote` (`235–256`, `+ 1` rounding) is a V2-book inverse. It is **not** the PoolManager swap formula. Do not use it for idle pool swaps.

### 1.1 Equations that are adopted

**E1 — sleeve target.** `targetFree = floor(T * p / (1e18 + p))` with live oracle `p`. Deadband `tol = max(absoluteFloor, floor(targetFree * 5 / 100))`. Absolute floor remains `1` if decimals ≤ 6, else `10^(decimals-6)`. Confidence: high. This replaces `Common.sol` 358–360.

**E2 — dual mint.** For `S > 0` and `B0, B1 > 0`: `sharesOut = min(floor(S * C0 / B0), floor(S * C1 / B1))`. Confidence: high. Already `StandardExchangeConstantProduct.sol` 52–56.

**E3 — alignment.** For each leg with `S, C_i, B_i > 0`, pass iff `sharesOut * B_i * 10000 >= S * C_i * 9999` by `mulDiv`. Equivalent to the PRD epsilon `<= 0.0001` including flooring. If any required denominator is zero, the deposit reverts `AlignmentExceeded`. No dust waiver. Confidence: high as a comparison; medium that every tiny deposit the product wants will pass. The PRD already forbids a dust exception.

**E4 — price impact.** On `sqrtPriceX96`, pass iff `max(sa,sb)^2 * 1e18 <= min(sa,sb)^2 * (1e18 + limitWad)` by `mulDiv`. Limits: repair `0.0025e18`, caller pool swap `0.005e18`. This is price, not sqrt-price. Overflow fails the cap. Confidence: high.

**E5 — blocked share-to-token forward.** `_singleExit` (`StandardExchangeConstantProduct.sol` 98–111): `out = floor(X*s/S) + floor((X - floor(X*s/S)) * floor(Y*s/S) / Y)`. Confidence: high.

**E6 — inverse of E5, not the bisection.** Real identity of E5 is `out/X = 2f - f^2` with `f = s/S`, so `f = 1 - sqrt(1 - out/X)`. Integer rule: if `reserveOther == 0`, `shares = ceil(amountOut * supply / reserveOut)`. Else `shares = ceil(supply * (1 - sqrt_up(1 - amountOut/reserveOut)))`. Evaluate E5 at `shares` and, if short, at `shares+1` only. If neither delivers `amountOut` with `shares < supply`, `InvalidRoute(NO_CLOSED_FORM)`. Do not call `_sharesForSingleExit` (113–128). Confidence: high that this inverts the published forward in reals; medium on the two-check covering every integer residue. Tests must compare against E5, not against the bisection.

**E7 — single-tick pool exact-out.** `sqrtNext = SqrtPriceMath.getNextSqrtPriceFromOutput(sqrtP, L_active, amountOut, zeroForOne)` (`SqrtPriceMath.sol` 156–175). Gross input is the rounded-up `getAmount*Delta` between the two prices, then `ceil(net * 1e6 / (1e6 - swapFee))` where `swapFee = calculateSwapFee(directionalProtocolFee, lpFee)` (`ProtocolFeeLibrary.sol` 35–45, `Pool.sol` 291–312). Domain: `sqrtNext` does not cross the next initialized tick; `swapFee < 1e6`; `L_active > 0`. Otherwise `InvalidRoute(TICK_DOMAIN)` or core `InvalidFeeForExactOut`. This is the operation-only inverse. It does **not** include rebalance. Confidence: high inside one tick with no hook delta; not claimed across ticks.

**E8 — Pons unspecified-leg charge, operation-only.** After the pool quote, `charge = floor(amount * hookFeeBps / 10000) + floor(amount * creatorTaxBps / 10000)` from `launches(poolId)` words 10 and 7 (`PonsV2MemeHook.sol` 503–504; `QuoteService.sol` 35–41). Exact-in subtracts from output; exact-out adds to input. Do not add the global `hookFeeBps` setter. Confidence: high as a match to the current hook source; not a claim that deployed bytecode was compared.

**E9 — no combined closed form.** No helper in `lib/crane/contracts/utils/math/` or the unsegmented v4 vault composes an exact-output leg with a holder repair swap and sleeve placement into one quotation. `LiquidityAmounts.getLiquidityForAmounts` is placement at a known price only. `ConstProdUtils._quoteZapInToTargetLPWithFee` and `_quoteZapOutToTargetWithFee` search. `UniswapV4ZapQuoter` searches. Therefore **no route interleaves holder repair inside an exact-output quotation.** Public `rebalanceLiquidReserve` remains the later repair path (D9–D12, D21).

### 1.2 Matrix

Both families use the same support cells. Fee models differ: hookless uses E7’s `swapFee` only; Pons applies E8 after E7 on the unspecified leg. A hook mismatch reverts `HOOK_MISMATCH` before either formula.

| ID | Signature | State | Support | Formula | Interleave |
|---|---|---|---|---|---|
| R1 | `exchangeIn(token0, amount, token1, minOut, …)` and the reverse | Idle | Execute pool exact-in. Quote is `UniswapV4Quoter.quoteExactInput` plus E8 on Pons. | Evaluation, not an inverse. 50 bp from leg start. 10 bp vs that quote. | No. Combined form absent. Exact-in remains, so D19 does not apply. |
| R2 | same | Blocked | `InvalidRoute` / existing `PoolManagerInteractionBlocked`. Sleeve cannot convert the other token. | None. | No. |
| R3 | `exchangeOut(token0, maxIn, token1, amountOut, …)` and the reverse | Idle | Supported only in the E7 domain. Pull `grossIn`, refund unused pretransfer only. | E7, then E8 on Pons. | No. |
| R4 | same | Blocked | `InvalidRoute`. | None. | No. Exact-in of this pair is also blocked (R2), but the route is a pool swap, not a sleeve route. Do not invent a book swap. |
| R5 | `exchangeIn(token, amount, shares, minShares, …)` | Idle | Caller-funded composition then E2 mint then algebraic placement. Bounded solver, 4 Newton steps, single-tick clamp. Fail `AlignmentExceeded` if E3 fails. | E2, E3, E4. Not `_amountInForShares`. | Placement only, after mint measurement. Not a holder repair swap inside the quote. |
| R6 | same | Blocked | Preserve invariant-growth mint. No unlock. | Existing `_sharesForDeposit` one-sided branch. | No. |
| R7 | `exchangeOut(token, maxIn, shares, sharesOut, …)` | Idle | `InvalidRoute(NO_CLOSED_FORM)`. | No existing inverse of composition-plus-E2. | No. Exact-in R5 remains, so D19 does not apply. |
| R8 | same | Blocked | Supported. `amountIn = _amountInForShares` on post-credit book (`StandardExchangeConstantProduct.sol` 78–96). Mint exactly `sharesOut`. | That helper. Ceil on the invariant branch. | No. Cannot unlock. |
| R9 | `exchangeIn(shares, sharesIn, token, minOut, …)` | Idle | Burn, remove that share of liquidity, swap the other entitlement with E7 exact-in, pay token. | Proportional burn plus E7. | No holder repair swap. Required removal is not optional maintenance. |
| R10 | same | Blocked | Pay E5 if local `token` covers; else `InsufficientLocalReserve`. | E5. | No. |
| R11 | `exchangeOut(shares, maxShares, token, amountOut, …)` | Idle | Supported by E6 against the post-removal book only if the conversion swap stays in the E7 domain. Otherwise `InvalidRoute(TICK_DOMAIN)`. | E6 then E7. | No. |
| R12 | same | Blocked | Supported by E6 against the complete book. Pay only if local cover. | E6. | No. |
| R13 | `exchangeInManyToOne(token0, token1, amounts, shares, …)` | Idle and blocked | Preserve dual `min()` mint. No composition swap. Idle path may place excess with `getLiquidityForAmounts` after mint. | E2. | Placement only. Not D19. |
| R14 | `exchangeOutOneToMany(shares, max, [token0, token1], amounts, …)` | Both | Supported iff `ceil(amount0*S/T0) == ceil(amount1*S/T1)`. Else existing `ExchangeOutNotAvailable`. | Proportional burn. | No. Idle still removes liquidity (required settlement), then one placement. No repair swap. |
| R15 | `rebalanceLiquidReserve()` | Idle | One holder step, §2.3. No shares. | E1, E4 at 25 bp. | This is the repair, not an exact-output route. |
| R16 | same | Blocked | Revert `PoolManagerInteractionBlocked`. | None. | No. |
| R17 | `importPosition` | Idle | Unchanged full-range conversion. Hook must already match the package. | Existing import. | No zap. |
| R18 | activation | Idle | Both tokens required. Single-token returns 0 shares. | `mulSqrt` minus minimum liquidity. | No. |

D19 is not used on any row. In every token direction above, exact-in remains available in at least one interaction state without a combined formula, or the direction is not a sleeve-fundable pair (R2/R4). Forgoing interleaving is the ordinary D18 result, not the exception. Document that in quotes so it is not a silent fallback.

`previewExchangeIn` / `previewExchangeOut` return the same amounts as the matching execution cell or revert the same `InvalidRoute`. Transition quotes (`quoteExternalDeposit`, `quoteTransition`) must call the same cell. A zero return is not a substitute for `InvalidRoute`.

## 2. Accounting and progress

Sequence on every idle money path:

1. Credit before fee collection. Pull credit is the balance delta and must equal the request. Pretransfer credit is the declared amount iff `declared <= balanceOf - reserveOfToken` and `LocalCreditLib.requirePretransferCaller` passes (`Common.sol` 1219–1240).
2. If idle, collect fees once. `E → F` is incumbent. Do not collect again between a caller swap and the mint.
3. Incumbent `B = D + F + E` after removing unspent caller credit from `F`. `D` is position math. `E` is uncollected fee growth. `F` is raw `balanceOf`.
4. Caller swap spends only that credit. `C` is unspent input plus taken output. Position repricing and fee growth earned on `L_v` stay in `B`.
5. Mint with E2/E3 using those `C` and `B`, including sleeve residuals. Then place. Placement does not change the measured `C` and `B`.
6. Sync `balanceOf` for token0, token1, and the self-share (`Common.sol` 610–616). Keep the self-share booking.

Pons: E8 is a hook charge, not vault LP fee. Do not credit it to `E`. Hookless: no `launches` call.

**Repair step (R15), one call:**

1. Probe `(a0, a1) = LiquidityAmounts.getAmountsForLiquidity` at the current price and position ticks, liquidity `1e6`.
2. Proportional iff `abs(T0*a1 - T1*a0) * 1e18 <= 1e14 * max(T0*a1, T1*a0)`. Sleeve holds iff each token is within E1’s deadband. Both true: sync and return. No trade.
3. If placement alone can put both tokens inside the deadband without pushing the other out, do that and do not swap.
4. Else one holder swap of free inventory only, capped by E4 at 25 bp and by the next initialized tick. Then one placement. Progress is measured after the swap fee, own-position fee growth, and placement. The post-step proportionality error or a sleeve deviation must be strictly smaller, and the other token must not newly exit its deadband. Otherwise skip the swap.
5. Do not loop. The next call may be immediate.

Confidence: high on the sequence and the 1 bp / 5% thresholds. Medium on the single-tick repair cap leaving some books for a later call. That is the approved incremental policy, not a missing formula.

## 3. Family components and reuse

Directories, created in phase A:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/`

Each family gets its own: DFPkg, interface, FactoryService, Common, In/Out targets, bases, facets, query targets, multi targets, execution delegates, liquid-reserve target/facet, position import, pool-key repo, position repo, and quote service. Prefixes are `UniswapV4FullSpreadHooklessStandardExchangeVault` and `UniswapV4FullSpreadPonsFamilyHook`. Interfaces take the `I` prefix.

Hookless `processArgs` requires `hooks == address(0)` and `!LPFeeLibrary.isDynamicFee(fee)`. Pons requires `hooks == ROBINHOOD_MAIN.PONS_V2_MEME_HOOK`, `hook.poolManager() == ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER`, registered `launches`, and `poolKey.fee == 0` because `PonsV2LaunchFactory.sol` 1497 reverts otherwise. No setter. No shared quote or execution contract.

**Permitted import from hookless into Pons:** a pure math file in the hookless tree that contains only E1–E7 and the repair comparisons, with no hook address and no `launches` call. Pons quote service imports that file and then applies E8. Generic reuse, not a family dispatcher: `StandardExchangeConstantProduct.sol`, `ConstProdUtils.sol` only for blocked book math if a test compares it, `SqrtPriceMath`, `LiquidityAmounts`, `ProtocolFeeLibrary`, `LPFeeLibrary`, `LocalCreditLib`, ERC20 and MultiAsset vault facets, Permit2, fee-oracle query facet, and the diamond factory. Those crane and vault-view facets keep their existing CREATE3 salts.

**Not reused across families:** In/Out facets, query facets, execution delegates, quote services, and `unlockCallback`. `InTarget.sol` 32–35 bakes a delegate address; each family deploys its own delegate and facet under its own type-name salt. Do not point both packages at the current `UniswapV4FullSpreadStandardExchangeVaultInFacet` salt.

Package salts are `keccak256(abi.encode("<new contract name>"))`. Do not reuse `UniswapV4FullSpreadStandardExchangeVaultDFPkg`. Instance salt remains `keccak256(abi.encode(pkg, calcSalt(args)))` as implemented in `DiamondPackageCallBackFactory.sol` 201–206. Two packages may each deploy the same PoolKey. No extra uniqueness rule.

## 4. Pons binding

Use `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK` (`ROBINHOOD_MAIN.sol` 441, `0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044`) and `UNISWAP_V4_POOL_MANAGER` (line 169). Official documentation and graduated pools that use that hook are the accepted identity evidence. Do not add a runtime-bytecode gate. Do not write that equivalence was proven.

Quote and execution still read `launches(poolId)` for the snapshotted bps. A historical pool whose hook is not this constant is rejected. That is admission, not a bytecode proof.

## 5. Acceptance and parity tests

Production registry path. Real fee oracle and PoolManager. No mock vault.

For every supported cell, `previewExchangeIn` or `previewExchangeOut` equals execution at the same state, or both revert the same error before funding. In-kind pairs that are both supported must round-trip inside the stated rounding: R3 input is the smallest gross-in whose E7 output is at least the request; R1 with that input returns at least that output inside one tick. R12’s E6 shares, passed through R10, return at least `amountOut`. R8’s blocked mint, passed through a blocked exit, does not increase incumbent value beyond E5 rounding. Idle R7 stays `InvalidRoute` on both preview and execution.

Same operation through `quoteExternalDeposit` / `quoteTransition` must match the direct preview. Buffer-leg callers must treat `InvalidRoute` as unavailable, not as zero shares.

Impostor tests: hookless rejects the Pons address; Pons rejects `address(0)`, a same-flag impostor, and any other address. D20 checks use E4, not a sqrt-price percentage. R15 does not trade when both thresholds hold. Combined exact-output-plus-repair is not a supported cell; a test that expects it must expect `InvalidRoute` or the non-interleaved cell, not a solver.

## 6. Removal manifest

Delete only after phase B. Never delete the two new subtrees. Never delete `lib/crane/contracts/protocols/dexes/uniswap/v4/` (protocol port). Never delete `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol`.

**Delete `contracts/protocols/dexes/uniswap/v4/` vault implementation after rehoming imports:** all 49 inventoried entries, including `UniswapV4StandardExchange*.sol`, `UniswapV4QuoteService.sol`, `UniswapV4Pool*Repo.sol`, `UniswapV4PositionRepo.sol`, `IUniswapV4StandardExchangeDFPkg.sol`, `UniswapV4_Component_FactoryService.sol`, `interfaces/IUniswapV4StandardExchangeLiquidReserve.sol`, and `test/bases/TestBase_UniswapV4StandardExchange*.sol`. Rehome any non-vault helper that a non-vault consumer still imports before deletion. The PRDs in that directory are disposed in §7, not kept as law.

**Delete the unsegmented tree `contracts/vaults/standard/exchange/protocols/uniswap/v4/` except the two retained subtrees:** all current `UniswapV4FullSpreadStandardExchangeVault*` files, `IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol`, `UniswapV4FullSpreadClosedFormCandidate.sol`, and `test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol`. The candidate is deleted because it is not adopted, not because it failed a build. `.DS_Store` is junk.

**Preserve:** `v4/fullSpread/hookless/**` and `v4/fullSpread/ponsFamilyV2Hook/**`.

After deletion, rebuild and rerun the new family suites plus consumers that were rehomed. Cite the pre-removal git revision in the commit message. Do not claim live instances were upgraded.

## 7. Old PRD disposition

Do not reconcile these into current law. At phase D, add a one-line deprecated banner pointing at this PRD and the pre-removal revision, then remove them with the code they describe.

| File | Disposition |
|---|---|
| `contracts/protocols/dexes/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md` | Deprecated. Percent-of-total sleeve and no-swap rebalance lose to D3 and D9. |
| `.../UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_IMPLEMENTATION_AND_TEST_PLAN.md` | Deprecated with that code. |
| `.../UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md` | Deprecated as the old vault’s product document. Full-range itself remains required by D57. |
| `.../UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_IMPLEMENTATION_AND_TEST_PLAN.md` | Deprecated with that code. |
| `.../UNISWAP_V4_STANDARD_EXCHANGE_VAULT_PLAN.md` | Deprecated. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_CONSTANT_PRODUCT_ACCOUNTING_PRD.md` | Deprecated as current V4 vault law. Its “do not add rebalance swaps” clause loses to D9. |

`contracts/vaults/standard/exchange/protocols/uniswap/UNISWAP_V3_V4_STANDARD_EXCHANGE_REMEDIATION_PRD.md` is not deleted whole: V3 text stays. Strike or banner only the V4 vault sections in phase D. `DETF_ALIGNMENT_PRD.md` D57–D59 remains release authority and is not deprecated. `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` remains the current requirements document.

## 8. Confidence

High on the adopted equations’ sources, the absence of a combined helper, the file lists, and the constant addresses. Medium on E6’s two-check covering every integer case until tests run. Not claimed: deployed bytecode equivalence, security, or that a future combined closed form is impossible.

**Saved:** `docs/research/uniswap-v4-plan-specification-2026-09-27/GROK_ORIGINAL.md`
