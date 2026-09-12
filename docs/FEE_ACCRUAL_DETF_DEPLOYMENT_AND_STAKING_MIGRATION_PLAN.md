# Fee-accrual DETF deployment, staking migration, and UI rehearsal plan

**Date:** 2026-09-11  
**Status:** Local migration completed at block 60445063. The existing staking contract is Wrapped, all deposits and rewards migrated in 60 native calls, and DTF remaining is zero. The existing staking SY backs the claim vault. UI integration and public-mainnet release gates remain open.  
**Product:** [Fee-accrual DETF composition PRD](../contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/FEE_ACCRUAL_DETF_COMPOSITION_PRD.md).  
**Deployment baseline:** [4663 architecture PRD](./ANVIL_ROBINHOOD_MAIN_ARCHITECTURE_PHASE_STAGE_PRD.md).  
**Objective:** Add the specified three-leg composition to the maintained Robinhood deployment workflow, migrate the existing staking contract through its existing public functions, and leave a reproducible local environment for developing and testing the complete UI.

## 1. Scope and fixed requirements

- Fork Robinhood mainnet at the latest available block when starting a fresh rehearsal; record that block and hash and retain the same fork through deployment, migration, and UI testing. Use chain ID 4663 with EIP-170 enabled.
- Reuse the existing CREATE3 factory, diamond factory, hook factory, IndexedEx Manager and Fee Collector. Reuse the existing staking instance and its real forked storage. Do not redeploy those components to make a test pass.
- Deploy the composition specified by F01–F12: one unified V4 DETF with the weighted reserve's raw DETF self-leg, WETH mapped to the Pons DTF/native-ETH liquidity SE, and DTF mapped to a distinct single-asset Custody SE.
- Bootstrap the DETF before migration. Use the staking contract's `setTargetDetf`, `migrateToClaimVault`, and user `withdrawClaim` functions. Deposits and remaining reward reserves migrate together through `migrateToClaimVault`; the owner rejected rescue/donation. `completeWrap` is a controlled residual-finalization path, not an automatic success fallback.
- Preserve funded staking, bonds, price gates, reserve-swap fallback, fees and reserve ownership under the current DETF alignment PRD. The new composition does not create a parallel DETF lifecycle.
- Keep the completed deployment available on persistent Anvil for the UI. Forge tests on an isolated fork do not by themselves populate that node.
- No public-mainnet transactions, staking storage rewrites, token-balance fabrication, replacement core, or migration-contract upgrade is included. This file specifies proposed implementation work; it does not execute it.

## 2. Current scripts and gaps

| Reviewed source | Current behavior | Required change |
|---|---|---|
| `scripts/shell/lib/rh_4663_stages.sh` | `all` is architecture-only. Includes wrapper package 06-10; TokenStaking 06-08/08-01 and funding 08-02 are opt-in. | Add an explicit composition/rehearsal catalog that reuses the core and adds SE instances, weighted hook, DETF, bootstrap, and migration. Preserve the meaning of architecture-only `all`. |
| `scripts/foundry/anvil_robinhood_main/deploy_all.sh` | `rehearse-packages` imports existing core records, impersonates manager owner locally, and deploys selected product packages. Fork-latest is supported. | Extend the maintained orchestrator with composition and migration commands, phase checkpoints, distinct signer roles and live-state resume checks. |
| `Phase_08_Stage_01_TokenStakingDtf.sol` | Deploys a new staking instance; it does not attach to and migrate the existing one. | Do not run this deployment stage for migration. Load and verify the existing address in preflight. |
| `Phase_08_Stage_02_TokenStakingNotifyRewards.sol` | Funds streaming rewards from the sender's full DTF balance. | Do not run it automatically during migration; preserve the existing principal/reward reserve. Use exact recorded fixture amounts only in a separate rehearsal setup branch if necessary. |
| `Phase_09_Stage_01_ExportFrontend.s.sol` | Architecture export writes empty strategy/DETF/featured lists and a public RPC URL. | Add a composition export path for verified instances, the existing staking contract, claim vault, phase, pools and local environment identity; prevent subsequent architecture export from erasing that bundle. |
| `scripts/foundry/anvil_robinhood_fee_detf/` | Legacy Pons V1/V3 liquidity, CP reserve, older CHIR composition, separate foundation/core deployment, historical fixed-block defaults. | Reference only. Do not run it or port its economics into this three-leg V4 composition. Update its README to point to the new plan when implementing. |
| `scripts/foundry/anvil_robinhood_testnet/Phase_08_Stage_01_FeeDetf.sol` | Empty library referring to an older leaf-DETF stage. | Not an implementation of this deployment or migration. |
| `test/foundry/fork/robinhood_4663/RobinhoodReleaseRehearsal.t.sol` | Broad production-component matrix, but setup deploys a new collector and rotates `feeTo`. | Add a separate reuse-only composition/migration suite. Do not inherit the collector-replacement setup for reuse evidence. |
| `TokenStaking.t.sol`, `TokenStaking_PonsUv4Detf.t.sol` | Cover reward reserve rescue, migration chunks, wrapping and user claims in production fixtures. | Retain and extend; add the exact weighted + custody composition and the actual forked staking instance. Existing fixture success does not establish deployed-code compatibility. |
| `frontend/apps/dtf/e2e/token-staking-overlay-live.spec.ts` | Requires phase Staking and skips later phases. | Add required Migrating/Wrapped coverage; no successful full-rehearsal report when required cases skip. |

The owner resolved the custody prerequisite by selecting a separate instance of the enhanced fee-free SY/SE rebasing-aware ERC4626 package, retaining its +10 decimal offset. This supersedes the initial standalone-Custody-SE proposal. Its 28-decimal DTF shares require the weighted-hook extension and correctly normalized provider rates before deployment.

## 3. Recorded identities and fork preflight

These addresses are **repository manifest values**, not live verification performed for this plan:

| Role | Recorded address |
|---|---|
| CREATE3 factory | `0xD7786b10BC8Bc97dc7651CAb7B97086c8b227882` |
| Diamond factory | `0x976949aB55830fA4794bF40C88ea7D7567931003` |
| Hook factory | `0x8BB5FCC67e8CCa44DC41dd08A5e2b2B392C22945` |
| IndexedEx Manager / vault registry | `0x09682b00D873D913ada0bB69B4D4c9631810d0bc` |
| Fee Collector | `0x20af9A1e21a59a411cd3b0C40E70AF9084770b2E` |
| Existing TokenStaking | `0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00` |
| DTF staking token | `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01` |
| Recorded staking owner | `0x72BeA6Fa3E68EF18c87D045Aac7C4Aa5249d933B` |
| Recorded staking claim-vault package | `0xaD70Af09fd9CEDe7575BDf2b16a5e4A7f7465040` |

