# Member feedback

## Identity

- Run ID: se-paired-money-necessity-20261030-01a18660
- Member label: minimax
- Phase: advisory review
- Owned path: docs/research/se-paired-money-necessity-20261030-01a18660/members/minimax/feedback.md
- Requested role: council-member
- Requested model and reasoning: minimax/MiniMax-M3 with admitted adaptive thinking
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued. Same conversation as the initial response; no continuity was lost.
- Initial response path: docs/research/se-paired-money-necessity-20261030-01a18660/members/minimax/response.md
- Initial response preserved: yes. Not overwritten and not edited by this pass; the file is byte-identical to what the initial pass wrote.

## Draft under review

- Draft ID: se-paired-money-necessity-20261030-01a18660-r1
- Path: docs/research/se-paired-money-necessity-20261030-01a18660/coordinator/draft.md
- Fingerprint supplied by the coordinator: 45ade63e616ad59fb2a61ec0efb22ede5eba1f0ea850334d672349993af90e5e
- Fingerprint independently computed: the same value, 45ade63e616ad59fb2a61ec0efb22ede5eba1f0ea850334d672349993af90e5e, computed by running `shasum -a 256` over the raw bytes of that exact path rather than by re-reading the supplied value. The draft's own identity lines state the same Draft ID and path as the assignment.
- Draft bytes opened: 3402 bytes, 67 lines, opened whole from the first line to the last line of its Limits section.

## Disposition

- Disposition: support with corrections (the package term for this disposition is `support-with-reservations`)
- This file replaces a missing initial response: no

