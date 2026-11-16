# T5-EGRESS r2: principal SY, retained ownership, and funded reward rights

Date: 2026-11-10. Revision: `t5-egress-principal-sy-r2`.
Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`.

**Construction delivered, not production implementation or E5 acceptance.**
This is one construction: checkpoint rewards to the old SY owner before every
share mutation; represent those rewards at the standard boundary by an actual,
nonrebasing, exactly gon-backed ERC20; use local wide-integer Pendle reward
consumers; and route upstream principal outputs through a bounded local egress
adapter's external SY balance before creating its own internal-burn ticket.
Neither an index annotation nor an assumed change to shared Pendle is part of
the construction.

The independent r1 findings F1, F2 and F3 are accepted. The historical
`egress-contract.md`, `egress-verification.md` and both evidence directories
remain immutable. The complete 701-line r1 was read; SHA-256 of the inspected
text is `5104e78908e38274c987b7e8dfcd2e291373d984c78d919908a5f11f4bcb0506`.
The complete correction/implementation briefs, implementation handoff, main
checkout Migration implementation plan, original models/results and independent
models/results were read.

## 1. Exact revision boundary

The native-principal receipt ledger, real funded rebase/allocation equations,
bond cliff, fixed role-allocation ownership, principal output budgets, and
irreversible activation contract of r1 remain normative. This document replaces
r1 sections 2.3, 6.1, 6.3-6.5 and their SY API/storage/operation-matrix rows.
It changes the domain-2 release boundary and adds the integration components
listed in section 8. It does not change domains 0/1, ordinary products, source
eligibility, pricing, ownership administration or bootstrap authority.

| Rejected r1 rule | Required r2 replacement |
| --- | --- |
| Standard reward token is sDETF; index is `Q-k` | Standard reward token is the actual reward-rights ERC20 **RG**; one native RG is one gon; index is `1 + W*(Q-k)` in WAD-scaled native RG per native SY. |
| Prior reward slice follows transferred SY | All accrued gons stay with the pre-transfer SY owner. Only `x*k` principal gons move with `x` shares. Explicit reward-right transfer is separate. |
| SY claim pays native sDETF directly | SY claim materializes already owned gons into RG, without liquid payout, in either stage. Only RG redemption pays sDETF and requires activation. |
| Domain 2 can also pay the same standard claim | Domain 2 materializes RG only. There is no second domain-2 native release route. |
| A new final selector alone solves upstream push | Direct pull uses `(adapter,user)`. YT/market outputs go first to the adapter's external SY balance, then its own transfer creates `(adapter,adapter)`. |
| Ordinary narrow Pendle reward storage is sufficient | Exact-gon rewards require the explicitly local wide reward consumers below; unchanged narrow consumers are not accepted. |

This introduces one new **representation of an existing right**, RG, not a second
staking supply, funding source, reward allocation, principal basis or owner
authority. Unlike sDETF, RG cannot be unstaked or spent as principal before
activation. Its transfer is the economic-right assignment already permitted
for locked gons. Materializing or transferring that right is not liquid
DETF/sDETF reward delivery.

### Why this boundary, rather than a scalar correction

An old YT user's recorded native sDETF amount does not rebase when its reward
shares reach zero. Continuing to expose rebasing sDETF therefore cannot represent
that user's growing retained gon right with the stock one-index accrual rule.
RG has a constant native balance and an appreciating redemption value instead.
There is no extra index payment for appreciation of already issued RG.

One native RG is deliberately the smallest existing ledger unit, one gon.
Larger quanta require a second fractional-ownership ledger at each consumer;
simply dropping or reassigning those fractions is not acceptable. Exact units
instead require wide local reward fields and full-precision multiplication.
This is the reason for the bounded local consumer adaptation, not permission
to alter shared consumers, market pricing, gauge boosts or yield ownership.

## 2. Read source anchors and their implications

Prefixes are relative to this worktree:
`C = contracts/vaults/detf/common/`;
`P = lib/crane/contracts/protocols/perps/pendle/`;
`M = contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.