At run start, resolve the remote latest block once, record number/hash/timestamp, and start a new local Anvil from that pinned latest-at-start block. Record source chain ID, local RPC, run ID, Anvil version, compiler/build identity and all deployment fingerprints. A replay pins the recorded block; a refresh selects a new latest block and creates a new run directory. Do not restart/reset the UI's active node implicitly.

Verify code, loupe selectors, dependency references, live owners/operators, manager registry permissions, and current `feeTo`. Check the previously identified CREATE3 registry authorization issue explicitly. An occupied address or matching JSON key is not sufficient. A missing permission or incompatible deployed component is a real blocker: do not fix it with `etch`, replacement factories, collector rotation or manifest relabeling.

Discover the actual graduated Pons DTF/native-ETH PoolKey and verify token identities, PoolManager, hooks, fee, tick spacing, graduation state and position availability. Verify Universal Router, Permit2, WETH and liquidity-SE capabilities against deployed code. Do not launch a substitute token or use the old V3 fixture for the primary rehearsal.

Read existing staking `owner`, `stakingToken`, `phase`, `targetDetf`, `claimVault`, `totalSupply`, `reserveRemaining`, `rewardReserve`, reward clock and required function selectors. Resolve installed facet bytecode and the stored claim-vault package against matching deployed-source/artifact evidence. Source in the working tree is not proof of what the existing diamond executes. Read-only storage inspection may establish the package reference if no getter exists; do not write it.

Initial migration requires phase Staking, positive principal supply, and backing at least equal to principal. An already-Migrating instance may resume only against its existing target and verified journal; an already-Wrapped instance enters verification/UI mode. Never overwrite an incompatible target or create a fresh staking instance under the existing address label.

## 4. Existing migration mechanics that scripts must preserve

The deployed historical staking bytecode differs from current `TokenStakingTarget.sol`.
Use the approved adapter with the historical sequence verified on its actual fork:

```text
owner: setTargetDetf(migrationAdapter)                [Staking only]
owner: migrateToClaimVault(amount, minSYOut, deadline)
    first successful chunk: stop streaming rewards; enter Migrating
    DTF -> adapter.mint -> canonical DETF purchase -> DETF-backed receipts
    approve receipts to adapter; adapter.exchangeIn -> existing staking SY.deposit
    lazily deploy claimVault from staking's stored package, with SY as asset
    deposit static SY held by staking into that ERC4626 vault
    no remaining DTF: enter Wrapped; otherwise await another chunk
user: withdrawClaim(stakeAmount)                     [Wrapped only]
    redeem proportional claim-vault shares; pay static SY to user
user: stakingSY.redeem(user, syAmount, realSDetf, minSDetfOut, false)
    synchronize funded rewards; redeem static ownership for actual sDETF
```

`migrateToClaimVault` supports chunking, charges no second user deposit, and leaves principal
weights unchanged until withdrawals. The adapter uses canonical DETF routing, including
primary issuance and reserve-swap fallback. `minClaimOut` bounds acquired **SY**, while the
historical intermediate mint uses minimum zero. Quote the entire native call because DETF
issuance can settle funded growth before the SY is issued.

For principal weight `u`, remaining total principal weight `P`, and staking-held wrapper
shares `W`, `withdrawClaim(u)` redeems `floor(u*W/P)`, except the final total-weight
withdrawal redeems all W. The immediate output is static staking SY, which users redeem
for actual sDETF. Wrapper virtual-offset residuals may remain even after all real wrapper
shares are redeemed; do not claim the final user receives all backing regardless of those
rules. Static SY prevents pending rebases during transfer from underpaying the exiting user.

The first migration disables ordinary `stake`, DTF `withdraw`, `getReward`, `exit` and new reward funding by changing phase. Existing `reassign` remains callable: it transfers principal weights and proportional stored rewards between accounts. Tests and UI accounting must handle it instead of assuming every balance is frozen in Migrating/Wrapped.

### 4.1 Reward reserves: migrate through the existing function — owner confirmed

**Confirmed allocation:** Deposits and all remaining rewards convert together into users' proportional funded staking claims, held through static SY. This is a fixed implementation requirement; the migration runner must not offer a separate reward-rescue/donation mode.

The owner explicitly rejected reward rescue and donation. Migrate the entire actual DTF balance, including deposits and remaining reward reserves, through `migrateToClaimVault(amount, minClaimOut, deadline)`. No separate reward-transfer branch is required. Do not call `rescueRewardReserve`, `recoverERC20`, or a DETF donation function as part of migrating these funds.

The function bounds each chunk against `stakingToken.balanceOf(address(this))`, not principal `totalSupply`, so it can convert principal and rewards together. Its first successful call stops streaming rewards and enters Migrating atomically with the conversion. Later chunks consume the remaining actual DTF balance. Remaining unclaimed and unstreamed rewards enter the common SY-backed claim pool; `withdrawClaim` allocates that pool by remaining principal weights, rather than individually settling stored `earned()` balances. This is the contract's documented migration behavior.

`reserveRemaining()` is the amount still available to migrate. `rewardReserve()` is diagnostic only: it computes excess DTF over unchanged principal weights and ceases to represent the original reward bucket as principal is converted. Never subtract principal from the migration budget or use that diagnostic to extract rewards.

Before the first successful chunk, ordinary user withdrawals/reward claims can change available DTF; refresh the amount and simulation immediately before submission. Once Migrating, those original-token exits are disabled. A failed first chunk rolls back the phase and reward-clock changes with all token movements. The existing `reassign` behavior remains covered as described above.

### 4.2 Claim-vault dependency is fixed on the existing instance

`TokenStakingDFPkg` supplies a claim-vault package at initialization; current TokenStaking has no setter for it. Updating stage 06-10 or deploying the planned SY/SE-enhanced wrapper does not redirect this existing staking instance.

The primary fork rehearsal must use its actual stored package and deployed ERC4626 behavior. The migration itself only requires ERC4626, so it must not wait for the unrelated direct-buffer rebasing-wrapper design by assumption. Use the approved adapter and existing staking SY to handle legacy selectors and pending funded rebases. Test nested calls against the actual historical wrapper; replacing the staking instance, storage or package is not an acceptable rehearsal shortcut.

Export the actual claim-vault address and capabilities created by migration. Do not advertise it as registered/SY/SE-capable merely because a newer package exists in the registry. New enhanced-wrapper deployments have their own plan and acceptance gates.

## 5. Composition configuration and prerequisites

**Owner-confirmed metadata:** set both the fee-accrual DETF's name and symbol to exactly `DTF-DETF`. The constants are pinned in `scripts/foundry/anvil_robinhood_main/FixtureEconomics.sol` as `FEE_ACCRUAL_DETF_NAME` and `FEE_ACCRUAL_DETF_SYMBOL`. The Phase 08-03 instance stage assigns these before address prediction and deployment:

```solidity
args.name = FixtureEconomics.FEE_ACCRUAL_DETF_NAME;
args.symbol = FixtureEconomics.FEE_ACCRUAL_DETF_SYMBOL;
```

