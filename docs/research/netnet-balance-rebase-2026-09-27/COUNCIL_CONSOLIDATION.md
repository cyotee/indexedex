# L1 — NetNet/Pendle rebasing source comparison

Moderator record date: 2026-09-27. Four independent originals and four same-session cross-reviews complete. The authorized corrected wrapper-path read succeeded. No implementation or tests executed.

## 1. Result

**Balance/share rebasing is established technology; no claim that it is an unsolved problem is justified.** The source investigation identifies exactly which arithmetic promises the inspected references implement, and supplies a principal-protected reward-share calculation. It does **not** establish a complete replacement for plan L1 satisfying every currently recorded native-principal/claim promise under the selected literal live B/U model.

The correction is important in both directions: do not call an entire design impossible from a small counterexample, and do not label two rounded formulas equivalent merely because both use shares. No reader should treat an unsupported model assertion as a completed correctness proof.

## 2. Directly checked references

The moderator independently read these paths during consolidation:

| Source | Lines | Actual behavior |
| --- | --- | --- |
| `lib/crane/contracts/protocols/pol/net/src/StakedNET.sol` | 25–40,45–77,83–99,127–136 | Fixed total gons including inventory; balance=floor(gons/stored divisor); exact x*divisor transfers; explicit divisor change on rebase; upstream supply cap |
| `lib/crane/contracts/protocols/pol/net/src/perp/WrappedStakedNET.sol` | 46–85 | Static wrapper: floor(native*1e18/index) on wrap and floor(shares*index/1e18) on unwrap; no remainder ledger or special full-exit sweep |
| `lib/crane/contracts/protocols/perps/pendle/core/StandardizedYield/SYBase.sol` | 37–85 | Implementation-specific deposit/redeem amounts, user minima, minted/burned adapter shares; no generic lossless native round-trip guarantee |
| `contracts/vaults/detf/common/core/DETFFundedStakingMath.sol` | 96–116 | Reference bond claims preserve remaining fixed native principal and define rewards as attributed staking value minus that principal |

Researchers additionally traced NetNet `Staking.sol:88–150`, concrete Pendle wstETH/Aave adapters, reward managers, PY indexes and decimal wrappers. Those additional paths support the distinctions in the original reports; not every external NetNet SY implementation was identified or verified.

### NetNet's exact native transfer identity

At a fixed stored divisor K:

`floor((g ± x*K)/K) = floor(g/K) ± x`.

This supports exact native transfers without iterating holders. But `rebase` explicitly refreshes K; the absence of a per-holder loop does not mean there is no authoritative index refresh. Its total gons include preminted staking inventory, unlike the custom family's actual funded ownership supply.

Do not substitute `K=floor(T/B)` and assert:

`floor(g/floor(T/B)) == floor(B*g/T)`.

For T10,B3,g3 the results are1 and0. This refutes that proposed equality, not the deployed NetNet mechanism. With circulating ownership instead of all inventory, the denominator changes and requires its own derivation. Do not import NetNet's preminted inventory or cap into the custom family implicitly.

### The actual wrapper rounding convention

At sNET index1,500,000,000, wrapping1,000,000,000 raw sNET units mints666666666666666666 raw wsNET shares. Unwrapping them pays999999999 raw sNET units. A one-native-unit loss is possible even with the real9/18-decimal scales. This is a static conversion wrapper with integer floors, not a guarantee of exact recovery of separately recorded native principal.

Pendle SYBase likewise delegates conversion to each implementation and enforces minSharesOut/minTokenOut. Its general interface is not proof that the chosen custom bond ledger may silently change its fixed principal or reward payout rule. Pendle reward indexes and PY conversion indexes are separate mechanisms, not evidence of the exact selected no-refresh staking formula.

## 3. Constructive live-B/U result

For B,U>0, standard share-denominated deposit and redemption are:

```text
deposit x: m=floor(x*U/B); new backing/supply B+x,U+m
redeem d shares: y=floor(B*d/U); new backing/supply B-y,U-d
```

