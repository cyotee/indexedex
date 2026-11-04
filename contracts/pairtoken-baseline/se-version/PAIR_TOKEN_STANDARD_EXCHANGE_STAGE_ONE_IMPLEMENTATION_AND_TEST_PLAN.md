# PairToken Standard Exchange Vault: implementation and testing plan

Status: owner-approved bounded-execution implementation/testing revision, 2026-10-29.
Plan revision: bounded-execution-r2; the original council provenance below is historical.
Reviewed synthesis: `pairtoken-se-stage-one-plan-20261028-01a1810f-r1`;
its frozen SHA-256 is `e586652849499d117b97c01882e66651777a3cbf3a50a5cd2750ea4c01660737`.
Publication destination:
`contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_IMPLEMENTATION_AND_TEST_PLAN.md`.

## 1. Authority, scope, and completion contract

Implement the adjacent `PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, not a
new strategy. Current amended PRD SHA-256:
`6f4cad4f648189da10d0c47db3a3d0cfbc01462bef6ecbe81d2ca97b25a9d1b3`.
The original council-admitted PRD SHA-256 was:
`574ce6c03c0bc62f79a816e5a7775c831cb932082e0dd4bfe414fc1945ed7a7f`.
Its immutable copy is
`docs/research/pairtoken-se-stage-one-plan-20261028-01a1810f/inputs/PRD.md`.
The original source and snapshot were byte-identical at admission. Preserve that
snapshot; the owner-approved S1-P07/S1-GAS-01 amendment now controls the operational
domain. This revision is not represented as another council-reviewed draft.

This plan covers S1-P01-P07, all named deviations, the 19 family methods,
60 package-owned product selectors, and every S1-A01-S1-A70 acceptance row.
The PRD controls economics; this document controls work order and evidence.
Any genuine requirement conflict is raised before the affected increment,
not resolved by silently weakening the PRD.

In scope: one full-range position, one public share supply, exact caller
attribution, fee checkpoints, conditional withdrawal fallback, native ETH/
wrapped faces, exact-input SE, native SY, explicitly unavailable exact output,
and real registered Diamond Packages. There is no second internal reserve
supply, Wings strategy, rate-provider deployment, protocol fee, dead/virtual
share sink, rescue/admin upgrade path, or code from a retired V4 family.

The owner explicitly authorized applying the bounded-execution recommendation
to the PRD, plan, implementation and tests. This is not deployment, migration or
commit authorization. Implementation is complete only when the amended observable
gates pass, not when files or mocked examples exist.

### Approved bounded-execution increment

Preserve the 60-selector product surface, atomic operations, all ownership/fee
equations, native representation and current full/collection-only selection.
Add deterministic limits shared across all swaps in a candidate: 64 iterations,
12 actual initialized crossings (repeat crossings count), and 16 distinct cached
bitmap words including owned boundary words. Withdrawals may attempt only two
fresh candidates. A rejected normal plan must stop early and cannot contaminate
the collection-only plan. Paired fallback contains no swaps; a single-token
fallback must itself fit or return its exact error before any manager action/burn.

The engineering acceptance ceiling is 12M transaction gas, tested as at most
11.9M cold call-body gas plus 100k intrinsic/fixed-calldata reserve. Use 5M for
local previews and report unverified provider-specific read caps separately.
Derive final work bounds from initialized-crossing, empty-word and combined-phase
fixtures; tighten the documented limits if required, never increase the gas
ceiling to make a test pass. The initial 32-crossing candidate failed a six-action
entry at 17.71M gas; 16 crossings still required 12.068M call-body gas, above
11.9M. The bound was therefore tightened to 12 without relaxing gas tests.
Twelve crossings limit two fresh outside-fee writes per crossing to 480k gas
before other costs, rather than the original 20.4M floor for 510 crossings.

Add QuoteTickCrossingsExceeded(uint256,uint256) and
QuoteBitmapWordsExceeded(uint256,uint256) to the existing error surface, keeping
the existing step error and MaintenanceWorkLimit reason. No new caller flags,
delayed claims, asynchronous settlement or per-instance mutable budgets.
Keep the old manager-only 510-crossing cost witness as historical domain evidence,
but test that the revised product rejects that single-token conversion cheaply
while allowing a valid paired escape. Update stale tests to the newly approved
domain without removing ownership, rollback or boundary assertions.

### Council provenance

Full council requested: Astra `chatgpt-subscription/gpt-6-astra:high`,
Grok `xai/grok-4.7:xhigh`, MiniMax `minimax/MiniMax-M3` with the existing
adaptive setting, and Kimi `kimi-coding/k3.1-pro:high`.

Three complete independent contributions are archived. Grok produced a
substantive contribution, but the supported transcript reader omitted 29,081
middle characters and a no-tool verbatim recovery returned provider HTTP 403.
The available original is retained with its elision marker. No provider retry
or model substitution was made. Consequently this is a **partial full-council
result**, not four complete independent approvals.

Run artifacts:
`docs/research/pairtoken-se-stage-one-plan-20261028-01a1810f/`.
The invoking coordinator is not a fifth independent vote. Astra, MiniMax and
Kimi each completed one draft-only advisory pass with **support with
corrections**. Their exact feedback and `coordinator/resolution.md` are retained
in the run directory. This publication incorporates coordinator corrections
after that pass; it is not a claim of a second review or four-member approval.

## 2. Naming and exact file boundaries

For compactness, this plan uses:

```text
P = contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken
F = UniswapV4PairTokenStandardExchangeVault
T = test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken
```

`P/FMath.sol` means
`contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultMath.sol`.
These are proposed paths, not existing implementations.

### 2.1 Production files

| Proposed file | Single responsibility / implementation boundary |
| --- | --- |
| `P/interfaces/IF.sol` | Expand F; exact 19 family methods, enums, events and errors. No second share-token interface or internal dispatch API. |
| `P/interfaces/IFDFPkg.sol` | `PkgInit`, `PkgArgs`, typed registry deployment helper, binding query, package errors; canonical package interfaces. |
| `P/FRepo.sol` | One fixed family namespace using canonical Repo convention; configuration, committed book, guard, callback commitment and operation reservations. No duplicate ERC-20 supply, balances, or authoritative position fee storage. |
| `P/FTypes.sol` | Shared operation, snapshot, plan, projected state, witness and categorized-inventory types. Public enums remain on IF, not redefined. |
| `P/FMath.sol` | Clamped principal/cost math, exact issuance/allocation, baseline compound sizing, bounded type/capacity checks, multiword valuation. |
| `P/FProjection.sol` | Memory-only V4 loader, overlays, swap/tick/position/fee transitions and witnesses. |
| `P/FPlanner.sol` | Whole-operation plans, fee checkpoints, caller attribution, typed normal/fallback selection and economic-domain failures. |
| `P/FExecution.sol` | Consume selected plans, authenticate operations, settle actual deltas, update custody categories, mint/burn, pay/refund and publish. Internal helpers; no proxy self-calls. |
| `P/FMoneyTarget.sol`, `P/FMoneyFacet.sol` | SE exchangeIn, paired entry/exit, donation and public compound: five selectors. |
| `P/FQuoteTarget.sol`, `P/FQuoteFacet.sol` | SE previewExchangeIn and four family previews: five selectors. |
| `P/FOutTarget.sol`, `P/FOutFacet.sol` | Both canonical exact-output methods, immediately reverting. |
| `P/FQueryTarget.sol`, `P/FQueryFacet.sol` | Eleven family configuration/position/book queries with their read policies. |
| `P/FSYMoneyTarget.sol`, `P/FSYMoneyFacet.sol` | SY deposit/redeem and two state-changing empty-reward methods. |
| `P/FSYQueryTarget.sol`, `P/FSYQueryFacet.sol` | Twelve SY read methods; family-owned guarded preview wrappers and exact accounting rate. |
| `P/FCallbackTarget.sol`, `P/FCallbackFacet.sol` | Only authenticated `unlockCallback(bytes)`. |
| `P/FDFPkg.sol` | Immutable composition/bindings, argument processing, salt, registry lifecycle and proxy initialization. |
| `P/FComponent_FactoryService.sol` | Artifact-based CREATE3 component and typed registry package deployment. |
| `P/test/bases/TestBase_F.sol` | Reusable real-family TestBase, following `CraneTest -> IndexedexTest -> family TestBase`. |
| `P/test/behaviors/Behavior_FPackage.sol` | Small family-local package declaration/lifecycle Behavior; do not assume the absent generic helper exists. |

Use the documented ERC1967-form Repo slot
`bytes32(uint256(keccak256(abi.encode("indexedex.vaults.standard.exchange.uniswap.v4.pairToken"))) - 1)`;
verify its value through the canonical workflow. A plain hash without the
subtraction does not meet the PRD's ERC1967-form requirement.

Prefer internal libraries initially. Keep math/projector/execution boundaries
explicit so code-size evidence can drive an external-link or fixed
package-bound execution-delegate split. Such a component is not a proxy
selector and may not be caller-selected. Its binding, factory deployment,
direct-call rejection and runtime-size tests are mandatory if used. Bind its
address immutably; adding/changing it changes package binding identity. No
caller-selectable delegatecall address is permitted.
Do not publish a no-op implementation merely to make intermediate packages deploy.

### 2.2 Verification tooling (planned scoped edits)

Extend the existing canonical
`lib/crane/scripts/foundry/ComputeNatSpecValues.s.sol` for the new family
using its actual typed interfaces, and record computed values in
`lib/crane/docs/reference/CENTRALLY_COMPUTED_NATSPEC_VALUES.md`.
Cover methods, errors, events, interface IDs and the Repo slot. Do not copy
simplified interface declarations or invent a separate authoritative selector
script. Shared production code remains unchanged; these scoped verification/
documentation updates are distinct from altering Crane economics.

### 2.3 Reuse unchanged

| Existing source | Ownership |
| --- | --- |
| `lib/crane/contracts/tokens/ERC20/ERC20Facet.sol` | Nine ERC-20/metadata selectors and ERC20Repo. |
| `lib/crane/contracts/tokens/ERC2612/ERC2612Facet.sol` | Three permit selectors and canonical nonce/domain state. |
| `lib/crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol` | `eip712Domain`, shared EIP712Repo. |
| `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol` | Three committed-local-reserve selectors. |
| `contracts/vaults/standard/MultiAssetStandardVaultFacet.sol` | Four initialized standard-vault selectors. |
| `contracts/utils/LocalCreditLib.sol` | Contract-caller checks and available/budget calculations, after explicit custody-solvency checks. |
| `contracts/utils/foundry/ArtifactCreationCode.sol` | Current artifact-loading workflow. |
| `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol` | Compatible execution/reward seams, not wholesale inheritance of every aggregate. |
| `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol` and `NativeStandardYieldQuoteBase.sol` | Compatible discovery/validation and quote seams. |
| `contracts/vaults/standard/exchange/StandardExchangeInExecutionBase.sol` | Shared internal route contract. |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/` | Canonical manager/types/state, transient state, pool/position/tick/bitmap, swap/price/liquidity, LP/protocol fee and full-precision math. |
| `lib/crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol` | Interface to the canonical bound 1:1 wrapper. |

