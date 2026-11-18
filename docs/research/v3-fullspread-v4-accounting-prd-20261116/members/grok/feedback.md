# Identity

- Member label: grok
- Phase: advisory review
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:high
- Run ID: v3-fullspread-v4-accounting-prd-20261116
- Fresh or continued: continued
- Initial response preserved: yes
- This file replaces a missing initial response: no
- Runtime task id: not exposed
- Runtime model: not exposed
- Runtime provider account: not exposed
- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

# Draft under review

- Draft ID: draft-v3-fullspread-v4-accounting-prd-20261116-r1
- Path: docs/research/v3-fullspread-v4-accounting-prd-20261116/coordinator/draft.md
- Fingerprint: not computed

The named file opened. No other draft was reviewed.

# Disposition

requested-changes

The adopted accounting is the right copy in its main lines: raw-liquidity shares, one 49% exact-input mint, no sleeve, refunds, a one-token exit of the exiting claim only, and no claim that same-pool manipulation is solved. The changes below are places where two implementors of this draft would ship different behavior, or where an open row also answers itself. This feedback does not authorize implementation and does not replace the draft.

# Concerns

### V3-ACC-03 against V3-ACC-05 and V3-ACC-06

The first-deposit failure is both a revert and a successful refund.

V3-ACC-03 says an unusable first deposit reverts and does not succeed as a whole-input refund. V3-ACC-05 says a 49% swap that cannot be formed, is not fully spent, or whose output the mint cannot consume refunds the whole processed input, executes no swap, and mints nothing. V3-ACC-06 says the zero-active-liquidity case refunds the whole input and uses no new error. Neither ACC-05 nor ACC-06 exempts the first deposit.

Those are different calls. A first depositor whose 49% swap cannot be formed is refunded and the call succeeds under ACC-05, or the call reverts and the tokens stay with the caller only because the transaction undoes the pull under ACC-03. The empty-supply rate-provider call is this case when one target unit cannot form a mint.

FS-OWN-33 refunds that input and mints nothing. It is not limited to a later deposit. FS-MONEY-01 separately rejects a formed add whose liquidity is less than or equal to 1,000 with `MinLiquidityNotMet()`. `Planner._shares` sets `failed` when supply is zero and `liquidityAdded <= 1_000`, which includes a zero-liquidity sizing failure. This review did not read V4 execution, so that flag is not by itself a refund-versus-revert rule. The draft's copy note treats it as a revert. The adopted sentences still contain both outcomes.

Advised correction: split the cases and delete the losing sentence. A formed add at or under 1,000 liquidity reverts `MinLiquidityNotMet()`, mints nothing, and is not a successful refund. A swap that cannot be formed, or an add that cannot consume the quoted output, follows FS-OWN-33 on the first deposit as on a later one: refund the whole input, execute no swap, mint nothing, and use no new error. Do not keep "any unusable first deposit reverts" beside those refund sentences.

### V3-OPEN-06

The open row answers the question the open-decision rule says not to answer.

The Open decisions introduction says the PRD must state each open row and must not answer it. V3-OPEN-06 then proposes fail-closed text as the parity rule, rejects a retained exact-out route with the old economics, and still sits in that unanswered list. One reader implements `previewExchangeOut` returns zero and enabled `exchangeOut` reverts `ExchangeOutNotAvailable()`. Another leaves the selectors unspecified because the section forbids an answer. The old search, inverse, and exact-out mint are rejected in the row body and are not in the rejected-alternatives list, so that rejection is also easy to miss.

Advised correction: put the economic rejection in Adopted requirements. The bounded search, the constant-product inverse, and the exact-out mint are not accounting paths. If fail-closed selectors are the parity rule, put that text in Adopted requirements too: `previewExchangeOut` returns zero, enabled `exchangeOut` reverts `ExchangeOutNotAvailable()`, and a disabled `exchangeOut` reverts `VaultDisabled`. Record any dissent that this must be labeled a compatibility decision under Disagreement, where it does not reopen the bytes. If the selector disposition is instead meant to stay open, delete the proposed fail-closed rule from V3-OPEN-06. Do not leave both.

### V3-ACC-09

The reserve exclusion is conditional on an open choice.

V3-ACC-09 says a booked remainder is not a reserve until `donate` or `compound` deploys it, if those operations are adopted under V3-OPEN-02. V3-ACC-11 still leaves fee and booked remainders with the remaining supply whether or not those selectors exist. If V3-OPEN-02 is closed by not adding them, the "if" can be read as dropping the exclusion. One implementor then keeps booked tokens out of `reserves()` and out of the next add. Another puts them back into the reserve read because nothing is left to deploy them.

