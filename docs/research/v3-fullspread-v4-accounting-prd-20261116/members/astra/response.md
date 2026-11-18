# Identity

- Member: astra.
- Run ID: v3-fullspread-v4-accounting-prd-20261116.
- Profile: research.
- Phase: initial independent response.
- Requested role: council-member.
- Requested model and reasoning: chatgpt-subscription/gpt-6-astra:high.
- Runtime model, provider, reasoning setting, and task identity: not exposed.
- Peers read before submission: no.
- This is an independent research contribution. It claims no council consensus and does not authorize implementation.

# Question and targets

What must a PRD require for V3 full-spread deposits, exits, dust, and issuance to follow V4 full-spread accounting, what current V3 behavior must change or remain, and what cannot be adopted merely by citing V4?

The necessary change is larger than replacing a share formula. V3 currently issues against a two-token reserve book and subsequently places that book into a target liquid sleeve and a position. V4 issues against newly added position liquidity, refunds unused user input, separately books fees and maintenance residue, and allocates liquidity, fees, and booked tokens proportionally on exit. V3's existing unlocked-pool single-token exit already has much of the proportional-withdrawal shape, but its balance ownership, partial-conversion treatment, and post-operation maintenance differ.

Two boundaries are essential. V4's hook component-accounting amendment is not the vault's issuance formula. Also, V3 cannot copy V4's borrowed-unlock execution: the inspected V3 gate forbids new operations on its bound pool while that pool is locked. Removing the V3 sleeve therefore changes availability as well as accounting.

The primary targets are the V3 tree, `StandardExchangeConstantProduct.sol`, and the V4 full-spread PRD, planner, and math. The optional external rate-provider implementation was examined because the brief requires its preview dependency to remain visible.

# Evidence

All paths below are relative to the repository root. Line numbers refer to the files read for this response. Observations are source readings, not executed test results.

For compact citations, the following prefixes are used:

- `V3/` = `contracts/vaults/standard/exchange/protocols/uniswap/v3/`.
- `V4/` = `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`.
- `V4 PRD` = `V4/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`.
- `CP` = `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol`.

