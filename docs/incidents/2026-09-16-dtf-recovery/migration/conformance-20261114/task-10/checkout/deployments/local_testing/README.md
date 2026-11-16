# `deployments/local_testing/`

Output directory for the local-testing deployment flow. Forge scripts under
`scripts/foundry/local_testing/anvil_single/` write their results here, the
shell driver at `scripts/shell/local_testing.sh` orchestrates the stages, and
the Node aggregator under `scripts/node/` reads the fragments emitted along
the way and produces the Token Lists the frontend consumes.

This document explains how to add a new deployment stage and how to add a new
class of tokens / pools / vaults so they end up in their own Token List bucket
that the UI picks up automatically.

---

## Directory layout

```
deployments/local_testing/
  anvil_single/                    # outputs for the default local-Anvil profile
    01_crane_foundation.json       # per-stage address registry (one file per stage)
    02_indexedex_core.json
    03_protocols_base.json
    05_foundation_packages.json
    06_foundation_assets.json
    10_scenario_1.json
    11_scenario_2.json
    fragments/                     # Token List fragment tree
      tokens/<key>.json
      pools/balancerV3/<key>.json
      pools/uniV2/<key>.json
      vaults/strategy/<key>.json
      vaults/erc4626/<key>.json
      ...
  runtime/                         # anvil.log and other ephemeral runtime files
```

Two kinds of output:

1. **Numbered stage JSON** (`NN_<name>.json`) — chain-keyed map of "logical key
   → deployed address". Read by later stages via `_readAddress` /
   `_readAddressSafe`, and merged by `synthesize_platform()` in
   `scripts/shell/local_testing.sh` into the UI's `platform.json`.
2. **Fragment files** under `fragments/<typeDir>/<key>.json` — per-token
   manifest entries. The Node aggregator buckets these by `typeDir` and emits
   one `<bucket>.tokenlist.json` per chain under
   `frontend/app/addresses/chain/<chainId>/`.

A stage usually writes both, but they're independent — a stage that only
deploys infrastructure (no on-chain assets) only writes the stage JSON.

---

## Implementing a new deployment stage

### 1. Pick an unused numeric prefix

`scripts/shell/local_testing.sh` matches stage artifacts with the glob
`[0-9]*.json` (see `purge_stage_artifacts`). The number drives ordering when
later stages read earlier outputs, and must not collide with another file in
`deployments/local_testing/anvil_single/`.

Before naming a new stage, list what's already taken:

```bash
ls deployments/local_testing/anvil_single/[0-9]*.json
```

Conventions in use today:

| Range  | Purpose                                       |
|--------|-----------------------------------------------|
| 01–03  | Foundation (Crane, Indexedex core, protocols) |
| 05–06  | Foundation packages and assets                |
| 10+    | Scenario overlays                             |

Pick the next free number in the band that matches the stage's intent. Two
digits is plenty; do not reuse a number from a different stage with a
different filename — the UI's chain-keyed `platform.json` is built by merging
every `[0-9]*.json`, so two files with the same logical role and different
names would both be merged in and the second one would silently shadow keys
from the first.

### 2. Add the Solidity script

Drop a new file under `scripts/foundry/local_testing/anvil_single/`:

```
scripts/foundry/local_testing/anvil_single/Script_NN_<Name>.s.sol
```

Inherit `LocalTestingDeploymentBase` (from
`scripts/foundry/local_testing/shared/`) — it provides:

- `_loadConfig()` — populates `deployer` and `owner` from env / sender
- `_readAddress(file, key)` / `_readAddressSafe(file, key)` — read keys from
  any earlier stage JSON in this directory
- `_writeJson(json, filename)` — write the stage JSON
- `_writeManifestEntry(typeDir, key, ManifestEntry)` — write a Token List
  fragment under `fragments/<typeDir>/<key>.json`
- `_logHeader`, `_logAddress`, `_logString`, `_logComplete` — consistent stage
  logging
- `_networkProfile()` — current profile string for embedding in JSON

Recommended skeleton:

```solidity
// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LocalTestingDeploymentBase} from "../shared/LocalTestingDeploymentBase.sol";
import {ManifestEntry} from "../shared/ManifestEntry.sol";

contract Script_NN_DeployMyStage is LocalTestingDeploymentBase {
    string internal constant ARTIFACT_FILE = "NN_my_stage.json";

    // Stage outputs go in state variables so _exportJson and _logResults can
    // both see them.
    address private myToken;

    function run() external {
        _loadConfig();
        _loadDependencies();

        _logHeader("Stage NN: My Stage");

        if (_loadExistingStage()) {
            _exportJson();
            _logResults();
            return;
        }

        vm.startBroadcast();
        _deploy();
        vm.stopBroadcast();

        _exportJson();
        _exportFragments();
        _logResults();
    }

    function _loadDependencies() internal {
        // Read addresses from earlier stage JSONs. Always require() on
        // anything you depend on — failures here are much clearer than failures
        // halfway through deployment.
    }

    function _loadExistingStage() internal returns (bool) {
        (address existing, bool ok) = _readAddressSafe(ARTIFACT_FILE, "myToken");
        if (!ok || existing.code.length == 0) return false;
        myToken = existing;
        return true;
    }

    function _deploy() internal {
        // ... deploy stuff, assign to state vars ...
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("myStage", "myToken", myToken);
        json = vm.serializeAddress("myStage", "owner", owner);
        json = vm.serializeAddress("myStage", "deployer", deployer);
        json = vm.serializeUint("myStage", "chainId", block.chainid);
        json = vm.serializeString("myStage", "networkProfile", _networkProfile());
        _writeJson(json, ARTIFACT_FILE);
    }

    function _exportFragments() internal {
        // See "Adding a new class of tokens" below.
    }

    function _logResults() internal view {
        _logString("Artifact:", ARTIFACT_FILE);
        _logAddress("My Token:", myToken);
        _logComplete("Stage NN");
    }
}
```

Idempotency note: every existing stage script implements `_loadExistingStage()`
so re-running on the same Anvil short-circuits before `vm.startBroadcast()`.
Match that pattern — `scripts/shell/local_testing.sh` calls earlier stages
again when running later ones, so they must be cheap when already deployed.

### 3. Wire the stage into `scripts/shell/local_testing.sh`

Two edits at the bottom of the script:

1. Add an entry to the `case "$COMMAND"` block (and any composite command
   like `scenarioN` that should run this stage).
2. Add a corresponding line to the `usage()` heredoc so `--help` advertises it.

Use the existing `stageNN`/`scenarioN` entries as a template — they all call
`run_stage <label> <script-path>`, which wraps `forge script` with the right
`--rpc-url`, `--sender`, `--unlocked`, `--broadcast`, and env-var passthrough.

### 4. Run the stage

```bash
# DEV_ADDRESS (or SENDER) must be set; see scripts/shell/local_testing.sh --help
scripts/shell/local_testing.sh stageNN
```

After every shell invocation:

- `run_aggregator()` rebuilds Token Lists from the fragments tree.
- `synthesize_platform()` merges all `[0-9]*.json` files into the UI's
  chain-keyed `platform.json`.

---

## Adding a new class of tokens (new Token List bucket)

The aggregator groups fragments into buckets by **type directory**. To
introduce a new class (e.g. a brand-new vault family the UI should show as its
own dropdown section), four pieces have to line up:

### 1. Pick a `typeDir` and `bucket id`

- `typeDir` is the filesystem path under `fragments/` (e.g. `vaults/myFamily`).
- `bucket id` is the filename stem the aggregator emits, used as the
  Token List filename: `<bucket-id>.tokenlist.json`.

Use kebab-case for the bucket id and camelCase for the leaf segment of the
type dir, matching existing entries (`pools/balancerV3` → `balancer-v3-pools`,
`vaults/strategy` → `strategy-vaults`, etc.).

### 2. Register the bucket in `tokenlists.config.ts`

Append to `buckets`:

```ts
{
  id: 'my-family-vaults',
  name: 'Indexedex MyFamily Vaults',
  keywords: ['indexedex', 'vault', 'myFamily'],
  includeTypeDirs: ['vaults/myFamily'],
  defaultTags: [],
  tagDefinitions: {
    vault: { name: 'Vault', description: 'Vault share token' },
    myFamily: { name: 'MyFamily Vault', description: '...' },
  },
},
```

`includeTypeDirs` selects which `fragments/<typeDir>/` directories feed this
bucket. A bucket may include more than one type dir, but a single type dir
should only feed one bucket.

### 3. Emit fragments from your deployment script

Inside your stage's `_exportFragments()`:

```solidity
string[] memory tags = new string[](1);
tags[0] = "myFamily";

ManifestEntry memory entry = ManifestEntry({
    chainId: block.chainid,
    addr: myDeployedToken,
    name: "Human Readable Name",
    symbol: "TOKEN",
    decimals: 18,
    tags: tags
});
_writeManifestEntry("vaults/myFamily", "<unique-key>", entry);
```

