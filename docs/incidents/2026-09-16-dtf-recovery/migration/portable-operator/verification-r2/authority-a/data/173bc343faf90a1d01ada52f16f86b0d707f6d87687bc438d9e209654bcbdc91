# Earlier ER receipt: eligible units and custody contract

Date: 2026-11-12. **Producer disposition: admitted-proposal.**
This is one source-backed normalization for independent admission, not an
independent admission verdict or permission to implement. Custody and
proportional frozen-credit measurement are supported within the exact
measurement domain below. Earlier receipt liquidation remains disabled.

## 1. Authority, identity, and evidence

The governing main-checkout files are
`docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`,
revision `migration-detf-implementation-plan-r5-owner-first-bond`, especially
sections 1.3-1.5, 3/E1-E2, 5.1-5.4, 5.6, and 8.2, and
`MIGRATION_DETF_DRAFT_PRD.md`, revision
`migration-detf-discussion-r22-owner-first-bond`. The plan's later
original-wallet, remaining-credit, Stage2-only surrender, immutable activation,
and paid owner-first-bond rules supersede conflicting historical prose.

Read the complete phase18 brief, phase17 final runtime report and immutable
commit receipt/audit, phase11 earlier contract and independent report/matrix,
and the referenced phase01 and phase07 evidence. `seal.json` binds their exact
paths and bytes. Historical wallet-less implementation seams are not current
code. Earlier preactivation surrender and partly consumed amendments are not
part of this contract.

Only this source is newly proposed:

| Item | Binding |
| --- | --- |
| Chain and block | 4663 / 108944663 |
| Block hash | `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733` |
| State root | `0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071` |
| ER proxy | `0x4AC89aD061A531FA62ddceED53520C2750113b01` |
| ER proxy runtime keccak256 | `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601` |
| Receipt facet | `0x25E611FB63Eb904776678286EF5cbe2a931B4f9A` |
| Facet runtime keccak256 | `0x31151be4bf8ff8e79f448872f9a0a5c37ee413ce7d2b15206f2debcc59d86ccc` |
| Parent ED | `0xaf0E1967c8F755c747615c5427108Bc549CA1122` |
| Rate/recovery asset DTF | `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01` |
| Disabled underlying ES | `0xb7D4Bb379d361aD442Cddee53EA71A33957826A7` |

`run-03/identity.json` authenticates the actual pin, proxy, complete loupe,
13 selected methods, facet bytes, decimals, parent, and rate asset.
`proof.json` compares those actual facet bytes with both archived observed
and archived on-chain bytes. The archived source qualification is **match**,
not exact_match. No new historical recompilation or complete transitive source
audit is claimed.

