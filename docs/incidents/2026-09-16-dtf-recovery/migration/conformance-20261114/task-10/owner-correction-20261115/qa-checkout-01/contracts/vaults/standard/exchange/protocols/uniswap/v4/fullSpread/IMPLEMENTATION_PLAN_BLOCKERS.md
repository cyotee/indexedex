# Implementation plan blockers

Working file for the owner decisions that still block an implementation and testing plan for the Uniswap V4 full-spread Standard Exchange vault.

This file unifies the four council originals, the advisory pass, and the coordinator report. It is the list we work through. It is not the plan, and it does not authorize implementation.

Council report: `docs/research/se-fullspread-plan-readiness-20261101/REPORT.md`.

Verdict on 2026-11-01: not ready. All four members reached that verdict. The advisory pass kept it. That header is not a lock over the 2026-11-04 overrides. Those overrides close the testing-inventory question and are applied in the PRD.

## How to use this file

Each open item has one question. When we lock an answer, replace `Decision: open` with the locked sentence and the date. Do not treat a member recommendation as the lock.

Do not edit the PRD from this file. After every open decision is locked, the council makes one comprehensive edit to the PRD from these locked sentences. Do not edit the PRD blocker by blocker. That pass must enumerate every consumer of the old 32-byte preview return, because the accepted preview is now a 64-byte tuple. Do not make that list here. The inventory is `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md`. It is not a PRD edit.

## Owner overrides, 2026-11-03

These sentences override the earlier sentences they name. They are not a PRD edit.

F1. Confirmed for a one-token call. If the caller's maximum is larger than the unbooked balance, refund that unbooked balance. Do not spend it. Do not pull the shortfall. A larger maximum is not a revert. The caller may declare any maximum. A bundle is atomic. If any declared maximum exceeds that token's unbooked balance, the call reverts before any leg is processed. No declared amount is spent. The owner locked that on 2026-11-03.

Bundle proportion, fees, errors, and WETH, locked 2026-11-03. A bundle deposit matches the underlying pool, books the fees `modifyLiquidity` returns, and refunds the bundle remainder. User calls that use `modifyLiquidity` book trading fees for a later `compound()`. They do not compound those fees in the user call. A first deposit that does not exceed `1_000` liquidity reverts `MinLiquidityNotMet()`. A recipient of `address(0)`, or this vault, reverts `InvalidRecipient()`. The WETH address is a `PkgInit` field, written with `WETHAwareRepo._setWeth`. Robinhood is the first deployment target, not a hardcoded constant.

F5. Replaced 2026-11-05 by FS-OWN-33 in the family PRD. A one-sided deposit, and a one-token `donate` or `compound`, swaps a fixed portion of the processed token, then deposits. The portion is a constant chosen by testing, starting at 48% of the input. It is not an on-chain search for the greatest liquidity the add can take. Any overage is in the input token.

F6. Confirmed. A one-token exit converts all unwanted withdrawn principal, plus the caller's opposing-token fee and booked claim from F2, into the selected token, or it reverts `AmountOutNotMet` and does not burn shares. It does not pay, book, or keep that residual. The 48% figure is the start of the FS-OWN-33 testing ladder for a deposit or donation swap. It is not an exit rule. The old no-leftover-shortfall-revert sentence is scoped to the former sleeve.

F2. Overridden again after the owner learned that `modifyLiquidity` returns accrued fees. On a share-minting deposit, book `feesAccrued`. Do not include those fees in the deposit, the caller's share credit, or a swap. Swapping them into the deposit is forbidden. On a withdrawal, the caller owns `shares burned / total shares` of `feesAccrued` and of each booked balance, measured before the burn and rounded down. Include that portion in the exit. Book the rest for the other holders. In a one-token exit, the caller's opposing-token fees and opposing booked claim are swapped with the withdrawn unwanted reserve. The caller's requested-token fees and requested booked claim are paid to the caller. This overrides the principal-only payment sentence and the earlier "do not withdraw fees" sentence. An exit preview uses that same apportioning and the same swap, so the quoted `amountOut` matches execution. That exit quote is the share valuation, and it includes accrued fees. A mint preview does not credit the new depositor with existing fees.

F7. Emit `Donation()` when `donate()` is called. Emit `Compounded()` when a deposit is made from collected fees or from booked tokens. A `compound()` call that deposits emits `Compounded()`. Booked tokens are treated as fees, including a donation remainder that was booked. The owner does not want a fee-origin store. This overrides the narrower 2026-11-02 emission sentence. `Compounded()` still has no fields. `Donation()` fields were not named.

F12. Owner authority is a live check that the caller is the address currently returned by `feeTo()`. This replaces stored-owner checks. Implement new ownership and operable modifiers. Do not reuse the existing facets for that check. Reuse `OperableRepo` to store operator authorizations. This overrides the 2026-11-02 sentence that initialization stores `feeTo()` as the owner `onlyOwnerOrOperator` uses. The owner identified this as a major change and said the directive overrides the earlier statements.

Three items are already plan scope. They are not questions:

- Add this vault to the integration testing matrix.
- Add it to the integration tests.
- Test that the vulnerabilities in `docs/security/audit/second_review` are not present in this new vault.

A locked sentence that keeps a reported mechanism cannot also be tested as absent unless that finding is accepted or the rule is replaced.

## Owner overrides, 2026-11-04

These sentences override the earlier sentences they name. They are applied in the PRD. They are not an implementation.

`Compounded()` has no arguments. That empty argument list is final. It replaces any reading of F7 that left the `Compounded()` argument list open. `Donation()` has no fields. It is a marker event, not an interface. That empty argument list is final and replaces the F7 sentence that said `Donation()` fields were not named. The absence test pins both empty events.

