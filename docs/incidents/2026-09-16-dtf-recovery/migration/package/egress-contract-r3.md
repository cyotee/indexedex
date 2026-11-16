# Migration egress r3: principal SY and activation-gated reward custody

Date: 2026-11-10. Revision: `migration-egress-r3`.
Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`.

**One proposed required-surface construction; no production acceptance.**
Keep native principal packets and canonical funded gons. Staking SY represents
principal, while accrued rewards stay with the old holder in receipt custody.
Deliver a separate, fixed-gon reward token **only after activation**. Use
`10^18` gons per native reward-token unit, not r2's one gon. Preserve the
standard bearer internal-SY burn instead of inventing owner/operator tickets.
No new Pendle market, yield factory, controller, voting contract, forked
consumer or egress-adapter deployment is required.

This document replaces the r1/r2 egress construction as a whole; it does not
incorporate their conflicting payout, ticket, precision or deployment rules.
Their reports and evidence remain immutable. The complete implementation
handoff, upstream ownership/bootstrap/children constructions, 701-line r1,
r2 and both independent reports were read. The actual
Migration plan was read completely at the main-checkout path below because
that file does not exist at the worktree incident path. That required input
and the explicitly named r3 brief are read-only exceptions; every authored
file is inside this worktree's authorized output boundary.

## 1. Authority and exact required integration boundary

Source aliases used below:

| Alias | Exact path |
| --- | --- |
| Plan | `/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` |
| FundedPlan | `contracts/vaults/detf/DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md` |
| C | `contracts/vaults/detf/common/` |
| D | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` |
| M | proposed `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/` |
| P | `lib/crane/contracts/protocols/perps/pendle/` |
| K | `lib/crane/contracts/` |

Other relative paths are worktree-relative. These are source observations,
not evidence that a new Migration proxy has been deployed.

| Required component or behavior | Exact authority/callable source | r3 obligation |
| --- | --- | --- |
| Funded receipt and cliff bond | Plan MIG-P06/P07/P08, sections 4.1 and 5.5, task 5; `C/bondNft/DETFFundedBondTarget.sol:94-130,139-208`; `C/claimToken/StakedDETFTarget.sol:147-224` | Real exact funding; 90-day principal cliff for marked positions; all reward payout gated; direct and composed exits. |
| Both separate SY wrappers | FundedPlan:30,93-106,318-351; `contracts/interfaces/IDETFStandardizedYield.sol:13-17`; `C/sy/DETFSYDeploymentLib.sol:15-27`; `D/UniswapV4DetfDFPkg.sol:227-239` | Keep raw and staking addresses, nine decimals, actual directional routes, metadata and all standard selectors. |
| SY deposit/redeem, internal burn, reward methods | FundedPlan:322-330; `P/interfaces/IStandardizedYield.sol:62-172`; `C/sy/DETFSYTarget.sol:65-180` | Four-argument deposit, five-argument redeem, caller versus self balance, rate/previews and real reward-token amounts. No ticket extension replacing the standard call. |
| Parent direct staking and receipt exits | `D/UniswapV4DetfTarget.sol:344-374`; Plan task 5 and E5 | Parent pulls only this operation's principal receipt packet and spends exactly it; no whole-balance redemption. |
| Configured output routes | Plan:150-158,409-418; FundedPlan:339-351; `C/sy/DETFSYRepo.sol:38-69`; `C/sy/DETFSYTarget.sol:196-242`; `D/UniswapV4DetfTarget.sol:410-477` | Keep DETF, staking-SY's automatic sDETF leg and every configured token route, with actual parent pricing, fees, decimals, minimums and rollback. Raw SY gains no automatic receipt route. |
| Manager registry, reserve and child deployment | Plan section 2 and task 3; `D/UniswapV4Detf_Pkg_FactoryService.sol:16-32`; `contracts/registries/vault/VaultRegistryDeploymentTarget.sol:44-76,141-165` | Real registered parent/bond/SY packages; real configured hook/SEs; existing generic receipt-child path. |
| One fixed-gon reward token | Engineering dependency of the nonempty reward methods in `IStandardizedYield:105-130`, not an owner-requested third-party protocol | A small local token child makes native token amounts and retained appreciation coherent. It is neither sDETF nor a new staking supply. Section 7 admits its actual callers. |
| New Pendle YT/PT, market, gauge/controller, ve/voting and special router | No such deployment obligation in Plan sections 4/6, tasks 3/5/7, or the above SY interface | **Optional external use, not delivered or required here.** Their calls are examined as compatibility probes, not promoted into dependencies. |

The ordinary static-gon SY formula and empty compounded reward list in
FundedPlan:341-351 remain ordinary-product rules. For **Migration only** the
later activation rule requires an explicit principal/reward partition.
r3 selects the already explored principal-denominated representation rather
than pretending unchanged appreciated-SY redemption can pay its quoted whole
asset value during Stage 1. Its constant principal rate and separate reward
token are declared together. No ordinary package changes semantics.

**Owner selection is closed:** only the current Crane owner selects and
executes pooled genesis amounts/anchor. Contributions and later donations
remain permissionless. Do not carry the historical BOOTSTRAP-AUTH question
forward. Keep measured donation budgets and bootstrap self supply separate
from personal principal and rewards; no funding-complete flag or price setter.
Owner, pending owner, creator, fee recipient and registry operator are not
interchangeable. This selection does not close runtime E4.

