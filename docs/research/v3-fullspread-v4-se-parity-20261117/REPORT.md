# Research report

## Question

- Run ID: v3-fullspread-v4-se-parity-20261117
- Question: Does `docs/research/v3-fullspread-v4-accounting-plan-20261116/UNISWAP_V3_FULL_SPREAD_V4_ACCOUNTING_IMPLEMENTATION_PLAN.md` accurately define how to refactor the Uniswap V3 Full Spread vault so that it behaves like the Uniswap V4 SE vault? If, and only if, that plan is an accurate definition of that refactor, was the Uniswap V3 Full Spread vault actually refactored so that it behaves like the Uniswap V4 SE vault?
- Profile: research
- Council kind: full
- Result label: full

## Authorization and scope

- Authorization source: explicit council directive
- Authorizing task or role: the user asked, in this session, to have the council confirm that the named plan accurately defines how to refactor the Uniswap V3 Full Spread vault to behave like the Uniswap V4 SE vault, and, if the plan is correct, whether that refactor was done
- Admitted read scope: the named plan, the PRD it names as authority, production Solidity under the V3 full-spread tree, the V4 full-spread tree, and the V4 upper/lower wings tree
- Inherited permissions: accepted. They are not extra authority and not a sandbox.
- Implementation authority: none. This report does not authorize edits, tests, installs, deployment, or Git.

## Participation

| Participant | Role | Requested model and reasoning | Actual model and reasoning | Task ID | Fresh or continued | Status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Invoking session | coordinator, not a vote | current session model | xai/grok-4.7, high | not exposed | continued | settled | session environment |
| astra | council-member | chatgpt-subscription/gpt-6-astra:high | chatgpt-subscription/gpt-6-astra; reasoning not exposed | st_01a1eb4a | continued for feedback | initial and feedback settled | completion notification |
| grok | council-member | xai/grok-4.7:high | xai/grok-4.7, high | st_01a1eb4b | continued for feedback | initial and feedback settled | completion notification |
| minimax | council-member | minimax/MiniMax-M3, adaptive thinking | minimax/MiniMax-M3; reasoning not exposed | st_01a1eb4c | continued for feedback | initial and feedback settled | completion notification |
| kimi | council-member | kimi-coding/k3.1-pro:high, global route | kimi-coding/k3.1-pro, high | st_01a1eb4d | continued for feedback | initial and feedback settled | completion notification |

- Coordinator mode: invoking-agent
- Actual mode equals requested mode: yes
- Missing initial responses: none
- Missing feedback: none

## Conclusions

The council does not confirm either claim.

The supported Uniswap V4 SE family is `upperLowerWings`. `CLAUDE.md` line 24 names that family and says both V4 FullSpread families are deleted and must not be restored. Against that vault, the plan is not an accurate definition of the requested refactor. The plan's own question, at lines 4-5, is how to satisfy its locked PRD. That PRD, at lines 11-13 and 31, names the V4 full-spread vault as the behavior source and says upper/lower wings are not the template. Those are different scopes. They are not two instructions that both bind this council, and file presence does not erase the router sentence.

The behaviors that do not match wings are economic, not filenames:

- Wings issues shares from target-token credit against liquidation value and says there is no permanent sink (`upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol` lines 8-9 and 18-22). Its deposit mints that amount to the recipient after harvest (`UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol` lines 120-136). The plan requires raw-liquidity shares, a first add above 1,000, and a 1,000-share `address(0)` balance inside `totalSupply` (plan lines 43 and 65), and it takes the usage fee out of gross shares (plan line 67).
- Wings `exchangeIn` accepts only target-to-share or share-to-target (`UniswapV4UpperLowerWingsStandardExchangeVaultQuoteBase.sol` lines 27-31). The plan also defines either-token entry, a both-token bundle, and an underlying-to-underlying pass-through.
- Wings executes exact-out (`UniswapV4UpperLowerWingsStandardExchangeVaultOutTarget.sol` lines 8-24) and exposes `getRate` (`UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol` lines 27-31). The plan forbids `getRate` (plan lines 33 and 36) and makes enabled `exchangeOut` fail closed.
- Wings keeps an oracle liquid-reserve sleeve (`Accounting.sol` lines 41-48). The plan removes the sleeve.

