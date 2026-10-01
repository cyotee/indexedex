# FullSpread G4 import, deployment and oracle closure

## Reconciled parent execution checkpoint — 2026-09-30

**Latest G4: 28 passed, zero failed/skipped**, 14 tests in each family,
`tool_0f2c329e50011839URdKreiEXa`. This includes the sorted-copy contents-ID fix,
both native discovery permutations, reverse-sorted WETH money paths, propagating
TWAP fault rollback, changed-manager instance rejection and imported core
checkpoint/SY lifecycle additions. The log's final result was read during this
docs-only reconciliation; no tests were executed by this task.

This supersedes the pending-validation wording for those additions and the old
items 1, 2, 4 and 5 below. F is the selected preservation baseline: its TWAP
dependency failure propagates, and the new fault test validates atomic rollback.
O's conflicting fail-open success is specifically superseded, not an unresolved
owner decision. CREATE3's masked constructor failure remains explicitly distinct
from the exact `processArgs` mismatch error. Extra decimal/native Cartesian
products or generic package lifecycle variants are not new G4 release gates.

The earlier 436-family/128-fuzz checkpoint predates the native production fix;
the final expected 450-family run and final manifests remain pending. Existing
deployments are not migrated, PoolKey face order and salts are unchanged, and no
overall readiness/retirement approval is claimed. The remainder is historical
worker provenance; the actual predicates described there remain useful.

**2026-09-30 — native contents-ID fix: owner reports 22 G4 green. New fault/lifecycle extensions await parent validation.**

### Bounded TWAP preservation and lifecycle extension

The owner reports the native DFPkg fix passed all 22 prior G4 instances. This pass adds three test definitions inherited by both existing family leaves (six new intended instances; **28 intended G4 instances total**) and extends the existing native-order test. None of these new cases has been compiled or executed by this worker. No Forge command, delegation, production edit or existing shared-fixture edit was performed in this pass.

**Baseline resolution, superseding the earlier open-policy note below:** implementation/test plan **§1, lines 15–21** explicitly defines `F = U/v4/`, the unsegmented baseline, `O` as the older protocol-tree baseline, and `Baseline suffix = F/UniswapV4FullSpreadStandardExchangeVault<suffix>.sol`. Current PRD §3 selects the new FullSpread baseline; plan §7 preserves its oracle selectors. At `F/UniswapV4FullSpreadStandardExchangeVaultCommon.sol:336–337`, `_pokeBoundPoolTwap()` directly calls `twapOracle().update(_poolKey())` without a catch. The F release test `UniswapV4FullSpreadStandardExchangeVault_TwapPoke.t.sol::test_H16_pokeRevertFailOpen` actually expects `bytes("hostile")` at lines 155–175: its name is misleading, its assertion is fail-closed. H/P retain the direct call. Thus the preservation target is **F's propagating failure**, not older O's fail-open success. O is superseded for this specific conflicting expectation by the already-selected F baseline; this is not a new owner policy decision, removal of TWAP, or blanket waiver of O custody/rollback assertions.

New external counterparty: `contracts/test/stubs/FullSpreadG4OracleCounterparty.sol`. Deployed through CREATE3, it holds a genuine bound production oracle and forwards ordinary calls. Its controlled fault affects only this external dependency: `update` first invokes the real oracle and then optionally reverts with `UpdateFault()`. Its advertised manager can be changed after package construction. H/P vaults, facets, packages, registry, manager and underlying oracle remain real; no `mockCall`, injected storage or substituted vault execution is used. New package construction uses each family's existing G4 adapter and registry, under a unique test identity.

