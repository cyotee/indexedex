# Astra — REQ-C06 replacement-session plan draft

This is an independent replacement-session plan draft, not continuity with `ses_ec412bcc2ffejKLo7nuoEAqbV0`; I do not recall that session. No other reviewers' notes were read for this draft. Controlling document: `docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md`, read in full. This is not `REMEDIATION_PRD.plan.md`. Writing this draft does not authorize implementation.

## 1. Evidence and fixed scope

The current source search confirms all **21 named measurement assignments at the PRD's exact lines**. The function bodies and downstream guards were inspected in this replacement session's source review; this plan pass rechecked the assignments and imports. The scope is seven production files, seven existing test files, no new production class, and no new test file. All required assertions have an existing production-proxy test home identified below; missing individual test cases are added to that home, not to a file selected during implementation.

Before a later authorized implementation changes anything, compare the unedited source against the entire table below. If **any named line no longer assigns `_pretransferCredit`**, stop and report the mismatch; do not select another site. Validate all original locations before inserting imports or statements, which necessarily shifts subsequent line numbers. After that preflight, use the checked function/branch identities while applying this single change set.

No edits to EtherFi, Slipstream, `contracts/protocols/dexes/uniswap/v4`, the ten caller-first sites, common custody helpers, quote/refund/settlement math, or shared test bases. Do not add a catch, unconditional caller check, facet split, self-call, or deployment change. Keep prior unrelated work intact. Source drift outside this closed task is not permission to expand it.

## 2. Production edits, in this order

The canonical import is `import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";`.

