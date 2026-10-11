# Fix PRD — APEX Stage 2 confirmed defects

- **Status:** DRAFT. This file specifies repairs. It does not authorize editing code in the session that writes it.
- **Date:** 2026-10-07
- **Source review:** `docs/reviews/apex-stage2-council-2026-10-07/REPORT.md` and `REMEDIATION_PRD.md`
- **Elaboration:** RC-01 through RC-06 are specified below. RC-07 is ignored. No implementation plan is authorized by this file.

## Reserved items

| ID | State | One-line subject |
| --- | --- | --- |
| RC-01 | ELABORATED | Native SY must burn the vault's own shares internally. The external self-call is removed. |
| RC-02 | ELABORATED | Camelot zap-out exact-output must reject before burn when shares exceed `maxAmountIn` |
| RC-03 | ELABORATED | V3 pretransfer credit uses the local per-token book. The old deployed-reserve copy is not kept. |
| RC-04 | ELABORATED | V3 FullSpread direct exact-output must reject a partial fill at quote and at settlement |
| RC-05 | ELABORATED | Small Rocket Pool credits accumulate in the sleeve. Deposit only the excess over that sleeve. |
| RC-06 | ELABORATED | Book a DETF leftover only when preview of that leftover returns zero |
| RC-07 | IGNORED | Owner 2026-10-07: `r12_selector_size_compare.py` is a prior audit tool. Do not repair it. EIP-170 still applies at deploy. |

## RC-01 — Do not external-call the vault to burn the vault's own shares

### Correction

The first draft treated the external self-call as a mechanism to preserve, and proposed checking the caller before it. That repair is withdrawn. The self-call is the design error.

### Plain-language error

Internal-balance redemption means one thing: shares already held by the vault are burned, and the named receiver is paid. The vault already knows the holder. The holder is itself.

The shared adapter does not burn those shares directly. On that flag it makes an external call to itself, `address(this).call`, and then relies on the exchange seeing the vault as `msg.sender`. The burn happens only because the caller identity was changed. That identity change is unnecessary. Burning the vault's own shares is an internal accounting action. It does not need a new external message.

The ordinary path already shows the difference. It uses `delegatecall` so the original caller stays the caller. That is how this diamond reaches an exchange selector on another facet without pretending the vault called itself. The external `call` branch exists only to forge `msg.sender`. The code comment says so: internal-balance exits "call as the proxy" so the existing holder-burn route burns the vault's shares. It also avoids the pretransfer flag because some exchanges refund leftover prepaid shares. Neither reason justifies an external self-call. The burn can name `address(this)` and burn exactly the requested amount, with no refund of other vault shares.

This identity trick is also why a wallet can redeem vault-held shares. The adapter never asks whether the starter is a contract. After the self-call, the exchange no longer sees the wallet. Adding a bytecode check in front of the self-call would hide that, and it would keep the bad mechanism. Checking after the self-call would be useless, because the caller would then be the vault.

### What is not the error

- This is not permission to burn shares in someone else's wallet. The holder is the vault.
- This is not a missing burn cap. The amount is still the requested amount, limited to the vault's own balance.
- D12 does not justify the self-call. D12 accepts resting credit between contract callers. It is not a reason to enter the vault through an external call.
- Custody SY is the contrasting shape. It selects the vault as holder in the same call and burns that holder. It does not call itself to become the caller. Its wallet rejection stays. Its self-call shape is not copied because it does not have one.

### What the diamond does and does not require

Exchange settlement for some families lives on another facet. A Solidity `internal` call cannot enter a different facet contract. That constraint does not require `address(this).call`.

The allowed way to share the burn is a function both entry points can reach without changing `msg.sender`: a shared library or common base that takes the share holder as an argument. ERC-4626 already has `_burnSeShares(owner, amount, pretransferred)` on the common base inherited by the SY target. The internal-balance path should burn `address(this)` through that kind of function, then pay the receiver through the same settlement helper. It should not re-enter `exchangeIn` so that `msg.sender` becomes the vault.

`delegatecall` to another facet may remain for the ordinary path, where the original caller must stay the caller. That is not this defect. This defect is the external `call` used to replace the caller.

### Locations