| Actual test | Added predicates |
|---|---|
| `test_G4_twapUpdateFaultRollsBackFundedOperation` | Ordinary funded dual activation propagates the exact counterparty error. Before/after fingerprint includes payer/vault token and share ledgers, sink/supply/local books, payer allowances, complete opaque quote snapshot, manager token custody, pool slot0/active liquidity/global fee growth/full-range owned liquidity and both fee checkpoints, genuine oracle observation, caller/vault ETH. Clearing the fault allows the same funded activation to succeed with exact caller shares and supply. The fault occurs after the genuine oracle update, so its write must also roll back. |
| `test_G4_twapChangedManagerRejectsInstanceWithoutRegistration` | Construct and register the real package with correct advertised manager, then mutate only external advertisement. Instance deployment rejects with exact `TwapOraclePoolManagerMismatch` through `processArgs`; global vault count and empty package-vault membership are unchanged. Restore advertisement and deploy successfully, proving the valid path registers the actual vault. This is not a constructor payload assertion; prior constructor tests retain CREATE3's masked `ErrorCreatingContract`. |
| `test_G4_importCoreCheckpointAndSyLifecycleBothFaces` | Mint/trade a real NFT; obtain its actual PoolKey and PositionInfo; compare core liquidity with the PositionManager getter. Snapshot-isolated actual full removal supplies the expected **complete core position tuple**: zero liquidity and both fee-growth-inside-last values, keyed by actual PositionManager owner, NFT ticks and `bytes32(tokenId)` salt. Import must match that tuple exactly. From restored post-import states, both token faces redeem through SY with exact preview/payout, caller share debit and supply burn, requested recipient, zero self-share residue/full booking, and unchanged recipient ETH. The empty NFT retains original pool/ticks, vault owner, cleared approval and zero PositionManager spend approvals; its entire core tuple stays unchanged through each redemption. |
| Extended `test_G4_nativeRegistryPreservesPoolKeyOrder` | Retains reversed-address WETH ordering, canonical contents and both-permutation discovery checks. Funds real WETH by `deposit`, activates the actual native pool through the ERC20-facing dual route, then snapshot-isolates **WETH→pair, pair→WETH, WETH→shares and pair→shares**. Each uses exact preview/execution/payer/recipient/supply deltas, unchanged caller and recipient ETH, zero vault ETH and complete local token/self-share books. Calls use WETH ERC20 inputs/outputs, not raw-ETH SE entrypoints. |

The existing `NativeSettlement.t.sol` family leaves inherit EquivalentInterfaces tests and provide useful native alias coverage; they do not alone establish a deliberately reverse-sorted WETH money-path fixture. The extended G4 test now supplies that fixture. This bounded extension still does not instantiate every legacy decimal leaf, every native exit/refund route or every generic package lifecycle assertion. The earlier gap list is historical: items 1–2 (TWAP fault/mutable advertisement) and the core-checkpoint/SY portion of item 4 now have concrete new test predicates; their execution remains pending. No overall readiness or retirement result is inferred.

### Authorized H/P discovery fix checkpoint

Owner reports **22/22 G4 green** and the prior **H/P full 436/128 green** checkpoint before this production fix. Those are parent-reported prior-source results, not execution evidence for the changes below; no new log or interpretation of the 436/128 counts is supplied here.

The owner subsequently authorized the minimal production correction in only the new H/P DFPkgs. Each `initAccount` now allocates a **fresh two-address copy**, sorts that copy, and hashes it for `StandardVaultRepo`'s `contentsId`. The original `tokens` array remains PoolKey-ordered for vault storage, metadata names and approvals. PoolKey storage, package arguments, component/package name salts and instance `calcSalt` are unchanged. No shared registry or other production file changed.

`test_G4_nativeRegistryPreservesPoolKeyOrder` retains the deliberate `pair < WETH` fixture, exact `[WETH,pair]` public/config arrays, name/symbol and per-token membership checks. Its helper now requires config/public contents IDs to equal the independently calculated sorted-array hash, verifies exact singleton membership under that contents ID, and requires **both permutations of `vaultsOfTokens` to return the actual native vault**. The former ordered-ID registration expectation is superseded by this authorized fix, not kept as a desired product property.

This applies to **fresh deployments using corrected package bytecode only**. Existing packages/proxies are not migrated or rewritten. CREATE3 occupied-name reuse does not replace existing package runtime, and the diamond factory returns an existing proxy without reinitializing it. Address derivation remains unchanged for identical factory/package addresses and arguments; the stored metadata of an already-deployed instance remains unchanged. Parent must refresh both DFPkg runtime artifacts before validating the corrected source under the standard artifact-first workflow.

This pass changed the two new-family DFPkgs, the G4 deployment helper and this document only. No Forge command, delegation or commit was performed. The historical sections below describe earlier checkpoints; the discovery gap described there is now addressed in source, **pending parent build/test**, with no new pass claimed.

### Historical parent checkpoint and native reference correction

