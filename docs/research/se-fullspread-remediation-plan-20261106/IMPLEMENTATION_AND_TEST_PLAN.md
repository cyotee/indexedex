# FullSpread SE hooks - Implementation and Testing Plan

## TL;DR (For humans)

Status: completed against the recorded FS-OWN-36/37 decisions and source-backed self-review. No owner decision remains pending. This is an implementation/testing plan, not executed work or deployment authorization.

Implement the updated FullSpread PRD across all seven SE Vault Hook types. LP-bearing hooks use actual SE-share and locally booked pair-token components for joins and exits; swaps use local pair tokens plus rated SE backing, with local-first output. Handle SE refunds and disabled vaults without losing ownership attribution or forcing prohibited cleanup deposits. Remove the SE `asset()` dependency and rebuild the FullSpread fixtures around valid paired-token bindings and implicit own-share processing.

The non-CP `single/` product is a conversion hop with no Hook LP supply. It receives custody, refund, disablement, membership, and settlement changes, not an invented LP product. Every other family receives the complete component-based liquidity adaptation.

The plan contains four implementation waves with 20 implementation/testing tasks and four final-verification tasks. It covers all 48 PRD acceptance rows and all 36 originally supplied failing instances. FS-OWN-36/37 replace the former fee and genesis alternatives; no decision is deferred to the implementer.

Effort: XL. This is a cross-family accounting change, not a test-message patch. Writing this plan does not authorize deployment, registry migration, deletion of deprecated contracts, or Git operations.

## Scope

### Affected user and ideal state

| ID | User and required outcome | Gap addressed |
| --- | --- | --- |
| IS-1 | LPs receive proportional claims on actual assets without rate-driven issuance or another caller's residual windfall. | Separate component books and all join/exit aliases. |
| IS-2 | Swappers get the quoted local-plus-rated curve, paying output locally before redeeming an SE deficit. | Swap reserves, projections, local settlement, disablement. |
| IS-3 | LPs can complete permitted pair-token withdrawals when an underlying SE is disabled. | Remove cleanup deposits; keep remaining holders' ownership intact. |
| IS-4 | Integrators bind pairToken through vaultTokens(), while own SE shares remain implicit supported assets. | Remove asset probes and invalid self-membership fixtures. |
| IS-5 | Every hook topology and facade follows the same accounting contract without erasing family-specific swap curves. | Seven-family edit map and route matrix. |
| IS-6 | Reviewers can trace the 36 reported failures and all 48 acceptance rows to executed assertions. | Rebuild positive fixtures, preserve negatives, publish exact evidence. |

### Authority and boundaries

The sole requirements authority is:

`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`

Read its latest FS-OWN-34 through FS-OWN-37 decisions, FS-HOOK-05 through FS-HOOK-10, and FS-A01 through FS-A48. This new plan supersedes conflicting execution instructions in the older co-located implementation-and-test plan for the hook refactor and fixture/test migration. The older council's deliberate-non-pass recommendations are not the current own-share acceptance contract.

Preserve:

- FullSpread's raw-liquidity issuance, 1,000-share floor, clamped usage fee, 49% one-sided input rule, boundary no-swap behavior, and FS-OWN-30 exit receipt.
- Vault execution restrictions, existing deadlines/minima, WETH-only public boundary, owner/operator rules, per-address manager settlement, and immutable package deployment law.
- Family swap curves, amplification/weights, fee configuration wiring, owner-only-liquidity restrictions, and supported facade selectors. FS-OWN-36 replaces growth-based fee issuance; FS-OWN-37 replaces rate-valued or pair-funded Hook LP genesis. Preserve neither superseded numerical behavior.
- Every unrelated workspace change. Before implementation, inventory the working tree and partition owned files; never reset someone else's work.

Do not:

- Use a rate, spot NAV, or sum of incompatible native units to decide LP ownership.
- Restore the deprecated named vault as a fixture dependency or delete its implementation as part of this plan.
- Require `asset()`, a vault's self-address in `vaultTokens()`, or a transition-quote interface on ordinary FullSpread routes.
- Turn every former red test into an expected revert, keep invalid fixture prerequisites, or skip the actual behavior assertions.
- Add a universal replacement hook engine, a vault sleeve, a new provider on FullSpread, a package-specific Foundry profile, or via-IR.
- Upgrade a live immutable hook or migrate registry inventory. Build and test fresh instances; deployment is separate.

### Path legend and implementation inventory

All paths below are repository-relative. A family prefix joined to a suffix denotes the complete filename, not an optional search target.

