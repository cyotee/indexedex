# Original-wallet source contract: NFTs, claims and recorded ETH/WETH

Date: 2026-11-11. Evidence-only handoff; no implementation or runtime verdict.

## Authority, checkout and evidence notation

The complete phase11 brief was read at
`/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase11-same-wallet-source-brief.md`.
The controlling main-checkout plan is
`/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`,
revision `migration-detf-implementation-plan-r3-original-wallet-entitlement`,
section 1, especially section 1.3, lines 56-64.

Every surrender requires **configured original wallet = caller = actual
controlling holder**, for the matching source/claim. No configured record means
rejection before custody, consumption or issuance. A transferred asset does not
carry the former wallet's compensation. A wallet that regains its asset needs
no intermediate-transfer proof, but still needs its original record and current
control. Independent compensation and permissionless capital donations remain
separate paths.

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-11-same-wallet-sources`.
Read-only Git verification returned HEAD
`3f577eeca049c1bd70a812d130941c8a38dd4781` and branch
`work/dtf-migration-phase-11-same-wallet-sources`.
Initial ordinary status exited 128:
`error: expected submodule path 'lib/crane' not to be a symbolic link`.
Status with `--ignore-submodules=all` then exited 0 with no output. No dependency
was changed. Only this owned `claims/` directory is authored.

Absolute evidence roots used below:

| Prefix | Directory |
| --- | --- |
| E | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/` |
| N | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-05/docs/incidents/2026-09-16-dtf-recovery/migration/nft/` |
| R | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery/docs/incidents/2026-09-16-dtf-recovery/migration/nft-recovery/` |
| M | This worktree's `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/` |
| O | This worktree's `scripts/recovery/dtf-migration/` |

Historical execution pin H is Robinhood chain **4663**, block **108944663**,
hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
It is not the new funded pricing snapshot. Phase05/07 in-process Foundry calls
are distinct from phase01 mined local-fork receipts; neither is a public
transaction claim.

Load-bearing retained evidence:

| Evidence | Exact scope and locator |
| --- | --- |
| `E/phase01-verification.md` sections 1-3 | Independent historical `other-metered` acquisition/custody supersedes the producer's HTTP 429 acquisition gap. `tokenstaking-caller.json` establishes the ordinary-caller limitation. Missing later Migration integration alone is not a missing source primitive. |
| `N/weighted/contract.md`, `archive-audit.json` | Exact weighted ABI, facet/runtime bindings, `sourceRanges` with original unescaped source lines, original purchase joins and local receipt identities. |
| `N/earlier/contract.md`, `source-evidence.json` | Exact earlier ABI, original-share units, archived flattened-source excerpts, purchase and custody records. |
| `N/verification/report.md` sections 2-4; `fork-independent.log` | 16 independent pinned integrated NFT cases and eight configuration cases under the **old current-holder rule**, not proof of the new original-wallet check. Trace locators below retain that distinction. |
| `R/weighted/contract.md`, `source-evidence.json`; `R/earlier/contract.md`, `source-evidence.json` | Exact recovery calls and source bindings; source-admission reports, not themselves integrated execution. |
| `R/verification/report.md`; `R/correction-verification/report.md` | Actual bounded proxy recovery, retained earlier failures, original R1 failure and its later independently confirmed correction. Corrected report sections 1-3 locate 22 fork cases, five focused cases and the added composition witness. |
| `E/verification/other-metered.sources.json`, `other-metered.json` | Historical actual TokenStaking/claim-vault runtime routes, reads, receipts and deltas. Use these, not the fresh-pin producer result, for H. |
| `E/verification/tokenstaking-caller.json`, `tokenstaking-source.raw.json` | `checks` for forwarding failure and absent recipient callback; optional source archive HTTP 404 remains. |
| `E/provenance/report.md` lines 33-40, 66-136 | Source-specific contribution joins, incomplete native/WETH coverage, unknown numeric fields and lack of an approved independent-allocation set. This is not an allocation upload. |

Source-line citations inside N/R audits mean the archived **unescaped source**,
not the audit JSON's physical lines and not today's similarly named contracts.
No new compilation, source recompilation, RPC probe or ancestry research was
performed. Prior runtime hashes and PASS/FAIL counts below are retained
observations, not newly recomputed results.

## 1. Current configuration seam and finite original-wallet change

### Observed current surfaces

1. `M/interfaces/IUniswapV4DetfMigration.sol`, `NftEntitlementInput` contains
   `collection, tokenId, originalUnits, originalEth, originalDtf, evidenceId,
   contributionsKnown`. It has **no original-wallet address**.
   `NftEntitlement` stores that input, configuration/original IDs and credit.
   `NftSurrender.holder` records the executed holder only after surrender;
   it cannot authenticate the wallet that originally contributed.
2. `M/UniswapV4DetfMigrationRepo.sol:20-44` keys configuration, permanent
   surrender and custody separately by `(collection,tokenId)`.
   `configuredOriginal`, `issuedOriginal` and `nftOriginal` are independent
   origin-collision bookkeeping, not an original-wallet registry.
3. `M/UniswapV4DetfMigrationAllocationTarget.sol:129-155`,
   `configureNftEntitlements`, validates source through `originalId`, ID >= 3,
   positive original units, known contributions and nonzero evidence; rejects
   independent canonical-origin collisions, evaluates frozen original inputs,
   and stores a complete replacement. It cannot validate a missing wallet
   field. It does not mint.
