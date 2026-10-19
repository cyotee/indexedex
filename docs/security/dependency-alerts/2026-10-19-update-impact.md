# Dependency alerts: coordinated update impact assessment

Assessment date: **2026-10-19**. Repository: `cyotee/indexedex`. Baseline: `0f82de7e8fab7e444d5eb4ae1d678a3851e2f5d0`.

## 1. Decision summary

**Use separate update batches, not a blanket upgrade.** Start with the deployed Next.js patch and range-compatible critical leaves, then update pinned parent packages. Treat the wallet stack, TEVM and legacy Hardhat/AI tools as migrations where necessary. Keep vendored examples and local-agent tooling separate from the deployed application.

The live API snapshot contains **423 open alerts**, **226 distinct GHSA advisories**, **49 package names**, and **96 package/manifest combinations** across **8 manifests**. Severity: **17 critical, 167 high, 194 medium, 45 low**. These are alert records, not 423 independent vulnerabilities or 423 upgrade commands. Root npm/Yarn records overlap, and the active Next.js installation is reported through both its app manifest and workspace lockfile.

Every alert matched at least one current manifest or locked version against its recorded vulnerable range. None is classified as already fixed merely because another installed copy is safe. The OpenCode lockfile is orphaned from its package manifest, but still contains the vulnerable dependency.

| Static upgrade classification | Package/manifest combinations | Alert records | Interpretation |
| --- | ---: | ---: | --- |
| A: Range-compatible candidate | 50 | 235 | A nondeprecated, snapshot-safe target fits every recorded incoming range for the vulnerable copies. Still check Node, peers, install scripts and tests. |
| B: Parent/pin update | 14 | 59 | Same compatibility line, but at least one exact or narrow parent requirement blocks a leaf-only refresh. Includes the low-risk explicit Next.js pin update. |
| C: Migration | 26 | 123 | At least one vulnerable copy requires crossing a major or a 0.x minor boundary. Prefer changing the owning parent rather than forcing a transitive override. |
| D: No recorded patch | 6 | 6 | Elliptic, sprintf-js and braces have no patched release recorded for these advisories. Removal/replacement, upstream work or explicit residual-risk handling is needed. |
| **Total** | **96** | **423** | Each combination and alert counted once; mixed combinations use the most demanding classification. |

**Most useful early batches:** Next.js/eslint-config-next `16.3.8` plus Sharp `0.35.5`; Hono `4.13.7`; root Axios `1.20.0`, form-data `2.5.6`/`4.0.6`, proxy-addr `2.0.8`, Handlebars `4.7.10`; then the compatible glob/schema/CSS leaves. These are candidates derived from the snapshot and parent constraints, not upgrades tested in this review.

**Avoid misleading fixes:** app Vitest 4 does not remove TEVM's nested Vitest 3; top-level Viem does not remove WalletConnect's pinned Viem copies; a root npm update does not fix `yarn.lock`; a new Next.js version does not necessarily refresh its optional Sharp lock entry. Do not apply global latest-version overrides or `npm audit fix --force` as the remediation plan.

## 2. Evidence, scope and confidence

- [Complete alert snapshot](2026-10-19-alert-snapshot.json): authenticated GitHub REST retrieval at `2026-10-19T11:15:05.228Z`, five pages of 100/100/100/100/23 records; 423 distinct alert numbers. Includes advisory URLs, affected ranges, first-patched versions, severity and GitHub scope/relationship labels.
- [Upgrade evidence](2026-10-19-upgrade-evidence.json): 96 package/manifest groups with exact vulnerable node paths, direct parents and constraints, reverse paths to owning dependencies, candidate versions and blocking parents; 83 npm package-version metadata records with source URLs, dependencies, engines, peers and deprecation data.
- npm lock graphs were read from `packages` records using upward physical-path resolution, including workspace links. Yarn v1 selectors were parsed separately. npm dependency, development, optional and peer edges were retained; Yarn does not encode the complete peer graph, so parent ownership is supplemented by the npm graph and manifest declarations. Thirty-two absent Yarn selector targets are optional platform binaries, not alerted packages.
- Candidate versions are the lowest of the verified nondeprecated branch targets that are not in any recorded affected range for that package. They are security floors for this snapshot, not a claim to be the globally latest release or to clear newly published advisories. The per-alert original first-patched value remains unchanged in the snapshot.
- Static compatibility is distinct from exploitability. A GitHub `runtime` label can describe a tool's transitive dependency rather than shipped website code. No dependency was installed or upgraded; no resolution trial, build, exploit, browser test or transaction was executed for this assessment.
- The snapshot and reviewed GitHub Advisory Database ranges govern the proposed floors. Maintainer prose can be narrower or lag the reviewed database (notably Effect/esbuild/Next cache advisories); do not dismiss records on that basis without an explicit, evidenced decision.

### Installation and ownership boundaries

| Key | Manifest | Open alerts | Owner / installation boundary |
| --- | --- | ---: | --- |
| F | `frontend/package-lock.json` | 97 | Active npm workspace: shared IndexedEx/DTF app and protocol package. |
| A | `frontend/apps/indexedex/package.json` | 7 | Same Next.js installation as F; not seven additional installed copies. |
| N | `package-lock.json` | 127 | Root npm dependency tree: primarily developer/contract tooling. |
| Y | `yarn.lock` | 140 | Competing root Yarn Classic resolution tree. Keep it synchronized or deliberately retire it after choosing the supported installer. |
| S | `scripts/node/package-lock.json` | 15 | Independent token-list generator and its test toolchain. |
| T | `lib/bankr-skills/onchainkit/assets/templates/basic-app/package.json` | 34 | Vendored starter template, not the active frontend. Newly generated apps inherit its vulnerable Next.js pin. |
| P | `lib/bankr-skills/pmfi-parbitrage/package-lock.json` | 2 | Vendored operational Bankr script, separate from IndexedEx frontend. |
| O | `.opencode/package-lock.json` | 1 | Local-agent dependency lock; `.opencode/package.json` is absent. Establish ownership before restoring or removing it. |

Root `package.json` declares Yarn 1.22.19, while README installation instructions use npm. `bun.lock` also exists and still lists `oh-my-opencode`, absent from the current manifest. There are no open-alert records attributed to that Bun lock in this snapshot; this is not evidence that its dependency set is safe. Decide root package-manager authority before regenerating locks. The frontend and `scripts/node` are separate npm install roots and should not share arbitrary overrides.

The checked-in Foundry CI workflow runs no Node install or frontend test gate. Vercel's app configuration runs `npm install` in `frontend/`, then the app build (which includes lint), not the entire frontend check. Contract CI success therefore does not establish JS dependency compatibility. See `.github/workflows/foundry-ci.yml:43-80`, `frontend/apps/indexedex/vercel.json:4-5`, `frontend/NEXTJS_UPGRADE.md:14-64`.

## 3. Update groups and shared impact

Each alert has one primary group for accounting. Groups are not independent: the shared-parent edges below must be checked when sequencing them.

