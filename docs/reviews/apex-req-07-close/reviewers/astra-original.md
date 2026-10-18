# Astra — REQ-07 current-source closure review

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This is an independent first pass. No other reviewers' notes, including any artifacts under `docs/reviews/apex-req-07-snapshots/reviewers/`, were read. No code was edited.

## Verdict

**No implementation gap. Close the current REQ-07 item.** The gas-gated self-snapshot branch described in the historical requirement is absent from the current rate-provider implementation, the wrapped provider does not recreate it, matching caller-supplied snapshot failures are not retried against the live rate, and current tests exercise the specified live/supplied-state distinction.

**Do not relabel the historical alert as an impossible scenario on the evidence reviewed.** No persisted vault snapshot is necessary for a rate provider to make a temporary `quoteState` call and choose behavior based on gas. That is a feasible architecture, and the historical PRD describes such a branch. The present code no longer has it. Current-source closure is supported; proving that the earlier alert was mistaken would require historical implementation evidence not examined here.

Fresh reads of controlling OD-02 **99–111** and REQ-07 **291–304** in `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` succeeded in this pass. No fresh guard denial occurred, and no earlier denied read was bypassed. The requirements preserve caller-supplied transition quotes and the D48 exact-length handling; they do not require deleting ephemeral quote models or storing snapshots.

## Production checks

### Standard provider: ordinary rate path contains neither snapshot acquisition nor gas branching

File: `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol`, read in full.

- **45–46:** `getRate()` enters `_getRate("")`.
- **61–68:** empty state uses the subject's live `totalSupply()`. Only a nonempty supplied state invokes `quoteTotalSupply(state)`.
- **79–82,112–125:** empty state selects the ordinary `previewExchangeIn` ABI call; nonempty state selects `quoteAssets`. The code does not acquire a snapshot first.
- **98–109:** zero-supply initialization also calls the ordinary deposit preview, not `quoteState`.
- There is no `gasleft()` read or `quoteState` acquisition in this facet. A scoped search across the rate-provider source directory found neither, including encoded-selector forms.
- **155–160:** the actual facet selector list exposes `getRate` and `quoteRate`; these are not unreachable helper-only implementations.

This directly proves that the particular forbidden empty-state branch is not a remaining production defect. A callee may internally construct a temporary pricing model, but that is not the rate provider selecting between a self-acquired snapshot and a live quote according to remaining gas.

### Supplied snapshot failure is not replaced with live valuation

In the same facet:

- **49–58:** only matching configured exchange, asset and subject use the supplied snapshot. An unrelated subject or mismatched context takes the ordinary rate path **before consuming the snapshot**. This is context selection, not catching a failure of an applicable snapshot.
- **67–68:** a matching nonempty state's `quoteTotalSupply` failure propagates; there is no catch/live-supply fallback.
- **119–125:** matching nonempty state calls `quoteAssets`. Failure or a reply of a length other than exactly 32 bytes returns `(false, 0)`, and **81** returns zero. It does not retry `previewExchangeIn`.
- **70–75:** the zero-supply initialization rule is a distinct existing initial-rate case, not failure recovery. A successful zero projected supply is not the same as a failed snapshot.

Thus “a failed snapshot is not reported as the live rate” does not imply every dependency failure must revert: the preserved D48 valuation failure result can be zero. The important absence here is a retry with live valuation after a supplied-state failure.

### Wrapped getRate exposure: same separation

File: `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderTarget.sol`, read in full.

- **25–26:** public `getRate()` calls `_getRate("")`.
- **36–48:** reads wrapper supply and its `previewRedeem` once, then values the resulting reserve-share claim. Neither snapshot acquisition nor remaining-gas selection appears.
- **29–33:** matching context forwards supplied state; unrelated context chooses the ordinary live route without first attempting to consume the supplied state.
- **56–68:** nonempty state selects `quoteAssets`; empty state selects ordinary `previewExchangeIn`. Failed/invalid-length quote returns false and leads to zero at **48**, not live fallback.

`WrappedStandardExchangeRateProviderFacet.sol:11,23–29`, also read, inherits that target without overriding getRate and exposes both selectors. There is no additional wrapper implementation hiding the historical branch.

A contracts-wide getRate/_getRate declaration search also located the wings vault's own economic rate API. `UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol:27–36` calculates its ordinary rate from current supply and liquidation quote; matching supplied state is decoded and valued directly. It does not call quoteState or inspect gasleft in these functions. Its unrelated-context live selection at 34 is not a failed-snapshot retry. Other declaration hits were test infrastructure/fixtures, not additional production standard-provider wrappers.

## Acceptance-test mapping

### Empty-state snapshot failure and low budget

`test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_RateProvider.t.sol:258–269`, `test_emptyGetRate_ignoresQuoteStateFailure`:

