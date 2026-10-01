# Funded-gons staking and transfer-only reward funding

Moderator record date: 2026-09-27. Four originals and four same-session cross-reviews completed. Requirements/plan amendment only.

## Decision and direct answer

**Yes: a normal NET-DETF transfer into sNET-DETF can distribute rewards in the same transaction with no second user call.** It requires a small notification adapter because our custom NET-DETF controls the backing-token movement. Internally the staking child still executes funded allocation and updates a shared divisor.

Unmodified stock sNET does not make a backing-token transfer execute a rebase, and the current Universal funded component does not automatically observe arbitrary parent-token transfers. “No extra user call” is feasible; “no internal accounting execution” is not the behavior of an index-based token.

The human explicitly permits changing the prior requirements to use sNET-style accounting and states the transfer-only preference. PRD v0.31 and plan v0.4 adopt existing **funded-gons** mechanics with immediate parent notification, rather than copying NetNet stock inventory/cap/clock or silently claiming equivalence with literal live B/U.

## Source evidence

The moderator directly read `StakedDETFTarget.sol:30–247`, `DETFFundedStakingRepo.sol:24–226` and prior `DETFFundedStakingMath.sol` in `contracts/vaults/detf/common/`; researchers traced parent mint/transfer and Crane ERC20 paths.

| Source | Finding |
| --- | --- |
| `StakedDETFTarget.sol:113–167,241–247` | Synchronization is attached to staking-receipt operations. It does not intercept an ordinary NET-DETF backing transfer. |
| `StakedDETFTarget.sol:170–183,228–234` | Existing DETF-only `fundRewards` pulls and measures funding, then distributes. Calling it after an already-completed transfer would pull again. |
| `DETFFundedStakingRepo.sol:93–139,147–202,213–217` | Exact principal/gon credit/debit, local fraction retirement, separate standing weights, allocate→ordinary rebase→recipient issuance and backing assertion. Unsolicited surplus is not automatically allocated. |
| `DETFFundedStakingMath.sol:10–11,45–94,110–116` | K0=1e36, exact x*K movement, conservative funded rebase, explicit dust/standing allocations and fixed native-principal protection. |
| `UniswapV4DetfCommon.sol:138–140,373–379` | Direct Repo mint bypasses public transfer; reference rewards currently mint-to-self/approve/pull. |
| Crane `ERC20Target.sol:52–68`; `ERC20Repo.sol:258–268,297–301,329–346` | Reference transfer/transferFrom/mint do not automatically notify recipients. Every custom movement into staking needs coverage. |
| NetNet `StakedNET.sol:83–99,127–136` | Stock sNET rebases explicitly; its transfer function only moves gons. |

Paths are inspected local snapshots, not deployed revision pins. No external API claim needed fresh documentation lookup for this local analysis. Repository configured compiler0.8.35 is previously read configuration, not an executed build/version check. The custom adapters are specified new work, not existing code or certified deployment behavior.

## Adopted integration

1. **Funded source math:** `balance=floor(g/K)`, `liability=floor(Q/K)`, native x principal/transfer/debit uses x*K at settled K. Reward allocation/rebase can reduce K using source ceiling arithmetic. For fixed K, `floor((g±xK)/K)=floor(g/K)±x`; early reward claims preserve native principal exactly. No per-holder loop or literal B/U admission equation.
2. **Immediate reward receipt:** parent transfer/transferFrom and internal mint/transfer into staking update balances and issue one authenticated receipt to a new no-pull child funding entry. Normal positive incoming transfers without a classified funding context are reward donations; sender receives no principal. Old surplus is not the amount of this receipt.
3. **Principal context first:** the authorized staking path establishes kind/nonce/from/operator/amount/position before movement. Matching notification acknowledges principal only; the outer operation issues principal once. Direct mint requires the same classification; from=zero alone is insufficient.
4. **No double accounting:** replace reward mint-to-self/approve/pull in the custom family with notified funding. If legacy fundRewards remains, its predeclared pull context makes the callback acknowledgment-only and lets the outer path distribute exactly once.
5. **Guards:** receipt handler accepts only configured parent and matching operation, consumes nonce once, never calls `_synchronize`, and permits only the expected callback during parent synchronization or locked principal pulling. It must not disable a general lock. Oracle/NFT/backing reads and intermediate views still require protection; “gons-only” is not a reentrancy proof.
6. **Source ordering:** account new backing once; allocate new reward plus allocationDust using persistent weights; apply ordinary allocation plus stakingDust first; issue recipient gons at resulting K; top up future weights. Do not rebase the full pot and then add fee claims again. Existing fee/creator authority remains distinct from hook reward feeTo routing.
7. **Empty states:** zero ordinary Q with standing recipients remains funded and distributable. All-zero weights retain source `MissingRewardWeight` rejection for positive reward funding. Zero/self transfer has no reward effect; old unclassified funds cannot enrich the next depositor. This is not a guarantee every donation succeeds in an inert or weightless instance.
8. **Atomicity/trade-off:** the sender performs one ERC20 transfer, but that transfer uses more gas and can revert if required funding/accounting dependencies fail. If successful, receipt balances reflect its funded distribution before return. Lazy sync is not the selected default.