| Evidence | Source observation |
| --- | --- |
| E01: V3 issuance | `V3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol:63-169` computes single and dual deposit shares from added token quantities and pre-deposit reserves. It collects if idle, mints, synchronizes reserves, and then rebalances if permitted. While blocked, a deposit can still mint locally and emit `LocalDepositWhileBlocked`. Both dual amounts must be positive. |
| E02: Constant-product book | `CP:20-34,37-64` uses a token-decimal-derived minimum and geometric-mean genesis. With existing supply, dual inputs take the minimum of the two reserve ratios; one-sided inputs use square-root invariant growth, with special one-asset branches. `CP:78-95` inverts that issuance for exact-share mints. `CP:98-128` defines and inverts a separate local single-token exit. These are not V4 raw-liquidity share formulas. |
| E03: V3 balance ownership | `V3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:178-180,315-365` reads actual held balances plus deployed amounts and stored/unpoked fees for share math. `:400-405` synchronizes held balances into reserve bookkeeping. `:624-650` uses the CP formulas and assigns pre-genesis residual inventory a dead-share weight. Existing ambient balances consequently enter a materially different accounting system from V4's unbooked/booked separation. |
| E04: V3 sleeve and protocol mechanics | `V3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:121-163` reads `slot0.unlocked` and authenticates mint/swap callbacks against the bound pool. `:188-212,658-791` uses the oracle's liquid-reserve percentage, a 5% relative deadband, decimal-dependent floors, deployment of excess, and proportional liquidity removal to refill deficits. `:485-504,540-605` implements fee poke/collect, exact-input swap, mint, and burn/collect. `V3/UniswapV3FullSpreadStandardExchangeVaultLiquidReserveTarget.sol:34-78` exposes sleeve views and permissionless rebalance, blocked when the vault is disabled or the pool is locked. |
| E05: V3 exact-input exits | `V3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol:171-209,212-277` distinguishes CP-valued local exits while blocked from unlocked-pool proportional withdrawal plus one opposing-token swap. `V3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:239-253` quotes the swap after removing liquidity. `:793-832` removes proportional liquidity and swaps the removed opposing amount plus a proportional free balance. Its `_swap`, at `:540-566`, checks output but does not require the specified input to be fully spent. The exit then rebalances. |
| E06: V3 exact-output | `V3/UniswapV3FullSpreadStandardExchangeVaultOutBase.sol:39-51,54-122` uses CP inverse issuance, a blocked CP exit inverse, a linear sleeve branch, and a minimum-sufficient-share search. The search uses at most eight interpolation probes and then bisection; it is not an eight-iteration cap on the whole search. The former 1% pad is absent. `V3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:14-69,89-128` executes exact-output withdrawal, pays exactly the request and retains surplus, and mints exactly requested shares from the CP input. `V3/UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:24-65` also supports direct exact-output token swaps. |
| E07: V3 public and auxiliary surfaces | `V3/UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:26-72` already returns `(amountOut, amountRefunded)`, but hardcodes refund to zero. Its preview wrapper does the same in `V3/UniswapV3FullSpreadStandardExchangeVaultInMultiQueryTarget.sol:11-17`. `V3/UniswapV3FullSpreadStandardExchangeVaultInMultiTarget.sol:11-30` accepts explicit paired token arrays without a refund result. `V3/UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol:23-121` offers requested dual amounts, requiring equal rounded share requirements for both legs; this is not V4's shares-in bundle redemption. |
| E08: V3 projected/frozen quotes and SY | `V3/UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol:29-42,198-288,290-383` exports the CP pair-deposit model, simulates CP issuance, local and pool exits, exact-output inversion, partial-swap residue, and sleeve rebalance. `V3/UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:17-29` exposes SY metadata and a geometric-mean-reserves `exchangeRate`; `:32-59` exposes exact-output previews. `V3/UniswapV3FullSpreadStandardYieldExecutionTarget.sol:8-29` routes SY redemption through the V3 exit core. `V3/UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol:125-142` advertises these interfaces. |
| E09: V3 import and range | `V3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol:81-126,129-175,194-220` authorizes NFT import, requires an empty vault, removes the NFT's liquidity, collects principal and fees, credits actual incoming assets under CP genesis, and rebalances. The empty NFT remains on the vault according to `:46-50`. Execution creates canonical full-range ticks at `:163-164`; it does not retain the NFT's arbitrary range. `V3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:408-419` derives minimum/maximum usable ticks. The older class comment at `:49-51` is not a reason to override that implementation. |
| E10: V4 controlling locks | `V4 PRD:198-214` (FS-OWN-24/25/27) defines raw-liquidity issuance, net mint fees, and no-swap proportional bundles. `:222-246` (FS-OWN-30/32) separates fees, booked claims, and caller refunds. `:248` (FS-OWN-33) locks one 49% swap inside the range, boundary behavior, output consumption, and input-side residue. `:57-67,162-180` states the rate, genesis, no-sleeve, maintenance, and exit rules. |
| E11: V4 planner and math | `V4/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:39-71,107-118,132-175,177-246` implements proportional bundle liquidity, mint/exit planning, a fixed `floor(amount * 49 / 100)` swap, full spending of that selected swap, and liquidity-based shares with fees. `V4/UniswapV4FullSpreadStandardExchangeVaultMath.sol:46-146,197-226` requires the add to consume exactly the quoted swap output, fits deposits to rounded-up token obligations, floors claims, and handles no-swap boundary adds. The math file still contains `quadraticInput` at `:159-179` and a harness at `:520-547`; the inspected active planner does not use it. Its presence is not a requirement to restore root solving. |
| E12: V4 execution ownership | `V4/UniswapV4FullSpreadStandardExchangeVaultExecution.sol:42-95,98-148` separates payer refunds, recipient shares, and actual one-token receipts; `:151-180` handles maintenance; `:213-249` books fees from liquidity adds and subtracts booked exit claims while retaining fee remainders; `:275-281` checks caller-held shares and computes unbooked inventory separately from booked/reserved inventory. `V4/UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation.sol:40-67` separates swap actions and liquidity-action fees. |
| E13: Hooks are a different ownership layer | `V4 PRD:250-252` (FS-OWN-34) expressly preserves vault liquidity issuance and booked-claim exits. `:541-557` (FS-HOOK-05/06) separates hook SE-share and local-token books; only swap pricing uses a rated sum and local-first settlement. `:559-595` (FS-HOOK-07/08) requires proportional component contributions and exits for Hook LP. `:557` explicitly says this does not solve swap-price manipulation. |
| E14: External rate provider | `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:61-82` currently quotes the entire subject supply, then normalizes it. `:98-109` inverts a unit-target mint preview at zero supply. `:112-127` calls `previewExchangeIn` for live quotes and `quoteAssets` for projected states, accepting 64-byte live tuples. Thus the V4 PRD's historical 32-byte-consumer list at `:92-105` is not the present state of this file. The current provider is also not a one-share sampling implementation. |

# Assumptions