Deployment/reuse verification must assert live `name()` and `symbol()` both equal `DTF-DETF`; Phase 09-02 must export the verified values. A legacy `CHIR` or `Test DETF DTF-DETF` instance does not satisfy these metadata checks. Existing deployed tokens and historical exports are not renamed by this source change. This requirement applies to the fee-accrual DETF itself, not a renaming of its underlying DTF, sDETF or bond NFT.

Before implementation can execute this deployment, close PRD O01–O08 in a versioned configuration document. No hidden test-fixture economics may become deployment defaults.

| Configuration | Required resolution |
|---|---|
| Base pool and infrastructure | Verified deployed DTF/native-ETH PoolKey, liquidity-SE instance or exact new instance args, router/core identities. |
| Custody SE | Reviewed share scale, accounting/donation/dust policy, fees, SY/SE/quote interfaces, pretransfer rules, registry declaration and provider semantics. |
| Weighted reserve | Exact normalized weights, sorted token/SE/provider/decimal vectors, creation/opening prices, thresholds and liquidity permissions. |
| Routes | Custom WETH→liquidity and DTF→custody mint/donation rows; DTF custody burn output; explicit bond rows and first-bond funding of every required leg. |
| Bootstrap funding | Named actor, exact amounts, provenance and minimum outputs. Existing user staking principal and rewards are not silently used for bootstrap. |
| Migration | Confirmed pooled conversion under §4.1, bounded chunk size, nonzero minimum-output policy and maximum total residual. |
| Fee inflow | Identified existing collector withdrawal/liquidation caller and ETH→WETH→donation path. `pushSingleTokenFee` only synchronizes recorded reserves; it is not a liquidation/forwarding function. |

Use measured full-call quotes for migration limits and reject zero expected SY or wrapper shares. The reviewed run config must specify `slippageBps`, maximum chunk input and deadline TTL; derive `minClaimOut = floor(quotedClaimOut*(10000-slippageBps)/10000)` and reject a rounded-zero minimum. Do not copy min=0 from existing smoke tests. Select chunks no larger than the configured limit and actual remaining balance; reduce only after classifying a reproducible amount-related failure, with a bounded attempt count. Unrelated authorization/route failures stop immediately.

**Owner decisions, 2026-09-11:** use a separate instance of the fee-free SY/SE rebasing-aware ERC4626 wrapper for DTF custody; use reserve weights 60% DETF, 20% WETH, 20% DTF. The existing staking claim vault uses its stored package with the DETF's existing static staking SY as asset. Launch very rich with minimal bootstrap liquidity, targeting months or years of expansion; measure after migration as well as before it. The owner subsequently confirmed 100× opening/creation prices on both capital legs, 10% annual expansion closure, and a 0.001 WETH bootstrap plus quoted DTF from the staking owner when funded. Retain the wrapper’s +10 offset and extend weighted-hook share support to 36 decimals. Normalize provider rates between whole share and asset units; accepting 28-decimal metadata alone is insufficient. Keep actual decimals in all bindings and provider calculations.

## 6. Proposed additions to the maintained Phase/Stage tree

Use `scripts/foundry/anvil_robinhood_main/` and `scripts/shell/lib/rh_4663_stages.sh`; do not create a third orchestrator or revive the legacy fee-DETF script tree. Each proposed stage has the standard `.s.sol` wrapper, `.sol` library, and a JSON record. Add these rows to the architecture PRD's separate composition-extension catalog before implementing them. Existing 08-01/08-02 retain their meanings.

| Stage | Proposed basename | Responsibility |
|---|---|---|
| 01-04 | `FeeAccrualPreflight` | Read/verify existing core, Pons pool and staking; record fork/config/code identity. No replacement deployment. |
| 06-10 (existing) | `RebasingAwareERC4626Pkg` | Deploy/reuse the fee-free SY/SE wrapper facets and registered package. No new standalone custody package. |
| 07-01 | `FeeAccrualLiquiditySe` | Attach a matching existing V4 position SE or deploy a registered one for the verified Pons pool, according to explicit configuration. |
| 07-02 | `FeeAccrualCustodySe` | Deploy/reuse registered DTF custody instance. |
| 07-03 | `FeeAccrualRateProviders` | Deploy/reuse the reviewed WETH-per-liquidity-share and DTF-per-custody-share providers. Verify live/projected units. |
| 07-04 | `FeeAccrualLiquiditySeed` | Initialize the empty liquidity SE with both WETH and DTF before DETF route validation; charge the seed against the total bootstrap budget. |
| 08-03 | `FeeAccrualDetf` | Predict DETF, deploy weighted hook with predicted DETF owner, initialize pair doors through staged package flow, deploy unified DETF and verify every binding. |
| 08-04 | `FeeAccrualBootstrap` | Fund and execute the required first bond; prove reserve live, both capital legs and raw DETF self-leg funded, correct bond receipt and staking backing. |
| 08-05 | `StakingMigrationTarget` | Verify existing staking and live target, then call `setTargetDetf` only if appropriate. No staking deployment. |
| 08-06 | `StakingMigrationSnapshot` | Read and record principal, rewards, full DTF balance and the confirmed pooled-conversion policy. No fund transfer. |
| 08-07 | `StakingPrincipalMigration` | Execute one bounded, fully simulated `migrateToClaimVault` chunk per invocation; record receipt and actual deltas, then continue/resume from live state. |
| 08-08 | `StakingMigrationFinalize` | Verify automatic Wrapped completion. If approved residual policy applies, use `completeWrap` with its exact reviewed amount cap and destination. |
| 09-02 | `ExportFeeAccrualFrontend` | Export verified composition plus actual staking/claim-vault state to the run-specific local UI bundle; no transaction. |

Command interface (source added; full execution validation pending):

```text
fee-accrual-packages      reuse core -> current required registered product packages
fee-accrual-prepare       preflight -> required product packages -> SEs/providers -> DETF -> first bond -> export
fee-accrual-migrate       target -> snapshot -> pooled migration chunks/finalization -> export
fee-accrual-verify        read-only live postconditions and migration reconciliation
rehearse-fee-accrual      prepare -> pre-migration UI checkpoint -> migration checkpoints -> full verification/UI checks
```

The full local rehearsal includes deployment and migration. Separate prepare/migrate commands allow UI work at intermediate phases without resetting or rerunning the whole stack. All commands reuse the same stage libraries and manifests. Only the local rehearsal shell rejects nonlocal endpoints and requires `anvil_nodeInfo`, chain 4663 and matching fork identity; chain ID alone is not sufficient to distinguish Anvil from public mainnet. Use actual manager owner and staking owner as separate signer roles, impersonated only locally; retain a separate human UI wallet.

Run only missing product-package stages after core preflight, including existing V4 SE, rate providers, weighted hook, unified DETF and child packages as required. Never include Phase 02 factory creation or Phase 04 core creation in the reuse catalog. `FORCE` must not override core reuse or replay migration money transfers.

