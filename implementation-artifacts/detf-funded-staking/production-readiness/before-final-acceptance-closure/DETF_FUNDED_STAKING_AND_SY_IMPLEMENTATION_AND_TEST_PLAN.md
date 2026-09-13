# DETF funded staking, vesting bonds and Standard Yield implementation and test plan

**Written:** 2026-09-06  
**Status:** Implementation authorized by the owner; execution continues in the main repository directory after owner-approved relocation on 2026-09-07.
**Requirements:** [DETF alignment PRD](./DETF_ALIGNMENT_PRD.md), D32–D66 and §24; acceptance criteria A1–A42.

**Latest checkpoint (2026-09-11):** The owner-reported passing baseline and the later agent-executed 31,305-case pass remain archived. Strict local lifecycle validation subsequently exposed two production defects. Their fixes passed the matching complete build and all seven new regressions. All 27 existing security cases and the full 31,312-case suite passed. Package reconciliation and the strict local rehearsal remain in progress. Use the [production-readiness remaining implementation plan](./DETF_PRODUCTION_READINESS_REMAINING_IMPLEMENTATION_PLAN.md) for the current queue. Final acceptance remains open.

The owner subsequently instructed the agent to execute this plan, authorizing the contract, test, script and application changes it specifies. The owner also explicitly approved the previously rejected obsolete V4 mature-close cleanup, including configuration, getters, unused storage and related caller/test/ABI changes. `implementation-artifacts/detf-funded-staking/v4-close-cleanup-owner-approval.json` records that approval; no question remains pending for this cleanup. Execution is in progress. Production deployment and migration remain outside scope. Checkboxes record verified completion, not merely started work.

The [earlier implementation plan](./DETF_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md) is a historical baseline. Its completion marks do not mean this refactor is implemented. D32–D66 override conflicting historical requirements, including Open mode, expansion caps, LP-backed bond principal and spot-valued rebasing claims. Preserve unrelated behavior and work produced by other contributors. Do not interrupt another agent, reset its changes, or execute this plan in its active checkout.

PR-08's launch-only build and completed 19-stage local deployment are historical checkpoints. The later strict lifecycle result was 33 passed / 6 failed / zero skipped. PR-09 terminates unmintable residual retries before transaction gas exhaustion; PR-10 uses full-precision Orbital NAV multiplication/division. LC-01 supplies the actual funded reserve growth required by four Quad fee fixtures. The full hermetic evidence is renewed and passing; local deployment/lifecycle evidence must still be renewed for these production changes. Only the 35 provider/V3 forks qualify for narrowly verified unchanged-dependency reuse.

## 1. Deliverables and scope

**D60 scope update:** functional DETF work now covers only the four unified V4 reserve bindings. Stop functional work on Balancer-hosted DETFs; subsequent edits there may only keep the repository compiling. Preserve already-recorded work and validation history without expanding or finalizing that excluded product refactor. Unrelated SE work, including Balancer SE vaults, remains in scope. The old Balancer reserve-LP bond-payment question is retired. D65 is resolved by owner-approved redemption through the current `feeTo()` Fee Collector.

**D66 scope update:** Defer all unfinished Slipstream work from this release by owner decision. Robinhood targets Uniswap V4. Preserve completed Slipstream changes, existing functionality, tests and validation evidence. Permit only compilation maintenance or compatibility edits required by shared V4 changes; no pending Slipstream functional, full-range/import conversion, accounting, native SY, deployment/UI, test, fork or integration completion gate remains. Shared V4 work and other approved scope continue; no unresolved release requirement is created.

The refactor produces:

1. Nine-decimal DETF and nine-decimal sDETF, with exact raw-unit 1:1 funded stake/unstake and nondecreasing funded rebases.
2. Protocol ownership of all reserve LP acquired by DETF operations, independent of the DETF held to honor sDETF redemptions.
3. Bonds holding fully funded, staked DETF principal that vests linearly; independently claimable staking rewards; every bond payout in sDETF.
4. Immediate seigniorage distribution and uncapped automatic expansion on fixed eight-hour boundaries, with funded sDETF payments for standing fee/creator rights.
5. Mandatory primary mint/burn price gating with reserve-swap fallback, shared by standard routes and their previews.
6. Pendle SY coverage for every in-scope SE vault and DETF, including separate raw-DETF and static staking SY addresses.
7. Consolidated public selectors, simplified new-deployment storage, revised deployment/caller configuration, and redesigned bond SVG/JSON.
8. Updated and consolidated production-path tests, requirement traceability across every affected family, and measured reductions in redundant compilation and test execution.

### 1.1 DETF family matrix

| Family | Implementation root relative to `contracts/vaults/detf/protocols/dexes/` | Required integration |
|---|---|---|
| Balancer V3 Single SE | `balancer/v3/standardExchange/single/` | **Excluded by D60; compilation maintenance only** |
| Balancer V3 multi-vault weighted | `balancer/v3/multi-vault-weighted/` | **Excluded by D60; compilation maintenance only** |
| Balancer V3 mixed buffer | `balancer/v3/mixedBuffer/` | **Excluded by D60; compilation maintenance only** |
| Balancer V3 composed stable | `balancer/v3/stable/common/` | **Excluded by D60; compilation maintenance only** |
| Uni V4 CP | `uniswap/v4/detf/`, CP reserve-hook binding | Unified DETF implementation; preserve host-specific quote/swap/bootstrap |
| Uni V4 Orbital | `uniswap/v4/detf/`, Orbital binding | Same |
| Uni V4 Weighted | `uniswap/v4/detf/`, Weighted binding | Same |
| Uni V4 Curve Quad | `uniswap/v4/detf/`, Curve Quad binding | Same |

Do not recreate deleted V4 family DETF diamonds. A passing CP test does not establish the other three hook bindings. The four V4 rows must satisfy the common requirements; the four Balancer DETF rows are excluded by D60.

### 1.2 SE coverage matrix

Add SY at the existing SE share-token address where its static share model permits it. Keep existing SE token decimals and economic entitlements. The two DETF wrappers are separate addresses because raw DETF issuance and static staking-share issuance have different semantics.

| SE group | Production package inventory / roots | SY integration rule |
|---|---|---|
| Uni V2, Camelot V2, Aerodrome V1 | `contracts/protocols/dexes/{uniswap/v2,camelot/v2,aerodrome/v1}/` | Existing SE shares; actual ERC-20 LP token is the yield token; existing proportional LP entitlement supplies the rate |
| Uni V3 | `contracts/protocols/dexes/uniswap/v3/` | Native position-backed SE; zero yield-token address where no underlying ERC-20 yield token exists; maximum usable tick range, including converted imports; D58 complete-book proportional/constant-product accounting |
| Slipstream | `contracts/protocols/dexes/aerodrome/slipstream/` | **Deferred by D66. Preserve completed functionality/tests/evidence; maintenance for compilation or shared V4 compatibility only. No unfinished release gate.** |
| Uni V4 SE | `contracts/protocols/dexes/uniswap/v4/` | Maximum usable tick range, including converted imports; exact deployed amounts plus sleeves and earned fees under D58 |
| Uni V4 buffer-hook SE | `contracts/hooks/uniswap/v4/standardExchange/` — single, dual, unified, Orbital, Weighted, Curve Quad and Balancer Quad packages | Integrate each registered share issuer; preserve hook liquidity units, existing external reward treatment and buffer routes |
| Balancer V3 SE pools | `contracts/protocols/dexes/balancer/v3/pools/` — constant product, standard-exchange buffer, stable common/mixed buffer, weighted multi-pair/mixed-leg/common buffer | Existing BPT/SE ownership model; distinguish a native pool share from a wrapper holding an external BPT |
| ERC-4626 | `contracts/vaults/standard/erc4626/` | Existing underlying vault share is the yield token; underlying vault accounting asset and proportional asset conversion |
| Aave V3.6 Stata | `contracts/protocols/lending/aave/v3.6/` | Actual Stata yield token; its underlying accounting asset and existing conversion |
| Morpho Blue | `contracts/vaults/standard/exchange/protocols/morpho/blue/` | Preserve native market-share accounting; market loan token is the accounting asset; no invented ERC-20 market-share address |
| Lido, EtherFi, Rocket Pool | `contracts/protocols/staking/{lido,etherfi,rocket-pool}/` | Actual wstETH/weETH/rETH yield token; preserve existing underlying conversion and token policy |

