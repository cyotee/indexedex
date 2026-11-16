# NFT surrender implementation evidence

Status: complete for the bounded two-source NFT implementation. Current
artifact-first Solar build, 91 Migration specifications, 16 pinned fork tests
and 9,932 established ordinary/common regressions pass. Full Migration remains
incomplete under the open gates below. No deployment is authorized.

Baseline independently verified on 2026-11-11: branch
`work/dtf-migration-phase-05`, HEAD
`5021e8d4a62bcbddc555f580ef98f8666d993aab`.
The only initial untracked content was the preserved NFT source evidence.
Root supplied warm-seed exit 0; `out/`, `cache_forge/` and the existing Crane
symlink were observed and preserved.

The complete original implementation plan, phase05 brief, phase01 independent
report and both producer contracts and source-verification report were read.
The latter admits both exact historical NFT read/custody contracts.

Implementation uses distinct fixed chain-4663 interfaces, on-chain frozen
original quotes, permanent collection/ID consumption, separate custody,
current-holder-only safe pull and the existing exact-funded Migration bond
path. No fungible attribution, descendant entitlement or harvest policy is
inferred. All non-NFT full-plan gates remain open.

## Commands and outcomes

- Baseline `git rev-parse HEAD`, `git branch --show-current`,
  `git status --short --ignore-submodules=all`, and requested commit object
  resolution: exit 0.
