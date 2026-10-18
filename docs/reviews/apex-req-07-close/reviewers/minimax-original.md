# MiniMax M3 — REQ-07 close investigation (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** Owner question: is REQ-07 an actual remaining problem, or were agents overly cautious about a scenario that cannot exist? Can REQ-07 be closed as a mistaken alert?
- **Inputs read:** `REMEDIATION_PRD.md` REQ-07 section (lines 291-306) and OD-02 (lines 99-111); `StandardExchangeRateProviderFacet.sol` (172 lines, full).
- **No code edit. No PRD write. No Forge.**

---

## Conclusion — Close REQ-07.

The PRD at lines 99-111 records the owner's ruling: "Empty-state `getRate` and `_getRate` do not call `quoteState` and do not read remaining gas. The rate is the live preview path."

The PRD at lines 297-298 records the broken requirement: "`_getRate` currently calls `quoteState` when no state was supplied, the subject supports unlock-context quotes, and `gasleft()` exceeds 250,000."

The PRD at line 302 records: "A test shows the empty-state path does not change when the vault's `quoteState` would fail or when the call budget is low."

The current source at `StandardExchangeRateProviderFacet.sol:67-68`:

```solidity
uint256 totalShares = state.length == 0 ? subject_.totalSupply()
    : IStandardExchangeTransitionQuote(address(layoutStruct.reserveVault)).quoteTotalSupply(state);
```

The empty-state path (`state.length == 0`) reads `subject_.totalSupply()` directly. It does not call `quoteState`. It does not read `gasleft()`. It does not pass through a `quoteState` soft-snapshot path. The `quoteTotalSupply(state)` call is on the alternative branch, which only runs when `state` is non-empty. The branch that REQ-07 named as broken is absent from the current source.

The function does not call `quoteState` on the empty-state path and does not read `gasleft()`. The acceptance criterion at PRD line 300 ("Empty-state `getRate` and `_getRate` do not call `quoteState` and do not read remaining gas") is satisfied by the current source.

A branch that is absent from current source is not a remaining production defect. The user instruction is explicit: "A branch that is absent from current source is not a remaining production defect." The `quoteState`-soft-snapshot branch that REQ-07 named is absent.

The owner is correct: agents were overly cautious about a scenario that cannot exist. The empty-state `getRate` does not have a `quoteState` or `gasleft()` probe. REQ-07 can be closed as a mistaken alert.

**Close REQ-07.**

I did not run Forge.