Read parent log `/Users/cyotee/.local/share/opencode/tool-output/tool_0f26ab3a3001DPPOuSul0nxQod`: compilation succeeded; each G4 family passed ten tests and failed `test_G4_nativeRegistryPreservesPoolKeyOrder`, with ordered hash `0x06149b7b3a6538ba0e8df6bfaaa6682b9bae9083daa69a071f167cbce8f29f35` versus sorted hash `0x4cea33fccec8ecd20578127334388c4d99b8b78367e1a66565a07debda4ca0e4`. Other suites in that combined log are outside this G4 checkpoint. The original source-only status statements below describe the initial handoff; this paragraph records later parent evidence. The corrected source has not been rerun by this worker.

The test incorrectly equated two source-defined IDs:

- H `DFPkg.initAccount` lines 301–308 and P equivalent lines 310–317 build ERC20 faces in **PoolKey currency order** and store `keccak256(abi.encode(tokens))` without sorting. Native currency0 becomes WETH even when WETH sorts after the pair. PRD §3 preserves PoolKey ordering/native faces; it does not state that this stored hash equals the registry's sorted helper.
- `MultiAssetBasicVaultRepo._initialize` lines 50–55 inserts tokens using `AddressSetRepo._add`, not `_addAsc`. `_vaultTokens` lines 58–63 returns stored values. `MultiAssetStandardVaultTarget.vaultConfig` lines 25–32 returns those tokens and the stored contents ID. The exact fresh-fixture `[WETH,pair]` assertions therefore remain. This is not a general ordering guarantee for arbitrary registry set enumeration after insertions/removals.
- `VaultRegistryVaultQueryTarget.calcContentsId` lines 75–84 sorts its input before hashing. `vaultsOfTokens` lines 64–65 also searches by the sorted hash.
- `VaultRegistryVaultRepo._registerVault` lines 106–114 indexes the **supplied** `vaultConfig.contentsId`; it does not recompute a sorted hash. Per-token membership is separately inserted at lines 135–139.

Correction is confined to the G4 helper and this document: retain exact public token/config order, assert the ordered config hash independently and through `contentsId()`, verify exact membership under that hash via `vaultsOfContentsId`, and independently assert both input permutations to `calcContentsId` equal the sorted hash. An explicit inequality preserves the reverse-sorted fixture's non-vacuity. No assertion was simply deleted or converted to an unordered membership check.

**New explicit discovery gap:** for this native ordering, sorted `vaultsOfTokens` lookup searches a different key from registration's ordered config key. The reference correction does not fix or endorse that discovery inconsistency and does not close all registry discovery behavior. It requires separate production-scope disposition; no production changes are authorized here. No trace is needed to explain the reported hash mismatch from these sources; parent owns the rerun.

This is a bounded update to G4 in [the acceptance map](UNISWAP_V4_FULLSPREAD_ACCEPTANCE_MAP.md), not an overall readiness or retirement verdict. The existing map's inventory of 250 O plus 100 L test definitions remains historical source inventory, not a count of assertions closed here. No historical 270/313/315 or broader result is promoted to a current-tree pass.

## Initial test-only owned files and validation boundary (historical)

Added only:

- `contracts/test/bases/TestBase_UniswapV4FullSpreadG4ImportClosure.sol`
- `contracts/test/bases/TestBase_UniswapV4FullSpreadG4DeploymentClosure.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ImportDeploymentClosure.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ImportDeploymentClosure.t.sol`
- This document.

The concrete contracts are `UniswapV4FullSpreadHooklessStandardExchangeVaultImportDeploymentClosureTest` and `UniswapV4FullSpreadPonsFamilyHookImportDeploymentClosureTest`. Each inherits the **11 actual `test_G4_*` definitions** listed below. This is 22 intended family test instances, **not 22 executed passes**.

The worker invoked no Forge command, compiler/LSP-check command, subagent, or commit. `apply_patch` surfaced an asynchronous LSP diagnostic labelled `[forge build]` for mixed tuple declaration syntax; that syntax was corrected in source. No subsequent compiler verdict is claimed. Parent alone owns the combined artifact-first build/test after concurrent workers finish. Inspect compilation first, including stack depth and current inherited interfaces; this patch has only source review.

Existing shared bases, acceptance tests and production sources were not edited. Both adapters extend their existing family Acceptance base, with its actual registry, PoolManager, Permit2 and TWAP oracle. PositionManager is the real periphery artifact deployed through CREATE3. The P fixture uses the real V2 hook and registration via the existing authorized test registrar; it is not represented as a new launch/graduation or production-chain attestation. Existing P native import tests retain the genuine Launch fixture.