| Group | Update boundary | Alerts | Critical / High / Medium / Low |
| --- | --- | ---: | --- |
| G01 | Active Next.js and native image stack | 15 | 2 / 3 / 8 / 2 |
| G02 | Frontend wallet connectors and signing dependencies | 61 | 0 / 10 / 48 / 3 |
| G03 | TEVM, compiler, Effect and nested test tooling | 8 | 2 / 2 / 2 / 2 |
| G04 | Frontend lint, glob and CSS leaf dependencies | 20 | 0 / 15 / 5 / 0 |
| G05 | Root HTTP, multipart and authentication dependencies | 64 | 4 / 24 / 32 / 4 |
| G06 | Root Task Master, AI SDK and MCP toolchain | 16 | 0 / 10 / 4 / 2 |
| G07 | Root Hardhat, compiler, coverage and verification toolchain | 169 | 6 / 71 / 67 / 25 |
| G08 | Root Babel, wagmi generation and shared WebSockets | 18 | 0 / 8 / 8 / 2 |
| G09 | Token-list generator and its test tooling | 15 | 0 / 10 / 4 / 1 |
| G10 | Vendored OnchainKit starter template | 34 | 3 / 12 / 15 / 4 |
| G11 | Vendored PMFI ethers script | 2 | 0 / 1 / 1 / 0 |
| G12 | Orphaned OpenCode lockfile | 1 | 0 / 1 / 0 / 0 |

### G01. Active Next.js and native image stack

**Recommended small coordinated patch; highest priority for the deployed app.** Change `next` and `eslint-config-next` from `16.3.5` to `16.3.8` together. Refresh optional `sharp` from `0.35.4` to `0.35.5`; its `^0.35.4` range already permits the fix. Check the platform-specific `@img/sharp*`/libvips records after resolution. The critical Next ImageResponse advisory starts fixing at `16.3.6`, but all seven active-app Next advisories require the combined floor `16.3.8`.

Retain React, React DOM and both React type packages at their current aligned `19.3.0` unless a separate reason requires changing them. Next `16.3.8` accepts React `^19.0.0`; no React major migration is needed for this batch. Preserve the workspace overrides and `zod-validation-error` pin. Next/Sharp require Node >=20.9.0; the full frontend toolchain has higher constraints discussed below.

Preserve `--webpack` and the `@base-org/account$` browser-entry alias in `frontend/apps/indexedex/next.config.js:19-25`. A framework patch is not authorization to switch bundlers. Next's baseline-browser-mapping is a shared G04 leaf and should also resolve to >=2.11.0.

Likely code changes: manifest/lockfile pins only; update the version-specific frontend instruction/upgrade notes when implementing. Validate both deployment variants, route wrappers, image processing and wallet-dialog rendering. Sources: `frontend/apps/indexedex/package.json:29-32,52`, `frontend/package.json:28-41`; npm metadata for Next/eslint-config-next 16.3.8 and Sharp 0.35.5; GHSA-vcvr-r3jv-pc5j.


### G02. Frontend wallet connectors and signing dependencies

**Split the compatible Hono refresh from connector migrations.** `porto@0.2.35` and `0.2.37` both permit `hono:^4.10.3`; `4.13.7` clears all 36 Hono records. A Hono refresh does not require a Wagmi major upgrade. Whether each vulnerable server/JSX path is reachable in this application remains unproven.

Axios `1.16.0` is exactly pinned by `@coinbase/cdp-sdk@1.55.0`, reached through Wagmi connectors -> `@base-org/account@2.4.0`. CDP SDK `1.56.0` changes its Axios range to `^1.18.0`, so advancing this parent within its existing `^1.0.0` range can admit Axios `1.20.0`. Explicitly verify the resulting Axios resolution; 1.18.0 alone is insufficient. Preserve the SDK browser alias rather than accidentally bundling its server/x402 entry.

WebSocket copies require separate treatment. App Viem `2.56.3` already pins safe `ws:8.21.0`, but WalletConnect/Reown utils pin nested `viem:2.23.2 -> ws:8.18.0`. The top-level `isows` peer can resolve another unsafe `ws@8.18.3`. Permit2 SDK -> ethers 5 providers also pins ws 8.18.0. Refreshing app Viem alone does not fix these copies. Some permissive copies, such as Ink's `^8.18.0`, can refresh independently.

MetaMask SDK/communication packages require UUID `^8.3.2`, and MetaMask utils require `^9.0.1`; the recorded safe floor is `11.1.1`. WalletConnect's `query-string:7.1.3` requires `decode-uri-component:^0.2.2`; safe `0.5.0` is outside that range. `query-string@9.5.0` permits `^0.5.0` but is an ESM/Node>=18 parent migration, not a blind transitive substitution.

Wagmi 3 is not a drop-in solution: candidate `wagmi@3.7.7` requires TypeScript >=5.9.3, while the app uses 5.4.5. RainbowKit 2.2.11 peers Wagmi `^2.9.0`, and the protocol workspace peers `^2.19.5`. A Wagmi-major plan must align RainbowKit, connector APIs, protocol peers and TypeScript together.

No patched Elliptic release is recorded for the signing-key chain under `@uniswap/permit2-sdk@1.4.0 -> ethers@5.8.0`. Existing Permit2 code uses Viem directly (`frontend/packages/protocol/src/permit2-signature.ts:3-11`), and searches found no current source imports of permit2-sdk. Confirm generated/tooling use before proposing removal; do not remove it merely to reduce alerts.

Code/behavior checks: `app/providers.tsx`, connected-wallet and RainbowKit tests, transaction panels and protocol typing. The `frontend/patches/@rainbow-me+rainbowkit+2.2.11.patch` changes permission-before-chain lookup and immediate-rejection behavior. Keep the patch applying or deliberately port both behaviors with their regressions. Root WebSocket updates in G08 do not affect this install root.


### G03. TEVM, compiler, Effect and nested test tooling

**High-coupling TEVM subtree; direct Vitest patching is only partial remediation.** The app and protocol package use Vitest 4.1.8, which can update to 4.1.11 with its exact-version `@vitest/*` family. Separately, `tevm@1.0.0-next.149 -> @tevm/memory-client@1.0.0-next.148 -> vitest:^3.2.4` installs Vitest 3.2.6, Mocker 3.2.6 and Tinypool 1.1.1 as a runtime dependency subtree.

The nested floor requires Vitest/Mocker 4.1.11 and Tinypool 2.1.2. Both cross the nested parent ranges; replacing only `@vitest/mocker` or overriding Tinypool 2 into Vitest 3 is not a demonstrated compatible fix. The direct Vitest 4 update will leave these alerts open while the nested copies remain.

A verified upstream candidate is `tevm@1.0.0-rc.153`, which requests memory-client rc.151 (`vitest:^4.1.6`) and Effect 3.21.2. This can admit patched Vitest 4.1.11 and address older Effect pins, but it is a coordinated prerelease migration, not proof of complete remediation. Inspect every @tevm version/pin and test actual APIs before adopting it.