4. `M/legacy/MigrationLegacyNftLib.sol:47-65`, `preview`, already rejects
   consumed identities and zero `configurationId` before custody. It then
   reads live owner/units and computes the stored-credit fraction.
   `M/UniswapV4DetfMigrationTarget.sol:65-106` requires caller = current owner,
   takes safe custody, checks postconditions, records permanent consumption,
   and exact-funds a fresh bond. A different current holder can currently
   satisfy that check. Thus **missing NFT configuration rejection exists;
   original-wallet enforcement does not**.
5. `O/schema.ts:32-41` and `O/payloads.ts:7,20-28,76-88` encode the same
   wallet-less tuple. A proof pointer or evidence hash is not an address check.
   `scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol:58-61`
   forwards the typed array unchanged. The current bounded operator surface
   is configuration preparation/execution, not all-source surrender support.

### Required narrow future contract

Add a nonzero `originalWallet` to the complete NFT input and stored original
record. Load it only from the verified original qualifying acquisition/
contribution record, never from current `ownerOf`, the configurator, an
approval or the surrender caller. Include it in the existing complete-input
configuration hash; carry it through the typed operator schema/ABI and evidence
join. The existing chain/instance/snapshot/collection/ID canonical economic
origin key must remain wallet-independent so a corrected wallet field cannot
create a second economic origin or evade independent-overlap rejection.

At the retained surrender entrypoint, require a present configured record and
`msg.sender == config.original.originalWallet`, then require live
`ownerOf(id) == msg.sender`, before any custody call, consumption or issuance.
Keep the beneficiary fixed to that wallet. A public read preview need not turn
its caller into a beneficiary or create an entitlement. Keep consumed/custody
history immutable across configuration replacement, including wallet correction;
do not relocate the consumed identity into a resettable wallet-keyed mapping.
No zero-wallet default, current-holder fallback or on-demand enrollment.

For future fungible/claim configurations, bind explicit existence,
`originalWallet`, chain/source/class and economic claim identity, verified
original ETH/DTF inputs, exact original/remaining source-unit basis, frozen
credit, and revision/evidence identity. Keep surrendered units, delivered credit
and remaining credit separate from replaceable loading data. No such general
claim surrender record or entrypoint exists in the inspected current interface.
That is a finite implementation gap; row-specific missing numeric mappings and
caller restrictions below remain separate.

For a permitted partial surrender, use the plan's existing `Q,C` remaining
unit/credit rule: final `q == Q` consumes C; otherwise
`credit = floor(C*q/Q)`, then debit q and that credit. Never infer Q from token
decimals or quote reduced original contributions. Whole-NFT rules below consume
the whole identity instead. Do not apply independent allocation's
recipient-only no-surrender issuance API as a fallback for any source.

## 2. Weighted fixed-principal NFT: seven-field contract

### 1. Exact identity and ABI

Collection `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E`; funded weighted
generation, not the earlier LP lock. At H its proxy runtime hash is
`0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`.
Owner/approval facet G is `0xde5a691CEFE1830e8Ff2b65F6657738b0d9B9279`,
hash `0xf709b5311471ef0b02cf7ddaa8f48b9da30647ab9958a3efde1813e5ac4337b8`,
archive `match`. Bond facet B is
`0x3a07364eabA092472d40F0e6788b8891A31faD4D`,
hash `0x325a3b9bf3e616386e03d2a14d0a1fb29820f104a5f433d0b08a88dbdd0bef52`,
archive `exact_match`. Shared proxy hash is insufficient without these routes.

`N/weighted/archive-audit.json.bindings` pins:

| Proxy call | Selector | Return |
| --- | --- | --- |
| `ownerOf(uint256)` -> G | `0x6352211e` | address; absence can return zero |
| `positionOf(uint256)` -> B | `0x46f96023` | Static five-uint tuple: principal, claimedPrincipal, stakingGons, startTimestamp, vestingDuration; 160 bytes |
| `previewClaim(uint256)` -> B | `0xae648e90` | Static four-uint tuple: vestedPrincipal, principalRemaining, principalDue, rewardsDue; 128 bytes |
| `safeTransferFrom(address,address,uint256)` -> B | `0x42842e0e` | No return |
| `approve(address,uint256)` / `setApprovalForAll(address,bool)` -> G | `0x095ea7b3` / `0xa22cb465` | No return |
| `claimBond(uint256,address)` -> B | `0x084c59ae` | Two uint256 words, principal then rewards |
| `claimPrincipal(uint256,address)` / `claimRewards(uint256,address)` -> B | `0xf400c743` / `0x6c7b69cb` | One uint256 each |

Archived B `DETFFundedBondTarget.sol:127-200,210-243` and
`ERC721Repo.sol:153-170,229-254` are direct source anchors in the audit.

### 2. Wallet/source key and configured originals

Use `(4663,collection,id)` plus the Migration instance/snapshot domain and
the **recorded original qualifying wallet**. Configuration supplies original
wallet, purchase identity, positive original principal P0, verified original
ETH/WETH-input component and direct DTF component, known-component flags,
evidence ID and frozen C0. Source position exposes P0 and actual paid principal,
not original payer/contribution amounts.

`E/weighted/probe.results.json.history.purchases`,
`probe.historical-receipts.json`, and the joined records cited in
`E/provenance/report.md:68-85` supply 43 purchase joins, IDs 3-45; observed
inbound DTF/WETH payers match recorded purchase recipients. IDs 44-45 are
postincident fixtures, not approved allocations. No report here approves every
purchase or every numeric allocation.

ID 26's current holder
`0x2e69E40C4a4Ab5CA6826850F347acf8076a8063e` differs from its original
purchaser (`N/weighted/contract.md` section 3). Under r3 that different holder
must reject even with approval. The historical successful holder-transfer
test is retained, not reused as eligibility authority.

### 3. Native units and frozen credit

