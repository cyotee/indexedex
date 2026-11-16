# Earlier LP-lock NFT: bounded recovery stage contract

Date: 2026-11-11. Source lane only; no production or test implementation.

**Admit direct reward claim into Migration and holding of the actual old DETF
received. Admit mature sale into the earlier receipt and holding of the actual
receipt shares received, subject to the checks below. Do not admit mature
close, receipt liquidation, old-DETF liquidation or donation as demonstrated
successful earlier-source stages.** A sale burns the selected NFT; it is not
full liquidation. Locked NFTs can remain held and claim rewards without sale.

These are exact source contracts for the independent source gate and subsequent
implementation/proof lane. Historical claim/sale execution used an EOA
custodian; accepted phase05 proves actual Migration NFT custody, not these new
recovery methods. No integrated phase07 recovery execution is claimed here.

## 1. Provenance and evidence

Independently checked worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery`,
branch `work/dtf-migration-phase-07-recovery`,
HEAD `6e7d8b8dc2cda313c7fb19ec051bfb84612f5f31`.
Initial status with `--ignore-submodules=all` was empty. Plain status failed
because the warm `lib/crane` is a symlink; it was not repaired or replaced.
The Migration source directory matched the specified commit with diff exit 0.
Root's warm-seed exit 0 is supplied provenance, not a seed rerun by this lane.

Read the complete main-checkout
`docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`,
especially MIG-P12-P14, section 5.6, task 8, MIG-AC09-11/15/17/29/32-34/44-47
and the remaining source/operator/release gates. Read the complete phase07
brief, repository rules, canonical architecture and actual custody/owner code.

Read-only evidence roots:

- **P1:** `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/`.
  Consumed the complete `phase01-verification.md`, `earlier-cp/report.md`,
  `earlier-cp/probe-alchemy-retry.source.json`, the producer
  `probe-alchemy-retry.json`, independent `verification/cp-replay.json`
  and its exit receipt. Weighted evidence distinguishes its funded 9-decimal
  model; its liquidation success is not borrowed for the earlier source.
- **P5:** `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-05/docs/incidents/2026-09-16-dtf-recovery/migration/nft/`.
  Consumed the accepted `earlier/contract.md`, source gate, complete
  `verification/report.md` and `commit/receipt.md`. Current phase07 code,
  not uncommitted phase05 code, grounds the integration requirements.
- [source-evidence.json](source-evidence.json): input SHA-256 fingerprints,
  exact proxy routing, selected source excerpts, recomputed selectors/runtime
  identities, historical transaction locators and measured before/after state.

Historical evidence pin: Robinhood chain **4663**, L2 block **108944663**,
hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root `0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
Both consumed executions have `freshFallback=false`. No additional pin or
fresh state was acquired. This is not the new funded pricing snapshot.

Source references **N**, **D**, **R**, **T** below mean unescaped flattened
source lines in the archived `.contracts[address].sources[file].content`:

| Key | File / facet | Recomputed runtime Keccak-256 |
| --- | --- | --- |
| N | `DETFNFTVaultFacet.sol`, `0x3AB85813785b43B864F9C171F7ac97d6B76c459b` | `0xe44c05ff19808e8e7096c7e470cb1d40ddaf057f4e53818f1e749621d3632027` |
| D | `UniswapV4SingleStandardExchangeDETFFacet.sol`, `0x8333749Cc7b1f66b5be568257d362aA749497Cf0` | `0x5b5f12902a0baeb235ec2dc91794c425a0c60a439a7d9070cb1abb17b094389d` |
| R | `RebasingClaimTokenFacet.sol`, `0x25E611FB63Eb904776678286EF5cbe2a931B4f9A` | `0x31151be4bf8ff8e79f448872f9a0a5c37ee413ce7d2b15206f2debcc59d86ccc` |
| T | `ERC20Facet.sol`, `0x1d17acA0e0717d90cea916372070a1BE4652223F` | `0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50` |