The owner may appoint both a global operator and a function-level operator. Follow the Crane operable model: `setOperator(address,bool)` and `setOperatorFor(bytes4,address,bool)`, stored in `OperableRepo`. The maintenance check is the live `feeTo()` owner, a global operator, or a function operator for that selector. Only the live owner may appoint. Do not gate appointment with a stored owner, and do not store `feeTo()` as that owner. This adds the function-level arm. It does not replace the live `feeTo()` owner check in F12.

Disable follows the live V2 call site, widened to every execution route. Block every execution route except a withdrawal, `donate`, and `compound`. A withdrawal is share in and underlying out. A pass-through is not a withdrawal. Views do not revert. A missed deadline still reverts `DeadlineExceeded` before the disable check. `donate` and `compound` may run while the vault is disabled.

The testing inventory is the 45-ID table now restated in the PRD at FS-TEST-04, copied from `docs/research/se-fullspread-plan-readiness-20261101/REPORT.md`. Copy the yes, no, and integration-only marks. Replace the expected results of 023, 024, 039, 044, 045, and 048 with the PRD rows. Replace the report sentence that said booked-remainder rows cannot pass. Do not treat an "expected result blocked" cell in that report as still open. Do not add an audit ID. Status sentences in this file that say the PRD has not been edited are stale. They are not locks.

## Sources

| Member | Original | Advisory | Original blocker count |
| --- | --- | --- | --- |
| Astra | `docs/research/se-fullspread-plan-readiness-20261101/members/astra/response.md` | `members/astra/feedback.md` | 11 |
| Grok | `members/grok/response.md` | `members/grok/feedback.md` | 13 |
| MiniMax | `members/minimax/response.md` | `members/minimax/feedback.md` | 3 |
| Kimi | `members/kimi/response.md` | `members/kimi/feedback.md` | 7 |

PRD: `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` in this directory.

Function review: `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` in this directory.

Audit: `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`.

Tracker: `docs/security/audit/second_review/REMEDIATION_TRACKER.md`. The tracker closes APEX-2026-011, 041, 042, and 051 by deleting the old FullSpread code. That deletion does not certify this vault.

## Open decisions

### B-01. Usage fee versus APEX-2026-044

Decision: locked 2026-11-01. On a new deposit, take the fee shares from the new shares that deposit mints. Do not mint them on top.

Raised by: Astra, Grok, MiniMax, Kimi.

PRD: FS-OWN-24. When shares are minted, if `feeTo` is not `address(0)`, mint `mulDiv(sharesMinted, usageFeeOfVault(address(this)), 1e18)` additional shares to `feeTo`. That sentence stays until the single council PRD pass. This lock replaces it for the plan.

The current ERC-4626 vaults mint the depositor's full shares, then mint extra shares to `feeTo`. Nothing is taken from the depositor. The extra shares dilute everyone already in the vault. There is no exit fee, so a deposit-and-redeem round trip moves value from existing holders to `feeTo` while the cycler pays only a small slice. The audit measured about 95 times the cycler's cost at the live 5% fee. An operator can also set the fee to 100% in the same block. The audit calls this APEX-2026-044.

The owner accepted the auditor's remedy. Existing-holder dilution is not an accepted exception.

If `feeTo` is not `address(0)`, let `grossShares` be the shares that new deposit would mint before the fee, and let `feeShares = mulDiv(grossShares, usageFeeOfVault(address(this)), 1e18)`. Mint `feeShares` to `feeTo` and `grossShares - feeShares` to the depositor. Do not mint any shares beyond `grossShares`. If either amount is zero, skip that mint. This applies to a one-sided deposit and a bundle deposit, including the first deposit. On the first deposit, `grossShares` is `added liquidity - 1,000`. The fee is taken from those minted shares, as it is on a later deposit. The 1,000-share floor is a separate mint to `address(0)`. It is not part of `grossShares`, and it is not a fee mint. Do not mint a fee on the fee shares. On a later deposit, supply grows only by `grossShares`. On the first deposit, supply grows by `grossShares` plus the floor.

`previewExchangeIn`, `previewExchangeBundleInForSingleOut`, and `minAmountOut` use the depositor's net shares. The usage fee is charged only when this vault mints shares. A pass-through does not take that fee. An underlying-to-underlying `exchangeIn` is a pass-through: it abstracts the pool swap and mints no shares. The owner locked that on 2026-11-02. This vault has no exact-out route, so the audit's exact-out gross-up is not adopted. No delay on fee increases, no exit fee, and no new 0% override are added.

The Fee Oracle is not restricted. It may still store any WAD percentage up to `1e18`, including a per-vault override, because other vaults may need those values. This vault clamps the usage fee it applies. When it reads `usageFeeOfVault(address(this))`, a resolved fee above 30% is used as 30%. A resolved fee of 30% or less is used as read. 30% is `3e17` in the existing WAD unit, where `1e18` is 100%. The clamp is in this vault's read. It does not write the oracle.

The same clamped fee is the fee in the netting formula and in the share previews named above. Do not preview the raw oracle fee and execute the clamp. Do not apply it to a pass-through.

The required precision is the ability to charge 0.001%. That is `1e13` in the WAD unit. The existing `mulDiv` against `1e18` already has finer precision, so use it. Do not round the fee to three digits. Do not add a minimum fee. A configured fee of zero stays zero.

This replaces the earlier sentence that left the 100% fee uncapped. A configured fee above 30% does not give the depositor zero shares.

A test that "044 is absent" means this rule: no additional unbacked mint, and a round trip does not move existing holders' value to `feeTo`.

Question answered: the replacement fee rule is the auditor's netting rule, as written above.

