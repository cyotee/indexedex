# Coordinator resolution

## Reviewed draft

- Draft ID: draft-v3-fullspread-v4-accounting-prd-20261116-r1
- Path: docs/research/v3-fullspread-v4-accounting-prd-20261116/coordinator/draft.md
- Fingerprint at review: not computed
- Draft bytes changed after review: no
- Members asked to review: astra, grok, minimax, kimi
- This resolution supersedes stale status lines in the draft: yes

## Participation and identity

- Run ID: v3-fullspread-v4-accounting-prd-20261116
- Council kind and result label: full
- Coordinator mode: invoking-agent
- Requested coordinator role and model: invoking session; current invoking model
- Actual coordinator role, model, reasoning, task ID, and session ID: invoking session; grok-4.7; reasoning not exposed; task ID not exposed; session 01a1e62a-9f21-77e3-9f3b-2eef1320e49b
- Coordinator fresh or continued: continued
- Coordinator logical assignment and attempt count: v3-fullspread-v4-accounting-prd-20261116/coordinator/synthesis; 1
- Owner or root session ID: owner session 01a1e62a-9f21-77e3-9f3b-2eef1320e49b; root session not exposed
- Identity source: session environment and task completion notifications. Model prose is not the identity source.

## Feedback disposition

| Label | Feedback path | Draft ID named by member | Disposition | Initial response present |
| --- | --- | --- | --- | --- |
| astra | members/astra/feedback.md | draft-v3-fullspread-v4-accounting-prd-20261116-r1 | requested-changes | yes |
| grok | members/grok/feedback.md | draft-v3-fullspread-v4-accounting-prd-20261116-r1 | requested-changes | yes |
| minimax | members/minimax/feedback.md | draft-v3-fullspread-v4-accounting-prd-20261116-r1 | requested-changes | yes |
| kimi | members/kimi/feedback.md | draft-v3-fullspread-v4-accounting-prd-20261116-r1 | requested-changes | yes |

## Concern map

