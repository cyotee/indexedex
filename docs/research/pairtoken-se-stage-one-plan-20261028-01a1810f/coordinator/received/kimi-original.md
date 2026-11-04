# Kimi planning contribution: coordinator archival receipt

Verbatim final response from Native task `st_01a18424`, initial planning assignment. No content corrections were applied in this archive.

---

# Identity

Kimi, independent Native council planning member, requested exact global route `kimi-coding/k3.1-pro:high`.

This is an implementation/testing contribution for the revised Stage One PRD. It does not implement code, alter requirements, or claim measured feasibility.

# Inputs and coverage

I read the complete common brief and all 1,213 lines of the immutable revised `inputs/PRD.md`, including S1-P01–P06, S1-X01–X19, the exact issuance/exit equations, conditional fallback, native adaptation, projection requirements, and S1-A01–A70.

Within the admitted source scope, I also inspected:

- Repository coding, deployment, artifact-build, and testing rules.
- Canonical Crane architecture/deployment/testing guidance and IndexedEx testing law.
- `PairToken.sol`, `PairTokenMath.sol`, and the baseline dependency interface.
- The existing baseline `PairTokenTestBase.sol` and `ScriptedDependencies.sol`.
- The Wings package, family Repo, component FactoryService, interfaces, and real-manager TestBase, strictly for packaging/fixture patterns.
- The five shared facets’ initialization paths through `ERC20Repo`, `EIP712Repo`, `MultiAssetBasicVaultRepo`, and `StandardVaultRepo`.
- Native SY execution/discovery/preview bases, `StandardExchangeInExecutionBase`, SE In/Out interfaces, and `LocalCreditLib`.
- Canonical V4 state, position, tick, swap, price, protocol-fee, transient-state, and full-precision arithmetic libraries.

The plan below preserves the settled product choices. All new-family paths are **proposed**, not representations that implementation already exists. No files were written and no builds, tests, Git commands, deployment commands, or external research were run.

# File/component map

## 1. Canonical reuse

| Existing component | Required use |
|---|---|
| `lib/crane/contracts/tokens/ERC20/ERC20Facet.sol` | Install unchanged for the nine ERC-20/metadata selectors. Initialize share name, symbol, and 18 decimals through `ERC20Repo`. |
| `lib/crane/contracts/tokens/ERC2612/ERC2612Facet.sol` | Install unchanged for `permit`, `nonces`, and `DOMAIN_SEPARATOR`; use canonical nonce storage. |
| `lib/crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol` | Install unchanged for `eip712Domain`. |
| `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol` | Install unchanged for booked local reserve discovery. Do not make it a live whole-basket valuation view. |
| `contracts/vaults/standard/MultiAssetStandardVaultFacet.sol` | Install unchanged for standard vault discovery; use zero fee-type IDs and deduplicated package-owned vault types. |
| `NativeStandardYieldMoneyTarget`, discovery/preview/reward targets, `NativeStandardYieldQuoteBase`, `StandardExchangeInExecutionBase` | Reuse the shared SY and SE seams. Override only the family’s native-payment, route, discovery, preview, and vault-held redemption behavior. Do not change shared SY policy for other families. |
| `LocalCreditLib` | Contract-only pretransfer validation and unbooked-credit availability/budget calculations. |
| `IWETH` canonical interface and bound wrapped-native deployment | I/O adaptation only; no wrapper exchange-rate economics. |
| `StateLibrary`, `TransientStateLibrary`, `PoolIdLibrary`, `Position`, `TickMath`, `SqrtPriceMath`, `SwapMath`, `LiquidityAmounts`, `LiquidityMath`, `ProtocolFeeLibrary`, `LPFeeLibrary`, `FullMath` | Canonical V4 state access and arithmetic. Do not reproduce raw PoolManager offsets independently where `StateLibrary` exposes the read. |
| Wings DFPkg/TestBase | Copy only lifecycle, artifact-loading, CREATE3, registry deployment, and declaration-test patterns. Reuse no Wings economic execution or storage. |
| Baseline PairToken sources and harness | Characterization and preserved/deviation ledger only. Do not import the baseline’s ordinary storage, factory fee configuration, dead shares, retention, or protocol-fee behavior. |

The package-owned reused surface is exactly the specified 20 selectors. Do not install `ERC20PermitFacet`, duplicate SY-inherited token selectors, or include factory-provided ERC-165/loupe/ERC-8109/post-deploy components in package inputs or cuts.

## 2. Proposed production directory

Root:

`contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/`

### Interfaces and storage

- `interfaces/IUniswapV4PairTokenStandardExchangeVault.sol`
  - Exact family ABI from S1-API-05.
  - `WithdrawalMode` and `MaintenanceReason`.
  - Family events, including `ZapCredit` and `WithdrawalMaintenanceSelected`.
  - Family errors and paired-operation/donation/compound events.
  - Document that `exchangeRate` is spot-marked accounting value, not withdrawal-and-sale proceeds.
- `interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol`
  - `PkgInit` and `PkgArgs` on the interface.
  - `PkgInit`: real shared/family facet array, PoolManager, registry, fee-oracle query reference, wrapped-native binding, and any actually used canonical infrastructure dependency.
  - `PkgArgs`: `PoolKey`, `rateAsset`, share name/symbol, `maxZapBps`, `maxZapTickMove`.
  - Package lifecycle errors and `bindingHash`.
- `UniswapV4PairTokenStandardExchangeVaultRepo.sol`
  - Family-specific ERC1967-form namespace, distinct from Wings and shared Repos.
  - Immutable-after-init configuration: manager, key/pool ID, full-range ticks, registry, wrapped native, rate asset and cached decimals, zap bounds.
  - `busy`, active operation kind, one-time callback commitment, and plan/phase invalidation state.
  - Booked idle `B0/B1`.
  - Pending caller inventory, exit allocations, and refunds in actual pool-currency order.
  - No stored “unbooked donation” category; unbooked excess is derived from custody minus every accounted category.
  - No second share supply, operational owner, fee manager, strategy setter, or rescue state.