The G4 helper's H interface imports supply common ABI/error declarations and do not route P execution through H. The two family proxies and economic implementations remain separate. No mock SUT, storage injection, proxy impersonation, or artificial token balance injection was added. Snapshot restores isolate real NFT fee collection/withdrawal controls.

## Authority and supersession

Authoritative documents: [current PRD](UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md), [implementation/test plan](UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md), [context amendment](UNISWAP_V4_FULLSPREAD_CONTEXT_QUOTE_ADDENDUM.md).

- PRD §3 preserves actual dual funding, full-range imported backing, native/WETH ordering and fees counted once. Plan §2.1/F0 expressly excludes pre-existing sleeve inventory from NFT contribution and preserves empty-NFT custody.
- PRD D15–D16, §§11–12 preserve source-agnostic unbooked credit, the contract-caller guard and complete local booking. Imported principal/fees already booked at completion cannot be claimed again.
- PRD D22 and §10 supersede old component names. Plan §7 requires full ABI-name salts and registry deployment. The context amendment adds optional interfaces; old fixed 15-interface expectations are not current law. Current package controls use **20 interfaces and 15 facets**, with exact ordering and full names.
- Plan §2.5 explicitly gives P's factory model **zero own LP fees** and separate Pons charges. The H fee test requires positive actual NFT LP fees. P executes a real taxed trade and requires zero collected NFT LP fees; it does not fabricate a positive fee-bearing P pool or classify hook fees as NFT backing.
- **TWAP is not removed or superseded.** Plan §7, “Deployment and selector wiring,” expressly says to preserve every baseline oracle selector. PRD §9's statement that no new independent-reference oracle requirement is approved is not permission to remove the existing TWAP. PRD D31 deprecates old code-linked PRDs; it does not itself waive these preserved assertions.

## Assertion-level resolution

Here **Added** means source predicates exist and await parent validation; **Mapped** means reuse existing assertion bodies without duplicating them; **Open** means not closed. H/P below refer to the two concrete contracts above unless a different file is given.

