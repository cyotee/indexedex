# MiniMax — independent implementation-plan contribution

Run root: `docs/research/dtf-migration-gap-closure-plan-20261116/`
Author: MiniMax (`minimax/MiniMax-M3`), council-member, research/plan-authoring profile.

## 1. Identity

| Field | Value |
| --- | --- |
| Member label | `minimax` |
| Requested role | `council-member`, research/plan-authoring profile |
| Requested model | `minimax/MiniMax-M3` |
| Runtime identity | not exposed beyond route and role; the local adaptive-thinking compatibility override was reported by the coordinator, not by my runtime |
| Inputs read | `docs/reviews/dtf-migration-implementation-council-20261116-0228/REMEDIATION_PRD.md` (514 lines) and `coordinator/resolution.md` (142 lines) completely, per the brief; the migration plan and the prior review/resolution are common context |
| Peer files read | none — no prior peer original, and no other member's planning response for this run |
| Actions taken | read-only source and document navigation; no command, build, test, install, Git, RPC, wallet or transaction; no delegation; no code or configuration edit |
| Publication | this harness exposes no `apply_patch` tool (catalog search returned no match). Per the brief's fallback — "If unavailable, return the complete contribution inline and do not use an alternate writer" — the complete contribution is returned inline and **no alternate writer was used**; `members/minimax/response.md` is therefore not written by me. The coordinator can archive this output verbatim. |
| Authorization | planning only. Nothing here authorizes implementation, deployment, funding, activation or a public transaction. |

## 2. Question and targets

**Question.** Produce one executable implementation-and-test plan that closes the five accepted gaps — F1 (production funding), F2 (retained native QA), F3 (metadata), F4 (documentation/navigation) and the pricing-evidence qualification P1 — against the current checkout, with exact repair mechanisms, dependency-ordered tasks, production-first regressions, a realistic native-QA procedure, source/artifact evidence binding, final acceptance and exclusions.

**Targets.** Migration contracts (`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`), the shared bond-metadata renderer (`contracts/vaults/detf/common/bondNft/`), the ordinary DETF process args (`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProcessArgsLib.sol`), the ordinary weighted-hook fixture (`test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/`), the retained native scripts (`scripts/foundry/recovery/dtf-migration/`) and the plan-named evidence (`docs/incidents/2026-09-16-dtf-recovery/migration/`).

**Precedence.** The2026-11-15 owner correction and plan §1.1–§1.10 govern. No custom CLI, preparation application, bundle/journal framework, holder-transfer ancestry requirement, automatic price capture or selected live-production-composition prerequisite is restored. The prior review's rejected claims — the TokenStaking adapter dependency, the "absent gas bounds" assertion and the mandatory NFT-wrapper interpretation — are not re-filed as requirements.

## 3. Evidence

