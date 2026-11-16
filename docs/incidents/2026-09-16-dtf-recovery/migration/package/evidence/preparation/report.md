# Five-path preparation implementation

Date: 2026-11-10.
Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`.
Base: `90ff0307a7a8e084aa073e02eff125e9c7973933`.

## DoneClaim

**PASS: the exact handoff section 5 preparation increment is implemented and consumed by ordinary production paths.** The prescribed focused scope executed **24 tests in 7 suites**, and the prescribed broad scope executed **9,932 tests in 589 suites**. Both commands exited **0**, with **0 failed and 0 skipped**. All three new deployment tests executed in both scopes. These are overlapping scopes, not 9,956 distinct tests.

The four production files and one deployment test are the only source/test changes. Every original deployment-test body and behavioral assertion remains intact. No Migration shell, issuer/setter, new selector, storage field, pricing integration, owner policy, pending-rights ledger, or unused permission hook was added. No attributable compiler/test failure remains.

This is preparation acceptance only. **E1, E2, full actual-recovery E3, BOOTSTRAP-AUTH, T5-EGRESS, E4/E5, and complete tasks 3/5 remain open.** No RPC, fork, broadcast, operational configuration, full Migration pass, or original-plan completion is claimed.

## Implemented production consumers

| Allowed path | Implemented change and preserved contract |
| --- | --- |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol` | Internal `_initialize` and private route-table storage extracted from the existing package. Caller supplies the actual fee oracle, fee classification, type declarations, bond package, and receipt package. No ordinary interface ID or child address is hardcoded into the library. |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol` | Existing canonical decoding delegates directly to the library. Constructor dependencies, external ABI, canonical rejection, salt, cuts, registry processing, and post-deploy bond/receipt/SY order remain unchanged. |
| `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol` | Ordinary `createFundedPosition` immediately calls the real `_createFundedPosition(principal_,duration_,recipient_)`. Its `onlyDetf synchronized nonReentrant` modifiers remain on the external entry. Validation, exact pull/stake, allowance clearing, gons attribution, timestamp/duration and event remain in the consumed body. |
| Same bond target | Implemented `internal view virtual _calculateClaim(uint256 tokenId_,uint256 gonsPerUnit_)` reads that ID's actual position and calls the existing linear math at `block.timestamp`. Preview and execution call it after their existing existence/reserved checks. `_claim` is now virtual and otherwise preserves authorization, debit, payout, retirement and funding checks. No no-op permission hook exists. |
| `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol` | `fundRewards` calls implemented virtual `_distributeRewards(storage,amount,resolvedFeeRecipient,resolvedCreatorRecipient)`, returning the real allocation/growth from `Repo._distribute`. Authorization, exact backing pull, current reserved-NFT owner lookup, distribution, weight top-up, event and immediate ordinary receipt destinations retain their order. |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Deploy.t.sol` | Three real registry-proxy initialization regressions added; the three existing tests are unchanged. No SUT mock, subclass, storage injection, fake issuer or fabricated lifecycle state was added. |

The initializer preserves hook-shape/liquidity/self-leg-owner validation, creation/opening validation and fallback, ERC20/EIP712 metadata, contents and declarations, thresholds/closure-rate resolution, core once-only hook guard, child metadata, route modes, hook sets/rates, mint/burn/bond/donate tables, basic-vault contents and `ThresholdsConfigured`, in their original order. The extraction does not change the existing core repo or math.

## Why the new assertions are necessary

The original deployment file checked dual-hook rejection, obsolete payload rejection and four inert/wiring getters. Existing route suites check ordinary default mint/burn/bond tables, while ordinary claim/accounting suites already exercise the funded economics. Those assertions were retained rather than duplicated or weakened.

