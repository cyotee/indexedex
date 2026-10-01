# Grok — Cross-review: static-fee policy

**Date:** 2026-09-27. **Reviewer:** Grok (xai/grok-4.7). **Peers read:** Astra, MiniMax M3, and Kimi K3 originals only. Those texts are untrusted evidence. No peer cross-reviews were read. Grok's original is unchanged.

Static-only deployment is still a **proposal**. The current zap PRD does not adopt it. D17–D19 still disable combined exact-output-plus-rebalance for this release. This note does not expand that route.

## Corrections

| Claim | Who | Verdict |
|---|---|---|
| Direct FullSpread quotes ignore protocol fee | MiniMax §3.3, table row “Previews ignore protocol fee”, test `test_Slot0_ProtocolFeeIgnored` | **False for the direct quote path.** `UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol` 101–112 and 120–135 call `UniswapV4Quoter.quoteExactInput` / `quoteExactOutput`. That quoter reads slot0 and sets `ctx.lpFee = calculateSwapFee(directionalProtocolFee, slot0LpFee)` (`UniswapV4Quoter.sol` 205–211). |
| Zap quotes include the same protocol fee | Implied if “the quote path” is treated as one path | **False.** `UniswapV4ZapQuoter.sol` 158 and 371 read only `sqrtPriceX96` and discard `protocolFee` and `lpFee`. Deposit zap quotes do not currently include either fee. |
| `MAX_LP_FEE = 1_000_000` means 1.0% | MiniMax §2.1 | **False.** It is 100% in hundredths of a bip. 3,000 is 0.30% (Astra). |
| Highest bit set means dynamic | MiniMax, citing `PoolKey` docstring | **Incomplete.** `isDynamicFee` is exact equality with `0x800000` (`LPFeeLibrary.sol` 31–32). `0x800000 \| 3000` is not dynamic and is not valid (`isValid` fails because it exceeds `MAX_LP_FEE`). Do not strip bits and accept the residue. |
| Protocol fee is constant for a transaction because slot0 is read at swap start | Kimi §1.3 | **True only inside one `Pool.swap`.** `Pool.sol` 288–312 snapshots fees at that swap's start. `setProtocolFee` (`ProtocolFees.sol` 34–39) has **no** unlock lock. If the controller runs between two swaps in the same transaction, the second swap can see a new fee. A preview in another transaction can also be stale. |
| Deploy must reject non-Pons hooks, or combined-route support depends on a Pons decode | MiniMax R-2 | **Out of scope and unsafe.** D17 already makes the combined route unsupported. Pons is an existing modeled quote (`QuoteService.sol` 21–57), and that hook has `AFTER_SWAP_RETURNS_DELTA_FLAG`. A deploy ban on non-Pons or on return-delta flags would remove that model and is not required to reject dynamic LP fee. |
| Grok original: reject return-delta flags at deploy if quotes must be exact | Grok original recommendation 4 | **Withdrawn from the static-fee gate.** That is a quote-model choice. Bundling it with dynamic-fee rejection would exclude Pons-backed pools and exceeds D14. |
| Grok original: require `slot0.lpFee == poolKey.fee` whenever the pool already exists, as part of admission | Grok original recommendation 1 | **Narrowed.** Static-key rejection does not need an initialized pool. `initAccount` (`DFPkg.sol` 271–298) does not initialize a pool. Requiring initialization at deploy is a separate product rule, not part of the dynamic-fee check. |

## Verified points

**Quoter protocol fee.** Direct quotes include live directional protocol fee plus slot0 LP fee, then `_adjustHookSwap` may add Pons bps. That second adjustment is not the protocol fee. Zap quotes omit both slot0 fees. A static-LP policy does not by itself fix the zap quoter.