1. The question authorizes proposing V3 adoption of V4 accounting, not declaring every V4 owner decision already binding on V3. Each proposed requirement below identifies its provenance.
2. Current Solidity describes observed V3 behavior. The V4 PRD supplies the behavior template. A disagreement between source and prose is disclosed rather than silently settled.
3. Proportionality means integer asset quantities, not equal economic value or a price guarantee. The fixed entry swap and exit conversion still use the bound pool's live execution price.
4. Symbols used below are: `S` = pre-mint or pre-burn total share supply, including the locked floor; `L` = this vault's deployed liquidity before adding or removing liquidity; `dL` = actual added liquidity; `b` = shares burned; `F_i` = unpaid fees attributable to the position at the exit snapshot; and `B_i` = already booked local tokens, excluding those unpaid fees.
5. No deployed-vault inventory, migration mandate, consumer dependency inventory, or owner answer on the newly identified decisions was supplied. Compatibility and migration conclusions therefore remain proposals.

# Coverage

The eight expressly named source files were read completely: the four V3 core files, CP, the V4 PRD, V4 Planner, and V4 Math.

Additional admitted sources read completely were the V3 InTarget, InMultiTarget, InMultiQueryTarget, InExecutionDelegate, OutExecuteTarget, OutExecutionDelegate, OutQueryTarget, OutMultiTarget, OutMultiQueryTarget, LiquidReserveTarget, PositionImportTarget, StandardYieldExecutionTarget, and DFPkg files; and the V4 Execution and ExecutionPreparation files. The trivial V3 OutTarget was loaded but was not needed as evidence.

Optional-source disposition:

| Optional source | Disposition |
| --- | --- |
| V3 remediation PRD | Not examined. Existing D-number comments are reported as source comments, not independently verified owner authority. |
| V4 pairToken tree | Not examined; not used as the template. |
| V4 upperLowerWings tree | Not examined; not used as the template. |
| `StandardExchangeRateProviderFacet.sol` | Examined completely; E14. |

The brief and repository router were read. No peer artifact, coordinator draft/resolution, run record, or final PRD was read. No project tests, builds, installs, deployment, wallet actions, Git operations, or sub-agents were used.

# Conclusions

The following are proposed PRD sentences, not accepted V3 owner locks. A requirement marked **copy** explicitly proposes adopting a named V4 lock. A requirement marked **V3 adaptation** specifies the protocol translation. A **new decision** identifies something the V4 lock cannot settle. These classifications should survive coordinator synthesis.

**V3FS-ACC-01 - Accounting basis.**

> The V3 full-spread vault adopts FS-OWN-24/27 for issuance: shares represent proportional raw liquidity in its single vault-owned full-range V3 position; for existing supply, gross new shares equal `floor(dL * S / L)`, using pre-mint `S` and pre-add `L`, with full-width multiplication before division. Token quantities remain in native units when computing V3 liquidity. Neither token-decimal normalization, square-root growth of the two-token reserve book, local balances, nor unpaid fees enters this issuance denominator. A positive supply with zero deployed liquidity is not an alternative CP issuance branch.

Type: **copy** of FS-OWN-24/27, expressed in V3 liquidity. Retires E01-E03 CP issuance and one-asset sleeve issuance. Preserves the single share supply, 18-decimal metadata, and full-range position. Refuses to decide how pre-existing positive-supply/zero-liquidity vaults migrate into this invariant; V3FS-DEC-04 applies. Sources: E01-E03, E09-E11.

**V3FS-ACC-02 - One-sided deposits.**

> V3 adopts FS-OWN-33: strictly inside the managed range, a one-sided mint selects exactly `floor(processedInput * 49 / 100)` for one exact-input swap on the bound V3 pool, then adds liquidity at the resulting pool state. The selected swap input must be fully spent, its output must be fully consumed by the add, and any unused contribution must remain in the originally supplied token. Do not optimize the split, solve a root, iterate swap sizes, or swap a second time to clear residue. Do not include existing fees, booked balances, or unbooked ambient inventory in the user's swap or add budget.

Type: **copy** of FS-OWN-33/30/32, with V3 settlement. Retires mint-before-deployment and the implicit assumption that all declared tokens deserve shares. Preserves exact-input funding and the existing broad V3 price-limit endpoints. It does not forbid the tick traversal needed to quote the fixed swap; it forbids traversal to optimize its split. Sources: E01, E04, E10-E11.

**V3FS-ACC-03 - Boundaries and unusable entries.**

> At or outside either position boundary, V3 adopts FS-OWN-33's no-swap branch: add only the token the position requires, refund the unused amount of that token, and refund the entire declaration when the other token is supplied. Zero active liquidity strictly inside the range is not this boundary case. If the selected interior swap cannot execute completely or its output cannot be consumed by the add, retain no swap and mint no shares; apply the explicitly stated refund/genesis policy in V3FS-DEC-07. A user minimum greater than the achievable output remains binding.

