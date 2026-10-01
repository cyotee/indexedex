# Grok — Static pool-fee policy for the FullSpread V4 vault

**Date / access date:** 2026-09-27. **Reviewer:** Grok (xai/grok-4.7). **Question:** Can the new FullSpread vault read the configured pool fee, reject dynamic-fee pools at deployment, and use a static fee in calculations, while hook compatibility stays the deployer's responsibility?

This pass does not adopt the prior zap-in plan. No peer artifacts were read. No code or PRD edits.

**Answer:** Yes for the LP fee. No if "static fee" is taken to include protocol fee or hook deltas. Deploy-time rejection of dynamic LP fee is a deterministic PoolKey check and is compatible with PRD D14. It does not make a fee-inclusive quote exact.

## Evidence

### What the vault can already read

- `PoolKey.fee` is stored and exposed. `UniswapV4FullSpreadStandardExchangeVaultPoolKeyAwareRepo.sol` 70–75 returns `poolKey.fee`. `initAccount` stores the key with no fee check (`UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` 257–264, 286).
- Live slot0 is already read. `UniswapV4FullSpreadStandardExchangeVaultCommon.sol` 432–433 returns `sqrtPriceX96`, `tick`, `protocolFee`, and `lpFee` via `StateLibrary.getSlot0`. Callers today do not use that `lpFee` as the zap quote. `UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol` 50–57 adjusts only a modeled Pons hook bps charge and otherwise returns the vanilla amount.

### Three different fees

| Fee | Where it lives | Deterministic? | Mutable after init? |
|---|---|---|---|
| Static LP fee | `PoolKey.fee`, hundredths of a bip, max `1_000_000` | Yes, if not the dynamic flag | No, on a non-dynamic pool |
| Dynamic LP fee | `PoolKey.fee == 0x800000` | The flag is deterministic | Slot0 LP fee starts at 0; the hook may set it and may override it per swap |
| Directional protocol fee | Slot0, packed `uint24`: low 12 bits 0→1, high 12 bits 1→0, max `1000` pips (0.1%) each | Readable at quote time | Yes. `protocolFeeController` may call `setProtocolFee` later |
| Hook amount delta | `beforeSwap` / `afterSwap` / liquidity callbacks | Only the permission bits in the hook address are deterministic | The amounts are arbitrary code |

Local pins, vendored for Solidity 0.8.30 compatibility:

- `LPFeeLibrary.sol` 15–20, 31–32, 38–39: `DYNAMIC_FEE_FLAG = 0x800000`, `OVERRIDE_FEE_FLAG = 0x400000`, `MAX_LP_FEE = 1000000`. `isDynamicFee` is equality with the flag, not a masked bit. `isValid` is `fee <= MAX_LP_FEE`. The dynamic flag is therefore not a valid static fee.
- `ProtocolFeeLibrary.sol` 7–23, 35–45: `getZeroForOneFee` / `getOneForZeroFee`; `calculateSwapFee` is `protocolFee + lpFee - protocolFee * lpFee / 1_000_000`. Protocol fee is taken from the input first; LP fee is taken from the remainder. `Slot0.sol` 19–25 says the same.
- `UniswapV4Utils.sol` 17 says protocol fee is taken from the LP fee. That comment disagrees with `ProtocolFeeLibrary` and `Slot0`. Do not use it.

Context7 `/uniswap/v4-core`, accessed 2026-09-27, matches these flags and the slot0 layout: https://context7.com/uniswap/v4-core/llms.txt . Upstream `main` is not a deployment pin. The vendored files above are the repo pin.

### What the manager actually charges

`Pool.swap` (`Pool.sol` 291–312):

1. Select the direction's protocol fee from slot0.
2. If `lpFeeOverride` has `OVERRIDE_FEE_FLAG`, use that value after removing the flag. Otherwise use slot0 `lpFee`.
3. `swapFee = protocolFee == 0 ? lpFee : calculateSwapFee(protocolFee, lpFee)`.

`Hooks.beforeSwap` (`Hooks.sol` 263–265) copies a returned fee into `lpFeeOverride` **only when** `key.fee.isDynamicFee()`. On a static-fee pool the override is ignored even if the hook returns one.

`PoolManager.updateDynamicLPFee` (`PoolManager.sol` 288–294) reverts unless the key is dynamic and the caller is the hook. A static pool's slot0 LP fee is therefore the fee stored at initialize (`LPFeeLibrary.getInitialLPFee`, lines 48–56), which is `PoolKey.fee`.