All original legacy categories remain: both liquid DETF generations, both
NFT models, current/earlier receipts, legacy SY, TokenStaking/claim-vault
rights, underlying SE shares and fungible LPs (Plan:120).
Optional **new** Pendle markets are not those legacy source categories.
E1/E2 and actual recovery E3 remain open without narrowing their scope.

## 2. Units, physical custody and funding

Use native integers; `Q=10^36`, `W=10^18`, `q=W`, `1<=k<=Q`.
`k` is canonical gons per native sDETF; `q` is constant gons per native
reward token `RT`. DETF, sDETF and both SYs have nine decimals.
RT has **27 decimals**: initially `10^27` native RT represents
`10^45` gons, or one whole DETF. This is a display derivation, not a
price oracle or a different payment-token denomination.

| State | Unit and authoritative owner |
| --- | --- |
| `G[a]`, `T` | Physical receipt gons by custodian and total, in the existing funded repo. |
| `B,Da,Ds,F,Cw` | Native accounted DETF, allocation dust, staking dust, and standing weights in the existing repo. |
| `P[a]` | Native liquid principal basis of ordinary receipt wallets. Bond/SY/receipt escrow are not ordinary wallets. |
| `R0[a],R1[a],R2[a]` | Exact gons in receipt-proxy custody: wallet reward, captured role allocation, unmaterialized SY reward. |
| `E=q*RT.totalSupply()` | Tokenized SY reward gons, still physically in receipt custody. Not another addition to `T`. |
| `U` | Exact reward gons of SY's public self-held shares, separately held by the protocol; section 4.3. Not beneficiary rounding dust. |
| `s[a],l[a],A` | Canonical SY share balance, last settled `k`, and common SY `backingGons`. No duplicate share ledger. |
| `Pi,Gi` | Bond remaining native principal and attributed gons, in its existing position/aggregate repo. |

Receipt new namespace needs `P`, the three beneficiary maps, their aggregate,
`E`, `U` and the operation phase. SY new namespace needs only per-address
`lastK` and its phase; **no tickets, internal-owner slots or attached rewards**.
RT needs canonical ERC20 state, fixed parent/receipt bindings and phase.
Parent stores its once-wired RT child and sole finalized activation state.
Use Crane namespace/layout conventions and interface-owned package args.

The same source funding math is retained, including its two floors:
`C/core/DETFFundedStakingMath.sol:46-94`,
`C/claimToken/DETFFundedStakingRepo.sol:185-201`,
`C/core/DETFSeigniorageShareLib.sol:18-38`.

```text
weight = T+F+Cw; require weight>0 for positive funding
v = floor((f+Da)*10^54/weight)
aS=floor(T*v/10^54); aF=floor(F*v/10^54); aC=floor(Cw*v/10^54)
Da' = f+Da-aS-aF-aC
L=floor(T/k); budget=aS+Ds
k' = k if T=0 or budget=0, otherwise ceil(T/(L+budget))
Ds' = budget - (floor(T/k')-L)
B' = B+f
```

Pull exactly `f` actual DETF before increasing backing. Rebase first, then
issue `aF*k'` and `aC*k'`. Before activation issue those gons only to receipt
escrow, crediting `R1` to each reserved NFT's owner captured at allocation.
Identical beneficiaries merge. After activation ordinary role recipients
receive their native receipts; previously escrowed allocations stay with
their captured owners. A protocol-custodian role gift remains separately
attributed, not another user's principal or sweepable surplus.
Top-up standing weights by the existing nonnegative target-minus-current
formula after funded supply changes. Do not suppress funding or catch failure.

```text
T = sum physical G
B = floor(T/k)+Da+Ds; actual DETF held >= B
G[receiptEscrow] = sum(R0+R1+R2)+E+U
G[ordinary a] >= P[a]*k
G[bond] >= sum Gi
A = sum_a s[a]*l[a]; G[stakingSY] >= A
```

At `k=1`, unrepresentable additional growth stays canonical native dust.
At empty weight, parent advances the empty baseline before new participation
without fabricating funded rewards. Standing-weight-only or retained-gon
participation is not empty. Use full-precision products/divisions and checked
uint256 results; introduce no economic cap, index reset or unfunded debt.

## 3. Receipt, bond and retained reward transitions

All public money entries synchronize before their local accounting lock,
subject to section 7's fixed nested-call graph.

**Wallet checkpoint:** move `e=G[a]-P[a]*k` from wallet gons to receipt
escrow and `R0[a]`; require no deficit. This crystallizes an existing locked
gon entitlement, not a mint or payout. Neither prior receipt gons nor an
existing NFT becomes a newly issued reward receipt merely by appreciation.
Before any Stage-1 spend, this step puts the entire accrued surplus under
protocol custody. New role allocations are escrowed from issuance.

**Stake:** exact received `n` DETF creates `n*k` gons, adds `n` to backing
and liquid basis after checkpointing the recipient. Bond/SY funding uses
its fixed authenticated special-custodian branch and attribution ledger.
No amount declaration or idle surplus substitutes for receipt.
Normal receipt recipients exclude receipt escrow, bond custody, staking SY
and RT. Generic transfers cannot spend those custodians' inventory. Only
the actual bond or staking SY may fund its own custodian branch; SY's
authenticated deposit pull is the only generic receipt-transfer ingress to
staking SY. Bond claims and reward releases cannot bypass SY accounting by
paying it directly. Raw SY and parent receipt intermediates are ordinary
basis accounts, spending only their current operation packet. For protected
custodians `egressState` reports zero public spend authority, not a fictional
wallet surplus obtained by subtracting zero basis from their entire backing.