Enumerate every registered package under these roots in the Stage 0 manifest, including packages whose filenames do not contain `StandardExchange`. Router and rate-provider packages are dependencies, not additional SY share issuers. Do not declare a whole group complete based on one representative wrapper.

For existing SEs, the accounting asset is their existing underlying token or native liquidity unit, not a newly selected quote currency. For an ERC-20 accounting asset, report `AssetType.TOKEN`, its address and its actual decimals. For a native liquidity position, report `AssetType.LIQUIDITY`, its pool/host identifier and its existing liquidity-unit precision; a V4 pool identifier that cannot fit an address remains available through existing pool metadata. Do not pretend the manager address is an ERC-20 token. The rate is the current proportional accounting-asset entitlement per raw SE share, scaled by `1e18`, excluding trade-size price impact. Reuse existing accounting conversions, not a one-token spot swap quote. For V3/V4, D57–D59 explicitly require the full-range structure and V2-style complete-book accounting described in §7.4; update their underlying accounting before adapting it to SY. No one-token NAV policy is introduced.

## 2. Source anchors and architecture

### 2.1 Existing code to refactor

| Area | Source anchor | Planned treatment |
|---|---|---|
| Issuance split | `common/core/DETFMintSplitLib.sol` | Preserve ordinary gross/net split; generalize bond inputs from one `G` to independent `U` and `G` |
| Duration bonus | `common/core/DETFBondNFTMathLib.sol` | Preserve duration mapping, minimum validation and maximum clamp; use its full multiplier exactly once in the purchased quote |
| Standing fee weights | `common/core/DETFSeigniorageShareLib.sol` | Preserve top-up-only algebra; adapt ordinary weight to actual funded staking shares |
| Staking token | `common/claimToken/DETFFundedStakingRepo.sol`, `StakedDETFTarget.sol`, `RebasingClaimToken{Facet,DFPkg}.sol` | Held-DETF custody and funded gons; keep the existing integration role name where needed |
| Bond custody/lifecycle | `common/bondNft/DETFFundedBond{Repo,Target}.sol`, `DETFNFTVault{Facet,DFPkg}.sol` | Fixed principal, vesting and attributed staking gons; retain the required reserve-custody integration. Remove the unused legacy `DETFNFTVault{Target,Common,Repo,Service}` cluster after the verified import-boundary review |
| Interfaces | `contracts/interfaces/{IStakedDETF,IDetfBondNFT}.sol`, corresponding proxy interfaces, `contracts/interfaces/detf/` | Funded interfaces replace the V4 legacy surfaces; retain `IDETFNFTVault` only where excluded Balancer compatibility requires it |
| V4 DETF | `uniswap/v4/detf/UniswapV4Detf{Common,Target,Repo,DFPkg}.sol` under the family root | Shared clock and reward settlement; primary/swap branch selection; nine-decimal host conversion |
| Balancer DETFs | Family `*Common`, `*Repo`, `*BondingTarget`, exchange targets, facets and packages | Excluded by D60; repair shared-interface compilation dependencies only |
| Shared reserve quotes | `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol` and implementations | Make quote/execution units explicit; preserve host-specific price behavior |

Paths beginning with `common/` above are relative to `contracts/vaults/detf/`. The Single SE package is currently named `SingleStandardExchangeDETDFPkg.sol`; do not assume the alternate spelling exists.

### 2.2 Component boundaries

- **DETF diamond:** raw nine-decimal token, primary/swap route decision, issuance splits, expansion clock, reserve accounting and authorized reward minting.
- **sDETF diamond:** holds all DETF allocated to staking; owns gons accounting and the funded rebase; implements standard stake/unstake routes. It cannot use backing to acquire LP or redeem someone else's DETF against reserves.
- **Bond NFT vault:** retains necessary protocol LP custody and NFT authorization; owns one pooled sDETF escrow balance with explicit gons attribution per purchased bond. Its fee-role records are not LP claims.
- **Raw DETF SY:** separate static ERC-20 backed by raw DETF. Routes into DETF through the existing exchange core and wraps the received DETF without staking it.
- **Staking SY:** separate static ERC-20 backed by sDETF gons. Composes exchange, staking and unstaking through the same core accounting used by SE.
- **SE SY adapters:** thin facets/targets around existing SE asset/share calculations. Do not reproduce pricing, fee or custody logic in the SY layer.

New common math and settlement helpers belong under `contracts/vaults/detf/common/core/`. New DETF SY Repo/Target/Facet/DFPkg components belong under `contracts/vaults/detf/common/sy/`; common SE SY adapters belong under `contracts/vaults/standard/sy/`. Follow Crane Facet → Target → Repo, namespaced storage and dual layout helpers. Reuse existing Crane token/math/transfer/deployment primitives; do not import a second framework to implement the wrapper.

Reserve custody and staking custody must be separately reconcilable from actual token balances. Moving all reserve LP into a different contract is unnecessary: retaining the existing authorized LP custodian is acceptable, while deleting bond-owner LP liabilities. External LP balances remain external property.

## 3. Units, issuance and reserve redemption

### 3.1 Unit rules

- DETF, sDETF, raw DETF SY and staking SY use 9 decimals; `1e9` raw units equal one token.
- Percentages, synthetic prices and advertised SY exchange rates retain WAD precision. Gons use separate precision; token decimals never determine fee precision.
- Convert payment amounts to the quote adapter's documented unit, apply its existing math, and convert the result to native nine-decimal DETF once. Avoid applying a `1e9` correction at several layers.
- Update pool scaling factors, initial-price encoding, reserve ratios, exact-output rounding, Permit2 amounts, metadata, fixtures and clients. Existing payment tokens and unrelated SE shares keep their decimals.
- Output/entitlement calculations round down; required input for exact output rounds up. Use full-precision `mulDiv` rather than overflowing intermediate multiplication.

### 3.2 Retained equations

Let `p` be the existing issuance seigniorage fraction and `m(duration)` the existing full duration multiplier, including the base `1`. Preserve fee-oracle sources and their existing validation.

```text
ordinary U = existing reserve quote(payment * (1 + p))
ordinary user DETF = floor((1 - p) * U)
ordinary reward pot = floor(p * U)

bond G = existing proportional liquidity DETF quote(actual payment)
bond quote input = actual payment * m(duration)
bond U = first bond ? linear initial-price quote(quote input)
                    : existing live reserve swap quote(quote input)
bond P0 = floor((1 - p) * U)
bond reward pot = floor(p * U) + floor(p * G)
bond liquidity = actual payment + separately minted G DETF
```

Use the actual family route's input convention; the equations are not permission to multiply already-normalized native amounts again. The bond multiplier is not stacked with an additional ordinary-issuance `1 + p` quote uplift. `G` is unboosted; it is additional to `P0`. Never transfer a fictitious bonus payment into the pool.

For the first bond, use the configured initial-price `PkgArgs` value on a linear curve. **Historical, now excluded by D60:** Composed Stable was specified to carry its opening price and seed ratios into deployment arguments (D56), validate and store them, and use them consistently for independent purchased `U` and liquidity `G`. Support non-1:1 rich launches; remove the provisional hardcoded 1:1 bootstrap quote. For V4, preserve the existing opening-price override and its creation-price fallback. At price 2 payment units per DETF, payment 100 and multiplier 1.2 give gross `U = 60 DETF`, before the existing split. Later bonds use the live curve. Quote both `G` and `U` from the pre-purchase reserve state, then perform the actual join; previews must use the same order.

**Historical Composed encoding; no further functional work under D60:** `openingDetfPrices[2]` stores each accepted initial payment's price (whole stable BPT / whole DETF, whole common BPT / whole DETF), both WAD. This expresses the configured opening price in each payment unit without a live, size-dependent inner-pool quote. `reserveSeedAmounts[3]` is a representative native `[DETF, stable BPT, common BPT]` basket. Scale it from the supplied stable amount; required common payment is `floor(stableIn * seedCommon / seedStable)` and liquidity `G` is `floor(stableIn * seedDETF / seedStable)`, minted once for that basket. Reject mismatched payment ratios. Purchased first-bond `U` sums the separately bonus-adjusted payments converted at their configured prices; later `U/G` use the retained live formulas. All five configuration entries must be nonzero. Test distinct prices and an unequal seed basket as well as an explicitly configured 1:1 case.