| Order | File | Current measurement lines | Exact edit | Import |
|---|---|---|---|---|
| P1 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol` | 94 mint; 165 direct-out | New `if (pretransferred)` check before 94; new `if (prepaid)` check before 165 | Already present at 18; do not add |
| P2 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol` | 94 mint; 165 direct-out | Same two insertions, independently in Pons | Already present at 18; do not add |
| P3 | `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol` | 102, `executeZapInMintExactOut` only | Guarded move specified below | Already present at 7; do not add |
| P4 | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol` | 462, 547, 623, 693, 794, 905, 972 | New `if (pretransferred)` check immediately before each of seven assignments | Absent; add canonical import once |
| P5 | `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol` | 411, 513, 596, 663, 766 | New `if (pretransferred)` check immediately before each of five assignments | Absent; add canonical import once |
| P6 | `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol` | 60 mint; 82 asset-to-asset | New `if (pretransferred)` check immediately before each assignment | Absent; add canonical import once |
| P7 | `contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol` | 64 mint; 85 asset-to-asset | New `if (pretransferred)` check immediately before each assignment | Absent; add canonical import once |

Every inserted guarded block contains exactly the canonical `LocalCreditLib.requirePretransferCaller(msg.sender)` call. The ternary assignment remains outside and after that block. Do not insert into the existing later pretransfer block: that would leave the measurement first.

### P1/P2 statement order

- Mint: keep zero-share validation; insert true-flag check; keep credit assignment; keep `_amountInForZapMint`; keep input ceiling; keep balance snapshot and later `_requirePrepaidCredit` call and pull assignment; retain all following delivery/refund/mint/sync statements.
- Direct-out: keep zero-output validation and frame/direction initialization; insert prepaid-only check; keep credit assignment; keep snapshot/plan; keep `used` extraction, maximum comparison and `_requirePrepaidCredit`; retain all settlement statements.
- Leave `_requirePrepaidCredit` **unchanged**, including its second caller check and existing short-credit comparison. Leave the common `_secureTokenTransfer` unchanged. Duplicate downstream checking is deliberate and not a discretionary cleanup.

### P3 guarded move

In `executeZapInMintExactOut`, move the existing check at 109 into a **new `if (pretransferred)` block after the `IERC20` conversion at 101 and before assignment at 102**. Keep zero-share validation before that conversion. Remove only the relocated check from the later block; retain its exact `amountIn > credit` error comparison and `pullAmount = credit`. Keep the quote, input ceiling, delivery, refund, mint and sync code unchanged. Do not edit the correctly ordered `executeZapOutWithdrawal` in this file. A preceding standalone check is prohibited: the later ternary does not guard it.

### P4–P7 order and comparisons

Add the check at each assignment boundary only. All preceding independent route/quote/input-ceiling validations stay where they are. All downstream transfer/self-burn/pull checks and refund-credit comparisons stay intact. In staking mint branches the check now precedes both measurement and reserve-adjusted pricing; retain Lido's false-flag stETH adjustment in its present place. Do not add a blanket function-entry gate, change a credit helper, or modify ordinary share-redemption branches that are not in the table.

## 3. Seven fixed test homes

Extend these **existing** files in order T1–T7. Do not create a second file or choose another suite during implementation. New C06 cases use the prefix `test_C06_`; retain existing unrelated assertions. Existing bare reverts in old unrelated tests do not justify adding, copying or using a bare `vm.expectRevert()` for C06.

| ID | Exact test file | Existing production-proxy evidence and C06 additions |
|---|---|---|
| T1 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ApexRecurrenceErrorOrder.t.sol` | Inherits hookless `Acceptance`; existing direct-out EOA/contract/error/false-flag cases at 29–118 call `vault.exchangeOut`. Retain these and add mint cases plus strengthened snapshots. |
| T2 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol` | Separately inherits Pons `Acceptance`; same existing direct-out controls. Add its own mint cases and snapshots; hookless results do not close Pons. |
| T3 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadExactOutputFill.t.sol` | Existing `_deployVault(pool)` and `vault.exchangeOut` calls use the production FullSpread package; preserve RC04 cases. Add a C06-funded share-book fixture and mint-route tests in this file. Keep its `QuietUnlessArmedInputToken` unarmed for C06. |
| T4 | `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_InOutInvariant.t.sol` | Existing `TestBase_UniswapV2StandardExchange_MultiPool`, `_getVault(PoolConfig.Balanced)` and `_seedVault` operate real vault proxies; existing Out tests cover all seven route identities. Add C06 cases for all seven routes. |
| T5 | `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2ZapOutMaxAmountIn.t.sol` | Existing manager-package TestBase and `deployVault` setup at 18–29; current Out tests assert actual proxy burns/payouts. Extend this fixture's cases to all five listed C06 routes; preserve its independent maximum tests. |
| T6 | `test/foundry/spec/protocol/staking/rocket-pool/adversarial/Adversarial_RocketPoolRETH_P0.t.sol` | Inherits `TestBase_RocketPoolRETHStandardExchange`; its base registers the manager package and casts `seOut` from `seVault`. Existing caller/error/atomic-caller controls provide a home for both Out branches. |
| T7 | `test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol` | Inherits `TestBase_LidoWstETHStandardExchange`; base registers the manager package and casts `seOut` from `seVault`. Existing EOA/contract and Out controls provide a home for both branches. |

Deployment evidence: staking bases register their packages at Rocket line 81 / Lido line 72 and expose `seOut` at 89 / 80; Camelot base registers its package at 45. The V2 MultiPool base deploys its three vaults at 66–68. Hookless Acceptance deploys its proxy at 57 and `_bootstrap` funds it via the production multi-in surface. Preserve those paths; never instantiate or mock a facet, delegate, registry or vault as the SUT. Tests call the proxy, not the V3 delegate directly.

### Fixed branch coverage, not a selection menu

