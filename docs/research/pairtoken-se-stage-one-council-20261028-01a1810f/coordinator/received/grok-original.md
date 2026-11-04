# Grok original: coordinator archival receipt

Source: Native task `st_01a183c2`, initial inline response, plus same-task delivery-only verbatim R5-R7 recovery. The body below is the member text, not a coordinator revision. The recovery replaced the task-output elision; no recommendations were rewritten.

---

Limitation: `apply_patch` is not an available tool. Searches for it returned no catalog match. Per the brief, the complete initial response is inline. No alternate write was attempted.

## Identity

Independent Grok council member, initial pass only. Assigned route: `xai/grok-4.7:xhigh`. This is not a coordinator vote, not an advisory review, and not an implementation or security certification. No peer responses were read.

## Question and targets

Question: what material requirements need owner clarification, and what concrete improvements would make the stage-one PRD coherent, implementable, testable, and faithful to the confirmed owner choices?

Target read in full: `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` (S1-ARCH-04/05 and S1-A01 through S1-A57 present).

Required baseline read in full: `contracts/pairtoken-baseline/PairToken.sol`, `PairTokenMath.sol`, and `interfaces/IPairTokenDependencies.sol`.

## Evidence and coverage

Confirmed owner choices are not re-opened: staged simple SE, one full-range position, ownership logic without dead shares / 10 bps retention / protocol-fee routing, baseline compounding, native ETH, exact-output selectors that reject, the five reused facets with factory facets excluded, and no stage-one shares-of-shares. Section 1.2 correctly says the rest of the PRD is draft. S1-X01 through S1-X14 are author proposals. That distinction is sound and should be kept.

What already matches sources:

- Baseline deviations the owner confirmed are real. Genesis mints 1,000 shares to `DEAD` and subtracts them from the recipient (`PairToken.sol` 224-227; `DEAD_SHARES` line 48). Redemption uses `shares * 9990 / 10000` (lines 201 and 413; `RETENTION_BPS` line 49). Compound routes a factory protocol fee (lines 433-438). Stage one correctly removes those.
- The five reused facets expose exactly the 20 selectors the PRD counts: `ERC20Facet.facetFuncs` is 9, `ERC2612Facet` is 3, `ERC5267Facet` is 1, `MultiAssetBasicVaultFacet` is 3, `MultiAssetStandardVaultFacet` is 4. `ERC20Facet.facetInterfaces` includes the IERC20 / IERC20Metadata XOR. `ERC20PermitFacet` combines those token interfaces and must stay out of the cut.
- `DiamondPackageCallBackFactory` installs ERC-165, loupe, ERC-8109, and a temporary post-deploy hook, then the factory salt is `keccak256(abi.encode(pkg, pkg.calcSalt(pkgArgs)))` (`calcAddress`, same file). Excluding those four from package cuts is correct. S1-A56 and S1-A57 match that factory.
- `IStandardExchangeIn.exchangeIn` is nonpayable. `IStandardExchangeOut` defines `ExchangeOutNotAvailable()`. The multi interfaces are exact many-to-one input and exact one-to-many output, not max-input paired deposit or share-input paired redemption. Refusing those names is correct.
- `NativeStandardYieldMoneyTarget.deposit` is payable and immediately reverts `UnsupportedNativePayment()` when `msg.value != 0`. The 16 SY methods listed in S1-API-03 are the shared surface. Overriding that rejection only in this family is the right requirement.
- `LocalCreditLib.requirePretransferCaller` rejects a caller with no bytecode. Construction-time `extcodesize` is zero, so S1-A35 matches the library.
- `MultiAssetBasicVaultRepo._reserveOfToken` returns a stored mapping value, 0 for an unknown token, and does not revert `UnknownReserve`. Reserves are whatever the family writes. Insertion-order `AddressSet._add` preserves `[C0, C1]`.
- Wings is the wrong economic template. Its package rejects `currency0 == address(0)`, registers a USAGE fee type, and sets share decimals from the target token. Its money path returns early when `manager.isUnlocked()` (`UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol` 96-102). Its SY `exchangeRate()` returns `1e18` at zero supply. Stage one must not copy those.
- Deadline precedent, if reused, is inclusive: Wings reverts only when `deadline_ < block.timestamp` (same file, line 45), with `IStandardExchangeErrors.DeadlineExceeded`.
- Baseline swap limits are the canonical extremes: `4295128740` and `1461446703485210103287273052203988822378723970341` (`PairToken.sol` 54-55), equal to port `TickMath.MIN_SQRT_PRICE + 1` and `MAX_SQRT_PRICE - 1`.
- `Proxy.receive()` accepts ETH and does not delegatecall. `fallback()` does. Empty-calldata ETH never enters a facet.