Primary burn retains:

```text
LP to withdraw = floor(DETF in * protocol-owned LP / outstanding DETF supply)
```

Take the supply and LP snapshot after due expansion and before the primary burn. Outstanding DETF includes DETF held in the reserve pool and staking custody. Protocol-owned LP means actual LP attributable to the DETF, not total pool LP supply. No bond LP amount is deducted from protocol LP under the new design. Preserve the host's existing withdrawal and fee calculation after this mapping.

### 3.3 Immutable reserve liquidity policy and V4 LP-payment bonds

Carry `ownerOnlyLiquidity` from user-facing creation state into DETF deployment arguments and the reserve hook payload. Verify it against the actual deployed hook; do not trust a UI-only flag or hardcode one mode. DETF remains hook owner in both modes, creator is only the policy selector, no subsequent toggle exists, and swaps remain public. Audit every ordinary, standard and privileged liquidity entrypoint for equivalent addition/removal enforcement and LP ownership/allowance handling.

For the instance's own reserve-LP bond route, settle due expansion and snapshot all proportional reserve entitlements before accepting LP. Preserve each non-DETF leg; use the actual reserve binding's existing accounting/pricing and buffer conversion, excluding the direct DETF self-leg. Build the purchased quote from those non-DETF amounts with the duration multiplier once. Use the existing funded split with `G = 0`, mint/stake purchased principal and record the normal vesting NFT, then distribute newly issued seigniorage immediately so that funded position participates in its own purchase distribution. Keep the entire received LP in protocol custody; do not unwind it to quote or create a new matching DETF liquidity leg. Existing DETF in the LP is retained inventory, with no new-issuance seigniorage charge. First-bond activation remains the existing route.

Actual protocol-owned LP is the basis for redemption, synthetic pricing and expansion in both modes. Public-operation permissions do not change ownership. Cover externally held LP even when operations are restricted, and credit a submitted position only after its complete actual transfer.

**D65 approved redemption mechanism:** expose an owner-operated proportional reserve-LP redemption on the Fee Collector. Restricted hook additions remain DETF-only; removal also permits the current `feeTo()` collector, using a live oracle lookup on every call. Preserve LP ownership/approval, recipient, minimum-output and deadline checks. Test collector rotation, rejection of the old collector, transfer of its remaining LP to the new collector, rejection of collector deposits and unauthorized LP spending. Keep ordinary public removals restricted. Do not move the original standing staking-reward NFT rights on fee-recipient rotation.

## 4. Funded staking accounting

This section selects an Olympus-shaped dynamic gons model. It does not copy Olympus deployment caps, warm-up behavior, or unissued token inventory. Implementation must prove the stated invariants; a failed proof is a defect to resolve against this plan, not authority to substitute LP-valued staking.

### 4.1 Ledger and conversions

Use `K0 = 1e36` initial gons per native sDETF unit, current `K`, total outstanding gons `Q`, and `gonsOf[account]`. Initially `K = K0`, `Q = 0`. Never increase or reset `K` on an empty staking supply.

```text
balanceOf(account) = floor(gonsOf[account] / K)
redeemable aggregate supply = floor(Q / K)
stake x DETF: receive exactly x; credit x * K gons
transfer x sDETF: debit and credit x * K gons
unstake x sDETF: debit x * K gons; transfer exactly x DETF
```

These operations increase/decrease the relevant displayed balances by exactly `x`, including when the index is not an integer multiple of its initial value. Do not mint `floor(x / index)` shares and silently short the depositor's 1:1 principal.

Before increasing liabilities, verify actual DETF funding. Ordinary stake is principal, not reward income. Remove balance-delta reward discovery that treats every deposit as distributable yield. Track accounted backing separately from unsolicited DETF transfers; unsolicited balances are not public mint credit. A retained authorized donation route may explicitly allocate newly received funds using the reward settlement path, once.

### 4.2 Rebase and rounding

After resolving fee/creator amounts, let `S` be the actual ordinary-staking reward plus ordinary rebase dust already assigned to staking. For nonzero `Q`:

```text
old liability = floor(Q / K)
target liability = old liability + S
new K = ceil(Q / target liability)
new liability = floor(Q / new K)
consumed staking reward = new liability - old liability
ordinary rebase dust = target liability - new liability
```

Use full-precision arithmetic and an explicit ceiling. This keeps `1 <= new K <= K` and never issues aggregate liability above funded target. A zero funded reward leaves balances flat. Remaining quantization dust stays in DETF custody and is retried as ordinary rebase funding on a subsequent distribution; it is not charged another fee. Never reduce a holder's balance to force exact equality with backing.

Keep **allocation dust** from splitting a reward between weights separate from **ordinary rebase dust** whose fee allocation has already occurred. Allocation dust joins the next allocation; ordinary rebase dust joins only the ordinary rebase. Each raw unit has exactly one bucket. Unallocated unsolicited transfers are a third, separate category.

`floor(Q/K)` can exceed the sum of individually floored balances. This is conservative backing, not permission to withdraw another holder's rounding reserve. Test the aggregate and per-position invariants rather than assuming the sum of rounded balances always equals aggregate supply.

### 4.3 Full exits

On a full account unstake, pay its entire displayed sDETF balance in equal DETF units, then retire any remaining fraction below one raw sDETF unit. Reconcile any aggregate liability released by that retirement into ordinary rounding dust. Do not leave an account unable to exit its last whole native unit. Partial unstaking retains its fractional gons.

For a bond, retire only that position's final sub-native remainder after all its principal and whole-unit rewards are paid; never clear the pooled escrow's residual gons wholesale. For SY, keep conversion dust explicitly separate from outstanding SY backing. None of these final exits resets `K`, wipes standing fee weights, or awards unrelated dust to the next depositor.

No configurable supply, rebase, elapsed-time or mint-amount ceiling is introduced. Checked numeric representation limits are not a substitute policy cap. Arithmetic stress tests must exercise large uncapped catch-up values and conversions close to representation limits.

### 4.4 Standing fee/creator weights

Represent ordinary weight as actual funded gons `O = Q`. This includes freely held stake, bond escrow, SY custody and previously issued fee/creator sDETF. Maintain separate nonredeemable standing weights `Wf` and `Wc` in the same units. Preserve `DETFSeigniorageShareLib._topUpDeltas`:

```text
T = floor(O * 1e18 / (1e18 - f - c))
Wf target = floor(T * f / 1e18)
Wc target = floor(T * c / 1e18)
Wf += max(Wf target - Wf, 0)
Wc += max(Wc target - Wc, 0)
```

Apply top-ups after changes to funded ordinary gons, including issuing fee receipts for future distributions. An unstake never reduces standing weights. Transfers move existing ordinary weight and need no new standing weight. A rebase changes `K`, not gons. Do not count the standing weights themselves as sDETF supply or DETF backing.

Preserve reward-per-share floor allocation, using a precision compatible with the larger gons unit. Specify `REWARD_SCALE = 1e54`, full-precision multiplication/division, and allocate the current reward plus prior allocation dust as follows:

```text
W = Q + Wf + Wc
rps = floor(reward * REWARD_SCALE / W)
S = floor(Q  * rps / REWARD_SCALE)
F = floor(Wf * rps / REWARD_SCALE)
C = floor(Wc * rps / REWARD_SCALE)
allocation dust = reward - S - F - C
```

This retains the weight-based, top-up-only formula and conservative two-step floor structure; the precision changes with the new staking-share unit. It is not a fixed `F=f*reward`, `C=c*reward` split. When `Q=0`, standing weights still receive their proportional allocations, with only arithmetic dust left. Do not create an ordinary-staker remainder without an ordinary recipient.

Resolve recipients through the existing fee/creator beneficiary rules. Preserve the initial fee recipient's established right when the oracle's `feeTo()` subsequently changes, the creator-zero fallback, and existing standing-role ownership rules. Receiving ordinary transferred sDETF does not transfer a role. Redeeming all sDETF does not cancel it.