Current TEVM and ten @tevm parents pin Effect exactly at 3.18.1, blocking the 3.20.0 floor. The separate `voltaire` alias (`@tevm/voltaire@0.4.0`) permits Effect `^3.19.13` and can independently refresh its installed 3.19.18. Avoid globally forcing one Effect version through all packages.

Vite 7.3.5 pins the esbuild compatibility line to `^0.27.0`; its installed 0.27.7 needs 0.28.1. Vite 7.3.6 admits `^0.27.0 || ^0.28.0`, so use this parent update rather than unnecessarily jumping to Vite 8. Both current Vite lines require Node ^20.19.0 or >=22.12.0.

Tmp 0.0.33 is exactly pinned by Solc 0.8.30/0.8.34. Solc 0.8.37 uses Tmp 0.2.6, but some @tevm packages exactly pin Solc 0.8.30, and their reviewed RC line still pins 0.8.35. A TEVM RC update alone is therefore not an all-clear. This concerns the npm Solc tooling subtree, not authorization to change the production Foundry compiler pin.

Source searches found no current TS/JS imports of the umbrella TEVM/Voltaire packages. Confirm intended tooling and dynamic use, then choose between removing genuinely unused roots and doing the upstream migration. Retain a separate regression for any operational compiler/client usage. Shared glob refreshes remain in G04.


### G04. Frontend lint, glob and CSS leaf dependencies

**Low-risk resolution candidates within current ranges.** Refresh the affected copies of minimatch 10.2.1 -> 10.2.3; brace-expansion 5.0.6 -> 5.0.12 and 1.1.14 -> 1.1.21; picomatch 3.0.1 -> 3.0.2 and 2.3.1 -> 2.3.2; flatted 3.3.3 -> 3.4.2; browserslist 4.28.1 -> 4.28.7; baseline-browser-mapping 2.9.19 -> 2.11.0; source-map-js 1.2.1 -> 1.2.2.

Parents include TEVM ts-plugin/glob, ESLint 8/9 cache paths, @wagmi/cli, patch-package, Babel, Autoprefixer, Tailwind, PostCSS and Next. Preserve the separate major branches: one global brace-expansion 5 or picomatch 4 override would violate older consumers. Already-safe copies such as minimatch 10.2.6 and brace-expansion 5.0.12 do not prove the nested vulnerable ones are gone.

Expect lockfile changes rather than app code changes, subject to real install and lint/build/test results. Keep ESLint 9 and TypeScript 5.4.5 for this batch; do not fold unrelated major upgrades into leaf remediation.


### G05. Root HTTP, multipart and authentication dependencies

**Mostly small updates; shared with Hardhat and AI tooling.** Root ranges admit Axios 1.20.0, follow-redirects 1.16.0, form-data 4.0.6 and the separate 2.5.6 line, jws 3.2.3, and proxy-addr 2.0.8. Critical multipart and proxy-trust findings make these worthwhile early fixes even though the root tooling is not the deployed frontend.

QS is mixed: the MCP SDK's Express 5/body-parser branch permits a safe leaf refresh, while root Express 4.21.2/body-parser 1.20.3 pins qs 6.13.0 exactly. Express 4.22.3 admits qs ~6.16.0 and body-parser ~1.20.5. This stays in Express 4 and exceeds the snapshot QS floor 6.15.2; an Express 5 migration is unnecessary solely for these alerts.

Preserve both form-data branches. Version 2.5.4 is not a suitable final target (deprecated and below later advisory floors); use 2.5.6. Check multipart upload, proxy/trust configuration, redirects and JWT verification in the tools that actually use them. npm and Yarn must both reflect the fixes if both remain supported.


### G06. Root Task Master, AI SDK and MCP toolchain

**Separate compatible MCP refreshes from the Task Master/AI migration.** FastMCP 1.27.7 and mcp-proxy 2.14.3 permit MCP SDK 1.31.0 through their existing 1.x ranges. FastMCP also permits Undici 7.29.1 (counted in G07). SDK peers and the Node floor still need checking: MCP SDK needs compatible Zod ^3.25 or ^4, and Undici 7.29.1 needs Node >=20.18.1.

Task Master 0.13.2 requests AI SDK ^4.3.10, and AI 4.3.16 pins jsondiffpatch 0.6.0. The safe targets AI 5.0.52 and jsondiffpatch 0.7.6 are outside those constraints. Task Master 0.28.0 is a verified candidate moving to AI ^5.0.51 and FastMCP ^3.5.0; ensure it actually resolves AI >=5.0.52 and audit the new tree. This change also moves AI provider families and needs provider/configuration/MCP smoke checks.

Nanoid 3.3.12 fits the AI provider-utils range. UUID 11.1.0 -> 11.1.1 fits Task Master, but the same root alert also covers Hardhat's UUID 8.3.2, which needs G07 parent work. Root scripts expose `list`, `generate` and `parse-prd`; do not assume the tools are unused because application imports are absent. Test CLI/tool discovery without paid AI calls or external writes.


### G07. Root Hardhat, compiler, coverage and verification toolchain

**Largest coupled group, with both quick leaves and genuine parent migrations.** Hardhat 2.25.0 and its ethers/viem toolboxes own Undici 5, legacy Solc/Tmp, Sentry/Cookie, Mocha/serialize-javascript, ADM-ZIP, coverage templates, verifier schemas and cryptographic utility trees. Toolbox peers are part of the install graph even when Yarn v1 does not encode their edges.

Quick leaves: Handlebars 4.7.10, Immutable 4.3.9, js-yaml 3.15.2/4.3.2, minimatch 3.1.4/5.1.8, brace-expansion 1.1.21/2.1.7, fast-uri 3.1.8, AJV 8.18.0, diff 4.0.4 and pbkdf2 3.1.7 fit their applicable ranges. Handle these independently of the longer Hardhat migration. Most bn.js 4 copies permit 4.12.3, but ethjs-unit/number-to-bn exactly pin 4.11.6. Ignition Core exactly pins lodash 4.17.21. Use nondeprecated lodash 4.18.1 after resolving that parent constraint; 4.18.0 is a known bad npm release, and its deprecated fallback recommendation is vulnerable for this snapshot.

Blocked branches: Hardhat and Verify require Undici ^5.14.0, excluding safe 6.28.1; Undici 5 requires @fastify/busboy ^2.0.0, excluding 3.2.2. Hardhat requires adm-zip ^0.4.16, excluding 0.6.1, and UUID ^8.3.2, excluding 11.1.1. Sentry 5 requires Cookie ^0.4.1, excluding 0.7.0. Mocha's serialize-javascript ^6.0.2 excludes 7.0.5 (Node >=20). Solc exactly pins Tmp 0.0.33; the inquirer/external-editor route has a separate ^0.0.33 restriction.

Updating only Hardhat to 2.29.1 is not a completion plan: its verified metadata still carries Undici 5, ADM-ZIP 0.4, Solc 0.8.26, Sentry 5 and UUID 8. Decide whether this retained toolchain is required. If retained, plan a supported Hardhat/plugin migration with a deliberate ethers/viem testing stack and Node version; if retired, remove it only after verifying generation, coverage, verification and script consumers. Do not call a Hardhat 3 install safe without checking its complete replacement tree and plugin compatibility.