Source archive A is
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/earlier-cp/probe-alchemy-retry.source.json`.
References R below are unescaped lines of
`A.contracts[0x25e611fb63eb904776678286ef5cbe2a931b4f9a].sources[RebasingClaimTokenFacet.sol].content`.
`source-evidence.json` retains the exact excerpts and runtime bindings.
The original archive remains at its bound path.

## 2. Actual callable surface and units

| Call | Selector | Return and unit |
| --- | --- | --- |
| `sharesOf(address)` | `0xf5eb42dc` | uint256, floored external ER shares |
| `totalShares()` | `0x3a98ef39` | uint256, floored external ER shares |
| `redemptionRate()` | `0x540385a3` | uint256, source rate r |
| `balanceOf(address)` | `0x70a08231` | uint256, displayed native18 ER |
| `convertToShares(uint256)` | `0xc6e6f592` | uint256, floored external shares |
| `convertToClaim(uint256)` | `0x2fbc6fea` | uint256, displayed ER |
| `approve(address,uint256)` | `0x095ea7b3` | bool; allowance in displayed ER |
| `allowance(address,address)` | `0xdd62ed3e` | uint256, displayed ER |
| `transferFrom(address,address,uint256)` | `0x23b872dd` | bool; input in displayed ER |

Let `S=10^9`, `U=10^27`, and `I_a` be an account's actual internal ER shares.
These are not WS gons, WY shares, earlier NFT original LP-accounting shares,
physical LP, DTF, or new native9 DETF credit.

```text
sharesOf(a) = floor(I_a/S)
balanceOf(a) = floor(I_a*r/U)
transferFrom(w,M,n) moves t = floor(n*U/rTransfer)
I_w_after = I_w_before - t
I_M_after = I_M_before + t
```

R:9604-9637, 9835-9877, 9953-9982, and 10116-10147 establish these
transitions. R:6541-6546 uses full-precision floor multiplication/division.
R:7875-7884 spends exactly n allowance, including when the allowance was
uint256 maximum; there is no assumed infinite-allowance exemption.

The transfer has no recipient callback, no reward synchronization, no mint,
no burn, no total-share change, and no full-balance special case. Its rate
calculation uses static source calls, then it changes only allowance and the
two internal-share accounts. A transfer event reports n, not t. The ERC20
display delta need not equal n.

**There is no admitted public exact internal-share getter.** The probe's
`eth_getStorageAt` reads are diagnostics, never an implementation primitive.
Nor does `convertToShares(n)` return exact internal shares.

## 3. One original allocation and normalization

Use **exact internal ER ownership-share units** for Q0, Q, q and the new
standalone ER custody attribution. This retains every source fraction rather
than rounding a received external-share delta into an award. The source
ownership invariant and the plan's source-unit and conservation requirements
derive this normalization. It is not a selectable pricing mode or dust policy.

Each original record must supply:

* Fixed chain, ER identity and unit discriminator; original acquiring wallet;
  wallet-independent canonical economic origin and original record identity;
  snapshot and evidence identities.
* Explicitly known original ETH and DTF contributions, each native18.
  Verified zero is valid; unknown is rejection. Routed intermediate DTF is
  not another contribution.
* Original eligible internal shares Q0, positive, with its documented receipt
  allocation. Where the allocation includes a larger receipt acquisition T0,
  retain the exact partition `T0=Q0+excludedOriginalInternal`; identify rewards
  and other excluded exposure separately. No current wallet balance or
  supply discrepancy fills these fields.
* The original operation's native input and rate/measurement evidence for a
  transfer-derived allocation, or its authenticated minted external shares
  times S for a mint-derived allocation. Never replace an unavailable original
  operation rate with today's rate.

Original eligibility is not inferred from the recovery inventory's unit.
Q0 must correspond to the original contribution being quoted. It cannot be
chosen or resized to make a current transfer divide evenly.

For the source's earlier NFT sale, the archived child
`DETFNFTVaultFacet.sol:16500-16546` returns principal-only original accounting
shares and separately harvests rewards as ED. The parent at
`UniswapV4SingleStandardExchangeDETFFacet.sol:25419-25446` invokes that sale.
ER R:10163-10184 mints an integer external quantity times S. The minted ER
claim and separately paid ED rewards must not both receive the full original
credit. A Migration-owned NFT already compensated and later sold produces
recovery inventory only; it cannot reopen a standalone ER entitlement.

Ordinary ER rate growth changes displayed value without changing internal
ownership shares. It creates no additional Q0 or C0. Reward-only possession
without an eligible original configuration rejects. Additional tokens acquired
by the wallet do not expand the cap. Current control is required, but no
transfer ancestry or identification of fungible "molecules" is introduced.

Quote each original exactly once:

```text
C0 = U_frozen(ETH, originalEth) + U_frozen(DTF, originalDtf)
Q  = Q0 - cumulativeEligibleInternalSharesConsumed
C  = C0 - cumulativeFrozenCreditDelivered
```

`U_frozen` is the existing post-funding snapshot mint evaluator from plan
section 5.2, including its exact route, fee, seigniorage and user-output
rounding. It is unrelated to the source constant U=10^27 above. Production
loading computes C0; it does not accept a supplied award. Do not quote reduced
partial components or merge originals before their nonlinear quotes.

No operational ER allocation dataset is approved by this evidence.
The source probes' acquired quantities and C0 arithmetic parameters are
explicit synthetic originals, not reconstructed historical ETH/DTF awards.
The future implementation must require actual known components and compute
their C0. This source-only proof does not exercise that already separate
snapshot evaluator or mint a compensation bond.

## 4. Exact callable measurement without an internal getter

Let M be the future actual registry-deployed Migration proxy. Within its
shared protected operation, after Stage2/configuration/original-wallet checks:

1. Read r, both endpoints' external shares and displayed balances, and total
   external shares. Require r>0 and n>0. Calculate candidate
   `q=floor(n*U/r)` using full precision; require `0<q<=Q` and positive credit.
2. M calls only fixed ER `transferFrom(originalWallet,M,n)` and requires true.
   Approval is the original wallet's real displayed-unit allowance to M.
   There is no pretransferred mode or alternate recipient.
3. Read the same public observations immediately afterward, before bond
   funding or any other external mutation. Require unchanged r and total
   external shares, nonincreasing wallet observations and nondecreasing
   custody observations.
4. Define public external-share deltas:

```text
d_w = sharesOf(wallet)_before - sharesOf(wallet)_after
d_m = sharesOf(M)_after - sharesOf(M)_before
a   = floor(q/S)
b   = q mod S
```

   Each delta must be a when b=0, otherwise a or a+1. **Do not book either
   delta times S**, take their minimum as q, or require the two deltas equal.
5. Prove that these public observations uniquely determine the rate used
   inside the authenticated transfer, not merely a compatible external floor:

```text
dMax = max(d_w,d_m)
dMin = min(d_w,d_m)
require dMax > 0
L = (dMax-1)*S + 1
H = (dMin+1)*S - 1
require L <= H

