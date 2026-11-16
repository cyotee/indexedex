# Independent NFT recovery source-stage admission

Date: 2026-11-11.

**Verdict: admitted for bounded implementation of W1-W3 and ER1-ER2,
subject to the binding accounting and authority conditions below.**
Both legacy NFT models remain required. This is not complete source support,
integrated recovery verification, successful earlier liquidation, or release
approval.

The [weighted contract](../weighted/contract.md) and
[earlier contract](../earlier/contract.md) identify usable finite primitives.
No additional source permission is needed for the actual Migration custodian
to call those five stages. The missing recovery implementation is downstream
work, not a circular source blocker. In particular, earlier claim-and-hold and
sale-and-hold are admitted despite blocked later exits.

| Stage | Exact admitted result | Disposition |
| --- | --- | --- |
| W1 | Selected surrendered weighted NFT claims principal/rewards into legacy weighted sDETF held by Migration | Source-admitted; combined/principal-only executed previously; rewards-only follows the same authenticated implementation |
| W2 | Booked weighted sDETF unstaked directly into equal native units of weighted liquid DETF at Migration | Source-admitted, with the fractional-gon protection in section 5 |
| W3 | Booked weighted liquid DETF exchanged for measured DTF at Migration | Source-admitted; the recorded successful witness uses the reserve-swap branch, not proof of every primary-burn branch |
| ER1 | Selected surrendered earlier NFT claims earlier liquid DETF rewards at Migration and remains held | Source-admitted claim-and-hold, including locked positions |
| ER2 | Selected mature earlier NFT sold through its old DETF parent; NFT burns, earlier receipt shares and remaining rewards stay at Migration | Source-admitted sale-and-hold, not liquidation; optional rather than forced |
| W4 / reserve handoff | Booked supported proceeds enter this same new DETF's reserve through its protected capital flow | Required implementation/integration stage; not a legacy selector or an already demonstrated recovery donation |
| Earlier mature close, either receipt redemption, earlier liquid DETF liquidation, resulting donation | No successful liquidated proceeds established | Not admitted as successful routes; exact blockers in section 7 |

The implementer may consume this contract now. Do not implement a fake
successful exit for the blocked rows. The W2 unbooked-gon floor and the
distinction between successful sale and optional legacy compounding are
explicit refinements of the producers' contracts, not source-policy changes.

