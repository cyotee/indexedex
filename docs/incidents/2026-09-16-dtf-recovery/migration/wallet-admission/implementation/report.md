# Original-wallet NFT admission implementation

Date: 2026-11-11.

**The scoped H1/H2/H7 implementation and its required checks passed.**
Final source passed 97 Migration specs, 47 pinned legacy fork tests, 54
operator tests, strict TypeScript checking, typed Foundry stage compilation,
and the fixed real local CLI rehearsal. Independent review remains a separate
next step; this report is not full Migration release acceptance.

## Authority, baseline and scope

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-12-wallet-admission`.

Branch: `work/dtf-migration-phase-12-wallet-admission`.
Verified HEAD: `3f577eeca049c1bd70a812d130941c8a38dd4781`.
The dispatched warm-seed exit 0 and `WALLET_ADMISSION_WORKTREE_VERIFIED`
were supplied by the root task. This node independently observed the exact
branch/HEAD, an empty `git status --short --ignore-submodules=all`, and both
warm artifact directories. Ordinary status first exited 128 because the
prescribed `lib/crane` path is a symlink; the submodule-ignoring check exited 0.

Read the complete phase12 brief, current main-checkout plan revision
`migration-detf-implementation-plan-r3-original-wallet-entitlement` including
section 1.3, the complete independent phase11 report/matrix, repository rules,
canonical testing/style rules and applicable operator/programming rules.
The input fingerprints are in `source-artifact-bindings.json`.

There are 23 changed/new implementation, operator, runbook and test files,
plus this directory's evidence. Production edits are confined to the
Migration interface, allocation Target and surrender Target. No ordinary,
common or Crane production, dependency, configuration, model-routing,
general fungible or gas-package implementation changed. No held phase09
candidate was read, imported, edited or tested. No source commit, push,
merge, production signer or public transaction was used.

## Implemented contract

Let `M` denote
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.

* `M/interfaces/IUniswapV4DetfMigration.sol:96` adds required
  `address originalWallet` immediately after `tokenId` in the interface-owned
  `NftEntitlementInput`. The existing nested configuration storage and
  `nftEntitlement` query carry it without another ledger. The complete
  configuration hash includes it. The configuration event includes the
  wallet at line 172.
* `M/UniswapV4DetfMigrationAllocationTarget.sol:129` rejects a zero wallet
  with `InvalidNftEntitlement(collection, tokenId)`. Full replacement remains
  allowed. It changes configuration only, not custody, surrender history,
  delivered bond principal or supply.
* `M/UniswapV4DetfMigrationTarget.sol:64` retains the existing preview's
  absent-configuration and permanent-consumption checks, then requires
  `msg.sender == config.original.originalWallet` with
  `NotOriginalNftWallet(caller, originalWallet)` at line 76. The existing
  live-owner check follows. Both precede the safe pull. Receiver, post-custody,
  source-position, minimum, funding and atomic rollback checks are retained.
* `M/legacy/MigrationLegacyNftLib.sol` and `M/UniswapV4DetfMigrationRepo.sol`
  are unchanged. The canonical economic origin remains
  `keccak256(abi.encode("migration.nft", chainid, instance, snapshotId,
  collection, tokenId))`. It deliberately excludes the wallet. The existing
  `nftOriginal`, independent-original collision checks and immutable
  surrender record therefore survive a wallet correction.
* The new configuration selector is `0x12076202`, for
  `configureNftEntitlements((address,uint256,address,uint256,uint256,uint256,bytes32,bool)[])`.
  Existing interface-derived facet inventories and
  `AllocationTarget._administrationSelectors` at line 173 propagate and
  remove it at activation. No new restoration surface was introduced.

The decision was to bind the complete existing NFT configuration to its
explicit recorded wallet, not to key economic consumption by wallet or
derive eligibility from current ownership. A wallet-keyed economic origin
could reopen the same NFT after correction; a live-owner default would
preserve the original defect. Neither was adopted.

Weighted credit remains `floor(C0 * (P0 - Pc) / P0)`. Earlier eligible live
locks retain full original-share credit. Rewards do not increase credit.
Each success still consumes the whole identity and funds a fresh 90-day
bond for that same wallet. Independent allocations and permissionless
uncredited capital donations retain their separate behavior.

## Operator propagation

`scripts/recovery/dtf-migration/schema.ts:32` requires a nonzero wallet;
`payloads.ts:7` encodes the same tuple order. Existing full-original
fingerprinted proof comparison in `provenance.ts` now includes that field.
Missing/zero wallet inputs fail schema parsing; a changed wallet that does
not match its recorded proof fails with `PreparationError/PROVENANCE`.
No preparation path consults live ownership to fill it.

Execution checks the decoded payload, stored wallet and emitted wallet;
`verify` checks it again with the full configuration identity. The Stage08
`configureNfts` function continues to consume the interface-owned type.
The operator test encodes/decodes the final Solidity ABI and compares its
configuration hash and tuple with the final typed Stage08 ABI.

`rehearsal-data.ts` records explicit original wallets for weighted IDs 4,
26 and 6 and earlier IDs 3 and 9. Their purchase transaction IDs and native
units/components remain explicit. Weighted ID26's recorded purchaser is
`0xc379feb4182211abe71a34858265e4bf5ff35e06`, not its pinned current holder
`0x2e69e40c4a4ab5ca6826850f347acf8076a8063e`.
The acquisition CSV fingerprints are retained in the bindings file.

The operator runbook and stale `blockedGate` reasons now name the phase11
implementation/unit/caller/disabled-route gaps. No unsupported category was
unblocked. Existing synthetic labels and public-execution prohibition remain.
Old payloads without `originalWallet` require regeneration, not fallback.

## Exact final-source commands and results

All commands ran from this worktree. Fork and rehearsal runs used the existing
interactive login credential environment through `/bin/zsh -lic`, with
`PATH=/Users/cyotee/.foundry/bin:$PATH`. No endpoint or credential is printed.
Pipelines used `set -o pipefail`; process exits were observed, not inferred
from compilation or a pending run.

Versions: Forge/Anvil `1.9.1-nightly`,
commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`; compiler metadata
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`; Bun `1.4.2`; TypeScript `5.9.2`.

### Artifact-first specs

```sh
python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationTarget.sol \
  --consumer scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol \
  --consumer scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration -- -vv