Observed bytes equal archived on-chain bytes; archived published recompilation
bodies equal observed bodies after terminal CBOR removal. All four archives
say `match`, not `exact_match`. No new recompilation or complete transitive
source audit is claimed. The three proxies share runtime hash
`0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`;
their different loupe bindings determine behavior.

## 2. Fixed identities and noninterchangeable units

Let **M** be the actual registry-deployed Migration proxy/new DETF. Its current
Crane Ownable owner calls recovery on M; external legacy calls originate from
M, never the facet implementation, owner EOA or a helper holding no NFT.

| Identity | Fixed address / units |
| --- | --- |
| Earlier collection **NProxy** | `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391` |
| Earlier liquid DETF **Old** / NFT reward token | `0xaf0E1967c8F755c747615c5427108Bc549CA1122`, native 18 decimals |
| Earlier rebasing receipt **Receipt** | `0x4AC89aD061A531FA62ddceED53520C2750113b01`, 18 displayed decimals, separate share units |
| Physical reserve LP | `0x923877336b14662cFb5B3A60b14e7d716d54A888`, 18 decimals; remains in legacy NFT custody on sale |
| Legacy pair / receipt rate asset **DTF** | `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01`, 18 decimals |
| Disabled underlying SE | `0xb7D4Bb379d361aD442Cddee53EA71A33957826A7` |

`getPosition(id)` (`0xeb02c301`) returns exactly five static `uint256` words:
`originalShares, effectiveShares, bonusMultiplier, unlockTime, rewardDebt`.
`ownerOf(id)` (`0x6352211e`, ERC721 facet
`0xde5a691CEFE1830e8Ff2b65F6657738b0d9B9279`) returns one address word;
absence/burn may return zero. `originalSharesOf(id)` (`0x0f3767df`) is one
LP-accounting-share word, not a DETF balance. `pendingRewards(id)`
(`0x7dcb2abf`) is one Old amount word. `rewardToken()` (`0xf7c618c1`)
and `lpToken()` (`0x5fcbd285`) bind the identities above.

Original LP accounting shares are distinct from boosted reward weight and
physical LP obtained by `convertToAssets(uint256)` (`0x07a2d13a`). For accepted
ID 12, original shares `47848240999749918187208884` differ from observed LP
assets `47848240999749918187208985` (P5 contract and verification). Reward debt
is a checkpoint, not withdrawn principal. Neither Old nor Receipt is the
weighted 9-decimal DETF/sDETF or new 9-decimal Migration credit.

Preserve accepted surrender semantics: authenticated purchased IDs, not
reserved 0/1/2; live original shares equal the authenticated purchase baseline;
locked positions remain eligible; sale/burn clears the user identity. Recovery
never recalculates credit or changes that model. Current
`legacy/MigrationLegacyNftLib.sol:14-65` and
`UniswapV4DetfMigrationTarget.sol:67-106` implement the admitted distinction.

## 3. Preconditions shared by admitted recovery operations

1. Check the current M-local Crane owner and the existing shared reentrancy/
   child-accounting guards before external effects. Permissions persist after
   activation and follow actual ownership acceptance, not the initial owner,
   pending owner, fee recipient, creator or registry role.
   `MultiStepOwnableRepo.sol:107-111,253-263` is the real guard/transition:
   acceptance does not enforce the buffer/confirmation delay suggested by its
   comment. Do not repair Crane or base safety on an invented delay.
2. Select exact `(NProxy,id)` entries already surrendered to this instance:
   immutable consumed surrender record plus matching custody record and
   `ownerOf(id)==M`, positive admitted original units, and no prior sale.
   Consumption alone is insufficient for an unsolicited transfer. Use retained
   surrender/custody facts, not replaceable entitlement configuration, to bind
   recovery after activation or after an allowed configuration replacement.
3. Call only the fixed proxies/methods below with zero native value. Every
   reward, receipt or future output recipient is explicitly M. Expose no
   recipient, seller, arbitrary target, executor, adapter or calldata parameter.
   M grants no NFT approval or operator rights to the legacy owner/operator.
