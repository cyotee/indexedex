# Plan draft — caller check before pretransfer credit

- **Status:** input draft only. The coordinator owns the final plan.
- **Controlling PRD:** `docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md`, including the 2026-10-11 owner decision.
- **Authorization:** Writing this draft does not authorize implementation. A later session must be explicitly asked to edit code.

## Order

On a pretransfer, call `LocalCreditLib.requirePretransferCaller` before the credit comparison. Then keep that comparison. A code-less caller gets `EOAPretransferNotAllowed` even when the credit is also short. A contract caller whose credit is short still gets `TransferDeltaInsufficient`. Do not remove the credit check. Do not add this check to a false-flag path. A false-flag pull still measures the transfer and does not revert `EOAPretransferNotAllowed` merely because the caller has no bytecode.

Match the order already in `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:30-34`: caller check, then credit comparison. Do not copy that delegate's burn or refund. Do not change `_secureTokenTransfer`. It already checks the caller before available balance. Do not change quote math, the input maximum, or the settlement output check.

## Three known sites

Place the check inside the existing pretransfer branch, before the short-credit revert, and leave the comparison in place.

- V3 FullSpread `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-83`. Before `quotedIn > credit` reverts `TransferDeltaInsufficient`.
- Hookless `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:100-101`. Before `amountIn > credit` reverts.
- Pons-family `UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:100-101`. Same placement. Closing V3 does not close these two.

## Search, including the second branch already visible

Search active production pretransfer paths for an insufficient-credit revert that runs before `requirePretransferCaller`. A path that already checks the caller first is cited and left alone.

The same early credit revert is already present in both families' direct-out branch, before `_secureTokenTransfer`:

- Hookless `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:163`
- Pons-family `UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:163`

On those branches, call `requirePretransferCaller` only when the prepaid flag is true, and call it before `used > frame.credit` reverts. Do not call it when the flag is false. Do not change the swap math around that branch.

Slipstream `SlipstreamStandardExchangeOutTarget.sol:178-183` already calls `requirePretransferCaller` before its credit comparison. Record that. Do not rewrite Slipstream. Do not restore it as a product.

## Tests

Use the production proxy. Do not mock the vault. One family does not close another. A test-contract caller is not the code-less assertion.

Separate tests for V3 FullSpread, hookless FullSpread, and Pons-family FullSpread:

- A code-less caller on a pretransfer exact-output route, with credit below the quoted input, reverts `EOAPretransferNotAllowed`. The credit error is not the one reached. No tokens move.
- A contract caller allowed to pretransfer, with credit below the quoted input, still reverts `TransferDeltaInsufficient`. No tokens move.
- A funded contract caller allowed by the rule succeeds and spends no more than the input maximum.
- A false-flag call by a code-less holder does not revert `EOAPretransferNotAllowed` merely because that holder has no bytecode.

## Done when

The named branches and the two direct-out branches check the caller before the credit comparison. The credit check remains. False-flag paths do not gain the check. Slipstream is recorded and not rewritten. The three family tests exist. This draft was not executed.