## 1. Scope, evidence and independently checked baseline

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery`.
Branch: `work/dtf-migration-phase-07-recovery`.
Independently observed HEAD:
`6e7d8b8dc2cda313c7fb19ec051bfb84612f5f31`.

Read the entire phase07 brief, original main-checkout
`docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`,
both phase07 contracts, the complete phase01 independent report, both accepted
phase05 source contracts and phase05 runtime-verification report. Consulted
repository/canonical architecture and DETF rules, the phase05 source gate and
commit receipt, relevant accepted phase04 correction evidence, and the actual
current Migration custody, allocation, owner and operation-budget code.
No uncommitted phase05 production state was used.

Root's successful warm seed is supplied provenance; this lane did not repeat
it. Plain `git status --short` exited 128:
`error: expected submodule path 'lib/crane' not to be a symbolic link`.
Read-only status with `--ignore-submodules=all` succeeded. At entry only the
two producer evidence directories were untracked; no globally clean worktree
is claimed. The scoped production diff against the specified HEAD exited 0
with no output. The dependency link was preserved.

Evidence abbreviations:

| Prefix | Exact location |
| --- | --- |
| P1 | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/` |
| P5 | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-05/docs/incidents/2026-09-16-dtf-recovery/migration/nft/` |
| M | Current worktree `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/` |
| W | `P1/weighted/probe.sources.json`, address-keyed archived source/ABI/runtime |
| WR | `P1/verification/weighted-replay.results.json`, actual RPC journal and mined local-fork receipts |
| E | `P1/earlier-cp/probe-alchemy-retry.source.json`, archived `.contracts[address].sources[file].content` |
| ER | `P1/verification/cp-replay.json`, actual transaction traces and before/after states |

Source line citations below refer to the original **unescaped archived
Solidity**, not JSON lines or today's similarly named contracts.
`B/S/X` are weighted bond/staking/exchange facets; `N/D/R/T` are earlier
NFT/parent/receipt/ERC20 facets.

The source/execution pin remains Robinhood chain **4663**, L2 block
**108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
ER has `freshFallback=false`. No fresh pin was acquired or substituted.
This is not the new funded pricing snapshot and does not certify today's
operational source state.

[evidence.json](evidence.json) records independently recomputed input
fingerprints, archive checks and selected receipt joins. Consumed contracts:

| Input | SHA-256 |
| --- | --- |
| Original main-checkout implementation plan | `56106853d29ddff963ff2b8a872bdfa1840ed95ed29806bdc10d728220b60be7` |
| `weighted/contract.md` | `4754b0069565bd32e901ce3f3a54a546274269d4db2f83d63ac45b0e4b1be433` |
| `weighted/source-evidence.json` | `f4b82041b6457bc2adb3fa2714281850c0d7513cb92e7a30c403b19c784a597c` |
| `earlier/contract.md` | `d2b2ca71da9f5fd14640e2194a4ee62253c47d525fc36eeeda60bd3027ccb305` |
| `earlier/source-evidence.json` | `e94e8da9fee0c563a94c24fd294d88e21f647bf1f8dec2b666955427a7db5897` |

## 2. Fixed identities, routes and units

Let **MIG** be the actual registry-deployed Migration proxy/new DETF.
All calls below originate from MIG, use zero native value and target fixed
legacy proxies, not facets. MIG is neither the old DETF nor the original
holder. Do not delegatecall a legacy facet.

| Name | Address | Unit |
| --- | --- | --- |
| WN, weighted NFT | `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E` | Purchased ID |
| WS, weighted sDETF | `0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c` | Native 9-decimal amount; canonical internal gons |
| WD, weighted liquid DETF | `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7` | Native 9-decimal amount |
| EN, earlier NFT | `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391` | Purchased LP-lock ID |
| ED, earlier liquid DETF/reward token | `0xaf0E1967c8F755c747615c5427108Bc549CA1122` | Native 18-decimal amount |
| ES, earlier receipt | `0x4AC89aD061A531FA62ddceED53520C2750113b01` | 18 displayed decimals; separate external/internal share units |
| Earlier physical LP | `0x923877336b14662cFb5B3A60b14e7d716d54A888` | Physical 18-decimal LP, not EN original shares |
| DTF | `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01` | Native 18-decimal asset |
| Earlier disabled SE | `0xb7D4Bb379d361aD442Cddee53EA71A33957826A7` | Existing source dependency, not a new route |

MIG's own 9-decimal DETF and new funded staking receipt are different tokens
from both old generations and from DTF. Their principal, funded rewards,
self-leg and user packets are protected, not recovery input.

The six named legacy NFT/DETF/receipt proxies have shared runtime hash
`0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`.
That shared code does not establish behavior. Bind selector routes and facet
runtime as well:

| Tag | Facet address | Runtime Keccak-256 |
| --- | --- | --- |
| G, both NFT owner/approval | `0xde5a691CEFE1830e8Ff2b65F6657738b0d9B9279` | `0xf709b5311471ef0b02cf7ddaa8f48b9da30647ab9958a3efde1813e5ac4337b8` |
| B | `0x3a07364eabA092472d40F0e6788b8891A31faD4D` | `0x325a3b9bf3e616386e03d2a14d0a1fb29820f104a5f433d0b08a88dbdd0bef52` |
| S | `0xB7581fe833a2B2380DD786B345D61FFB734D36EB` | `0xcb505aba37d6ad909d8fb33dbf0091be50c9dd37f43e5df506bd240fc711b361` |
| X | `0x4886F86CD0DFFf8b8A836F858925eD4de3a2b291` | `0x1eadaa06571b1cca173491d149bab9b07d5d1b9dc83d268654e49d3179b1a460` |
| T, WD/ED ERC20 | `0x1d17acA0e0717d90cea916372070a1BE4652223F` | `0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50` |
| N | `0x3AB85813785b43B864F9C171F7ac97d6B76c459b` | `0xe44c05ff19808e8e7096c7e470cb1d40ddaf057f4e53818f1e749621d3632027` |
| D | `0x8333749Cc7b1f66b5be568257d362aA749497Cf0` | `0x5b5f12902a0baeb235ec2dc91794c425a0c60a439a7d9070cb1abb17b094389d` |
| R | `0x25E611FB63Eb904776678286EF5cbe2a931B4f9A` | `0x31151be4bf8ff8e79f448872f9a0a5c37ee413ce7d2b15206f2debcc59d86ccc` |

B/S/X archives report `exact_match`; G/T/N/D/R report `match`.
Recorded on-chain bytes and published recompiled execution bodies match after
terminal CBOR removal. This lane performed no independent recompilation or
complete transitive audit. The producer's additional weighted preview binding
remains a read-only quote, not proof of proceeds.

### Finite typed ABI

| Proxy / call | Selector / facet | Exact output |
| --- | --- | --- |
| WN/EN `ownerOf(uint256)` | `0x6352211e` / G | One address; absent/burned can be zero |
| WN `positionOf(uint256)` | `0x46f96023` / B | Five static uint256: principal, claimedPrincipal, stakingGons, startTimestamp, vestingDuration |
| WN `previewClaim(uint256)` | `0xae648e90` / B | Four static uint256: vestedPrincipal, principalRemaining, principalDue, rewardsDue |
| WN `claimBond(uint256,address)` | `0x084c59ae` / B | Two uint256: principalPaid, rewardsPaid |
| WN `claimPrincipal(uint256,address)` | `0xf400c743` / B | One uint256 principalPaid |
| WN `claimRewards(uint256,address)` | `0x6c7b69cb` / B | One uint256 rewardsPaid |
| WS `exchangeIn(address,uint256,address,uint256,address,bool,uint256)` | `0xd02d3063` / S | **One uint256**, not today's two-output layout |
| WD same exchange signature | `0xd02d3063` / X | **One uint256** |
| WS `gonsOf(address)` | `0x79a67521` / S | One uint256 |
| WS `stakingState()` | `0xe082f1d4` / S | Seven static uint256: totalGons, gonsPerUnit, accountedBacking, allocationDust, stakingDust, feeWeight, creatorWeight |
| EN `getPosition(uint256)` | `0xeb02c301` / N | Five static uint256: originalShares, effectiveShares, bonusMultiplier, unlockTime, rewardDebt |
| EN `claimRewards(uint256,address)` | `0x6c7b69cb` / N | One uint256 ED rewards |
| ED `sellPositionToDetfNft(uint256,address)` | `0x6b7d927e` / D | One uint256 **original LP accounting shares**, not receipt output |
| ES `sharesOf(address)` | `0xf5eb42dc` / R | One uint256 external shares |
| WS/WD/ED `balanceOf(address)` | `0x70a08231` / S/T/T | One uint256 native token amount |
| WD `approve(address,uint256)` | `0x095ea7b3` / T | One bool |

The five-word tuples are 160 static bytes, the four-word preview 128 bytes,
and staking state 224 bytes, with no leading dynamic offset. Same selectors
or tuple lengths across generations do not imply the same model.
WN and WS `detf()` (`0x8a91f8bc`) bind WD; EN `rewardToken()`
(`0xf7c618c1`) binds ED. These are fixed source identities, not supplied routes.

## 3. Authority, custody and invariant preconditions

Every stage's entrypoint must check MIG's **current proxy-local Crane owner**,
hold the common reentrancy lock and apply the existing child-accounting
admission checks over the complete external call graph. Retain the permission
after activation. Do not reuse M's `administration` modifier, which expressly
rejects activation (`UniswapV4DetfMigrationAllocationTarget.sol:36-41`).

`MultiStepOwnableRepo.sol:107-111,253-263` checks actual current ownership
and changes it on pending-owner acceptance. Its implementation does not
enforce the confirmation/buffer delay suggested by comments. Test current,
pending and former owners according to actual transitions; do not repair
Crane or create a second owner/operator role.

Before a selected NFT action require chain 4663, the exact collection,
purchased nonreserved ID, consumed `nftSurrenders[collection][id]`, matching
immutable `nftCustodies[collection][id]` including configuration-at-surrender,
and actual `ownerOf(id)==MIG`. Use these execution records, not replaceable
entitlement configuration or the surrender preview that rejects consumed IDs.
The source kind follows the fixed collection. An unsolicited unsafe transfer
alone is not a surrendered identity.

M `UniswapV4DetfMigrationTarget.sol:67-106`, `Repo.sol:18-44` and
`interfaces/IUniswapV4DetfMigration.sol:112-129` establish those separate
records. P5's accepted real-proxy execution proves both source custodies,
per-token approval clearing, irreversible consumption and fresh bonds;
it does not prove a recovery entrypoint exists at this baseline.

MIG must grant no NFT approval or approval-for-all. Historical operator
approvals remain keyed to the previous holder. WN permits approved operators
to redirect claims; ER1 instead authorizes owner or old parent, not an approved
operator alone. Neither source rule substitutes for the new current-owner
entrypoint check. Every recipient is explicitly MIG, never a caller argument,
zero/default recipient, former holder, fee recipient or deployer.

Harvest cannot call `_fundBond`, issue independent compensation, buy an
ordinary bond, resize/restart a delivered bond, reset consumption or credit
descendants. Sold/burned source IDs retain all immutable surrender history.
Recovery from a now reward-only weighted position is valid after its prior
surrender; reapplying surrender's positive-remaining-principal eligibility
would incorrectly block it.

## 4. W1: weighted claim into held WS

The primary call is `MIG -> WN.claimBond(id,MIG)`. The typed principal-only
and rewards-only variants are also admitted; a generic selector/calldata
interface is not. No allowance is needed. B `DETFFundedBondTarget.sol:45-48,
142-200,230-242` synchronizes the old parent, authorizes owner/approved operator,
checks recipient, transfers WS, and retires a fully paid NFT.

At the synchronized divisor `k`, source principal due is linearly vested
principal minus claimed principal; reward due is
`floor(position.stakingGons/k) - (principal-claimedPrincipal)`.
The original source clock and native 9-decimal units remain unchanged
(B `DETFFundedStakingMath.sol:96-117`). This is not the new 90-day cliff.
Preview uses stored state and is not a realized payout promise.

Let `A=principalPaid+rewardsPaid`. Read MIG's WS gons `G0` before the call
and `G1,k1` after. Require actual `G1-G0 == A*k1`; at the same index
`floor(G1/k1)-floor(G0/k1)==A`. Credit exactly A native claim units and the
corresponding actual gons, with principal/reward components separately
recorded. Do not credit the unsynchronized raw `balanceAfter-balanceBefore`
when it includes revaluation of previously held receipts.

Zero payout on a live position books zero, not completion. Partial claim
preserves the remaining principal and clock. Repeated live claims may recover
new vesting/rewards only. If claimed principal equals principal and remaining
position gons are less than k, the source retires that fraction and burns.
Do not require a post-claim position read to succeed in the final-claim case.
A burned repeat rejects; it is not an idempotent success stub.

WR `rpc[429]` sent the actual custodian claim; `rpc[431]` contains its mined
receipt, hash
`0x40049b8b180aaf28d770b96a0b607bce5cd181b3efa5489b00cfa60db9c27cb8`.
ID 3 paid **3,772,281,649 principal + 536,524,556 rewards =
4,308,806,205 WS** to EOA custodian
`0x000000000000000000000000000000000000c057`. Source transfer and claim
events corroborate the amount. Principal-only execution leaves a reward-only
position in the separate recorded case. These are historical local-fork
witnesses, not phase07 calls from MIG.

## 5. W2-W3: bounded conversions and the gon-floor condition

### W2 direct unstake

```text
MIG -> WS.exchangeIn(WS,q,WD,q,MIG,false,deadline) -> q
```

Require positive q within booked WS native inventory. The source debits
MIG's own WS account and pays equal native 9-decimal WD from held backing.
No WS allowance or parent-only permission is needed. Enforce deadline,
nonzero amount, false pretransfer and exact observed WD output equal to q.
Debit q booked WS once and credit q WD once. Source:
S `StakedDETFTarget.sol:142-149,187-214,230-236`.

**Binding implementation refinement: preserve unbooked fractional gons.**
S `DETFFundedStakingRepo.sol:107-124` debits `q*k` for a partial account exit,
but debits **all account gons** if q equals its entire displayed balance.
Thus `q <= booked native inventory` alone is insufficient: an unrelated
sub-native fraction can be retired even when the visible old balance is
protected.

Keep attributed recovery gons as well as native inventory. If MIG has G0
gons and B0 are booked recovery gons immediately before W2, require the
observed debit `Dg=G0-G1` to be no greater than B0, and preserve
`G1 >= G0-B0`. Debit the actual Dg from the booked gon ledger; never erase
unbooked gons or infer them from the whole balance. Corroborate the source
partial/full-account debit rule at the synchronized index. If a full-account
exit would retire an unbooked fraction, reject it atomically or select a
smaller amount; do not silently classify that fraction as recovery dust.
Attributed dust and revaluation remain explicitly held/accounted, not another
NFT claim or authorization to expand a native spending budget.

For example, a final one-native-unit recovery with an additional unbooked
sub-native remainder has no smaller positive q under this selected direct
route. That exit remains held while the condition persists. This is an
explicit liveness limit, not permission to retire unrelated rights or claim
complete weighted liquidation.

This is an implementation accounting requirement, not a missing legacy
selector. W1's same-index measurement plus W2's gon floor make the admitted
routes implementable without sweeping unrelated receipt rights.

WR `rpc[440]` / receipt `rpc[442]`,
`0xc5fdef1e066063b549f98c2f9d4508726f3e20b6f65303f42dc0de89eebac6eb`,
burned **4,308,806,205 WS** and transferred exactly **4,308,806,205 WD**
to the same custodian. It does not exercise mixed booked/unbooked fractions.

### W3 weighted DETF to DTF

```text
MIG -> WD.approve(WD,q)
MIG -> WD.exchangeIn(WD,q,DTF,minimumDtf,MIG,false,deadline) -> out
MIG -> WD.approve(WD,0)
```

Require positive q within booked WD inventory. WD is both token and fixed
spender: `_burnPath` pulls from its caller. No NFT/receipt/facet approval is
appropriate. Use an exact temporary allowance, reject failed calls and clear
on success. Require actual WD debit q, positive DTF delta equal to the
one-word return, and delta at least minimumDtf. Input is native 9-decimal
WD; output/minimum is native 18-decimal DTF, with no constant 1:1 rate.

X `UniswapV4DetfTarget.sol:204-234,429-495,516-534` selects primary
proportional burn or swap fallback from existing gates. The swap transfers
WD into the reserve rather than burning supply. Owner-restricted reserve
operations are called by WD through its legitimate graph, not by MIG
pretending to own the legacy LP. Nested approvals are scoped and cleared
(`UniswapV4DetfCommon.sol:413-427`).

WR `rpc[448]` / receipt `rpc[450]`,
`0x8e20f225db3d277f59b1950224f075c2b8ba1198d475d2308297cb283d9caffc`,
shows **4,308,806,205 WD** pulled and transferred to reserve
`0x46e068c2393e189fbc86632f67210af253a42aa8`, followed by
**24,312,424,763,253,115,621,623 DTF** to the custodian.
This is actual successful **swap fallback** evidence. Primary burn semantics
are source-derived; this receipt must not be counted as its execution.
The fixture's zero minimum and oversized deadline are not operational advice.

No WETH leg, arbitrary output, direct owner-only LP exit or registry enable
operation is admitted. `_requireActive` in this old source checks amount and
deadline, not Migration activation. Dependency failures still propagate;
one historical success is not the full registry-disable or market-state matrix.

## 6. ER1-ER2: earlier rewards and receipt holding

### ER1 claim without selling

```text
MIG -> EN.claimRewards(id,MIG) -> rewards
```

Require the section 3 custody identity and unchanged positive original
accounting shares. No maturity, allowance or NFT operator grant is needed.
N `DETFNFTVaultFacet.sol:15222-15224,16413-16454` admits the exact owner or
stored old parent, updates rewards and transfers ED. N `:15810-15824,
16000-16012` and T `ERC20Facet.sol:3060-3063,3099-3101` show the local
balance/transfer graph, not an SE withdrawal or receipt conversion.

Measure ED at MIG immediately before/after; require delta equals returned
rewards, credit only that delta, and require NFT ownership and original shares
unchanged. Zero adds zero; repeat can claim genuinely new accrued rewards.
Do not freeze a permanent claimed flag on a still-live NFT.

ER `transactions[6]`,
`0x5dfa0bfd67a8a62b6db4867245de7a3e2332195d97a75219bc0b6dd6e9ca1d45`,
returns/transfers **309,005,608,995,105 ED** for ID 4, retaining
**2,281,854,312,954,086,546 original shares**. The actual claim trace has
six calls and never reaches the missing parent facet or disabled exit.
Former-owner and approved-operator claims reject in the saved cases.

### ER2 mature sale into ES, not liquidation

```text
MIG -> ED.sellPositionToDetfNft(id,MIG) -> originalShares
```

Require section 3 custody, no previous terminal sale and
`block.timestamp >= unlockTime`. Enforce a selected deadline and minimum
**external receipt shares** in the wrapper; the source signature has neither.
An earlier reward claim is optional, since sale harvests remaining rewards.

The authenticated graph is:

1. D `UniswapV4SingleStandardExchangeDETFFacet.sol:25419-25447,22665-22690`
   passes its caller MIG as seller, with MIG as recipient.
2. ED calls EN `sellPositionToDetfNft(id,MIG,MIG)`, `0x2115e3dc`,
   returning two uint256 words: original principal shares, rewards claimed.
   N `:16500-16546` is old-owner-only and also checks NFT owner equals seller,
   maturity, nonreserved ID and positive original shares.
3. EN harvests ED to MIG, moves principal accounting shares into protocol
   ID 0, clears the user position and burns. Physical LP stays in EN custody.
4. ED calls ES `mintFromNFTSale(originalShares,protocolOriginalBefore,MIG)`,
   `0x8d3c633c`, returning one **displayed receipt amount**. That inner return
   is not the outer original-share return.

Measure ED and ES `sharesOf(MIG)` around the outer call. Require original-share
return equals the selected pre-sale original units, positive new external ES
shares meeting the selected minimum, zero owner and all five position fields
cleared. Record one terminal sale transition without deleting consumption or
new-bond history. Credit measured ED and ES external shares separately; do
not numerically add retired LP-accounting shares to token outputs.

R `RebasingClaimTokenFacet.sol:9852-9877,9966-9975,10163-10184` converts
external shares to internal shares with scale `10^9`; displayed balance is
`floor(internalShares * rate / 10^27)`. Sale adds an integer external-share
quantity times that scale, so external `sharesAfter-sharesBefore` isolates
the minted shares even with a preexisting internal fractional remainder.
Displayed balance/rate movement can revalue older holdings; it is not newly
minted inventory. Holding does not need a redemption-price call.

ER `transactions[9]`,
`0x3d54621af7e5dff968aed64f3639d0222170d962ead7c80339f39a33ede46042`,
returns **2,281,854,312,954,086,546 original shares**, delivers
**1,967,558,883,021,387,942 ES external shares** (displayed balance **4,322**)
and **309,005,608,995,105 ED**, and burns ID 4.
LP custody stays **107,516,722,668,090,845,797,720,021,675,152,213**.
This isolated sale case starts before the separate claim case: their quoted
reward amounts are not additive. Repeat sale and early sale of locked ID 3
reject. A locked NFT can remain held and use ER1.

The 149-call successful sale trace has no call to the missing facet, but
does include transitive pricing dependencies. Source D `:24946-24969`
**catches failure of its optional atomic compounding self-call**; therefore
sale success does not prove that compounding succeeded. A revert escaping
the outer sale must revert MIG's entire selected transaction. MIG itself
must not catch and skip failed sale items. This preserves actual legacy
semantics without introducing a recovery fallback.

## 7. Needs-fix and source blockers retained

| ID | Exact limitation | Required disposition |
| --- | --- | --- |
| NF-W2 | Native-only WS budgeting can retire unbooked fractional gons on a full-account exit | Implement section 5's actual-gon debit bound and unbooked floor; prove mixed-inventory rejection. Five-stage source admission does not waive this condition. |
| SB-E1 | ED `closeBondMature(uint256,uint256[],address,uint256)`, `0x7c212893`, returns a dynamic uint256 array; it expects two minima, first zero, nominal output `[0,DTF]` plus separately harvested ED | Not admitted as successful. ER transaction 12, `0x61fb08ec01b576756fa25ae3ab9631613f140471c843576a2eac3774a7ff37a1`, fails `VaultDisabled` and restores state. |
| SB-E2 | ED `redeemClaim(uint256,address,uint256,address,uint256)`, `0xbfe55606`, accepts ED output and returns one amount | Not admitted as successful. Transaction 20, `0xe4359e06c585390d0c6e33cfb105c2384f58c4f9b44d75e1e0c566a2a97109e9`, reaches disabled SE and rolls back. |
| SB-E3 | ES `redeem(uint256,address,bool)`, `0x5236be40`, would pay its pair/rate asset DTF, despite the source variable named `wethOut` | Not admitted as successful. Transaction 23, `0x22fb95c8bfd0b3f7c58faa20f4672371f4740ffb8a3276cccb3ff2a731880a0d`, fails at the disabled SE. True pretransfer is no fallback. |
| SB-E4 | ED `exchangeIn(ED,q,DTF,min,MIG,false,deadline)`, `0xd02d3063` | Unproved, not admitted. D `:25137-25174,25204-25236` requires live reserve and primary burning eligibility, then reserve withdrawal. No success or specific newly executed revert is invented from weighted evidence. |
| SB-AUTH | Public earlier mature close lacks a holder check before old-parent-authorized retirement | Security/source limitation, not authorization PASS. See below; MIG cannot repair the separately callable old parent. |
| SB-SOURCE | Earlier facet `0x67ed019eC3f8b77Bc51ED1e6403Fc90E0aBb15bE` remains archived HTTP 404 | Its four routed selectors remain outside admission. No complete old-parent/transitive source audit is claimed. |
| IG-DONATE | No phase07 bridge from recovered inventory through the new DETF reserve has executed | Implement and prove W4 for supported proceeds. ED/ES are not automatically valid new reserve legs; earlier donation is not demonstrated. |
| IG-RUNTIME | Source custodian witnesses are EOAs; baseline phase05 proves custody but not recovery methods | Genuine registry MIG execution, owner transfer, activation, callback/batch/gas/accounting tests remain required below. |

The exact recorded disabled payload in SB-E1-E3 and the wrong-owner close is:

```text
0x1ba84b43000000000000000000000000b7d4bb379d361ad442cddee53ea71a33957826a7
VaultDisabled(0xb7D4Bb379d361aD442Cddee53EA71A33957826A7)
```

For **SB-AUTH**, D `:25644-25691` and N `:16377-16404` do not authenticate
the original external caller as the NFT holder. `_requireMature` only checks
time (D `:24483-24487`). ER transaction 14,
`0xbecb8677c003a5a4a58dfbc511237973681cb0250ba6a78fc6928ce1a03ab528`,
actually reaches an inner `retireMaturePosition` returning original shares
and rewards with attacker-selected recipient. The enclosing disabled exit
then reverts **all** effects. That is stronger evidence of an authorization
gap than a generic failed call, but it is neither successful theft nor proof
that custody is globally safe if dependencies change. Do not enable the SE
or hide this residual exposure behind MIG's correct owner guard.

SB-SOURCE's runtime is
`0xa289425ebf221bd44551376c3459083a4d53eb30f485b48e783bf8291f7a05d6`;
selectors are `0x6a4d3f12,0xf5ee7c5b,0x36abf3dc,0x7cc34bb4`.
Observed ER1/ER2 traces do not reach it. That supports bounded admission,
not future-state or blanket source acceptance.

Direct EN retirement/mint administration and direct legacy LP exits are not
alternative holder APIs. Preserve phase01 `NotOwner`/`UnsupportedRoute`
findings and weighted WETH-leg SE disable evidence. No policy relaxation,
arbitrary executor, route adapter, rescue destination or new source is admitted.

## 8. Shared accounting, fixed donation and downstream proof

Each selected transaction is atomic across source effects, local inventory,
approvals and any selected donation. Propagate a failed middle item. A smaller
retry is a new transaction. A committed W1/ER1/ER2 in transaction A survives
failed conversion/donation in transaction B; reverting B must not erase A.
Snapshot restoration in an old source probe is not an integrated batch proof.

Maintain explicit per-token undonated inventory, denominated accurately:
native amounts for WD/ED/DTF; WS with attributed gons and native budget;
ES holding in external shares with its scale explicitly identified.

```text
after = before
      + newly received claims
      + actual conversion outputs
      - actual conversion inputs
      - actual donations
