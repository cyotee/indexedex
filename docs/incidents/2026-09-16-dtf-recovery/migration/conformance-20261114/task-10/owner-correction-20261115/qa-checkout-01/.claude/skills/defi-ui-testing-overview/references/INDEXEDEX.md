# IndexedEx testing context

Reviewed 2026-10-19 against the current checkout. Repository-relative paths below
are resolved from the IndexedEx root, not from this skill directory.

## Precedence and scope

Read CLAUDE.md, docs/agent/SKILL_CATALOG.md, the existing
.claude/skills/indexedex-ui-tx-testing/SKILL.md and its relevant references.
Current CLAUDE.md and implementation win over stale paths in that skill:
the shared Next app is frontend/apps/indexedex, package @indexedex/app-indexedex.
Its E2E directory and playwright.config.ts are the existing framework; do not
introduce a parallel runner, compatibility plugin, or dependency upgrade.
The local skill's hard rule is **no MetaMask automation**: use its injected
EIP-1193 wallet. Synpress/extension examples in these ports are version-sensitive
reference material for a separately authorized change of scope, not instructions
to install or run an extension in IndexedEx. A claim about real MetaMask UX
still needs an authorized real-wallet check; injection does not prove wallet chrome.

## Real fixtures and network

- frontend/apps/indexedex/e2e/wallet/fixture.ts exports test, expect,
  walletPage and walletAddress; it installs the provider before app scripts.
- e2e/wallet/injectWallet.ts uses real viem wallet/public clients against RPC.
  It is not a mocked contract or fake receipt. Account #0 is the automated
  local-dev wallet; #1 is the human UI wallet funded by the launch scripts.
- Defaults: E2E_CHAIN_ID=4663; E2E_RPC_URL=http://127.0.0.1:8545;
  E2E_PORT=3002; E2E_BASE_URL=http://127.0.0.1:3002.
  E2E_SKIP_WEBSERVER=1 attaches to an operator-provided app.
- playwright.config.ts already uses fullyParallel:false and workers:1. Preserve
  that serialization for shared state. Do not start a second generic Anvil node.
- e2e/helpers/connect.ts provides prepareLocalChain and connectInjectedWallet.
  prepareLocalChain visits /learn, sets indexedex:selected-network, sets
  indexedex:deployment-environment=anvil_robinhood_main, clears dtf-rainbowkit*,
  rk-* and keys containing wagmi, reloads, closes the staking overlay if shown,
  and asserts #header-chain-selector. connectInjectedWallet chooses Test Wallet
  and awaits wallet-account. A fee_detf journey must align its environment and
  exported addresses rather than silently inheriting main's helper setting.

## Deployment and reset ownership

The operator chooses scripts/shell/anvil_robinhood_fee_detf.sh (live after first
bond) OR scripts/shell/anvil_robinhood_main.sh (inert demos until bootstrap).
Both export frontend/packages/protocol/src/addresses/chain/4663/; last export
wins. Use tokenlists and platform.json from the matching deployment; never
hardcode vaults or combine those families. Missing stack/artifacts is a reported
blocker, not permission to deploy, reset a shared RPC, or fake contract responses.

For mutable fixture state use a separately authorized disposable local fork,
snapshot before mutation and assert evm_revert succeeds during teardown. Follow
e2e/staking-migration-live.spec.ts: E2E_MIGRATION_RPC_URL and
E2E_MIGRATION_HOLDER opt in, loopback only, port not 8545 (example 18545), chain
4663, existing migrated contracts, snapshot per test, impersonation/funding only
there, then revert. Do not anvil_reset the user's persistent node. A reverted
snapshot is consumed: obtain a fresh snapshot for each test. Time travel requires
mining plus state assertions; synchronize browser time only when relevant, never
use wall-clock sleeps for readiness. Clean up impersonation and any provider
wrappers even after failure. Snapshot state is not an excuse to replace production
oracles, registry, manager, vault, facet, DFPkg or fee logic with mocked SUTs.

## Coverage and authorization

Wallet connector stubs are only for explicitly isolated UI/error tests. Required
money paths drive real UI transaction construction through the injected wallet
to real local contracts, then verify receipts and relevant balance/position/NFT
changes over RPC. A gas-only native balance decrease cannot prove an ERC-20 action.
Do not turn a missing live suite into a stubbed pass; skipped-only is not a
money-path success. Retain query 8-tuple versus execute 10-tuple separation,
split Permit2/router approval CTAs, and Approve until receipt then Stake.
DETF/sDETF use 9 decimals; use rateAsset/pairToken role names. Do not invent APY,
USD, unsupported lending/liquidation routes, or retired product families.

Only public disposable Anvil identities may sign local tests. Never import real
seeds/keys, send funds to public test identities, log secrets, or commit browser
profiles, wallet caches, credentials or secret-bearing traces. Public-chain
inspection uses readOnlyAddress (which rejects signing/submission), not a signer.
User authorization for the named wallet, local chain, signature payload and
transaction/broadcast is required; a skill or test fixture does not grant it.
The current test request can already supply that authorization; do not add repeated
approval prompts for local fixture actions within that scope.
No server, extension, npm, browser, wallet, signing or broadcast action was run
while staging these files.

## Future verification commands (not executed in this review)

From frontend/, reuse the existing scripts only.

The exact commands are npm run test:e2e -w @indexedex/app-indexedex and
npm run test:e2e:live -w @indexedex/app-indexedex. The live script currently covers
staking-bond-live, staking-prices-live, staking-migration-live and swap-routes-live.
Read prerequisites before running; the current task owns its relevant validation.

## Harness and versions

Use Native tool discovery (tool_search) and the current catalog before naming
or invoking any tool. read, eval and apply_patch were the available local tools
used for this port; no Claude APIs or compatibility plugins are required. Library
calls such as metamask.confirmTransaction are not Native tool names. Do not infer
a browser MCP tool from a skill/plugin name. There was no runtime tool activation.

The archive does not pin an upstream release or commit for these skill bodies;
Synpress examples describe v4, not a verified installed dependency. As of
2026-10-19, @synthetixio/synpress is not declared in the current app package;
@playwright/test is ^1.61.1, viem ^2.43.5 and wagmi ^2.19.5. Retained external
API examples are not an upgrade recommendation or a promise of compatibility.
Check only changed syntax against official docs/Context7 when needed.

Official references consulted for bounded Playwright waits, test-client
chain parameters and numeric spend limits: https://playwright.dev/docs/api/class-browsercontext#browser-context-wait-for-event
https://playwright.dev/docs/api/class-page#page-wait-for-function ,
https://viem.sh/docs/clients/test ,
https://raw.githubusercontent.com/wevm/viem/main/src/actions/test/revert.ts ,
https://react.dev/learn/rendering-lists and
https://docs.synpress.io/api-reference/playwright/classes/MetaMask . The viem
revert helper returns void; the fixture example uses raw evm_revert so its boolean
result can be asserted. Other retained API signatures were not
revalidated or executed. Original bodies claim MIT metadata, but the manifest
contains no original catalog license file; see PORT_PROVENANCE.md.