Fund `S + F + C + allocation dust` once; rebase with `S` first, then issue exactly `F` and `C` sDETF against their allocated DETF at the resulting `K`. Top up standing weights for the next distribution after those receipts exist. Do not let the new receipts participate in their own reward. Preserve configured fee validation; do not add a no-recipient policy contrary to D48.

## 5. Bonds and NFT lifecycle

### 5.1 Purchased position

Each purchased bond stores only the required economic position:

```text
P0: fixed net DETF principal purchased
claimedPrincipal: cumulative vested principal paid
stakingGons: gons still attributed to this NFT
startTimestamp
vestingDuration
```

Use existing ERC-721 ownership/approval state for authorization. `P0` never rebases. The duration bonus affects the purchased quote once and is not a second reward weight. Store additional data only if a retained active function needs it; image-only values derivable from this ledger need no storage.

At timestamp `t`:

```text
vested = floor(P0 * min(t - startTimestamp, vestingDuration) / vestingDuration)
principalDue = vested - claimedPrincipal
principalRemaining = P0 - claimedPrincipal
stakingValue = floor(stakingGons / K)
rewardsDue = stakingValue - principalRemaining
combinedDue = principalDue + rewardsDue
```

Require `stakingValue >= principalRemaining`; do not hide a principal deficit with a saturating reward subtraction. Claims transfer the corresponding sDETF and debit the position's gons at current `K`. They do not mint DETF, unstake, or withdraw LP. Reward-only claims leave `claimedPrincipal` unchanged; principal claims increment it only by principal paid. NFT transfer conveys its remaining position and does not restart vesting.

The pooled bond-vault balance must cover the sum of attributed position gons. Track any non-position dust separately. Neither reserved-role NFTs nor protocol LP custody may consume purchased-bond gons.

### 5.2 Purchase transaction order

1. Validate route, recipient, duration, minimum output and actual payment authorization.
2. If already opened, settle all due expansion before admitting the purchase.
3. Quote `G`, bonus-adjusted `U`, `P0`, and the reward pot from the same pre-purchase reserve state.
4. Receive actual payment; mint `G`; join payment plus `G`; retain resulting LP as protocol property. The first successful purchase initializes the reserve and anchors the epoch clock.
5. Mint and fund `P0` DETF into staking; attribute its sDETF gons to the new NFT and initialize vesting. Top up standing weights from this funded stake.
6. Mint and fund the separate bond reward pot, then distribute it immediately. The new bond participates as ordinary funded stake in this distribution.
7. Emit purchase and funding events from actual amounts. Revert the entire transaction on any failed settlement; never leave an opened clock or NFT after a failed bootstrap.

### 5.3 Minimal position-specific API

Retain one family-compatible bond purchase route because it requires duration and NFT recipient. Keep its existing route/Permit2 envelope where still useful; document the final signature in the selector manifest rather than inventing NFT data in fungible amount fields.

Use these common NFT payout operations:

- `claimPrincipal(uint256 tokenId, address recipient)` → vested principal in sDETF.
- `claimRewards(uint256 tokenId, address recipient)` → currently funded reward in sDETF.
- `claimBond(uint256 tokenId, address recipient)` → both, returning principal and reward amounts separately.

Each requires the existing owner/operator authorization, settles due expansion first, and derives its payout from the same view helper. Retain no alternative payment-asset or direct-DETF payout selector. A mature close is the final combined claim plus position retirement; consolidate its old asset-selecting variants into this lifecycle. Fully paid purchased positions may be retired under existing NFT retirement semantics only after all principal and whole-unit rewards are paid. Standing-role NFTs remain distinct and are not retired by redeeming delivered sDETF. They receive automatic fee settlement, not a second claim on the same reward pot.

Reference case: `P0=100 DETF`, halfway vested, `stakingValue=110 sDETF`, none claimed. Principal due is 50, rewards due 10, combined payout 60 sDETF. Combined claim leaves principal 50 and staking value 50. Reward-only claim pays 10 and leaves principal 100. Neither action changes the vesting clock.

## 6. Expansion, synchronization and fallback

### 6.1 Clock and aggregate calculation

Use a constant `EPOCH = 28_800` seconds. Store the last processed boundary in the existing `lastExpansionTimestamp` field, initialized at the first successful bond. The equations below call this value `lastSettledBoundary`; no separate write-only `epochAnchor` is needed because advancement always uses whole fixed epochs. Before opening, no automatic expansion is due.

```text
N = floor((now - lastSettledBoundary) / EPOCH)
completedElapsed = N * EPOCH
next settled boundary = lastSettledBoundary + completedElapsed
```

Calculate once from actual pre-action supply and the family's retained current price/rate eligibility. Do not fabricate historical pool prices or hypothetical intermediate fee receipts. For the current V4 equation, retain its per-epoch floor order and multiply its eligible per-epoch amount by `N`. Balancer-hosted DETF expansion work is excluded by D60; retain only shared-interface compilation compatibility there. Do not simulate reinvested per-epoch payouts or silently change family rate formulas to compound.

Mint the resulting eligible total once and distribute once. Advance the boundary even when the eligible result is zero. Preserve incomplete elapsed time. At hour 25 after opening, settle through hour 24 and leave hour 32 as the next boundary. Seven days supply 21 completed epochs; no previous one-day, epoch-count, BPS or absolute cap may truncate the result.

### 6.2 Entry ordering and reentrancy

All balance-changing entrypoints that can change reward participation synchronize due expansion before their action: DETF exchange/bond routes, stake/unstake, sDETF transfers, SY deposit/redeem/transfers, and bond transfer/claims. This establishes the boundary cutoff without a historical account-snapshot system. Pure reads report stored, actually funded backing; previews may simulate settlement explicitly for the proposed transaction.

Use a shared transaction settlement context with narrowly authorized DETF/staking/bond callbacks. Nested internal legs must not synchronize the same boundary or distribute the same pot twice. Mark the boundary/distribution consumed before external payout interactions, with transaction rollback on failure. A public caller cannot set a flag to bypass settlement or authorize use of idle assets. Reentrancy protection must allow the deliberate composition while rejecting unrelated callbacks.

For a transaction with due expansion and a new mint: expansion distribution comes first; then issuance and its immediate seigniorage distribution. Expansion fee receipts can participate in that later seigniorage. For ordinary mint-then-stake, mint seigniorage precedes staking the acquired DETF. For a bond, funded bond principal precedes its own seigniorage. Expansion itself is already a complete reward mint and creates no additional `p * expansion`.

### 6.3 Primary versus reserve swap

Remove `ThresholdMode.Open` and the enable/disable deployment choice. Retain configured threshold values and strict primary mint/burn inequalities. Equality and the deadband select reserve swaps. First-bond bootstrap, direct funded staking and bond claims retain their gate exemptions.

At execution, synchronize expansion, evaluate the primary gate on that resulting state, then call either the existing primary core or the existing reserve swap core. Select the branch explicitly; do not `try/catch` arbitrary primary failures. A swap branch does not mint/burn DETF, charge issuance seigniorage, or add a fallback surcharge. A prior expansion in the same transaction may have changed supply; attribute it separately.

The same decision helper must drive SE, SY composition and previews. When a composed input first redeems or swaps through an underlying SE, the subsequent reserve quote must reflect that operation’s changes to SE supply, backing, fees and buffered claims. Reuse the reserve family’s existing curve against the projected provider state; verify it against actual sequential execution from a restored snapshot. An idle protocol balance cannot subsidize a mismatched quote. Supported exact-output routes round required input up and honor refunds. Insufficient liquidity, unsupported routes, allowance, deadlines and user slippage retain their legitimate failure behavior. “Always execute” means price gating alone does not prohibit a valid reserve swap, not that user limits or missing liquidity are ignored.

## 7. Standard interfaces and SY accounting

### 7.1 Interface baseline

Use Pendle's four-argument deposit and five-argument redeem semantics from [IStandardizedYield](https://github.com/pendle-finance/pendle-core-v2-public/blob/main/contracts/interfaces/IStandardizedYield.sol). The local interface baseline reviewed for this plan is:

`lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol`

Content pin, SHA-256: `3696ff447383860a12fb18c50ac33bb498c92e48ceb1e5113417dc8850ddfad8`.

