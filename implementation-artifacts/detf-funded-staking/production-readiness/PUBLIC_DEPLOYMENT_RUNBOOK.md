# Public deployment handoff — validated release candidate

This is a future operator procedure, not authorization to broadcast. This execution is limited to hermetic tests, read-only upstream forks and an isolated local deployment. No public deployment or fund migration has occurred. The final `release-manifest.json` reports the exact accepted source and artifact hashes. Recheck that manifest and any changed external state before a separately authorized public operation.

## Release boundary

The application supports the unified V4 DETF with CP, Weighted, Orbital and Curve Quad hooks, its funded bond NFT, nine-decimal sDETF, raw DETF SY and staking SY, and the retained SE/SY packages in `package-source-manifest.json`. SE shares and external tokens retain their actual native decimals. D60 Balancer-hosted DETFs and D66 unfinished Slipstream are excluded from new deployment claims. Balancer SE and Balancer V4 hooks are separate supported components.

Architecture deployment registers packages; it does not create customer markets, deploy test tokens or seed funds. A later instance deployment needs a reviewed market-specific `PkgArgs`, provider binding, amounts and creator address. Hermetic fixture tokens and rehearsal-only instances are not public market configuration.

## Core prerequisite

PR-04 confirmed that the pinned old CREATE3 core at `0xD7786b10BC8Bc97dc7651CAb7B97086c8b227882` lacks authorization on canonical registry writes. **Do not reuse that core as a dependency of this candidate.** The source patch does not repair already deployed contracts. This release requires the newly built and rehearsed core, its protected facet/package registries, current manager and current Fee Collector. Verify actual code, installed selectors, owner and operator scope before using any address. A nonempty `eth_getCode` result or a matching diamond proxy alone is insufficient.

Keep the Crane submodule patch in the release snapshot: both `FacetRegistryTarget.sol` override methods and `DiamondFactoryPackageRegistryTarget.sol.setCanonicalPackage` must include the existing `onlyOwnerOrOperator` guard. Deploying the old Crane revision without its recorded dirty patch loses this fix.

## Exact configuration to review

| Setting | Maintained architecture value / source |
| --- | --- |
| Target chain | Robinhood mainnet, chain ID 4663; never infer chain from an RPC URL label |
| Deployer and core owner in the rehearsal | `0x72BeA6Fa3E68EF18c87D045Aac7C4Aa5249d933B`; public signing authority must be available and verified by the operator |
| CREATE2 core namespace | `FixtureEconomics.SALT_NS = "RhMain"`; core salt binds owner, namespace and `"Create3Factory"` |
| Product component salts | `ArtifactCreationCode.releaseSalt`: `keccak256(abi.encode(namespace, keccak256(initCode), keccak256(initArgs)))` where used by the recorded FactoryService; record the exact bytes, not a label |
| Global usage fee | `5e16` (5%) |
| Global DEX swap fee | `3e14` (0.03%) |
| Seigniorage | `5e16` (5%) |
| Default fee/creator standing-weight parameters | `12e16` / `28e16` (12% / 28%), initialized by `IndexedexManagerDFPkg`; apply the funded standing-right calculation rather than treating these as a new fixed payout split |
| Gas estimation multiplier | `GAS_ESTIMATE_MULTIPLIER=120`, matching the strict rehearsal; do not silently inherit the public wrapper's 300 default. Requote if this value changes. |
| Output isolation | Set fresh `DEPLOYMENTS_DIR` and matching `OUT_DIR_OVERRIDE`, `FOUNDRY_BROADCAST`, and `FRONTEND_ADDRESS_EXPORT_DIR` before any simulation or stage. Simulations can write local manifests and exports even without broadcasting. |
| V4 liquid reserve default | `0.2e18` (20%) |
| Bond lock and bonus defaults | Minimum 86,400 seconds / 0% bonus; maximum 180 days / 50% bonus; verify `defaultBondTerms()` against the stage output |
| DETF instance policy | Immutable unowned instance; required price gates with reserve-swap fallback; hook ownership and `ownerOnlyLiquidity` must match the encoded args |
| Fee and creator destinations | Verify the current manager oracle recipient, collector owner and each proposed instance's creator/allocations; do not substitute a test actor or zero/default address silently |
| External pins | `RobinhoodCanonicalLib.sol`, Phase 01 manifests and verified runtime code; provider-specific addresses/pools/markets must match the candidate's package constructor args |

Changing the deployer, owner, code, package constructor, linked library or market arguments can change predictions or security assumptions. Regenerate affected predictions and repeat the corresponding local simulation instead of recycling old receipts.

## Deployment sequence