Current root TypeScript uses CommonJS, the inspected Hardhat config is archived as `hardhat.config.ts.old`, and retained tests use `hre.viem`. Migration may require package module mode, config/plugin APIs and tests. Foundry remains the active CI path and must be checked if Solidity import dependencies change.

No recorded fixes remain for Elliptic through ethers 5/secp256k1 and sprintf-js through sc-istanbul -> js-yaml/argparse. These require replacing/removing the owning path, upstream remediation or explicit residual treatment. The fastmcp Undici 7 branch can refresh to 7.29.1 now; do not force the Hardhat Undici 5 branch to the same major.


### G08. Root Babel, wagmi generation and shared WebSockets

**Babel/glob leaves are small; WebSockets need parent-aware updates.** Babel core 7.29.6 and browserslist 4.28.7 fit the root 7.x/4.x requirements. Picomatch fixes must retain 2.x, 3.x and 4.x branches. Root @wagmi/cli permits Viem 2.x and picomatch ^3.0.0.

For ws, permissive Hardhat 7.x can reach 7.5.11 and OpenAI/isows 8.x can reach 8.21.0. Ethers 6.15.0 pins ws 8.17.1; ethers 6.17.0 pins 8.21.0 and fits toolbox's ethers ^6.4 peer. Viem 2.31.7 pins ws 8.18.2; Viem 2.54.2 pins 8.21.0 and fits CLI 2.x. Ethers 5 providers still pin 8.18.0 and belong to the gas-reporter/Hardhat migration.

CLI 2.10.0 requires TypeScript >=5.7.3: root 5.9.2 satisfies it, whereas frontend 5.4.5 does not. Do not apply the same root upgrade decision to the frontend workspace. Root wagmi generation currently references a placeholder external project path; establish a working input before treating generation as a passing check.


### G09. Token-list generator and its test tooling

**Independent scripts/node install root; mostly simple, with one no-fix leaf.** AJV 8.20.0 permits fast-uri ^3.0.1, so 3.1.8 fits. Vitest 4.1.9 -> 4.1.11 should advance its exact-version Mocker family together. Vite 8.1.3 permits PostCSS 8.5.23; PostCSS permits source-map-js 1.2.2. TSX 4.22.4 permits esbuild ~0.28.0, so 0.28.1 fits; Vite's esbuild peer accepts it too.

No recorded fixed release exists for braces <=3.0.3. Actual source `scripts/node/src/readFragments.ts:3` imports fast-glob -> micromatch -> braces ^3.0.3. Evaluate whether pattern inputs are controlled, an upstream fix, or a replacement before choosing a residual disposition. Do not dismiss the alert simply because token-list processing is a script.

Likely code changes: none for compatible fixes; possible glob API/pattern behavior changes if replacing fast-glob. Validate `npm test`, schema validation (`src/schema.ts`) and deterministic output from representative checked-in token-list fragments. Do not run scripts that modify published artifacts or access networks just to assess versions.


### G10. Vendored OnchainKit starter template

**Isolated template migration, not an active-app patch.** The template pins Next/eslint-config-next 14.1.0 with React/DOM ^18.2.0. All 34 alerts map to Next. Latest-14 patching alone cannot clear ranges that extend to Next 15.5.24; 15.5.24 is the combined verified snapshot floor, with matching eslint-config-next.

It already declares OnchainKit ^1.1.0, whose 1.1.0 peers require React/DOM ^19. This is an existing mismatch with the template's React 18 declarations. Align React runtime/types, Next, ESLint config and wallet peers as a template migration. Next 14 ->15 also requires checking async request APIs and caching assumptions. Choosing Next 16 instead is a separate larger migration, including the existing `next lint` script.

No lockfile is present for this starter; its future transitive resolution needs a fresh audit and scaffold build. The `validate` script merely logs a message and is not a meaningful success criterion. `scripts/sync-bankr-skills.sh` can overwrite vendored customizations: prefer an upstream fix or explicitly maintained vendoring patch. Do not delete or exclude the template just to silence the 34 records.


### G11. Vendored PMFI ethers script

**Small parent update in a separate vendored script.** PMFI declares ethers ^6.15.0, locks ethers 6.16.0 and its exact ws 8.17.1. Ethers 6.17.0 fits the declared range and pins ws 8.21.0, clearing both snapshot WebSocket alerts without crossing the ethers major. A leaf-only ws refresh cannot satisfy the old exact pin.

Check imports and read-only/local execution of `scripts/pmfi_parbitrage.mjs`; use a disposable environment and do not sign deposits/withdrawals or invoke paid Bankr operations. Coordinate the vendoring update with the same sync/provenance process as G10.


### G12. Orphaned OpenCode lockfile

**Owner/cleanup decision before a technically compatible refresh.** The lock root names `@opencode-ai/plugin:1.17.18 -> effect:4.0.0-beta.83 -> toml:^4.1.1`; locked TOML 4.1.2 can update to 4.2.0, which requires Node >=20. This Effect 4 prerelease tree is independent from frontend TEVM's Effect 3.

However, `.opencode/package.json` is absent. Establish whether this lock is generated by an active tool before recreating a manifest, refreshing it through that tool, or removing it as retired. It is not part of the current npm app install, and no runtime dependency change should be made to the app to fix it.

## 4. Cross-group coupling and implementation order

| Shared boundary | Coordinate these changes | Failure mode if treated independently |
| --- | --- | --- |
| Root npm / Yarn / Bun | G05-G08; choose and document supported install paths first | One lock stays vulnerable, a fresh install recreates old versions, or stale Bun-only roots return. |
| Next / ESLint config / React pins / Sharp / native binaries | G01 + relevant G04 leaves | Framework-only bump retains vulnerable optional image package or introduces React/type duplication. |
| Wagmi / connectors / RainbowKit / protocol peers / TypeScript | G02 | Wagmi 3 violates RainbowKit 2 and protocol Wagmi 2 peers; wallet patch and API behavior can regress. |
| TEVM / Effect / memory-client / Vitest / Vite / Solc | G03 + G04 | Direct test-tool updates leave runtime nested test/compiler copies; pinned parents defeat leaf refreshes. |
| Hardhat / toolbox peers / Verify / Ignition / Mocha / coverage | G07 + G05/G08 | A modern top-level utility does not remove pinned legacy cryptographic, HTTP or serialization subtrees. |
| Task Master / AI providers / FastMCP / MCP SDK / Express / Undici | G06 + G05/G07 | AI major or transport changes can break CLI/provider integration; Undici 5 and 7 need different treatment. |
| ethers / Viem / isows / ws across install roots | G02, G08, G11 | Updating one root or peer placement leaves other locked copies; ethers 5 is not solved by ethers 6. |
| PostCSS / Tailwind / Vite / source-map-js | G01/G04/G09 | Both frontend and scripts/node require their own lock updates and build/test checks. |
| Vendored Bankr templates/scripts and refresh provenance | G10-G11 | Local fixes are overwritten by the next sync, or unrelated example dependencies are mistaken for active app code. |

