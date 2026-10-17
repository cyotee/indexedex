# Remediation PRD — amount-out processing and caller refund

- **Status:** DRAFT. The owner answered on 2026-10-16. This file does not authorize an edit in this review session.
- **Date:** 2026-10-16
- **ID:** REQ-SEP-04
- **Review target:** Documentation and remaining production vaults. `contracts/protocols/dexes/uniswap/v4` is being deleted and is out of scope. Do not restore Slipstream.
- **Owner ruling:** "Vaults should only process the operation using only the amount needed to meet the requested amount out and refund the rest to the caller. The amount processed should only come from the unbooked amount." Both old README sentences are withdrawn. Booked inventory is not spent. A shortfall is not filled from booked inventory.
- **Astra participation:** Substantive first pass and substantive cross-review. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored.
- **Grok:** `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **MiniMax M3:** Labeled replacement `ses_ebdf718feffemWQNf7wuTpapqX`. It does not recall `ses_ec41255ceffeVhrySLQe8hwwMC`.
- **Kimi K3:** Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **Execution evidence:** No Forge run. Consensus is not proof.

Writing this PRD does not authorize code, test, or documentation edits.

## Owner answer, 2026-10-16

"The rest" is only the unused portion of the quantity this caller declared for this call. The vault does not know how every unbooked token arrived. It trusts the caller to bound the operation, to the extent that declaration is covered by present unbooked tokens. A caller may gather tokens from several sources into one declared deposit. A pretransfer made outside an atomic operation is that sender's responsibility. The existing EOA caller check remains the protection. Do not add a ledger that attributes resting unbooked tokens to a caller.

## Required outcome

A prepaid exact-output call processes the quote for the requested output, taken only from unbooked value and bounded by the caller's declared maximum. It refunds `min(unbooked, declared maximum) - used` to the caller. It does not refund unbooked value above that declaration.

A prepaid exact-input call processes the declared `amountIn`, taken only from unbooked value. That declaration is the bound. It does not refund unbooked value above `amountIn`. It does not revert merely because `amountIn` differs from the whole surplus.

A shortfall against the declaration is not filled from booked inventory. Do not change a vault path that already has this shape. Do not refund the entire unbooked remainder.

## Closed edit list

No executable code, signature, or test-expectation change. A path that already processes the declared input, or refunds only `min(unbooked, declared maximum) - used`, is not edited. If a named line no longer contains the cited sentence, stop and report. Do not choose a substitute.

The same meaning applies at every comment and document below. The declared input is processed only when present unbooked input covers it. Tokens above the declaration are not refunded. A difference between the declaration and the whole surplus does not by itself revert. Booked inventory does not fill a shortfall. Exact-output credit remains `min(unbooked, declared maximum)`, and only the unused part of that bounded credit is refunded to the caller.

### Comments

| ID | File | Lines |
| --- | --- | --- |
| C1 | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol` | 125–126, 136–137 |
| C2 | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol` | Blocks ending at 11, 24, 30, 36, 42, 48 |
| C3 | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol` | Blocks ending at 12, 21, 27, 33, 39, 45 |
| C4 | `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol` | Blocks ending at 11, 24, 30, 36, 42, 48 |
| C5 | `contracts/interfaces/detf/IDetf.sol` | 169, 238 |
| C6 | `contracts/interfaces/IRebasingClaimToken.sol` | 177, 188 |
| C7 | `contracts/interfaces/IStandardExchangeInMulti.sol` | 27 |
| C8 | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` | 56. Edit the Crane source and sync it. Do not change the signature. |
| C9 | `contracts/vaults/basic/BasicVaultCommon.sol` | 76 only. Leave the qualified surplus sentences at 17 and 69–70. |
| C10 | `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol` | 24–27 |
| C11 | `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol` | 55–57 |

### Documentation

In the Uniswap README, keep the measurement sentence in line 32. Replace the exact-in refund and equality sentences with: "The caller declares the bound. The vault processes only the amount needed for the requested output, and only from present unbooked tokens within that declaration. It refunds the unused part of the declaration to the caller. It does not refund unbooked tokens the caller did not declare. A shortfall is not filled from booked inventory. A pretransfer outside an atomic operation is the sender's responsibility."

Replace line 38 with: "Unsolicited transfers remain donor risk and can later count toward a declared bound. They are not refunded to a later caller merely because they are unbooked. This does not permit spending inventory already booked by a vault operation." Leave lines 3, 34, and 56 unchanged.

| ID | File | Lines |
| --- | --- | --- |
| D1 | `contracts/vaults/standard/exchange/protocols/uniswap/README.md` | 32, 38 |
| D2 | `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md` | 14, 63, 113, 146, 172, 202–203 |
| D3 | `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.plan.md` | Add one current-law note. Do not rewrite the checked historical records at 65, 88, 117, 229, 251, 261, and 333. |
| D4 | `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` | 21 |
| D5 | `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md` | 45 |
| D6 | `docs/agent/INDEXEDEX_AGENT_LAW.md` | 422. This is not `AGENTS.md`, `CLAUDE.md`, or `SKILL.md`. |
| D7 | `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md` | 376 |
| D8 | `contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_PRD.md` | 7, 152 |
| D9 | `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` | 159 |
| D10 | `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` | 419 |
| D11 | `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md` | 214 |
| D12 | `docs/plans/UNISWAP_V4_FULLSPREAD_ACCEPTANCE_MAP.md` | 48 |
| D13 | `docs/plans/UNISWAP_V4_CLOSED_FORM_CANDIDATE_VALIDATION_AGENT_PROMPT.md` | 278 |

## What is already known

- Prepaid exact-output paths already take the quote from unbooked value, cap the refund at the declared maximum, and do not fill a shortfall from booked inventory. That shape matches this answer. Do not remove the cap.
- Prepaid exact-input paths already process the declared `amountIn` from unbooked value and do not refund the undeclared surplus. That shape matches this answer.
- The README and the comment and document rows above still teach an unqualified never-refund or a surplus-equality revert. Those rows are the remaining edit. Dated audit, review, and research records are not rewritten.

## Non-goals

- Do not edit `contracts/protocols/dexes/uniswap/v4`.
- Do not restore Slipstream.
- Do not invent a caller-attribution ledger.
- Do not change lines 3 and 56 of the Uniswap README to satisfy this item.
- Do not implement either refund reading in this review session.

## Dissent

The owner answered the refund-cap question. Grok's site cross-review would edit only the README and would leave comments that say exact-input refunds nothing. This list includes those comments because they still teach an unqualified never-refund. MiniMax's "grep before deciding" step is rejected. Historical review records are not edit targets.