### B-02. Live-price deployment and unbounded swaps versus APEX-2026-023 and APEX-2026-024

Decision: locked 2026-11-01. The sleeve is dropped. Only the owner or an operator may compound fees. The entry and redemption swap limits stay unbounded. A redemption swaps only the withdrawn net.

The owner will drop the sleeve. There is no local liquidity sleeve. Do not keep a target from `liquidReservePercentageOfVault`. Do not move a local balance toward that target after a deposit, a withdrawal, or `compound()`. FS-OWN-04 and FS-OWN-12 are replaced for the plan by this sentence. The PRD is not edited until the single council pass.

`compound()` is restricted to the owner or an operator. Any other caller reverts. A deposit, a withdrawal, and `exchangeIn` do not call `compound()`. The 2026-11-03 override replaces the owner half of this guard: the owner check is a live `feeTo()` read, not the stored owner, and the existing facet is not reused. Operator authorizations stay in `OperableRepo`.

`compound()` and `donate()` follow the booking rule locked 2026-11-02 below. A one-token call may swap fees or a booked remainder. A call that already holds both tokens is a proportional deposit and does not swap. Neither call swaps the deployed position. The 2026-11-02 initialization sentence, that the stored `feeTo()` address is the owner `onlyOwnerOrOperator` uses, is overridden on 2026-11-03. Owner authority is the current `feeTo()` address, checked live. An operator authorized in `OperableRepo` may still call these functions. A sandwich of that call can still sell the fees or the booked remainder. The owner accepts that exposure and will tell users that the protocol manager can do it.

This lock does not add a price check, a tick bound, or a fee cap. A sandwich of the owner or operator's own `compound()` can still place the matched fees at a moved price. The owner accepts that remaining exposure. It is the best they can do.

The entry swap limit stays `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. The redemption swap uses that same unbounded limit. There is no new price check, tick bound, or fee cap. A caller who sets no minimum can sell their own input at the live price. That sale does not spend the staying holders' inventory.

A redemption swaps the exiting holder's principal plus that holder's fee and booked claim from the 2026-11-03 F2 override. It does not swap the other holders' booked fees. It does not sell the staying holders' inventory. This is a quantity sentence, not a new cap. A test that "024 is absent" means this rule: a one-token exit swaps the exiting claim only, not the vault's whole opposing balance.

This vault can be included in a batch swap with other Uniswap V4 pools. That is not a revert. The earlier exclusion is removed. The borrowed-unlock path stays. The owner locked that on 2026-11-02.

Raised by: Astra, Grok, MiniMax, Kimi.

PRD: FS-OWN-14 makes `compound()` permissionless and deploys booked idle. FS-OWN-12 moves the sleeve toward its target after every deposit, withdrawal, and compound. Those two sentences are replaced for the plan by the lock above. FS-OWN-15 takes deployed liquidity first and may swap through the pool for volume. FS-MONEY-01 sets the entry swap limit at `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. FS-OWN-10 forbids a replacement zap view, zap cap, or `maxZapTickMove`. It does not already authorize a new maintenance price guard.

APEX-2026-023 is the old FullSpread maintenance path. It sized the mint from the live pool price. Nothing checked that price against the price before the transaction. An attacker can push the price, then cause the vault to deploy at that bad price. When the price returns, the loss sits in the position and the other holders bear it. The old code did this from a permissionless rebalance and again after its own redemption swap.

APEX-2026-024 is the Wings case of a large exit selling the opposing balance at a minimum or maximum price limit. This vault has no Wings core, but it does have a one-token exit and the same unbounded limit. A redemption that swaps only the exiting holder's fraction is not the same as a redemption that sells the vault's whole opposing balance.

The plan cannot claim 023 is fully absent. Permissionless sleeve placement is absent. The accepted remainder is a sandwich of the owner or operator's own `compound()`. The plan can claim 024 is absent under the withdrawn-net rule above.

Question answered: the unbounded limits stay, and a redemption swaps only the withdrawn net.

### B-03. `compound()` when there are no fees

Decision: corrected 2026-11-02. There is no sleeve target. A call with no fees, no donation, and no booked remainder returns with no state change and no event. A booked remainder is still processed.

Raised by: Grok, Kimi. Astra would close it. Grok's advisory kept it open.

PRD: FS-OWN-14 says `compound()` deploys booked idle. The same lock says that if there are no fees, the call returns without a state change and without an event. The sleeve drop removes the idle sentence. The no-fee sentence wins.

Question answered: a call with no fees, no donation, and no booked remainder returns unchanged. A booked remainder is still processed. The undeployable-fee case stays in B-11.

### B-04. Positive supply and zero deployed liquidity

Decision: closed 2026-11-02. Unreachable after the sleeve drop. No denominator is chosen.

Raised by: Astra, then narrowed by Grok's advisory.

PRD: FS-MONEY-01. For an existing supply, `frame.shares = (uint256(frame.liq) * v.totalShares) / v.liquidity`. Idle balances are not in that denominator.

That liquidity-only rule stays locked. It is not reopened here.

Astra's zero-liquidity state was an all-local sleeve: shares outstanding, and every token held locally, so the existing-supply formula divided by zero. The sleeve drop removes that path. The 1,000-share floor is minted inside the first deposit, not before it. A later withdrawal cannot take the last liquidity unit while those floor shares remain. No locked function pulls the position to zero and leaves the shares behind. The division is not given a special case.

Question answered: the state is not reachable, so the call does not need a zero-liquidity denominator.

### B-05. One-token donation

Decision: locked 2026-11-02. `donate` is `onlyOwnerOrOperator`. A one-token underlying donation swaps its own tokens into the position's ratio and deploys that liquidity. If the combined balance already holds both tokens, the call is a proportional deposit and does not swap. It reverts when `totalSupply` is zero. The owner confirmed that both-token reading on 2026-11-02.