Type: **copy** of FS-OWN-33, with an explicitly unresolved genesis precedence. Retires local issuance for an undeployable contribution. Preserves atomicity and caller minima. No opposing-token dust may be silently gifted to existing holders. Sources: E10-E12.

**V3FS-ACC-04 - Two-token deposits.**

> V3 adopts FS-OWN-25: a two-token deposit adds only the proportional liquidity supported by its declared token budgets at the current pool state, performs no balancing swap, credits only actual added liquidity through V3FS-ACC-01, and refunds each unused token to the payer. Rounded-up V3 mint obligations must fit those budgets; a nominal liquidity calculation is not authority to spend an incumbent balance. Collected pre-existing position fees are booked separately and do not become this deposit's contribution.

Type: **copy** of FS-OWN-25/30/32. Retires acceptance of unmatched input into V3's sleeve without a refund. Preserves canonical token ordering and minimum-share protection. The availability of a zero leg at a boundary and the legacy versus accepted bundle selectors must be explicit in the route manifest, not inherited from `_dualAmountsPositive`. Sources: E01, E07, E10-E11.

**V3FS-ACC-05 - Genesis and mint fees.**

> For a new V3 vault adopting V4 genesis, require added liquidity greater than 1,000, allocate exactly 1,000 raw shares to the zero address as a permanent floor included in supply, and set first-deposit gross shares to `dL - 1,000`. For every share-minting deposit, including genesis, adopt FS-OWN-24: resolve the live usage fee, clamp it to `3e17`, and, when the fee recipient is nonzero, allocate `floor(grossShares * fee / 1e18)` from gross shares to that recipient and the remainder to the depositor. Mint no fee on top. Previews and minimum-output checks use net shares. Pass-through swaps and exits pay no such mint fee.

Type: **copy** of FS-OWN-11/24/27. Retires the token-decimal-derived minimum, `0x...dEaD` genesis allocation, residual-inventory dead shares, and direct unsplit canonical deposit minting in the inspected V3 paths. Preserves a permanently locked floor and fee-oracle configuration as a dependency. Applying this denomination and floor to already issued shares is a separate decision, not a rescaling instruction. Sources: E01-E03, E10-E11.

**V3FS-ACC-06 - Refunds, bookings, and custody.**

> V3 adopts FS-OWN-20/30/32 and maintains distinct amounts for booked vault property, this operation's reserved input, and unbooked held tokens. On a pull deposit, pull the full declaration and refund its unconsumed amount to `msg.sender`; pay shares or exit output to `recipient`. Do not issue shares for refunded input. Book collected position fees and maintenance residue, but do not book a user-deposit refund. Do not treat an entire ERC-20 balance as redeemable idle or as this caller's contribution.

Type: **copy**. Retires unconditional actual-balance inclusion in share math and hardcoded zero refunds. Preserves ERC-20 custody and payer/recipient separation. Booked balances remain exit-claim property even though they are excluded from the deployed-reserve view. Sources: E03, E07, E10, E12.

**V3FS-ACC-07 - Pretransfers and share authority.**

> For underlying-token pretransfers, V3 adopts FS-OWN-32: process only the declared maximum from available unbooked inventory, never booked or reserved property; refund maximum minus consumed when the maximum is available. For a one-token declaration above availability, consume nothing and refund only available unbooked input, subject to the genesis rule; do not pull a shortfall. A bundle whose any maximum exceeds availability reverts atomically. Retain the prohibition on EOA pretransfer. For exits, explicitly adopt FS-OWN-20's caller-owned share burn if V4 authority parity is intended; parked vault shares must not become generic exit credit.

Type: **copy** of FS-OWN-20/32, with a compatibility consequence requiring explicit adoption. Retires V3's insufficient-underlying-credit revert on canonical one-token entry and its generic prepaid-share delivery path if the caller-burn clause is adopted. Preserves bounded credit, atomic bundle funding, and authority over the shares actually burned. The fate of SY's named vault-held redemption is V3FS-DEC-03, not permission to remove it silently. Sources: `V3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:863-925`, E07-E08, E10-E12.

**V3FS-ACC-08 - No sleeve or automatic maintenance.**

> V3 adopts FS-OWN-04/12/14: deposits, exits, and pass-through swaps must not target `liquidReservePercentageOfVault`, apply its deadband, call liquid-reserve rebalance, or deploy remaining holders' booked tokens. There is no sleeve fallback. Booked balances are deployed only by the separately specified donation/compound operations. Removal of the sleeve's target and execution behavior must be reflected in its query and package surfaces.