## 7. Migration execution, resume and residual handling

1. Record pre-migration fork/state evidence and the user ledger. Reconstruct stakeholder addresses from historical staking/reassignment/withdrawal events where available, reconcile their live principal sum with `totalSupply`, and separately record known reward claims. A missing complete ledger is an evidence gap, not permission to invent balances.
2. Verify actual DETF is bootstrapped, the adapter binds it to existing staking and DTF, staking SY wraps its real sDETF, the DTF route maps to custody, and providers plus primary/fallback paths pass rehearsal tests.
3. Simulate the full-balance migration's first chunk from the actual staking owner. Check relevant balances again immediately before each submitted transaction.
4. Execute stage 08-05 and the read-only 08-06 snapshot, then migrate deposits and reward reserves together under §4.1. Persist only confirmed receipts as completed mutations.
5. For each chunk, snapshot DTF, DETF receipts, static SY, real sDETF and claim-wrapper balances, principal weights, phase and allowance state. Simulate the exact amount/minimum/deadline, submit locally, verify receipt, record events and reconcile deltas. Successful previous chunks are not repeated if a later one fails.
6. On phase Migrating, verify ordinary DTF withdrawals/claims are unavailable and preserve remaining DTF for subsequent chunks. Never respond to a revert by draining all remaining capital with `completeWrap`.
7. Prefer normal zero-reserve automatic transition to Wrapped. If residual is nonzero, prove why it cannot be economically converted, compare against an explicit approved raw-unit cap, and use only the approved destination. `completeWrap` transfers **all** remaining DTF and has no onchain dust ceiling. An operator script must not mislabel a large balance as dust. If no residual policy is approved, stop with a resumable Migrating checkpoint.
8. Reconcile Wrapped custody, actual claim-vault backing and user previews; perform user withdrawals in a test branch, preserving the human-review checkpoint.

Every stage record includes run/config hash, fork block/hash, signer, pre/post block, transaction hash, input amounts, minimums, actual outputs, phase and relevant addresses. Record principal/reward composition at cutover and reconcile the entire DTF balance through the single migration path. Calculate amounts from live balances plus receipt evidence, never simply replay the initially configured amount. A simulation artifact is not a broadcast receipt.

A phase/nonce/event/balance mismatch stops the runner for reconciliation. `--from-phase` is only a scheduling aid, not proof prerequisites happened. For fresh deterministic deploys, match bytecode/config/registry and sorted bindings; for bootstrap and migration, inspect live state and receipts. Never use code-presence skip keys as migration completion evidence.

## 8. Persistent rehearsal and UI checkpoints

Use `.scratch/fee-accrual-rehearsal/<run-id>/` for config, manifests, receipts, state evidence, local frontend artifacts and reports. Keep checked-in public 4663 artifacts untouched. Import the existing staking address into the local bundle; do not omit it when exporting package or instance updates.

| Checkpoint | State available to UI | Required demonstration |
|---|---|---|
| A — Before cutover | Target DETF live; existing staking still Staking | Existing principal/rewards render; stake, withdraw and reward claim work for funded test users. |
| B — Migrating | At least one successful chunk, remaining principal token balance | Phase updates; original-token deposit/withdraw/claim controls are unavailable; balances and migration status do not imply Wrapped claims are executable. |
| C — Wrapped | Migration complete; users have not all withdrawn | `previewClaim` renders SY and its sDETF redemption value; partial/full `withdrawClaim` and subsequent SY redemption work. |
| D — After user exit | At least one user exited; another remains | Correct weight removal, SY receipt, redemption into sDETF, delayed funded growth and final-holder redemption. |

Create named snapshots/state dumps with a checkpoint manifest; snapshot IDs are valid only on the node that created them. Reverting a snapshot requires refreshing the UI bundle/state version and invalidating transaction caches. Do not restore a checkpoint underneath active browser tests or a user's pending transaction. Preserve C for interactive UI review; execute destructive withdrawal scenarios on a separate branch/serial snapshot lifecycle.

Use real forked stakeholders for migration fidelity. For additional UI actors, transfer DTF from a verified funded account or acquire it through the actual pool, then stake through the existing function before cutover. Record fixture-only changes separately; fund gas with local ETH balance methods only. Do not edit ERC20 storage to create principal/reward history or impersonate a replacement staking deployment. If the fork has no stakers, preserve that observation and label any added test stakes as fixture setup.

Update the current frontend sources, not the stale `frontend/app/` paths in older skill examples:

- `frontend/apps/dtf/app/components/landing/TokenStakingOverlay.tsx`: correct Staking/Migrating/Wrapped controls, partial claim input, SY claim and sDETF redemption display, and links to the actual DETF rather than the adapter.
- `frontend/apps/dtf/app/lib/tokenStaking/abi.ts`: verified deployed views including target, claim vault, remaining reserve and supply; preserve existing user function signatures.
- `frontend/apps/dtf/app/lib/tokenStaking/display.ts`: use token-specific decimals. Claim SY and sDETF both have 9 decimals but distinct values; neither may be formatted as 18-decimal DTF or confused with claim-wrapper shares.
- `frontend/apps/dtf/app/lib/tokenStaking/resolveAddress.ts`: resolve the selected environment's verified staking address; reject stale env overrides that disagree with the run.
- `frontend/apps/dtf/app/providers.tsx` and the current protocol artifact registry: ensure selected addresses, reads, wallet writes and router simulation all use the same local run. A 4663 chain ID does not distinguish local from public RPC.
- `frontend/packages/protocol/src/addresses/`: extend environment-aware bundle loading for isolated composition exports rather than overwriting public lists. Export liquidity/custody SEs, actual DETF, adapter, staking SY, real sDETF, actual claim vault, reserve hook, three pair keys, providers, bootstrap status and migration checkpoint.

Retain the existing DETF bond/staking/portfolio flows and add the PRD's Universal Router routes. Show actual quote, hook fees, minimum output, deadline and residual handling. Do not advertise legacy claim-vault SY/SE capabilities, guaranteed appreciation, or guaranteed round-trip profit.

## 9. Testing plan

### 9.1 Script and hermetic integration coverage

Create a production-composition TestBase and tests under `test/foundry/spec/protocols/staking/token/` and the unified V4 DETF suite. Use real factory-created contracts, manager registry, custody SE, V4 SE, weighted hook, Pons components, DETF, sDETF and claim vault. Underlying harnesses may test hostile behavior, but no mocked staking/DETF/registry SUT.

Required tests:

1. Full sorted three-leg deployment and first bond, registry membership, both SE bindings, all pair doors and expected providers; rejection of the old CP/V3 topology.
2. Existing migration selectors and owner authorization; unset/wrong/inert target; wrong staking asset; incompatible sDETF or claim package; atomic failure on missing wrapper selector.
3. Unequal user stakes, early reward claims, accrued unclaimed rewards, unstreamed reward reserve, no rewards, direct DTF transfers, partial withdrawals before cutover and `reassign` in each phase.
4. Principal plus accrued/unstreamed rewards migrate together, including chunks exceeding principal alone. Assert reward-clock stopping, proportional wrapped claims, and no rescue/donation call in the migration runner. Preserve unrelated existing rescue unit tests as contract regressions; test pre-cutover balance changes.
5. One-shot and multichunk migration; exact-input DETF primary route and mandatory fallback; nonzero minClaimOut equality/one-unit failure; expired deadline; insufficient balance; failed first chunk rolls back phase; failed later chunk preserves previous completed work.
6. `claimVault` deployed once from the actual configured package; DTF/receipt/DETF/SY/wrapper allowance cleanup; funded rebase during and between chunks; existing wrapper preview/execution behavior and no duplicate credit.
7. Normal zero-DTF transition to Wrapped; exact bounded residual completion; reject runner attempts to complete with large capital or wrong destination; no automatic rescue on an unrelated migration failure.
8. Partial/full user `withdrawClaim`, independent floor arithmetic, final-holder wrapper-share remainder, wrapper dust, post-migration rewards and no double claim. Assert immediate static SY payout and subsequent actual sDETF redemption, both in native 9-decimal units.
9. Rerun after every stage and interrupted receipt/journal writes; no second bootstrap, duplicated migration debit or wrapper deployment. Detect stale/wrong-run manifests and failed transactions.
10. Confirm every reused core address/code hash and `feeTo` is unchanged. Do not call the general rehearsal's collector-replacement helper.

### 9.2 Fork fidelity and persistent-node coverage

Add `test/foundry/fork/robinhood_4663/FeeAccrualDeploymentMigration.t.sol`. Attach to the run's deployed products and actual forked staking instance. Keep the fixture setup reuse-only; avoid the parent setup that deploys core contracts. Verify deployed legacy selectors as well as source-compatible fresh contracts.

Separate these two evidence types:

- **Isolated Forge fork tests:** replay adversarial state changes, failed chunks, reward races, time changes and complete exits without altering the UI node.
- **Persistent Anvil script rehearsal:** confirm actual local transaction receipts, deployed contracts and migration state that the browser subsequently reads. Verify RPC postconditions independently after each stage.

Use the Pons native-ETH pool for all four PRD §9.2 route shapes. Test weighted-first prepayment without incidental PoolManager funds, shared unlocked PoolManager constraints, both provider contexts, full-route quote/execution parity, exact-input/output limits, correct payer, Permit2, router residual refunds and atomic failure. A WETH-only or different-PoolManager fixture is not a substitute.

Exercise fee inflow through the actual supported collector/liquidation path, wrapping ETH and donating WETH, plus DTF donations through custody. The current collector push method does not do this automatically. If no compatible deployed liquidation route exists, record that dependency instead of claiming automation from a manually minted test balance.

### 9.3 Fuzz and stateful invariants

Fuzz user principal weights, rewards, chunk sizes, claim order, reassignment, rebase timing, minima and residuals. Use an independent model for share allocation and account for external funded gains. Require:

- Principal weights sum to staking totalSupply before and after transfers/claims.
- Original DTF is accounted for across remaining staking balance, successful converted input and approved residual; each original unit is classified once.
- Staking-held wrapper shares reconcile minted shares minus redeemed shares; underlying static SY, its sDETF ownership and funded DETF backing reconcile independently of original DTF price.
- Remaining rewards enter the same wrapped claim pool as principal and are allocated by principal weights; no migration assets are rescued or donated.
- Phase transitions are monotonic under contract rules; failed first/later calls have the specified rollback; unauthorized actions cannot progress migration.
- Final completion cannot be reported with unexplained missing principal, duplicated migration input, zero-output successful chunks or unresolved large residuals.

Run 10,000 cases per migration fuzz property and 1,000 invariant runs of depth 100 for three recorded seeds (1, 17 and 257, encoded as 32-byte hex values). Use existing default-profile environment overrides, assert effective Foundry configuration and nonzero successful coverage of each phase/route. Preserve failures as deterministic regressions. No all-reverting handler campaign passes.

### 9.4 Browser money-path tests

Extend `token-staking-overlay-live.spec.ts` and add `fee-accrual-migration-live.spec.ts`. Include both in the package's `test:e2e:live` command. Use the existing injected EIP-1193 wallet and real RPC receipts; required cases fail clearly if the selected checkpoint, funded actor, RPC, artifact fingerprint or contract is absent.

At A test stake/withdraw/getReward; at B test phase gating and status refresh; at C/D test partial/full withdrawClaim, SY redemption, actual sDETF balances, portfolio updates and no double claim. Verify the 9-decimal sDETF display against raw RPC amounts. Include existing DETF bond/mint/burn/stake flows and all required cross-pool routes. Owner migration orchestration stays in operator scripts; user UI does not acquire owner permissions.

Run browser tests sequentially against controlled checkpoints. Require correct recipient balance changes, allowance effects, events/receipts and returned residuals, not merely enabled buttons or submitted hashes. No skip-only full-deployment pass.

## 10. Implementation order and review gates

1. Apply the owner's confirmed pooled migration and resolve the remaining PRD O01–O08 configuration, with an explicit custody implementation specification and deployment economics. Record unknown live identities as mandatory preflight inputs. The implementer must not select product behavior.
2. Amend the architecture PRD with §6's separate instance/migration catalog; implement the preflight/config/journal and reuse-only guards first.
3. Reuse the enhanced fee-free wrapper package for custody, resolve weighted-buffer decimal compatibility, validate providers/router compatibility, and update only the required product package stages.
4. Add SE/provider/hook/DETF/bootstrap stages and deterministic/live-state verification.
5. Add migration stages around existing staking functions, preserving the actual claim-package dependency and confirmed pooled migration; cover interruption/resume before running money paths.
6. Add isolated exports, phase checkpoints and browser functionality/tests. Establish an initial Staking checkpoint so UI development can proceed while migration coverage is completed.
7. Build production artifacts, run hermetic suites and the reuse-only fork suite, then execute the persistent local deployment/migration rehearsal and UI tests. Do not use isolated test results as persistent-node evidence.
8. Deliver a run report with source/config revisions, fork provenance, reused/new addresses, code/selector/registry checks, bootstrap and migration receipts, per-phase ledgers, tests/seeds, UI checkpoints and remaining failures. Leave the requested human-review checkpoint running.

Build before tests/scripts after production changes; FactoryServices read `out/` creation code. Seed warm `out/` and `cache_forge/` in a new worktree and wait for actual compiler completion. No `via_ir`, disabled EIP-170, stale artifact bypass or `--skip-simulation`.

## 11. Completion criteria

The work is complete only when the exact PRD composition is deployed on the recorded Robinhood fork, all specified core contracts and the original staking instance are reused, the confirmed combined reward/principal migration is reconciled through existing functions, and the UI successfully transacts against the resulting persistent state. Preserve phase checkpoints for further UI iteration.

