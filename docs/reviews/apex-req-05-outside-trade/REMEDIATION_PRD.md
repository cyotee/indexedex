# Remediation PRD — REQ-05 outside-trade credit

- **Status:** DRAFT
- **Date:** 2026-10-17
- **ID:** REQ-05
- **Review target:** Outside-trade credit tests for V3 FullSpread, V4 hookless FullSpread, V4 Pons-family FullSpread, and the wings vault.
- **Inputs:** REQ-05 in `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`. Owner ruling, 2026-10-17: add the wings check and the held-token credit check to all four families. No separate implementation plan or audit report was supplied for this round.
- **Astra participation:** Substantive verification and requirements check. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored. Astra's wings-only scope is superseded by the owner ruling.
- **Grok:** `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **MiniMax M3:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. It does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Kimi K3:** Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **Runtime:** No Forge run. Source was read. Consensus is not proof.

Writing this PRD does not authorize implementation.

## Required outcome

Each supported family proves, after an outside pool trade, that the next credit is limited to tokens the vault holds. No production code changes.

## Owner ruling

On 2026-10-17 the owner rejected both a wings-only repair and a no-new-test close. Add the held-token credit check to V3 FullSpread, V4 hookless FullSpread, V4 Pons-family FullSpread, and the wings vault. One family does not close another. The deleted tree `contracts/protocols/dexes/uniswap/v4` is not this item.

## REQ-05-1 — Held-token credit after an outside trade

- **Severity:** Medium
- **File and line:**
  - V3: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadLocalBook.t.sol:68-75` and `:114-136` already has this sequence. Cite it. Do not add a second V3 test.
  - Hookless: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol:34-56`.
  - Pons: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol:37-59`.
  - Wings: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:26-40`.
- **Intended behavior:** An outside pool trade does not refresh the vault book. The next credit equals tokens the vault holds above that book. A request for one more token is rejected. `minted == preview` is not that proof.
- **Broken requirement or invariant:** Hookless, Pons, and wings check that the book did not change, then accept a deposit whose shares equal the vault's own preview. Hookless and Pons also reject an unfunded one-token pretransfer. None of those three shows that a known unbooked balance remains the only credit after the outside trade. Wings stops at preview equality.
- **Acceptance criteria:**
  - Keep each family's direct pool trade and unchanged-book assertions.
  - For hookless, Pons, and wings, after that trade transfer a fixed positive amount of one vault token to the vault. The amount is `7 ether` where the token has 18 decimals. If the family's fixture token does not have 18 decimals, use `7 * 10 ** decimals` for that token. Do not choose another amount.
  - Available credit is `token.balanceOf(vault) - vault.reserveOfToken(token)`. Assert it equals the fixed transfer plus any unbooked balance recorded before the transfer. It must not increase by the outside trade's pool movement.
  - Call the family's true-flag `exchangeIn` for `credit + 1` shares-in of that token, minimum zero, to the test caller. It must revert `ISecurePullErrors.TransferDeltaInsufficient(credit + 1, credit)`.
  - After the rejection, the vault token balance, booked reserve, and total supply are unchanged.
  - Do not treat `minted == preview` as this proof. The existing preview-echo line may stay, but it does not satisfy this item.
  - V3 LocalBook already performs this sequence, including the `7 ether` transfer and the same revert. Leave that file unchanged.
- **Non-goals:** Do not change production. Do not restore the deleted legacy V4 package. Do not reconstruct stored-total cases. Do not cite `UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol` as this proof. Do not add a `catch`. Do not change custody accounting.

## Dissent

MiniMax and Kimi said the existing preview-echo tests close the item. The owner ruling supersedes that. Astra limited the new test to wings. The owner extended the same check to all four families. V3 already has it, so the new tests are hookless, Pons, and wings.

## Unverified

This review did not run the tests. No production unearned-credit defect was demonstrated.