rLow  = floor(n*U/(H+1)) + 1
rHigh = floor(n*U/L)
require rLow == rHigh == r
```

   Checked uint256 interval arithmetic and full-precision mulDiv are required;
   overflow, zero denominator or an unresolved interval reverts the whole
   operation. There is no ceiling/clamp of custody or consumption.
6. As additional consistency checks, both displayed endpoint deltas equal
   `floor(q*r/U)` or one more, with the extra one permitted only when
   `mulmod(q,r,U)>0`. Do not use displayed deltas as compensation units.

### Why the interval test proves exact q

For any actual positive internal transfer t, each endpoint's unknown
fraction lies in `[0,S-1]`. A measured external delta d therefore implies
`(d-1)S+1 <= t <= (d+1)S-1`, intersected with t>=0. Applying both endpoints
gives `[L,H]` above when dMax>0. The authenticated transfer always uses
`t=floor(n*U/rTransfer)` for some positive integer source rate.

Inverting that floor yields exactly:

```text
L <= floor(n*U/rTransfer) <= H
iff
floor(n*U/(H+1))+1 <= rTransfer <= floor(n*U/L)
```

If this integer interval is the singleton r, then the actual movement is
exactly q. This does not require either starting fraction, a diagnostic
storage read, or the assumption that all source quote calls took the same
fallback. R:10372-10379 and 10446-10498 contain caching and caught quote
fallbacks: equal pre/post rate reads alone are not presented as an independent
proof of the rate used in the middle. The inverse interval closes that
measurement weakness for accepted calls.

The real pinned witnesses pass this singleton test at r=2197 and r=4046.
Other source states whose public observations cannot resolve it reject
atomically. This is a measurement-validity condition, not a change to Q0,
pricing, entitlement expiry, forfeiture, or permission to spend uncertainty.

## 5. Conservation, partial credit, and inventory separation

After exact q is proved, apply the plan's recurrence:

```text
credit = C                    if q == Q
credit = floor(C*q/Q)          otherwise
require credit > 0 and credit >= minimumCredit
Q_after = Q-q
C_after = C-credit
B_after = B+q
```

B is booked standalone ER internal shares. Deliver exactly credit into one
fresh, exactly funded bond for that same wallet, with its own creation time
and full 90-day cliff. No callback or funding failure may commit source
custody, allowance spending, consumption, local inventory or issuance.
An approval transaction completed before surrender is not undone.

The exact source equations apply to the measured pull interval; the Q/C
equations are the inductive entitlement invariant after each successful
surrender:

```text
wallet internal debit = custody internal increase = q
(I_wallet + I_M)_after = (I_wallet + I_M)_before
Q + cumulative q = Q0
C + cumulative credit = C0
(I_M - totalBookedInternal)_after
    = (I_M - totalBookedInternal)_before