**Stage-1 transfer/withdrawal:** require `n<=P[from]`; transfer or burn
exactly `n*k`, and reduce basis by exactly `n`. Transfer credits the normal
recipient's basis by `n`; withdrawal pays exactly `n` held DETF.
Never clip a larger request to the cap. Active native transfers/withdrawals
can spend `floor(G/k)` and update basis without underflow. `transferFrom`
spends the native allowance, including max and owner-as-spender calls:
`K/tokens/ERC20/ERC20Repo.sol:157-166,297-301`.
ERC2612 is retained, not a second reward authorization.

`balanceOf` remains physical `floor(G/k)`; during Stage 1 its grown amount
is not a promise of transferable reward. A new `egressState` reports basis,
latent/deferred gons and exact executable principal cap. Existing 1:1
SE previews quote conversion, not another account's authority. Both direct
exact-in and supported exact-out receipt exits apply the same cap.

**Bond:** only the actual wired parent creates fresh marked positions using
the existing exact pull/stake/delta pipeline, with actual creation time and
90 days supplied internally. Existing owner/operator rules and recipient
validation remain. For marked positions:

```text
principalDue = 0 before start+90 days, otherwise Pi
require floor(Gi/k)>=Pi
rewardDue = floor(Gi/k)-Pi
```

Unmarked ordinary Stage-2 purchases retain canonical linear vesting and
their own issuance/reward ordering; migration surrender keeps fresh cliffs.

Rewards-only and combined requests reject atomically before activation,
even after maturity. Principal-only pays at maturity. Debit `Gi`, remaining
principal and aggregate attribution before the bond-only receipt call.
Transfer `(principalPaid+rewardPaid)*k` actual gons; the receipt independently
requires activation if `rewardPaid>0`. The claim recipient's later growth is
separate from original rewards still on the NFT. Three guarded NFT transfer
selectors convey the remaining position/clock, not a new reward payout.

**Deferred wallet/role release:** after activation only, pay
`n=floor(Rd[a]/k)`, debit exactly `n*k`, transfer those existing receipt
gons to fixed beneficiary `a` and credit its liquid basis. Repeat at unchanged
`k` is zero. Domain 2 uses section 5 instead, not this native release.
Anyone may trigger fixed-beneficiary role release; no free recipient argument.
This also avoids making an ordinary contract beneficiary implement a new
claim callback. Protected protocol custodians remain separate gifts, not
publicly redeemable user principal.

**Rights assignment:** actual owner may assign exact already attributed
`R0` or `R2` gons to another normal account in either stage; custody never
moves and no token is minted. Native ERC20 approvals do not authorize it.
`R1` allocation ownership cannot be retargeted. Existing NFT transfer remains
the way to transfer the NFT's still-attached rights.

### Admitted rounding and retirement, not r1's stronger draft rule

FundedPlan:192-196 and `C/claimToken/DETFFundedStakingRepo.sol:109-139`
admit retirement of **this account's** sub-native fraction on full displayed
unstake; `C/bondNft/DETFFundedBondTarget.sol:200-208` admits retirement of
**this position's** fraction once all principal and whole-unit rewards are
paid. Preserve those conditions and credit the aggregate liability reduction
to `Ds`. Do not turn an arbitrary `g<k` into authority to retire pooled gons.

A Stage-1 principal exit is not a full reward exit: checkpoint first and
retain its `R0`, even after wallet basis reaches zero. Bond retirement cannot
erase a whole reward unit or remaining principal. A final sub-native bond
fraction meeting the canonical condition is retired, not silently promised
as a forever transferable right. RT quantum residue is **not** covered by
that rule: `q` can exceed current `k`, so less than one RT can still represent
many payable native DETF units. Section 5 preserves and pays it explicitly.

## 4. SY principal accounting and the actual internal-balance contract

### 4.1 Checkpoint, deposit, transfer and redemption

At each affected address, before its shares change:

```text
if s[a]=0 and l[a]=0: initialize l[a]=k
g = s[a]*(l[a]-k); require l[a]>=k
l[a]=k; A-=g
move g physical gons from stakingSY to receiptEscrow
credit R2[a]+=g (except self address, section 4.3)
```

This makes old rewards stay with the old SY holder, including a contract
holder whose downstream users have already recorded claims. A late entrant
starts at current `k`. Zero/self transfers checkpoint each distinct account
once. Shares never carry already-accounted rewards to the recipient.

Deposit acquires actual permitted principal first, then pins final `k` after
any active issuance distribution. Mint exactly `n` native shares for measured
`n*k` new gons; add those gons to `A`. No `Q` division/conversion dust is
introduced by this principal representation. Direct receipt input is pulled
by SY and leaves the sender's old wallet rewards in `R0[sender]`.
Direct DETF is actually staked. Configured external acquisition is closed in
Stage 1 **before** parent primary/swap branch selection; after activation
reuse the actual route and measured output.

Transfer moves exactly `x` shares, logically backed by `x*k`, after source
and recipient checkpoints. A redemption checkpoints its selected source,
burns exactly `x` shares and removes exactly `x*k` from `A`:

| Output | Exact operation |
| --- | --- |
| sDETF, when configured | Fixed-SY-only receipt method transfers `x*k` actual gons to receiver and credits `x` principal basis. |
| DETF | Fixed-SY-only receipt withdrawal burns exactly `x*k`, debits `B` by `x` and transfers exactly `x` DETF. |
| Every other configured output | Withdraw exactly `x` DETF to SY; approve only `x` to parent; execute the actual parent route; clear allowance; check actual output and final minimum. |

Raw SY retains `rawBacking=issued raw shares`, no staking and empty reward
arrays. Its configured receipt/external routes still use the principal-aware
parent. Unsupported routes, insufficient shares, expired parent deadlines,
short input, acquisition/output minimums and downstream failures revert all
funding, checkpoints, approvals, burns and payouts.

Both wrappers return truthful routes and nine-decimal metadata. Staking
`exchangeRate=1e18`, `assetInfo=(TOKEN,DETF,9)`, `yieldToken=sDETF`.
Principal previews for direct DETF/sDETF are `x`; configured routes use the
same parent quote/budget. Rewards are not added to principal previews.
Unavailable Stage-1 external acquisitions preview unavailable, not success.

### 4.2 Required caller graph: preserve the five-argument redeem

The exact standard source selection remains:

```text
redeem(receiver,x,out,min,false): source=msg.sender
redeem(receiver,x,out,min,true):  source=address(SY)
```

The second branch burns actual issued SY shares held by SY, **not underlying
inventory**, and does not infer an original owner or require a new ticket.
This is expressly required by FundedPlan:330 and implemented by
`C/sy/DETFSYTarget.sol:94-121`. r1/r2's ticket restriction was an engineering
proposal, not owner law. It caused F3 by changing this contract.

| Graph | Source, caller, retained reward owner and principal budget |
| --- | --- |
| Direct external redeem | Alice calls SY; source Alice; `R2[Alice]` remains hers; receiver may differ; spend `x`. |
| Approved atomic direct pull | R pulls Alice -> SY with Alice's SY allowance, then calls old `redeem(...,true)` for exactly `x`; pre-transfer rewards remain Alice's, not R's or receiver's. |
| Caller-funded self deposit | R pays actual input to `deposit(SY,...)`; returned new share amount is its operation budget; old self shares are excluded from R's calculation; old redeem works unchanged. |
| Parent receipt composition | User -> parent receipt pull -> exact unstake -> optional real output route. This is `D/UniswapV4DetfTarget.sol:364-374`, not a parent call to `redeemInternal`. |
| Optional YT upstream push | Actual sender YT checkpoints its rewards, sends principal SY directly to SY; router performs old internal redeem. Source identities are `P/router/base/ActionBase.sol:94-129` and `P/core/YieldContracts/PendleYieldToken.sol:317-339`. No YT ticket/allowance to router is invented. |
| Optional market push | Actual market sends SY to SY after burn/swap; old router redeems the exact returned principal amount. `P/core/Market/v3/PendleMarketV3.sol:129-145`; r2's external-R reroute is unnecessary. This establishes the SY handoff, not market admission or successful pricing. |

An approved router has principal-transfer authority, not authority to redirect
the source's retained reward account. Wrong source allowance, external redeem
without shares, or wrong fixed-custodian caller rejects. Conversely, a test
that demands an arbitrary caller **cannot burn deliberately self-held SY**
would contradict the required bearer API. Underlying donations cannot create
self shares. Pending self shares are not authenticated storage for a user.
Atomic callers pull/deposit and redeem within one transaction, using explicit
returned/delta budgets, never `balanceOf(SY)` as their input amount.

### 4.3 Self-held shares and delayed internal redemption

Do not conceal this standard boundary: transferring issued shares to SY
relinquishes control of that bearer principal. Its old holder keeps rewards
earned **before** transfer. Rewards earned while shares remain self-held
belong to no external user account. Settle them into `U`, under protocol
custody, and neither pay them to the next internal redeemer nor award them
to a new depositor. `claimRewards(SY)` returns `[0]` after activation;
`accruedRewards(SY)` returns `[0]`. `U` has no public payout/sweep path.
It remains in `T` and fully backed, not destroyed or described as dust.

This follows the concrete reward-consumer self exclusion at
`P/core/RewardManager/RewardManagerAbstract.sol:35-44` together with
`P/core/StandardizedYield/SYBaseWithRewards.sol:74-95`, rather than creating
an invisible user ticket on an interface that deliberately burns a bearer
balance. It is an explicit consequence of the selected separate-reward SY,
not a promise of user-owned multi-transaction escrow. Required atomic caller
graphs settle before transfer and immediately redeem; their original owner's
earned rewards remain payable. The delayed self-balance witness documents
the different case, including its retained `U`.

## 5. Real reward API, quantum and payout

For every external SY holder:

```text
latent(a) = s[a]*(l[a]-k), with untouched zero-share slot handled first
getRewardTokens() = [RT]
rewardIndexesStored() = [1+Q-k]
rewardIndexesCurrent(): synchronize actual funding, return stored expression
accruedRewards(a) = [floor((R2[a]+latent(a))/q)]
```

Index unit is **WAD-scaled native RT per native SY**; initial sentinel is 1.
Since `q=W`, the unchanged consumer formula is:

```text
floor(s*(Inew-Iold)/W) = floor(s*(kOld-kNew)/q) native RT
I<=Q<2^128
```