P0 and paid principal Pc are native **9-decimal legacy DETF-equivalent**
units. Gons are not principal; rewards add no credit. Require configured
P0 equals live principal, `Pc <= P0`, and `Pr=P0-Pc > 0`.
Deliver `floor(C0*Pr/P0)` native 9-decimal new DETF, where C0 is the sum of
the two once-evaluated original 18-decimal contribution components on the
same frozen book. Still-locked principal counts; `principalDue` is not Pr.
ID 32 at H: P0 `54436459`, Pc `8071216`, Pr `46365243`.
Whole surrender consumes the identity; `C0-delivered` is not another NFT award.
Reserved 0-2, burned 25/42, absent 46 and extant reward-only positions reject.
Unknown original input or wallet is a configuration blocker, not zero.

### 4. Custody/caller/approval and rollback

Original wallet must currently own the NFT and call Migration itself; an
approved legacy operator is not the claimant. Holder approves the **Migration
proxy**, per-ID or operator-wide. Migration calls the fixed collection's
three-argument safe transfer to itself, with zero value.
Both source authorization and ownership update occur **after** receiver
acceptance. In the callback check the guarded expected collection/operator/
from/ID/empty-data context only; return `0x150b7a02`. After return require
actual Migration ownership, one accepted callback and unchanged five-field
position. The transfer also synchronizes legacy rewards, so cover that external
work with the same guard.

Record custody and permanent consumption only within the same operation as
exact-funded fresh-bond creation for the original wallet. Transfer, callback,
postcondition or funding failure restores NFT owner/approval, consumption,
supply, backing and bond state. The transfer clears token approval; Migration
grants no legacy operator approval. No user-side claim is a prerequisite.

### 5. Recovery and fixed custody

Current Migration Crane owner selects bounded stages; every legacy recipient
is Migration, never the former holder, administrator EOA or a selected address.
Claim calls above pay 9-decimal old sDETF
`0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c`; partial vested claims can leave
the NFT alive. Preserve consumed identity after burn and across config replacement.

Exact admitted sequence (`R/weighted/contract.md` section 2):
old sDETF `exchangeIn(WS,q,WD,q,Migration,false,deadline)` ->
old WD `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7`;
WD `exchangeIn(WD,q,DTF,min,Migration,false,deadline)` ->
DTF `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01`.
Both use `0xd02d3063` and return **one** uint256, not today's two-output ABI.
The latter uses exact temporary WD approval to WD, cleared on success.
Book attributed WS gons, measured WD/DTF deltas and fixed reserve donation
separately. Synchronize attributed-gon value; do not strand legitimate growth
or spend unbooked gons. Current `M/legacy/MigrationLegacyRecoveryLib.sol:43-134`
retains this corrected finite sequence. Donation is a later protected reserve
budget operation and issues no second credit.

### 6. Executed evidence versus gaps; new tests

`N/verification/fork-independent.log:20099` proves the actual ID32 fraction,
`:17931` both source custodies, `:14790` callback ordering/missing-approval
rollback, and `:5679` funded-bond receiver rollback. `:19121` proves the
**former** different-holder success which the new wallet requirement must
reverse. `E/verification/weighted-replay.results.json` retains
**34 PASS / 1 FAIL / 2 UNPROVEN**; approved-operator redirection is a real
adverse source result, not failed custody.

`R/correction-verification/report.md` sections 1-3 and its
`fork-independent.log:64287-66502` establish real terminal-NFT growth recovery:
4,308,806,205 claimed WS plus 488,794 attributable later whole units convert.
The original R1 `RecoveryInventoryInsufficient(WS,1,0)` failure remains in
`R/verification/accrual-independent.log:16240-16515` and
`R/correction/fail-before.log`; correction, not relabeling, supersedes it.
No current r3 wallet-binding runtime evidence exists.

New integration tests: configure true original wallet, reject wrong current
holder/operator/unconfigured wallet before asset movement; reject original
wallet without current control; transfer back and successfully surrender
without transfer-history input; run ID32 partial/claim-race and zero/burned
cases; prove pre/postactivation identity checks, frozen credit, exact funded
fresh bonds and full funding/callback rollback. Replace configuration before
and after consumption, including wallet field, without reopening custody or
credit. Retain corrected growth-recovery and inventory-floor coverage.

### 7. Disposition

**Usable legacy custody and bounded recovery primitives.** Implement the
finite original-wallet binding seam in section 1. Actual approved wallet/input
rows remain configuration inputs; this report computes no C0. No retained
ancestry-only E2 label blocks this source. This is not all-category acceptance.

## 3. Earlier CP LP-lock NFT: seven-field contract

### 1. Exact identity and ABI

Collection `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391`, LP-lock generation.
Same proxy hash as section 2, but position/transfer facet is
`0x3AB85813785b43B864F9C171F7ac97d6B76c459b`,
hash `0xe44c05ff19808e8e7096c7e470cb1d40ddaf057f4e53818f1e749621d3632027`;
owner/approval facet G is the section 2 identity. Both archive labels are
`match`, not `exact_match`.

`N/earlier/source-evidence.json` authenticates `ownerOf`/approval/safe-transfer
selectors and layouts as in section 2, but the position call is
`getPosition(uint256)`, `0xeb02c301`, one static 160-byte tuple:
`originalShares,effectiveShares,bonusMultiplier,unlockTime,rewardDebt`.
`originalSharesOf(uint256)`, `0x0f3767df`, returns uint256;
`claimRewards(uint256,address)`, `0x6c7b69cb`, returns uint256 old DETF.
Do not decode this collection's position aliases as weighted principal.
Archived flattened `DETFNFTVaultFacet.sol:14305-14311,16643-16669,16982-17001`
locates layout/read/transfer; `:16413-16425` locates claim authority.

