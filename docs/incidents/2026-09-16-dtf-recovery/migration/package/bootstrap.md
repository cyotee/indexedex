# Migration DETF bootstrap implementation contract

Date: 2026-11-10. Status: source-backed preflight proposal, not implementation acceptance.

## 1. Scope and evidence notation

Read the complete main-checkout `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` (647 lines), the complete phase-03 brief, applicable repository rules, canonical Crane architecture/deployment/testing skills and IndexedEx testing/product law. The plan's MIG-P06/P08/P11/P13, E4, sections 4.1/5.2/5.5/6, task 3 and example 8.1.10 govern this contract. Migration overrides ordinary first-personal-bond startup only in its distinct package.

Paths below are relative to `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`, unless explicitly absolute. For compact exact source locators:

- `D` = `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf`
- `W` = `contracts/hooks/uniswap/v4/standardExchange/weighted`
- `B` = `contracts/vaults/detf/common/bondNft`
- `S` = `contracts/vaults/detf/common/claimToken`
- `C` = `contracts/vaults/detf/common/core`
- `M` = `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration` (proposed)

All numbered implementation steps below are **proposals**, not descriptions of shipped behavior. Source observations are confined to section 2. No executable checks ran.

## 2. Observed contracts and failure mechanisms

| Boundary | Exact inspected source | Observation |
| --- | --- | --- |
| Inert parent | `D/UniswapV4DetfRepo.sol:105-117` | Core initialization sets `isReserveLive=false`, `lastExpansionTimestamp=0`. Wired children do not imply funded reserves. |
| Reserve identity | `D/UniswapV4DetfProcessArgsLib.sol:25-68`; `D/UniswapV4DetfDFPkg.sol:223-279` | Exactly one unbuffered self-leg; the parent must occur once in hook tokens and be the hook's owner. Other legs have SE bindings; preserve opening/creation rates, decimals and route tables. |
| Child wiring | `D/UniswapV4DetfDFPkg.sol:305-320`; `D/UniswapV4DetfTarget.sol:816-857` | Post-deploy wires the bond child, staking child and SY wrappers. `initializeReservedBondNfts` is separate from personal issuance. |
| Reserved IDs | `B/DETFFundedBondTarget.sol:82-92`; `S/DETFFundedStakingRepo.sol:54-67` | IDs 0/1/2 are minted for protocol/fee/creator roles. This initializes neither purchased principal nor staking gons nor standing reward weight. The staking index starts at `1e36`. |
| Ordinary bootstrap | `D/UniswapV4DetfTarget.sol:576-595,632-695` | First bond mints `G` into liquidity, joins the complete book, sets liveness/clock, **then also** opens personal principal and distributes the ordinary bond reward pot. Calling this path with a fictitious recipient would invent an economic bond. |
| Seed sizing | `D/UniswapV4DetfCommon.sol:265-288`; `D/UniswapV4DetfTarget.sol:859-865` | Opening self-leg is `floor(nativeToWad(pair,payment)*1e9/opening)`, with creation-price fallback. Other first-bond payments are derived from that `G` and their configured opening prices. A raw anchor uses actual consumed payment, not a second post-deposit liquidation quote (`D/UniswapV4DetfTarget.sol:610-615`). |
| Donation deadlock | `D/UniswapV4DetfTarget.sol:731-776`; `B/DETFFundedBondTarget.sol:317-379` | Parent donation forwards donor identity to the child. Child checks live/enabled; its callback also requires a live parent. Neither reaches an empty reserve. Child preview returns zero before live (`B/DETFFundedBondTarget.sol:304-314`). Merely removing one live check is insufficient. |
| LP destination | `D/UniswapV4DetfCommon.sol:95-104,451-463` | Joins send net LP to the wired bond child. Protocol-owned LP counts child plus parent custody, not externally owned fee/seed LP. |
| Hook startup | `W/UniswapV4StandardExchangeWeightedBufferHookInitTarget.sol:53-94`; `W/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol:219-246,345-348` | Hook deployment does not initialize PoolManager doors. Open every unordered product pair, then finalize to install production facets. Door initialization is distinct from reserve liquidity. |
| Full-book intake | `W/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:143-149`; `W/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:236-252` | Address-array genesis join requires every hook leg. Hook live means positive LP supply plus full book. |
| Actual buffering | `W/UniswapV4StandardExchangeWeightedBufferHookLiquidityLib.sol:169-237,473-520` | Genesis converts raw external legs into SE shares and redeems a bootstrap portion; even shares supplied directly can require redemption. LP minting uses native inventory components, not DETF principal or provider-rate valuation. Minimum-liquidity LP is minted to zero, usage-fee LP to oracle `feeTo`, net LP to the supplied recipient; residual components return to the join caller. |
| Native boundary | `W/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol:380-400`; `W/UniswapV4StandardExchangeWeightedBufferHookInitTarget.sol:83-91` | Zero-address currencies are rejected. Existing parent donation/exchange functions are nonpayable (`D/UniswapV4DetfMaintenanceTarget.sol:31-33`; `D/UniswapV4DetfExchangeTarget.sol:11-22`). Native ETH needs a WETH adapter, not an ETH PoolKey. |
| Empty reward failure | `D/UniswapV4DetfCommon.sol:314-327,349-385`; `C/DETFFundedStakingMath.sol:79-94` | Expansion is computed from live reserve, supply and elapsed eight-hour epochs without checking reward weight. Nonzero funding with `totalGons+feeWeight+creatorWeight==0` reverts `MissingRewardWeight`. Seed `G` gives nonzero DETF supply but no staking weight. |
| Settlement ordering | `D/UniswapV4DetfMaintenanceTarget.sol:16-28`; `B/DETFFundedBondTarget.sol:46-49,95-128` | A wired child's synchronization callback returns zero while the parent lock is held. The parent must settle **before minting**; child synchronization does not repair missing parent settlement. Child funding already enforces exact DETF receipt and exact credited gons. |
| Reward destinations | `S/StakedDETFTarget.sol:165-181`; `S/DETFFundedStakingRepo.sol:187-206` | Ordinary distribution immediately issues fee/creator sDETF. Stage 1 cannot reuse that destination behavior unchanged. |
| Residual danger | `D/UniswapV4DetfCommon.sol:483-546`; `D/UniswapV4DetfMaintenanceTarget.sol:45-66` | Ordinary sweeps inspect whole parent balances. Migration also holds staged legacy recovery assets, so those balances cannot all be treated as free donation inventory. |

