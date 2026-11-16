# T5-EGRESS: funded principal and retained reward gons

Date: 2026-11-10. Construction revision: `t5-egress-principal-sy-r1`.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`.

**Construction complete; runtime acceptance not claimed.** Use native-unit principal rights, the existing funded gon index, and segregated reward-gon custody. Principal can leave during Stage 1. The gons left by that exit remain the exiting owner's reward right, continue participating in actual funded distributions, and cannot become another account's principal. Activation permits release of already funded gons; it does not mint them again.

**The explicit Migration-only representation change is important:** staking SY becomes a nine-decimal, principal-denominated static share with separately accounted funded reward gons. One native SY share redeems one native principal unit; accrued rewards use the existing SY reward API and the receipt's retained-rights ledger. This is not the ordinary `shares * 1e36` appreciated-gon SY with a guard added. Its `exchangeRate` is `1e18`, its reward-token list contains sDETF, and its deposit preview no longer divides principal by the appreciated gon rate. Raw SY remains 1:1 raw DETF. These semantics are fixed in this construction, not left to an implementer or silently advertised as ordinary wrapper compatibility.

This representation resolves the indivisible-principal problem rather than rounding principal away. For example, fixed-gon shares with `Q=100`, `k=90`, nine shares and ten native principal units have 900 gons. Transferring one 100-gon share cannot partition all ten principal units into two independently solvent integer-principal holdings: the capacities are `floor(100/90)=1` and `floor(800/90)=8`. A proportional native-principal sidecar alone loses or underbacks one unit. This construction instead transfers one principal share with exactly 90 principal gons, plus explicitly attributed reward gons. It introduces no fractional native-principal liability, deficit subsidy, scan, or principal exit delay.

Consequently, the `children.md` section 4 proposed ordinary-SY oracle `representedGons=shares*1e36` is replaced **for this new Migration wrapper** by section 2.3's exact slot decomposition and section 6's separate principal/reward outputs. That report's section 2.4 expressly leaves the split storage and exit contract unfrozen. Its ordinary-wrapper formula must remain in ordinary regression tests; it cannot simultaneously be asserted for the selected principal-denominated representation. This is a declared implementation-contract change, not a claim that an unchanged `DETFSYTarget` already satisfies the construction.

The continuation authorizes choosing this engineering partition. It does not settle legacy E1/E2, actual recovery E3, or BOOTSTRAP-AUTH. No legacy attribution tuple, genesis authority, funding certification, arbitrary-credit issuer, or new owner privilege is selected here.

## 1. Evidence and inspected boundaries

Read the complete phase-03 continuation and original phase brief, complete `implementation-handoff.md` including section 4, complete `children.md`, and complete main-checkout `MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` (Plan). Plan MIG-P07/P08/P11, sections 4.1/5.5, task 5 and section 8.2 control the principal/reward obligations. Read the worktree router, assistant rules, applicable DETF agent law, Crane architecture guidance, Bun and arithmetic-script language guidance. No upstream report was edited.

Paths below are worktree-relative. `C` means `contracts/vaults/detf/common/`; `D` means `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`; `K` means `lib/crane/contracts/`. Source observations are distinguished from the proposed transitions in subsequent sections.

| Anchor | Inspected source and symbol | Observation |
| --- | --- | --- |
| S1 | `C/claimToken/DETFFundedStakingRepo.sol:24-36,52-64,82-102` | Actual gon balances, funded backing, native dust and persistent weights; initialization sets `k=1e36`; no principal/reward wallet partition. |
| S2 | Same file `:109-139,148-156,185-201,225-234` | Ordinary full withdrawal can remove an account's entire fractional balance; transfers move `amount*k`; distribution rebases first and issues role gons afterward. |
| S3 | `C/claimToken/StakedDETFTarget.sol:34-38,112-123,147-253` | Synchronization before local lock, native allowance spending, actual backing pull, parent-only rewards, implemented `_distributeRewards` dispatch, bond-only dust retirement, strict public pretransfer rejection. |
| M1 | `C/core/DETFFundedStakingMath.sol:9-11,46-94,97-123` | `Q=1e36`, allocation precision `1e54`, floor allocation, ceiling-funded rebase, bond remaining-principal deficit check and ordinary SY rate. |
| M2 | `C/core/DETFSeigniorageShareLib.sol:18-38` | Top-up-only standing weights; no redeemable principal from those weights. |
| B1 | `C/bondNft/DETFFundedBondTarget.sol:81-130,139-210` | Exact parent pull/stake/gon delta; consumed creation/calculation dispatches; principal and rewards pay through the same native receipt transfer; final sub-native position retirement. |
| B2 | Same file `:213-258`; `C/bondNft/DETFFundedBondRepo.sol:13-18,33-70` | Protected backing assets, guarded NFT transfers, per-position gons and aggregate attributed gons. |
| Y1 | `C/sy/DETFSYTarget.sol:54-121,124-180,196-256` | Ordinary static-gon wrapping/redemption, freely consumed wrapper internal balance, direct sDETF output bypass, empty reward API and aggregate conversion dust. |
| Y2 | `C/sy/DETFSYRepo.sol:15-23,38-78`; `C/sy/DETFSYDFPkg.sol:41-51,66-74,99-117` | Separate raw/staking wrapper identities, actual backing, route sets, selected facet and one-time initialization. |
| Y3 | `K/protocols/perps/pendle/interfaces/IStandardizedYield.sol:62-172` | Existing deposit/redeem, internal-balance burn, rate, reward list/claim/index and directional preview ABI. |
| P1 | `D/UniswapV4DetfTarget.sol:200-230,261-314,344-374` | Parent composes transfers, stake, unstake, primary/swap entry and onward redemption. Parent unstake first receives sDETF into its own address. |
| P2 | `D/UniswapV4DetfCommon.sol:314-325,349-385`; `D/UniswapV4DetfMaintenanceTarget.sol:16-27` | Parent reward settlement and funding; only wired receipt/bond synchronization can no-op under the parent lock. SY is not exempt. |
| A1 | `K/tokens/ERC20/ERC20Repo.sol:155-172,298-306` | Native allowance is checked and decremented, including a maximum-valued allowance; preserve this behavior, not an invented infinite-allowance convention. |
| A2 | `K/tokens/ERC721/ERC721Repo.sol:153-169` | Safe receiver callback precedes ownership mutation. |

The source was read before and during concurrent preparation. Stable symbol meanings above are the dependency; preparation may move lines while extracting the authorized helpers. Content fingerprints computed from `read` text on this inspection:

| Source | SHA-256 |
| --- | --- |
| `C/claimToken/StakedDETFTarget.sol` | `fed9bd4bf324c8e1c3d71e1809c3ae516320d05beb580085b2deedb83bb24f82` |
| `C/claimToken/DETFFundedStakingRepo.sol` | `ac8618bcc168f05902ae27da16381bbfed2811ff19cbf992ab07666198c6abe9` |
| `C/core/DETFFundedStakingMath.sol` | `3ec13e4bb20549f5e3055e63212d6518cdc011bb616bab2783e22e5c7a20ba06` |
| `C/bondNft/DETFFundedBondTarget.sol` | `ff3c95b45adec74973aabcb874be2a8d86aa79a9af8770949b0b7e635fbcc360` |
| `C/bondNft/DETFFundedBondRepo.sol` | `23fbbc8494229c7f87e56d118d8931991e16bcdb8fb1425d6d8eb553926e58a4` |
| `C/sy/DETFSYTarget.sol` | `245a0a49e045c663c432391bafd2efd3d6778e71ae5e9b18e8855e7c9bc749c2` |
| `C/sy/DETFSYRepo.sol` | `92226fd5440862f424aa0fecbf4337af1f96f9324296a9513c30d6570d0d990e` |
| `D/UniswapV4DetfTarget.sol` | `aa177d25e2d7462db3727562884aa082e52305b86f97880dd82cd0c86ede004f` |
| `D/UniswapV4DetfMaintenanceTarget.sol` | `50bc1ac57a74a30201afe0f23a987b40d440a873302b6b47ad1d0f9389f2f6fd` |

These are inspection fingerprints, not deployed runtime identities or a claim that preparation has stopped. The final source read includes preparation's `_createFundedPosition`, `_calculateClaim`, virtual `_claim`, and implemented `_distributeRewards` extraction; their default economics remain the source observations above.

## 2. State, units and authority

All arithmetic below is integer arithmetic. `floor`, `ceil`, `min` and exact checked subtraction are explicit. Use full-precision `mulDiv` for products divided by a denominator; reject an unrepresentable uint256 result. Never truncate a gon product to fit storage.

### 2.1 Receipt and backing

Retain the common receipt namespace and its actual funding machinery:

| Symbol | Unit / owner |
| --- | --- |
| `Q=10^36`, `k` | Gons per native sDETF unit; initial and current divisor. `1 <= k <= Q`. |
| `G[a]`, `T` | Physical receipt gons at address `a`, total issued gons. The receipt proxy, bond proxy and staking SY are real gon custodians. |
| `B` | Accounted native DETF backing in the receipt proxy. Actual held DETF must be at least `B`. |
| `Da`, `Ds` | Native allocation dust and native staking dust from the existing math. Not beneficiary gon balances. |
| `F`, `Cw` | Nonredeemable fee/creator standing weights, in the existing gon-weight units. |

Add in `UniswapV4DetfMigrationStakedDETFRepo`:

```solidity
struct Storage {
    mapping(address => uint256) liquidBasis;
    mapping(uint8 => mapping(address => uint256)) deferredGons;
    uint256 totalDeferredGons;
    uint8 accountingPhase;
}
```

Use an independent ERC1967-style namespace, `bytes32(uint256(keccak256(abi.encode("indexedex.detf.uniswap.v4.migration.egress.receipt"))) - 1)`, with Crane's explicit/default layout overloads. All added state starts at zero. The phase field is transient-in-effect persistent storage: set/clear it within the operation; a revert rolls it back.

`P[a] = liquidBasis[a]` is native units. During Stage 1 it can arise only from real DETF staking, a permitted bond principal delivery, a permitted SY principal delivery, or a transfer of those units. After activation, an authorized reward payout or unrestricted native transfer may also add to this liquid basis. That post-activation bookkeeping is not historical-principal attribution.

`R[d,a] = deferredGons[d][a]` is gons: domain `0 = wallet and retired bond residue`, `1 = captured role allocation`, `2 = detached staking-SY reward`. Physical custody for every `R` is `G[receiptProxy]`; `totalDeferredGons = sum R`. There is no second token, detached backing pool, new index, or synthetic reward mint.

Bond and staking SY are special custodians, not ordinary `P` accounts. The receipt proxy's own balance is exclusively deferred custody. Their generic outgoing receipt `transfer`/`transferFrom` routes cannot spend attributed inventory; they use the narrow APIs in section 7. Reject generic receipt sends to these custodians, except the authenticated staking-SY pull during its deposit. Bond funding uses its existing authenticated DETF pull/stake path. Raw SY and parent transient receipt holdings are ordinary `P` accounts, with their existing operation-local accounting.

Initialization creates no gons, basis or deferred right. No caller can initialize a nonzero credit. Child identities come only from the immutable initialized parent/bond wiring. Until the parent has wired a nonzero staking-SY address, no SY authority matches. No mutable custodian allowlist or public registration setter exists.

### 2.2 Bond

Keep each existing `BondPosition` and aggregate `attributedGons`; add only the independently required Migration cliff marker. For position `i`:

```text
Pi = originalPrincipal - claimedPrincipal
Gi = position.stakingGons
Gi >= Pi*k
```

The NFT owns `Gi` and its remaining cliff obligation. `G[bond] >= sum Gi`; unsolicited surplus is not another bond's funding. The current NFT owner controls its whole remaining economic right under existing holder/operator authority. There is no wallet principal credit before a valid claim.

The Migration bond namespace is `bytes32(uint256(keccak256(abi.encode("indexedex.detf.uniswap.v4.migration.egress.bond"))) - 1)` and contains exactly `mapping(uint256 => bool) migrationCliff` and `uint8 accountingPhase`. Existing principal, clock and aggregate attribution stay in the common bond repo.

### 2.3 Principal-denominated staking SY

Keep nine-decimal ERC20 balances and allowances. Let `s[h]` be native shares in a logical holder slot. A slot is either `(External,beneficialOwner)` or `(Internal,beneficialOwner)`. Store `lastK[h]` and `attachedRewardGons[h] = r[h]`. Internal slots additionally store their own share count. A separate `(operator,owner)` native-share ticket authorizes spending internal principal; it does not make a router the reward beneficiary. External share counts come from the canonical ERC20 repo; do not duplicate them in a second mutable balance map.

```solidity
struct RewardSlot {
    uint256 lastGonsPerUnit;
    uint256 attachedRewardGons;
}
struct InternalSlot {
    uint256 shares;
    uint256 lastGonsPerUnit;
    uint256 attachedRewardGons;
}
struct Storage {
    mapping(address => RewardSlot) externalRewards;
    mapping(address => InternalSlot) internalBalances;
    mapping(address => mapping(address => uint256)) internalSpendShares;
    uint256 totalInternalShares;
    uint8 accountingPhase;
}
```

Use namespace `bytes32(uint256(keccak256(abi.encode("indexedex.detf.uniswap.v4.migration.egress.sy"))) - 1)` on each separate wrapper proxy. Binding, mode, route sets and aggregate backing remain in the common SY namespace; no additional mutable parent/receipt identity is introduced.

Use the common SY `backingGons` field for aggregate attributed gons `A`, including attached rewards. On a newly deployed Migration staking SY, `conversionDustGons` stays zero: there is no conversion of `n*k` to `floor(n*k/Q)` shares. The exact attribution is:

```text
A = sum_h (s[h]*lastK[h] + r[h])
G[stakingSY] >= A
ERC20.balanceOf(stakingSY) = totalInternalShares = sum internal-slot shares
ERC20.totalSupply = sum external-slot shares + totalInternalShares
internalBalances[owner].shares = sum_operator internalSpendShares[operator][owner]
```

The wrapper's own ERC20 address is not another external reward slot. All operators' tickets for one beneficial owner share that owner's one internal reward slot; claims/previews therefore need no operator scan. Unsolicited receipt gons are surplus `G[stakingSY]-A`, never credited to depositors or internal redeemers. No sweep may consume `A`. The wrapper owns the physical gons; each slot owns its precisely attributed economic rights.

The raw SY keeps its current `rawBacking` in native DETF. It needs the same internal-share ownership ledger, but no `lastK` or reward-gon arithmetic.

## 3. Unchanged funding and global conservation

Call the existing allocation/rebase/top-up algebra, not a simplified percentage calculation. For a measured reward receipt `f > 0`, let `W=T+F+Cw`, `H=10^54`:

```text
require W > 0
v = floor((f+Da)*H/W)
aS = floor(T*v/H)
aF = floor(F*v/H)
aC = floor(Cw*v/H)
Da' = f+Da-aS-aF-aC
L = floor(T/k)
u = aS+Ds
k' = k                              if T=0 or u=0
k' = ceil(T/(L+u))                  otherwise
growth = floor(T/k')-L
Ds' = u-growth
B' = B+f
```

Rebase existing gons first. In Stage 1, issue `aF*k'` and `aC*k'` gons into receipt-proxy custody and credit role domain `R[1,capturedBeneficiary]`. Both count in `T` and participate in every subsequent funded rebase. Equal beneficiaries merge by addition. Capture the two reserved NFT owners for this allocation before issuing its gons.

After activation, ordinary recipients get the allocated receipts immediately, with liquid basis increased by the paid native amount. Prior deferred allocations remain separate and releasable. If a role's actual beneficiary is itself a protected protocol custodian, retain that allocation in `R[1,thatAddress]` rather than count it as wrapper backing, bond principal or unassigned escrow. This avoids suppressing the whole distribution or silently gifting it to that custodian's users. No external user may release a protected custodian's own role gift, and this construction adds no generic executor, administrator rescue or beneficiary substitution for it. Ordinary contract beneficiaries remain supported and call as their own address.

Apply existing top-up-only weights after issue, direct stake and actual unstake. With oracle fractions `fW,cW` and `Z=1e18`:

```text
if T=0 or fW+cW>=Z: deltaF=deltaC=0
else:
  implied = floor(T*Z/(Z-fW-cW))
  deltaF = max(0,floor(implied*fW/Z)-F)
  deltaC = max(0,floor(implied*cW/Z)-Cw)
F' = F+deltaF; Cw' = Cw+deltaC
```

Custody moves, share transfers, deferred assignments and reward release do not change `T`; they do not mint a second role weight or change funding. Existing funding/weight previews remain usable because custody destinations do not affect the arithmetic.

Required identities at every completed operation:

```text
T = sum physical G[a]
B = floor(T/k) + Da + Ds
actual receipt-held DETF >= B
G[receiptProxy] = totalDeferredGons = sum R[d,a]
G[ordinary a] >= P[a]*k
G[bond] >= attributed bond gons
G[stakingSY] >= A
```

Unsolicited DETF is `held-B`, never a principal credit or reward funding. Native dust remains in its canonical class; it is not falsely assigned to one holder. At `k=1`, further unrepresentable funded growth remains canonical dust. No index reset or unfunded liability is allowed. Parent empty-baseline behavior still follows handoff section 3.2: empty means `T+F+Cw=0`, not zero liquid principal. Retained reward gons are genuine participation even after every principal exit.

## 4. Receipt transitions

### 4.1 Crystallize a wallet's growth, without payout

For an ordinary wallet `a`, after synchronization and under the local lock:

```text
e = G[a] - P[a]*k                  // checked; a deficit reverts
G[a] -= e
G[receiptProxy] += e
R[0,a] += e
totalDeferredGons += e
```

This is called `checkpoint(a)` below. It changes neither `T`, `B`, `k`, the native dust nor reward ownership. It moves actual already-issued gons into protocol custody. Even if `e<k`, preserve all of it. Do not round `e` to a native token amount.

The ordinary holder can explicitly call `checkpointRewards()` in either stage. It synchronizes, checkpoints only the actual caller, and returns the moved gons. This also permits an activated holder to combine a physical sub-native remainder with its detached wallet residue before release/assignment; it is not forced to wait for another distribution. Protected custodians cannot use this wallet operation.

### 4.2 Direct stake

Synchronize before credit. Validate route, recipient, deadline, nonzero amount and min/max bounds. Preserve the existing hard `pretransferred=true` rejection. Pull exactly `n` native DETF from the actual caller, measuring this operation's delta.

For a normal recipient in Stage 1, checkpoint its previous holding first, then:

```text
G[recipient] += n*k
P[recipient] += n
T += n*k
B += n
```

Active deposits use the same additions without needing a checkpoint. Protected bond/SY recipients are accepted only through their wired funding/deposit caller; their position/slot ledger, not `P`, receives the corresponding principal. Parent approvals and child allowances are exact and cleared after success.

### 4.3 Transfer and transferFrom

Stage 1: synchronize; checkpoint sender and receiver once each (only ordinary accounts); require `n <= P[from]`. For a distinct permitted recipient:

```text
G[from] -= n*k; P[from] -= n
G[to]   += n*k; P[to]   += n
```

For the staking-SY authenticated pull, credit `G[stakingSY]`, not `P[stakingSY]`; section 6 credits exactly `n` shares. A request above the sender's liquid principal reverts atomically, including preceding synchronization/checkpoints and allowance debit. This is a reward-bearing spend rejection, not a blanket transfer pause. The sender can transfer every native principal unit.

Active: require `n <= floor(G[from]/k)`; transfer exactly `n*k`; set `P[from]=max(0,P[from]-n)` and add `n` to a normal recipient's liquid basis. This can relabel released reward value only after the irreversible gate has opened. Existing detached `R` remains a separate claim until released.

Self-transfer checkpoints once, validates amount and otherwise changes no ownership. `transferFrom` still spends its normal native allowance, even on a self-transfer; preserve A1's maximum-allowance behavior. A zero transfer cannot manufacture basis or a funded right. Zero sender/receiver rejects.

**Meaning of the transfer:** a native receipt transfer during Stage 1 conveys principal and its future participation, not the sender's already accrued gated reward. That reward is explicitly retained under the sender's `R[0]`. Economic reward-right assignment is a separate gon-denominated action in section 4.6, not a payout and not authorized by a native ERC20 allowance.

### 4.4 Partial and full withdrawal

Stage 1: synchronize, checkpoint caller, require `0<n<=P[caller]`. Active: require `0<n<=floor(G[caller]/k)`. Both use:

```text
G[caller] -= n*k
P[caller] = max(0,P[caller]-n)
T -= n*k
B -= n
```

Transfer exactly `n` held DETF to the validated recipient; check backing; apply ordinary weight top-up. Because `floor((T-n*k)/k)=floor(T/k)-n`, neither native dust counter changes.

**Never use the common full-account branch that burns all `G[caller]`.** Even an active full displayed-balance withdrawal leaves the caller's sub-native gons intact. During Stage 1, exiting all principal leaves every reward gon in `R[0,caller]`. `exchangeIn` and direct `exchangeOut` execute the same arithmetic; exact output cannot exceed the principal cap or bypass it by using a larger maximum.

### 4.5 Views

Keep `balanceOf(a)=floor(G[a]/k)` and `gonsOf(a)` truthful about physical receipts. Before checkpoint, a displayed balance can include non-executable Stage-1 growth; after checkpoint it is in deferred custody. Add `egressState(a)` as specified in section 7. Clients must not treat `balanceOf` or price-only SE previews as a Stage-1 spending approval.

Existing direct SE previews remain 1:1 price quotes, not account-sensitive authorization. `egressState.maxUnstake` supplies the actual funded principal cap; read it at the same settled index for execution comparison. Projected parent expansion is not already owned funding.

### 4.6 Deferred rights, release and assignment

Only after finalized activation:

```text
n = floor(R[d,a]/k)
q = n*k
R[d,a] -= q; totalDeferredGons -= q
G[receiptProxy] -= q
G[a] += q; P[a] += n
```

The claim pays the recorded beneficiary, not an arbitrary recipient supplied by a third party. No backing movement, `T` increase or second mint occurs. Repeated release at unchanged `k` pays zero. The remaining `R<k` can grow into a native unit under future real funding, or combine with other rights of that owner.

`transferDeferredRewardRights(domain,to,gons)` allows the actual owner to assign **already detached** wallet/domain-0 or SY/domain-2 rights in exact gons:

```text
require domain in {0,2}, ordinary(to), gons <= R[domain,msg.sender]
R[domain,msg.sender] -= gons
R[domain,to] += gons
```

It is available before and after activation. Here `ordinary(to)` means a nonzero address other than the receipt escrow, bond custodian or staking-SY custodian; it does not mean EOA-only. Physical gons stay at the receipt proxy; `T`, backing and liquid basis do not change. No allowance or administrator can invoke it for another owner. Role domain 1 is not assignable through this API: preserve the fixed allocation beneficiary required by the handoff. Identical role beneficiaries already merge automatically. This explicit assignment also makes exact fractional-right consolidation possible without converting a fraction to liquid principal. Public checkpoints, assignments and releases all synchronize before their local lock. Role aliases use internal dispatch, not a self-call that changes the beneficiary's caller identity.

## 5. Bonds, roles and activation

### 5.1 Creation and cliff

The parent settles old participation before minting new principal. The existing exact pull/stake/gon-delta pipeline creates `Gi=principal*k`, `claimedPrincipal=0`, actual start `now`, and internal duration `90 days`. Only genuine Migration/compensation creation marks the cliff; Stage-2 ordinary purchases remain unmarked and linear.

For a marked bond:

```text
principalDue = now < start+90 days ? 0 : Pi
require floor(Gi/k) >= Pi
rewardDue = floor(Gi/k)-Pi
```

Use the same calculation for preview and execution. Stage-1 rewards-only and combined requests revert as whole transactions, even if their principal component is mature. Principal-only succeeds at the cliff. Approved operators keep existing authority; no caller supplies a historical start or a made-up principal basis.

### 5.2 Delivery and original versus post-claim reward

Update the position and aggregate attributed gons first, then use the bond-only receipt API:

```text
require active || rewardPaid=0
q = (principalPaid+rewardPaid)*k
Gi -= q
claimedPrincipal += principalPaid
bond.attributedGons -= q
G[bond] -= q
G[recipient] += q
P[recipient] += principalPaid+rewardPaid
```

Checkpoint a normal recipient's old Stage-1 receipt holding before adding the new principal. Preserve existing zero-recipient-to-owner resolution and forbidden parent/bond recipients; additionally reject direct payment to the receipt escrow or staking-SY custodian, which require their own accounting entry. A holder can still claim to itself and then wrap through the supported deposit.

The remaining `Gi` stays with the NFT. The recipient's newly delivered `principalPaid*k` is a different funded position. Subsequent growth on it is `G[recipient]-P[recipient]*k`, not a second claim on `Gi`.

When `Pi=0` and `Gi<k`, save the exact remaining `Gi` and current NFT owner, subtract the fraction from bond attribution, delete the position, then move **all saved gons** to `R[0,savedOwner]` through `deferCustodyRewards` and burn the NFT. Thus the receipt's post-debit attribution check observes the already-decreased bond obligation. The claim recipient does not silently acquire the owner's fractional residue. It remains under receipt custody, including before activation. For `Gi>=k`, the reward-only NFT remains alive. Migration's old `retireEscrowDust(nonzero)` selector rejects; no migration path invokes common fraction destruction. Ordinary products keep their existing retirement behavior.

NFT transfers convey the remaining principal clock and all `Gi`, without payout. Reserved-role transfers change future allocation recipients only. Retained role gons continue to belong to captured beneficiaries; activation does not scan or recalculate them.

### 5.3 Activation

Read the sole permanent parent `migrationActivated()` view. No child flag or child gate setter. Under the parent lock, with all child money-path phases idle, perform the complete local selector removal and finalized flag transition required by handoff section 2.4/Plan section 6.1. No external call occurs between removal and finalization. Any failure reverts both.

Activation moves **zero** gons and backing and resets **no** index, slot, principal clock or reward basis. Previously detached and attached rewards become payable through their existing claim paths. Full original-plan selector/callback closure remains a production proof obligation, not an arithmetic result.

## 6. Exact wrapper operations

### 6.1 Local checkpoint and proportional split

For either kind of staking-SY slot `h`, normalize before any balance change:

```text
if s[h]=0 and lastK[h]=0: lastK[h]=k
require lastK[h] >= k
r[h] += s[h]*(lastK[h]-k)
lastK[h] = k
```

This is an exact decomposition of the same physical gon entitlement:

```text
s*oldK + oldR = s*k + (oldR+s*(oldK-k))
```

There is no token transfer and no change to `A`. Attached rewards themselves continue growing in native value because `r/k` uses the actual current index. After principal leaves, only retained reward gons participate; no withdrawn principal remains in `T`.

For `x` shares of a checkpointed nonempty slot:

```text
require 0 <= x <= s
rewardSlice = 0                       if x=0
rewardSlice = r                       if x=s
rewardSlice = floor(r*x/s)            otherwise
principalGons = x*k
packetGons = principalGons+rewardSlice
```

Subtract the slice, rather than recomputing a remainder. Full consumption gets every remaining gon. Partial rounding residue stays in the source slot, never a protocol dust bucket. No multiplication of two native principal quantities or fixed-gon-share division is involved.

### 6.2 Deposit and mixed holdings

Synchronize first. Validate receiver, input route, positive input, zero `msg.value` and minimum shares. Acquire actual permitted principal:

- Raw DETF input: measure the exact received DETF; stake it through the real receipt path.
- sDETF input: the wrapper itself pulls through `transferFrom`; Stage 1 transfers only liquid principal and leaves the sender's prior wallet growth in `R[0,sender]`. The measured gon delta must equal `n*k`.
- Configured external input: use the existing parent exchange route and exact approvals/receipts. Stage 1 ordinary external new-money acquisition is rejected before primary/swap selection. Active issuance rewards settle before the newly acquired principal is staked.

Pin the final `k` **after** acquisition, since active parent issuance can fund an immediate distribution. Checkpoint the receiver's existing slot at that final `k`, then:

```text
sharesMinted = n                       // native principal, not floor(n*k/Q)
s[receiver] += n
lastK[receiver] = k
A += n*k
```

Require actual acquired gons exactly `n*k`, excluding old backing, surplus and any prior receipt rebase. If `receiver=wrapper`, mint into the caller's internal beneficial-owner slot, add `n` to ticket `(caller,caller)`, and increase the canonical wrapper ERC20 balance/total internal shares. Otherwise mint into its external slot. New principal receives no earlier reward. Mixed earlier/current deposits merge shares and attached gons by addition after checkpoint; they are never re-quoted. A router wishing to create internal custody for a different owner must use a deposit to that owner's external balance followed by an authorized pull, not pretend that its own direct funding identifies an unseen earlier payer.

Raw SY deposit remains measured raw DETF -> equal shares and `rawBacking += n`. A configured sDETF input to raw SY goes through the principal-aware parent unstake route. It cannot smuggle growth in as raw DETF.

### 6.3 Share transfer / transferFrom / internal custody

Checkpoint source and destination slots once. Compute the proportional packet from section 6.1. Move `x` shares and `rewardSlice` attached gons between those slots. Both checkpoint indices equal current `k`. `A`, `G[stakingSY]`, `T`, backing and liquid receipt basis are unchanged.

Thus a share transfer conveys principal **and its proportionate attached reward right**, not reward receipts. A recipient may be an existing mixed holder or a router. No gate exemption follows from its address.

For a transfer to the wrapper's own address, destination is `Internal(from)` and the spending ticket is `(actual msg.sender,from)`. The original share owner keeps reward ownership while an approved router receives authority to redeem this principal. Do not infer reward ownership from the aggregate wrapper balance, principal payout receiver or router address:

```text
transfer/transferFrom to wrapper:
  External(from) -> Internal(from), with its proportional attached rewards
  ERC20.balanceOf(wrapper) += x
  internalBalances[from].shares += x
  internalSpendShares[msg.sender][from] += x
  totalInternalShares += x

redeem(...,burnInternalBalance=true):
  use owner=msg.sender and operator=msg.sender
  require x <= internalSpendShares[msg.sender][msg.sender]

redeemInternal(owner,receiver,x,tokenOut,minimum):
  operator=msg.sender
  require x <= internalSpendShares[operator][owner]

either internal redemption:
  checkpoint Internal(owner)
  take the section-6.1 packet from that owner's aggregate internal slot
  internalSpendShares[operator][owner] -= x
  internalBalances[owner].shares -= x
  totalInternalShares -= x
  burn x of ERC20.balanceOf(wrapper)
  detach rewardSlice to R[2,owner], never to operator or receiver
```

Another caller cannot spend the aggregate self-balance. A router holding tickets for Alice and Bob cannot substitute Bob's balance for a shortage in Alice's ticket. Multiple operators' principal tickets for Alice share Alice's one reward pool; since all those rewards have the same beneficiary, proportional pooling changes neither ownership nor solvency. Reject generic `transferFrom(wrapper,...)`; it cannot identify a ticket owner. A zero transfer creates no ticket. Direct user transfers, approved-router transfers, and deposits with `receiver=wrapper` are authenticated ways to create internal credit. Raw SY uses the same convention without attached reward arithmetic.

`redeemInternal` is the required minimal ABI extension for approved-router custody. The old five-argument `redeem` has no source-owner argument and cannot recover it from `msg.sender` or an arbitrary `receiver`. Keep that selector valid for external and caller-owned internal balances; require a router redeeming another owner's ticket to use the new selector. An unmodified router's atomic pull + old internal redeem reverts the entire operation rather than paying principal and stranding the user's reward at the router. Integrate this selector in each actual production router caller before claiming that caller supported; no installed/current router acceptance is claimed here.

This is an explicit tightening of the ordinary wrapper's bearer-like self-balance burn, not acceptance of arbitrary pretransferred underlying inventory. The existing native share allowance authenticates creation of a router ticket; redemption consumes that exact ticket and needs no second allowance. The beneficial owner can claim its accrued internal rewards through `claimRewards(owner)` even while a router controls an outstanding principal ticket.

### 6.4 Principal redemption, every output

Use source slot `External(msg.sender)` or `Internal(msg.sender)` for the existing redeem selector, and `Internal(owner)` for the ticket-authenticated `redeemInternal`. Checkpoint, compute the exact packet, and burn `x` shares. Remove `rewardSlice` from that slot and move it physically from `G[stakingSY]` to `G[receiptProxy]`, crediting `R[2,sourceSlotOwner]`. The internal beneficial owner is authenticated by the ticket created from the original share transfer, not inferred from the payout recipient. This step is not a reward payout and works in both stages.

```text
s[source] -= x
r[source] -= rewardSlice
A -= x*k+rewardSlice
G[stakingSY] -= rewardSlice
G[receiptProxy] += rewardSlice
R[2,sourceOwner] += rewardSlice
totalDeferredGons += rewardSlice
```

Then consume exactly `x*k` principal gons, through one of the following branches:

| Configured output | Actual custody and equation |
| --- | --- |
| sDETF | `transferSyPrincipal` moves `x*k` gons from SY to receiver and adds `x` liquid basis. No DETF transfer or aggregate gon change. Stage-1 recipient can unstake exactly `x`; later growth on these receipts is gated again. |
| Raw DETF | SY calls receipt SE withdrawal as its authenticated custodian for exactly `x`; receipt burns exactly `x*k`, decreases `T`/`B` by that gon/native amount and pays `x` DETF. No residual fraction is retired. |
| Every other `tokensOut` member | Withdraw exactly `x` DETF into SY, approve exactly that operation budget to parent, execute existing parent DETF-to-output exchange, clear approval, enforce actual returned/measured output and user minimum. Price branch, fees, decimals and route liquidity remain the actual parent route's behavior. The budget cannot include `rewardSlice`, old raw inventory or detached rights. |

Reject unsupported routes. A failing output/minimum reverts share burn, detachment, receipt debit, approvals and token transfers together. There is no silent `min(principal,requested)` substitution.

On complete principal exit (`x=s`), every attached gon goes to the source owner's detached reward account; the zero-share slot has zero attached reward. Future deposits to that slot do not reattach or transfer those old detached rights. On partial exit, only the proportionate reward slice detaches; the remaining shares retain the exact remaining reward gons.

Raw SY redemption burns `x`, reduces `rawBacking` by `x`, and routes only `x` raw DETF. If a configured output is sDETF, the parent direct staking branch creates exactly that principal receipt; if it is another asset, retain the actual parent exchange. Raw SY has no separate funded index or reward payout to gate.

### 6.5 SY claims, rates, previews and dust

For staking SY:

- `exchangeRate() = 1e18`; `assetInfo()` remains native nine-decimal DETF; `yieldToken()` remains the wired sDETF.
- `previewDeposit` returns the measured-principal-equivalent quote `n` for supported inputs, not `floor(n*k/Q)`. Stage-1 external new-money inputs return zero as unavailable; their execution reverts at the parent acquisition gate. Direct DETF/sDETF quotes remain available. Like receipt SE previews, an sDETF quote is a conversion quote, not an account's principal spending authorization.
- `previewRedeem(output,x)` quotes the same principal-only budget `x`. For sDETF and DETF it is `x`; other outputs use the canonical parent quote. It never adds reward value to the principal quote.
- `getRewardTokens() = [sDETF]`. Define `latent(h)=0` when `s[h]=0`, otherwise `s[h]*(lastK[h]-k)`; test the zero-share case before subtraction, so an untouched slot's zero index cannot underflow. `accruedRewards(user)` returns one native value, `floor((rE+latent(E)+rI+latent(I)+R[2,user])/k)`, including the user's external and internal slots and detached SY residue. These are accrued, not executable before activation.
- `claimRewards(user)` is synchronized and guarded. It rejects before activation, even if the amount is zero. After activation, checkpoint both slots, detach all their attached gons to `R[2,user]`, then call the receipt's SY-only fixed-beneficiary release. Return `[paidNative]` and emit the standard event. Any caller may trigger it, but only `user` receives the receipts. This actually transfers already funded gons; it is not a fake empty reward claim.
- `rewardIndexesStored() = [Q-k]`, in **gons per native principal share**, not an assumed WAD native-reward index. `rewardIndexesCurrent()` synchronizes then returns that same exact funded index. The complementary stored `lastK` makes its delta exactly `oldK-k`; the receipt `k` converts accrued gon rights to native reward amounts. Consumers must use this declared unit and `accruedRewards`, not infer ordinary appreciated-SY arithmetic.

Raw SY keeps its empty reward arrays/API. No new reward index applies to it.

No staking-SY `Q`-division conversion dust exists in this new representation. The Migration path must not execute ordinary SY's post-withdrawal dust clamp or common full-account retirement. Fractional reward gons live in `r` or `R`, continue participating, and remain owned after the last share burns. The global `Da`/`Ds` classes still exist and retain their ordinary funding treatment.

## 7. Minimal ABI and implementation contract

These are proposed production interfaces, not installed selectors. Exact Solidity argument types below define the ABI; selector hashes must later be derived from compiled interfaces, not copied from this report.

### Receipt additions

```solidity
struct EgressState {
    uint256 physicalGons;
    uint256 liquidBasis;
    uint256 latentRewardGons;
    uint256 walletDeferredGons;
    uint256 roleDeferredGons;
    uint256 syDeferredGons;
    uint256 maxUnstake;
}
function egressState(address account) external view returns (EgressState memory);
function checkpointRewards() external returns (uint256 movedGons);
function deferredRewardGons(uint8 domain, address beneficiary) external view returns (uint256);
function claimDeferredRewards(uint8 domain) external returns (uint256 paid);
function deferredRoleGons(address beneficiary) external view returns (uint256);
function claimDeferredRoleRewards() external returns (uint256 paid);
function transferDeferredRewardRights(uint8 domain, address to, uint256 gons) external;
function deliverBondClaim(address recipient, uint256 principal, uint256 reward, uint256 expectedK) external;
function deferCustodyRewards(address beneficiary, uint256 gons, uint256 expectedK) external;
function transferSyPrincipal(address recipient, uint256 principal, uint256 expectedK) external;
function releaseSyRewards(address beneficiary, uint256 expectedK) external returns (uint256 paid);
```

Authority:

- Public claims use `msg.sender` as beneficiary. Domains are exactly 0/1/2; role aliases call the same domain-1 implementation. All payout paths require activation. A wallet release requires an ordinary beneficiary as defined in section 4.6; it cannot relabel protected custody as liquid basis. A role allocation voluntarily owned by a protected custodian stays separately attributed and is not a public spend source.
- `deliverBondClaim` is wired-bond-only and cannot be used as arbitrary credit: it debits actual bond custody by the exact sum paid, with the bond's position debit/check in the same transaction.
- `deferCustodyRewards` is wired bond or staking-SY only; its domain is derived from actual caller (0 or 2), never supplied. Move that caller's real gons into self custody; check `expectedK==k`. The caller has already debited its exact attributed inventory.
- `transferSyPrincipal` and `releaseSyRewards` are wired-staking-SY-only. Principal transfer debits real SY gons; release uses only domain 2 and fixed beneficiary. Neither has a general `from` argument.
- Custody APIs do not resynchronize after the caller has pinned `expectedK`; they take the receipt local lock, validate the current index, caller and remaining custody coverage. Public receipt entries retain synchronize-before-lock.
- The existing receipt SE withdrawal remains the raw principal output for SY. Only the wired SY can use the special-custodian branch; receiver is that SY for onward routing, or the validated final receiver for direct DETF. It burns exact gons and verifies remaining SY custody covers its already-updated `backingGons`. Generic bond outgoing transfers/withdrawals remain forbidden.

`egressState` for ordinary accounts returns `latentRewardGons=G-P*k` and `maxUnstake=active ? floor(G/k) : P`. For protected custodians return no public withdrawal authority (`liquidBasis/maxUnstake=0`); their attributed inventories are not user spendable. Report physical gons and separately attributed deferred balances without counting self custody as its own wallet reward.

### SY / cross-contract additions

```solidity
function internalSharesOf(address account) external view returns (uint256);
function internalSpendSharesOf(address operator, address owner) external view returns (uint256);
function redeemInternal(address owner, address receiver, uint256 shares, address tokenOut, uint256 minimum)
    external returns (uint256 amountOut);
function attributedSyGons() external view returns (uint256);
function attributedBondGons() external view returns (uint256);
function migrationAccountingPhase() external view returns (uint8);
```

Install `internalSharesOf` (the beneficial owner's aggregate), `internalSpendSharesOf`, `redeemInternal` and `attributedSyGons` on both SYs; the last returns common `backingGons` on staking SY and zero on raw SY. Install `attributedBondGons` on the bond, returning common aggregate attribution. Install the phase view on receipt, bond, and both SYs. The parent already owns its lock and retains `migrationActivated()`. Phase values are fixed: `0=Idle`, `1=Synchronizing`, `2=Acquiring`, `3=Accounting`, `4=Paying`. Do not export a setter.

Existing SY selectors remain, with the explicit new semantics in section 6. `redeemInternal` supplies the missing authenticated source owner for router egress; it is not an arbitrary beneficiary-bearing principal-credit API. Permit/domain signatures stay unchanged.

Caller-search boundary: a bounded content search of 63 `contracts/**/*Router*.sol` files found no `IStandardizedYield`, `burnInternalBalance` or redeem-call match. The DETF subtree search found the SY declaration and an older Balancer receipt declaration, not an internal-SY router caller. The actual parent consumer inspected at P1 uses receipt Standard Exchange calls, so it does not need this SY selector. This is not an exhaustive claim about external routers or vendored integrations: their exact required adapter contract is the ticket-creating pull followed by `redeemInternal(originalShareOwner,receiver,shares,tokenOut,minimum)`, and compatibility must be exercised rather than assumed.

Events must carry exact gons for checkpoint/defer/assignment/release, with domain, beneficiary, source custodian and current `k`; SY events additionally identify slot kind/owner, principal shares and moved reward gons. Native `Transfer`, `Staked`, `Unstaked`, `Deposit`, `Redeem`, `RewardsFunded` and bond claim events remain. A sub-native gon movement cannot be reconstructed from native `Transfer` alone: the new exact-gon event is authoritative for that attribution. Errors must distinguish locked reward spend, wrong custodian, stale index, invalid domain, insufficient internal shares, forbidden dust retirement and custody deficit.

### Proposed production paths and exact seams

All paths below are under `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/` unless prefixed `C/` or `D/`. They are future implementation paths, not this lane's edit authority.

| Paths | Exact change |
| --- | --- |
| `claimToken/IUniswapV4DetfMigrationStakedDETF.sol`, `UniswapV4DetfMigrationStakedDETF{Repo,Target,Facet}.sol` | Namespaced basis/deferred storage, stage-aware receipt transfer/exit/checkpoint, real funding destination policy, exact custody APIs, queries and phase view. |
| `C/claimToken/StakedDETFTarget.sol` | Reuse preparation's implemented distribution seam. Add only virtual/internal dispatch for transfer, withdrawal, principal credit and dust retirement needed by the Migration target; ordinary dispatch remains existing behavior. No global common Repo math change. |
| `bondNft/IUniswapV4DetfMigrationBondNFTVault.sol`, `bondNft/UniswapV4DetfMigrationBondNFTRepo.sol`, `bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol`, `bondNft/UniswapV4DetfMigrationBondNFTVaultFacet.sol`, `bondNft/UniswapV4DetfMigrationBondNFTVaultDFPkg.sol` | Fresh cliff flag/create, shared claim calculation, gated claims, exact `deliverBondClaim`, gon-preserving final residue, guarded transfers, aggregate attribution and phase views. |
| `C/bondNft/DETFFundedBondTarget.sol` | Consume preparation's creation/calculation/claim seams; make final delivery/retirement narrowly overridable if the claim override cannot reuse them. Never let inherited native transfer or fraction retirement remain an alternate Migration route. |
| `sy/IUniswapV4DetfMigrationSY.sol`, `UniswapV4DetfMigrationSY{Repo,Target,Facet}.sol` | Principal shares, external/internal slots, attached-gon transfer, detached exit rights, actual reward API, principal previews, authenticated internal burns, phase view. |
| `C/sy/DETFSYTarget.sol` | Narrow implementation dispatch for receipt acquisition, share mutation/redemption and reward queries; or factor their reusable route/pull/payment helpers as implemented internal methods. Do not install ordinary concrete transfer/redeem selectors on Migration. Keep ordinary fixed-gon behavior unchanged. |
| `C/claimToken/RebasingClaimTokenDFPkg.sol`, `C/sy/DETFSYDFPkg.sol`, `C/bondNft/DETFNFTVaultDFPkg.sol` | Declaration extensibility for actual selected Migration interfaces; preserve package deployment identity/wiring conventions. Initialize the new namespaces only on fresh Migration instances. |
| `UniswapV4DetfMigration{Policy,ExchangeFacet,BondFacet,MaintenanceFacet,QueryFacet,DFPkg}.sol` and interfaces/factories from handoff | Install actual children and their policy-bearing selectors, keep closed-stage ordinary acquisition gate, parent-before-principal settlement and empty baseline, validate child phases at cross-contract mutation boundaries. Parent routing must use the actual Migration receipt, not an ordinary fallback. |
| Migration bond metadata Target/Facet and narrow common renderer seam | Cliff availability, locked/claimable rewards, retained residue and phase-correct views; ordinary metadata stays ordinary. |

The new SY share model and internal-burn ownership rule are required implementation differences, not unrecorded cleanup. All child packages/facets use the existing registry/CREATE3/factory conventions. No production code, tests or package definitions are written by this report.

## 8. Complete operation matrix

Every row applies to direct proxy calls and inherited selector routes, not only a parent facade. `Sync` means the ordering in section 9. Grouped selectors share one accounting operation.

| Surface | Stage 1 | Activated / exact accounting |
| --- | --- | --- |
| Parent direct DETF -> receipt stake, exact in/out where supported | Allowed actual funded principal; Sync before new participation. | Same funding; receipt section 4.2. |
| Parent receipt -> DETF or configured routed output | Pull only permitted principal through receipt transfer; consume exact new packet. | Native receipt value spend permitted. Old parent inventory never subsidizes this packet. |
| Parent ordinary external input -> DETF/sDETF, including swap fallback | Reject before branch selection. | Existing issuance/swap formulas; acquire/measure before wrapper or receipt new-principal credit. |
| Parent ordinary bond/reserve-LP purchase | Closed ordinary new money. | Existing unmarked linear position; Migration reward-aware child accounting still used. |
| Genuine parent migration/compensation creation | Exact-funded fresh cliff; no arbitrary child caller. | Surrender's fresh cliff remains; discretionary compensation surface removed. |
| Parent donation/bootstrap/harvest and sweeps | No personal basis from gifts, self supply or recovery inventory. No deferred gons swept. BOOTSTRAP-AUTH remains unresolved. | Budgeted allowed inventory only; new-instance receipt/bond/SY backing is protected. Legacy E1/E2 accounting is separate. |
| Receipt `exchangeIn` / `exchangeOut`, DETF in | Exact pull; valid route, min/max/deadline/pretransfer checks; new `n*k` only. | Same; no idle-balance credit. |
| Receipt same selectors, receipt in | Checkpoint and require principal cap; partial/full exact `n*k` burn. | Full physical native value permitted; retain fractional gons. |
| Receipt `transfer` / `transferFrom` | Principal-only native packet; old growth stays sender's deferred right. Allowance does not override gate. | Exact native transfer; basis updates section 4.3. |
| Receipt approve/permit/nonces/domain | Allowance/domain only, not payout. | Same; preserve actual decrement/replay semantics. |
| Receipt parent-only `fundRewards` | Real funding, unchanged index math, captured role escrow. No suppression. | Ordinary recipients paid; old pending preserved. Protected-custodian role gifts remain separately attributed. |
| Receipt dust retirement | Nonzero legacy retirement rejected; exact bond residue is deferred instead. | Same gon-preserving Migration rule. |
| Receipt `claimDeferredRewards` / role alias | Reject before payout. | Exact fixed-beneficiary transfer, preserve modulus, repeat zero. |
| Receipt detached-right transfer | Domains 0/2, actual owner, exact gons, custody unchanged. | Same; role domain prohibited. |
| Receipt explicit wallet checkpoint | Caller only; move exact latent gons to its deferred right without payout. | Same; permits exact fractional consolidation after an active full withdrawal. |
| Receipt bond/SY custody methods | Only fixed caller; no independent principal creation; expected-index check. Reward release still gated. | Same authority, funded reward delivery allowed. |
| Receipt metadata/balances/state/distribution and SE previews | Read actual custody/accrual; max spend explicitly distinct. | Same factual reads; no view changes ownership. |
| Bond principal-only claim | Zero before cliff, all remaining at/after; exact receipt delivery. | Same clock; linear math only for unmarked ordinary positions. |
| Bond rewards-only / combined | Whole operation rejects. | Funded available reward; exact combined gon debit once. |
| Bond all three NFT transfers | Convey remaining `Gi`, principal obligation and clock; no payout; callback protected. | Same; role transfer changes later allocations only. |
| Bond initialization/parent-only held-token transfer | Once-only roles; backing DETF and sDETF cannot be swept. | Same; no restoration or alternate issue path. |
| Bond donation overloads/Permit2 variants | Existing live/route authority, no principal creation; not empty-bootstrap authority. | Same; exact receipts/budgets, no receipt escrow spend. |
| Bond owner/approval/position/preview/metadata queries | Truthful cliff and locked-reward availability. | Existing authority and phase-correct availability. |
| Raw SY deposit, direct DETF | Equal raw backing/shares. | Same. |
| Raw SY configured receipt input | Principal-aware parent unstake only. | Native active receipt value may convert; actual receipt measurement. |
| Raw SY external new-money input | Parent ordinary acquisition closed. | Existing supported route and measured raw DETF. |
| Raw SY transfer/transferFrom | Ordinary static units; authenticated internal-slot attribution when destination is wrapper. | Same; no independent yield ledger. |
| Raw SY redeem, either internal flag, every output | Caller-owned shares only; `x` raw DETF budget, supported direct/stake/routed output. | Same min-output and budget limits. |
| Both SYs `redeemInternal` | Require the caller's exact `(operator,owner)` ticket; consume owner's internal packet; all detached rewards remain owner's. | Same principal-only output and source attribution; no aggregate-balance authorization. |
| Staking SY deposit, direct DETF/sDETF | Exact permitted principal; mint `n` shares; source wallet growth not relabeled. | Any legitimately unlocked acquisition can establish new basis; old receiver rewards preserved. |
| Staking SY external input | Parent gate rejects before ordinary acquire. | Complete acquire/reward settlement, then measure `n*k` and mint `n`. |
| Staking SY transfer/transferFrom | Checkpoint; proportionate attached reward rights travel under SY custody; no payout. | Same economics; approvals only authorize the transferred packet. |
| Staking SY redeem external balance | Burn exact requested principal shares; source owns detached reward slice; every output uses only principal. | Same principal-only redeem; use reward API for rewards. |
| Staking SY redeem internal balance | Existing `true` flag consumes `(caller,caller)` ticket. Approved routers use `redeemInternal`; source owner owns detached slice even if operator/receiver differ. | Same; aggregate wrapper balance is not authorization. |
| Staking SY `claimRewards(user)` | Reject; accrued view still reports real funding. | Detach/checkpoint user's two slots and release to user; cannot redirect. |
| Staking SY reward indexes/current/stored | Stored uses funded `k`; current Sync can fund but cannot pay. | Same exact gon unit; no extra reward mint. |
| Both SY rates/yield/asset/routes/previews/metadata | Principal rate and explicit reward description; configured route validation. | Same. Staking differs intentionally from ordinary appreciated-gon SY. |
| Both SY approve/permit/nonces/domain | No custody or reward change. | Same native share allowance and replay semantics. |
| Parent/children sync callbacks | Accrue genuine funding; no payout exemption; wired bond/receipt locked-parent no-op only. | Same ordering; preserve empty/standing-only behavior. |
| Activation / owner transfer / factory/init/cut callbacks | Only existing owner law; no callback can open gate mid-operation or reinstall authority. | Removed administration cannot be restored. No child setter or copied lifecycle flag. |

## 9. Validation, synchronization and locks

### 9.1 Boundary checks

Validate nonzero normal recipients, exact fixed custodian/parent identities, canonical domain, valid slot ownership, sufficient principal/shares/gons, uint256 result bounds, token direction, deadline, slippage and exact transaction-local receipts. Reconcile after every completed cross-contract transition. Reject stale `expectedK` rather than silently resizing a packet. Parent registry checks remain route-specific; do not introduce a universal disabled-state exit pause.

For wrapping, a previously held gon balance or native `balanceOf` delta through a rebase is not a new deposit: pin the final index and check actual credited gons. For routed redemption, cap approvals and spending by the exact unstaked principal budget; clear temporary approvals. Preserve `pretransferred=true` rejection at receipt/parent paths. SY internal share tickets authorize only already issued SY shares, never idle underlying tokens.

Cross-contract residue moves preserve custody exactly:

```text
before: caller attributed gons X, receipt G[caller] >= X
caller effects: X -= moved
receipt: G[caller] -= moved; G[self] += moved; R += moved
after: G[caller] >= new X and self escrow reconciliation holds
```

The receipt verifies the wired caller, pinned index, sufficient physical gons and remaining caller attribution. For bond calls read `attributedBondGons()` after the caller's effects; for staking-SY calls read `attributedSyGons()`. Require the caller's post-move physical gons to cover that exact returned value. Do not accept a user-supplied assertion of attribution. These queries are authoritative views, not mutation privileges.

### 9.2 Fixed call graph

Local locks alone do not prevent owner activation inside another child's callback. The added read-only child phase views let parent lifecycle/administrative/issuance/surrender entrypoints reject a non-idle child. Set `Synchronizing` before the external synchronization call and clear it only on completion/revert. Account for receipt's existing synchronization recursion flag as well.

Receipt funding is the one deliberate nested-phase exception: the wired parent can call `fundRewards` while the receipt's outer entry is in `Synchronizing`, before that outer entry takes the local lock. Save the prior phase, set Accounting while the funding lock is held, and restore **that prior phase**, not blindly Idle, on return. Parent-only funding otherwise enters from Idle; reject entry from the receipt's Acquiring/Accounting/Paying phase. Other child money operations enter only from Idle, except the fixed caller's own internal phase changes in the table. Read/approval/permit functions do not reset a busy phase.

| Outer operation | Allowed nesting and lock order |
| --- | --- |
| Parent issuance/stake/unstake | Parent enters its lock and settles first. Receipt/bond synchronization is the existing fixed-child no-op. Then child local lock and exact accounting. Parent never assumes a child no-op settled old holders. |
| Wallet receipt entry | Receipt announces Sync phase before parent call; parent settles under parent lock and may fund receipt. Receipt funding takes receipt local lock, returns; outer receipt then takes local lock for Accounting/Paying. Reentry into the synchronizing outer receipt is rejected. |
| Bond claim/transfer | Bond Sync -> parent settlement -> bond local Accounting lock. Typed receipt custody APIs then take receipt lock without resynchronization and require expected `k`. Safe NFT receiver callback remains inside the bond lock, before ownership mutation. |
| SY deposit | SY Sync -> parent settlement -> SY Acquiring lock/phase. Allowed parent acquisition may fund receipt normally. Finish acquisition, read final `k`, move to Accounting, update slots/mint/check backing. No callback from another address may act as SY. |
| SY redemption | SY Sync -> parent settlement -> SY Accounting lock, checkpoint/burn/detach -> typed receipt custody mutation -> SY Paying phase. Onward parent exchange takes parent lock. Wrapper itself is never added to the parent-locked synchronization exemption. |
| SY reward claim | SY Sync -> parent settlement -> SY Accounting lock -> typed receipt detach/release at pinned `k`. Fixed beneficiary, no external route execution. |
| Bond donation | Preserve existing bond-first lock -> authenticated parent join/notify cycle. Parent forwarding itself must not pre-lock and deadlock this allowed callback. |
| Activation/configuration/surrender/independent issuance | Require current authority and all fixed child phases Idle before taking parent mutation path. Parent lock plus exact selector removal prevents half-activation. No child callback exception for these operations. |

The parent recognizes only these exact legitimate busy-child calls: synchronization from its wired receipt/bond (and unlocked wrapper's own initial synchronization), acquisition/payment exchange from the same wired SY in its corresponding phase, and existing typed bond donation callbacks. It does not accept a caller-selected child, phase, target or selector. A token callback cannot invoke parent exchange on the strength of another contract's Acquiring phase. Unauthorized caller or incompatible phase rejects.

This parent admission rule applies to its lifecycle and economic entrypoints, not to the normal ERC20 balance/allowance operations used to pull and return backing. Those retain their actual token authorization; otherwise receipt funding/unstaking would deadlock on the backing token's own parent address.

An independent wallet operation nested through a permitted receipt call cannot spend bond/SY/self custody or open activation; it is still subject to its own receipt lock, allowance and principal cap. At each point where an index-sensitive packet is transferred, `expectedK` or measured `n*k` equality closes stale-index accounting. External output conversion happens after the source packet's complete accounting effects, and any failure reverts the whole transaction.

Production tests must exercise the actual safe-NFT callback order, token callbacks, owner-as-receiver, role transfer at a due boundary, direct child calls during parent locks and parent calls during child locks. Source inspection and the integer model do not prove these locks are installed correctly.

## 10. Proof obligations and checked witnesses

### 10.1 Algebra

1. **Funding solvency.** Section 3's floor allocation partitions `f+Da`; rebase distributes no more than `aS+Ds`; role issue adds exactly the allocated native liability. Thus `B=floor(T/k)+Da+Ds` is preserved. Physical DETF pull backs `B` before credit.
2. **Exact principal exit.** Every permitted principal packet is exactly `n*k`, with integer `n`. Subtracting it changes aggregate native liability by exactly `n`, independent of every other holder's fraction. This proves full and partial principal exits without consuming another holder's dust.
3. **No principal inflation.** During Stage 1, only actual deposited DETF and validated matured bond principal originate liquid basis. Receipt transfer and wrapper wrap/unwrap move that same basis; SY transfers preserve total principal shares. Custody/defer/assignment/distribution never add basis. Therefore no transfer/router/split/merge turns gated growth into withdrawable principal.
4. **Post-claim growth.** Delivery `p*kc` followed by actual `k<kc` leaves `p*(kc-k)` reward gons when `p` exits. Original bond residual `Gi` was debited at delivery and is a separate term. Both continue participating, neither duplicates the other.
5. **SY exact decomposition.** Checkpoint preserves `s*lastK+r`. Transfer moves integer `x*k` plus a floor-allocated `r` slice; remainder uses subtraction. Deposit adds only actual `n*k`. Redemption subtracts the entire packet from `A`, moving reward gons to the source owner and burning/transferring only principal gons. No fixed-share rounding creates an underbacked native principal.
6. **Mixed holders and transfer rounding.** Add checkpointed principal shares and attached gons independently. Splitting can change which holder retains sub-gon division residue, but cannot increase total gons or principal. A whole final transfer takes all residue. Native floors are applied only on reward payout, never to erase the underlying right.
7. **Ownership after exit.** Wallet growth is `R[0,exitingWallet]`; bond final fraction belongs to current NFT owner; wrapper reward slice is `R[2,sourceSlotOwner]`, including operator-controlled tickets against that owner's internal pool; captured roles remain `R[1,capturedBeneficiary]`. Principal recipient, router, current fee owner and administrator cannot silently replace those owners.
8. **Exactly-once release.** Debit precisely `floor(R/k)*k` before transferring receipts. At fixed `k`, the residue is below one unit and repeat pays zero. A future payment can occur only because actual funding changes `k` or an authenticated owner assigns additional gons. No iteration over holders on activation.
9. **No participation after principal departure.** Principal withdrawal destroys exactly its current gons. Only the still-issued bond, wallet, SY and deferred reward gons remain in `T`; neither a historical principal number nor a burned share receives subsequent distribution.
10. **No dust confiscation.** Sub-native beneficiary gons are never retired by Migration full-exit paths. Canonical native dust remains distinct, accounted and fundable under the ordinary allocation rules; it is not asserted to be immediately payable to a particular beneficiary.

### 10.2 Actual integer results

Executed dependency-free `evidence/egress/vectors.mjs` in resident Bun 1.4.4; complete compact output and exact interpretation are in `evidence/egress/results.md`. These are arithmetic results, not executable SUT tests.

| Checked sequence | Actual result |
| --- | --- |
| Bond principal delivered, new growth, full principal exit, further funding, activation | `k:1000->500->400->200`; 10 principal exits while closed; 1,000 wallet reward gons and 5,000 original bond gons remain distinct; later payments 5 and 25; immediate repeat 0; total backing and gons finally 0; total native paid 40 equals all input. |
| SY split, mixed ownership, internal transfer/burn, receipt output and raw principal exit | Seven principal units exit while closed; no shares left; 1,815 reward gons belong to Alice and 726 to Bob, whose internal principal ticket was spent by the router. The router receives no reward right. |
| Detached-right merge and two active rewards releases | Pay 2 then 2; repeats 0; final 421 gons remain owned at `k=423`. Backing 2 reconciles exactly to `floor(421/423)+Da(1)+Ds(1)`. |
| Wallet Alice -> router -> mixed Bob | All 30 original principal units exit; Alice/Bob retain 4,600/2,300 gons; router gains zero reward basis. |
| Reserved role owner changes between real allocations | Old beneficiary keeps 1,054 gons; at `k=374`, release 2 leaves 306; later fee allocation is 748 gons for new beneficiary. Release leaves `T=12703`, `B=35` unchanged. |
| Identical fee/creator beneficiary | Allocation 2+1 native at `k=527` gives one 1,581-gon pending right. |
| One router, two beneficial owners, funding while internally held | Alice/Bob tickets are 2/3 shares; an attempted 3-share Alice spend rejects despite five aggregate internal shares. All 10 principal units exit; 2,000/3,000 reward gons remain Alice's/Bob's and later pay 4/6; final backing/gons are zero. |
| Final bond fraction with a different claim recipient | Bob receives 8 native units; NFT owner Alice retains 776 gons, initially payable as zero. Later funded `k=388` releases 2 to Alice, repeat zero. |
| Active full displayed-balance withdrawal and explicit checkpoint | Eight native units leave; 776 physical gons survive at `k=778` and move intact into the original wallet's deferred account. |
| All splits `x=0..n`, `n=1..24`, at readable and production `Q` | 648 successful split/fund/merge/full-principal-exit/activate/release sequences, with gon/backing/basis/slot invariants and duplicate-release checks. |
| Cliff boundaries and preactivation requests | Principal due at unlock-1/unlock/unlock+1 is `0,10,10`; model reward claims/releases reject before mutation; attacker internal credit and reward-only wallet principal cap are both 0. |

The model uses the exact allocation floor rather than assuming all nominal reward immediately reaches the rebase. Early hand arithmetic failed on that distinction; the final output retains and checks those dust counters. The model does not execute token routes, Solidity uint256 overflow, gas, allowances, permits, callbacks, registry deployments or selector removal.

### 10.3 Required production witnesses, not run here

Use genuine registry-deployed Migration parent/children, the production funding and issuance caller, and real held backing. No arbitrary-credit issuer, parent impersonation, storage injection or SUT substitute.

- Run every operation-matrix money path directly and through the parent, with ordinary regression controls. Test underlying outputs from the actual configured `getTokensOut` set, not just sDETF/DETF. Exact-input, supported exact-output, allowance, permit, recipient and min-output rollback must agree.
- Check account/slot decomposition and actual custody after every split, merge, partial/full exit, direct stake, wrapper-internal redemption, role transfer, checkpoint and activated release. Include one-native-unit principal, zero/self transfers, nonzero fractional residues, a mixed existing recipient, and long Stage 1.
- Demonstrate successful matured principal exit for both direct receipt and every permitted wrapper output, then later funded exact-once reward release to the retained owner with no shares/NFT remaining.
- Demonstrate that public receipt true-pretransfer, direct wrapper self-balance theft, wrong custody caller, wrong `expectedK`, claimed descendants counted twice, unsafe whole-account/fraction retirement and a receiver callback cannot create or steal basis.
- Exercise real cross-proxy callback/phase checks and actual unchanged owner authority; activation attempts during every child phase must fail. Prove full rollback after failure in an onward route and after failed selector removal.
- Validate new facet declarations and actual proxy selector routing, all three guarded NFT transfers, read-only phase views, unavailable retired administration, and honest metadata/previews. Verify ordinary appreciated-gon SY remains ordinary.

These are the remaining E5/runtime acceptance obligations. The report does not close E4, E5, task 3 or task 5, nor claim external Pendle/router integrations have been executed against the changed SY semantics.

## 11. DoneClaim and cleanup

**DoneClaim: the requested T5-EGRESS engineering construction and deterministic arithmetic evidence are delivered.**

- **Deliverable:** this `egress-contract.md`, plus `evidence/egress/model.mjs`, `evidence/egress/vectors.mjs` and `evidence/egress/results.md`, authored with `apply_patch` only.
- **Decision settled:** exact native principal packets plus existing funded reward gons; Migration-only principal-denominated staking SY with attached transferable gon rights and source-owned detached exit residue. Rejected a native-principal sidecar on unchanged fixed-gon shares because integer splits can leave an unbacked principal unit. Rejected blanket exit pauses, growth-as-new-principal, suppressed funding, destructive full-account retirement and a bearer wrapper self-balance.
- **Evidence:** actual receipt/SY/bond/parent source and call paths inspected; source fingerprints recorded; final BigInt run returned successfully, including 648 split/merge cases at two scales, successful principal exits and later exact-once releases. No SUT acceptance is inferred from arithmetic.
- **Limitations:** this is a new-instance contract, not a legacy E2 construction. E1/E2, actual recovery E3 and BOOTSTRAP-AUTH remain open. No operational allocation, configuration, public action or production implementation is approved by this document. New interface/selector/bytecode/gas/callback and external-integration behavior remains to be verified through genuine production lanes. The edit tool's fresh JavaScript LSP diagnostic request timed out; no clean LSP/type-check claim is made.
- **Cleanup:** no processes, nodes, listeners, temporary directories, worktrees or installed dependencies were created. No Forge command, Git operation, delegation, dependency/config edit or upstream-report edit ran. Shared warm `out/`, `cache_forge/`, node_modules and Crane links were left untouched. Only the four intended authored files are retained; there is no owned temporary runtime resource to clean.