- The first argument is the **type directory** under `fragments/` — must match
  the bucket's `includeTypeDirs`.
- The second argument is a stable key within the bucket; it becomes the
  filename stem (`fragments/vaults/myFamily/<unique-key>.json`). Two stages
  writing the same `(typeDir, key)` will overwrite each other — pick keys that
  are unique across all stages.
- Tags should match keys in the bucket's `tagDefinitions` (or be added to the
  config when introduced).
- Fragment metadata is reconciled with on-chain state before emission:
  - `name` may be left empty (`""`) — `_writeManifestEntry` falls back to
    the token's on-chain `IERC20Metadata.name()`. Pass a literal string
    only when you want a display name different from what the contract
    returns on chain.
  - `symbol` may be left empty (`""`) — same fallback to
    `IERC20Metadata.symbol()`.
  - `decimals` is **always** read from `IERC20Metadata.decimals()`. The
    value passed in the struct is ignored — there is no way for a script to
    misreport a token's decimals.
  - If any required value can't be resolved (token doesn't implement
    `name()` / `symbol()` / `decimals()`, or the call returns empty), the
    script reverts with a clear message, so the aggregator never receives
    a fragment that would fail Token List schema validation downstream.

### 4. Re-run the aggregator (and the UI picks it up)

```bash
cd scripts/node && npm run build-tokenlists -- --config ../../tokenlists.config.ts
```

This is also invoked automatically by `scripts/shell/local_testing.sh` via
`run_aggregator()`, so the typical flow is just to re-run the relevant
`scripts/shell/local_testing.sh <command>`.

The aggregator emits, for every chain id it finds under
`deployments/<inputDir>/fragments/`:

```
frontend/app/addresses/chain/<chainId>/<bucket-id>.tokenlist.json
```

It also regenerates the UI's auto-discovery modules:

```
frontend/app/lib/tokenlistRegistry.generated.ts
frontend/app/lib/chainPlatformOverrides.generated.ts
```

These two files are the bridge to the UI — they scan
`frontend/app/addresses/chain/<id>/` and produce static imports for every
`*.tokenlist.json` and `platform.json` they find. Adding a new bucket needs
zero manual changes in the frontend; adding a new chain id only requires
dropping its files into a new `chain/<id>/` directory and rerunning the
aggregator.

---

## Adding a new chain id

If you want the UI to recognize a chain that isn't `11155111` (Sepolia) or
`84532` (Base Sepolia) today:

1. Add an `InputEntry` to `tokenlists.config.ts` pointing at the deploy
   directory that produces fragments for that chain:

   ```ts
   inputs: [
     { inputDir: 'local_testing/anvil_single', chainId: 11155111 },
     // ...
     { inputDir: 'my_new_target/anvil_single', chainId: 1234 },
   ],
   ```

2. Run the aggregator. It will create
   `frontend/app/addresses/chain/1234/<bucket>.tokenlist.json` for every
   bucket your stages emitted fragments into.

3. The generator (`scripts/node/src/generateRegistry.ts`) discovers the new
   `chain/1234/` directory on its next run and adds the chain to
   `tokenlistRegistry.generated.ts` and `chainPlatformOverrides.generated.ts`
   automatically. No edits to `tokenlistRegistry.ts` or `addressArtifacts.ts`
   needed.

Reusing an existing chain id (e.g. running a local Anvil fork of Sepolia under
`11155111`) needs no config changes — the aggregator overwrites the existing
`chain/11155111/` files with the latest deploy's contents.

---

## Filename collision rules of thumb

| File                                             | Must be unique across...          | Why                                                                              |
|--------------------------------------------------|-----------------------------------|----------------------------------------------------------------------------------|
| `anvil_single/NN_<name>.json` (stage artifact)   | All other `[0-9]*.json` here      | `synthesize_platform` merges every match; same key in two files = silent shadow. |
| `anvil_single/fragments/<typeDir>/<key>.json`    | All stages writing that `typeDir` | Overwrites are silent; aggregator just uses the last write.                      |
| `<bucket-id>.tokenlist.json` (config)            | All other buckets                 | Filename stem in `frontend/app/addresses/chain/<id>/`.                           |

When in doubt, prefix the fragment key with something stage-specific (e.g.
`scenario3_<thing>`) — fragment keys never leak into the UI; they just need to
be unique on disk.