| Read source | Implemented observation; not a claim about deployed Migration |
| --- | --- |
| `C/core/DETFFundedStakingMath.sol:10-12,46-94` | `Q=10^36`, allocation precision `10^54`, native conversion by floor, funded divisor by ceiling. |
| `C/claimToken/DETFFundedStakingRepo.sol:24-36,93-123,185-201` | One gon/backing authority; ordinary full-account withdrawal destroys fractions; allocation rebases before issuing role gons. Migration still replaces that destructive exit. |
| `C/sy/DETFSYTarget.sol:54-121,173-180,196-256` | Ordinary SY has concrete transfers/redemption, bearer self-balance burning, no reward list, three output branches and measured acquisition. These are not already the r2 semantics. |
| `C/sy/DETFSYRepo.sol:38-56` | Receipt/parent identity and route sets are once initialized; receipt routes are automatic only for staking SY. |
| `P/core/RewardManager/RewardManagerAbstract.sol:16-29,44-64` | Initial reward index is **1**, user shares multiply an index delta, and both index and accrued native reward amounts are narrowed to `uint128`. |
| `P/core/libraries/math/PMath.sol:20,34-38,48-52` | Native reward multiplication divides by `10^18`; the ordinary implementation multiplies in uint256 before division. |
| `P/core/YieldContracts/PendleYieldToken.sol:124-153,317-339,443-495,498-503` | PY exit does not clear user rewards; YT transfers SY itself; reward shares are SY-equivalent units; accrual occurs before YT balance changes. |
| `P/core/YieldContracts/InterestManagerYT.sol:63-79`; `P/core/StandardizedYield/SYUtils.sol:7-20` | At constant principal rate `W`, PY converts 1:1, no interest is created, and reward shares equal initialized users' YT balances. |
| `P/core/YieldContracts/PendleYieldToken.sol:199-225,373-385,421-476` | First expiry checkpoint reserves the then-held reward inventory for users; later rewards go to treasury; fees are taken from native reward amounts. |
| `P/core/StandardizedYield/SYBaseWithRewards.sol:7,74-95` | Reference SY checkpoints before transfer and warns against using the yield token itself as reward token. RG and sDETF are different tokens. |
| `P/core/RewardManager/RewardManager.sol:27-55,61-75`; `P/core/Market/PendleGauge.sol:43-47,62-86,94-114` | Market reward allocation uses actual received native tokens and **active balances**, not raw LP balances; it has block caching and narrow reward fields. |
| `P/router/base/ActionBase.sol:94-129`; `P/router/ActionMiscV3.sol:18-23,39-46` | Direct pull creates a router/user transfer, but PY output to SY is sent by YT while the router makes the final call. |
| `P/router/ActionAddRemoveLiqV3.sol:307-323`; `P/router/ActionSwapPTV3.sol:43-55` | Market LP removal and PT swap likewise request SY output at SY, then redeem from the router. |
| `P/core/Market/v3/PendleMarketV3.sol:129-145,159-183,347-356`; `P/core/Market/MarketMathCore.sol:153-175` | Market itself sends output SY; explicit LP burn pays `floor(lpIn*totalSy/totalLp)` and corresponding PT; hooks checkpoint rewards around LP mutation. |
| `P/core/YieldContracts/PendleYieldContractFactory.sol:75-85,119-157`; `P/core/Market/v3/PendleMarketFactoryV3.sol:39-63,69-101` | Existing factory implementations accept immutable split creation-code components. Fresh factory instances can create the local adapted YT/market and bind PT/YT without editing shared factories. |
| `P/interfaces/IRewardManager.sol:4-5`; `P/interfaces/IPYieldToken.sol:5-8` | The old getter promises uint128 outputs. A widened local implementation needs its own interface, not a false claim to that return schema. |

The integer evidence explicitly executes the source consumer expressions.
Widening is labelled **proposed**, and unchanged narrowing is also executed as
a negative. No interface-name comparison substitutes for that distinction.

## 3. Preserved principal and funded custody

Use `W=10^18`, `Q=10^36`, `1<=k<=Q`, and the r1 symbols `G,T,B,Da,Ds,F,Cw`.
Actual receipt-held DETF is at least `B`. A principal packet remains exactly
`n*k` gons for native integer `n`; no static-gon division creates principal.

For measured funding `f`, retain:

```text
v  = floor((f+Da)*10^54/(T+F+Cw))
aS = floor(T*v/10^54); aF = floor(F*v/10^54); aC = floor(Cw*v/10^54)
Da' = f+Da-aS-aF-aC
L = floor(T/k); budget = aS+Ds
k' = k if T=0 or budget=0, otherwise ceil(T/(L+budget))
Ds' = budget-(floor(T/k')-L); B' = B+f
```

Issue `aF*k'` and `aC*k'` afterward, to captured domain-1 owners while
locked; retain the existing active-role policy and top-up-only standing weights.
Empty participation means `T+F+Cw=0`, not no principal shares.

Ordinary wallet Stage-1 checkpoint moves `G[a]-P[a]*k` to `R[0,a]`.
Transfer/withdrawal can spend only `P[a]`, exactly `n*k`. A mature bond pays its
native principal at/after its actual 90-day cliff; original bond reward gons
remain separate from growth on delivered principal. Final bond residue belongs
to the NFT owner, not an arbitrary claim recipient. Active native withdrawals
still retain the modulus. Domains 0/1 release `floor(R/k)` once, debit exactly
that many times `k`, and retain the rest. None of these equations changes here.

### Revised physical escrow invariant

`E` is the receipt's **tokenized SY reward gon liability**, not new backing:

```text
G[receiptEscrow] = sum R[0,*] + sum R[1,*] + sum R[2,*] + E
E = RG.totalSupply = sum RG.balanceOf(*)
T = sum physical receipt gons
B = floor(T/k) + Da + Ds
```

RG token balances are claims on the `E` term, never added to `T` again.
Unsolicited DETF/gons/RG are not funding, principal, new reward allocation or
an operation's spend budget. The escrow cannot sweep `E`.

## 4. SY ownership and standard reward accounting

### 4.1 State and initialization

Keep native nine-decimal principal shares, external canonical ERC20 balances,
internal owner balances, and `internalSpendShares[operator][owner]` from r1.
Replace each reward slot by its `lastK`; accrued gons are checkpointed directly
to domain 2, not carried with the shares. Keep the common `backingGons=A`.

```solidity
struct InternalPrincipal {
    uint256 shares;
    uint256 lastK;
}
struct MigrationSYStorage {
    mapping(address => uint256) externalLastK;
    mapping(address => InternalPrincipal) internalPrincipal;
    mapping(address => mapping(address => uint256)) internalSpendShares;
    uint256 totalInternalShares;
    uint8 accountingPhase;
    address rewardGonsToken; // fixed initialization binding, staking SY only
}
```

Use the r1 SY namespace on **fresh** Migration wrappers, not an upgrade of r1
state. Raw SY has no rewards and retains raw 1:1 backing. The receipt adds
`uint256 tokenizedSyRewardGons` and the fixed `rewardGonsToken` binding to its
Migration namespace. RG uses canonical ERC20 balances/allowances and a separate
once-only `{receipt,parent}` binding and accounting phase. No mutable minter,
executor, owner, rescue, pause, conversion-rate or binding setter exists.

