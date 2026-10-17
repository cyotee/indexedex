# Kimi K3 — plan draft: REQ-C06 caller check before pretransfer credit

- **Label:** Replacement-session plan draft, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No reviewers' notes were read. This is not `REMEDIATION_PRD.plan.md`; nothing was edited.
- **Date:** 2026-10-14.
- **Status:** DRAFT. Writing this plan does not authorize code, test, config, or script edits. A later session must be explicitly asked to implement it.
- **Controlling PRD:** `docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md` (re-read 2026-10-14; 98 lines). Where this draft conflicts with it, the PRD controls.
- **Remaining choice:** **None.** The PRD closes the site table (`:25-37`), the edit shape (`:39-51`), the exclusions (`:53-69`), and the acceptance set (`:71-78`). Every line below was spot-checked against current source this round. If an implementer believes a choice remains, stop and report rather than choosing.
- I did not run Forge.

## 0. Spot-check record (all re-read this round)

- The 21 measurement lines in the PRD's table (`:25-37`) match current source exactly: hookless `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:94,165`; Pons `UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:94,165`; V3 `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:102` (inside `executeZapInMintExactOut`); UniV2 `UniswapV2StandardExchangeOutTarget.sol:462,547,623,693,794,905,972`; Camelot `CamelotV2StandardExchangeOutTarget.sol:411,513,596,663,766`; Rocket `RocketPoolRETHStandardExchangeOutTarget.sol:60,82`; Lido `LidoWstETHStandardExchangeOutTarget.sol:64,85`. Every one currently assigns `_pretransferCredit` on a prepaid branch before the gate.
- **Imports:** the V3 delegate (`:7`) and both FullSpread OutExecuteTargets (`:18` each) already import `LocalCreditLib`. The UniV2, Camelot, Rocket, and Lido OutTargets do **not**; each gains exactly `import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";`.
- The leave-alone list (`:53-64`) was spot-checked against current source in the review round and matches.

## 1. Production edits (PRD `:39-51`, restated per site)

At every site except the V3 mint, insert one new guarded statement immediately before the credit-assignment line, never inside the later `if (pretransferred)` block:

```solidity
if (pretransferred) {
    LocalCreditLib.requirePretransferCaller(msg.sender);
}
```

