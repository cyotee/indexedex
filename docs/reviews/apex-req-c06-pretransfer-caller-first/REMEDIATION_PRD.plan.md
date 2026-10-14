# Implementation plan — caller check before pretransfer credit

- **Date:** 2026-10-11
- **Status:** ready for a separately authorized implementation session
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md), including the 2026-10-11 owner decision.
- **This plan does not authorize code changes.** A later session must be explicitly asked to implement it.
- **Council input:** Grok, MiniMax M3, and Kimi K3 reported no blocking question. Astra asked whether the V3 delegate file is frozen or only `executeZapOutWithdrawal` is. The PRD settles that. Cite `executeZapOutWithdrawal` as the order to match and do not edit it. `executeZapInMintExactOut` in the same file has the early credit revert, so it gets the caller check. That is not a new owner decision.

## Order

On a pretransfer, call `LocalCreditLib.requirePretransferCaller` before the credit comparison. Then keep the comparison.

- A code-less caller gets `EOAPretransferNotAllowed` even when the credit is also short.
- A contract caller whose credit is short still gets `TransferDeltaInsufficient`.
- Do not remove the credit check.
- Do not add this check to a false-flag path.

Do not change `_secureTokenTransfer`. It already checks the caller before available balance. Do not change quote math, the input maximum, or the settlement output check.

## Step 1 — Three named branches

Place the caller check inside the existing pretransfer branch, before the short-credit revert.

- V3 FullSpread `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-83`, before `quotedIn > credit`.
- Hookless `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:100-101`, before `amountIn > credit`.
- Pons-family `UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:100-101`, same placement.

Leave the credit comparison and the `TransferDeltaInsufficient` revert in place.

## Step 2 — Same shape, already visible

These are the same early credit revert. Apply the same order. Do not treat them as a new product.

- V3 `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.executeZapInMintExactOut` at `:108-110`. Call `requirePretransferCaller` before `amountIn > credit`. Do not edit `executeZapOutWithdrawal` at `:30-34`. That function already has the required order.
- Hookless `_executeDirectOut` at `:163`. Call `requirePretransferCaller` only when the prepaid flag is true, and call it before `used > frame.credit`.
- The Pons mirror of that direct-out branch. Same placement.

Do not call the check when the flag is false. Do not change the swap or mint math around these branches.

## Step 3 — Search, then stop expanding

Search active production pretransfer paths for an insufficient-credit revert that runs before `requirePretransferCaller`. A path that already checks the caller first is cited and left alone.

Slipstream `SlipstreamStandardExchangeOutTarget.sol` already calls `requirePretransferCaller` before its credit comparison. Record that. Do not rewrite Slipstream. Do not restore it as a product.

## Step 4 — Tests

Use the production proxy. Do not mock the vault. One family does not close another. A test-contract caller is not the code-less assertion.

Separate tests for V3 FullSpread, hookless FullSpread, and Pons-family FullSpread:

- A code-less caller on a pretransfer exact-output route, with credit below the quoted input, reverts `EOAPretransferNotAllowed`. The credit error is not the one reached. No tokens move.
- A contract caller that may pretransfer, with credit below the quoted input, reverts `TransferDeltaInsufficient`. No tokens move.
- A funded contract caller that may pretransfer still succeeds and spends no more than the input maximum.
- A false-flag call by a code-less caller does not revert `EOAPretransferNotAllowed` merely because the caller has no bytecode.

If an existing probe expects the credit error first for a code-less short-credit caller, change that expectation to `EOAPretransferNotAllowed`. Do not delete the probe to hide the old order.

## Build and report

After the production edit, refresh artifacts with `python3 scripts/forge-artifacts.py` before `forge test`. Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`.

Run the three family suites. Report the commands actually run and any test that did not pass.

## Out of scope

- Removing the credit check.
- Ordinary redemption and REQ-C02.
- `_secureTokenTransfer`'s existing order.
- Burn and refund behavior in `executeZapOutWithdrawal`.
- Quote math, the input maximum, and the settlement output check.
- A Slipstream rewrite.
- Deployment or a live-instance upgrade.

## Done when

- Each named pretransfer branch, and each same-shape branch in Step 2, checks the caller before the credit comparison.
- The credit check remains for an allowed contract caller.
- A false-flag path does not gain this check.
- `executeZapOutWithdrawal` is unchanged.
- The three family tests have been run, with a code-less short-credit caller.

Stop after that report. Do not deploy.