| Legacy assertion / map row | Actual replacement test and predicates | Disposition / bounds |
|---|---|---|
| IMP untrusted PositionManager | `test_G4_importTrustMatrix`: valid real NFT exists; wrong supplied manager yields exact `UntrustedPositionManager`; ownership, approval, NFT liquidity, local/supply/payer and manager/PositionManager custody fingerprint unchanged | Added H/P. Wrong manager is an inert argument, not a mocked contract. |
| IMP unbound manager | Same test creates a separate real registry package with `positionManager == 0`, approves its proxy, and checks exact trust rejection, fingerprint and zero supply for both proxies | Added H/P. Canonical package is not overwritten or rebound. |
| IMP owner mismatch | Same test checks both forged `owner` argument and caller claiming an NFT actually owned by another account; exact `UntrustedImportOwner`, unchanged fingerprint and no attacker shares | Added H/P. |
| Unfunded imported side / missing actual funding | `test_G4_importUnfundedSideRollbackBothOrientations`: out-of-range narrow NFTs on each side; independent withdrawal proves one positive and one zero delivered leg. Prior donations fund both local faces but cannot substitute for missing NFT contribution. Exact `ZeroAmount`, restored owner/approval/liquidity/custody and zero supply | Added H/P 18/18, both orientations. This is not a blocked-import rejection masquerading as a funding check. |
| A0 import below minimum | `test_G4_importBelowFloorRollback`: real small NFT, both measured amounts produce positive raw geometric mean at or below `1e15`; exact `InsufficientMinimumLiquidity(raw,1e15)` and restored fingerprint, zero supply and zero vault token custody | Added H/P 18/18. Decimal leaf expansion remains open. |
| Earned fees once / exact first issuance | `test_G4_importEarnedFeesOnceAndApprovalsZero`: actual external trade, snapshot-isolated zero-liquidity fee collection followed by full principal removal; restored full removal equals principal plus fees exactly; actual mint equals `sqrt(actual0*actual1)-1e15`, exact caller/sink/supply | Added H/P, with positive H fee witness and P zero-LP-fee control under plan §2.5. Uses generic arithmetic and actual periphery settlement, not the vault's preview as expected mint. |
| ERC20 import minimum failure | Same test first requests measured expected shares + 1; exact slippage error restores NFT/approval/liquidity and custody fingerprint; retry with exact minimum succeeds | Added H/P. Native minimum rollback mapped separately below. |
| M3 Permit2/direct/NFT approvals | Same test checks both vault-to-PositionManager ERC20 allowances zero; Permit2 amount/expiry/nonce for each PositionManager spend entry all zero; retained NFT owner is vault, liquidity zero, token approval cleared, no approval-for-all to importer | Added H/P. Does **not** falsely require the package's intentional ERC20-to-Permit2 settlement allowance to be zero. |
| Cannot import the retained empty NFT again | Same test retries from original owner, exact owner-authentication rejection, no ledger change | Added H/P. It asserts the actual earlier guard, not `PositionImportUnavailable` after an impossible owner impersonation. |
| L imported position cannot become unfunded credit | `test_G4_importCannotManufacturePretransferCredit`: successful import, positive booked sleeve on both faces; code-bearing caller with no delivery gets exact `TransferDeltaInsufficient(1e12,0)`; EOA gets exact guard; fingerprint/attacker assets and shares unchanged | Added H/P. Both faces tested; preserves EOA vs contract distinction. |
| FR6 narrow→full-range, NFT retention | Existing H/P `PositionImport.t.sol::test_narrowNftConvertsToFullRangeAndRetainsEmptyNft`: positive full-range vault position at canonical salt, zero imported NFT liquidity, vault ownership and complete local booking | Mapped; no duplicate fixture test. New exact issuance/approval tests add the missing predicates. |
| Blocked import | Existing H/P `PositionImport.t.sol::test_importDuringOuterUnlockRejectedWithoutNftTransfer`: real outer unlock, exact interaction-blocked error, caller retains NFT and positive liquidity | Mapped. |
| Native actual import funding / prior sleeve exclusion / residual sink | Existing H/P `NativePositionImportFunding.t.sol::test_nativeImportActualFundingExcludesPriorSleeve`, through `TestBase_UniswapV4FullSpreadNativeImport._nativeImportFundingAndDonationExclusion`: snapshot-isolated actual withdrawal, equal caller issue with/without donations; exact independent residual sink/supply, full-range position, WETH/local/self booking and no ETH residue | Mapped. Private `_mintAndMeasure` / `_executeImport` remain private; no attempted inheritance call or shared-base edit. |
| Native minimum failure | Existing H/P `NativePositionImportFunding.t.sol::test_nativeImportLateGuardRestoresNftAndBalances`: actual expected amount + 1, exact minimum failure, owner/liquidity/pool/custody rollback then funded retry | Mapped. |
| Package metadata and component bindings | `test_G4_packageRegistryMetadata`: exact full family package name; full 20-interface vector; 15 expected fixture facet addresses/order; metadata/getter/config/cut consistency; Behavior_IFacet metadata consistency for every facet | Added H/P. Existing Admission target-derived selector controls remain the independent API coverage; cuts-vs-declarations consistency alone is not asserted to replace them. No `Behavior_IDiamondFactoryPackage.sol` implementation was found in the current Crane tree; no nonexistent helper was imported. |
| Registry, config, names | Same test: exact package/token registry count and membership for ordinary fixture; vault token/config order, full types, contentsId; exact public name, `UV4X`, 18 decimals | Added H/P. |
| ABI-name component and package salts | `test_G4_packageAndComponentAbiNameSalts`: independent expected full prefix/suffix names for all ten family facets, both bound execution delegates and package; `Creation._create3AddressFromOf(factory,keccak256(abi.encode(name)))` equals actual; raw-name predicted address differs; nonempty runtime | Added H/P. Deployment itself is the Acceptance registry path. This is address evidence rather than merely an occupied-salt negative. Generic facets retain their canonical identities. |
| Native order and registry strings | `test_G4_nativeRegistryPreservesPoolKeyOrder`: actual mintable pair deliberately deployed below WETH address, native PoolKey retains WETH-first public faces; exact config/contentsId, WETH/pair registry membership, `UniV4 Vault of (WETH / G4N)` and `UV4X` | Added H/P. Metadata only; not a native-money-path test. |
| Launch helper activation/replay/later intake | `test_G4_launchActivationReplayDoesNotReseed`: actual `PoolSeedLib.activateStandardExchange`, exact two input debits, receiver/sink shares, cleared allowances; replay preserves payer/vault book/supply and receiver shares; later quoted positive unilateral pull gives exact receiver increase | Added H/P ordinary 18/18. This is the helper actually used by the legacy assertion, not a replacement bootstrap helper. |
| H14 binding/cardinality; H15 first tick | `test_G4_twapBoundPoolObservationAndNonwritingPolicy`: actual bound oracle/manager; initially empty observation; actual direct trade then cardinality one, recorded/prev tick equals final manager tick, initialized observation and cumulative zero | Added H/P. |
| H17 transfer/foreign isolation | Same test: transfer after time advance leaves bound observation unchanged; vault maintenance does not write foreign key; explicit update of initialized foreign key writes only it | Added H/P. Foreign pool is a real hookless pool, independent of the P admitted vault pool. |
| H27 package-wide oracle sharing | Same test deploys second proxy and verifies same oracle and manager | Added H/P. |
| Nonwriting update policy | Same test: same-timestamp `update` returns false; funded vault activation still succeeds; uninitialized foreign pool update returns false | Added H/P. **False return is not a reverting-dependency test.** |
| H29 zero/mismatched constructor binding | `test_G4_twapInvalidConstructorBindingsDoNotRegister`: registry CREATE3 rejects zero oracle and a real oracle bound to a second real PoolManager; registry package count unchanged | Added H/P. Exact observed boundary error is `Bytecode.ErrorCreatingContract`; CREATE3 masks inner constructor data. Does not claim to assert inner `ZeroTwapOracle` / `TwapOraclePoolManagerMismatch` payloads. |