### 2. Wallet/source key and configured originals

Same domain-separated collection/ID key as section 2, separate original-wallet
field. Join the original `NewLock(uint256,address,uint256,uint256,uint256)`
ID/recipient and canonical purchase receipt to original direct DTF/WETH input.
`E/earlier-cp/probe-alchemy-retry.json` and independent
`E/verification/cp-replay.json` retain IDs 3-18 and all 16 purchase receipts;
N's source evidence retains the joins. The source does not expose original
contribution amounts or guarantee that current owner is the original wallet.
Earlier historical wording that purchase recipient is not a restriction is
superseded by r3; do not silently carry it into implementation.

Original share baseline S0, wallet, original ETH/DTF components, evidence and
frozen C0 must be configured. Unknown inputs reject. ID3's direct input is
`2000000000000000000` WETH; routed `1778859964387451305574664` DTF is not a
second contribution. ID4 directly contributed `7215852540309913726431` DTF;
reserve settlement `3703818` is not additional principal.

### 3. Native units and frozen credit

Use raw original **LP accounting shares**, not DETF principal, physical LP,
boosted effective shares or reward debt. Require live Sr = authenticated S0 > 0
for a purchased nonreserved ID. The admitted user source has no partial
principal-decrement path: a live lock retains its original shares; sale/burn
deletes the whole identity. Its fraction is one, even while locked.
Reward claims do not reduce original shares. No `claimedPrincipal` is invented.
ID12's `47848240999749918187208884` accounting shares differ from observed
physical LP `47848240999749918187208985`. Positive S0 mismatch rejects rather
than implying an undocumented fractional exit.

C0 retains original once-quoted 18-decimal ETH/DTF inputs and delivers native
9-decimal new DETF. Reserved 0/1/2, sold, burned, missing and zero-original-share
positions earn nothing. Whole surrender consumes the identity once.

### 4. Custody/caller/approval and rollback

Use the same original-wallet/current-owner equality and guarded expected safe
receiver protocol as section 2. Original wallet approves Migration; Migration
pulls the whole ID. Earlier transfer forbids the old parent recipient, not
every contract. The receiver is called before ownership update; validate
ownership and unchanged original shares after return.

No maturity, reward claim or sale is required before surrender. Approved
operator alone must fail Migration eligibility. Custody/consumption/exact
funding/new-bond receipt are one atomic transaction. Current implementation
fingerprints only earlier original shares because reward debt/effective weight
are not surrendered principal (`M/legacy/MigrationLegacyNftLib.sol:27-44`).
Do not demand unchanged reward debt as a new eligibility policy.

### 5. Recovery and retained blockers

After custody, Migration calls collection `claimRewards(id,Migration)` as
actual NFT owner; legacy approved operator alone does not qualify.
It receives 18-decimal earlier DETF
`0xaf0E1967c8F755c747615c5427108Bc549CA1122` and can retain the locked NFT.

Optional **mature** sale is Migration -> earlier parent
`sellPositionToDetfNft(id,Migration)`, `0x6b7d927e`, returning original
LP-accounting shares, not receipt output. Parent forwards
`sellPositionToDetfNft(id,Migration,Migration)`, `0x2115e3dc`, to its owner-only
child; Migration cannot directly call that child as parent. Child also checks
actual seller ownership and maturity. Sale burns the NFT, credits protocol
shares and mints earlier receipt
`0x4AC89aD061A531FA62ddceED53520C2750113b01` to Migration. Measure
`sharesOf(Migration)`, `0xf5eb42dc`, uint256 external shares; internal scale
is 1e9. Displayed 18-decimal receipt balance is a valuation, not share inventory.
Original LP remains in legacy custody. Book rewards and receipt deltas once.

`R/earlier/contract.md` sections 5-6 locates exact archived call graph
N:16500-16546, D:25419-25447 and R:10163-10184 and these retained failures:

| Further route | Exact result |
| --- | --- |
| Parent `closeBondMature(id,[0,minDtf],Migration,deadline)`, `0x7c212893`, returns uint256[] | Actual `VaultDisabled(0xb7D4Bb379D361AD442CddEE53eA71a33957826A7)` |
| Parent `redeemClaim(amount,oldDetf,min,Migration,deadline)`, `0xbfe55606`, returns uint256 | Same disabled earlier SE; not a direct DTF return |
| Receipt `redeem(amount,Migration,false)`, `0x5236be40`, returns uint256 | Same disabled SE; nominal pair output is DTF despite misleading `wethOut` source names |
| Earlier liquid `exchangeIn(oldDetf,q,DTF,min,Migration,false,deadline)` | No admitted successful conversion; weighted success is not evidence for this source |

Exact disabled revert bytes:
`0x1ba84b43000000000000000000000000b7d4bb379d361ad442cddee53ea71a33957826a7`.
Wrong-owner public mature close reaches this failure after parent-authorized
retirement logic; no original external holder check precedes that logic in the
archived path. Disabled rollback is **not** proof of safe ownership rejection
or successful theft. Keep SB-AUTH separate from Migration's own checks.
Missing archived facet
`0x67ed019eC3f8b77Bc51ED1e6403Fc90E0aBb15bE`, hash
`0xa289425ebf221bd44551376c3459083a4d53eb30f485b48e783bf8291f7a05d6`,
remains HTTP 404 for excluded selectors
`0x6a4d3f12,0xf5ee7c5b,0x36abf3dc,0x7cc34bb4`. It does not erase the
separately authenticated bounded claim/sale, or confer complete source audit.

### 6. Executed evidence versus gaps; new tests