Do not import stock NetNet preminted fragments, uint128 cap, queued eight-hour distributor clock, source linear principal vesting, a new fee/default or different custom lock. Actual DETF must fund every issued liability. Keep source account/position-local dust retirement and do not clear pooled NFT escrow remainders globally.

## Corrections and attribution

- Astra supplied the full immediate-notification proposal and source-mapped principal/legacy contexts, empty-state and guard boundaries.
- Grok initially recommended limiting raw wallet donations. Its cross-review withdrew that extra restriction: ordinary incoming reward transfers are precisely the requested interaction. It correctly distinguished reference pull funding from a new no-pull adapter.
- MiniMax initially claimed the feature already worked because sDETF transfers are synchronized, and that stock sNET transfer rebases. Cross-review corrected both. Its initial statement that NET-DETF itself becomes a rebasing token is not adopted: this amendment concerns the staking receipt. Separate native-principal bookkeeping alone is not the proof; the settled-K x*K identity is.
- Kimi correctly identified missing notification but initially suggested ingesting all `held−accountedBacking` surplus and over-relied on gons-only distribution for safety. The final design uses operation-specific receipts and explicit callback phases, not arbitrary surplus discovery.

There is final agreement on funded-gons source reuse plus a new immediate movement adapter. No consensus claim substitutes for integration/guard tests. The user preference, rather than a vote or a moderator-imposed economic policy, supplies the ordinary-transfer reward behavior. No new owner question is necessary for this staking choice.

## Round protocol and evidence limits

Eight task calls completed: four independent originals before sharing, then four original-session continuations reading the other three complete originals together. No peer cross-review shared; prior histories retained; no substitution/restart.

| Researcher | Original | Cross-review | Session |
| --- | --- | --- | --- |
| Astra | [Original](astra-original.md) | [Cross-review](astra-cross-review.md) | `ses_f1c499b6bffe6RiNjZZUSMsP8S` |
| Grok | [Original](grok-original.md) | [Cross-review](grok-cross-review.md) | `ses_f1c4384d7ffeZX74uV9yhIXbVq` |
| MiniMax M3 | [Original](minimax-original.md) | [Cross-review](minimax-cross-review.md) | `ses_f1c3f57edffedYs43k2PBvA5xU` |
| Kimi K3 | [Original](kimi-original.md) | [Cross-review](kimi-cross-review.md) | `ses_f1c3a8701ffeB4x8S7oRn2JnXK` |

Routing metadata: openai/gpt-6-astra, xai/grok-4.6, minimax/MiniMax-M3, kimi-code-plan-global/k3; not provider attestation. Some researcher environments report September28 versus moderator/system September27; preserve original access annotations rather than silently reconcile them.

High confidence in source behavior and representation/trigger distinction. No executed proof of the new notification/guard integration, gas measurement, live oracle configuration or deployment equivalence. No code, shell/tests, RPC, browser execution, transactions or instruction/config changes performed.

## Saved changes and handoff

PRD v0.31 §10.2/R43/A41/A49 records the explicit representation change and transfer-only user interaction. Plan v0.4 §9 specifies the source math and new received-funding/parent movement protocol; L1 is closed as a model-choice conflict, not marked implemented. Tracker NN-12 moves to source-based implementation/validation. L2–L4, configuration evidence and non-staking integration remain separate work.

Human checkpoint: the requested transfer-only reward interaction is feasible under this custom-parent design; no extra distribution transaction is needed. Implementation is a separate authorized task. Stop here, without claiming the complete unrelated plan or new adapter has been executed.
