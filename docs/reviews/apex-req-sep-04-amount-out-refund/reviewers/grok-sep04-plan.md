# Grok plan draft — REQ-SEP-04

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-16
- **Controlling PRD:** `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md`
- **Scope:** Comment and document sentences only. No function body, signature, or test change.

This file does not authorize an edit. It is not `REMEDIATION_PRD.plan.md`.

## Stop rule

Before each replacement below, the cited old sentence must still be on the cited line. If it is gone, stop and report that ID and line. Do not choose another line, another file, or another sentence.

Do not edit function bodies. Do not add a ledger. Do not refund the whole unbooked remainder. Do not edit Slipstream, `contracts/protocols/dexes/uniswap/v4`, `AGENTS.md`, `CLAUDE.md`, `SKILL.md`, or dated review records.

## Shared replacement

Use this sentence wherever a row below says "shared exact-input sentence". Do not shorten it and do not add a second refund rule.

The declared input is processed only when present unbooked input covers it. Tokens above the declaration are not refunded. A difference between the declaration and the whole surplus does not by itself revert. Booked inventory does not fill a shortfall.

Where a row already states exact-output credit as `min(unbooked, declared maximum)` and a refund of only the unused part of that credit, leave that exact-output sentence. Do not replace it with a whole-surplus refund.

## Order

Comments C1 through C11, then documents D1 through D13. C8's Crane sync is part of C8, after the comment sentence and before D1.

### C1 — `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol`

Lines 126 and 137. Both still say: `Exact-input credits the requested amount from unbooked available and refunds nothing.`

Replace that sentence, on each line, with the shared exact-input sentence. Leave the `EOAPretransferNotAllowed()` sentence on lines 125 and 136.

### C2 — `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol`

Blocks ending at lines 11, 24, 30, 36, 42, and 48. Each still says: `excess is left uncredited and nothing is refunded.`

In each of those six blocks, replace `Exactly the requested amount is credited when at least that much unbooked input exists; excess is left uncredited and nothing is refunded.` with the shared exact-input sentence. Leave `EOAPretransferNotAllowed()` and `Booked holder backing is never pretransfer credit.`

### C3 — `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol`

Blocks ending at lines 12, 21, 27, 33, 39, and 45. Same old sentence as C2.

Same replacement as C2, in each of those six blocks. Leave the EOA sentence and `Booked holder backing is never pretransfer credit.`

### C4 — `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol`

Blocks ending at lines 11, 24, 30, 36, 42, and 48. Same old sentence as C2.

Same replacement as C2, in each of those six blocks. Leave the EOA sentence and `Booked holder backing is never pretransfer credit.`

### C5 — `contracts/interfaces/detf/IDetf.sol`

Line 169 still says: `Exact-input processes exactly `rateAssetAmount` when unbooked available covers it, leaves excess uncredited, and refunds nothing.`

Replace that sentence with the shared exact-input sentence. Leave the EOA sentence and `Booked holder backing is never pretransfer credit.`

Line 238 still says: `Exact-input processes exactly the requested amount when at least that much unbooked input exists, leaves excess uncredited to this operation and refunds nothing`

Replace that clause with the shared exact-input sentence. Leave one copy of `booked holder backing is never pretransfer credit.` Do not add a second copy.

### C6 — `contracts/interfaces/IRebasingClaimToken.sol`

Lines 177 and 188. Both still say: `Exact-input burns the requested amount and refunds nothing.`

Replace that sentence, on each line, with the shared exact-input sentence. Leave the EOA sentence and `Booked holder backing is never pretransfer credit.`

### C7 — `contracts/interfaces/IStandardExchangeInMulti.sol`

Line 27 still says: `Exact-input processes each requested amount when unbooked available covers it, leaves excess uncredited, and refunds nothing.`

Replace that sentence with: Each declared input is processed only when present unbooked input covers it. Tokens above the declaration are not refunded. A difference between the declaration and the whole surplus does not by itself revert. Booked inventory does not fill a shortfall.

Leave the EOA sentence on the same line.

### C8 — `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`

Line 56. The prior read of this file recorded: `Exact-input processes exactly `amountIn` when unbooked available is at least that amount, leaves excess uncredited to this operation, and refunds nothing.`

This session's direct read of `lib/crane` was denied as an external directory. Do not treat that denial as proof the sentence is gone, and do not treat the prior record as a reason to edit a different line. Open line 56. If that sentence is not there, stop and report C8. If it is there, replace only that sentence with the shared exact-input sentence. Do not change the function signature.

Crane sync, and no other Crane edit:

