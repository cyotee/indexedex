# Resumed deployment staging contract

Date: 2026-11-13. Local implementation/testing only. Historical phase09 remains read-only.

Current base: 1694e68a4bd66dd67d3b5e3f145f1da23074ff48 plus the parent's existing uncommitted E-S, two-contribution NFT 3 and conserved claimed-SY implementations.

The reviewed bond-plus-two-SY construction is ported, retaining current PkgArgs, 15 package facets, the claim-vault allocation facet dependency, and all current runtime functionality. Its final gas on current bytes is an outstanding executable gate, not inherited from phase09.

## Package ABI and sequence

1. Deploy/register UniswapV4DetfMigrationSYDFPkg with MigrationPkgInit(baseInit, diamondFactory). Base fields are existing domain, permit and Migration SY facets, fee oracle and manager registry.
2. Select this package as current Migration parent PkgInit.baseInit.syPkg. Retain current PkgInit.claimVaultAllocationFacet.
3. Derive parent using existing callback factory calcAddress(parentPackage, abi.encode(PkgArgs)); parent calcSalt clears only baseArgs.hook in a copy. Construct the real owner-bound weighted hook using that prediction.
4. Call parentPackage.syConstruction(fullArgs). It derives constructionId, parent, bond, receipt, canonical bondArgs, rawArgs and stakingArgs from actual selected immutable dependencies.
5. Submit parentPackage.prepareSyChildren(fullArgs), returning rawSy/stakingSy, with an outer gas envelope <=32,000,000. The historical API name prepares the bond and both SYs atomically.
6. Read syPackage.preparation(constructionId), require completed and exact canonical identities/hashes. Before finalization parent/receipt code and parent registry discovery are absent; bond is unreserved/unfunded; both SYs have zero issued supply/backing and no temporary hook. Validate actual callback-factory package/argument records, not only cached operator state.
7. Submit parentPackage.deployVault(the identical fullArgs), with envelope <=32,000,000. It initializes reserved IDs, receipt/RT, reciprocal links, removes the hook and publishes the complete parent in one transaction.
8. Resume against actual parent factory arguments. Existing-code direct registry/factory reuse is not fresh construction and does not validate a changed hook payload; parent helper rejects that mismatch. Do not replay preparation after parent creation.

constructionId = keccak256(abi.encode(block.chainid, parentPackage, fullArgs)), including actual hook. Child hashes = keccak256(abi.encode(canonicalChildArgs)).

Parent getters: syPackage(), preparationDependencies() -> (bondPackage, receiptPackage, feeOracle, syPackage), syConstruction(PkgArgs).

SY getters: diamondFactory(), preparation(bytes32), construction(address parentPackage, PkgArgs), authorizedChild(bytes32 argsHash), validateChild(address, IDETFSYDFPkg.PkgArgs), validateBond(address bond, address package, IDETFNFTVaultDFPkg.PkgArgs, bool reserved, address creator).

Preparation tuple order: parentPackage, constructionId, parent, bond, bondPackage, bondArgsHash, receipt, rawSy, stakingSy, rawArgsHash, stakingArgsHash, completed.

## Parent integration and environment

Operator TypeScript, Phase_08_Stage_01 and runbook remain parent-owned. Phase_08_Stage_00 also calls deployVault in simulation after stopping broadcast; that call now needs simulation-only preparation first. This lane does not edit that stage.

The existing populated lib/crane remains intact. Missing lib/crane/lib/forge-std/src was recreated as a symlink to /Users/cyotee/Projects/indexedex/lib/crane/lib/forge-std/src for tests; cleanup is left to parent as requested. Warm out/cache_forge were not copied or deleted.

## Preserved historical verdicts

Phase09 diagnosis reproduced the original oversized deployment. Its two-SY implementation and independent verification failed both final transactions. The later bond-design admission and bond-correction producer report cover the reviewed combined split, but do not constitute current-bytecode acceptance. Full historical reports were read, including C1-C6/G1-G8 and the unchanged contents-ID convenience-query discrepancy. Current evidence will be recorded separately here.
