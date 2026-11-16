# Independent bounded frozen-pricing verification

Date: 2026-11-10. Verdict: **AdversarialVerify: needs-fix**.

The demonstrated direct-pair / ordinary V3 buffering-deposit / raw-DETF-output pricing behavior is independently confirmed on current artifacts and real local proxies. No pricing discrepancy was observed in that bounded configuration. Overall confirmation is withheld for the local-script endpoint guard and the misleading named-test evidence described below. **This is not full task-2 actual-configuration E3 closure.**

This verifier made no source, test, product, plan, owner-policy, or shared-dependency changes, no commits, no delegation, and no public-chain actions. Root owns fixes and integration.

## 1. Findings requiring disposition

### F1 - The script's loopback probe is not bound to the selected broadcast RPC

Location: `scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol:93-97`.

Observed source: `run()` requires chain 31337 and the standard dev sender, then calls `vm.rpc("http://127.0.0.1:18546", "anvil_nodeInfo", "[]")`. That probe always queries the hard-coded local endpoint; it does not inspect or constrain the RPC selected by Forge's `--rpc-url`. The adjacent comment says a normal/public RPC rejects this method, but that is not the endpoint receiving this particular probe.

Inference from the control flow: with the required local node available, a different selected RPC reporting chain 31337 and the same unlocked dev address would satisfy these checks. The required rejection of a non-local intended broadcast environment is therefore not established by the script. No such non-local execution was attempted.

Fix direction: bind the loopback/port check to the actual selected execution/broadcast endpoint, retain the chain and dev-account checks, and demonstrate rejection before deployment for a mismatched endpoint. A check of an unrelated local service is insufficient. This is an execution-scope guard, not an owner-policy change.

Corrective acceptance: the authorized `127.0.0.1:18546` / chain-31337 / dev-account invocation remains usable; an endpoint mismatch is rejected before `startBroadcast` or any deployment even while the hard-coded local node is available. Verify the negative case with local-only infrastructure or a non-broadcast guard check, not a public-chain transaction. No pricing or product-policy change is required.

The verification execution itself was safe and exactly local: the recorded command used `http://127.0.0.1:18546`, its owned listener was PID 81860, `anvil_nodeInfo` reported chain 31337 and no fork URL, and every mined sender was the standard dev account.

### F2 - The producer's exact named-test command executed zero tests

Locations: `migration/quote-evidence.md:107-115` and `pricing/evidence/implementation/real-proxy-trace.log:94-98`, relative to the incident recovery directory.

The producer's preserved command and this verifier's first exact requested command both returned exit 0 but printed:

```text
Warning: no tests match the provided pattern:
    match-test: `^test_MigrationSnapshot_RealProxyCaptureAndFreeze$`
```

Thus the producer's additional named real-surface receipt cannot be cited as an executed test pass. The producer's **separate** `regression-final.log:3773` does contain a real PASS for this case, within its 111-test run; that valid evidence is retained.

The verifier preserved its empty-selection receipt as `real-proxy-command.txt`, `real-proxy.log`, and `real-proxy-exit.txt`. It compared the producer argv, current configuration, ABI, and environment: the same nightly binary, default spec path, no inherited Foundry matching environment overrides, unchanged current test source, and ABI signature `test_MigrationSnapshot_RealProxyCaptureAndFreeze()` with selector `0x75425450`. The producer had recompiled before its empty match; the verifier initially skipped compilation. Compilation success was not execution success in either case.

The correction was an exact ABI-signature regex, further restricted to the exact contract, not a weaker substring or a skipped test:

```sh
forge test --use solar \
  --match-path test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshot.t.sol \
  --match-contract '^UniswapV4DetfMigrationSnapshotTest$' \
  --match-test '^test_MigrationSnapshot_RealProxyCaptureAndFreeze\(\)$' -vvvv
```

Actual result: **1 passed, 0 failed, 0 skipped**, test gas 13,063,518, command exit 0, tee exit 0. See `real-proxy-exact-signature-command.txt`, `.log`, and `-exit.txt`. The test emitted frozen component outputs 1,192,506,669 and 1,773,603,425, with the live ETH-component quote changing to 1,097,894,234 after the real trade. These test-fixture integers are not substituted for the distinct RPC-fixture integers below.

