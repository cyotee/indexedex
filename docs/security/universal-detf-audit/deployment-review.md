# Universal DETF deployment review

**Target-chain correction from the release review:** Robinhood chain 4663 allows 98,304 bytes of runtime code and 196,608 bytes of initcode, per its [official node configuration](https://cdn.robinhood.com/assets/generated_assets/hoodchain_docsite/chain-node-configs/robinhood-chain-info.json) and [network differences](https://docs.robinhood.com/chain/differences-from-ethereum/). The historical 24,576/49,152-byte findings below establish Ethereum-limit incompatibility, not Robinhood deployment failure. The already implemented splits are preserved; this correction does not assert that their behavioral verification or the remaining release gates are complete. See [current release review](release-review/RELEASE_REVIEW.md).

Review-only snapshot, 2026-09-05. No production edits, Forge commands, live transactions, or issue posting performed. Artifact sizes below precede the parent audit's rebuild and must be refreshed after it completes.

## Follow-up implementation: universal package split

The subsequent authorized implementation replaces the combined deployed universal facet with five independently deployed facets. The original `UniswapV4DetfFacet` is now an abstract metadata base; the former public bodies in `UniswapV4DetfTarget` and `UniswapV4DetfCommon` are internal-only. Each sibling role target adds only its own external wrappers, enabling elimination of unreachable internal code rather than merely filtering metadata on an oversized public target.

| Facet | Product selector count | Runtime after split |
| --- | ---: | --- |
| UniswapV4DetfExchangeFacet | 3 | Awaiting build |
| UniswapV4DetfBondFacet | 2 | Awaiting build |
| UniswapV4DetfMaintenanceFacet | 8 | Awaiting build |
| UniswapV4DetfClaimFacet | 3 | Awaiting build |
| UniswapV4DetfQueryFacet | 36 | Awaiting build |

`PkgInit.productFacets` holds those five facets in the listed order. The package retains its complete interface declarations and installs five shared token/vault facets plus these five product facets. All six existing universal package constructors and the gold/decimal/Pons test fixtures use the updated FactoryService. `UniswapV4DetfFactoryArtifactSeed` explicitly imports the five implementations and package from a production source root, so artifact-loaded deployment does not depend on test/script imports.

Static verification retained all 52 original selectors exactly once and compared all 139 existing Target/Common function bodies unchanged after mechanical helper-name, self-call-interface, and event-qualification normalization. Existing callback calls remain external self-calls; ordinary entrypoints call internal bodies with the original sender and existing reentrancy modifiers. No new delegatecall was introduced.

The three existing adversarial surface suites now validate the complete facet union. Added `UniswapV4Detf_FacetPackaging` asserts deployed runtime/initcode limits, package-to-loupe routing, metadata consistency, and self-only callback authentication on both proxy and implementation. Compilation, measured size results, and execution of those tests remain required; this follow-up has not run Forge. CP hook size remediation is owned separately.

## Confirmed deployment blockers under the repository size gate

| Actual deployed component | Runtime bytes | Creation bytecode bytes |
| --- | ---: | ---: |
| UniswapV4DetfFacet | 50,731 | 50,759 |
| UniswapV4DetfDFPkg | 17,771 | 18,584 |
| UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet | 31,506 | 31,534 |
| UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg | 19,160 | 20,280 |

Measured directly from `out/<Contract>.sol/<Contract>.json`: hex length of `deployedBytecode.object` and `bytecode.object`, excluding `0x`. Package constructor arguments are additional initcode; the table does not include them.

These are real deployment components. `UniswapV4Detf_Facet_FactoryService.deployUniswapV4DetfFacet` loads precisely this artifact through `ArtifactCreationCode`, then calls CREATE3 `deployFacet`. `UniswapV4DetfDFPkg.facetCuts` routes all 52 product selectors to that single facet. Both Robinhood staged package scripts invoke this FactoryService.

The CP hook FactoryService similarly deploys the complete DepositFacet through `type(...).creationCode`. Its DFPkg initially installs the package's six initialization selectors. `productionFacetCuts()` subsequently installs DepositFacet's 19 selectors on finalization. Deferring the cut does not reduce the facet bytecode deployed beforehand. By contrast, the CP InitFacet is explicitly an abstract, source-only mixin; the actual init implementation is the DFPkg, whose runtime passes the size gate.

The repository requires runtime <=24,576 bytes. Both product facets fail that gate. On chains enforcing [EIP-170](https://eips.ethereum.org/EIPS/eip-170), creation fails above this runtime limit. Universal's creation bytecode also exceeds the 49,152-byte limit of [EIP-3860](https://eips.ethereum.org/EIPS/eip-3860). CREATE3 does not bypass either limit. This review did not independently establish Robinhood's current chain-specific code-size configuration and does not claim an observed failed mainnet deployment. Existing infrastructure deployment does not establish that these newly compiled facets can deploy.

## Smallest safe correction plan

Follow the already approved packaging approach in `docs/CONTRACT_SIZE_REDUCTION_PRD.md` and `docs/CONTRACT_SIZE_REDUCTION_IMPLEMENTATION_PLAN.md`: split Facet/Target entrypoints first; preserve formulas, storage, interfaces, and authorization. The old inventory predates universal DETF and treats Single SE CP as a splitting template; it is insufficient for these current artifacts.

1. Universal: replace the combined product target/facet with sibling targets for exchange/mint/burn, bond/close, and maintenance/claim. Separate a query facet if any sibling still exceeds the cap. Retain existing internal helper bodies where possible. Common currently contains externally callable atomic compound/sweep functions: move their external wrappers to the maintenance target while retaining internal implementations in shared code. Otherwise every sibling inherits unnecessary external entrypoints and reachable bodies.
2. CP deposit: first isolate execution and preview entrypoints into sibling Deposit and DepositQuery targets/facets. Keep internal preview helpers wherever execution calls them. If execution still exceeds the cap, split proportional/SE-share deposits from single-asset/zap execution. Determine the final minimal partition from compiled sizes; static inspection cannot promise a two-facet split suffices.
3. Do not simply change `facetFuncs()` or create thin facets inheriting the full existing target: Solidity still emits inherited public/external functions. Internal shared helpers may be dead-code-eliminated; inherited external wrappers are the relevant boundary.
4. Add facet references on the package interfaces' `PkgInit`, update immutable references, `facetAddresses`, universal `facetCuts`, CP `productionFacetCuts`, FactoryServices, manager registry construction, launch stages, and TestBases together. Preserve all 52 universal and 19 CP deposit selectors exactly once across the replacement cuts. Keep universal package interface reporting complete even when individual facets expose subsets.
5. Preserve `msg.sender` behavior. Avoid routing extracted execution through unguarded external self-calls: token pullers, owner authorization, and reentrancy contexts depend on the original caller. Preserve the existing self-only atomic callbacks as self-only selectors. Preserve repo storage slots, hook address flag mining, and staged initialization behavior.
6. Build before tests, then measure every replacement facet and package (including constructor args for initcode). Exercise actual manager/CREATE3/package deployment and CP finalization with size limits enforced; check full selector union, absence of duplicates, immutable universal surface, and removal of init-only selectors. Run universal CP/weighted/orbital/quad lifecycle coverage because all families share this product facet.

## Initialization/proxy observations

Applied the upstream [proxy checklist](https://raw.githubusercontent.com/austintgriffith/evm-audit-skills/main/evm-audit-proxies/references/checklist.md) to the actual diamond path. The callback factory installs cuts and delegates package `initAccount` during proxy construction. Universal package initialization is not exposed in its product facet cuts, and universal cuts contain no ownership/upgrade facet. CP deliberately exposes a temporary staged initialization surface; its DFPkg `initAccount` is not one of the six routed initialization selectors. An unrestricted function on the standalone package therefore does not by itself establish reinitialization of a deployed product proxy.

The parent audit's canonical tick-spacing validation belongs in the shared CP BeforeInitializeLib, which serves both staged initialization and production hook callbacks. No additional confirmed initialization exploit was established in this bounded review. Direct facet calls, shared storage, and self-only callbacks must be rechecked after splitting because packaging changes alter reachable ABI surfaces.

## Follow-on local compiler evidence

Sibling universal and CP deposit facets have been implemented. The parent's isolated compiler pass used solc 0.8.35, optimizer runs 1, Prague, no IR. All 14 selected production components now fit the runtime gate (`evidence/production-sizes-after.json`). It additionally found the universal bond NFT facet at 24,791 bytes; changing six unrouted ERC721 methods from public to internal reduced it to 23,958 bytes. The package continues routing those methods to its existing ERC721 facet, and its guarded transfer replacements remain unchanged.

These are compiled size measurements. The separate Foundry artifact refresh and production-factory deployment/routing tests remain pending. No deployed package or proxy was modified.
