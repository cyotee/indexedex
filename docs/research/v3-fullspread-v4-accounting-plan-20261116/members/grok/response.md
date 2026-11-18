# Member response

## Identity

- Run ID: v3-fullspread-v4-accounting-plan-20261116
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/v3-fullspread-v4-accounting-plan-20261116/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:high
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

This contribution does not authorize implementation.

## Question and targets

- Question: What ordered implementation and test plan must a later author follow so the Uniswap V3 full-spread Standard Exchange vault under contracts/vaults/standard/exchange/protocols/uniswap/v3/ satisfies the locked PRD, including the owner locks that the empty position NFT is burned and that import may run after supply exists?
- Required targets: docs/research/v3-fullspread-v4-accounting-prd-20261116/UNISWAP_V3_FULL_SPREAD_V4_ACCOUNTING_PRD.md, including V3-OWN-01 through V3-OWN-05; the governed vault under contracts/vaults/standard/exchange/protocols/uniswap/v3/; the V4 full-spread vault under contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/, including UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md
- Optional context: docs/research/v3-fullspread-v4-accounting-prd-20261116/ member responses. Not read. The locked PRD wins.
- Admitted read scope: the brief, the required targets, and the optional context. No public query was used.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Question, locks, owned path | docs/research/v3-fullspread-v4-accounting-plan-20261116/brief.md | coordinator-supplied | Import stays; burn the empty NFT; import may run after supply; donate and compound follow locked V4 rules; additional V4 selectors go on new facets; no unlockCallback; new vaults only; do not edit contracts/protocols/dexes/uniswap/v3/; no IStandardizedYield, exchangeRate, assetInfo, quoteAssets, or vault getRate; keep previewExchangeIn. Gas bar is the V4 plan's 12,000,000 transaction ceiling and 5,000,000 preview ceiling unless that plan states a different current ceiling. |
| Locked requirements | docs/research/v3-fullspread-v4-accounting-prd-20261116/UNISWAP_V3_FULL_SPREAD_V4_ACCOUNTING_PRD.md | source observation | V3-ACC-01 through V3-ACC-20 and V3-OWN-01 through V3-OWN-05 were read. The PRD does not authorize implementation. It names selectors and retired helpers. It does not name the new facet filenames, the booked-storage file, or a test filename. |
| Gas ceilings | contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md, section 2 | source observation | "Gas ceilings stay 12,000,000 and 5,000,000." The same sentence says a standalone public money or maintenance call passes only if its cold call body is at most 11,900,000, leaving 100,000 overhead; fixture setup stays outside that body; do not warm the measurement with a preview; a composed hook route passes only if the whole transaction is at most 12,000,000; previews fit 5,000,000; an oversized route is unresolved, not passed; there is no getRate read. Section 13 names seven standalone routes and excludes setOperator and setOperatorFor. This is not a different ceiling from 12,000,000 and 5,000,000. |
| V4 floor mint call | contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol, `_mint` | source observation | The inspected V4 execution calls `ERC20Repo._mint(address(0), Types.MIN_SHARES)` when `plan_.mintFloor` is set. The V3 PRD forbids that path. |
| V4 floor lock | contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md, FS-OWN-11 | source observation | The balance requirement is 1,000 at address(0), included in totalSupply, and the mint must not revert. That lock says to use the Crane repo helper that writes balanceOf and totalSupply directly, and not to use `ERC20Repo._increaseBalanceOf` or the shared ERC-20 facet path, because both revert `ERC20InvalidReceiver` for address(0). |
| Donate, compound, fee, deadline, exit | same V4 PRD, FS-OWN-14, FS-OWN-21, FS-OWN-24, FS-OWN-26, FS-OWN-28, FS-OWN-30, FS-OWN-32, FS-OWN-33 | source observation | These are the locks V3-OWN-02 and the V3-ACC copies name. DeadlineExceeded is before disable on a route that takes deadline. Donation() and Compounded() have no arguments. Bundle minima use MinAmountNotMetAt. A donation or compound remainder is booked, not refunded. |
| V4 selector shapes | contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol | source observation | donate(address,uint256,bool), compound(), setOperator(address,bool), setOperatorFor(bytes4,address,bool). Bundle-in preview and execution return (uint256 amountOut, uint256[] amountsRefunded). Bundle-out preview and execution return (uint256[] amountsOut, uint256 amountRefunded). |
| V4 reserves read | contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQueryTarget.sol | source observation | reserveOfToken and reserves return position amount plus unpaid fee for each face. An unknown token returns zero. |
| Current import | contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol | source observation | previewImportPosition returns one word. importPosition reverts UniswapV3ExchangeImport_Unavailable when totalSupply is not zero or the position record is created. The contract comment says the empty NFT is left on the vault. The function collects through decreaseLiquidity and collect, then mints with `_sharesOutForDeposit`, `DEAD_SHARES_SINK`, `_minimumLiquidity`, and `_initialResidualShares`, then the caller rebalances. It does not call burn. It does not transfer an overage to recipient. |
| NPM burn | lib/crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol, the interface the import target already imports | source observation | `burn(uint256 tokenId)` is exposed. Its notice says the token must have 0 liquidity and all tokens must be collected first. |
| Current one-token route | UniswapV3FullSpreadStandardExchangeVaultInTarget.sol and InBase.sol | source observation | exchangeIn already returns (uint256 amountOut, uint256 amountRefunded) and hardcodes the refund word to 0. Share mint uses constant-product helpers, mints the dead-sink floor and residual, and on a locked pool emits LocalDepositWhileBlocked instead of reverting. Pass-through calls `_rebalanceLiquidReserveBestEffort`. Disable is checked before deadline on a non-share input. |
| Current preview | UniswapV3FullSpreadStandardExchangeVaultInMultiQueryTarget.sol | source observation | previewExchangeIn is installed here, not on the in-query facet, and also hardcodes the refund word to 0. The same facet installs previewExchangeInManyToOne. |
| Current exact-out and SY | UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol, OutExecuteTarget.sol, YieldExecutionTarget.sol, DFPkg facetInterfaces | source observation | previewExchangeOut quotes swaps and zaps, and reverts BoundPoolInteractionBlocked when the pool is locked. exchangeRate, assetInfo, yieldToken, getTokensIn, and getTokensOut are implemented. exchangeOut executes exact-out swap, exact-out withdrawal, and exact-out mint. The yield target redeems vault-held shares. The package advertises IStandardizedYield. |
| Current reserves snapshot | UniswapV3FullSpreadStandardExchangeVaultCommon.sol `_syncVaultReserves`; contracts/vaults/basic/MultiAssetBasicVaultTarget.sol; MultiAssetBasicVaultRepo.sol | source observation | No reserves() or reserveOfToken function exists in the governed V3 directory. The package installs the basic-vault facet, whose reserves read a repo mapping. `_syncVaultReserves` writes each token's balanceOf, including the share token, into that mapping. |
| Usage fee key | UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol `vaultFeeTypeIds` | source observation | USAGE is inserted with `type(IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve).interfaceId`. `usageFeeOfVault(address)` exists on contracts/interfaces/IVaultFeeOracleQuery.sol. |
| Sleeve surface | Liquid reserve facet, target interface, and Common | source observation | The facet installs canOpenBoundPoolOps, localReserve, deployedReserve, targetLiquidReservePercentage, actualLiquidReservePercentage, and rebalanceLiquidReserve. Common defines DEAD_SHARES_SINK, the 5% deadband, `_sharesOutForDeposit`, `_minimumLiquidity`, `_initialResidualShares`, `_collectIfIdle`, and both rebalance helpers. canOpenBoundPoolOps is `pool.slot0().unlocked`. |
| Position storage | UniswapV3FullSpreadStandardExchangeVaultRepo.sol | source observation | Storage is one center position: tickLower, tickUpper, created. The slot string is `indexedex.protocols.dexes.uniswap.v3.vault`. There is no booked array. |
| Callbacks | UniswapV3FullSpreadStandardExchangeVaultInFacet.sol and Common | source observation | The in facet installs exchangeIn, uniswapV3MintCallback, and uniswapV3SwapCallback. The callbacks transfer the amount the pool asks for from the vault balance. No unlockCallback is installed. |
| Tests that call the retired surface | release/v3 import and facet tests, release/sy NativeSY test, adversarial base, SeMatrix_FullSpreadV3Fixture.sol, StandardExchangeStages.t.sol | source observation | These files were not read in full. Search shows they call importPosition, previewImportPosition, rebalanceLiquidReserve, deployedReserve, the liquid-reserve interface id, or the V3 package. |