### Arithmetic, projection, and execution libraries

- `UniswapV4PairTokenStandardExchangeVaultMath.sol`
  - Checked genesis product and square root.
  - Full-precision floor/ceiling issuance and proportional-exit calculations.
  - Clamped full-range principal/addition-cost wrappers using canonical V4 math.
  - Attributable `G_i`, paired `C_i = G_i + J_i`, zap `C_i = G_i`, and final `qCredit`.
  - Exact single-floor SY rational conversion using the multiword approach below.
- `UniswapV4PairTokenStandardExchangeVaultProjectionLib.sol`
  - Memory-only pool, tick, bitmap, position, fee, and categorized-inventory overlays.
  - Exact swap-loop and liquidity-transition projection.
  - Per-candidate step accounting and typed economic-domain failures.
- `UniswapV4PairTokenStandardExchangeVaultPlanLib.sol`
  - Shared entry, compound, paired exit, and single-token exit planner.
  - Full/CollectOnly candidate selection and immutable phase commitments.
  - One economic model called by both execution and views.
- `UniswapV4PairTokenStandardExchangeVaultOperationLib.sol`
  - Ledger transitions, callback payload commitments, actual-delta settlement, receipt checks, native sync/settle/take, wrapping adaptation, and final shared-Repo publication.
  - Internal calls only; no public proxy self-calls that change `msg.sender`.

### Targets and facets

Start with four family facets to avoid duplicating the large planner across many small route facets:

- `UniswapV4PairTokenStandardExchangeVaultExecutionTarget.sol` and `...ExecutionFacet.sol`
  - Paired deposit/redemption, SE `exchangeIn`, SY deposit/redeem, donation, compound, SY non-view reward methods.
  - Shared operation guard and internal execution engine.
- `UniswapV4PairTokenStandardExchangeVaultQueryTarget.sol` and `...QueryFacet.sol`
  - Family configuration, position/book/basket queries.
  - Paired, SE, and SY previews; withdrawal-mode and zap-credit previews.
  - SY discovery/rate/reward views.
- `UniswapV4PairTokenStandardExchangeVaultOutTarget.sol` and `...OutFacet.sol`
  - Both `IStandardExchangeOut` selectors, immediately reverting `ExchangeOutNotAvailable()`.
- `UniswapV4PairTokenStandardExchangeVaultCallbackTarget.sol` and `...CallbackFacet.sol`
  - Authenticated `unlockCallback` only; no public money-entry route.

If runtime measurements require it, split Query into Discovery/Preview and Execution into Paired/Route facets while retaining the same internal engine. Do not solve size with `via_ir`, omitted selectors, or a reduced economic model.

### Package and deployment support

- `UniswapV4PairTokenStandardExchangeVaultDFPkg.sol`
  - Canonical `IDiamondFactoryPackage` and `IStandardVaultPkg` lifecycle.
  - Registry-only `processArgs`, deterministic `calcSalt`, validation, `initAccount`, inert `postDeploy`, and no mutable package configuration.
- `UniswapV4PairTokenStandardExchangeVaultComponent_FactoryService.sol`
  - CREATE3/artifact-first deployment of each family facet.
  - Deterministic labels/salts; no `new` facets or packages.
- `test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol`
  - `CraneTest -> IndexedexTest -> family TestBase`.
  - Real PoolManager, registry, manager, facets, package, and diamond deployment.

### Initialization ownership

`initAccount` executes once in the diamond delegatecall context and performs, in order:

1. Reject direct package-context invocation and reinitialization.
2. Validate manager, registry, facets, wrapper, pool, hookless/static-fee configuration, initialized price, rate asset, faces, and zap bounds.
3. Store family configuration and compute full-range ticks with `TickMath.minUsableTick/maxUsableTick`.
4. Initialize `MultiAssetBasicVaultRepo` with `[C0,C1]` in PoolKey face order and zero booked reserves.
5. Compute `contentsId` from an address-sorted copy of the faces without reordering stored token/reserve arrays.
6. Initialize `StandardVaultRepo` with the bound oracle, zero fee-type IDs, deduplicated package-owned types, and that contents ID.
7. Initialize `ERC20Repo` with configured metadata and 18 decimals, zero supply.
8. Initialize `EIP712Repo` with the same name and version `"1"`.

No facet initializes itself. Factory-owned introspection and temporary-hook state remain factory-owned.

# Implementation stages

## WP0 — Declaration manifest and comparison ledger

**Prerequisites:** None.

**Actions:**

- Create a Target/product-interface-derived selector manifest covering:
  - The 20 reused selectors.
  - All family ABI methods.
  - Both SE In/Out interfaces.
  - All 16 SY methods.
  - Factory-owned persistent selectors separately from package cuts.
- Record selector → interface → Target → Facet → Repo ownership.
- Start the baseline comparison ledger with `preserved`, `intentional deviation`, `unsupported scope`, and `new capability`.
- Pin canonical NatSpec values through the repository workflow rather than handwritten constants.

**Exit evidence:** A06/A56/A57/A68 declaration controls exist before economic code, and no factory-owned selector appears in package-owned cuts.

## WP1 — Repo, validation, package, and shared-facet initialization

**Prerequisites:** WP0.

**Actions:**