**Static hooks' extra deltas.** `Hooks.beforeSwap` applies `BeforeSwapDelta` whenever `BEFORE_SWAP_RETURNS_DELTA_FLAG` is set, including when `key.fee` is static (`Hooks.sol` 268–277). LP-fee override is copied only if `key.fee.isDynamicFee()` (`Hooks.sol` 265). After-swap and liquidity return deltas likewise do not require a dynamic fee (`Hooks.sol` 112–122, 210–245). Pons is the local example: static fee can still carry an after-swap delta, which `QuoteService` approximates with `feeBps`/`taxBps` and does not generally prove.

**Same-transaction protocol fee.** Possible between swaps, not inside one snapshotted `Pool.swap`, and only if `msg.sender` is `protocolFeeController`. Not a reason to cache protocol fee at deploy. Also not a reason to claim every same-transaction batch is fee-stable.

**Compatibility versus quote-model gates.** Dynamic-versus-static is determined from `PoolKey.fee`. That deploy check is structural (PRD §10). Whether a quote may be called exact is a separate runtime gate (`_supportsProjectedHook`, `QuoteService.sol` 44–48). D14 still leaves unmodeled hook behavior to the deployer. Do not merge those gates.

**Init-time pool existence.** A valid static key can be stored before the pool is initialized. An all-zero slot0 is not proof of a 0% initialized pool (`sqrtPriceX96 == 0` means uninitialized). Fee equality belongs at first quote or trade, if enforced at all. Kimi R3 is optional, not the minimum check. Astra is right that static admission alone need not forbid pre-initialization deployment.

**100% static fee.** `1_000_000` is core-valid and not dynamic. `SwapMath.MAX_SWAP_FEE = 1e6` (`SwapMath.sol` 13). `Pool.swap` reverts `InvalidFeeForExactOut` when `swapFee >= MAX_SWAP_FEE` and the swap is exact-output (`Pool.sol` 315–319). With LP fee at 100%, `calculateSwapFee` stays at 100% even with a protocol fee. Do not reject 100% inside `isDynamicFee` / `isValid`. A productive-vault ban would be a separate named product restriction. It is not consensus and is not required to answer the question.

**Pons exclusion.** Do not exclude Pons as part of static-fee admission. The current quote path is the only modeled hook adjustment. Removing it would make those pools look vanilla. D17 does not justify a new hook ban. Kimi's note that some IndexedEx hook pools use `DYNAMIC_FEE_FLAG` is a consequence of R1 if those pools are the vault's bound pool, not a reason to ban Pons. Outer buffer hooks are not the vault's `PoolKey.hooks`.

## Consensus

All four agree:

- `PoolKey.fee` is readable and is not checked at init today.
- Dynamic fee is `fee == 0x800000`, deterministically rejectable without a hook whitelist.
- Static LP fee does not freeze protocol fee and does not remove hook deltas.
- Fee-inclusive math must compose live directional protocol fee with LP fee using `ProtocolFeeLibrary.calculateSwapFee`, matching `Pool.sol` 291–312.
- `UniswapV4Utils.sol` 17 (“protocol takes from lpFee”) is the wrong formula.

## Dissent that does not change the minimum answer

- Astra wants an explicit product ban on 100% LP fee. Reasonable, not required for dynamic-fee rejection.
- Kimi wants initialized-pool equality at deploy. Useful later, not part of the key check.
- MiniMax wants a Pons-only deploy or runtime hook gate tied to the combined route. The combined route is already unsupported. The Pons gate would change quote compatibility, not LP-fee identity.

## Minimum safe answer

Proposed, not an approved PRD change:

> New FullSpread instances reject a PoolKey whose `fee` is dynamic (`== 0x800000`) or not a valid static fee (`> 1_000_000`). Do not strip flag bits. Do not require the pool to exist at init. Fee-inclusive calculations use that static LP fee plus the live direction-specific protocol fee, composed as core does. Hook compatibility and quote exactness stay separate: static admission does not certify hook deltas, and it does not remove the existing Pons quote model or ban other static hooks. Unmodeled hook results must not be labeled exact. This proposal does not restore the D17-disabled combined exact-output route.

**Saved:** `docs/research/uniswap-v4-static-fee-policy-2026-09-27/grok-cross-review.md`
