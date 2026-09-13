# Failure remediation validation

All **4,255 distinct selected tests passed**, with **zero unresolved failures**. The affected conservation fuzz tests passed in all **18 native/decimal variants**, executing **385 cases** (configured runs plus one replay) without the former rejection filters. Fuzz run counts were not reduced.

The full roughly 30,000-test monorepo suite was not rerun. Validation covered the reported failure families and targeted shared-code regressions.

## Diagnosis and changes

- **Fuzz rejection:** 18-decimal-era thresholds rejected every nine-decimal DETF output. The four shared conservation tests now use `bound()` for funding and for partial burns sized against actual funded output. Every case asserts positive funding/output, exact debits and credits, and conservation.
- **Buffer accounting:** swap assertions expected the seeded physical buffer to disappear. They now verify that physical seed remains while the virtual balance grows in its proper units.
- **DETF API and product-law drift:** Balancer tests expected retired free-token bond splits, claim-token methods, configurable open gates, reserve-BPT bonding, and diamond-owned reserve LP. The tests now exercise funded NFT vesting, backed staking receipts, current selectors, protocol LP custody, mandatory primary gates, and reserve-swap fallback. These are test/fixture migrations to current funded product law; Balancer production behavior was not functionally refactored.
- **Decimal fixture errors:** WAD literals were used as native payments, and LP quantities were inferred from ERC20 metadata despite geometric supply scaling. Fixtures now fund real external liquidity in appropriate native units and use measured shares. Nested reserve seeds are sized from actual funded nested-token value so proportional payouts remain payable. The H9 donation burn uses its actual funded balance and requires a positive payout.
- **Composed deployment fixtures:** required funded companion packages, pricing arguments, and reserve seeds were missing. Fixtures now deploy through the production registry with real reserves. Security tests use a hostile external ERC20 inside a registered production SE route rather than mocks of the system under test.
- **Quad burn setup:** finite funded DETF was spread across every reserve pair before any individual burn gate could open. The setup now trades the selected redemption route, caps inputs using actual reserve balances, and verifies a primary burn removes the supplied DETF.
- **V4 residual-capital defect:** residuals of ten native units or less were skipped even when they could mint LP. The sweep now attempts all positive inputs and stops repeating unchanged balances. A pair deposit quoting zero SE shares is parked in the bound SE's backing only when a reverse quote bounds it below the value of ten native SE share units. The previously joinable four-unit residual and Orbital Pons cases pass against the final rebuilt artifacts.

## Final coverage

Counts below deduplicate repeated test cases. Later results replace earlier results for the same source, contract, and test signature.

| Family | Passing tests |
| --- | ---: |
| Mixed Buffer DETF | 378 |
| Single SE DETF | 1,030 |
| Multi-Vault Weighted DETF | 1,169 |
| Uniswap V4 DETF | 646 |
| Composed Stable DETF | 808 |
| Weighted buffer pools | 224 |
| **Total** | **4,255** |

The machine-readable results are in [final-validation.json](final-validation.json); compact totals and source-hash checks are in [final-audit.json](final-audit.json).

Acceptance logs:

- [Mixed Buffer matrix](mixed-buffer-matrix.log): 378 passed across 61 suites.
- [Single core and fuzz matrix](single-core-and-fuzz-matrix.log), followed by [Single adversarial and donation matrix](single-adversarial-donation-matrix.log): the H9 donation failure in the first run was corrected; all 480 tests in the follow-up passed.
- [Multi-Vault Weighted matrix](multi-weighted-matrix.log), followed by [complete nested follow-up](multi-nested-matrix-final.log): the four initial nested failures were corrected; all 18 nested suites passed afterward.
- [Composed Stable matrix](composed-stable-matrix.log): 808 passed across 75 suites.
- [Quad burn policy matrix](quad-burn-policy-matrix.log): all 54 variants passed.
- [Final regression matrix](final-regression-matrix.log): 820 passed across 31 suites, covering both weighted buffer decimal families, the native Single SE invariant suite, CP/Weighted product-law regressions, and all selected Orbital Pons smoke/product-law variants. This rerun uses the final rebuilt production artifacts.

Earlier round and trace logs intentionally retain intermediate failures for diagnosis. They are not the final status and must not be summed as unique test counts.

## Build and source checks

- [Production rebuild](formatted-production-build.log) completed before runtime tests, as required for FactoryServices that load creation bytecode through `vm.getCode`.
- All five routed V4 facets are below 24,576 runtime bytes; the largest is 19,308 bytes. [Artifact sizes and hashes](production-sizes.json) were checked against the final `out/` artifacts.
- All 93 remediation source files were formatted. [Whitespace check](whitespace-check.log) passed, and final source hashes have no drift from [changed-files.json](changed-files.json).
- [remediation.patch](remediation.patch) is measured against the snapshots in `before/`, isolating this remediation from pre-existing workspace edits. No commits or deployments were made.

## Reproduction

Run from the repository root, using the default hermetic profile and existing compiler settings:

```sh
forge build --offline contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/*Facet.sol
forge test --offline --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/**' -vv
forge test --offline --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**' -vv
forge test --offline --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/**' -vv
forge test --offline --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/**' -vv
forge test --offline --match-contract '^UniswapV4Detf_Quad.*Policy.*$' --match-test '^test_policy_burn_allowed_when_synthetic_below_burnThreshold' -vv
forge test --offline --match-contract '^(SingleStandardExchangeDETFInvariant|MixedLegWeightedBufferPool_B_.*|MultiPairStandardExchangeBufferPool_B_.*|UniswapV4Detf_Cp_Univ3Se_ProductLaw_P9_R18|UniswapV4Detf_Weighted_Univ3Se_ProductLaw|UniswapV4Detf_Orbital_Pons(Mix|V1Se|V2Se)(_ProductLaw)?(_B_P18_R[69])?)$' -vv
```

For only the rejected-input regression:

```sh
forge test --offline --match-contract '^(MultiVaultWeightedDetf|SingleStandardExchangeDETF)_Fuzz.*$' --match-test '^testFuzz_mintThenPartialBurn_conservation' -vv
```
