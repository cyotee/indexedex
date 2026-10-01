# Proportional zap-in implementation-plan round — incomplete

Date: 2026-09-27.

## Status

The requested decision-complete implementation-and-test plan was **not completed**. The fourth independent researcher continuation reached the task tool's 1,800,000 ms polling timeout. The moderator received no completed Kimi answer for this round. This is not proof that the underlying computation terminated; its completion and artifact status are unverified.

No cross-review calls were made in this round. No substitute researcher or replacement session was started. No code, configuration, tests, deployments or migration were executed.

## Request and authority

The user requested a detailed implementation plan leaving no decisions to the implementer, based on:

`docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`

The target remains the NEW FullSpread vault under `contracts/vaults/standard/exchange/protocols/uniswap/v4/`. In particular, D17–D19 and §6.4 require a closed-form solution for the **entire combined exact-output-plus-rebalance transition**, otherwise `InvalidRoute`. A closed-form input quote followed by iteratively solved repair is insufficient. Old-vault deprecation intent does not authorize old-source edits, deletion, deployment or migration.

## Session continuity

| Researcher | Preserved original session | This round |
|---|---|---|
| Astra | `ses_f1c5107bfffefDJanl5lU29WfQ` | Independent proposal returned; reported `astra-original.md` saved |
| Grok | `ses_f1c4d2922ffewPe5TNJvLvwfiy` | Independent proposal returned; reported `grok-original.md` saved |
| MiniMax M3 | `ses_f1c42bd1cffeeUULWzxjga1tEf` | Independent proposal returned; reported `minimax-original.md` saved |
| Kimi K3 | `ses_f1c40272fffegWv5fAQexS8el4` | Tool polling timeout; no completed returned answer received |

Proposal filenames are relative to `docs/research/uniswap-v4-zapin-plan-2026-09-27/`. The three completed researchers reported saving their originals; this status report does not claim a filesystem audit of those documents or that Kimi saved a completed artifact. All sessions were continuations of the original researchers, not replacements. Researchers were instructed not to read peers' artifacts during independent passes. Prior-round context remained in their sessions.

## Partial findings — proposals, not adopted specifications

### Astra

Proposed a common transition planner, separate exact-output closed-form planner, explicit ownership/fee attribution, and a liquidity-equivalent progress measure. Derived continuous candidate equations for holder repair, exact-share mint and redemption in a restricted single-core-swap-step domain. Explicitly identified unresolved integer-rounding/domain proofs, production-hook coverage and execution-budget feasibility. Did not claim that the continuous derivations establish integer-exact route support.

### Grok

Proposed one-step maintenance and restricted closed-form exact-output branches, with finite rounding checks. Identified current numerical inverse paths that cannot be reused unchanged under §6.4. Left a hook-sensitive exact-in protection exception unresolved. Such an exception is not adopted: inability to quote accurately does not itself authorize dropping the required execution-shortfall protection.

### MiniMax M3

Proposed work packages and a combined exact-output swap-plus-add-liquidity sequence, but called a quoter-driven construction closed-form without establishing that its underlying calculation is non-iterative or includes required inventory repair. Its returned proposal also described alignment as before flooring despite the accepted flooring-inclusive requirement. Those claims are not adopted. Several proposed owner questions concern already-settled policy rather than remaining choices.

## Why there is no decision-complete plan yet

The partial proposals agree on the principal work areas: idle exact-in composition, percentage-of-deployed sleeve targeting, holder-funded maintenance, new protections, synchronized quotes and preservation of existing FullSpread local snapshots/caller guard. This is not full-council consensus.

They do not establish a common, verified combined exact-output specification. Continuous formulas, calling a quoter, bundling operations into one unlock, or adding finite forward checks do not by themselves prove the user's closed-form requirement and integer correctness. Failure to establish a formula also does not prove mathematical nonexistence or justify blanket removal of required routes.

The following remain unresolved evidence/specification work, not choices delegated to an implementer:

1. Complete combined-transition equations, physical domains, fee/own-LP-fee treatment and integer-rounding guarantees.
2. Exact route support across pool steps, hooks, idle/blocked states and required consumers, with justified `InvalidRoute` boundaries.
3. A selected progress objective and solver/execution mechanism consistent with incremental repair, protection limits and no-churn requirements.
4. A final file/ABI/test specification reconciled against those decisions.

This status document deliberately does not convert unreviewed model proposals into implementation authority.

## Human checkpoint and separate handoff

Stop at this partial result. A human-authorized continuation can resume Kimi's same session and recover its completion state before finishing the original collection and four combined cross-reviews. Do not silently restart the researcher or substitute another model. No completed eight-turn plan round is claimed.

The intended final plan path remains:

`docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_IMPLEMENTATION_AND_TEST_PLAN.md`

That plan was not authored in this round. The next task is to complete the research/specification, not to implement the partial proposals. Writing the eventual plan will not authorize executing it.
