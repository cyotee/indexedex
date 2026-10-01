# V4 FullSpread — finite removal and PRD deprecation manifest

Date: 2026-09-27. Status: specified, **not executed**. Authority: proportional zap-in PRD D24/D31 and §3.1; [implementation plan](UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md).

This is a finite file list, not a recursive parent-directory deletion instruction. Both new family subtrees are unconditional exclusions. Capture the actual pre-removal source revision and preserve historical contents before applying the list. Re-enumerate at execution time to detect drift; unexpected files require explicit disposition, not automatic deletion.

## A. Older protocol-tree vault — delete 44 Solidity files after gate

Root: `contracts/protocols/dexes/uniswap/v4/`. All paths below are relative to this root.

```text
IUniswapV4StandardExchangeDFPkg.sol
UniswapV4_Component_FactoryService.sol
UniswapV4PoolKeyAwareRepo.sol
UniswapV4PoolManagerAwareRepo.sol
UniswapV4PositionRepo.sol
UniswapV4QuoteService.sol
UniswapV4StandardExchangeCommon.sol
UniswapV4StandardExchangeDFPkg.sol
UniswapV4StandardExchangeInBase.sol
UniswapV4StandardExchangeInExecutionDelegate.sol
UniswapV4StandardExchangeInFacet.sol
UniswapV4StandardExchangeInMultiFacet.sol
UniswapV4StandardExchangeInMultiQueryFacet.sol
UniswapV4StandardExchangeInMultiQueryTarget.sol
UniswapV4StandardExchangeInMultiTarget.sol
UniswapV4StandardExchangeInQueryFacet.sol
UniswapV4StandardExchangeInQueryTarget.sol
UniswapV4StandardExchangeInTarget.sol
UniswapV4StandardExchangeLiquidReserveFacet.sol
UniswapV4StandardExchangeLiquidReserveTarget.sol
UniswapV4StandardExchangeOutBase.sol
UniswapV4StandardExchangeOutExecuteTarget.sol
UniswapV4StandardExchangeOutExecutionDelegate.sol
UniswapV4StandardExchangeOutFacet.sol
UniswapV4StandardExchangeOutMultiFacet.sol
UniswapV4StandardExchangeOutMultiQueryFacet.sol
UniswapV4StandardExchangeOutMultiQueryTarget.sol
UniswapV4StandardExchangeOutMultiTarget.sol
UniswapV4StandardExchangeOutQueryFacet.sol
UniswapV4StandardExchangeOutQueryTarget.sol
UniswapV4StandardExchangeOutTarget.sol
UniswapV4StandardExchangePositionImportFacet.sol
UniswapV4StandardExchangePositionImportTarget.sol
interfaces/IUniswapV4StandardExchangeLiquidReserve.sol
test/bases/TestBase_UniswapV4StandardExchange.sol
test/bases/TestBase_UniswapV4StandardExchange_Decimals.sol
test/bases/TestBase_UniswapV4StandardExchange_H6.sol
test/bases/TestBase_UniswapV4StandardExchange_H9.sol
test/bases/TestBase_UniswapV4StandardExchange_P6_R9.sol
test/bases/TestBase_UniswapV4StandardExchange_P6_R18.sol
test/bases/TestBase_UniswapV4StandardExchange_P9_R6.sol
test/bases/TestBase_UniswapV4StandardExchange_P9_R18.sol
test/bases/TestBase_UniswapV4StandardExchange_P18_R6.sol
test/bases/TestBase_UniswapV4StandardExchange_P18_R9.sol
```

Replace functionality with the family files specified in the plan. Port tests and all still-needed generic behavior before deletion. No generic V4 core contract lives in this list; Crane's core is outside this root.

## B. Unsegmented FullSpread vault — delete 36 Solidity files after gate

Root: `contracts/vaults/standard/exchange/protocols/uniswap/v4/`.

```text
IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol
UniswapV4FullSpreadClosedFormCandidate.sol
UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.sol
UniswapV4FullSpreadStandardExchangeVaultCommon.sol
UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol
UniswapV4FullSpreadStandardExchangeVaultInBase.sol
UniswapV4FullSpreadStandardExchangeVaultInExecutionDelegate.sol
UniswapV4FullSpreadStandardExchangeVaultInFacet.sol
UniswapV4FullSpreadStandardExchangeVaultInMultiFacet.sol
UniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet.sol
UniswapV4FullSpreadStandardExchangeVaultInMultiQueryTarget.sol
UniswapV4FullSpreadStandardExchangeVaultInMultiTarget.sol
UniswapV4FullSpreadStandardExchangeVaultInQueryFacet.sol
UniswapV4FullSpreadStandardExchangeVaultInQueryTarget.sol
UniswapV4FullSpreadStandardExchangeVaultInTarget.sol
UniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet.sol
UniswapV4FullSpreadStandardExchangeVaultLiquidReserveTarget.sol
UniswapV4FullSpreadStandardExchangeVaultOutBase.sol
UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol
UniswapV4FullSpreadStandardExchangeVaultOutExecutionDelegate.sol
UniswapV4FullSpreadStandardExchangeVaultOutFacet.sol
UniswapV4FullSpreadStandardExchangeVaultOutMultiFacet.sol
UniswapV4FullSpreadStandardExchangeVaultOutMultiQueryFacet.sol
UniswapV4FullSpreadStandardExchangeVaultOutMultiQueryTarget.sol
UniswapV4FullSpreadStandardExchangeVaultOutMultiTarget.sol
UniswapV4FullSpreadStandardExchangeVaultOutQueryFacet.sol
UniswapV4FullSpreadStandardExchangeVaultOutQueryTarget.sol
UniswapV4FullSpreadStandardExchangeVaultOutTarget.sol
UniswapV4FullSpreadStandardExchangeVaultPoolKeyAwareRepo.sol
UniswapV4FullSpreadStandardExchangeVaultPoolManagerAwareRepo.sol
UniswapV4FullSpreadStandardExchangeVaultPositionImportFacet.sol
UniswapV4FullSpreadStandardExchangeVaultPositionImportTarget.sol
UniswapV4FullSpreadStandardExchangeVaultPositionRepo.sol
UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol
interfaces/IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.sol
test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol
```