Not read: peer files, earlier councils, an implementation plan, or an audit. No tests, builds, or Git. `PairTokenMath.T` was not coefficient-diffed against `TickMath.getSqrtPriceAtTick`; the first coefficient matches the Uniswap constant, which is not a proof of identity. Wings was read as packaging and for the sleeve, deadline, and empty-supply rate traps, not as economic authority.

The document is not ready to implement. Two economic algorithms are still open (zap attribution, and the rate's scale), and several draft rules contradict the sources they cite. Those are below, blockers first.

## Recommendations

### R1. Decide zap attribution before coding

1. S1-OP-02, S1-X12's neighboring entry path, S1-A15, and section 11 item 4. Baseline: `zapDeposit` at `PairToken.sol` 239-273 and `_deploy` / `_add` at 505-545.
2. Source observation.
3. Baseline shares equal `min(used0 * S / R0, used1 * S / R1)`, where `used0`/`used1` are the amounts consumed by adding liquidity against all idle after the swap, not the zapper's incremental tokens. Incumbent idle can be deployed and credited to the zapper. Unspent zap input stays in the contract. The PRD keeps that formula, then says comparative tests must report unacceptable transfer as a blocking product finding and forbids a silent formula change. That leaves the core issuance rule to be discovered during coding. S1-D03 confirmed ownership logic, not this bug. It is not one of the eight settled choices.
4. Owner chooses one of the Q1 alternatives. If the choice is incremental attribution, replace the S1-OP-02 share step with this rule, and delete the "report later" sentence:
   - Compound and snapshot `S`, `R0`, `R1` with the pending input excluded. Require all three nonzero.
   - Hold the received input in an operation-private inventory. Do not book it before the swap and add.
   - Swap `floor(received / 2)` from that private inventory only, using the baseline extreme limits. Tick movement is `abs(tickAfter - tickBefore)` of that swap only. Revert when movement is strictly greater than `maxZapTickMove`. Equality is allowed. A partial fill of this entry swap is allowed.
   - Add liquidity with `Fit` on the private inventory only. Incumbent booked idle is not an input to this add.
   - `deployed0`/`deployed1` are amounts taken from the private inventory. Shares are `min(floor(deployed0 * S / R0), floor(deployed1 * S / R1))`. Reject zero. Mint that amount.
   - Private remainder is then booked idle, mints nothing, and is not refunded.
   - Do not use the name `used0` for both accepted paired input and deployed zap amounts. Call them `accepted0` and `deployed0`.
5. Owner choice. The wording above is the recommendation only if the owner picks incremental attribution.
6. Incremental attribution can mint fewer shares than baseline when idle is imbalanced, and the zapper still donates unspent input to the basket. Freezing baseline is simpler and preserves a known incumbent-to-zapper transfer. Confidence high that the baseline formula has this effect. Confidence high that the PRD currently postpones the decision.

### R2. Make the SY rate match the interface identity

1. S1-QUOTE-02 and S1-A32/A33. Interface notice: `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol` lines 108-112. Wings trap: `UniswapV4UpperLowerWingsStandardExchangeVaultSYTarget.exchangeRate` returns `1e18` at zero supply.
2. Source observation, plus inference on the second interface sentence.
3. The interface says `exchangeRate * syBalance / 1e18` must be the asset balance. The PRD formula `Vraw * 10^18 * 10^18 / (S * 10^d)` does that only when `d == 18`. For a 6-decimal rate asset it is `10^12` too large. The second interface sentence, which would mint shares from the rate, contradicts the first and contradicts S1-QUOTE-02's own ban on using the rate for issuance. Wings' nonzero formula `value * 1e18 / supply` satisfies the first sentence; its zero-supply `1e18` must not be copied.
4. Replace the formula with: `exchangeRate = floor(Vraw * 10^18 / S)` by overflow-safe full-precision division, in the rate asset's raw units per `10^18` share wei. At `S == 0`, return 0. `assetInfo` reports `TOKEN`, the configured ERC-20 face, and that face's actual decimals. No metadata call to `address(0)`. A native leg uses the wrapped face and wei. `Vraw` is removable principal plus booked idle plus uncollected position fee growth, each once, at the current sqrt price, without simulating a sale and without running the compound swap. This rate is not an input to S1-ACC-02 or S1-OP-02. Ignore the interface's second sentence. Do not install `IRateProvider`.
5. Owner confirmation of a technical correction. The written formula is an author proposal that breaks the cited interface.
6. Consumers that expected a always-18-decimal WAD number must use `assetInfo.decimals` instead. Confidence high.

### R3. Store the registry's sorted contents id

1. S1-ARCH-05, S1-NATIVE-01, S1-A01, S1-A07. Registry: `VaultRegistryVaultQueryTarget.calcContentsId` and `vaultsOfTokens` sort ascending, then `abi.encode(...)._hash()`. `_hash(bytes)` is keccak256 of the payload (`BetterEfficientHashLib.sol` 734-740). `BetterAddress._sort` is ascending. Registration indexes `vaultConfig.contentsId` as stored (`VaultRegistryVaultRepo._registerVault`).
2. Source observation.
3. For two ERC-20 pools, PoolKey order is already sorted, so the bug is hidden. For a native pool, `C0` is the wrapper and can sort above `C1`. `keccak256(abi.encode([C0, C1]))` then disagrees with `calcContentsId`. `vaultsOfTokens` and type/package pair lookups miss the vault. `vaultsOfToken` on each face still works. S1-P02 makes the unsorted case the native case, not an edge.
4. Set `contentsId` to `keccak256(abi.encode(address-sorted [C0, C1]))`, equal to `calcContentsId(faces)`. Keep `vaultTokens()` and `reserves()` in PoolKey face order so index `i` is the same face. Do not index `address(0)` in the registry. Pair discovery uses the sorted contents id. Single-face discovery uses each ERC-20 face. Unknown `reserveOfToken` returns 0, matching the repo, and does not revert `UnknownReserve`.
5. Technical correction.
6. A consumer that hashes `vaultTokens()` without sorting will still be wrong on native pools; the registry query is the canonical pair key. Confidence high.

### R4. Basket principal must equal manager removal, including interior

1. S1-X13, S1-ACC-01, S1-A45. Baseline `basket()` uses unclamped `PairTokenMath.A0down` / `A1down` plus raw idle (`PairToken.sol` 175-185). `Fit` clamps (`PairTokenMath.sol` 99-110). Port clamp constants are `TickMath.sol` 29-31.
2. Source observation. Whether `PairTokenMath.T` equals `TickMath.getSqrtPriceAtTick` for every tick is unverified.
3. "Match removable principal" and "preserve interior PairToken rounding" cannot both be requirements if those formulas differ from the manager. Issuance and redemption that use a basket the manager will not pay mis-allocate shares. S1-A45 only forces the boundary case, so an interior mismatch can pass the matrix.
4. Define principal as the token amounts a full removal of owned liquidity would pay at the current sqrt price, using the port's clamped V4 amount math (`TickMath` bounds, floor amounts owed to the position). Add booked idle after that. Do not use `PairTokenMath.T` for inventory. Where baseline interior math differs, record an intentional deviation. Extend S1-A45 to at least one interior price, both boundaries, and a price outside the usable range. Addition sizing must use the same canonical floor liquidity-for-amounts function so requested liquidity cannot exceed what the manager will consume. A one-unit shortfall versus `PairTokenMath.Fit` is acceptable leftover idle, not a revert.
5. Technical correction. The owner asked for ownership of the real position, not for a second rounding system.
6. Comparative tests against baseline will diverge at boundaries and possibly interior. That divergence is the point of S1-X13. Confidence high on the contradiction. Confidence medium on how often `PairTokenMath` already matches the port.

### R5. Write the preview model, and do not let the step cap be an accident

1. S1-QUOTE-01, S1-X08, S1-A27, S1-A28. Baseline `previewDeposit` / `previewRedeem` do not compound (`PairToken.sol` 187-203).
2. Source observation for the baseline gap. Inference for simulator feasibility.
3. S1-X08 correctly requires execution-equivalent previews. The PRD does not define a step, the fee source, whether the vault's own liquidity is already in the tick data, or how removal is subtracted before an exit sale. "512" is explicitly proposed, but execution must refuse the same domain. That is a new restriction on baseline-completable swaps and it is not in the deviation register. Exact parity is feasible only if preview and execution share one V4 math model. A one-wei simulator miss fails S1-A27 on every path.
4. Add a deviation row: execution and preview reject a plan whose simulated swap steps exceed the cap, even if the manager could finish it. Define a step as one `SwapMath.computeSwapStep`. The cap is the sum across every simulated swap in that preview, default only if Q3 confirms 512. Simulator rules:
   - Read pool fee from slot0. Static key fee is the validation constraint, not a second fee.
   - Project fee collection into booked idle, then the ratio swap, then the liquidity add, on a copied state. Do not write storage and do not call `unlock`.
   - The position's liquidity is already in pool tick state. After a simulated removal, subtract that liquidity from in-range active liquidity before the exit swap.
   - Fees generated by the compound swap itself stay uncollected and are outside the issuance snapshot. See R6.
   - Valid-token failure, including an unsellable exit, reverts the same error as execution. Invalid-token SY previews still return 0.
   - Exhaustion reverts `QuoteWorkExceeded(steps, limit)` in both preview and execution. Never return a partial quote.
   - Preflight that plan before any ERC-20 pull or liquidity add. Native `msg.value` stays reserved and is excluded from the book. Revert undoes it. Do not forward ETH before preflight succeeds.
5. The cap number is an owner choice (Q3). The simulator rules are a technical correction.
6. A shared model costs code size (S1-A48 already allows a facet split). Capping preview only would break parity. No cap allows unbounded view gas. Confidence high that the model is underspecified. Confidence medium that 512 is the right product number.

### R6. Stop the fee-snapshot contradiction

1. S1-ACC-01's sentence "Uncollected fees are collected or projected before the issuance/redemption snapshot." Baseline `_compound` collects, then swaps (`PairToken.sol` 424-448). The following `basket()` does not include fees created by that swap.
2. Source observation.
3. A literal reading forces a second collection or projection that baseline does not do, and that would change shares. It is not listed as a deviation.
4. Replace that sentence with: the pre-operation compound collects fees accrued before the operation and reinvests under S1-OP-05. Fees created by the compound swap remain uncollected position fees and are not in the issuance or redemption snapshot. `basket()` reports principal plus booked idle and does not claim uncollected fees. Previews report the post-compound snapshot, not `basket()`.
5. Technical correction.
6. Old holders keep the compound-swap fee growth on old liquidity. That is baseline behavior, not a new fee. Confidence high.

### R7. Define booked idle as the only compound input

1. S1-OP-05, S1-X09, S1-ACC-04, S1-A38. Baseline `_idle` is raw balance minus native reservation (`PairToken.sol` 370-372). `DUST` is 1000 (line 50). The trigger is strictly `>` (line 443).
2. Source observation.
3. "Eligible idle" is undefined. If compound uses raw balances, unbooked pretransfers and unsolicited ETH are absorbed, which S1-A38 forbids. Collected fees arrive as raw tokens and will be lost from the shareholder book unless credited first.
4. Specify the engine:
   - Credit collected fees to booked raw-currency reserves before the dust test. Native fees are wei, credited once.
   - Dust test and ratio swap read booked idle only. Unbooked balances are excluded.
   - Trigger only when booked idle is strictly greater than 1000. Equality does not swap or add.
   - Leftover value is `floor(floor(leftover0 * P / 2^96) * P / 2^96)`. Tie (`value0 >= leftover1`) sells token0. Swap amount is `floor(leftover / 2)`, then `min` with `floor(floor(activeReserve * maxZapBps / 10000) / 4)`.
   - If leftover is at most 1000, or active liquidity is 0, or the cap is 0, swap amount is 0, but the deploy still adds affordable booked liquidity.
   - No protocol split, no fee-manager call, no share mint or burn.
   - Family compound event has `fees0`, `fees1`, `liquidityAdded`, and residual booked idle. No zeroed protocol fields.
5. Technical correction.
6. Booked accounting is extra storage and must be updated on every manager delta. That is the cost of S1-X09. Confidence high.

### R8. Native receipt, refund, and backing must match the proxy

1. S1-NATIVE-01, S1-OP-01, S1-A49 through S1-A55. `lib/crane/contracts/proxies/Proxy.sol` `receive()` is empty and does not delegate. Wings `_requireBalance` calls `balanceOf` (`Money.sol` 60-64), which cannot be used on `address(0)`.
2. Source observation.
3. A facet `receive()` will not run for WETH withdraw or PoolManager native `take`. Implementers who book donations there will book nothing. A backing check that calls ERC-20 on address zero will revert or lie. Paired refund and zap no-refund are easy to mix.
4. Add this rule:
   - Empty-calldata ETH is accepted by the proxy and changes only `address(this).balance`. Accounting is done by the operation that expected the receipt, by measuring the wei delta. A facet receive is not the receipt path.
   - Booked native is wei under the raw currency `address(0)`, reported 1:1 under the wrapped face. Require the bound wrapper's `decimals()` be 18. Reject a native/wrapper collision. Never call ERC-20 methods on address zero.
   - Backing invariant for the native leg is `address(this).balance >= bookedEth + reservedEth`. ERC-20 legs use `balanceOf >= booked`. Temporary WETH during wrap or unwrap is not a second reserve.
   - Paired native entry requires `msg.value == amount0Max`, reserves it before compound, and refunds `amount0Max - accepted0` to `msg.sender` after the guard is still held. Refund failure reverts the whole operation. Two-ERC-20 pools require zero value.
   - Single-token native or wrapped entry does not refund unspent input. Unspent input is booked once.
   - Wrapped donation or wrapped SE input unwraps and credits the observed ETH increase once. Require that increase equal the unwrapped amount.
   - Outbound ETH uses a checked call with all remaining gas, still inside the operation guard. No 2300 stipend.
   - Standard SE selectors stay nonpayable and reject `address(0)`. Native single-token entry and exit are the payable SY and paired methods.
5. Technical correction. Native support itself is already confirmed.
6. Wrapper decimal enforcement rejects a non-18 wrapper. That is intended. Confidence high.

### R9. Pin the paired ABI, burn order, and error table

1. S1-OP-01, S1-OP-03, S1-ACC-03, S1-OBS-01, S1-A06. Baseline paired burn is `msg.sender` only, before `unlock` (`PairToken.sol` 406-418). No deadline exists on baseline entry.
2. Source observation for baseline. The PRD names methods but does not pin selectors.
3. S1-A06 cannot be tested until selectors exist. "Valid holder authority" can be read as allowance, vault-held shares, or caller-only. Burn-after-swap lets callbacks observe the old supply.
4. Adopt this ABI and these rules. Paired methods have no pretransfer flag and burn or pull only the caller's assets. No allowance spend on `redeemPair`.
   - `depositPair(uint256 amount0Max, uint256 amount1Max, uint256 minShares, address recipient, uint256 deadline) external payable returns (uint256 shares)`
   - `previewDepositPair(uint256 amount0Max, uint256 amount1Max) external view returns (uint256 shares, uint256 accepted0, uint256 accepted1)`
   - `redeemPair(uint256 shares, uint256 min0, uint256 min1, address recipient, uint256 deadline) external returns (uint256 amount0, uint256 amount1)`
   - `previewRedeemPair(uint256 shares) external view returns (uint256 amount0, uint256 amount1)`
   - `donate(address token, uint256 amount) external payable`
   - `compound() external returns (uint256 fees0, uint256 fees1)`
   - Snapshot `S`, `L`, `B0`, `B1`, then burn, then manager removal. Idle allocation uses the snapshot. `floor(L * S / S) = L` and the same for booked balances, so a full paired exit empties the owned position and booked basket.
   - Deadline check matches Wings: revert `DeadlineExceeded` when `deadline < block.timestamp`.
   - Pulls require exact received amount or revert `TransferDeltaInsufficient`. Do not mint quote shares against a short pull. This is a named deviation from baseline `_pull` overwriting the amount and still minting.
   - One-sided positive-supply issuance pulls the full specified amount of the live leg. It does not ceiling-trim that leg.
   - Reject zero amount, zero recipient, and diamond-self mint or payout recipients.
   - Exit sale is exact-input of the full unwanted allocation, same extreme limits, no liquidity add. Revert unless the manager's input delta consumes that entire allocation. Entry zap does not use this full-consumption rule.
   - Family events include received input, deployed amounts, minted shares, withdrawal allocations, swap proceeds, and actual payout. No success event on revert.
5. Technical correction.
6. Exact-receipt reverts on fee-on-transfer, which repository law already forbids. S1-A44 should expect that revert, using a harness token, not a successful short mint. Confidence high.

### R10. Route errors and interface IDs

1. S1-API-02, S1-API-03, S1-P03, S1-A25, S1-A26, S1-A29. `IStandardExchangeErrors` has `InvalidRoute`, `RouteNotSupported`, `MinAmountNotMet`, and `DeadlineExceeded`. `ExchangeInNotAvailable` exists on the In interface. ERC-165 does not infer a combined interface id.
2. Source observation.
3. "Unsupported routes reject" is not a testable error. Registering In and Out does not make `supportsInterface(IStandardExchange)` true. SY invalid-token preview returns 0; a valid token that cannot execute must not.
4. Use this table:
   - Installed exact-output selectors, including their previews: `ExchangeOutNotAvailable()`, before any transfer or manager call.
   - Unsupported exact-input pair, including currency-to-currency, share-to-share, and `address(0)` on standard SE: `InvalidRoute`.
   - Supported zap while supply or either reserve is zero: `ExchangeInNotAvailable()`.
   - Unmet SE minimum: `MinAmountNotMet`.
   - Disabled issuance: a family `IssuanceDisabled` after the registry `isDisabled` check. Exits and in-exit compound do not use that revert.
   - Register `type(IStandardExchange).interfaceId` explicitly, plus `IStandardExchangeIn`, `IStandardExchangeOut`, `IStandardizedYield`, `IBasicVault`, `IStandardVault`, and the family interface. SY `facetFuncs` must not repeat the 20 shared selectors.
   - `vaultTypes()` is that deduplicated package-owned set. Zero `vaultFeeTypeIds`. Bind a deployed fee oracle because `StandardVaultRepo` stores one, and never call it.
   - Do not bind Permit2. No reused initializer requires it.
5. Technical correction.
6. `ExchangeInNotAvailable` for empty-supply zap is a product signal, not a fake exact-output rejection. Confidence high.

### R11. Pool-key validation numbers

1. S1-ARCH-03 and S1-A03. Port: `PoolKey.fee` comment and `LPFeeLibrary.DYNAMIC_FEE_FLAG = 0x800000`, `MAX_LP_FEE = 1000000`. Baseline tick bounds: `PairToken.initialize` lines 131-132. Wings rejects native and `fee > 1_000_000`.
2. Source observation.
3. "Static pool fee" and "legal positive tick spacing" are not enough for a preview that must know the fee. Dynamic fee is `0x800000`, which is already above `MAX_LP_FEE`. Zero fee is valid. Unsorted ERC-20 keys will not be the initialized pool.
4. Reject unless `currency0 < currency1` (address zero allowed only as currency0), both nonzero currencies have code, currency1 is nonzero, hook is zero, `0 < tickSpacing <= 32767`, `fee <= 1_000_000`, slot0 sqrt price is nonzero, and neither currency nor the wrapper nor `rateAsset` is the diamond. Full-range ticks are `(int24(-887272) / tickSpacing) * tickSpacing` and the positive counterpart, salt `bytes32(0)`. `maxZapBps` is an integer in `1..10000`. `maxZapTickMove` is a nonnegative int24. No silent defaults. `calcSalt` is `keccak256(abi.encode(PkgArgs))` over every instance field. Do not hash the package address again; the factory already does.
5. Technical correction.
6. Rejecting dynamic fees and hooks is what makes R5's simulator honest. A later dynamic-fee pool is out of scope. Confidence high.

### R12. Callback commitment and the unlocked-manager reject

1. S1-X11, S1-SEC-01, S1-OP-05, S1-A39, S1-A40. Baseline callback checks only `msg.sender == poolManager` (`PairToken.sol` 314-332). Wings skips pool work when `isUnlocked()` is true.
2. Source observation.
3. "Payload commitment" is not defined, so replay tests have nothing to assert. Copying the Wings early return would execute against local balances while the manager is unlocked, which the PRD forbids but does not replace with a predicate.
4. Before any `unlock`, if `poolManager.isUnlocked()` revert `ManagerAlreadyUnlocked`. Do not fall back to local balances. Store `keccak256(abi.encode(operation, payload))` plus an active flag before `unlock`. The callback must match manager, flag, and hash, then clear the hash before it returns. Reject a second callback in the same operation. The cross-facet guard lives in family repo storage and stays set through payout and refund. Economic views (`basket`, reserves, quotes, rate) revert while the guard is set. ERC-20 and permit views stay available.
5. Technical correction.
6. The vault cannot be called while any other pool holds the same manager unlocked. V4 would revert on nested `unlock` anyway. The explicit error is what S1-A40 asks for. Confidence high.

### R13. Do not let later gates reopen settled ownership

1. Section 11 item 4, S1-A46, S1-D03. Baseline first-depositor protection is the 1,000 dead shares, which the owner removed.
2. Source observation, plus inference.
3. A one-share genesis plus a later donation inflates the share price. That is a consequence of the confirmed no-dead-share choice, not an undecided formula. S1-A46 tells the implementer to measure it and not to treat it as an oracle defense. It should not be readable as permission to add virtual shares during coding.
4. Add one sentence to section 11: donation after a small genesis is an accepted residual of S1-D03. A46 records the measured gain or loss. It does not authorize dead shares, virtual liquidity, or a formula change. Unsolicited balances stay unbooked forever, including across restart. No rescue, and `donate` does not sweep them.
5. Technical clarification of a confirmed choice. Permanent stuck dust is the author's current rule; Q5 asks the owner to accept it explicitly.
6. Inflation remains possible. That is the trade-off the owner already made. Confidence high.

## Owner clarification questions

1. Zap shares when incumbent idle exists.
   - A. Freeze the baseline deployed-amount formula. A15 is a disclosure measurement. Delete the blocking-finding sentence in S1-OP-02 and section 11 item 4.
   - B. Adopt the R1 private-inventory rule before implementation. Incumbent idle cannot increase the zapper's shares. Unspent zap input is still booked and not refunded.
   - C. Stage one is paired entry and paired exit only. Single-token zap waits.
   - Recommendation: B. A known incumbent-to-zapper credit should not be both "the algorithm" and a completion blocker.

2. `exchangeRate` scale.
   - A. `floor(Vraw * 10^18 / S)` in raw rate-asset units per `10^18` share wei. Zero at zero supply. Decimals live in `assetInfo`.
   - B. Keep the PRD's extra `10^18 / 10^d` WAD scaling.
   - Recommendation: A. B breaks `IStandardizedYield` for non-18 assets.

3. Preview step cap and execution domain.
   - A. Cap is 512 `computeSwapStep` iterations, summed across the preview's swaps. Preview and execution both revert past it.
   - B. Cap preview only. Execution follows the manager even when the preview cannot.
   - C. Raise or remove the cap.
   - Recommendation: A, if 512 is an accepted product limit rather than a placeholder. B breaks S1-A27 and S1-A28.

4. What a disabled vault may still do.
   - A. Reject paired, SE, and SY issuance, and reject `donate`. Allow public `compound` and every exit. In-exit compound always runs.
   - B. Also reject public `compound`. Only the compound inside an exit runs.
   - C. Allow `donate` while disabled.
   - Recommendation: A. Donation is new value in. Compound does not issue shares and keeps exits live.

5. Permanently stuck unsolicited balances.
   - A. Accept it. No rescue and no later sweep.
   - B. Add a permissionless no-mint adopt of unbooked balances after supply is positive.
   - Recommendation: A. B is a second donation path and is not needed for stage one.

Canonical SY internal-balance redemption lets any bytecode caller burn vault-held shares. That is what the shared target does. Keep it, and say so on the family interface. Do not treat resting shares as escrow. This is not a new question unless the owner wants to abandon that canonical rule.

## Assumptions and limits

- Draft normative language is not owner approval. The eight confirmed choices were treated as closed.
- No runtime proof, no exploit procedure, and no claim that the baseline or the PRD is safe.
- `PairTokenMath` versus port V4 math was not fully identified. R4 therefore prefers manager-equal amounts over an unverified claim that interior rounding already matches.
- Factory salt combination and registry sort/hash were read. Every Wings economic function was not.
- Exact route attestation is the assigned task route, not a wire capture.
- Assigned file was not written: `docs/research/pairtoken-se-stage-one-council-20261028-01a1810f/members/grok/response.md`. `apply_patch` is unavailable. This message is the complete initial response.