- Default PATH Forge is Homebrew 1.9.0 and is not used for compilation.
  `/Users/cyotee/.foundry/bin/forge --version`: exit 0,
  `1.9.1-nightly`, commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`.
- Native Solidity LSP document-symbol request timed out; no clean LSP result
  is claimed. The observed Forge LSP process is not a competing build.

No public transactions, commits, delegation or main/integration operations
were performed. All commands ran in the phase05 worktree; original-plan and
phase01/phase04 evidence reads were read-only.

## Implementation decisions

- `legacy/IMigrationLegacyNft.sol` preserves the distinct static five-word
  historical layouts. `MigrationLegacyNftLib` admits only the two specified
  chain-4663 collection addresses, without a mutable source registry.
- Weighted remaining units are original fixed principal less actual claimed
  principal. All five position fields must survive custody unchanged.
  Earlier remaining units must equal authenticated original LP accounting
  shares; effective reward weight, reward debt and physical LP are not principal.
- `configureNftEntitlements` computes C0 on the existing immutable quote book.
  Explicit known-component and evidence fields distinguish unknown inputs from
  known zero. Configuration, permanent consumption and custody use separate
  records keyed by collection and ID.
- The canonical original-origin key includes chain, Migration address, snapshot,
  collection and ID. NFT configuration and existing independent configuration
  and issuance reject known-origin collisions in both orders. This is not a
  general authenticated ancestry proof: arbitrary opaque aliases still require
  operational reconciliation under the open E2 gate.
- The guarded holder-only pull accepts exactly its expected collection,
  operator, holder, ID and empty callback data. The deployed sources call back
  before approval/ownership changes, so actual ownership and unchanged position
  are checked only after transfer returns.
- Both independent and NFT issuance now call the same internal
  `Repo._fundBond` operation after settling existing participation. This is the
  existing exact-mint/approval/child-pull/stake/gons path, not a second issuer.
  The Migration child requires contract recipients to accept the fully funded,
  marked bond while its accounting guard remains held. Ordinary child code is
  unchanged. Failed acceptance reverts the outer funding and legacy custody.
- The single new loading selector is included in the actual six-selector
  activation cut. All seventeen permanent selectors remain installed,
  including surrender and the strictly contextual receiver.

## Current verification receipts

| Run | Actual outcome |
| --- | --- |
| `build-01.log` | Exit 0; artifact-first Solar production closure, 142 build roots / 894 sources / 118 runtime artifact IDs |
| `spec-01.log` | Exit 1; 90 passed, 1 failed, 0 skipped across 14 suites. The existing external hostile-contribution holder did not implement the newly required bond receiver. |
| `spec-02.log` | Exit 0; 91 passed, 0 failed, 0 skipped across 14 suites after adding ERC721 acceptance to that external holder fixture. All original assertions remain. |
| `fork-01.log` | Exit 1 before execution: test-only address checksum and a `Receipt` name collision with StdCheats. Both corrected. |
| `fork-02.log` | Exit 1; two setup failures from comparing Orbit's L1 `BLOCKNUMBER` with the L2 fork-selection number. No fresh block was selected. |
| `fork-03.log` | Exit 1; 13 passed, 1 failed. The late-clock assertion used a compiler-rematerialized `block.timestamp` local across `vm.warp`; actual stored old/new bond timestamps were correct. Replaced the test read with `vm.getBlockTimestamp()`. |
| `fork-04.log` | Exit 0; 15 passed across two suites. Subsequent trace audit found the gas-failure call expectation could be satisfied by the successful retry; superseded by the stronger final witness below. |
| `fork-05.log` | Exit 0; 16 passed, 0 failed/skipped across two suites. Includes corrected exact-count funding-call proof and both-source inconsistent-unit rejection. |
| `regression-01.log` | Exit 0; 9,932 passed, 0 failed/skipped across 589 suites. Both original-plan ordinary V4 DETF and common scopes ran once on the changed inputs. |

The first failure and its trace remain saved. No test was deleted, skipped,
weakened, or made to impersonate/mutate a subject. The full Migration run also
checks actual package/proxy declarations and EIP-170 sizes.

The pinned fork run uses the configured archive alias, exactly block
108944663, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
and its state root. Each fixture checks both proxy hashes, the actual
owner/position/transfer/approval loupe bindings and all three admitted facet
runtime hashes before deploying the genuine Migration system. Execution is
single-threaded with a 10-compute-unit RPC limit; no fresh-pin fallback exists.
The archived header explicitly records L2 number `0x67e5d17` (108944663)
and L1 number `0x19256ab` (26367659). The corrected fixture verifies both,
the hash and state root; it does not rewrite the EVM block context.

## Source-bound fixtures and limits

The fork runs create a fresh registry Migration reserve using real local WETH,
external mintable contribution/rate fixtures, real V3 pools and SEs, and the
real weighted reserve and Migration children. The large funded quote book
accommodates authentic historical contributions without splitting their quote
unit. This local funding is not an operational recovery allocation or a claim
about deployed new-Migration reserve balances.

Original native inputs are read from the preserved phase01 canonical purchase
receipts and earlier NewLock/direct-payment joins, not inferred from current
balances. Weighted fixtures include IDs 3, 4, 25, 26 and 32; earlier fixtures
include IDs 3, 4 and 12. Each configuration records its original purchase
transaction hash. Earlier ID 3 uses 2e18 WETH and zero direct DTF; its routed
intermediate DTF is excluded.

| Exact observation | Current source-bound proof |
| --- | --- |
| Weighted ID 32 | P0 54,436,459; claimed 8,071,216; remaining 46,365,243. Credit is floor(C0 * remaining / P0), not the smaller-input nonlinear quote. |
| Weighted ID 26 | The pinned holder differs from the original purchaser; a further actual transfer changes the only eligible bond recipient. An approved old-holder operator cannot surrender. |
| Earlier ID 4 | Actual reward claim pays 309,005,608,995,105 old DETF without changing 2,281,854,312,954,086,546 original shares. Further holder transfer and surrender retain full C0. |
| Earlier ID 12 | 47,848,240,999,749,918,187,208,884 accounting shares differ from 47,848,240,999,749,918,187,208,985 physical LP assets. Credit uses accounting shares. |
| Both ID 3 identities | Independent source keys; whole custody and distinct new bonds. Earlier ID 3 remains legacy-locked but eligible. |
| Empty identities | Actual weighted principal-only claim creates a reward-only NFT; actual earlier sale burns the NFT. Both reject credit. Reserved, absent, already-burned and zero-credit inputs reject. |
| Claim race | An actual weighted claim after configuration reduces the live fraction; stale minimum rejects before custody, then current credit succeeds. |
| Replacement | Configuration can change after surrender; recorded credit, clock, bond, custody and consumed identity remain unchanged. Known independent overlap remains rejected. |
| Separate instances | Both are genuinely registry-deployed and separately funded. Origin/configuration domains differ; the second cannot take an NFT already held by the first. |
| Late activation | Both source routes execute before and after the actual selector cut; later bonds start 120 days later with their own full 90-day cliffs. |
| Receiver failure | A real contract holder rejects the fully funded new bond; legacy owner/approval, supply, backing, gons, consumption and new NFT all roll back. A later accepting retry succeeds. |
| Funding failure | A 900,000-gas real earlier-NFT surrender reaches the real bond and receipt acquisition; the receipt runs out of gas after actually pulling backing. Entire custody/funding/consumption rolls back. Exact call count two proves both failed acquisition and successful retry reached the receipt. |

The final funding trace shows `createMigrationPosition(2566655548570,holder)`
calling the genuine receipt `exchangeIn`, actual ERC20 transfer into the
receipt, and `OutOfGas` inside that receipt. Following reads show the legacy
NFT still at its holder, zero new receipt backing/gons, no new bond, no
consumption and no surviving parent-to-bond approval. This is an execution
failure during real funding, not a manufactured insufficient balance or
mocked transfer. The earlier `fork-04` limited-gas attempt failed in legacy
synchronization instead and is not claimed as this funding witness.

The final fork contains **18 successful surrender events and 18 corresponding
Migration-position events** across isolated test cases. These are executed
Foundry fork calls, not publicly broadcast or locally mined transaction
receipts. Full traces are retained in `fork-05.log`, SHA-256
`76f46ebc99c4335e8b82577019f3a75b377a2f49cc6b23a9044861ea0f07041b`.

### Final trace index

Line numbers refer to the case start in the complete `fork-05.log`.

| Line | Passing case |
| ---: | --- |
| 2903 | Both sources before/after activation, fresh late clocks and cliff boundaries |
| 5754 | Contract receiver rejection rolls back source custody and newly funded bond |
| 6967 | Earlier contract holder cannot reenter, replay receiver acceptance or activate |
| 7301 | Real receipt-acquisition failure and successful retry |
| 7785 | Postconsumption replacement, duplicate surrender and known independent-origin rejection |
| 8851 | Two real Migration instances, separate domains and no second custody of one NFT |
| 12297 | Burned, absent, reserved and zero-credit rejection |
| 12718 | Actual claim-before-surrender race and stale-minimum rejection |
| 13740 | Earlier accounting shares versus physical LP |
| 14041 | Earlier rewards, holder transfer and preserved disabled harvest |
| 14630 | Both source models reject inconsistent original-unit metadata |
| 14865 | Both pre-transfer callbacks followed by missing-approval rollback |
| 16816 | Weighted reward-only and earlier sold/burned identity rejection |
| 18006 | Same ID in distinct collections and still-locked earlier principal |
| 19196 | Transferred weighted holder, not purchaser or approved operator |
| 20174 | Weighted live partial principal, frozen quote and exact backing |

Typical genuine fork-deployed identities in these traces are parent
`0x4b6C3b2773DF9587F3B4c2960E4556317f7cc0Fc`, bond
`0x5592164Ef3bf47C1e0690CeD5818C26E85e6E6cB`, and receipt
`0x263F26eb92CBeE11c748d325d678A4870B2b4aB7`.
They are new local registry instances, not public deployments.

Foundry's global ABI trace decoder sometimes labels the shared
`positionOf(uint256)` return with the earlier tuple's field names. Tests
decode weighted and earlier values through their separate typed interfaces,
and compare actual byte tuples where required; decoder labels do not replace
the admitted layouts.

Earlier mature close still reverts
`VaultDisabled(0xb7D4Bb379D361AD442CddEE53eA71a33957826A7)`.
No disabled policy is changed and no surrender performs harvest. The phase01
approved-operator redirection and failed/unknown broader recovery routes
remain adverse evidence. The phase04 F1/V1 correction report and its earlier
failed receipts remain unchanged; this work does not relabel them.

## Built production artifacts

Solar metadata reports `0.8.38+commit.e7a91fc7.solar.0.3.0-dev`, without viaIR.
Actual deployed-code sizes observed from the built artifacts:

| Contract | Runtime bytes | Artifact SHA-256 |
| --- | ---: | --- |
| `UniswapV4DetfMigrationFacet` | 20,886 | `4f56cc1ce79e90b53bbac9a7bbf2bc75e89db2a8c522f816ecd506ff37ddcb8f` |
| `UniswapV4DetfMigrationAllocationFacet` | 21,204 | `2f068f103015f760e75e8663a8c8aca711b0d52481175fab03fa65aaada4f827` |
| `UniswapV4DetfMigrationDFPkg` | 16,646 | `bb95e5fcdbd262b2dc40b0d499acb56d1ffbecbfe59ee7919117cf41f69aa779` |
| `UniswapV4DetfMigrationBondNFTVaultFacet` | 9,496 | `3f25518483e843e62ccd318c856f67149fd725a7d468a91cf43764525970ddbe` |

### Exact historical source bindings

| Source/facet | Address | Runtime Keccak-256 |
| --- | --- | --- |
| Weighted collection | `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E` | `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601` |
| Earlier collection | `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391` | Same proxy hash, distinct routed behavior |
| Owner/approval facet | `0xde5a691CEFE1830e8Ff2b65F6657738b0d9B9279` | `0xf709b5311471ef0b02cf7ddaa8f48b9da30647ab9958a3efde1813e5ac4337b8` |
| Weighted position/transfer | `0x3a07364eabA092472d40F0e6788b8891A31faD4D` | `0x325a3b9bf3e616386e03d2a14d0a1fb29820f104a5f433d0b08a88dbdd0bef52` |
| Earlier position/transfer | `0x3AB85813785b43B864F9C171F7ac97d6B76c459b` | `0xe44c05ff19808e8e7096c7e470cb1d40ddaf057f4e53818f1e749621d3632027` |

The live fork binds `ownerOf`/`approve` to the owner facet, weighted
`positionOf` to the weighted facet, earlier `getPosition` to the earlier
facet, and the three-argument `safeTransferFrom` to each corresponding
position facet. Both tuples are five static uint256 words; matching byte
length is not used to choose a model.

## Exact execution commands

Working directory for every command:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-05`.
All compile/test shells prepend `/Users/cyotee/.foundry/bin` to PATH. Fork
shells use `/bin/zsh -lic` to obtain the existing configured archive access;
only key presence was printed, never the key or resolved URL. `set -o pipefail`
preserves failures through each log's `tee`.