| Concern ID | Source | Concern | Disposition | Reason |
| --- | --- | --- | --- | --- |
| A1 | members/astra/feedback.md | Oversized one-token pretransfer must spend none and refund the whole unbooked balance | accepted | Matches the V4 PRD sentence already read, and the V4 execution branch at UniswapV4FullSpreadStandardExchangeVaultExecution.sol:52-58 |
| A2 | members/astra/feedback.md | Genesis revert and later refund branches contradict each other | accepted | Split in the final. A failed genesis plan reverts. Established-supply no-mint refunds stay refunds |
| A3 | members/astra/feedback.md | Import row booked the importer's NFT fees while declaring import undecided | accepted | That booking instruction is removed. Import stays open |
| A4 | members/astra/feedback.md | Deposit fee booking is not deterministic on V3 mint | accepted | Final requires a pre-add snapshot and actual collect before the add. Unpaid and booked amounts are mutually exclusive |
| A5 | members/astra/feedback.md | ACC-19 put new liquidity in the denominator | accepted | Wording corrected to the ACC-02 formula |
| A6 | members/astra/feedback.md | Selector row hid an ABI meaning change | accepted | The open row now covers signatures, arguments, and return words |
| A7 | members/astra/feedback.md | Share burn authority was unnamed | accepted | Canonical exits burn caller-held shares. Named SY vault-held redemption stays inside the open SY row |
| A8 | members/astra/feedback.md | Astra was mislabeled as opposing fail-closed exact-out | accepted | Dissent label corrected. Fail-closed text is an adopted requirement, not an open row that also answers itself |
| G1 | members/grok/feedback.md | First-deposit failure was both a revert and a refund | accepted | Same split as A2. Checked against Planner._shares and Execution.sol:65-68: a failed plan reverts MinLiquidityNotMet. FS-OWN-33's refund sentence is not applied to that failed genesis plan |
| G2 | members/grok/feedback.md | OPEN-06 both answered and forbade an answer | accepted | Economic rejection and fail-closed selectors moved to adopted requirements |
| G3 | members/grok/feedback.md | Booked-token exclusion was conditional on an open maintenance choice | accepted | Exclusion holds whether or not donate and compound are added |
| G4 | members/grok/feedback.md | address(0) floor write can revert | accepted | Final forbids a path that reverts ERC20InvalidReceiver for address(0) |
| G5 | members/grok/feedback.md | processedInput was not tied to pull and pretransfer | accepted | Processed input is the amount this call will use after funding rules, before the 49% split. An oversized pretransfer has no processed input |
| G6 | members/grok/feedback.md | Failed exit preview had no shape and no error name | accepted | Preview returns a zero first word and does not revert. Execution reverts AmountOutNotMet and does not burn |
| G7 | members/grok/feedback.md | Full-range ticks were unnamed | accepted | Organic position uses TickMath.minUsableTick and maxUsableTick for the pool spacing. Import is not decided by that sentence |
| G8 | members/grok/feedback.md | rebalanceLiquidReserve removal did not say whether the selector remains | accepted | The mover and the sleeve-target views are removed. canOpenBoundPoolOps remains the lock gate |
| M1 | members/minimax/feedback.md | ACC-05 refund contradicted ACC-03 genesis revert | accepted | Same split as A2 and G1. MiniMax's later-only refund reading is accepted for the failed-genesis plan. Grok's request to refund an unformable first-deposit swap is rejected for that plan because execution reverts MinLiquidityNotMet when the plan is failed |
| M2 | members/minimax/feedback.md | Pretransfer rule spent the staged balance | accepted | Same correction as A1 |
| M3 | members/minimax/feedback.md | Boundary test had no position before genesis | accepted | Organic bounds are fixed before the first add. Lazy sleeve creation is not the replacement |
| M4 | members/minimax/feedback.md | Empty-supply provider zero was unstated | accepted | Stated. No fallback rate is added |
| M5 | members/minimax/feedback.md | No scope sentence | accepted | The PRD governs only the full-spread vault under contracts/vaults/standard/exchange/protocols/uniswap/v3/. The older tree under contracts/protocols/dexes/uniswap/v3/ is not modified. No deployment is repointed |
| M6 | members/minimax/feedback.md | Sleeve views were unnamed | accepted | Named from IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve |
| M7 | members/minimax/feedback.md | Floor write path omitted | accepted | Same correction as G4 |
| K1 | members/kimi/feedback.md | Mint fee booking was not deterministic | accepted | Same correction as A4 |
| K2 | members/kimi/feedback.md | Booked exclusion forbade the maintenance add | accepted | User share-minting adds exclude booked balances. An adopted maintenance operation may budget them. The exclusion itself is not conditional |
| K3 | members/kimi/feedback.md | ACC-19 denominator wording was wrong | accepted | Same correction as A5 |

## Coordinator revisions

| Change | Where applied | Reviewed by members | Label |
| --- | --- | --- | --- |
| Genesis revert split, pretransfer spend-none rule, fee collect-before-add, floor write constraint, processed-input definition, exit preview zero word, AmountOutNotMet, organic tick bounds, sleeve selector removal, scope fence, import-fee instruction removed, exact-out fail-closed moved to adopted text, share-burn authority, denominator wording | UNISWAP_V3_FULL_SPREAD_V4_ACCOUNTING_PRD.md | no | coordinator revision |

The reviewed draft bytes are unchanged. These sentences were not reviewed again. They are not member-approved.

## Missing responses

- Missing initial responses: none
- Missing feedback: none
- Treatment: not approval. Not consensus. Not filled by a later advisory file.

## Unresolved dissent

- MiniMax reserved whether the usage fee applies at all because this vault charges none today. The final adopts the V4 fee copy. That reservation is carried, not adopted.
- Donate and compound remain an open surface choice. Grok and Kimi wanted the selectors required. Astra and MiniMax wanted the addition stated as a choice. The final states the choice and does not answer it.
- Import, existing-supply migration, selector signatures, and the Standardized Yield or quoteAssets surfaces remain open. No feedback closed them.
- Grok's request to refund an unformable first-deposit swap is not adopted. The inspected V4 execution reverts MinLiquidityNotMet on a failed plan, including genesis liquidity at or under 1,000.

## Synthesis attempts

| Logical assignment | Attempt | Task ID | Fresh or continued | Reason | Outcome |
| --- | --- | --- | --- | --- | --- |
| v3-fullspread-v4-accounting-prd-20261116/coordinator/synthesis | 1 | not exposed | continued | synthesis | final written |

## Limits

- Original responses and feedback files remain unchanged.
- No implementation, reviewed-project tests, installs, or Git actions.
- Agreement among respondents is not a correctness guarantee.
- Inherited permissions are not confinement evidence.