`N/verification/fork-independent.log:13665,13966,17931` proves real
accounting-share use, reward-without-principal-reduction and locked custody.
Its former transferred-holder eligibility success is stale under r3.
`R/correction-verification/fork-independent.log:68093,68752,69889` retains
real Migration reward claim, measured sale shares, unchanged physical LP,
duplicate rejection and selected rollback; `:67372` retains adverse
wrong-owner disabled-close behavior. Sale ID4 retires
`2281854312954086546` original shares and mints
`1967558883021387942` external receipt shares; separate isolated reward-claim
and sale fixtures must not add their identical `309005608995105` rewards twice.
Historical phase01 **18 PASS / 2 FAIL / 4 UNPROVEN** remains unchanged.

New integration tests: the section 2 wallet/missing-config/transfer-back/
replacement/activation/rollback matrix on this collection too; original
shares remain the full fraction after rewards, locked NFTs remain eligible,
S0 mismatch rejects, sold/reserved/absent rejects, same numeric ID in both
collections stays independent. Recovery must use immutable surrender custody
after configuration correction. Retain explicit disabled exits and masked
authorization findings; no enable/owner impersonation or substitute source.

### 7. Disposition

**Usable whole-NFT custody and bounded claim-and-hold/mature-sale-and-hold
primitives**, with the finite wallet-binding change. **Concrete recovery
blockers** remain the disabled earlier SE, unproved earlier-liquid conversion,
masked external close authorization and excluded missing-source surface.
Holding/sale is not full underlying recovery, and none is repaired by removing
the obsolete ancestry prerequisite.

## 4. TokenStaking weight rights: seven-field contract

### 1. Exact identity and ABI

Source `0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00`, claim-weight system,
not ERC-20. At H, `E/verification/other-metered.sources.json` and
`tokenstaking-caller.json` bind `balanceOf(address)` (`0x70a08231`, uint256),
`reassign(address,uint256)` (`0xcc447fba`, no return) and
`withdrawClaim(uint256)` (`0xa224dcb7`, uint256) to
`0x9C90d4a476f3473b9a0e32B530aF3474271a80B1`,
hash `0x5628dcb4bb0a1a24e6bde3b985f92c2ef0894ddd6006a55ddaffccc877a52742`.
Proxy hash is the section 2 shared diamond hash. `totalSupply()` is
`0x18160ddd`, uint256; `claimVault()` is `0xab518e6e`, address.
ERC-20 approve/transfer/transferFrom, tested permit and multicall selectors are
unbound. The optional Sourcify source fetch is HTTP 404, not an exact-source
match. Current `contracts/protocols/staking/token/TokenStakingTarget.sol:184-209,289-306`
explains caller/math behavior; it is **not** claimed byte-identical legacy code.

### 2. Wallet/source key and configured originals

Key the original wallet and this source/claim identity, not a transferable
balance-derived entitlement. The source exposes current weight, total supply,
claim vault and phase, not original ETH/DTF contribution metadata or a
Migration-beneficiary authorization. The original configuration must supply
verified wallet, claim/economic origin, original native weight Q0,
remaining eligible weight basis, original ETH/DTF inputs and frozen C0.
The 92 observed weight rows in `E/provenance/report.md:102` are not an approved
allocation set or enough to manufacture those inputs.
Missing record must reject; neither current weight nor `reassign` enrolls one.

### 3. Native units and exact mapping gap

Weights use an 18-decimal DTF-denominated accounting basis; they are neither
9-decimal DETF/SY nor vault shares. In Wrapped phase, the current explanatory
source reads supply T and claim-vault shares V, consumes weight q, then redeems
`V` if `q==T`, else `floor(q*V/T)` shares. Those vault shares have 19 decimals
and redeem to 9-decimal SY. This conversion is not a compensation rate.
Actual H example: weight `64890781291192882058375` yields `117153341` SY;
it is not a global linear mapping and does not establish C0.

The exact missing operational mapping is **original wallet/claim and original
ETH/DTF -> original eligible weight/frozen credit**, plus, for an already
claimed representation, the exact native SY quantity and remaining credit
assigned to that same economic origin. No rate can be filled from one
historical claim ratio. Rewards moved by `reassign` are not new principal.

### 4. Actual caller and atomicity limit

`reassign` debits **source msg.sender** and has no recipient callback.
Ordinary Migration forwarding sees Migration's weight, not the user's.
`E/verification/tokenstaking-caller.json.checks` records:
forwarded claim-holder call fails `InsufficientStake(helper,q,0)`,
selector `0x936d426d`; direct holder transfer to an always-reverting recipient
nevertheless succeeds and calls no recipient. Reassigning first and issuing a
bond later does not make both transactions atomic. No approval fixes this.

**Legitimate user-side claim prerequisite:** in Wrapped phase the recorded
wallet can call `withdrawClaim(q)` itself. It consumes that wallet's weight and
pays SY to that **same caller**, with no arbitrary recipient argument. That
source-defined conversion may prepare a transferable representation for a
later configured SY surrender; it is not migration surrender, earns no new
bond, and cannot be rolled back by failure of a later transaction.

For such a later route, the eventual SY pull, same-wallet configuration
consumption and exact-funded new bond still must be **one atomic Migration
transaction**. A failed pull/issue leaves the already-claimed SY in the wallet;
it must not pretend to restore old weight. This report does not silently
replace the required raw-weight category with SY or assert a configured
weight-to-SY entitlement mechanism exists. Without the exact same-origin unit/
credit binding in field 3, that alternative is not ready to implement as a
credited path. Specialized account execution is not presumed or selected.

### 5. Recovery