**Facts read (source).**
- `M/UniswapV4DetfMigrationAllocationTarget.sol` — `bootstrapMigrationReserve` L305–367, `_genesisPreview` L369–387, `_convertGenesis` L389–415, `activateMigration` L267–283, `_administrationSelectors` L285–303, `administration` modifier L37–42.
- `M/UniswapV4DetfMigrationWeightedHookTarget.sol` — `donateMigrationCapital` L327–371, `_releaseDonation` L373–378, surrender routes L76–310, `onERC721Received` L314–325.
- `M/UniswapV4DetfMigrationPolicy.sol` — `_budgetTokens` L20–27, `_beginBudget` L29–38, `_endBudget` L40–49, `_residualBalance` L51–57, `_sweepDustBody` L59–64, `_admit` L74–95, `_emptyParticipation` L105–110, `_isMintingAllowedToken` L125–127.
- `M/UniswapV4DetfMigrationRecoveryTarget.sol` — `_donateRecovery` L441–469 (the existing budget-isolation pattern), `recoverMigrationNfts` L324–370.
- `M/UniswapV4DetfMigrationRepo.sol` — storage L18–59, `_weightedPricing(expectedBookId_)` L83–88, `_fundBond` L92–101.
- `M/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol` — `createMigrationPosition` L29–43, `_calculateClaim` L60–71, `_claim` L73–79, `_requireActivated` L115–119.
- `M/bondNft/UniswapV4DetfMigrationBondMetadataTarget.sol` (all 35 lines) and `C/bondNft/DETFFundedBondMetadata.sol` (all 234 lines) and `C/bondNft/DETFFundedBondMetadataTarget.sol` (all 29 lines).
- `C/bondNft/DETFFundedBondTarget.sol` (`_createFundedPosition` L107, `_calculateClaim` L153, `_claim` L180), `C/core/DETFMintSplitLib.sol`, `C/core/DETFFundedStakingMath.sol`.
- `B/UniswapV4DetfTarget.sol` — `_entryBond` L527–557, `_seatBond` L597–…, `_openBondNft` L714–725, `_entryDonate` L731–736, `_entryJoinDonatedCapital` L738–776, `_entrySweepDustAtomic` L803–806.
- `B/UniswapV4DetfCommon.sol` — `_pairEq` L170, `_quoteMintGross` L259, `_residualBalance` L493, `_sweepDustBody` L497–549 (join loop, 8 rounds, 24-basket budget, `_tryJoinResidual`/`_consolidateResidualPairs`, per-token reserve update L543–548), `_trySweepDust` L483–485.
- `M/TestBase_UniswapV4DetfMigration.sol` — `_migrationEnvironment` L96–135, `_migrationArgs` L276–284, `_deployMigration` L286–294, `_prepareMigrationHookWithWeight` L297–330, `_fundAndCapture` L332–345.
- `M/TestBase_UniswapV4DetfMigrationSnapshot.sol` (all 193 lines) — `MigrationWeightedPricingFixture.observed` L33–67, `MigrationSnapshotConsumer` L71–102, `MigrationSnapshotMathExposure` L105–131, `_oracle` L156–180, `_assertOracle` L182–191.
- `S/MigrationCoreLocalQA.s.sol` (all 346 lines) — `MigrationCoreLocalOwner` L40–81 (`bind`/`bootstrap`/`setConfigureIssue`/`activate`), `deployAndIssue` L265–296, `exerciseAfterCliff` L298–343, `runMixedRecordRehearsal` L102–179 (the working owner-bond path at L170–172), `_localInfrastructure` L181–263.
- `M/UniswapV4DetfMigrationBondFacet.sol` — `_entryBond` L38–57 (owner-only first-purchase exception), `_openBondNft` L24–30.
- `contracts/hooks/uniswap/v4/standardExchange/weighted/` — `IUniswapV4StandardExchangeWeightedBufferHookCapture.sol` (all 43 lines), the capture implementation in `UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol` L333, the hook's public surface (`previewSwapExactIn`, `previewJoinSingleAssetExactIn`, `ratedBalances`, `rateProvider(i)`, `standardExchange(i)`), `UniswapV4StandardExchangeWeightedBufferHookMath.sol` (`applyTradingFeeNet` L100–105, `ratedPairUnits` L57–64, `scaleTo` L66–68).
- `contracts/test/libs/RateProviderFixtureLib.sol` — `providersFor` L52–62 ("One provider per SE leg; address(0) on raw legs"), `fillMissing` L65–78 (keeps a caller-supplied provider, so a raw leg can carry one).
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol` L62–174 — the default hook is "token0 SE-buffered, token1 raw" (L65), and L110 performs `vm.etch(PERMIT2_ADDR, address(permit2).code)`.
- `M/UniswapV4DetfMigrationWeightedPricingLib.sol` — `validate` L18–81 (leg-mode and scale rules), `evaluateOriginal` L103–139, `evaluateOriginals` L141–146.
- `.github/ASSISTANT_TESTS.md` (testing/CI law) and `CLAUDE.md` rules 7, 9, 10 (Solar for every compiling forge command; worktree compile seed; `forge build --use solar` before `forge test --use solar` because FactoryServices read creation bytecode from `out/`).
- `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-11/batch-limits.md` — authenticated transaction limit 32,000,000; admitted shapes: loading 64 recipients × 1 original; issuance 32 recipients × 1 original; 1 recipient × 64 originals; recovery up to 8 WeightedClaim stages or one other typed step; the 64-recipient issuance is measured above the limit.

**Facts read (documents).** `REMEDIATION_PRD.md` F1–F4, E/MIG-AC dispositions and the disagreement section; `coordinator/resolution.md` dispositions of Astra A1 and MiniMax C1–C4, including the three F1 implementation restrictions the coordinator declined to adopt (reclassification into the residual budget is permitted; common routing logic may be reused but the legacy recovery inventory may not be debited; a blanket ban on caller-selected amounts is not an owner requirement, only a bound by legitimate booked capital).

**Coordinator-supplied observations (not my source reads).** The snapshot base is V3-SE oriented; `MigrationWeightedPricing.t.sol:338-364` asserts arithmetic but is not a real raw-hook comparison; `UniswapV4DetfProcessArgsLib.sol:120-126` rejects a non-self hook pair with no Standard Exchange (`BarePairForbidden`); the ordinary weighted-hook fixture's deploy test rejects an all-zero-SE hook (`:128-133`) and allows a rate provider on a raw leg (`:143-147`); that fixture's `vm.etch` of the canonical Permit2 (`:110`) is a state mutation that must not be copied.

**Design inferences (clearly labelled).** That the stranded genesis remainder is joinable by the ordinary sweep because the sweep iterates the hook's pair tokens and SEs (`_sweepDustBody` L507–539) — inference from the read code, not an executed observation. That the canonical comparator for a raw contribution leg must be the hook's own quote rather than a DETF-subject quote, because `BarePairForbidden` bars a bare pair from an ordinary DETF mint table — inference from the coordinator's pointer plus the process-args rule.

**Unverified points (labelled, not asked as questions).** The exact inherited `_buyOwnerFirstBond()` parameter values (payment token, amount, duration) live in the weighted production-SE base and must be read by the executor before writing the QA purchase; the plan fixes the *mechanism* and requires the executor to mirror that helper rather than invent new values. The numeric gas cost of the new F1 operation and of the F2 owner purchase is not measured; the plan requires measurement against the 32,000,000 ceiling rather than assuming it.

## 4. Assumptions

1. The plan and the review inputs are the byte-identical artifacts the coordinator refreshed; no hash recomputation is required or performed.
2. The working tree is live. The plan's edits land on the current primary checkout; the conformance worktree stays evidence-only.
3. No live deployment exists that must be repaired in place. The plan produces source changes plus fresh deployment artifacts; any live-deployment repair is a separate explicit decision.
4. `detf`/`pairA`/`pairB` in the migration fixture remain mintable fixtures; the migration package, reserve, registry, fee oracle, staking, SY and bond children remain production code.
5. The ordinary package's metadata renderer must remain byte-identical in *output*; any shared-renderer change must be provably inert for it.

## 5. Coverage

| Target | Status | Files actually read for this plan |
| --- | --- | --- |
| F1 funding accounting | Examined | `M/UniswapV4DetfMigrationAllocationTarget.sol`, `M/UniswapV4DetfMigrationWeightedHookTarget.sol`, `M/UniswapV4DetfMigrationPolicy.sol`, `M/UniswapV4DetfMigrationRecoveryTarget.sol`, `M/UniswapV4DetfMigrationRepo.sol`, `B/UniswapV4DetfCommon.sol`, `B/UniswapV4DetfTarget.sol` |
| F2 native QA | Examined | `S/MigrationCoreLocalQA.s.sol` (all), `M/TestBase_UniswapV4DetfMigration.sol` (all), `M/UniswapV4DetfMigrationBondFacet.sol`, `B/UniswapV4DetfTarget.sol` |
| F3 metadata | Examined | `M/bondNft/UniswapV4DetfMigrationBondMetadataTarget.sol` (all), `C/bondNft/DETFFundedBondMetadata.sol` (all), `C/bondNft/DETFFundedBondMetadataTarget.sol` (all), `M/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol` |
| F4 documentation | Examined | `D/verification.md` (historical), `D/quote-evidence.md` (head), `D/foundry-runbook.md` (all), `D/source-route-matrix.md` (head), `D/recovery-route-disposition.md` (head), `D/conformance-20261114/task-11/batch-limits.md` (head) |
| P1 pricing evidence | Examined | `M/TestBase_UniswapV4DetfMigrationSnapshot.sol` (all), `M/UniswapV4DetfMigrationWeightedPricingLib.sol` (all), `M/interfaces/IUniswapV4DetfMigrationWeightedPricing.sol`, capture interface (all), hook public surface, `RateProviderFixtureLib.sol`, ordinary weighted-hook fixture L62–174 |
| Not examined | — | `MigrationLegacyRecoveryLib.sol` internals, `sy/` and `claimToken/` internals beyond the gates already cited, `legacy/MigrationLegacyRecoveryLib.sol` full body, the `migration/` evidence archive beyond the documents listed, `scripts/forge-artifacts.py` source (its invocation contract is taken from plan §10 and `CLAUDE.md`) |

## 6. Proposed plan

### 6.0 Design rules applied to all five gaps

- Production-first only: real registry, real manager, real fee oracle, real hook, real V3 SEs, real bond/receipt/SY children, real permit2 deployment. No `vm.etch`, `vm.store`, `vm.mockCall`, mocked SUT, subclassed SUT, injected storage or impersonation in any new test.
- No new product authority: every new surface is owner-only, bounded by already-booked legitimate capital or by the existing configuration/execution books, and has a fixed destination.
- Every state transition is all-or-nothing; every failure path leaves every book, balance, supply, backing and clock unchanged.
- Fresh artifacts before tests: a single-Solar `forge build --use solar` immediately precedes any test run in the changed tree, so `out/` never mixes compiler generations (the 2026-11-16 artifact-mismatch lesson).
- No removed capability is restored, and no live-production-composition or live-ancestry prerequisite is introduced.

### 6.1 F1 — stranded booked donations after a permitted partial bootstrap

**Mechanism (chosen, single).** Add one owner-only, bounded operation on the **permanent** migration facet that releases *booked* donation inventory into reserve liquidity through the ordinary reserve-join sweep, and debit the donation book consistently.

- **File/symbols.**
  - `M/UniswapV4DetfMigrationWeightedHookTarget.sol` — new external function next to `donateMigrationCapital` (L327):
    `releaseMigrationDonations(IERC20[] calldata tokens_, uint256[] calldata amounts_, uint256 minLpOut_, uint256 deadline_) returns (uint256 lpOut_)`.
  - `M/interfaces/IUniswapV4DetfMigration.sol` — declare it on the permanent interface (not on `IUniswapV4DetfMigrationAllocation`, so it is **not** in the removal set).
  - `M/UniswapV4DetfMigrationWeightedHookFacet.sol` — add the selector to `facetFuncs()`.
  - `M/UniswapV4DetfMigrationPolicy.sol` — add a shared internal helper `_releaseBookedDonation(address token_, uint256 amount_)` implementing the budget isolation, so the policy (not the facet) owns the accounting.
- **Authority and preconditions.** `MultiStepOwnableRepo._onlyOwner()`; `_requireNotDisabled()`; `_requireReserveLive()`; `_requireIdleChildren()`; `block.timestamp <= deadline_`; `_requireActive(deadline_, amount_)`; `tokens_.length == amounts_.length`; duplicate tokens rejected; each `amounts_[i] > 0` and `amounts_[i] <= Repo._layoutStruct().donationInventory[tokens_[i]]` (legitimate booked capital only).
- **State transitions, per selected token, mirroring `_donateRecovery` (L455–465) exactly.**
  1. Snapshot `residualInventory` for every tracked token and set `operationFloor[tracked] = IERC20(tracked).balanceOf(address(this))` so nothing else is spendable in this operation.
  2. `operationFloor[token] -= amount` — the sweep budget for the selected token is exactly `amount`.
  3. `Repo._layoutStruct().donationInventory[token] -= amount` — the units leave the donation book at selection.
  4. Run the existing `_sweepDustBody()` (the ordinary reserve-join sweep, already routed through the hook and the bond LP holder).
  5. `_endBudget()`, then restore the prior `residualInventory` values (as `_donateRecovery` does), leaving `residualInventory[token] = amount − consumed` (join/conversion refunds).
  6. Measure the reserve progress: the hook LP balance at `_bondLpHolder()` must increase by at least `minLpOut_`; otherwise revert the whole batch.
- **Invariants.** (i) `donationInventory` only ever decreases when units leave it; the sum of `donationInventory` and the proxy's tracked balances never exceeds the balance. (ii) The legacy recovery inventory (`UniswapV4DetfMigrationRecoveryRepo.inventory`) is never read or debited. (iii) Unsolicited (unbooked) balances are never selected — only `donationInventory`-booked units are. (iv) No DETF is minted, no bond is opened, no receipt/staking/gon state changes: the operation only moves already-donated pair/SE units into reserve liquidity. (v) `isReserveLive`, `activated`, the administration selectors and every configuration/issuance/consumption fact are untouched, before and after activation. (vi) Batch atomicity: any item failure reverts every item.
- **Explicit exclusions.** No recipient or beneficiary parameter; no arbitrary calldata or delegatecall; no route that transfers value out of the proxy other than into the new reserve's LP position; no bond purchase with released capital; no change to `_beginBudget`/`_endBudget` semantics used by other operations; no change to `donateMigrationCapital` (a later donation still releases only its own receipts); no change to the sweep's own round/basket budget.
- **Failure/rollback.** A join that reverts, a zero LP progress, a stale deadline, an owner mismatch or a child that is not Idle reverts the entire call; the donation book, residual book, balances and the reserve are unchanged.
- **Production-first regressions.**
  - `T/MigrationCore.t.sol` — extend with `test_partialBootstrapRemainderReachesReserveLiquidity`: donate 100 ether of each leg, bootstrap with 50 ether of each (the existing permitted setup), assert `donationInventory` shows the50 remainder, then call `releaseMigrationDonations` for50 ether of one leg; assert the hook LP balance at `_bondLpHolder()` strictly increased, `donationInventory` decreased by exactly50 ether, `residualInventory` equals the refund, DETF `totalSupply` unchanged, receipt backing unchanged, and no bond created.
  - `T/MigrationCore.t.sol` — `test_releaseDonationsRejectsUnbookedAndOverbookedAmounts`: an unbooked token balance, an amount above `donationInventory`, a duplicate token, zero amount and a non-owner caller each revert with no state change.
  - `T/MigrationCore.t.sol` — `test_releaseDonationsPreservesRecoveryAndUnsolicitedInventory`: seed the recovery inventory and an unsolicited transfer; assert both are untouched by the release and that the release cannot select them.
  - `T/MigrationCore.t.sol` — `test_releaseDonationsAfterActivationAndBeforeActivation`: run the same release before activation and after activation on two instances; assert both succeed and that activation remains irreversible and the administration selectors remain removed after activation.
  - `T/MigrationRecovery.t.sol` — `test_balancesAndDonationBudgetsDoNotAuthorizeRecoverySpending` (existing) must keep passing unchanged: the new operation must not become a recovery spend route.
  - `T/MigrationSurface.t.sol::test_allPackageCutsReachRealProxyAndFitEip170` (existing) must keep passing: the enlarged permanent facet stays under EIP-170 and the new selector routes to the deployed facet.
- **Observable acceptance.** On a real registry-deployed proxy: donate more than the chosen bootstrap amount → bootstrap → the legitimate remainder reaches reserve liquidity, observed as growth of the hook LP balance at `_bondLpHolder()` and the matching token/inventory deltas, with no new payment and no personal issuance; the same before and after activation; refunds preserved as residual; every failure path leaves all books unchanged.

### 6.2 F2 — the retained native QA lifecycle cannot satisfy activation

**Mechanism (chosen, single).** Give the QA owner contract a genuine, controller-authorized paid ordinary purchase and sequence it before activation. The production prerequisite stays exactly as it is.

- **File/symbols.** `S/MigrationCoreLocalQA.s.sol`:
  - `MigrationCoreLocalOwner` (L40–81) — add `function buyOwnerFirstBond(IERC20 tokenIn_, uint256 amountIn_, uint256 lockDuration_, address recipient_) external onlyController returns (uint256 tokenId_)`.
  - `deployAndIssue` (L265–296) — after the independent issuance (L286–289), fund the owner contract with the payment token, approve the parent, call `buyOwnerFirstBond`, and assert the prerequisite marker is set.
  - `exerciseAfterCliff` (L298–343) — assert the prerequisite before `account_.activate()` (L319) and keep the existing post-activation assertions (L320–341), adding the owner-bond metadata capture (see 6.3).
- **Source of actual payment.** The controller (the unlocked dev account `DEV`) holds the payment token in the local Anvil environment (the migration fixture's `_migrationEnvironment` mints the contribution fixture to `payer` and wraps ETH into `pairA` under broadcast). The controller transfers the payment token to the owner contract and approves it; the owner contract pulls exactly `amountIn_` from the controller with `safeTransferFrom(controller, address(this), amountIn_)`, approves the parent for exactly that amount, and spends it. The owner contract holds no other funds and exposes no generic call or transfer surface.
- **Transaction sequence (stage A, `deployAndIssue`).** deploy → bind → donate → bootstrap → `setConfigureIssue` (independent compensation, bond id 3) → **controller funds the owner → owner buys the ordinary bond (bond id 4) → assert `migrationOwnerFirstBondTokenId() != 0`** → the existing second donation → emit addresses. The purchase uses `pretransferred = false` (the production guard rejects a pretransfer on the first-purchase path) and `recipient = controller`.
- **Ordinary terms, not compensation.** The purchased position must be an *ordinary* purchased bond: assert `bonds.isMigrationPosition(tokenId_) == false`, that its principal came from real paid capital, and that it uses the ordinary lock duration and linear vesting. Do not seed the marker, do not substitute compensation, do not use the independent-issuance path. The payment token, amount and duration must mirror the inherited `_buyOwnerFirstBond()` helper of the migration fixture's base (the executor reads that helper and reuses its exact values) rather than inventing new ones.
- **Hardcoded assertions / metadata calls to adjust.**
  - `deployAndIssue` L287 asserts `id_ == 3` for the *independent* bond — unchanged; the owner bond is a distinct id (4) and must be captured as such, not by reusing 3.
  - `exerciseAfterCliff` L307–308 reads `bond_.positionOf(3)` (the independent cliff bond) for the cliff/principal assertions — unchanged; the owner bond's id is captured in stage A and passed to stage B (or re-derived from `parent.migrationOwnerFirstBondTokenId()`), and its metadata is captured before and after activation.
  - `exerciseAfterCliff` L319 `account_.activate()` — now reachable; keep the L320 removal assertion and add `require(parent_.migrationActivated())`.
- **Failure witness.** Keep an explicit negative: a variant that skips the purchase and asserts `activateMigration` reverts with `MigrationOwnerFirstBondRequired` and that no stage-2 state changed. The production guard itself is not modified.
- **Regressions.** `T/MigrationOwnerFirstBond.t.sol` (existing five tests) must keep passing unchanged — the production prerequisite is untouched. `T/MigrationOperationGas.t.sol` and `T/MigrationDeploymentGas.t.sol` must keep passing. The new native QA path is exercised by the local-node procedure in 6.6, not only by compilation.
- **Observable acceptance.** The retained two-stage QA path executes against the real registry/proxy graph on a local node and reaches: payment made from real capital → a nonzero funded ordinary owner bond → the prerequisite marker set → activation succeeding → the sixteen administration selectors removed → post-activation claims paying rewards. The failure witness shows activation rejected without the purchase.

### 6.3 F3 — ordinary owner-first bonds display closed rewards as claimable

**Mechanism (chosen, single).** Derive reward availability from the parent activation state for *every* token in the migration instance, and make the shared renderer state that condition for purchased bonds, without changing the ordinary package's output.

- **File/symbols.**
  - `M/bondNft/UniswapV4DetfMigrationBondMetadataTarget.sol:32` — replace
    `v_.rewardsClosed = v_.migrationPresentation && !IUniswapV4DetfMigration(parent_).migrationActivated();`
    with
    `v_.rewardsClosed = !IUniswapV4DetfMigration(parent_).migrationActivated();`
    (`migrationCliff` and `migrationPresentation` keep their current meanings: reserved roles and cliff positions).
  - `C/bondNft/DETFFundedBondMetadata.sol` — make the *purchased-bond* rendering reward-availability aware by keying on `rewardsClosed` instead of `migrationCliff` in exactly three places:
    - description (L34–43): add a branch for a purchased (tokenId ≥ 3) non-cliff bond with `rewardsClosed` true — "Funded DETF purchase with linear principal vesting. Funded staking rewards accrue from purchase but reward claims are closed until activation. All claims pay sDETF.";
    - `_purchased` (L96–101): render the existing "Reward claims locked until activation" / "Reward claims open" line for any purchased bond when `rewardsClosed` is set, not only for cliff bonds;
    - `_claimAttributes` (L166–175): emit the existing "Reward delivery" trait ("Locked until activation"/"Open") for purchased bonds when `rewardsClosed` is set.
  - `_positionValues` (L105–118) needs no change: `_claimableRewards` already returns 0 when `rewardsClosed` (L178–180), so the numeric "Claimable rewards sDETF" and "Total claimable sDETF" exclude rewards once the flag is set. Keep the "Accrued rewards sDETF" row cliff-only so ordinary purchased bonds keep their ordinary rendering shape.
- **Invariants.** (i) The shared renderer is inert for the ordinary package: `C/bondNft/DETFFundedBondMetadataTarget.sol` never sets `migrationCliff`, `migrationPresentation` or `rewardsClosed`, so every new branch is unreachable there and the ordinary token URI is unchanged. (ii) The migration instance's reserved roles (ids 0–2) and migration cliffs keep their current text and traits — their `rewardsClosed` value was already `!activated`. (iii) The numeric "Claimable rewards sDETF" equals 0 before activation and equals `claim.rewardsDue` after activation, for every token. (iv) Principal rendering is untouched: purchased bonds keep linear vesting and migration cliffs keep the 90-day cliff.
- **Explicit exclusions.** No change to the payout gate (`M/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol:73-79`, `_requireActivated` L115–119) — this is presentation only. No change to `DETFFundedBondMetadata.View` (no new field). No change to the ordinary package's metadata target or facet. No prose-only test: the assertions parse the numeric JSON attributes.
- **Failure/rollback.** Metadata is a view; there is no state transition and nothing to roll back. A mismatch must fail the test, not be softened.
- **Production-first regressions.**
  - `T/MigrationSurface.t.sol` — extend `test_realTokenUriNumericCliffBoundaries` with the owner bond: capture the owner ordinary bond's `tokenURI`, assert the numeric "Claimable rewards sDETF" attribute is 0 before activation while `rewardsDue > 0`, assert the "Reward delivery" trait reads "Locked until activation", assert the principal attributes still show the ordinary linear schedule, then activate and assert the rewards attribute equals the accrued rewards and the trait reads "Open".
  - `T/MigrationEgress.t.sol::test_ordinaryActiveBondIsUnmarkedAndLinear` (existing) must keep passing: an ordinary bond in the migration instance is still not a cliff position and still vests linearly.
  - Ordinary-package regression: the shared renderer's output for the ordinary DETF package must be byte-identical. Assert it with a machine-readable comparison (the ordinary package's numeric attributes and traits), not by pinning prose.
- **Observable acceptance.** The paid owner's ordinary bond's numeric JSON attributes and rendered availability state the activation gate before and after activation; ordinary packages, reserved roles and migration cliffs render exactly as before.

### 6.4 F4 — plan-named evidence must navigate to the current native implementation

**Mechanism (chosen, single).** One current navigation entry point plus four targeted document refreshes; historical records preserved.

- **Files/symbols.**
  1. **New** `docs/incidents/2026-09-16-dtf-recovery/migration/README.md` — the current navigation entry: what the retained deliverable is (contracts + native Foundry scripts) after the 2026-11-15 correction; the current plan fingerprint; links to the current completion record, the current pricing differential evidence, the source-route matrix, the recovery-route disposition, the gas record and the runbook; a one-paragraph statement that everything else in `migration/` is historical evidence.
  2. `docs/incidents/2026-09-16-dtf-recovery/migration/verification.md` — rewritten as the **current** completion record: exact commands and exit codes, compiler and Foundry versions, the source revision, the Migration hermetic and fork results with their artifact paths, the full-hermetic result, the gas limits from `D/conformance-20261114/task-11/batch-limits.md` (32,000,000 authenticated ceiling; the admitted shapes), the unresolved items (F1–F3 until closed, then closed with their own evidence), and an explicit supersession note pointing to the preserved operator-era record. The operator-era content is **preserved**, not deleted: move it into a clearly labelled historical section (or a sibling `verification-20261113-operator-era.md`) and keep it byte-identical.
  3. `docs/incidents/2026-09-16-dtf-recovery/migration/quote-evidence.md` — prepend a supersession banner: the one-shot capture consumer is the superseded pre-§1.10 model; the current evidence is the replaceable manual book and the differential suites (`T/UniswapV4DetfMigrationSnapshot.t.sol` and the new P1 suite). Preserve the historical body byte-identically.
  4. `docs/incidents/2026-09-16-dtf-recovery/migration/source-route-matrix.md` and `.../recovery-route-disposition.md` — refresh the stale plan fingerprint line (currently the prior plan hash and 98,213-byte size) to the current plan's identifier, or replace it with a self-describing "governing plan" reference plus a date. No other body change; no custody rerun is required for a fingerprint correction.
  5. `docs/incidents/2026-09-16-dtf-recovery/migration/foundry-runbook.md` — rewrite for portability and explicit typed coverage: repository-root-relative commands (no machine-specific worktree path); the stage table naming, for each operation, the exact script function that performs it, and **explicitly stating "not wrapped in the retained script"** for NFT surrender (a production operation that exists; no wrapper is required or added); the two-stage local QA procedure from 6.6, with the anvil port, the account, the time-advance step and the gas-limit step; and the distinction between simulate, broadcast and production deployment.
- **Invariants.** (i) No historical evidence file is deleted or rewritten in substance; only banners, fingerprint lines and the current-entry files change. (ii) Every command named in the runbook is copy-pasteable from a repository root. (iii) Every stage-table row either names a script function or says it is not wrapped. (iv) The completion record cites artifact paths that exist in the primary checkout or names the exact external path for retained raw logs.
- **Explicit exclusions.** No new application, bundle, journal or launcher; no re-authored historical reports; no requirement to re-run legacy fork recovery for a fingerprint correction; no claim that the runbook's local QA authorizes a public deployment.
- **Regressions / acceptance.** A documentation check in the QA script's own run (the script prints the artifact paths it used) plus the reviewer's own walk-through: a reader starting from `MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` §10 reaches the current commands, results, source/compiler applicability, gas limits and unresolved work without any private session history. No prose-pinning test; the acceptance is a reviewable navigation property, checked by the coordinator's review of the rendered documents.

### 6.5 P1 — pricing evidence qualification for Raw / RawRate

**Mechanism (chosen, single).** Establish the missing **observed-hook** differential for a raw contribution leg at the hook level, on a real production weighted hook built without any state mutation.

- **What exists today (facts).** `T/UniswapV4DetfMigrationSnapshot.t.sol` compares the manual evaluator against the canonical live quote on a V3-SE-backed hook: `EnabledV3Buffer` (real V3 SE deposit) and `DisabledBuffer` (an SE disabled at runtime) are both covered by real-proxy comparisons (`_assertOracle`, `TestBase_UniswapV4DetfMigrationSnapshot.sol:182-191`). `MigrationWeightedPricing.t.sol:338-364` exercises the four `LegMode`s as **arithmetic vectors** only. The captured book can only produce `Raw`/`RawRate` for a leg whose `standardExchange` is `address(0)`; in the current fixture the only such leg is the DETF self leg, which is the **output** leg, and the evaluator quotes only the ETH and DTF contribution legs (`UniswapV4DetfMigrationWeightedPricingLib.sol:108`). Therefore **no observed-hook Raw or RawRate comparison exists**.
- **Chosen comparator.** The canonical oracle is the **hook's own** quote, `hook.previewExchangeIn(rawLegToken, manual.boosted, selfLegToken)` (the hook is the production weighted pool; `previewExchangeIn` is the same entry the DETF subject uses at `B/UniswapV4DetfCommon.sol:261`). A DETF subject is **not** used as the oracle: `UniswapV4DetfProcessArgsLib.sol:120-126` rejects a bare non-self pair from a DETF mint table (`BarePairForbidden`), so a raw contribution leg cannot be hosted by an ordinary DETF package. This keeps the obligation an evidence obligation and does not presume pricing is wrong.
- **Fixture (new, production-first).**
  - New hermetic spec `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedPricingRawLeg.t.sol`.
  - New hook-args variant in `M/TestBase_UniswapV4DetfMigration.sol` beside `_prepareMigrationHookWithWeight` (L297–330): a hook with three legs — one SE-backed V3 pair (so the hook is not all-zero-SE, per the ordinary deploy rule), one **raw** leg with `standardExchange = address(0)`, and the DETF self leg (9 decimals, `ratedScale = 1e27`). Weights must sum to `1e18` and the self leg keeps `4e17`.
  - The raw leg's provider is chosen explicitly through `RateProviderFixtureLib.fillMissing` (L65–78), which keeps a caller-supplied provider: `address(0)` yields `LegMode.Raw`; a real provider yields `LegMode.RawRate`. `providersFor` (L52–62) returns `address(0)` on raw legs and must not be used for the RawRate case.
  - The fixture must reuse the migration base's real permit2 provisioning (CREATE3-deployed `BetterPermit2`, as `M/TestBase_UniswapV4DetfMigration.sol:260-262` does) and must **not** copy the ordinary hook fixture's `vm.etch(PERMIT2_ADDR, …)` (L110). If the hook package can only bind the canonical Permit2 address, the executor must deploy `BetterPermit2` at that address through the repository's real-deploy path rather than etching code — and if no such real path exists, the executor records that as a concrete blocker instead of etching.
  - The book is captured with the production capture facet: `Capture(hook).captureWeightedMintBook()`. The capture-to-`Pricing.Leg` mapping is reused, not re-implemented: extend `MigrationWeightedPricingFixture.observed` (L33–67) with a hook-address overload so the existing `Raw`/`RawRate` branch (L50–52) is the single mapping source.
  - The manual book is installed into the existing `MigrationSnapshotConsumer` (L71–102), which already validates the book with `PricingLib.validate` — so the fixture inherits the production validation rather than asserting it separately.
- **Assertions (per case, Raw and RawRate).**
  1. `manual.pairEquivalent == amount` (identity for a raw leg) and `manual.boosted == mulDiv(amount, 1e18 + p, 1e18)`.
  2. `manual.net == Weighted.applyTradingFeeNet(manual.boosted, capturedFee)`.
  3. `manual.ratedInflow` equals the canonical rated inflow of the raw leg for the same net amount.
  4. `manual.gross == hook.previewExchangeIn(rawLegToken, manual.boosted, selfLegToken)` — the canonical hook quote.
  5. `manual.user == DETFMintSplitLib._splitLiveGross(manual.gross, p).user`.
  6. Freeze check: a real pool trade on the hook changes the live quote and leaves the manual book and its results unchanged (mirrors `test_ManualDifferential_RealProxyCaptureAndFreeze`).
  7. Deliberate manual adjustment changes the manual result without changing the live quote (proves the book is the only input).
- **Authoritative side.** The hook's live quote is the oracle. If an assertion fails, the defect is repaired wherever it lies — the evaluator's leg model or the capture mapping — and the failing case is kept as the regression. No change is made to make the manual result match by weakening an assertion, and no new pricing mode, book field or nested-vault model is introduced.
- **Invariants.** (i) The evaluator keeps using the canonical `Weighted`/`Claim`/`DETFMintSplitLib` arithmetic (no re-implementation). (ii) No live dependency during evaluation (the manual evaluation reads only the installed book). (iii) `PricingLib.validate` remains the single structural gate. (iv) The ordinary weighted-hook suite keeps passing (no production change is expected, but the shared hook code is exercised).
- **Explicit exclusions.** No selected live-production reserve composition; no live-production pricing equality requirement; no new `LegMode`; no change to the manual book's structure; no fork requirement (this is a hermetic real-hook comparison); no re-opening of the E3 gate as a defect.
- **Acceptance.** Two new hermetic cases establish Raw and RawRate observed-hook parity field-by-field against a real hook, with the frozen/manual-adjustment witnesses, and the E3/MIG-AC21 rows can then state "real-proxy Raw/RawRate comparison present" rather than "arithmetic vectors only".

### 6.6 Dependency-ordered task list

Each unit is individually verifiable. Parallelism is allowed only where the edit sets do not collide.

| # | Task | Edits (files) | Depends on | Verifiable unit |
| --- | --- | --- | --- | --- |
| T1 | **F3 metadata** | `M/bondNft/UniswapV4DetfMigrationBondMetadataTarget.sol`; `C/bondNft/DETFFundedBondMetadata.sol`; `T/MigrationSurface.t.sol`; `T/MigrationEgress.t.sol` (assertion only) | — | Owner bond's numeric JSON shows0 claimable rewards and "Locked until activation" before activation, real rewards after; ordinary package URI unchanged; ordinary/cliff/role rendering unchanged |
| T2 | **F1 funding** | `M/interfaces/IUniswapV4DetfMigration.sol`; `M/UniswapV4DetfMigrationWeightedHookTarget.sol`; `M/UniswapV4DetfMigrationWeightedHookFacet.sol`; `M/UniswapV4DetfMigrationPolicy.sol`; `T/MigrationCore.t.sol`; `T/MigrationRecovery.t.sol` (assertion only) | — | Partial-bootstrap remainder reaches reserve liquidity (measured LP growth) before and after activation; over-booked/unbooked/non-owner/duplicate/zero all revert with no state change; recovery and unsolicited inventory untouched |
| T3 | **F2 native QA** | `S/MigrationCoreLocalQA.s.sol` | T2 (the QA script must exercise the post-T2 funding surface if its flow is extended) | The retained two-stage QA path reaches activation on a local node; the failure witness still shows `MigrationOwnerFirstBondRequired` |
| T4 | **P1 pricing evidence** | `M/TestBase_UniswapV4DetfMigration.sol` (raw-leg hook-args variant); `M/TestBase_UniswapV4DetfMigrationSnapshot.sol` (`observed` overload); **new** `T/MigrationWeightedPricingRawLeg.t.sol` | — | Raw and RawRate observed-hook parity, field-by-field, against a real hook; freeze and manual-adjustment witnesses; no etch, no mocked SUT |
| T5 | **F4 documentation** | `D/README.md` (new); `D/verification.md`; `D/quote-evidence.md`; `D/source-route-matrix.md`; `D/recovery-route-disposition.md`; `D/foundry-runbook.md` | T1–T4 (the completion record must cite the evidence those tasks produce) | A reader from the plan reaches current commands, results, source/compiler applicability, gas limits and unresolved work; runbook is repository-root portable; the stage table names each script function or says "not wrapped"; historical records preserved |
| T6 | **Final gate** | none (evidence only) | T1–T5 | The final gate in 6.8 passes with source-bound artifacts |

**Collision notes.** T1 and T2 touch disjoint files. T4 edits the migration TestBase; T3 does not. T5 edits only documents. If T3 needs the TestBase, T4 lands first and T3 re-bases on it. T2 and T1 both change production contracts, so the `forge build --use solar` that precedes their tests must run after both land; the artifact refresh in6.7 is therefore a single rebuild for the whole batch, not one per task.

### 6.7 Exact future verification commands

All compiling Forge commands use Solar. No new Foundry profile; `FOUNDRY_TEST` is never retargeted; caches are never deleted.

```bash
# 0. Fresh single-compiler artifacts before any test (repo law: FactoryServices read creation bytecode from out/)
forge build --use solar