4. One selected transaction is atomic, including checks, all selected source
   effects and recovery bookkeeping. Propagate failure; no catch-and-count
   fallback. A later transaction's failure cannot erase an earlier committed
   claim or sale. Smaller retry is a separate selected transaction.
5. Preserve existing registry policy route by route. The direct legacy claim
   below contains no disabled-SE check; that does not enable an SE exit.
   Do not alter any registry, restore a retired family, or change M's existing
   surrender/donation disable checks to make recovery pass.

The integrated lane must prove owner changes, activation and hostile callback
behavior through actual installed M selectors. No phase01 EOA fixture proves
those checks exist. No Stage1/Stage2 recovery path may issue personal credit,
buy an ordinary bond, resize a delivered bond or reopen consumed entitlement.

## 4. Admitted stage ER1: claim Old rewards, retain NFT and proceeds

**Exact call:** M -> NProxy
`claimRewards(uint256 id,address recipient=M)`, selector **`0x6c7b69cb`**,
returns one `uint256 rewards` word (32 bytes), in Old native units.
This is the collection call, not the same-signature call on Old.

N:16413-16425 authorizes exact current NFT owner or the stored old DETF parent.
An approved NFT operator alone is insufficient (N:15222-15224 and historical
negative transactions). M is authorized because it owns the selected NFT.
No maturity or principal withdrawal is required.

The call updates NFT global rewards from newly observed Old held by NProxy
(N:15810-15824), computes the position entitlement and transfers Old to M,
advancing paid-per-share and debiting the tracked NFT reward balance
(N:16432-16454,16000-16012). Its Old `balanceOf` and `transfer` calls route to
T:3099-3101 and T:3060-3063; the claim trace reaches no missing old-DETF facet,
SE conversion or receipt liquidation.

Required local accounting:

```text
b0 = Old.balanceOf(M)
s0 = getPosition(id).originalShares
r  = NProxy.claimRewards(id, M)
deltaOld = Old.balanceOf(M) - b0
require deltaOld == r
require ownerOf(id) == M and getPosition(id).originalShares == s0
undonated[Old] += deltaOld
```

Store/emit actual token, ID and delta. No maximum whole balance is a claim.
A genuine zero reward may return zero and add zero inventory. Repeat may
claim new accrual only; source checkpointing and local deltas, not a permanent
"claimed forever" flag, enforce non-recounting. This is a source-derived
repeat contract; integrated repeated-claim coverage is still required.
Receipt valuation is not a prerequisite of this stage.

Pinned positive receipt: `0x5dfa0bfd67a8a62b6db4867245de7a3e2332195d97a75219bc0b6dd6e9ca1d45`
on the local fork, from EOA custodian `0x100000000000000000000000000000000000c001`.
ID 4 pays **309005608995105 Old**; original shares stay
**2281854312954086546**. Former-owner and approved-operator claims reject.
This establishes a callable claim-and-hold primitive, not M recovery execution
or successful conversion of that Old into DTF.

## 5. Admitted stage ER2: mature sale, burn NFT, retain Receipt

**Exact outer call:** M -> Old
`sellPositionToDetfNft(uint256 id,address recipient=M)`,
selector **`0x6b7d927e`**, returns one `uint256 principalShares` word.
**That return is original LP accounting shares, not receipt output.**

Require ER1's custody preconditions and `block.timestamp >= unlockTime`.
The M wrapper must enforce its selected deadline and minimum receipt-share
output itself: this old sale signature has neither argument. A separate ER1
claim is optional; sale itself harvests remaining Old rewards.

Caller graph and fixed recipients:

- D:25419-25447 forwards `seller=msg.sender=M`, `recipient=M` through
  D:22665-22690. Old -> NProxy calls the **three-argument**
  `sellPositionToDetfNft(id,M,M)`, selector `0x2115e3dc`, returning
  `(uint256 principalShares,uint256 rewardsClaimed)`.