Reports must distinguish implemented source, successful hermetic tests, successful fork tests, actual local deployment, actual local migration and browser evidence. List unresolved live-code compatibility, custody, migration or quote-provider issues as blockers; never substitute another topology or core to obtain a green result. Public deployment remains a later, separate decision.

## 12. Execution preflight — 2026-09-11

The owner requested execution of the staking migration against the existing local node. Read-only preflight completed; **migration could not execute and no transactions were submitted**.

Observed at `http://127.0.0.1:8545`:

| Check | Result |
|---|---|
| `anvil_nodeInfo` chain ID | 4663 |
| Current block / reported fork block | 60444927 / 60444927 |
| Existing staking | `0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00` |
| Staking owner | `0x72BeA6Fa3E68EF18c87D045Aac7C4Aa5249d933B` |
| `phase()` | 0 — Staking |
| `targetDetf()` | Zero address |
| `claimVault()` | Zero address |
| `reserveRemaining()` | `223355050624580728299834717` raw DTF units |
| `totalSupply()` | `220032706803999006035614295` raw staking principal units |

Execution blockers:

1. The Stage 08-05 through 08-08 migration runner and `fee-accrual-migrate` command described in §6 are not implemented. A search of the current `scripts/` tree found no calls to `setTargetDetf` or `migrateToClaimVault`.
2. No verified, bootstrapped target for the agreed composition is configured. The target, custody and bootstrap stages in §6 remain prerequisite implementation work. The composition PRD still lists unresolved deployment configuration in O01–O08, including reserve weights, seed amounts and custody accounting. The pooled deposit/reward allocation is already settled and must not be reopened.
3. Additional onchain discovery failed: the manager's `vaults()` read and code reads for the historical CHIR address and the recorded 46630 DTF-DETF address returned upstream fork errors containing `metadata is not found, 60444930`. These failed reads do not establish that the queried addresses have no code. The fork source must support the required historical account/storage reads before a faithful deployment/migration can proceed.

The old CHIR manifest describes a different composition; the 46630 manifest belongs to another chain. Neither is accepted as this run's migration target. No staking target, reward reserve, principal balance, Anvil state, or frontend deployment address was changed by this preflight. The next execution attempt must first establish the required target and runner and resolve the fork-read failures, then refresh all live state and simulate the complete migration call.

### Implementation update — 2026-09-11

Migration stage source 08-05 through 08-08 is now present; this is not deployment or receipt evidence. The initial 08-07 script compiled, with further edits and integration tests pending. On 2026-09-11 the existing Anvil backend was changed to the configured Robinhood archive endpoint using `anvil_setRpcUrl`, after checking chain ID and block hash. The local block remained unchanged; no reset, contract deployment or staking migration was performed by that backend change. Refresh live reads before execution.

The URL-only change left the old fork database using its failing source. A subsequent repair confirmed that no local blocks or pending transactions existed, backed up `anvil_dumpState` under `.scratch/fee-accrual/runtime/`, reset to the identical block 60444927 through the archive endpoint, and restored that state. Staking `phase`, `totalSupply`, `reserveRemaining`, `targetDetf`, `claimVault` and `owner` matched before/after. Manager and CREATE3 owner calls now succeed and both return `0x72BeA6Fa3E68EF18c87D045Aac7C4Aa5249d933B`; manager `feeTo` still returns the required existing collector. Anvil instance identity changed during repair; any earlier journal must not be reused. No contract deployment or migration transaction was submitted.

### Source and verification status

Added the opt-in local command path, isolated config/journal checks, stages 01-04, 07-01–03, 08-03–08 and 09-02, and a configuration template. Source pins DTF-DETF metadata and 60/20/20 role weights; custody uses the selected fee-free wrapper package. The command validates receipts and migration events and rejects public endpoints, forced replay and node reset. The initial targeted script build passed; five hermetic Python guard tests pass. Further Solidity edits, migration runner tests and the exact-composition/fork/browser gates are still under validation. Candidate frontend export exists; installing it into the active UI is pending verified local deployment.

Read-only local discovery now confirms Pons V2 launch `exists=true`, phase PoolCreated, native ETH quote, fee 0 and tick spacing 200. Factory `memeHook`, `poolManager` and `positionManager` match the canonical pins. The current CREATE3 global operator query authorizes the manager. Registered legacy packages do not establish freshness of the current unified DETF or enhanced wrapper; use the product package prerequisite command. No fee-accrual instance or staking migration transaction has been submitted.

The complete local shell/Forge preflight now passes, including CREATE3 manager authorization and the live graduated Pons pool. An initial Forge compatibility workaround checked the client version inside the stage. That check was subsequently removed at the owner's direction: Solidity stages must be shared unchanged with public mainnet. Anvil-specific identity/signing setup belongs only to the local shell. The current stage set compiles. `TokenStakingMigrationScript` passes all three focused tests (pooled conversion and user exits, complete quote rollback/parity, unsafe limits/incomplete finalization). These use the existing production CP Pons fixture and are not evidence of the exact weighted/custody composition. Separate registered-custody/provider tests are being run.

**Owner correction:** Remove Anvil environment flags, client checks and private-key exclusions from all fee-accrual Solidity stages. Rehearse the public-mainnet deployment code unchanged against the selected fork. Local RPC guards and impersonation belong in the existing Anvil shell; shared stage catalogs contain no local orchestration. This correction does not authorize a public broadcast.

### Custody decimal validation update — 2026-09-11

The three custody/provider script tests passed. Weighted-hook changes now accept buffered shares in [6,36], verify supplied decimals against live metadata, and normalize whole-share provider rates to native pair-token units for reserves, swap inflows and projected transitions. Regression/fuzz and exact native-ETH composition tests are running; this is source/build evidence, not deployment evidence. The staking-owner wallet has approximately 0.48048 ETH and zero WETH/DTF. A read-only base-pool quote priced 362.909158945834082728 DTF at 0.001030021194272814 ETH; acquisition authorization is pending, with a proposed 0.0021 ETH total bootstrap funding cap excluding gas. No staking funds have moved.

The updated shared-stage preflight passed against the persistent local fork after removal of Anvil-specific Solidity checks. The live manager’s default bond terms are 30-day minimum and 180-day maximum (do not overwrite them with fixture defaults). The frontend responds on port 3002. Initial weighted custody tests identified a test-fixture operator mismatch, corrected through the real factory’s authorization API. Runtime checks also found Join and JoinFlexible facets above EIP-170; the provider conversion is being factored into the existing linked math library and must pass size assertions before deployment.

The facet-size correction compiled successfully: Join 24,521 bytes, JoinFlexible 24,504 bytes, Hooks 24,399 bytes, all below 24,576. Provider conversion uses the existing external weighted math library; rate validation reuses the existing claim library and rejects malformed non-32-byte results. The deployed-facet regression asserts EIP-170 directly. Exact-composition and final regression results remain pending.

