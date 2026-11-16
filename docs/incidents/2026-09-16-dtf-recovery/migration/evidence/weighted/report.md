# Weighted legacy custody and receipt evidence

Date: 2026-11-10. Scope: task 1, weighted NFT, DETF, sDETF and SY only. This is source/custody evidence, not approval of allocations or completion of the Migration product.

## Result and evidence boundaries

**The deployed weighted sources support actual whole-NFT custody, funded claims, receipt custody, SY redemption, unstaking and DTF harvesting on the pinned local fork.** The source itself does **not** prevent an approved operator from redirecting a claim. A migration adapter must independently enforce current-owner surrender and a fixed recovery recipient. Fungible contribution ancestry and migration credit consumption remain **UNPROVEN**.

`WEIGHTED_PROBE_PASS` means the probe's enumerated source-capability checks passed, not that every migration requirement passed. `migrationReady` is deliberately false. Individual FAIL and UNPROVEN rows must not be hidden by the capability summary.

The final exact invocation exited **0**, printed **WEIGHTED_PROBE_PASS**, and recorded **34 PASS, 1 FAIL and 2 UNPROVEN** checks. The executable file's content SHA-256 equals the executed hash, `17e618d198559cdf6bf77674286858911fa61532ca274e04b52f753aa9249df0`.

Evidence in this directory:

- `probe.results.json`: invocation, observed runtime, exact selector bindings/ABIs, raw RPC reads, fork transaction receipts, per-behavior verdicts and teardown.
- `probe.sources.json`: Sourcify responses containing deployed source, verified ABI, compilation metadata and runtime bytecode for each selected proxy/facet.
- `probe.historical-receipts.json`: fresh public receipt reads for original purchases and post-incident claims, with canonical block-hash checks.
- `source-state-summary.json`: compact pinned source state, all IDs 0–46, original/remaining units, selectors and historical joins.
- `deployed-source-extracts.json`: verbatim deployed-source lines referenced below.
- `source-comparison.json`: frozen-input SHA-256 checks and deployed/current source differences.
- `direct-first-run.results.json`: first successful direct-alias fork run; the exact illustrative transaction amounts below come from this immutable run receipt.
- `initial-run.results.json`, `rate-limited-run.results.json`, `loopback-rate-run.results.json`: preserved failed harness attempts, not product evidence.
- `probe.anvil.log`: final local node output, with the RPC credential redacted.
- `cleanup-audit.json`: independent final read-back of all five owned node PIDs, ports and run roots, the failed-launch directory, executable mode and executed source hash.

No original incident input was edited. The weighted-bond, post-incident-claim, bond-accounting and normalized-transfer files match their recorded SHA-256 values. Current bond, receipt and SY target files have different hashes from the verified deployed source; they were not substituted for it.

## Chain, block and code identity

Public reads used configured alias `robinhood_mainnet_alchemy`, chain **4663** (`0x1237`), block **108944663** (`0x67e5d17`), hash **`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`**, timestamp **2026-11-08 04:08:21 UTC**. The requested historical state was available; no fresh-block fallback was needed. The probe retains a separately labelled fallback path if that pin becomes unavailable.

| Kind | Deployed address |
| --- | --- |
| NFT | `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E` |
| DETF | `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7` |
| sDETF | `0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c` |
| SY | `0xB55604CF4dcdABB362078e106D20F98512391EdF` |
| Harvest DTF | `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01` |

The four proxies share runtime Keccak-256 `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`. That alone does not identify their behavior: the probe also reads each selected selector's facet binding at the pin and authenticates that facet's runtime.

