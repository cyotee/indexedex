# Kimi K3 — cross-review: REQ-05 requirements checks

- **Label:** Replacement-session cross-review, resuming my requirements check (`kimi-req05-questions.md`). I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. MiniMax is the labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. The three peer checks were read in full as untrusted output; the wings test was re-read this round against the credit sentence (`UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:26-40`, with its bootstrap at `:45-58`). Nothing was edited.
- **Date:** 2026-10-17. I did not run Forge.

## Assigned question — the wings assertion vs REQ-05's credit sentence: **No blocking question.**

All four passes answer "No blocking question." The only substantive content is Astra's wings observation, which I adjudicate below.

### Astra's wings gap, analyzed and declined

Astra holds the wings control "checks the subsequent deposit against the vault's own preview rather than establishing the physical-credit limit" (`:9`) and scopes her PRD sentence to "complete the wings vault's outside-trade physical-credit test oracle." The concern is real in the abstract: `minted == preview` compares execution to the vault's own quote, so a formula reading a stale stored total could self-agree. It does not survive contact with the wings accounting, verified this round:

1. The wings target-token credit is **structurally 1:1 against the measured input**: the bootstrap pins `previewExchangeIn(target, 1e12) == 1e12` and `shares == 1e12` (`:48-51`), and the deposit pulls the caller's tokens in the same call — the minted credit equals the tokens just received. There is no stored-total input in the target-deposit formula for the bug's shape (minting against a stale total) to live in.
2. The custody the credit is measured against is live-balance-backed: the bootstrap asserts `token0.balanceOf(vault) == local0` and `token1.balanceOf(vault) == local1` (`:57-58`), and the test's own `:34-36` prove the outside trade does not move the book. The 001-M failure mode (credit from stored-total-minus-deployed) has no operand here.
3. The PRD's wings criterion is deliberately narrower than the FullSpread one: "the same outside-trade test **against its own accounting**" (`:265`). The wings test has all three required elements under its own accounting. The exit-side exposure (paying from a moved wing-position book) is a different surface with its own witnesses (`ApexRecurrenceInvariantWitness.t.sol` requires funded exits to succeed; `VaultHeldRedeem.t.sol` covers redemption rules) and is outside the written criterion.

One refinement of Astra's point survives and is worth one sentence in a closing PRD, without blocking it: asserting `minted == 1e12` (the funded amount, pinned by the bootstrap's 1:1 rate) instead of `minted == preview` would make the wings credit leg independent of the vault's own preview function. That is test-oracle hygiene the owner may adopt or decline; it is not a question the council needs answered, because the written criterion is already met.

### MiniMax's wings defense — right conclusion, wrong reason

MiniMax's `:59` argues the assertion suffices because "if the vault had credited from the outside trade, preview would still be the same but minted would be higher." That counterfactual is backwards: the preview is computed from the same live state the execution reads, so a hypothetical stale-book formula would move both together. The correct defense is the structural one above (1:1 measured input; no stored-total operand). Noted so the record carries the right reasoning; his conclusion stands.

## The one closed scope

"REQ-05 closes as a completion record with no production or test change: each of the four supported families has a current outside-trade test — V3 FullSpread (`release/v3/…_FeeCompound.t.sol:50-75`), V4 hookless (`fullSpread/hookless/AttributionAndBooking.t.sol:34-49`), V4 Pons (`fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol:37-52`), and wings (`upperLowerWings/…VaultMoney.t.sol:26-40`) — in which the pool trade never touches the vault, the vault's book and supply are unchanged by it, and the following credit equals the exact funded input under that family's own accounting; the reserve-reconcile supplement is not cited as that proof; the deleted legacy V4 package is not this item; one family does not close another."

## Unresolved dissent

None. Astra's wings note is recorded and narrowed to one optional hardening sentence; Grok's and MiniMax's checks agree with mine on closure. Consensus is not proof; the determination here is textual — the PRD's written criteria against four tests all four passes read.

I did not run Forge.