At ten native principal and ten funded reward units: `k=Q/2`,
`I=500000000000000000000000000000000001`, and reward is `5*10^18`
native RT backed by `5*10^36` gons, worth ten native sDETF.
It is not `5*10^36` native RT or `5*10^18` native sDETF.
`RT!=yieldToken`, respecting the warning in `SYBaseWithRewards.sol:7`.

**`claimRewards(a)` requires activation, including a zero claim.**
Checkpoint `a`; let `m=floor(R2[a]/q)`. Debit `m*q` from `R2[a]`,
add `m*q` to `E`, and mint exactly `m` RT to `a`. Return `[m]` and emit
`ClaimRewards` with RT and that native RT amount. Any caller may trigger it,
but cannot choose another beneficiary. In Stage 1 it reverts before delivery;
no RT exists outside custody, and in this construction RT supply is zero.
There is no early mint relabeled as a locked-right assignment.

RT is fixed-gon, nonrebasing and transferable. Its own native units do not
grow; their underlying gons appreciate from actual future funding. On
activated `RT.redeem(m,receiver,minNative)`:

```text
require caller's RT balance >= m and normal receiver
g=m*q; n=floor(g/k); r=g-n*k
burn m RT; E-=g
move n*k actual receipt gons escrow -> receiver; liquidBasis[receiver]+=n
R0[actual RT owner]+=r
require n>=minNative
```

The RT owner retains every gon not paid, even when receiver differs. It can
claim/assign that remainder; no new funding or `T` increase occurs. Zero RT
redeem returns zero; a positive token burn with zero native output requires
zero minimum and preserves **all** its gons in the owner's `R0`.

The unmaterialized `R2%q` is also an owned right, not forfeited conversion
dust. Add owner-only `SY.claimRewardRemainder() returns(uint256 nativePaid)`:
after activation and checkpoint, pay `floor((R2[caller]%q)/k)` sDETF,
debit only `nativePaid*k`, retain the rest. This is an explicitly named
native-sDETF extension, not the standard RT-valued `claimRewards` return.
It cannot spend the `floor(R2/q)*q` backing reserved for standard RT claims.
Exact owner-authorized R2 assignment can consolidate fractions as well.

A claim at unchanged funding repeats zero. After all principal shares leave,
old `R2`, RT and its retained R0 still appreciate according to their actual
gons. No historical principal remains in `T` after its withdrawal.

### Honest consumer limits

There is no local wide consumer and no guarantee of all stock Pendle behavior.
The corrected index fits uint128, but large legitimate accrued RT quantities
can still exceed a stock uint128 field. The Migration ledger/token use
uint256; no user cap is added to accommodate optional consumers.
The stock manager floors each user update (`RewardManagerAbstract:44-64`);
it can lose sub-token fractions in its own ledger. r3 preserves exact
beneficiary fractions at the SY boundary and does **not** advertise stock
downstream exact-fraction support or silently patch it.

Stock first-expiry checkpoint calls `SY.claimRewards(YT)` before storing
reserved rewards (`PendleYieldToken.sol:373-385`). Stock market mint/transfer
harvests SY and the controller (`PendleGauge.sol:84-86,109-114`;
`PendleMarketV3.sol:96-110,347-356`). These operations can revert during
Stage 1. They are not delivered integrations. No caught/skipped harvest,
zero fake payment, expiry exemption or extra controller is proposed.
Migration itself has no expiry (Plan MIG-P07); its 90-day clock is a cliff.

N2's actual negative remains: membership in a fresh market factory does not
admit that market to an unchanged controller's four immutable registries
(`PendleMarketFactoryV3.sol:39-63,69-116`;
`PendleGaugeControllerBaseUpg.sol:42-93`). This construction removes that
unrequested factory from its dependency graph; it does not claim to fix,
register or bypass the controller.

## 6. Exact proposed additions and selector coverage

These signatures are proposed, not installed. Keep existing ERC20/permit,
IStakedDETF, SE, bond and full IStandardizedYield selectors with the policies
above. Do not expose r1/r2 `redeemInternal`, tickets, wide reward getters,
early `materializeSyRewards`, or arbitrary external execution.

```solidity
// Permanent parent query, sole activation authority:
function migrationActivated() external view returns (bool);
function migrationSyRewardToken() external view returns (address);

// Receipt; public owner checkpoints/claims synchronize before local lock.
function egressState(address account) external view returns (
    uint256 physicalGons, uint256 liquidBasis, uint256 latentGons,
    uint256 walletGons, uint256 roleGons, uint256 syGons, uint256 maxUnstake);
function checkpointRewards() external returns (uint256 movedGons);
function deferredRewardGons(uint8 domain, address beneficiary) external view returns (uint256);
function tokenizedSyRewardGons() external view returns (uint256);
function claimDeferredRewards(uint8 domain) external returns (uint256 nativePaid); // 0 or 1
function claimDeferredRoleRewards(address beneficiary) external returns (uint256 nativePaid);
function transferDeferredRewardRights(uint8 domain,address to,uint256 gons) external; // 0 or 2

// Receipt custody entries: fixed caller, pinned index, post-effects coverage.
function deliverBondClaim(address recipient,uint256 principal,uint256 reward,uint256 expectedK) external;
function deferSyRewards(address beneficiary,uint256 gons,uint256 expectedK) external;
function transferSyPrincipal(address recipient,uint256 principal,uint256 expectedK) external;
function withdrawSyPrincipal(address recipient,uint256 principal,uint256 expectedK) external;
function issueSyRewardTokens(address beneficiary,uint256 expectedK) external returns (uint256 nativeRT);
function paySyRewardRemainder(address beneficiary,uint256 expectedK) external returns (uint256 nativeSDETF);
function redeemSyRewardTokens(address owner,address receiver,uint256 nativeRT,uint256 minNative)
    external returns (uint256 nativeSDETF,uint256 retainedGons);

// SY extensions, in addition to the unchanged standard ABI:
function claimRewardRemainder() external returns (uint256 nativeSDETF);
function attributedSyGons() external view returns (uint256);

// RT: ordinary ERC20 metadata/allowance/transfer plus fixed-receipt mint/burn.
function mintByReceipt(address beneficiary,uint256 amount) external;
function burnByReceipt(address owner,uint256 amount) external;
function redeem(uint256 amount,address receiver,uint256 minimum)
    external returns (uint256 nativeSDETF,uint256 retainedGons);
function previewRedeem(uint256 amount) external view returns (uint256 nativeSDETF);
function receipt() external view returns (address);
function parent() external view returns (address);

// Read-only on bond, receipt, both SYs, RT as appropriate:
function attributedBondGons() external view returns (uint256);
function migrationAccountingPhase() external view returns (uint8);
```

