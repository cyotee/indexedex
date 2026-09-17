# CREATE3 salt correction validation

Status: implemented and validated. V1, focused V3, maintained-script V4, Crane compile, and the full V5 gate passed (32,199 passed, 0 failed, 0 skipped across 2,774 suites).

## Execution baseline

Snapshot: `/private/tmp/create3-salt-baseline-3k4ijum3` (sources, Git status/diffs, source hash manifest and Foundry configuration).

- indexedex starting HEAD: `ee7827f137e2a4d7d9a8fee65902f9ba930819bc`; working-tree status and staged/unstaged patches saved in snapshot.
- crane starting HEAD: `d87c74b76ad30f6055211e6a37089c600d3ab3c3`; working-tree status and staged/unstaged patches saved in snapshot.

V1 passed before code edits: all 96 preserved source hashes match; production fingerprint `c9daacfcc2e45ded8c47124373254928dd668b1611e1851204e695c74eca3b14`; test fingerprint `468ebea45af71dc6e260907754e738ce4e74966f8d48b91093fa51023b811cbb`. FullSpread plan is implemented and validated; regression log ends with 654 passed, 0 failed, 49 suites, exit status 0. Original evidence remains read-only.

| FullSpread record | Baseline SHA-256 |
|---|---|
| `uniswap-se-v2-liquidity-leak-fixes.md` | `578eff51275fcd733a7d76bc3c5268843a598c374c27ecfa392cb13e3d14e358` |
| `uniswap-se-v2-liquidity-leak-fixes.plan.md` | `aae48421f8bb92ff7e3c7d3ad0f55d09a407e6579683ba0cd22fe9b4639ac2c6` |
| `VALIDATION.md` | `7633d7279ecee6dcec5518698cd8e58c27f56cae87b7acb591fdc7d5e9ba34c9` |
| `REGRESSION_RESULTS.txt` | `f4daf7e0066005c9ece5267297629ed608f7f653b8733836fb6c4e94d6384f31` |
| `VALIDATED_ARTIFACTS.json` | `4e3c3b2ed8083a2b51cd72dc8e8c21dd939f4a9e3c5a74b94492a41ad81c0036` |
| `VERSION_SOURCE_MAP.json` | `bf6ed31e5f22a1fc38140ba6b192f7979a3ac0af36855f866ca3d0835748c7db` |
| `PRESERVED_SOURCE_SHA256.json` | `b025357a1ace781765c3d92c725dec66706f821c0db6e0f264a7bab7dbfcdf8d` |
| `PRESERVED_BUILD_CONTEXT.json` | `a90483bc2f3720060d36ade5c1118cd4fbfbfb148b85809e394b0612428d1459` |

Occupied salts retain existing deployments. Source changes do not upgrade live contracts or rerun constructors. No deployment, broadcast, migration, or registry repointing is part of this effort.

## Preservation check (implementation source review)

All eight original FullSpread evidence records remain byte-identical. The 96-source preservation manifest has exactly these two deployment-glue exceptions; all remaining 94 hashes match. No FullSpread vault economic/runtime implementation source changed. FullSpread component services also receive value-equal runtime `_hash()` style corrections.