- Configures the external dependency's quoteState to revert.
- Calls the real deployed rate provider normally and with an explicitly reduced call budget.
- Requires the bounded call to succeed and decode to the same rate as the ordinary call.

The provider itself is deployed through the production facet/package path at **181–190**. `contracts/test/stubs/ApexD48QuoteReplyFixture.sol:79–98` defines the actual configured quoteState failure and supplied-state supply failure. It is a non-SUT dependency fixture, not a replacement rate-provider implementation.

**Test limitation:** this named low-budget test sets supply to zero and does not assert a zero quoteState call count or advertise the historical optional unlock-context interface. It is not, by itself, a complete mutation test of the old interface-gated branch for every supply case. That limitation does not establish a current coverage blocker here: the current getRate paths have no quoteState acquisition or gas branch at all, and the additional tests below cover ordinary full-supply valuation and supplied states. I do not invent a missing production repair from the narrower fixture.

### Failed supplied snapshot

Same test file **271–279**, `test_failedCallerSnapshot_isNotReportedAsLiveRate`:

- Sets a valid ordinary quote, obtains the live rate, and makes the supplied-state total-supply query fail.
- Requires the exact dependency `QuoteBoom` error from matching `quoteRate` rather than accepting the available live rate.
- Checks the live route still returns its original result afterward.

The distinction is implemented in fixture **95–97**: the failure applies to nonempty state; ordinary totalSupply remains available. This is a direct failure-is-not-live-fallback control, not merely a test with a generic revert.

Same file **248–255** tests successful supplied-state valuation. **193–239** covers allowed D48 zero results for failed and malformed ordinary valuation replies. The fixture uses the same emitter for ordinary and state asset valuation, so successful synthetic parity alone is not the only supplied-state proof used here.

### Real projected states and wrapper behavior

`test/foundry/spec/protocol/dexes/balancer/v3/WrappedStandardExchangeRateProvider.t.sol:94–105,220–251` builds actual underlying SE quote state, projects an external exchange or deposit, passes that state to both standard and wrapped provider quoteRate, executes the corresponding funded operation, and compares projected with subsequent live rates. It also requires a changed rate for the external-exchange case. This is substantive evidence that snapshots are used for projected pricing, not silently ignored.

Its **152–181** controls ordinary wrapper full-supply valuation with expected preview calls; **184–190** covers invalid dependency payloads, and **193–210** checks wrapper metadata/redemption failures propagate rather than becoming a misleading rate. I found no separate dedicated wrapper snapshot-failure test in the inspected file; the wrapper's explicit no-live-retry control flow is directly readable, so that absence alone is not a remaining REQ-07 defect.

`contracts/test/bases/TestBase_UniswapV4FullSpreadRateContext.sol:47–85` additionally compares actual FullSpread supplied-state and live pricing in idle and blocked-manager contexts and after a projected deposit. **112–118** explicitly tests the independent-subject live policy. Concrete consumers exist in:

- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/RateProviderContextParity.t.sol:7–12,20–22`.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/RateProviderContextParity.t.sol:9–22`.

Both were directly read. These are executable test definitions, not claims that I ran them.

## What is and is not established

**Facts:** the current ordinary provider and wrapper contain neither the forbidden quoteState call nor gasleft branch; supplied-state failures do not retry live valuation; tests implementing the stated failure/budget and supplied-state rules exist; actual projected-state parity tests also exist.

**Inference:** the present REQ-07 source/test acceptance is sufficiently established to close this scoped item. No closed fix direction is necessary because no remaining defect was found. Existing snapshots supplied by callers are supported functionality, not evidence of the removed empty-state self-snapshot path.

**Unverified:** test execution in this review, deployed instance behavior, historical branch provenance, and exhaustive protection against every conceivable future regression. I did not inspect history to prove when or why the old branch was removed. Therefore closure should say “current implementation satisfies REQ-07,” not “the earlier concern could never exist.”

No receipt, custody, snapshot persistence or new product rule is added to OD-02. No reason was established to delete quoteState/quoteTransition or change D48's exact-length handling. Passing tests or consensus would not prove all unreviewed paths safe.

## Files examined without a scoped defect

The standard provider facet; wrapped target and facet; wings economic rate entrypoints; Morpho rate-provider test ranges and their dependency fixture; wrapped-provider tests; shared FullSpread rate-context tests and both concrete consumers; and controlling OD-02/REQ-07 text. Relevant file/line ranges are listed above. Some broad initial test discovery was capped; conclusions rely on the targeted reads and explicit source paths, not a claimed exhaustive test inventory.

All requested controlling/source paths were present and readable in this pass. The assigned report was absent before writing. No artifact in the prohibited snapshot-review directory was opened. Only this assigned Markdown report was created. No code, tests, PRD, configuration or instruction files were edited. No delegation, shell, build, test, chain read or deployment was performed. Return to the coordinator/human and stop.

Close REQ-07
I did not run Forge.