Initial concrete-artifact build (`build-01.log`):

```sh
python3 scripts/forge-artifacts.py build \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationTarget.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationDFPkg.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol \
  --consumer 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/**'
```

Full current Migration specification command (`spec-02.log`; `spec-01.log`
used the same command before correcting its external receiver fixture):

```sh
python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationTarget.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration \
  -- -vvv
```

Final pinned fork command (`fork-05.log`; fork-02 through fork-04 used the
same command on their recorded test revisions):

```sh
FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration \
  -- -j 1 --compute-units-per-second 10 --rpc-timeout 120 -vvvv
```

The first fork attempt added the same five changed source arguments as the
spec command; its test compilation failures are preserved in `fork-01.log`.
One invalid monitor-filter request was rejected before launching a command.
No duplicate compiler was started.

Established ordinary/common command (`regression-01.log`, default profile):

```sh
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf \
  --test-root test/foundry/spec/vaults/detf/common \
  -- -vvv
```

The unchanged repository helper expands these into artifact-first
`forge build --use solar` followed by `forge test --use solar` with the exact
selected roots and unrelated-root exclusions. Full expanded argv is at the
start of every log. Neither `FOUNDRY_TEST` nor configuration/dependencies were
changed. Warm caches were retained.

## Cleanup and change boundary