Fix direction: correct the producer's evidence characterization and the originating invocation contract to distinguish empty selection from executed coverage. The independent execution gap is repaired by this report's receipt; the producer report itself was not edited. The verifier briefly advanced its ledger on exit status before reading the complete empty output, then reopened the item and required the actual PASS above.

Corrective acceptance: preserve both original empty-selection logs; label them as zero executed tests; cite `regression-final.log:3773` for the producer's actual named-case coverage and `verification/real-proxy-exact-signature.log` for the independent executed case. The command contract must select the exact ABI signature and require at least one executed PASS, not merely exit 0. No rerun of these unchanged passing cases is needed for this documentation correction.

## 2. Exact scope and source binding

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-02`.

Base and final HEAD: `90ff0307a7a8e084aa073e02eff125e9c7973933`.

Read the complete phase-two brief, complete `pricing/implementation-handoff.md`, `migration/quote-evidence.md`, the tracked implementation diff, all eight new Solidity files, applicable repository/testing/runtime instructions, baseline receipts, final regression receipts, and relevant canonical pricing/deployment dependencies.

`source-artifact-binding.json` enumerates all **17 authored Solidity paths**, their producer SHA-256, independently recomputed SHA-256, current size/mtime, and checked artifact identities. All 17 matched. The nine tracked changes and eight new files are:

| Group | Inspected files |
| --- | --- |
| Weighted hook, tracked | `UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol`, `UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol`, `UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol`, `UniswapV4StandardExchangeWeightedBufferHookTarget.sol`, `facets/UniswapV4StandardExchangeWeightedBufferHookHooksFacet.sol`, under `contracts/hooks/uniswap/v4/standardExchange/weighted/` |
| V3, tracked | `UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol`, `UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol`, `UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol`, under `contracts/vaults/standard/exchange/protocols/uniswap/v3/` |
| Declaration, tracked | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryFacet_IFacet_Test.t.sol` |
| New capture interface | `contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookCapture.sol` |
| New nested recipe | `contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol`, `contracts/utils/StandardExchangeFrozenQuoteLib.sol` |
| New migration primitive/fixture | `UniswapV4DetfMigrationSnapshotLib.sol`, `interfaces/IUniswapV4DetfMigrationSnapshot.sol`, `TestBase_UniswapV4DetfMigrationSnapshot.sol`, under `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/` |
| New test | `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshot.t.sol` |
| New local surface | `scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol` |

All are within the reviewed handoff plus the explicit local-script amendment. No unjustified out-of-scope implementation edit was found. Receipt-production files, ordinary DETF Target/Common, shared Crane, configuration, and lockfiles were not changed by this increment. Copied incident documents were already untracked, not inferred to be new implementation edits merely from Git's directory-level status.

Compiler metadata for nine relevant runtime artifacts plus the test and script artifacts was checked against current source keccak256 values: **599 unique dependency files, no mismatches**. The 17-source manifest, current artifacts, and actual successful build/test receipts were verified before relying on them. No stale-artifact rebuild was required. This is stronger than relying on artifact mtime alone.

`preservation.json` confirms the 17 sources, nine selected producer evidence files, and the original normal broadcast artifact remained byte-identical. Shared links still resolve to the primary checkout. The verifier's broadcast uses its own `verification/broadcast/` directory.

## 3. Admitted source/model configuration

Only the demonstrated newly composed local configuration is confirmed:

| Role | Address / support |
| --- | --- |
| One-shot consumer | `0x28dB1faE7d59B36aE6BBB939766F3F7F1c3eabec` |
| DETF subject and raw output | `0x0Db4a30BB8A6A1873455693a33d732DBF0ABF9E2`, 9 decimals |
| Weighted hook | `0xb85cBEDF5098cCD53152386980702FD4245C6aa8` |
| Manager / registry / fee oracle | `0xAa66038Ae217b246F5bF7537104342672e56fed8` |
| Original ETH quote pair | `0x9283F3Ff485698b26333120D2F24c0dDBfd5BF08`, 18 decimals |
| Original DTF quote pair | `0x536dA309fa11FEF8Fc8B94F5A9f7a608cdBbF3Ee`, 18 decimals |
| Pair A / pair B V3 SEs | `0x29103624cFf0c4FF93f41065b08aa5bA199bDFbE` / `0x6704e2474fdC91BB25e608F3B6FA50cEf9b80FE1` |