For weights actually held by a custodian, that custodian can call
`withdrawClaim(q)` in Wrapped phase and receive SY itself. Actual partial
consumption reduces its weight and total supply, redeems source-owned vault
shares and leaves no surviving right to the consumed weight. Recovery then
uses the supported SY -> WS -> WD -> DTF sequence, fixed to Migration custody,
with measured native shares/gons/token deltas and no new compensation.
Do not call source-owner-only `migrateToClaimVault` as a user exit, assume a
recipient callback, or treat held backing vault shares as independently owned
by every claimant. Staged holding is allowed; separate committed transactions
have separate rollback boundaries.

### 6. Executed evidence versus gaps; new tests

Historical independent `E/verification/other-metered.json` weight custody/
harvest evidence around lines 8419-8712 demonstrates real EOA holder
`0x016900aa17a08a52f1cc10a9474b3bbfaeb380a3` weight -> new custodian, then
custodian weight zero and `117153341` SY. Its rollback case restores weight,
SY, supply `15338080546808403036783930` and vault shares
`276912583840862116302`. This resolves producer historical HTTP 429 custody
acquisition, not the ordinary-caller composition issue.
`tokenstaking-caller.json` independently proves that issue at H. Outer-revert
custodian-claim rollback is not proof that Migration can pull an EOA's weight.

New tests, after exact configuration mapping is available: real original EOA
claims to itself; verify weight/supply/vault-share/SY deltas and rounding;
configured same-wallet SY surrender preserves original C0 and only the
permitted fraction; missing/mismatched records reject before the SY pull;
partial/repeat claims cannot count both old weights and descendants; failure
of new funding rolls back SY custody/credit, not an earlier completed claim.
Retain a negative direct-ordinary-Migration raw-weight test. Do not test it
green through SUT/EOA impersonation or a fictional callback.

### 7. Disposition

**Concrete source blocker for direct ordinary-contract atomic raw-weight
surrender**, even under r3. Holder reassignment/claim are usable primitives.
An own-wallet prior claim is a legitimate source operation, not policy
permission for a two-step compensated handoff. A claimed-SY route additionally
has the exact configuration/unit mapping gap in field 3 and unimplemented
atomic SY surrender. No holder-ancestry blocker is asserted.

## 5. Claim-vault rights/shares: seven-field contract

### 1. Exact identity and ABI

Vault `0xAf5C0cD3fDEdd10bee00Eff77Fa0429Bacdb41f0`, rebasing-aware
ERC-4626 custody over SY `0xB55604CF4dcdABB362078e106D20F98512391EdF`.
At H, `E/verification/other-metered.sources.json:203-298` binds
`balanceOf`, approve/transfer/transferFrom to generic ERC20 facet
`0x1d17acA0e0717d90cea916372070a1BE4652223F`, hash
`0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50`.
The vault's `redeem(uint256,address,address)`, `0xba087652`, returns one
uint256 SY amount and routes to `0x517234F78A4BcAfc5F880024A3E45D49cF43b305`,
hash `0x8c1ea71d607b09b21c4e78f850647a059dc7935b6772f7cd3aeaa700a995439f`.
Proxy hash is the shared section 2 hash. ERC20 approve/transfer/transferFrom
selectors are `0x095ea7b3/0xa9059cbb/0x23b872dd`, bool returns;
balanceOf/totalSupply are uint256. Current
`contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Target.sol:97-110`
is explanatory, not a newly verified byte-identical archive.

### 2. Wallet/source key and configured originals

Distinguish a claimant's **TokenStaking weight right to vault backing** from
actual directly held ERC20 vault shares. They are not two claims.
For direct shares require recorded original wallet, vault/economic-origin key,
verified original and remaining eligible native shares, original contributions,
frozen credit and evidence. Read current actual `balanceOf(wallet)` separately.
`E/provenance/report.md:103` describes 74 related inventory rows, **not a proved
user vault-share census**. Actual probe share holder was TokenStaking
infrastructure. Impersonating that holder proves token mechanics, not that an
EOA claimant can authorize those shares.

### 3. Native units and frozen-credit mapping

Vault shares are **19 decimals**, not 9 or 18. Underlying SY is 9-decimal;
live vault conversion is not a frozen original-compensation quote.
The mechanical fixture transfers `2769125838408621163` raw vault shares and
redeems to `276912584` SY. This is not a global rate.
For direct shares, original-wallet/share/contribution/C0 configuration is
missing from the admitted input set. For indirect claimants use section 4's
weight units and own-wallet claim, not an invented allocation of V to each
account or a second award on backing.

### 4. Custody/caller/approval

For a legitimate directly held configured share record, the original wallet
calls Migration, approves that proxy, and Migration performs
`transferFrom(wallet,Migration,q)`. Require exact measured holder debit and
custody increase, q within that record's remaining units, and successful
remaining-credit consumption plus one fresh exact-funded bond in the same
transaction. Unauthorized pull, short custody or issuance failure restores
balances/allowance, consumption, supply and bond state.
The ERC20 has no special recipient callback requirement. The actual
infrastructure holder cannot be replaced with a user by assertion.
No direct-share user claim prerequisite is shown; a weight holder instead
uses its own source-defined `withdrawClaim` as described above.

### 5. Recovery

Migration-owned shares redeem with
`vault.redeem(q,Migration,Migration)`, burning only selected booked shares and
measuring actual SY received. No allowance is needed for Migration's own-share
redemption. Never choose TokenStaking as `owner` to bypass its claim rights.
Keep fixed custody and separate subsequent SY conversion/donation budgets.
The source-level SY route exists: `E/weighted/report.md:115-122` observes
8094 SY -> 9245 WS -> WD -> `52221256856930805` DTF.
SY redemption is
`redeem(address,uint256,address,uint256,bool)`, `0x769f8e5d`, uint256,
using Migration as receiver, WS as selected supported output and false
pretransfer. That proof is not a new installed general claim-vault recovery
stage or a general surrender implementation.