At initialization all supplies, backing and credits are zero; `k=Q`;
`I=1`. An untouched zero-share slot is initialized to current `k` before
subtraction. Rate `exchangeRate=W`, `assetInfo=(TOKEN,DETF,9)`, and
`yieldToken=sDETF` remain. RG metadata is **45 decimals**: initially `10^45`
native RG would represent one whole nine-decimal DETF. RG is not DETF, sDETF,
SY, or a configured principal input. No pricing conversion uses that display
decimal; all settlement uses native integers.

### 4.2 Settle before changing shares

For each distinct affected slot, after synchronization:

```text
g = shares*(lastK-k)
lastK = k
A -= g
G[SY] -= g
G[receiptEscrow] += g
R[2,slotOwner] += g
```

SY debits attribution **before** the typed receipt call; receipt validates the
wired SY, `expectedK`, and post-effects custody coverage. No native receipt is
paid. No gon is rounded. This is permitted during Stage 1.

Deposit checkpoints the destination, then credits measured `n*k`, mints `n`
shares, and adds `n*k` to `A`. Pin `k` after acquisition, as in r1.
Transfer checkpoints source and destination, then moves exactly `x` shares
and `x*k` gons of logical backing. Existing `R[2,source]` does not move.
Zero/self transfers cannot create credit. Redemptions checkpoint the entire
source slot, burn the requested `x`, and debit only `x*k` principal backing.
Partial exit does not move an arbitrary proportional slice of old rewards.

At operation boundaries:

```text
A = sum(slots.shares * slots.lastK)
G[SY] >= A
totalSupply = sum external shares + totalInternalShares
balanceOf(SY) = totalInternalShares
internalPrincipal[owner].shares = sum_operator internalSpendShares[operator][owner]
```

The lazy expression includes not-yet-checkpointed growth; checkpoint preserves
`A + sum R[2,*] + E` across custody domains. A new holder receives future
participation on acquired principal, not the sender's already accrued rights.
Owners can separately assign exact `R[2]` through the owner-only r1 assignment
API, or transfer materialized RG with normal token authority. An SY allowance
does not authorize either assignment.

### 4.3 Actual standard reward token, index and claim

```text
getRewardTokens() = [RG]
rewardIndexesStored() = [1 + W*(Q-k)]
rewardIndexesCurrent(): synchronize, then return stored expression
accruedRewards(a) = [R[2,a] + latentExternalGons(a) + latentInternalGons(a)]
```

These amounts are **native RG token amounts**, not native sDETF amounts.
The unit of the index is WAD-scaled native RG per native SY.
For a consumer's existing share quantity `s`:

```text
deltaI = W*(kOld-kNew)
floor(s*deltaI/W) = s*(kOld-kNew) native RG
```

The initial sentinel is included, rather than subtracted from the first actual
reward. New consumer users checkpoint at current index before receiving shares,
following the read YT hook order. `rewardIndexesStored` never projects unfunded
expansion.

`claimRewards(a)` synchronizes, checkpoints `a`'s external/internal slots, then:

```text
g = R[2,a]
R[2,a] = 0
E += g
RG.mintByReceipt(a,g)
return [g]
```

Only the receipt may mint RG, and only in this exact atomic transition.
Physical gons are already in receipt escrow. The mint does not change `T,B,k`
or liquid basis. Anybody may trigger SY's claim, but only `a` receives RG.
Zero returns zero. Materialization can occur before activation: otherwise
the real YT expiry checkpoint and market transfer hook would block principal
operations merely because they harvest a reward right.

Remove the direct native domain-2 release alternative; `claimDeferredRewards(2)`
rejects with `UseSYRewardMaterialization`. Domains 0/1 remain unchanged.
`releaseSyRewards` from r1 is replaced by `materializeSyRewards`; no old selector
may remain installed as an alternate route. Once materialized, the domain-2
credit is zero. A second SY claim cannot issue the same RG.

### 4.4 Native payout, rebasing and fractions

RG exposes:

```solidity
function redeem(uint256 maxGons, address receiver, uint256 minNative)
    external returns (uint256 nativePaid, uint256 gonsBurned);
function previewRedeem(uint256 maxGons) external view returns (uint256);
function receipt() external view returns (address);
function parent() external view returns (address);
function migrationAccountingPhase() external view returns (uint8);
function mintByReceipt(address beneficiary,uint256 gons) external;
```

The mint method is fixed-receipt-only and checks that the receipt's new E is
exactly current RG supply plus the mint amount. It is not a funding API.
Require finalized parent activation, normal permitted receiver (excluding
receipt escrow, bond, staking SY and RG itself), and
`maxGons<=balanceOf(msg.sender)`. Synchronize before fixing `k`; compute
`n=floor(maxGons/k)`, `g=n*k`. Burn **g**, not `maxGons`, from the caller's RG;
debit `E` by `g`; move `g` receipt gons from escrow to receiver and credit `n`
liquid receipt units. Require `n>=minNative`; propagate every failure.
Zero-pay redemption burns zero, so a fractional right cannot disappear.
Payout is native sDETF, which can then actually unstake to held DETF.

No delegated redemption is necessary: a spender can use an ordinary RG
`transferFrom` approval to acquire exact rights first. No caller supplies an
arbitrary owner to `redeem`. In Stage 1, even an approved spender cannot pay
native rewards. Transferring a locked right is allowed.

RG balance/supply never rebases. Its underlying gons remain in `T`, so their
native value `floor(g/k)` appreciates under later **real** funding, including
after every principal SY share has left YT. At fixed `k`, full available payout
leaves `balance<k`; repeat payout is zero. Every remaining gon stays an actual
transferable RG unit, can be consolidated, and can pay after further funding.
No wrapper conversion dust, synthetic native debt, native rounding write-off
or index reset is introduced.