These preserve or increase backing per remaining old share. They are reusable patterns with explicit floor semantics. They do not alone guarantee a newcomer a separately computed fixed native principal x, or make every independently requested exact-native withdrawal safe for a locked position.

For a position with u shares and native principal P already satisfying floor(B*u/U)>=P, a **principal-protected reward-share budget** is:

```text
p = ceil(P*U/B)
rewardShares = u-p
x = floor(B*rewardShares/U)
if x == 0: leave shares untouched
otherwise:
    d = ceil(x*U/B)
    pay x from custody and burn d shares
```

Because d<=rewardShares, at least p shares remain. Because d>=xU/B, the remaining backing/share ratio does not decrease. Thus the claimant's principal and other holders' backing are protected for this withdrawal construction.

**Limit:** x can be less than the reference's displayed `floor(B*u/U)-P`, and a universal one-native-unit bound was not proven. Nor was the deadline for eventual payout. This construction describes a custody withdrawal; transferring sDETF shares on the NFT reward-claim surface additionally requires recipient/post-transfer rounding analysis. It is not silently adopted as full parity with all selected claim surfaces.

The selected source defines native rewards as staking value minus remaining principal. The PRD permits native rounding, but it does not clearly state that an otherwise displayed whole native reward may be deferred indefinitely. Grok/Kimi consider the budget ordinary allowed dust; Astra does not consider that equivalence established. This is a genuine unresolved interpretation, not unanimous algorithm closure.

## 4. Rejected alleged solutions

### Pay a reward without reducing ownership

MiniMax's unchanged-u/U reward transfer is rejected. With two positions each funded100 and holding100Q shares, add20 backing: each displays110. If the first takes10 while its shares stay unchanged, B falls to210 and **both** positions display105. The second lost5 reward to the first. A separate native-principal counter does not prevent this cross-holder loss.

### Full reward rebase plus extra fee receipts

Kimi's original rebases all Δ to ordinary circulation and then creates additional recipient fΔ/cΔ. Without excluding those allocations before ordinary distribution or a correct funded-share issuance, this double-pays. Ordinary claims100 + reward10 →110, plus fee claims2, cannot be backed by110. A B/U reinterpretation instead dilutes claims and no longer has the asserted exact-native identity.

### Fixed share precision solves every edge

Multiplying new issuance alone by SCALE mixes units. Scaling all shares/U consistently still leaves divisibility/rounding boundaries. Reversing a rejected native1 example by asserting that both old and new positions get their exact principal is not a calculation. A stored P and a `value>=P` check detect some errors; they do not prove all selected deposits/claims remain executable.

### Blanket orphan rejection or reward queuing

U0/Bpositive must distinguish actual outstanding allocation rights from unrelated old backing. Funding an eligible standing recipient before issuing its receipt is not an invalid orphan event. An upstream no-circulation queue cannot replace the custom requirement that standing recipients remain eligible. Conversely, assigning all unrelated old B to a newcomer or fee recipient is not authorized by a label.

## 5. Correct recipient-algebra boundary

Keep persistent nonredeemable Wf/Wc separate from ordinary ownership U. Ordinary allocation weight includes previously funded fee/creator receipts. Preserve source top-up and two-stage floor allocation; it is not universally F=f*reward/C=c*reward.

For exactly representable receipt issuance with zero unresolved allocation dust, let S,F,C be the allocated portions of new reward A. The ownership amounts `mF=F*U/(B+S)` and `mC=C*U/(B+S)` allocate new F/C without taking old principal. Integer and orphan/dust cases still require the complete representation proof; do not substitute standing-weight deltas for ownership issuance.

At U0/Bpre0 with surviving weights20/30 and funded reward100,40/60 recipient ownership can be seeded against100 backing. This valid branch contradicts indiscriminate `OrphanBacking` immediately after funding. Neither this example nor a top-up library finishes every U0/Bpositive case.

## 6. Attributed positions and final disposition