The limited overlaps do not make those receipts the same. Both can check a deadline, reject a disabled deposit, and expose a two-word `previewExchangeIn`. Wings hardcodes that preview's refund word to zero. Those overlaps are not the share, fee, route, exit, reserve, or exact-out result.

Because the plan is not an accurate definition of wings behavior, the conditional confirmation is not reached. Current V3 sources were not refactored to behave like wings. Astra, grok, and kimi each reached that negative. The coordinator's checks above agree with it. This is not a vote, and it is not a claim that the user's words can only mean wings.

The plan the user named defines a different refactor. Against the on-disk V4 full-spread vault, which the PRD names and whose files are present, the plan is only partially accurate. Partial is not a yes, so the conditional confirmation is not reached on that reading either. MiniMax used this comparator. The other three did not. The coordinator does not convert that split into consensus, and does not drop the reading, because the user pointed at this plan.

The full-spread gaps that keep it from being accurate:

- Appointment while disabled is a labeled plan choice, not a lock (plan lines 24 and 92). V4 full-spread `setOperator` and `setOperatorFor` do not check disable (`v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol` lines 122-131). Current V3 does (`v3/UniswapV3FullSpreadStandardExchangeVaultMaintenanceTarget.sol` lines 63-73).
- A zero-output pass-through. Plan line 96 says a zero first word is a failed or unsupported plan, not a successful pass-through. The draft called the plan silent. That was wrong. Current V3 sets `failed` when the quoted output is zero (`v3/UniswapV3FullSpreadStandardExchangeVaultPlanner.sol` lines 286-288) and reverts `ExchangeInNotAvailable` (`v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol` lines 39 and 50). V4 full-spread `_pass` does not set `failed` (`v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` lines 120-130). Its execution does not revert that plan at line 68. It reverts `AmountOutNotMet` only when output is below `minOut` (lines 69-70). When `minOut` is zero, it pays the recorded output and refunds the unspent input (lines 78-80). The plan therefore specifies a rejection the V4 vault does not have, and current V3 follows the plan rather than that vault.
- Invalid bundle previews. V4 returns zero words (`v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol` lines 24-36 and 42-48). Current V3 reverts (`v3/UniswapV3FullSpreadStandardExchangeVaultBundleQueryTarget.sol` lines 12-13, 24-25, and 30).

A possible one-liquidity-unit difference in proportional sizing was inferred and not measured. It is not adopted.

Separate observation, not the requested confirmation: the current V3 production tree follows the plan's full-spread accounting on the paths read. The floor write is direct storage, as the plan requires (`v3/UniswapV3FullSpreadStandardExchangeVaultRepo.sol` lines 43-48), not the V4 call `ERC20Repo._mint(address(0), Types.MIN_SHARES)` (`v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol` line 239). All four responses reported substantial plan-following in their observation sections. No response reported a material contradiction between the plan's required economic rows and the current V3 sources on the paths that member read. That is static reading, not a test run, and it is not wings behavior.

Import remains a V3 route. The PRD, at line 195, says V4 has no import and that this entry is not a V4 copy. Keeping it means the V3 vault has a behavior the compared V4 vaults do not.

## Evidence

