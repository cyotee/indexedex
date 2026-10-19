# Dependency remediation progress

Baseline: `0f82de7e8fab7e444d5eb4ae1d678a3851e2f5d0`.
Reference: [update-impact assessment](2026-10-19-update-impact.md).

## Owner constraints

- npm is authoritative; manifests and scripts must remain usable with Yarn.
- Stop and ask before application behavior changes or unresolved migration,
  removal, or tooling-policy choices.
- Retain TEVM and Voltaire, and retain TEVM's EthereumJS execution backend.
  The owner rejected the ZEVM-backed RC migration.
- Hardhat 3 and its coordinated plugin migration were explicitly approved.
- The owner confirmed no local Task Master use and explicitly approved retiring
  root Task Master/FastMCP and their three npm aliases.
  Checkpoint commits are explicitly authorized. No alert dismissals or pushes
  have been performed.

## Applied locally

- Documented npm/package-lock ownership and retained Yarn Classic compatibility.
  Root `test` invokes `forge test` directly instead of requiring Yarn internally.
  Removed the Yarn-only `packageManager` selector; no npm-only enforcement was
  added. npm updated the root Yarn compatibility lock alongside the npm lock;
  the root Bun lockfile remains unchanged.
- Updated frontend Next.js and eslint-config-next from 16.3.5 to 16.3.8,
  including aligned Next runtime/compiler packages.
- Updated Sharp from 0.35.4 to 0.35.5 and its native/libvips packages.
- The owner approved TypeScript 5.7.3 for both frontend workspaces. The
  @wagmi/cli 2.10.0 compiler-peer conflict is resolved without application edits.
- Updated direct frontend Vitest families to 4.1.11 and compatible Hono,
  glob, cache, browser-data and source-map dependencies within existing ranges.
  Nested TEVM Vitest 3 and its other incompatible pins remain.
- Updated scripts/node Vitest families to 4.1.11, esbuild to 0.28.2,
  fast-uri to 3.1.8, PostCSS to 8.5.31 and source-map-js to 1.2.2.
  Its compatible Vite 8 dependency tree also advanced; braces 3.0.3 remains.
- Updated compatible root HTTP, multipart, JWT, template, schema, glob and
  Babel dependencies. Both npm and Yarn locks include these resolutions.
  A final compatible SDK/utility resolution advanced MCP SDK to 1.32.1,
  FastMCP's Undici to 7.30.1, and Task Master's UUID to 11.1.1; this final
  root sub-batch passed a clean install, full npm dependency-tree validation,
  and offline library/SDK smoke checks.
- Pinned the TEVM root declaration to its current `1.0.0-next.149` version;
  no installed TEVM runtime package version or execution backend was changed.
- Preserved React pins, wallet root dependencies, Webpack alias,
  application code and the existing RainbowKit patch. Parent-required
  transitive changes are recorded in the lockfiles rather than overridden.

## Completed checks

