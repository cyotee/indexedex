# Implementation plan: APEX Stage 2 confirmed repairs

- **Status:** ready for a separately authorized implementation session
- **Date:** 2026-10-07
- **Controlling PRD:** [FIX_PRD.md](./FIX_PRD.md). Where an older review sentence conflicts with an owner correction in that file, the correction controls.
- **This plan does not authorize code changes.** A later session must be explicitly asked to implement it. Writing this plan is not that request.
- **RC-07 is ignored.** Do not edit `scripts/r12_selector_size_compare.py`. Contracts must still fit 24,576 bytes when deployed. That limit is not this script.

## Objective

Implement and test RC-01 through RC-06 as corrected in the fix PRD. A failing test is iterated until the stated repair is true. Passing these tests is not audit submission and does not certify the 108 original APEX criteria.

## Read first

Read `CLAUDE.md`, `.github/ASSISTANT_RULES.md` and its coding and testing documents, `docs/testing/ARTIFACT_BUILDS.md`, and [FIX_PRD.md](./FIX_PRD.md). Use production TestBases. Do not mock the vault, manager, registry, fee oracle, facet, or package under test. Do not enable `via_ir`. Do not change Foundry profiles. Do not delete `out/` or `cache_forge/`. After a production edit, refresh artifacts with `python3 scripts/forge-artifacts.py` before `forge test`. Wait for compiler completion. Do not kill `forge` or `solc` for lack of progress lines.

Test names, comments, and reports must not describe how to attack a live system. Tests still use the real production path and assert the exact corrected result, including that a forbidden credit, burn, or payout does not occur.

## Order

Do the small local repairs first. Do not start RC-01 or RC-03 until the smaller items compile, because those two touch shared call shape and package construction.

| Step | Item | Why this order |
| --- | --- | --- |
| 1 | RC-02 Camelot maximum | One comparison. No package or call-shape change. |
| 2 | RC-04 V3 FullSpread exact-output | Quote and settlement only. Does not change hookless, Pons, or Wings. |
| 3 | RC-06 DETF leftover preview | One signal. No new catch. |
| 4 | RC-05 Rocket Pool sleeve excess | One stake decision. `liquidReserveEth` stays. |
| 5 | RC-01 Native SY internal burn | Removes the external self-call. Inventory every inheritor before editing. |
| 6 | RC-03 Delete old protocols V3 | Delete `contracts/protocols/dexes/uniswap/v3`. Point tests and callers at V3 FullSpread. Do not delete the old V4 package. |

## Step 1 — RC-02

In `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol`, zap-out branch, after `amountIn` is known and before `_secureSelfBurn`:

- if `amountIn > maxAmountIn`, revert `MaxAmountExceeded(maxAmountIn, amountIn)`;
- do this on both pretransfer flags;
- compare shares with the share maximum, not LP units or output tokens.

Copy the placement already used by the share-to-pool branch in the same function. Do not reorder the fee-share mint. Do not treat `_refundExactOutCredit` as the check. Do not edit Uniswap V2 or Aerodrome.

Test on the production Camelot package: a zap-out whose computed shares exceed the maximum reverts before any burn, and share balances are unchanged. A zap-out within the maximum still burns the computed shares and pays the requested output.

## Step 2 — RC-04

V3 FullSpread direct pair exact-output only.

- `UniswapV3FullSpreadStandardExchangeVaultCommon._quoteSwapOut` returns `quote.amountIn` only when `quote.fullyFilled` is true and `quote.amountOut` equals the request. Otherwise revert. Preview uses this function, so an unfillable preview reverts.
- `_swapExactOut` keeps the input ceiling. After `pool.swap`, require the output token's paid delta to equal `amountOut`. Do not cast that output delta into the input amount.
- Leave the input pull and refund in `_executeQuotedSwapOut`. A settlement revert rolls the pull back.
- Do not change `lib/crane/contracts/utils/math/UniswapV3Quoter.sol`.
- Do not edit hookless, Pons-family, or Wings.

Test the production V3 FullSpread proxy: an unfilled exact-output quote reverts; an execution whose output is short reverts and the caller's input is unchanged; a fillable request pays the requested output and spends no more than `maxAmountIn`.

## Step 3 — RC-06

In `UniswapV4DetfCommon._retainSubSharePairResidual`, both branches use `previewExchangeIn(pair, amount, se) == 0` as the only signal that the leftover cannot be deposited. If that preview is zero, do not deposit. The local reserve is the full locally held balance of that token, not the leftover alone and not dust alone. The mapping does not record why the vault holds the tokens.

Do not call `quoteInputForExactShares(state, 1)` for this decision. Do not add a catch. The existing `supportsInterface` catch remains a failed probe and does not book. Do not redesign bond, threshold, or vesting economics.

Test the production DETF path: a leftover whose preview is zero is not deposited, and the reserve equals the full local balance; a non-zero preview is not treated as an undepositable leftover by this function; a reverting preview does not book.

## Step 4 — RC-05

In `RocketPoolRETHStandardExchangeCommon._bestEffortStakeOverageTowardTarget`, make one stake decision.

- Keep `liquidReserveEth`. It is the vault's WETH balance. Do not remove it.
- Excess is `liquidReserveEth() - (totalReserveEth * targetLiquidReservePercentage / 1e18)`.
- If excess is below `getMinimumDeposit()`, deposit nothing. It stays in the sleeve.
- If excess meets the minimum, deposit `min(excess, getMaximumDepositAmount())`. Remainder stays in the sleeve.
- Remove the booked-first pass. Do not track each small credit.

A later small credit may be what makes the accumulated excess depositable. That combined deposit is intended. Do not change EtherFi. Do not change deposit-fee socialization.

