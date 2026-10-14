# Plan draft — REQ-C06 caller check before pretransfer credit (input, not final)

- **Date:** 2026-10-11. **Author:** Kimi K3, as review input. The coordinator owns the final `REMEDIATION_PRD.plan.md`; this draft is input to it.
- **Controlling document:** `docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md` (DRAFT, 2026-10-11), including the 2026-10-11 owner decision: a code-less pretransfer caller receives `EOAPretransferNotAllowed`, and the bytecode check runs before the balance or credit check.
- **Authorization:** Writing this draft does not authorize implementation. The PRD itself does not authorize editing code. A later session must be explicitly asked to implement and must report the commands it actually ran.
- **Blocking questions:** none. The owner decision fixes the order, the PRD names the sites and the reference implementation, and its search rule covers the additional same-shape branches identified below.

## 1. What the repair is

On every pretransfer branch that can currently revert for insufficient credit before the caller is authenticated, `LocalCreditLib.requirePretransferCaller` runs first; the existing credit or balance comparison then runs unchanged. The order to match already exists in the repository: the V3 exact-output withdrawal delegate authenticates the caller at `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:30-34` before its credit comparison, and `_secureTokenTransfer` authenticates before measuring availability at `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:866-872`. Only the early branches that bypass that order change. This is diagnostic order only: the call already reverts today; no credit check is removed, no quote math, input maximum, or settlement output check changes, and no catch is added.

## 2. The three known sites and where the check goes

1. `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-88` (`_executeQuotedSwapOut`). Inside the `if (pretransferred)` block, the caller check is placed before `uint256 credit = _pretransferCredit(tokenIn, maxAmountIn)`. The existing `quotedIn > credit` comparison and its `TransferDeltaInsufficient` revert stay, in the same position relative to the credit read.
2. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:100-104` (`_executeZapInMintExactOut`). Same placement: the caller check opens the `if (pretransferred)` block; the `amountIn > credit` comparison and revert remain.
3. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:100-104` (the Pons counterpart of site 2). Same placement. One family's edit does not stand in for the other's.

## 3. The required search, and what it finds from this review's prior reads

PRD repair 4 requires searching active production pretransfer paths for the same early credit revert. Two additional same-shape branches were already read in this review's earlier passes and are recorded here for the implementation session to confirm and treat identically (caller check first, credit comparison kept):

- `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:108-111` (`executeZapInMintExactOut`): the pretransfer shortfall comparison precedes `_secureTokenTransfer` at `:112`. This branch sits in the same file as the reference implementation. The PRD's non-goal protects the already-correct `executeZapOutWithdrawal` function's behavior from change; it cannot protect this branch, because the acceptance criteria require any additional active path found by the search to have the same order or be cited as already correct, and this one is not already correct.
- `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:159-165` (`_executeDirectOut`): `frame.credit` is measured at `:159`, the shortfall reverts at `:163`, and `_secureTokenTransfer` runs at `:165`. The Pons file's mirrored direct-out branch is checked at the same time.

If the session's search finds further active branches with the early credit revert, they receive the same placement. A branch that already authenticates before comparing is cited and left alone. Deprecated Slipstream is not reopened as a product: if its tree shows the same early revert, that is recorded in the implementation report and not rewritten here.

## 4. What does not change

- The credit and balance comparisons themselves. A contract caller allowed to pretransfer whose credit is short still reverts `TransferDeltaInsufficient`.
- No `pretransferred=false` path receives the caller check. A false-flag pull still measures the transfer, and a code-less caller on a false-flag route does not revert `EOAPretransferNotAllowed` merely for lacking bytecode.
- `_secureTokenTransfer`'s existing order is untouched, as is the withdrawal delegate's. Hookless and Pons settlement math is untouched; only check order on the named and search-found pretransfer branches.
- Ordinary redemption of the caller's own shares is not a pretransfer and is unaffected (this is not REQ-C02).

## 5. Tests — separate production proxies for V3 FullSpread, hookless, and Pons

For each of the three vaults, on its production registry-deployed proxy with no mocked vault, package, manager, registry, or fee oracle, and with one family's result never counted for another:

1. **Code-less short-credit caller.** A caller with no bytecode, holding pushed credit below the quoted input, reverts `EOAPretransferNotAllowed`. The credit error is not the one reached, and no tokens move. The caller is a fresh code-less address, not the test contract.
2. **Contract caller with short credit.** A bytecode-bearing caller with the same short credit still reverts `TransferDeltaInsufficient`, and no tokens move.
3. **Funded allowed contract caller.** A funded contract caller succeeds and spends no more than the input maximum.
4. **False-flag control.** A code-less caller on the false-flag route is not rejected as `EOAPretransferNotAllowed` merely for lacking bytecode.
5. Where a search-found branch (site group in §3) is exercised, the same two error-order assertions apply to that branch.

Test-maintenance note: the existing recurrence probes assert the old order and must be updated, not deleted. In particular `ApexRecurrenceErrorOrder.t.sol` in each of the three family trees currently expects the shortfall error for an underfunded code-less exact-output caller (e.g. the hookless file's `test_review_underfundedEoaExactOutObservesCreditError` at `:27-43`); after this repair that case must expect `EOAPretransferNotAllowed`, while the funded case that reaches the caller guard (`test_review_fundedEoaExactOutReachesCallerGuard`) remains valid as written.

## 6. Execution notes for the later implementation session

- Production edits first, then `forge build`, then `forge test` — FactoryServices read creation bytecode from `out/`. Use the documented artifact-refresh workflow. Never `new` a facet or package; no `via_ir`; do not kill long compiles.
- Report the commands actually run, the search results for §3 (including any Slipstream observation, recorded only), and any site left unchanged with the reason. Do not claim this draft was executed.

**Stop.**