- T1 and T2 each cover direct-out token-to-token and exact-output token-to-share mint, with both pool-token directions as parameterized cases.
- T3 covers token-to-share exact-output mint in both pool-token directions; it does not substitute the already-correct quoted-swap branch for mint coverage.
- T4 covers the seven assignments in order: token swap; LP-to-token pass-through withdrawal; LP-to-vault-share deposit; vault-share-to-LP withdrawal; vault-share-to-token withdrawal; token-to-vault-share zap deposit; token-to-LP pass-through deposit. Use the Balanced proxy and existing route fixtures, not unsupported route guesses.
- T5 covers its five assignments: token swap; LP-to-token pass-through withdrawal; LP-to-vault-share deposit; vault-share-to-LP withdrawal; vault-share-to-token withdrawal. Do not add tests for Camelot's explicitly unsupported token zap-in branches as C06 witnesses.
- T6 uses the supported WETH-to-SE-share mint and WETH-to-rETH asset conversion branches on its hermetic production proxy.
- T7 uses the supported WETH-to-SE-share mint and WETH-to-wstETH asset conversion branches on its hermetic production proxy. Existing native stETH rounding tests remain unchanged.

## 4. Exact assertion contract

For every branch above, add distinct C06 controls rather than a broad “any revert” test. Use supported positive-output fixtures with a nonempty share book where required, a valid deadline, and a maximum sufficient for the route's quote. Assert those fixture preconditions before execution. Do not let an earlier input-ceiling, empty-book, capacity or route rejection stand in for the credit comparison.

1. **Code-less true-flag caller:** assert caller bytecode length is zero; expect exactly `ISecurePullErrors.EOAPretransferNotAllowed.selector` on a short-credit case. Compare before/after input-token, output-token and vault-share balances for caller, recipient and vault, plus total share supply and relevant booked reserves: each must be equal. Capture the baseline immediately before the operation, not before a separate transfer used to prepare the fixture.
2. **Allowed contract true-flag caller:** assert the actual proxy caller has bytecode; expect full encoded `ISecurePullErrors.TransferDeltaInsufficient(required, available)` data, not an arbitrary selector from a preview failure. Compute the expected requirement from the fixture's pre-operation quote and the measured available credit under the existing route semantics. Assert the same unchanged balances, supply and books. Use the existing `AtomicPretransferCaller` for direct calls; use the Acceptance contract itself for the V4 nested-manager case below. Do not replace an EOA assertion with this test-contract case.
3. **False-flag code-less caller:** assert zero bytecode; use a funded caller and real approval where the route pulls; require a successful supported route, not merely an arbitrary revert other than the caller error. Assert returned input equals the fixture quote where the route promises quote parity, input debit equals returned input, returned input does not exceed maximum, and output matches the route's existing payout semantics. Exact-output mint has exact requested share issuance; preserve existing pass-through rounding/surplus semantics rather than changing production to force a different payout. No caller check is introduced on this flag.
4. **Funded allowed-contract control:** retain/add successful true-flag execution with returned input within maximum and exact reconciliation of input, refund, output and shares according to the unchanged route. This prevents removing the credit comparison or disabling the route from satisfying the rejection tests.
5. **Static order acceptance:** inspect the final diff at all 21 checked locations: guarded caller check precedes measurement and any consumer; the existing credit comparisons remain. Revert-only tests are not, by themselves, evidence that a non-reverting balance read moved after the caller check. Record the location-by-location check in the implementation result; no additional repair-site search is assigned.

### V4 mint admission is not optional

Hookless/Pons exact-output mint is admitted inside the enclosing PoolManager session, not the idle direct-out context. Their existing Acceptance `_nested` helper opens the real manager session and calls the real proxy; `_bootstrap` supplies the share book. Use that helper for the allowed-contract short-credit and funded mint controls. Its callback forwards failures without converting their error data. Do not mock the manager-unlock state, edit the production admission rule, or accept `InvalidRoute` instead of the contract-caller credit error.

For the **code-less true-flag mint control**, call the proxy from the code-less caller in the idle fixture: the new caller check must precede the credit-dependent mint admission quote and produce exactly `EOAPretransferNotAllowed`. For the **code-less false-flag mint control in that same idle context**, expect exactly the existing `IStandardExchangeErrors.InvalidRoute(tokenIn, address(vault))` data and unchanged balances, not `EOAPretransferNotAllowed`; this branch is intentionally unsupported idle, so do not invent idle success. In addition, require the funded false-flag mint to succeed through the existing real `_nested` contract-caller fixture. The direct-out false-flag EOA control remains a successful call in each family. This explicitly fixes the only route-specific exception to item 3, with no implementation-time choice of expectation.