- Use `if (prepaid) { … }` instead at hookless `:165` and Pons `:165` (those branches' flag is `prepaid`). Every other site uses `pretransferred`.
- Sites: hookless `:94`, `:165`; Pons `:94`, `:165`; UniV2 `:462`, `:547`, `:623`, `:693`, `:794`, `:905`, `:972`; Camelot `:411`, `:513`, `:596`, `:663`, `:766`; Rocket `:60`, `:82`; Lido `:64`, `:85`.
- Helpers `_requirePrepaidCredit`, `_secureTokenTransfer`, `_securePull`, `_secureSelfBurn` are not edited; their internal caller checks and credit comparisons stay (PRD `:49`).
- No quote, ceiling, refund, or settlement statement moves. The false-flag path gains nothing.

**V3 mint (`executeZapInMintExactOut`, PRD `:51`):** move the existing `LocalCreditLib.requirePretransferCaller(msg.sender);` out of the later `if (pretransferred)` block into a new `if (pretransferred) { … }` block placed after the `IERC20 token = IERC20(tokenIn);` line and before `uint256 credit = …` at `:102`. The later block keeps `if (amountIn > credit) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, credit);` and `pullAmount = credit;` and loses only the moved gate statement. No duplicate gate remains on this branch.

**Stop rule (PRD `:27`):** if any named line no longer assigns `_pretransferCredit`, stop and report that file and line; do not choose another site and do not proceed on that file.

## 2. Test homes — one per family, no choice, no new file

Each family's repaired-route assertions go into its existing production-proxy suite. All seven were verified this round to exist, deploy through the registry/package path, and already pin `ISecurePullErrors.EOAPretransferNotAllowed` on at least one route:

| Production file | Test file (existing; assertions are added here) |
| --- | --- |
| Hookless OutExecuteTarget | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ApexRecurrenceErrorOrder.t.sol` |
| Pons OutExecuteTarget | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol` |
| V3 OutExecutionDelegate | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol` |
| UniV2 OutTarget | `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol` |
| Camelot OutTarget | `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_SecRemediation.t.sol` |
| Rocket OutTarget | `test/foundry/spec/protocol/staking/rocket-pool/adversarial/Adversarial_RocketPoolRETH_P0.t.sol` |
| Lido OutTarget | `test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol` |

No new test file is created: every required assertion has one of these homes.

## 3. Exact assertions per family (PRD `:71-78`)

In each of the seven files, add cases on the family's repaired route(s) — for hookless and Pons that is both the mint and the direct-out branch; for V3 the exact-out mint; for UniV2 and Camelot the seven/five named branches (one representative per distinct helper path is acceptable per route shape: the pass-through token route, the self-share burn route, and the zap routes named at the listed lines — the implementer covers each listed line's branch); for Rocket and Lido the mint branch (`:60`/`:64`) and the asset→asset branch (`:82`/`:85`):

1. **Code-less true-flag, short credit:** fund nothing (or push less than the quote); call the route with the prepaid flag; `vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.EOAPretransferNotAllowed.selector))`; assert the caller's and vault's token/share balances are unchanged.
2. **Contract caller, short credit:** use the family's existing atomic pretransfer caller stub; push less than needed; expect the family's existing credit error with its exact arguments (e.g., `TransferDeltaInsufficient(used, credit)`); assert no tokens moved.
3. **False-flag code-less control:** fund the caller normally, call with the flag false, and assert the call does not revert `EOAPretransferNotAllowed` (success or an unrelated failure is acceptable only where the existing suite already pins one; do not weaken an existing pin).
4. **No bare `vm.expectRevert()`** anywhere: every new negative pins the selector and arguments. These directories are inside the REQ-03 scanner's roots; a bare expectation would fail that gate.

One family's pass does not close another (PRD `:78`). Existing tests are not weakened, renamed away, or edited to expect the credit error where the caller error is required.

## 4. Commands

Production sources are edited, so artifacts refresh before tests (per `docs/testing/ARTIFACT_BUILDS.md`). From the repository root, default hermetic profile, `via_ir` untouched:

```sh
python3 scripts/forge-artifacts.py plan \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol \
  contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol \
  contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol \
  contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol \
  contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ApexRecurrenceErrorOrder.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol \
  --test-root test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_SecRemediation.t.sol \
  --test-root test/foundry/spec/protocol/staking/rocket-pool/adversarial/Adversarial_RocketPoolRETH_P0.t.sol \
  --test-root test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol
python3 scripts/forge-artifacts.py test \
  <the same seven sources> \
  <the same seven test roots> \
  -- -vv
```

Then `scripts/apex_bare_expectrevert_scan.sh --check` — the seven edited files sit inside the scanner's roots; the run must not gain a site from this item (the new assertions are all pinned). Report the commands actually run, the toolchain, and every result. A present assertion is not a pass until that run is reported (PRD `:98`).

## 5. What not to do

- Do not edit EtherFi, Slipstream, or `contracts/protocols/dexes/uniswap/v4` (PRD `:85`).
- Do not edit the ten caller-first sites or the shared helpers' internal order (PRD `:53-64`, `:49`).
- Do not remove or reorder a credit comparison, quote, ceiling, refund, or settlement statement; do not add a `catch`; do not add the check to a false flag; no bare `expectRevert()`; no new test file.
- Do not proceed on a file whose named line drifted; stop and report (PRD `:27`).

## Done when

- All 21 sites carry the guarded caller check before the measurement (or the V3 mint's moved check), and the nine listed stop/leave-alone conditions hold.
- Each family's suite contains the three assertion shapes of §3 on its repaired routes, pinned to exact errors.
- The helper `plan`/`test` runs and the scanner `--check` are reported with actual results; no class of site remains unreported.

I did not run Forge.