| Researcher | Useful finding | Consolidation correction |
| --- | --- | --- |
| Astra | Exact NetNet/wsNET/Pendle semantics and principal-safe reward-share budget | Earlier exact fractional-preservation demand withdrawn; budget accepted as a proved local safety construction, not complete claim/admission semantics |
| Grok | Actual exact-fragment NetNet issuance; gons/index wrapper distinct | Reference reachability does not prove equivalent live-B/U custom reachability. Its conclusion that deferred displayed reward is already authorized remains dissent, not settled law |
| MiniMax M3 | Correct distinction among index, wrapper and live-B/U models | Unchanged-share reward payout, direct receipt/standing-share conflation and unverified PRD quotations are rejected |
| Kimi K3 | Retracted rounded-divisor equality, index/premint import and subnative-only dust claim; accepted reward budget | Its final candidate still contains unsupported scale/admission and recipient formulas. Do not mark all rights preserved or close L1 on those assertions |

**Decision:** rebasing itself is solved and these sources are useful. The exact selected combination remains an integration derivation that no complete candidate in this round proved. L1 narrows to fixed-native principal admission, exact versus safely redeemable early reward semantics, reward-funded recipient-share rounding, and U0/unassigned-backing handling. No alternative gons model or weakened principal rule is selected by this report.

## 7. Protocol, dates and artifacts

The initial Astra attempt hit a guard at the incorrect `src/WrappedStakedNET.sol`. The human supplied/authorized the known `src/perp/WrappedStakedNET.sol` correction; its ordinary read succeeded in the original session. Four originals then completed before four continuations, each reading only the other three complete originals together. No peer cross-review was shared. Nine task invocations including the interrupted original attempt produced eight completed substantive reports. No researcher/session substitution or guard bypass.

| Researcher | Original | Cross-review | Session |
| --- | --- | --- | --- |
| Astra | [Original](astra-original.md) | [Cross-review](astra-cross-review.md) | `ses_f1c499b6bffe6RiNjZZUSMsP8S` |
| Grok | [Original](grok-original.md) | [Cross-review](grok-cross-review.md) | `ses_f1c4384d7ffeZX74uV9yhIXbVq` |
| MiniMax M3 | [Original](minimax-original.md) | [Cross-review](minimax-cross-review.md) | `ses_f1c3f57edffedYs43k2PBvA5xU` |
| Kimi K3 | [Original](kimi-original.md) | [Cross-review](kimi-cross-review.md) | `ses_f1c3a8701ffeB4x8S7oRn2JnXK` |

Routing metadata: openai/gpt-6-astra, xai/grok-4.6, minimax/MiniMax-M3, kimi-code-plan-global/k3; not provider attestation. Originals unchanged. Some researchers report access/review date2026-09-28 from their environment; moderator/system record and directory use2026-09-27. Preserve the discrepancy rather than rewriting retrieval history.

Public sources reported after Context7 lookup include https://docs.netnet.capital/official-channels, https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield, https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield/DecimalsWrapper and https://raw.githubusercontent.com/pendle-finance/pendle-sy-public/main/contracts/core/misc/PendleDecimalsWrapper.sol. See originals for per-researcher access annotations. The actual configured external SY implementation was not independently certified in this round. Source pragmas/compilation history do not establish current runtime; no tests or live-chain calls performed.

## 8. Plan handoff and checkpoint

Plan §9 now includes the protocol comparison and principal-protected reward construction explicitly as reviewed analysis, without silently changing principal/claim semantics. No code, shell/tests, RPC, browser execution, signing, deployment or instruction/config edits were performed. L1 is not marked resolved, and the plan is not falsely declared finished.

The next narrow checkpoint is whether the permitted rounding contract includes retaining otherwise displayed native reward units to protect principal; that would address the claim-conversion edge only, not prove admission/orphan/recipient rounding solved. A separate complete representation derivation remains author work. Do not ask the owner to redesign weights, fees, locks, custody or the whole rebasing mechanism. Stop after this bounded consultation.