| Item | Source | Class | Used for |
| --- | --- | --- | --- |
| Plan asks a PRD question, not this question | plan lines 4-5 and 8 | source observation | Q1 framing |
| PRD names full-spread and excludes wings | PRD lines 11-13 and 31 | source observation | comparator scope |
| Supported family sentence | `CLAUDE.md` line 24 | source observation | supported-family reading |
| Wings issuance, sleeve, routes, rate, exact-out | Accounting.sol 8-22 and 41-48; Money.sol 120-136; QuoteBase.sol 27-31; EconomicTarget.sol 27-31; OutTarget.sol 8-24 | static analysis | wings mismatch |
| Plan floor, fee, and no `getRate` | plan lines 33, 36, 43, 65, and 67 | source observation | wings mismatch |
| Appointment disable choice versus V4 and V3 | plan lines 24 and 92; V4 MoneyTarget.sol 122-131; V3 MaintenanceTarget.sol 63-73 | static analysis | full-spread gap |
| Zero-output pass-through | plan line 96; V3 Planner.sol 286-288; V3 InBase.sol 39 and 50; V4 Planner.sol 120-130; V4 Execution.sol 68-70 and 78-80 | static analysis | full-spread gap; draft correction |
| Bundle preview failure | V4 QuoteTarget.sol 24-48; V3 BundleQueryTarget.sol 12-13, 24-25, and 30 | static analysis | narrower full-spread gap |
| Floor write path | V3 Repo.sol 43-48; V4 Execution.sol 239 | static analysis | mechanism difference the plan requires |
| One-liquidity-unit sizing | MiniMax response, not measured | unverified | not adopted |
| Public queries | not used | not used | none |

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| The named implementation plan | required | examined | question, choices, and the cited requirement lines were read |
| The locked PRD | required | examined | behavior-source and import sentences were read |
| V3 production Solidity | required | partially examined | cited money, planner, import, reserve, and package paths were read; not every line of every file |
| V4 full-spread production Solidity | required | partially examined | cited planner, execution, quote, and appointment paths were read |
| V4 upper/lower wings production Solidity | required | partially examined | accounting, deposit, route, rate, and exact-out paths were read; harvest and rebalance bodies were not re-read line by line |
| Pair-token | optional | not examined | no required document named it as the behavior source |
| Prior council member files | optional, excluded | not examined | the brief forbade them as evidence |

## Disagreement and missing responses

- Disagreement: Astra, grok, and kimi used upperLowerWings as the V4 SE vault. MiniMax used the on-disk V4 full-spread vault. Astra and kimi asked the final to make wings the only primary verdict. Grok and MiniMax supported keeping both readings. The confirmation fails under both readings, for different reasons.
- Dissent carried into this report: MiniMax's selection of the full-spread vault remains a preserved comparator, not a defeated one. The one-liquidity-unit inference remains unverified.
- Missing responses treated as approval: no
- Feedback used as a missing initial response: no

## Advisory review

- Draft ID: draft-v3-fullspread-v4-se-parity-20261117-r1
- Draft path: `docs/research/v3-fullspread-v4-se-parity-20261117/coordinator/draft.md`
- Resolution path: `docs/research/v3-fullspread-v4-se-parity-20261117/coordinator/resolution.md`
- Feedback dispositions: astra requested-changes; grok requested-changes; minimax support-with-reservations; kimi requested-changes
- Post-review wording changes: the pass-through locators, the bundle-preview locators, the supported-family wording, and the compact wings summary
- Those changes are member-approved: no

## Recommendations

- Do not treat this report as authority to edit the vault or the plan.
- If a later task needs one comparator, the owner has to say whether "the Uniswap V4 SE vault" means the supported wings family or the full-spread vault named by the plan's PRD. This report does not make that product choice.
- A test run was not authorized. Static agreement with the plan is not a passing suite.

## Limitations

- Static analysis only. No Forge build, test, gas measurement, or deployed-bytecode check was run.
- Live files can change. This report is not an atomic snapshot.
- The historical identity of the present `v4/fullSpread` tree, relative to the deleted families named in `CLAUDE.md`, was not established. The files were read. Nothing was restored.
- Wings harvest and rebalance bodies were not re-read line by line for this final. The sleeve and deposit-path checks above were.
- Inherited permissions are not confinement evidence.

## Publication

- Publication state: published
- Final path or chat-only statement: `docs/research/v3-fullspread-v4-se-parity-20261117/REPORT.md`, also returned in the conversation
- Cooperative update: none. The plan and the PRD were not edited.
- Unrelated edits preserved: yes. The reviewed draft bytes were not edited.
- Model work repeated for publication: no
- Git actions: none
- Artifacts retained until explicit deletion: yes