Reuse `lib/crane/contracts/factories/diamondPkg/Behavior_IFacet.sol`.
`Behavior_IDiamondFactoryPackage.sol` was not found in the admitted Crane tree;
the registry-specific Behavior is not a substitute for package lifecycle tests.
Use the small family-local Behavior above instead of adding a fictional import.

Wings contributes packaging/artifact/TestBase patterns only. Baseline sources
and the existing PairToken harness remain separate characterization references.
No shared facets, shared SY behavior, baseline code, or Wings code are edited.

## 3. Product selector and initialization manifest

### 3.1 Sixty package-owned selectors

| Owner | Methods/count |
| --- | --- |
| Five canonical reused facets | 9 + 3 + 1 + 3 + 4 = 20, exactly S1-ARCH-04. |
| MoneyFacet | `exchangeIn`, `depositPair`, `redeemPair`, `donate`, `compound`: 5. |
| QuoteFacet | `previewExchangeIn`, `previewDepositPair`, `previewRedeemPair`, `previewWithdrawalMode`, `previewZapCredit`: 5. |
| OutFacet | `previewExchangeOut`, `exchangeOut`: 2. |
| QueryFacet | `poolManager`, `poolKey`, `wrappedNative`, `rateAsset`, `tickLower`, `tickUpper`, `positionLiquidity`, `localReserves`, `basket`, `maxZapBps`, `maxZapTickMove`: 11. |
| SYMoneyFacet | `deposit`, `redeem`, `rewardIndexesCurrent`, `claimRewards`: 4. |
| SYQueryFacet | `previewDeposit`, `previewRedeem`, `getTokensIn`, `getTokensOut`, `yieldToken`, `assetInfo`, `exchangeRate`, `isValidTokenIn`, `isValidTokenOut`, `getRewardTokens`, `accruedRewards`, `rewardIndexesStored`: 12. |
| CallbackFacet | `unlockCallback(bytes)`: 1. |