Type: **copy**. Retires E04's target, floors, refill, permissionless rebalance, and routine post-operation rebalance calls. Preserves ownership of existing booked tokens. It cannot preserve current locked-pool availability automatically; V3FS-DEC-01 states the conflict. Sources: E01, E04-E07, V4 PRD:59,164-178,434.

**V3FS-ACC-09 - Fee ownership and proportional withdrawal.**

> V3 adopts FS-OWN-30: before burning `b` shares, snapshot `S`, `L`, each unpaid position fee `F_i`, and each already booked balance `B_i`. Remove `floor(L * b / S)` liquidity; allocate `floor(F_i * b / S)` unpaid fees and `floor(B_i * b / S)` booked tokens to the exiting holder. Include the locked floor in `S`, multiply before dividing, and leave rounding residue with the remaining supply. A fee moved from the pool into booked custody is counted once, not once as unpaid and again as booked.

Type: **copy**, translated from `feesAccrued` to V3 stored/unpoked fee growth and actual collection. Retires claims against all ambient free balances. Preserves V3's proportional position removal, recognition of stored and unpoked fees, and the principle that collecting fees changes location rather than ownership. Collection must distinguish burned principal from fees; a raw `collect` balance delta is not entirely new principal. Sources: E03-E05, E10-E12.

**V3FS-ACC-10 - One-token exit receipt.**

> V3 adopts FS-OWN-15/30: after proportional removal, swap exactly the exiting holder's unwanted principal, unwanted fee claim, and unwanted booked claim in one exact-input swap, against the pool state after that removal. Require complete consumption of this unwanted amount; otherwise revert the whole exit without a lasting share burn or payout. Pay the requested-token principal, requested-token fees, requested booked claim, and actual swap proceeds to `recipient`. Return that complete receipt as `amountOut` and enforce `minAmountOut` against it. Do not keep or book an unwanted-token residual, spend remaining holders' inventory, or rebalance after the exit.

Type: **copy**. Preserves the existing V3 unlocked-pool proportional-remove-then-swap structure and post-withdrawal swap quotation. Retires partial-input acceptance, whole-free-balance ownership, and post-exit sleeve maintenance. The 49% entry fraction is not an exit fraction. Sources: E05, E10-E12.

**V3FS-ACC-11 - Both-token exit.**

> V3 adopts FS-OWN-09/30's shares-in both-token redemption: for a specified share input, pay the V3FS-ACC-09 principal, fee, and booked claims in both underlying tokens without a swap, enforce each recipient minimum, and retain only remaining holders' property. Both-token redemption must not be specified as two independently requested outputs whose rounded share requirements happen to match.

Type: **copy**. Retires the current dual exact-output route as the definition of proportional redemption; its compatibility disposition remains explicit under V3FS-DEC-02. Preserves a no-swap paired payout and atomic minima. Sources: E07, V4 PRD:115-150,224-232, E11-E12.

**V3FS-ACC-12 - Maintenance treatment.**

> If V3 adopts V4 maintenance, `compound()` and `donate()` follow FS-OWN-14/21/33: harvest and combine booked fees, booked residue, and the directed underlying donation; use the same fixed one-sided process when only one token is held, or a no-swap proportional add when both are held; book the actual remaining held balance after processing instead of refunding it. They do not mint depositor shares for underlying donations, sell deployed principal, or add a second attempt to clear dust. Share donation burns authorized donor shares without withdrawal. Donation before genesis reverts.

> Authority follows the explicitly adopted FS-OWN-14 rule: the live fee-oracle `feeTo()` owner, a global operator, or an operator for that selector; this authority is not inherited from permissionless V3 rebalance. A no-work compound changes nothing and emits no event; successful donation emits `Donation()`, and a deposit from collected fees or booked tokens emits `Compounded()`.

Type: **copy**, but adding these V3 surfaces and authority is an express scope choice. Retires permissionless target maintenance as the dust-deployment mechanism. Preserves the continuing holders' ownership of maintenance residue. The maintenance booking exception can absorb stray transfers as FS-OWN-14 states; it must not be generalized to user deposits. Sources: E04, V4 PRD:168-192,248, E11-E12.

**V3FS-ACC-13 - V3 settlement and lock semantics.**

> Express these rules through the bound V3 pool's swap, mint, burn, and collect operations and its authenticated mint/swap callbacks. Preserve the vault-owned full-range position and the operation reentrancy guard. Never call V4 `unlock`, `modifyLiquidity`, or delta-settlement APIs on the V3 vault, and never interpret V3 `slot0.unlocked == false` as V4's usable borrowed-unlock context. A callback may pay only the active operation's authorized obligations; it is not a separate deposit.