## 5. Concrete standard-consumer boundary

### 5.1 Why the local wide consumers are mandatory

At production Q, ten native principal shares and ten funded rewards produce
`5*10^36` RG and index `1+5*10^53`. The old index field cannot hold that index.
Even the accrued field overflows at sufficiently larger, entirely ordinary
native principal amounts. Therefore **using the unmodified narrow YT or market
is not a supported production path**. It is replaced, not omitted: the local
creation-code variants in section 8 provide the required YT and market paths.

Use the read consumer formulas, hook order, fee policy, PT/YT ownership,
expiry split, reserve accounting, market equations and gauge active balances.
Change only reward representation precision and the RG-specific settlement
cadence:

1. `RewardState.index/lastBalance` and `UserReward.index/accrued` are uint256.
   Initial index remains 1. RG uses that wide domain. For unrelated reward
   tokens, preserve the original uint128 representability checks, floor rule
   and block cadence. Add a per-user RG `remainder<W` for a fractional
   native RG unit at a consumer floor; no PENDLE remainder policy is changed.
2. Replace reward `mulDown`/`divDown` products with checked full-precision
   `mulDiv`. For user accrual:
   `q=mulDiv(shares,deltaI,W)`, `r=mulmod(shares,deltaI,W)+oldRemainder`;
   add `q+floor(r/W)` to accrued; retain `r%W`.
   In the Migration YT, `deltaI` is a multiple of W, so this remainder is
   identically zero. Market gauge allocations need not have that property.
3. For RG, market `_updateRewardIndex` harvests SY before **every** active-balance
   mutation, even in the same block. Snapshot old active total first. The
   existing block cache continues to control unrelated PENDLE harvesting.
   Split the local gauge's internal harvest into unconditional SY harvest and
   once-per-block gauge-controller harvest; no shared gauge change.
4. For market RG balance delta `d` and old active supply `a`, retain the source
   index rule `I'=I+floor(d*W/a)` when `a>0`, sentinel initialization, and
   actual-balance `lastBalance`. If `a=0`, no individual reward is fabricated.
   Index-floor residue remains actual market-owned RG inventory, as in the
   source balance rule; it is not a new principal credit, protocol sweep or
   a confiscated user's already accrued amount. User remainders survive even
   when their active balance becomes zero. No new LP allocation policy is set.
5. Local `transferRewardRemainder(token,to,numerator)` checkpoints sender and
   recipient first, authorizes only the actual sender, moves only that sender's
   remainder numerator, carries a whole unit into recipient accrued if possible,
   and retains the modulus. It pays nothing. Whole accrued claims remain on
   the existing fixed-user claim route. This makes the smallest consumer
   fractions consolidatable without changing an LP or YT balance. Put its
   internal mutation in the local abstract reward manager; expose the external
   guarded entry on the local YT/Market leaf contracts under their existing
   nonReentrant lock, rather than assuming the abstract manager owns that lock.
   Require token to be the fixed RG; this is not a new unrelated-token API.
6. Fee calculations on RG use full-precision `floor(gross*feeRate/W)`. Fee and
   user RG transfers sum exactly to gross. A fee recipient receives locked
   rights, never Stage-1 sDETF. Factory fee rates/treasury are not changed by r2.

The source YT's before-transfer checkpoint consequently records oldUser's exact
RG amount before its YT balance is burned/transferred. SY's checkpoint records
the matching backing for **YT** before YT transfers out principal SY. Later
`YT.claim -> SY.claimRewards(YT) -> RG to YT -> RG to oldUser/treasury` pays that
same liability. Neither the SY receiver nor router gets those old gons.

### 5.2 Expiry remains a real supported path

Keep source `_setPostExpiryData`: first post-expiry operation harvests RG,
records first PY/reward indexes, and reserves actual held native RG for users.
The local YT has no fractional RG accrual because its principal rate is W.
Pre-expiry user RG liabilities continue to be payable with zero SY balance.
Already reserved RG appreciating in native sDETF value is **not** a new token
balance delta and does not become treasury income.

Post-expiry newly earned RG on still-held principal SY goes to treasury by the
existing inventory-minus-reserved rule. User reward indexes freeze at the
recorded first index; principal redemption remains 1:1 at W; no artificial
interest is created. RG can be harvested and transferred at expiry during
Stage 1, but treasury and user native redemption both remain activation-gated.
This avoids a hidden post-expiry principal lock.

### 5.3 Types and numerical domains

`I<=1+W*(Q-1)<2^256`. Gon amounts and every checked resulting aggregate must
fit uint256, as must the canonical ledger's T and backing. Products use
full-precision operations; it is not sufficient that their quotient fits.
There is no new principal/supply cap or truncated uint128 fallback.
The old getter `userReward(address,address)` has the same selector but an
incompatible narrow return schema; do not advertise or decode it as the old
`IRewardManager`. The local interface returns uint256 and adds
`rewardAccountingVersion() = keccak256("indexedex.migration.reward-gons.r2")`
for unambiguous discovery, plus the remainder getter/assignment.

Checked unrepresentable states revert rather than mint unbacked rights. The
finite evidence is not a proof over all lifetime uint256 accumulation or gas
bounds. Those remain implementation tests; no arbitrary economic cap is
invented to make the examples fit.

## 6. Authenticated principal handoff, including both upstream pushes

### 6.1 Wrapper rules

Retain r1's source-attributed internal ledger:

```text
external transferFrom(from,SY,x) by operator:
  checkpoint External(from); checkpoint Internal(from)
  move x principal shares to Internal(from)
  ticket[operator,from] += x

deposit(receiver=SY) funded by caller:
  mint x principal shares to Internal(caller)
  ticket[caller,caller] += x
```

Old `redeem(...,true)` consumes only `(caller,caller)`.
`redeemInternal(owner,receiver,x,tokenOut,min)` consumes only
`(msg.sender,owner)`. Burn exact canonical self shares and the matching ticket
and internal-owner amount. Neither selector spends aggregate self inventory.
Generic `transferFrom(SY,...)` remains forbidden.

### 6.2 One local egress adapter, R

`M/sy/UniswapV4DetfMigrationSYEgressAdapter.sol` is the implementation of a
fixed-dependency, nonreentrant, typed router proxy. It has no user-callable
delegatecall, arbitrary target/calldata,
beneficiary substitution, rescue or administrator-spend surface. Bind the
Migration parent/SYs, local yield factory and local market factory at creation.
Validate YT/PT/SY/expiry/factory cross-bindings and factory registration, and
market `readTokens()` against those fixed dependencies on each selected route.
No caller-supplied address is accepted merely because it implements a getter.

Its external argument contracts are:

```solidity
redeemSy(address sy,uint256 shares,address tokenOut,uint256 minOut,address receiver,uint256 deadline)
redeemPy(address yt,uint256 py,address tokenOut,uint256 minOut,address receiver,uint256 deadline)
removeLiquidity(address market,uint256 lp,address tokenOut,uint256 minOut,uint256 minPt,address receiver,uint256 deadline)
swapPt(address market,uint256 pt,address tokenOut,uint256 minOut,address receiver,uint256 deadline)
depositAndRedeem(address sy,address tokenIn,uint256 amount,uint256 minShares,address tokenOut,uint256 minOut,address receiver,uint256 deadline)
```

Each returns actual native output; liquidity removal additionally returns PT.
All input ownership is **msg.sender**, with exact normal token allowances.
There is no free `owner` argument. Deadline, supported routes, nonzero receiver,
measured input, exact budgets and user minimums are enforced. Use the existing
SY output routes, not an arbitrary swap aggregator.

| Operation | Entire authenticated graph and source of authority |
| --- | --- |
| Direct SY pull | User calls R; R calls `SY.transferFrom(user,SY,x)`. User allowance authenticates `(R,user)`. R calls `SY.redeemInternal(user,receiver,x,out,min)`. Reward owner remains user. |
| YT upstream push | R pulls exactly user PT and, before expiry, user YT into that YT contract. R calls existing `redeemPYMulti([R],[py])`, not the floating-balance `redeemPY`. Its read `_redeemPY` burns exactly py and **YT** transfers SY to external R. R measures the returned operation delta, transfers exactly that delta `SY.transfer(SY,x)`, creating `(R,R)`, then calls old `SY.redeem(receiver,x,out,min,true)`. Old reward backing stays YT's; original downstream user claim survives. |
| Market LP upstream push | R pulls exactly user LP into the verified market; calls `market.burn(R,receiver,lp)`. **Market** transfers the computed SY to external R and PT to receiver. R checks returned/measured SY delta and minPt, then performs the same own-ticket transfer/redemption. Old market rewards remain with market, whose LP hook already accrued the user's retained claim. |
| Market PT swap upstream push | R pulls exactly user PT into the verified market; calls `market.swapExactPtForSy(R,pt,bytes(""))`. **Market** pushes SY to external R. Empty callback data means no invented callback authority. Actual returned output/delta, not a quoted constant, supplies x for R's own-ticket transfer/redemption. Market fee/pricing remains its real formula. |
| Router-funded self deposit | R measures/pulls user input into R, approves only this input, calls `SY.deposit(SY,tokenIn,amount,minShares)` and clears approval. Actual caller R funds `(R,R)`. R consumes precisely the returned new ticket amount with old internal redeem. Old tickets/balances are not included. |

The receiver change is deliberate: no `(YT,YT)` or `(market,market)` ticket is
assigned to an unrelated router. The upstream sender genuinely transfers
principal to R first; R subsequently acts on its own acquired shares. This
requires no allowance from YT/market to R and no mutable list of privileged
routers in SY.

Before an operation, record R's external/internal SY amounts, tickets and
domain-2 pending gons. Checkpoint any preexisting R holding first. After the
upstream call, use only its verified share delta/explicit amount. Never redeem
the adapter's whole balance. Pin the received principal's actual index
`kArrival`; while x of this operation's principal remains in R's external or
internal custody, its transit reward is exactly `x*(kArrival-kConsume)`.
If a route uses more than one principal tranche, sum that expression per
tranche. Only those exact transit gons are materialized and transferred as RG
to the actual input caller. A total pending-balance delta alone is insufficient:
preexisting adapter shares can also earn new growth. Checkpoints/materialization
may settle those old rights, but they remain R's segregated inventory. Old R
inventory and old pending rights are outside the operation budget.
Old YT/market rewards were detached **before** R received principal and cannot
enter that transit calculation.

The adapter is one atomic call: any failed input, producer call, PT minimum,
SY minimum, output transfer or final minimum propagates and restores all input
allowances, transfers, producer burns/reserves, SY checkpoints/tickets, receipt
funding, RG changes and output transfers. It catches none of those failures.
It does not complete one transaction and ask the user to recover pretransfers.

### 6.3 Honest compatibility boundary

The read `ActionMiscV3.redeemPyToToken`, `removeLiquidityDualTokenAndPt` and
`swapExactPtForToken` still request an upstream transfer **to SY**. They are
not silently made safe by r2 and are not the Migration egress entrypoints.
The required operations are supplied by R's explicit equivalents above,
including the actual YT and market sender identities. Direct old-router
pull plus old internal redeem also still fails. No generic external-router
acceptance is claimed.