| Selected facet | Runtime Keccak-256 |
| --- | --- |
| NFT generic ERC721 `0xde5a691CEFE1830e8Ff2b65F6657738b0d9B9279` | `0xf709b5311471ef0b02cf7ddaa8f48b9da30647ab9958a3efde1813e5ac4337b8` |
| Funded bond `0x3a07364eabA092472d40F0e6788b8891A31faD4D` | `0x325a3b9bf3e616386e03d2a14d0a1fb29820f104a5f433d0b08a88dbdd0bef52` |
| DETF ERC20 `0x1d17acA0e0717d90cea916372070a1BE4652223F` | `0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50` |
| DETF query `0x1d38189B5f3548bc86838061F4318DBFA2f77680` | `0xcdb1b86aac1f571fc4f78937a4c670a6710ae2ab465d0f9c23acb87ddad7d8f4` |
| DETF exchange `0x4886F86CD0DFFf8b8A836F858925eD4de3a2b291` | `0x1eadaa06571b1cca173491d149bab9b07d5d1b9dc83d268654e49d3179b1a460` |
| sDETF `0xB7581fe833a2B2380DD786B345D61FFB734D36EB` | `0xcb505aba37d6ad909d8fb33dbf0091be50c9dd37f43e5df506bd240fc711b361` |
| SY `0x4B6e65CfC9a16aae0DfA4257A680f4697275e5fc` | `0x6da9227c829765d0464b5eeee02c55ea45883e3af2767aea546f5e906e8b143d` |

Pinned bytes equal the archived Sourcify onchain bytes. Recompiled execution bodies also match after removing terminal Solidity CBOR metadata. Sourcify labels the generic ERC20/ERC721 facets `match`, not `exact_match`; their metadata difference is preserved rather than described as a full metadata match. Other selected sources have `exact_match`. This trusts Sourcify's published recompilation; no shared Forge build was run.

Execution used macOS arm64, Bun **1.4.2**, `/opt/homebrew/Cellar/bun/1.4.2/bin/bun`, and Anvil **1.9.0-Homebrew**, commit `6056c5845d34205a83cf7108042adb137325c9df`. The final result records the probe SHA-256 and its exact executable path.

## Exact source interface and units

All amounts below are raw integers. DETF, sDETF and SY report **9 decimals**. DTF has the incident's 18-decimal unit. Gons are internal integer ownership units, not another token balance.

| Source/read or operation | Observed selector | Deployed return schema |
| --- | --- | --- |
| NFT `ownerOf(uint256)` | `0x6352211e` | `address`; burned/nonexistent IDs observed as zero |
| NFT `positionOf(uint256)` | `0x46f96023` | Five uint256: principal, claimedPrincipal, stakingGons, startTimestamp, vestingDuration |
| NFT `previewClaim(uint256)` | `0xae648e90` | Four uint256: vestedPrincipal, principalRemaining, principalDue, rewardsDue |
| NFT approve/getApproved | `0x095ea7b3` / `0x081812fc` | none / address |
| NFT set/isApprovedForAll | `0xa22cb465` / `0xe985e9c5` | none / bool |
| NFT transferFrom/safeTransferFrom, three arguments | `0x23b872dd` / `0x42842e0e` | none |
| NFT claimPrincipal/claimRewards/claimBond | `0xf400c743` / `0x6c7b69cb` / `0x084c59ae` | uint256 / uint256 / two uint256 |
| ERC20 balanceOf/approve/transferFrom | `0x70a08231` / `0x095ea7b3` / `0x23b872dd` | uint256 / bool / bool |
| sDETF `gonsOf(address)` | `0x79a67521` | uint256 |
| sDETF `stakingState()` | `0xe082f1d4` | Seven uint256: totalGons, gonsPerUnit, accountedBacking, allocationDust, stakingDust, feeWeight, creatorWeight |
| DETF and sDETF `exchangeIn(address,uint256,address,uint256,address,bool,uint256)` | `0xd02d3063` | **one uint256**, unlike the current two-value interface |
| DETF `previewExchangeIn(address,uint256,address)` | `0x89d61912` | **one uint256** |
| SY yieldToken/exchangeRate/getTokensOut | `0x76d5de85` / `0x3ba0b9a9` / `0x071bc3c9` | address / uint256 WAD / address[] |
| SY previewRedeem/redeem | `0xcbe52ae3` / `0x769f8e5d` | uint256 / uint256 |

The JSON retains every selected signature, facet and verified ABI, including overloaded or additional read surfaces. Return types are taken from deployed source, not inferred from selector existence.

### Original and remaining principal