Type: **V3 adaptation**, preserving E04's protocol boundary and the ownership intent of FS-UNLOCK-02/03. Retires any literal API transplant from V4. Whether a request is available during a bound V3 pool callback is a new availability decision below. Sources: E04, E09, V4 PRD:443-475.

**V3FS-ACC-14 - Quotes and reserve reads.**

> V3 adopts FS-OWN-07/19/24/30/32 and section 6: deposit previews return net shares plus declared-input refunds using the same fixed-swap and liquidity arithmetic as execution; exit previews quote the same proportional claims and recipient receipt as execution at the same state. Refund previews assume the declared budget is available and do not inspect the payer's pretransfer balance. Deployed-reserve reads include current position token amounts and unpaid fees, exclude booked/unbooked local balances, and are not a replacement share valuation. Unsupported views return zero according to the route manifest; a zero preview is not execution permission. Do not add an undocumented tick-step cap or optimize the 49% split.

Type: **copy**, requiring propagation through retained V3 quote surfaces. Retires zero-refund wrappers, CP frozen inputs, sleeve-state projections, and old unsupported-view reverts wherever the adopted surface uses the new rules. Preserves post-removal pool-state simulation and deterministic integer rounding. Genuine sequential quotes must project the new operations; returning live-state answers for a changed state is not compatibility. Their retention/removal is V3FS-DEC-03. Sources: E07-E08, E10-E11, V4 PRD:65-67,188,230,246,477-488.

**V3FS-ACC-15 - Disable, deadline, and funding behavior.**

> V3 adopts FS-OWN-26/28/32: deadline validation precedes the disable check; disabling blocks deposits and pass-through swaps but permits the supported share-in withdrawals and authorized maintenance. An exit must not fail merely because a post-exit cleanup deposit into a disabled vault is forbidden. Keep exact actual-delivery checks for supported ERC-20 inputs, caller bounds, token ordering, and atomic rollback. Reject invalid recipients and routes as stated by the adopted interface contract.

Type: **copy** for ordering, disable policy, and route validation; **preservation** of V3 transfer-delta checks. Retires current canonical V3 disable-before-deadline ordering and automatic exit cleanup. It does not make a locked V3 pool callable. Sources: `V3/UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:40-68`, `V3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:863-885`, E07, V4 PRD:212-216,244.

**V3FS-ACC-16 - Rate-provider and hook boundary.**

> Preserve the configured external Standard Exchange rate provider's supported `previewExchangeIn` dependency and tuple decoding. Do not install `getRate()` on V3, delete the executable preview to make a rate test pass, substitute NAV, or call a whole-book or sampled approximation the same executable rate without an explicit product decision. FS-OWN-34 and FS-HOOK-06 do not change the vault's liquidity issuance formula or create a vault sleeve: hook LP ownership and hook-local swap settlement remain separate from V3 vault share ownership.

Type: **copy** of the separation in FS-OWN-03/29/34 and FS-HOOK-06, plus preservation of the assignment's provider constraint. Retires conflation of rated hook reserves with vault issuance. Preserves the external provider path and acknowledges its actual full-supply sampling, rather than assuming one-share code. Sources: E13-E14.

**V3FS-ACC-17 - Scope of price protection.**

> This redesign changes issuance, ownership, and settlement quantities; it does not claim to solve same-pool swap-price manipulation, make a provider quote manipulation-proof, guarantee conversion value, or protect an unbounded-minimum caller from a moved execution price. Retain the caller's minima and the adopted V4 broad price limits. Any new TWAP requirement, independent oracle, price cap, or manipulation-protection promise is a separately approved product requirement.

Type: **copy** of FS-HOOK-06 and the accepted exposure in FS-OWN-14/30/33 and FS-MONEY-01. Retires an overbroad interpretation of the hook amendment. Preserves explicit execution-price exposure. Sources: V4 PRD:170,226,248,431,557,799.

The PRD must also contain the following explicit decision records. They cannot be closed by a blanket phrase such as "same as V4."