The experimental candidate is unadopted: retire it, do not invent a candidate-repair workstream. Preserve its historical findings as such. It is not the source of an adopted inverse.

## C. Six historical documents — deprecated now as current V4 law

Under root A:

```text
UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md
UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md
UNISWAP_V4_STANDARD_EXCHANGE_VAULT_PLAN.md
UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_IMPLEMENTATION_AND_TEST_PLAN.md
UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_IMPLEMENTATION_AND_TEST_PLAN.md
```

Under root B:

```text
UNISWAP_V4_STANDARD_EXCHANGE_CONSTANT_PRODUCT_ACCOUNTING_PRD.md
```

These are historical code-linked specifications, not current law for the two replacement families. This document and the updated current PRD record their deprecation without changing their historical text. At the source-removal gate, retire the six active copies after preserving a revision-qualified historical record. No clause-by-clause reconciliation is required. A separately authorized implementation/documentation agent may place deprecation banners on the old paths; this council does not edit those out-of-scope paths.

## D. Explicit preservation exclusions

- Both complete `v4/fullSpread/hookless/` and `v4/fullSpread/ponsFamilyV2Hook/` subtrees, including new files added during implementation.
- Root B's `.DS_Store`: unrelated metadata; outside this vault-removal operation.
- `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol` and all parent-level shared arithmetic.
- V3 implementations, V3 companion law, and the V3/shared portions of parent remediation documents. Update only active V4 pointers; preserve historical source maps, hashes and build evidence without rewriting their old meaning.
- All `lib/crane/contracts/protocols/dexes/uniswap/v4/`, `lib/crane/contracts/utils/math/`, Pons reference sources, network constants and generic interfaces.
- Live deployments, balances, registry entries and immutable instances. No migration/retarget/deactivation is part of source removal.

## E. Consumer rehoming and verification before deletion

1. `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol`: replace the old FactoryService dependency (observed near lines 92–98) with explicit new-family deployment wiring. Choose Hookless only for zero-hook keys, Pons only for the fixed admitted key; reject others. This is deployment selection, not shared economic dispatch. Preserve opaque SE interfaces in DETF money paths.
2. `contracts/test/bases/TestBase_UniswapV4StandardExchange_PonsV2.sol`: rebase onto the new Pons family TestBase. Port consuming-hook, token-decimal, nested-unlock and fee tests; do not retain the deleted old interface file solely for its ERC-165 ID.
3. Existing protocol-tree and FullSpread release/remediation/SE-matrix tests: port applicable security assertions to both family suites. Tests solely documenting obsolete behavior retain a historical revision and stop compiling against deleted SUTs. Preserve shared CP tests unchanged unless a separately demonstrated shared defect warrants an authorized fix.
4. Candidate-only `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v4/closed-form/UniswapV4FullSpreadClosedFormPrimitiveParity.t.sol`: retire/archive with candidate evidence, not repair/adopt it. Port any independently required sleeve arithmetic assertions into the new tests; no discarded assertion may be used to make a release green silently.
5. Verify maintained contracts/tests/scripts and artifact identifiers contain no unresolved dependency on any file/type in A/B. Apply the plan's exact prefix mapping to required consumers. Keep old names only in clearly historical records. New matches discovered during implementation are dependency-update work, not permission to expand deletion scope indiscriminately.

## F. Gate and counts

Observed recursive legacy file totals: A = 44 Solidity + 5 Markdown = 49; B = 36 Solidity + 1 Markdown + unrelated metadata = 38. Therefore the specified vault retirement set is **80 Solidity files and six historical documents**, not all 87 observed files. New family directories are excluded.

Record pre-removal revision, preserved evidence, both completed replacements, acceptance results and audit-submission readiness. Only then execute listed removals. Refresh runtime artifacts and rerun replacement/consumer suites on the final post-removal revision before audit handoff. No build/test/deletion was performed to create this manifest. Direct moderator directory reads and Astra/Grok independent counts corroborated the filenames on 2026-09-27.
