# FullSpread SE Hooks — Independent Code Review (task-22 track)

- Auditor: omo-native-code-reviewer (st_01a1b465), read-only source audit.
- Requirements authority: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` (rev `fullspread-se-prd-hook-fees-bootstrap-20261106`, FS-OWN-34..37 / FS-HOOK-05..10).
- Method: read current working-tree sources (no builds/tests/git per mandate). Note: the tree was edited in flight by the parent during this audit; every finding below was re-verified against the tree at report time, and where the parent already corrected a path mid-audit that is stated explicitly.
- Skill-perspective check: the `remove-ai-slops` and `programming` skills are NOT installed in this environment (checked `.claude/skills/`, `.agents/skills/`, and user-level skill roots). Their documented criteria from the task prompt were applied by hand: deletion-only/tautological/implementation-mirroring tests, needless production complexity, untyped escape hatches, boundary-less validation. Verdict of that pass: one MEDIUM slop cluster (M-2); no brittle prompt tests or removal-only tests found in the sampled new test adapter (see Limits).

## Findings

### HIGH

**H-1 — Dual advertises `IDetfReserveQuote` (ERC-165) but omits 3 of its 5 selectors.**
- `.../standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol:17-19` — family interface inherits `IDetfReserveQuote`.
- `.../dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol:153` — `facetInterfaces()[10] = type(IDetfReserveQuote).interfaceId` (registered on the proxy at deploy).
- Installed selectors: `previewSynthetic` (`dual/facets/...HooksFacet.sol:89`, funcs[20]) and `previewBurnToToken` (`dual/facets/...WithdrawFacet.sol:40`, funcs[10]). `previewSynthetic` is a constant-0 stub (`dual/...HooksTarget.sol:348-359`).
- Missing: `previewSwapAfterExchange`, `previewJoinAfterDeposit`, `previewBondAfterDeposit` — zero matches anywhere under `dual/`.
- Trigger/impact: any DETF-side consumer that probes `supportsInterface(IDetfReserveQuote)` (true) then calls one of the three projection selectors hits the diamond fallback and reverts. This also fails the task-14 acceptance clause "facet metadata agrees with interface-derived controls". The interface's own NatSpec is self-contradictory ("DETF-facing ABI is IUniswapV4SeBufferHook + IDetfReserveQuote" vs "Dual is not a DETF reserve").
- Smallest fix: either (a) implement the three views — dual already has the raw material (`DepositQuoteLib.preview` / `previewExit`, and `LegLib.afterExternalDeposit`/`afterExternalExchange` used by siblings) — or (b) drop `IDetfReserveQuote` from the interface inheritance and from DFPkg `facetInterfaces()` + HooksFacet `facetInterfaces()`, keeping the two installed view selectors under the family interface only. (a) is preferable if dual is ever a bond reserve.
- Status: known item from the parent's tracker; confirmed with exact slot/selector inventory above.

**H-2 — (classification per the parent's ruling) paid-incumbent-swap joins violated the literal FS-HOOK-07 pre-intake snapshot rule in the pre-migration revision; the current tree has already corrected all six LP families.**
- The audit started on a revision where single-asset/partial joins sold part of the caller's input against incumbent books and ran component acceptance against the post-trade snapshot (CP-single `ClaimLib._singleTrade`+`_commitBasket(postTradeBook,…)`; dual `Common._depositSingle`→`_executeZapSwap` then `_joinComponents`; orbital `_tradePartialBasket`→`_acceptJoin` reading post-trade storage; weighted `LiquidityLib.join` rebalance branch re-snapshotting after `swap()`; curve `tradeJoinBasket`/`commitJoinTrades`).
- Under the parent's chosen literal reading of FS-HOOK-07 ("snapshot every booked component and the actual supply before crediting incoming assets; the incoming caller's assets must not enter the incumbent snapshot"), those paths required correction. Current-tree verification:
  - Orbital: `_joinBook()` pre-intake snapshot struct threaded through `_quoteJoin`/`_assembleJoin`/`_acceptJoin` (`orbital/...Common.sol:836-985`); `_tradePartialBasket`/`_needsBasketTrades` deleted.
  - Dual: `_joinComponents` (`dual/...Common.sol:369-401`) snapshots x/y pre-intake and reverts `InsufficientLpOut` when a zero-amount leg faces a nonzero incumbent book ("A missing leg cannot be manufactured by trading against the incumbent book"); `_executeZapSwap` removed from the join path.
  - CP-single: `singleComponentJoin` (`constantProduct/single/...ClaimLib.sol:291-320`) snapshots `componentBook()` pre-intake; `_singleInput` places the caller's asset on its own component; SE-only conversion via `_assemble`; acceptance against the pre-intake book.
  - Weighted: `join` (`weighted/...LiquidityLib.sol:235-274`) — `_rebalance`/`_swapPreview` trade branches removed; single snapshot `old`; `rebalance` now only feeds the `_joinBound` ratio guard.
  - Curve: `_joinComponents` (`stable/quad/curve/...JoinCore.sol:85-120`) — `tradeJoinBasket`/`commitJoinTrades` deleted; comment: "Pin every incumbent component before pulling or converting any caller input."
  - Balancer: `_joinBasket` (`stable/quad/balancer/UniswapV4BalancerStableLiquidityUnitsCore.sol:267-287`) was already on the pre-intake model.
- Consequence now visible in current code: single-asset/unbalanced joins on a live book succeed only when every other incumbent component is zero (dual `InsufficientLpOut` guard; CP-single/weighted/curve via `maxComponentMint` limit 0 → revert). That is the literal rule's intended failure mode; tests that expected cross-leg manufacturing are the ones the parent is migrating.
- No further fix path from this audit; parent owns remaining test migration. Recorded as HIGH for traceability because the pre-migration behavior violated a locked requirement.

### MEDIUM

**M-1 — Dual `ownerSwapExactIn`/`ownerSwapExactOut` have no owner gate.**
- `dual/...SeTarget.sol:134-177`: first checks are `_requireDeadline`/`_requireNonZero`/route classification; no `_onlyHookOwner()`. All four other LP families gate: CP-single `SeTarget.sol:761/789`, orbital `SeTarget.sol:167/191`, weighted `SeTarget.sol:218/241`, curve `SeTarget.sol:197/220`.
- Dual also ships no MultiStepOwnable facet at all (`dual/...DFPkg.sol` `facetAddresses()` has no ownable facet; `calcSalt` has no owner field), unlike CP-single (`MULTI_STEP_OWNABLE_FACET` in its DFPkg). So there is no owner to gate on even if the check existed.
- Contract violated: DETF_INSTANCE_IO_ROUTING PRD (§15.12, D30 line 1101): "ownerSwap* is … callable by the hook owner (the DETF) while PoolManager is already unlocked."
- Impact: blunted — the same pair↔pair swap with identical math is already permissionlessly available via `exchangeIn`/`exchangeOut`, so no unique extraction path opens; but the named authorization contract is false, and any integrator/test asserting `NotOwner` for a stranger fails.
- Smallest fix: add the ownable facet + `_onlyHookOwner()` on both functions (sibling parity), or explicitly document permissionless semantics on `IUniswapV4SeBufferHook.ownerSwap*`.

**M-2 — Retired-model code retention (remove-ai-slops/programming perspective).**
- `constantProduct/single/...HookTarget.sol` (~1480 lines) still contains the retired growth-fee machine: `_mintProtocolFeeIfNeeded` (`:1243`), `_setKLastPostOp` (`:1257`), `_supplyAfterProtocolMint` (`:1263`), rated-ratio clamp joins, and ambient-balance books. It is inherited by nothing and deployed nowhere (verified: zero inheritance references under `contracts/` or `test/`); its own header marks it "Legacy monomorph (reference)". FS-HOOK-09 mandates removal of growth-issuance call sites; this file keeps them one inheritance away from resurrection.
- `constantProduct/single/...DepositCommon.sol` retains ~15 uncalled pre-refactor helpers (`_firstMint`, `_firstMintSeShares`, `_laterMintSeShares`, `_refundSeDepositExcess`, `_mintFromDeltas`, `_reservesBeforeDualPull`, `_rawReservesBeforeDualPull`, `_executeZapInSwap`, `_clampAfterZap`, `_previewReserveAfterIntake`, `_previewDelta0/1`, `_previewFirstMintSeShares`, `_previewLaterMintSeShares`, `_feeOnAndShare`, `_supplyAfterProtocolMint*`); verified uncalled anywhere in the family after the ClaimLib kernel migration.
- All six LP Math libs keep uncalled retired-fee wrappers: `calculateProtocolFee` (CP-single Math:132, dual Math:78) and `protocolLpShares` (orbital/weighted/curve/balancer Math); weighted `ClaimLib.previewBufferClaimIn` has no callers.
- Impact: no deployed-bytecode effect (compiler eliminates unreferenced internals); the cost is source-level confusion and a live footgun (the legacy Target contradicts the locked fee model).
- Smallest fix: delete the legacy Target file and the uncalled helpers, or move the reference copy out of the compile set.

**M-3 — Curve DFPkg omits `IUniswapV4SeBufferHook` and `IDetfReserveQuote` from ERC-165 registration while fully implementing both.**
- `stable/quad/curve/...DFPkg.sol:146-160`: 12-entry `facetInterfaces()` has neither id. All five `IDetfReserveQuote` selectors ARE installed (HooksFacet: `previewSwapAfterExchange`, `previewBondAfterDeposit`; LiquidityFacetExt: `previewSynthetic`, `previewJoinAfterDeposit`; ExitFacet: `previewBurnToToken`), and the SeBufferHook join/exit ABI is installed.
- Impact: the proxy answers `supportsInterface(...) == false` for interfaces it fully serves — under-advertisement. ERC-165-gated DETF discovery skips a curve hook that would work. The other LP families (CP-single, dual, orbital, weighted) register both ids.
- Smallest fix: add the two interface ids to `facetInterfaces()` (resize to 14).

### LOW

- **L-1 — CP-single exact-net preview/execution parity gap.** `previewJoinSingleAssetExactOut` returns 0 unconditionally, with a dead `_isLive()` guard before the constant return (`constantProduct/single/...DepositPreviewTarget.sol:55-62`), while `joinSingleAssetExactOut` executes via `grossForNet` + max-pull/refund (`:64-78`); `previewExitSingleAssetExactTokenOut` returns 0 (`WithdrawTarget.sol:452-455`) while execution burns `sharesInMax` with a min-out check (`:438-450`). `LiquidityRoute.previewOut` therefore reverts `ExchangeOutNotAvailable` on routes the direct facades support. Fix: wire previews to the component kernel, or make the preview's unsupported status explicit and consistent (dual's pattern: both revert/return 0).
- **L-2 — Fee-activation boundary diverges at usageFee == 1e18.** Orbital `netMint` (`orbital/...ClaimLib.sol:112-117`) and Balancer `_feeOnAndShare` (`balancer/...Target.sol:387-395`, including the restored `ownerFeeShare != 0` term — parent's intended policy, not flagged) treat a 100% configured fee as inactive; CP-single/dual (`dexSwapFeeAndFeeToOfVault`, active at `fee != 0`) and weighted (`feeSplit`, `percentage != 0`) treat 100% as active (entire gross to feeTo, net 0). Pathological-config-only divergence; recommend one documented family rule.
- **L-3 — Full-share-book exact-out boundary differs per family.** Dual reverts at `shares >= book` (`dual/...Common.sol:458-475`, `ClaimLib.outputAt`), CP-single allows `== book` (`takeExactPair`, `...ClaimLib.sol`), weighted allows `==` on share legs but reverts `>=` on raw legs (`WouldZeroReserve`), orbital reserves 1 wei (`_spendableSeShares`, `orbital/...Common.sol:544-547`). Dust-boundary policy inconsistency only.
- **L-4 — Orbital `_acceptJoin` interleaves per-leg refund transfers with book writes, before the LP mints** (`orbital/...Common.sol:938-985`). Safe today (nonReentrant + plain ERC20, atomic tx), but it deviates from the books→mints→refunds ordering the other five LP families use; a two-phase loop would make the invariant uniform.
- **L-5 — Balancer registers neither `IUniswapV4SeBufferHook` nor `IDetfReserveQuote` and installs no `IDetfReserveQuote` selectors** (registers `IUnits` instead, `balancer/...DFPkg.sol:152`). Internally consistent; noted only because DETF_INSTANCE_IO_ROUTING marks Balancer I/O as later work. Informational.

## Verified clean against current tree (so the parent does not re-audit)

- **Books updated exactly once per facade.** Swap paths: dual `_executePlannedSwap` (`_bufferPool` once on the input leg, `_unwrapPlanned`/`_unwrapExactOut` once on the output leg); CP-single `_swapExchangeIn`/`_swapExchangeOut`/`_execExactIn`/`_execExactOut`/`ownerSwap*` (raw-in: `bookedRaw +=`; pair-in: `bufferPoolPair` once; output: `unwrapQuoted`/`takeExactPair` once — parent's fix confirmed coherent); orbital `_swapExactIn/OutExecute` + `_finishSwap`; weighted `_hookBeforeSwap` (pay output first, buffer input last, each once); curve `_swapExchangeIn`/`_swapExchangeOut`; Balancer Target swap block; H1 wrap/unwrap (retained-custody books only, no LP). SE/SY/Permit2 aliases all funnel into the same kernels (SY `deposit`/`redeem`→`_exchangeIn`→`_joinLiquidityExactIn`/`_exitLiquidityExactIn`; Permit2 deposits differ only in the pull).
- **Commit ordering.** CP-single `_commitBasket`, dual `_joinComponents`, weighted `join`: books → mints → refunds. Curve `_joinComponents` and Balancer `_joinBasket`: mints → books+refunds (no callback surface in between; atomic). Genesis floor minted exactly once to `address(0)` via `ERC20Repo._mint`, which writes `balanceOf`/`totalSupply` directly with no zero-receiver revert (verified `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:329-334`).
- **Genesis (FS-HOOK-10).** All six LP families reject pair-token input on SE-backed legs at supply == 0 (dual/orbital/weighted/curve/balancer explicitly; CP-single via `_assemble` genesis branch). 5% = `supplied/20` floored with zero-redemption and zero-local-receipt rejection; redemption-refund rejection (`bootstrapReceipt`/`requireReceipt` balance reconciliation). Seed functions are rate-free (retained-share/raw coordinates) and exclude the floor exactly once (dual `genesisGross`, curve `firstMintShares` :390-394, Balancer `firstMintShares`, weighted `firstMintSharesFull/Partial` :246-265, CP-single `_accepted` genesis branch).
- **Fee split (FS-HOOK-09).** All LP families split the backed gross via `Components.splitMintFee` with family-preserved sources (H2/H3 `dexSwapFeeAndFeeToOfVault`; H4-H7 `feeTo()`+`usageFeeOfVault`); previews use net; exact-net uses `grossForNet` with the 100%-fee divide-by-zero pre-empted by the `maximumNet_` feasibility check. No production caller of the retired growth mint remains (sole caller is the undeployed legacy Target — see M-2).
- **Membership/disable (FS-OWN-35, FS-A40).** All seven DFPkgs validate `pairToken ∈ se.vaultTokens()` via `LegLib.pairInVaultTokens` (no `asset()` call/probe anywhere under `contracts/hooks/`). All seven wire the deployment registry as the disable authority (dual `disableRegistry`, curve via `VaultRegistryAwareRepo`, others `vaultRegistry`); unknown/unregistered SEs fail closed (`UnknownLeg`/`BufferFailed`/`InvalidRoute`).
- **Fail-closed exact-output against FullSpread legs is by design.** FullSpread installs no transition/context/quantity quote interfaces (PRD §1.4 note at line 288) and `previewExchangeOut` returns 0 (FS-HOOK-03), so hook exact-out SE conversions (dual `_outputExactOut`, CP-single `takeExactPair`, orbital `_exactOutputDebit`, weighted `unwrapExactTokenOut`, H1 `_wrapExactOut`/`_unwrapExactOut`) revert `ExchangeOutNotAvailable`. This is the intended rejection — and the mechanical source of the H1 `ExchangeOutNotAvailable` failures the parent is investigating: any test expecting exact-out success against a FullSpread leg contradicts FS-HOOK-03.
- **Projected-vs-live state discipline.** `ContextQuoteLib` substitutes a projected quantity quote only when the projected state actually differs and the quantity-quote interface is advertised (`_exactOutputState` + `_requireQuantity`); otherwise it falls back to live previews without fabricating state. PM-context previews (`manager = poolManager`) are deliberate actual-context models; execution paths read live state inside the real unlock context.
- **Exit side is FS-HOOK-08-conformant in all families** (allocate floor(b·B/T) per component against pre-burn supply including floor/fee LP, decrement books, convert only the exiting holder's allocation; share-only exits revert atomically when the local→share conversion is disabled-prohibited).

## Known-unresolved items (parent's tracker; not re-litigated)

- Weighted FullSpread cross-leg preview mismatches (2) — files under `weighted/...ClaimLib.sol` preview paths (`previewSingleExit` vs `singleExit` sequencing) and the row adapters; the two known failing preview comparisons were not re-derived.
- Balancer requested-share positives (2) — `_convertOutputs` share-requested path in `UniswapV4BalancerStableLiquidityUnitsCore.sol`.
- Dual IDetfReserveQuote gap — promoted to H-1 with exact inventory above.

## Reviewed paths

- Shared: `contracts/hooks/uniswap/v4/libs/` (all five), `contracts/hooks/uniswap/v4/interfaces/` (IUniswapV4SeBufferHook, IDetfReserveQuote), `contracts/utils/ExchangeInAmount.sol`, `contracts/utils/LocalCreditLib.sol`, `contracts/vaults/standard/sy/NativeStandardYield{Target,Selectors,PreviewTarget,QuoteBase}.sol`, `contracts/vaults/standard/exchange/StandardExchangeInExecutionBase.sol`, Crane `ERC20Repo._mint`.
- H1 `single/`: Repo, Common, Target, DFPkg (read in full).
- H2 `constantProduct/single/`: Repo, ClaimLib (full), DepositCommon (full), DepositTarget, DepositSingleTarget, DepositPreviewTarget, DepositProjectionTarget, WithdrawTarget, WithdrawalLib, InExecutionBase, InQuoteBase, SeTarget (full), Target (full — legacy), DFPkg, all facets.
- H3 `dual/`: Repo, Common (full), ClaimLib (full), DepositQuoteLib (full), DepositTarget, WithdrawTarget, HooksTarget, SeTarget, InExecutionBase, InQuoteBase, DFPkg, all facets, family interface.
- H4 `orbital/`: Repo, Common (full, both revisions seen in flight), ClaimLib (majority), SeTarget, DFPkg (validation path).
- H5 `weighted/`: LiquidityLib (full), ClaimLib (majority), HooksTarget, SeTarget, JoinCore, ExitCore, DFPkg (validation path).
- H6 `stable/quad/curve/`: ClaimLib (majority), JoinCore (full), SeTarget (full), Target (fee section), DFPkg interface block.
- H7 `stable/quad/balancer/`: LiquidityUnitsCore (full), Target (fee/pull/buffer sections), Math (fee/seed section), DFPkg interface block.
- Test adapters: existence of the seven `*SeMatrixBehavior.sol` contracts + FullSpread rows verified; content-sampled `weighted/...SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` (substantive: real fixture, preview/execution parity, local-first and gas-ceiling assertions).

## Limits

- Read-only mandate: no forge build/test run; claims rest on source reading of the current tree, which was edited by the parent during the audit (orbital/dual/CP-single/weighted/curve all changed mid-read; findings re-verified at report time).
- Test-content sampling: 1 of ~20 new FullSpread row adapters read in depth; the slop pass over tests is partial.
- The two known weighted preview mismatches and two Balancer positives were not root-caused (excluded by mandate).
- `frontend/`, FullSpread vault internals, and the factory/ directory were out of scope.

## Verdict

- `codeQualityStatus`: **BLOCK** (H-1 unresolved in current tree; H-2 corrected in flight and recorded for traceability).
- `recommendation`: **REQUEST_CHANGES** — H-1 (dual ERC-165/selector mismatch) must be fixed or deliberately dispositioned before this work is called complete; M-1..M-3 are strongly recommended before final sign-off.
- Blockers:
  1. H-1: dual advertises `IDetfReserveQuote` while `previewSwapAfterExchange`/`previewJoinAfterDeposit`/`previewBondAfterDeposit` are absent (DFPkg.sol:153 + HooksFacet.sol:28 vs. installed funcs). Fix by implementing the three views or removing the advertisement.
  2. M-1 (recommended, not strictly blocking): dual `ownerSwapExactIn/Out` missing the owner gate that all sibling families and the D30 routing lock specify; dual ships no ownable facet at all.
  3. M-2/M-3 (recommended): delete the retired growth-fee Target/helpers; register `IUniswapV4SeBufferHook`+`IDetfReserveQuote` on the curve DFPkg.