1. Restore the exact release source/dependency snapshot and matching `out/` artifacts. Verify the final manifest, compiler 0.8.35, Foundry version/configuration, no `via_ir`, and every deployed runtime at or below 24,576 bytes. Rebuild before execution if the source/configuration differs; FactoryServices read artifacts through `vm.getCode`.
2. Use a new output/broadcast directory and inspect predicted occupied salts on the intended chain. Preserve prior manifests. Do not use `--force` or assume that an occupied CREATE3 salt contains current code. The reviewed local core must correspond to the new predictions, not the vulnerable pinned core.
3. Select the maintained public wrapper, `scripts/shell/robinhood_main.sh`. It omits the local Phase 00 bootstrap and requires a real public signer. Its `all` command broadcasts by default; a preliminary invocation without broadcast authorization must explicitly use `--dry-run`. This wrapper simulates stages separately: a fresh-core dry run cannot establish later onchain dependencies and is not an end-to-end deployment proof. Use the complete isolated rehearsal and aggregate funding simulation for that evidence. Set the output-isolation variables above before either route. Do not use the Anvil wrapper, impersonation, `PRIVATE_KEY=0`, or `--unlocked` on a public network.
4. Follow the catalog order: Phase 01 external pins; Phase 02 corrected CREATE3, diamond callback and hook factories; Phase 03 common facets; Phase 04 current Fee Collector and manager; Phase 05 rate providers/oracles and V4/V3/Morpho/V2 SE packages; Phase 06 supported hook and DETF companion packages; Phase 09 isolated address export. The shared `rh_4663_stages.sh` catalog is authoritative. TokenStaking and funding stages are opt-in and outside this release task.
5. Recheck each simulated transaction's target, calldata, salt, sender, deployment argument hash and predicted result against the manifest. The maintained wrapper simulates each stage before broadcast. Do not add `--skip-simulation`, relax the node runtime limit, or lower the lifecycle test gas bounds.
6. Obtain a fresh EIP-1559 funding estimate using a fresh isolated strict fork and the maintained `simulate` route. Clear `ETH_GAS_PRICE`/`ETH_PRIORITY_GAS_PRICE`; sum planned transaction gas limits, multiply by the then-current upstream gas price and the maintained 25% funding buffer. Use the corrected simulation, which includes all 19 onchain architecture stages including 06/09, and point `FOUNDRY_BROADCAST` at a fresh directory. Empty or incomplete gas records must fail. Local unlocked legacy receipts record actual effective gas prices; a requested command-line gas price is not a verified public cost. The aggregate dry-run uses this Forge version's default 130% gas estimate, while the rehearsed staged broadcasts use 120%; retain the recorded limits and fresh 25% funding buffer. Historical local costs are not a public funding quote. Do not reset the completed rehearsal node to obtain this estimate.
7. Public broadcast remains a separate authorized action. After that action, verify every receipt, status, code hash, immutable value, package registration, core operator and installed proxy cut. Retain deployment args, logs and transaction hashes. A successful transaction alone does not establish the correct wiring.
8. Generate Phase 09 output with `FRONTEND_ADDRESS_EXPORT_DIR` pointed to a review directory first. Compare the resulting platform bindings to actual verified public addresses before publishing them to `frontend/packages/protocol/src/addresses/chain/4663`. The export stage also creates empty product lists; preserve existing lists unless an explicit publication intentionally replaces them. Run the app's check command and relevant live money-path tests whenever final application bindings change.

## Instance verification and operations

Before activating any later DETF instance, verify the hook address/flags, exact package and facet hashes, single self-leg, rate/SE route bindings, live fee oracle, companion NFT/sDETF/SY addresses, nine-decimal product units, creator allocation, thresholds, epoch rate and immutable liquidity policy. Use its actual `previewFirstBondPayments` to approve and supply every required native-unit payment. Do not infer the quote from a historical single-token fixture.

For user actions, require fresh previews, deadlines, final-output minimums and exact intended recipients/approvals. A positive-input zero-final-output DETF redemption now reverts atomically. Legitimate zero partial bond claims retain unvested principal. Claim funded principal/rewards through the NFT routes; do not restore retired LP-valued close/redeem selectors. Direct stake/unstake remains 1:1 against held DETF and is not gated by reserve price.

The final candidate must also contain PR-09 residual retry termination and PR-10 full-precision Orbital NAV. Their earlier local deployment is superseded evidence: valid zero-LP dust exhausted a bounded CP/V3 transaction, and a high-precision Orbital/V2 calculation overflowed before division. Require the seven direct/constructive regressions and the renewed 39-case lifecycle pass. Do not replace their production fixes with a higher gas allowance, smaller test amounts or a different native-decimal assumption.

Monitor backing versus staking liabilities, funded epochs, reserve custody, creator/collector configuration and unexpected transaction reverts. Rotation of the live collector changes restricted reserve-LP removal authority; verify the old recipient loses that privilege. Keep core registry operators least-privileged and revoke temporary deployment permissions when the reviewed deployment flow no longer needs them.

If an immutable DETF instance is defective or misconfigured, publish a verified replacement package/instance and an explicit user-led transition procedure under separate authorization. Do not claim an owner pause, upgrade route or automatic custody migration exists. Preserve available standard exits and funded NFT claims, correct discovery/publication, and communicate the exact affected addresses. No migration is performed by this plan.

## Completed release evidence

`release-manifest.json` is the final gate record for local source/config SHA `187b03242b92380b8696be84a5d3f55a74ba4a140012b67820a4bee70cd7b2fe` and Crane source/config SHA `b45a057611f782040ee29f1fddbbcc8eeba01def2c9341ef01c6bb65f685e123`. All 40 applicable criteria passed; A33/D60 and A42/D66 retain their exclusions/deferral. The complete build includes 294 maintained scripts; 31,312 unfiltered tests, 27 overlapping security cases and seven overlapping lifecycle regressions passed. Eight retained V3 and 27 provider fork passes have the explicit 423-file unchanged-dependency proof. Fresh local deployment at port 18665 produced all 156 successful receipts and all 39 strict lifecycle cases passed. The final post-Forge runtime, constructor, salt, artifact, storage and ABI reconciliation also passed.

The corrected local core is `0xd41305e8ba283b1043e78f0cfc506557f2c69df1`; its local addresses are not evidence of a public deployment. At 2026-09-11T12:44:59Z the separate EIP-1559 dry run quoted 0.0817942118499 ETH, or 0.102242764812375 ETH with the maintained 25% buffer, for 156 transactions and 747,456,930 summed gas limits. Requote against current chain conditions before public execution. The completed node and its receipts were preserved.

No in-scope implementation or validation blocker remains. Actual public signing, public broadcast, customer instance configuration/activation, address publication and fund migration were not performed. The internal review is not an independent external audit. The manifest excludes Balancer-hosted DETFs, unfinished Slipstream and opt-in TokenStaking deployment.
