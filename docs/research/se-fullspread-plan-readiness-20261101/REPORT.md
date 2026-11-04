# Research report

## Question

- Run ID: se-fullspread-plan-readiness-20261101
- Question: Are the locked full-spread vault requirements complete enough to write an implementation and testing plan now, without leaving a product decision to the plan author or the implementor?
- Profile: research
- Council kind: full
- Result label: full

## Authorization and scope

- Authorization source: explicit council directive
- Authorizing task or role: the owner asked whether the council is ready to write the implementation and testing plan, and required the matrix, the integration tests, and second-audit absence tests
- Admitted read scope: the full-spread PRD, the function-review file, the second-audit report and tracker, the live hook-by-SE matrix, and the ERC-20 mint path checked during resolution
- Inherited permissions: accepted. They are not extra authority and not a sandbox.
- Implementation authority: none. This report does not authorize edits, tests, installs, deployment, or Git.

## Participation

| Participant | Role | Requested model and reasoning | Actual model and reasoning | Task ID | Fresh or continued | Status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| invoking agent | coordinator | current invoking model | not exposed | current session | continued | draft and final written | coordinator |
| astra | council-member | chatgpt-subscription/gpt-6-astra:high | chatgpt-subscription/gpt-6-astra:high, reasoning high | st_01a195a3 | continued for advisory | initial and feedback settled | Native task status |
| grok | council-member | xai/grok-4.7:xhigh | xai/grok-4.7:xhigh, reasoning xhigh | st_01a195a4 | continued for advisory | initial settled; feedback file written; terminal notice was an empty error | Native task status |
| minimax | council-member | minimax/MiniMax-M3 | minimax/MiniMax-M3 | st_01a195a5 | continued for advisory | initial settled; feedback file written; terminal notice was an empty error | Native task status |
| kimi | council-member | kimi-coding/k3.1-pro:high, global route | kimi-coding/k3.1-pro:high, reasoning high | st_01a195a6 | continued for advisory | initial settled; feedback file written; terminal notice was an empty error | Native task status |

- Coordinator mode: invoking-agent
- Actual mode equals requested mode: yes
- Missing initial responses: none
- Missing feedback: none. Three feedback tasks emitted an empty terminal error after writing a complete feedback file. Those files were used. They are not approval of the draft.

## Conclusions

Not ready. All four initial responses reach that verdict. The advisory pass keeps it. This report does not authorize the implementation plan.

The owner already required three plan-scope items. They are not open choices:

1. Add this vault to the integration testing matrix.
2. Add it to the integration tests.
3. Test that the vulnerabilities in `docs/security/audit/second_review` are not present in this new vault.

The plan can name the matrix files and can write tests whose expected results are already locked. It cannot assign expected results for the questions below.

### Questions that still block the plan

1. Usage fee. FS-OWN-24 mints the depositor's shares and then mints extra shares to `feeTo`. That is the APEX-2026-044 dilution. Is that dilution an accepted exception, or what replacement fee rule is authorized?

2. Live-price deployment and unbounded swaps. `compound()` is permissionless and deploys idle. A redemption may swap through the pool. The entry swap limit is `MIN_SQRT_PRICE + 1` or `MAX_SQRT_PRICE - 1`. That is the shape of APEX-2026-023 and APEX-2026-024. Is placement at the live price, and that unbounded limit, accepted, or which change to the locked maintenance and redemption swap is authorized? A new bound is a new authorization. FS-OWN-10 does not already allow one.

3. `compound()` with no fees. The same lock says compound deploys booked idle, and says a no-fee call returns with no state change and no event. Which sentence wins when idle is present and fees are zero?

4. Positive supply and zero deployed liquidity. Issuance for an existing supply divides by deployed liquidity. Idle is not in that denominator. That liquidity-only rule stays locked, including its consequence that a later depositor takes a claim on the existing sleeve. What is the denominator, and does the call revert, when supply is positive and deployed liquidity is zero?