Underlying liquidity is a separate prerequisite. The existing real V3 fixture explicitly seeds its pools and activates SE positions before DETF one-token deposits (`D/TestBase_UniswapV4Detf_Weighted_Univ3Se.sol:47-69`). `D/UniswapV4DetfProductionSeDeployLib.sol:349-414` distinguishes pool seeding, position-vault funding and externally held seed shares; its WETH branch actually wraps ETH. These are fixture references, not permission to mint actual recovery assets or assume live pools are seeded.

## 3. Smallest coherent Migration-only bootstrap

### 3.1 Callable and storage contract

Use a retained Migration funding/maintenance facet, not the removable entitlement facet:

- `donateMigrationCapital(tokens[], amounts[], nativeAmount, minLpOut, deadline)` payable: permissionless exact-pull donation into fixed parent custody; bounded by installed route/token count. Before live, require `minLpOut=0`, book capital and return zero LP. After live, join only the current batch's measured budget, enforce `minLpOut`, and retain refunds as pending donation inventory; old pending balances are not implicitly another caller's input. Reject duplicate inputs and invalid routes. Require `msg.value == nativeAmount`; wrap that amount using the instance's immutable configured WETH, which must resolve to an accepted donation route. No beneficiary, supplied credit, arbitrary target, pretransfer flag, personal bond or allocation configuration.
- `bootstrapMigrationReserve(legs[], anchorIndex, minLpOut, deadline)`: permissionless, once by existing `isReserveLive`; each leg selects a supported token, an amount from **booked donated inventory**, and a minimum converted-share output. Require precisely one selected representation for every external hook leg, unique canonical bindings, plus the internally generated self-leg. `anchorIndex` chooses an offered external leg, as ordinary first-bond input already does; it supplies no price or mint amount. Amounts cannot exceed their booked budgets.
- A public read of pending donated inventory and bootstrap result; emit per-token actual receipts/consumption/refunds, `G`, and net LP received. Use a Migration bootstrap event, not `ReserveLive(tokenId,shares)` with a fabricated personal token ID.
- After live, retain all-leg donations and ordinary live child donation/Permit2 routes. The batch route joins only selected donated budgets through the existing host ABI, returns **all outputs to protocol custody**, and mints no new self-leg. Child-first donation callbacks retain their actual caller checks. Do not advertise pre-live child donation success until a separate child adaptation exists; pre-live funding uses the explicit parent route above.