Total: 20 + 40 = 60; exactly 19 family, 4 SE, 16 SY, 1 callback beyond reused
selectors. Preserve overload parameter order and mutability from actual
canonical interfaces and PRD S1-API-05, not a hand-transcribed hash.

Generate an independent manifest:
`typed signature -> selector -> facet -> interface declaration -> Repo ->
initialization owner -> read policy -> test`.
Compare Target/interface controls with facet metadata, package cuts, live
loupe, interface declarations, and callable proxy behavior. Splitting family
or SY methods across facets requires full-interface closure on the composed
proxy; it does not justify dummy methods on partial facets.

No factory-provided facets appear in package inputs, addresses, cuts or
package-owned interface aggregation. The final persistent proxy includes the
factory's ERC-165/loupe/ERC-8109; its temporary hook follows factory lifecycle.
Do not install ERC20PermitFacet or duplicate SY-inherited token methods.
Concrete In/Out IDs remain declared; the inheritance-only combined marker is
not a route-availability signal.

### 3.2 Package bindings and delegatecall-safe lifecycle

P0 records exact signatures/call contexts from
`lib/crane/contracts/factories/diamondPkg/utils/DiamondFactoryPackageAdaptor.sol`
and `lib/crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol`. The
coordinator read both during this council; implementation must recheck them
against its checkout before relying on these bindings. No weaker authentication
is substituted if the underlying API changes.

`PkgInit` binds the real shared/family facets, manager, registry, fee oracle,
canonical wrapper, callback factory, and any deployed linked component.
`PkgArgs` contains exactly the PRD's pool key, rate asset, name, symbol,
maxZapBps and maxZapTickMove. No Permit2 or fee-manager dependency is introduced.

Use immutable SELF and bindings, with an immutable binding hash. The actual
`DiamondFactoryPackageAdaptor` delegatecalls `calcSalt` and `processArgs`
in the factory context. Do not read package storage from that foreign context;
use immutables and explicit SELF calls for package-resident arrays.

Instance identity uses canonical decoded args plus bindingHash. Preserve
name-based CREATE3 component/library salt conventions; constructor arguments
and bytecode remain deployment payloads. Occupied CREATE3 identities must not
be silently reused with different bindings/code. Test binding sensitivity from
a pre-deployment snapshot, not by rebinding an already occupied deployment.

Authenticate processArgs against the registry in the actual call context.
At proxy init, use bound factory `pkgOfAccount(address(this))` and
`pkgArgsOfAccount(address(this))` to validate package/argument identity, reject
direct package execution/reinitialization, then initialize:

1. Family immutable-after-init config, canonical pool/ticks and zero position salt.
2. ERC20Repo metadata, 18 decimals, zero supply.
3. EIP712Repo with the same name/version `"1"`; nonces remain canonical zero.
4. MultiAssetBasicVaultRepo `[C0,C1]` in PoolKey face order and zero reserves.
5. StandardVaultRepo with actual oracle, zero fee IDs, deduplicated package
   interface types and the hash of a separately address-sorted face copy.

Never initialize facet storage or factory introspection state. Confirm
prediction/direct-call and factory-delegatecall identity agree.

### 3.3 SY and read-policy precedence

Shared `NativeStandardYieldPreviewCallsTarget` wrappers are nonvirtual and
check invalid tokens before entering the quote engine. Do not inherit those
wrappers where they prevent the required guard-first behavior. Build the two
family wrappers from compatible discovery/validation/quote bases:
guard economic view first, then return zero for an unsupported SY token, then
invoke the exact planner. Modify no shared file.

New economic reads fail during mutation. Shared basic reserves return the last
committed snapshot; canonical token/domain/static discovery stays canonical.
Both Out methods always return their specified unavailable error, including
during mutation: the explicit unconditional Out requirement takes precedence
over the general preview read rule. Pin that interpretation in tests.

## 4. Dependency-ordered implementation stages

No stage is green merely because a later fixture is assumed to exist.
Component tests before a deployable product use pure libraries and real-manager
actors, not a fake vault. Full acceptance claims begin only at registered
product integration. Every implemented public method must perform its real
behavior; do not ship stubs to close an early stage.

| Stage | Prerequisites | Work | Observable exit evidence |
| --- | --- | --- | --- |
| P0: contract and evidence map | Pinned PRD | Manifest, types/interfaces, Repo ownership, comparison ledger, canonical source pointers, test names and deployment-envelope record. | All 60 selectors and A01-A70 mapped; required policy is unchanged; unknown deployment budget is explicitly a release gate. |
| P1: exact arithmetic and accounting primitives | P0 | FMath, ledger types/pure transitions, independent oracle, endpoints, qQuote/qCredit/allocation, rational valuation. | Exact vector/fuzz controls; no non-limiting intermediate overflow rejection; final-value overflow and rounding domains explicit. |
| P2: V4 state projection and planner | P1 | Lazy overlays, exact swap/modify/fee transitions, witnesses, whole-operation plans and fallback classifier. | Differential real-manager tests; step/crossing/word boundaries, shared phase budgets, fresh candidate isolation, protocol fees and exact boundaries. Not yet full A27 product evidence. |
| P3: execution engine and callback | P2 | Custody categories, exact pulls, native/wrapped settlement, callbacks, maintenance, entry/exit, state invalidation and final publication. | Compiler/diagnostics and component settlement controls; all paths implemented with no temporary success placeholders. |
| P4: facets, package and real-family fixture | P0-P3 | Complete Money/Quote/Out/Query/SY/Callback surfaces, artifact factory service, registry package, family TestBase and package Behavior. | Real registered proxy with all 60 selectors, initialized state, declaration/lifecycle tests, first public genesis-to-exit, initial size evidence. |
| P5: route and lifecycle acceptance | P4 | Full paired/zap/exit/compound/SY/native/pretransfer/donation/disable matrices; real state/output parity and rollback. | Named real-proxy evidence for every functional row; no component-only test substituted for a product obligation. |
| P6: adversarial sequences and invariants | P5 | Public-route handlers, independent ownership controls, fee checkpoints, state-mutating callbacks, terminal/restart, difficult fallback reachability. | Configured fuzz/invariant depths unchanged; falsifiable custody/ownership properties and each A61 reason classified by evidence. |
| P7: feasibility, regressions and handoff | P4-P6 | Final size/gas gates, canonical regressions, artifact provenance, hermetic integration, full evidence ledger. | All A01-A70 passed or an explicit blocking gate remains; no deployment or implementation-complete claim while a gate is open. |