Fresh local wide YT/market instances are mandatory for this exact reward-token
representation. Ordinary deployed Pendle products and their routers remain
unchanged. This is a named, implementable integration replacement, not a
claim that existing deployments can be upgraded in place.

## 7. Principal outputs, locks and activation

Every staking-SY principal output still consumes only `x*k`:

* sDETF: wired receipt principal transfer pays exactly x units, with Stage-1
  basis, so the receiver can actually unstake.
* DETF: authenticated exact receipt withdrawal burns `x*k`, reduces `T` by
  `x*k` and `B` by x, and pays held DETF.
* Every other configured output: withdraw exactly x DETF, approve that budget
  to the parent, execute its actual configured route, clear approval and check
  actual output/minimum. RG and deferred gons are never in that budget.

Raw SY retains its raw backing and empty rewards; it uses the same caller
ticket/adapter rules. No unconditional receipt input/output is invented for
raw SY beyond its actual route table.

Retain r1 synchronize-before-lock, fixed child phases, parent-before-new-
participation funding, expected-k custody checks and callback admission.
RG and the one fixed egress adapter are additional money-path phases in
activation's idle check (six fixed children/participants in total). The adapter
sets its phase before its first external input call and clears it only after
all output/budget checks. Its identity is fixed by package initialization,
not caller registration. RG announces Synchronizing before entering the receipt synchronization
path; the receipt still saves/restores its outer phase on parent funding.
RG burn effects precede the receipt's liability/custody checks. Token transfers
and rights materialization do not authorize independent parent economic calls.
No custom RG transfer callback is installed.

While R is busy, the parent admits only its already wired SY/receipt's
specified synchronization/acquisition/payment nesting. Other lifecycle and
independent economic calls still require all participants idle. R's phase
alone never authenticates a token callback or another caller.

RG redemption is RG -> receipt's fixed caller `redeemTokenizedSyRewards` at
pinned k -> already-issued native sDETF to receiver. This method takes the
receipt lock without resynchronizing. Receipt checks `expectedK`, activation,
`E>=g`, RG's **post-burn totalSupply==E-g**, and escrow coverage. SY materialize
is SY -> receipt -> RG's receipt-only mint; receipt checks post-mint supply.
No public general `from` argument or arbitrary custody mover is added.

Activation moves no gons, RG, backing, pending right or index. It merely opens
native payouts under the existing atomic owner/selector-removal contract.
It scans neither RG holders nor YT users. Every existing role identity, bond
clock and later-funded fraction remains unchanged.

## 8. Exact proposed implementation paths and interfaces

These are **future production paths**, not files authored in this correction
lane. All paths prefixed M are under the exact prefix in section 2.

| Exact local path(s) | Required implementation difference |
| --- | --- |
| `M/sy/IUniswapV4DetfMigrationSY.sol`; `M/sy/UniswapV4DetfMigrationSYRepo.sol`; `M/sy/UniswapV4DetfMigrationSYTarget.sol`; `M/sy/UniswapV4DetfMigrationSYFacet.sol` | Section 4 slots/checkpoint/standard reward API, unchanged principal output budgets, exact tickets and selected selectors; no r1 attached reward slicing. |
| `M/claimToken/IUniswapV4DetfMigrationStakedDETF.sol`; `M/claimToken/UniswapV4DetfMigrationStakedDETFRepo.sol`; `M/claimToken/UniswapV4DetfMigrationStakedDETFTarget.sol`; `M/claimToken/UniswapV4DetfMigrationStakedDETFFacet.sol` | Add E and fixed RG binding; revise domain-2 release; typed materialization and tokenized-gon redemption; preserve domains 0/1 and all r1 principal/funding rules. |
| `M/sy/rewards/IUniswapV4DetfMigrationRewardGons.sol`; `M/sy/rewards/UniswapV4DetfMigrationRewardGonsRepo.sol`; `M/sy/rewards/UniswapV4DetfMigrationRewardGonsTarget.sol`; `M/sy/rewards/UniswapV4DetfMigrationRewardGonsFacet.sol`; `M/sy/rewards/UniswapV4DetfMigrationRewardGonsDFPkg.sol` | Actual nonrebasing ERC20 RG, metadata45, canonical allowance/transfer, receipt-only mint, caller-owned exact-gon burn/native payout, once-only bindings, phase view. No user stake/fund method or public initializer selector. PkgInit/PkgArgs belong on its interface. |
| `M/sy/pendle/IUniswapV4DetfMigrationRewardManager.sol`; `M/sy/pendle/IUniswapV4DetfMigrationYieldToken.sol` | Local wide reward getter/version/remainder interface; local YT interface copies the read YT ABI except narrow reward inheritance. Interest interface stays unchanged. Do not extend the old narrow reward interface. |
| `M/sy/pendle/UniswapV4DetfMigrationRewardManagerAbstract.sol` | Local licensed derivative of `P/core/RewardManager/RewardManagerAbstract.sol`: wide fields, full-precision reward multiply, carried remainder and its owner-only assignment; source sentinel and pre-balance ordering retained. |
| `M/sy/pendle/UniswapV4DetfMigrationRewardManager.sol` | Local derivative of `P/core/RewardManager/RewardManager.sol`: import local abstract, wide reward state, full-precision division, RG updates on each call, existing balance-delta and payout debit semantics. |
| `M/sy/pendle/UniswapV4DetfMigrationYieldToken.sol` | Local derivative of read `PendleYieldToken.sol`: use local interface/abstract; full-precision reward fee calculation. Preserve all mint/burn, PT, reserve, rate, interest, expiry and fixed-user claim logic. Its nonvirtual/private upstream seams are why mere subclassing is not the implementation. |
| `M/sy/pendle/UniswapV4DetfMigrationGauge.sol`; `M/sy/pendle/UniswapV4DetfMigrationMarketV3.sol` | Local copies of the **import spine only**: Gauge imports local reward manager and separates RG/gauge harvest cadence; MarketV3 imports that Gauge. Retain active-balance/ve rules, market math, fees, reserves, oracles, hooks and external market ABI. Shared libraries remain imports, not private copies. |
| `M/sy/IUniswapV4DetfMigrationSYEgressAdapter.sol`; `M/sy/UniswapV4DetfMigrationSYEgressAdapter.sol`; `M/sy/UniswapV4DetfMigrationSYEgressAdapterRepo.sol`; `M/sy/UniswapV4DetfMigrationSYEgressAdapterFacet.sol`; `M/sy/UniswapV4DetfMigrationSYEgressAdapterDFPkg.sol` | Section 6's five typed atomic routes and fixed factory/SY bindings; measured budgets, source validation, minima/deadline, own-ticket push path. Canonical proxy package with interface-owned init/args, once-only bindings, phase view and no installed initializer/updater. No shared router changes. |
| `M/sy/UniswapV4DetfMigrationSYIntegrationFactoryService.sol` | Deploy RG/adapter facets and packages through CREATE3, and fresh instances of the existing factory implementations configured with **these local** YT/market split creation-code artifacts. Existing yield factory creates ordinary PT bound to local YT; existing market factory's yieldContractFactory points to that yield factory. Preserve factory fee/treasury/expiry/ve/gauge configuration semantics, not a new Migration administrative role. Record dependencies in deployment args/salts. |
| `M/interfaces/IUniswapV4DetfMigrationDFPkg.sol`; `M/UniswapV4DetfMigrationDFPkg.sol`; `M/UniswapV4DetfMigrationInitializationLib.sol`; `M/UniswapV4DetfMigrationPolicy.sol`; `M/UniswapV4DetfMigration_Component_FactoryService.sol` | Interface-owned PkgInit selects RG/adapter packages and the two fixed local integration factories. Predict/wire children in the order below, validate reciprocal once-only bindings before usable initialization completes, include RG/adapter in fixed phase checks. Declare actual selected interfaces and never leave ordinary SY or old domain-2 release as alternate selectors. |