Store only bootstrap-specific accounting in `M/UniswapV4DetfMigrationRepo.sol`: immutable `weth`, `pendingDonation[token]`, cumulative measured donation receipts, consumed donation inputs, conversion outputs/residuals, and cumulative `bootstrapSelfMinted`. Existing parent `isReserveLive` and `lastExpansionTimestamp` remain authoritative. Do not add `fundingComplete`, a configuration-finalization flag, an entitlement balance or a user LP ledger. Receipt/consumption events can carry cumulative reconciliation history; do not duplicate reserve balances in another pricing ledger.

Separate donated inventory from legacy custody/undonated harvest balances, new principal temporarily in transit, unsolicited transfers and staking backing. Explicit donation receipts create budgets; a direct token transfer is not a new caller's deposit. A typed owner harvest operation can move its measured recovered amount from recovery custody accounting into the donation budget exactly once; it cannot infer newly received proceeds from total balance.

### 3.2 Atomic initialization algorithm

1. Verify deadline, enabled registry state, complete child wiring, correct hook owner/self-leg, finalized product doors, empty hook LP supply and parent not live. A partial prior **funding** transaction is allowed; a partial pre-existing **reserve** is not silently adopted as genesis.
2. Donations may arrive in separate transactions, including one leg only. Book measured input without minting DETF or attempting an incomplete first join. A failed later bootstrap leaves earlier donated inventory intact; an atomic funding batch failure reverts that batch.
3. Bootstrap spends only the selected pending budgets. For each raw/other accepted SE input, use the declared immutable route and `ExchangeInAmount.exchangeResult/requireReceipt` to measure input consumed, returned input and actual shares. For direct SE shares, record the exact held amount and obtain canonical pair equivalence using `_pairEq` **before** mutating that SE. For any other input, preview the SE receipt, compute canonical equivalence on its predicted **consumed** quantity before conversion, and require the measured consumed quantity to match that preview; otherwise revert the attempt. Never size self supply from refunded input. Use the current first-bond raw-anchor rule: its payment is actual consumed raw canonical pair, not redemption value after deposit. Refactor the narrow receipt-acquisition helper if useful, but do not reuse its refund-to-`msg.sender` behavior. These receipt operations are grounded in `contracts/utils/ExchangeInAmount.sol:15-38,50-84`; pair conversion is `D/UniswapV4DetfCommon.sol:170-180`.
4. Compute `G` from the selected anchor's actual payment at the configured opening/creation fallback, reusing `_openingBondQuote`; require positive `G`. For each other leg, require positive acquired inventory and pair-equivalent supplied capital at least `_firstBondOtherPayment(G,pair)`, using consumed raw payment for canonical pair inputs and the pre-conversion canonical equivalence for share/other inputs. Selected excess is an explicit donation, not additional principal or another self-leg mint. Unselected balances remain pending. This preserves the existing anchor/opening sizing rather than inventing an ETH/DTF funding split, minimum-leg valuation formula or new seed price. It does not promise that fees leave the final book at an exact quoted spot ratio.
5. Mint **only `G`** to the parent. Join `[parent self-leg G, acquired shares for each external leg]` with the existing full-book `joinUnbalanced` host ABI, recipient fixed to the bond child. Supply the caller's actual minimum/deadline rather than the ordinary helper's hard-coded minimum zero and `block.timestamp+1`. Measure the child's net LP delta and enforce the minimum. Preserve hook minimum-liquidity and usage-fee LP mechanics.
6. Require actual hook `isLive()` and positive net LP custody before setting parent live. Book returned raw/share components as protocol donation residuals. Retain them; never send old pooled donations or harvest balances to the bootstrap caller. Clear every temporary allowance. Set `lastExpansionTimestamp=block.timestamp`; emit bootstrap/accounting events. No `_openBondNft`, `_splitBondDetf`, duration bonus, user mint, `p*G` reward pot or entitlement issuance occurs. Those belong to ordinary purchases, not donations.
7. Missing leg, dust-sized seed, zero conversion output, unavailable SE redemption, short receipt, failed join/minimum or callback mutation reverts the whole attempt, including `G` and any conversions. Reserve live cannot survive an unsuccessful first join. Repeating bootstrap after success reverts; corrective funding thereafter uses donations.