- Implement family Repo and DFPkg lifecycle.
- Deploy real shared and family facets using artifact-first CREATE3 helpers.
- Validate ordered currencies, native/wrapped face mapping, nonzero currency1, deployed token code, no self-reference, static fee, legal tick spacing, hookless initialized pool, distinct faces, wrapper/rate-asset membership, and zap limits.
- Include all economically relevant instance arguments in `calcSalt`; include package bindings in package deployment identity.
- Implement registry discovery and disabled-vault checks without blocking exits or standalone compound.

**Exit evidence:** A01–A07, A56–A58, A68–A69 pass on real registered diamonds before money operations are enabled.

## WP2 — Arithmetic and memory projector, before money execution

**Prerequisites:** WP1 configuration types.

### Memory overlay

Use a candidate-local overlay containing:

- `slot0`, active liquidity, and both global fee-growth words.
- Lazy-loaded tick overlays: gross/net liquidity and both fee-growth-outside words.
- Lazy-loaded tick-bitmap word overlays.
- The diamond-owned position overlay: owned liquidity and both checkpoints.
- Booked/pending/exit/refund inventories.
- Candidate step counter and typed failure stage.

Load initial state through `StateLibrary`; copy-on-write only into memory. No quote-only storage mutation, manager unlock, callback simulation, or state override.

### Exact transitions

- For each swap iteration, including zero-liquidity and uninitialized-word progress:
  1. Increment the shared candidate counter.
  2. Read the next initialized tick using canonical bitmap compression/position rules against the overlay.
  3. Use `SwapMath.computeSwapStep` with the current LP and directional protocol fee.
  4. Apply protocol-fee deduction and LP global growth exactly as `Pool.swap`.
  5. Cross initialized ticks with modular fee-growth-outside updates and signed active-liquidity transitions.
  6. Commit the projected price, tick, active liquidity, and global growth to the overlay.
- Step 512 is valid. Requiring step 513 terminates that candidate with `QuoteWorkExceeded(513,512)` or a classified maintenance-work failure.
- For liquidity modifications, reproduce canonical tick initialization/clearing, bitmap flips, gross-capacity checks, active-liquidity changes, position updates, and principal amounts.
- Compute fees as `FullMath.mulDiv(feeGrowthInside - checkpoint, ownedLiquidity, Q128)` using modular subtraction. Never use active pool liquidity as the owned position’s liquidity.
- Keep `callerDelta`, `feesAccrued`, and principal distinct:
  - Addition principal cost is derived from the signed principal delta, not the combined caller delta.
  - Removal principal is `callerDelta - feesAccrued`.
  - A zero-liquidity collection updates checkpoints and books only fees.
  - Never poke an empty position.
- Later swaps and collections see every earlier overlay change.

### Candidate isolation and invalidation

- Entry and standalone compound run one full-compound candidate.
- Withdrawal runs full first; only a listed maintenance-stage failure may start a fresh collection-only candidate from the original snapshot.
- A failed candidate’s overlay is discarded in full. Worst-case planning is 1,024 steps.
- Produce a plan containing selected mode/reason, expected amounts/deltas, touched-state commitments, and phase commitments.
- Execution checks the initial and subsequent commitments after token/wrapper interactions and before each manager phase. Any unexpected price, liquidity, fee, checkpoint, or touched-tick change reverts `EconomicStateChanged()`; execution never replans or changes mode mid-operation.

**Exit evidence:** A27–A28, A45, A61–A63, and A67 projector differential tests match real manager receipts and failures before route integration.

## WP3 — Operation ledger, callback authentication, settlement, and compound

**Prerequisites:** WP2.

### Ledger rules

Track every actual pool-currency unit as exactly one of:

- Incumbent booked idle.
- Pending caller inventory.
- Reserved exit allocation.
- Reserved refund.
- Unbooked excess.

The shared basic-vault Repo is only a published snapshot of booked idle, not an additional category. During temporary wrapping, the wrapped representation replaces the corresponding native reservation; it never creates another asset.

Required transitions:

- Pull/pretransfer increases only pending caller inventory by exact authorized receipt.
- Collection increases booked idle by realized fees once.
- Compound spends only booked idle; entry swaps/additions spend only pending caller inventory; exit sales spend only exit allocation.
- Entry mint merges accepted principal/residual into book only after final credit is computed.
- Exit allocation debits booked idle before external payout and removes burned holders from subsequent fee ownership.
- Final external payouts/refunds consume their reservations. Stable boundaries have zero reservations.
- Publish both shared reserve values after external interactions, then clear the operation and guard.

### Callback and settlement

- Check `TransientStateLibrary.isUnlocked` before unlock; revert `ManagerAlreadyUnlocked()` without nested execution.
- Commit `keccak256(abi.encode(operation,payload))` before each unlock and consume it once at callback entry.
- Authenticate manager, active operation, expected kind, and commitment. Hold the cross-facet guard through payout/refund.
- For native debt, always `sync(native)` immediately before `settle{value: exactDebt}()`, even after an ERC-20 sync. Validate paid amount and use `take` for native credits.
- Close actual manager deltas to zero and reconcile observed receipts with the operation ledger.

### Compound engine

Implement one engine for explicit and mandatory compound:

1. Collect all position fees if nonempty.
2. Retain all fees; no external fee-manager call.
3. If either eligible idle balance exceeds raw-unit `DUST=1000`, compute baseline affordable addition and leftovers.
4. Preserve sequential-floor token0-to-token1 leftover comparison and token0 tie direction.
5. Swap half the selected leftover, capped by active-pool reserve estimate × `maxZapBps / 10000 / 4`.
6. Preserve zero-active-liquidity and small-leftover no-swap branches.
7. Add affordable liquidity from incumbent book only; leave residuals booked.
8. Perform the final nonrecursive fee checkpoint.
9. Return total fees realized across checkpoints once; never change share supply.

The clean all-zero state is a successful no-op.