- That child call is old-package-owner-only. M must not call it directly or
  impersonate the parent. N:16500-16546 also requires actual NFT owner equal
  to seller M, positive original shares, nonreserved ID and maturity.
  It pays Old rewards to M, removes the user position, moves principal-only
  accounting shares into protocol ID 0, clears the user fields and burns ID.
- Old -> Receipt calls
  `mintFromNFTSale(principalShares,protocolOriginalSharesBefore,M)`,
  selector `0x8d3c633c`, returning one displayed receipt amount word.
  R:10163-10184 mints proportional external shares into M. Physical reserve LP
  is not transferred to M. D:25444-25446 also updates bonded LP, fee/creator
  weight and attempts protocol compounding; failure of the enclosing sale
  must roll back the whole representation transition.

Measure Old balance and Receipt **`sharesOf(M)`** (`0xf5eb42dc`, one uint256)
immediately around the call. Require returned principal shares equal the
selected pre-sale original shares, positive new receipt shares meeting the
selected minimum, zero post-sale owner and all five position fields cleared.
Book the Old delta once and new receipt shares once, with a separate terminal
sale marker linked to the original custody identity. Keep the original
consumption, bond, holder, award and configuration-at-surrender history.
A duplicate sale must reject before counting anything.

R:9966-9975 reads external shares without a redemption-price call. R:9852-9877
uses `SHARE_SCALE=10^9`, `SHARE_UNIT=10^27`:

```text
internal shares from displayed amount = floor(amount * 10^27 / rate)
external shares = floor(internal shares / 10^9)
displayed balance = floor(internal shares * rate / 10^27)
```

Mint adds an integer number of external shares multiplied by `10^9`, so
`sharesAfter - sharesBefore` measures this sale even if M already holds
receipt fractions. Use this durable share inventory for holding. Record
displayed balances as valuations only; a sale/rate change can revalue older
receipt holdings and is not a second claim. A plain total ERC20 balance delta
is not sufficient provenance for newly minted receipt inventory.

Pinned local sale:
`0x3d54621af7e5dff968aed64f3639d0222170d962ead7c80339f39a33ede46042`.
ID 4 returns **2281854312954086546 principal shares**, burns, and delivers
**1967558883021387942 external Receipt shares** (displayed balance **4322**)
plus **309005608995105 Old**. This sale case begins before the separate
claim case; the two quoted reward amounts are not additive in one history.
Legacy physical LP remains **107516722668090845797720021675152213**.
Repeat sale rejects. Locked ID 3's early sale rejects.

This is a source-admitted **sale-and-hold**, not a forced sale requirement.
ID 3 may remain an NFT and use ER1. The successful sale trace observes
transitive LP/SE pricing and fee dependencies; their complete authentication
and different-state success are not inferred from that one trace. Price
reads may succeed while actual SE withdrawals remain disabled.

## 6. Blocked or unproved subsequent stages