Math and interface work can be parallelized only behind agreed types. Test
controls should be independent of SUT arithmetic. Do not parallel-edit the
baseline harness or common fixture owned by another implementer.

## 5. Accounting and execution approach

### 5.1 Custody representation

Keep booked idle, caller input, exit allocation and refund distinct.
Unbooked excess is derived, never a second balance that can double-count assets.
Check solvency before using LocalCreditLib's saturating available calculation.
For a native alias, available wrapped credit subtracts only wrapper-represented
reservations, not ETH booked backing. WETH as an actual ERC-20 pool leg uses
ordinary ERC-20 accounting.

Native input already on entry is reserved before planning. False-flag paired
pulls take accepted amounts only; scalar pulls require exact delivery.
Contract-only pretransfers reserve exactly the declaration. Share pretransfers
use authenticated held shares, never another holder's wallet balance.

On each liquidity modification, decode each signed currency component and
widen it before arithmetic:
`principalDelta_i = callerDelta_i - feesAccrued_i`.
Never subtract packed BalanceDelta words as ordinary integers. Validate each
principal, fee, net settlement and liquidity quantity in its own domain.
For an addition, principal is nonpositive per leg (an unused leg is zero);
its nonnegative cost is `-principalDelta_i = feesAccrued_i - callerDelta_i`. The baseline `_add` sign is
therefore not the defect alleged in MiniMax's contribution. Removal principal
is nonnegative. Book fees once even when netted against principal debt.

### 5.2 Manager operations, maintenance and fee checkpoints

Hold one cross-facet guard through manager operations and final transfers.
Before each unlock check canonical `TransientStateLibrary.isUnlocked`, commit
the encoded operation/payload hash, and consume it once at authenticated callback.
No callback expectation survives successful completion.

Native debt uses sync(native) before exact value settlement; ERC-20 debt uses
sync/transfer/settle. Check paid amounts, observed credits, and final zero
manager deltas. Proxy receive accepts ETH without dispatching a facet; book
expected receipts in the active engine.

Full maintenance uses the baseline raw-unit dust condition, leftover valuation,
tie direction, half swap and quarter cap, from incumbent booked inventory only.
Preserve its **sequential-floor leftover comparison**; this differs deliberately
from SY's single-floor valuation. Positive adds may realize maintenance-swap
fees; otherwise finish with one poke of a nonempty position. Canonical
Position.update calculates whole-position fees on pre-update liquidity and
advances inside-fee checkpoints even for a nonempty zero-delta poke. That
advancement, or the equivalent checkpoint established by a positive add, makes
a later unchanged-state removal report zero new fees. Do not require a second
redundant poke when the checkpoint is already current. Never recursively
reinvest the final fees or poke an empty position.

The clean zero book/supply/position is a no-op even with unbooked transfers.
No fee-manager call or share change occurs. Registry disable rejects issuance/
donation, not standalone compound or eligible exits.

### 5.3 Entry and exit checkpoints

Paired: preflight the complete plan using hypothetical input and projected
post-maintenance reserves; execute incumbent maintenance/final fees; validate
the resulting snapshot; calculate qQuote/accepted input from that snapshot;
pull accepted ERC-20 amounts and revalidate state; add caller-only inventory;
calculate actual G_i and J_i, `C_i=G_i+J_i`, and `q=min(qQuote,qCredit)`;
enforce the actual-share minimum, mint/book/refund and publish. Preserve full live-leg acceptance in the one-sided
branch; do not recalculate accepted input after the cap. Positive-supply paired
entry may credit valid idle input even if dL is zero; genesis requires positive
fundable liquidity and mints all geometric-mean shares.

Zap: apply size cap to pre-entry-swap reserves, swap floor(received/2) from
caller inventory, check ticks, checkpoint incumbent entry-swap fees, freeze
post-swap P*, add caller-only liquidity, mint from G_i, then book J_i without
extra shares. Do not credit earlier maintenance deployment or use SY rate.

Compute products/comparisons with wide integers. Choose the limiting
contribution/reserve ratio before a narrowing division, or retain wide
quotients: an overflowing non-limiting leg must not reject a representable
minimum. For paired entry, qQuote already caps final shares; test its
inequalities before requiring an otherwise irrelevant huge qCredit quotient.
Validate actual final supply and declared result types.

Exit: validate amount, authority, recipient and deadline before maintenance;
preflight/select the complete plan; execute selected maintenance and establish
a current fee checkpoint; snapshot S/L/B; burn; remove floor proportional
liquidity and allocate idle/principal; perform any allocation-only sale; enforce
actual payout minima; pay and commit. Checkpoint advancement prevents the
subsequent partial removal from receiving whole-position accrued fees. Unexpected fee/price mutation
invalidates the plan. A partial remover cannot receive whole-position fees
already assigned at the snapshot. Remaining liquidity owns exit-sale fees.
Reject zero total paired payout or zero final single-token payout.

A final paired exit removes all owned liquidity and pays all owned generated
receipts. Unsolicited funds remain excluded through restart. Final single-token
exit needs external remaining liquidity and full unwanted-token consumption.

### 5.4 Fallback is typed planning, not exception recovery

Normal full candidate always goes first. Only these PRD results permit a fresh
CollectOnly candidate:

| Reason | Exact implementation meaning |
| --- | --- |
| MaintenanceWorkLimit | The **complete normal withdrawal**, including final sale, exceeds its 64-iteration, 12-crossing or 16-distinct-word limit. It is not limited to maintenance. Fallback succeeds only if the complete fresh collection-only candidate satisfies every limit. |
| MaintenancePriceLimit | A planned nonzero maintenance swap lacks a legal directional interval. Zero swap does not qualify. |
| MaintenanceLiquidityLimit | Maintenance addition violates specified signed/owned/per-tick/principal-delta limits. |
| MaintenanceDeltaLimit | Maintenance swap amount or computed settlement delta is not representable. |

Track failure phase and kind so an entry addition, invalid book, fee collection,
unwanted-token partial sale, or minimum failure is not relabeled maintenance.
The WorkLimit case has the explicit whole-candidate scope above, even when
exhaustion occurs in the final sale.

Discard the failed candidate's entire mutable overlay. Plan CollectOnly from
the immutable original with a fresh counter. If it fails, return its failure.
Never catch a state-changing call to retry, carry over partial execution,
or change mode in response to an actual receipt. Emit one selected-mode event.

## 6. Exact projector and arithmetic

### 6.1 Memory overlay and canonical transitions