**Exit evidence:** A22–A24, A39–A41, A51, A59–A60, and the ledger portions of A65–A67 pass.

## WP4 — Paired genesis/entry and proportional/terminal exits

**Prerequisites:** WP3.

### Paired entry

After mandatory maintenance and final fee checkpoint:

- Freeze `S`, `P*`, `L`, and booked `B_i`; compute `R_i=N_i(P*,L)+B_i`.
- Compute `qQuote` and accepted amounts exactly from S1-ACC-02.
- Genesis requires positive both inputs, checked product, positive `q`, and positive fundable addition; mint all `q` to recipient.
- Positive supply with both reserves zero reverts `InvalidAccountingState()`.
- Pull only accepted ERC-20 amounts. Reserve native maximum before compound and refund only the unused native maximum.
- Add `dL` using pending caller inventory only.
- Compute `G_i=N_i(P*,L+dL)-N_i(P*,L)` and residual `J_i`.
- Use `C_i=G_i+J_i`, `qCredit=min floor(S*C_i/R_i)`, and final `q=min(qQuote,qCredit)`.
- Do not rerun accepted-input selection after the final cap.
- Enforce the minimum against final `q`, mint, merge accepted residuals, refund, and publish.

### Paired exit

After selected maintenance and final checkpoint:

- Snapshot `S,L,B0,B1`.
- Burn `s` before removal.
- Compute `floor(L*s/S)` and `floor(B_i*s/S)`.
- Allocate actual removal principal plus idle allocations, excluding fee components already checkpointed.
- Revert if later state/fee growth invalidates the plan.
- Reject zero total actual payout; allow a positive one-sided payout.
- For `s==S`, remove all owned liquidity and pay every booked/terminal-generated receipt. Unbooked assets remain excluded.
- Rebootstrap only through paired genesis.

**Exit evidence:** A08–A12, A16–A17, A20, A41, A43, A45–A46, A64–A66.

## WP5 — Zap entry, single-token exit, and typed fallback

**Prerequisites:** WP4.

### Zap entry

- Require positive supply and both pre-entry-swap reserves positive.
- Apply the size cap to the pre-entry-swap input reserve.
- Isolate exact received input outside incumbent book.
- Swap `floor(received/2)` from pending inventory, allowing partial fill.
- Apply `maxZapTickMove` only around that swap.
- Collect entry-swap fees to incumbents without another ratio swap.
- Freeze the post-swap `P*,L,B`.
- Add only caller inventory and mint solely from `G_i`.
- Book `J_i` as uncredited residual and expose it in preview/event.
- Never use SY exchange rate in issuance.

### Single-token exit

- Reserve the exiter’s principal/idle allocation.
- Disable re-addition for the exit sale.
- Sell the entire unwanted allocation against remaining pool liquidity.
- Require full consumption and final minimum; otherwise revert the entire transaction.
- Keep sale-generated fees with remaining liquidity.
- Terminal single-token exit requires external remaining liquidity.

### Fallback classifier

Return typed planner failures with a stage tag; do not catch external exceptions.

- `MaintenanceWorkLimit`: only maintenance needs step 513 and a fresh CollectOnly candidate fully plans.
- `MaintenancePriceLimit`: planned nonzero maintenance ratio swap has no legal directional interval at the current boundary.
- `MaintenanceLiquidityLimit`: maintenance addition violates owned signed-liquidity, per-tick gross capacity, or manager principal-delta limits.
- `MaintenanceDeltaLimit`: maintenance swap quantity or settlement delta exceeds supported types.

For the last three, recompute CollectOnly from original state. A valid full candidate always wins. Invalid accounting, custody shortfall, collection failure, actual manager/token/wrapper/payout failure, minima failure, and final-sale failure do not trigger fallback. Emit the selected mode/reason once on every successful withdrawal.

**Exit evidence:** A13–A15, A18–A21, A28, A61–A64, A67.

## WP6 — SE, SY, native adaptation, pretransfer, and donation

**Prerequisites:** WP5 economic engine.

- Implement only the four exact-input SE routes.
- Reject currency/currency, V/V, identical, unrelated, and raw-zero standard SE routes.
- Both exact-output methods revert before guard, transfer, mint/burn, or manager mutation.
- Override family SY native deposit to reserve exact `msg.value`; route internally rather than calling nonpayable SE selectors.
- Reuse `_standardRoute` and `_redeemVaultHeld` for caller/vault-held share authority and canonical events.
- Unsupported SY previews return zero; valid-token economic failures remain failures.
- Native pools expose `[address(0),C0,C1]`; ERC-20-only pools expose `[C0,C1]`.
- Native and wrapped forms use the same economic plan; only delivery representation differs.
- False-flag pulls require observed receipt exactly equal to authorized amount.
- True-flag routes require contract callers and sufficient available unbooked credit, reserve only the declaration, and never refund excess.
- `donate` requires positive supply/amount and credits only same-call observed receipt. Native and wrapped-alias donation credit the native reserve once. Wrapped native in an ERC-20-only pool remains an ordinary ERC-20.
- Registry disable rejects paired/SE/SY entry and donation but not compound or exits.

**Exit evidence:** A25–A26, A29–A38, A42–A44, A49–A55, A63, A65–A66.

## WP7 — Exact SY accounting rate

**Prerequisites:** WP2 math and WP6 SY discovery.

For each leg compute:

`A_i = N_i(P,L) + B_i + F_i`

where `F_i` is current claimable fee from canonical fee-growth-inside minus the position checkpoint. Do not simulate compounding or include pending/unbooked/reserved assets.

### Single-floor token1-denominated value

Compute:

`X = floor(A0 * P^2 / 2^192)`

using exact 64-bit-limb multiplication:

- Represent `A0` as four limbs and `P` as three limbs.
- Triple-convolve `A0 × P × P` into ten limbs. A column has at most nine 128-bit products plus carry, so accumulation fits comfortably in 256 bits.
- Dividing by `2^192` is exactly dropping limbs 0–2; this is the sole floor.
- Require limbs 7–9 to be zero, then compose limbs 3–6 as the 256-bit `X`; otherwise the conversion is unrepresentable and reverts.
- Return checked `A1 + X`.

This never forms an overflowing Solidity `A0 * P * P` intermediate and does not use sequential floors.

### Single-floor token0-denominated value

Compute:

`Y = floor(A1 * 2^192 / P^2)`

- Form exact `P^2` in 64-bit limbs.
- Form the shifted numerator as a limb array, not a Solidity overflowing shift/product.
- Use normalized multiword Knuth-style long division to produce the exact integer quotient and discard the remainder only at that final division.
- Reject a quotient exceeding four limbs, then return checked `A0 + Y`.

### Final share rate

- Zero supply returns zero.
- Otherwise use canonical `FullMath.mulDiv(Vraw,1e18,S)`, reverting if the final value is unrepresentable.
- Do not normalize by asset decimals; cached decimals are metadata only.

**Exit evidence:** A32–A33, including arbitrary-precision controls and vectors where two sequential floors differ from the required result.

## WP8 — Hardening, invariants, size, and release evidence

**Prerequisites:** WP1–WP7.

- Complete proxy surface, read-reentrancy, native receiver, multi-instance, terminal, and disabled-registry matrices.
- Add bounded fuzz/invariant handlers and independent arithmetic controls.
- Measure every facet’s deployed runtime size and worst-case preview/execution gas.
- Split facets further if necessary without changing economics.
- Publish the final selector manifest, comparison ledger, A01–A70 evidence, commands, gas/size results, and remaining limits.

**Exit evidence:** Every acceptance row has passing real-surface evidence; A48/A61/A70 have explicit feasibility evidence rather than assumptions.

# Testing plan and A01-A70 matrix

## 1. Production-first fixtures

The family TestBase must deploy:

- Real `PoolManager` from freshly built artifacts.
- Real canonical shared facets and new family facets through CREATE3.
- The real package through `indexedexManager.deployPkg`, then instances through registry `deployVault`.
- Real registry/manager/fee-oracle infrastructure from `IndexedexTest`.
- Canonical wrapped native for native pools.
- Mintable non-SUT ERC-20 harnesses with 6/8/18 decimals and controllable short-delivery, FoT, callback, and rejecting behavior where negative tests require them.

Pool fixtures must cover:

- ERC-20/ERC-20 and native/ERC-20.
- Zero and nonzero LP fee; nonzero directional protocol fees.
- Interior, exact lower/upper boundaries, and outside-range positions.
- Initialized crossings and empty bitmap words.
- External liquidity providers for terminal single-token exits.
- Work-limit pools constructed through genuine positions/ticks, not SUT storage injection.
- Wrapper address sorting after the other ERC-20 face for contents-ID testing.

Use actual public operations to establish pool state. Never subclass, etch, or inject storage into the diamond SUT. Non-SUT harness contracts may implement rejecting/reentrant receivers, construction-time pretransfer callers, contract credit callers, and short-delivery tokens.

Keep baseline characterization separate and reuse the existing baseline harness unchanged. Baseline comparisons use fresh real PairToken instances and cannot replace new-family real-manager acceptance.

## 2. Independent controls and invariant handlers

- Add an independent arbitrary-precision test oracle, using Python integers/fractions or an equivalent non-SUT implementation, for:
  - `qQuote`, accepted amounts, `G_i`, `J_i`, `C_i`, and final `q`.
  - Proportional removal and idle allocations.
  - SY rational valuation and final raw-unit rate.
  - Vectors where two sequential floors differ from single-floor conversion.
- Treat real PoolManager receipts as the principal/cost authority; do not use baseline arithmetic as authority where the PRD changes behavior.
- Use canonical `Behavior_IFacet` and `Behavior_IDiamondFactoryPackage`; add family Behaviors only for family-specific declarations.
- Use snapshot/revert parity tests: preview, execute from the identical state, and compare exact amounts, events, and final state.
- Handlers operate only through public routes with bounded valid domains:
  - Paired genesis/deposit, both zap directions, donation, compound, paired/single exits, native/wrapped variants.
  - Track supply as sum of holder balances, zero dead supply, exact custody categories, zero stable reservations, and independent per-entry non-dilution.
  - Record external price/fee effects and zap residual donations separately from ownership failures.
- Leave configured fuzz/invariant depths unchanged. No fixed sleeps or timing-dependent assertions.

## 3. Proposed suite abbreviations

- `PKG`: `UniswapV4PairTokenStandardExchangeVaultPackage.t.sol`
- `SURF`: `...ProxySurface.t.sol`
- `ENTRY`: `...Entry.t.sol`
- `EXIT`: `...Exit.t.sol`
- `COMP`: `...Compound.t.sol`
- `ROUTE`: `...StandardExchange.t.sol`
- `PROJ`: `...Projection.t.sol`
- `SY`: `...StandardizedYield.t.sol`
- `CREDIT`: `...CreditDonation.t.sol`
- `SEC`: `...Security.t.sol`
- `ACCT`: `...AccountingSequences.t.sol` and invariant suites
- `NATIVE`: `...Native.t.sol`
- `MATH`: `...Math.t.sol` plus independent oracle
- `GAS`: `...Feasibility.t.sol`

All paths are under proposed:

`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken/`

## 4. Complete acceptance mapping