- Shared entry and self-call: `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:34-67`
- Initiator record, with no bytecode check: `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:105-120`
- Existing check to match: `contracts/utils/LocalCreditLib.sol:23-28`, already used by `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:57-58`
- Generic false-flag burn: `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:272-291`
- FullSpread self-held acceptance: `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:907-913`. Hookless and Pons-family have the same initiator predicate in their own Commons. Re-read those files during implementation; do not copy a line number from V3.
- Wings false-flag holder selection: `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:147-171`

Known production inheritors of the shared adapter, to inventory rather than assume identical:

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
- FullSpread V3, hookless, and Pons-family query/common paths that inherit or call this adapter
- Legacy Uniswap V3/V4 out-query targets that inherit it. Those preserved trees are a separate product decision under RC-03. Do not silently treat them as out of RC-01, and do not expand RC-01 into the RC-03 accounting repair.

### Intended behavior

Internal-balance redemption burns shares held by the vault and pays the named receiver. The holder is `address(this)`, chosen in the same call. There is no external self-call and no rewritten `msg.sender`.

D9 still applies at that external entry. Owner confirmation, 2026-10-07: reject an EOA that attempts a pretransfer. A caller with no bytecode is rejected with `EOAPretransferNotAllowed()` before the burn. The check uses `LocalCreditLib.requirePretransferCaller`. It does not create a second call.

### Required repair

1. Remove the external self-call from internal-balance redemption. `NativeStandardYieldContextRepo` exists only to remember the caller across that call. It goes away with the call, unless a cited family still has a real use that does not forge `msg.sender`.
2. Burn the vault's own shares through a shared internal or library function. The holder argument is `address(this)`. The amount is the requested amount. Do not refund other shares held by the vault.
3. Run the payout through that same explicit-holder settlement. Do not re-enter `exchangeIn` to obtain a different `msg.sender`.
4. Keep ordinary redemption on the original caller. It burns that caller's shares and does not become an internal-balance burn.
5. Keep D9 at the external SY entry, before any burn: a code-less caller using the internal-balance flag reverts `EOAPretransferNotAllowed()`. That check is authorization. It is not a reason to retain the self-call.
6. Inventory every production inheritor of `NativeStandardYieldTarget`. Each internal-balance override that still uses `address(this).call` is in scope. A family that already burns `address(this)` without a self-call is cited and left alone.
7. Do not add a new external entry point or an ownership ledger.

### Acceptance criteria

- No in-scope internal-balance redemption reaches `exchangeIn` through `address(this).call`.
- The burn holder is `address(this)`, passed explicitly. A third-party wallet balance is not the holder.
- A code-less external caller using the internal-balance flag is rejected with `EOAPretransferNotAllowed()` before any burn, and both share balances are unchanged.
- A contract caller can redeem vault-held shares, in the requested amount, to the named receiver, with no refund of the vault's other shares.
- An ordinary redemption still burns the original caller's own shares.
- V3 FullSpread, hookless FullSpread, Pons-family FullSpread, and Wings each have their own assertion. One passing family does not prove the others.
- Tests use the production vault path. They do not mock the vault. They do not describe a live-system procedure.

### Non-goals

- Do not preserve the self-call and add a caller check in front of it.
- Do not weaken `requirePretransferCaller` or D12.
- Do not make internal-balance redemption burn an arbitrary wallet.
- Do not replace the ordinary path's facet `delegatecall` in this item unless that path also forges `msg.sender`.
- Do not change custody SY except where a search shows it uses this self-call. It does not.
- Do not repair Camelot, legacy stored-total credit, V3 exact-output fulfillment, Rocket Pool sleeve accounting, DETF residual policy, or selector evidence in this item.
- Do not deploy, migrate, or upgrade live instances.

### Verification boundary

Implementation of this item requires a later authorized test session. The review that found it did not run Forge. A green test on one family is not closure for an uninventoried inheritor.

## RC-02 — Compare the quoted share burn with `maxAmountIn` before burning

### Plain-language error

On an exact-output withdrawal, the caller names the most shares they will spend. The vault calculates how many shares the requested output actually costs. If that number is larger than the caller's maximum, the call must stop and burn nothing.

The share-to-pool branch already does that. After it computes `amountIn`, it reverts `MaxAmountExceeded` when `amountIn > maxAmountIn`, and only then burns. The zap-out branch computes the same `amountIn` and burns it without that comparison. On the false pretransfer flag, the later refund helper returns immediately, so nothing else enforces the maximum. The true flag can still revert afterward if used shares exceed credited shares, but that check is after the burn and does not run on the false flag. The missing comparison is the fix. A later revert is not a substitute.