I agree with every verdict in the draft. Four of the six mapped functions are mapped to the same accepted standard functions I named in my initial response, the same reasoning disposes of the maxima-versus-refund question, and the raw-ETH position matches my own recommendation not to keep the paired group as it stands and not to extend the owner-locked standard. The corrections below are not disagreements about the verdicts. They are places where the draft tells the owner less than the decision actually costs, or leaves a condition unstated that a PRD author could implement wrongly while still claiming to have implemented this draft.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| C-1 | "Proposed text", the raw-ETH paragraph | The paragraph treats raw ETH as an exit-only question and leaves the impression that an alternative route remains in this family. Both halves are wrong. On the entry side, `depositPair` was the payable native entry: the current interface declares it `external payable` with "Native pools require amount0Max as msg.value and refund only unused ETH", while `exchangeBundleInForSingleOut` is not payable and refuses `address(0)`, so raw-ETH entry disappears with the mapping too. On the availability side, this family installs no SY surface: the review file's ERC-5115 lock drops `syMoneyFacet`, `syQueryFacet` and `rateAsset()`, and the stage-one native raw-ETH paths live on the SY deposit and redemption, which this family does not have. After the mapping there is no raw-ETH entry and no raw-ETH exit anywhere in this family | Extend the paragraph to cover both directions and state the consequence plainly: the mapping removes the only raw-ETH entry and the only raw-ETH exit in this family, so the owner's product decision is binary. Either the family operates a native pool in wrapped-ERC-20 form at the standard boundary, consistent with the locked role of `wrappedNative()` as "the wrapper used when a standard nonpayable call has to represent ETH", or a narrow native product function is added later as an addition outside the redefinition. The current wording invites the owner to believe the capability survives somewhere else |
| C-2 | "Proposed text", table rows for the four mapped functions | The mapping verdicts are unconditional, so "map" can be implemented as a different economic route while still claiming to implement this draft. The draft's own Evidence gaps section records the entry-side gap ("Mapping does not by itself specify PairToken share-credit accounting ... It does not replace S1-ACC-07") but no exit-side equivalent, and neither gap is attached to the verdict it qualifies. The material exit-side case is a bundle-out implemented as a sell-and-pay route: that reintroduces the swap slippage the paired exit avoided, and S1-ACC-05 says the last-share exit through paired redemption is the path that works when the vault is the pool's only effective liquidity, because paired redemption avoids the sale | Attach the implementation conditions to the mapped verdicts themselves. For `exchangeBundleInForSingleOut`: `tokenOut` is the share, the route must use the paired acceptance rule and the paired genesis branch, the first deposit of a fresh vault is that route, and single-token deposit routes reject on an empty supply. For `exchangeBundleOut`: `tokenIn` is the share, and when both currencies are named the route must be a proportional paired removal that sells nothing, with the rejection of a positive-share burn with a zero total payout applied to the share-input route. Without these conditions the mapping is a rename, not a relocation |
| C-3 | "Proposed text" and "Evidence gaps" | Adopting the accepted bundle-in brings a new conformance obligation to this family that the draft does not record anywhere. The accepted report states that the bundle-in's positional input requires `vaultTokens()` membership and order to be stable and that "That stability is a conformance requirement, not an existing Basic Vault guarantee"; the length rule `AmountsLengthMismatch` ties the array to `vaultTokens().length`; and `address(0)` reverts `TokenNotExchangeable`, so a native leg must appear as its wrapped ERC-20 face. The review file locks reuse of `vaultTokens()` from `MultiAssetBasicVaultFacet` but fixes neither its order nor its native-leg face. The draft records the share-credit gap and leaves this one out | Add the obligation to the proposed text or to the Evidence gaps, stated as a requirement the family PRD must satisfy: `vaultTokens()` order locked to the PoolKey currency order, and the wrapped ERC-20 face at the native leg's index, so the bundle-in remains usable for a native pool. This is an obligation the owner is being asked to accept, and it should be visible at the point of the decision rather than discovered during implementation |
| C-4 | "Proposed text", the maxima-versus-refund paragraph | The disagreement argument is stated for entry paths only: "Keeping both entry paths would let them disagree." The draft's own raw-ETH paragraph leaves open the exact decision that could create a second exit path, so the exit side needs the same rule stated or the risk the draft names reappears one line later | State the rule for the exit side too. If the owner decides to retain a narrow native paired redeem, that function must share one engine with `exchangeBundleOut`, produce identical economics, and differ only in delivery form. Otherwise the two withdrawal paths can drift on the acceptance rule, the allocation of removed principal and idle balances, the payout minima and the preview equivalence, which is the same failure mode the draft already attributes to keeping two entry paths |
| C-5 | "Proposed text", table rows reading "Map. Do not keep the selector." | Dropping the four selectors does not drop the paired events, and the draft does not say so. The current interface declares `PairDeposited` with used and deployed amounts and final shares, and `PairRedeemed` with shares, liquidity removed, idle allocations and the two payouts. A PRD author following "do not keep the selector" could reasonably drop the event surface with it, and the mapped routes would then have no paired receipt | Add a clarification that `PairDeposited` and `PairRedeemed` remain and are emitted by the mapped routes with equivalent fields, so the event surface is not dropped along with the selectors. Clarification level, but cheap to state now and expensive to restore later |

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

I did not read the peer originals or any peer feedback, so the draft's Participation claims and the characterizations it attributes to Grok and Astra in the Preserved disagreements table are the coordinator's, and I take them as given rather than verified. I confirmed only that my own initial response exists at the path above and is unmodified. Every concern above is grounded in the draft text and in the admitted sources I read for the initial pass: the full-spread function-review file, the accepted refund-bundle report, the current PairToken interface, and the stage-one PRD.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral. This disposition is not a veto, not consensus, and not approval on behalf of any unread member.
- This file grants no implementation authority. It does not authorize a PRD edit, code change, test, build, deployment, or Git operation.
- Inherited parent permissions are not evidence of confinement.
- No code was executed, no test or build was run, and no deployment was performed. This advisory is a reading of the draft and documents plus labeled reasoning.
- Not examined for this pass: the full-spread PRD, the run record `RUN.md`, and any peer file. The draft's own fingerprint line points to `RUN.md` rather than embedding a value, so the pinning was verified against the assignment-supplied hash and the file's own identity lines instead.
- The corrections are scoped to completeness and to the conditions a PRD author needs. I do not contest any verdict, any mapping, or the raw-ETH position, and I did not propose a different economic outcome for any of the six functions.