| New test | Missing state/wiring contract and credible regression |
| --- | --- |
| `test_deploy_parentMetadataDeclarationsAndDefaults` | Checks parent name/symbol/9 decimals, EIP712 domain, default thresholds, creation-to-opening fallback, hook liquidity policy, exact declared fee/types/contents and default donation union. Dropping metadata/declaration writes, changing contents order, omitting the hook from contents, or losing donation-union storage now fails through the real proxy. |
| `test_deploy_customRoutesMetadataAndChildBindings` | Uses distinct mint, burn and ordered bond rows plus a valid donation subset, explicit rates/thresholds, explicit child names and a separate creator. Checks modes and full rows, prediction/deployment equality, inert wired state, bond parent/LP/reserved owners/metadata, receipt prediction containing the actual bond/oracle/package arguments, receipt parent/metadata/empty funded state, and distinct raw/staking SY backing modes. Dropping/crossing a table, ignoring explicit child metadata/creator, or misbinding a child now fails independently of helper names. |
| `test_deploy_sameArgsPreserveFundedStateAndNoInitializerRouting` | Creates a genuine paid bond, redeploys identical args through the registry and checks the same parent, live state, supply, child identities and complete staking state. Checks absence of package init/postDeploy, temporary postDeploy hook and diamond-cut selectors on the completed parent. A reset or accidentally retained initialization route now fails. |

These are ordinary deployment tests, not failing-before Migration acceptance tests. Their expected values come from fixture arguments, public wiring contracts, and the prior funded state, not source-string checks.

## Exact executed commands

Both commands ran once after all four production edits and the deployment assertions were in place. `run.sh` preserves the exact argument arrays and logs the expanded literal command. The helper's raw output includes its concrete `forge build --use solar ...` and `forge test --use solar ... --skip ...` commands. Configured source/test/output paths and profiles were not changed.

Environment:

```sh
export PATH="/Users/cyotee/.foundry/bin:$PATH"
export TMPDIR="/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/preparation-runtime"
export XDG_CACHE_HOME="$TMPDIR/xdg-cache"
export BUN_INSTALL_CACHE_DIR="$TMPDIR/bun-cache"
export npm_config_cache="$TMPDIR/npm-cache"
export PYTHONDONTWRITEBYTECODE=1
```

Focused command, captured without output filtering in `focused.log`:

```sh
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03
python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol \
  contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol \
  contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Deploy.t.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Weighted.t.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Weighted_Univ3Se.t.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_BondNftPackaging.t.sol \
  --test-root test/foundry/spec/vaults/detf/common/bondNft/DETFNFTVault_Surface.t.sol \
  --test-root test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimToken_Accounting.t.sol \
  --test-root test/foundry/spec/vaults/detf/common/claimToken/FundedStakingSequence.t.sol \
  -- -vv
```

Broad command, captured without output filtering in `broad.log`:

```sh
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03
python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol \
  contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol \
  contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf \
  --test-root test/foundry/spec/vaults/detf/common \
  -- -vv
```

| Receipt | Actual result |
| --- | --- |
| `focused.log`, 2026-11-10 16:29:39-16:29:46 UTC | 107 build roots, 586-source closure, 104 runtime artifact IDs. Artifact build compiled 35 files successfully; test compilation compiled 7 successfully. **24 passed / 0 failed / 0 skipped; exit 0.** |
| `broad.log`, 2026-11-10 16:30:09-16:31:40 UTC | 265 build roots, 1,253-source closure, 276 runtime artifact IDs. Artifact build reused current outputs (`No files changed, compilation skipped`); test compilation compiled 678 files successfully. **9,932 passed / 0 failed / 0 skipped; exit 0.** |

Focused counts by suite: deployment 6; weighted 4; production Uniswap V3 SE weighted 4; bond packaging 2; common bond surface 3; receipt accounting 3; funded sequence 2. The broad output also records `invariant_accounting()` with 256 runs, 16,384 calls and 0 reverts. Test declarations, fuzz cases and invariant handler calls are not conflated into one count.

Actual compiler evidence:

```text
forge Version: 1.9.1-nightly
Commit SHA: 430523103f3e2f9ba432ffdd2031a9f966153d0d
Build Timestamp: 2026-11-03T06:12:02.538056000Z
Build Profile: dist
Solar 0.8.38
artifact compiler: 0.8.38+commit.e7a91fc7.solar.0.3.0-dev
```

The configured `solc = "0.8.35"` was not edited; the actual Solar/compiler metadata above is reported rather than relabelled. Artifacts report optimizer enabled, one run and Osaka EVM. No via-IR flag was used.

## Ordinary production regression witnesses