All owned build/test/inspection sessions exited. The accidental read-only Git
pager was closed with `q` and exited 0. A final process census found no Forge
build/test, Solar compiler or Anvil process; only the previously observed
shared `/opt/homebrew/bin/forge lsp --stdio` service remained and was left alone.
No Anvil node, listener, temporary runtime root, public transaction or
persistent impersonation was created. Forge forks are in-process isolated
test states and ended with their runners. No cleanup is pending.

Final branch and HEAD remain `work/dtf-migration-phase-05` and
`5021e8d4a62bcbddc555f580ef98f8666d993aab`. Tracked diff whitespace check
with `--ignore-submodules=all` exited 0. The pre-existing Crane symlink and
warm caches are preserved; ordinary/common/Crane/config/snapshot sources
were not edited.

Changes are limited to eleven Migration files including its TestBase and two
new legacy interface/library files, three existing specification files, one
new configuration specification, three new fork files, and this owned
implementation evidence directory. Existing source-lane files and
phase01/phase04 evidence remain read-only. The two consumed producer-contract
SHA-256 values still match the source gate:

- weighted: `02aad997374190bf8f5428029c8fb80eed102ba63a83752113250118bd313d85`
- earlier: `f090bb5f1bcb9ae74fe2c7a9dbbe1d87f5fced9a6b3d346867d83b92265025b1`

Compiler/lint warnings remain visible in the logs; none was suppressed.
Native LSP fresh diagnostics timed out, so no clean LSP claim is made.
The successful Solar builds and all required test scopes are the executable
validation. No whole-repository release run, operational allocation approval,
operator rehearsal or public deployment is claimed.

## Remaining full-plan gates

All non-NFT gates remain open: authenticated fungible/descendant ancestry,
operational exposure disjointness, TokenStaking ordinary-caller composition,
restricted fungible LP/SE exits, bounded staged harvest/conversion/donation,
actual recovery quote-domain and funding inputs, resumable operators, complete
product invariants, gas/batch limits, and final full-product release validation.
Both liquid generations, both NFT models, weighted sDETF, earlier receipt, SY,
TokenStaking/claim vaults, underlying SE shares and fungible LP remain required.
This bounded NFT implementation neither omits a category nor closes the
original full-plan F1-F4 gates.