Before loading owned state, derive the key with canonical
`Position.calculatePositionKey(diamond, tickLower, tickUpper, bytes32(0))`.
Verify both key encoding and StateLibrary.getPositionInfo/getPositionLiquidity
against a real manager round trip rather than assuming a hand-rolled encoding.

Initial snapshot contains configuration, supply/book, slot0 including stored
tick and LP/protocol fees, active liquidity, global fee growth, owned liquidity/
checkpoints, and full-range boundary state.

Lazy caches key bitmap words and ticks; first reads use StateLibrary and later
reads use candidate overlays. Include tick gross/net liquidity, fee growth
outside, and bitmap flips. Cache capacity follows the amended bounds: at most
12 distinct crossed ticks plus two fixed boundaries, and 16 distinct words.
Count repeat crossings even when a tick is cached, but do not double-count a
bitmap key. No unexplained cache-full rejection or all-pool tick scan is allowed.

Mirror actual Pool.swap: signed exact-input semantics, directional protocol
fee, next-word progress, target price, SwapMath step, paid/received amounts,
protocol deduction before LP growth, modular fee updates, initialized crossing,
liquidity-net sign, and boundary stored tick (including tickNext-1). Deriving
stored tick from price everywhere is wrong at exact boundaries.

Liquidity modification must update ticks, bitmap, active liquidity, position
checkpoints and principal/fees in canonical order. Whole-position fees use old
owned liquidity, not pool active liquidity. Preserve modular wraparound and
floor rounding. Later steps see all prior simulated mutations.

Count every loop iteration, actual initialized crossing and distinct word
independently. One candidate has limits 64/12/16; withdrawal has at most two
independently bounded candidates, with aggregate maxima 128/24/32. Check iteration
admission first, then word admission before fetching, then crossing admission
before tick-state reads/mutation. Never reset counters between maintenance and
the entry/final-sale suffix. Do not use gasleft as economic policy.

### 6.2 Live-state witnesses

Plans carry selected mode/reason, expected operation/ledger deltas and phase
witnesses for configuration, pool price/tick/liquidity/fees, position state,
and every tick/word read by the **complete projected plan**, including records
needed only by later phases, not just already-mutated records. Check assumptions
after external token/wrapper
interactions and before the next manager phase. Expected changes from the
vault's own preceding phase are allowed; unexplained differences revert
EconomicStateChanged, with no in-flight replanning.

New economic views reject while busy; shared views keep their specified
snapshot/canonical semantics. Publish both shared reserves only after all
external payouts/refunds. Preview promises economic parity from the same
state, not authorization, allowance, value, deadline or receiver acceptance.

### 6.3 Canonical principal and exact single-floor valuation

Use one principal function for basket, attribution growth and exit controls:

| Price domain | N0 | N1 |
| --- | --- | --- |
| P <= sqrtLower | getAmount0Delta(sqrtLower, sqrtUpper, L, false) | 0 |
| P >= sqrtUpper | 0 | getAmount1Delta(sqrtLower, sqrtUpper, L, false) |
| Interior | getAmount0Delta(P, sqrtUpper, L, false) | getAmount1Delta(sqrtLower, P, L, false) |

Addition costs use the corresponding canonical round-up rules. Baseline interior
amount/liquidity formulas appear equivalent on their common admitted domain;
prove that with differential controls before labeling them preserved. Boundary
clamping is an explicit PRD deviation, not a universal interior-math defect.

Use explicit multiword limbs; do not compose two lossy mulDiv calls and call
them one floor. Keep book-value intermediates wide until final public rate
narrowing. A representable final rate must not be rejected just because an
intermediate currency valuation exceeds uint256.

For token1 value:

1. Compute P*P as an exact two-word product (P is uint160).
2. Multiply by A0 into three words; this captures up to 576 significant bits.
3. Shift the complete product right by 192 once. Retain the resulting wide
   quotient, then add A1 with carry.

For token0 value:

1. Form numerator A1<<192 as an exact two-word value (up to 448 bits).
2. Compute exact two-word P*P denominator (up to 320 bits, nonzero).
3. Use bounded unsigned multiword long division, returning the complete
   quotient and discarding the remainder **once**. A restoring bit algorithm
   with at most 512 numerator-bit steps is an auditable initial implementation.
   Prove carry/borrow/shift bounds; normalized division is only an equivalent
   optimization after independent controls.
4. Add A0 with carry.

Multiply the wide Vraw by 1e18, then divide by S with one final floor.
The two-word-by-one-word division produces a wide quotient; never discard its
high word before the final public-result representability check. Under
the admitted uint160 price and uint256 amount bounds these intermediates fit
the chosen two-word post-conversion representation; prove the bounds, do not
rely on Solidity wraparound. Narrow only the final rate, reverting if that
mathematical public result cannot fit. Zero supply returns zero.

This rate path is separate from compound's baseline sequential-floor comparison.
Independent controls must include a representable final rate with wide
intermediate Vraw, as well as a genuinely unrepresentable final rate.

## 7. Test infrastructure and independent controls

### 7.1 Proposed test files

Under T, use `F` expanded in each Solidity filename:

| Key | Proposed suite |
| --- | --- |
| DEP | `FDeployment.t.sol` |
| SUR | `FProxySurface.t.sol` |
| MAT | `FMath.t.sol` |
| ENT | `FEntry.t.sol` |
| EXT | `FExit.t.sol` |
| CMP | `FCompound.t.sol` |
| PRO | `FProjection.t.sol` |
| STD | `FStandardExchange.t.sol` |
| SY | `FStandardizedYield.t.sol` |
| NAT | `FNative.t.sol` |
| CRD | `FCreditDonation.t.sol` |
| SEC | `FSecurity.t.sol` |
| INV | `FAccountingInvariant.t.sol` and `harness/Handler_F.sol` |
| BASE | `FBaselineComparison.t.sol` |
| GAS | `FFeasibility.t.sol` |

Add an independent Python-integer/fraction oracle and checked-in compact vector
fixtures under `T/reference/`. Generate/replay vectors deterministically, with
seed recorded. Do not make production math its own test oracle. Pure arithmetic
tests need no fake vault; real vault acceptance uses the registered fixture.

### 7.2 Production fixture

Family TestBase uses real IndexedexTest infrastructure, real artifact-loaded
PoolManager, five shared plus family facets, real registry-deployed package/
diamonds, and canonical wrapped native. Non-SUT mintable ERC-20s may supply
6/8/18-decimal and negative transfer/callback behaviors.