```

Thus existing internal fractions, prior NFT-sale inventory, unrelated tokens,
and unsolicited ER never become newly booked or credited. A rate move does
not alter these equations. Sender floor borrow and recipient floor carry
change displayed observations, not the amount attributed to this operation.
The configured cap is necessary even when the source could satisfy an
over-cap request using the wallet's other holdings.

Subsequent bond callbacks cannot reopen the guarded migration operation or
spend its ER. If a callback independently sends additional ER to M, that is
unbooked inventory, not another q; the full-transaction unbooked floor must
not decrease. Do not interpret the interval equality as prohibiting an
unrelated donation later in the transaction or as permission to book it.
Any failed enclosing transaction still rolls back all of its source effects.

**Preserve the accepted earlier NFT-sale inventory's units.** At the accepted
base, `MigrationLegacyRecoveryLib.sol:260-283` records newly minted ER in
external shares, and `IUniswapV4DetfMigrationRecovery.sol:67` documents that
query unit. For future integration under this contract, keep that existing
NFT external-share inventory E separate from new standalone internal B.
Add a separately named retained query for B; do not add B to E or silently
change the old query's unit.

```text
totalBookedInternal = E*S + B
standalone whole external representation = floor(B/S)
standalone fractional internal representation = B mod S
```

The fraction remains booked ownership, not dust donated to another domain.
NFT sale adds whole external shares, so its existing delta remains exact
even when B contains fractions. Recovery growth values already booked
ownership; it is neither a new surrender nor another personal award.
No conversion/debit path is admitted by this contract. Any later source
conversion must prove its actual internal debit fits totalBookedInternal and
leaves unrelated internal ownership intact.

## 6. Exact terminal representability and retained residue

A terminal operation requires actual q==Q, not displayed balance zero,
`floor(Q/S)==0`, or "all currently visible units." For a given rate r an
exact candidate is `n=ceil(Q*r/U)`, calculated with full precision. It is
terminal only if n>0, `floor(n*U/r)==Q`, the wallet can actually transfer it,
and section 4 proves the actual movement. Do not substitute
`floor(Q*r/U)` as the maximum transferable input: this source can sometimes
transfer one more displayed unit than `balanceOf` reports.

A split can leave internal residue even when the original acquisition was
exactly representable. Preserve both Q and C when no valid next transfer
fits Q. Do not send an extra displayed unit, clamp q to Q, reset consumption,
clear a zero display, forgive the residual, or promise future rate movement
will make it representable. A zero-credit partial reverts without custody.

Executed examples:

| Witness | Exact result |
| --- | --- |
| Genuine acquisition of 4394 displayed ER at r=2197 | Q0=2*10^27 internal shares; synthetic C0=1001 |
| First approved pull of 2197 | q=10^27; credit500; Q=10^27,C=501 |
| Second approved pull of 2197 | q=Q; credit501; Q=C=0; old custody fraction unchanged |
| Genuine acquisition of 2197 at r=2197 | Q0=10^27; synthetic C0=1000000000 |
| Pull1 then pull2196 | Credits455166 and999544833; **Q=1,C=1 remain** |
| Further input1 against that remainder | Rejected by the cap despite sufficient unrelated wallet inventory |
| Separate controlled empty wallet, acquisition2197, transfer1 then2196 | Actual internal1 remains, display0; a further source transfer1 fails |

These are different synthetic originals with actual source acquisitions, not
denominators imposed on operational users. The one-unit residue is preserved,
not an unsatisfied conservation invariant. No current requirement demands
paying C without valid corresponding surrender. Disabled liquidation, missing
operational allocations and future unresolvable measurement states remain
distinct limitations, not reasons to silently delete the category.

## 7. Actual endpoint and rate witnesses

Controlled original wallet:
`0x33b1ce5357959ec0043e0d77556a5093ab347862`, public development mnemonic
derivation181. Its approvals and pull calls are signed, not impersonated.
The source donor is the existing EOA
`0xbedf78eb17a054d972c85ce222e2175f19899cd6`; its real ER is transferred on
the local fork. No source balances, code, storage or roles are injected.
Gas funding is an actual development-account transfer, not a source-state edit.

The mixed original acquisition is input10000 at r=2197:
`Q0=4551661356395084205735093309`, synthetic C0=1000001.
Unrelated receipt custody is an earlier real input1 transfer:
`455166135639508420573509` internal shares, fraction420573509 modulo S.

| Operation | q internal | Public wallet debit / custody credit |
| --- | ---: | --- |
| input4, wallet fraction735093309 | 1820664542558033682294037 | 1820664542558033 / 1820664542558034 |
| input1 afterward, wallet fraction52799272 | 455166135639508420573509 | 455166135639509 / 455166135639508 |

The first raw recipient delta overstates the transfer by317705963 internal
units if multiplied by S. The second raw sender delta overstates it by579426491.
The proposed mapping books neither excess. It delivers400 then100; the same
unrelated custody quantity survives both operations exactly.

In `run-05`, the controlled wallet acquires DTF through an actual existing
weighted-liquid swap solely as probe funding. It transfers100*10^18 DTF to
the earlier ES whose DTF balance the actual ER rate trace reads. This is an
ERC20 donation, not an ES exit or governance action. The real ER rate rises
**2197 -> 4046**, without changing total ER internal shares.
The subsequent input1 pull moves
`247157686604053386060306` internal units and delivers54 from the remaining
frozen credit. Original Q0 and C0 stay fixed; the earlier unrelated internal
quantity remains unchanged. This uses ER throughout; no WS gon measurement
or WS surrender is substituted.

`proof.json` records both inverse-rate bounds as2197 or4046 for all eight
successful helper pulls, plus all eight no-effect failures and32 decoded
signed operations. Six actual helper runtime bindings match the compiled
1568-byte runtime outside only compiler-declared constructor immutable spans.
`ReceiptCustodyProbe.sol` is a disposable source witness, **not Migration**.
Its deliberate late failure occurs after real transferFrom and local Q/C/B
writes. It proves source transaction rollback, not an implemented funded-bond
callback. Real Migration funding/callback verification remains a later gate.

## 8. Lifecycle and independent implementation admission boundary

Any later implementation must retain:

* Owner-only complete/idempotent Stage1 loading, known original components,
  no issuance on configuration, and canonical-origin exclusions against
  independent compensation, both NFT models, WD, WS, WY, W-SD and direct
  claim-vault shares, including wallet corrections.
* Stage1 rejection before any surrender effect; the real paid owner-first
  bond prerequisite; atomic Stage2 opening and permanent removal of all
  loading/amendment/discretionary issuance routes.
* Stage2 original-wallet-only actual control, protected exact approved pull,
  positive/capped q, frozen remaining-credit arithmetic, minimum/deadline
  protection, same-wallet fresh funded cliff bond, and full source/funding/
  callback rollback. Transfer away/back neither moves nor resets the record.
* Separately typed held inventory and correct operator preparation, ABI,
  source evidence, query, resume and receipt reconciliation. Actual registry
  package deployment, artifact-first Solar tests and real size limits.

No such production, existing-test or operator change was made here.
Independent source-verification must admit this actual contract before any
integration. The independent lane owns `source-verification/`, not this lane.

## 9. Conversion and other categories remain explicit

The retained phase01 parent `redeemClaim` failed transaction
`0xe4359e06c585390d0c6e33cfb105c2384f58c4f9b44d75e1e0c566a2a97109e9`
remains **FAIL**. Direct ER `redeem` transaction
`0x22fb95c8bfd0b3f7c58faa20f4672371f4740ffb8a3276cccb3ff2a731880a0d`
retains its historical **UNPROVEN** label and actual identical error:

```text
0x1ba84b43000000000000000000000000b7d4bb379d361ad442cddee53ea71a33957826a7
VaultDisabled(0xb7D4Bb379d361aD442Cddee53EA71A33957826A7)
```

Neither was rerun or relabeled. No success decoder, pretransfer fallback,
generic executor, source-owner/governance impersonation or registry enablement
was introduced. Custody admission is not conversion support or full recovery.
Earlier NFT claim-and-hold and sale-and-hold remain separate accepted stages.
The missing optional ED facet and masked mature-close holder-authorization
qualification remain the historical limits, not newly resolved findings.

Both liquid generations, both NFT models, both receipt models, SY, raw
TokenStaking, claim-vault rights, all three SE rows, both fungible LP rows,
and native ETH/WETH exposure remain in the plan. Earlier liquid conversion,
disabled SE/receipt exits, source-owner-restricted LP exits, raw-claim atomic
pull limits, operational original datasets, opaque-origin reconciliation,
archive portability and target deployment gas remain separate open matters.
No held09 work, public operation or production implementation is included.