Public query: not used.

## Assumptions

- The 11,900,000 cold-body figure is the V4 plan's measurement method inside the 12,000,000 ceiling, not a different current ceiling. The brief says to adopt a different ceiling only if that plan states one. It does not.
- A copied V4 lock applies only where the V3 PRD names that copy. FS-OWN-13, unlock, borrowed unlock, native substitution, and hook LP formulas are not copied.
- The Crane helper that writes balanceOf and totalSupply directly was not opened. V3-ACC-03 requires a non-reverting address(0) write and forbids `ERC20Repo._mint`. The helper's name is not a requirement this response can add.
- Live files can change. This response is not an atomic snapshot.
- No assumption replaces an unread required target. The optional earlier council was not needed once the locked PRD was read.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| brief.md | required by the assignment | examined | Followed for question, locks, owned path, and gas instruction. |
| Locked PRD, including V3-OWN-01 through V3-OWN-05 | required | examined | Read through publication. |
| Governed V3 vault tree | required | partially examined | Every file was listed. Import, repo, in target, in-multi query, out query, yield target, and the liquid-reserve interface were read. Common, in base, out execute, and DFPkg were read at the share, sleeve, cut, and reserve sites. Out-multi, liquid-reserve target, in-query body, and execution delegates were not read line by line. Their selectors and the calls that reach them were observed. |
| V4 full-spread vault code | required | partially examined | Interface, query target, and the execution floor mint were read. Money target, planner, and math were searched for donate, compound, operator, and floor symbols, not read line by line. |
| V4 implementation and test plan | required | partially examined | Sections 1 through 11 and 13 through 16 were read, including the gas sentence and the seven-route list. Section 12 hook-row detail was not read line by line. V3-ACC-01 does not adopt those hook formulas. |
| V4 PRD locks named by the V3 PRD | required as the behavior source the V3 PRD copies | partially examined | FS-OWN-11, FS-OWN-14, FS-OWN-21, FS-OWN-24, FS-OWN-26, FS-OWN-28, FS-OWN-30, FS-OWN-32, and FS-OWN-33 were read. The rest of that PRD was not. |
| Earlier council member responses | optional | not examined | Locked PRD wins. They are not a vote. |
| contracts/protocols/dexes/uniswap/v3/ | not a target | not examined | V3-OWN-04 forbids editing it. This plan does not read it in order to port it. |

## Conclusions

Agreement is not available. Peers were not read. This is one ordered plan. It is not a second PRD. It writes no Solidity.

The PRD does not sequence the work. The order below is a plan choice except where a later step cannot be true without an earlier one. Those dependencies are named. A filename the PRD does not name is a plan choice. The behavior each step must satisfy is not.

Do not start the edits this plan describes until a later owner instruction authorizes implementation. This file does not give that instruction.

### Step 0. Fence

No file change.

Satisfy V3-ACC-01, V3-OWN-04, and V3-OWN-05 before any edit:

- Edit only the governed tree under contracts/vaults/standard/exchange/protocols/uniswap/v3/, plus the tests in step 10. Do not edit contracts/protocols/dexes/uniswap/v3/.
- New vaults of this implementation only. Do not add a migration of supply, dead-sink shares, sleeve balances, unpaid fees, or imported positions. Do not repoint an existing deployment.
- Pool actions are pool.swap, pool.mint, pool.burn, and pool.collect, paid through the existing uniswapV3MintCallback and uniswapV3SwapCallback. Do not add unlockCallback. Do not call PoolManager unlock. Do not take a borrowed unlock.
- Do not adopt native-currency substitution, a WETH face substitution, hook component formulas, or a vault getRate. Pool tokens remain pool.token0() and pool.token1().
- Do not copy the inspected V4 execution call `ERC20Repo._mint(address(0), MIN_SHARES)`. V3-ACC-03 forbids it.
- Do not reopen import removal, empty-NFT retention, empty-vault-only import, sleeve rebalance as the dust path, local constant-product settlement while the pool is locked, quadraticInput, a searched split, a successful refund of a failed genesis plan, a dead-sink floor, or a NAV rate.