- `lib/crane` is the submodule in `.gitmodules` (`path = lib/crane`, `url = https://github.com/cyotee/crane`). The comment edit belongs in that Crane source file.
- `contracts/interfaces/IStandardExchangeIn.sol` is a four-line re-export of `@crane/contracts/interfaces/IStandardExchangeIn.sol`. It has no NatSpec to change. Do not edit it.
- After the Crane source edit, record the new `lib/crane` submodule pointer in the parent repository. The repository script for that pointer update is `scripts/submodule-commit.sh`. Run it only in the later implementation session. Do not run it in this review.
- Do not edit any Crane `AGENTS.md`, `CLAUDE.md`, or `SKILL.md`.

### C9 — `contracts/vaults/basic/BasicVaultCommon.sol`

Line 76 only. It still says: `Exact-in credits exactly `amountTokenToDeposit` and refunds nothing.`

Replace that sentence with the shared exact-input sentence. Do not edit lines 17 or 69–70.

### C10 — `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol`

Lines 24–27 still say: `exact-input routes never refund.`

Replace `and exact-input routes never refund` with: `. Exact-input routes process the declared input only when present unbooked input covers it. Tokens above the declaration are not refunded. A difference between the declaration and the whole surplus does not by itself revert. Booked inventory does not fill a shortfall`

Leave the residual-booking, fee-recipient, under-consumed, and Slippage sentences in that same comment. Do not edit lines 29–32. They already state the capped exact-output refund.

### C11 — `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol`

Lines 55–57. Line 55 still says: `Exact-in credits the requested amount and refunds nothing.`

Replace that sentence with the shared exact-input sentence. Leave the `EOAPretransferNotAllowed` sentence and `Resting unbooked face is D12 credit, not this call's refund.`

### D1 — `contracts/vaults/standard/exchange/protocols/uniswap/README.md`

Line 32 still contains: `exact-in never refunds.` Keep `No `preparePretransfer` call is used or exposed.` Keep `The measured pushed input is `balanceOf(vault) - reserveOfToken(token)` captured before settlement changes balances.` Keep `A short push reverts `TransferDeltaInsufficient`.`

Replace `Exact-in credits exactly `amountIn` when unbooked availability is sufficient. An exact-in excess push does not revert merely for being excess, and exact-in never refunds.` with this PRD sentence, unchanged:

The caller declares the bound. The vault processes only the amount needed for the requested output, and only from present unbooked tokens within that declaration. It refunds the unused part of the declaration to the caller. It does not refund unbooked tokens the caller did not declare. A shortfall is not filled from booked inventory. A pretransfer outside an atomic operation is the sender's responsibility.

Line 38 still contains: `An exact-in call whose declared amount differs from that surplus reverts.` Replace the whole line with this PRD sentence, unchanged:

Unsolicited transfers remain donor risk and can later count toward a declared bound. They are not refunded to a later caller merely because they are unbooked. This does not permit spending inventory already booked by a vault operation.

Leave lines 3, 34, and 56 unchanged.

### D2 — `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md`

Replace only the cited clause on each named line. Leave false-flag "pulls quoted used and refunds nothing" sentences. Those are pull paths, not the prepaid exact-input defect.

- Line 14 still says `refunds nothing (D28; FullSpread D19 exact-in push equality is replaced)`. Replace `Exact-input pretransfer credits exactly the requested `amountIn` when unbooked available covers it, leaves excess uncredited, and refunds nothing (D28; FullSpread D19 exact-in push equality is replaced).` with the shared exact-input sentence.
- Line 63 still says `never refunded, never a revert`. Replace `credits exactly `amountIn`, and leaves the rest uncredited (never refunded, never a revert)` with the shared exact-input sentence. Leave the historical-rule sentence that follows it.
- Line 113 still says ``exchangeIn` requires `actualIn == amountIn``. Replace that clause with the shared exact-input sentence. Replace `refunds this-call surplus to `msg.sender`` with: refunds only the unused part of `min(unbooked, declared maximum)` to `msg.sender`.
- Line 146 still says ``exchangeIn` requires `actualIn == amountIn``. Same two replacements as line 113.
- Line 172 still says `Extra unbooked above `amountIn` is not refunded and does not revert (D28).` Replace that sentence with the shared exact-input sentence. Leave `credit `min(unbooked, maxAmountIn)` and refund only `credit - used``.
- Lines 202–203. Line 202 still says `credits exactly `amountIn` and refunds nothing (excess stays uncredited)`. Replace `and refunds nothing (excess stays uncredited)` with the shared exact-input sentence. Leave the `Historical text:` clause. Line 203 still says `an excess exact-in push is neither refunded nor rejected`. Replace `an excess exact-in push is neither refunded nor rejected; exactly `amountIn` is credited and the excess stays uncredited on the vault.` with the shared exact-input sentence. Leave the `Historical text:` clause.