### Suggested execution waves

1. **Resolve install policy and baseline first.** Decide root npm versus Yarn ownership; if both are retained, keep both complete. Reconcile the stale Bun root deliberately. Record Node versions for local tools, CI and deployment. Confirm whether TEVM/Voltaire/Permit2 SDK, archived Hardhat tooling, Task Master and the orphan OpenCode lock are still required. No removals are authorized by this report.
2. **Patch the deployed framework and urgent compatible leaves.** G01 first; then Hono in G02, root multipart/proxy/Axios and Handlebars, and G04/schema/CSS/glob leaves. Keep coherent framework and tool families together. Prioritize exposure and severity, not only the number of records closed.
3. **Advance compatible parents.** CDP SDK 1.56.0 + Axios 1.20.0; Express 4.22.3 + its QS/body-parser subtree; ethers 6.17.0 and appropriate Viem 2 parent resolutions; Vite 7.3.6 + esbuild 0.28.1; direct Vitest 4.1.11 families in frontend and scripts/node. Re-audit exact locked duplicates after each batch.
4. **Perform explicit migrations or confirmed removals.** TEVM prerelease family; pinned WalletConnect/MetaMask/query-string paths; Hardhat/plugins/coverage; Task Master/AI providers. Their constraints require design decisions and regression coverage, not one transitive override.
5. **Update vendored material and resolve the orphan lock.** G10 is a template migration; G11 is a small ethers parent update. Feed changes into the upstream/vendor maintenance route. Handle G12 through its actual generator/owner.
6. **Close the evidence loop.** Rerun the graph/advisory comparison on the resulting locks, collect real checks, then refresh the paginated GitHub alert inventory after dependency-graph ingestion. Record no-fix and parent-blocked residuals explicitly. Do not dismiss alerts solely to make the dashboard green.

### Decisions and existing conflicts to settle