Genesis buffering still redeems part of every acquired SE leg (section 2). Pre-wrapping into shares is **not** a workaround for an empty/unusable underlying pool. Choose no fictitious LP provider or pool seed here: production deployment must supply independently evidenced underlying liquidity and attribute its actual ownership.

### 3.3 Native ETH/WETH and reserve wiring

Add WETH only to Migration interface-owned arguments/storage/salt material; preserve ordinary base arguments. The payable donation wrapper calls canonical `IWETH.deposit{value:nativeAmount}()` and verifies its WETH balance increased exactly by that amount. The method is declared in `lib/crane/contracts/external/balancer/v3/interfaces/contracts/solidity-utils/misc/IWETH.sol:10-15`, re-exported at `lib/crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol:4-11`. It may combine with explicit ERC-20 WETH in the same batch only with separate measured receipts and no double credit. Reject nonzero value on nonnative routes and do not sweep pre-existing ETH as this call's contribution. Do not add a general ETH forwarding/withdrawal route.

The weighted book remains `[new DETF, canonical WETH/pair tokens]`, with configured SE/provider bindings. PoolManager doors use those ERC-20 currencies; no zero-address native leg. Follow `D/TestBase_UniswapV4Detf_Weighted_ProdSe.sol:106-162`: predict the owner-aware Migration address, deploy the hook with that address as owner/raw self-leg, open all three doors for three tokens (all `n*(n-1)/2` generally), finalize, then registry-deploy the parent and children at the predicted identity. Ownership-lane salt/registry design is a dependency; do not transplant the ordinary salt unchanged.

V4 doors are swap doors into hook custody, not concentrated-liquidity positions funded by this bootstrap. Hook LP, underlying SE shares/positions and any external underlying-pool seed are three different ownership domains. Preserve owner-only reserve liquidity policy; the hook owner is the **parent**, not its human owner. Current fee-collector LP removal is a separate existing allowance (`contracts/hooks/uniswap/v4/libs/UniswapV4HookOwnerOnlyLiquidityLib.sol:16-29`).

### 3.4 Supply and asset reconciliation

Immediately after bootstrap, before any compensation:

```text
new DETF totalSupply = bootstrapSelfMinted = G
personal bond principal = sDETF totalSupply = totalGons = 0
feeWeight = creatorWeight = accountedBacking = 0
personal NFT count = 0; reserved role NFTs = IDs 0, 1, 2
hook LP totalSupply = locked minimum LP + fee LP + net child LP
protocolLp = child LP + parent LP; exclude external fee/seed LP
```

Include any prior balances explicitly rather than asserting the last LP equality outside a clean genesis fixture. For every token reconcile `received + conversionOutputs - conversionInputs - acceptedHookInputs = remainingDonationInventory`; classify hook/SE refunds in the token actually returned. SE fees are conversion costs, not missing capital. Reconcile LP mint events and custody deltas separately from DETF mint events. No configured or merely quoted entitlement contributes supply.

Subsequent successful delivery of credit `P` mints exactly `P`, transfers/stakes exactly `P`, creates one fresh bond, and increases child attributed gons by exactly `P*currentGonsPerUnit`. Migration delivery does not replay ordinary self-leg or inventory issuance. Total supply thereafter reconciles separate bootstrap, actually delivered principal, ordinary postactivation issuance, actually funded reward mints and burns.

Replace Migration dust entrypoints and override its internal `_trySweepDust` use with **budgeted donation-residual** joins. Do not install or reach the ordinary whole-balance sweep body on Migration proxies. Ordinary code's global hold-reserve synchronization is not authorization to spend legacy custody; add budget checks at every residual join/convert boundary. This applies after activation too. Never broaden the child donation callback's authority or use a generic self-call executor.

## 4. Empty baseline and first-funded-position ordering

**Migration-only extension:** add one narrow virtual reward-weight predicate to `D/UniswapV4DetfCommon.sol`, ordinary default true. Use it consistently in `_pendingExpansionDetf` and `_realizeExpansionIfNeeded`; Migration reads the real staking child's `stakingState()` and returns whether `totalGons+feeWeight+creatorWeight != 0`. The existing fields/API are at `S/StakedDETFTarget.sol:52-58`; no new staking ledger or fictitious standing weight is needed.