Exact initialization order avoids a circular address assumption. RG PkgArgs
contains the parent address only; its own initializer reads the already wired
receipt from that parent. Thus its address is predictable before receipt
deployment without knowing receipt address. The parent package predicts RG,
deploys/initializes the receipt with that fixed predicted RG binding, records
the receipt, deploys RG and verifies the prediction/reciprocal receipt binding,
then deploys both SYs with the fixed RG reference where applicable. Finally
it deploys the adapter proxy from its selected package with parent, both SYs
and the two selected factory identities, and records that fixed adapter in
parent storage. All this is the existing atomic package completion path;
the parent is not usable with missing children. No receipt rebinding selector
is installed. Registered parent/SY packages still use the manager registry;
RG and router helpers use their selected generic callback packages as
non-vault children. FactoryService reads artifacts off-chain; it is not
mistaken for an on-chain artifact loader in parent postDeploy.

Receipt additions/replacements, exact argument types:

```solidity
function materializeSyRewards(address beneficiary,uint256 expectedK)
    external returns (uint256 nativeRewardGons);
function redeemTokenizedSyRewards(address receiver,uint256 nativeAmount,uint256 expectedK) external;
function tokenizedSyRewardGons() external view returns (uint256);
function rewardGonsToken() external view returns (address);
```

`materializeSyRewards` is wired-staking-SY-only, consumes only R[2,beneficiary],
and mints actual RG through the fixed RG receipt-only mint method.
`redeemTokenizedSyRewards` is fixed-RG-only and spends only E; no free owner.
Existing `deferCustodyRewards` and `transferSyPrincipal` retain their actual
caller/expected-index/post-effects checks. The public domain-2 assignment remains
owner-only and is disabled only for protocol custodians as in r1.

Local consumer additions:

```solidity
function userReward(address token,address user) external view returns (uint256 index,uint256 accrued);
function rewardRemainder(address token,address user) external view returns (uint256 numerator);
function transferRewardRemainder(address token,address to,uint256 numerator) external;
function rewardAccountingVersion() external pure returns (bytes32);
```

The adapter interface also declares `migrationAccountingPhase() returns(uint8)`.

No shared Crane/vendored file is an edit target. No already deployed factory
is assumed to change its immutable creation code. Fresh factory configuration
is explicit, and the local egress adapter validates that provenance. Existing
generic router calls used for ordinary products do not become a privileged
executor of the Migration wrapper.

## 9. Executed evidence and what it establishes

Owned evidence is `evidence/egress-correction/`. `ledger.mjs` reuses the immutable
independent `Book` for canonical funding and non-SY transitions, but explicitly
replaces its rejected SY ownership and payout rules. `consumer.mjs` separately
executes the read consumer's sentinel, shares, native multiplication, fee and
expiry expressions. `callers.mjs` follows sender/operator/owner edges and real
LP output ratios. `vectors.mjs` composes them. These are finite arithmetic and
caller proofs, not mock contracts presented as SUT tests.

Observed standalone execution: Bun 1.4.2, exit 0. Reproduction and exact
results are in `evidence/egress-correction/results.md`.