```

Exit **0**: **97 passed, 0 failed, 0 skipped, 16 suites**.
Evidence: `spec-final.log`.

### Artifact-first pinned forks

```sh
FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationTarget.sol \
  --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration -- -vvv
```

Exit **0**: **47 passed, 0 failed, 0 skipped, 9 suites**.
Evidence: `fork-final.log`.
Each helper run built current concrete/runtime artifacts with Solar before
testing. Both expanded build/test commands are preserved in
`commands-and-cleanup.json`. Configured roots, profiles and caches were not
changed. Unchanged ordinary/common evidence is reused; those separate suites
were not rerun. The existing recovery population test received only the
necessary explicit-wallet fixture adaptation, not a gas-package change.

### Typed stages, operator tests and types

```sh
forge build --use solar \
  scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol \
  scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol

bun test --timeout 15000 \
  ./scripts/recovery/dtf-migration/preparation.test.ts \
  ./scripts/recovery/dtf-migration/execution.test.ts

node_modules/.bin/tsc --noEmit --target ES2022 --module NodeNext \
  --moduleResolution NodeNext --esModuleInterop --strict \
  --noUncheckedIndexedAccess --skipLibCheck scripts/recovery/dtf-migration/*.ts
```

Each exited **0**. Operator tests: **54 passed, 0 failed, 2 files**, in one
run. Evidence: `script-build-final.log`, `script-tests-final.log`,
`script-types-final.log`. The typecheck log is empty because it passed.
Final LSP checks on the production interface/Targets and preparation tests
reported no diagnostics. Some earlier LSP freshness requests timed out;
JSON LSP is unavailable because Biome is not installed. No dependency was
installed; compiled/tested/typechecked results above are the verification.

### Genuine fail-before result

Before production edits, the new
`test_wrongCurrentHolderCannotUseRecordedPurchaserEntitlement` used the real
weighted ID26 current holder, an actual approval, and the expected original
wallet rejection. Artifact-first execution exited **1**, **0 passed / 1
failed**, with **`next call did not revert as expected`**. The trace shows
the formerly eligible wrong holder completing surrender. It now passes in
the final fork suite. Evidence: `fail-before-authenticated.log`.

Initial setup attempts are not counted as behavioral proof:
`fail-before.log` used the shell's non-Solar Forge and failed with
`solc "solar" does not exist`; `fail-before-solar.log` reached the correct
compiler but lacked inherited `ALCHEMY_KEY`. A login-wrapper quoting attempt
also failed before tests. The corrected single-quoted login command produced
the real fail-before result. No test was weakened to hide these failures.

## Coverage of the changed admission rule

| Required behavior | Executed proof |
| --- | --- |
| Both generations, pre/postactivation | Four real-fork cases in `MigrationOriginalWallet.t.sol:12`; both phases in the real CLI |
| Missing configuration despite ownership/approval | `MigrationOriginalWallet.t.sol:69`; four mined CLI rejections across both phases |
| Zero wallet | Both source configurations in `MigrationNftConfiguration.t.sol`; operator schema regression |
| Wrong current holder, approved operator, original without ownership | Exact distinct error checks in the fork matrix and mined CLI rejections |
| Return without transfer history | Actual source transfers away/back, then exact-funded success; historical weighted ID26 returned to its purchaser |
| Consumption/config correction | Both-source immutable surrender/custody/bond/supply comparison at `MigrationOriginalWallet.t.sol:93`; weighted partial-position replacement also retained |
| Economic-origin/independent overlap | Wallet correction preserves original ID; independent attempts still reject; both ordering directions remain tested |
| Source arithmetic and fresh funding | Weighted ID32 retains 54,436,459 original / 8,071,216 claimed / 46,365,243 remaining; earlier share layout, exact gons/backing and fresh clocks remain tested |
| Callback/funding rollback | Both real generations reject a deliberately refusing external bond recipient atomically; real child-acquisition gas failure and retry remain tested |
| Activation/recovery/funding | Existing selector removal, reward gates, recovery protection/rollback, capital donation and independent issuance suites pass |
| No donation entitlement fallback | Genesis donation assertions retain zero personal configuration/issuance/credit while capital funds the reserve |
| Operator parity | Full-proof wallet mismatch, zero/missing wallet, wallet-independent origin, final ABI/hash and Stage08 tuple tests pass |

External callback receivers use explicitly labeled synthetic contract-wallet
configuration solely to exercise real receiver failure/reentrancy. They are
not substitutes for the source NFT, Migration, manager, registry or funding
children, and not claimed historical purchaser records.

## Actual fixed local CLI rehearsal

```sh
bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --rpc-alias robinhood_mainnet_alchemy \
  --fork-block 108944663 \
  --port 18562 \
  --checkpoint .omo-runtime/dtf-migration-wallet-admission/checkpoints \
  --evidence docs/incidents/2026-09-16-dtf-recovery/migration/wallet-admission
```

Exit **0**, `bounded-rehearsal-complete`; `fullTask9` deliberately remains
`open`. Evidence directory: `rehearsal-1794395193134/`.

The source domain is chain **4663**, L2 block **108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
Fork tests also authenticate source facet/runtime bindings and the distinct
position layouts; Orbit's exposed L1 block number is not substituted for
the selected L2 block. The new funded snapshot is separately recorded as
`0x692579719657ae0bfc12ab710fe5f66d0586f477ebae32786259852a54709769`.

Actual new local proxy:
`0xedf7d9f65b9e57d62a3c4278223170db1308f5f0`.
Registry: `0xaa66038ae217b246f5bf7537104342672e56fed8`.
Package: `0x642fa76f2f7a6b97ec0822d67a785379a92df347`.

The run contains **333 unique mined local transactions**: 220 environment,
37 durable operator-journal and 76 fixture receipts. Of these, **308
succeeded and 25 are deliberate admission reverts**. The 42 nested CLI
commands comprise **34 exit-0**, **6 expected exit-1 DOMAIN rejections** and
**2 deliberate SIGKILL interruptions**; the separate environment-stage
command exited 0. Complete command records and transaction indexes are in
`commands-and-cleanup.json` and `rehearsal-transactions.json`.

`admission-before-activation.json` and `admission-after-activation.json`
retain exact revert data and mined status-0 hashes: four missing-config,
eleven original-wallet, five actual-owner and five already-consumed
rejections. Before/after state assertions cover configuration, owner,
custody, consumption, supply, child backing, gons and caller bond balance.
Five successful surrenders prove exact supply/backing deltas and marked,
exact-gon, fresh 7,776,000-second bonds:

| Phase | Legacy NFT | New bond | Native nine-decimal credit | Actual creation timestamp |
| --- | --- | --- | --- | --- |
| Before activation | Weighted 4 | 6 | 13,872,781 | 1794111233 |
| Before activation | Weighted 26 | 7 | 22,233,172,691 | 1794111248 |
| Before activation | Earlier 3 | 8 | 923,391,925 | 1794111260 |
| After activation | Weighted 6 | 9 | 36,992,599 | 1825676088 |
| After activation | Earlier 9 | 10 | 46,243 | 1825676100 |

These are fixture-domain quotes, not approved operational awards. The later
timestamps include the explicit local maturity warp. Elapsed rewards are
settled separately before measuring each surrender's exact funding delta.

Existing interruption/resume proofs remain actual mined events:

* Donation nonce **2118**, hash
  `0xcdf028aed990fc0bb48e6007b6d31c5aeff2ecaa6486e4f861640f4e80171ee4`,
  was recovered without resending. Funding totals are exactly 1,000e18 WETH
  and 1,000e18 DTF across three capital events.
* Independent issuance nonce **2130**, hash
  `0x3b888fc08982b2e3a098e0a42ffb2b95cc3bd2a2ca441047cc0c33d8e396efad`,
  recovered the same bond 3. Remaining rows actually executed in reversed
  order at nonces 2131/2132, producing bonds 4/5. Each credit is 461.
* The unselected fourth recipient remains `issued=false`, bond ID 0.
  Configuration did not mint supply. Selected independent issuance changed
  supply from 1,000,000,000,000 to 1,000,000,001,383.
* Reordered preparation produced byte-identical manifests and payload
  mirrors. Full replacement preserved delivered issuance and supply.
* Recovery spent 103,958,529 original receipt units plus 11,891 attributed
  accrued units, producing 103,970,420 weighted units, then
  557,321,827,729,285,049,862 DTF; 1e18 DTF was donated to the fixed
  destination. Earlier claim and sale remain claim/sale-and-hold.

## Final bindings and retained limitations

`source-artifact-bindings.json` binds 101 scoped source/test/operator files,
the six read-only authority/acquisition inputs, and five compiled artifacts.
All **614 unique source files** in those artifacts' combined metadata
closures match their embedded keccak256 values: **zero mismatches**.
Its SHA-256 is
`e911566cbcc865410aa8f64af8759cc4a6b2b55bc7147774f97d515969316a1a`.
Unlinked bytecode is labeled and fingerprinted as text, not misrepresented
as deployed runtime. The rehearsal manifest separately binds the actual
proxy, registry, package and 17 installed facet runtime hashes.

The known deployment-feasibility problem remains. Baseline parent deployment
was **42,985,843 gas**; this final-source local parent deployment used
**42,985,865 gas**, transaction
`0x9eceab6b54600e3668de39793899dffeef405e20d28fe7a7fcb1bca930d51540`.
Both exceed the previously recorded **32,000,000** target transaction limit.
The permissive local block/simulation budgets do not solve that held issue.
No target-gas feasibility or public readiness is claimed.

Phase11's other limitations remain: general fungible/claim surrender is
unimplemented; original unit/contribution mappings are not manufactured;
earlier receipt fractional attribution is unresolved; raw TokenStaking
rights lack an admitted ordinary-contract atomic pull/callback composition;
direct claim-vault and SE infrastructure holdings do not establish user
authority; earlier and weighted WETH SE exits remain disabled; LP exits
remain owner-restricted or unsupported; earlier liquid conversion remains
unproved. Native originals and standalone WETH exposure remain incomplete.
The masked earlier mature-close authorization result and optional archive
404 remain historical limitations, not changed findings.

The existing compiler warnings and `lastCallGas` deprecation are retained.
No unrelated test failure is hidden. No required in-scope execution check
is pending, but no full-category, allocation-approval, complete-source-audit,
public-deployment or independent-verification acceptance follows from this
bounded result.

## Cleanup and handoff

The CLI stopped each impersonation in `finally`, closed providers and receipt
subscriptions, copied durable journals into evidence, awaited owned Anvil
PID **71170** exit, and removed its checkpoint root. Its `cleanup.json`
records that sequence. The final cleanup command exited **0** with
`OWNED_NODE_PORT_CHECKPOINT_PARENT_CLEAN`: port **18562** had no listener,
PID 71170 was absent, and the empty owned
`.omo-runtime/dtf-migration-wallet-admission` parent was removed.

Warm artifacts, caches, dependency links and shared services were preserved.
Artifacts were not copied outside the authorized worktree. Prior reports
and inputs remain immutable. `git diff --check` exited 0. The code remains
uncommitted on the requested branch for independent review.