For a live Migration instance with aggregate weight zero:

- Pending expansion is zero in all previews, including `previewStakingGonsPerUnit` (`D/UniswapV4DetfQueryTarget.sol:31-41`) and synthetic/burn preview supply projections.
- Settlement sets `lastExpansionTimestamp=block.timestamp` and returns zero **before** the existing completed-epoch early return. Do not mint, call `fundRewards`, queue rewards as dust, or defer an empty-period pot to the first depositor.
- The first actual participation-changing transaction performs this settlement under the parent lock before mint/stake. Reset to the exact timestamp, not merely the last completed boundary: otherwise a funding-period fractional epoch can become the first participant's elapsed epoch.
- Once any aggregate weight exists, retain the existing eight-hour math, highest-synthetic-price selection, completed-boundary advancement and funded distribution. Zero ordinary gons with nonzero standing weights is **not** the empty case; preserve fee/creator participation.

The ordinary default predicate and ordinary epoch behavior remain unchanged. `DETFEpochNaturalExpansionLib` and `DETFFundedStakingMath._allocate` need no global semantic change.

Every parent issuance path (independent execution and eventual surrender) must use this order:

1. Validate protected operation, require live reserve and complete child wiring, and enter shared parent lock. Funding must precede issuance; do not add a separate funding-certification flag.
2. Settle old participation using `_realizeExpansionIfNeeded`, before changing DETF supply, gons or principal.
3. Mint exact delivered principal, approve only it, call parent-only `createMigrationPosition(P,recipient)`, with its child-enforced fresh 90-day terms; clear approval.
4. Reuse the real child's exact pull/stake/gons checks; commit issuance/consumption/custody atomically. Child callbacks under the parent lock may no-op exactly as they do now; they are not settlement.

Apply the predicate through the actual compiled Migration facets, not just a new facade: ordinary facets embed their own inherited common code. Migration maintenance, exchange/bond and query compositions must inherit the same Migration policy override wherever they settle/project expansion. Ordinary issuance is closed in Stage 1 even after `isReserveLive=true`; gate parent mint-to-DETF, mint-to-sDETF and bond/reserve-LP purchase routes before primary-versus-swap selection (`D/UniswapV4DetfTarget.sol:200-226,261-279,527-552`). SY routes that delegate to those paths must not bypass it. No bootstrap route calls a gated purchase to obtain its self-leg.

The child/reward lane must retain fee/creator allocations under protocol custody with their economic attribution; simply sending receipts and blocking redemption is insufficient. This report supplies baseline/order requirements, not that payout implementation. Preserve mature principal rights during a prolonged Stage 1.

## 5. Proposed minimal edit boundaries

| Paths | Bounded change |
| --- | --- |
| `M/interfaces/IUniswapV4DetfMigration.sol`, `M/interfaces/IUniswapV4DetfMigrationDFPkg.sol`, `M/UniswapV4DetfMigrationRepo.sol` | Funding/bootstrap tuples/events/errors, immutable WETH, separate donation budgets and supply counters. No affected fungible ancestry tuples. |
| `M/UniswapV4DetfMigrationTarget.sol`, `M/UniswapV4DetfMigrationFacet.sol` | Retained funding/bootstrap and budgeted residual implementation; private/internal shared funding-to-bond ordering used by both issuance families. |
| `M/UniswapV4DetfMigrationDFPkg.sol`, `M/UniswapV4DetfMigration_Component_FactoryService.sol`, `M/UniswapV4DetfMigration_Pkg_FactoryService.sol` | Ownership-lane composition: register funding selectors and Migration policy-bearing ordinary-route facets, configure native asset once, preserve immutable child wiring and no restoration. |
| `M/UniswapV4DetfMigrationPolicy.sol` (new narrow internal mixin), Migration maintenance/query/exchange/bond facet implementations under `M/` | Reuse ordinary targets where possible, overriding the common predicate and residual policy; actual installed facets must compile with the override. This mixin contains no alternate pricing, staking or epoch algorithm. |
| `D/UniswapV4DetfCommon.sol` | Narrow virtual aggregate-weight policy seam in preview/settlement and virtual internal residual dispatch, ordinary behavior unchanged. Do not copy the full common stack. |
| `D/UniswapV4DetfTarget.sol` only if needed for receipt-helper reuse | Extract first-bond measured conversion from refund destination policy; default ordinary refund remains unchanged. The Migration implementation must retain refunds. Do not globally remove live gates or alter ordinary bond splits. |
| `M/bondNft/*` and Migration staking/reward composition | Child lane owns `createMigrationPosition`, exact funded cliff and retained reward destinations. Bootstrap depends on these children, not an ordinary-child placeholder. |
| `M/TestBase_UniswapV4DetfMigration.sol`; `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationFunding.t.sol`, `MigrationRewardBaseline.t.sol` | Real manager/registry/proxies, weighted hook, fee oracle, backing/staking/bond children, real WETH and live production SE integrations. |