### Required repair

In the zap-out branch of `exchangeOut`, after `amountIn` is known and before `_secureSelfBurn`, use the same comparison as the share-to-pool branch:

- if `amountIn > maxAmountIn`, revert `MaxAmountExceeded(maxAmountIn, amountIn)`;
- otherwise continue.

Apply it on both pretransfer flags. Do not compare the LP amount or the token output with `maxAmountIn`. Those are different units. `amountIn` here is the share amount to burn, and `maxAmountIn` is the caller's share maximum.

Location: `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol:751-764`. The working comparison is at `:657-661`.

### Acceptance criteria

- A zap-out whose computed share cost exceeds `maxAmountIn` reverts `MaxAmountExceeded` before any share burn, on both flags.
- That rejection leaves the caller's shares and the vault's shares unchanged.
- A zap-out whose computed share cost is within `maxAmountIn` still burns that computed amount and pays the requested output.
- The share-to-pool branch's existing comparison is left as it is.

### Non-goals

- Do not change Uniswap V2 or Aerodrome routes that already compare before burn.
- Do not reorder the fee-share mint. The working branch also mints it before the comparison, and a revert rolls that mint back.
- Do not treat `_refundExactOutCredit` as this check.
- Do not describe a live withdrawal.

## RC-03 — Book local balances. Do not reconstruct them from the deployed position

### Correction

The first review described the symptom: `notebook - live deployed` drifts when the position changes. The proposed repair was too small. It asked whether launch scripts may keep constructing that package, or whether the subtraction should be patched. That repair is withdrawn.

The mapping is already the local book. `MultiAssetBasicVaultRepo.Storage._reserveOfToken` is `mapping(address token => uint256 balance)`. A pretransfer check asks only whether the vault's wallet holds tokens above that local book. The deployed position is supposed to change. It is not an input to this check.

The old V3 and V4 packages store total inventory in that mapping, then subtract the live deployed amount to invent the local book. Their own comment says `U = balance - R` under-credits if `R` includes deployed amounts. That comment defends the wrong store. Once `R` is the locally held balance, `balance - R` is the unbooked local amount. No deployed subtraction is required.

### Plain-language error

Shareholders' loose tokens are the tokens sitting in the vault's wallet that the vault has already booked. A pushed deposit is real only when the wallet holds more than that book. The old code does not read the book that way. It treats the book as loose tokens plus whatever the Uniswap position currently contains, then subtracts the live position to guess the loose part. Because the position changes on purpose, the guess changes too, and wallet tokens that were already booked can look like a new deposit.

### Reference, and what matching it means

Wings is the reference for this rule, not a template for copying its V4 pool shape onto V3.

- Wings tracks loose custody itself and writes that local amount into `MultiAssetBasicVaultRepo` at the end of the operation (`UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:49-52`).
- Its pretransfer budget is wallet balance minus that local book (`:234-237`). It does not subtract position inventory.
- FullSpread V3 already uses the same credit line: `LocalCreditLib.available(balanceOf(this), _reserveOfToken(token))` (`UniswapV3FullSpreadStandardExchangeVaultCommon.sol:851-862`). That is the check. It is not a reason to keep the old package beside it.

Matching Wings does not mean giving the V3 vault Wings' hookless pool, one-target routes, harvest, or reserve floor. Those are a different product. It means the V3 vault books each locally held token in the mapping and validates a pretransfer from that book alone.

### Required repair

1. Delete the old Uniswap V3 Standard Exchange under `contracts/protocols/dexes/uniswap/v3`. Do not rewrite it in place and do not keep a copy. The supported V3 vault is Uniswap V3 FullSpread.
2. Tests that exist only to test that old vault are removed. Tests that include it are updated to the Uniswap V3 FullSpread vault.
3. Launch and DETF callers stop constructing `deployUniswapV3StandardExchangeDFPkg`. They use the FullSpread package. Known callers include `scripts/foundry/anvil_robinhood_testnet/Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol`, `scripts/foundry/anvil_robinhood_main/Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol`, `scripts/foundry/anvil_robinhood_fee_detf/Script_05_DeployUniV3SeOnRichPool.s.sol`, and `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol`.
4. FullSpread already credits `balanceOf(this) - _reserveOfToken(token)`. That book is the full locally held balance of the token, not dust and not local plus deployed. Deployed amounts are not an input.
5. A pull (`pretransferred=false`) still measures the wallet increase from the actual transfer.
6. This item does not migrate or upgrade instances already deployed. Deleting the old source does not change those instances.

