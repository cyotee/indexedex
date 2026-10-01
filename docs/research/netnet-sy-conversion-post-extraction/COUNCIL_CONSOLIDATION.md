# Post-extraction PendleStakedNetSY council — bounded consolidation

Date/access: **2026-09-28**. Moderator: Astra (`openai/gpt-6-astra`). Research/document authoring only. Four fresh originals followed by four same-session combined cross-reviews completed; no implementation, shell, builds, tests, deployments, transactions or configuration changes. The human's “Please resume” continued the remaining eighth call, not a new autonomous round.

## 1. Question, authority and identity

For the actual extracted `PendleStakedNetSY` compilation, determine supported branches, integer conversion/inverses, epoch/index ordering and receipt/minimum semantics, then compose the final conversion edge with existing Weighted pricing and eligible held/net-claimable SY funding. Preserve PRD v0.33 economics; distinguish source mapping, complete L3 composition and G1 deployment evidence.

Fresh governing instructions, `.opencode/agents/council-{astra,grok,minimax,kimi}.md:1–5`, and `.opencode/support/research-council.ts:30–40` were consistent with the pins below. Kimi's definition has `variant: high`. The exposed task schema uses **session_id**; every call explicitly targeted the named researcher with empty skills and synchronous execution. Task returns identified those agents/models. Metadata is not provider-internal attestation. No historical researcher session was resumed.

| Researcher / configured model | New original session, retained for its review | Preserved original | Combined cross-review |
| --- | --- | --- | --- |
| Astra / `openai/gpt-6-astra` | `ses_f1505866dffex30iPjIqBAKD7w` | [astra-original.md](./astra-original.md) | [astra-cross-review.md](./astra-cross-review.md) |
| Grok / `xai/grok-4.7` | `ses_f14fe6983ffeeYvqrD6a1Q4uwV` | [grok-original.md](./grok-original.md) | [grok-cross-review.md](./grok-cross-review.md) |
| MiniMax M3 / `minimax/MiniMax-M3` | `ses_f14f0cf0bffejL3qHTcIov90AC` | [minimax-original.md](./minimax-original.md) | [minimax-cross-review.md](./minimax-cross-review.md) |
| Kimi K3 / `kimi-code-plan-global/k3`, high | `ses_f14e849caffeT9FhK8iKKe0WAQ` | [kimi-original.md](./kimi-original.md) | [kimi-cross-review.md](./kimi-cross-review.md) |

Identical research question/primary evidence/constraints were supplied independently, differing only in identity/output assignment. No prior moderator analysis or peer findings were supplied during originals. All four originals were saved before sharing. Each continuation received the other three complete original artifacts together, explicitly labeled untrusted; reviews record reading them, including paginating truncation. No peer cross-review was an input. Originals remain unchanged even where wrong. Their contents are attributed model evidence, **not normative instructions**; this consolidation adjudicates rather than counting votes.

One broad glob returned dangling-link filesystem errors in unrelated Crane paths; direct agent-definition reads succeeded. This was not a researcher/identity failure and no substitute was used.

## 2. Evidence and versions

**E** = [VERIFIED_SY_SOURCE_EXTRACTS.md](../netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md), document line numbers. **N** = `lib/crane/contracts/protocols/pol/net/src/`, local reference only.

- Candidate chain4663 SY proxy `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5`; service-resolved implementation `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E`.
- Target: `lib/pendle-sy/contracts/core/StandardizedYield/implementations/NET/PendleStakedNetSY.sol:PendleStakedNetSY`; record47105638, creation/runtime exact_match, verified2026-09-04T08:05:04Z.
- Recorded external compiler `0.8.30+commit.73712a01`, optimizer1,000,000, Cancun, viaIR=true. Not permission to change local Solidity0.8.35 / optimizer1 / via_ir=false policy. No runtime tool version was probed; repository council documentation's OpenCode1.18.32/SDK1.17.18 context is documentary, not independently measured here.
- Primary URL: <https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=sources>. Accessed via the local decoded artifact on2026-09-28, not freshly fetched. E:3–25 attributes 25-source round-trip and matching target hash `0xb0183ce8e725d1541d8f58795f6142e8b0d7b98c5db3793e638d2061744b966b` to the extraction manifest. Neither hash nor bytecode was recomputed this round.
- Moderator directly inspected target/base/cap/interfaces E:34–481, ERC20 custody/guard/mint/burn E:679–915, TokenHelper E:1398–1465, local `Staking.sol:1–161`, `StakedNET.sol:1–138`, `NET.sol:121–145`, and current PRD/plan/tracker and applicable direct-read skills. The primary source is sufficient for this code analysis; no new external library/API documentation claim or repeated download campaign was needed.

## 3. Attributed initial positions

