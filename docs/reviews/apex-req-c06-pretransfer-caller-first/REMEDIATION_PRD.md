# Remediation PRD — caller check before pretransfer credit

- **Status:** DRAFT
- **Date:** 2026-10-11
- **ID:** REQ-C06
- **Severity:** Low
- **Owner decision:** 2026-10-11. A code-less pretransfer caller receives `EOAPretransferNotAllowed`. The bytecode check runs before the pretransfer balance or credit check.
- **Review target:** Current IndexedEx working tree, inspected 2026-10-11.
- **Inputs:** `docs/reviews/apex-stage2-remediation-confirmation-2026-10-11/REMEDIATION_PRD.md` REQ-C06; `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-86`; `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:866-872`.
- **Authorization:** Writing this PRD does not authorize editing code in this session. A later session must be explicitly asked to implement it.

## Required outcome

On a pretransfer, the caller is authenticated before the credit is measured. A code-less caller is rejected with `EOAPretransferNotAllowed` even when the pushed credit is also short. The credit check remains. It runs only after that caller check.

This is a diagnostic order. The call already reverts. It is not an authorization bypass, and it is not REQ-C02. Ordinary redemption of the caller's own shares is not a pretransfer and does not receive this check.

## What is wrong

`_secureTokenTransfer` already has the required order. On `pretransferred`, it calls `requirePretransferCaller` and only then compares available balance (`UniswapV3FullSpreadStandardExchangeVaultCommon.sol:866-872`).

The exact-output caller does not reach that function when credit is short. It compares the quote with credit and reverts `TransferDeltaInsufficient` first:

```81:86:contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol
if (pretransferred) {
    uint256 credit = _pretransferCredit(tokenIn, maxAmountIn);
    if (quotedIn > credit) revert ISecurePullErrors.TransferDeltaInsufficient(quotedIn, credit);
    pullAmount = credit;
}
uint256 providedAmountIn = _secureTokenTransfer(tokenIn, pullAmount, pretransferred);
```

A code-less caller with a short push therefore gets the credit error. The caller error is reached only when the credit was already sufficient.

The same early credit revert is in:

- `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:100-104`
- `UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:100-104`

Closing V3 does not close those two. The V3 exact-output withdrawal delegate already has the required order: `requirePretransferCaller`, then the credit comparison (`UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:30-34`). Match that order. Do not copy its burn or refund behavior into this item.

## Required repair

1. On every pretransfer branch that can revert for insufficient credit before the caller check, call `LocalCreditLib.requirePretransferCaller` first.
2. Then keep the existing credit or balance comparison. A contract caller who is allowed to pretransfer and whose credit is short still reverts `TransferDeltaInsufficient`. Do not remove that check.
3. Do not apply the caller check to `pretransferred=false`. A false-flag pull still measures the transfer.
4. Search active production pretransfer paths for the same early credit revert. The three files above are the known sites. A path that already checks the caller before the credit comparison is cited and left alone. Do not reopen deprecated Slipstream as a product. If that tree has the same early credit revert, record it and do not rewrite it here.
5. Do not add a catch. Do not change quote math, the input maximum, or the settlement output check.

## Acceptance criteria

- A code-less caller on a pretransfer exact-output route, with credit below the quoted input, reverts `EOAPretransferNotAllowed`. The credit error is not the one reached. No tokens move.
- The same assertion is separate for V3 FullSpread, hookless FullSpread, and Pons-family FullSpread. One family does not close another.
- A contract caller that is allowed to pretransfer, with credit below the quoted input, still reverts `TransferDeltaInsufficient`. No tokens move.
- A funded contract caller that is allowed by the rule still succeeds and spends no more than the input maximum.
- A false-flag call does not revert `EOAPretransferNotAllowed` merely because the caller has no bytecode.
- Any additional active path found by the search has the same order, or is cited as already correct.

## Non-goals

- Do not remove the credit check.
- Do not treat this as the ordinary-redemption repair in REQ-C02.
- Do not change `_secureTokenTransfer`'s existing order. It already checks the caller before available balance.
- Do not edit the V3 exact-output withdrawal delegate except to cite it as the order to match.
- Do not change hookless or Pons settlement math. Only the check order on the named pretransfer branch, unless the search finds another branch with the same early credit revert.
- Do not restore Slipstream.
- Do not describe a live call that depends on error order.
- Do not deploy or upgrade live instances.

## Verification

Implement only after a separate request. Tests use the production proxy. They do not mock the vault. A test-contract caller is not the code-less assertion. Report the commands actually run.