The probe freshly authenticates **43 BondPurchased receipts** and **seven post-incident BondClaimed receipts**, verifies receipt block hashes, joins source event/token identity, and checks original principal against live positions where they exist. IDs 0–2 are reserved, zero-principal records. Purchased IDs are 3–45; 25 and 42 are burned at the pin. IDs 44–45 are post-incident purchases, not pre-incident snapshot positions. There are 41 live purchased NFTs.

| NFT | Original principal | Claimed principal | Remaining total principal | Currently due principal |
| --- | ---: | ---: | ---: | ---: |
| 3 | 3772281649 | 0 | 3772281649 | 3772281649 |
| 4 | 281387179 | 0 | 281387179 | 86292556 |
| 26 | 56299 | 0 | 56299 | 16976 |
| 32 | 54436459 | 8071216 | 46365243 | 8249343 |
| 34 | 59081498 | 7942358 | 51139140 | 51139140 |
| 36 | 1642192630 | 3247321 | 1638945309 | 488108181 |
| 44 | 81035885 | 73745125 | 7290760 | 7290760 |
| 45 | 12596732131 | 11460965662 | 1135766469 | 1135766469 |

Remaining principal is `principal - claimedPrincipal`, **not** currently vested principal and not receipt value including rewards. For example, NFT 4 retains its entire 281387179 principal although only 86292556 is currently due. NFT 26 belongs to `0x2e69E40C4a4Ab5CA6826850F347acf8076a8063e`, not its original purchaser; source ownership is not payer-bound.

For IDs 25, 42 and nonexistent 46, `positionOf` and `previewClaim` revert with `ERC721NonexistentToken`, selector `0x7e273289`. A zero `ownerOf` read must not be accepted as custody or eligibility.

Source references are the archived deployed `DETFFundedBondTarget.sol:127–140,163–200,234–242`, not the current worktree copy.

## Actual custody, harvest and rollback

The local custodian fixture is EOA `0x000000000000000000000000000000000000c057`. It is not a deployed Migration proxy or a proof of its receiver callback. Only gas balances were supplied through Anvil; no source storage or source bytecode was fabricated.

For NFT 3 the fork executes:

1. Impersonate the actual owner, approve this custodian, and read `getApproved`.
2. Send `safeTransferFrom(owner,custodian,3)` **as the approved custodian**.
3. Read `ownerOf == custodian`; re-read all five position fields and require them unchanged. Whole identity, remaining principal and reward rights move together.
4. As custodian call `claimBond(3,custodian)`. Measure sDETF custody balance from 0 to **4308806205** in the first successful run. The NFT burns; a repeat claim fails.
5. Unstake exactly **4308806205** sDETF into the same raw amount of DETF through sDETF `exchangeIn(sDETF,amount,DETF,amount,custodian,false,deadline)`.
6. Approve the DETF source and call its `exchangeIn(DETF,amount,DTF,0,custodian,false,deadline)`. Measure **24312424763253115621623 raw DTF** received, not an assumed preview or an emitted intermediate amount.

The successful NFT transfer and harvest receipts, log indexes, local block hashes and transaction hashes are archived under `checks[approved_actual_whole_nft_custody]` and `checks[custodied_nft_actual_claim]`. These are genuine mined local transactions, not `eth_call` simulations.

Separate receipt/SY scenarios surrender 10% of an observed holder balance after actual approval, execute `transferFrom`, and measure custody. First-success examples:

| Path | Input raw units | Actual output |
| --- | ---: | ---: |
| Direct sDETF custody then unstake | 38283506 sDETF | 38283506 DETF |
| That DETF into DTF | 38283506 DETF | 216228659430800592372 DTF |
| SY custody then redeem | 8094 SY | 9245 sDETF; surrendered SY balance becomes zero |
| That receipt, via DETF, into DTF | 9245 sDETF | 52221256856930805 DTF |

These amounts include actual transaction-time synchronization. Do not substitute the pinned pre-synchronization preview for a realized claim.

