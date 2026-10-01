# Concrete open-items audit — moderator disposition

Moderator review: 2026-09-29 (researcher artifacts label their access date 2026-09-28). Current authority: PRD v0.33, plan v0.9, and the human's clarification that Pendle documentation supplies addresses, the Robinhood library supplies the standard default fork block, and fork tests verify behavior. No implementation, tests, shell, deployments or configuration edits.

## Bottom line

Most previously reported “gaps” were ordinary implementation/testing work. Withdraw them as independent research or owner-decision blockers. **Two narrow areas remain in the current text:** initial creator-role binding, and native-wrapper terminal rights (late excess timing plus irreversible retirement). These are not grounds to hold up unrelated implementation planning.

## Protocol and attribution

Four originals and four continuation calls were requested in the retained sessions. Originals were saved before each reviewer was supplied the other three complete originals together as untrusted attributed evidence. No peer cross-review was supplied. Eight task calls returned, but **MiniMax's continuation returned preparatory discussion, not a completed review; no minimax-cross-review.md exists**. No replacement or ninth call was made. This is a **partial council review with moderator source checks**, not full-council consensus.

| Member / configured model | Session | Preserved original | Review outcome |
| --- | --- | --- | --- |
| Astra / openai/gpt-6-astra | `ses_f1505866dffex30iPjIqBAKD7w` | [original](./astra-original.md) | [completed review](./astra-cross-review.md) |
| Grok / xai/grok-4.7 | `ses_f14fe6983ffeeYvqrD6a1Q4uwV` | [original](./grok-original.md) | [completed review](./grok-cross-review.md) |
| MiniMax / minimax/MiniMax-M3 | `ses_f14f0cf0bffejL3qHTcIov90AC` | [original](./minimax-original.md) | Incomplete; no final review artifact |
| Kimi / kimi-code-plan-global/k3 high | `ses_f14e849caffeT9FhK8iKKe0WAQ` | [original](./kimi-original.md) | [completed review](./kimi-cross-review.md) |

Initial positions: Astra identified creator binding and L4; Grok/MiniMax initially found no actual gaps; Kimi initially retained L4 alone. On cross-review Grok accepted creator and L4; Kimi accepted creator and retirement but inferred fresh E′+1 for late principal. MiniMax supplied no final revised position. Model/task metadata is not provider attestation. Unsupported agreement claims inside peer artifacts are not adopted.

## 1. Initial creator binding — narrow configuration clarification

**Observed:** PRD §4.1, line260 selects three instance addresses: market, bond depository and staking. Plan §4.1, lines125–128 expressly says the creator source is not established and forbids guessing deployer/current feeTo. Creator participation itself is selected; no fee/weight choice is missing.