Raised by: Astra, Kimi. Grok first treated donation custody as closed, then accepted this question in advisory.

PRD: FS-OWN-21. An underlying donation is deployed into the pool before `donate` returns. It is not left as idle. A share donation burns the shares and does not withdraw. The caller restriction, the swap, and the zero-supply revert replace the missing conversion rule for the plan. The PRD is not edited until the single council pass.

The one-token swap spends the donated tokens only. It does not take the holders' opposite token. It does not run when the combined balance already holds both tokens. That call deposits the matched pair and does not swap. It uses the same unbounded price limit as the entry swap. There is no new price check, tick bound, or fee cap. A sandwich of the owner or operator's own call can still sell the gift at a moved price. The owner accepts that remaining exposure. The existing position is not what gets sold.

No shares are minted. A share donation still burns the shares and does not withdraw, and it does not swap the shares. Held tokens processed because `donate()` also compounds follow the same one-token or both-token rule. A deposit, a withdrawal, and `exchangeIn` do not call `donate`.

If `totalSupply` is zero, `donate` reverts before any swap. There is no donation before the first mint. A remainder is booked, not returned to the donor. The booking rule below replaces the earlier return-to-caller sentence.

Question answered: a one-token donation swaps itself into the ratio. A donation or compound that already holds both tokens is a proportional deposit and does not swap. The caller is the owner or an operator, and a zero-supply donation reverts.

### B-06. Which views may revert

Decision: locked 2026-11-02. No view reverts by a vault error. An unsupported view route returns zero. The execution route still reverts.

Raised by: Astra, Grok, Kimi.

PRD: FS-OWN-19 says no view reverts. An unknown `reserveOfToken` returns zero. FS-A32 says busy-vault economic views revert, while an idle vault answers during an unlock. `previewExchangeOut` reverts `ExchangeOutNotAvailable()` because this vault has no exact-out route. Those view reverts are replaced for the plan by this lock. The PRD is not edited until the single council pass.

A view with no supported route returns zero. `previewExchangeOut` returns zero. `exchangeOut` still reverts `ExchangeOutNotAvailable()` and moves no tokens. A zero preview is not a promise that the execution route succeeds.

A busy or unlocked manager is not a view revert. Economic views return the computed value. `reserves()` and `reserveOfToken` wrap the deployed-reserve reads. There is no local term and no last-committed snapshot. The owner locked that on 2026-11-02. It replaces the local-plus-deployed specification. The deployed read remains the live position: the position's current token amounts plus unpaid fees, using the existing reads, with no new formula. A booked local remainder is not in that read. There is no new step-cap error. An out-of-gas revert is an EVM error, not a vault error, and this lock does not define one.

Question answered: no view has a coded revert. An unsupported view returns zero. Execution of an unsupported route still reverts.

### B-07. Proxy getters and package inputs

Decision: locked 2026-11-02. The Protocol Aware facet and the package addresses are locked below. The position getters are `UniswapV4SinglePositionAware`, also locked below.

The Uniswap V4 architecture addresses are package immutables, set when that package is deployed, as the other package bindings are. They are the PoolManager, Position Descriptor, Position Manager, Quoter, State View, Reserves Lens, and Universal Router. A deployment on another chain uses the same package code and passes that chain's addresses. Do not hardcode `ROBINHOOD_MAIN.sol` into the package. Those constants are the Robinhood values, not the storage rule.

When the package initializes a vault instance, it writes those immutable addresses into the Uniswap V4 Protocol Aware Repo. The repo is not given a second per-vault copy of the addresses.

Implement the Uniswap V4 Protocol Aware Facet in the Crane submodule, under `lib/crane/contracts/protocols/dexes/uniswap/v4/aware`. The facet exposes the stored components. This vault's package takes that facet as a package input and uses it to initialize the vault instances. The getters on that facet are externally callable on this vault. Do not implement a family `poolManager()` selector.

The Crane work includes tests for that facet. Those tests live in Crane. They are part of this directive, not a later optional pass.

Raised by: Astra, Grok, Kimi.

PRD: `queryFacet` is still marked under function review. FS-OWN-01 places `poolManager()` in a Protocol Aware repo and facet. FS-OWN-18 names seven stored components. FS-OWN-16 writes only `PkgInit.poolManager` into that repo. Those sentences are replaced for the plan by the lock above. The PRD is not edited until the single council pass.

The position getters are a second Crane pair, `UniswapV4SinglePositionAware`: one Repo and one Facet. It is reusable by other vaults with different position configurations. It is a package input on this vault, and its getters are externally callable. Do not put a family-only `poolKey()` selector on the full-spread query facet.

The repo stores the full `PoolKey` for that vault instance. A `PoolKey` identifies the pool, not the position, so the repo also stores `tickLower`, `tickUpper`, and the position salt. Those four values are instance storage, written when the package initializes the vault. They are not package immutables, because another vault can use another pool or another range. This vault's range is the full-range position and its salt is `bytes32(0)`.

The position read uses `StateLibrary` against the PoolManager. That is the on-chain read of a position owned directly by the diamond. `StateView` is the off-chain wrapper of the same read, so it is not the vault's dependency. `PositionManager` reads an NFT position this vault does not hold. `positionLiquidity()` wraps `StateLibrary.getPositionInfo` for this diamond, the stored ticks, and the stored salt. It returns that position's liquidity, not a token amount and not the whole pool's liquidity.

`localReserves()` was the sleeve balance. The sleeve was dropped. This facet does not restore that balance and does not grow a local-reserve getter.