A test that fails if this fence is wrong: a package or facet test that finds unlockCallback, getRate, exchangeRate, assetInfo, quoteAssets, or IStandardizedYield on a newly deployed vault. A diff test is not required. The absence is the assertion.

### Step 1. Booked balances and the non-reverting floor write

Files, all plan choices: extend UniswapV3FullSpreadStandardExchangeVaultRepo.sol rather than adding a second slot. Keep the existing position record and the existing slot string. Add a two-entry booked record in vaultTokens() order, index 0 for token0 and index 1 for token1. Do not index booked by address. V3-OWN-04 makes a migration of old storage unnecessary; extending the struct is safe only because this plan does not migrate old instances.

Behavior:

- V3-ACC-09. The vault accounts separately for deployed position liquidity, accrued but uncollected position fees, booked per-token remainders, and unbooked ERC-20 balances. A booked remainder is a vault record. It is not a reserve, including after donate and compound. Unbooked balances are not reserves and are not redeemable.
- V3-ACC-03. On a successful first add, record balanceOf(address(0)) of 1,000 and include that balance in totalSupply(). The write does not revert. It does not use ERC20Repo._mint, ERC20Repo._increaseBalanceOf, or the shared ERC-20 facet path. The floor is not part of grossShares and is not a fee mint. It is not minted to address(0xdead), from decimals(), or as residual unlike-token weight. Naming the Crane helper that performs the direct write is a plan choice. The non-revert and the resulting balance are not.

Tests that fail if this is wrong:

- After a successful first add, balanceOf(address(0)) is 1,000 and totalSupply includes it. A path that reverts ERC20InvalidReceiver fails this test by reverting.
- A direct token transfer to the vault does not increase reserves() and is not spendable by a later caller's share mint.
- After a fee is booked, reserves() does not include it, and the next user share-minting add does not deploy it.

### Step 2. One sizing engine for preview and execution

File: plan choice. Put the sizing in one library or in Common, and call that same function from preview and execution. Two copies are not allowed by V3-ACC-05, which says preview and execution use the same sizing. Do not leave StandardExchangeConstantProduct calls in this vault. Do not edit that library. Do not add quadraticInput.

This step is a dependency for steps 4, 7, and 8. Doing import or the bundle routes first by copying the add is a plan choice this plan rejects.

Behavior the engine must satisfy:

- V3-ACC-02 and V3-ACC-20. Shares use raw position liquidity, not token reserves, sqrt(x*y), NAV, or decimals(). On an existing supply, grossShares = floor(addedLiquidity * totalSupply / existingLiquidity), with supply and liquidity read before the add. Idle balances, booked remainders, and accrued fees are not in that denominator. On a burn, liquidity removed is floor(positionLiquidity * sharesBurned / supplyBeforeBurn). A later mint can reduce an old holder's booked claim per share. Do not add a stronger per-vintage claim.
- V3-ACC-03. The first liquidity add must exceed 1,000 or the plan fails. A failed genesis plan reverts MinLiquidityNotMet() and mints nothing. That includes a first deposit whose 49% swap cannot be formed, whose output the add cannot consume, or whose added liquidity is at or under 1,000. It is not a successful whole-input refund. On success, grossShares = addedLiquidity - 1,000. The floor write is step 1, not part of grossShares.
- V3-ACC-04. On every share-minting deposit, including the first, take the usage fee from grossShares. Do not mint it on top. Read usageFeeOfVault. If feeTo is not address(0) and the clamped fee is non-zero, feeShares = mulDiv(grossShares, clampedFee, 1e18). Mint feeShares to feeTo and the remainder to the recipient. A fee above 3e17 is used as 3e17. The clamp does not write the oracle. Skip a zero mint. Previews and minima use the depositor's net shares. A pass-through takes no fee. There is no exit fee. The carried disagreement that this vault charges none today is not adopted.
- V3-ACC-05 and V3-ACC-18. Processed input is the amount the call will use after the funding rule, and before the 49% split. An oversized one-token pretransfer has no processed input. When supply is already positive and the current sqrt price is strictly inside the position, run one exact-input pool.swap of floor(processedInput * 49 / 100), with sqrtPriceLimitX96 equal to TickMath.MIN_SQRT_RATIO + 1 or TickMath.MAX_SQRT_RATIO - 1, then pool.mint of the liquidity whose rounded-up amounts consume that swap's entire output and no more than the unswapped input. Do not iterate. Do not solve a closed-form root. Do not walk ticks to find a better split. Do not add maxZapTickMove, a TWAP check, a tighter price limit, or a new fee cap. If that swap amount is zero, cannot be quoted, is not fully spent, receives zero output, or the following mint cannot consume that output, and supply is already positive, refund the whole processed input, execute no swap, and mint nothing. Use no new error. If the caller's minimum is greater than zero, that no-mint result reverts AmountOutNotMet instead of succeeding as a zero output. A first deposit does not use this refund branch.
- V3-ACC-06. If supply is already positive and the sqrt price is not strictly inside the position, including exactly at either boundary, do not swap. If the caller provided the token the position wants, add it with no swap and refund what the add does not take. If the caller provided the other token, refund it and mint nothing. Zero active pool liquidity is not that boundary case. In that established-supply case, refund the whole input and mint nothing. The same minimum rule uses AmountOutNotMet. The zero-active refund does not apply to a wanted-token boundary add and does not override genesis on an empty vault.
- V3-ACC-07. A both-token deposit adds the greatest proportional liquidity supported by the declared amounts at the current pool price. It refunds each token the add does not take. It does not run the 49% swap. This retires the minimum-of-proportions constant-product dual mint.
- V3-ACC-11. Before every share-minting add, snapshot collectable fees attributable to liquidity that already exists. Collect them, including by burn(0) and collect when that is what moves them out of the pool, and book the collected amounts. Do not infer the fee from a combined mint-callback or balance delta. Do not include those fees in the add, the caller's share credit, or a deposit swap. Unpaid fees and booked amounts are mutually exclusive. On a withdrawal, read collectable center fees before the burn. The caller's fee claim is floor(collectableFees * sharesBurned / supplyBeforeBurn) for each token. The caller's booked claim is floor(booked * sharesBurned / supplyBeforeBurn). Leave the rest with the remaining supply. After burn and collect, split the collected tokens by that pre-burn read. Do not use the combined balance delta as the claim. A fee moved from the pool into booked custody is counted once.
- V3-ACC-01. The one position uses TickMath.minUsableTick and TickMath.maxUsableTick at the bound pool's tick spacing. Those bounds are fixed before the first add. No minimum tick spacing is added.