A read-only funding transaction was prepared and successfully simulated in `.scratch/fee-accrual-launch/funding-proposal.json`: Universal Router buys 363 DTF, wraps 0.001 ETH, and sweeps unused ETH back to the owner, with total `msg.value` capped at 0.0021 ETH. No transaction was sent; the owner's funding choice remains pending. Refresh its deadline and re-simulate before any authorized broadcast. The extra DTF above the estimated bootstrap payment is a small rounding cushion retained by the owner.

### Verified funding and required liquidity seed — 2026-09-11

The owner approved acquisition within 0.0021 ETH plus gas. Local funding transaction `0x1cf389b0dd03fff54799f5b06ff024b2050ab3dd142e3cefc706fbfd19457ebf` succeeded, delivering 363 DTF and 0.001 WETH to the staking owner. The staking reserve and phase were verified unchanged. The receipt and funding intent are recorded under `.scratch/fee-accrual-launch/`. This is funding evidence, not DETF deployment or migration evidence.

All 15 weighted custody tests pass, and both pure scale/rate fuzz properties pass 10,000 runs each. Exact-composition validation exposed a required liquidity-SE initialization: empty SE supply deliberately quotes zero for a single-asset deposit, so custom WETH routes fail validation until a two-asset seed exists. New Stage 07-04 seeds the empty SE from the funding owner using 1,000,000,000 wei WETH and the live pool-ratio DTF quote. The owner receives the initial SE shares. Stage 08-04 subtracts both seed payments from the approved total bootstrap budgets before bonding. The WETH total remains 0.001; the first bond receives 0.000999999 WETH. The seed cannot execute twice against nonzero SE supply, and local resume requires its confirmed receipt. The exact-composition tests now include this stage; results remain pending.

### Persistent local deployment and bounded migration — 2026-09-11

The authorized owner-funded purchase completed in transaction
`0x1cf389b0dd03fff54799f5b06ff024b2050ab3dd142e3cefc706fbfd19457ebf`:
363 DTF and 0.001 WETH, with a 0.0021 ETH transaction-value cap and unused ETH refunded.
Staking reserves were unchanged. A subsequent 1 ETH transfer from the standard Anvil
account funded deployment/migration gas only; it did not increase the token bootstrap budget.

The seven prerequisite package stages and composition stages 07-01 through 08-04 have
confirmed receipts under `.scratch/fee-accrual-packages/` and `.scratch/fee-accrual-launch/`.
The existing core, manager, collector and staking contract were reused. The DETF deployment
paused for insufficient gas after the hook and doors were created; `forge --resume` submitted
its remaining transaction, and all six stage receipts were then reconciled.

- DTF-DETF: `0x8ff37779B8Fe866470aEcf64910F4Bf899d73705`
- Reserve hook: `0xc63c9753cdb5DecB4fD5D50cD2edf83B25706aA8`
- sDTF-DETF: `0x764C96E8b66832c78030f36DbdeDF2A34FEadaaB`
- Liquidity SE: `0x4901fF4c99ef253eeEb22aa23be34C71e1fAa95f`
- DTF custody SE: `0xF766b981742b2c929aF26F74384931E2851EB413`

The first bond returned 1,598,507,935,962,916,267 reserve LP units and NFT 3.
The measured post-bootstrap synthetic price was 48.495241181696262374 WAD units
(about 48.5 times the creation benchmark). This is a measurement, not a promised rebase duration.

The recorded full staking balance cannot migrate in a single call: the exact-composition
regression reproduced `MaxInRatio()`. Capping each native migration call at 25% of the
current rated DTF reserve completed both principal and rewards in the production-component
fixture. The shared 08-07 stage now prepares at most `maxChunks` such transactions per run,
with a full-call quote and a nonzero slippage minimum for each. Receipt reconciliation checks
the ordered event/quote pairs and every reserve debit, including batch completion.
The original oversized-call failure remains a rollback regression.

The weighted-hook suite passed 390 tests. The initial chunked full-balance composition suite
passed all three tests; final extraction into the shared sizing helper is being reverified.
Nine Python receipt/identity tests pass. These are local rehearsal checks, not completion of
the full fuzz/invariant and public release gates above.

The updated migration script uses a fresh `.scratch/fee-accrual-migration/deployments/`
journal directory, linked to the preceding deployment evidence. At its creation, staking
was still in phase Staking with the entire recorded reserve intact. Completion and runway
measurements must be recorded after actual migration receipts are confirmed.

### Blocking deployed-staking ABI mismatch — 2026-09-11

**Actual migration is not complete.** The live target was set through `setTargetDetf` in
08-05, but the full 08-07 simulation stopped before broadcasting any migration transaction.
The deployed staking facet at `0x9C90d4a476f3473b9a0e32B530aF3474271a80B1` invokes
`mint(address,uint256,uint256,address,bool,uint256)`, selector **`0x5820c428`**.
The new DETF does not export this retired standalone selector, so the native staking
call reverts with `NoTargetFor(0x5820c428)` before purchasing or wrapping any sDETF.
An initial trace interpretation called this an `exchangeIn` overload; selector computation
corrected it to `mint`. Do not repeat the initial interpretation.

The observed state after failure is:

- phase `Staking` (0), not Migrating or Wrapped;
- reserve 223355050624580728299834717 raw DTF, unchanged;
- principal 220032706803999006035614295 raw DTF, unchanged;
- claim vault zero;
- target points to the deployed local DTF-DETF;
- no 08-07 migration transactions were submitted.

`facetAddress(0x1f931c1c)` on the existing staking diamond returns zero: no standard
diamond-cut upgrade entrypoint is available. The passing composition fixtures deploy the
current staking implementation, whose mint leg uses the newer Standard Exchange call.
They therefore prove the new components and chunk sizing, **not compatibility with the
already-deployed staking bytecode**. The real fork rehearsal exposed this missing gate.
The final shared-helper regression passed all three tests, including 40 chunks for the
recorded balance in that fixture; its post-migration synthetic price was
20.637197293343195266. That number is not a measurement of the persistent Anvil migration.

#### Approved standalone migration adapter — 2026-09-11

The owner selected an adapter so the deployed, funded DETF remains unchanged. This
supersedes the proposed legacy DETF facet and fresh DETF/bootstrap. The owner explicitly
authorized a monolithic contract, constructor initialization and ordinary `new` deployment
without a package or CREATE3. The owner subsequently approved using the DETF's existing
static staking SY as the legacy claim-vault asset.

Implementation: `contracts/protocols/staking/token/TokenStakingMigrationAdapter.sol`.
Constructor arguments are existing staking, DTF, actual DETF, and real sDETF. The adapter
derives `actualDetf.stakingSY()` and validates token bindings, backing metadata and nine
decimals. It has no mutable configuration, ownership, rescue, upgrade or fee entrypoints.