| Proposed decision ID | Copyable decision requirement and advised disposition | Retires / preserves / provenance |
| --- | --- | --- |
| V3FS-DEC-01: Bound-pool callback availability | **"The PRD shall state whether money operations requiring the bound V3 pool reject while that pool is locked. With V4's no-sleeve accounting adopted, the proposed policy is to reject those operations atomically and remove the existing blocked-pool local deposit/exit fallback; any retained local settlement requires separately specified funding and issuance economics."** This changes supported composition. A V4 hook calling a V3 vault whose own V3 pool is idle is a different case from reentering that bound V3 pool. | **New V3 product decision.** Retires E01/E05 locked-pool local service if adopted; preserves bound-pool safety. FS-OWN-13/31 cannot supply equivalent V3 liveness. |
| V3FS-DEC-02: Exact-output and legacy aliases | **"The PRD shall explicitly classify direct exact-output swaps, exact-share mints, exact-token withdrawals, and legacy many-to-one/one-to-many routes. Strict V4 route parity disables exact-output execution and returns zero for its preview under FS-OWN-08/19 and FS-HOOK-03; retaining any V3 exact-output route is a stated extension with new accounting, refund, fee, and quote requirements."** I advise the strict-parity policy for this stated goal, but it must be an express V3 compatibility decision. Do not merely replace the search while leaving its old economic inverse. | **V4 behavior copy plus new V3 compatibility decision.** Retires E06's CP inverse and share search if parity is adopted. Preserves exact-input swaps, share mints, and proportional redemption. The direct exact-output swap is a distinct route, not collateral damage hidden under "remove withdrawal search." |
| V3FS-DEC-03: SY, projected quotes, and interface claims | **"The PRD shall list every retained or removed SY, frozen-input, transition, external-state, and legacy paired selector and its interface advertisement. A retained alias must use the new money engine and correct authority/refunds; a retained projected quote must project that engine. Removal must name affected consumers; no stub may advertise the old model."** Full V4 API parity removes SY under FS-OWN-05 and normally omits transition interfaces under section 2, but accounting parity alone does not authorize deleting existing V3 integrations. | **New compatibility decision**, informed by V4 absences. Retires E08's old CP/frozen/sleeve semantics in every case; preserves truthful capabilities. The examined external provider can call projected `quoteAssets`, so removing that surface needs a consumer disposition, not silence. |
| V3FS-DEC-04: Existing supply and assets | **"The PRD shall state whether the accounting change applies only to newly deployed vaults or includes an explicit migration of existing V3 supply, locked shares, deployed liquidity, local reserves, unpaid fees, and unbooked credit; no change of formula silently reclassifies old local property or rescales existing balances."** New-vault scope is the least-assumptive recommendation until deployment/migration evidence is supplied. | **New product/migration decision.** V4's genesis rule does not map V3's decimal-derived floor, residual dead shares, or positive-supply sleeve-only state. Preserves existing claimants until a mapping is authorized. |
| V3FS-DEC-05: NFT import | **"If NFT import remains supported, the PRD shall specify how actual imported principal and accrued fees become a caller-funded contribution under the new liquidity issuance, how unused tokens are returned and to whom, and whether the route is still empty-vault-only; otherwise it shall explicitly retire the import route and its advertisement."** Preserve authorization, pool matching, actual inbound measurement, and canonical full-range remint if retained. Imported NFT fees are the importer's incoming assets, distinct from pre-existing fees of the destination vault. | **New V3 feature decision.** V4 supplies no NFT-import behavior. Retires E09's CP genesis and sleeve remint path in either retained-route redesign or explicit removal; does not silently credit the old NFT's raw liquidity as new full-range liquidity. |
| V3FS-DEC-06: Incumbent booked assets on later mints | **"The PRD shall distinguish literal FS-OWN-24/27/30 parity from a stronger promise that new deposits cannot dilute existing holders' fee and booked-token claims. Literal parity excludes those assets from mint pricing while all outstanding fungible shares participate in later proportional exits. Protecting historical component entitlements through matching contributions, separate claims, or another rule is a new product design, not FS-OWN-34 copied into this vault."** Do not add a stronger promise without its mechanism. | **New decision only if stronger protection is desired.** Retires ambiguity between the V4 vault and Hook LP rules; preserves exact V4 issuance if that is the selected target. E10-E13 substantiate the distinction. |
| V3FS-DEC-07: Genesis refund precedence | **"The PRD shall specify the result of an unusable one-sided first deposit: insufficient-genesis-liquidity revert or successful whole-input refund with no mint, and how a positive minimum changes that result."** FS-OWN-33 broadly describes whole refunds, while FS-OWN-11 and FS-MONEY-01 reject genesis at or below 1,000 liquidity. The inspected Planner `_shares` marks such genesis failed and Execution reverts; established-supply no-mint refunds are a different branch. I advise explicitly copying that implemented genesis precedence if literal implementation parity is intended. | **New clarification requiring an explicit V3 choice**, rather than hiding the source tension. Retires ambiguous no-op behavior; preserves the chosen floor and atomic caller bounds. E11-E12 and V4 PRD:162,248,432. |
| V3FS-DEC-08: External rate availability and meaning | **"The PRD shall preserve the provider's preview call while explicitly recording any state in which the current full-supply exit quote returns zero or cannot complete the opposing-token conversion; it shall separately state whether zero-supply inverse-mint pricing uses declared or consumed target input when deposits refund."** Do not silently switch sample size, replace the quote with NAV, or invent a V3 `getRate`. | **New integration/product decision where behavior is unacceptable.** E14 shows full-book live sampling and ignored refund in initial-rate inversion. E11 shows exit full-conversion requirements. Inference: removing the whole vault position can leave no executable opposing-token conversion when that position supplies the relevant liquidity; this was not experimentally demonstrated. Preserves the mandated executable-preview dependency. |