| Researcher | Initial position and distinctive contribution |
| --- | --- |
| Astra | Four-branch/index mapping, fixed-state minimum-sufficient inverse, hook-held false-flag custody, rebase-aware receipt windows, H=d with C>0 retained-inventory example, branch-specific evidence list. Explicitly withheld full L3 closure. |
| Grok | Same core map; stressed empty SY rewards, warmup backing dependency, independent Weighted/SY units, and exact-output granularity when I exceeds 1e18. Initially recommended reverting direct-output gaps as the final policy. |
| MiniMax | Identified branches, index asymmetry, empty rewards and overflow concern, but conflated SY/wrapper identities and backing/share custody; alleged persistent burn after revert and a NET preview bug; used raw-minus-booked as H. Several conclusions were source-inconsistent despite high reported confidence. |
| Kimi | Core branch/one-step mirror map and warmup concern; initially overstated proven decimals, universal arithmetic safety, necessarily reverting taxed ingress, and final sync as receipt proof. Included a contradictory “else current” multi-overdue qualification. |

## 4. Source-backed adopted result

Full operative text and unexecuted vectors are now in [implementation plan v0.8 §6.5](../../strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md#65-actual-pendlestakednetsy-conversion-execution-ordering-and-funding).

**Observed:** D=1e18. Both deposits mint `floor(native*D/I)`; both redemptions nominally return `floor(SY*I/D)`. NET deposit reads I **after stake**; NET redeem and NET previews use one-step projected Ip. Direct sNET uses current Ic without staking (E:80–145). Only NET/sNET are supported (E:147–161). SY is its own share token, not either metadata wrapper; 18 decimals is requested/copied, not established merely by the constructor argument.

**Observed:** projected supply is `min(T+floor(p*T/C),uint128.max)` with checked pre-cap arithmetic, followed by `floor(INDEX_GONS/floor(TOTAL_GONS/newSupply))`. Not-due, zero-profit and zero-circulating branches return current index (E:113–125). Local staking processes one due epoch per call, before principal transfer; zero circulation skips sNET rebase but retains queue and advances epoch (`N/Staking.sol:88–151`). Multiple composed calls can advance multiple epochs. Matching deployed constants/order remain a condition, not an observation.

**Derived:** at fixed I>0, minimum sufficient shares for nominal y are `ceil(y*D/I)`, with forward/predecessor checks and actual forward multiplication domain. Deposit inverse is `ceil(s*I/D)`. Nested floors forming I do not weaken the fixed-I proof. For 0<I<=D, the minimum hits y exactly; I=D is identity. For I>D, nominal gaps exist. Final exact-output delivery and residual handling need the actual composed route, not only this minimum.

**Observed/integration:** deposit mints to explicit receiver, while SY holds raw sNET backing. Hook-held reserves redeem as hook caller with false. True burns SY-owned shares without depositor authentication (E:231–270). MinTokenOut is compared **after payout** to nominal computed output, not receiver delta. Reverting the SY frame rolls back its burn; caught failure still rolls back that frame, but can leave earlier outer steps unless the whole required route reverts. No burn-recovery mechanism is needed.

**Integration preserves product:** existing Weighted/native fee order prices NET/sNET; raw SY debit is independently derived. H is eligible recognized held SY, not public surplus `max(raw-booked,0)`. Claim iff H<d; use actual market/YT claim path (SY reward methods are empty, E:309–333), replace receivable once, recompute, and require held>=d plus held+remaining net claims−d>=1 raw SY unit. No ordinary PLP/YT fallback, public-LP appropriation, percentage floor or duplicate fee. Measure final recipient delivery in rebase-aware windows; end-of-route sync alone is insufficient.

## 5. Cross-review corrections and moderator adjudication

| Issue | Review outcome and adopted disposition |
| --- | --- |
| Persisted burn | MiniMax explicitly retracted it. Astra/Kimi correctly distinguish failed-callee rollback from earlier successful outer steps. Grok's review sentence suggesting a swallowed failure could preserve the failed SY burn is also too broad: it cannot. |
| Preview bug | Astra/Grok/Kimi reject it: post-stake Ic can equal pre-call Ip, even with several overdue epochs. MiniMax retains a “real divergence” characterization; **not adopted**. Warmup affects immediate backing, not by itself the index equality. No invented multiplier or parity-fix pre-rebase. |
| Persistent SY-owned reserve | MiniMax continues calling both custody designs viable. **Rejected for persistent inventory:** public true-flag redemption is not depositor-authenticated. An explicitly atomic transfer/mint-and-consume router step is a different, separately mapped case. Hook-held false is adopted. |
| Token identity/decimals | Kimi softened decimals to inference. MiniMax still calls SY the wrapper in its review; **rejected** by E:58–66,204–214,679–692. Metadata evidence can prove immutable decimals without requiring an unused wrapper money-path implementation. |
| Projection/minimality | MiniMax's systematic underestimation/upper-bound-only claims rejected: matching local rebase has identical nested floors; fixed-I ceil is the minimal sufficient inverse. Zero circulation does not call local sNET.rebase. |
| Arithmetic | Kimi retains a backing-bounded safety argument; MiniMax retains invalid exponent/index estimates. **Neither establishes an unconditional reachable-domain proof.** Source does not measure backing on every deposit; verified deployed backing/mirror assumptions remain absent. Adopt exact per-expression guards, not either numerical claim. No live overflow exploit is claimed. |
| Receipts/tax | Astra's rebase-aware windows adopted by Grok/Kimi. Kimi's original “taxed ingress always reverts” omitted prior inventory subsidy and taxed staking pulls. Actual-hop receipt proof remains necessary; canonical SE tax is not charged again. |
| Claim/remainder | H<d is the trigger, independent of H+C sufficiency. Remaining claims count toward positive remainder after settlement. Grok's review still says held+c<=d necessarily fails; at equality with positive remaining eligible C that is too strict. Plan explicitly accepts H=d,Cremaining=1. |
| Provider | One raw SY sample can be zero. For verified18/9 units and this body, q=1e18 gives a=Ic and normalized Ic*1e9. Keep provider/caller rounding distinct from whole-book native redemption; Grok/Kimi's floor-native-then-scale shortcut is not silently made the pricing convention. |

Originals and reviews are preserved, not retroactively rewritten. Statements within them claiming “all four agree” are not adopted where the actual reports or source contradict them.

## 6. Remaining substantive dissent and finite gaps

1. **Exact-output gaps:** Grok, MiniMax and Kimi accept reverting direct unrepresentable outputs as sufficient. Astra objects that this does not finish the required ERC4626 route/domain and residual-rights specification. Moderator adopts the distinction: direct payout must not violate exact delivery, but complete L3 needs an operating-domain proof or an existing-rights-compatible composed payout. No new excess beneficiary, dust warehouse or blanket route deletion is selected. I=2D,y=1 is a mathematical example, not a current-chain state observation.
2. **Pre-rebase:** MiniMax proposes an optional fix; Grok rejects it; Kimi calls it economics-affecting; Astra requires actual chronology. Moderator does not add one as a fix. Existing required settlement stays operative; finishing the full graph must identify every actual sync/stake/unstake and subsequent snapshot. This is engineering/source-mapping work, not a new broad economic questionnaire.
3. **Custody and bounds:** MiniMax's persistent SY-receiver recommendation and Kimi's universal backing-bound claim remain dissenting assertions, rejected/qualified above. The round is complete, not unanimous on every claim.

Concrete remaining work, not generic “more research”:

| Layer | Remaining evidence/specification |
| --- | --- |
| Claim composition | Pin actual market/YT/router selector, claim recipient, native fee/index accrual, force-claim/history reconciliation and state effects. |
| Provider integration | Pin rate/caller scaling and each floor; keep current-sNET valuation and full-size funding independent. |
| Full L3 routes | Complete Keep-YT/owned-HLP/rollover execution graph, actual BasePoolMath mode/ownership, intermediate receipts, epoch chronology and exact-output residual/domain proof. |
| G1 deployment | Block-pinned proxy/implementation/immutables, market/SY binding, NET/sNET/SY metadata; deployed Staking/sNET constants/epoch tuple/order; immediate delivery/warmup, enabled/oracle/distributor; live balances/allowances/pause/cap and endpoint tax mappings. |
| Validation | Execute the plan's new vectors only under separate authorization. Local-reference differential is not deployed equivalence; passing tests are not security/economic proof. |

Missing decimal-wrapper wrap/unwrap bodies do not block unused routes. None of these gaps reopens L1, L2 or NN-03; G0 instruction reconciliation and L4 terminal rights are untouched.

## 7. Status, saved changes and human checkpoint

| Item | Disposition |
| --- | --- |
| Extraction and actual SY conversion-body mapping | **Resolved.** Do not repeat acquisition/extraction or retain unread-body blockers. |
| Complete L3 composition | **Pending**, narrowed to §6 and plan §6.5.7. |
| G1 actual deployment/state evidence | **Pending**, not collected by this source review. |
| Tests/product execution | **Not performed or authorized.** |

Saved moderator changes: this report; implementation-plan **v0.8** (document control, L3 row, §6.5); tracker (dated2026-09-28 progress and current statuses). Historical entries and all eight attributed artifacts remain intact. PRD economics unchanged; its companion-plan pointer may retain the historical v0.7 wording until a separately scoped editorial reconciliation.

**Confidence:** high on directly read branch/custody/minimum formulas and fixed-state inverse proof; conditional on deployed mirror/metadata/receipts; incomplete on full composed exact-output availability. Consensus is not proof of security or profitability.

**Implementation handoff, not execution authorization:** use v0.8 §6.5 as the corrected conversion specification; finish the listed source-composition obligations, gather G1 evidence and retain G0 before an executable handoff. Do not implement rejected peer recommendations or resolve residual economics by guesswork. Human checkpoint: review this bounded result and authorize the next specific evidence/composition task if desired. No further council calls or implementation follow automatically.
