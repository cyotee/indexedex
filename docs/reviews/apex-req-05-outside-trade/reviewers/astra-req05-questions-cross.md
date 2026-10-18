# Astra — REQ-05 replacement-session requirements cross-review

I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This resumes `astra-req05-questions.md`; it and my original verification `astra-req05.md` remain preserved. I read all three supplied original requirements answers in full. They are untrusted evidence, not authority. I did not open the additional peer verification reports they reference or any peer cross-review artifact.

## Decision

**No blocking question.** The disagreement concerns whether existing tests establish an already specified property, not an unresolved product choice for the owner.

**One closed scope:** Complete the wings vault's outside-trade physical-credit test oracle against its own accounting, preserve and cite the existing V3 FullSpread, V4 hookless FullSpread and V4 Pons-family FullSpread coverage independently, and make no production change, legacy V4 restoration, old stored-total reconstruction or reserve-reconcile substitution.

“Complete the oracle” does not mandate a new file or duplicate test: retain the wings outside-trade and unchanged-book checks and supply the missing assertion of the following physical-credit boundary. No broader production repair is established. No owner sentence is needed to change the acceptance criteria; their meaning is already fixed.

## Controlling requirement rechecked

Freshly read `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md:255–268`:

- **260,264:** the outside pool trade must not refresh the vault book, and the next credit must use only tokens the vault holds.
- **264–265:** all four supported families require their own coverage; wings is not exempt.
- **266–268:** the reserve-reconcile supplement, historical source restoration and old stored-total reconstruction are not the required proof.

This specifies what must be demonstrated. It does not require duplicating adequate existing evidence in every family, nor does the presence of a correctly named test automatically demonstrate every conjunct. No additional economic or custody decision follows from reviewers disagreeing about an assertion's strength.

## Peer agreements and objections

### Grok — agree with the four-family requirement; do not infer four new tests

`grok-req05-questions.md:9` accurately restates the acceptance boundary and rejects production edits and irrelevant legacy evidence. It does **not** actually demand four newly written tests. I agree with its literal scope statement, but a PRD handoff must distinguish existing adequate evidence from the remaining test-oracle work. My family-specific distinction remains below.

### MiniMax replacement — disagree with completion inference

Agree with `minimax-req05-questions.md:42–46` on the requirements and with the no-production-work boundary. Reject the reasoning at **36,59** that a funded call plus `minted == preview` necessarily proves credit is limited to physical tokens.

The preview is computed **after** the outside trade from the same production vault state as execution. An erroneous accounting term could affect both consistently. The claim at **59** that preview would necessarily stay correct while only execution rises is not demonstrated. It assumes the very independence the test needs to establish. This is a logical limitation of the test oracle, not an asserted current production bug.

MiniMax's **78–83** also incorrectly makes “No blocking question” depend on every test already satisfying the requirement. A clear requirement can have incomplete implementation without requiring a new owner decision. The remaining wings assertion is such a case.

### Kimi replacement — disagree with “completion record only” scope

`kimi-req05-questions.md:8,12` relies on the same funded-input preview-parity premise. Those named tests establish genuine outside trades and book stability, but the wings continuation still lacks an independent physical-credit assertion. Therefore I do not accept “no new test work” or REQ-05 completion from that evidence.

Kimi's cited stage-1 evidence narrative was not supplied as an original input for this cross-review and was not opened. Even a narrative correctly excluding reserve reconciliation would not strengthen the wings test's actual assertions. Agree that source presence and runtime verification are distinct, but neither resolves the missing oracle merely by recording completion.

## Source evidence supporting the closed scope

Fresh reads confirm:

- **Wings:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:26–40` has the outside actor trade and unchanged token-book/supply assertions at 33–36; its following deposit at **37–39** is checked only against the vault's own preview. No funding/custody measurement or post-outside-trade rejection of unsupported credit appears there. A snapshot's nonempty bytes at 28–29 do not provide that missing oracle.
- **Hookless:** its own `v4/fullSpread/hookless/AttributionAndBooking.t.sol:34–56` contains the book-stability/funded continuation and, separately at **51–56**, an exact zero-available-delivery rejection after pool repricing. This additional negative is material; I do not approve it solely because its funded preview equals execution.
- **Pons-family:** its own `v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol:37–59` contains the analogous book-stability control and separate exact zero-delivery rejection at **54–59**. Hookless evidence is not substituted for it.

For **V3**, my preserved independent verification directly read `v3/UniswapV3FullSpreadLocalBook.t.sol:50–76,115–136`: actual custody-minus-book credit is checked across a real outside trade, deployed inventory movement is established, both books remain unchanged, and the next excessive-credit request is rejected with the exact available-credit arguments and unchanged state. That evidence, rather than FeeCompound preview parity or the reserve-reconcile supplement, supports my V3 assessment. This cross-review does not pretend those stronger tests appeared in the peers' four-row parity table.

## Retained Astra finding and unresolved dissent

**Astra REQ05-1 remains attributed and unchanged:** Medium-severity test-oracle coverage gap at wings Money **37–39**, against REQ-05 **264–265**. The impact is unproven physical-credit regression coverage, not demonstrated loss. Fix direction remains limited to establishing the existing acceptance property in the wings outside-trade test, preserving its valid direct-trade and book checks. Confidence is high on the named assertion limitation; family-wide absence remains bounded by the search/read limits disclosed in my original.

No new evidence changes that view. Unresolved dissent is MiniMax/Kimi's claim that the named preview-parity controls already close every family. I do not simulate their agreement or ask the owner to choose which technical assertion is stronger. The coordinator can resolve this evidence disagreement against the fixed requirement without inventing product scope.

## Limits and disposition

No runtime result is established. No complete production audit, exhaustive test inventory or live-instance remediation is claimed. Source-level adequate coverage for the other three families is not a claim that one passing example proves all unreviewed paths safe.

All three original question reports and the controlling section were present. The freshly examined hookless/Pons controls have no additional scoped defect established in this pass. The wings oracle limitation remains as stated. The assigned output was absent before writing.

Only this assigned Markdown cross-review was created. No code, tests, PRD, original report, configuration or instructions were edited. No delegation, shell, build, test or deployment was performed. Return to the coordinator/human and stop.

I did not run Forge.