| Stage / exact deployed operation | Source contract and admission disposition |
| --- | --- |
| Mature close: M -> Old `closeBondMature(id,[0,minDtf],M,deadline)`, `0x7c212893`, returns `uint256[]` | D:25644-25691 expects two slots, first minimum zero; nominal output is `[0,DTF]`, plus separately harvested Old rewards, not physical LP to M. **Not admitted:** actual call reverts `VaultDisabled(SE)`. |
| Parent receipt redemption: M -> Old `redeemClaim(amount,Old,minOld,M,deadline)`, `0xbfe55606`, returns one Old amount | D:25450-25509 accepts only Old as output. D:25707-25717 burns caller M's receipt shares via old-owner authority and removes protocol shares. **Not admitted:** actual call reaches the same disabled SE and rolls back. It is not direct Receipt -> DTF. |
| Direct receipt redemption: M -> Receipt `redeem(amount,M,false)`, `0x5236be40`, returns one pair-token amount | R:10194-10204,10382-10410 transfers M's self-token receipt internally, burns and calls Old `claimLiquidity`. The Solidity name `wethOut` does **not** change the observed rate asset: output would be DTF. **Not admitted:** actual call reaches the disabled SE; no successful output. `pretransferred=true` is no fallback (R:10419-10441). |
| Claimed Old -> DTF: M -> Old `exchangeIn(Old,amount,DTF,minDtf,M,false,deadline)`, `0xd02d3063`, returns one uint256 | D:25204-25236 selects D:25137-25174 primary burn, requiring live reserve and burning eligibility and invoking reserve withdrawal. No successful earlier-Old liquidation is proved by the consumed claim/sale receipts. **Unproved, not admitted**; do not substitute weighted success or assert a specific fresh revert not executed here. |
| Direct NFT `redeemPosition`/`retireMaturePosition`, direct LP withdrawal or receipt mint/burn administration | Legacy owner-controlled internals are not holder APIs. `retireMaturePosition(id,M)`, `0xe0c623c6`, returns two uint256 words and is called by Old, not M (N:16377-16404). Fungible LP owner-only failures remain separate phase01 findings. **No alternative route admitted.** |
| Donation into the same new DETF reserve | Fixed eventual destination is M's reserve through an actually supported, measured donation route. No earlier liquidation/donation success exists here; Old/Receipt are not automatically configured donation legs. **Not admitted as executed.** Holding is the terminal admitted result until a route is independently proved without policy changes. |

The exact observed disabled error is:

```text
0x1ba84b43000000000000000000000000b7d4bb379d361ad442cddee53ea71a33957826a7
VaultDisabled(0xb7D4Bb379d361aD442Cddee53EA71A33957826A7)
```

Pinned local failed transactions: mature close
`0x61fb08ec01b576756fa25ae3ab9631613f140471c843576a2eac3774a7ff37a1`;
parent receipt redemption
`0xe4359e06c585390d0c6e33cfb105c2384f58c4f9b44d75e1e0c566a2a97109e9`;
direct redemption
`0x22fb95c8bfd0b3f7c58faa20f4672371f4740ffb8a3276cccb3ff2a731880a0d`.
Each failed transaction preserves the recorded before/after state. These
isolated cases do not pretend to be a newly executed sale-then-redemption
sequence on M. Retaining earlier committed inventory on later failure is
also an integration proof obligation.

**Security/source blocker, not an authorization PASS:** D:25644-25691 has no
public holder check before its old-DETF-authorized child retirement.
N:16377-16404 checks existence/maturity, not the original external caller.
Wrong-owner close transaction
`0xbecb8677c003a5a4a58dfbc511237973681cb0250ba6a78fc6928ce1a03ab528`
reaches the same disabled-SE error. This masks authorization; no successful
theft or safe rejection by ownership is proved. M's own holder checks cannot
repair a separately callable legacy parent. Claim/holding admission does not
guarantee immunity if external legacy conditions later make this route work.
Do not enable the SE, remove the limitation, or market custody as globally safe.

Old-DETF facet `0x67ed019eC3f8b77Bc51ED1e6403Fc90E0aBb15bE`,
hash `0xa289425ebf221bd44551376c3459083a4d53eb30f485b48e783bf8291f7a05d6`,
still has archived Sourcify HTTP 404 for selectors
`0x6a4d3f12,0xf5ee7c5b,0x36abf3dc,0x7cc34bb4`.
It is not the authenticated claim/sale facet and is not reached in those saved
traces. This permits those bounded primitives, not blanket source acceptance
or an assertion that all transitive/future-state dependencies are audited.

## 7. Inventory, atomicity, cleanup and proof obligations

For each fixed source/position and token or explicitly denominated share unit:

```text
undonatedAfter = undonatedBefore
              + newlyReceivedClaims + conversionOutputs
              - conversionInputs - donations
```