### Acceptance criteria

- The old package under `contracts/protocols/dexes/uniswap/v3` is deleted.
- No test, launch stage, or DETF deploy still constructs that old package.
- Tests that need a V3 vault use Uniswap V3 FullSpread.
- FullSpread pretransfer credit does not read deployed amounts.
- `_reserveOfToken(token)` is the full locally held balance of that token.

### Non-goals

- Do not port Wings' V4 geometry, target-only routes, harvest, or floor into V3 in this item.
- Do not store a deployed reserve for this check.
- Do not patch the subtraction and keep the old package as a supported twin.
- Do not upgrade live instances.
- Do not describe a transaction that relies on the old subtraction.

## RC-04 — Exact-output must deliver the requested output

### Plain-language error

An exact-output swap is a request for a specific amount of the output token, with a ceiling on what the caller will pay. Success means the recipient received that output and the vault spent no more than the ceiling.

The V3 FullSpread direct pair route only prices and checks the input. `_quoteSwapOut` asks the quoter for an exact-output quote, then returns `quote.amountIn` and throws away `quote.amountOut` and `quote.fullyFilled`. The quoter is allowed to stop at the price limit and return a smaller output. The vault then treats that partial input price as the price of the full request.

Execution has the same hole. `_swapExactOut` asks the pool for the requested output, reads only the input delta, and reverts only if that input is above `maxAmountIn`. It never checks that the output delta equals `amountOut`. `_executeQuotedSwapOut` then checks that the input was delivered and returns. A short output can therefore be reported as a successful exact-output swap.

This is V3 FullSpread's direct token-to-token route only. Hookless already rejects a quote whose output is not the requested amount. Wings has no direct pair-swap route. Do not spread this repair to them.

The Crane quoter is not the defect. Returning `fullyFilled=false` and the actual partial output is the correct quote result. The vault is wrong to ignore it.

### Suggested repair

Reject the incomplete result in both places. Do not change the quoter.

1. In `_quoteSwapOut`, after `quoteExactOutput`, return `quote.amountIn` only when `quote.fullyFilled` is true and `quote.amountOut` equals the requested `amountOut`. Otherwise revert. Preview uses this function, so an unfillable exact-output preview reverts instead of quoting the input for a short fill.
2. In `_swapExactOut`, after `pool.swap`, keep the existing input-ceiling check. Also read the output token's delta. That delta is the amount the pool paid the recipient. Require it to equal `amountOut`. If it does not, revert. Do not cast the output delta into the input amount.
3. Leave `_executeQuotedSwapOut`'s input pull and refund as they are. If settlement reverts, that pull rolls back with it. Do not add a second output check that can be skipped.

A zero requested output already returns zero before the quote. Leave that alone.

### Locations

- Quote: `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:253-279`
- Settlement: the same file, `:500-525`
- Caller that reports success: `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:68-95`
- Preview: `UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:46-61`
- Quoter result, not to be changed: `lib/crane/contracts/utils/math/UniswapV3Quoter.sol:141-158`

### Acceptance criteria

- A direct exact-output quote that is not fully filled reverts, and preview of that request reverts.
- A direct exact-output execution whose output delta is not the requested amount reverts, and the caller's input balance is unchanged.
- A funded request that the pool can fill still pays the requested output and spends no more than `maxAmountIn`.
- Hookless, Pons-family, and Wings are not edited for this item.

### Non-goals

- Do not change `UniswapV3Quoter`.
- Do not rename the existing input-ceiling error in this item. The short-output revert must mean the output was short, not that the input ceiling was exceeded.
- Do not describe a pool state or a call that produces the short fill.

## RC-05 — Below-minimum amounts accumulate in the existing liquid sleeve

### Correction

The previous draft treated each small credit as a deposit that must never be combined with a later credit. That is not the vault. The liquid sleeve is the WETH balance. It is the accumulator. Small amounts sit there together. When that balance exceeds the configured sleeve, the vault deposits the excess, if that excess is a legal Rocket Pool deposit. There is no per-deposit ledger.