Crane tests for `UniswapV4SinglePositionAware` are part of this directive, beside the Protocol Aware facet tests. The code is not written by this lock.

Question answered: both facets are Crane package inputs. The position facet is `UniswapV4SinglePositionAware`. Its getters are callable. The position read is `StateLibrary` on the PoolManager.

### B-08. Hook rows that need a rate provider

Decision: locked 2026-11-02. This vault has no rate. A hook leg uses a rate-provider instance deployed for this vault and one rate target. The vault does not know that provider.

Raised by: Astra, Kimi. Grok would remove this question and leave it as the existing FS-HOOK-04 record.

PRD: FS-OWN-29 and FS-OWN-03. This vault does not implement `getRate()`. Do not install `StandardExchangeRateProviderFacet` on this vault, and do not bind that facet and call its result this family's rate. FS-OWN-03 stays closed.

Rate-provider instances are deployed by `IStandardExchangeRateProviderDFPkg` for a configured Standard Exchange vault and rate-target pair. `PkgArgs` carries `reserveVault`, `rateSubject`, and `rateTarget`. One vault can have as many of those instances as it has `vaultTokens()`. That count is the maximum useful number, not an enforced limit. Do not add a cap.

This vault stores no rate-provider address and exposes no rate-provider getter. The hook configures a rate-provider address for each Standard Exchange liquidity leg. The required hook rows use that configured instance. They do not derive a provider from this vault, and they are not recorded incompatible. The rows include these scenarios. The rate subject is this vault, used as liquidity in the test pool. There is a scenario for each underlying token, so the rows test that this vault can be rated and that the integrated token can be token0 or token1. Separate pools may hold the same vault, each with a rate provider whose `rateTarget` is a different underlying token. That tests two pools valuing the same vault at different targets. The owner locked those scenarios on 2026-11-02.

The accepted preview returns `(uint256 amountOut, uint256 amountRefunded)`. The rate provider, and every other consumer of the old 32-byte return, must be updated to read that tuple. The single council PRD pass enumerates those consumers. This lock does not make that list, and it does not add a vault rate.

Question answered: the hook configures an externally deployed rate-provider instance. This vault does not know it.

### B-09. Borrowed one-token exit units

Decision: closed 2026-11-02. The unpullable borrowed exit does not occur. No token unit is chosen for that error.

Raised by: Astra, then narrowed by Grok's advisory.

PRD: FS-OWN-31. If another caller holds the unlock and this vault cannot pull the deployed fraction, pay the caller's local fraction from the sleeve, or revert `UnderlyingUnavailable`. The sleeve was dropped in B-02. The V4 council found no rule that withholds the owner's position while the manager is unlocked. Report: `docs/research/se-v4-unlock-sleeve-20261102/REPORT.md`.

On a borrowed unlock the vault does not call `unlock()`. It calls `modifyLiquidity` and `swap` directly. A one-token exit pulls the caller's deployed fraction and swaps only the withdrawn net, on that same open flag. There is no sleeve payment and no `UnderlyingUnavailable` for an unpullable fraction. The vault settles its own deltas before it returns.

The manager does not refuse that call. The call fails only if this vault's own code calls `unlock()` again, or if the hook never calls the vault. Neither is a sleeve case.

Question answered: the deployed fraction can be pulled, so `required` and `available` have no case to measure.

### B-10. Share units and decimal scaling

Decision: locked 2026-11-02. The deployed reserve is one raw liquidity number. Share minting and burning use that number. Token decimals do not enter the share formula.

Raised by: Astra, Grok.

PRD: FS-OWN-27. Share `decimals()` is 18. Scale and unscale internal amounts to each underlying token's decimals. FS-MONEY-01 says the first mint is raw V4 liquidity minus 1,000 and does not rescale that constant. The share formulas below replace the unresolved conversion for the plan. The PRD is not edited until the single council pass.

The deployed reserve is accounted as one value, `liquidity`, by the Weir method. It is raw V4 liquidity. Token amounts stay in their own decimals when they go into `getLiquidityForAmounts`. No amount scaled to a token's decimals, and no use of `decimals()`, enters the share formula.

The first deposit cannot divide by existing liquidity. Before the fee, the minted shares are `added liquidity - 1,000`. The fee is taken from those shares under B-01, as it is on a later deposit. The depositor receives that amount minus `feeShares`. The `1,000` floor stays in `totalSupply`. It is not credited to the depositor, and it is not part of the fee.

After the first deposit, mint `added liquidity * totalShares / existing liquidity`. On a burn, remove `liquidity * shares / totalSupply`. `totalSupply` includes the floor, so the burn uses the whole supply.

`decimals()` returns 18. That is metadata. It is not a scale, and it is not an input to the mint or burn. The stored share balance is the liquidity number from the formulas above. Do not multiply it, or the floor, by a constant to match `decimals()`. The owner locked that on 2026-11-02. A wallet that divides the balance by `1e18` is formatting the liquidity number. It is not reading a rescaled share.

Question answered: genesis shares before the fee are raw liquidity minus 1,000. The fee is taken from those shares. Later mints and burns use the formulas above. Token-decimal scaling does not enter them. There is no share-side scale.

### B-11. `Compounded` amount and undeployable fees

Decision: locked 2026-11-02. Emit `Compounded()` with no fields when fees are compounded into the reserve. Amounts come from the PoolManager events. The owner confirmed that emission rule on 2026-11-02.

Raised by: Astra. Kimi added the undeployable-fee case. Grok accepted the event gap in advisory.

PRD: FS-OWN-14. Emit `Compounded(address indexed token, uint256 amount)` once for each token with a nonzero compounded amount. That signature is replaced for the plan by the lock below. The PRD is not edited until the single council pass.