5. One-token donation. An underlying donation must be deployed before `donate` returns. One token cannot become full-range liquidity by itself. Does the donation swap its own input, use the other holders' opposite token, or revert, and what happens to an amount that cannot be placed?

6. Views. FS-OWN-19 says no view reverts. Busy economic views and `previewExchangeOut` are still specified to revert. Which views may still revert, and what does a non-reverting unsupported or busy preview return?

7. Proxy getters. Which Protocol Aware and Position getters are installed on this diamond, and are those facets package inputs? The Robinhood addresses are the named constants. They are not an open value choice.

8. Hook rows that need a rate. This vault does not implement `getRate()`. Current buffered-hook fixtures derive a rate provider for the SE leg. Name the external provider those fixtures use, or record those rows incompatible until one exists. Do not add `getRate()` to this vault.

9. Borrowed one-token exit. If the deployed fraction cannot be pulled, the vault pays the caller's local fraction or reverts `UnderlyingUnavailable`. Which token's amounts are `required` and `available`? The vault may not spend more than that holder's local fraction.

10. Share units. Are genesis shares raw V4 liquidity minus 1,000, and does any amount scaled to token decimals enter `liq * totalShares / liquidity` on a later deposit?

11. `Compounded`. Is `amount` harvested fees, amount reinvested, or net deployment after the sleeve move? If fees exist but cannot be deployed, does the call succeed, what state changes, and is an event emitted?

12. Paired events. What are the exact event names and argument lists for the mapped bundle deposit and redeem routes?

13. Pretransfer attribution. Booking only the requested amount does not say who supplied it. What ordinary-pretransfer and self-recipient rule excludes APEX-2026-039, or is that path an accepted unsupported use? Grok and MiniMax say the existing booked-amount and caller-burn rules are already enough to write the absence test. That dissent is preserved. The question stays because the absence expectation is otherwise a product choice.

### Locked consequences, not new choices

- The 1,000-share floor stays at `address(0)`. `ERC20Repo._mint` writes `balanceOf` directly. The reverting helper is not on that path. The plan uses `_mint`, not `_increaseBalanceOf`.
- The sleeve target is best-effort. The plan must not add a maintenance swap to force both targets.
- The wrapper is the network `WETH` constant. There is no `wrappedNative()` getter.
- `SwapProjection` and `ExecutionPreparation` stay as library slots. The engineer assigns already specified operations to them. The owner is not asked to design those libraries.
- The plan must not add a quote step cap, a minimum tick spacing, or a partial-fill rule. A quote that cannot finish reverts. MiniMax dissents and would make the quoter, cap, fallback, and spacing an owner choice.

### Matrix files the plan extends