No shared Crane edit, pricing-worktree edit, global reward-math rewrite, source adapter or new generic router is proposed. Parent issuance helpers and final policy facet filenames must be reconciled with the ownership/children lanes before a source increment; these are required composition edits, not optional follow-up hardening.

## 6. Failing-before real-proxy tests and exact oracles

These are **specified, unexecuted** regressions. Deploy fresh real instances through registry/factories. Do not call implementations as the SUT, impersonate the parent to seed reserves, inject storage, etch the SUT or mock the reserve/children/oracle. Existing fixtures are behavioral references, not permission to copy their unrelated `etch` setup.

| Case | Failing-before witness and required post-change oracle |
| --- | --- |
| Empty donation startup | Ordinary donation reaches `ReserveNotLive` in the observed child/parent chain. Migration funding plus complete bootstrap succeeds with live quoteable reserve, exact `G` supply, only IDs 0/1/2, no sDETF, no personal credit, and all ordinary new-money routes still reverting. |
| Partial then corrective all-leg funding | Donate only one external leg: exact pending budget, supply/LP zero, live false. Incomplete bootstrap reverts without consuming earlier funding. Supply missing leg later; complete bootstrap succeeds exactly once. A second bootstrap fails unchanged; subsequent corrective batch donation raises protocol reserve holdings without new `G`/personal principal. Ordinary donation cannot perform the initial partial booking. |
| Receipts, refunds and custody isolation | Overfund one leg; verify selected excess is donated, unselected input remains pending, and every SE/hook refund remains protocol inventory. Prefund unrelated legacy custody and unsolicited balances; assert neither is credited as this receipt, used as principal nor swept by another donor/caller. A callback or second-leg failure reverts the whole selected attempt, including any self mint. |
| Native route | Equivalent fresh ETH-wrapped and ERC-20-WETH cases produce identical WETH budget/conversion/LP accounting under identical state. Measure native spent, WETH minted and SE inputs separately. Wrong `msg.value`, unsupported WETH binding and unfinalized doors fail before live. Existing nonpayable entry cannot accept this native call. No ETH currency is installed in a door. |
| Supply and ownership | Sum DETF Transfer mint/burn deltas and reconcile `G`, principal and rewards separately; reconcile hook LP supply against locked minimum, fee LP and child net LP. Donor has no LP/NFT right. Deliberately nonzero usage fee exercises external fee LP rather than assuming protocol owns total hook supply. |
| Underlying readiness | Open doors but leave a required SE/pool unready: bootstrap fails atomically without live/supply. Fund a real underlying pool/position through its production entrypoints, explicitly record seed share holder, then bootstrap successfully. This distinguishes door initialization from capital availability. |
| Immediate first issuance | Execute a real configured independent allocation through the parent at bootstrap timestamp. Exact `P` mint/backing/gons, fresh ID 3 and creation timestamp, 90-day cliff, reward preview zero; no seed reward pot or preminted entitlement. Do not expose a test-only arbitrary-credit issuer. |
| Delayed first issuance | Use rich live reserve large enough that the ordinary epoch formula would produce more than dust, but keep aggregate weight zero. Warp to `bootstrap+8 hours`, `+25 hours`, and `+7 days` in independent deterministic cases. Pending reward/index previews return zero; permissionless synchronization and actual independent issuance succeed without `MissingRewardWeight`, reward mint or precreation reward credit. Existing common settlement attempts nonzero allocation into zero weight. |
| Fractional empty interval | First issue at `bootstrap+8 hours+1 hour`; assert baseline equals **issue timestamp**. At `issue+8 hours-1` no expansion; at `issue+8 hours` compare exact canonical funded formula using actual supply/highest synthetic price. Prevent a completed-boundaries-only fix that grants the earlier hour. |
| Existing participant before second issuance | Issue A, cross a due boundary, then issue B. Calculate one canonical distribution on supply/weights **before B mint**, assert A's gons/index and retained role allocations; B starts with exactly `P_B*postSettlementIndex`, rewards due zero. An implementation relying only on locked child synchronization fails to settle A. Repeat via a later surrender once its verified source adapter exists. |
| Standing weights and payout closure | After real participation creates standing weights, zero ordinary balances must not suppress their funded entitlement. While Stage 1, fee/creator recipients receive no reward receipts; activation preserves/releases attributed rights exactly once. This is child-lane integration, not satisfied by a baseline-only test. |
| Actual installed routes/regression | Loupe every funding and policy selector on the registered parent/children; test exchange-to-DETF/sDETF, reserve-LP bond, SY forwarding and direct child callbacks. Run ordinary weighted and common funded-bond/staking suites unchanged to prove the default seam preserves ordinary behavior. |