The booked-assets distinction in V3FS-DEC-06 is substantive. Algebraically, if existing supply is `S`, booked token balance is `B > 0`, and a new liquidity-only contribution mints `m > 0`, an old holder's booked claim changes from `floor(B * b / S)` to `floor(B * b / (S + m))` absent other changes. New shares can claim booked assets on a later exit even though no extra shares were directly credited for those assets at mint. The V4 Planner uses exactly the liquidity-only mint denominator and the proportional booked exit term (E11); there is no per-vintage fee ledger in the inspected booking path (E12). This is an inference about the specified formulas, not a new finding identifier or a proposal to override the V4 lock. FS-HOOK-07's separate component contribution requirement cannot be asserted for the vault without changing the target product.

Copyable acceptance requirements should accompany the prose:

| Proposed ID | Required observable evidence |
| --- | --- |
| V3FS-AC-01 | At identical starting state, one-token preview and execution agree on net shares and the planned fixed 49% swap; actual caller input equals retained input plus payer refund. Existing booked balances are excluded from the operation budget. Test both token directions, fee tiers, and mixed decimals. |
| V3FS-AC-02 | At each range boundary and outside it, the required token adds without a swap, the other token is returned, and interior zero-active-liquidity behavior follows the explicitly selected failure policy. Include rounding to zero swap, incomplete fixed swap, unusable swap output, insufficient genesis liquidity, and caller minima. |
| V3FS-AC-03 | An imbalanced bundle does not swap; actual added liquidity supports the gross mint, fees split that gross mint without extra supply, and each excess token is refunded. Genesis includes its floor exactly once. |
| V3FS-AC-04 | One-token exits allocate principal, unpaid fees, and booked tokens using pre-burn supply; quote after removing liquidity; spend the complete unwanted claim; pay the measured complete receipt; and leave other holders' quantities unspent. Failed conversion/minima restore tokens, shares, position liquidity, and books. Both-token exits pay the same allocation without swaps. |
| V3FS-AC-05 | User refunds, booked maintenance residue, unpaid fees, and unbooked direct transfers remain distinguishable across deposit, exit, donation, and compound. Test pretransfer under/equal/over declarations, atomic bundle shortfall, payer distinct from recipient, and parked shares under the selected authority policy. |
| V3FS-AC-06 | No supported user route changes balances toward a sleeve target. Verify the selected bound-V3-pool locked-state behavior, disabled deposits versus permitted exits, maintenance authority, and deadline precedence through actual public routes. |
| V3FS-AC-07 | Every retained alias and projected/frozen quote uses the adopted accounting; retired routes fail as specified and interface advertisements match. Exercise the external provider for each target, including zero supply, refunds, and insufficient liquidity after full-supply removal. A zero rate is recorded as that behavior, not replaced by NAV. |
| V3FS-AC-08 | Measure separately the vault's raw-liquidity issuance, any explicitly chosen booked-claim protection, Hook LP component ownership, and actual swap conversion outcomes. A quantity-accounting test must not be reported as proof that same-pool manipulation is solved. |

These acceptance rows preserve the relevant observable intent of V4 FS-A05 through FS-A11, FS-A32, FS-A38, and the accounting/price distinction in FS-A43 through FS-A46. V3-specific lock, compatibility, migration, import, and provider cases are new coverage derived from the differences above. They are proposed requirements; no tests were run.

# Limits

This response is source-backed requirements research, not a contract audit, execution plan, implementation, or compatibility certification. The V4 source files were not treated as proof that every V4 PRD requirement already passes. The noted genesis precedence, provider semantics, and booked-asset consequences remain visible rather than being repaired in this response.

No independent oracle, rate manipulation solution, same-pool composability guarantee, gas result, deployed-state migration safety claim, or full consumer inventory was established. V3 remediation owner decisions were not independently reconciled because that optional PRD was not examined. PairToken and upper/lower wings were not used as behavioral substitutes.

Only this owned response was written. It does not replace the coordinator's later draft or the final PRD, does not claim council consensus, and does not authorize implementation.
