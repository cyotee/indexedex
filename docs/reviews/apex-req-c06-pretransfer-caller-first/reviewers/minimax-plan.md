# Implementation plan draft — REQ-C06 pretransfer caller check before credit comparison

- **Date:** 2026-10-11
- **Reviewer:** MiniMax M3
- **Controlling PRD:** `docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md` (DRAFT, 2026-10-11 owner decision included).
- **Status of this file:** DRAFT plan input. The coordinator owns the final `REMEDIATION_PRD.plan.md`. This draft does not authorize editing code in this session. A later session must be explicitly asked to implement it.
- **Method:** Source re-read at each cited line. No build, test, or shell.

This draft follows the 2026-10-11 owner decision: `LocalCreditLib.requirePretransferCaller` runs before the pretransfer credit comparison. The credit check stays; it runs only after the caller check. False-flag (`pretransferred = false`) paths are not given this check. The V3 exact-output withdrawal delegate at `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:30-34` is the reference order to match and is left alone. Slipstream is not reopened.

## 1. The three known sites and the order to install

For each of the three sites below, the early credit revert is currently placed *before* the caller check. The repair moves the caller check to the top of the `if (pretransferred)` block and keeps the credit revert where it is.

| Site | Current order | Repaired order |
| --- | --- | --- |
| `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-86` (exact-output swap path on V3 FullSpread) | `:81` enters the pretransfer block, `:82` computes credit, `:83` reverts `TransferDeltaInsufficient` if short, then `:84` sets `pullAmount = credit`, then `:86` calls `_secureTokenTransfer`. | Inside the `if (pretransferred)` block, the first statement is `LocalCreditLib.requirePretransferCaller(msg.sender);`. Then keep `:82` (credit computation), `:83` (short-credit revert), `:84` (`pullAmount = credit`), and `:86` (`_secureTokenTransfer`). The early credit revert at `:83` stays; it now runs only after the caller check. |
| `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:100-104` (exact-out mint on V4 hookless FullSpread) | `:100` enters the pretransfer block, `:101` reverts `TransferDeltaInsufficient` if short, `:102` sets `pullAmount = credit`, then `:104` calls `_secureTokenTransfer`. | Inside the `if (pretransferred)` block, the first statement is `LocalCreditLib.requirePretransferCaller(msg.sender);`. Then keep `:101` (short-credit revert), `:102` (`pullAmount = credit`), `:104` (`_secureTokenTransfer`). |
| `UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:100-104` (exact-out mint on V4 Pons-family FullSpread) | `:100` enters the pretransfer block, `:101` reverts `TransferDeltaInsufficient` if short, `:102` sets `pullAmount = credit`, then `:104` calls `_secureTokenTransfer`. | Inside the `if (pretransferred)` block, the first statement is `LocalCreditLib.requirePretransferCaller(msg.sender);`. Then keep `:101` (short-credit revert), `:102` (`pullAmount = credit`), `:104` (`_secureTokenTransfer`). |

The reference order to match is `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:30-34`: `requirePretransferCaller` at `:31` before the `_pretransferCredit` and short-credit revert at `:32-34`. The OutExecuteTarget above should look like the delegate at the pretransfer block: caller check, credit compute, credit compare, set `pullAmount`, then the existing pull.

## 2. False-flag path is not given this check

The three sites above place the new `LocalCreditLib.requirePretransferCaller(msg.sender)` *inside* their `if (pretransferred) { ... }` blocks. The `else`/`!pretransferred` branch continues to measure the transfer via `_secureTokenTransfer`'s `safeTransferFrom(msg.sender, address(this), amountIn)` path at `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:866-876`, which does not require bytecode on the caller. A code-less caller on `pretransferred = false` reaches the ordinary pull, which is unchanged by this item.

Repair 4 in the PRD makes this explicit: "Do not apply the caller check to `pretransferred=false`. A false-flag pull still measures the transfer." Do not place the caller check outside the `if (pretransferred)` block.

## 3. Search for other active early-credit reverts

The PRD's Repair 5 requires an active search of pretransfer paths for the same pattern. A path that already has `requirePretransferCaller` before its credit comparison is cited and left alone. A path that does not have the early credit revert at all is also left alone. The PRD names three files as the known sites; the implementer must search further.

The pattern to search for is any production source file that contains both:
- An `if (pretransferred) { ... }` block (or any equivalent guard such as `if (pretransfer_)` or `if (prePaid)`), AND
- Inside that block, a revert with `ISecurePullErrors.TransferDeltaInsufficient` (or any contract-specific short-credit revert with a similar signature) *before* a `LocalCreditLib.requirePretransferCaller(msg.sender)` call.