Each scenario snapshots first, restores with `evm_revert`, and reads back block number, NFT owner/position/approval, custodian sDETF/DETF/DTF, redirected receipt balance and staking state. Equality must hold after restoration. The failed safe-transfer case sends to the real sDETF contract, which does not accept the NFT; mined status is zero and ownership is restored. Explicit mining, rather than receipt polling or a fixed delay, determines completion.

### Reward-only and operator behavior

Claiming only NFT 3 principal leaves an extant NFT with principal and claimedPrincipal both **3772281649**, remaining principal **0**, and **469717513647742174174809819095640627244883279** staking gons in the first successful run. Existence alone therefore does not imply migration eligibility.

An approved operator `0x0000000000000000000000000000000000000a11` successfully directs `claimBond` to stranger `0x0000000000000000000000000000000000000bad`, receiving **4308806205 raw sDETF** in the first successful run. This is a **FAIL for source-provided redirection protection**, not an unexpected ERC721 permission failure. The deployed `_claim` explicitly accepts owner, per-token approval or operator approval and an arbitrary nonzero allowed recipient (`DETFFundedBondTarget.sol:163–184`). The new adapter cannot treat “approved operator” as proof of the migration beneficiary.

## Receipt gons, wrapper ancestry and limits

At the pin:

- `gonsPerUnit = 876973181092115404940326782759509937`.
- `SY.exchangeRate = 1140285725447928057` WAD; `yieldToken` is the assigned sDETF.
- SY holds **54373903589043794139626986358920462592399234625 gons**, represented as **62001786099 raw sDETF**.
- SY advertises DETF, sDETF and DTF outputs. Only the tested staged SY → sDETF → DETF → DTF route receives an executable PASS here; a direct SY → DTF call was not tested.

Deployed `DETFFundedStakingRepo.sol:109–161` transfers `amount * currentGonsPerUnit` gons. A full-account unstake debits all remaining account gons, including its final fraction; a partial unstake debits the exact native amount times the index. Deployed `DETFSYTarget.sol:94–134,225–251` consumes static shares, converts each share's `1e36` gons through the funded exchange rate, and preserves conversion dust. SY shares and their underlying receipt backing are one claim, not two awards.

The seven freshly checked historical claims match actual sDETF Transfer logs for principal plus reward. For example, NFT 45's first post-incident claim transferred **857705702 raw sDETF**: **802706343 principal + 54999359 reward**. Its frozen event-time divisor **894552893289458638617112841728172227** produces **767263117314966210835055079127676853135938354 debited gons**. This arithmetic was checked, but the frozen divisor was not independently recreated by replaying every RewardsFunded event.

**UNPROVEN:** complete proportional contribution ancestry through arbitrary later ERC20 transfers, mixed balances, claims and wraps. Source balances/receipts do not authenticate the original ETH/DTF entitlement or carry new prequoted migration credit. The probe does not implement an immutable transfer-history verifier, post-activation proof mechanism, descendant consumption ledger or disjoint independent-allocation proof. Those are concrete E2 mechanism gaps, not a reason to use a mutable owner root/signature or payer-only eligibility.

The accepted award remains `floor(C0 * remainingPrincipal / originalPrincipal)`, where C0 sums the once-quoted original ETH and DTF outputs against one funded frozen snapshot. No partial re-quote, reward credit, configuration premint or descendant second award is established here. Fresh 90-day bonds, activation freezes and atomic bond-creation rollback belong to the later Migration implementation and remain untested by this source-only lane.

## Required-behavior verdicts