| Check | Result |
| --- | --- |
| Refreshed GitHub open-alert inventory | 423; no added or closed IDs relative to the assessment |
| `npm test -- --help` and `yarn test --help` at root | Both exit 0 and invoke the same `forge test --help` |
| Framework resolution dry run | Exit 0, without force or legacy-peer-deps |
| Framework and Sharp lockfile resolution | Exit 0; version changes inspected |
| `cd frontend && npm ci --no-audit --no-fund` | Exit 0; RainbowKit 2.2.11 patch applied |
| App `npm run check`, after compiler and compatible frontend updates | Exit 0; lint has 0 errors and 78 warnings; app typecheck passed; 498 unit tests passed and 1 existing test skipped; 1 deployment-config test passed |
| Protocol workspace typecheck with TypeScript 5.7.3 | Exit 0 |
| Targeted framework/compiler `npm ls` | Exit 0; no reported peer conflicts |
| Full frontend `npm ls --all` | Exit 1: TEVM-related missing Webpack/Ink peers and Zod 3/4 conflicts, including WalletConnect consumers |
| scripts/node clean install and `npm test` | Exit 0; 20 tests passed across 5 files |
| Latest root npm clean install and full `npm ls --all` | Both exit 0; no npm dependency-tree problems; Husky prepare ran |
| Latest root offline library/SDK checks | Exit 0; 9 checks covering Axios, multipart, JWT, proxy trust, Handlebars, YAML, Babel and MCP/FastMCP construction/tool registration; no server started or network request sent |
| Latest isolated Yarn Classic frozen-lock install | Exit 0; lifecycle scripts intentionally not run for this compatibility check; legacy toolbox peer and mixed-lock warnings remain |
| IndexedEx production build | Exit 0; compilation, TypeScript, static-page generation and build traces completed with warnings |
| Initial IndexedEx deployment browser run | Exit 1 before browser launch: required Chromium headless-shell binary was absent; browser installation started, application assertions not exercised |
| IndexedEx deployment browser rerun after Chromium installation | Exit 0; 10 tests passed across desktop/mobile, with 12 DTF-only cases skipped by the existing deployment condition |
| DTF production build and browser suite before Coinbase update | Exit 0; 22 desktop/mobile tests passed |
| Root Express refresh validation | Clean install and full dependency tree exit 0; local HTTP smoke passed JSON/form parsing, repeated query parameters and route parameters |
| Yarn compatibility after Express refresh | Frozen-lock install exit 0 with scripts disabled; existing toolbox peer warnings remain; disposable directory removed |

The install emitted dependency deprecation and npm lifecycle-script coverage
warnings; none was suppressed or resolved by changing security policy. Biome
diagnostics were unavailable because Biome is not installed.

The compatible Express parent
refresh resolved Express 4.22.3, body-parser 1.20.8, QS 6.16.1 and
path-to-regexp 0.1.13 and passed the checks above.
A compatible Coinbase SDK/Axios refresh resolved SDK 1.59.0 and Axios 1.20.0,
adding the SDK's agent-base 6.0.2 and https-proxy-agent 5.0.1 dependencies.
Its full validation command exited 0: clean install, app checks (498 passed,
1 existing skip), protocol typecheck, both production builds, 10 IndexedEx
browser tests and 22 DTF browser tests. Existing warnings remain.
The read-only audit identified further compatible updates. Root tooling now
resolves ethers 6.17.0, Viem 2.57.7, Figlet 1.12.0, fflate 0.8.3,
@inquirer/editor 4.2.23, compatible BN.js 4.12.5/5.2.5 branches and WebSocket
updates. Clean install, full dependency-tree validation, offline API smoke
checks and an isolated frozen Yarn install all passed.

Frontend fast-copy advanced to 3.1.0 and the compatible hoisted ws to 8.22.0.
Its full frontend validation passed again: clean install, app checks, protocol
typecheck, both production builds, 10 IndexedEx and 22 DTF browser tests.
An attempted Vite/esbuild
resolution also downgraded the hoisted Vite 8 to 7; that lock-only experiment
was fully reverted before installation because a major change was not approved.
The two retained frontend leaf changes do not change Vite or TEVM versions.

Voltaire's separately ranged optional Effect copy advanced from 3.19.18 to
3.22.3, with no other lock entry changed. TEVM's exact Effect 3.18.1 pins remain.
A clean install passed, as did focused checks of Voltaire address conversion,
Effect success/failure execution, and preservation of TEVM's Effect 3.18.1.
The source investigation found no app imports of Voltaire; the production/browser
checks above stand for the unchanged application dependency paths.

## Static alert impact

Comparing the current local resolutions to the captured vulnerable ranges
marks **374 of 423 snapshot records as candidate-cleared**. GitHub's comma-
separated range clauses are normalized to semver conjunctions before comparison.
This includes the Express, Coinbase SDK, additional audit batches and the
Hardhat 3 migration and approved Task Master/FastMCP retirement. Hardhat's full
build compiled 1,449 Solidity files successfully before the retirement; retained
package versions did not change during removal.