| Deployment-only exception | Baseline SHA-256 | Current SHA-256 |
|---|---|---|
| `contracts/protocols/dexes/uniswap/v3/UniswapV3_Component_FactoryService.sol` | `8a552212359e93fd5c8183250aa50c24714b2cec88f93d17b36be1d7ffc37fd1` | `1130cf3be3490ff9a3586863b0b23e4574baf832de4693446dce4e1905442cd4` |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol` | `22836158f54fbcf62e7d7880a1d78ec7c9e428096515535529a02eab0f502f85` | `3f654202ccf6db81c45bedea03a2e1b179ec3f704ec6dbdcaacd3f05b320e9a7` |

Scoped diff against the entry working tree: `/private/tmp/create3-salt-baseline-3k4ijum3/implementation-working-baseline.patch`. Original root changes and FullSpread untracked files are preserved.

## Commands and results

All runs use the existing default Foundry profile, Solidity 0.8.35, optimizer runs 1, and `via_ir = false`. No cache/output directory was deleted. This is the existing warm checkout; no worktree was created. Root and Crane builds each have one writer to their own output/cache trees. RPC environment variables listed in V3–V5 are removed.

- V3 runner: `python3 /private/tmp/create3-V3.py`, exact implementation-plan V3 Python block with the inventory execution inputs. The first invocation raced the inventory JSON write and failed its input assertion before any Forge command. The next invocation successfully built 147 artifact files (145.00 seconds) and 12 test files (226.75 seconds), then Forge panicked during macOS system-proxy discovery inside the sandbox; no runtime result is claimed for that invocation. Log: `/private/tmp/create3-V3.log`.
- V3 rerun outside the sandbox: same command, log `/private/tmp/create3-V3-unsandboxed.log`. **107 passed, 0 failed, 0 skipped, 12 suites; exit 0.** All seven mandatory roots plus four directly affected extra suites ran. Compilation used the refreshed artifacts.
- Final V3 after crash recovery and the Stata fixture correction: `python3 /private/tmp/create3-V3.py`, log `/private/tmp/create3-V3-final.log`; **122 passed, 0 failed, 0 skipped, 15 suites; exit 0**. Artifact preparation reused the warm cache, and the one changed test source compiled in 42.36 seconds. All 13 inventory test roots ran.
- Crane default-profile compile-only first attempt: `forge build`, cwd `lib/crane`, no RPC environment. It caught a missing `using BetterEfficientHashLib for bytes` on the fork source's actual base contract; corrected that declaration and reran. Logs: `/private/tmp/create3-crane-build.log`, `/private/tmp/create3-crane-build-retry.log`. Retry passed: **exit 0**, 326 sources compiled in 634.82 seconds, compiler successful with warnings. The default build includes `test/foundry/fork/protocols/l2s/superchain/TokenTransferRelayer_Superchain.t.sol`; no fork setup or tests executed.
- V4 maintained scripts: `python3 /private/tmp/create3-V4-batched.py`, log `/private/tmp/create3-V4.log`; runtime preparation and compilation **exit 0**, 173 roots covered.
- V5 runner: `python3 /private/tmp/create3-V5.py`, exact plan V5 block, outside the sandbox for the same confirmed Forge limitation. Log `/private/tmp/create3-V5.log`. Initial result: default build and runtime-artifact refresh passed; full hermetic tests ran 2,773 suites with 32,198 passed and one failed, exit 1. Compilation took 15,606.42 seconds; a subsequent nine-file incremental compile took 41.42 seconds. The sole failure was the obsolete occupied-salt isolation assertion in `AaveStataNativeSY.t.sol`, corrected under AC25/D6. The final full gate rerun below passed after that correction.

The inventory JSON plus the plan's V3/V5 code blocks are the reproducible command inputs; all expanded artifact/test commands appear in the logs. No `forge script`, broadcast, fork setup or RPC call was executed.

## Salt vectors

`BetterEfficientHashLib._hash(bytes)` and Solidity `keccak256(bytes)` have equal values. The ABI-name column is the permitted runtime form and D14 constant form; raw and packed one-string names produce the different last column. Reproduced using `cast abi-encode "f(string)" <identity>` then `cast keccak <encoded-hex>`; raw column uses `cast keccak <identity>`. The helper regression asserts constant/runtime equality and distinct identities.

| Identity | ABI-encoded name hash | Raw / packed name hash |
|---|---|---|
| `FeeCollectorDFPkg` | `0xfa70ebf1712c8ad974c3a340ae6dc56ecc439586284b6a9836e1930f0bab96b9` | `0xe96e424eb9e464a87f81ae43115b53bd0868330dc880f6f813405e0e68b135ae` |
| `RebasingAwareERC4626DFPkg` | `0xedff6ec896bbf38076c9101e91710e145b1f77f5d6d408c56620d4e92e101e49` | `0xe3db44df52c7aafd4023eafa971ca379ac7c6c6384065606276acfffcf975c81` |
| `RebasingClaimTokenFacet` | `0x0cf5b4a63a33bcfee102f5222be0b4ebba2bacaf4fdcdfb5e2072d16aab1b323` | `0x03938f848774d12a96257d424d7cee3bab98bed179abcbfe99cf6b209908daeb` |
| `UniswapV3FullSpreadStandardExchangeVaultDFPkg` | `0xfbc9b30829beb2b28c3b7f21ecd0d49f912c58d5b752d4e6e1651cd7c952644d` | `0xdda6d99808b0b1999a306b50991a39749a3093a77b8a3fe25462d771b4b3d9a3` |
| `UniswapV4FullSpreadStandardExchangeVaultDFPkg` | `0xbd81c01e6791be7769090198eee348de378441bd89da5dc43031406d24272250` | `0x7ef2054eb38808c7970b7504b49a8f8d1385c628e65556d7ab4cadbb9de95c63` |
| `ApprovedMessageSenderRegistryDFPkg` | `0xf0eda361b60e926642a8b5065d03d16befd2b4a48cc1f6b848e32cc8493d845f` | `0x86b3e9ea18f03bd709b4890cbf843d4581852688948597b341f58bf8ed3f98eb` |
| `SuperChainBridgeTokenRegistryDFPkg` | `0x422dcf5eb1aa35038eec52f0b53cd66ef5d8c14c1e7e412dc89371b6ec17ac7a` | `0x4160e24b9f5d4d8f3b90c9b3d30d6165e709b0a8081e1578980c48e22ffab4c9` |
| `TokenTransferRelayerDFPkg` | `0x5ec0839833c8a41b259e375775035f697700edf2e6cafe2950401f1ade2800b4` | `0xecea3a4ff4aac2c7f2487dc3e8fa0a9f95cf616ffb0b0e28af8d601535fd6944` |
| `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol:UniswapV4SingleStandardExchangeBufferConstantProductHookMath` | `0x7f1a6c8fc166d22fcf32ea6dae19ab6b70718830d88e91997950f97b60439f87` | `0x579ad690a6cbc76b07f9c7de8452a38eff31951c11bcedeb3fd321f600a243fd` |

Source comparison confirms every edited existing production primitive call preserves all creation-code and constructor payload arguments in their original order. Proxy algorithms, `PkgArgs`, `calcSalt`, `processArgs`, and initialization sources are unchanged against the working-tree baseline.

## Focused producer coverage

| Suite | Tests | Result |
|---|---:|---|
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_FacetPackaging.t.sol:UniswapV4Detf_OccupiedFacetSalt` | 1 | ok. 1 passed; 0 failed; 0 skipped; finished in 47.97ms (19.87ms CPU time) |
| `test/foundry/spec/vaults/standard/sy/AaveStataNativeSY.t.sol:AaveStataOccupiedNamespaceTest` | 1 | ok. 1 passed; 0 failed; 0 skipped; finished in 47.67ms (16.22ms CPU time) |
| `test/foundry/spec/protocols/l2s/superchain/SuperchainBridgeInfra_Create3Salt.t.sol:SuperchainBridgeInfra_Create3Salt` | 3 | ok. 3 passed; 0 failed; 0 skipped; finished in 119.38ms (6.46ms CPU time) |
| `test/foundry/spec/fee/collector/FeeCollectorProxy_Selectors.t.sol:FeeCollectorProxy_Selectors_Test` | 6 | ok. 6 passed; 0 failed; 0 skipped; finished in 121.28ms (14.87ms CPU time) |
| `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Packaging.t.sol:RebasingAwareERC4626_Packaging` | 14 | ok. 14 passed; 0 failed; 0 skipped; finished in 228.27ms (88.98ms CPU time) |
| `test/foundry/spec/protocol/staking/rocket-pool/RocketPoolRETHStandardExchange_Core.t.sol:RocketPoolRETHStandardExchange_Core_Test` | 16 | ok. 16 passed; 0 failed; 0 skipped; finished in 243.96ms (30.70ms CPU time) |
| `test/foundry/spec/protocol/dexes/aerodrome/v1/AerodromeStandardExchange_DeployWithPool.t.sol:AerodromeStandardExchange_DeployWithPool_Test` | 12 | ok. 12 passed; 0 failed; 0 skipped; finished in 244.84ms (142.80ms CPU time) |
| `test/foundry/spec/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHook_Reentrancy.t.sol:UniswapV4OrbitalSwapHook_Reentrancy_Test` | 1 | ok. 1 passed; 0 failed; 0 skipped; finished in 261.48ms (973.76µs CPU time) |
| `test/foundry/spec/utils/foundry/ArtifactCreationCode.t.sol:ArtifactCreationCode_Test` | 12 | ok. 12 passed; 0 failed; 0 skipped; finished in 308.50ms (587.67ms CPU time) |
| `test/foundry/spec/vaults/standard/sy/AaveStataNativeSY.t.sol:AaveStataNativeSYTest` | 8 | ok. 8 passed; 0 failed; 0 skipped; finished in 362.72ms (73.12ms CPU time) |
| `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_LaunchCompatibility.t.sol:RebasingAwareERC4626_LaunchCompatibility` | 6 | ok. 6 passed; 0 failed; 0 skipped; finished in 408.93ms (338.17ms CPU time) |
| `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_LocalLiquidBuffer_H2.t.sol:UniswapV4StandardExchange_LocalLiquidBuffer_H2` | 1 | ok. 1 passed; 0 failed; 0 skipped; finished in 555.83ms (6.95ms CPU time) |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_FacetPackaging.t.sol:UniswapV4Detf_FacetPackaging` | 9 | ok. 9 passed; 0 failed; 0 skipped; finished in 599.96ms (150.82ms CPU time) |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Quad_ReserveDonation.t.sol:UniswapV4Detf_Quad_ReserveDonation` | 20 | ok. 20 passed; 0 failed; 0 skipped; finished in 801.88ms (765.91ms CPU time) |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Quad_IoTables.t.sol:UniswapV4Detf_Quad_IoTables` | 12 | ok. 12 passed; 0 failed; 0 skipped; finished in 801.97ms (292.44ms CPU time) |

Inventory H001/H002 are covered by `ArtifactCreationCode_Test`; nested FeeCollector namespaces by `FeeCollectorProxy_Selectors_Test`; independent salts by the Aerodrome/RocketPool/RebasingAware suites; DETF and stage negative controls by both contracts in `UniswapV4Detf_FacetPackaging.t.sol`; Crane bridge identities, public bindings, registration and reuse by `SuperchainBridgeInfra_Create3Salt`. Hook helpers additionally retain their existing affected suites in V3 and transitive suites in V5. FullSpread canonical salt assertions remain unchanged.

A subsequent source review found the equivalent wrong-registry negative fixture in `RebasingAwareERC4626_LaunchCompatibility.t.sol`; it now deploys its wrong-bound package under an explicit D11 key. Its original rejection assertion remains; it was added to the focused roots and is included in V5. The final V3 rerun includes this correction and passed all six launch-compatibility tests.

Static checks: all 117 current shared-helper calls (including four new test calls) have one argument; production namespaces use the ABI-encoded contract identifier. All six D14 constants and their complete source files are byte-identical to baseline. All seven explicitly named D11 composition/variant source files are byte-identical.

## Crane revision

Local branch `fix/create3-component-name-salts`, commit `dfc93a9bcf7bcb4376333a10c74d924417b2bfbe`: exactly the three superchain FactoryServices and the constructor-sensitive ERC20PermitDFPkg fork-fixture salt. Crane working tree is clean. IndexedEx `lib/crane` gitlink is staged at that revision. Nothing has been pushed.

Package-address changes may change downstream diamond predictions even with identical `PkgArgs`: `DiamondPackageCallBackFactory` already includes the package address in its existing prediction/deployment salt. Callers pass the corrected package address to the same API; no proxy formula changed. This observation does not apply to hook formulas that exclude the package address.

## Maintained-script compile gate

Passed after the initial full V5 result and the final focused rerun, with one root build writer. `python3 /private/tmp/create3-V4-batched.py`, log `/private/tmp/create3-V4.log`: runtime artifact preparation **exit 0**; all **173 maintained roots compiled, exit 0**, with 199 files compiled in 237.84 seconds. Compiler warnings remain; no script was executed. A read-only `forge-artifacts.py plan --all-artifacts --json` with all 173 `--consumer` inputs passed (exit 0; `/private/tmp/create3-V4-artifact-plan.json`); this establishes artifact discovery only, not compilation. The 173 affected maintained source roots include directly edited producers, stage libraries, and importing entrypoints. For V4, runtime preparation and script compilation are batched over the union of those roots to avoid repeating the same compiler-graph traversal 173 times. Every listed consumer is prepared before compilation; the profile, source/test paths, optimizer and artifacts remain unchanged. Script 24 is included, never executed. The separate Crane default build above supplies D13 evidence.

Reproducible equivalent of the plan's per-consumer V4 loop:

```python
from pathlib import Path
import json, os, re, subprocess
text = Path("docs/create3-release-salt-input-inventory.md").read_text()
inputs = json.loads(re.findall(r"```json\s*\n(.*?)\n```", text, re.S)[0])
roots = sorted(set(inputs["maintained_script_roots"]))
env = os.environ.copy()
env["FOUNDRY_PROFILE"] = "default"
for key in ("ALCHEMY_KEY", "ETH_RPC_URL", "BASE_RPC_URL", "ROBINHOOD_RPC_URL",
            "FOUNDRY_ETH_RPC_URL", "FOUNDRY_BASE_RPC_URL", "FOUNDRY_ROBINHOOD_RPC_URL"):
    env.pop(key, None)