The vault does not emit its own swap or liquidity-add event. The PoolManager already emits `Swap` and `ModifyLiquidity` with the vault as `sender`. Filter on that sender for the amounts, price, and liquidity. A caller deposit or withdrawal is correlated by the Standard Exchange event in the same transaction. The 2026-11-02 emission sentence is overridden on 2026-11-03. Emit `Donation()` when `donate()` is called. Emit `Compounded()` when a deposit is made from collected fees or booked tokens, including a `compound()` call that deposits. Booked tokens count, including a booked donation remainder. `Compounded()` still has no arguments. A call that deposits nothing does not emit `Compounded()`.

A call with no fees, no donation, and no booked remainder returns with no state change and no event. A remainder after a best-effort deposit is booked. It is not a sleeve, and it is not returned to the caller. The call does not revert merely because a remainder remains.

Question answered: the event carries no amount. The PoolManager events carry the amounts.

### Donation and compound booking

Decision: locked 2026-11-02.

`donate()` also compounds. It uses tokens already transferred when `pretransferred` is set, and pulls the directed amount otherwise. `compound()` has no donation input. Both then take collected fees and the booked remainder and process that combined balance.

One token: swap toward the position's ratio, as a one-sided user deposit does. The remainder must be in the token being processed. Book that remainder. Both tokens, from any mix of fees, donation, and an already booked balance: do not swap. Deposit the matched pair. The scarcer token is the proportionally smaller amount relative to the position ratio, not the smaller raw balance. That token is fully used. Book the excess of the other token. The owner locked that reading on 2026-11-02.

Book the actual held balance after the deposit, not a calculated leftover. That books a stray transfer as well. A non-atomic pretransfer can be booked too. Callers must keep a pretransfer atomic. Best-effort means the simplest secure process. Do not invent an extra attempt, a fallback, or a swallowed failure to force a cleaner result. A failed step reverts. A remainder of that simplest deposit is booked. The owner locked that reading on 2026-11-02. A deposit, a withdrawal, and `exchangeIn` do not deploy or swap a booked remainder.

The 2026-11-03 F2 override replaces the principal-only payment sentence. A share-minting deposit books `feesAccrued` and does not deploy or swap it. A withdrawal pays the caller their rounded-down share of `feesAccrued` and of the booked balances, and books the rest.

`reserves()` wraps the deployed-reserve reads. It does not add a local term. A booked remainder is not deployed, so it is not in that read until a later `donate()` or `compound()` deploys it. Unpaid fees are in the deployed read. That replaces the earlier sentence that excluded uncollected fees from `reserves()`. The withdrawal rule is the 2026-11-03 F2 override: pay the caller their share of the collected fees and booked balances, and book the rest. The size of a remainder does not matter. Call `compound()` again to process it. The owner locked the wrap on 2026-11-02.

The deployed position is not swapped. The one-token path does swap holder-owned fees and booked remainders. Owner restriction does not stop a sandwich of that call.

### B-12. Paired event signatures

Decision: locked 2026-11-02. The bundle routes emit `PairDeposited(address indexed caller)` and `PairRedeemed(address indexed caller)`. No other arguments.

Raised by: Grok. Kimi and Astra agreed the ABI is observable and still open.

PRD: FS-OWN-09 says paired events survive the selector drop. The function review says `PairDeposited` and `PairRedeemed`, or renamed equivalents, are still emitted. These signatures replace the missing argument lists for the plan. The PRD is not edited until the single council pass.

The event name identifies the operation. `caller` is the indexed address that called the route, so a log can be filtered by caller. The ERC-20 `Transfer` records the share mint or burn. The PoolManager events record the token amounts. This vault does not repeat those amounts in the paired events.

Question answered: the names stay `PairDeposited` and `PairRedeemed`, and the only argument is the indexed caller.

### B-13. Pretransfer attribution versus APEX-2026-039

Decision: locked 2026-11-02. The project directive is `docs/vaults/PRETRANSFER_DIRECTIVE.md`. A pretransfer declares a held unbooked balance. It does not claim the whole sitting balance.

Raised by: Astra. Kimi's advisory agreed it should be added. Grok and MiniMax dissent: they say the existing rules are enough to write the absence test. The owner locked the directive anyway.

PRD: FS-OWN-20. A pretransfer books only the requested amount. Unbooked balances are not reserves. Unused input is refunded to the payer. A burn uses the caller's shares. The directive replaces the missing attribution rule for the plan. The PRD is not edited until the single council pass.

The vault does not ask where the tokens came from. `pretransferred == true` uses the unbooked held balance, up to the caller's maximum. A booked remainder is not that balance. If that maximum is within the unbooked balance, the refund is the maximum minus the amount used, in the token the caller provided. If the maximum is larger than the unbooked balance, refund the unbooked balance. Do not refund maximum minus used in that case, and do not pull the shortfall. A non-atomic pretransfer is the caller's risk. An address without bytecode cannot pretransfer. The owner locked the overstated-maximum refund on 2026-11-02.

A balance sitting on the vault is not the caller's credit beyond that maximum. The unbooked remainder is not sent to `msg.sender`. A burn uses the caller's shares. Shares parked on the vault are not that credit. That is the absence of APEX-2026-039.

Question answered: the directive is the exclusion. The 039 path is not an accepted use.

## Raised, and not carried as owner questions

These were in a member original or in the draft. They are recorded so they are not lost. Reopen one only by an explicit lock. Do not treat the coordinator note as that lock.

### N-01. Address-zero floor versus `ERC20InvalidReceiver`

Raised by: Grok. MiniMax and the coordinator checked the mint path and removed it.