### D3 — `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.plan.md`

Do not rewrite the checked historical records at lines 65, 88, 117, 229, 251, 261, and 333.

Add this paragraph immediately after the execution-complete paragraph that ends at line 10, and before `## Objective`. Add no other note.

Current law (REQ-SEP-04, owner answer 2026-10-16): a prepaid exact-input call processes the declared amount only when present unbooked input covers it and does not refund tokens above that declaration. A difference between the declaration and the whole surplus does not by itself revert. A prepaid exact-output call refunds only `min(unbooked, declared maximum) - used`. Booked inventory does not fill a shortfall. Checked historical records in this file are not restated.

### D4 — `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md`

Line 21 still says: `Exact-in pretransfer credits exactly `amountIn` and refunds nothing.`

Replace that sentence with the shared exact-input sentence. Leave `Exact-out pretransfer refunds only `credit - used`.` and the false-flag sentence.

### D5 — `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md`

Line 45 still says: `Exact-in pretransfer never refunds.`

Replace that sentence with the shared exact-input sentence. Leave `claimed < U` surplus absorbed into `R` at sync, and leave `Pretransferred exact-out refunds only `credit - used`.`

### D6 — `docs/agent/INDEXEDEX_AGENT_LAW.md`

Line 422 still says: `Exact-in never refunds.` This file is not `AGENTS.md`, `CLAUDE.md`, or `SKILL.md`.

Replace `Exact-in never refunds.` with the shared exact-input sentence. Leave the EOA revert, `TransferDeltaInsufficient(claimed, 0)`, the declared-amount cap, and `False-flag exact-out pulls quoted used.`

### D7 — `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md`

Line 376 still says: `refunds nothing and leaves the excess uncredited.`

Replace `Exact-input pretransfer credits exactly the requested amount when at least that much unbooked input exists, refunds nothing and leaves the excess uncredited.` with the shared exact-input sentence. Leave the exact-output sentence on the same line.

### D8 — `contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_PRD.md`

Line 7 still says: `Exact-input share pretransfer burns the requested amount and refunds nothing.`

Line 152 still says: `Exact-input share pretransfer burns exactly `amountIn` and refunds nothing.`

Replace each of those two sentences with the shared exact-input sentence. Leave each line's exact-output refund sentence.

### D9 — `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md`

Line 159 still says: `Exact-input push processes exactly the declared amount and refunds nothing.`

Replace that sentence with the shared exact-input sentence. Leave the exact-output sentences on the same line.

### D10 — `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`

Line 419 still says: `Exact-in refunds nothing.`

Replace that bullet with the shared exact-input sentence. Leave `Absorb unclaimed surplus into the book at successful workflow completion.`

### D11 — `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md`

Line 214 still says: `Exact-in retains sleeve/residual assets and refunds nothing.`

Replace `and refunds nothing` with: `. The declared input is processed only when present unbooked input covers it. Tokens above the declaration are not refunded. A difference between the declaration and the whole surplus does not by itself revert. Booked inventory does not fill a shortfall`

Leave `Exact-in retains sleeve/residual assets`.

### D12 — `docs/plans/UNISWAP_V4_FULLSPREAD_ACCEPTANCE_MAP.md`

Line 48 still says: `EI refunds nothing`

Replace `EI refunds nothing` with: EI processes the declared input only when present unbooked input covers it and does not refund tokens above that declaration. A difference between the declaration and the whole surplus does not by itself revert. Booked inventory does not fill a shortfall.

Leave `push EO refunds only `min(unbooked,max)-used``.

### D13 — `docs/plans/UNISWAP_V4_CLOSED_FORM_CANDIDATE_VALIDATION_AGENT_PROMPT.md`

Line 278 still says: `exact-in refunds nothing`

Replace that bullet with the shared exact-input sentence. Leave `exact-output refunds only unused credited input`.

## Not in this plan

No production function is edited. Prepaid exact-output already refunds only the unused part of `min(unbooked, declared maximum)`. Prepaid exact-input already processes the declared amount and does not refund undeclared surplus. Those paths stay.

Do not add `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTarget.sol`, Slipstream, or `contracts/protocols/dexes/uniswap/v4`. Do not refund unbooked value above the declaration. Do not add a caller-attribution ledger.

I did not run Forge.