## Exact remaining gaps

1. **H16 reverting TWAP dependency:** no new hostile-oracle replacement/injection test was added under the no-mock-SUT constraint. Actual H and P `Common._pokeBoundPoolTwap()` directly call `twapOracle().update(_poolKey())`, without a catch. Their PositionImportTarget calls this after import. Therefore current source propagates dependency reverts; this is a source conclusion, not newly executed fault evidence. Legacy O's `test_H16_pokeRevertFailOpen` expects success; legacy L's identically named body explicitly expects `bytes("hostile")`. They cannot both be mapped to one assertion by name. **No explicit current PRD decision was found superseding the old O failure policy.** Preserve O as historical evidence and leave the policy discrepancy plus exact dependency-revert/atomicity test open; do not claim deletion or blanket supersession.
2. **H28 mutable oracle manager after package construction:** real supplied oracle has immutable initialized binding and no manager setter. The legacy `FlipTwapOracleFullSpread.setPm` scenario needs a controlled external oracle dependency; not reproduced here. Package `processArgs` still performs the manager comparison, so this is not obsolete behavior. Exact inner H29 errors are also not established by the wrapped registry constructor negative.
3. **Original decimal inheritance:** new import predicates use the existing ordinary 18/18 acceptance fixtures. They do not instantiate all O/L 6/9/18 decimal leaves. Existing native import coverage is mapped with its own native fixtures, not promoted to an all-decimal trust/floor matrix.
4. **Post-import SY lifecycle:** existing source mappings establish full-range conversion and native exact funding; new fee test establishes exact issuance and rejection of a repeat import. The legacy FR6 sequence's subsequent SY redemption and complete narrow core-position checkpoint comparison are not newly asserted here. NFT liquidity zero is observed through the actual PositionManager, not a substitute for every core fee-growth checkpoint assertion.
5. **Native money ordering:** new deliberately reverse-sorted WETH test establishes registration/order/metadata, while existing native import tests establish wrapping/custody. It does not independently close every legacy native direct-swap/zap user's ETH-balance and WETH-payout predicate or decimal wrapper.
6. **Package declaration details beyond G4's new checks:** new metadata vectors and salt predictions do not independently test all lifecycle hooks/instance `calcSalt` permutations or replace the existing Target-derived selector tests. Generic package Behavior coverage remains a broader testing-infrastructure issue; no new shared framework helper was introduced.
7. **Validation:** all new source must compile and execute in the parent's sole combined run. No gas result, test pass, coverage percentage, G4-full-closure claim, or retirement authorization is supplied. Keep the remaining gaps unresolved even if the 22 intended instances pass.

## Parent handoff

Focus the two concrete `*ImportDeploymentClosureTest` contracts and their inherited `test_G4_` methods in the parent's planned run. Reuse the existing H/P PositionImport and NativePositionImportFunding suites for the mapped predicates. Build actual runtime artifacts first under `CLAUDE.md`; do not change profiles, enable via-IR, or treat these new tests as preserving all 350 legacy definitions. The only permitted follow-up edits for this work package are the five owned files above unless the parent expands scope.