| Manifest | Candidate-cleared records |
| --- | ---: |
| frontend/package-lock.json | 85 |
| frontend/apps/indexedex/package.json | 7 |
| package-lock.json | 127 |
| yarn.lock | 140 |
| scripts/node/package-lock.json | 14 |
| .opencode/package-lock.json (retired) | 1 |

There are 13 still-affected records in changed install roots and 36 unchanged
records in vendored manifests. This is a static comparison, not a fresh
audit of every new transitive dependency, not proof of exploitability, and not
374 closed GitHub alerts. Nothing has been pushed; GitHub's baseline remains
423. The paired npm/Yarn records are not independent vulnerability counts.

### Fresh npm audit

The root audit after retirement exits 0 with no vulnerabilities. The latest
frontend audit after the nested Vite repair and the previously recorded
scripts/node audit returned findings (npm exit 1). Counts include affected parent packages
and are not comparable one-for-one with the 423 Dependabot records:

| Install root | Low | Moderate | High | Critical | Total |
| --- | ---: | ---: | ---: | ---: | ---: |
| Root, after retirement | 0 | 0 | 0 | 0 | 0 |
| Frontend | 13 | 27 | 21 | 2 | 63 |
| scripts/node | 0 | 0 | 3 | 0 | 3 |

The frontend audit includes the isolated Voltaire Effect update and nested Vite
repair. TEVM's pinned Effect copy still triggers its advisory.

Frontend critical findings are the retained TEVM Vitest/Tinypool subtree.
Remaining automatic fix suggestions include the rejected TEVM RC backend
change, Wagmi 3, and framework/tool downgrades. These were not applied.
`fixAvailable: true` is not proof that a repair preserves the current runtime
or approved version policy. Hardhat was migrated with owner approval; Task
Master/FastMCP were subsequently retired with separate owner approval.

## Retained frontend EVM tooling

The owner chose **retain and repair** for TEVM and Voltaire. Their app dependency
declarations must not be removed as an alert-remediation shortcut.

The full dependency-tree check reports:

- `@tevm/webpack-plugin@1.0.0-next.148` lacks its `webpack >5.0.0` peer.
- `@tevm/cli -> ink-gradient@3.0.0` lacks its `ink >=4` peer.
- TEVM's Pastel/Zod-validation subtree requests Zod 3 but resolves Zod 4.3.6.
- Older WalletConnect/Reown `abitype` copies also request a Zod 3 peer while
  resolving Zod 4.3.6; removing TEVM alone is not represented as fixing these.

Searches found no TEVM/Voltaire references in 315 app, script and protocol source
files, or in inspected TypeScript, Next, Vitest and Wagmi configuration files.
The declared roots may still represent an intended tooling capability, so
removing them is an owner decision.

## Rejected TEVM execution-backend migration

Registry inspection identifies `tevm@1.0.0-rc.153`, with the corresponding
`@tevm/*@1.0.0-rc.151` family, as a repair candidate. It admits patched Vitest 4,
uses Effect 3.21.2, and updates the CLI to Pastel 4, Ink 7 and Zod 4-compatible
dependencies. This version satisfies the existing prerelease range, but range
acceptance is not enough to approve the runtime change.

| Runtime package | Current next.148 dependency | RC.151 dependency |
| --- | --- | --- |
| @tevm/evm | @ethereumjs/evm ^10.0.0 | @evmts/zevm 0.0.0 |
| @tevm/vm | @ethereumjs/vm ^10.0.0 | @evmts/zevm 0.0.0 |
| @tevm/common | @ethereumjs/common ^10.0.0 | @evmts/zevm 0.0.0 |