| Required behavior | Verdict | Evidence or concrete limit |
| --- | --- | --- |
| Historical chain, block/hash, selected selector/facet and source identity | PASS | Pinned RPC bytes, verified source archive and execution-body comparison |
| Original principal and post-incident claimed descendants | PASS | 43 purchase and seven claim receipt checks; source-state reads |
| Remaining total principal versus currently claimable principal | PASS | Five-field positions and four-field previews, including partial claims |
| Approvals and actual whole-NFT custody | PASS | Mined approval/transfer, current owner read and unchanged position |
| Legacy claim, burn and repeat-claim rejection | PASS | Mined claim and post-claim source reads |
| Reward-only position and reserved zero-principal behavior | PASS | Principal-only claim leaves zero principal; reserved claim rejects |
| Wrong-owner transfer, wrong-owner redirected claim and failed receiver rollback | PASS | Failed mined transactions and state read-back |
| Stale runtime identity rejected | PASS, probe guard only | Deliberately wrong expected hash rejects with state unchanged |
| Approved-operator payout-redirection protection | FAIL | Actual redirected receipt payout; adapter must enforce its own binding |
| Actual DETF/sDETF/SY custody and staged harvest | PASS | Token deltas, gons, receipts and DTF deltas |
| Production Migration contract custody callback and atomic award/bond rollback | UNPROVEN | No Migration adapter/bond is implemented or deployed by this lane |
| Zero-principal/reward-only migration award rejection | UNPROVEN | Legacy state demonstrated; new migration rejection not implemented here |
| Complete authenticated fungible/descendant entitlement | UNPROVEN | No compliant immutable history/consumption mechanism established |
| Alternative direct SY→DTF route and forced disabled-state matrix | UNPROVEN | Not executed; no selector/existence-based support claim |
| Owned process, port and cache teardown | PASS | Per-run PID, port, snapshot, impersonation and directory receipts |

## Reproduction, failures and cleanup

Run from `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01`, with `ALCHEMY_KEY` supplied by the login shell:

```sh
R=$(mktemp -d '/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/weighted.XXXXXX')
export TMPDIR="$R" BUN_INSTALL_CACHE_DIR="$R/bun-cache"
export npm_config_cache="$R/node-cache" XDG_CACHE_HOME="$R/cache"
bun scripts/recovery/dtf-migration/phase01/weighted/probe.mjs --chain-id 4663 --block 108944663 --rpc-alias robinhood_mainnet_alchemy --local-fork --output docs/incidents/2026-09-16-dtf-recovery/migration/evidence/weighted/probe
```

The probe logs the literal invocation and binary PASS condition before work. Public script RPC is read-only; all transactions go to its own loopback Anvil fork. Anvil receives the configured alias, not a secret URL in argv. Its HOME/cache lives under the owned temporary root. No Forge compilation, public deployment or public transaction occurs.

The initial run failed on an asynchronous automined-receipt read; it was corrected to explicit mining. Two loopback-forwarded runs encountered Alchemy HTTP 429 during fork state loading despite the native throughput flag; these remain archived as harness gaps. The direct configured-alias fork with native metering completed the transitions. A failed launch caused by shell expansion left an empty owned `weighted.9SjTAg` directory; it was removed with `rmdir` and a nonexistence read-back.

Every completed runtime restores its base snapshot, stops its recorded impersonations, terminates and awaits its Anvil child, verifies the PID is gone and the loopback port closed, removes only its owned run root, and verifies ENOENT. `probe.results.json.resources` and the archived run resources are the cleanup receipts. Language-server diagnostics timed out; this is not reported as a clean diagnostic result. The executable runs supply the JavaScript runtime/syntax check.

## DoneClaim

- **changed_files:** only `scripts/recovery/dtf-migration/phase01/weighted/probe.mjs` and generated/authored files in this weighted evidence directory.
- **tests/probes:** the exact command above exited 0 with WEIGHTED_PROBE_PASS; 34 PASS, 1 FAIL and 2 UNPROVEN checks. Authenticated pinned reads, 43 purchase receipts, seven claim receipts, actual local custody/claim/conversion transactions, adversarial cases and rollback were executed. Capability PASS is not migration readiness.
- **evidence_paths:** the artifacts enumerated above, including `cleanup-audit.json` and the executable probe at the requested path.
- **cleanup_receipts:** all five node PIDs absent, all five node ports closed, all five run roots absent, base snapshots restored, recorded impersonations stopped, and failed-launch directory absent. Independent read-backs are in `cleanup-audit.json`; no shared process, cache, library or dependency was changed.
- **risks:** approved legacy operators can redirect payouts; complete fungible provenance and Migration-only safeguards remain unproven; the positive custody fixture is an EOA, not the future Migration proxy. No eligibility amounts or product policy were changed.