T3 must initialize the V3 proxy's two-token share book through the existing production multi-in interface before mint tests; an external pool funded only for RC04 swaps is not sufficient. Add that fixture helper inside T3, retaining its current TestBase, rather than modifying shared bases or the RC04 setup for unrelated tests.

If a fixed fixture cannot reach its named comparison, stop and report the failing precondition. Do not weaken the expected error, use bare `vm.expectRevert()`, catch and accept a failure, or relocate the test to a different file. No numerical attack parameters or executable reproduction are specified by this plan.

## 5. Artifact refresh and tests — commands for the later authorized session only

Use the default hermetic profile, keep `via_ir` false, and retain configured source/test paths and `out/` / `cache_forge/`. Read actual `foundry.toml` before execution; in a new/empty worktree seed both artifact directories from a warm checkout per `CLAUDE.md`. Never remove caches or switch `FOUNDRY_TEST` to narrow selection. Allow long compiler runs to exit normally.

After the seven source and seven test edits, run the following from the repository root in **one Bash session**. These arrays close the inputs; no placeholder paths, extra family selection or discretionary new file is left to the implementer.

```bash
sources=(
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol
  contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol
  contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol
  contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol
  contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol
  contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol
)
test_args=(
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ApexRecurrenceErrorOrder.t.sol
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadExactOutputFill.t.sol
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_InOutInvariant.t.sol
  --test-root test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2ZapOutMaxAmountIn.t.sol
  --test-root test/foundry/spec/protocol/staking/rocket-pool/adversarial/Adversarial_RocketPoolRETH_P0.t.sol
  --test-root test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol
)
python3 scripts/forge-artifacts.py plan "${sources[@]}" "${test_args[@]}" &&
python3 scripts/forge-artifacts.py test "${sources[@]}" "${test_args[@]}" -- -vv
```

The repository's `docs/testing/ARTIFACT_BUILDS.md:5–24` specifies this multi-source/repeated-test-root workflow. `test` refreshes concrete dependent runtime artifacts with a targeted build **before** executing tests; a failed build stops testing. Run whole selected files, not only the new test prefix, so existing RC04/maximum/caller behavior stays covered. Even the helper's `plan` subcommand invokes Forge configuration internally; neither command was run in this review.

Stop/report a failed build, missing artifact/import, failing fixed assertion, or changed excluded file. Do not patch excluded source, alter compiler settings, weaken tests, or treat an unrelated failure as a pass. The result must distinguish commands actually run from commands merely planned, and identify any pre-existing failures without claiming acceptance.

## 6. Final closure check

- Verify exactly 20 new guarded insertions plus the one V3 guarded move; four production import additions, no duplicate imports in the three already importing targets.
- Verify all 21 assignments and credit comparisons remain, and the V3 later block contains its comparison/pull assignment but not the moved caller check.
- Verify no changes to the ten already caller-first functions or excluded trees; the V3 withdrawal function is unchanged even though its file contains the mint edit.
- Verify exactly the seven named test homes carry the C06 additions; no bare expected reverts, no mocked SUT and no new production/test-base deployment shortcut.
- Report source-order evidence and per-family test outcomes separately. Passing tests alone do not prove the source-order invariant, and a present assertion is not an executed pass.

## Review limits

The selected seven test files and relevant deployment/test-base evidence were read. Other test candidates were searched only to select these concrete homes; none is an alternative implementation target. A root-level glob initially encountered unrelated dangling dependency/skill links; scoped searches under `test/foundry` succeeded. One broad test glob hit its result cap and was narrowed to the actual family directories. No missing supplied input was encountered. The assigned output was absent before this write.

No delegation, shell execution, code implementation, tests or deployments occurred. Only this Markdown draft was created. Shared guidance and the artifact workflow were read directly; no skill tool was used. Runtime feasibility, compiled sizes and acceptance results remain unexecuted evidence, not promises of passing tests.

I did not run Forge.
