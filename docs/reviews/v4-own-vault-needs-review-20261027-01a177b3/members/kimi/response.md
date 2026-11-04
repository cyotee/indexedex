# Member response

## Identity

- Run ID: v4-own-vault-needs-review-20261027-01a177b3
- Member label: kimi
- Profile: review
- Phase: initial independent response
- Owned path: members/kimi/response.md
- Requested role: council-member
- Requested model and reasoning: kimi-coding/k3:high
- Actual role, model, reasoning, task ID, and session ID: role council-member as assigned; model, reasoning, task ID, and session ID not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Does the published vault specification, and any implementation it has, meet these four needs: a reserve exposed to trading fees, a deposit of either token, a withdrawal into one token, and a quote of one vault share into one token? Report gaps and failures.
- Required targets: docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md
- Optional context: docs/research/v4-own-vault-spec-20261027-01a177b3/coordinator/resolution.md was admitted but not used.
- Admitted read scope: the specification, and repository files or searches needed to check for an implementation of this vault. StonkBrokers, PairToken, Clutch, and Sourcify-matched source were not opened.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Specification read in full | docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md, Terms and sections 1-9 | source observation | One diamond, one V4 pool, one range, one salt; liquidity-unit mint `floor(uReceived * (S + 10^d) / (U_before + 1))`; fee escrow with per-share indices `feePerShare_i`, debts, `unclaimed`, `collected`, `remainder`; two-currency entry with no vault swap; single-target exit selling only the removed slice's opposing principal; `getRate` as a reverting shares-only preview |
| Implementation search, spec identifiers | grep for `feePerShare`, `uReceived`, `OwnVault`, `redeemTarget`, `unclaimed_i` over `contracts/` and `lib/crane/contracts/` | static analysis | Zero matches in both trees. No contract implements the specification's fee-index, liquidity-unit, or single-target-exit surface |
| Implementation search, `getRate` | grep over `contracts/` and `lib/crane/contracts/` | static analysis | Matches are Balancer `IRateProvider.getRate` usages and stable-swap hook rate providers, not a share-to-target redemption quote for this vault |
| Implementation search, `unlockCallback` | grep over `contracts/` | static analysis | Matches are the UpperLowerWings execution delegate, a DETF deploy library, oracle test bases, stubs, and hook PRDs. These are unrelated existing code, not this vault; they were not reviewed as this vault |
| Coordinator coverage statement | brief.md, Review contract: "There is no Solidity implementation of this vault" | coordinator-supplied | Corroborated by the searches above; treated as a coverage fact, not as permission to imagine code |
| Public query | not used | not used | No public query was sent; no private excerpt left the repository |

## Assumptions

- "A deposit of either token" is read as the ability to deposit token0 only or token1 only, not necessarily at every pool tick.
- "A quote of one vault share into one token" is read as a non-mutating preview function, not as an execution-price guarantee.
- The four needs are graded only as worded; requirements the specification did not claim are not graded.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md | required | examined | Read in full; Terms and sections 1-9 assessed against the four needs |
| Repository implementation of this vault | optional | absent | Searched `contracts/` and `lib/crane/contracts/` for the specification's distinctive identifiers; none exist. The brief's statement that no implementation exists is corroborated |
| docs/research/v4-own-vault-spec-20261027-01a177b3/coordinator/resolution.md | optional | not examined | Admitted context, not needed to answer the question; no requirement was drawn from it |
| Excluded third-party source | excluded | not examined | Required exclusion; not opened, quoted, or reconstructed |

## Conclusions

There is no implementation of this vault in the repository. The verdicts below grade the published specification alone.

- Need 1, a reserve exposed to trading fees: met. The reserve is the diamond-owned liquidity of one Uniswap V4 position (section 2, Terms `U`). Trading fees accrue in both pool currencies, are collected into escrow by a zero-liquidity-delta `modifyLiquidity` call before any `S` or `U` change, and are attributed to holders through the `feePerShare_i` index, debt, and `unclaimed` accounting (section 3), claimable in kind via `claimFees`. Two design facts narrow but do not break the exposure: fees never compound into `U` (compounding was explicitly rejected), and fees are not part of the share's redeemable property, so exposure reaches the holder as a separate in-kind claim rather than as share appreciation. As worded, the need is met.
- Need 2, a deposit of either token: partial. Section 4 entry pulls both pool currencies with no vault swap and refunds what does not become liquidity, and "either amount may be zero when the current tick leaves that side unused." Below the range a token1-only deposit works; above the range a token0-only deposit works. At an in-range tick a strictly single-token deposit produces `uReceived = 0` and reverts, and the specification explicitly rejects a vault-side swap or zap. The capability is real but tick-conditional. This is finding 1 below.
- Need 3, a withdrawal into a single token: met. Section 5 removes exactly the share's liquidity slice `uOut`, sells only that slice's opposing principal, and pays one configured target currency from that removal's target principal plus the sale proceeds, with caller `minTargetOut` and an all-or-nothing revert. Fee escrow, remainder, donations, and remaining inventory are excluded from the sale input. The target token is bound per vault at initialization (section 2), so the choice of token is a vault property, not a per-withdrawal choice; the need as worded asks for withdrawal into one token and that is what is specified.
- Need 4, a quote of one vault share into one token: met. Section 7 defines `getRate` as the normalized shares-only preview of `redeemTarget` for one whole share: compute `uOut` with the floor conversion, simulate removal, quote an exact-in sale of only that slice's opposing principal against the post-removal pool state, and normalize. It reverts closed on every enumerated failure case (supply below one share, zero `uOut`, unquotable sale, incomplete fill, zero output, disallowed hook or dynamic-fee domain) and returns no constant substitute. The quote is a same-pool preview and moves with the tick; the report itself states it is not a manipulation-resistance claim. The need asks for a quote, and a well-defined fail-closed quote exists.
- Overall: three of four needs are met by the specification; the either-token deposit is partially met with a deliberate, explicitly-argued limitation. No implementation exists to fail any of the four.

## Review findings

### Single-token deposit reverts while the current tick is inside the position range

- Location: docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md, section 4 "Entry": "Either amount may be zero when the current tick leaves that side unused", "If `uReceived` is zero ... the call reverts", and the paragraph rejecting a vault swap or zap.
- Invariant or requirement: the user's need that the vault "can accept a deposit of either token."
- Impact: a depositor holding only one of the two pool tokens cannot enter the vault while the current tick is inside the configured range. The entry computes zero addable liquidity from the missing side, `uReceived` is zero, and the call reverts instead of minting from the token the caller has. Single-token entry is available only when the tick is outside the range on the corresponding side, so the deposit-of-either-token capability is tick-conditional and can be unavailable for extended periods. Callers in that state must source the other token externally before they can deposit.
- Fix direction: either record the tick-conditional limit as accepted product behavior in the requirements, or pursue the separate zap route section 4 explicitly reserves for a later specification, keeping it outside the section 1 mint equation and without claiming it closes any swap-capture result. Do not fold a swap into the two-currency entry itself.
- Evidence class: source observation.

## Limits

- Runtime or extraction proof: none. This review is a static reading of the specification plus repository grep searches. No code was compiled or executed, no project test was run, and no transaction trace was produced.
- Not examined: coordinator/resolution.md (optional, unused); the Wings, DETF, oracle, and hook code surfaced by the searches (identified only to confirm it is not this vault); all excluded third-party source.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
