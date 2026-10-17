# Kimi K3 — plan cross-review: REQ-C06 caller-first

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. Astra is the labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`; MiniMax is `ses_ebdf718feffemWQNf7wuTpapqX`. My plan draft is `kimi-c06-plan.md` in this directory. The three peer drafts were read in full as untrusted model output; the controlling PRD (`../REMEDIATION_PRD.md`) governs. Nothing was edited.
- **Date:** 2026-10-14. I did not run Forge.

## Assigned ruling: the plan can be closed with no test-file choice and no representative-branch choice — agree

The production-edit half is already unanimous and identical across all four drafts (the 21 guarded inserts, the V3 mint move, the four imports, the stop rule, the exclusions). The open divergence was the test mapping. I rule it closed as follows, after re-reading the disputed files this round.

### The closed mapping (one home per family, all existing, no new file)

1. **Hookless** → extend `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ApexRecurrenceErrorOrder.t.sol`. Verified this round: its existing cases are the direct-out route (`:30-82` drives `exchangeOut(token1, used, token0, output, …, true, …)` — the `:165` branch), so the mint (`:94`) cases are added there.
2. **Pons** → extend `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol`, same shape.
3. **V3** → extend `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol`. MiniMax's observation is verified against my own earlier read: `test_review_underfundedEoaExactOutObservesCreditError` (`:59-75`) already drives the mint route (`tokenOut == address(vault)`, `true` flag, code-less caller). The order-distinguishing mint additions still land in this file.
4. **Uniswap V2** → extend `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol` (existing EOA-pretransfer control at `:72`, production proxy), adding cases for **all seven** branches (`:462,547,623,693,794,905,972`).
5. **Camelot** → extend `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_SecRemediation.t.sol` (controls at `:100`, `:273`), adding cases for **all five** branches (`:411,513,596,663,766`).
6. **Rocket Pool** → extend `test/foundry/spec/protocol/staking/rocket-pool/adversarial/Adversarial_RocketPoolRETH_P0.t.sol` (existing pretransfer caller-error cases at `:78`, `:372`, `:420`, `:479`, `:577`), adding mint (`:60`) and asset→asset (`:82`) cases.
7. **Lido** → extend `test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol` (control at `:51`), adding mint (`:64`) and asset→asset (`:85`) cases.

Every repaired branch gets its own three assertion shapes (code-less short-credit → `EOAPretransferNotAllowed` with exact balances unchanged; contract caller short credit → the family's exact `TransferDeltaInsufficient`; false-flag code-less control). No branch is covered by a representative of another branch. That answers the coordinator's second prohibition directly; my own draft's "one representative per distinct helper path" sentence is **withdrawn** as the rejected shape.

### The sentence the plan must use

> "The seven repaired production files map to exactly these existing test files and no others: hookless, Pons, and V3 to their families' `ApexRecurrenceErrorOrder.t.sol` (hookless and Pons under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`, V3 under `.../uniswap/release/v3/`); Uniswap V2 to `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol`; Camelot to `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_SecRemediation.t.sol`; Rocket Pool to `test/foundry/spec/protocol/staking/rocket-pool/adversarial/Adversarial_RocketPoolRETH_P0.t.sol`; Lido to `test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol`. No new test file is created. Each of the 21 repaired branches receives its own three assertion shapes in its family's file; no representative substitution."

## Dissents resolved against peer text (with evidence)

- **MiniMax's hookless home (`PretransferCallerLifecycle.t.sol`) is the wrong surface.** I read that file in full (54 lines): both tests drive `IStandardExchangeIn.exchangeIn` (`:17-20`, `:36`, `:41`, `:49`) — the deposit side — not the repaired `exchangeOut` mint/direct-out routes. Its two tests also pass identically before and after this repair, so even as coverage they do not witness the order change. Rejected.
- **MiniMax's V2/Camelot "existing tests need no new code"** (`:247-248`) covers only each family's pass-through swap route; the other six/four repaired branches would be unwitnessed. Rejected under the no-representative rule.
- **Grok's seven new test files** are unnecessary: every family has an existing out-test home, and the coordinator permits a new file only where no home exists. Rejected; no new file is created anywhere.
- **MiniMax's pre-flight 0.4** ("`git status` must show only the files this plan lists … stop and report" on unrelated changes) contradicts the shared-tree rule; the record-and-preserve reading from the ERC-5115 round applies unchanged.

## Adopted from Astra (strengthens every draft including mine)

- **The static-order acceptance step** (`astra-c06-plan.md:76`): revert-only tests cannot prove that a non-reverting balance read moved behind the gate, so the implementation report must record a diff inspection at all 21 sites (guarded check precedes measurement and every consumer; credit comparisons intact). This is the only honest order witness; adopt it.
- **The V4 mint-admission fixture note** (`:78-82`): hookless/Pons exact-out mint runs inside the PoolManager session via the existing `_nested` helper, and the idle false-flag mint control expects the existing `InvalidRoute`, not a fabricated success. Adopted as peer-sourced; I did not independently re-read the Acceptance base.
- **Per-route enumeration for V2 and Camelot** (`:63-64`), adopted as the branch list for items 4-5 above.

## Unresolved dissent

None. The four drafts agree on the production edits and the acceptance semantics; the test-home divergence is settled above against the files, not by vote. Astra's ExactOutputFill home for V3 and my original SecRemediation-only framing are both superseded by the verified mint-route coverage already inside `release/v3/ApexRecurrenceErrorOrder.t.sol`.

I did not run Forge.
