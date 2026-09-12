# Robinhood universal DETF release review

Status: **release blocked; review and remediation in progress**. This review covers the universal Uniswap V4 DETF, its claim and bond NFT dependencies, and the CP single-buffer, Weighted, Orbital, and Curve Quad buffer-hook packages. It does not certify every contract in the monorepo. No transaction has been signed or broadcast by this review.

The previous audit's 136/137 passing checkpoint is a historical baseline, not a green release gate. This review preserves its fixes and unresolved failures. `baseline.json` records the starting Git heads and 601 scoped source hashes; `source-before/` preserves the working versions of files changed here, including changes made before this review.

## Findings and local work

### RR-01 — Ethereum-size finding does not block Robinhood deployment

**Corrected finding; not a Robinhood deployment blocker.** Fresh baseline artifacts put the Orbital deposit facet at 34,140 bytes, Weighted join facet at 29,648 bytes, Curve Quad join facet at 26,019 bytes, and Weighted package at 24,989 bytes. They exceed Ethereum's traditional 24,576-byte limit. Robinhood's [official differences documentation](https://docs.robinhood.com/chain/differences-from-ethereum/) and [published node configuration](https://cdn.robinhood.com/assets/generated_assets/hoodchain_docsite/chain-node-configs/robinhood-chain-info.json) instead specify **98,304 runtime bytes and 196,608 initcode bytes**. All four fit the target chain's limits. `robinhood-chain-info.json` preserves the configuration. Live code exceeding 24 KB prompted this correction; it must also qualify the earlier audit's size findings.

Experimental local changes moved Weighted/Curve query wrappers, split Orbital deposits, and compacted Weighted package cut assembly. These are being removed from the release changes because the verified target-chain limits do not require them. The previous agent's pre-existing changes are preserved. Source restoration will use the exact `source-before/` snapshots, not Git checkout, which would discard prior work.

The isolated experimental compiler outputs are retained for audit history, not as the selected release design. The final size gate must use Robinhood's actual limits, including encoded constructor arguments and linked libraries, and must not mistake the local unlimited-code configuration for a production simulation.

### RR-02 — Custom bond close includes unrelated token inventory

**Security blocker; source confirmed, runtime reproduction pending.** `_payCustomClose` swaps the entire balance of each non-settlement pair token and then pays the entire settlement-token balance. Consequently, an authorized bond holder can receive inventory left on the DETF independently of that bond. Holder authentication alone does not constrain the amount paid.

The new `test_E6_customClose_doesNotPayPriorSettlementInventory` compares the same mature close before and after an unrelated transfer, using a state snapshot and the real CP hook/manager deployment. The intended correction is to settle only the withdrawn bond legs and swap proceeds attributable to those legs, leaving pre-existing inventory for the existing dust policy. Production behavior has not yet been changed for this finding.

### RR-03 — Rerunning deployment can silently retain old code

**Release migration blocker.** CREATE3 returns the existing contract at a salt without comparing new initcode or constructor arguments. The current factory services reuse type-name salts, and stage skip logic accepts any code at recorded package addresses. A forced run does not reliably deploy new implementations. The current unified deployment runbook's claim that such reuse necessarily reverts is incorrect for the reviewed factory implementation.

**Read-only runtime reproduction on Robinhood:** `eth_call` supplied the current claim facet creation bytecode to the real CREATE3 factory from its recorded owner using the existing type-name salt. The call succeeded and returned the already deployed old facet `0x25e611fb63eb904776678286ef5cbe2a931b4f9a`, whose runtime differs from the candidate. See `rpc-legacy-salt-request.json` and `rpc-legacy-salt-response.json`. No transaction was sent. This directly demonstrates that a successful forced rerun can retain the old implementation.

A release needs implementation-sensitive facet/package salts and dependency checks, followed by a rehearsal against the existing foundation. Hook-instance salt and CREATE2 flag-mining laws must remain unchanged. Foundation addresses must not be replaced as a side effect of updating product components.

The prepared correction passes an ABI typecheck. Separately, `eth_estimateGas` successfully simulated deploying the pending corrected bond facet through the real CREATE3 factory with its implementation-sensitive salt, estimating 4,516,038 gas. This is a dated simulation of one component, not a package deployment or whole-release gas quote. Evidence: `rpc-pending-bond-estimate-request.json` and `rpc-pending-bond-estimate-response.json`.

### RR-04 — Quoting remains incomplete

**Correctness blocker, inherited from the previous review.** The CP raw/pair minimum regression overquotes by one LP unit after yield and fee dilution. The single-asset preview uses pre-swap reserves where execution uses post-swap reserves. Universal claim-purchase previews return ownership-share units while execution returns a rebasing token amount. A fixed haircut or weakened assertion would not establish correctness.

The existing [transition-quote design](../PREVIEW_REMEDIATION_DESIGN.md) explains why a generic `IStandardExchange`/ERC-4626 view cannot reconstruct arbitrary downstream hypothetical conversion state. Selecting supported launch exchange implementations and providing exact transition quotes remains necessary. No implementation of that capability has been validated here.

### RR-05 — Initial claim backing has an unresolved owner

**Product/accounting blocker.** When protocol NFT backing exists but claim supply is zero, the hardened mint currently reverts atomically. Giving that backing to the first buyer or reserving an existing claim for the protocol are different economic policies. The owner has been asked to choose; this review does not silently choose a beneficiary.

## Existing Robinhood deployment

Read-only observations confirm chain ID **4663** and the recorded CREATE3 factory, diamond package factory, hook factory, manager, collector, and PoolManager have code. The manager's hook-factory storage points to `0x8BB5FCC67e8CCa44DC41dd08A5e2b2B392C22945`. Its `feeTo()` points to collector `0x20af9A1e21a59a411cd3b0C40E70AF9084770b2E`. Manager and collector ownership is `0x72BeA6Fa3E68EF18c87D045Aac7C4Aa5249d933B`.

At block `0x34ee861` / `0xb04f17aab4fcd01be8e9dfef3e0e24c7c906469feb08a1c7cc0fad4c3896b0d8`, every manager facet (15) and collector facet (7) matched local artifact runtime exactly. Including the reviewed foundation components, 23 unique matched artifacts cover 165 source files with no source-hash mismatches. See `foundation-runtime-comparison.json` and `foundation-artifact-freshness.json`. These checks establish the recorded implementation identity, not complete behavioral certification.

The package metadata observation used `latest` in a batch with head `0x34f292d`; its separate calls are not guaranteed to share one block. `deployed-package-metadata.json` records:

- The existing bond NFT package identifies itself as `DETFNFTVaultDFPkg`, not the universal V4-specific package.
- The existing CP hook package advertises ten facet addresses, predating the three-way deposit split.
- The existing DETF package records identify the older CP, Weighted, and Curve-specific packages. They are not the universal `UniswapV4DetfDFPkg`.
- A historical package metadata request failed because the public provider could no longer serve that state. The error responses are retained separately and were not treated as successful evidence.

Collector receipts alone do not establish automatic conversion and donation to the protocol DETF. The matched collector exposes owner-controlled withdrawal and permissionless reserve bookkeeping; operational handling of collected assets must be specified separately.

## Validation in progress

`validation/ReleaseRegression.t.sol` imports 71 original test files by name, including hook operations, surfaces, package declarations, staged initialization, shared claim accounting, and universal lifecycle regressions. It does not copy or replace their test bodies. The ABI-only typecheck passed. The matching-root `forge build` is running before runtime testing, using the existing warm isolated output/cache to avoid another shell's active canonical build.

Required before release: complete build and runtime regressions, reproduce and close RR-02, verify final artifact/source identity and actual deployed component sizes, resolve RR-03 through RR-05, execute the required adversarial/invariant matrix, and rehearse the precise release against the existing Robinhood foundation. A focused green test set alone will not close the remaining gates.