Tests that fail if this is wrong:

- A first add of exactly 1,000 liquidity reverts MinLiquidityNotMet and mints nothing. A first add whose 49% swap cannot be formed does the same. It does not refund as a success.
- A later one-sided mint inside the range swaps 49% once. A test that observes a second swap, a tick walk, or quadraticInput fails the implementation.
- At either boundary, a wanted-token add does not swap. The other token is refunded and mints nothing. Zero active liquidity with positive supply refunds the whole input.
- A both-token add does not swap. Unused input of each token is refunded, not booked.
- Fee shares come out of grossShares. A fee above 3e17 is clamped. feeTo of address(0) mints no fee. The depositor's preview and minimum use net shares. A round trip does not mint an extra fee on top.
- A mint after fees have accrued does not credit those fees to the new depositor. The denominator excludes them. A later mint reduces an old holder's booked claim per share. A test that "fixes" that reduction fails V3-ACC-20.
- An exit pays floor(fee * sharesBurned / supplyBeforeBurn) and floor(booked * sharesBurned / supplyBeforeBurn), multiplied before dividing. Paying the same fee again from a balance delta fails.

### Step 3. Callbacks must not spend booked balances

Files: UniswapV3FullSpreadStandardExchangeVaultCommon.sol, and the in facet that already installs the two callbacks. Which facet holds the callbacks is a plan choice. They must remain. unlockCallback must not be added.

Behavior:

- V3-ACC-01. Keep uniswapV3MintCallback and uniswapV3SwapCallback. The pool must be the caller. Pay the amount the pool asks for through those callbacks.
- V3-ACC-09. A user deposit, a withdrawal, and exchangeIn do not deploy the staying holders' booked balance. The current callbacks transfer from the vault's whole balance. After booked tokens sit in that balance, the operation must be sized so the callback's transfer does not need booked tokens. How that isolation is done is a plan choice: size the mint to the operation's funded unbooked amount, or reserve the operation's spendable amount the way the V4 plan reserves an in-flight amount. Moving booked tokens to another contract is not authorized. The invariant is the requirement.
- V3-ACC-11. Retire `_collectIfIdle` before share math. Collection for a share-minting add is the snapshot-then-book in step 2, not a sweep that changes the share denominator.

Tests that fail if this is wrong:

- Book a known remainder, then run a user share mint and a user exit. The booked balance of the staying holders is unchanged except for the exiting caller's own booked claim.
- A callback from any address other than the bound pool reverts.
- The installed selector set contains the two V3 callbacks and does not contain unlockCallback.

### Step 4. One-token exchangeIn and previewExchangeIn

Files: UniswapV3FullSpreadStandardExchangeVaultInTarget.sol, UniswapV3FullSpreadStandardExchangeVaultInBase.sol, and the facet that installs previewExchangeIn. Today that preview is on the in-multi query facet. If step 9 removes that facet, move previewExchangeIn. The home facet is a plan choice. Losing the selector is not.

The current CREATE3 in and out execution delegates are a plan choice. They may remain only as a code-size split. They must not keep a second economics path. executeZapInMintExactOut and the sleeve zap helpers must not remain callable as accounting.

Behavior:

- V3-ACC-10 and the copied FS-OWN-32 checks. On a route that takes deadline, a missed deadline reverts DeadlineExceeded before any other work, including disable. The current in-target checks disable before deadline. That order fails the copied FS-OWN-26 sentence.
- V3-ACC-16. After that deadline check, a disabled vault reverts VaultDisabled on every execution route except a withdrawal, donate, and compound. A withdrawal is share in and underlying out. A pass-through is not a withdrawal. Views do not revert VaultDisabled. A disabled exchangeOut is step 5.
- Then the copied route checks: tokenIn == tokenOut reverts InvalidRoute; amountIn == 0 reverts EmptyExchange; a zero address or a token that is neither the share nor a face reverts TokenNotExchangeable; recipient of address(0) or this vault reverts InvalidRecipient; a pretransferred caller with no bytecode reverts EOAPretransferNotAllowed. These names come from the copied FS-OWN-32 text, not from a new V3 error family.
- V3-ACC-15. While pool.slot0().unlocked is false, every execution route that must swap, mint, burn, or collect reverts UniswapV3Exchange_BoundPoolInteractionBlocked. It does not fall back to constant-product issuance, `_singleExit`, a local pay, or a V4 unlock. A preview returns the computed result, or zero if the route is unsupported. It does not revert merely because the pool is locked. The current preview reverts on a locked pool for the pass-through quote. That fails V3-ACC-15. slot0.unlocked == true means the V3 pool is idle. That polarity is not V4 isUnlocked. canOpenBoundPoolOps remains only that gate.
- V3-ACC-10. On a pull, pull the declared amount from msg.sender, then refund the unkept amount of that token to msg.sender. Shares or exit output go to recipient. On a one-token pretransfer, process only this call's unbooked credit. If the declared maximum is within that credit, use at most the maximum and refund maximum minus used. If the declared maximum exceeds the unbooked balance, spend none of that balance, mint no shares, and do not pull a shortfall. On an empty vault, that call reverts MinLiquidityNotMet(). On an existing supply, refund the entire unbooked balance. If the caller's minimum is greater than zero, revert AmountOutNotMet instead of returning a zero output. A share-minting deposit's pre-existing fees are booked, not refunded. A one-token exit's unspent opposing residual is neither booked nor kept.
- V3-ACC-12. A one-token exit burns shares the caller holds. Shares merely delivered to the vault are not burn credit. It burns the caller's liquidity fraction and pays recipient the swap proceeds of that holder's opposing claim, the withdrawn requested-token principal, that holder's requested-token fee portion, and that holder's requested booked claim. The opposing claim is that holder's unwanted principal, unwanted fee claim, and unwanted booked claim. It is not the staying holders' inventory. The swap is one exact-input pool.swap of that entire opposing amount, quoted after the liquidity removal, at the same price limit as V3-ACC-05. If that swap cannot spend the entire opposing amount, execution reverts AmountOutNotMet and does not burn shares. The preview of that failed plan does not revert. It returns a zero first word and is not a successful receipt. A completable preview returns the receipt execution will pay, so amountOut matches execution. minAmountOut binds the full receipt.
- V3-ACC-14. An underlying-to-underlying exchangeIn is a pass-through. It mints no shares, takes no usage fee, refunds input the swap does not spend, and does not rebalance. minAmountOut binds the swap output. Remove the trailing rebalance the current pass-through calls.
- V3-ACC-19. previewExchangeIn keeps its current two-word return. The first word is the depositor's net shares on a share-minting route, or the V3-ACC-12 receipt, or zero when that plan cannot spend the opposing amount. The second word is the refund. A mint preview is not the share valuation. The exit preview is the valuation of that operation and is not getRate(). A preview of a refund does not transfer and need not equal the execution refund. That inequality does not waive the exit receipt match.
- V3-ACC-08. Do not emit LocalDepositWhileBlocked. Do not call either rebalance helper after this route.