Use fixed `vm.warp` boundary cases, exact integer amounts and receipt deltas, not sleeps or a claim that exit zero means tests executed. For each new regression record the old failure or observable mismatch, then the passing behavior; not merely absence of a new selector. Some precursor assertions already pass on ordinary products and serve as controls, not claimed new red tests.

Later execution: seed warm `out/` and `cache_forge/`, artifact-first Solar build, then focused Migration funding/baseline specs and ordinary `.../v4/detf/**` and `.../common/**` regressions per plan section 10. Require real executed PASS counts and exit codes. No build/test result is claimed here.

## 7. Dependencies, limits and cleanup

- **Independent bounded work:** donation budgets, receipt-backed bootstrap, native wrapper, empty-weight policy seam and real-proxy baseline tests do not require a fungible attribution design. Phase-one canonical verification section 6 expressly permits this package/bootstrap work.
- **Composition prerequisite:** ownership lane must supply final registry/package/owner-aware prediction and actual Migration children; child lane must supply cliff issuance and complete reward retention/gating. A bootstrap-only package is not E5 closure. Native WETH must be part of immutable arguments and address prediction; actual recovery WETH identity and funding amounts remain execution inputs, not approvals made here.
- **Pricing prerequisite:** phase-two changes are not integrated in this worktree. `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-02/docs/incidents/2026-09-16-dtf-recovery/migration/pricing/evidence/verification/report.md:1-7,83-110` confirms only bounded direct-pair/V3-input/raw-output evidence and withheld overall acceptance. Quoteability here does not establish actual-route E3 or authorize snapshot/configuration loading. Do not depend on independently pending F1/F2 corrections.
- **Source prerequisites:** authenticated fungible ancestry, TokenStaking atomic claimant handoff and restricted legacy LP harvesting remain unresolved as recorded in `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/phase01-verification.md:93-180,306-329`. No fungible tuples, trusted allowances, original-payer policy, pretransfer or two-step claim substitute is frozen here. Actual-source surrender/recovery tests cannot yet all be implemented compliantly. Underlying SE/pool redemption readiness requires explicit real-route evidence.
- **Inspection evidence:** LSP document symbols succeeded for the parent and weighted liquidity library; a subsequent LSP reference lookup resolved parent expansion callers in maintenance and mint/stake/unstake/burn/bond paths. Initial definition/reference requests returned `analysis inputs changed since request`; no clean diagnostics result is claimed. Source was inspected with `read`; literal searches located routes. No external documentation, historical-runtime equivalence or live-chain observation is asserted.
- **Cleanup:** none created: no owned process, node, endpoint, runtime cache or temporary directory. Only this named report was authored with `apply_patch`. Shared Crane was read-only. No source/test/script/config edits, builds, tests, Git operations, installs, broadcasts or delegation occurred. Tool-host transcript artifacts are not task-created runtime resources and were not modified or deleted.

**DoneClaim:** This report establishes one bounded implementation contract: book real donated capital, construct the canonical full-book reserve with separately accounted self supply and no personal bond, preserve fixed protocol liquidity custody/residuals, and settle a zero-weight baseline before any fresh exact-funded principal. Source anchors, minimal edit boundaries and failing-before test oracles are specified. E4/E5 and task 3 remain unclosed until implementation and real-proxy verification; E1/E2/E3 limitations remain explicit. No owner-policy decision or numerical recovery allocation is made.