ER1 increments only measured Old. ER2 increments measured Old plus minted
Receipt external shares; the retired NFT's original units are recorded as a
representation transition, never added numerically to token proceeds.
Holding changes neither balance attribution nor credit. Receipt price
movement is valuation of existing inventory, not a new receipt-share recovery.
Future conversion must debit only booked inputs and credit measured outputs;
Receipt and its eventual DTF output are never two recoveries.

Protect all preexisting balances: new DETF self-leg, funded bond/staking/SY
backing, reward rights, user packets, donation/residual budgets, unrelated
legacy custody and unsolicited assets. Keep recovery inventory separate from
`donationInventory`/`residualInventory` and respect operation floors
(`UniswapV4DetfMigrationRepo.sol:18-44`,
`UniswapV4DetfMigrationPolicy.sol:18-55`). Do not call the external contribution
surface as if its full balance were fresh donor input or release all inventory
into a sweep. A future actual donation transfers booked recovery inventory into
the existing fixed reserve accounting exactly once and creates no user award.
No receipt conversion dust or unbooked receipt fraction is spendable by inference.

ER1 and ER2 require **no M ERC20 allowance and no M NFT approval**. Keep them zero;
do not add approval-for-all "to help" sale. Old exercises its own legacy package
authority internally. Future separately admitted allowance-requiring operations
must approve only the fixed spender/exact booked amount and reset to zero on
success; a failed selected transaction reverts its temporary approvals.
No callback may reenter recovery, surrender, activation, donation or a child
money path under an in-progress operation.

Process only selected IDs, not all surrendered inventory. Duplicate selection
must not double-book: a second ER1 call can add only genuinely new rewards;
a second ER2 fails as already sold and rolls back that transaction. Integrated
coverage must include a failing middle item, smaller retry, partial/mature and
zero/repeated claims, earlier-stage persistence across later failure, existing
Old/Receipt holdings, unsolicited inventory, zero/short receipt-share sale,
fixed destinations and owner transfer before/after activation. Measure selected
batch gas against small/large unrelated populations. **No gas ceiling or
target-chain operational batch bound is derived by this source-only lane.**

## 8. Verification disposition and remaining gates

Offline audit: **50 checks, zero final failures**, covering ten selectors,
four runtime hashes/on-chain byte equalities and published execution bodies,
both saved historical pins, exact reward deltas, sale return/burn/share output,
unchanged LP custody, four disabled failures/rollbacks per run and cleanup.
The initial audit wrongly compared RPC hex chain ID to a numeric literal;
it failed before admission and was corrected to integer parsing. That harness
failure is retained in supporting evidence, not relabeled a product failure.

Both saved phase01 earlier runs retain **18 PASS, 2 FAIL, 4 UNPROVEN**;
independent replay exit **2**, overall **UNPROVEN**. This lane does not change
those verdicts. Accepted phase05 proves the two-generation NFT surrender into
real M, including earlier locked custody and original-share accounting.
It does not close phase07 harvest, source-policy, fungible ancestry or release.

Only this directory's `contract.md` and `source-evidence.json` were authored.
No compiler, test suite, RPC, local node, public operation, commit, delegation,
dependency/configuration or production/test edit occurred. Port 18556 was not
acquired; no owned runtime, temporary directory, approval or impersonation
needs teardown. Warm artifacts/cache and all prior evidence remain untouched.
JSON LSP is unavailable because `biome` is not installed; no installation is
authorized. JSON parsing, source-excerpt fidelity and final scoped diff/status
checks are the document/evidence validation, not a claimed clean LSP result.

Every other original source category remains required: both liquid DETFs,
both NFT models, weighted sDETF, earlier Receipt, SY, TokenStaking/claim-vault
rights, underlying SE shares and fungible LP. E1 remains partial, E2 is not
implemented here, and the broader harvest/donation, payout/activation matrix,
operator/resume, invariants/gas, full integration and F1-F4 release gates remain
open under their existing dispositions. No complete liquidation, full two-source
recovery, all-source recovery or deployment readiness claim follows.