Use genuine manager actors/positions to create initialized tick crossings,
empty words, protocol fees, active-liquidity changes, capacity pressure and
external liquidity for terminal exits. Forked or real-token facts are not
substituted for the default hermetic gate. No SUT subclass, vm.store, or vm.etch.
Native balance funding of test actors is not storage fabrication of the vault.

Snapshot/revert around preview and execution to compare identical pool/book/
config state. Assert outputs, events, actual deltas, owned liquidity, fees,
booked/unbooked balances and supply; a return-value-only parity test is weak.

Negative receivers, construction-time callers, credit routers and callback
tokens are boundary actors, not mock manager/SUT replacements.

### 7.3 Invariant and difficult-case policy

Handlers use public supported routes and track distinct holders. Assert
sum of balances equals supply, no dead supply, stable zero reservations,
custody/manager reconciliation, exact per-leg q*R<=S*C, correct proportional
pre-sale allocation, no unbooked adoption and terminal reset.
Separate pool-price/fee effects and zap residual donations from ownership
assertions. Do not assert monotonic NAV or absence of profitable trading.

For each fallback reason, build a real reachable state or prove its
unreachability under configured constraints using independent domain reasoning.
Planner-result injection is useful for classifier unit coverage but does not
satisfy A61. Test work exhaustion after maintenance has consumed part of the
budget and during the final sale, with a valid lower-work second candidate.

Boundary/empty states that require impossible token behavior in a healthy
vault must be labeled reachability assumptions, not manufactured by SUT storage
injection. Use permitted negative token actors or independent transition
controls where the row specifies a domain rejection.

### 7.4 Complete acceptance map

Every ID is retained, with concrete proposed cases. Secondary suites may add
evidence; the named primary case is not a substitute for all stated subcases.