Tests that fail if this is wrong:

- A missed deadline reverts before VaultDisabled. A disabled pass-through reverts VaultDisabled. A disabled share-in exit still pays.
- exchangeIn's refund word is not hardcoded to 0. A pull refund goes to msg.sender. Output goes to recipient.
- An oversized one-token pretransfer on an empty vault reverts MinLiquidityNotMet. On an existing supply it spends nothing and, if the minimum is positive, reverts AmountOutNotMet.
- A one-token exit whose opposing swap cannot spend the whole opposing amount reverts AmountOutNotMet and does not burn. Its preview returns zero and does not revert. A completable preview's first word equals execution's amountOut from the same state.
- A locked-pool execution reverts UniswapV3Exchange_BoundPoolInteractionBlocked and does not mint shares. The preview of that route does not revert merely because the pool is locked.
- A pass-through mints no shares, takes no fee, and leaves no sleeve move.
- The external rate provider still calls previewExchangeIn. A non-empty call that cannot spend the opposing amount reads a zero rate. An empty-supply call that would not clear the floor reads a zero rate. No test may add a fallback rate or replace a word with NAV to keep the old number.

### Step 5. Fail-closed exact-out, and remove the Standardized Yield surface

Files: UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol, OutQueryTarget.sol, OutFacet, OutQueryFacet, UniswapV3FullSpreadStandardYieldExecutionTarget.sol, and the DFPkg interface list. Deleting the yield file versus making its selectors unreachable is a plan choice. The surface must be gone.

This step can be ordered before or after step 4. That relative order is a plan choice. Both must be done before the package is treated as compliant.

Behavior:

- V3-ACC-17. previewExchangeOut returns zero and does not revert with a vault error, including when the pool is locked. On an enabled vault, exchangeOut reverts ExchangeOutNotAvailable() and moves no tokens. A disabled exchangeOut reverts VaultDisabled. Neither selector gains a refund word. A zero preview is not a promise that execution succeeds. Deadline still precedes disable on exchangeOut, because that route takes deadline.
- V3-OWN-05 and V3-ACC-12. Do not implement IStandardizedYield, exchangeRate(), assetInfo(), quoteAssets, or a named vault-held share redemption. Remove those selectors and the package's IStandardizedYield interface id. A vault-held share burn is not an exit path. Do not add getRate() or rateAsset(). Keep previewExchangeIn.
- V3-ACC-19. A stateful quoteRate that calls quoteAssets will not find that function. That is the surface match. It is not a deletion of previewExchangeIn.

The in-query facet also installs quoteState, quoteShareBalance, quoteTransition, quoteExternalExchange, quoteTotalSupply, quoteExternalDeposit, and captureFrozenQuoteInputs. V3-OWN-05 names quoteAssets, not those other selectors. Removing the unnamed ones is a plan choice under the sentence that this vault matches the V4 surface except for import. Recommended plan choice: remove them, because the V4 query surface is reserveOfToken and reserves, plus the previews this PRD names. Keeping them is the other reading. Do not let that choice reinstall quoteAssets.

Tests that fail if this is wrong:

- Enabled exchangeOut reverts ExchangeOutNotAvailable and moves no tokens. Disabled exchangeOut reverts VaultDisabled. previewExchangeOut returns zero and does not revert.
- supportsInterface for IStandardizedYield is false. exchangeRate, assetInfo, quoteAssets, and a vault-held redeem selector are absent. getRate is absent.
- A share balance sitting on the vault is not burned as the caller's exit credit.

### Step 6. reserves() must stop being the balance snapshot

Files: plan choice. Stop installing reserveOfToken and reserves from the basic-vault facet, and install family implementations. The V4 plan's "install only vaultTokens from the basic facet" is the pattern, not a V3 requirement. The required outcome is V3-ACC-09.

Behavior:

- reserves() and reserveOfToken report deployed token amounts plus unpaid position fees. They do not add a free-balance term, a booked term, or the last-committed snapshot that `_syncVaultReserves` writes. An unknown token returns zero. The two-entry array is in vaultTokens() order.
- deployedReserve, if retained, reports position token amounts and is not a share basis and not a sleeve target. Retaining it is a plan choice. V3-ACC-08 says "if retained". Recommended plan choice: do not retain it, because V3-OWN-05 matches the V4 surface except import, and V4 does not expose it. If it is retained, the adversarial helper that treats it as a sleeve balance must not be an acceptance test.

Tests that fail if this is wrong:

- After a donation is booked, reserves() does not rise by the booked amount. After fees accrue and before collect, reserves() includes the unpaid fees. After those fees are booked, reserves() no longer includes them.
- A direct transfer does not change reserves().
- The callable reserves selector is not the basic-vault snapshot. A test that only reads the repo mapping is not the acceptance test.

### Step 7. New facets for the additional V4 selectors

Files, all plan choices, new under the governed tree:

- one facet and target for exchangeBundleInForSingleOut
- one facet and target for exchangeBundleOut
- one facet and target, or one quote facet, for previewExchangeBundleInForSingleOut and previewExchangeBundleOut
- one facet and target for donate, compound, setOperator, and setOperatorFor

Do not stuff these selectors into the existing one-token in or out facets. That split is V3-OWN-03, not a plan choice. How many new facet files hold them is a plan choice. Matching the V4 money-facet grouping is a plan choice, not a requirement to copy the V4 filenames.

Argument meanings and return words are the V4 meanings observed on IUniswapV4FullSpreadStandardExchangeVault.sol. A requested exact output is not silently a minimum. A maximum share input is not silently an exact share burn. Use the errors declared beside those selectors: AmountsLengthMismatch, ExchangeBundleInForSingleOutNotAvailable, MinAmountNotMetAt, TokenAmountsLengthMismatch, DuplicateOutput, ExchangeBundleOutNotAvailable. Do not declare MinAmountNotMet. Do not add a new error for the bundle over-max revert.

Behavior:

- V3-ACC-07 and V3-OWN-03. previewExchangeBundleInForSingleOut and exchangeBundleInForSingleOut are the both-token deposit. Amounts in, one share amount out, and a refund word for each input. tokenOut must be the share. Emit PairDeposited(address indexed caller) on the execution route, because that event is part of the copied FS-OWN-14 bundle sentence.
- V3-ACC-13 and V3-OWN-03. previewExchangeBundleOut and exchangeBundleOut pay the V3-ACC-12 claim in both tokens and do not swap. Shares burned are the caller's exact-in share amount, from shares the caller holds. The exit is not sized by inverting token reserves. tokensOut are the two faces in either caller order. Emit PairRedeemed(address indexed caller). The preview matches both outputs. A caller minimum fails with MinAmountNotMetAt at the caller's tokensOut index.
- V3-ACC-10. A bundle whose any maximum exceeds that token's unbooked balance reverts before a leg is processed. Spend nothing. Mint nothing. Do not add an error.
- V3-ACC-16. A bundle deposit reverts VaultDisabled when disabled. A bundle exit is a withdrawal and does not. Deadline precedes that check on both, because both take deadline.
- V3-ACC-15. A locked pool reverts UniswapV3Exchange_BoundPoolInteractionBlocked on execution. The preview does not revert merely because the pool is locked.
- V3-OWN-02, copying FS-OWN-14, FS-OWN-21, and the donate and compound sentences of FS-OWN-33. donate(address token, uint256 amount, bool pretransferred) and compound() are added. No deadline and no disable check. The caller is the live feeTo() owner, a global operator, or a function operator for that selector. Store grants in OperableRepo. Do not store feeTo() at initialization as an ownable owner. Do not expose feeTo(). Do not call OperableModifiers.onlyOwnerOrOperator or MultiStepOwnableRepo._onlyOwner. Only the live feeTo() owner may call setOperator and setOperatorFor. The error name for a stranger is a plan choice: use the existing IOperable.NotOperator(address). Do not add a family error.
- donate reverts when totalSupply is zero, before any swap. There is no donation before the first mint. It accepts a vault token or the share. A share donation burns the caller's shares and does not withdraw or swap them. No shares are minted for an underlying donation.
- One-token maintenance uses the 49% shape and books the remainder. Both-token maintenance adds in proportion and does not swap. The scarcer token is the proportionally smaller amount relative to the position ratio, not the smaller raw balance. Book the actual held balance after settlement. If the unpaid fee-owed read is nonzero, collect it with burn(0) and collect before any 49% swap or proportional add. If that read is zero, do not collect only to collect. A failed step reverts. A remainder alone does not. Do not refund a donation or compound remainder. User routes do not call donate or compound. Permissionless rebalanceLiquidReserve is not a substitute.
- compound() with no fees and no booked remainder returns with no state change and no event. A successful donate() emits Donation() with no arguments even when it deposits nothing. Emit Compounded() with no arguments only when a deposit is made from collected fees or booked tokens. A reverting call emits neither.
- V3-ACC-18. A sandwich of an authorized maintenance swap can still sell booked fees or a booked remainder at a moved price. The tests must not claim that exposure is absent.
- V3-ACC-08. These routes do not read liquidReservePercentageOfVault as a target and do not mint or burn to move a free balance toward that target.

Tests that fail if this is wrong:

- A stranger cannot donate, compound, setOperator, or setOperatorFor. A function operator for the other selector cannot. The live feeTo() owner and a global operator can. A disabled vault still allows donate and compound, and still blocks a bundle deposit.
- donate before the first mint reverts and does not swap.
- A one-token donate swaps 49% of the combined one-token maintenance balance and books the remainder. It does not refund that remainder. A both-token maintenance call does not swap.
- An empty compound emits nothing. A donate that deposits nothing emits Donation() and does not emit Compounded(). A donate that deploys booked tokens emits both. A revert emits neither.
- Bundle over-max reverts before either leg moves. Bundle exit burns only the caller's shares and pays both token claims without a swap. The preview matches both outputs.
- A user exchangeIn does not call compound.

### Step 8. Import stays, burns the empty NFT, and may run after supply exists

Files: UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol and the interface in that file. The facet already installs previewImportPosition and importPosition. Keep those selectors. Widening the preview return changes the selector. That widening is required, because V3-OWN-01 says the one-word preview return is not enough. The exact return words are a plan choice constrained by the report: the depositor's net shares and both refunds. Recommended plan choice: net shares, then the two refunds in vaultTokens() order, so the report matches the bundle preview's positional refunds. Whether importPosition's return also grows those refund words is a plan choice. The execution transfer is not.

This step depends on the both-token add in step 2. Import is that add plus the NFT collect and burn. It is not a third share formula.