Both contribution-to-pair routes are identities. The zero-address ETH identity maps to fixture pair A, **not a demonstrated real WETH or historical recovery binding**. Both input hook legs use ordinary V3 pair-to-SE deposit recipes; the output is raw DETF. Each pair weight is 0.3 and the DETF weight is 0.4.

`StandardExchangeFrozenQuoteLib.sol:16-37` recognizes the complete runtime of the capture and ordinary-preview facets through immutable linked identity libraries. It does not accept a caller hash, self-reported model enum alone, or a ratio probe. Actual RPC bytecode matched current compiler artifacts exactly:

| Runtime | Bytes | Actual and artifact keccak256 |
| --- | ---: | --- |
| V3 capture facet | 15,973 | `0xeabe74daa04c5a71ad11f3acfbbf2fad08805e3981c261ba727a50044dc7d017` |
| V3 ordinary preview facet | 11,012 | `0xcfd76bca0a8a464e513d6917596967e20f3a2ae8c54ebb6fa31e644e56b2dc9a` |
| Pure weighted math | 6,481 | `0x5e563ee491931de428a1779e92c5c4df80833af85e7967fc68a49c947c97606a` |

Both recognized V3 facet artifacts have no immutable or link substitutions. These checks are not certification of arbitrary proxies with hostile replacement ERC20/pool/provider semantics. The actual composition, source routes, and installed production providers were inspected and exercised. The consumer's fee-oracle identity is a composition precondition; the library does not independently discover the DETF's private configured oracle.

**No ERC4626 receipt model is admitted.** SimpleYield, arbitrary receipts, native nested models, Morpho, nonzero-refund families, buffered output, and V3 conversion/redemption/transition/full-curve recipes remain unsupported. Real receipt-wrapper and conversion capture failures are tested atomically; their absence is not represented as universally supported behavior.

## 4. Pricing and dependency obligations

Paths below are relative to the worktree. `Migration` means `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`; `Hook` means `contracts/hooks/uniswap/v4/standardExchange/weighted/`; `V3` means `contracts/vaults/standard/exchange/protocols/uniswap/v3/`.

| Obligation | Observed evidence and conclusion |
| --- | --- |
| Original primary mint, not fallback | `Migration/TestBase_UniswapV4DetfMigrationSnapshot.sol:111-152` obtains pair conversion from real DETF `peekPairEq` and gross output from real hook `previewExchangeIn`. The independent executed test compares all intermediates and both originals. The preserved final suite also executes separate naturally open public-preview and closed-gate-not-fallback cases. |
| Pair order | `UniswapV4DetfProcessArgsLib.sol:112-133` inserts hook tokens excluding self in hook order; `UniswapV4DetfCommon.sol:157-181` resolves the first matching pair. `Migration/UniswapV4DetfMigrationSnapshotLib.sol:44-97` preserves that order and rejects nonidentity conversion rather than inventing support. |
| General exponent and integer order | Actual frozen trace calls quote balances with weights `3e17` and `4e17`, hence exponent `750000000000000000`. `Hook/...Math.sol:197-216` calls canonical `WeightedMath.computeOutGivenExactIn`; Crane `WeightedMath.sol:153-187` uses rounded base/exponent and `powUp`, not a 50/50 formula. Exact proxy results, not copied expected arithmetic alone, establish parity. |
| Fees and split | Uplift precedes the hook fee. The fee is `amount - floor(amount*fee/W)`, not `floor(amount*(W-fee)/W)`. Weighted budget receives fee zero after mapping. `DETFMintSplitLib.sol:19-26` floors the user amount independently. Actual tests cover the 1050-to-1047 residual, gross 3/p=50% user 1, p=0/W, fee=0/W, dust, overflow, and max-in equality/crossing. |
| Raw plus SE book | `Hook/...Target.sol:130-179` reads stored raw and attributed shares directly. At capture each pair had raw `4389004841283420869` plus `39350288425444029636` SE shares. Real hook `ratedBalances()` returned native pair totals `87780041509464641650`; those are the frozen trace's exact weighted input balances. DETF raw `100000000000` becomes WAD `100000000000000000000`. Raw cash is not confused with `nativeReserve()`'s SE-share inventory. |
| V3 nonlinear deposit | `V3/...InQueryTarget.sol:27-43` captures supply and `_totalVaultReservesForShareMath`; `...Common.sol:329-395` includes position amounts plus stored and unpoked fees. The frozen recipe uses `StandardExchangeConstantProduct._sharesForDeposit`, including ceil-before/floor-after square-root handling, at the post-fee amount. Real pool, donation, and supply mutations change the live oracle. |
| All-leg rating | `Migration/...SnapshotLib.sol:117-130` matches `Hook/...ClaimLib.sol:57-100`: every held leg is rated before input mapping. The third non-input leg is not dropped. Missing, failed, malformed, zero, and unused-provider outcomes have current passing **unit-only** memory vectors; these are not claimed as hostile live-provider proxy tests. Actual live provider returns changed in RPC mutation readbacks. |
| Atomic unsupported capture | The consumer writes sealed bytes only after capture returns (`Migration/TestBase...sol:42-47`). The current suite's real unsupported conversion and real receipt-wrapper tests show empty bytes after rejection. Second capture reverts. No SUT mocks, etching, or storage injection were introduced. |
| Source independence | The mined capture trace contains static source reads and delegatecalls, with no source-mutating child CALL. Post-mutation evaluation has exactly eight child calls, all DELEGATECALLs to the independently matched pure weighted-math runtime. No hook, SE, fee oracle, registry, provider, pool, token metadata, or ERC165 lookup occurs during evaluation. |
| Same book / nonlinear grouping | Current executed coverage checks zero/one/two components, checked sum, repeated immutable book use, and deliberately nonlinear merged/partial-input counterexamples. Components do not move reserves sequentially. |
| Routing and interfaces | Actual hook capture selector `0x7a2c747c` and SE capture selector `0xe13e2921` resolve to nonzero facets on the real proxies and are ERC165-supported. Registry package addresses are nonzero. Existing interface declarations remain, with separate added interfaces. The exact V3 declaration suite reports 5 passes. |