- Frontend TypeScript is pinned at 5.4.5, but the current frontend lock resolves @wagmi/cli 2.10.0, whose published TypeScript peer is >=5.7.3. This is an existing peer mismatch to resolve deliberately (compatible CLI pin or compiler update) before interpreting clean-install failures. A Wagmi 3 migration separately requires TypeScript >=5.9.3.
- The template's React 18 declarations conflict with its OnchainKit 1.1.0 React 19 peer. This is separate from the active app's aligned React 19.3.0.
- Checked-in frontend guidance recommends Node 22.13+ and records Vercel Node 24; current Vite requires ^20.19.0 or >=22.12.0, and Undici 7 requires >=20.18.1. Verify each runner rather than checking only Next's lower Node floor.
- No fixed release is recorded for Elliptic (#15, #57, #122), sprintf-js (#813, #814), or braces (#840). Keep upstream tracking and reachable-code analysis as explicit residual work; do not invent a safe version.

## 5. Verification required for the eventual updates

These are proposed acceptance checks, **not commands executed during this report**. Run updates in bounded batches using the chosen package manager; do not combine all migrations into one lockfile rewrite.

### Frontend (G01-G04)

After changing and reviewing the workspace manifests/lockfile, use the repository's existing sequence from `frontend/NEXTJS_UPGRADE.md`:

```bash
cd frontend
npm ci
npm ls --all
npm run check -w @indexedex/app-indexedex
npm run typecheck -w @indexedex/protocol
npm run build:indexedex
npm run test:e2e:deployment
npm run build:dtf
npm run test:e2e:dtf
```

Run production variants sequentially because both write `.next`. Confirm `patch-package --error-on-fail` applies the RainbowKit patch. Connector changes additionally need the existing RainbowKit/connected-wallet regressions and applicable injected-wallet transaction tests on disposable local chains. Real-wallet or live-money operations require their normal separate authorization; do not use mocks as proof of a money-path upgrade.

### Root tooling (G05-G08)

Use a clean disposable install with the chosen frozen-lock mode (`npm ci` or the supported Yarn Classic equivalent), inspect peers and all resolved vulnerable copies, and smoke-test the actual CLI/SDK integrations. Restore/migrate an executable Hardhat configuration before claiming Hardhat tests pass; no active config was found in the inspected root. Check Task Master/MCP tool registration, provider configuration and transport behavior without paid model calls. Validate wagmi generation only with valid project inputs.

If changing dependencies consumed by Solidity compilation or its test/deployment tooling, follow the repository build-before-test rule:

```bash
forge build
python3 scripts/forge-artifacts.py build --all-artifacts
env -u FOUNDRY_ETH_RPC_URL -u ETH_RPC_URL forge test -vv --no-match-path '**/fork/**' --no-match-contract 'Fork'
```

### Scripts, templates and local tooling (G09-G12)

- `scripts/node`: clean install, `npm test`, local schema/fragment fixtures and deterministic token-list output comparison. Treat replacement of fast-glob/braces as a code change.
- Template: scaffold a disposable app, resolve peers, build and test actual components. The current logging-only `validate` script is insufficient.
- PMFI: clean install plus local/read-only checks; do not submit deposits, withdrawals or signatures.
- OpenCode: first establish its owner/generator, then validate the intended tool startup and TOML parsing. Do not recreate a manifest without confirming purpose.

### Completion evidence for each batch

1. Review every changed manifest and lock; record exact resolved versions and all surviving copies.
2. No unresolved peer/engine conflicts introduced; explicit justification for any existing baseline issue.
3. Matching build/test evidence for the consumers above; no unrun check represented as passing.
4. New dependency graph/advisory check, including the parent package's newly introduced dependencies.
5. Refreshed GitHub alert IDs: closed, still open, or newly introduced. Version floors here are not permission to ignore later advisories.

## 6. Complete package/manifest ledger

All **423 alert numbers** appear exactly once in the following **96 rows**. Manifest keys are defined in section 2. Targets are deduplicated across vulnerable node copies; full physical paths, parents, individual candidate assignments, original advisory ranges and source URLs are in the two evidence JSON files.

Class A = range-compatible candidate; B = parent/pin update; C = major or 0.x-minor migration; D = no recorded patch. Parent lists show blocking requirements when present, otherwise direct consumers. Exact app pins such as Next are B even when the planned edit itself is a small patch.

| Group | Manifest | Package | Vulnerable locked versions | Candidate floors | Class | Parent constraints / shared consumers | Alert IDs |
| --- | --- | --- | --- | --- | --- | --- | --- |
| G01 | A | next | 16.3.5 | 16.3.8 | B | @indexedex/app-indexedex 16.3.5 | #776, #798, #800, #802, #804, #817, #818 |
| G01 | F | next | 16.3.5 | 16.3.8 | B | @indexedex/app-indexedex 16.3.5 | #777, #799, #801, #803, #805, #828, #829 |
| G01 | F | sharp | 0.35.4 | 0.35.5 | A | next ^0.35.4 | #827 |
| G02 | F | axios | 1.16.0 | 1.20.0 | B | @coinbase/cdp-sdk 1.16.0 | #720, #721, #722, #723, #724, #725, #726, #727, #728, #729, #766, #767, #768, #769, #770, #771, #772, #778, #822, #823 |
| G02 | F | decode-uri-component | 0.2.2 | 0.5.0 | C | query-string ^0.2.2 | #730 |
| G02 | F | elliptic | 6.6.1 | No recorded fix | D | @ethersproject/signing-key 6.6.1 | #15 |
| G02 | F | hono | 4.12.1 | 4.13.7 | A | porto ^4.10.3 | #19, #26, #27, #28, #29, #177, #178, #179, #180, #181, #199, #220, #221, #226, #227, #228, #276, #277, #278, #279, #301, #302, #303, #304, #305, #465, #466, #467, #531, #557, #558, #559, #701, #702, #703, #775 |
| G02 | F | uuid | 8.3.2, 9.0.1 | 11.1.1 | C | @metamask/utils ^9.0.1; @metamask/sdk ^8.3.2; @metamask/sdk-communication-layer ^8.3.2 | #719 |
| G02 | F | ws | 8.18.0, 8.18.3, 8.19.0 | 8.21.0 | B | @ethersproject/providers 8.18.0; viem 8.18.0 | #253, #326 |
| G03 | F | @vitest/mocker | 3.2.6, 4.1.8 | 4.1.11 | C | vitest 3.2.6; vitest 4.1.8 | #704 |
| G03 | F | effect | 3.18.1, 3.19.18 | 3.20.0 | B | @tevm/base-bundler 3.18.1; @tevm/bun-plugin 3.18.1; @tevm/cli 3.18.1; @tevm/compiler 3.18.1; @tevm/config 3.18.1; @tevm/effect 3.18.1; @tevm/resolutions 3.18.1; @tevm/runtime 3.18.1; @tevm/ts-plugin 3.18.1; @tevm/unplugin 3.18.1; tevm 3.18.1 | #34 |
| G03 | F | esbuild | 0.27.7 | 0.28.1 | C | vite ^0.27.0 | #295 |
| G03 | F | tinypool | 1.1.1 | 2.1.2 | C | vitest ^1.1.1 | #825, #826 |
| G03 | F | tmp | 0.0.33 | 0.2.6 | C | solc 0.0.33 | #7, #270 |
| G03 | F | vitest | 3.2.6, 4.1.8 | 4.1.11 | C | @tevm/memory-client ^3.2.4 | #709 |
| G04 | F | baseline-browser-mapping | 2.9.19 | 2.11.0 | A | browserslist ^2.9.0; next ^2.9.19 | #706 |
| G04 | F | brace-expansion | 1.1.14, 5.0.6 | 5.0.12, 1.1.21 | A | minimatch ^5.0.2; minimatch ^1.1.7 | #353, #410, #516, #530, #541, #542, #764, #765, #812, #819, #820, #821 |
| G04 | F | browserslist | 4.28.1 | 4.28.7 | A | @babel/helper-compilation-targets ^4.24.0; autoprefixer ^4.28.1; update-browserslist-db >= 4.21.0 | #689 |
| G04 | F | flatted | 3.3.3 | 3.4.2 | A | flat-cache ^3.2.9 | #32 |
| G04 | F | minimatch | 10.2.1 | 10.2.3 | A | @tevm/ts-plugin ^10.0.3; glob ^10.2.1; glob ^10.1.1 | #21, #24 |
| G04 | F | picomatch | 2.3.1, 3.0.1 | 3.0.2, 2.3.2 | A | @wagmi/cli ^3.0.0; micromatch ^2.3.1 | #39, #40 |
| G04 | F | source-map-js | 1.2.1 | 1.2.2 | A | @tailwindcss/node ^1.2.1; postcss ^1.2.1 | #810 |
| G05 | N | axios | 1.11.0 | 1.20.0 | A | <root> ^1.11.0; eth-gas-reporter ^1.5.1 | #65, #197, #200, #204, #208, #210, #212, #214, #216, #247, #249, #254, #255, #284, #286, #289, #293, #312, #448, #450, #783, #833, #834 |
| G05 | N | follow-redirects | 1.15.9 | 1.16.0 | A | axios ^1.15.6; solc ^1.12.1 | #195 |
| G05 | N | form-data | 2.5.3, 4.0.4 | 2.5.6, 4.0.6 | A | then-request ^2.2.0; <root> ^4.0.4; @types/node-fetch ^4.0.0; axios ^4.0.4 | #45, #309, #311 |
| G05 | N | jws | 3.2.2 | 3.2.3 | A | jsonwebtoken ^3.2.2 | #54 |
| G05 | N | proxy-addr | 2.0.7 | 2.0.8 | A | express ^2.0.7; express ~2.0.7 | #807 |
| G05 | N | qs | 6.13.0, 6.14.0 | 6.15.2 | B | body-parser 6.13.0; express 6.13.0 | #55, #64, #266 |
| G05 | Y | axios | 1.11.0 | 1.20.0 | A | eth-gas-reporter ^1.5.1; <root> ^1.11.0 | #130, #198, #201, #205, #209, #211, #213, #215, #217, #248, #250, #259, #260, #285, #287, #290, #294, #313, #460, #462, #784, #844, #845 |
| G05 | Y | follow-redirects | 1.15.9 | 1.16.0 | A | axios ^1.15.6; solc ^1.12.1 | #194 |
| G05 | Y | form-data | 2.5.3, 4.0.4 | 2.5.6, 4.0.6 | A | then-request ^2.2.0; @types/node-fetch ^4.0.0; axios ^4.0.4; <root> ^4.0.4 | #110, #308, #310 |
| G05 | Y | jws | 3.2.2 | 3.2.3 | A | jsonwebtoken ^3.2.2 | #119 |
| G05 | Y | proxy-addr | 2.0.7 | 2.0.8 | A | express ~2.0.7; express ^2.0.7 | #806 |
| G05 | Y | qs | 6.13.0, 6.14.0 | 6.15.2 | B | body-parser 6.13.0; express 6.13.0 | #120, #129, #267 |
| G06 | N | @modelcontextprotocol/sdk | 1.15.0 | 1.31.0 | A | fastmcp ^1.10.2; mcp-proxy ^1.11.4 | #53, #63, #792 |
| G06 | N | ai | 4.3.16 | 5.0.52 | C | task-master-ai ^4.3.10 | #49 |
| G06 | N | jsondiffpatch | 0.6.0 | 0.7.6 | C | ai 0.6.0 | #47, #675 |
| G06 | N | nanoid | 3.3.11 | 3.3.12 | A | @ai-sdk/provider-utils ^3.3.8 | #693 |
| G06 | N | uuid | 8.3.2, 11.1.0 | 11.1.1 | C | hardhat ^8.3.2 | #268 |
| G06 | Y | @modelcontextprotocol/sdk | 1.15.0 | 1.31.0 | A | fastmcp ^1.10.2; mcp-proxy ^1.11.4 | #118, #128, #793 |
| G06 | Y | ai | 4.3.16 | 5.0.52 | C | task-master-ai ^4.3.10 | #114 |
| G06 | Y | jsondiffpatch | 0.6.0 | 0.7.6 | C | ai 0.6.0 | #112, #676 |
| G06 | Y | nanoid | 3.3.11 | 3.3.12 | A | @ai-sdk/provider-utils ^3.3.8 | #697 |
| G06 | Y | uuid | 8.3.2, 11.1.0 | 11.1.1 | C | hardhat ^8.3.2 | #269 |
| G07 | N | @fastify/busboy | 2.1.1 | 3.2.2 | C | undici ^2.0.0 | #836 |
| G07 | N | adm-zip | 0.4.16 | 0.6.1 | C | hardhat ^0.4.16 | #352, #737, #757, #763 |
| G07 | N | brace-expansion | 1.1.12, 2.0.2 | 1.1.21, 2.1.7 | A | minimatch ^1.1.7; minimatch ^2.0.1 | #444, #445, #786, #809 |
| G07 | N | cookie | 0.4.2 | 0.7.0 | C | @sentry/node ^0.4.1 | #44 |
| G07 | N | elliptic | 6.6.1 | No recorded fix | D | @ethersproject/signing-key 6.6.1; secp256k1 ^6.5.7 | #57 |
| G07 | N | fast-uri | 3.0.6 | 3.1.8 | A | ajv ^3.0.1 | #469, #471, #533, #668, #670, #679, #681, #753 |
| G07 | N | handlebars | 4.7.8 | 4.7.10 | A | sc-istanbul ^4.0.1 | #95, #99, #100, #102, #103, #107, #108, #795, #797, #816 |
| G07 | N | immutable | 4.3.7 | 4.3.9 | A | hardhat ^4.0.0-rc.12 | #77, #688, #735 |
| G07 | N | js-yaml | 3.14.1, 4.1.0 | 4.3.2, 3.15.2 | A | mocha ^4.1.0; sc-istanbul 3.x | #50, #51, #341, #343, #446, #447, #553, #554, #716, #732 |
| G07 | N | lodash | 4.17.21 | 4.18.1 | B | @nomicfoundation/ignition-core 4.17.21 | #61, #182, #184 |
| G07 | N | minimatch | 3.1.2, 5.1.6 | 5.1.8, 3.1.4 | A | glob ^5.0.1; mocha ^5.1.6; glob ^3.1.1; recursive-readdir ^3.0.5; glob 2 \|\| 3; glob ^3.0.4 | #74, #75 |
| G07 | N | serialize-javascript | 6.0.2 | 7.0.5 | C | mocha ^6.0.2 | #76, #265 |
| G07 | N | sprintf-js | 1.0.3 | No recorded fix | D | argparse ~1.0.2 | #814 |
| G07 | N | tmp | 0.0.33 | 0.2.6 | C | external-editor ^0.0.33; solc 0.0.33 | #46, #272 |
| G07 | N | undici | 5.29.0, 7.11.0 | 6.28.1, 7.29.1 | C | @nomicfoundation/hardhat-verify ^5.14.0; hardhat ^5.14.0 | #79, #80, #81, #82, #83, #307, #319, #323, #325, #331, #333, #335, #521, #523, #525, #527, #529, #534, #536, #538, #739, #743, #745, #747, #751, #830 |
| G07 | Y | @fastify/busboy | 2.1.1 | 3.2.2 | C | undici ^2.0.0 | #847 |
| G07 | Y | adm-zip | 0.4.16 | 0.6.1 | C | hardhat ^0.4.16 | #351, #736, #756, #762 |
| G07 | Y | ajv | 8.17.1 | 8.18.0 | A | table ^8.0.1 | #131 |
| G07 | Y | bn.js | 4.11.6, 4.12.2 | 4.12.3 | B | ethjs-unit 4.11.6; number-to-bn 4.11.6 | #133 |
| G07 | Y | brace-expansion | 1.1.12, 2.0.2 | 1.1.21, 2.1.7 | A | minimatch ^1.1.7; minimatch ^2.0.1 | #162, #456, #457, #549, #550, #785, #808, #842, #843 |
| G07 | Y | cookie | 0.4.2 | 0.7.0 | C | @sentry/node ^0.4.1 | #109 |
| G07 | Y | diff | 4.0.2 | 4.0.4 | A | ts-node ^4.0.1 | #127 |
| G07 | Y | elliptic | 6.6.1 | No recorded fix | D | @ethersproject/signing-key 6.6.1; secp256k1 ^6.5.7 | #122 |
| G07 | Y | fast-uri | 3.0.6 | 3.1.8 | A | ajv ^3.0.1 | #468, #470, #532, #667, #669, #678, #680, #752, #773 |
| G07 | Y | handlebars | 4.7.8 | 4.7.10 | A | sc-istanbul ^4.0.1 | #160, #164, #165, #166, #167, #168, #172, #173, #794, #796, #815 |
| G07 | Y | immutable | 4.3.7 | 4.3.9 | A | hardhat ^4.0.0-rc.12 | #142, #687, #734 |
| G07 | Y | js-yaml | 3.14.1, 4.1.0 | 4.3.2, 3.15.2 | A | mocha ^4.1.0; sc-istanbul 3.x | #115, #116, #340, #350, #458, #459, #555, #556, #715, #733 |
| G07 | Y | lodash | 4.17.21 | 4.18.1 | B | @nomicfoundation/ignition-core 4.17.21 | #126, #183, #185 |
| G07 | Y | minimatch | 3.1.2, 5.1.6 | 3.1.4, 5.1.8 | A | glob ^3.0.4; recursive-readdir ^3.0.5; glob ^3.1.1; glob 2 \|\| 3; glob ^5.0.1; mocha ^5.1.6 | #136, #138, #139, #140 |
| G07 | Y | pbkdf2 | 3.1.3 | 3.1.7 | A | ethereum-cryptography ^3.0.17 | #848 |
| G07 | Y | serialize-javascript | 6.0.2 | 7.0.5 | C | mocha ^6.0.2 | #141, #264 |
| G07 | Y | sprintf-js | 1.0.3 | No recorded fix | D | argparse ~1.0.2 | #813 |
| G07 | Y | tmp | 0.0.33 | 0.2.6 | C | external-editor ^0.0.33; solc 0.0.33 | #111, #271 |
| G07 | Y | undici | 5.29.0, 7.11.0 | 6.28.1, 7.29.1 | C | @nomicfoundation/hardhat-verify ^5.14.0; hardhat ^5.14.0 | #144, #145, #146, #147, #148, #306, #318, #322, #324, #332, #334, #336, #520, #522, #524, #526, #528, #535, #537, #539, #738, #742, #744, #746, #749, #841 |
| G08 | N | @babel/core | 7.28.3 | 7.29.6 | A | <root> ^7.28.3; @babel/helper-module-transforms ^7.0.0 | #338 |
| G08 | N | browserslist | 4.25.2 | 4.28.7 | A | @babel/helper-compilation-targets ^4.24.0; update-browserslist-db >= 4.21.0 | #691 |
| G08 | N | picomatch | 2.3.1, 3.0.1, 4.0.2 | 3.0.2, 4.0.4, 2.3.2 | A | @wagmi/cli ^3.0.0; fdir ^3 \|\| ^4; tinyglobby ^4.0.2; anymatch ^2.0.4; micromatch ^2.3.1; readdirp ^2.2.1 | #90, #92, #93, #94 |
| G08 | N | ws | 7.5.10, 8.17.1, 8.18.0, 8.18.2, 8.18.3 | 8.21.0, 7.5.11 | B | @ethersproject/providers 8.18.0; ethers 8.17.1; viem 8.18.2 | #258, #314, #327 |
| G08 | Y | @babel/core | 7.28.3 | 7.29.6 | A | <root> ^7.28.3 | #339 |
| G08 | Y | browserslist | 4.25.2 | 4.28.7 | A | @babel/helper-compilation-targets ^4.24.0 | #695 |
| G08 | Y | picomatch | 2.3.1, 3.0.1, 4.0.2 | 3.0.2, 4.0.4, 2.3.2 | A | @wagmi/cli ^3.0.0; tinyglobby ^4.0.2; anymatch ^2.0.4; micromatch ^2.3.1; readdirp ^2.2.1 | #155, #157, #158, #159 |
| G08 | Y | ws | 7.5.10, 8.17.1, 8.18.0, 8.18.2, 8.18.3 | 8.21.0, 7.5.11 | B | ethers 8.17.1; @ethersproject/providers 8.18.0; viem 8.18.2 | #263, #315, #328 |
| G09 | S | @vitest/mocker | 4.1.9 | 4.1.11 | B | vitest 4.1.9 | #705 |
| G09 | S | braces | 3.0.3 | No recorded fix | D | micromatch ^3.0.3 | #840 |
| G09 | S | esbuild | 0.28.0 | 0.28.1 | A | tsx ~0.28.0; vite ^0.27.0 \|\| ^0.28.0 | #347 |
| G09 | S | fast-uri | 3.1.2 | 3.1.8 | A | ajv ^3.0.1 | #472, #477, #540, #677, #682, #683, #838, #839 |
| G09 | S | postcss | 8.5.16 | 8.5.23 | A | vite ^8.5.16 | #514, #548 |
| G09 | S | source-map-js | 1.2.1 | 1.2.2 | A | postcss ^1.2.1 | #811 |
| G09 | S | vitest | 4.1.9 | 4.1.11 | A | <root> ^4.1.9 | #710 |
| G10 | T | next | 14.1.0 | 15.5.24 | C | onchainkit-basic-app 14.1.0 | #413, #414, #415, #416, #417, #418, #419, #420, #421, #422, #423, #424, #425, #426, #427, #428, #429, #430, #431, #432, #433, #434, #435, #436, #437, #438, #480, #483, #486, #489, #492, #495, #707, #708 |
| G11 | P | ws | 8.17.1 | 8.21.0 | B | ethers 8.17.1 | #439, #440 |
| G12 | O | toml | 4.1.2 | 4.2.0 | A | effect ^4.1.1 | #686 |

## 7. Additional matching copies and limits

The 423-count ledger is an exact account of the open GitHub alert response, not a complete independent package audit. Applying the same already-reviewed ranges across the npm lockfiles also found the following affected package/manifest combinations with no corresponding open record in that response. Include them in remediation verification; do not add them to the 423-alert denominator or dismiss them as safe.

| Manifest | Package | Locked versions | Matching advisory |
| --- | --- | --- | --- |
| N | diff | 4.0.2 | GHSA-73rr-hh4g-fpgx |
| N | ajv | 8.17.1 | GHSA-2g4f-4pwh-qvx6 |
| N | bn.js | 4.12.2, 4.11.6 | GHSA-378v-28hj-76wf |
| N | braces | 3.0.3 | GHSA-vfj7-8cjw-p6xm |
| N | pbkdf2 | 3.1.3 | GHSA-477h-4r7f-fvrx |
| F | braces | 3.0.3 | GHSA-vfj7-8cjw-p6xm |

Unresolved decisions are root package-manager authority; which legacy or apparently unused tooling is still required; the target supported wallet/TEVM/Hardhat migration lines; and the owner of the orphan OpenCode lock. No clean-install experiment or runtime compatibility claim is made. The full Crane submodule's own dependency alerts, separate repositories, container/OS packages and GitHub Actions version auditing are outside this repository-alert snapshot.

## 8. Sources and reproducibility

Local evidence is pinned to the baseline commit above. The JSON evidence files retain exact package versions and metadata URLs rather than mutable `latest` advice. One ethers metadata lookup used the live latest tag and resolved to 6.17.0; the report names that exact version. All 83 package/version records were retrieved successfully.

- GitHub alert API: `GET /repos/cyotee/indexedex/dependabot/alerts?state=open&per_page=100&sort=created&direction=asc`, fetched with authenticated `gh api --paginate --slurp`. [Endpoint and pagination contract](https://docs.github.com/en/rest/dependabot/alerts).
- npm registry: exact `https://registry.npmjs.org/<package>/<version>` metadata, recorded in `2026-10-19-upgrade-evidence.json`. [npm dependency/peer/override semantics](https://docs.npmjs.com/cli/v11/configuring-npm/package-json/). Parent range acceptance is a necessary condition, not proof of behavior.
- [Next.js 14 to 15 migration guide](https://nextjs.org/docs/app/guides/upgrading/version-15): template request-API, React and caching migration surface. Active-app patching follows the local `frontend/NEXTJS_UPGRADE.md`, not this major-migration recipe.
- [Vitest migration guide](https://vitest.dev/guide/migration/): use when migrating nested Vitest 3 consumers; [Vitest/Mocker advisory](https://github.com/advisories/GHSA-82fw-gwwq-j7x9).
- [Next ImageResponse advisory](https://github.com/advisories/GHSA-vcvr-r3jv-pc5j); [Effect advisory](https://github.com/advisories/GHSA-38f7-945m-qr2g); [Elliptic advisory](https://github.com/advisories/GHSA-848j-6mx2-7j84). The complete per-alert GHSA and repository-alert URLs are in the snapshot.
- Primary local declarations: root `package.json`; `frontend/package.json`; `frontend/apps/indexedex/package.json`; `frontend/packages/protocol/package.json`; `scripts/node/package.json`; both vendored manifests; all five npm lockfiles plus root Yarn and Bun locks.
- Local integration evidence: `frontend/apps/indexedex/next.config.js`; `frontend/patches/@rainbow-me+rainbowkit+2.2.11.patch`; wallet/provider and route tests; `scripts/node/src/schema.ts` and `readFragments.ts`; `.github/workflows/foundry-ci.yml`; `scripts/sync-bankr-skills.sh`.

Validation of this report: 423 unique API IDs; five complete pages; all 423 vulnerable-range matches; 96 disjoint ledger rows covering every alert exactly once; group/severity/classification totals reconcile; registry metadata present for every proposed leaf target. JSON parsing and report coverage were checked locally. No dependency changes, commits, pushes or GitHub alert mutations were performed.