Test the production Rocket Pool package: a below-minimum credit is not its own deposit; several below-minimum credits remain sleeve until their accumulated excess meets the minimum; that excess is then deposited; the SE mint still succeeds when nothing is staked.

## Step 5 — RC-01

Inventory every production inheritor of `NativeStandardYieldTarget` and every override of `_standardRoute` or `redeem` that uses `address(this).call` for internal-balance redemption. Known starting set:

- `ERC4626StandardYieldTarget`
- `MorphoBlueStandardYieldTarget`
- `LidoWstETHStandardYieldTarget`
- `RocketPoolRETHStandardYieldTarget`
- `EtherFiWeETHStandardYieldTarget`
- `AaveV3StataStandardYieldTarget`
- `BalancerV3PoolStandardExchangeTarget`
- `ConstantProductStandardYieldTarget`
- `UniswapV4UpperLowerWingsStandardExchangeVaultSYTarget`
- `UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget`
- V3, hookless, and Pons-family FullSpread query or common paths that inherit the adapter
- Legacy V4 out-query targets that inherit it. Fix their internal-balance call shape here. Do not turn this step into an accounting repair, and do not delete the old V4 package.
- Do not repair `contracts/protocols/dexes/uniswap/v3`. Step 6 deletes that package.

Repair:

1. Remove the external self-call from internal-balance redemption. Do not keep it and add a caller check in front of it.
2. Burn `address(this)` through a shared internal or library function. The holder is an argument. Burn exactly the requested amount. Do not refund the vault's other shares.
3. Pay the receiver through that same explicit-holder settlement. Do not re-enter `exchangeIn` to change `msg.sender`.
4. A facet cannot internally call a different facet. Share the burn and settlement through a common base or library. `delegatecall` may remain on the ordinary path, where the original caller must stay the caller.
5. Delete `NativeStandardYieldContextRepo` unless a cited family uses it for something other than remembering the caller across the self-call.
6. At the external pretransfer or internal-balance entry, before any burn, reject an EOA. A code-less caller reverts `EOAPretransferNotAllowed()` through `LocalCreditLib.requirePretransferCaller`. That check is authorization. It is not a reason to keep the self-call.
7. Ordinary redemption still burns the original caller's own shares.

A family that already burns `address(this)` without a self-call is cited and left alone. Custody SY is that reference. Do not change it unless the inventory finds this self-call there. It does not.

Tests, each on the production proxy, and separately for V3 FullSpread, hookless, Pons-family, and Wings:

- no internal-balance redemption reaches `exchangeIn` through `address(this).call`;
- the burn holder is the vault;
- a code-less caller is rejected and both share balances are unchanged;
- a contract caller redeems only vault-held shares, in the requested amount, to the named receiver;
- an ordinary redemption still burns the original caller's shares.

One family's test does not close another.

## Step 6 — RC-03

Delete the old Uniswap V3 Standard Exchange under `contracts/protocols/dexes/uniswap/v3`. Do not rewrite it. Do not keep a copy. The supported V3 vault is Uniswap V3 FullSpread.

- Remove tests that exist only for the old vault.
- Update tests that include the old vault so they use Uniswap V3 FullSpread.
- Stop constructing `deployUniswapV3StandardExchangeDFPkg`. Point these callers at the FullSpread package:
  - `scripts/foundry/anvil_robinhood_testnet/Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol`
  - `scripts/foundry/anvil_robinhood_main/Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol`
  - `scripts/foundry/anvil_robinhood_fee_detf/Script_05_DeployUniV3SeOnRichPool.s.sol`
  - `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol`
- The 2026-10-07 sentence that forbade deleting `contracts/protocols/dexes/uniswap/v4` is withdrawn. The owner is deleting that package. This RC-03 step still must not treat that deletion as the V3 FullSpread replacement.

FullSpread already credits `balanceOf(this) - _reserveOfToken(token)`. That book is the full locally held balance of the token. It is not dust, not a leftover slice, and not local plus deployed. Deployed amounts are not an input. A pull still measures the wallet increase from the actual transfer.

This step does not migrate or upgrade instances already deployed. Deleting the old source does not change those instances. Do not port Wings' V4 pool, routes, harvest, or floor into V3.

Test that the old package path is gone, that no remaining test or launch caller constructs it, and that a FullSpread pretransfer credits only the wallet excess above the full local book.

## Out of scope

- RC-07 and any edit to `scripts/r12_selector_size_compare.py`.
- Deployment, migration, broadcasts, registry disablement, and live-instance upgrades.
- Merging hookless and Pons-family FullSpread.
- Binding Wings to a Pons-configured pool.
- Porting Wings' V4 product shape into V3.
- Deleting or rewriting `contracts/protocols/dexes/uniswap/v4`.
- Rewriting the old V3 package in place instead of deleting it.
- Removing `liquidReserveEth`.
- EtherFi sleeve arithmetic.
- Camelot, Uniswap V2, or Aerodrome routes that already compare `maxAmountIn` before burn.
- A new catch around DETF preview, or a `beforeSwap` guard from the withdrawn claim.
- DETF bond, threshold, or vesting economics.
- Changing `UniswapV3Quoter`.
- `via_ir`, a new Foundry profile, or deleting `out/` or `cache_forge/`.

## Done when

- Each RC-01 through RC-06 acceptance list in [FIX_PRD.md](./FIX_PRD.md) has a production-path test, and that test has been run in the implementation session.
- RC-07 was not edited.
- No live transaction was sent.
- The implementation session reports the commands, the toolchain it actually ran, and any test that did not pass.

Stop after that report. Do not deploy.
