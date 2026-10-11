# Remaining-errors follow-up — 2026-10-10

## Subsequent resolution

The 17 cases deferred during this pass were subsequently authorized, fixed, and verified. See [the Balancer DETF fix report](BALANCER_DETF_REMAINING_ERRORS_FIXES_2026-10-10.md). The scope and counts below describe the completed third pass.

## Scope and status

The owner's new list contains 32 failing test cases: 15 active cases and the same 17 Balancer-hosted DETF cases previously deferred. The active cases were reproduced before changes: 15 failures and 3 passing sibling cases across 9 suites. All **15 active failures are fixed**. The complete affected suites pass: **301 tests, 0 failures, 9 suites**.

No production changes are required by the three diagnosed active groups. Five test source files are changed. Exact quote/execution equality remains required.

## R24-A: buffered output reference rounding — 5 cases

File: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_TokenCount.t.sol`.

- N2–N5: `test_count_raw_donation_prices_live_book_and_becomes_booked` (4 cases).
- N2: `test_count_shared_book_matches_reference_after_cross_pair_swap` (1 case).

The reference compared StableMath's rated output budget directly with native tokens paid out. The final token is buffered through an ERC4626 Standard Exchange. Production converts the rated budget into whole SE share units, rounding down, then redeems those shares. The omitted conversion accounts for the one-unit differences. N3–N5 cross-pair reference cases target a raw output and were already passing.

Correction: independently convert the StableMath budget using the configured rate and share decimals, then use the SE redemption preview. Both tests additionally execute the swap and assert exact recipient balance changes against this reference. The donation test retains its consumed-funding rejection. No tolerance was introduced.

Production reference: `UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib._outputBudget`.

## R24-B: residual sweep expectations after R18 — 3 cases

Files:

- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol`.
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol`.

The tests still expected a zero-quote proportional join to execute and revert. The completed R18 implementation checks the complete route and tries the single-asset alternative. A positive SE deposit quote alone does not prove that the complete hook join can mint LP.

- The 5-ether RC06 case can deploy via the single-asset fallback. The before trace shows a quote and actual mint of exactly **2,438,199,280,572,434,367 LP units**. The renamed `test_RC06_nonzeroPreview_usesSingleAssetFallback` requires that fallback, exact quoted LP delivery into NFT custody, local reserve accounting, no new user entitlement or caller payout, and cleared allowances.
- The small-amount fuzz and rehearsal cases retain and book custody when the SE quote is zero or both complete join quotes return zero. They now require success, full booked custody, unchanged LP when retained, and deployment when mintable. Every nonzero remainder is checked for actual unmintability; the old ten-unit exemption is removed. Reverting previews are no longer classified as zero quotes.
- The independent RC06 preview-failure test continues to require atomic reversion and unchanged balances.

Production reference: `UniswapV4DetfCommon._tryJoinResidual` and `_entryJoinResidualAtomic`.

## R24-C: implementation metadata in Target ABIs — 7 cases

Affected leaf suites: V3 `Adversarial`, `F6Diagnostic`, and `Delivery`. Assertions live in `StandardExchangeReleaseBehavior.sol` and `StandardExchangeFullSpreadAdversarialBehavior.sol`.

The Target ABI includes the immutable getter `UNISWAP_V3_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE()`. It is deliberately absent from the proxy's declared facet functions. Vault-held redemption reads this binding directly from the installed input facet implementation. The tests incorrectly required every implementation ABI selector to be a vault selector.

Correction: classify only that exact V3 getter as implementation metadata. Assert that it is absent on the proxy, callable on the installed input implementation, ABI-correct, and points to deployed code. Continue requiring every other Target selector to be installed and declared by the expected facet. No production selector was added.

Production references: `UniswapV3FullSpreadStandardExchangeVaultInFacet.facetFuncs` and `UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget._redeemVaultHeld`.

## Still deferred — 17 cases

Owner direction and DETF alignment D60 exclude functional changes to Balancer-hosted DETFs. The newer authorization for all Balancer SE vaults did not change that DETF exclusion.

| Family / test group | Cases | Prior tracking |
|---|---:|---|
| MixedBuffer stable DETF invalid exact-out route, base + native matrix | 2 | R02 |
| MultiVault weighted DETF invalid exact-out route, base + eight decimal rows | 9 | R02 |
| ComposedStable common exchange-in uninitialized preview | 1 | R02 |
| ComposedStable common exchange-out invalid/uninitialized previews | 3 | R02 |
| ComposedStable common exchange-out execution error precedence | 2 | R16 |

These tests have not been modified or revalidated in this follow-up. Their disposition remains documented in [the earlier diagnosis](ERRORS_DIAGNOSIS_2026-10-09.md).

## Evidence

[Durable per-test evidence](ERRORS_THIRD_PASS_EVIDENCE_2026-10-10.json) maps all 15 baseline failures to passing tests and records commands, log hashes, changed-source hashes, and every test result. All 11 fuzz tests pass with 128 configured runs; the residual fuzz test reports 129 executions including its retained counterexample.

- Baseline: `.scratch/errors-third-pass-2026-10-10/before.log` and `before-command.json`.
- Full affected-suite validation: `.scratch/errors-third-pass-2026-10-10/after.log` and `after-command.json` — 301 passes / 0 failures.
- Before-source snapshots and change manifest: `.scratch/errors-third-pass-2026-10-10/sources-before/` and `changes.json`.
- Isolated change diff: `.scratch/errors-third-pass-2026-10-10/changes.diff`.

Validation uses the default profile, the artifact-first runner, two test threads, 128 fuzz runs, and one Forge writer. The initial sandbox run crashed in macOS system configuration; the baseline was rerun successfully outside the sandbox. No commit, push, or deployment was requested.