This changes the underlying EVM implementation; the owner chose to keep
EthereumJS, so this migration must not be applied.
The RC bundler packages also still pin Solc 0.8.35, so the candidate is not
represented as resolving the entire compiler/Tmp subtree.

Sources: exact npm metadata for the named versions, and the upstream
[runtime documentation](https://node.tevm.sh/introduction/what-is-tevm-node).

## Owner decision: upstream releases only

An ordinary peer-repair experiment added compatible Webpack 5, Ink 6 and Zod 3
peers without changing TEVM runtime versions. A clean install removed the
missing Webpack/Ink errors but did not resolve the Zod conflict. Moving the
shared Zod 3 peer to the frontend workspace root then failed strict dependency
resolution with:

```text
ERESOLVE could not resolve
@tevm/cli@1.0.0-next.148 requires zod ^4.1.11
pastel@3.0.0 requires peer zod ^3.21.4
@tevm/cli@1.0.0-next.148 requires pastel ^3.0.0
```

The unsuccessful peer additions were removed and the previously validated
frontend resolution restored, retaining the explicit TEVM version pin.
A clean install restored the matching installed modules successfully and
reapplied the existing RainbowKit patch (exit 0).
No force, legacy-peer-deps, overrides or custom backports were used.

The installed memory-client's source, distribution and declaration files have
no Vitest imports, despite declaring Vitest 3 as a runtime dependency. Solc's
SMT helper uses Tmp's `fileSync`/`removeCallback` interface. These findings help
scope possible dependency backports; they are not proof that replacement
versions are behaviorally equivalent.

Choices presented:

1. Evaluate version-controlled, package-specific overrides or patches with
   EVM, CLI and compiler compatibility checks, preserving the EthereumJS
   backend and Solidity compiler version.
2. Rely only on compatible upstream releases, leave these alerts explicitly
   unresolved until such releases exist, and continue other remediation.

The owner selected **upstream releases only**. No dependency overrides or custom
backports will be added to repair TEVM. Its incompatible upstream pins remain
explicitly unresolved; no alert is dismissed and the EthereumJS backend remains.
Independent remediation and production/browser validation can continue.
Completed checks stand unless their inputs change.

## Next owner decisions

The compatible batch is validated. Remaining changes require choosing migration
or ownership policies; no unresolved risk has been accepted on the owner's behalf.

- **Hardhat:** the owner-approved retention and migration is complete. The active
  config and retained tests now use Hardhat 3; the old config is historical.
  Independently vendored Crane and protocol toolchains were not migrated.
- **AI/MCP tools:** the owner approved retirement after the consumer assessment.
  Removal and validation are recorded below.
- **Wallet stack:** Wagmi/connector changes need a coordinated compatibility
  decision with RainbowKit and the retained patch, not blanket transitive overrides.
- **Vendored skills:** the OnchainKit template requires a framework/React migration;
  PMFI has a compatible ethers update but vendor refresh can overwrite local edits.
  Choose upstream refresh versus maintained local vendor changes before editing.
- **OpenCode lock:** the owner confirmed OpenCode is no longer used and explicitly
  approved deleting `.opencode/package-lock.json`. Shared skills and other
  `.opencode` content remain intact.
- **TEVM and no-fix packages:** upstream-only policy keeps unresolved pins and
  advisories open. Compiler-version changes remain gated. The nested Vite branch
  was repaired without changing either Vite major line.

### Hardhat migration preflight

The owner selected retention and migration, then approved an active config
matching current Foundry settings and reusing Crane's existing Lock fixture.
The migration is implemented and validated.

- Current root `hardhat --help` exits 1 with HH24, attempting initialization:
  there is no active root configuration, only `hardhat.config.ts.old`.
- Current upstream candidates are Hardhat 3.20.0, Foundry plugin 3.0.5,
  Viem toolbox 5.0.7 and Mocha/Ethers toolbox 4.0.0. The old
  `@nomicfoundation/hardhat-toolbox` name is not the documented Hardhat 3
  Mocha/Ethers replacement.
- Hardhat 3 needs an ESM project/config and explicit plugin registration.
  Root `tsconfig.json` currently emits CommonJS. The tracked generated
  `wagmi.config.js` and `test/hard-hat/spec/test/stubs/lock/Lock.js` are CommonJS;
  changing the root package module mode without handling them would break them.
- The only root Hardhat test source is the eight-case `Lock.ts` example. It
  references `Lock`, absent from root `contracts/`, while an existing fixture
  is available at `lib/crane/contracts/test/stubs/lock/Lock.sol`.
- The archived Hardhat config uses Solidity 0.8.30, Prague, optimizer 2000 runs
  and ethers-v5 TypeChain output. The active Foundry config uses Solidity 0.8.35
  and optimizer 1 run. Automatically restoring the archive or matching Foundry
  would choose different compilation behavior; neither is assumed authorized.
- Root Wagmi generation is separately incomplete: missing `addresses.json`
  and placeholder `../my-contract`. These are pre-existing findings, not
  migration fixes to invent. Independent frontend, scripts/node and vendored
  toolchains remain outside the root module migration.

### Hardhat migration implementation and checks

- Active `hardhat.config.ts` uses Solidity 0.8.35, Osaka, optimizer 1 run and
  no viaIR, matching `forge config --json`. The archive is retained.
- The root package is ESM; root TypeScript uses Node20 module resolution.
  The existing test and Wagmi JavaScript mirrors were regenerated as ESM.
  Wagmi's missing address file and placeholder path were not fabricated.
- Viem remains the active Ignition adapter. Ethers, Mocha, TypeChain and
  verification are registered individually alongside the Viem toolbox because
  the two complete toolboxes register conflicting Ignition adapters.
- Both toolboxes and their required peers are declared explicitly for Yarn.
  Old Hardhat 2 resolutions are absent. The initial npm peer conflict was
  resolved by pruning the obsolete stack before resolving Hardhat 3, without
  force or legacy-peer-deps.
- `hardhat --help` and the complete npm dependency-tree check passed.
  The clean npm install passed.
- The existing Crane Lock contract builds with the approved compiler settings.
  All 16 retained executions passed (eight TypeScript cases and their tracked
  JavaScript counterparts). `npm run typecheck:hardhat` passed after including
  generated artifact declarations and the promise-assertion types.
- An isolated frozen Yarn install passed, and its independently loaded graph
  resolved all 14 active Hardhat plugins. Remaining Yarn peer warnings concern
  the unchanged Task Master React subtree, not Hardhat.
- Full-source compilation exposed Foundry-style root-relative imports that
  Hardhat rejects by default. A small Hardhat-only remapping hook preserves
  those imports without editing production sources or changing shared Foundry
  remappings/metadata. The full build compiled 1,449 Solidity files successfully
  with solc 0.8.35 and Osaka; existing compiler warnings were not suppressed.
- After explicitly configuring Hardhat 3's default and node networks, the Yarn
  test script passed all 16 executions and TypeScript passed again. An offline
  smoke check verified compiler settings, default local-network settings,
  Viem/Ethers account and provider parity, and the active Viem Ignition adapter.
- `lib/package.json` preserves the prior CommonJS boundary for vendored scripts
  lacking their own manifest. The Helixa script was checked with its credential
  variable explicitly removed: it loaded and stopped at its expected missing-key
  guard without any signing or network request. Independent package manifests
  still control their own module mode. The final full build/typecheck after
  this boundary addition exited 0, with no contracts requiring recompilation.
- LSP diagnostics repeatedly timed out; the successful TypeScript command is
  the available compiler evidence, not a claimed clean LSP result.

References: official Hardhat 3 migration, ESM migration and toolbox documentation;
exact npm metadata for the versions above. No broad Hardhat clean command was
run and Foundry's `out/` and `cache_forge/` were not modified.

### Approved Task Master/FastMCP retirement

After Hardhat migration, the root npm audit had 18 affected package entries
belonging to Task Master/AI SDK and FastMCP/file-type. The owner requested a
retirement assessment, confirmed no local use, and then explicitly approved
removal.

The assessment found only the `list`, `generate` and `parse-prd` npm aliases
as operational repository references. No local task database or Task Master
configuration was found. The Grok configuration explicitly denies its MCP tools.
FastMCP also belonged to Task Master's dependency tree, so both root declarations
must be removed. No first-party imports of the packages or their exclusively
owned transitive APIs were found within the root install boundary.

The two dependency declarations and three aliases have been removed from
`package.json`. Root npm/Yarn locks were refreshed. The npm lock lost 125
package entries, added none, and changed no retained package versions.
Other directly declared shared dependencies and external agent configurations
remain unchanged. The non-authoritative Bun lock remains deferred as before.

Validation completed:

- Clean `npm ci --no-audit --no-fund` and full `npm ls --all --json`: exit 0.
- `npm run test:hardhat`: 16 passing; `npm run typecheck:hardhat`: exit 0.
- Fresh root `npm audit --json`: exit 0, zero vulnerabilities, down from 18
  affected package entries after the Hardhat migration.
- Isolated Yarn Classic frozen-lock install: exit 0; its 14-plugin Hardhat
  graph loaded and both retired packages were absent. Lifecycle scripts were
  disabled only for this isolated compatibility check; its directory was removed.
- Manifest comparison verified exactly the two approved dependency removals
  and three alias removals. Neither package remains in either root lock.
- `git diff --check`: passed. Existing dependency deprecation warnings were
  not suppressed. No additional application or contract changes were made.

At the retirement checkpoint, the comparison marked 372/423 records
candidate-cleared locally, with 51 still affected or unchanged.
Frontend TEVM remains subject to the EthereumJS/upstream-only policy.

### Checkpoint and OpenCode lock retirement

Checkpoint commit `e14994ee` contains all verified remediation through Task
Master/FastMCP retirement. The owner then confirmed OpenCode is no longer used
and approved deleting its orphan lock, which has no corresponding manifest.
Only `.opencode/package-lock.json` was deleted; shared skills, plugins and
configuration were not removed. No application or dependency resolution changed,
so prior runtime checks stand.

Deleting the retired lock removes the local dependency record for snapshot alert
#686 (TOML), bringing the comparison to 373/423 candidate-cleared, with 50
remaining. GitHub closure is not claimed until the changes are pushed and
reprocessed. Nothing has been pushed and no alert has been dismissed.

### Nested Vite repair

The two nested Vite 7.3.5 copies now resolve 7.3.7, whose upstream dependency
range admits fixed esbuild 0.28.2. The existing top-level Vite 8.3.4 and
@wagmi/cli's separate esbuild 0.25.12 remain unchanged.

A temporary direct Vite 8.3.4 resolution constraint prevented npm from
downgrading the top-level branch. It was removed before installation; the
frontend manifest is byte-for-byte unchanged. Only the lockfile update remains,
with no overrides, backports, TEVM runtime, Effect or Solidity compiler changes.

Validation passed: clean npm install; app lint/type/unit/deployment checks
(498 unit tests passed, one existing skip); protocol typecheck; and TypeScript
transform/execution smoke checks through each installed Vite 7 copy. Existing
lint warnings remain. The fresh frontend audit no longer reports esbuild;
63 affected package entries remain, including the two retained TEVM critical
entries. Application sources and production framework dependency paths did not
change, so previous production/browser validation stands.

This clears snapshot #295 locally. Together with OpenCode retirement (#686),
the comparison is 374/423 candidate-cleared, with 49 still affected or unchanged.

## Remaining decision gates after checkpoint

Verified commits:

- `e14994ee`: checkpoint of all earlier verified remediation.
- `a11f9aa3`: owner-approved OpenCode lock retirement.
- `b6d50bdf`: nested Vite/esbuild repair without changing major branches.

### Wallet and Permit2: five snapshot records

Current npm metadata confirms Wagmi 2.19.5 is the newest version satisfying the
app's existing range. RainbowKit's current 2.2.11 release still peers Wagmi
`^2.9.0`; Wagmi 3.7.7 requires TypeScript >=5.9.3 and a coordinated connector
migration. A blind major update would violate the current RainbowKit contract.
The active UI exposes injected wallets, MetaMask, Rainbow, Coinbase and
WalletConnect, with explicit local-network restrictions. Its permission-before-
chain-lookup and immediate-rejection patch must be preserved or deliberately
ported with regression coverage.

Searches across 353 frontend source/config files found no Permit2 SDK imports.
`frontend/packages/protocol/src/permit2-signature.ts` uses Viem directly.
The SDK is the sole locked owner of ethers 5, which owns the Elliptic signing
dependency. Retiring the unused SDK is a separate owner approval; it could clear
the Elliptic record, but other wallet branches still retain vulnerable ws copies.
No direct frontend test of the named Permit2 hash helpers was found; no signing
implementation change is proposed as part of dependency retirement.

Choices: preserve RainbowKit and await a supported connector path, or authorize
a coordinated wallet UI/connector migration. Removing the unused SDK can be
reviewed independently; it has not been removed.

### Vendored OnchainKit and PMFI: 36 snapshot records

The checked upstream Bankr files still contain the same vulnerable Next 14.1.0
template and ethers 6.16.0/ws 8.17.1 PMFI lock. A refresh alone therefore does not
provide these fixes. `scripts/sync-bankr-skills.sh:57` deletes and replaces the
vendor tree; no patch reapplication mechanism exists.

The OnchainKit template contains only its manifest, Next config, README and
environment example. The README describes pages/components that are absent,
and its validation command only prints a message. A credible retained-template
migration must align Next/React/OnchainKit, update lint/configuration, and
validate a real generated scaffold rather than claiming the incomplete template
already builds. This requires a retain-and-repair versus retirement decision.

PMFI's ethers 6.17.0 update fits its current range and admits fixed ws. It needs
an explicit maintained-vendor-fix policy so the next refresh does not undo it.
Validation should use a clean isolated install, no-argument CLI/module loading,
and local ABI checks. Its transaction/dry-run paths are not suitable generic
smoke commands because they can contact Bankr or chain endpoints.

Recommendation: if these vendor assets are retained, maintain narrow reviewed
patches with explicit upstream provenance and checked reapplication during
refresh. Neither vendor package nor the sync script has been changed.

### Token-list glob dependency: one snapshot record

Braces remains at upstream 3.0.3 without a recorded fixed release. The generator
uses fast-glob only in `scripts/node/src/readFragments.ts:3`; its patterns are
fixed taxonomy paths ending in `/**/*.json`, not caller-supplied glob syntax.
That limits the observed input surface but does not remove the vulnerable
dependency or justify dismissing its alert.

A replacement must preserve recursion, hidden-file handling, symlink traversal,
deduplication and generated token-list output. Existing reader tests cover a
two-fragment fixture and a missing directory, not those edge cases. Recommend
a narrowly scoped replacement plus differential fixture checks, subject to
approval before changing this reader. No generator behavior has changed.

### TEVM: seven snapshot records

Fresh registry metadata still identifies `1.0.0-next.149` as the newest TEVM
next release. The current EVM package uses EthereumJS; the investigated RC EVM
uses ZEVM. The existing EthereumJS/upstream-only decision therefore remains
binding. Effect, Solc/Tmp and nested Vitest/Mocker/Tinypool constraints remain
unresolved, including the two critical frontend audit entries.

No further major migration, package retirement, vendor ownership change or
generator behavior change has been applied at these gates. No alerts have been
dismissed and none of the commits has been pushed.