### 6. Executed evidence versus gaps; new tests

`E/verification/other-metered.json` cases named `claim-vault shares: ...`
retain unauthorized rejection, approval, exact custody, rollback and successful
redemption. Historical custody hash
`0xbfd713f0ff0a1fd4250cf720489d9d427f75cc98901696a4630dc17e492f9ed7`;
redemption hash
`0xd03b842118e15cfc252766d7c8150d8e099818f3c326143a1d181d5e95748ed1`.
Those are local-fork hashes, not public transactions. Overall independent
other-source result remains **21 PASS / 4 FAIL / 3 UNPROVEN**, exit 2.

New tests require an actually authorized original direct-share holder and
approved exact unit rows, not infrastructure impersonation as user authority.
Prove 19-decimal q/C partial/final rounding, same-wallet/missing-config checks,
atomic pull/credit/funding, protected old balances, staged vault-to-SY recovery,
conversion failure retaining previously committed shares/proceeds, and no
weight/backing/SY/independent duplicate award.

### 7. Disposition

**Usable direct-share custody/redemption primitives; missing original-wallet
exposure/configuration/unit mapping for credited user support.** Indirect
weight rights retain section 4's caller blocker. There is no basis to mark this
entire category implemented, absent, or a new independent-compensation path.

## 6. Recorded native ETH exposure: seven-field contract

1. **Identity/ABI:** native currency on chain 4663 is not an ERC20, NFT or
   transferable legacy claim contract with an owner/approval selector.
   The inspected Migration donation ABI
   `donateMigrationCapital(IERC20[],uint256[],uint256,uint256,uint256)` is
   payable and returns uint256 LP output; it is capital funding, not proof
   of an old personal claim. `M/UniswapV4DetfMigrationTarget.sol:122-174`
   requires exact msg.value/nativeAmount and wraps into configured WETH.
2. **Original wallet/key/inputs:** a historical ETH contribution must be
   attached to its recorded original wallet and matching eligible source/claim,
   with exact transaction/amount/evidence and frozen credit. Native ETH is
   `UNKNOWN` in `E/provenance/report.md:37,74,106,111-118`; zero native position
   rows mean not reconstructed, not proof of no exposure. The old ledger has
   435 blanks each for `V_eth/R_eth/E_eth/H_eth`, and 69 recovery `R_eth` blanks.
   No approved original-native entitlement dataset is supplied here.
3. **Units/credit:** native amounts are wei, 18 decimals, not legacy DETF
   principal. Unknown is not zero and must not be inferred from WETH transfers,
   NFT principal or gross payer totals. Use only verified original ETH inputs
   in frozen C0; no new ETH-to-DETF rate. Remaining surrender units belong to
   the eligible asset/claim record, not today's wallet ETH balance.
4. **Custody/caller:** sending fresh ETH is not surrender of an old legacy
   right. Reject missing personal source entitlement before any compensated
   action. Permissionless capital donations do not need entitlement and earn
   none; do not attach that missing-record rule to donations. No old native
   claim-consumption operation has been established by the admitted records.
5. **Recovery:** demonstrated weighted recoveries end in DTF, not native ETH;
   earlier blocked source variables named `wethOut` do not prove native output.
   No distinct old ETH recovery method/amount is invented. Future legitimate
   recorded recovered ETH must remain in fixed Migration recovery custody,
   with exact measured wrapping and protected reserve-budget accounting, not
   paid to a selected wallet.
6. **Evidence/tests:** absence/unknown is retained evidence, not a runtime
   PASS. Future configuration tests reject unknown native components, preserve
   known zero, and prevent counting ETH plus its wrapped representation twice.
   Any eventual source-specific ETH claim needs its exact caller/ABI and
   before/after recovery proof. No new generic native-surface or ancestry
   investigation is required for this evidence handoff.
7. **Disposition:** **missing original source/amount/configuration mapping**.
   No new personal native-surrender route is admitted. This does not remove
   native contribution quoting or the existing permissionless donation route.

## 7. Recorded WETH exposure: seven-field contract

1. **Identity/ABI:** chain-4663 WETH
   `0x0bd7d308f8e1639fab988df18a8011f41eacad73`, 18-decimal token.
   `E/verification/other-metered.sources.json:768-878` records code hash
   `0x5706be52f64875fee65a2cec0d80e47a23d8793cbe85d214b48445e2d05f5353`
   and metadata. It is not the common diamond runtime, and this evidence does
   not provide a complete WETH implementation/source audit. ERC20 custody ABI is
   `balanceOf(address)` (`0x70a08231`, uint256),
   `approve(address,uint256)` (`0x095ea7b3`, bool) and
   `transferFrom(address,address,uint256)` (`0x23b872dd`, bool).
   Current Migration uses payable `deposit()` (`0xd0e30db0`, no return)
   for exact native wrapping. No WETH-to-native recovery execution
   or additional legacy withdrawal selector is admitted from a token name.
2. **Original wallet/key/inputs:** WETH purchase transfer joins attach to the
   NFT/source entitlement and original payer wallet, not a second WETH award.
   `E/provenance/report.md:68-83` records weighted ID3 direct WETH
   `999999000000000` plus DTF `362893857600000000000`, weighted ID4 WETH
   `30000000000000000`, earlier ID3 WETH `2000000000000000000`.
   Full WETH coverage is only **27 partial inbound transfer rows**
   (`:107,174`); it is not a complete eligible wallet census.
3. **Units/credit:** verified original WETH-input amounts feed the existing
   original ETH-component quote as bound by the purchase records/accepted
   evaluator. Do not add native msg.value or routed DTF again without a
   distinct verified contribution. Neither current WETH holdings nor recovery
   WETH output is a valuation rate or an approved original entitlement.
   No separate standalone original-wallet WETH surrender quantity/C0 map is
   present; the known NFT inputs remain usable subject to configuration.