`UniswapV4Quoter.sol` 205–211 already composes directional protocol fee with slot0 LP fee. It documents that it does not see a `beforeSwap` override (`UniswapV4Quoter.sol` 26, 102).

### Hook deltas are not fees

`Hooks.beforeSwap` still applies `BeforeSwapDelta` when `BEFORE_SWAP_RETURNS_DELTA_FLAG` is set, including on a static-fee pool (`Hooks.sol` 268–277). `afterSwap` can return a further delta. Add/remove-liquidity return-delta flags exist (`Hooks.sol` 112–122). Those change amounts or liquidity accounting. They are not represented by `PoolKey.fee`.

`Hooks.isValidHookAddress` (`Hooks.sol` 124–128) forbids a dynamic fee when `hooks == address(0)`. A hook address may be dynamic-fee with no other flag, or flagged without being dynamic. Flag bits do not prove the hook will no-op.

Pons handling in `QuoteService.sol` 21–41 is a separate constant-bps model for one flag set. It is not the LP fee and not a general hook-delta model.

### Product law

PRD D14 and §10 (lines 41, 302–315): keep deterministic structural PoolKey validation; do not treat hook flags as compatibility proof; no discretionary whitelist; deployer supplies a compatible pool; do not present an unmodeled vanilla quote as exact. D20 requires a 10 bp shortfall check against a fee-inclusive quote. Rejecting `fee == 0x800000` is structural validation, not a whitelist.

## Recommended requirements

1. **Reject dynamic LP fee at deployment.** In `processArgs` or `initAccount`, revert unless `!LPFeeLibrary.isDynamicFee(poolKey.fee) && LPFeeLibrary.isValid(poolKey.fee)` and `Hooks.isValidHookAddress(poolKey.hooks, poolKey.fee)`. Also require the pool to be initialized and `slot0.lpFee == poolKey.fee` if the pool already exists. This is the precise static-LP check.
2. **Quote the static LP fee plus the live directional protocol fee.** For a swap in direction `zeroForOne`, `swapFee = ProtocolFeeLibrary.calculateSwapFee(getZeroForOneFee(slot0.protocolFee), poolKey.fee)`. Do not cache protocol fee at deploy. Do not add the Pons bps on top of this unless that hook model is actually the pool hook; never add LP fee twice.
3. **Keep execution on measured fills.** The 10 bp check compares the actual `PoolManager` delta with that quote. It is the backstop if protocol fee changes between quote and execution.
4. **Do not claim the static LP fee prices hook deltas.** If a fee-inclusive quote is required to be exact, also reject hook addresses with `BEFORE_SWAP_RETURNS_DELTA_FLAG`, `AFTER_SWAP_RETURNS_DELTA_FLAG`, or the add/remove return-delta flags. That check is the address mask, still not an address whitelist. If those hooks remain allowed, D14 applies and the quote must not be labeled exact; the 10 bp check may then revert a compatible-looking but delta-returning hook.
5. **Leave other hook callbacks to the deployer.** Static fee does not prove `beforeAddLiquidity`, `afterRemoveLiquidity`, or a no-delta `beforeSwap` will succeed or leave amounts unchanged.

## Limits of the static-fee assumption

- It fixes the LP component only. Protocol fee remains directional and controller-mutable. A quote that uses only `PoolKey.fee` is not fee-inclusive under D20.
- It removes `beforeSwap` LP-fee override. It does not remove hook deltas or liquidity callbacks.
- It does not freeze fee growth already accrued on the position. That is inventory (`E`), not the swap fee.
- Slot0 `lpFee` on a dynamic pool does not include the `0x800000` flag (`Slot0.sol` 24–25). Reading slot0 alone cannot prove the pool is static. The key flag is the deploy check.
- A non-canonical manager could theoretically change LP fee without `updateDynamicLPFee`. The vault's pinned `PoolManager` plus `slot0.lpFee == poolKey.fee` at use time closes that for the canonical contract. It is not a proof about every contract that implements the interface.
- `UniswapV4Utils.sol`'s "protocol takes from lpFee" sentence is not the calculation to implement.

## Confidence

High on the local flag, override, protocol-fee split, and the absence of a deploy-time dynamic-fee reject. Context7 agrees with the vendored flag values; it is not a bytecode pin. Medium on whether product should also reject return-delta flags: that is a requirements recommendation, not a fact already in D14. No tests were run.

**Saved:** `docs/research/uniswap-v4-static-fee-policy-2026-09-27/grok-original.md`