| PRD ID | Primary case(s) | Required assertion / evidence |
| --- | --- | --- |
| S1-A01 | DEP.RegistryDiscovery | Registered real native/ERC-20 diamonds found by faces, pair contents and declared types. |
| S1-A02 | DEP.IdentitySensitivity | Prediction/deployment agree; args and package bindings vary identity from controlled pre-deployment snapshots. |
| S1-A03 | DEP.ConfigurationDomain | All invalid key/code/fee/spacing/hook/price/rate/zap/wrapper/face cases reject; valid pools deploy. |
| S1-A04 | DEP.LifecycleAuthentication | Direct init, repeat init, wrong process caller/context and invalid components leave no partial initialization. |
| S1-A05 | SUR.TokenDomainPermit | Exact metadata, 18 decimals, proxy/chain domain, nonce advancement, replay rejection and two-instance isolation. |
| S1-A06 | SUR.TargetFacetCutProxyMatrix | Independent typed controls equal declared/cut/live 60 selectors; factory set disjoint and callable. |
| S1-A07 | SUR.BookAndDiscovery | Ordered views/config/types, sorted contents identity, zero fee IDs and local-vs-deployed distinction. |
| S1-A08 | ENT.Genesis | Exact checked geometric mean wholly to recipient; no dead/virtual shares. |
| S1-A09 | ENT.GenesisFailures | Zero input/mint/fundable liquidity, product overflow and unmet final minimum roll back all state. |
| S1-A10 | ENT.PairedCandidateCredit | Ratio/ceiling accepted input, actual G/J and final cap, unused ERC-20 maxima and exact native refund. |
| S1-A11 | ENT.OneSidedDomain | Full live-leg maximum only; invalid positive-supply/zero-book domain rejects with reachability explained. |
| S1-A12 | ENT.MaintenanceInputIsolation | Pre-entry fees maintained while hypothetical/received caller input and native refund stay excluded. |
| S1-A13 | ENT.BothZaps | Half-swap, tick check, post-swap incumbent fees, caller-only addition and actual credit in both directions. |
| S1-A14 | ENT.ZapBoundaries | Empty/zero/cap/tick boundaries including equality, sub-tick movement and one-over cases. |
| S1-A15 | INV.EntryNonDilution | Independent wide q*R<=S*C at same P*, no epsilon; idle imbalance, partial input fill and rounding. |
| S1-A16 | EXT.ProportionalPair | Exact liquidity/idle floors and actual principal; no retention. |
| S1-A17 | EXT.DustAndFeeOwnership | Remaining-holder rounding dust and fees; no duplicate allocation or share creation. |
| S1-A18 | EXT.BothSingleOutputs | Only exit inventory sold; final actual minimum and positive output. |
| S1-A19 | EXT.PartialSaleAndMaintenanceFallback | Partial sale rollback; valid paired CollectOnly succeeds for listed obstacles, not unrelated faults. |
| S1-A20 | EXT.LastHolderRestart | Zero supply/liquidity/book after paired exit; restart excludes old unbooked assets. |
| S1-A21 | EXT.TerminalSaleLiquidity | External liquidity permits full sale; vault-only liquidity failure preserves shares/state. |
| S1-A22 | CMP.NoVaultFeeOrShareChange | All realized LP fees retained once, no fee manager, no supply delta. |
| S1-A23 | CMP.BaselineBranches | Strict raw dust boundary, tie direction, zero-active liquidity, quarter cap and zero-swap paths. |
| S1-A24 | CMP.FeeCheckpointOwnership | Positive-add/no-add checkpoints, entry-swap incumbent fees, partial exit whole-position fees, remaining-holder exit-sale fees. |
| S1-A25 | STD.RouteTable | Four exact-input routes and every unsupported direction/token. |
| S1-A26 | STD.ExactOutputUnavailable | Both selectors/interfaces present, exact unavailable error before any funding/mutation, including busy context. |
| S1-A27 | PRO.EndToEndParity | Exact output, failure and resulting state from identical initial state for all route forms/modes. |
| S1-A28 | PRO.WorkBudgetBoundaries | Exact 64/65 iterations, 12/13 crossings and 16/17 distinct words; shared suffix counters, at most two fresh candidates, exact error/fallback parity and zero failed-overlay leakage. Separate unreachable combinations from component guard controls. |
| S1-A29 | SY.FullSurface | All 16 SY selectors share the same token and economic engine; no wrapper receipt token. |
| S1-A30 | SY.InternalSharesAndValidation | Internal-balance authority, caller class, value, token validation and invalid-preview policy. |
| S1-A31 | SY.EmptyRewards | Empty arrays and canonical events; LP backing not separately claimable. |
| S1-A32 | MAT.CanonicalRawSYRate | Fraction oracle, each conversion's own rounding contract, and SYUtils.syToAsset raw-unit results within its checked-multiplication domain for 6/8/18 decimals. No exact-inverse promise; distinguish helper overflow from valid wide-rate/final-overflow cases. |
| S1-A33 | SY.EmptyRate | Zero before bootstrap; no artificial target-token 1:1 genesis issuance. |
| S1-A34 | CRD.FalseFlagReceipt | Exact actual receipt; short delivery cannot borrow booked/existing balances. |
| S1-A35 | CRD.CodeLessPretransfer | EOA and construction-time callers receive canonical pretransfer error. |
| S1-A36 | CRD.MissingOrShortCredit | Contract with insufficient unbooked inventory cannot mint/burn against incumbent backing. |
| S1-A37 | CRD.ExcessCredit | Process declared amount only; no excess refund/adoption, including wrapper representation. |
| S1-A38 | CRD.DonationVsUnsolicited | Same-call donation no mint; unsolicited balances stay unbooked through full lifecycle. |
| S1-A39 | SEC.CallbackCommitment | Actual manager callback succeeds; wrong sender, payload, operation, replay and cross-facet reentry reject. |
| S1-A40 | SEC.ManagerAlreadyUnlocked | Explicit pre-nested-unlock failure, no Wings local-sleeve path. |
| S1-A41 | INV.CustodyAndPosition | Stable reservations, manager deltas, liquidity, supply/book/events reconcile on every operation. |
| S1-A42 | CRD.DisabledPolicy | Issuance/donation blocked; public compound and eligible normal/fallback exits still work. |
| S1-A43 | SEC.AtomicFailure | Receiver/token/minimum failure rolls back swaps, removals, burns and prior transfers. |
| S1-A44 | ENT.MixedDecimalsAndForbiddenTokens | Supported non-18 amounts and real negative FoT/short delivery never overcredit. |
| S1-A45 | MAT.EndpointCapacityDomain | Canonical below/equal/interior/equal/above principal/costs and specified type/capacity failure classification. |
| S1-A46 | INV.AdversarialOwnershipSequences | Exact ownership/supply predicates across first deposit, donation, entries/exits; separately track market effects. |
| S1-A47 | DEP.InstanceIsolation | Shared facets do not share instance book, domain, approvals, position or initialization state. |
| S1-A48 | GAS.RuntimeSize | Every shipped facet/package/linked runtime within normal limits; configured compiler/settings unchanged. |
| S1-A49 | NAT.PairedInputRefund | Exact msg.value maximum, pre-maintenance reservation, unused-only refund and rollback on rejection. |
| S1-A50 | NAT.NativeWrappedEquivalence | Same economics/state from equal initial state; only representation differs across SE/SY. |
| S1-A51 | NAT.ActualProxySettlement | Payable proxy calls, wrapper callbacks, native sync/take/settle and zero-address ERC-20 exclusion. |
| S1-A52 | NAT.ReservationSolvency | Forced ETH, pending funds, refunds and temporary wrapper cannot double-count or create free credit. |
| S1-A53 | NAT.ReceiverBehavior | Ordinary contract receivers work; reentry/rejection cannot escape guard or partial rollback. |
| S1-A54 | NAT.TerminalRestart | Last-holder ETH/token book drained; restart excludes old unsolicited ETH. |
| S1-A55 | CRD.DonationForms | Raw/alias/native vs actual WETH leg correct once; wrong value/token/pool form rejected. |
| S1-A56 | SUR.ReusedTwenty | Exactly five canonical facets/20 selectors; no combined permit duplicate, factory input/cut or duplicate SY token entry. |
| S1-A57 | SUR.FactoryLifecycleAndPermit | Persistent factory interfaces, removed temporary hook, correct shared initialization and real permit behavior. |
| S1-A58 | DEP.NativeContentsOrdering | Wrapped face sorts after other token: pair lookup still works; visible lists stay in face order. |
| S1-A59 | SEC.CallbackReadMatrix | New economic views reject; unchanged basic reserves stay committed; token/static views remain canonical. |
| S1-A60 | NAT.OutstandingSync | Native reset after outstanding ERC-20 sync and ledger attribution of proxy receive; final manager deltas zero. |
| S1-A61 | PRO.FallbackReasons | Each reason has a real reachable fixture or independent unreachability proof; valid full plan always wins. |
| S1-A62 | SEC.NoExecutionRetry | Actual manager/token/wrapper/custody/collection/state/payout failures never become fallback retries. |
| S1-A63 | PRO.ModeAndFinalSale | Minima/ordinary sale failure alone do not switch mode; paired sentinel and raw-ETH output unambiguous. |
| S1-A64 | ENT.CreditDecomposition | G/J/C/incumbent fee separation; addition rounding cost borne by entrant; min against final q. |
| S1-A65 | INV.StableLedgerTerminalReceipts | Categories reconcile; terminal owned receipt paid, unsolicited excluded through restart. |
| S1-A66 | CMP.EmptyAndTinyStates | Empty compound no-op, zero-total-output burn rejects, positive one-sided output and tiny-state accounting hold. |
| S1-A67 | PRO.FullStateAndInvalidation | Protocol fees, crossings, empty words/checkpoints and token/wrapper mutations match or invalidate exactly. Include a later-needed tick/bitmap mutation with unchanged current price; reject before consuming that future action. |
| S1-A68 | SUR.AbsentCapabilitiesAndBindings | No ownership/diamondCut/rescue/ERC4626/excluded integrations; full manifest and binding-sensitive identity. |
| S1-A69 | DEP.ZeroFeesAndConstants | Real registry accepts zero fee IDs; no fee fallback, raw dust, explicit zap args and cached validated metadata. |
| S1-A70 | GAS.DeploymentEnvelope | Supported normal/fallback/native/wrapped boundary combinations fit 11.9M cold call-body gas plus 100k transaction reserve and 5M previews. Previously admitted dense single sales reject early; valid paired fallback remains affordable. Keep normal code limits and test settings; disclose unverified RPC-provider caps. |

### 7.5 Baseline comparison

Read and reuse the existing `test/foundry/spec/pairtoken-baseline/harness/PairTokenTestBase.sol`
and `ScriptedDependencies.sol` before writing comparisons. Fresh real PairToken
instances, no SUT subclass/storage injection/etching; do not edit that shared
harness without explicit ownership coordination.

The four comparison classes are preserved, intentional deviation, unsupported
scope, and new capability. Equal outputs are required only for preserved
behavior. Scripted-manager characterization is not new-family real-manager
acceptance. Expected test differences caused by removed fees/dead shares or
corrected attribution must not be hidden by weakening baseline tests.

## 8. Commands and release gates

