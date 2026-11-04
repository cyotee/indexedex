# Independent redo: do entry and exit swaps eliminate APEX-012?

Date: 2026-10-26. Owner: 01a17791-24d6-72f1-8577-499bc1f0819a.
Explicit authorization: the user requests a fresh council to redo the research and obtain actual evidence whether swapping during deposit and exit eliminates the vulnerability.
Full native research council; invoking-agent coordinator, not an independent vote.

## Question

Under the premise that the target/opposing pair has only one liquidity venue and this pool's TWAP is the available reference, do actual entry and proportional-slice exit swaps eliminate manipulation-induced ownership dilution or reserve extraction? Determine the exact mint equation, fee and inventory cutoff, and execution rules for every answer. Seek both a safety invariant and counterexamples, without presuming either verdict.

Distinguish:
1. APEX-012's current whole-book liquidation quote mint/payout and temporary-depth attack.
2. Adding real swaps but retaining quote-priced entitlements.
3. Literal executed-price mint `m=S*D/(A_T+p_exec*A_O)` with pre-swap book, and corrected post-swap/fee-aware/final-contribution variants.
4. Price-free proportional position-vector mint, unmatched input refunded.
5. Corrected historical same-pool TWAP versus the actual oracle implementation.

No independent feed or free external liquidation. No redefinition of getRate: normalized actual one-whole-share withdrawal-and-sale preview, separate from issuance. Recommendations may change requirements if named; no implementation authorization.

## Independence and evidence

Start from production/audit/dependency sources. Do NOT read the prior council REPORT, handoff conclusions, member originals, research code/results, or new peers during your independent pass. The coordinator has read the prior report, which is disclosed contamination; members are fresh. After your first-principles argument, explicitly state what remains unproved.

Required primary local sources:
- CLAUDE.md.
- contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/: Money, Accounting, LiquidationQuote, Inventory, Geometry, Harvest, ExecutionDelegate, EconomicTarget and relevant PRD.
- docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md, especially APEX-012 (lines 266-326), 024/025/026/040 and 050 as relevant.
- contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleTarget.sol and libraries/UniswapV4TruncatedTwapOracleLib.sol; adapters as needed.
- Vendored Uniswap V4 pool/range/swap math and PoolManager as needed.
- Audit PoC sources may be read, not executed by members.

Each member must supply an exact derivation or fully specified computational witness/control. An attack ledger must close attacker target, opposing, shares, LP, debt and fees; count old vault LP fees and composition changes. Report target profit only after liquidation/repayment through the same pool, or disclose the remaining token vector. Do not mistake marked residual tokens, hypothetical lender availability, idle-book examples or single-interval models for production Wings evidence.

Cover fixed 49/50/51% swaps, size/depth sensitivity, vault self-fill, both-wing activation and attacker/JIT liquidity to the extent supported. A finite search is not a safety proof. A swap is not itself a fair-mint invariant. Explain which part of APEX-012 disappears under slice-only settlement and which separate risks remain.

## Roster, ownership and workflow

Fresh ordinary council-member tasks requested:
- astra: chatgpt-subscription/gpt-6-astra:high.
- grok: xai/grok-4.7:xhigh.
- minimax: minimax/MiniMax-M3, configured adaptive if exposed.
- kimi: kimi-coding/k3:high (global route).

Native workflow applies: four independent originals, one immutable coordinator draft, then one advisory continuation per available member containing all originals plus the same draft; preserve dissent and resolve all substantive concerns. Wait for all requested originals/feedback to settle. No substitution for provider refusal. No unrequested fan-out.

Members own only `members/<label>/response.md`, `members/<label>/feedback.md`, and optional standalone model source `members/<label>/model.py` within this run root. Use apply_patch; if unavailable, return COMPLETE text and model inline for coordinator receipt. Do not use alternative writers or truncate executable evidence.

All production/config/tests/other reports are read-only. No project tests/builds, installs, wallets, deployments or Git. The coordinator may execute standalone arithmetic in a resident kernel and publish reproduction code/results under this run; this is not an EVM or production fix test.

The current Native skill's asynchronous ordinary roles/model routes take precedence over the OpenCode-specific invocation example in docs/agent/RESEARCH_COUNCIL.md. Its research-only ownership, independent originals and no production execution boundaries remain.

## Delivery

New REPORT.md, originals, immutable draft, feedback, resolution and reproducible evidence under this unique root. Clearly separate source observations, exact proofs, executed numerical models, reported audit outputs, and unverified production reachability. No claim of audit closure from council agreement.