4. **Custody/caller:** NFT-backed WETH contributions use the NFT surrender
   contracts above; the holder does not need to reacquire and pay WETH.
   If a distinct direct WETH-backed legacy entitlement is later actually
   recorded, it requires its own original-wallet/source key and exact units
   before any atomic measured pull/credit/bond path can be admitted.
   Fresh WETH funding through the donation surface creates no personal claim.
5. **Recovery:** WETH already legitimately recovered would remain fixed
   Migration custody and enter only its configured supported reserve leg with
   measured budgets. The weighted WETH-leg SE
   `0x999DaE02D22E5FEe1c4508430D5196d31d631009` has actual
   `VaultDisabled(source)` exit failures in
   `E/phase01-verification.md` section 3 and `E/other-sources/report.md`.
   WETH's ordinary transferability does not fix that upstream SE exit.
6. **Evidence/tests:** original purchase transfer joins and token identity are
   evidence; standalone compensated WETH surrender is not an executed PASS.
   New tests must keep NFT ETH-component inputs stable, distinguish direct
   from routed/native inputs, reject absent direct-WETH records, and prevent
   WETH/ETH/receipt/independent duplicate credit. Preserve the disabled SE result
   separately from WETH custody.
7. **Disposition:** **recorded WETH contribution inputs, incomplete standalone
   exposure/configuration mapping**, not category absence. No new standalone
   personal WETH policy or conversion rate is authorized by these records.

## 8. Separate conservation, overlap and missing-record requirements

The new wallet rule removes the need to prove every intermediate transfer;
it does not make economic origins disjoint. These are three separate checks:

| Check | Finite requirement |
| --- | --- |
| Original-wallet eligibility | A present original source/claim configuration binds the actual recorded wallet; only that wallet, while controlling the asset, can surrender. Missing record rejects. |
| Consumption and remaining credit | Immutable consumed NFT identities; separately tracked fungible/claim remaining units, credit and delivered amounts. A claim/wrap conversion is a representation change, not a new original contribution. |
| Independent allocation overlap | Preserve canonical NFT-origin rejection in both configuration orders and after issuance/replacement. Require reviewed disjoint economic inputs for opaque aliases and weight/vault/SY descendants. Do not conflate this with holder ancestry or solve it by giving a missing-record wallet independent compensation. |

Current collision checks are
`M/UniswapV4DetfMigrationAllocationTarget.sol:73-88,113-120,136-140`,
backed by `configuredOriginal`, `issuedOriginal`, `nftOriginal`.
They catch canonical keys, not arbitrary aliases representing the same
economic exposure. `E/provenance/report.md:128-136` preserves seven
postincident bond/receipt descendants, 18 weight-to-SY conversions and
`UNRESOLVED_NO_APPROVED_INDEPENDENT_SET`. Those are input partition issues;
no complete intermediate-holder reconstruction is demanded here.

Retain fresh exact-funded bonds for each successful surrender, 90-day clocks
from actual creation, frozen original quotes, rewards excluded from credit,
whole-operation rollback and persistent postactivation surrender/recovery.
Remove all new loading/amendment selectors at activation with the existing
administration surface. No arbitrary target/calldata, source substitution,
postactivation approval authority or mutable transfer-history oracle is needed.

## 9. Coverage and implementation handoff

| Assigned category | Source disposition | Exact remaining action/blocker |
| --- | --- | --- |
| Weighted fixed-principal NFT | Usable custody and corrected bounded recovery | Add originalWallet to typed complete inputs/hash/loading and retained caller check; prove r3 matrix. Approved input amounts remain operational, no C0 invented. |
| Earlier CP LP-lock NFT | Usable custody and bounded claim/sale holding | Same wallet change; full original-share fraction. Disabled SE, unproved liquid conversion, SB-AUTH and excluded SB-SOURCE persist for recovery. |
| TokenStaking raw weight | Source blocker for ordinary atomic caller handoff | Claimant-only reassign/withdraw and absent callback. Prior own-wallet claim is legitimate preparation, not atomic compensated surrender. Claimed-SY support needs exact same-origin units/C0 mapping and atomic SY implementation. |
| Claim-vault direct shares / indirect backing | Usable ERC20 custody/redemption | Missing approved direct-share original-wallet exposure and exact unit/credit rows; 19 decimals. Infrastructure ownership is not user authority; indirect claim retains TokenStaking limit. |
| Recorded native ETH | Exact source/input blocker | Original native quantities/source rights unknown; reject missing personal configuration, preserve donation distinction. |
| Recorded WETH | NFT contribution evidence; incomplete standalone mapping | Reuse joined originals without double count; no invented direct-WETH award or cure for disabled WETH-leg SE. |
| Original-wallet configuration seam | Finite implementation gap in current bounded NFT code | Section 1 specifies interface/storage/input serialization, caller binding, immutable consumption and activation tests. |

This is an evidence-complete contract for the assigned rows, **not** a claim
that all rows have runtime support. Old E2 ancestry-only FAIL/UNPROVEN wording
is superseded as an eligibility blocker, not deleted or changed to PASS.
Actual caller/disable/source/unit failures and historical hashes remain intact.
No awarded numeric dataset, independent allocation approval or source-owner
policy change is supplied.

Validation in this task is read-only source/evidence reconciliation and scoped
document checking. No tests, compilation, deployment, transactions, commits,
delegation, out/cache seed or owned runtime were started. The separate held
phase09 gas candidate, node, tests and verdict were not inspected or resumed.