Live behavior contracts under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`:

- `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`
- `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`
- `dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`
- `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol`
- `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`
- `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`
- `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol`

The plan adds a row for this vault beside those contracts. It does not edit their assertions for other families. Exact-output success rows cannot pass here: `exchangeOut` reverts `ExchangeOutNotAvailable()`. Booked-remainder rows cannot pass here: unused input is refunded. Those are adaptations of this family's rows, not permission to weaken the other families.

`docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json` has historical V4 FullSpread compatibility rows whose cited tests are not current proof of this family. The followup-review snapshots are not the current matrix. Preserve the V3 rows. Replace the stale V4 FullSpread rows rather than treating them as passed.

### Second-audit dispositions

A tracker closure by deleting the old FullSpread code does not certify this vault. "No" means this vault's plan does not encode a separate test because the mechanism is not in this vault or its required hook rows. A hook-only finding can still be tested in that hook's own suite. It is not a vault product choice.

| ID | Test in this plan | Why |
| --- | --- | --- |
| 010 | yes | A direct transfer must not become redeemable idle or caller credit. The live disablement of the retired vaults is operational history, not a test of this vault. |
| 011 | yes | Borrowed and own-unlock entry and exit must not over-mint. Deletion of the old family is not evidence. |
| 012 | no | Wings liquidation-quote pricing is absent. Borrowed-path parity is the 011 test. |
| 013 | yes | The generic ERC-4626 `deposit` selector must be absent. A pre-existing balance must not mint shares. |
| 014 | integration only | The rated-versus-face drain is in the hook, not this vault. The weighted, Curve, Balancer, and orbital rows must not treat this share as an unrated raw leg. Members differ on whether that is a vault test. |
| 015 | integration only | Curve quad join and exit accounting is hook code. The matrix row must not be counted as a vault fix. |
| 016 | no | Weighted partial-book dust seed is hook code. This vault's first deposit is the 034 test. |
| 017 | no | Balancer caller-supplied router callback. Not this vault. |
| 018 | no | Balancer `computeBalance`. Not this vault. |
| 019 | yes, as a negative | This vault has no exact-out route. The test is the locked `ExchangeOutNotAvailable` revert, not a Balancer router regression. |
| 020 | no | DETF mint and bond pricing. Not this vault. |
| 021 | no | Balancer DETF bond pricing. Not this vault. |
| 022 | yes | Same borrowed-path loop as 011, named against both IDs. |
| 023 | yes, expected result blocked | Question 2. The test cannot say the loss is absent while live-price deployment stands. |
| 024 | yes, expected result blocked | Question 2. A one-token exit must not be specified as dumping the whole opposing balance unless the owner accepts that. |
| 025 | no | Wings rebalance and loss cap are absent. |
| 026 | no separate Wings test | The 512-step liquidation quote is absent. Dust-tick liveness of this vault's own quote is the 041 test. MiniMax would make 026 conditional on a spacing choice. That choice was not added. |
| 027 | no | Staking withdrawal queues are absent. |
| 028 | yes | A dual identity-leg attempt must not burn the caller's position and pay zero. |
| 029 | yes, as a negative | This vault exposes no `getRate()` and is not bound to the full-book provider. A pumped external provider is question 8, not a vault rate. |
| 030 | integration only | Balancer quad phantom fee LP is pool code. The quad row must not be counted as a vault fix. |
| 031 | no | Balancer virtual-TTA join. Not this vault. |
| 032 | yes | Deployment through the shared factory must not leave an unprivileged post-deploy selector. |
| 033 | no | DETF primary redemption. Not this vault. |
| 034 | yes | Direct transfers and the 1,000-share floor must prevent first-deposit inflation. |
| 035 | no | Aave cross-version loop. Not this vault. |
| 036 | yes | Hook integration must not credit a staged pretransfer to a later caller. |
| 037 | no | Re-enabling a named frozen legacy vault. Not this vault. |
| 038 | no | sDETF staking weights. Not this vault. |
| 039 | yes, expected result blocked | Question 13. The absence test stays. Its expectation waits on the attribution rule. |
| 040 | yes | A pool donation followed by compound must not round a later deposit to dust shares. |
| 041 | yes | Seed dust ticks and show that a normal deposit and redeem are not frozen by an undocumented step cap. The plan must not add a cap or a minimum spacing. MiniMax dissents. |
| 042 | yes | Deployment must succeed for a token whose `approve` returns no bool. No typed Permit2 approval is required. |
| 043 | integration only | Orbital radius pinning is hook code. The orbital row must not be counted as a vault fix. |
| 044 | yes, expected result blocked | Question 1. The absence test fails if FS-OWN-24 stands, unless dilution is accepted. |
| 045 | yes | A disabled vault or package reverts `VaultDisabled` on inbound issuance. Supported exit remains. |
| 046 | no | Balancer composite-router settlement. Not this vault. |
| 047 | no | Stata one-wei donation freeze. Not this vault. The nearest vault case is 040. |
| 048 | yes, expected result partly blocked | A no-fee or undeployable-fee `compound` must not freeze later routes. The no-fee outcome is question 3. The undeployable-fee outcome is question 11. |
| 049 | yes, as a negative | Exact-out is absent. The test is the locked revert, not a Camelot equality check. |
| 050 | no | This vault does not read the truncated TWAP oracle. Do not add one. |
| 051 | yes | A preview that returns an amount must not be rejected by an impact check that does not run. No analytic planner is authorized by a silent default. |
| 052 | yes | `permit` must work for a standard signer after initialization. The plan states the EIP-712 domain name and version it initializes. That statement is an implementation note, not a new token. |
| 053 | no | Crane ownership-transfer buffering. This PRD does not change the manager. |
| 054 | yes | Each required hook that unwraps this share must approve the vault and complete the exit. A missing approval must not freeze the user. |

Member counts differ. MiniMax counted 12 fixed, 6 conditional, and 26 excluded, which does not sum to 45. Kimi counted 27 required and 18 excluded. This table is the coordinator disposition. It is not a vote and not proof that the tests pass.

## Evidence

| Item | Source | Class | Used for |
| --- | --- | --- | --- |
| Four not-ready originals | members/*/response.md | source observation | the verdict |
| Four change requests | members/*/feedback.md | source observation | the corrections |
| Fee dilution | second-audit report, APEX-2026-044 | source observation | question 1 |
| Displaced-spot maintenance | second-audit report, APEX-2026-023 | source observation | question 2 |
| Mint does not use the reverting helper | `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol` `_mint` | source observation | removing the address-zero blocker |
| Draft | coordinator/draft.md | coordinator-supplied | the text under review |

Public search was not used. Private excerpts were not sent to a search service.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| Full-spread PRD | required | examined | All four read it. Later locks override stale sentences and still conflict with each other. |
| Function-review file | required | examined | Behaviors are locked. Selector assignment is not. |
| Second-audit report | required | examined | All 45 IDs are dispositioned above. |
| Remediation tracker | required | examined | Deletion is not a certificate for this vault. |
| Live SE matrix | optional, then required by the owner | examined | The seven behavior files are named. Historical JSON rows are stale. |
| New vault implementation | not supplied | absent | The vault does not exist. No exploit was executed. |

## Disagreement and missing responses

- Disagreement: fee replacement wording, no-fee compound, 039 attribution, rate-provider fixtures, quote cap and tick spacing, and the finding counts. Each is recorded above.
- Dissent carried into this report: MiniMax would add a quoter, step-cap, fallback, and spacing question. Grok and MiniMax would not add the 039 question. Astra would treat the no-fee sentence as already controlling. Grok would ask the owner whether sleeve adjustment may swap.
- Missing responses treated as approval: no
- Feedback used as a missing initial response: no

## Advisory review

- Draft ID: draft-se-fullspread-plan-readiness-20261101-r1
- Draft path: docs/research/se-fullspread-plan-readiness-20261101/coordinator/draft.md
- Resolution path: docs/research/se-fullspread-plan-readiness-20261101/coordinator/resolution.md
- Feedback dispositions: all four request changes and retain not-ready
- Post-review wording changes: the address-zero blocker was removed after checking `_mint`; the fee, price, donation, view, getter, rate, shortfall, share-unit, event, and pretransfer questions were narrowed; the matrix files and 45-ID table were added
- Those changes are member-approved: no

## Recommendations

- Answer the thirteen questions before the council writes the implementation and testing plan.
- Do not treat this report as that plan.
- Do not restore `getRate()` on this vault while answering question 8.

## Limitations

- The new vault was not executed.
- Retired FullSpread sources were not reconstructed.
- Three advisory tasks ended with an empty terminal error after writing feedback. Those files were read. Their terminal notices were not treated as additional review text.
- The finding table is a coordinator disposition of member disagreements, not an executed regression.
- This report does not claim permission confinement.

## Publication

- Publication state: published
- Final path or chat-only statement: docs/research/se-fullspread-plan-readiness-20261101/REPORT.md
- Cooperative update: none. The PRD was not edited.
- Unrelated edits preserved: yes
- Model work repeated for publication: no
- Git actions: none
- Artifacts retained until explicit deletion: yes