| Executed witness | Result |
| --- | --- |
| Production-Q r1 counterexample | Reproduces the incorrect native sDETF liability `4,999,999,999,999,999,999`. |
| Corrected native reward boundary | Initial index 1; ten funded native rewards produce exactly `5*10^36` native RG, worth ten native sDETF at `k=Q/2`. Old uint128 index rejects; explicit local-wide arithmetic succeeds. |
| Old YT holder after SY goes to different receiver | Ten principal units exit during Stage 1; old user receives the retained `5*10^36` locked RG, new receiver gets zero old reward; another actual ten-unit funding lowers k to Q/4; old user later receives twenty native sDETF and unstakes it. Total native output 30, final backing 0, duplicate 0. |
| Repeated funding, cohorts and YT transfer | Late cohort gets zero prior accrual; old user's accrued RG survives transfer; fees plus user RG equal exact materialized custody. |
| Expiry during locked stage | Pre-expiry `5*10^36` user RG stays reserved; later newly earned RG goes to treasury, not old RG appreciation; original user claim and treasury repeat checks succeed. |
| All splits, mixed deposits, transfers and exits | 360 sequences at Q=1000 and production Q, n=1..12, every split 0..n, two funding sizes, repeated funding, external/internal movement, raw/receipt principal exits; 3,992 native principal units successfully exit. |
| Complete minimum rollback | All 360 sequences restore the full operation including its simulated synchronization funding; caller routes additionally roll back failed minima and wrong input ownership. |
| Retained native fractions | 686 nonzero per-owner payout remainders retained in those sequences. Separate 776-gon right transfers to another owner and later pays two native units after real funding. |
| Original mature bond/receipt invariant | Ten principal units exit, distinct original/post-claim gon rights remain; later payouts 25 and 5, final backing 0. |
| Role identity and duplicate release | Captured same-owner allocation of 1,581 gons survives later owner changes; native payout 4 leaves 85 gons; repeat 0. |
| Direct pull, YT push, market LP push, funded self deposit | Each pays 5 successfully. Wrong caller/owner and insufficient minimum reject. Push routes preserve two preexisting adapter shares, use only `(R,R)`, and leave old source reward gons with YT/market. |
| Unmodified upstream-to-SY route | Router cannot spend `(YT,YT)` merely by naming YT; actual ticket owner can exit. No aggregate self-balance bypass. |
| Market reward units | Source active-balance allocation of `7*10^36` RG to weights 2/3 pays `2.8*10^36` and `4.2*10^36`; narrow index fails range. A nondivisible case retains actual market RG inventory. |
| Market consumer fractional and same-block correction | Two nondivisible allocations retain per-user numerators; consolidation can form one whole gon while inventory remains solvent. Two same-block deltas yield 10 native RG under the local cadence versus 4 under the old block cache. The caller guard remains a specified runtime obligation. |
| Transit growth with prior adapter inventory | Funding while five operation shares and two old adapter shares coexist assigns only the five-share growth to the input user; old two-share growth stays with R. |
| Receipt principal transfers | Thirty principal units exit after Alice -> parent -> mixed Bob; old wallet rewards stay 4,600/2,300 gons, with no router reward basis. |
| Saturation and arithmetic width | At production Q, k reaches 1; later funding of 50 remains native staking dust. Principal and all representable rewards exit, issued gons 0, retained backing 50. Full-precision reward multiplication succeeds where the intermediate uint256 product would overflow. |

The first resident run exposed an incorrect **evidence assertion**, not a
contract result: `5*10^36` fits uint128 although its WAD index does not.
The corrected vector checks both the fitting amount and the larger overflowing
amount. A subsequent expanded run found a model rollback bug: Object.assign
restored old fields but did not remove a newly created caller field. The
snapshot restorer now removes speculative fields before restoring the complete
snapshot. No failed check was suppressed; execution history and final status
are recorded in results.md.

## 10. Limits, cleanup and DoneClaim

No runtime SUT, compiler, bytecode, deployment, actual reserve swap, gas,
signature, token-callback, selector-cut or external-router acceptance is
claimed. The caller proof uses the concrete source senders and LP formula;
it does not execute market logarithmic swap pricing. The existing configured
parent output routes are specified and remain runtime verification obligations,
not invented arithmetic prices. Rollback snapshots assume EVM atomicity;
production must prove every adapter failure propagates.

The local wide consumers are required implementation work, not optional future
fallbacks. Their creation-code bindings, actual getter schemas, market
same-block settlement, fractional consumer carry, full import/declaration
compilation and real factory/router calls need independent production
verification. The deterministic evidence proves the stated integer/caller
contract, not those runtime facts. JavaScript LSP refreshes timed out; no clean
LSP or Solidity type-check result is asserted.

E1/E2, actual recovery E3, BOOTSTRAP-AUTH and runtime E4/E5 remain open.
Owner questions remain unanswered. This construction does not answer them,
authorize implementation/deployment, or replace the independent review.
The independent reviewer must issue its own ready-for-implementation or
needs-fix result; this author does not impersonate that reviewer.

**Cleanup:** only this report and its bounded evidence files were authored,
using apply_patch. The finite standalone evidence monitor exited 0; no node,
listener, dependency, cache, worktree or temporary directory was created.
Shared Crane, warm artifacts, prior reports and evidence remain untouched.
No Forge, install, Git, commit, broadcast, external message or delegation ran.

**DoneClaim:** F1/F2/F3 have one explicit corrected construction and executed
source-derived arithmetic/caller evidence. The changed contract is native
gon-backed reward-token settlement with wide local consumers, source-retained
reward ownership on principal transfer, and operation-budgeted local adapter
handoff into authenticated internal tickets. Exact native principal, genuine
funding, role identity, retained gons and exact-once native release are
preserved. This is construction completion only, not E5 or runtime acceptance.