FS-OWN-11 mints 1,000 shares to `address(0)`. `ERC20Repo._increaseBalanceOf` reverts `ERC20InvalidReceiver` for `address(0)`. `ERC20Repo._mint` does not call that helper. The call is commented out. The mint writes `balanceOf` and `totalSupply` directly. The sibling V3 vault uses a dead address, not `address(0)`. This vault's lock is `address(0)`, through `_mint`.

Not a blocker. The holder does not change.

### N-02. Fee base including the floor or the fee shares

Raised by: Grok.

FS-OWN-24 already names the base as `sharesMinted`. The floor mint is not part of B-01. B-01 locks that the extra mint does not stay: fee shares are taken from the new deposit shares. Do not compound the fee on the fee shares.

### N-03. Sleeve adjustment swap

Raised by: Grok. Astra and the coordinator did not carry it.

The sleeve was dropped on 2026-11-01 in B-02. There is no sleeve adjustment, so this swap question is closed. This note does not delete the one-token redemption swap, the one-token donation or compound swap, or the `exchangeIn` pool swap. Those stay under their own locks.

### N-04. Quote step cap, fallback, and tick spacing

Raised by: MiniMax. Astra, Grok, and Kimi did not add it. MiniMax dissents.

The deleted FullSpread vault quoted swaps with a 64-step limit and reverted `QuoteWorkLimit` when the quote could not finish. On a hookless pool, anyone can place one-wei positions on consecutive ticks. Each position consumes a quote step. After enough of them, deposit, redeem, and swap quotes revert. APEX-2026-026 is the Wings form, a hard 512-step liquidation quote. APEX-2026-051 is the analytic form: a preview promised shares that execution rejected because an impact check did not run.

FS-OWN-22 accepts any initialized hookless pool. It does not name a quoter method, a step cap, a fallback, or a minimum spacing.

The plan must not invent a 64-step cap, a minimum tick spacing, a partial fill, or a failure mode for a quote that cannot finish. The owner rejected that case on 2026-11-02. This vault's quote is the mathematical result of the operation. Do not choose a V4 quoter against an analytic planner as a product rule. Dust-tick liveness is the APEX-2026-041 regression: a normal deposit and redeem must not depend on an undocumented cap. That is a test, not a new spacing rule.

### N-05. WETH storage home

Raised by: Grok. Astra did not carry the storage question.

Remove `PkgInit.wrappedNative`. The vault does not accept or produce native ETH. There is no `wrappedNative()` getter. Callers send and receive WETH only. The owner locked that removal on 2026-11-02.

### N-06. `SwapProjection` and `ExecutionPreparation`

Raised by: Grok. Astra treated this as code organization. Kimi wanted it split from the event question, which is B-12.

The package still lists both libraries. PairToken economics are not inherited. The slots stay. The engineer assigns already specified operations to them. The owner is not asked to design the libraries.

### N-07. Reopening liquidity-only issuance

Raised by: Astra, as the sleeve-claim transfer. Narrowed to B-04.

B-04 was closed on 2026-11-02. The zero-liquidity state depended on the sleeve, which was dropped. Do not reopen liquidity-only issuance. Reopen it only to change FS-MONEY-01.

## Matrix files