Behavior, V3-OWN-01, V3-ACC-02, V3-ACC-03, V3-ACC-04, V3-ACC-07, and V3-ACC-11:

- previewImportPosition and importPosition remain. V4 has no import. Do not delete them.
- Collect every token amount the NFT yields: both tokens' principal and the fees collected from that position. Those amounts are a both-token deposit under V3-ACC-07. Add the greatest proportional liquidity those amounts support. Refund each token the add does not take. The refund goes to recipient, not to msg.sender. That recipient rule is the import lock. It is not the V3-ACC-10 msg.sender refund. The execution transfers the overage. It does not leave it in the vault. It does not book the NFT amounts into the destination vault's shared fee balance.
- After the tokens are collected, burn the empty position NFT through the position manager's burn. Do not leave it on the vault. Do not return it to the owner. The interface notice requires 0 liquidity and all tokens collected first, so burn comes after decreaseLiquidity, when liquidity is nonzero, and after collect. A failed import reverts, so the burn does not stick. Whether burn sits before or after the vault's own pool.mint is a plan choice inside that constraint.
- Remove the current revert when totalSupply is nonzero or the position record is created. Import may run when the vault already has supply. A later import is the same proportional add and refund. It does not replace the existing position and it does not reset supply. It uses the ticks already fixed. It does not mint a second floor.
- Fees already owed by the destination position stay under V3-ACC-11 and are not part of the importer's deposit. Measure the NFT yield as the tokens that NFT decrease and collect pay, after destination fees have been snapshotted and booked. Using the vault's whole balance as the importer's inbound fails this lock. The measurement method is a plan choice. The separation is not.
- The genesis floor applies only when the import is the first liquidity. A first import that cannot add more than 1,000 liquidity reverts MinLiquidityNotMet(), mints nothing, and does not leave the NFT burned. Shares otherwise follow V3-ACC-02 and V3-ACC-04.
- Do not use StandardExchangeConstantProduct, the dead-sink floor, or a sleeve rebalance. The current import does all three. Those calls are retired.
- A disabled import reverts VaultDisabled. Import is not a withdrawal, donate, or compound. Deadline precedes that check. A locked pool reverts UniswapV3Exchange_BoundPoolInteractionBlocked on execution. The preview does not revert merely because the pool is locked.
- Keep the existing pool-identity and caller-authorization checks. The PRD does not retire them. Dropping them would be a new permission, not a copy of the lock.
- Whether a zero-liquidity NFT that still yields fees is accepted is a plan choice. Recommended reading: do not keep UniswapV3ExchangeImport_ZeroLiquidity if that reject skips fee collection, because the lock says to collect every token amount the NFT yields. If the yield cannot form a valid add, genesis or the positive-supply no-mint rule applies. Do not invent a new error for that case.

Tests that fail if this is wrong:

- After a successful import, the vault is not the owner of the NFT and the owner is not the owner of the NFT. burn was called. A test that only checks the share mint passes a vault that still holds the NFT.
- Import after a normal first deposit succeeds. Supply is not reset. The existing position's ticks are unchanged. A second floor is not minted. Destination fees accrued before the import are not credited to the importer and are not refunded to recipient.
- The preview reports net shares and both refunds. The one-word return is gone. Execution transfers both overages to recipient. Neither overage remains in the vault or in the booked fee balance.
- A first import that cannot clear 1,000 liquidity reverts MinLiquidityNotMet, mints nothing, and leaves the NFT with its previous owner.
- A disabled import reverts VaultDisabled. A missed deadline reverts before that. A locked-pool import execution reverts UniswapV3Exchange_BoundPoolInteractionBlocked.
- The current empty-vault-only test in test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_Import.t.sol expects the retired gate. It is not an acceptance test until it expects the post-supply import. Do not put the old revert back to keep that file green.

### Step 9. Package cut

Files: UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol, IUniswapV3FullSpreadStandardExchangeVaultDFPkg.sol, and UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol. PkgInit and PkgArgs stay on the interface. That placement is the existing package shape, not a new requirement.

Behavior:

- V3-OWN-03. Install the new selectors on the new facets. Remove exchangeInManyToOne, previewExchangeInManyToOne, exchangeOutOneToMany, and previewExchangeOutOneToMany from the cut. V3-ACC-07 and V3-ACC-13 retire their economics, and V3-OWN-05 matches the V4 surface except import. Leaving those four selectors installed would be a second surface. Deleting their files versus stopping the install is a plan choice. The selectors must not be callable.
- V3-ACC-08. Remove rebalanceLiquidReserve, targetLiquidReservePercentage, localReserve, and the liquid-reserve percentage view. Keep canOpenBoundPoolOps. Remove the 5% deadband and the post-operation rebalance calls. Do not read liquidReservePercentageOfVault as a target.
- V3-OWN-05. Remove the IStandardizedYield interface id and the quoteAssets selector.
- Keep previewExchangeIn, exchangeIn, previewExchangeOut, exchangeOut, previewImportPosition, importPosition, the two V3 callbacks, ERC-20, ERC-2612, ERC-5267, and vaultTokens.
- Fee-type id, plan choice of mechanism, required outcome. vaultFeeTypeIds currently keys USAGE to the liquid-reserve interface id. That id is the XOR of the interface's selectors, so removing sleeve selectors changes it. V3-ACC-04 does not leave the usage fee unset. Before editing that interface, record its current interface id and keep USAGE resolving to the fee the oracle already keys for this vault type. Do not silently zero the fee by changing the key. New vaults only does not make a zero fee acceptable.
- Do not install getRate, rateAsset, asset, depositPair, redeemPair, quoteAssets, or any Standardized Yield selector. Do not install unlockCallback.
- Initialization still binds the pool, the two pool tokens, the name, the symbol UV3X, 18 decimals, and the EIP-712 domain. It does not mint the floor. The floor is minted on the first successful add, not in initAccount. It does not store feeTo() as an ownable owner.

Tests that fail if this is wrong:

- A newly deployed vault exposes the eight additional selectors and the import selectors, and does not expose the retired multi selectors, the sleeve mutators, quoteAssets, exchangeRate, or unlockCallback.
- usageFeeOfVault for a new vault is the configured usage fee, not an accidental zero caused by an interface-id change. A fee-bearing first deposit then mints feeShares from grossShares.
- The existing facet-selector tests and StandardExchangeStages.t.sol, which assert the liquid-reserve interface, fail if left unchanged. Update them to the new cut. Do not restore the retired selectors to satisfy them.
- SeMatrix_FullSpreadV3Fixture.sol bootstraps through the sleeve percentage. That fixture must deploy this package through the registry and must not call setLiquidReservePercentageOfVault, localReserve, or rebalanceLiquidReserve as setup for an acceptance row. Plan choice: do not edit other families' expected amounts inside the seven shared behavior contracts. If a shared row can pass only by restoring constant-product amounts, that row is not an acceptance test for this PRD. Do not weaken it.

### Step 10. Tests and gas

Test filenames are a plan choice. Recommended directory: test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/, with one file for the package cut, one for one-token money, one for bundle and import, one for donate and compound, and one for previews and the external rate provider. Do not treat the current release, adversarial, or matrix files as the acceptance suite until they assert the locked behavior. They currently encode the sleeve, the dead sink, the one-word import preview, or the SY surface.

Harness, plan choice aligned with the V4 plan's own harness sentence: deploy a new vault through this package and the registry. Call the public selectors. Do not etch this vault, the pool, or the position manager. Do not mock the pool callback. A mocked callback cannot fail the booked-balance invariant. Bootstrap shares only through the public routes. The first share mint is a successful public add or a successful first import, not a storage write.

Gas measurement. Adopt the ceilings the V4 plan states. Do not invent a higher ceiling.

Source: UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md, section 2. The current ceilings are 12,000,000 for the transaction and 5,000,000 for a preview. That plan does not state a different current ceiling. The same sentence sets the standalone measurement method: a standalone public money or maintenance call passes only if its cold call body is at most 11,900,000, leaving 100,000 overhead. Fixture setup stays outside that body. Do not warm the measurement with a preview. An oversized route is unresolved, not passed. There is no getRate read in the measurement.

The composed-hook sentence in that same paragraph, a whole transaction including hook work at most 12,000,000, is the V4 hook-route bar. This PRD does not adopt hook routes. Do not add section 12 hook gas rows to this plan. That exclusion is a plan choice about scope, not permission to raise the vault ceilings.

Measure these standalone routes, which are the seven the V4 plan names, on this vault:

- exchangeIn one-sided share mint
- exchangeIn one-token exit
- exchangeIn pass-through
- exchangeBundleInForSingleOut
- exchangeBundleOut
- donate
- compound

setOperator and setOperatorFor are not in that set. Do not add them.

Measuring importPosition under the same 12,000,000 transaction ceiling, and previewImportPosition under the same 5,000,000 preview ceiling, is a plan choice. Recommended, because this vault has that economic route and V4 does not. It is not a new ceiling and not a reason to skip the seven.

Preview measurements that must fit 5,000,000: previewExchangeIn for a share mint and for a one-token exit, previewExchangeBundleInForSingleOut, previewExchangeBundleOut, and previewExchangeOut. previewExchangeOut returning zero is still a preview measurement, not a skip.

A gas test fails the route, rather than passing it, when the cold body exceeds 11,900,000 or a preview exceeds 5,000,000. Do not mark that route passed. Do not raise the ceiling in the test.

### ID map

| ID | Step |
| --- | --- |
| V3-ACC-01 | 0, 2, 3 |
| V3-ACC-02 | 2, 8 |
| V3-ACC-03 | 1, 2, 4, 8 |
| V3-ACC-04 | 2, 8, 9 |
| V3-ACC-05 | 2, 4 |
| V3-ACC-06 | 2, 4 |
| V3-ACC-07 | 2, 7, 8 |
| V3-ACC-08 | 4, 7, 9 |
| V3-ACC-09 | 1, 3, 6 |
| V3-ACC-10 | 4, 7 |
| V3-ACC-11 | 2, 3, 8 |
| V3-ACC-12 | 2, 4, 5 |
| V3-ACC-13 | 7 |
| V3-ACC-14 | 4 |
| V3-ACC-15 | 4, 7, 8 |
| V3-ACC-16 | 4, 5, 7, 8 |
| V3-ACC-17 | 5 |
| V3-ACC-18 | 2, 7 |
| V3-ACC-19 | 4, 5 |
| V3-ACC-20 | 2 |
| V3-OWN-01 | 8 |
| V3-OWN-02 | 7 |
| V3-OWN-03 | 7, 9 |
| V3-OWN-04 | 0, 9 |
| V3-OWN-05 | 0, 5, 9 |

### Plan choices, collected

These are not new requirements. Two authors could do them differently. The recommended side is the one used above.

- Extend the existing repo struct instead of a new slot.
- One shared sizing function instead of a copy in each target.
- Keep the execution delegates only as a code-size split.
- Home facet for previewExchangeIn after the multi facet is removed.
- Remove, rather than keep, the unnamed transition-quote selectors.
- Do not retain deployedReserve.
- Facet filenames and how the eight new selectors are grouped.
- Import preview return layout: net shares, then both refunds in vaultTokens() order. Execution return width may stay one word.
- Internal order of NFT burn relative to the vault's pool.mint, after collect, in the same reverting transaction.
- Do not keep the zero-liquidity import reject if it skips fee collection.
- Preserve the current USAGE fee-type id when the liquid-reserve interface changes.
- Install family reserves and only vaultTokens from the basic facet.
- Use IOperable.NotOperator for a stranger.
- New acceptance tests live under test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/. Do not edit other families' expected amounts to keep matrix rows green.
- Measure import under the same ceilings. Do not copy V4 hook-composed gas rows.

## Limits

- Runtime or extraction proof: not run. No test, gas measurement, or deploy was executed. The gas ceilings are cited from the V4 plan, not measured on this vault.
- Not examined: the optional earlier council responses; V4 plan section 12 hook-row bodies; most of the V4 PRD outside the named locks; execution-delegate bodies; the older tree at contracts/protocols/dexes/uniswap/v3/; the Crane helper that writes balanceOf directly; the numeric value of the current liquid-reserve interface id.
- The V4 execution file's address(0) mint was read and is not the path this plan adopts.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