- Actual ordinary parent bonding reaches exact-funded child creation. Existing `test_T7_10_laterBond_joinUnbalanced_unboostedG` checks exact principal, position gons, backing and supply deltas; the common funded sequence checks two independent escrows and retirement.
- Existing `test_preMaturity_principalVestsLinearly` checks zero principal at purchase and exactly half principal halfway through stored terms. `test_claimRewards_whileLocked` checks reward preview equals payment, no principal debit and no repeat reward. Mature-claim suites retain funded sDETF payouts.
- Bond packaging/common surface suites verify all three guarded transfer selectors on the assembled proxy and execute actual transfers/approval/receiver guards.
- `test_sameBlockFundedRewardsUpdateGonsButUnsolicitedBackingDoesNot` checks unchanged holder gons, funded index growth and uncredited unsolicited backing. `test_reserveTradingCannotReduceFundedPrincipalAndFullExitRetiresOnlyOwnFraction` checks full withdrawal and other holders' preserved gons.
- Broad fee/creator suites execute `test_FC_fundedTwoWavesMatchIndependentFloors`, `test_FC_explicitCreatorReceivesSeparateFundedIncome`, zero-creator fallback, reserved-role second-claim rejection and standing-right preservation after fee-oracle rotation.

These witnesses use the existing ordinary registry-proxy fixtures, not an impersonated Migration parent or an arbitrary-credit issuer. No existing economic assertion was changed.

## Exact source manifest and scope proof

`source-manifest.json` records full paths, final SHA-256/Keccak-256 and original SHA-256 for the four existing files. Final SHA-256 values:

| File | SHA-256 |
| --- | --- |
| `UniswapV4DetfInitializationLib.sol` | `6e3a8c25dad4c01ca1e0b517ebe365b8340520237ca8bc269a9ac3eceb94af7c` |
| `UniswapV4DetfDFPkg.sol` | `14112eb68aac3f67bcbae5d41d1a5e76fe3b526033f6dab782df5c1d396b899d` |
| `DETFFundedBondTarget.sol` | `ff3c95b45adec74973aabcb874be2a8d86aa79a9af8770949b0b7e635fbcc360` |
| `StakedDETFTarget.sol` | `fed9bd4bf324c8e1c3d71e1809c3ae516320d05beb580085b2deedb83bb24f82` |
| `UniswapV4Detf_Deploy.t.sol` | `d1a4a227847c32bb5b5f3a4b97d9fed8114d2fca47c4c4ff0106b8332248b41e` |

`baseline-scope.log` and `final-scope.log` contain literal read-only Git commands and SHA-256 inventories for **5,207 tracked source/test/script/rule/config files**. Comparison found exactly the four allowed existing-file changes; **5,203 files were unchanged**. Final status independently lists the one new allowed initializer library. `source.patch` contains the complete four tracked diffs. `git diff --check` exited 0.

The initial status showed pre-existing untracked package reports. They were preserved. All authored reports, manifests, evidence tools and generated receipts from this task are under this `preparation/` directory. No dependency/configuration, shared Crane, other lane, upstream report, commit or public-action change was made. Warm artifact/cache writes are the authorized compilation outputs, not extra source changes.

## Actual artifact binding

The fixture's package factory loads `UniswapV4DetfDFPkg.sol:UniswapV4DetfDFPkg`; its facet factories load the named ordinary product, V4 bond and receipt artifacts. `inspect-artifacts.mjs` reads those actual current JSON files, checks nonempty creation/runtime code and compares compiler metadata source Keccak hashes with independently executed local `cast keccak` results for the changed sources.

`artifact-bindings-success.log` records exact artifact SHA-256, compiler/target/settings, link references, byte counts and equality results. The package binds both changed package and initializer source hashes; the V4 and common bond facets bind the changed funded target; the receipt facet binds the changed staking target. **All bindings matched; audit exit 0.**

| Actual artifact | Creation / runtime bytes | Artifact SHA-256 |
| --- | --- | --- |
| `out/UniswapV4DetfDFPkg.sol/UniswapV4DetfDFPkg.json` | 17,128 / 16,298 | `12d7e10da4040c1b8dab6b6cfdd0f09f30b26396930af7d0ea924b64459a420c` |
| `out/UniswapV4DetfBondNFTVaultFacet.sol/UniswapV4DetfBondNFTVaultFacet.json` | 8,744 / 8,726 | `14b3b52e2c5fe4109691cb0607a81b8ff9479e409079c25adc51ce11c89da669` |
| `out/RebasingClaimTokenFacet.sol/RebasingClaimTokenFacet.json` | 6,115 / 6,097 | `a059fd6fca4d75e40f5683a1d46148ccd876c383ecb5a85d79210cfa5c745f32` |
| `out/DETFNFTVaultFacet.sol/DETFNFTVaultFacet.json` | 8,732 / 8,714 | `ac747ced538a6dde143ba8cb30ed9d7551d32a8b891a923c926a14adb56efcd5` |