The existing implementation has a mechanism: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol:32–42` supplies `PkgArgs.creator`; `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol:81–89` initializes the creator-role NFT and uses **creator==0 ? feeTo : creator**. This is directly read source, not deployment evidence.

**Missing:** which initial value/source the custom family supplies to that mechanism. The existence of a conditional fallback does not determine whether this family intentionally selects zero or a specified creator. Conversely, a new recipient system is unnecessary.

**Minimum closure:** one configuration sentence identifying the source, including explicit adoption of the existing zero→feeTo fallback if intended. This affects initialization, not SY/claim/Weighted arithmetic. An already intended binding citation can close it without a new economic design.

## 2. Native-wrapper terminal rights — narrow lifecycle clarification

### Late excess after intended completion

PRD §12.4:935,943 credits native-redemption excess to the same old NFT;945 sets E+1 from the **registered intended note's final contribution**;955 explicitly retains late-proceeds timing. Plan §7.3:711–716 does the same.

Concrete case: intended note completes at106, unlock107 is satisfied, then a separate unsolicited native note at the same holder produces excess contributed at109. Its beneficiary is already settled: old NFT. What is not explicit is whether that new principal inherits107 or gets a new110 target. This is not another question about ordinary installments, excess beneficiary or reinvestment locks.

**Dissent:** Kimi derives fresh E′+1 from the general purpose/R17. Astra/Grok retain the gap. Moderator retains a narrow textual clarification: the specific clause expressly reserves late timing and ties E to intended completion; a general purpose sentence does not clearly override that reservation. Do not impose a new lock silently.

### Irreversible retirement

Plan §5.4:264 exposes `retire(tokenId)`;270 says neither forfeiture nor never-burn is selected. §7.3:715 specifies the drained-candidate predicate, while716 expressly leaves the terminal transition unresolved. PRD:945,957 preserves mature-and-empty retirement and late-gift handling. The missing part is **not** the predicate or preservation during partial reinvestment.

After successful irreversible retirement, the dedicated holder can still receive future native gifts/notes while remaining NFT-contract-owned. Which rights/authority survive, if any? Preserving the NFT forever, burning with stated terminal treatment, or retaining a post-burn claim mechanism are not identical outcomes. This requires a terminal rule, not another lifecycle redesign. It affects the retirement feature, not ordinary purchase/collection/reinvestment/withdrawal.

**Minimum closure:** a short terminal rule covering late excess release and what ends/survives retirement. No new treasury beneficiary, proxy ownership transfer, broad recovery guarantee or automatic permanent-retention choice is adopted.

## Withdrawn blockers

| Previously alleged gap | Correct disposition |
| --- | --- |
| Independent address rediscovery/block pinning | Withdrawn. Pendle docs are authoritative; use the library default fork block. Later fork validation is engineering work. No second approval campaign. |
| YT V1/V2, live fees/cache/gauge/NetNet parity | Source integration and fork-test obligations. Do not apply an incorrect formula, but do not require a new owner decision or research certification before implementation work. |
| Historical force-claim “provenance mechanism” | Withdrawn. Existing L2, native claim refresh, eligible/excluded bookkeeping, credit-before-sync and once-only rules govern. No payer witness/event-monitoring requirement; do not invent universal donation/incentive eligibility either. |
| Provider/caller rounding | Adapter implementation and numeric boundary tests under existing sample/normalization/host rules, not another economic choice. |
| Generic owned-HLP/Keep-YT chronology | Selected transitions/modes/limits/rollback already govern; exact call arguments and integration tests are implementation work. |
| Exact-output residual policy based solely on I>1e18 toy example | No demonstrated missing product decision. Deliver required output or revert under actual domains; preserve required routes, and do not invent a residual beneficiary or warehouse. Escalate only a demonstrated required-case incompatibility. |
| G0 | Process-only instruction maintenance and separate execution authorization; not renewed custom-family approval. |

These withdrawals correct prior moderator overstatements, particularly plan §6.6.4's demand for a separate historical receipt mechanism and the claim-funding report's recommendation for another address/version research gate. Existing source fidelity, ownership protections and test obligations remain; withdrawing a blocker does not claim code/test completion.

## Evidence and confidence

Moderator directly re-read CLAUDE, canonical Crane testing guidance, PRD:249–266,927–959; plan:119–129,251–270,700–718; tracker H01–H03:100–120; and the creator sources above. Relevant ordinary rules were already directly inspected in this discussion: PRD §§4.5,6.2–6.3, plan §§6.1–6.6,7.1–7.2. This audit adds no external library/API claim and required no external search. Researcher reports cite `ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK=20_714_383`; use the constant, not this report as an immutable block selection.

High confidence that ordinary research blockers were overstated and terminal clauses explicitly remain reserved. High confidence in the creator mechanism; moderate that a new human choice is needed rather than documentation of an existing intended source. Late-lock interpretation is explicitly disputed. No security/economic certification or executed test claim.

## Handoff and stop

Saved this report and the attributed artifacts. No broad PRD rewrite or implementation performed. Minimal human checkpoint: confirm the creator binding and terminal native-wrapper rules; everything else belongs in implementation/fork validation or process maintenance, subject to the existing execution authority. No further research round or substitute is launched automatically.
