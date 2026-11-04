# Advisory resolution ledger

Frozen draft: `v4-vault-comparison-r1`, `coordinator/draft.md`. Final revisions belong to coordinator REPORT.md, not the frozen draft. All four requested advisories have settled; all material concerns are resolved below. Final changes are coordinator revisions, not member re-approval.

## MiniMax — SUPPORT WITH CORRECTIONS

- A1: **Rejected.** Per-leg minima are lower bounds, not upper bounds or zero-residual assertions. A nonzero minimum on the unwanted leg requires that unwanted token to be present; it cannot enforce its absence. A zero minimum also allows a positive residual. Selected-token minimum protects amount, not token exclusivity. Keep the draft's conditional one-output statement and explain this logical distinction. No partial-fill transaction was executed.
- A2: **Partially adopted with correction.** Disclose first-deposit `MIN_SHARES = 1000` lock and first-deposit size prerequisite. Do not claim a permanently fixed 1000 liquidity units after compounding, or that locked economic value belongs to remaining holders. Locked shares retain a proportional, nonredeemable claim as total liquidity changes.
- A3: **Partially adopted.** Promote canonical principal-plus-fees return semantics and partial-decrease fee allocation into shared comparison notes. Do not adopt the blanket claim that paying or inspecting `feesAccrued` is automatically exploitable: donation sensitivity needs a concrete accounting path, not a universal verdict.
- A4: **Adopted with correction.** Clearly distinguish V4 liquidity removal, which can recover the USDC-side principal, from skipped V4 non-base conversion. It is incorrect to say no V4 proceeds can fund a USDC withdrawal. Conditional classification remains.
- A5: **Adopted in substance.** Separate evidence maturity from mechanism and compare designs, not equivalent production products. Unoxi remains an asynchronous share-vault system with round-based interfaces, not simply relabeled as a standalone order book.
- A6: **Partially adopted.** Highlight USDa's automatic fallback and aggregate-minimum bypass, but do not adopt an unsupported universal severity ranking or repeat A1's false Weir guarantee.
- A7: **Adopted.** Make Weir's creation/runtime verification explicit while retaining no funded/current-operation proof.
- A8: **Resolved.** Virtual shares are coordinator-observed in ALPVault source (P10), not invented because a peer did not inspect them. Keep value-aware half-excess description.
- A9: **Partially adopted.** Record tools neutrally as disclosed process deviations and explicitly annotate MiniMax's changed classifications. Do not rewrite explicit `using apply_patch` and no-forbidden-workaround instructions as authorization for a different write tool. No evidence fabrication is inferred from the alternate writes. Astra's own actual write route is not established merely by MiniMax's assertion.
- B/Grapl: Include as peer-reported non-vault zap primitive, without adopting unverified “Uniswap-affiliated” branding.
- B/Aperture: Include as unresolved source/version/route evidence. Do not globally exclude on exploit/closed-source grounds without primary evidence of the exact version.
- B/upstream PoolVault: Include as useful upstream two-asset accounting/JIT reference; do not assert lpTOKEN derives from it without code-provenance evidence.
- B/one-sided positions: Name Weir ladders and locked lpTOKEN launch inventory as excluded paths.
- D1-D4: Preserve original unchanged; report MiniMax's withdrawal of unconditional ALPS/USDa classifications, lost-fee premise and naive half-swap interpretation. Its new A1 claim remains rejected as above.

## Kimi — SUPPORT

- No substantive corrections requested.
- Optional CuratedLP/UniSD and RangePilot rows accepted for breadth, clearly separate from the main shortlist and generic Range.
- MaxFi may be noted among wrong-venue/unverified V4 leads; do not broaden into a fresh investigation.
- Canonical PoolManager semantics independently checked in advisory; all other support retains peer/draft evidence provenance.

## Astra — SUPPORT WITH CORRECTIONS

- A1: **Adopted.** Coordinator re-read ZapVault withdrawal settlement: positive residual ETH is retained by the vault and the user record/config deleted. State this explicitly rather than treating a USDC payment as full-value consolidation. It is source reasoning, not a reproduced failure.
- A2: **Adopted.** Coordinator read complete UnoxiExitRounds: `_deliver` wraps proceeds and `_payoutToken` selects cToken0/cToken1. Disclose confidential wrapper payout, with plain-token unwrapping unverified.
- A3: **Adopted.** Coordinator read ALPS redeemInKind: skips orphaned pools/catches removal failures, burns full requested shares, and distributes subject to caller minima and entry/exit fee. Keep unpaused callability distinct from full-portfolio recovery. Fee cap and role effects included; current deployed fee not checked.
- A4: **Adopted.** Final contains compact chain/address/evidence table, distinguishing factory, implementation, router, shared manager, actual vault and testnet round contracts. Published locators do not attest current funding.
- A5: **Adopted.** Explicit seven study designs, not equal production matches or unconditional full-value exits.
- Preservation: retain Twofold as in-kind negative control and OpenZaps as documented but unconfigured/unverified LP lineage, not swap-only or globally absent.
- No additional advisory round. Original and feedback preserved.

## Grok — SUPPORT WITH CORRECTIONS

- C1: **Adopted.** Opening itself now says study designs with differing maturity/output guarantees, not seven production matches. Simplified six shared-capital plus one per-user arithmetic.
- C2: **Adopted.** Distinguish verified Weir manager and source record from funded PoolId; UI observation remains non-RPC.
- C3: **Adopted.** Fee semantics explicitly include possible hook adjustment. ZapVault's published hookless pool avoids implying hooks never alter caller delta; residual attribution remains separately qualified.
- C4: **Adopted.** Coordinator read `contracts/reference/PinnedReference.sol` and deployment script. It is an owner-posted price with freshness/age configuration, not market price/TWAP; manifest live source identity/current wiring not independently established. Correct path resolves prior 404.
- C5: **Resolved against source, not peer agreement.** Coordinator read both rebalance entrypoint and full handler; threshold is not checked, although range width comes from config. Keep the source-supported statement and explain why the generic user-config description does not contradict it.
- C6: **Partially adopted.** Distinguish range-center feed from executable exit pricing; make operator-posted reference concrete. Same-pool TWAP is not independent, but do not claim it is unusable merely because no other pool exists; economic robustness would need evidence.
- C7: **Adopted.** Separate ICHI/Charm linkage gaps, pre-V4 Beefy documentation and Topaz Slipstream evidence.
- C8: **Adopted.** Base manifest got receipt/source-commit reading; other network manifests/README claims did not get equivalent validation.
- EulerSwap/VII: Add compact exclusion for credit-backed JIT inventory and yield-bearing pool assets, not another LP-custody match.
- Delivery: Final status referenced an earlier complete inline advisory rather than repeating it. Coordinator recovered that exact message from Native full task transcript and archived it verbatim as `members/grok/feedback.md`; no new advisory or regenerated opinion was requested.

## Publication and closure

- Complete final: `REPORT.md`, with seven profiles, comparison table, maturity/deployment table, 37 primary-source entries, near-match coverage and actual participant metadata.
- Frozen draft unchanged; four originals and four advisories preserved.
- Kimi original and Grok/MiniMax/Kimi advisories archived by coordinator through apply_patch from complete Native responses/transcript.
- No missing participant, pending advisory, second review round, implementation, project tests, deployment, wallet operation or external message.
- Research limits remain explicit: static sources, mutable main branches, no runtime reproduction/current liquidity query, no independent audit established for shortlisted exact paths.