```

Apply that equation within each unit, never add gons, LP accounting shares,
external receipt shares and displayed token units. Record representation
transitions, not multiple recovered-value totals. Revaluation of old holdings,
unsolicited balances and full parent balances are not new claim receipts.
Duplicate selection cannot book old outputs twice. A second ER2 or burned W1
must reject, while a live claim may add only real new accrual.

For W4, only the selected booked supported quantity may enter MIG's existing
reserve/custody graph. Debit recovery inventory exactly once and preserve
actual residuals in the correct existing accounting domain. M
`UniswapV4DetfMigrationTarget.sol:125-200` measures external donor pulls;
a self-call is not a proof of fresh receipts. Its donation validation rejects
self token and unsupported legs. M `UniswapV4DetfMigrationPolicy.sol:18-55`
provides operation floors and separately accounted residuals. A new bridge
must use that protected flow without unlocking old donation budgets, sweeping
unrelated custody, widening residual authority, or issuing compensation.

Preserve new bond/staking/SY backing and funded reward rights, ordinary user
packets, donation budgets, self-leg inventory and other legacy custody.
No callback may enter recovery, surrender, activation, donation or another
child money path during the guarded operation. W1/W2/ER1/ER2 need no MIG
allowance; W3's exact WD self-spender allowance must finish at zero.
Failed selected transactions revert temporary approvals with other effects.

No activation gate may remove recovery. Preserve registry policy route by
route: legacy claim/holding success does not enable a disabled exit; the new
reserve donation retains its existing disable checks. Do not place a blanket
inbound-style registry barrier on every exit merely to simplify the wrapper.

Required implementation/verifier evidence through actual installed selectors:

- Real registry MIG with both genuinely surrendered pinned NFTs; current,
  former and pending owner behavior before/after acceptance and activation;
  fixed MIG recipients and no legacy operator grant.
- Weighted partial/mature/principal-only/reward-only/combined and repeated
  claims, final burn, no-new-accrual zero behavior; earlier locked claim,
  mature sale, duplicate sale, unchanged LP custody and exact share units.
- Prior WS holdings with an index change, unsolicited fractional gons,
  attributed-gon debit bounds, partial/full unstake, preexisting ED/ES/DTF,
  short/zero receipt-share sale, exact approvals and protected backing.
- Actual W2/W3 success and real supported reserve donation; branch-specific
  claims distinguish executed swap from source-derived primary burn. Exact
  observed registry failures, not fabricated alternative success.
- Failing middle selection with complete rollback, smaller retry, earlier
  committed inventory surviving later conversion/donation failure, callback
  reentry negatives and unchanged delivered bonds/consumed entitlements.
- Work proportional to selected positions, not all custody. Compare small
  and large unrelated populations; derive an honest operational bound from
  measured gas and actual target limits, not the permissive test gas cap.

Artifact-first Solar build and affected specs/forks/regressions remain the
implementation lane's obligation. No parent/source-owner impersonation,
SUT subclass, storage injection, etch or replacement legacy bytecode may
manufacture those successes.

All other plan gates remain open under their existing dispositions: full E1
categories, E2 ordinary-transfer/claim/wrapper ancestry and postactivation
nonduplication, operational E3 quote/route inputs, E4 funding provenance, full
E5 payout/surface/registry matrix, remaining fungible/claim surrender,
all-source harvest, reviewed allocations, operator/resume rehearsal,
invariants/gas/full integration and F1-F4 release. Both liquid generations,
both NFTs, both receipts, SY, TokenStaking/claim-vault rights, underlying SE
shares and fungible LP remain distinct required categories. NFT recovery
does not construct E2 or close any whole original-plan checkbox.

## 9. Verification performed and runtime disposition

This lane read actual archived source bodies and actual source execution
receipts, rather than adopting producer PASS strings. Resident offline
checks recomputed 28 weighted selectors and their recorded replay loupe
bindings, ten earlier selectors, facet runtime identities and published
execution-body equality, all 40 producer excerpts, selected mined-call
joins, earlier return values/burn/LP preservation and four disabled rollbacks.

The audit contains **190 assertions: 187 pass, three initial harness
comparisons failed and were corrected, zero unresolved failures**.
Those three compared enriched archive facet objects directly against compact
producer objects. Explicitly comparing `facetAddress` and archived
`functionSelectors` to producer `selectors` makes all three pass. Their initial
failures remain in `evidence.json`; no product or source failure was relabeled.

Preserved phase01 verdicts: weighted replay exit **0**, **34 PASS / 1 FAIL /
2 UNPROVEN**; earlier replay exit **2**, **18 PASS / 2 FAIL / 4 UNPROVEN**.
The weighted FAIL is actual operator redirection. Earlier disabled and
masked-authorization results remain adverse. The P5 genuine-custody evidence
is reused with its stated limits, not rerun or represented as phase07 recovery.

Only this report and `source-verification/evidence.json` were authored.
No Forge build/test, new RPC, new fork transaction, public action, source-policy
change, production/test/dependency/config edit, commit or delegation occurred.
JSON LSP could not run because `biome` is not installed; no installation or
clean LSP result is claimed. JSON parsing, fingerprint comparison and scoped
diff checks are the artifact validation. All 12 fingerprinted consumed inputs
remain identical; final tracked diff is empty and `git diff --check` passes.
The only new owned paths are the two files in this source-verification
directory; the four preexisting producer files remain unchanged.

No node, listener, local port or owned temporary runtime root was started;
no runtime is pending. Warm artifacts, dependency links and prior evidence
remain untouched. The handoff is the exact finite admission above, with
earlier holding retained and later liquidation still blocked or unproved.