`deferSyRewards(SY,...)` credits `U`, not R2. `issueSyRewardTokens` and
`paySyRewardRemainder` are staking-SY-only, independently activation-gated,
and fixed-beneficiary. `deliverBondClaim` is bond-only. SY principal methods
are staking-SY-only and cannot credit unbacked principal. They read actual
post-debit `attributedSyGons`; bond delivery/retirement reads actual
post-debit bond attribution. `expectedK` must equal current `k`; no caller
assertion substitutes for physical coverage.

`redeemSyRewardTokens` is RT-only. Unlike r2's missing synchronization edge,
it is an explicit synchronized receipt entry: RT calls it with its actual
caller as owner; receipt synchronizes, checks activation, fixes `k`, calls
RT's receipt-only burn, checks post-burn supply against new `E`, then pays.
RT never invokes an inaccessible internal `_synchronize`.
RT mint likewise checks receipt liability and actual supply before/after.
No public caller can mint RT, specify another owner's redemption or mint
receipt principal through these methods.

Events retain native Transfer/Deposit/Redeem/ClaimRewards semantics and add
exact-gon custody events carrying source, beneficiary/domain, gons and `k`.
Emit explicit native remainder payment and canonical retirement/dust changes.
No ambiguous "reward amount" mixes gons, RT units and native sDETF.

## 7. Real dependency admission, locks and operation order

The actual production dependencies retained are the existing manager/
registry/CREATE3/callback factory, real configured reserve hook/SEs, fee
oracle, parent, bond, receipt, two SYs and the new local RT child.
There is no PENDLE reward dependency or external privileged registration.

1. Authorized manager owner/operator deploys registered parent/bond/SY
   packages through `VaultRegistryDeploymentTarget.deployPkg:44-53`.
   Registered packages call their own `deployVault`; registry verifies
   registration/disabled state and invokes the callback factory (:64-76).
   No unprivileged fake registration is used. Registry authority is a
   pre-existing deployment prerequisite, not Migration owner's authority.
2. Parent package selects the real Migration bond and receipt facets.
   Existing bond package uses registry (:48-53); receipt uses the generic
   callback factory (`RebasingClaimTokenDFPkg.sol:39-59`).
   Their reciprocal parent/bond/fee-oracle identities remain exact.
3. After receipt is wired, deploy RT through its local generic package,
   args `{parent,receipt,metadata}`; once-initialize, validate reciprocal
   receipt-parent identity, and store RT once on parent.
   Until that pointer is nonzero, no RT caller is admitted by receipt.
   No predicted circular binding or mutable minter setter is needed.
4. Deploy both SYs through the registered selected package as in
   `DETFSYDeploymentLib:15-27`; staking SY reads the parent's fixed RT.
   Raw SY has no RT allocation. Verify both wrapper backing identities,
   mode/routes, RT parent/receipt and all selected interfaces before atomic
   parent completion. No initializer/updater is installed on child proxies.

The retained reserve admission is concrete too: the hook must contain
exactly one parent self-leg and have that parent as owner
(`D/UniswapV4DetfProcessArgsLib.sol:53-64`); the weighted first join is
liquidity-owner-only and full-book
(`contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:142-147`).
The current Migration owner authorizes the outer pooled-genesis call, while
the actual parent is the hook caller. Underlying SE liquidity/readiness,
route/provider bindings and real recovery assets remain actual deployment
inputs, not a fictional controller-admission step.

The finite admission predicates are **not** execution of these deployments.
Existing concrete callable entrypoints provide an implementation route;
fresh artifact/proxy execution remains section 9's acceptance gate.
Current `DETFSYDFPkg.facetInterfaces:66-74` and related child declarations
need narrow extensibility for actual added interfaces, not false declarations.

Phases are `Idle, Synchronizing, Acquiring, Accounting, Paying`.
Keep the receipt's save/restore of its Synchronizing phase when the genuine
parent funds it before its outer lock. Public entries reject incompatible
nested phases. Parent settles before funding new principal. The existing
locked-parent no-op remains **only** receipt/bond
(`D/UniswapV4DetfMaintenanceTarget.sol:16-27`), never SY/RT/router.