Advised correction: the exclusion holds either way. Booked tokens are not reserves, are not redeemable, and are not in the next add's budget, whether or not `donate` and `compound` are added. What, if anything, deploys them stays V3-OPEN-02. The "if" must not qualify the exclusion.

### V3-ACC-03

The floor balance is specified. The write that can actually create it is not.

V3-ACC-03 mints 1,000 shares to `address(0)` and includes that balance in `totalSupply()`. FS-OWN-11, which the row says it copies, also says the mint does not revert, and that `ERC20Repo._increaseBalanceOf` and the shared ERC-20 facet path both revert `ERC20InvalidReceiver` for `address(0)`. This vault's current floor uses `ERC20Repo._mint` to the dead sink. Pointing that same path at `address(0)` can revert, so the first deposit never reaches the gross-share mint.

Advised correction: copy the rest of that lock. The floor is a `balanceOf(address(0))` of 1,000 included in `totalSupply()`, the write does not revert, and it does not use a path that reverts `ERC20InvalidReceiver` for `address(0)`. It remains outside `grossShares` and is not a fee mint.

### V3-ACC-05

`processedInput` is not tied to the pull and pretransfer rules in V3-ACC-10.

One reading takes 49% of the declared amount. The other takes 49% of the amount this call can actually use. They differ when a one-token pretransfer maximum is larger than the unbooked credit. V3-ACC-10 says that call does not pull the shortfall. A 49% swap of the declared maximum would spend tokens the vault has not taken.

Advised correction: define processed input as the amount this call will use after the pull, or after clipping to this call's unbooked credit, and before the 49% split. Size the swap from that amount. Refund against that same amount under V3-ACC-10.

### V3-ACC-12 and V3-ACC-18

A failed one-token exit has no preview shape, and the execution revert has no name.

V3-ACC-12 says the preview quotes the same receipt, so `amountOut` matches execution, and that execution reverts without burning if the opposing swap cannot spend the whole claim. A preview cannot both match a reverting execution and avoid a view revert. V3-ACC-15 says a preview does not revert merely because the pool is locked. It does not say what a failed exit preview returns. V3-ACC-18 says a full-book exit that cannot spend the opposing amount previews as a failed plan and the provider then reads a zero rate. A revert and a zero first word both make this provider return zero. Other callers of `previewExchangeIn` do not treat those as the same result.

Advised correction: a completable one-token exit preview returns the receipt execution will pay. A plan that cannot spend the opposing amount does not revert in the preview. It returns a zero first word and is not a successful receipt. Execution of that plan reverts and does not burn. Name the error. FS-OWN-30 names `AmountOutNotMet`. If this vault keeps a V3 error name instead, say that name. Do not leave the preview failure shape or the error identifier to the implementor.

### V3-ACC-01

"One vault-owned full-range position" does not name the V3 ticks.

The absolute minimum and maximum ticks are not a valid V3 position for every spacing. The current center ticks are not full-range if a book is narrower. The 49% add's liquidity depends on the bounds. Two implementors can mint different ranges and still claim this sentence.

Advised correction: the position ticks are `TickMath.minUsableTick` and `TickMath.maxUsableTick` for the bound pool's tick spacing. No minimum tick spacing is added. This sentence does not decide whether import survives.

### V3-ACC-08

"`rebalanceLiquidReserve` no longer moves inventory" does not say whether the selector remains.

A deleted selector and a remaining no-op are different for a current caller. One reverts. The other succeeds and moves nothing.

Advised correction: remove the selector, or keep it and name the revert. Do not leave a successful no-op as an allowed reading.

# What was not adopted from others

Peer responses were not read. Peer feedback was not read. No omitted finding from another member is identified. Unread members are not treated as support. The draft's attributions to Astra, Kimi, and MiniMax were not checked against their files and are not confirmed or denied here.

# Limits

- This feedback is advisory. It does not authorize implementation. It does not replace the draft.
- The named draft was the only draft opened. Its fingerprint was not computed.
- No peer file was read. `response.md` was not edited.
- V4 execution was not read in this pass. The refund-versus-revert correction follows FS-OWN-33 and FS-MONEY-01, not an execution trace of `plan.failed`.
- No test, build, install, deploy, or Git operation was run.