| Key | Production directory | Filename prefix |
| --- | --- | --- |
| H1 | `contracts/hooks/uniswap/v4/standardExchange/single/` | `UniswapV4SingleStandardExchangeBufferHook` |
| H2 | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/` | `UniswapV4SingleStandardExchangeBufferConstantProductHook` |
| H3 | `contracts/hooks/uniswap/v4/standardExchange/dual/` | `UniswapV4DualStandardExchangeBufferConstantProductHook` |
| H4 | `contracts/hooks/uniswap/v4/standardExchange/orbital/` | `UniswapV4StandardExchangeOrbitalBufferHook` |
| H5 | `contracts/hooks/uniswap/v4/standardExchange/weighted/` | `UniswapV4StandardExchangeWeightedBufferHook` |
| H6 | `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/` | `UniswapV4StandardExchangeCurveQuadStableBufferHook` |
| H7 | `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/` | `UniswapV4StandardExchangeBalancerQuadStableBufferHook` |
| HS | `contracts/hooks/uniswap/v4/libs/` | Shared libraries named below |
| HT | `test/foundry/spec/hooks/uniswap/v4/standardExchange/` | Family test subdirectories mirror H1-H7 |
| VT | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/` | FullSpread regression suites |
| VP | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/` | FullSpread implementation and TestBase |

Mandatory shared touch points:

- `HS/UniswapV4SeBufferHookLegLib.sol`: paired-token validation, implicit share classification, wrapper-probe removal.
- `HS/UniswapV4SeBufferHookContextQuoteLib.sol`: refund-preserving quote results and optional-context fallback.
- `HS/UniswapV4BufferHookLiquidityRouteLib.sol` and `HS/UniswapV4BufferHookLiquidityExecutionBase.sol`: installed-selector/facade routing and bounds; reuse rather than bypass them.
- `contracts/utils/LocalCreditLib.sol`: supply correctly attributed native custody to existing credit arithmetic; do not replace it with rated reserves.
- `contracts/utils/ExchangeInAmount.sol`: current helpers discard refunds. Keep unrelated callers compatible and use refund-preserving tuple reads on the affected paths.
- `contracts/interfaces/IVaultRegistryDisableQuery.sol`: effective address-or-package disable lookup. Do not infer disabled state from a zero preview or catch every vault revert.
- Every family `Repo.sol`, `DFPkg.sol`, installed facets and their linked component metadata where source dependencies change. Append component books and trusted registry awareness where needed; preserve existing slot positions and leave retired fee-only fields reserved if removing them would shift storage. No backfill or migration of live proxies is part of this plan.

| Family | Liquidity and execution files to adapt | Preview/secondary paths to include |
| --- | --- | --- |
| H1 | `Repo.sol`, `Common.sol`, `Target.sol`, `DFPkg.sol` | Four wrap/unwrap quote modes; PoolManager settlement. No LP mint/burn API. |
| H2 | `DepositCommon.sol`, `ClaimLib.sol`, `WithdrawalLib.sol`, `WithdrawTarget.sol`, `SeTarget.sol`, `InExecutionBase.sol` | `DepositProjectionTarget.sol`, `InQuoteBase.sol`, deposit/share/Permit2/single-input aliases, hook SE and Native SY routes. Inspect installed split facets rather than editing only the older aggregate Target. |
| H3 | `Common.sol`, `ClaimLib.sol`, `DepositTarget.sol`, `SeTarget.sol` | `DepositQuoteLib.sol`, `InQuoteBase.sol`, ordinary and flexible joins/exits, sequential and fallback composition. One owner for shared Common and quote files. |
| H4 | `Repo.sol`, `Common.sol`, `DepositCore.sol`, `WithdrawTarget.sol`, `SeTarget.sol`, `ClaimLib.sol`, `HooksTarget.sol` | `DepositTarget.sol`, `DepositZapTarget.sol`, `DepositFlexibleTarget.sol`, `DepositQueryTarget.sol`, `ExitQuoteLib.sol`, `InExecutionBase.sol`, three-leg ordering. |
| H5 | `Repo.sol`, `Target.sol`, `LiquidityTarget.sol`, `LiquidityLib.sol`, `JoinCore.sol`, `ExitCore.sol`, `SeTarget.sol`, `ClaimLib.sol`, `HooksTarget.sol` | Join/Exit Query and Flexible targets, `InExecutionBase.sol`, `InQuoteBase.sol`, `PullLib.sol`, partial books and n=2..8. |
| H6 | `Repo.sol`, `Target.sol`, `JoinCore.sol`, `LiquidityTarget.sol`, `ExitTarget.sol`, `SeTarget.sol`, `ClaimLib.sol`, `HooksTarget.sol` | `ExitExecutionBase.sol`, `ExitQuoteBase.sol`, `InExecutionBase.sol`, quotes in `JoinCore.sol`/`HooksTarget.sol`, fixed-four arrays and flexible/exact-output routes. |
| H7 | `Repo.sol`, `Target.sol`, `LiquidityCore.sol`, `LiquidityTarget.sol`, `ExitTarget.sol`, `SeTarget.sol`, `ClaimLib.sol`, `HooksTarget.sol` | `QueryTarget.sol`, `InQuoteBase.sol`, `InExecutionBase.sol`, `UniswapV4BalancerStableLiquidityUnitsCore.sol`, `UniswapV4BalancerStableLiquidityUnitsTarget.sol`, units interfaces/facets, n=2..5. |

Package validators directly calling `isWrapperShareInventory` exist in H2/H4/H5/H6/H7. Removing only the shared membership shortcut leaves those callers behind. Every such validator and wrapper-decimal exception is included.

### Accounting contract for implementation

Use family-owned books with small shared arithmetic/result helpers. No separate ERC-20 or tradable "virtual LP" asset is introduced. A leg's liquidity coordinate represents its actual component basket; never add native SE-share units to native pair-token units and call that LP value.

For existing supply `T`, caller-owned contributions `a_j`, and pre-intake booked components `B_j`, each positive component limits gross minting to `floor(a_j*T/B_j)`. One common gross `m` must satisfy all components. Accept `ceil(m*B_j/T)` of each component and return unaccepted caller assets; split `m` into depositor net LP and protocol fee LP only afterward. No prior growth-fee mint changes `T`. Zero components are not denominators. Withdrawals allocate `floor(b*B_j/T)` using the actual pre-burn supply, including the locked floor and already minted protocol LP. Apply this across every SE-share, local-pair, and raw leg component.

Maintain separate:

1. Booked hook backing.
2. Current caller-owned conversion/input inventory.
3. Amounts owed back to the caller.
4. Unbooked ambient transfers.

Actual token deltas and the SE tuple determine outcomes. A pool-owned refund increases its local book; a joiner's refund remains caller-owned until the proportional basket is accepted. All snapshots and external calls remain under the existing operation lock. No interim public callback can spend pending assets or observe a usable partially committed reserve.

Swap reserve reads are `localPair + rated(bookedSeShares)`, normalized to pair-token units. Swaps consume local output first; only the deficit triggers permitted SE redemption. LP allocation does not call that reserve function. Keep accounting distinct even where a shared basic-vault reserve view publishes rated values.

Share-requested exit adapters must allocate the local claim as well as the SE-share claim. They may convert only the caller's local claim when the requested output requires it. If that conversion needs a prohibited disabled mint, the requested conversion reverts atomically; ordinary pair-token exits remain available. Never drop the local claim, silently pay an unrequested mixed basket, or weaken a minimum to force success.

### Conversion and settlement sequence

Snapshot actual booked components and supply before intake; do not run a prior-growth protocol mint. Then collect and attribute caller funds. Keep incumbent books unchanged while assembling the caller basket. Retain incoming local tokens where useful, deposit only the caller-owned amount selected for conversion, and attribute actual shares and refunds back to that caller. Redeem only caller-owned shares when local contribution is deficient. Recompute the supported common gross mint from the final actual basket, accept ceil-required quantities, return excess, and split that mint between the depositor and protocol under FS-HOOK-09. Gross shares acquired before a redemption are not the final accepted share contribution.

The acceptance kernel does not require a globally optimal conversion split. Forward-preview sizing is permitted only within caller budgets and only where its assumed monotonicity is established for that supported route. Do not introduce a generic binary-search/exact-output dependency on FullSpread, fabricate a projected state, or use a guessed conversion result to fund the mint. Reuse each family's forward-verified sizing path; if a requested conversion cannot assemble a supported basket, fail atomically rather than spend incumbent assets. The plan's tests must distinguish conversion cost/choice from the final rate-free ownership calculation.

For pool-owned input g with d forwarded to an SE and actual returned input f, local credit is g - d + f; SE-share credit is the actual shares received. For joins and exits, the same receipts remain caller-owned until their respective acceptance/payout step. Replace ambient-balance dust reinvestment with explicitly attributed operation amounts.

For exact-input swaps, preserve the family's curve budget convention: allocate local output against the budget, translate only the remaining rated budget to the existing rounded SE-share spend, and quote that spend with previewExchangeIn(share, shares, pair). The concrete output plan is local payment plus the predicted redemption receipt; execution reconciles actual output and enforces minima. Do not promise that a provider-valued budget equals liquidation proceeds. For a fixed-token-output route, localUsed = min(localBook, requestedOutput); its authorized sizing path must prove the remaining deficit can be supplied, or reject. A local-only settlement must not call the SE's unavailable exchangeOut.

For a pair-output LP exit, payout is allocatedLocal plus actual redemption of allocatedShares. For a share-output LP exit, payout is allocatedShares plus actual shares acquired using allocatedLocal. The second conversion may be unavailable while disabled: in that case the share-only request reverts atomically, while the supported pair-token exit remains available. Cross-leg single-token exits withdraw the component basket before trading it against the remaining pool; pending exit assets are not part of that remaining pool's reserve.

Remove additional dust haircuts from the component entitlement itself. The floor formula and existing locked LP floor already retain rounding residue. A helper returning zero while retaining the caller's allocated shares does not complete a pair-only withdrawal merely because the minimum was zero.

### Zero components and independent oracles

Use native-unit full-width multiply/divide, not WAD fraction truncation followed by descaling. For T>0, a positive component requires ceil contribution; a zero component requires zero and is not a denominator. An all-local leg is live inventory, not an empty leg. An all-zero book with outstanding LP supply is not genesis and must not produce an unlimited mint. A zero-mint operation must not retain caller assets as an involuntary donation.

For every accepted component, check accepted*T >= minted*oldComponent and (oldComponent+accepted)*T >= oldComponent*(T+minted). Maximal issuance from an already assembled basket must have at least one positive limiting component that cannot support one additional LP unit. Example: T=7, C=[11,5,13], available=[5,2,8] gives limits [3,2,4], minted=2, accepted=[4,2,4], returned=[1,0,4]. A burn b allocates floor(b*C/T) independently per component. Different exit orders need not have identical dust; splitting exits must not create additional ownership through rounding.

### Disable authority and passthrough topology

Use a trusted effective-disable authority established by deployment. The canonical FullSpread fixture binds registry and oracle to the IndexedEx manager. Retain that provenance when initializing hook internal registry awareness; H1's feeOracle is zero and cannot be used as an authority. Query isDisabled(se), including package disablement. Neither a failed query, an unknown registry entry, nor a zero preview means enabled. A foreign-authority SE binding requires evidenced authority resolution or an explicit integration limitation; do not add a package field or arbitrary fallback during implementation.

H1 has no LP supply. Keep its conversion-hop topology: track retained, attributed pair/share custody and incoming funds separately, preserve output/credit semantics, and never claim successful disabled wrap without delivering the requested shares. Do not add a synthetic LP, CP pricing curve, or permissionless sweep to reconcile its topology with LP-only matrix rows. Its LP scenarios are explicitly inapplicable; its refund/disable/own-share/settlement scenarios remain mandatory.

### Locked protocol fee: split the backed mint (FS-OWN-36 / FS-HOOK-09)

The owner selected a fee on new Hook LP issuance, not either of the earlier swap-fee accumulation alternatives. Let W = 1e18, g be the gross LP backed by the accepted contribution, and f the active configured WAD mint-fee percentage:

```text
feeLP = floor(g * f / W)
netLP = g - feeLP
total new LP = g
```

Mint feeLP to the live configured fee recipient and netLP to the depositor's recipient. With an inactive fee or zero recipient, feeLP is zero. Skip zero mints. Charge neither the fee LP itself nor withdrawals, transfers, rate changes, yield growth, or swaps that do not issue depositor-funded LP. Normal swap trading fees remain in the pool; the protocol earns its proportional share through its LP holding. Do not add a protocol fee-token reserve, fee-basket conversion, deferred crystallization, or an extra mint on top of g.

Preserve each family's existing fee-configuration source and activation policy instead of adding a new package parameter or selecting a new numerical fee: H2/H3 currently resolve the recipient and WAD percentage through dexSwapFeeAndFeeToOfVault(address(this)); H4-H7 resolve feeTo() and usageFeeOfVault(address(this)). Use the resolved WAD percentage in the mint split, not its older FEE_DENOMINATOR-scaled owner-share intermediate. The names of the legacy accessors do not retain the old growth basis. Preserve Fee Oracle fallback semantics; zero stored configuration means unset, not a new zero-percent override. Do not import FullSpread's 30% vault usage-fee cap into hooks. Validate the already-supported active fee domain and preserve explicit inactive/zero-recipient branches.

Remove all family _maybeMintProtocolFee/_mintProtocolFeeIfNeeded growth issuance calls, projected growth-mint supply adjustments, and fee-only kLast/rootK/feeReserves checkpoints. Inventory every consumer first: retain any invariant or reserve variable still required for swap math, custody, guards, or public views. Do not remove an unrelated trading-fee calculation because it shares a helper. Family views retain their installed-selector contracts but report the new model rather than projecting retired growth minting. No LP may be minted before the incoming contribution is accepted merely because a provider value moved.

Previews and minimum-LP checks use netLP. For a positive exact-net request n and an active fee 0 <= f < W, the smallest gross integer meeting the request is floor((n - 1) * W / (W - f)) + 1; use full-width arithmetic, then forward-check g - floor(g*f/W) >= n and that g-1 cannot meet n. The inactive branch uses g=n. A positive net request with no feasible gross amount fails before funding; never divide by zero at an active 100% fee or silently invent a cap. Size all component contributions against g, not n. Exact-output adapters retain their established caller-input maximum and unsupported-conversion rules.

On genesis, calculate the family seed supply from the completed post-redemption basket, allocate its locked minimum-liquidity floor once, and define g as the remainder. Only g is split for fees. Total initial LP is lockedFloor + g; subsequent supply grows by g. Existing helpers that already subtract the floor must not subtract it again. Fee mint, depositor mint, refunds, component bookings and manager settlement remain atomic.

Existing FeeCapital tests asserting that a larger deposit cannot change protocol fees are superseded: the fee now scales with that deposit's backed gross LP. Replace those expectations with exact feeLP/netLP/supply equations. A yield-only or rate-only change with no deposit mints nothing; when a later deposit occurs, only its g determines the mint fee. Tests must not incorrectly expect zero fee from a valid fee-bearing deposit just because prior growth was zero.

### Locked bootstrap: incoming SE shares and actual 5% redemption (FS-OWN-37 / FS-HOOK-10)

For T=0 on each funded SE-backed leg, accept only the caller's SE shares. Raw legs continue to accept their raw token. Route existing share-input/flexible deposit selectors to this bootstrap branch; reject initial pair-token input for an SE-backed leg rather than silently converting it into shares inside the hook. The caller or test fixture acquires the shares before invoking the Hook LP join. Preserve each family's positive-leg-count and supported seed topology. H1 has no LP bootstrap and is not given one.

```text
A_i = actual shares received from this caller
redeem_i = floor(A_i * 5 / 100)
retained_i = A_i - redeem_i
local_i = actual paired-token proceeds of redeeming redeem_i
```

Redeem through the supported exact-input share-in/member-pair-out SE route. Verify exact intended share consumption, positive local receipt, caller-supplied bounds, and deadline. Do not use exchangeOut, getRate, the actual hook balance before caller funding, a predicted refund, or an assumed 1:1 conversion as the seed. A zero rounded redemption, zero paired receipt, incomplete share consumption, below-floor seed, failed bound, or failed leg reverts all funding, bookings, allowance changes and mints. Permitted redemption while an SE is disabled can bootstrap this basket without any SE deposit or cleanup reinvestment.

Use the retained SE-share native quantity, with the existing share-decimal normalization, as that leg's input to its established seed-function shape. Raw legs use accepted raw quantities with their own normalization. H2/H3 retain their geometric seed shape; H4/H5 retain their existing supported full/partial seed functions; H6/H7 retain their existing quad/stable seed-function shape. Do not feed pair-denominated rated reserves into those functions or import FullSpread's raw-V4-liquidity formula. Book the complete retained-share/local-pair/raw basket as backing, but do not add a separate rated LP bonus for the locally redeemed proceeds. Apply the locked floor once, then the mint fee above. Conversion costs are borne by the genesis contributor, with no pre-existing or staged token subsidy.

Keep public input/output and preview contracts explicit: apply all bounds supplied by the selected selector, use net Hook LP for its LP minimum, and require positive actual local receipt even when a paired-token minimum is zero. Do not claim that an LP minimum is itself a paired-token price minimum. Previews quote the same 5% share spend, actual-route output estimate, retained-share seed and fee split; execution verifies actual receipts. Add no undocumented price check or new hook-package field.

The 5% is of supplied share quantity, rounded down. It is not a value measurement or a permanent reserve ratio. Subsequent joins match the actual current S/L basket, not an automatic 5% redemption. Subsequent swaps can alter the mixture. The protocol LP is backed by that same basket and later withdraws its ordinary component fraction. FullSpread's own genesis, locked floor, vault fee and 49% one-sided entry rule remain unchanged.


## Verification strategy

Planning performs static inspection only. The implementation uses production-first regression tests: extend existing Behavior/TestBase patterns, demonstrate the new assertions fail for the old mechanism, then make them pass without weakening unrelated assertions. Existing failures predating the refactor remain findings unless the new PRD explicitly supersedes their expectations.

Use `.github/ASSISTANT_TESTS.md`, `docs/testing/ARTIFACT_BUILDS.md`, the IndexedEx/Crane testing skills, and the current router. Solar is mandatory; no `via_ir`, package profiles, `FOUNDRY_TEST` changes, cache deletion, or concurrent writers to `out/` and `cache_forge/`.

For each task, pass every edited production source as positional arguments to the artifact helper and the concrete family/root test paths:

```sh
python3 scripts/forge-artifacts.py test contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/interfaces \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange -- --isolate -vv
```

The task's source list expands this command; the helper builds affected runtime implementations before running tests and injects `--use solar`. Do not compile only a helper while deploying stale facet artifacts.

Final execution gates:

```sh
python3 scripts/forge-artifacts.py build --all-artifacts
forge build --use solar --sizes
forge test --use solar --isolate --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/**' -vv
forge test --use solar --isolate --match-path 'test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/**' -vv
forge test --use solar --isolate
```

Run targeted gates after relevant edits; run the final default-profile suite once after integration. Broaden or repeat only for a change or failure. A new/empty worktree must first copy both warm artifact/cache directories under the repo's existing rules. Long cold compiles can take hours; wait for actual process completion. Serialize builds/tests against a stable source frontier as well as serializing artifact writers; do not mutate a selected source closure while its build runs. Independent family editing may be parallel, but the build owner freezes each selected closure for validation.

Record command, toolchain, source identity, exit code, exact discovered/executed test counts, and failure traces. Zero tests matched is not a pass. Store evidence under `.omo/evidence/fullspread-se-hooks-20261106/`; evidence is generated only during implementation, not fabricated by planning.

### Required cross-family scenario matrix

Every LP-bearing family runs each ownership scenario; H1 runs corresponding conversion/custody cases and records LP cases as structurally inapplicable because it has no LP supply.

| Scenario | Required assertion |
| --- | --- |
| Refund 0 / partial / all input | Actual consumed input, SE shares and returned pair tokens reconcile; only accepted ownership becomes backing. |
| Local output below / equal / above requested amount | Debit the book exactly; zero SE redemption when sufficient; redeem only the deficit otherwise. |
| Disable by address / by package / re-enable | Effective lookup is used; input remains local; permitted withdrawal works; direct forbidden SE call still rejects. |
| Zero local / zero shares / mixed components | No divide-by-zero, no fictitious rates, no double counting, no cash substitute for required shares. |
| Two LP holders, repeated joins/exits | Ceil joins and floor exits preserve incumbent per-LP quantities and remaining-holder book. |
| Pair-input / preowned-share input / flexible flags | Conversion touches only caller assets and the accepted basket supports all minted LP. |
| Pair-output / share-requested / single-token output | Allocate components before conversion; preserve exact output-mode contract and atomic failure. |
| Rate/underlying market change with no hook component change | Pure LP ownership entitlement does not change; separately account for actual trade/conversion PnL. |
| Pretransfer no delivery / short delivery / staged excess | Booked and pending inventory cannot finance another caller's mint or refund. |
| Minima, deadline, reentrancy, outer-manager failure | Supply, books, physical custody, allowance and deltas restore atomically. |
| Currency order, provider target, mixed decimals | Sort whole records; distinguish pair/share/LP units; both exact-input directions are exercised. |
| LP mint fee active/inactive, zero recipient and rounding | Assert feeLP + netLP = grossLP, no mint on top, no fee on fee, no growth/withdrawal mint, and net-output previews/minima on every alias. |
| Exact-net LP requests | Forward-check the minimal gross-up, caller input maximum, fee rounding boundaries, infeasible active-fee branch, and atomic rollback. |
| Share-only genesis on SE legs | Receive actual caller shares, redeem floor(A*5/100), verify full share consumption and positive local receipt; raw legs use raw input. |
| Genesis floor and fee interaction | Derive family seed from normalized retained shares/raw quantities; allocate floor once, split only the remainder, and reconcile total supply and all component backing. |
| Genesis rejection and disablement | Initial pair-token input on an SE leg, dust/zero/incomplete redemption, unmet minima, insufficient seed or a failed leg revert atomically; permitted disabled redemption can succeed. |
| Later joins and varying redemption proceeds | No automatic 5% target or second bootstrap; local proceeds are actual, not rated or assumed one-to-one. |

H4 has exactly three legs. H5 covers n=2, n=3, and n=8 plus existing supported partial-book cases. H6 has exactly four legs. H7 covers n=2 and n=5 plus interior token-count validation. All families retain their current unsupported route guards and owner-only-liquidity policies.

### Concrete test placement and invocation

Use each existing family test directory under HT for implementation regressions. The new shared file `test/foundry/spec/hooks/uniswap/v4/standardExchange/HookComponentAccountingBehavior.sol` is a planned addition beside existing SeMatrixBehavior infrastructure: separate custody/swap behavior from its LP-specific extension. H1 inherits only the applicable non-LP behavior. H2-H7 concrete tests inherit the LP cases; do not implement the H1 exclusion as an early-returning passing LP test. Add planned pure-helper coverage at `test/foundry/spec/hooks/uniswap/v4/libs/UniswapV4HookComponentAccounting.t.sol`. Extend the existing `HT/HookLiquidityInvariantHandler.sol` rather than creating a second incompatible invariant ledger. The proposed `VT/Permissions.t.sol` in the acceptance table is a new suite, not an already inspected file.

Required new test names (in addition to the existing suite assertions) include `test_HB47_mintFeeSplitsBackedGross`, `test_HB47_rateOnlyMovementMintsNoLp`, `test_HB47_exactNetGrossUpMatchesExecution`, `test_HB48_genesisRedeemsFivePercentOfShares`, `test_HB48_genesisFailureRollsBackEveryLeg`, and `test_HB48_laterJoinUsesCurrentComponents`. Run these through the six LP-family concrete adapters and their applicable aliases; a single generic math test does not establish integration coverage.

The nine concrete FullSpread matrix configurations are:

| Family directory under HT | Existing row filename |
| --- | --- |
| single/ | UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol |
| constantProduct/single/ | UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol |
| dual/ | UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol |
| orbital/ | UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol |
| weighted/ | UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol |
| weighted/ | UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol |
| stable/quad/curve/ | UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol |
| stable/quad/balancer/ | UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol |
| stable/quad/balancer/ | UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol |

After the artifact-first command for its edited source list, each family task runs `forge test --use solar --isolate --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/<family-directory>/**' -vv`, substituting exactly the directory from the table. Shared task 3 also runs `forge test --use solar --isolate --match-path 'test/foundry/spec/hooks/uniswap/v4/libs/UniswapV4HookComponentAccounting.t.sol' -vv` after adding that file. Task 2 runs the existing interfaces suite named in its QA step. Tasks 13-17 run the affected family directories plus `VT/BufferHookIntegration.t.sol`; task 18 runs the entire VT directory. Expand the VT/HT aliases to the path legend in commands. Capture nonzero executed test counts and exact commands under the per-task evidence names; commands are planned, not executed during authoring.

### Full PRD acceptance ledger

All paths in this table are under VT unless a hook matrix or shared family behavior is specified. Task 18 closes retained vault requirements; tasks 2-17 close the changed hook rows. A missing assertion is work to add, not assumed coverage from a similarly named test.

| PRD row | Concrete verification destination and action |
| --- | --- |
| FS-A01 | Package.t.sol: live selector manifest, shared factory surfaces, absent vault selectors; rerun after hook/package changes. |
| FS-A02 | Package.t.sol: test_bindingHashChangesWithAnyBinding; include any touched linked-library binding. |
| FS-A03 | Package.t.sol: invalid/missing/mismatched components, processArgs contexts, invalid pool, repeat init; preserve atomic deployment failure. |
| FS-A04 | Package.t.sol: add/assert multi-instance storage isolation through real calls, not storage injection. |
| FS-A05 | Package.t.sol and Money.t.sol: first deposit floor, zero-address floor balance, net/fee mint arithmetic, below-floor rejection. |
| FS-A06 | Money.t.sol and QuotesAndRate.t.sol: both bundle directions, order/minima, no bundle-exit swap. |
| FS-A07 | Money.t.sol: actual unused input refund, fee booking, zero/partial use, no share credit for refunded input. |
| FS-A08 | Money.t.sol and QuotesAndRate.t.sol: booked+unpaid fee claims, exact recipient receipts, opposing-token consumption or atomic failure. |
| FS-A09 | Money.t.sol: enabled exact-out rejection and zero view, no refund ABI changes. |
| FS-A10 | Native.t.sol: WETH-only external boundary and nonpayable routes. |
| FS-A11 | Money.t.sol and AlreadyUnlocked.t.sol: no automatic compound, preserve staying-holder book. |
| FS-A12 | Withdrawn; do not reintroduce an exchangeRate requirement. Vault selector exclusion remains A01. |
| FS-A13 | Withdrawn; getRate absence is covered by A01/A29, not a restored rate implementation. |
| FS-A14 | Withdrawn; no new InsufficientRateSupply behavior/test. |
| FS-A15 | Withdrawn; no planner-via-getRate behavior/test. |
| FS-A16 | Withdrawn; explicitly do not add the retired exchangeRate-read test. |
| FS-A17 | Callbacks.t.sol: exact locked unlock/callback counts and zero borrowed dispatch. |
| FS-A18 | Callbacks.t.sol: stranger/replayed/uncommitted callback atomic rejection. |
| FS-A19 | AlreadyUnlocked.t.sol: mint and exit within same manager unlock; own deltas zero, position identity preserved. |
| FS-A20 | AlreadyUnlocked.t.sol and Native.t.sol: funded-contract rule, pretransfer reject, value boundary. |
| FS-A21 | AlreadyUnlocked.t.sol: unowned shares and unfunded callers cannot mint/burn. |
| FS-A22 | AlreadyUnlocked.t.sol: bundle/donate/compound reject while already unlocked; obsolete selectors absent. |
| FS-A23 | AlreadyUnlocked.t.sol: caught/propagated failure restores vault state. |
| FS-A24 | BufferHookIntegration.t.sol plus all family rows: positive own-share operations with valid paired-token binding and own address omitted from vaultTokens. |
| FS-A25 | BufferHookIntegration.t.sol and seven-family matrix: real mints/redemptions while manager unlocked, recipients and positions preserved. |
| FS-A26 | Dual matrix and DualUnwrap: two real FullSpread vaults, disjoint backing keys, valid underlying pairs, both exact-input directions. |
| FS-A27 | All family matrix rows: topology-specific positive coverage and explicit incompatible route record only when permitted; no blanket identity short-circuit. |
| FS-A28 | BufferHookIntegration.t.sol and matrix: route that actually invokes unsupported vault exchangeOut fails atomically; local-only hook settlement is distinguished. |
| FS-A29 | BufferHookIntegration.t.sol and provider rows: configured external providers for both faces, separate pools/targets, tuple returns, no vault getRate. |
| FS-A30 | Evidence ledger: disjoint-pool success does not claim same-backing-pool sequential proof. |
| FS-A31 | All nine named matrix configurations plus BufferHookIntegration: actual isolated cold transaction measurement <=12m and previews <=5m, no setup gas masquerading as route gas. |
| FS-A32 | QuotesAndRate.t.sol: disabled/unlocked economic views and unsupported zero views. |
| FS-A33 | AlreadyUnlocked.t.sol: same-state locked/already-unlocked receipt parity in both faces. |
| FS-A34 | AlreadyUnlocked.t.sol: own nonzero delta rejection and preservation of foreign debt. |
| FS-A35 | Native.t.sol: native sync/settle accounting, foreign credit isolation, WETH receipt. |
| FS-A36 | AlreadyUnlocked.t.sol: outer propagated and caught failures with exact state/delta assertions. |
| FS-A37 | AlreadyUnlocked.t.sol: funded non-hook contract success, no allowlist. |
| FS-A38 | Money.t.sol plus BufferHookIntegration: direct disable matrix, local hook success and permitted deficits, no post-exit deposit. |
| FS-A39 | New Permissions.t.sol alongside suite: live owner, global operator, selector-specific operator, stranger and ownership-change cases through real manager/feeTo. |
| FS-A40 | Seven family Binding/Package tests and matrix: pair membership, implicit own share, no asset probe, all validator routes. |
| FS-A41 | Shared behavior plus seven family adapters: exact separate books, refunds, unbooked custody, rollback and staged-credit negatives. |
| FS-A42 | Shared behavior plus family Swap/SE/owner routes: local book below/equal/above output, input disablement, rated reserve normalization and previews. |
| FS-A43 | Shared behavior plus all liquidity aliases: ceil component contributions, caller-only conversion, no rate-driven LP entitlement, no incumbent dilution; contributions back gross LP, which is split under FS-A47, not just the depositor net. |
| FS-A44 | Shared behavior plus all exits: floor component claims, local+SE payouts, remaining-holder preservation, minima/rollback. |
| FS-A45 | All family adapters: address/package disable axes, preowned-share join versus unsatisfied component, zero/mixed books, locked floor and FS-A48 share-only bootstrap, re-enable. |
| FS-A46 | Stateful shared handler and family integration cases: join, external pool manipulation, exit, unwind, component ownership oracle separate from conversion PnL. |
| FS-A47 | Tasks 3, 5, 7-13 and 16: shared fee arithmetic plus every LP family's Fees/FeeCapital and deposit-alias suites; exact gross/fee/net/supply, inactive/zero-recipient branches, rounding, exact-net gross-up, floor exclusion, no growth or exit mint. H1 is explicitly not an LP product. |
| FS-A48 | Tasks 3-5, 7-14 and 16: share-funded genesis in each LP family's Liquidity/Flexible/StagedInit suites and FullSpread matrix seed helpers; actual 5% share burn/local receipt, retained-share seed function, raw-leg exception, floor and fee split, input/minimum/partial failure rollback, permitted disabled redemption, and no repeated 5% rule on later joins. |

### Original failure migration ledger

The user supplied 36 failing contract/test instances. These were not rerun during planning. The updated PRD supersedes the earlier council's instruction to keep the invalid sibling-identity fixtures deliberately red. Preserve the tested behavior, rebuild valid fixtures, and replace obsolete expectations explicitly rather than deleting coverage.

| Original instances | Count | Required plan action |
| --- | ---: | --- |
| Twelve identity-gated dual tests, each in the standalone dual matrix and inherited DualUnwrap suite | 24 | Replace the sibling with a real second FullSpread vault and its valid paired face; run each test body past the old identity guard. Keep both directions, both product-index cases, both provider targets, previews, swaps, refund ownership, and measured gas. |
| test_row_identity_pairToken in orbital, weighted N3, Curve, Balancer five-leg and their four inherited unwrap suites | 8 | Replace the deprecated sibling fixture and misleading identity expectation with valid paired-token membership plus positive own-share mint/redeem. Keep raw-leg controls and separate nonmember rejection tests. |
| test_row_identity_thisVault in dual and DualUnwrap | 2 | Rewrite as FS-A24 positive own-share processing with the vault address absent from its underlying list and a separate valid paired-token binding. Do not require self-membership. |
| test_dualUnwrapApprovesAndCompletesExit | 1 | Execute approval, burn, local entitlement and SE redemption on the rebuilt valid dual fixture. A prerequisite assertion alone is not exit coverage. |
| test_disabledBufferedWithdrawalApprovesAndCompletesExit | 1 | Preserve the positive exit obligation; separately assert retained local ownership and the absence of prohibited cleanup deposits. Extend the case to every hook family and both disable axes. |

The twelve dual test names are:

- test_composedRouteGasFitsCeiling
- test_row_bind_deploysThroughPackage
- test_row_bufferFirst_restingFace_notPaidToJoiner
- test_row_hookSwap_exactIn_eoaPretransferRejected
- test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly
- test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed
- test_row_index0
- test_row_index1
- test_row_partialConsumption_bookedNotRefunded
- test_row_poolManagerSwap_bothDirections_noFaceResidual
- test_row_previewMatchesExecution
- test_row_rateTarget_currency1

The existing test_disabledBufferedMintRevertsWhileUnlockedAndRollsBack is not one of the supplied failures but becomes stale under the new requirements: replace the blanket hook-level revert assertion with positive local booking plus a distinct direct-disabled-SE rejection/rollback test. Tests must continue distinguishing a hook-local exact-output settlement from a path that actually calls the FullSpread vault's unavailable exchangeOut. Also migrate fee suites that assert positive protocol LP from underlying yield or fee independence from new deposit size, and bootstrap helpers that provide pair tokens to SE-backed legs. These expectations are superseded by FS-A47/48; replace them with positive new-model assertions rather than skipping the suites.

## Execution strategy

Use four dependency waves followed by final verification. Every numbered task includes implementation and its tests; no task can close on a prose summary, a grep result, or a fixture that returns before the behavior under test.

| Wave | Tasks | Dependency / ownership rule |
| --- | --- | --- |
| A - Common contract and fixtures | 1-5 | Shared libraries, fixture and behavior changes have one owner per file. Task 1 establishes the baseline; tasks 2-5 consume it. |
| B - Family adapters | 6-12 | Depend on A. Distinct H1-H7 files permit parallel work; all shared helper changes route through their Wave A owner. |
| C - Facades, integration and invariants | 13-17 | Depend on all affected family adapters. No independent facet worker edits a family's Common/Claim implementation concurrently. |
| D - FullSpread regression and evidence | 18-20 | Depend on C. Shared artifact builds are serialized. |
| Final verification | F1-F4 | After all implementation tasks; read actual execution evidence and rerun only justified checks. |

### Exact dependencies and handoff gates

| Task | Must follow |
| --- | --- |
| 1 | none |
| 2 | 1 |
| 3 | 1 |
| 4 | 1, 2 |
| 5 | 2, 3, 4 |
| 6-12 | 2, 3, 4, 5 |
| 13 | 6, 7, 8, 9, 10, 11, 12 |
| 14 | 13 |
| 15, 16 | 14 |
| 17 | 15, 16 |
| 18 | 17 |
| 19 | 18 |
| 20 | 19 |
| F1-F4 | 20 |

Tasks 4 and 5 establish working production deployment/funding infrastructure and red-before regressions; their baseline does not claim that not-yet-implemented Hook bookkeeping already passes. Their fixture checks can close on real underlying-vault deployment and acquired SE shares, while the new hook fee/bootstrap/accounting behaviors are explicitly red until tasks 6-12 implement them. Those family tasks own the required green-after receipts. Final verification permits no in-scope red behavior to be waived as a baseline.

Shared-source ownership is fixed: task 2 owns LegLib classification and all DFPkg membership validators until Wave A closes; task 3 owns shared component/tuple helpers; task 4 owns shared FullSpread fixtures; task 5 owns the shared behavior file. Family workers own their family repos/targets/math/interfaces and concrete adapters. A requested shared edit goes back through that owner, then affected families rerun the scoped checks. Tasks 15 and 16 may work in parallel only while concrete regression rows and invariant-handler files remain disjoint.

## Todos

- [ ] 1. Freeze requirements and enumerate live route coverage
  - References: authoritative PRD; H1-H7 product interfaces, facetFuncs/facetCuts, HT family Behavior contracts, VT eight suites.
  - Work: record the clean/dirty baseline without changing it; enumerate every deployed deposit, withdrawal, flexible, SE, Native SY, owner-swap, Permit2, beforeSwap, and preview selector. Classify current behavior as retained, superseded, or missing against the PRD. Do not use facet declarations as the sole expected-selector oracle. Include retired growth-fee calls/supply forecasts and every T=0 funding path in the route inventory; identify fee-oracle sources and existing share-input selectors before editing.
  - Acceptance: every installed money/view route has a family owner, component-accounting path, and test destination; all 48 rows and original 36 instances are in the ledger. Tasks 3-14 implement FS-OWN-36/37 through all LP-bearing aliases, not just the ordinary join.
  - QA happy: inspect deployed-proxy surface controls and selected test discovery; capture `01-surface-map.md`.
  - QA failure: identify old deliberate identity failures and blanket disabled-hook-mint expectations; capture `01-superseded-tests.md` without deleting tests.
  - Recommended task executor category: deep-low - source-grounded cross-file inventory.
  - Commit: none unless separately authorized.

- [ ] 2. Correct SE membership and own-share classification
  - References: HS LegLib; H1-H7 DFPkg validators; PRD FS-OWN-35, FS-A24/40.
  - Work: remove asset probes and wrapper-decimal shortcuts from all callers; validate only configured pairToken membership. Recognize a bound SE's own share separately for supported conversion/holdings. Preserve independent overlap, zero-address, provider and package checks.
  - Acceptance: a real SE omitting itself from vaultTokens binds and processes its own shares; a nonmember configured pair token still rejects.
  - QA happy: extend `test/foundry/spec/hooks/uniswap/v4/interfaces/UniswapV4SeBufferHookLegLib.t.sol` and seven family binding/package suites; `02-binding.log`.
  - QA failure: nonmember, missing/reverting membership surface and asset-answering nonmember cannot bypass membership; `02-binding-negative.log`.
  - Recommended task executor category: deep-low - shared validation with known callers.
  - Commit: none unless separately authorized.

- [ ] 3. Implement shared component and refund-result primitives
  - References: HS LiquidityRouteLib/ExecutionBase, ContextQuoteLib, LocalCreditLib, ExchangeInAmount, PRD FS-HOOK-05 through FS-HOOK-10.
  - Work: centralize overflow-safe ceil contribution, limiting fraction and floor allocation arithmetic in the nearest existing liquidity helper. Add refund-preserving results without breaking unrelated one-word helper callers. Keep caller ownership decisions in the family adapter, not the stateless helper. Add the gross/fee/net split and exact-net inversion in native LP units, and shared bootstrap arithmetic for the 5% share spend and actual consumption checks. Family seed functions remain family-owned. Do not retain projected growth-fee supply in an adapter.
  - Acceptance: no arithmetic compares or sums unlike native units; zero components and actual pre-intake supply are handled consistently; tuple information is available through execution and preview paths. Use actual pre-intake supply, not a fee-adjusted growth forecast. Cover gross backing, fee conservation and once-only floor allocation.
  - QA happy: exact small-integer and large-value arithmetic/conservation cases alongside shared hook library tests; `03-components.log`. Exercise the worked ceil basket, gross=100 with 2% fee giving net=98, and exact-net=100 with 2% fee requiring minimal gross=102; native-unit boundary cases must use an independent arithmetic oracle.
  - QA failure: overflow boundaries, zero supply versus live zero component, short funding, and double-counted refunds are rejected or handled by the explicit branch; `03-component-boundaries.log`.
  - Recommended task executor category: deep-high - correctness derives from cross-family ownership invariants.
  - Commit: none unless separately authorized.

- [ ] 4. Replace the sibling fixture with real FullSpread instances
  - References: HT SeMatrix_FullSpreadV4Fixture.sol; VP test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol; all nine FullSpread matrix row configurations; PRD FS-HOOK-02.
  - Work: deploy the second vault from the existing FullSpread package on the same PoolManager with distinct hookless backing keys and real underlying tokens. Bind each member face, not its share as a fake pair. Acquire shares through supported public routes. Remove the obsolete sibling imports and avoid vault-address salt searching when token-side placement is the real observation. Acquire SE shares outside each hook bootstrap call and change all family _seed/_joinAll helpers to their existing share-input or flexible route on SE-backed legs, supplying raw tokens only for raw legs. Observe the real 5% redemption, retained-share inventory, local receipts, floor, protocol LP and user net LP.
  - Acceptance: two supported vaults, real providers for both faces, both product index placements and disjoint keys are asserted before operations; no fixture-specific bypass or mocked SE. A first pair-token deposit into an SE-backed LP leg is a negative, not the default seed fixture. H1 remains conversion-only.
  - QA happy: registry deployment, public bootstrap, separate positions and both conversion directions; `04-fixtures.log`.
  - QA failure: invalid paired-token binding and wrong manager/key fail without partial usable configuration; `04-fixture-negative.log`.
  - Recommended task executor category: deep-low - reuse existing package/TestBase deployment.
  - Commit: none unless separately authorized.

- [ ] 5. Add the shared component-accounting behavior matrix
  - References: HT existing SeMatrixBehavior contracts and HookLiquidityInvariantHandler.sol; PRD FS-A40 through FS-A48.
  - Work: add reusable behavior assertions/adapters beside existing test infrastructure for component snapshots, caller conversion ownership, local-first settlement and disable axes. Use exact independent expected quantities, not SUT previews as the only oracle. Each concrete family must run the relevant cases. Add shared FS-A47/48 fee and bootstrap behaviors, including source-versus-fee recipient balances, actual burn/receipt, partial/zero redemption, atomic multi-leg failure, inactive/zero-recipient fee policy and exact-net requests.
  - Acceptance: the scenario matrix is executable on real proxies; unsupported topology cases are identified narrowly, never silently returned. Every LP family runs fee/genesis behaviors through all applicable aliases; mark only H1 LP cases structurally inapplicable.
  - QA happy: deterministic two-holder joins/exits and partial SE refunds; `05-behavior-red.log` records the pre-fix failure.
  - QA failure: staged input, failed conversion, minima and reentry preserve incumbent books; `05-ownership-negative.log`.
  - Recommended task executor category: deep-low - shared production-first test infrastructure.
  - Commit: none unless separately authorized.

- [ ] 6. Adapt the single wrap/unwrap hook
  - References: H1 Repo/Common/Target/DFPkg and interface; HT single matrix, Binding, Buffer and Preview tests.
  - Work: implement attributed retained-custody/refund accounting and valid registry disable lookup; do not assume its zero feeOracle is a registry. Preserve four wrap/unwrap modes and settle only deliverable output. Apply paired-token membership and implicit SE-share handling.
  - Acceptance: no invented LP supply or CP curve; disabled wrap never promises unavailable SE shares; permitted unwrap and refunds retain exact ownership and manager settlement.
  - QA happy: all supported modes, actual partial refund, already-unlocked FullSpread redemption; `06-single.log`.
  - QA failure: disabled unavailable conversion, unsupported exact-out vault call, short credit and outer rollback; `06-single-negative.log`.
  - Recommended task executor category: deep-low - distinct non-LP topology.
  - Commit: none unless separately authorized.

- [ ] 7. Adapt constant-product single component accounting
  - References: H2 inventory above; HT constantProduct/single Liquidity, FeeCapital, FullSpread matrix and recurrence tests.
  - Work: book raw token, SE shares and local pair tokens separately. Replace rated intake clamps used for ownership with component constraints; retain raw-share issuance reuse where valid. Extend proRata with the local claim; replace ambient-balance dust sweeps with attributed handling. Update all swap and quote branches. Apply the locked mint-fee and share-only genesis contracts. Replace rated _previewFirstMint/first-mint inputs with normalized retained SE-share quantities and raw-token quantities. Remove fee-growth calls and supply previews from DepositCommon, InQuoteBase, WithdrawTarget and WithdrawalLib, preserving math used for swaps. Update depositWithSeShares and its preview to account for the 5% redemption.
  - Acceptance: every ordinary/share/single-input/Permit2/SE/SY route uses the same snapshot and actual contributions; pool-owned refunds cannot become user credit. FeeCapital tests now assert fee proportional to new gross LP and no mint from rate/yield alone; genesis books raw, retained SE and actual local pair quantities.
  - QA happy: three-component join/exit, all local-output thresholds, fee-on/off preview parity and disabled exit; `07-cp-single.log`.
  - QA failure: rate-only movement, incoming capital, staged transfers and forced cleanup deposit cannot dilute or block the permitted exit; `07-cp-single-negative.log`.
  - Recommended task executor category: deep-high - fee, projection and ownership boundaries interact.
  - Commit: none unless separately authorized.

- [ ] 8. Adapt dual constant-product component accounting
  - References: H3 inventory above; HT dual B6M3, Liquidity, swap/preview suites and new valid FullSpread row.
  - Work: track S0/L0/S1/L1; update BookSwapPlan execution, ordinary/flexible joins, proportional and single-token exits, sequential/fallback previews, sync and credit. Remove rated ownership clamps and ambient residual sweeps. Keep one owner of Common and quote libraries. Apply the locked mint-fee and share-only genesis contracts on both legs. Flexible initial funding uses SE-share flags for funded SE legs; each redeems its own 5% and both execute atomically. Remove Common/DepositQuoteLib projected growth-fee supply and fee-only checkpoints.
  - Acceptance: all flexible input/output combinations use one component fraction; both SE legs execute within the same outer unlock without confusing their deltas. Protocol fee plus net depositor LP equals gross in every dual alias; both initial local books arise from actual caller-owned share redemptions.
  - QA happy: all original dual positive tests reach actual execution, both index/provider orientations, four-component ownership; `08-dual.log`.
  - QA failure: unavailable requested conversion, failed minima and caught/propagated outer failures restore both books; `08-dual-negative.log`.
  - Recommended task executor category: deep-high - multi-vault sequential accounting and quotes.
  - Commit: none unless separately authorized.

- [ ] 9. Adapt orbital component accounting
  - References: H4 inventory; HT orbital Liquidity, Buffer, RawLiquidityConversions/Policy/RateFailure, LedgerReconcile, Preview and invariant suites.
  - Work: extend three-leg books and virtual execution-state share projections with local quantities; update addLiquidity, single/flexible deposits, ExitQuoteLib and swap paths. Preserve orbital curve semantics and owner-only policies. Apply the locked mint-fee and share-only genesis contracts in DepositCore/Common, projections and all flexible/zap aliases. Preserve supported orbital seed topology and seed-function shape using retained-share/raw coordinates. Remove prior-growth fee issuance and update fee tests rather than retaining it before the snapshot.
  - Acceptance: local inventory affects swap reserves but not quantity-based mint entitlement; no radius/invariant calculation bypasses component constraints. No orbital radius or fee-growth path mints additional LP outside the backed gross split.
  - QA happy: three-leg sorted records, caller-only basket assembly, disabled deficits and requested exits; `09-orbital.log`.
  - QA failure: rate failure/changes, zero components, partial consumption and owner-during-lock restrictions; `09-orbital-negative.log`.
  - Recommended task executor category: deep-high - family curve/projection adaptation.
  - Commit: none unless separately authorized.

- [ ] 10. Adapt weighted component accounting
  - References: H5 inventory; HT weighted Liquidity, MultiAssetLiq, N8, Partial, Scale, B6Firm, staged-init and invariant suites.
  - Work: extend inventory-domain proportional logic to S/L components; route unbalanced and single-asset entry through caller-owned conversion then the same acceptance contract. Update exits, rate-normalized swaps, rawReserves/credit separation, and previews. Apply the locked mint-fee and share-only genesis contracts to proportional, partial, unbalanced and flexible entries and their previews. Preserve the full/partial seed-function shape and allowed positive-leg count using retained-share/raw coordinates. Remove growth-fee supply adjustments and enforce exact net LP on all entrypoints.
  - Acceptance: n=2/3/8 and supported partial books retain one common LP fraction; weights do not bypass actual-component ownership after genesis. Weights may remain part of the existing genesis function and swap curve; after genesis they cannot replace the component ownership constraints.
  - QA happy: all route/flag variants across minimum and maximum n with real refunds; `10-weighted.log`.
  - QA failure: missing component, bad sort/flags, disabled mint, pretransfer recurrence and rate-only LP inflation; `10-weighted-negative.log`.
  - Recommended task executor category: deep-high - dynamic multi-leg partial-book logic.
  - Commit: none unless separately authorized.

- [ ] 11. Adapt Curve quad component accounting
  - References: H6 inventory; HT stable/quad/curve Liquidity, Swap, Fees, MultiAssetLiq, Scale, B6Firm and invariant suites.
  - Work: extend fixed-four share-inventory join/exit paths with local components; update single-asset/flexible/exact-output adapters and previews without rating LP ownership. Preserve amp/StableSwap behavior only where it prices actual conversion/swaps. Apply the locked mint-fee and share-only genesis contracts to all four SE-backed legs and the installed liquidity/flexible facades. Use the existing four-leg seed function with normalized retained shares/raw quantities; do not use rated reserves. Remove _maybeMintProtocolFee and fee-growth forecasts from entry and exit paths.
  - Acceptance: four-leg masks and output requests conserve the allocated basket; a volatile SE share is not treated as a peg to avoid conversion. Genesis, user/protocol fee split and all four component books commit atomically, with no fee on a withdrawal or conversion-only swap.
  - QA happy: full-book and mixed local/share cases with preview/execution parity; `11-curve.log`.
  - QA failure: disabled requested share conversion, missing components, bad minima and manager settlement rollback; `11-curve-negative.log`.
  - Recommended task executor category: deep-high - fixed-array stable curve and facade coverage.
  - Commit: none unless separately authorized.

- [ ] 12. Adapt Balancer stable component accounting
  - References: H7 inventory including separate LiquidityUnits Core/Target; HT stable/quad/balancer Liquidity, MultiAssetLiq, TokenCount, Fees, Scale, Math and invariant suites.
  - Work: extend both standard and units/flexible paths. Remove rated unbalanced issuance as an ownership shortcut; caller conversions must produce an accepted component basket. Distinguish feeReserves, raw custody and local-pair book; update proportional and requested-output exits and previews. Apply the locked mint-fee and share-only genesis contracts to both standard liquidity and the separate LiquidityUnits Core/Target. Update _initialLiquidityValues and first-mint inputs to retained-share/raw coordinates. Remove growth-fee issuance and fee-only checkpoints without deleting custody data or stable-curve invariants.
  - Acceptance: n=2 and n=5 adapters and all public units selectors use the same component ownership contract. Both standard and units/flexible routes expose net LP consistently and reject first pair-token funding of SE-backed legs.
  - QA happy: mixed flags and actual refund/disable sequences through both facet sets; `12-balancer.log`.
  - QA failure: duplicate input legs, unmatched components, disabled conversion, rate-only minting and staged input; `12-balancer-negative.log`.
  - Recommended task executor category: deep-high - multiple liquidity APIs and fee/reserve representations.
  - Commit: none unless separately authorized.

- [ ] 13. Close facade and preview bypasses across families
  - References: Task 1 route inventory; HS LiquidityRouteLib/ExecutionBase/ContextQuoteLib; every installed SE, Native SY, flexible and owner-swap adapter.
  - Work: compare each facade with its canonical family path for funding, refund ownership, snapshot, output contract, disable lookup and guard. Extend projected local books and actual-share state, preserving optional ERC-165-gated fallbacks. Never substitute a live state read for a projected post-conversion state. Ensure each depositor-funded LP mint is charged once in the family engine, not again in its SE/SY/Permit2 wrapper. Previews return net LP, exact-net paths gross up before component sizing, and every T=0 alias respects share-only genesis.
  - Acceptance: no alternate selector retains old liquidity accounting; unsupported exact-output behavior stays explicit and atomic. No facade silently performs a prohibited initial pair-to-share conversion or retains an old growth-fee mint.
  - QA happy: route-by-route parity from identical state; `13-facades.log`.
  - QA failure: provider/context capability failure, changed state, invalid route and output conversion minima; `13-facades-negative.log`.
  - Recommended task executor category: deep-high - cross-package contracts and preview semantics.
  - Commit: none unless separately authorized.

- [ ] 14. Verify package linkage and immutable proxy surfaces
  - References: all touched DFPkg/interfaces/facets/FactoryServices; ArtifactCreationCode; hook factory and registry deployment targets.
  - Work: update linked-component metadata and bindings only where code dependencies require it; initialize new books and registry awareness on new proxies without adding unnecessary package fields. Preserve hook flags, salts and finalization. No live migration. Verify every existing share-input/flexible selector required to seed the new LP products is installed and callable on its proxy. Initialize books from the accepted bootstrap receipts, not ambient balances; no new package field is required by the fee or bootstrap rule.
  - Acceptance: registry-deployed proxies expose the intended selectors and current code; facet metadata agrees with interface-derived controls. All new state respects existing storage slots; declaration/proxy tests exercise the actual entrypoint used by each matrix seed.
  - QA happy: real registry deploy, loupe/selector smoke, two-instance isolation and deterministic address checks; `14-packages.log`.
  - QA failure: missing library/component, stale binding, wrong init context or post-finalization mutation is rejected; `14-packages-negative.log`.
  - Recommended task executor category: deep-low - existing deployment and declaration patterns.
  - Commit: none unless separately authorized.

- [ ] 15. Replace all original failing fixture gates with current requirements
  - References: original-failure ledger above; all nine FullSpread matrix configurations and VT BufferHookIntegration.t.sol.
  - Work: run the twelve dual behaviors on both standalone and inherited suites; replace self-membership prerequisites with valid pair bindings and own-share positives; retain separate nonmember negatives. Update the stale blanket disabled-buffered-mint expectation to local success plus direct-SE rejection. Rebuild first Hook LP funding with the FS-HOOK-10 share-only seed before exercising each original test. Distinguish Hook LP mint fees from fees on the underlying SE conversion; old no-fee-on-new-capital expectations are replaced by the backed gross split.
  - Acceptance: all 36 instances have a traceable new outcome and actual downstream assertions; no early-return, skipped test or fake expected revert closes a required positive. The 36-instance ledger records the actual rebuilt contract/test name if a misleading identity test is renamed, with the positive behavior still executed.
  - QA happy: matrix, unwraps, refunds and preview assertions reach real calls; `15-original-failures.log`.
  - QA failure: independent exact-output, membership, funding, minima and disable negatives still prove no state loss; `15-original-negatives.log`.
  - Recommended task executor category: deep-low - requirement-driven test migration.
  - Commit: none unless separately authorized.

- [ ] 16. Add stateful component ownership and market-change tests
  - References: HT HookLiquidityInvariantHandler.sol and family invariant suites; PRD FS-A41 through FS-A48.
  - Work: track independent ghost books and per-operation caller inventory across joins, swaps, refunds, exits, direct transfers, disable/re-enable and external pool changes. Use production SEs and hook proxies; never inject SUT storage. Extend the ghost ledger with protocol fee LP, net depositor LP, gross supply changes, locked genesis floor and 5% share-consumption/local-receipt records. A fee recipient can later exit only its proportional components; rate-only/yield-only changes create no extra protocol LP.
  - Acceptance: bounded fuzz actions cover all asset ownership classes and same-state component formulas; reported profit is separated from conversion/trading PnL. Track fee recipient and user balances independently; vary fee settings, first versus later joins, and failed initial multi-leg redemption.
  - QA happy: multiple LPs and repeated transitions, mixed decimals and fee settings; `16-invariants.log`.
  - QA failure: requested join/market-change/exit/unwind sequence, forged credit, reentry and failed outer settlement cannot extract incumbent components; `16-adversarial.log`.
  - Recommended task executor category: deep-high - invariant proof and integration failure modes.
  - Commit: none unless separately authorized.

- [ ] 17. Measure composed gas and preserve capability limits
  - References: HT FullSpreadV4MatrixChecks.coldSwap in the dual row; each composed gas override; PRD FS-A28 through FS-A31.
  - Work: measure actual cold isolated transactions and previews after valid fixtures execute. Keep setup/mining cost separate. Revalidate both provider targets and all nine named configurations. Diagnose reachable unsupported-SE calls rather than relabelling local-only settlement. Include share-funded bootstrap in setup but exclude it from the measured cold operation; include any actual mint-fee processing belonging to the measured route. No setup gas substitutes for execution gas.
  - Acceptance: <=12,000,000 transaction gas and <=5,000,000 preview gas for claimed routes; no ceiling changes or measurements from failed prerequisites. Fee/genesis changes do not waive the transaction or preview ceilings.
  - QA happy: record exact route, mint/burn evidence and gas; `17-gas.log`.
  - QA failure: explicit non-passing evidence for a genuinely oversized/unavailable route; same-backing-pool safety is not inferred; `17-capabilities.md`.
  - Recommended task executor category: deep-low - empirical gate on the actual proxy surface.
  - Commit: none unless separately authorized.

- [ ] 18. Close the complete FullSpread acceptance inventory
  - References: 48-row ledger above, VT suites, VP TestBase, PRD owner locks.
  - Work: rerun retained cases and add missing assertions in the listed suites, including live operator authorization and exact floor/fee checks. Do not restore withdrawn rows or old quadratic sizing as the product rule. Include FS-A47/48 in the executed family adapters while preserving FullSpread's own FS-OWN-24/27/33 formulas. Do not apply the Hook LP fee or 5% bootstrap to the underlying vault's genesis.
  - Acceptance: every active row has executed evidence; withdrawn rows have an explicit disposition, not fabricated passing tests. The ledger distinguishes current positive, negative and withdrawn requirements without reviving retired economics.
  - QA happy: full VT suite and touched family package tests; `18-fullspread.log`.
  - QA failure: complete callback, funding, disable, fee, native and operator negatives with exact state restoration; `18-fullspread-negative.log`.
  - Recommended task executor category: deep-low - complete PRD traceability against existing behavior.
  - Commit: none unless separately authorized.

- [ ] 19. Run integrated regressions and artifact-size gates
  - References: final commands above; all touched runtime source dependencies and existing family suites.
  - Work: build current artifacts, check diagnostics and size limits, run seven-family tests, FullSpread regressions, then full default hermetic tests. Preserve non-target families as compatibility controls.
  - Acceptance: exit code zero and nonzero test counts, or precisely identified pre-existing unrelated failures; no in-scope failure waived.
  - QA happy: fresh artifact evidence and complete suite output; `19-regressions.log`.
  - QA failure: classify any stale artifact, deployment, code-size, compilation or behavior failure with its source and exact trace; `19-failures.md`.
  - Recommended task executor category: deep-low - integrated build/runtime verification.
  - Commit: none unless separately authorized.

- [ ] 20. Publish the execution and matrix evidence ledger
  - References: PRD FS-TEST-04 named audit evidence files, this plan's coverage and failure ledgers.
  - Work: update only the affected current V4 matrix/evidence entries from actual results; preserve V3 rows and historical provenance. Record source/toolchain, all 48 dispositions, 36 migrated instances, gas, capabilities and residual limitations. No report may grant deployment authority. Reconcile all 48 dispositions and record fee/genesis evidence explicitly. Update the named matrix JSONs and acceptance item R10.3 from executed results, preserving V3 and historical provenance.
  - Acceptance: each claimed completion links to a real test and result; obsolete deliberate failures are not still labelled current blockers after their replacements execute. The archived report must not retain D1/D2 as unanswered or claim protocol swap-fee accumulation is still the selected model.
  - QA happy: reconcile matrix counts against executed contract/test instances; `20-evidence-reconciliation.md`.
  - QA failure: reject omitted inherited copies, zero-test runs, stale build output and unsupported consensus claims.
  - Recommended task executor category: writing - evidence publication without new product changes.
  - Commit: none unless separately authorized.

## Final verification wave

- [ ] F1. Audit PRD and failure-ledger completeness
  - Verify all 48 rows, all seven topology dispositions and every original failure against actual evidence; reject skipped positive behavior.
  - Evidence: `.omo/evidence/fullspread-se-hooks-20261106/F1-compliance.md`.
- [ ] F2. Review accounting, guards and package quality
  - Review component conservation, gross/fee/net supply, genesis share consumption and floor exclusion, caller-only conversions, disable lookup, public surfaces and storage isolation. Do not accept a code grep as runtime proof.
  - Evidence: `.omo/evidence/fullspread-se-hooks-20261106/F2-review.md`.
- [ ] F3. Verify real proxy execution and release gates
  - Inspect successful deployed-proxy transactions, failure traces, gas and build artifacts from task 19; rerun only a missing or invalid evidence case.
  - Evidence: `.omo/evidence/fullspread-se-hooks-20261106/F3-runtime.md`.
- [ ] F4. Check ideal-state and scope fidelity
  - Confirm IS-1 through IS-6 and that no unrelated API removal, deprecated-vault dependency, deployment, or claimed security guarantee was added.
  - Evidence: `.omo/evidence/fullspread-se-hooks-20261106/F4-fidelity.md`.

## Commit strategy

No commits, pushes, PRs, deployments, registry migrations, or contract deletions are authorized by this plan-writing task. If implementation is later authorized, follow that session's explicit Git scope; do not infer commit permission from a checkbox or a workflow template.

## Success criteria

| Ideal state | Delivering tasks | Proof |
| --- | --- | --- |
| IS-1 | 3, 5, 7-13, 16 | Independent ceil/floor ownership, backed gross/net fee splitting, share-funded genesis, and rate-change invariants on all LP families. |
| IS-2 | 3, 6-13, 17 | Local threshold swap cases, disabled input booking and real SE deficit receipts. |
| IS-3 | 5-13, 15-16 | Actual disabled pair-output exits, remaining-holder accounting, no cleanup mint. |
| IS-4 | 2, 4, 14-15 | Valid paired-token bindings, positive own-share calls, no asset probes. |
| IS-5 | 1-14, 19 | Complete route map and green family/facade/package gates. |
| IS-6 | 15-20, F1-F4 | Explicit 36-instance migration, 48-row acceptance ledger and fresh execution evidence. |