# 1. Focused helper workflow for the edited sources (repo convention)
python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationWeightedHookTarget.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationPolicy.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/UniswapV4DetfMigrationBondMetadataTarget.sol \
  contracts/vaults/detf/common/bondNft/DETFFundedBondMetadata.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigrationSnapshot.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration

# 2. Migration hermetic suite
forge test --use solar --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/**/*.t.sol'

# 3. Ordinary families touched by the shared renderer and the hook fixture
forge test --use solar --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/**'
forge test --use solar --match-path 'test/foundry/spec/vaults/detf/common/**'
forge test --use solar --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/**'

# 4. Full hermetic regression (CI-equivalent)
forge test --use solar

# 5. Pinned legacy Migration forks (local only; never in CI)
FOUNDRY_PROFILE=fork forge test --use solar \
  --match-path 'test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/**/*.t.sol'
```

**Evidence destinations.** Per-task command/exit receipts, compiler versions and the source revision land under `.omo/verification/dtf-gap-closure-<date>/` in the primary checkout; the refreshed `D/verification.md` cites them by path, and the retained fork/hermetic raw logs are referenced by their exact external path where they still live only in the conformance worktree.

**Gas.** The new F1 operation and the F2 owner purchase are measured with the existing producer (`S/MigrationDeploymentGasResumedQA.s.sol` pattern) at 1/8/16/32/64 shapes where applicable, and the selected shapes are checked against the authenticated 32,000,000 transaction ceiling recorded in `D/conformance-20261114/task-11/batch-limits.md`. The 64-recipient issuance shape stays excluded from the admitted limit, as recorded. No measurement may be taken against the permissive local block-gas setting.

### 6.8 Realistic native local-QA procedure (existing repo conventions)

The retained `S/MigrationCoreLocalQA.s.sol` is a two-stage `forge script` on a local Anvil node (`MigrationCoreLocalQA` L83 names the guarded owned 18548 Anvil). No new launcher is invented and no public funding is required.

```bash
# 1. Owned local node on the repo's QA port, with the recorded gas-limit configuration
anvil --host 127.0.0.1 --port 18548 --chain-id 31337
cast rpc --rpc-url http://127.0.0.1:18548 anvil_setBlockGasLimit 0x5f5e100
cast rpc --rpc-url http://127.0.0.1:18548 anvil_mine 0x1