| Operation | Ordered graph |
| --- | --- |
| Parent stake/unstake/issuance | Parent lock and settlement; exact input; wired receipt/bond callback no-op; child local accounting; exact principal payment. |
| Receipt wallet entry | Announce Sync; parent settles and may call receipt funding; restore Sync; local lock; checkpoint; debit/transfer/pay; Idle. |
| Bond claim/transfer | Bond Sync -> parent -> bond lock; validate owner/operator/clock/gate; debit position and attribution; typed receipt call; guarded receiver callback; Idle. |
| SY deposit | SY Sync -> parent -> Acquiring; actual permitted route; pin final index; checkpoint recipient; add measured principal; mint; verify; Idle. |
| SY redeem | SY Sync -> parent -> Accounting; checkpoint source; burn shares/debit A; pinned receipt principal call; Paying; exact optional parent output route; final minimum; Idle. |
| SY reward claim/remainder | Sync -> parent -> Accounting; checkpoint beneficiary; receipt-only escrow transition; activation-gated RT/native delivery; Idle. |
| RT redemption | RT busy -> explicit synchronized receipt entry -> parent funding if due -> receipt Accounting -> fixed RT burn -> receipt payment and retained R0 -> Idle. |
| Donations | Preserve authorized bond-first -> parent join cycle; do not pre-lock parent forwarding and deadlock it. New parent-resident pooled donation/genesis has its own exact budget/lock path. |
| Activation/admin | Current owner; all five fixed children idle; parent lock; complete Remove cuts with actual owning facets; finalized flag; no intervening external callback. |

Parent admits only its fixed child's matching synchronization/acquisition/
payment callback, never a token callback borrowing another child's phase.
Ordinary parent ERC20 allowance/transfers used for backing remain usable.
SY output accounting is finished before onward reserve execution. Pin/index
checks and uncaught failures prevent a mid-call packet resize. Safe NFT
callbacks must be tested in their actual pre-ownership-update order.

Activation moves no assets, mints no RT, scans no beneficiaries and resets
no index or clock. Retained owner-only harvesting and permanent queries
survive; all Plan section 6.1 administration selectors disappear atomically.

## 8. Minimal future production edit paths

This is an implementation specification, **not authorization to edit them
in this lane**. No shared Crane/vendored source is an edit target.

| Exact paths or explicit brace expansion | Bounded change |
| --- | --- |
| `M/claimToken/IUniswapV4DetfMigrationStakedDETF.sol`; `M/claimToken/UniswapV4DetfMigrationStakedDETF{Repo,Target,Facet}.sol` | Basis, beneficiary custody, E/U, exact typed funding/payment methods and phases. Reuse canonical common funded state/math. |
| `M/bondNft/IUniswapV4DetfMigrationBondNFTVault.sol`; `M/bondNft/UniswapV4DetfMigrationBondNFTRepo.sol`; `M/bondNft/UniswapV4DetfMigrationBondNFTVault{Target,Facet,DFPkg}.sol`; `M/bondNft/UniswapV4DetfMigrationBondMetadata{Target,Facet}.sol` | Fresh cliff and genuine-parent creation, gated receipt delivery, canonical narrowly authorized retirement, metadata and three guarded transfers. |
| `M/sy/IUniswapV4DetfMigrationSY.sol`; `M/sy/UniswapV4DetfMigrationSY{Repo,Target,Facet}.sol` | Principal shares, exact old-owner checkpoint, standard bearer burn, correct RT API and remainder extension. Both wrappers retain required routes. |
| `M/sy/rewards/IUniswapV4DetfMigrationRewardToken.sol`; `M/sy/rewards/UniswapV4DetfMigrationRewardToken{Repo,Target,Facet,DFPkg}.sol` | One fixed-q, 27-decimal token, receipt-only mint/burn, owner redemption, once-only bindings. No external protocol import spine. |
| `C/claimToken/StakedDETFTarget.sol`; `C/bondNft/DETFFundedBondTarget.sol`; `C/sy/DETFSYTarget.sol` | Narrow implemented dispatch/route-helper seams where concrete nonvirtual methods prevent Migration specialization. Keep ordinary behavior. Existing virtual distribution/claim seams are already present. |
| `C/claimToken/RebasingClaimTokenDFPkg.sol`; `C/bondNft/DETFNFTVaultDFPkg.sol`; `C/sy/DETFSYDFPkg.sol`; `C/bondNft/DETFFundedBondMetadata.sol` | Narrow declaration/rendering extensibility only; never claim unsupported interfaces. |
| `M/interfaces/IUniswapV4DetfMigration{,DFPkg}.sol`; `M/UniswapV4DetfMigration{Repo,Policy,DFPkg}.sol`; `M/UniswapV4DetfMigration_Component_FactoryService.sol`; `M/UniswapV4DetfMigration_Pkg_FactoryService.sol` | One RT package binding/completion; actual child interfaces/phases; existing owner/genesis/lifecycle contract. |
| `M/UniswapV4DetfMigration{ExchangeFacet,BondFacet,MaintenanceFacet,QueryFacet}.sol`; `D/UniswapV4Detf{Common,Target}.sol` | Migration-only empty baseline, parent-first settlement, ordinary new-money gates and operation-budgeted residual handling, via narrow ordinary-preserving seams. |