### EIP-170

Independently recomputed artifact runtime sizes: HooksFacet 13,095; weighted DFPkg 15,835; ClaimLib 11,627; V3 InQueryFacet 15,973; V3 DFPkg 6,386; consumer 9,893; math exposure 5,047; capture identity library 16,109; preview identity library 11,148 bytes. All are below 24,576. Actual admitted V3 and weighted-math runtimes were additionally matched through RPC. No code-size-limit bypass was used. This does not claim that a test/script driver itself must be deployable as an EIP-170 production contract.

## 5. Independent local transactions and readbacks

Owned Anvil command:

```sh
anvil --host 127.0.0.1 --port 18546 --chain-id 31337 --gas-limit 100000000
```

Port freedom was checked before startup and again in the startup wrapper. Unlike the producer's earlier gas-header attempts, this fresh node had a 100M genesis block gas limit immediately. It had no fork URL and did not disable EIP-170.

The requested script argv was executed with the explicit finite Forge simulation budget and separate broadcast directory:

```sh
export FOUNDRY_BLOCK_GAS_LIMIT=1000000000
export FOUNDRY_BROADCAST="$WORKTREE/docs/incidents/2026-09-16-dtf-recovery/migration/pricing/evidence/verification/broadcast"
forge script --use solar \
  scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol:MigrationSnapshotLocalQA \
  --rpc-url http://127.0.0.1:18546 --broadcast --unlocked \
  --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
```

`local-rpc-command.txt` gives the literal expanded environment and command; `.log` records `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL`; `-exit.txt` records command 0 and tee 0.

All **233 actual transaction receipts** were fetched again from the owned node, not merely trusted from the broadcast JSON. Every status is `0x1`, every sender is the dev account, and none is pending. The maximum actual transaction gas was **33,584,353**, not 1B. Consequently this execution does not prove deployment under a 30M block or an untested target-chain transaction cap.

Capture transaction:

```text
0x62ce38bce79510802c79b490e03103a80db58f16c79a705a6e43857ba2d68dc8
block 226; status 0x1; gas 3,842,683
snapshot ID 0x9a0c681ed4abfb538fb432a989bd5d2cc51f130d12b5c529960958de58cb8006
```

At capture, the independent real-source primary oracle and frozen evaluator agreed:

| Native integer | ETH original | DTF original |
| --- | ---: | ---: |
| Original / pair equivalent | 2000000000000000000 | 3000000000000000000 |
| Boosted at p=5% | 2100000000000000000 | 3150000000000000000 |
| Net after captured fee | 1995000000000000000 | 2992500000000000000 |
| Rated inflow | 1490988852592040823 | 2233681549914704346 |
| Gross DETF | 1255270181 | 1866950978 |
| User DETF | 1192506671 | 1773603429 |

The primary oracle queried real DETF pair conversion, the real fee oracle's p, and real hook gross output; only uplift and final integer split were composed off-chain. It did not call the new evaluator to obtain its expected result.

Historical readbacks were made after every script mutation:

| Block | Mined operation | Live ETH user | Live DTF user | Frozen sum |
| ---: | --- | ---: | ---: | ---: |
| 226 | Capture | 1192506671 | 1773603429 | 2966110100 |
| 227 | Real DETF trade | 1097893376 | 1721816343 | 2966110100 |
| 228 | Hook fee update | 1041001866 | 1633378825 | 2966110100 |
| 229 | Seigniorage update | 999661240 | 1566579720 | 2966110100 |
| 230 | SE donation | 954763526 | 1566579720 | 2966110100 |
| 231 | Approval | 954763526 | 1566579720 | 2966110100 |
| 232 | Real SE deposit | 933796731 | 1566579720 | 2966110100 |
| 233 | Registry disable | 1290890931 | 1566579720 | 2966110100 |

Approval is deliberately **not** counted as an effective price mutation. Donation and deposit changed both backing/provider results; SE supply changed from `141106982678455252304` to `144395541698518073785` across the deposit. Historical raw responses and snapshots are preserved in `rpc-historical-comparison.json` and `rpc-requests.json`.

The verifier then mined two additional local transactions:

- Registry re-enable: `0xa601cd936ba54c919d93a0a34f666b0f5d848639d428dc564c39e31b844ceb52`, block 234, status 1. The live ETH quote returned to 933,796,731; frozen sum stayed 2,966,110,100.
- Real SE cross-token swap through V3 pool `0x16Fbbf5e9843192B528Cbf90eAa314E7d9F8EaFa`: `0x0ba326dc3753135935b38a7b5f006cff31d146ae36e3d6f291bb5fe651573f0e`, block 235, status 1. It sent 1,000 pair-A tokens through the ordinary SE exchange surface using the dev account.

For that independent pool mutation, sqrt price moved from `79228160200691200081389370856` to `79229740007294059861815287900`; tick moved from -1 to 0; feeGrowthGlobal1X128 moved from 0 to `20416903791236560691237681870776`; provider rate moved from `2218287300213787191` to `2218314510298073999`; live ETH user changed from 933,796,731 to 933,789,506. Frozen sum and all **5,632 stored bytes** remained identical.

The separate evaluation trace after this pool mutation again contained only eight delegatecalls to the same pure weighted-math library. Combined evaluation trace gas was 451,403. `rpc-pool-mutation.json`, `rpc-capture-trace.json`, and `rpc-evaluation-traces.json` preserve the evidence.

## 6. Commands, exits, and accepted regression evidence