| ID | Proposed suite/case and required assertion |
|---|---|
| S1-A01 | `PKG.test_A01_registryDiscovery`: deploy ERC-20 and native instances through registry; assert discovery by both declared faces and types, including wrapped-native face. |
| S1-A02 | `PKG.test_A02_deterministicIdentity`: identical init/args predict identical addresses; mutate every `PkgArgs` field and each package binding and assert the intended identity change. |
| S1-A03 | `PKG.test_A03_configurationValidation`: table every invalid key/hook/fee/spacing/price/rate/zap/wrapper/face/self-reference case and exact revert; valid native and ERC-20 pools deploy. |
| S1-A04 | `PKG.test_A04_lifecycleMisuse`: direct package init, second initialization, non-registry processing, and zero/codeless/invalid facets reject without partial initialization. |
| S1-A05 | `SURF.test_A05_tokenAndDomain`: exact metadata/18 decimals; permit verifies against diamond/current chain; domains and nonces isolate two instances. |
| S1-A06 | `SURF.test_A06_targetFacetCutProxyMatrix`: Behavior controls derived from Targets equal facet declarations/cuts; every package selector is callable; final loupe equals package ∪ factory, disjointly. |
| S1-A07 | `SURF.test_A07_vaultDiscovery`: exact token order, zero fee IDs, contents/types/config; local reserves exclude deployed principal and unbooked balances while `basket` includes principal plus booked idle. |
| S1-A08 | `ENTRY.test_A08_genesis`: independently compute `floor(sqrt(a0*a1))`; recipient/supply receive all shares, with no dead or virtual balance. |
| S1-A09 | `ENTRY.test_A09_genesisRejections`: zero input/mint/liquidity, product overflow, and final-share minimum each revert with no manager/token/supply changes. |
| S1-A10 | `ENTRY.test_A10_candidateAndFinalCredit`: assert limiting ratio, ceiling accepted inputs, final `min(qQuote,qCredit)`, ERC-20 unused maxima retention, and exact native refund. |
| S1-A11 | `ENTRY.test_A11_oneSidedAndInvalidReserves`: each one-sided branch consumes only its live leg; positive supply with both reserves zero reverts `InvalidAccountingState`. |
| S1-A12 | `ENTRY.test_A12_preEntryCompoundIsolation`: seed incumbent fees and pending input; fees compound before snapshot while pending native/ERC-20 input remains excluded. |
| S1-A13 | `ENTRY.test_A13_bothZapDirections`: exact half-swap, post-swap checkpoint, caller-only addition, actual `G_i`, and final issuance reconcile with manager state for both directions. |
| S1-A14 | `ENTRY.test_A14_zapBounds`: empty state and zero input reject; cap and tick movement succeed at equality and reject one unit/tick beyond. |
| S1-A15 | `ACCT.testFuzz_A15_nonDilution`: for every positive reserve, independent wide arithmetic proves `q*R_i <= S*C_i`; cover idle imbalance, partial fills, residuals, and addition rounding with zero dilution tolerance. |
| S1-A16 | `EXIT.test_A16_proportionalPairedExit`: exact liquidity/idle floors and actual principal payouts; demonstrate no 10-bp retention. |
| S1-A17 | `EXIT.test_A17_roundingDustAndFees`: residual dust remains in live basket; no duplicate fee allocation or supply mint occurs. |
| S1-A18 | `EXIT.test_A18_singleTokenDirections`: both directions sell exactly the exiter’s unwanted allocation and enforce actual final minima. |
| S1-A19 | `EXIT.test_A19_partialSaleAndCollectOnly`: partial sale fully rolls back; a listed maintenance obstacle permits valid paired CollectOnly exit; unrelated execution failure still reverts. |
| S1-A20 | `EXIT.test_A20_terminalAndRestart`: last paired exit zeroes supply/liquidity/book; rebootstrap works and excludes old unbooked balances. |
| S1-A21 | `EXIT.test_A21_terminalSingleTokenLiquidity`: external liquidity permits success; vault-only liquidity causes atomic revert with shares intact. |
| S1-A22 | `COMP.test_A22_feeRetention`: all LP fees enter book, no fee-manager call/allowance occurs, and supply is unchanged. |
| S1-A23 | `COMP.test_A23_compoundBranches`: exact DUST equality, tie chooses token0, zero active liquidity, quarter cap, and small/no-swap branches match independent calculations. |
| S1-A24 | `COMP.test_A24_feeCheckpointsAndOwnership`: positive/zero-add final checkpoints include compound-swap fees; entry fees remain incumbent, exit-sale fees remain with remaining LPs, and partial exiter receives no whole-position fee receipt as principal. |
| S1-A25 | `ROUTE.test_A25_routeMatrix`: all four exact-input routes execute; every unsupported direction/token/identity route rejects with no state change. |
| S1-A26 | `ROUTE.test_A26_exactOutputUnavailable`: both Out selectors exist and revert `ExchangeOutNotAvailable`; full state/manager/token diff is empty. |
| S1-A27 | `PROJ.testFuzz_A27_previewExecutionParity`: every SE/SY/paired preview exactly equals execution from snapshot-identical state, including fees, crossings, compounding, and terminal exits. |
| S1-A28 | `PROJ.test_A28_candidateBudgets`: step 512 succeeds, 513 produces identical domain behavior in preview/execution; withdrawal uses at most two candidates/1,024 steps, with no overlay leakage or partial quote. |
| S1-A29 | `SY.test_A29_surfaceAndSEParity`: all 16 SY methods are callable; execution/previews match SE economics and `yieldToken` is the diamond with no second receipt. |
| S1-A30 | `SY.test_A30_internalBalanceAndValidation`: contract-only internal redemption and vault-held share checks; EOA/construction/short-credit cases reject; invalid-token preview/execution and value rules match S1-API-03. |
| S1-A31 | `SY.test_A31_emptyRewards`: all reward arrays are empty, claim event is canonical and empty, and compounded LP fees cannot be externally claimed. |
| S1-A32 | `MATH.test_A32_rawSYRate`: for 6/8/18 decimals, exact-rational controls verify both currency conversions and `floor(Vraw*1e18/S)`; canonical SY helpers return raw units, with no exit-proceeds equality assumption. |
| S1-A33 | `SY.test_A33_zeroSupplyRate`: zero supply returns zero; genesis still uses geometric mean rather than synthetic 1:1 target pricing. |
| S1-A34 | `CREDIT.test_A34_shortFalseFlagPull`: booked reserves and unrelated balances cannot fill short delivery; exact receipt error and zero mint/state change. |
| S1-A35 | `CREDIT.test_A35_pretransferCallerClass`: code-less and construction-time callers revert with canonical pretransfer error. |
| S1-A36 | `CREDIT.test_A36_noBookedCredit`: contract true-flag claims without unbooked funds cannot mint or spend booked backing; short credit rejects exactly. |
| S1-A37 | `CREDIT.test_A37_excessPretransfer`: only declared input is reserved/processed; nothing is refunded and excess remains unbooked. |
| S1-A38 | `ACCT.test_A38_donationSeparation`: donation increases book without shares; unsolicited balances remain excluded through compound, entry, exit, terminal, and restart. |
| S1-A39 | `SEC.test_A39_callbackAuthentication`: valid callback succeeds; wrong manager, unsolicited/wrong payload, replay, nested reentrancy, and cross-facet calls reject. |
| S1-A40 | `SEC.test_A40_alreadyUnlocked`: real unlocked-manager context rejects before nested unlock; assert no local-sleeve behavior or state mutation. |
| S1-A41 | `ACCT.test_A41_operationReconciliation`: after every operation, manager liquidity, native/token custody, book, supply, deltas, and event amounts reconcile exactly. |
| S1-A42 | `SEC.test_A42_disabledMatrix`: disabled vault rejects all issuance/donation, allows compound, and preserves paired/executable single/SY exits and identical fallback behavior. |
| S1-A43 | `SEC.test_A43_atomicFailures`: transfer/payout failures and minima revert earlier swaps, removals, burns, mints, transfers, and reservations. |
| S1-A44 | `ROUTE.test_A44_decimalsAndFoT`: mixed 6/8/18 pools preserve exact raw-unit accounting; real short/FoT delivery cannot create shares or payouts. |
| S1-A45 | `PROJ.test_A45_boundariesAndCapacity`: interior/exact-boundary/outside amounts equal manager receipts; only listed maintenance capacity failures select fallback, all others reject without clamping. |
| S1-A46 | `ACCT.test_A46_ownershipSequences`: exact supply conservation, no unbooked adoption, donation without mint, per-leg non-dilution, and exact pre-sale allocations; report external price/fee effects and residuals separately. |
| S1-A47 | `SEC.test_A47_instanceIsolation`: two proxies sharing facets have independent balances, approvals, books, positions, initialization, and callbacks. |
| S1-A48 | `GAS.test_A48_artifactsAndSize`: every runtime facet is within normal deployed-code limit; configuration has no `via_ir` or reduced depths; behavioral sentinel proves freshly edited artifact is deployed. |
| S1-A49 | `NATIVE.test_A49_nativePairedEntry`: exact native maximum is reserved and excluded from pre-compound; only unused value refunds; wrong value/refund failure rolls back. |
| S1-A50 | `NATIVE.test_A50_nativeWrappedParity`: snapshot-equivalent native SY and wrapped SE/SY routes return identical economics and differ only in ETH/wrapper delivery. |
| S1-A51 | `NATIVE.test_A51_realNativeSettlement`: real registered diamonds execute native manager settlement, wrapper callbacks, ETH receipt, and payable selectors; trace proves no ERC-20 call targets zero. |
| S1-A52 | `NATIVE.test_A52_noDuplicateNativeCredit`: forced/unsolicited ETH, pending value, refunds, and temporary wrapper balances never add duplicate backing or free deposit credit. |
| S1-A53 | `NATIVE.test_A53_nativeReceivers`: rejecting and reentrant receivers roll back completely; legitimate contract receivers consuming more than 2,300 gas succeed. |
| S1-A54 | `NATIVE.test_A54_nativeTerminalRestart`: terminal paired exit empties ETH/token book and owned liquidity; later genesis excludes old unbooked ETH. |
| S1-A55 | `NATIVE.test_A55_donationFormsAndRoutes`: native/wrapped donation credits the same reserve once; wrong value, native calls on ERC-20-only pools, and zero-address SE routes reject. |
| S1-A56 | `SURF.test_A56_reusedFacetComposition`: exact 20 selectors/interface declarations from five facets; no combined permit, duplicate token/SY selector, or factory facet in package inputs/addresses/cuts. |
| S1-A57 | `SURF.test_A57_factoryAndPermitLifecycle`: factory ERC-165/loupe/ERC-8109 work without package cuts; temporary hook follows factory lifecycle; shared Repos initialize and permit nonce/replay/domain tests pass. |
| S1-A58 | `PKG.test_A58_sortedContentsVersusFaceOrder`: with wrapper sorting after the other face, registry hash uses sorted copy while token/config/reserve arrays retain PoolKey order. |
| S1-A59 | `SEC.test_A59_callbackReadPolicy`: economic reads revert during operation; basic reserves return last committed snapshot; token/domain/static reads retain canonical behavior. |
| S1-A60 | `NATIVE.test_A60_syncResetAndReceiptAttribution`: native debt after ERC-20 sync explicitly re-syncs native, final deltas are zero, and empty-calldata receipts bypass facets and credit only active-engine expectations. |
| S1-A61 | `PROJ.test_A61_everyFallbackReason`: each reason has a real-manager reachable case or documented unreachable-domain proof; preview/event/execution mode and reason agree and valid full always wins. |
| S1-A62 | `PROJ.test_A62_noExceptionFallback`: actual manager/token/wrapper/custody/collection/state/payout failures never select fallback; failed CollectOnly plans revert without partial compound. |
| S1-A63 | `PROJ.test_A63_nonMaintenanceFailuresAndModeABI`: minima/final-sale failures do not change mode; paired sentinel and single-token ETH queries are unambiguous. |
| S1-A64 | `ENTRY.test_A64_creditComponents`: independent controls distinguish `G_i`, paired credited `J_i`, zap uncredited `J_i`, and incumbent fees; entrant bears rounding costs and minimum uses final `q`. |
| S1-A65 | `ACCT.test_A65_stableCustodyBoundaries`: every stable boundary satisfies the complete custody equation with zero reservations; terminal receipts pay the last holder and unsolicited funds remain excluded. |
| S1-A66 | `ACCT.test_A66_emptyZeroAndTinySequences`: empty compound is a no-op; zero-output burns reject; one-sided payouts succeed; tiny genesis/donation sequences preserve exact accounting without sinks. |
| S1-A67 | `PROJ.test_A67_protocolFeeAndStateInvalidation`: nonzero protocol fees, initialized crossings, empty-word progress, and checkpoints match real manager results; token/wrapper-induced changes revert `EconomicStateChanged`. |
| S1-A68 | `SURF.test_A68_finalManifestAndNoExcludedSurface`: no owner/diamondCut/rescue/ERC-4626/excluded adapters; manifest covers complete ABI/IDs/Repos and binding identity. |
| S1-A69 | `PKG.test_A69_zeroFeesAndRawConstants`: zero fee IDs deploy through real registry; DUST is 1,000 raw units, zap values lack defaults, and cached validated decimals drive metadata only. |
| S1-A70 | `GAS.test_A70_worstCaseFeasibility`: record worst-candidate, native/wrapped, and CollectOnly paired gas plus every runtime size; any failed normal-limit gate blocks release for design revision, never relaxed tests or hidden caps. |