These are future implementation commands, not runs already performed. Work from
the repository root and use current `docs/testing/ARTIFACT_BUILDS.md`.

```bash
P=contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken
F=UniswapV4PairTokenStandardExchangeVault
T=test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken

# Example verified increment: list every production source changed in that increment.
python3 scripts/forge-artifacts.py plan "$P/${F}Math.sol" "$P/${F}Planner.sol" --test-root "$T"
python3 scripts/forge-artifacts.py test "$P/${F}Math.sol" "$P/${F}Planner.sol" --test-root "$T" -- -vv

# Final runtime-size evidence for all deployed family components and their dependencies.
forge build "$P" --sizes

# Unchanged baseline regression after its runtime prerequisites are current.
forge test --match-path 'test/foundry/spec/pairtoken-baseline/*.t.sol' -vv

# Artifact-first default hermetic gate.
forge build
forge test
```

Before build, run available LSP diagnostics on edited Solidity. Helper `test`
performs required artifact preparation and selected execution; do not duplicate
it with an identical extra test invocation without a changed input/failure.
Use actual changed source sets, not always the example Math/Planner pair.
No package-specific Foundry profile, cache clearing, force rebuild, optimizer
change, viaIR, lowered fuzz/invariant settings, or oversized-code escape.

Current configuration observed in foundry.toml: solc 0.8.35, optimizer runs 1,
via_ir false, fuzz runs 16, invariant runs 16 and depth 8. Preserve these values
unless a separately approved repository change raises coverage. The large
test gas limit is headroom, not A70 approval.
Follow current compile patience and worktree cache-seeding instructions.
Long commands run asynchronously with completion subscriptions.

If using `scripts/size_oversize_facets.py`, inspect its actual findings:
it is a report tool that exits zero even when oversize entries exist. Its exit
code alone is not a size pass. Include package/linked runtime and relevant
initcode checks, not just a convenient facet subset.

### Compiled NatSpec/selector gate

The committed Crane NatSpec workflow requires the dedicated script plus central
values file, not ad-hoc cast/manual constants. Extend that existing script for
this product, importing actual interfaces and independently checking typed
selectors against emitted/declared values. Run locally with no broadcast:

```bash
NS=lib/crane/scripts/foundry/ComputeNatSpecValues.s.sol
python3 scripts/forge-artifacts.py build "$P/${F}DFPkg.sol" "$P/${F}MoneyFacet.sol" --consumer "$NS"
forge script "$NS" --sig "run()" -vvv
```

The explicit production sources guarantee artifact build roots; a pure script
consumer alone may provide none. Record generated/verified methods, errors,
event topics, interface IDs, and Repo slots in
`lib/crane/docs/reference/CENTRALLY_COMPUTED_NATSPEC_VALUES.md`, then use those
values for @custom tags in production and test infrastructure. Check tag pairs,
composed proxy declarations and manifest closure; no new prose-pinning tests.

Coordinator source checks confirmed `forge-artifacts.py` supports multiple
source arguments (`nargs="*"`), the `plan` action, repeated consumers/test roots,
and forwarding after `--`. This does not claim any shown command was run.
The actual SY helper is
`lib/crane/contracts/protocols/perps/pendle/core/StandardizedYield/SYUtils.sol`;
its checked single-word multiplication domain is separate from wide valuation.

### Release evidence required

- Fresh runtime artifact provenance for actual deployed creation code.
- Independent selector manifest and all real registered-proxy interfaces.
- A01-A70 ledger with suite/case, command, output and exact observation.
- Configured fuzz/invariant runs/depth preserved; no timing sleeps or prose tests.
- All normal deployment runtime/code-size limits, not test overrides.
- Explicit deployment-chain/transaction/read-gas envelope and worst-case
  measured usage for both candidates and conditional paired exits.
- Targeted registry/shared facet/SY/native/manager regressions and the current
  default hermetic integration gate; explain pre-existing failures separately.
- No operator/upgrade/rescue backdoor and no changed baseline or unrelated family.
- No `new` for production deployments: CREATE3/FactoryServices and registered
  package/registry deployment remain mandatory.
- Worst-case `previewWithdrawalMode` and `previewRedeemPair` read gas measured
  against the chosen RPC eth_call budget, not just transaction gas.
- Compiled NatSpec output/central values and product/test tags agree.

**Approved release envelope:** Ethereum, Base and Robinhood share the 12M
transaction engineering ceiling and 5M local preview ceiling in S1-GAS-01.
Actual production RPC providers remain unspecified; their availability/read caps
must be reported as unverified, not invented. The configured test gas limit is
never evidence of feasibility. This owner-approved revision replaces the failed
512/1,024-step operational domain; no further hidden cap or economic change is
authorized. A test exceeding the engineering envelope requires tightening the
documented work limits or an explicit further owner decision.

## 9. Adoption choices, disagreements, and handoff

- Adopt Astra's explicit 60-selector split, delegatecall-safe bindings,
  guard-first SY wrappers, late wide-result narrowing, and real fixture controls.
- Adopt Kimi's memory-state/ledger and real-manager differential coverage;
  correct its work-limit narrowing to the PRD's **whole normal candidate**.
- Adopt useful MiniMax stage/test and signed-ledger decomposition. MiniMax
  withdrew its alleged baseline principal-sign defect and agreed to late
  narrowing. Do not conflate its explicit rejection of duplicate SY token
  selectors with duplicate routing across its proposed Execution/SingleToken
  facets. This plan chooses one owner per selector and orders real-proxy tests
  after a deployable implementation; that is a dependency correction, not a
  claim that MiniMax proposed no-op implementations. The generic package
  Behavior assumption is resolved by the coordinator's source search and the
  local Behavior plan, not by attributing an invented WideMath import.
- Grok's available original supports real fixtures, bounded planning and exact
  residue/fee handling, but missing middle sections are not inferred or credited.
- No new product economics, oracle, paired-only scope reduction, unconditional
  collection-only exit, or fee/dead-share policy is selected by this plan.

At implementation handoff report exact files, architecture/binding decisions,
PRD comparison classes, artifact commands, runtime sizes, measured gas envelope,
all 70 acceptance observations, and any blocking gap. Identify the reusable
stage-one paths for later reserve-ledger work without implementing that stage.

The original available advisory passes are complete. Their corrections are resolved in
the council run's `coordinator/resolution.md`; the frozen reviewed draft remains
unchanged. This published plan is a coordinator revision after review, not a
new member-approved round. The original council publication performed no builds
or deployments. The 2026-10-29 bounded-execution amendment is separately owner
authorized; its implementation evidence belongs in the adjacent execution report.