Historical staking calls legacy `mint(...)` and decodes one uint256, approves the target
as an ERC20, then calls the target's `exchangeIn` using that target as tokenIn. The adapter
therefore issues nontransferable DETF-backed receipts from its canonical DTF purchase,
then consumes the complete batch by depositing DETF into the existing staking SY.
The static SY output goes directly to staking and is wrapped by its stored legacy package.
`rebasingClaimToken()` intentionally returns **SY** for historical discovery;
`fundedStakingToken()` identifies actual sDETF. Receipt units remain DETF, while the
native migration minimum and output are SY units. Exact approvals are cleared, balance
deltas checked, donations excluded, and unauthorized/invalid routes rejected.

After conversion of all principal **and rewards together**, users call staking's existing
`withdrawClaim(stakeAmount)` for proportional SY. Partial exits are supported; the final
staker receives all remaining claim-vault shares. Users redeem their SY directly through
`redeem(user, syAmount, realSDetf, minimumSDetf, false)` to receive real sDETF, without a
separate token approval. SY ownership survives pending rebases and delays before redemption.
Real sDETF retains its canonical unstaking route to actual DETF.

Required orchestration and UI integration before persistent migration:

1. Deploy the adapter with the four pinned constructor addresses and verify its bytecode,
   actual DETF, real sDETF and canonical staking SY bindings.
2. Keep actual DETF as the protocol product in registry/UI discovery and reserve chunk
   sizing. Track the adapter separately as staking's migration target. The claim-vault
   asset must equal staking SY, whose yield token is real sDETF backed by actual DETF.
3. Set the target while staking remains in phase Staking. Quote each full native
   `migrateToClaimVault` call, using SY output for minimums, then submit that existing flow.
   Preserve deposits plus rewards together. Reconcile reserve debits, stake weights,
   claim-vault shares, and zero adapter receipts/residual approvals after every chunk.
4. Run the historical-bytecode fork gates, including original-reserve conversion, failed
   minimum rollback, partial/full/final exits, pending rewards and delayed SY redemption.
5. Update the UI to show both claiming SY and redeeming it for real sDETF. Value SY through
   canonical previews and reject zero-preview legacy withdrawals. Do not label SY units
   as sDETF units merely because both have nine decimals.

Tests: `test/foundry/spec/protocols/staking/token/TokenStakingMigrationAdapter.t.sol` and
`test/foundry/fork/robinhood_4663/TokenStakingMigrationAdapter_RobinhoodFork.t.sol`.
The shared real-composition fixture is `contracts/test/bases/TestBase_FeeAccrualComposition.sol`.
Detailed behavior and verification mapping are in
`contracts/protocols/staking/token/TOKEN_STAKING_MIGRATION_ADAPTER.md`.

The direct-sDETF prototype successfully migrated the original reserve in 60 native chunks
on a disposable fork, but a pending-rebase withdrawal underpaid 251280508 versus 253445301
raw sDETF for a 100-DTF holder. The historical wrapper valued redemption before the asset
transfer synchronized rewards. This is why the owner approved static SY; the adapter is
never called on withdrawals and cannot repair that calculation through a forwarding method.
The old failing result is historical evidence, not a result for the approved SY revision.

Updated test results and source hash belong in
`.scratch/fee-accrual-migration/adapter/verification.json`. Persistent deployment/migration
requires actual receipts; fork success alone does not change the rehearsal node. The
five-year read-only runway measurement remains pending Wrapped state on that node.

#### Static SY adapter verification complete — 2026-09-11

The final adapter build and all **22 focused tests** passed: 12 production-first adapter
tests (128 fuzz cases, 4,096 invariant calls with zero unexpected reverts), seven historical
fork tests, and three composition regressions. The historical suite verifies complete
original-reserve migration in 60 native calls, original-address user withdrawal, atomic
minimum failure, partial/full/final exits, pending rewards and delayed 90-day SY redemption.
Independent transactions on disposable forks confirmed those migration and withdrawal paths
under EIP-170. The pending-rebase payout exactly matched the pre-synchronized control.

No adapter deployment or migration was broadcast to the persistent UI rehearsal. Its last
read-only check remained block 60445001, phase Staking, original reserve unchanged and claim
vault zero. Script/UI integration listed above remains required before that migration.

#### Persistent local migration completed — 2026-09-11

The owner explicitly authorized execution. Adapter deployment and target update were
confirmed, followed by **60 successful native migration transactions** on the persistent
port-8545 Anvil. Final block: **60445063**. Staking is **Wrapped**, remaining DTF is **0**,
and principal weights remain **220032706803999006035614295**. The converted total is
**223355050624580728299834717 raw DTF**, including all remaining rewards together.

Adapter: `0x7F73efC0530DB6948a4535EbC77095897afCA1D0`.
Claim vault: `0xca66c89624d89e1fa5619d9a4dda7f2be8e7bc10`.
Its asset is the existing staking SY `0xce5b57f7c84825f789865719153684fC067fD6e7`.
The vault's **15236505631 raw SY** and staking-held **152365056310000000000 vault shares**
reconcile exactly with migration receipts. Adapter receipts/balances and required allowances
are zero. No core or DETF redeployment, reward rescue, donation or public-mainnet transaction
occurred. No persistent user claim was executed.

Evidence: `.scratch/fee-accrual-staking-sy/MIGRATION_COMPLETE.md`, the receipt journal and
`deployments/migration-live-verification.json` beneath that run directory. The receipt
checker now handles Forge's decimal-string uint256 exports without float conversion;
its source transition and original journal are preserved. All 60 native receipts were
reconciled without replay. The shared runner passed seven historical fork tests; the
checker passed eleven tests. Static-SY UI claim/redemption integration remains pending.


### 2026-09-11: staking UI integration verified

The local 4663 platform and DETF tokenlists now include the verified DTF-DETF instance.
`/staking` discovers and validates the native staking → claim vault → static staking SY
→ real sDETF route through the selected wallet provider. It supports partial/full native
`withdrawClaim` and direct SY redemption with a fresh minimum output. Original DTF weights,
SY receipts and sDETF values use their own live decimals. Zero-output claims are blocked.
Connected RPC errors never fall back to the app HTTP endpoint, and the header identifies
the actual provider source without claiming to know the wallet extension's RPC URL.

Type checking, 24 focused unit tests and 17 browser tests passed. Browser money paths used
a disposable fork of the already migrated state: real partial/full claims, receipt and
balance checks, 90-day delayed redemption, wallet rejection, lost receipt access, decimal
boundaries, RPC failure, account/network changes and responsive layout. The browser's
wallet used port 18545 while app HTTP access to port 8545 was blocked. No contracts were
deployed for these tests and each test restored its disposable snapshot. No persistent
user position was withdrawn. See `frontend/apps/dtf/STAKING_MIGRATION_UI.md` for the flow
and reproducible commands. This validates these UI paths, not the whole public launch.
