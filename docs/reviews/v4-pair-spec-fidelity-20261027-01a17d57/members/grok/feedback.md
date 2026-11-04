# Member feedback

## Identity

- Run ID: v4-pair-spec-fidelity-20261027-01a17d57
- Member label: grok
- Phase: advisory review
- Owned path: docs/reviews/v4-pair-spec-fidelity-20261027-01a17d57/members/grok/feedback.md
- Requested role: independent council member, continued from the original assignment. A separate runtime role field was not exposed.
- Actual role, model, reasoning, task ID, and session ID: role not exposed; provider xai, model grok-4.7, reasoning xhigh. Session ID 01a17d68-beab-78f5-a157-ba1f09e178eb. Task id st_01a17d69 was observed in the original session path and is the same id the draft lists for Grok. This is not a new identity claim.
- Fresh or continued: continued. Same conversation as the initial response. Continuity was not lost.
- Initial response path: docs/reviews/v4-pair-spec-fidelity-20261027-01a17d57/members/grok/response.md
- Initial response preserved: yes. This pass did not overwrite it.

## Draft under review

- Draft ID: pair-spec-fidelity-r1
- Path: docs/reviews/v4-pair-spec-fidelity-20261027-01a17d57/coordinator/draft.md
- Fingerprint supplied by the coordinator: none in the assignment text
- Fingerprint independently computed: SHA-256 31c5cab73e3a62883c07a53f590255350a146617c67f5da8a348866562c99874 of the file bytes opened
- Draft bytes opened: 24714

The draft's own identity line is pair-spec-fidelity-r1. The path matches the assignment. The current evidence/manifest.md was opened. Peers' originals and peer feedback were not read. The draft was not edited.

## Disposition

- Disposition: support-with-reservations
- This file replaces a missing initial response: no

I support the draft verdict. The supplied report does not correctly document this PairToken, and it is not a source-equivalent specification or a source-equivalent clean-room handoff. That was my original conclusion. The draft adopts the material parts of it: basket mint versus the offset-9 liquidity-unit formula, dead-share genesis and minShares order, collective compounding instead of personal escrow, protocol carve and ratio-swap, 10 bps dual-asset redemption versus a target sale, zapDeposit as a real entrypoint, idle inside the basket, full-usable-range and salt 0 versus a configured diamond, getRate absent, and Crane citations that are not this bundle.

I do not treat other members' agreement as something I checked. Unread originals are not support from me. The draft already says member agreement is not a substitute for source evidence. Keep that sentence.

Two corrections should land in the final. Neither changes the verdict. Details are in Concerns.

Accepted clarifications, not open defects:

- Archive integrity. My original response reported that evidence/sourcify-sources.json did not hash to the then-stated manifest digest. The assignment clarification is accepted: the archived JSON minus one terminal newline restores the fetched HTTP body and digest ebbbf460a7873b7a5a1fb2802035778976ac4c5f64f3c6074776fd71aa53cd98. The current manifest distinguishes that fetched-body digest from archived JSON b092a33582f4a7f6c76564b0a5ea276561b84347ab66494eea81e462442fcea0, and distinguishes original specification 15c6d7790aa1f8eca1c36ec0d147483359e2ff7d018c56ed8240e394d2c878e3 from archived specification f24991cd9f822f25c671c038f8d5fc808c6f6d433063e20431aaf3d98fa963bb. The draft's Archive hashes bullet states the same JSON restoration. I withdraw the mismatch as an evidence-loss or re-serialization finding. Do not revive it.
- MiniMax F11. I did not read that original. The stated rule is right: the modifyLiquidity feesAccrued inflation warning does not by itself prove unbacked liabilities or an exploit. The draft's rejection of that claim as a confirmed vulnerability should stand. The source delta distinction belongs in F3, as the draft says. Do not strengthen F11 into a vulnerability finding.
- getRate. F9 correctly refuses to turn this fidelity finding into a recommendation to change the project's rate contract. Keep that boundary.
- Coverage. The draft does not promote my partial library reads into a full 28-file audit. Keep that qualification. I confirm my own PairToken and called-helper coverage only.
- Clone mechanics. Qualifying EIP-1167 as NatSpec, not as a verified deployment trace, is the right tightening of my original wording. I accept it.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| G1 | F5 formula block; same cast in the F3 collect description | The removal amount is not the signed caller delta. Op.Remove encodes uint256(uint128(delta.amount0())) and the same cast for amount1, after _modify has resolved that delta. Op.Collect uses the same cast of callerDelta, not feesAccrued. A negative int128 cast wraps. I did not show that wrap is reachable, and this pass did not re-investigate it. | In F5, say the decoded removal amount is that uint128 cast of callerDelta, equal to a nonnegative caller delta when the high bit is clear. Do not equate it to the signed value. One clause on the F3 collect encoding is enough. Do not add an overflow or exploit claim. |
| G2 | Disagreement section, Workflow bullet | The bullet says MiniMax fell back to write/edit because apply_patch was unusable. That is incomplete if the final keeps a process-deviation list. On the initial pass, apply_patch was registered but inactive from this member's tool bridge, so members/grok/response.md was written through the host write path. This feedback file had the same inability. No other file was changed. | If the workflow sentence remains, do not state the fallback as MiniMax-only. Add the same process note for Grok, or drop the member-specific sentence. It is not a PairToken defect. |

Locator check, not a separate concern: the draft's rule that a readable-bundle line is the original source line plus three matched the spots I already knew (receive at bundle 136, BPS at bundle 62, basket at bundle 224). I am not requesting a locator rewrite. F1's bundle span 500-521 starts three lines before _quoteShares; the symbol name carries the citation.

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

Nothing in this file is adopted from another member's text. The F11 and archive points follow the assignment clarification and the draft's own bullets, not a peer original.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral. This disposition is not a veto, not consensus, and not approval for an unread member.
- This file grants no implementation authority.
- No new source investigation, tests, builds, or bytecode checks were done on this pass. The uint128 observation is from the initial read of unlockCallback, not a new execution.
- apply_patch was not exposed as a usable tool. A direct call returned registered-but-inactive. This assigned file was written through the host write path. The draft, the original response, the run record, and peer files were not edited.
- Inherited parent permissions are not evidence of confinement.
- License identifiers and the source-exposed character of this audit do not settle legal clearance. The draft's three-question split should remain.