Reuse the existing generic receipt and registered SY package with selected
facets and narrow declarations; no additional standalone receipt/SY deployment
framework. Do not add r2's integration factories, adapter package, wide
reward managers, YieldToken/Gauge/Market copies, tokenized one-gon API,
ticket maps or optional consumer deployment arguments.
The other allocation/snapshot/legacy tasks remain their original Plan work,
not extra egress edit scope.

## 9. Executed evidence and real-proxy validation contract

Owned finite evidence is under `evidence/egress-r3/`. Its ledger imports the
read immutable independent `egress-verification/reference.mjs` solely for
canonical funding and native bookkeeping, replacing rejected SY transitions.
It is a mathematical oracle, **not a test-only issuer used as the SUT**.
`results.md` records actual executions, failures, numeric receipts and
cleanup. No forged addresses, fictitious route prices or market-success
predicates substitute for runtime acceptance.

Executed evidence demonstrates:

- Mature principal 10 exits during Stage 1; original bond rewards 25 and
  delivered-principal growth 5 later pay to their separate owners; total
  paid 40, final backing zero.
- SY's old holder receives 20 after all principal leaves to another
  receiver and more real model funding arrives; RT supply was zero before
  activation. The source consumer-unit/fee calculation pays old user 18
  and treasury 2 after activation, once.
- 304 mixed-cohort/split/transfer/exit cases pay 3,872 principal and 6,585
  rewards; 606 nonzero owner residues remain explicitly accounted.
  Each sequence includes a failed-minimum rollback and locked reward claim.
- A sub-RT remainder of 555,555,555,555,555,554 gons is not thrown away:
  further canonical funding reaches `k=1`, then it pays that many native
  units through the named remainder method.
- Actual source sender identities, direct allowance failures, public internal
  burn, two preserved old self shares, caller-funded self deposit, parent
  intermediates, role identity, canonical final retirement and no RT before
  activation are checked. Optional upstream rows prove handoff only.
- Seventy-two raw-SY budget cases retain prior self shares, empty reward
  arrays and exact native principal; configured outputs are explicitly only
  input-budget checks, not simulated price acceptance.
- R1's unfunded native index, r2's premature token delivery/wide index,
  first-expiry Stage-1 harvest failure and fresh-factory controller rejection
  remain recorded as negatives, not changed to pass.

**Not executed:** Solidity deployment, real token transfer, actual reserve
pricing, signatures, callbacks, gas, selector cuts or real legacy sources.
The runtime contract for the next authorized implementation increment is:

1. Real registered Migration parent/bond/SYs, actual funded receipt and RT,
   real configured weighted reserve and SEs; CREATE3 facets/artifact-first
   build. Use `M/TestBase_UniswapV4DetfMigration.sol` and the genuine Plan
   independent-issuance route (later source surrender), never parent
   impersonation, arbitrary credit, SUT subclass, storage injection or etch.
2. Execute every receipt/parent/bond/SY matrix branch above, direct and
   composed. Include all actual configured outputs and supported exact-out
   routes with real observed output amounts, not a model conversion ratio.
   Assert input/output token deltas, cleared allowances and total rollback.
3. Observe real 90-day boundaries and prolonged Stage 1; principal succeeds,
   no RT transfer/mint or reward sDETF payout reaches users. Activate through
   the actual current-owner cut; pay every retained beneficiary once, including
   zero-share owners, changed roles, RT assignees and remainder owners.
4. Validate physical gon custody and native backing after each operation;
   canonical dust/retirement, multiple cohorts, self/zero transfers,
   allowances/permits, self-held SY semantics, wrong custody caller,
   stale index, callback-owner activation, idle underlying and repeat claims.
5. Derive selector controls from actual interfaces/targets and inspect the
   completed proxy loupe, declared interface IDs and runtime size. Prove
   no inherited ordinary payout, public initializer, arbitrary cut/executor
   or restoration path survives. Keep ordinary V4/common regressions.

Build with Solar before tests through the repository artifact-first workflow.
Run the actual new Migration suites and ordinary V4/common suites, then the
Plan's complete release/fork gates in their authorized lanes. No claim that
currently absent tests ran or that integer models close E4/E5.

## 10. DoneClaim, limitations and cleanup

**DoneClaim:** this lane delivers one explicit r3 accounting/caller
construction and reproducible bounded evidence, correcting N1 without
early reward-token delivery and N2 without new protocol deployments.
It preserves required SY entrypoints/internal balance semantics, native
principal and funded reward ownership. It explicitly replaces draft-only
one-gon precision, ticket restrictions and absolute no-retirement rules.

The required-surface construction is not a universal composability claim:
stock Stage-1 market/expiry harvesting, large narrow-field accrual and
downstream exact fractions are **not supported integrations**. They are
optional and have no asserted deployment obligation in the original Plan.
Bearer self-held SY is not owner escrow; its separately accounted self reward
reserve has no external beneficiary or new payout authority. Protected
protocol-custodian gifts likewise do not invent an administrator rescue.

E1/E2, actual recovery E3, runtime E4/E5 and original task completion remain
open. Real backing/route/phase/bytecode validation remains mandatory; no
production acceptance, funding, operational allocation or deployment is
authorized by this document. Independent reviewer disposition is not supplied
or impersonated here.

Only this report and the four arithmetic modules plus results receipt in
`evidence/egress-r3/` are authored, using apply_patch. Prior artifacts and
shared Crane remain untouched. Finite runtime/launcher outcomes and
diagnostic limitations are preserved in `results.md`; no Forge, install,
Git, commit, broadcast, external message or delegation was used.