Every verifier shell command after runtime setup uses `verification/run.sh` or the same explicit environment: selected Foundry PATH first; owned TMPDIR; its `/node-cache` and `/bun-cache`. Forge and Anvil are 1.9.1-nightly, commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`; Solar is `0.3.0-dev+commit.e7a91fc7`. Every compiling command used `--use solar`.

| Check | Exact receipt / outcome |
| --- | --- |
| Baseline build, accepted | `../baseline/build-command.txt`, `build-exit.txt`, `build.log:1-6`: 5,793-file Solar build; command 0, tee 0 |
| Baseline weighted tests, accepted | `../baseline/weighted-command.txt`, `weighted-exit.txt`, `weighted.log:3849-3851`: 4 passed |
| Baseline nested V3 tests, accepted | `../baseline/nested-command.txt`, `nested-exit.txt`, `nested.log:50119-50121`: 4 passed |
| Current artifact-first build and regression run, accepted | `../implementation/regression-final-command.txt` contains the literal helper argv with all 17 Solidity inputs and exact test roots; `regression-final.log:1-3` contains the full expanded `forge build --use solar` and `forge test --use solar` argv. Helper/tee exit 0; compiler success at line 3528; actual 111 passes at line 3814 |
| Required original exact filter, independently run | `real-proxy-*`: command 0, tee 0, **zero executed tests; not PASS** |
| Exact ABI-signature case, independently run | `real-proxy-exact-signature-*`: command 0, tee 0; exactly 1 PASS |
| Required local script, independently run | `local-rpc-*`: command 0, tee 0; 233 successful mined receipts |
| Independent re-enable | `registry-enable-receipt-*`, raw send/receipt in `rpc-requests.json`: status 1; recorder 0/0 |
| Independent pool swap | `pool-swap-command.txt`, `.log`, `-exit.txt`: exact `cast send` with dev sender; receipt status 1; recorder 0/0 |
| Source/artifact checks | `source-artifact-binding.json`: 17 matching source SHA-256 values, 599 current dependency hashes, no checked metadata mismatch |
| Whitespace / recorder syntax | `initial-state-*` and `cleanup-*`: `git diff --check` and `bash -n` successful |
| Node stop / cleanup | `stop-node-*`, `anvil-exit.txt`, `cleanup-*`: all recorder exits 0/0; actual endpoint refusal and PID absence below |

The 111-test result comprises: weighted Swap 7; Scale 16; Fees 2; RefundCallback 1; OwnerDuringLock 6; SeBufferAbi 10; original weighted DETF 4; original weighted V3 DETF 4; receipt TransitionQuote 13; V3 FullRangeBook 18; V3 Previews 9; V3 InQuery declaration 5; snapshot main 14, decimals 1, receipt exclusion 1. Each count comes from the exact current final log, not a declaration of intended selection.

No passing current regression was needlessly rerun. Earlier implementation failures remain preserved and are not reclassified as current passes. The successful final source hashes and executed final suite supersede those earlier changed-source attempts.

Tool limitations: Bash language server and Biome are not installed; no installation was attempted. No clean fresh LSP claim is made. Producer Solidity diagnostics and their reported timeouts are preserved, not promoted to additional evidence. Runtime compilation, exact test execution, bytecode identity, and local RPC execution are the verification gates used here. An initial unrestricted Git status failed on the intentional Crane symlink (exit 128); the explicit `--ignore-submodules=all` scope inspection succeeded. A receipt queried immediately after re-enable submission was initially null; the existing transaction was awaited with a monitored `cast receipt`, not resent.

## 7. Cleanup and retained artifacts

Owned temporary root:

```text
/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/pricing-verify.stvrBy
```

Only the owned Anvil PID **81860** was signaled, after verifying it was the listener on 18546. Its recorder PID was **81858**. The Anvil monitor delivered natural command exit 0 and tee exit 0.

At **2026-11-10T15:30:59Z**, actual cleanup probes recorded:

- `ps` for PID 81860: exit 1, absent.
- `ps` for recorder PID 81858: exit 1, absent.
- Listener probe on 18546: exit 1, no listener.
- HTTP JSON-RPC probe: curl exit **7**, connection refused.
- Owned empty root removed with `rmdir`; `test ! -e` passed.
- Warm `out/` and `cache_forge/` retained.
- Shared `lib/crane` and `node_modules` links unchanged.
- HEAD unchanged and whitespace check clean.

All finite test/script/receipt monitors completed. No owned node, open port, pending transaction, child task, or temporary root remains. Verification evidence and its separately archived broadcast are retained intentionally. Normal phase-owned Foundry cache outputs were allowed; original implementation evidence and original broadcast were not overwritten.

## 8. Bounded confirmation versus E3

Confirmed behavior is limited to the specified real local source composition, exact admitted V3 runtime identities, direct original-to-pair routes, raw DETF output, and the executed integer/domain/mutation evidence. The primitive is not a final Migration lifecycle implementation.

Full task-2 actual-configuration E3 remains **not closed**: production recovery assets and ordered routes are not pinned here; the actual source proxies must expose the getters and admitted implementations; any reachable unsupported recipe needs its own authorized implementation/evidence; composition must bind the actual configured oracle; and target-chain deployment gas feasibility remains unproved. Existing immutable deployments are not upgraded by these source edits. Attribution, TokenStaking, surrender, activation, custody, and entitlement policy are outside this verification.

Final structured verdict is `verdict.json`: **needs-fix**, with bounded demonstrated pricing behavior confirmed, F1/F2 requiring root disposition, and full task-2 E3 explicitly unclosed.