prepare = ["python3", "scripts/forge-artifacts.py", "build", "--all-artifacts"]
for root in roots:
    prepare += ["--consumer", root]
subprocess.run(prepare, env=env, check=True)
subprocess.run(["forge", "build", *roots], env=env, check=True)
```

## Final source review

The final comparison uses the entry working tree, including its pre-existing changes, rather than HEAD. There are 110 changed existing Solidity files and one new hermetic test. The inventory execution inputs contain all 35 edited production sources; TestBases, tests, and scripts are classified separately. Eight original FullSpread records are byte-identical, 94 preserved sources retain their recorded hash, and the only two exceptions are the deployment services listed above. The FullSpread test-source fingerprint is unchanged.

Fingerprint algorithm: sort repository-relative source paths, form one line per file as `<SHA-256 of file bytes>  <path>\n`, then SHA-256 the UTF-8 concatenation. The implementation fingerprint covers the 111 changed/new Solidity sources, including Crane. FullSpread fingerprints use the exact path sets in V1.

| Source set | Final SHA-256 |
|---|---|
| Implementation source changes | `ab5d3905236f4a7b5e61765410c51ddd70db698f6334e33619fd5a650aca4253` |
| FullSpread production | `f6106ccd81b75dd7037c5f7163e30ab15ead71122db8ba82fc077a8402050b6d` |
| FullSpread tests | `468ebea45af71dc6e260907754e738ce4e74966f8d48b91093fa51023b811cbb` |

The complete per-file hash manifest and baseline-relative patch are saved in the execution snapshot as `final-audit.json` and `implementation-working-baseline.patch`. IndexedEx HEAD remains `ee7827f137e2a4d7d9a8fee65902f9ba930819bc`; the root implementation is uncommitted. Crane is committed and pinned as recorded above.

## Archived-source exception (D7)

Inventory S0496–S0502 covers `scripts/archive/foundry/sepolia/Script_04_DeployDEXPackages_BalancerV3.s.sol` and `Script_07_DeployTestTokens.s.sol`. Both import the absent relative `./DeploymentBase.sol`; the import and missing dependency are present in the entry snapshot too. These entries are **source-validated, compilation blocked**. No archive compile or runtime success is claimed.

S0502 changes the ERC20PermitDFPkg component salt from the contract name plus `"DemoRichToken"` to `abi.encode("ERC20PermitDFPkg")._hash()`. The artifact contract identity and `abi.encode(IERC20PermitDFPkg.PkgInit(...))` constructor payload are retained; there is no separate component prediction expression in this source. Its token proxy `optionalSalt` is unchanged. S0496–S0501 already use canonical name-only component salts and remain unchanged. This exception does not waive any maintained-source gate.

## Crash recovery and full-gate follow-up

After the reported system crash, no Forge or solc process remained. The preserved V5 log contains completed compilation, artifact refresh and the full test summary above. Existing `out/` and `cache_forge/` are retained. The sole failure is addressed by moving the Stata occupied-identity regression to a minimal `CraneTest` setup that installs the first payload before invoking the production helper; it now verifies exact address/runtime retention. All Stata lifecycle tests are retained. The inventory adds this source to V3.

Final V5 rerun: `python3 /private/tmp/create3-V5.py`, log `/private/tmp/create3-V5-final.log`, started after the final fixture correction, focused success and maintained-script success. **Passed: 32,199 passed, 0 failed, 0 skipped across 2,774 suites; exit 0.** The final default build compiled one file in 22.36 seconds; runtime-artifact refresh and the hermetic test compile reused the warm cache. Full test timing: 542.00s (15877.87s CPU time).

## Completion evidence

| Gate | Final result |
|---|---|
| V1 preservation prerequisite | Passed before edits |
| V3 focused regressions | 122 passed, 0 failed, 15 suites; exit 0 |
| V4 maintained scripts | Runtime artifacts prepared; all 173 roots compiled; exit 0 |
| D13 Crane default build | Fork source compiled without setup/RPC execution; exit 0 |
| V5 full repository | 32,199 passed, 0 failed, 0 skipped across 2,774 suites; build, artifact refresh and tests exit 0 |

No broadcast, deployment, fork test, RPC setup, migration or registry repointing was performed. The D7 archived callers remain source-validated with their pre-existing compilation blocker.

Completed log SHA-256 values (logs retained locally):

| Log | SHA-256 |
|---|---|
| `/private/tmp/create3-V3-final.log` | `a212a131beec03a8451c00575dec079b2a3980b221c82ba8a46d8b484dcc307b` |
| `/private/tmp/create3-V4.log` | `8d03c894bb051c022424be57be9bd35738a3cf3d39544d4152b05c71b981c000` |
| `/private/tmp/create3-V5.log` | `2cfab468b117a33346f608451bcfb657de72fbc3ed852863cedf1ecf07ecd9ed` |
| `/private/tmp/create3-V5-final.log` | `937325ff616c7d9e9b6bdb6cc8be1fd2d38c56ceb407fe5336d6f55ffe875651` |
| `/private/tmp/create3-crane-build-retry.log` | `7d510e87413b13e67982fa73ac07e94920c08c42efe000765816a9520fabbc64` |

Final working-tree fingerprints: the tracked HEAD diff includes staged and unstaged changes (including the Crane gitlink); porcelain status includes untracked paths. These describe the whole checkout, including pre-existing user work. Untracked implementation source content is covered by the source fingerprint above.

| Working-tree record | SHA-256 |
|---|---|
| Tracked HEAD diff | `a47a0721d5dfea2b070c244c74c5c13ba45e2c37b6a90260a469fc5e65fce4f7` |
| Porcelain status including untracked paths | `9a3f821c6de7af96778a18fb035a1e178cfc78331cbcef3015266cd9099919c1` |