### Plain-language error

Rocket Pool rejects a deposit below its minimum. The current helper splits the excess into a booked slice and a second slice, and asks whether each slice can be deposited by itself. A slice below the minimum is skipped. That split is the mistake. The vault is not supposed to remember each small deposit. Those amounts are already in the sleeve. The only deposit decision is whether the WETH above the configured sleeve is large enough to deposit.

The family rule is already written that way. After a WETH credit, `targetLiquid` is the configured percentage of total reserves. Excess is `WETH.balance - targetLiquid`. Stake that excess, capped by maximum deposit capacity. If it cannot be staked, it remains sleeve. The mint does not revert because nothing was staked. See `ROCKET_POOL_RETH_STANDARD_EXCHANGE_VAULT_PRD.md:203-214`.

### Required repair

One stake decision, not two.

1. Credit the WETH into the existing sleeve. Do not record the credit as its own stake lot. `liquidReserveEth()` stays. It is the vault's WETH balance, and this item does not remove it.
2. Excess is `liquidReserveEth() - targetLiquid`. Target liquid is `totalReserveEth * targetLiquidReservePercentage / 1e18`.
3. If that excess is below `getMinimumDeposit()`, deposit nothing. It stays in the sleeve and accumulates with later credits.
4. If that excess meets the minimum, deposit `min(excess, getMaximumDepositAmount())`. Any remainder stays in the sleeve.
5. Remove the booked-first pass at `RocketPoolRETHStandardExchangeCommon.sol:505-510`. It is the per-deposit split. The sleeve-excess offer is the only stake decision.

A later small credit may be what pushes the accumulated excess over both the configured sleeve and the Rocket Pool minimum. That combined deposit is the intended result.

### Acceptance criteria

- A credit below the Rocket Pool minimum is not sent as its own deposit. The WETH remains in the sleeve.
- Further credits accumulate in that same WETH balance. They are not tracked individually.
- When `liquidReserveEth() - targetLiquid` meets the minimum, that excess is deposited, including WETH that arrived in earlier below-minimum credits.
- When the excess is still below the minimum, nothing is deposited and the SE mint still succeeds.
- The helper no longer stakes a booked slice separately from the sleeve excess.
- `liquidReserveEth` remains.

### Non-goals

- Do not add a ledger of small deposits.
- Do not keep a below-minimum amount out of every future sleeve-excess deposit.
- Do not change EtherFi in this item.
- Do not change the accepted deposit-fee socialization.

## RC-06 — Preview the leftover. Do not price one share

### Plain-language error

A DETF leftover that cannot mint a Standard Exchange share is booked to existing holders and not deposited. The only proof is a successful preview of that leftover returning zero shares.

The unsupported-quote branch does that. It calls `previewExchangeIn` on the actual amount. The supported-quote branch does not. It asks how many tokens one share costs, and books when the leftover is smaller than that cost. That is a different question. The comment says it is intentional. No owner ruling allows it to replace the zero preview.

There is no remaining reason to ask for one share. If the preview of the actual leftover is zero, book it. If the preview is not zero, do not book it on this path. If the preview reverts, that is not proof, and the route stays intact.

### Required repair

In `_retainSubSharePairResidual`, use the same signal on both branches: `previewExchangeIn(pair, amount, se) == 0`. If that preview is zero, do not deposit. The local reserve is then the full locally held balance of that token, not the leftover alone and not dust alone. The mapping records whatever the vault holds locally, without a reason code.

Do not call `quoteInputForExactShares(state, 1)` to decide this. Do not add a new catch. The existing `supportsInterface` catch stays a failed probe: it does not book.

Location: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:634-654`. The zero-preview helper already exists at `:670-675`.

### Acceptance criteria

- A leftover whose preview is zero is not deposited. The reserve records the full locally held balance of that token.
- A leftover whose preview is not zero is not treated as an undepositable leftover by this function.
- A reverting preview does not book.
- The one-share exact-output quote is not the book-and-wait signal.

### Non-goals

- Do not add a catch around the preview.
- Do not redesign DETF bond, threshold, or vesting economics.
- Do not invent a `beforeSwap` guard from the withdrawn claim.