# 2. Stage A: deploy, fund, bootstrap, configure, issue, and (after F2) the paid owner bond
forge script --use solar \
  scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol:MigrationCoreLocalQA \
  --sig 'deployAndIssue()' --broadcast --unlocked \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --rpc-url http://127.0.0.1:18548

# 3. Advance past the 90-day cliff on the owned node
cast rpc --rpc-url http://127.0.0.1:18548 evm_increaseTime 7776000
cast rpc --rpc-url http://127.0.0.1:18548 anvil_mine 0x1

# 4. Stage B: mature principal, owner activation (now reachable), post-activation claims
forge script --use solar \
  scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol:MigrationCoreLocalQA \
  --sig 'exerciseAfterCliff(address)' <MIGRATION_PARENT> --broadcast --unlocked \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --rpc-url http://127.0.0.1:18548
```

`MIGRATION_PARENT` is the address the stage-A run prints (`MIGRATION_PARENT` console log, L293). The stage-A gas-limit and time-advance steps follow the procedure already recorded in `migration/pricing/evidence/implementation/local-gas-header-command.txt` and the `chain-gas-limits.log` referenced by `task-11/batch-limits.md`; the local block-gas setting is never the admission policy. The QA must additionally print the F1 reserve-progress measurement and the F3 owner-bond metadata before and after activation, and its receipts land in the same evidence directory as the hermetic runs. **This is a local QA rehearsal, not a deployment or funding authorization.**

### 6.9 Final gate

The migration is closed only when all of the following hold, each with source-bound evidence:

1. **F1 closed**: a real registry proxy shows the partial-bootstrap remainder reaching reserve liquidity, measured as hook LP growth at `_bondLpHolder()` with matching token/inventory deltas, before and after activation, with no new payment and no personal issuance; the donation book is debited consistently; recovery, unsolicited and bond backing inventory are provably untouched; every failure path leaves all books unchanged.
2. **F2 closed**: the retained two-stage QA path executes on a local node and reaches payment → funded ordinary owner bond → prerequisite → activation → selector removal → post-activation reward payout; the failure witness shows activation rejected without the purchase; the production prerequisite is unchanged.
3. **F3 closed**: the paid owner's ordinary bond's numeric JSON attributes and rendered availability state the activation gate before and after activation; ordinary packages, reserved roles and migration cliffs render unchanged; the ordinary package's URI is byte-identical to its pre-change output.
4. **F4 closed**: `D/README.md` and the refreshed `D/verification.md` give a reader the current commands, exits, compiler versions, source revision, gas limits and unresolved work; `D/quote-evidence.md` and the two route indexes carry correct supersession/fingerprint lines; the runbook is repository-root portable and its stage table names each script function or says "not wrapped"; historical evidence is preserved.
5. **P1 closed**: Raw and RawRate observed-hook parity is demonstrated field-by-field on a real hook with the freeze and manual-adjustment witnesses, or — if an assertion fails — the evaluator or capture mapping is repaired against the canonical hook quote with the failing case kept as the regression; E3/MIG-AC21 then state the real-proxy comparison instead of arithmetic vectors only.
6. **Ordinary-family regression green**: the full hermetic suite passes (no failures, no skips) on a single-Solar rebuild, including the ordinary DETF, common bond/staking and weighted-hook suites.
7. **No stale-artifact substitution**: the run uses artifacts from one compiler generation, produced by the `forge build --use solar` that immediately precedes the tests; no mixed-generation artifact set is admitted as evidence.
8. **Current completion record**: `D/verification.md` cites every artifact path used above, with commands, exits and versions, and lists anything still open.
9. **Explicit non-claims**: no production deployment, funding, activation or compensation execution is performed or implied; no live instance is assumed upgradeable; no withdrawn application, bundle, journal, holder-ancestry or live-composition requirement is restored.

## 7. Conclusions

1. **F1 has a single minimal repair.** The stranded units are not lost — they are booked in `donationInventory` and physically held — and the only missing piece is a bounded, fixed-destination route that moves booked donation capital into the new reserve. The ordinary sweep already joins the hook's pair tokens and SEs into reserve liquidity; the plan reuses it with the budget isolation already proven in `_donateRecovery`, debits the donation book at selection, keeps refunds as residual, and measures actual LP progress. No new discretionary authority, no arbitrary withdrawal, no recovery-inventory debit and no change to the permissionless donation path.
2. **F2 is a helper capability, not a production defect.** The production activation guard is correct and stays untouched. The QA owner contract needs exactly one new capability — a genuine paid ordinary purchase by the current owner with real capital — plus a corrected stage-A/stage-B sequence and a failure witness. The bond id must be tracked distinctly from the independent-compensation bond so the existing `id_ == 3` and `positionOf(3)` assertions keep their meaning.
3. **F3 is a two-line semantic change plus a renderer widening.** `rewardsClosed` must stop depending on the presentation style and depend on the parent activation state, and the shared renderer must state the gate for purchased bonds as it already does for cliffs and roles. The ordinary package never sets the flag, so the shared change is provably inert there — which is why an additive View field is unnecessary.
4. **F4 is navigation, not new evidence.** The current results already exist (236/183 Migration, 28,641 full hermetic, the 32,000,000 gas record); what is missing is a coherent entry point, refreshed fingerprints, a portable runbook, and a stage table that says explicitly which operations the retained script does not wrap.
5. **P1 is an evidence gap, not a suspected arithmetic defect.** The current fixtures genuinely cover `EnabledV3Buffer` and `DisabledBuffer` against a real hook; `Raw`/`RawRate` are covered only as arithmetic vectors, and cannot be covered through a DETF subject because a bare pair is rejected from a DETF mint table. The minimal production-first coverage is therefore a hook-level differential on a real hook with a raw leg, built on the migration fixture's own hook-deployment path with no state mutation. The hook's live quote is the oracle, so the plan cannot conclude in advance which side is wrong — it fixes the oracle and keeps any failing case as the regression.
6. **The task order is collision-free.** T1 (metadata), T2 (funding) and T4 (pricing evidence) touch disjoint files and may proceed in parallel; T3 (script) follows T2; T5 (documentation) follows all of them because it must cite their evidence; T6 is the final gate. One Solar rebuild serves the batch because the artifacts are shared.

## 8. Limits

1. **Nothing was executed.** No build, test, script, fork, RPC call, transaction or Git action was performed. Every statement about current behavior is a source reading, and every statement about future behavior is a plan, not an observation.
2. **This plan cannot certify absence of further defects.** It closes the five accepted gaps; it does not re-audit the migration implementation, and it does not reopen the prior review's rejected claims.
3. **Partial source coverage.** `MigrationLegacyRecoveryLib.sol`, the `sy/` and `claimToken/` internals beyond the cited gates, and the `migration/` evidence archive were not re-read. The F1/F2/F3/F4/P1 targets themselves were read directly.
4. **Two implementation details are explicitly delegated to the executor's source reads, not left as design choices.** The exact inherited `_buyOwnerFirstBond()` payment parameters (the executor mirrors them; the mechanism is fixed) and the exact hook-args construction for the raw-leg fixture (the executor follows `_prepareMigrationHookWithWeight` and `fillMissing`; the comparator and assertions are fixed).
5. **A permit2 binding question remains a risk, not a menu.** If the weighted hook package can only bind the canonical Permit2 address, the executor must find a real-deploy path for that address; if none exists, the P1 fixture records a concrete blocker instead of etching code. The plan forbids the etch either way.
6. **Gas for the new surfaces is unmeasured.** The 32,000,000 ceiling and the admitted shapes are recorded evidence; the new operation's and the owner purchase's costs must be measured and must not be admitted below the ceiling.
7. **No live instance is assumed repairable.** Any live-deployment remedy for F1–F3 is a separate decision and authorization; this plan produces source changes and fresh deployment artifacts only.
8. **Publication.** Because no `apply_patch` tool exists in this harness and the brief forbids an alternate writer, this complete contribution is returned inline for the coordinator to archive; no file was written by me.

— end of contribution —