The receipt also records all five ordinary parent facets. The new initializer is internal code consumed in the package, not an externally linked deployment hook. Fresh hermetic fixtures loaded refreshed local artifacts; no occupied live CREATE3 identity was treated as upgraded.

## Diagnostics and corrected tooling failures

`diagnostics.md` records exact Native requests/results. The four production files returned no diagnostics. The deployment file initially timed out, then returned the existing mutability warning on its unchanged inert-state test. Evidence-script diagnostics were clean; Bash and Biome/JSON servers were unavailable and were not installed. Compiler/lint warnings remain visible in both raw suite logs; no warning was suppressed.

No test failure, pre-existing or attributable, occurred in either prescribed scope. Existing warning-bearing statements and synchronization order were retained; warnings are not represented as a warning-free build.

Non-test tooling failures were corrected or explicitly bounded:

1. Initial plain `git status --short` exited 128 because shared `lib/crane` is intentionally a symlink. Repeating the read-only status with `--ignore-submodules=all` succeeded; no link or Git configuration was changed.
2. A monitor request with a four-hour `timeout_ms` was rejected by tool validation before any command started. Both actual suites used persistent completion subscriptions without that deadline.
3. The first artifact-audit launch mistakenly used the bundled OmO `process.execPath`, not standalone Bun. `artifact-bindings.log` preserves `internal_key_unavailable` and shell exit 137. The corrected command used verified `/opt/homebrew/bin/bun` version 1.4.2 and exited 0; it did not rerun either suite. The failed PID 29253 is absent in `cleanup.log`.

The successful artifact-audit command was:

```sh
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03
/opt/homebrew/bin/bun docs/incidents/2026-09-16-dtf-recovery/migration/package/evidence/preparation/inspect-artifacts.mjs
```

## Resource and cleanup receipts

Root's `PACKAGE_WARM_SEED_READY` confirmation was supplied before compilation. Initial inspection found populated `out/`, `cache_forge/` and the pre-existing read-only-use Crane/node_modules links. No seed, install, link replacement or cache deletion was performed.

| Owned execution | Receipt |
| --- | --- |
| Focused monitor `mon_5FT7VCKF71KXY49D`, `bash_5` | Normal completion, exit 0. |
| Broad monitor `mon_RXPSFHBR6VXVPRDD`, `bash_6` | Normal completion, exit 0. |
| First artifact-audit monitor `mon_N7G8P6E25J7NC755`, `bash_7` | Failed exit 137; output retained; failed process confirmed absent. |
| Corrected audit monitor `mon_E0R8N0X87BNBNMFF`, `bash_10` | Normal completion, exit 0. |
| Finite status/hash/syntax/diff/CLI probes | Completed; the initial status exception is recorded above. No pending command remains. |
| Cleanup `bash_11` | Exit 0; raw receipt in `cleanup.log`. |

Only this task's empty runtime root and its three cache directories were removed using `rmdir`, after the commands had finished:

```sh
owned=/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/preparation-runtime
rmdir "$owned/xdg-cache" "$owned/bun-cache" "$owned/npm-cache" "$owned"
```

`cleanup.log` records `CLEANUP_EXIT=0`, absence of the failed audit PID, and retained `out/`, `cache_forge/`, `node_modules` and `lib/crane`. The parent temporary root belongs to root/other lanes and was not removed. No node, RPC client, listener, fork, new worktree or delegated agent was started for this increment. No manual kill was issued; tool-managed LSP/session infrastructure was left alone.

**Stop condition satisfied for this bounded increment:** consumed production extractions, justified real-proxy deployment regressions, both prescribed outcomes captured with no unaddressed attributable failure, exact source/artifact/scope receipts, and owned runtime cleanup. This report does not advance the Migration composition or unresolved policy gates.