# Validation/release gates

## 1. Per-change artifact-first validation

After each production edit, run the current artifact workflow for that edited source and its focused suite, for example:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultProjectionLib.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultProjection.t.sol
```

Repeat for every edited production source and dependent test root. This is required because FactoryServices load creation bytecode from `out/`; a bare test run may deploy stale code.

Before compilation, inspect diagnostics on every changed Solidity file. Do not suppress new errors or warnings.

## 2. Focused family gates

After artifacts are current:

```bash
forge test \
  --match-path 'test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken/*.t.sol'
```

Run declaration, arithmetic/oracle, real-manager integration, native, adversarial, and invariant suites to completion. Any expected domain failure must be asserted by exact error and atomic state, not omitted from the run.

Verify the final selector/NatSpec manifest through the committed canonical verifier:

```bash
forge script scripts/foundry/ComputeNatSpecValues.s.sol --sig "run()" -vvv
```

Do not replace this with handwritten selector/interface IDs.

## 3. Full hermetic gate

```bash
forge build
forge test
forge build --sizes
```

Requirements:

- Exit code zero for build and complete hermetic tests.
- No package-specific Foundry profile.
- No `via_ir`.
- No lowered fuzz/invariant depth.
- No deleted shared caches or stale artifact deployment.
- Pre-existing unrelated failures, if any, must be reported separately with output; never edit them to green.
- Cold/near-cold monorepo compiles are allowed to run for hours; do not kill them for inactivity.
- A new worktree must first receive `cache_forge/` and `out/` from a warm checkout, using the paths configured in `foundry.toml`.

## 4. Feasibility and release evidence

A48/A61/A70 are hard gates:

- Every deployed facet runtime is at most the normal 24,576-byte limit.
- Record worst-case 512-step single-candidate and 1,024-step two-candidate preview gas.
- Record actual execution gas for full and CollectOnly paired exits, both native/wrapped forms, and final-sale exits.
- Each fallback reason needs a real reachable fixture or a precise mathematical unreachable-domain proof.
- Failure of gas/size feasibility blocks completion and requires design revision. It does not justify lowering test depth, increasing the 512-step bound, hiding work, or relaxing normal deployment limits.

The implementation handoff must contain:

1. Changed production/test files and stage completion.
2. Exact commands and exit results.
3. Selector/interface/facet/Repo manifest.
4. Baseline comparison ledger with every intentional deviation.
5. A01–A70 evidence mapping, including independent non-dilution and exact-rational controls.
6. Runtime-size and gas table.
7. Fallback reachability evidence.
8. Remaining integration limits and explicit identification of any unrun or pre-existing failure.

# Blockers and limits

No contradiction in the revised PRD presently prevents this implementation plan. In particular, the view requirement is feasible in design through a memory overlay rather than state-mutating quote execution, and S1-QUOTE-02 has a viable exact multiword implementation.

Two matters remain **unproved evidence gates**, not silently waived blockers:

1. **A61 fallback domains:** real-manager reachability for every listed maintenance obstacle has not yet been demonstrated. Any reason that cannot be constructed needs an independent domain proof; a scripted manager failure is not evidence.
2. **A48/A70 gas and runtime size:** the 512/1,024-step projector and execution paths have not been compiled or measured. Facet splitting is the first permitted remediation; any remaining infeasibility requires PRD/design revision rather than changed limits or economics.

All economics, preview parity, native behavior, and ownership properties remain unverified until the proposed production-first suites run. This contribution authorizes neither implementation nor deployment.