Implementation verified the interface against upstream revision [`bdbe57b3952961a9d5ab44b8c3ba5e6f5844df05`](https://github.com/pendle-finance/pendle-core-v2-public/blob/bdbe57b3952961a9d5ab44b8c3ba5e6f5844df05/contracts/interfaces/IStandardizedYield.sol). Its interface body matches the local copy after excluding imports, comments and whitespace. Exact hashes and source URLs are recorded in `implementation-artifacts/detf-funded-staking/pendle-interface-provenance.json`. Do not silently take a changed `main` ABI. Preserve Pendle raw-unit/WAD conversion conventions described in [Unit, Decimals and Scaled18](https://docs.pendle.finance/pendle-v2-dev/Contracts/UnitAndDecimals); Scaled18 is not selected here.

Required surface includes ERC-20 metadata/transfers, deposit/redeem and events, previews, exchange rate, directional token discovery/validation, asset metadata, yield-token metadata and required reward methods. `burnFromInternalBalance=true` burns SY held by the SY contract; false burns the caller's SY. It is not permission to consume arbitrary underlying inventory. Preserve the established internal-SY-balance semantics while testing their distinction from the SE pretransfer trust rules.

### 7.2 DETF SY matrix

| Property | Raw DETF SY | Staking SY |
|---|---|---|
| Share address | Separate from DETF and sDETF | Separate from DETF, sDETF and raw SY |
| Decimals | 9 | 9 |
| Accounting asset | `TOKEN`, DETF, 9 | `TOKEN`, DETF, 9 |
| Yield token | DETF | sDETF |
| Backing | Actually acquired raw DETF | Actually acquired sDETF gons |
| Rate | `1e18`, raw DETF per raw SY | Funded DETF entitlement per raw static SY, WAD |
| Inputs | DETF plus configured DETF input routes | sDETF, DETF plus configured DETF input routes |
| Outputs | DETF plus configured DETF output routes | sDETF, DETF plus configured DETF output routes |
| Staking action | None | Direct DETF stakes; route tokens exchange then stake |
| Reward-token methods | Empty compounded-reward surface | Empty; seigniorage/expansion is already in the rate |

Deduplicate discovery lists. Directional route membership, validation, previews and execution must match. A direct DETF or sDETF leg does not need reserve liquidity. No bond NFT deposit route or unvested-principal access is added.

For staking SY, assign `K0` gons to one native SY unit. With actual received gons `q`, mint `floor(q/K0)` SY. Record its backing separately from conversion dust. The advertised rate is `floor(K0 * 1e18 / K)`; redeem conservatively in raw DETF-equivalent units using `floor(syAmount * exchangeRate / 1e18)`, then transfer that amount of sDETF or compose the selected output route. Retire the burned shares' liability and record leftover sub-conversion gons as wrapper dust. Do not reset the global unit at zero SY supply, gift old wrapper dust to the first depositor, or calculate a rate from pending unfunded expansion.

The rate stays flat or rises as funded `K` decreases; SY holder balances stay fixed through rebases. Calculate deposit gons after due synchronization and from actual receipts. A zero-share result for a positive sub-share deposit must revert rather than confiscate the deposit. Previews use the same rounding and transaction order. Final minimum output is checked after every composed leg's fees; never use only an intermediate minimum as the user's SY protection.

Native SE adapters use their existing share/accounting model under §1.2. Return `address(0)` for `yieldToken()` only when the represented native position lacks an underlying ERC-20 yield token. An external wrapper around an SE share must report that actual share address even if the strategy uses Uni V3/V4. Preserve any existing separately distributed external SE rewards and indexes; do not both add a reward to the exchange rate and expose it as claimable income.

### 7.3 Selector replacements

`IStandardExchangeIn.exchangeIn` is exact input; `IStandardExchangeOut.exchangeOut` is exact output. Their names do not mean deposit versus withdrawal. Use token pairs to express direction.

| Old operation / selector category | New canonical route |
|---|---|
| `mintClaim`, `buyClaim`, duplicated fungible claim purchase | SE exact-in/out requesting sDETF, using direct DETF stake or the supported exchange-then-stake route |
| Standalone `redeemClaim` / fungible LP-valued claim redemption | SE with sDETF input, direct DETF output or a configured composed output route |
| Standalone fungible stake/unstake convenience aliases | Same SE pairs; SY deposit/redeem when static shares are requested |
| Claim token `mintFromNFTSale` and its previews | Remove the obsolete LP-sale valuation path; funded NFT claims transfer existing escrow sDETF |
| Mature LP sale, `sellPositionToDetfNft`, asset-selecting close variants | Position-specific funded claim/retirement under §5.3 |
| Generic NFT principal/reward claim | Keep only the documented position-specific methods; never force token ID or duration into SE token/amount arguments |
| Internal reward/principal funding hooks | Retain minimal authorized settlement hooks; do not advertise them as public mint alternatives |
| Legacy rate refresh, pending LP redemption and unused claim getters | Remove when their source state is removed; expose actual funded index/backing and current position views |

Preserve SE ABI semantics, deadline/recipient/approval behavior, supported exact-output capabilities and existing permitted Permit2 envelopes. Remove duplicate selectors from interfaces, implementations, `facetFuncs`, DFPkg cuts, ERC-165 declarations, generated ABIs and clients together. An unused target method is not sufficient evidence that a deployed selector is gone; test the assembled proxy.

### 7.4 Full-range position vault implementation (D57–D59)

- Use the spacing-aligned minimum/maximum usable ticks for V3 and V4. Keep ordinary V3/V4 full-range launches; unfinished Slipstream conversion is deferred by D66. Convert imported positions to this same structure before activation, tracking actual received assets through conversion and preserving user minimums.
- Require both tokens on initial activation. Retain subsequent single-token deposits and operations using funded sleeves while the underlying pool is locked or otherwise cannot be modified.
- Reuse canonical exact concentrated-liquidity math to derive deployed token amounts at current price and bounds. Build the complete token reserves from deployed amounts, sleeve balances and earned fees, with a defined once-only treatment of accrued versus collected fees.
- Apply V2-style proportional ownership and constant-product accounting to this complete book. Share issuance, redemption, transition quotes and native SY must use the same book and rounding conventions. Moving assets between sleeves and deployed liquidity, or collecting fees, must not count assets again.
- Validate ordinary and imported launches, tick spacings, mixed decimals, price movement, earned/collected fees, initial one-sided rejection, subsequent single-token entry, and actual lock-context sleeve operations through real deployed packages. Record exact source and test coverage per family; no adapter deferral remains authorized by an unanswered design question.

## 8. Storage and deployment changes

### 8.1 Required disposition

The implementation manifest must account for every member of each affected Repo struct as retained, replaced or removed, with its active reader/writer. The following dispositions are fixed:

| Existing state | Disposition |
|---|---|
| Claim `detf`, required authorization references | Retain for funded custody and authorized composition |
| Claim `totalShares`, `sharesOf` | Replace with consistently named funded gons state; update every reader/writer |
| Claim `rateAsset`, `detfNFTId`, `cachedRedemptionRate`, `lastRateUpdateBlock`, `pendingRedeemDetfOut` | Remove old LP/NFT valuation and redemption dependencies; a required descriptive asset getter derives DETF from the backing reference |
| Claim `lastSelfBalance` | Remove; already documented as unused compatibility storage |
| Bond user `originalSharesOf`, `effectiveSharesOf`, `bonusMultiplierOf`, `unlockTimeOf` | Replace purchased-position economics with §5.1 principal/gons/vesting state; bonus can be derived for metadata if needed |
| Bond `rewardPerShares`, `userRewardPerSharePaid`, `lastRewardTokenBalance`, `decimalOffset` | Remove the old second reward ledger/delta detector; shared staking and explicit reward buckets replace it |
| Bond aggregate LP-principal/effective-share totals | Remove; keep separate standing fee weights and actual protocol LP custody |
| Bond `lpToken`, DETF/staking references, NFT IDs and role initialization | Retain only actual custody, authorization and role identity; do not retain virtual LP entitlements for reserved NFTs |
| Family `userBondedLp` and equivalent user-owned LP counters | Remove; LP acquired by new bonds is protocol-owned |
| Family `thresholdMode` / Open flags | Remove; thresholds remain |
| `expansionCatchUpMaxSeconds`, `expansionCatchUpCapBps`, `expansionMaxCatchUpEpochs`, equivalent cap fields | Remove storage, init args, getters, validators and consumers |
| Per-instance adjustable epoch duration | Replace with fixed eight-hour constant; no deployment override |
| Expansion timestamp bookkeeping | Replace/adapt to first-bond anchor and last completed boundary |
| Opening prices, active route tables, hook/pool references | Retain where used by bootstrap or live standard routes |
| Old close-to-payment-asset route configuration | Remove if only used by the retired bond payout routes; preserve active ordinary DETF output routes |
| Shared library fields used outside this refactor | Retain until repo-wide usage proves them dead; simplification is not authority to break unrelated products |

Add only the funded gons/index/backing buckets, standing fee weights, fixed principal/vesting state, wrapper backing/dust and minimal settlement context required above. Remove getter-only fossils together with their getters. No padding is kept solely to mimic an old layout. This is a new-deployment refactor; no live instance is upgraded or reinterpreted.

The current import audit corrects an earlier inventory assumption: no Balancer DETF or other product uses the old common NFT ledger implementation. Its six-file implementation/lifecycle cluster and 17 storage members are dead. The owner-approved cleanup includes their removal, the four unused Pons imports, unused V4 imports and seven tests that assert obsolete struct shapes or the old LP compound dust gate. Preserve the current funded custody/claims and legacy interfaces still required by excluded families. See `obsolete-common-ledger-cleanup-prepared.json` and `obsolete-common-ledger-test-consolidation.json`; prepared changes are not passing validation.

### 8.2 Wiring and deployment

Use existing CREATE3 FactoryServices for facets and packages, and IndexedEx manager/registry deployment for vaults and DETFs. Update interface-owned `PkgInit` / `PkgArgs`, factory artifact seeds, package cuts, registries, TestBases and launch serialization together. Do not bypass registered deployment paths.

Predict DETF, staking, bond and wrapper addresses using the existing deterministic deployment machinery; bind cross-references during authorized initialization and verify them in post-deploy checks. Do not leave public setters for later ownership wiring or introduce an owner capable of changing immutable-instance economics. Deployment fails atomically if required components cannot be wired.

Remove cap and Open-mode arguments rather than ignoring supplied values. Keep existing initial/opening price, threshold and fee configuration sources. Add wrapper component dependencies/address discovery without requiring callers to guess CREATE3 salts. Old deployment payloads with removed fields must fail decoding/validation, not select a silent compatibility mode.

Current size-driven packaging keeps projected V2 queries in `UniswapV2StandardExchangeQueryFacet`, supplied explicitly through package initialization and installed by the registry-deployed package. Shared V4 composed quote operations use the existing `UniswapV4SeBufferHookLegLib` as a linked view library. Factory and rehearsal builds must include these dependencies. These are implementation boundaries; they do not change approved routes, pricing or EIP-170 limits.

New layout and selector manifests must be checked against every assembled proxy. Test deterministic address prediction, repeat-deployment behavior, two-instance isolation and absence of initializer replay. Reconcile other contributors' completed work at the authorized implementation baseline; never delete it merely because it introduced a selector that now needs a standard replacement.

## 9. Bond SVG, metadata and callers

Use one position-view calculation for JSON traits, SVG and application bond views. The renderer must not calculate an independent reward amount from LP shares or spot prices.

The purchased-bond image has a clear identity line (DETF name/symbol and NFT ID), purchased DETF principal, a linear vesting progress bar with start/maturity, remaining DETF principal, and three labeled values: claimable principal, claimable staking rewards, total claimable — all payouts labeled sDETF. Display actual nine-decimal amounts with bounded formatting; JSON retains exact values. No APY promise, unfunded expansion projection, LP entitlement or raw gons appears in the customer view.

Required render fixtures:

| State | Required content |
|---|---|
| New bond | Purchased principal and zero elapsed principal vesting; any already-funded immediate reward may be claimable |
| Halfway, value 110 on principal 100 | 50% vested; principal due 50 sDETF; reward due 10 sDETF; total 60 sDETF |
| Same timestamp after combined claim | Remaining principal 50 DETF; zero current claimable principal/reward |
| Reward-only claim | Principal and progress unchanged; only claimable reward reduced |
| Fully vested, not fully claimed | 100% vested and actual remaining claimable principal/reward |
| Partially claimed / tiny amounts | Correct exact accounting and legible nine-decimal formatting without implying zero when nonzero |
| Standing fee / creator role | Explicit standing-role description and recipient; no purchased principal or vesting story; receipt redemption does not mark role exhausted |

SVG is self-contained and escapes user-controlled names/symbols; JSON is escaped independently. No external scripts, fonts or image requests. Validate representative long names, special characters, zero rewards and large values. Capture rendered previews as review artifacts during implementation; image generation is not needed to implement deterministic on-chain SVG.

Migrate supported frontend/script callers to standard routes and the new NFT claims. Update ABIs, decoding, token formatting, price displays, role receipts, bond claim labels and transaction previews. The active frontend is `frontend/apps/dtf`; root historical progress files are not the implementation roadmap. Update current law/family docs that otherwise tell future contributors to use 18-decimal DETF, Open mode, capped expansion or LP-backed claims. Preserve the historical documents with explicit supersession links rather than rewriting their past completion claims.

## 10. Implementation stages

Explicit implementation authorization has been received. Stages are dependency ordered; completion requires their stated evidence. No production migration or deployment is included in these stages.

### Stage 0 — Baseline and manifests

- [x] Establish an isolated implementation baseline without disturbing another agent's active checkout; record base commit and source state.
- [ ] Enumerate all four in-scope V4 DETF bindings and every SE share-issuing package in §1; record route lists, accounting/yield assets, unit conversions, current external rewards, facet cuts and factory dependencies.
- [ ] Record the exact interface-to-target-to-facet-to-package selector replacement map, including signatures of retained family bond purchase routes and NFT methods.
- [ ] Record field-by-field storage disposition and every affected deployment payload, script, ABI and application caller.
- [ ] Inventory existing affected tests, fixtures and inherited suites; map each to retain, update, merge or retire, and capture baseline compile/runtime measurements under §11.1.1.
- [x] Pin local/upstream dependency provenance; reconcile the existing Pendle interface content against §7.1 without changing the accepted ABI.

**Exit:** manifests cover actual packages, not only filename patterns. All entries follow the fixed policies above; any contradictory implementation is identified as work to change, not an unanswered product decision.

### Stage 1 — Shared math and nine-decimal boundaries

- [ ] Generalize the bond split to independent `U/G`; preserve ordinary split, fee top-up algebra, duration formula and burn-to-LP mapping.
- [ ] Implement full-precision gons/conversion, vesting and reward-allocation helpers with independent arithmetic test vectors.
- [ ] Specify exact native/WAD boundaries in all four in-scope V4 reserve adapters and deployment price encodings; update DETF decimals and affected expected amounts.
- [ ] Prove funded liability, monotone index, exact stake/unstake, distribution conservation and full-exit behavior before integrating external calls.

**Exit:** golden vectors establish unchanged baseline economics where required, intentional changed bond inputs, no double bonus, and no loss of one whole raw principal unit from conversion.

### Stage 2 — Funded sDETF and standing recipients

- [ ] Replace spot-valued claim accounting and implement shared principal/reward funding, rebase, standard stake/unstake and transfers.
- [ ] Implement standing weights, beneficiary resolution, fee/creator receipt settlement, dust buckets and reentrancy-safe synchronization hooks.
- [ ] Remove obsolete claim storage, LP redemption hooks and duplicate fungible selectors in the affected common components.
- [ ] Cover all-zero ordinary stake, recipient full redemption, later new receipts and donated/idle-balance negatives.

**Exit:** backing is isolated and sufficient across arbitrary funded stake/reward/transfer/unstake sequences; fee rights persist independently of balances.

### Stage 3 — Bonds, protocol LP and bootstrap

- [ ] Replace user LP accounting with `P0`, claimed principal, attributed gons and linear vesting.
- [ ] Implement first-bond linear quote and separate liquidity self-leg, later curve quote, funded purchased principal and immediate bond seigniorage order. A33 is excluded under D60; do not continue Composed functional implementation.
- [ ] Implement principal-only, reward-only and combined sDETF claims, transfer authorization and mature retirement.
- [ ] Remove old LP-sale/asset-payout paths; reconcile actual reserve custody without treating external LP as protocol property.
- [ ] Implement own-reserve V4 LP payment under §3.3: pre-transfer settled valuation, non-DETF legs only, whole-position custody, `G = 0`, funded vesting and immediate new-issuance rewards (A38–A40).

**Exit:** A4–A8/A16/A18 examples pass through real deployed contracts, including multiple NFTs, transfers, partial claims and the last principal unit.

### Stage 4 — All-family epochs and primary/swap routing

- [ ] Implement first-bond anchored eight-hour settlement and one aggregate catch-up with every cap removed.
- [ ] Route seigniorage immediately to the shared distributor; remove old automatic reward-to-LP joins and recursive reward minting.
- [ ] Remove Open/configuration modes and implement explicit post-expansion primary/swap selection shared with previews.
- [ ] Wire immutable `ownerOnlyLiquidity` through creation, DETF payload and actual hook; validate both modes and public swaps (A37). Implement and validate the approved dynamic Fee Collector redemption exception (D65/A41).
- [ ] Integrate the common lifecycle into all four V4 bindings, preserving the host's actual formulas/routes.

**Exit:** every family passes boundary/equality, 25-hour, seven-day, zero-eligible and supply-neutral fallback cases. No family retains a hidden capped/ungated profile.

### Stage 5 — Pendle SY and complete standard surface

- [ ] Implement separate raw-DETF and staking SY packages, static gons backing, metadata and all directional routes.
- [ ] Implement the V3/V4 full-range, imported-position conversion, complete-book accounting and two-token activation requirements in §7.4 (A34–A36).
- [ ] Add native SY adapters to every in-scope SE package in the manifest, using its accepted asset/share model, decimals and external reward behavior.
- [ ] Wire all wrappers/facets through FactoryServices and manager/registry deployment; remove legacy selector exports and update interface declarations.
- [ ] Test complete SE/SY transactions, exact-output SE paths, internal-SY redemption, projected previews and actual final output limits.

**Exit:** every in-scope manifest row has live proxy calls demonstrating its metadata, accepted tokens, funded deposit and redemption, plus negative selector and trust tests.

### Stage 6 — Metadata, callers and complete cleanup

- [ ] Implement SVG/JSON from the common position view and capture all §9 fixtures.
- [ ] Migrate active application, launch scripts, ABIs and configuration to nine-decimal tokens and standard routes.
- [ ] Complete storage-reader/writer cleanup, dead getter removal and package/deployment argument cleanup.
- [ ] Consolidate affected tests and fixtures under §11.1.1; replace superseded expectations, remove redundant suites after mapping their coverage, and preserve distinct family/route regressions.
- [ ] Reconcile current family/law/product docs and add supersession links to historical plans.

**Exit:** no supported caller depends on retired selectors or removed fields; image and transaction displays agree with actual funded accounting.

### Stage 7 — Integration and release evidence

- [ ] Complete the common acceptance matrix below for all applicable packages and family bindings.
- [ ] Run focused tests, full hermetic suite and available in-scope protocol fork smoke tests using repository workflows; document any unavailable fork environment explicitly.
- [ ] Review conservation/authorization failures, final selector/storage manifests, CREATE3 deployment wiring and current docs against D32–D66.
- [ ] Report before/after compilation and test runtime, compiled test-contract counts and consolidation coverage mapping; explain remaining bottlenecks or regressions.
- [ ] Produce the reviewable change/validation report and residual limitations. Do not mark completion based solely on common-unit tests or a subset of families.

**Exit:** requirements and validation are traceable to artifacts and passing results. Production deployment, migration and publication remain separate actions requiring their own authorization.

## 11. Validation specification

### 11.1 Test organization and execution

Use `CraneTest` → `IndexedexTest` → the actual protocol TestBase. Deploy facets through FactoryServices and vault/DETF packages through the manager registry. Use production contracts and real protocol ports for hermetic tests; do not mock the DETF, staking token, bond vault, fee oracle, manager or registry.

Add common behavior coverage under `test/foundry/spec/vaults/detf/` for funded staking, reward distribution, linear bonds, epoch settlement, standard routes and SY. Apply it through each family's existing test directory. Add SE SY behavior coverage to existing SE package tests. Include `Behavior_IFacet`/`Behavior_IDiamondFactoryPackage` and assembled-proxy assertions rather than testing targets alone.

Update and consolidate existing suites as part of this work; do not simply add a parallel refactor suite while leaving redundant legacy suites active. Follow §11.1.1 to reduce compile and execution costs while retaining the acceptance matrix.

After production source changes, use the current repository sequence:

```sh
forge build
forge test --match-path 'test/foundry/spec/vaults/detf/**/*.t.sol'
forge test
```

Stage-specific runs may target individual tests before the final full suite. Fork tests use `FOUNDRY_PROFILE=fork forge test --match-path '<actual affected fork test path>'` with the configured RPC environment, separately from hermetic CI. Run the active frontend package's declared checks after caller changes. Record exact commands and results; a planned command is not evidence of passing tests.

Before the first compile in a new worktree, seed `out/` and `cache_forge/` from a warm checkout as required by `CLAUDE.md`. Do not delete caches or interrupt another agent's compile. Cold compiles may take tens of minutes; wait for real completion. `via_ir` remains forbidden. FactoryServices read creation bytecode from `out/`, so `forge test` alone after source edits is insufficient.

### 11.1.1 Test consolidation and performance

Reducing redundant compilation and test execution is an explicit implementation objective. Consolidation must preserve meaningful coverage and failure diagnostics.

- **Replace obsolete expectations.** Rewrite tests for LP-backed claims, cliff-only bonds, Open mode, capped expansion and eighteen-decimal DETF around the accepted behavior. Remove tests that exist only to preserve deleted functionality. Map every retired regression to its surviving assertion or the decision that makes it obsolete; do not delete a failing test without that accounting.
- **Test common arithmetic once in depth.** Put exhaustive pure-math vectors and fuzz coverage for the identical shared implementation in canonical common suites. Each family still needs production-path integration proving its units, wiring, custody, fees, bootstrap, gates, epochs and routes; do not duplicate the entire common math corpus in every family contract.
- **Reuse focused fixtures and behaviors.** Consolidate duplicated deployment helpers, actors, stateful handlers and assertion logic using the existing TestBase/FactoryService hierarchy. Keep protocol-specific setup narrowly scoped. Avoid importing or deploying unrelated protocol stacks for a common test, and avoid inheriting the same large executable suite into many concrete test contracts merely to reuse helpers.
- **Preserve distinct integrations.** Retain all four in-scope V4 DETF bindings, every in-scope SE package's standard surface, family-specific failures, multi-instance isolation, exact-output paths and security regressions. Parameterize equivalent cases where it removes duplicated code/setup while retaining identifiable failures and isolated state. Do not replace all family integration tests with one representative family or combine everything into one oversized test contract.
- **Measure compilation separately from execution.** Capture comparable before/after build time, affected-suite runtime and full hermetic-suite runtime, along with concrete test-contract counts and the largest affected test artifacts. Record compiler settings, command/filter, source revision, machine and cache state. Compare like-for-like incremental builds and warm test runs; label any cold-build measurements separately. Source deduplication alone is not evidence of reduced compiler work.
- **Preserve assurance.** Do not achieve a faster result by lowering fuzz/invariant runs or depth, weakening assertions, skipping required suites, mocking production components, or dropping meaningful test isolation. Use targeted runs during development and the required complete checks at integration milestones; repeat broad runs when changes or failures justify them.

Stage 7 must show which redundant suites/deployments were removed, where their coverage moved, and the measured effect. Report any remaining slowdown attributable to new coverage or unresolved compilation cost explicitly; do not claim a speedup based only on fewer source files. Benchmarks run in the current implementation workspace with recorded provenance and an independent baseline; do not clear or interfere with another agent's build artifacts.

### 11.2 Requirement traceability

| PRD acceptance | Required evidence |
|---|---|
| A1, A13 | Nine-decimal metadata; native/WAD/payment decimal vectors; preserved ordinary split and burn-to-owned-LP mapping; principal funding excluded from rewards |
| A2, A3 | Sequence invariants for held DETF, gons liabilities, nondecreasing funded index, direct 1:1 exits, pool-price independence and final exit |
| A4, A5, A16 | First and later bond purchase through each reserve host; actual payment plus unboosted `G`; independent bonus-adjusted `U`; purchased principal funded immediately |
| A6, A7, A8, A18 | Exact vesting fractions, repeated/partial claims, 100/110 halfway case, reward-only claims, owner/operator and transfer cases, pooled-escrow isolation |
| A9, A14, A15, A23 | One reward funding allocation; rebase-before-receipts; fee-weight floor reference; zero ordinary stake; full recipient redemption followed by new sDETF |
| A10, A11, A26 | Each strict gate/equality/deadband; pre/post-expansion branch; actual supply-neutral swap; legitimate error propagation; Open rejected at deployment |
| A12, A19, A20, A21 | Each SY's metadata and raw-unit conversions; static balances; both internal-balance modes; all directional routes; empty or preserved external reward surface as applicable |
| A17, A22, A24, A25, A27 | Immediate seigniorage between epochs; just-before-boundary eligibility; post-boundary new stake excluded; fixed 25-hour/seven-day catch-up; one mint/distribution; no caps or hypothetical compounding |
| A28, A29 | Interface/target/facet/cut/proxy selector matrix; removed selectors fail; standard replacements preserve approval, recipient, route and slippage behavior |
| A30 | Complete field disposition and reader/writer map; removed initialization/accessors/config fields; cross-instance storage isolation |
| A31, A32 | Parsed JSON amounts match common views; rendered SVG states; correct sDETF labels, nine-decimal formatting and escaping |
| A33 | Excluded by D60. Preserve historical evidence; compilation maintenance only for Composed DETF |
| A34 | V3/V4 only; each position family and tick spacing: ordinary full range and conversion of narrow imported positions with asset conservation |
| A37 | Both immutable deployment modes, UI/payload/hook agreement, owner/add/remove/LP-spend enforcement and public swaps |
| A38–A40 | Own-LP non-DETF valuation, multiple/buffered legs, complete custody, pre-transfer settlement, no matching `G` or seigniorage on existing DETF, funded bond and external-LP conservation |
| A41 | Current Fee Collector redemption in restricted mode, feeTo rotation and old-collector rejection; no public-removal or collector-deposit exemption |
| A35, A36 | V3/V4 only; exact CL token book plus sleeves/fees once; proportional/CP share and SY accounting; price/mixed-decimal/collection tests; two-token activation and subsequent single-token/locked-pool sleeve operations |
| A42 | Owner-deferred Slipstream disposition in scope/decision records and manifests; preserve completed code, existing tests and evidence; remove only unfinished release gates. No Slipstream fork/integration or product-question blocker. |

### 11.3 Adversarial and conservation cases

Exercise these against the actual components, using stateful handlers where interaction order matters:

- Conservation across DETF mint/burn, LP join/exit, funded reserve, reward buckets, freely held stake, each NFT position and SY backing. A unit cannot be both ordinary rebase funding and fee principal.
- Stake immediately before versus after a boundary; transfer/unstake/wrap/claim at a boundary; long idle catch-up; repeated synchronization in one transaction; zero eligible expansion.
- Fee and creator equal addresses, creator fallback, later oracle recipient change, full redemption to zero, recipient transfers, only standing weights remaining and very small floor allocations.
- Multiple bonds with different starts/durations, interleaved partial claims, transfer to another owner, reward claims after full principal claim, final fraction cleanup and unauthorized operator/recipient attempts.
- Direct donations and preexisting idle funds before SE/SY calls; false pretransfer assertions; short delivery; duplicate callback; reentrancy into mint/distribute/claim; allowance and deadline failures. Only actual credited input funds new claims.
- Gate equality and a gate changed by expansion; swap output insufficient for user minimum; unavailable liquidity; exact-output refunds; configured input-only or output-only tokens.
- SY share transfers and rebases, empty wrapper supply, tiny deposits producing zero shares, rounded final redemption, wrapper-held internal shares, unsupported reward claims and pending-but-unfunded expansion in views.
- Large uncapped expansion, mixed token decimals, price normalization and rounding extremes. Compare with independent integer reference math rather than the same production helper.
- Every facet advertised selector through the real proxy; all retired aliases absent; failed/duplicate initialization; address prediction and two instances with unrelated balances/epochs.

## 12. Completion record — current readiness execution

The [remaining readiness plan](./DETF_PRODUCTION_READINESS_REMAINING_IMPLEMENTATION_PLAN.md) is executing against local Solidity/configuration SHA `187b03242b92380b8696be84a5d3f55a74ba4a140012b67820a4bee70cd7b2fe` and Crane SHA `b45a057611f782040ee29f1fddbbcc8eeba01def2c9341ef01c6bb65f685e123`. The owner-reported passing baseline remains distinct from agent-executed evidence. The previous completion record, process descriptions, timing estimates and failed historical snapshots are preserved in [before-parent-implementation-plan.md](../../../implementation-artifacts/detf-funded-staking/production-readiness/before-parent-implementation-plan.md) and [before-lifecycle-report-renewal](../../../implementation-artifacts/detf-funded-staking/production-readiness/before-lifecycle-report-renewal/).

Before PR-09/10, the corrected complete build, including all 294 maintained scripts, passed in 27,719.527 seconds. All 31,305 unfiltered default tests across 2,695 suites passed, with zero failures/skips; command wall time was 1,042.441 seconds. The 27 targeted security/boundary cases overlapped that full result. These results are historical for the changed production paths: a matching complete build, seven new regressions, 27 existing regressions and the full suite are queued in dependency order. The 27 provider fork cases and eight retained V3 cases retain their actual passing runs and pins through the record-specific 423-file dependency-closure proof. Frontend sources remain unchanged; lint, typecheck and 410 tests are reusable, with compiled ABI hashes to be renewed after the final Forge commands. No coverage settings were reduced.

Production changes reject positive DETF redemptions that would deliver zero final assets, retain unmintable self-leg dust as protocol inventory, and protect three canonical-registry mutations with existing owner/operator authorization. The vulnerable pinned public core is ineligible for this candidate; a fresh corrected core is being deployed only to the strict local fork. Launch changes isolate frontend exports, include all 19 architecture funding stages, validate isolated funding artifacts, and align staged local simulation/broadcast fees. Direct dust/boundary cases remain separate from constructive `bound()` fuzz inputs. Legitimate zero partial NFT claims preserve unvested principal.

The prior compiled inventory is 2,695 contracts / 31,305 methods against the independent baseline's 3,073 / 36,563. In-scope/shared methods were 27,551 versus 29,085; their contract and artifact-byte counts increased. Current source review confirms seven additional tests and no removed test declarations; fresh compiled counts remain pending. The 3,112-file source comparison reuses archived immutable-baseline descriptions/hashes because the old Git worktree/object is unavailable, and recomputes the current side. Different snapshots, failures and cache states prevent a controlled full-suite speedup claim; the earlier identical 14-case comparison remains the controlled fixture evidence. Reviewed storage and package payload source hashes are unchanged; runtime and artifact reconciliation will be renewed after validation.

Remaining gates are the matching complete build/tests, final package/caller artifacts, a fresh strict local deployment on port 18665, runtime/receipt reconciliation, all 39 lifecycle cases including funded staking and SY round trips, the isolated complete funding quote on port 18664, and final acceptance/handoff. The completed older node on port 18663 remains preserved. The new local node enforces 24,576-byte runtimes and 32,000,000-gas blocks; lifecycle money paths retain 30M call bounds. Current status and exact evidence are in [execution-status.md](../../../implementation-artifacts/detf-funded-staking/execution-status.md), [acceptance-progress.json](../../../implementation-artifacts/detf-funded-staking/acceptance-progress.json) and the [validation report](./DETF_FUNDED_STAKING_AND_SY_VALIDATION_REPORT.md).

D60 Balancer-hosted DETFs and D66 unfinished Slipstream remain excluded/deferred. The H9 test-domain remediation is an excluded-family limitation, not a production redemption fix. This internal review is not an independent external audit. Public deployment, customer activation and fund migration remain outside this execution.