The plan extends these live behavior contracts under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`:

- `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`
- `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`
- `dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`
- `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol`
- `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`
- `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`
- `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol`

It adds a row for this vault beside those contracts. It does not edit their assertions for other families.

Exact-output success rows cannot pass here. `exchangeOut` reverts `ExchangeOutNotAvailable()`, and `previewExchangeOut` returns zero. A user's unused input is refunded. A donation or compound remainder is booked, so those rows stay. These are adaptations of this family's rows, not permission to weaken the other families.

`docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json` has historical V4 FullSpread compatibility rows. Their cited tests are not current proof of this family. The followup-review snapshots are not the current matrix. Preserve the V3 rows. Replace the stale V4 FullSpread rows rather than treating them as passed.

Evidence files named by the members, for the plan to update rather than treat as passed: `hook-se-matrix.json`, `hook-se-matrix-findings.json`, `hook-se-matrix-finding-descriptions.json`, `docs/audits/apex-2026-09-17-evidence.md`, and `docs/audits/apex-2026-09-17-evidence/acceptance.json` item R10.3.

## Audit tests

The full 45-ID disposition is in the council report. These rows are no longer waiting on an open item. Do not read a closed row as reopened.

APEX-2026-044 no longer waits. B-01 locks its absence test: fee shares come out of the new deposit shares, and `previewExchangeIn` and `minAmountOut` use the net shares.

| Finding | Waits on | Why |
| --- | --- | --- |
| APEX-2026-023 | B-02, accepted in part | Permissionless placement of a sleeve is absent. The owner accepts the remaining exposure: a sandwich of the owner or operator's own `compound()` can still place matched fees at a moved price. The absence test must not claim that exposure is gone. |
| APEX-2026-024 | B-02, absent | A redemption swaps only the withdrawn net. It does not sell the staying holders' inventory. The unbounded price limit stays. The absence test is the quantity, not a price check. |
| APEX-2026-039 | B-13, locked 2026-11-02 | The absence test is the pretransfer directive. A pretransfer uses the unbooked balance up to the caller's maximum. It does not take parked shares or the whole sitting balance. |
| APEX-2026-048 | closed 2026-11-02 | A call with no fees, no donation, and no booked remainder returns unchanged. A remainder is booked and does not freeze a later route. |

## Already locked, and not reopened by this list

- The 1,000-share floor is minted to `address(0)` and is part of `totalSupply()`.
- This vault does not implement `getRate()` or `rateAsset()`.
- Callers send and receive WETH only. The vault does not accept or produce native ETH. `PkgInit.wrappedNative` is removed. Native ETH is wrapped or unwrapped only at the pool boundary.
- Unused input is refunded to the payer. It does not become shares and it is not left for other holders.
- A one-sided share mint runs the balancing swap. A bundle deposit does not.
- A redemption on the vault's own unlock pays the exiting holder's principal plus that holder's share of collected fees and booked balances, under the 2026-11-03 F2 override. The no-leftover-shortfall-revert sentence is scoped to the former sleeve. A one-token exit that cannot convert the unwanted side of that claim reverts `AmountOutNotMet` and does not burn shares.
- If another caller holds the PoolManager unlock, this vault does not call `unlock()`. It calls `modifyLiquidity` and `swap` directly, pulls the caller's deployed fraction, and settles its own deltas before returning. There is no sleeve fallback and no `UnderlyingUnavailable` for an unpullable fraction. Closed 2026-11-02 in B-09.
- There is no local liquidity sleeve. Do not keep a `liquidReservePercentageOfVault` target, and do not move a local balance toward one. Locked 2026-11-01 in B-02. FS-OWN-04 and FS-OWN-12 are not edited until the single council PRD pass.
- Positive supply with zero deployed liquidity is not a reachable state. B-04 does not add a zero-liquidity issuance denominator. Closed 2026-11-02.
- The deployed reserve is one raw liquidity number. On the first deposit, the pre-fee minted shares are `added liquidity - 1,000`. The fee is taken from those shares, and the depositor receives the net. The floor stays in `totalSupply` and is not part of the fee. Later mints use `added liquidity * totalShares / existing liquidity`, and the fee is taken from those shares the same way. Burns remove `liquidity * shares / totalSupply`. Token decimals do not enter those formulas. `decimals()` returns 18 and does not scale the stored balance. Locked 2026-11-02 in B-10. The owner confirmed the genesis fee and the unscaled unit the same day.
- `donate()` and `compound()` are authorized by the 2026-11-03 owner rule: the caller is the current `feeTo()`, or an operator stored in `OperableRepo`. The 2026-11-02 stored-owner initialization sentence is overridden. An operator may still call them. A one-token call may swap fees or a booked remainder. A call that already holds both tokens is a proportional deposit and does not swap. The owner confirmed that reading on 2026-11-02. The deployed position is not swapped. A remainder is the actual held balance and is booked, not returned. It is not in `reserves()` until deployed. `reserves()` wraps the deployed-reserve reads, including unpaid fees, and has no local term. A withdrawal pays the exiting holder's FS-OWN-30 claim. The principal-only sentence is overridden by the 2026-11-03 F2 rule.
- The entry and redemption swap limits stay unbounded. A redemption swaps only the withdrawn net. It does not sell the staying holders' inventory. There is no new price check. Locked 2026-11-01 in B-02.
- Views do not revert by a vault error. An unknown token and an unsupported view route return zero. `previewExchangeOut` returns zero. `exchangeOut` still reverts `ExchangeOutNotAvailable()`. A busy or unlocked manager is not a view revert. `reserves()` wraps the deployed-reserve reads. There is no local snapshot. Locked 2026-11-02 in B-06. FS-OWN-19 and FS-A32 are not edited until the single council PRD pass.
- Share donation burns shares and does not withdraw.
- A bundle deposit emits `PairDeposited(address indexed caller)`. A bundle redeem emits `PairRedeemed(address indexed caller)`. No other arguments. Locked 2026-11-02 in B-12.
- A pretransfer uses the unbooked held balance up to the caller's maximum. If that maximum is within the unbooked balance, the refund is the maximum minus the amount used, in the provided token. If the maximum is larger than the unbooked balance, refund the unbooked balance, do not spend it, and do not pull the shortfall. A larger maximum is not a revert. Booked remainders are not that balance. Locked 2026-11-02 in B-13 and confirmed 2026-11-03. Directive: `docs/vaults/PRETRANSFER_DIRECTIVE.md`.
- `donate` reverts when `totalSupply` is zero. A remainder is booked, not returned to the donor. The booking rule is the 2026-11-02 lock. FS-OWN-21 is not edited until the single council PRD pass.
- A new deposit's usage fee is taken from that deposit's new shares. It is not an extra mint. A pass-through, including an underlying-to-underlying `exchangeIn`, takes no fee. Locked 2026-11-01 in B-01. The pass-through exclusion was confirmed by the owner on 2026-11-02. FS-OWN-24 is not edited until the single council PRD pass.
- This vault clamps its resolved usage fee to 30% (`3e17` WAD). The Fee Oracle is not restricted. The existing WAD `mulDiv` is the calculation. No minimum fee is added. Locked 2026-11-02 in B-01.
- The seven Uniswap V4 architecture addresses are immutables of the package deployment, not hardcoded Robinhood constants. Instance initialization writes them into the Protocol Aware Repo. The Protocol Aware Facet is implemented and tested in Crane, then used as a package input. Locked 2026-11-02 in B-07.
- Position getters are the Crane pair `UniswapV4SinglePositionAware`. It stores the full `PoolKey`, `tickLower`, `tickUpper`, and the salt per vault instance. It reads that position through `StateLibrary` on the PoolManager. It is a tested Crane package input. It does not restore `localReserves()`. Locked 2026-11-02 in B-07.
- This vault has no `getRate()` and does not know its rate providers. A hook leg is configured with an `IStandardExchangeRateProviderDFPkg` instance for this vault and one rate target. The required rows rate this vault as liquidity against each underlying token, including two pools that hold the same vault at different `rateTarget` values. The useful count is `vaultTokens().length`, and that count is not a cap. Locked 2026-11-02 in B-08. The PRD pass enumerates the 64-byte preview consumers.