Search roots for this round, derived from the PRD scope and the Round-2 confirmation report:
- `contracts/vaults/standard/exchange/protocols/uniswap/` (V3 FullSpread, V4 hookless FullSpread, V4 Pons-family FullSpread, V4 upperLowerWings, and any other FullSpread variants in this tree).
- `contracts/protocols/dexes/uniswap/v4/` (legacy V4, hookless, Pons-family, FullSpread, Wings-adjacent). Per the PRD's Non-goals, the V4 paths named at `:100-104` are the known hookless/Pons sites; legacy V4 exact-output may be a fourth site or may already be correct — the implementer must verify by reading the active path, not by search count alone.
- `contracts/vaults/standard/erc4626/` (ReceiptBackedERC4626Target's adapter if its `redeem`/`withdraw` paths have a pretransfer branch).
- `contracts/protocols/lending/aave/v3.6/` and `aave/cross-version/` (Aave Stata and Cross-Version Loop; check the active `redeem`/`withdraw` paths that take a `pretransferred`-like flag).
- `contracts/protocols/staking/` for SY adapters that take a pretransfer flag.

The search must not include `contracts/protocols/dexes/aerodrome/slipstream/` or any file in the deprecated Slipstream tree. Slipstream is named DEPRECATED in the project's family law; the implementer records whether the Slipstream tree contains the same early credit revert and does not edit it. Recording it satisfies Repair 5's Slipstream non-rewrite directive. Recording it as "yes, present, not edited" is sufficient. Recording it as "no, absent" is also sufficient. The implementer does not modify Slipstream source under this item.

For each additional path that the search finds with the early credit revert:
- If `requirePretransferCaller` is already called before the credit revert, the file is cited and left alone.
- If `requirePretransferCaller` is not called before the credit revert, the implementer applies the same Repair 1 to that site: insert `LocalCreditLib.requirePretransferCaller(msg.sender);` as the first statement inside the `if (pretransferred)` block.

The PRD's "Do not change hookless or Pons settlement math" applies: only the check order on the named pretransfer branch, unless the search finds another branch with the same early credit revert. Do not rewrite any settlement math, deposit math, mint math, or quote math as part of this item.

## 4. Production-proxy tests

Three separate production-proxy tests are required. Each runs on the production proxy through the registry deploy path. None mocks the vault, the package, the manager, the registry, the fee oracle, the pool, or `pool.swap`. A test-contract caller is not the code-less assertion.

The four assertions per family are:

1. **Code-less short-credit caller reverts `EOAPretransferNotAllowed`.** A code-less EOA (no bytecode) sends a pretransfer exact-output call. The pushed credit is below the quoted input. The transaction reverts with `ISecurePullErrors.EOAPretransferNotAllowed`. The credit error (`TransferDeltaInsufficient`) is not the one reached. No tokens move. The vault's other state is unchanged.

2. **Contract short-credit caller reverts `TransferDeltaInsufficient`.** A contract caller (has bytecode) sends a pretransfer exact-output call. The pushed credit is below the quoted input. The transaction reverts with `ISecurePullErrors.TransferDeltaInsufficient`. No tokens move.

3. **Funded contract caller succeeds.** A contract caller sends a pretransfer exact-output call. The pushed credit meets the quoted input. The swap executes. The recipient receives the requested output. The caller spends no more than the input maximum.

4. **False-flag code-less caller does not revert `EOAPretransferNotAllowed`.** A code-less EOA sends `pretransferred = false` exact-output call. The transaction reaches the ordinary pull, not the caller check. The `EOAPretransferNotAllowed` revert is not the one reached; if the pull is short or fails for another reason, that other error is the one reached. This assertion exists to lock in the Repair 4 rule that the caller check is not applied to false-flag.

These four assertions are repeated for each of:

- V3 FullSpread production proxy (the `OutExecuteTarget` facet on the V3 FullSpread package).
- V4 hookless FullSpread production proxy (the `OutExecuteTarget` facet on the V4 hookless FullSpread package).
- V4 Pons-family FullSpread production proxy (the `OutExecuteTarget` facet on the V4 Pons-family FullSpread package).

One family's test does not close another. The three production-proxy tests are independent and each runs through its own TestBase and registry path. A test that mocks the SUT or the pool swap is not a pass.

If the search finds additional pretransfer paths that need the same fix, those paths get their own four-assertion test, separate from the three named above.

## 5. What stays the same

- The V3 exact-output withdrawal delegate at `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:30-34`. The order already matches (`requirePretransferCaller` at `:31` before the credit check at `:33-34`). Cite and leave alone.
- `_secureTokenTransfer` at `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:866-876`. Its order already has `LocalCreditLib.requirePretransferCaller(msg.sender)` at `:867` before the available-balance comparison. Cite and leave alone.
- The credit check at the three sites. The `TransferDeltaInsufficient` revert stays; only its position relative to the caller check moves.
- False-flag paths (`pretransferred = false`) at the three sites. The check is not added there. The pull measures the transfer as it does today.
- Quote math, input maximum, settlement output check, refund helper, _syncVaultReserves, and any other surrounding logic. Not touched.
- Hookless, Pons-family, and Wings settlement math. The repair only changes the order of checks inside the named pretransfer branch.
- Slipstream (Aerodrome). DEPRECATED. Recorded, not rewritten.
- Bond, threshold, or vesting economics. Not redesigned.
- No new `catch` is added. No translation of errors.
- No live-instance migration, deployment, or upgrade.

## 6. Implementation order

1. **Source.** For each of the three sites above, insert `LocalCreditLib.requirePretransferCaller(msg.sender);` as the first statement inside the `if (pretransferred) { ... }` block. The credit check that follows stays. Compile.
2. **Search.** Search the active production pretransfer paths for the same early-credit-revert pattern. Record results in the implementation report. Apply Repair 1 to any additional site that has the pattern but no caller check; cite and leave alone any site that already has the caller check. Record Slipstream as "yes, present, not edited" or "no, absent" without modifying Slipstream source.
3. **Tests.** Add the three production-proxy test suites (V3 FullSpread, hookless FullSpread, Pons-family FullSpread), each with the four assertions above. Use the existing TestBase and registry deploy path. Do not mock the SUT or the pool swap.
4. **Verification.** Report the commands actually run. A test that uses a test-contract caller for the code-less assertion is not a pass.

## 7. Authorization

Writing this plan does not authorize implementation. A later session must be explicitly asked to implement it. The implementer must report the commands actually run, the search results, and any test that did not pass. Do not claim this draft was executed. Do not deploy, migrate, or upgrade live instances. Do not describe a live call that depends on error order.

**STOP.**