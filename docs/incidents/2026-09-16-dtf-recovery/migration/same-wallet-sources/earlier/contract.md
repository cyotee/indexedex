# Earlier sources: original-wallet implementation contract

Date: 2026-11-11. Evidence-only handoff; no runtime was started.

**All four assigned categories have usable custody primitives. None is an
implemented fungible Migration surrender route at this base.** Configuration
must bind the original acquiring/contributing wallet, original economic
entitlement and source-native eligible units. Missing records reject; current
balances do not manufacture them. Earlier receipt liquidation and earlier SE
exits retain the actual disabled-vault failures. Earlier fungible LP exits
retain the actual unsupported-route and legacy-owner restrictions. Earlier
liquid-DETF liquidation is unproved, not demonstrated disabled by a new probe.
Already accepted NFT reward claim-and-hold and mature sale-and-hold remain
distinct from those liquidation failures.

## 1. Authority, evidence roots and limits

Working checkout **W**:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-11-same-wallet-sources`.
Verified HEAD: `3f577eeca049c1bd70a812d130941c8a38dd4781`.
The prescribed dependency links were not changed. Status with
`--ignore-submodules=all` was clean before this document; ordinary status
initially exited 128, so it was not represented as a clean-status result.

Governing requirements are the complete
`/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase11-same-wallet-source-brief.md`
and main-checkout
`docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`,
revision `migration-detf-implementation-plan-r3-original-wallet-entitlement`,
especially sections 1.3 and 5.3-5.4. Historical any-holder/E2 ancestry verdicts
are preserved as historical results, **not current eligibility blockers**.
No intermediate-transfer reconstruction, native-prefix oracle, new wallet
history mechanism or execution-build attestation is required.

Evidence aliases below are absolute directory roots, not replacement sources:

| Alias | Directory |
| --- | --- |
| P1 | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence` |
| P7 | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery/docs/incidents/2026-09-16-dtf-recovery/migration/nft-recovery` |
| I | `/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery` |
| M | W's `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration` |

Load-bearing existing evidence:

- **CP source:** `P1/earlier-cp/probe-alchemy-retry.source.json`.
  `.contracts[lowercaseFacet].abi`, `.sources[file].content`, `.codeHash`,
  `.runtimeMatch` and `.proxies[lowercaseProxy].facets` identify actual
  source/ABI/routing. Flattened source line references below mean unescaped
  `.content` lines, not JSON serialization lines.
- **CP execution:** `P1/verification/cp-replay.json`, particularly
  `.checks`, `.transactions`, `.receiptCustody`, `.receiptRedemption`,
  `.directReceiptRedemption`, `.nftSale` and `.purchases`.
  Producer `P1/earlier-cp/probe-alchemy-retry.json` and
  `P1/earlier-cp/report.md` retain the original receipts and prior failures.
  Both completed suites retain **18 PASS / 2 FAIL / 4 UNPROVEN** and exit 2.
- **SE/LP execution:** `P1/verification/other-metered.json` and
  `other-metered.sources.json`, respectively `.cases[name]` and
  `.identities[address].bindings/metadata`. Here bracketed names/addresses
  denote array selection, not literal JSON object keys.
  The independent historical acquisition supersedes the producer's
  earlier HTTP 429 custody-acquisition limitation, not its product failures.
  It retains **21 PASS / 4 FAIL / 3 UNPROVEN**, exit 2.
- **LP native exit:** `P1/verification/native-replay.json`,
  `.cases[name="earlier fungible LP: native staged harvest"].evidence`;
  caller restriction, exact arguments, selector binding, failed receipt and
  zero deltas are recorded together.
- **Independent reconciliation:** `P1/phase01-verification.md`, sections
  B3 and 3, distinguishes usable custody from disabled/owner-restricted exits.
  `P1/provenance/report.md`, Contribution joins, Category coverage and Unknown
  values, distinguishes observations from original contribution records.
- **Accepted NFT recovery boundary:** `P7/verification/report.md`, section 2
  ER1/ER2 and blocked-stage rows, establishes real Migration claim-and-hold
  and sale-and-hold. Its weighted R1 finding was subsequently corrected in
  `P7/correction-verification/report.md`; neither report proves earlier
  liquidation. `P7/earlier/contract.md`, sections 4-7, supplies exact earlier
  call graphs and retained failed-transaction identities.

The independent P1 executions above use Robinhood chain **4663**, block
**108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
This is historical source evidence, **not** the new funded quote snapshot.
Fresh producer fallbacks remain separately labeled in their original reports.
No result, fingerprint, old failure or source has been rewritten.

## 2. Fixed identities and common ABI

Let **MIG** be the actual registry-deployed Migration proxy/new DETF, never
the owner EOA, facet implementation or an infrastructure impersonation.

| Name | Earlier-generation address | Native unit |
| --- | --- | --- |
| ED | `0xaf0E1967c8F755c747615c5427108Bc549CA1122` | Liquid earlier DETF, 18 decimals |
| ER | `0x4AC89aD061A531FA62ddceED53520C2750113b01` | 18-decimal displayed rebasing receipt; separate internal/external shares |
| ES | `0xb7D4Bb379d361aD442Cddee53EA71A33957826A7` | Underlying SE shares, 18 decimals |
| EL | `0x923877336b14662cFb5B3A60b14e7d716d54A888` | Fungible physical reserve LP, 18 decimals |
| EN | `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391` | LP-lock NFT; original accounting shares, not EL token balances |
| DTF | `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01` | Contribution/recovery asset, 18 decimals |
| WETH | `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` | Contribution/recovery asset, 18 decimals |

All four proxies have observed runtime hash
`0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`;
that common diamond body does not establish common behavior.

ED, ES and EL ERC20 `balanceOf(address)` (`0x70a08231`, one uint256),
`allowance(address,address)` (`0xdd62ed3e`, one uint256),
`approve(address,uint256)` (`0x095ea7b3`, bool),
`transfer(address,uint256)` (`0xa9059cbb`, bool), and
`transferFrom(address,address,uint256)` (`0x23b872dd`, bool) use the generic
ERC20 surface. The archived CP generic facet is
`0x1d17acA0e0717d90cea916372070a1BE4652223F`, runtime hash
`0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50`.
The CP `.proxies[ED].facets` ABI and other-metered ES/EL bindings identify
these primitives; `decimals()` is `0x313ce567 -> uint8`.
ER overrides the accounting/transfer surface with its own facet below.

The source archive labels the relevant CP facets `match`, not
`exact_match`. The unverified ED facet
`0x67ed019eC3f8b77Bc51ED1e6403Fc90E0aBb15bE`, runtime hash
`0xa289425ebf221bd44551376c3459083a4d53eb30f485b48e783bf8291f7a05d6`,
retains Sourcify HTTP 404 and selectors
`0x6a4d3f12,0xf5ee7c5b,0x36abf3dc,0x7cc34bb4`.
This limits complete source authentication; it does not erase separately
authenticated ERC20 calls or accepted EN claim/sale executions.

## 3. Shared original-wallet configuration and execution contract

These are required future semantics, not an existing fungible ABI:

1. Key each original economic entitlement by chain 4663, MIG, frozen snapshot,
   fixed source/category (and claim/position identity where applicable),
   original acquiring wallet and distinct original record ID. Retain the
   economic-origin collision identity across representations and independent
   compensation; a different token address is not proof of different exposure.
   A wallet may have multiple separately quoted originals. Selection cannot
   merge them before quoting or select another wallet's record.
2. Configure verified original wallet, original ETH/DTF components in native
   18-decimal units, knownness/evidence identity, source-specific original and
   remaining eligible units, unit discriminator, and computed frozen credit.
   Quote each original once on the unchanged post-funding snapshot:
   `C0 = U(ETH, originalEth) + U(DTF, originalDtf)`, native 9-decimal user-DETF
   output. No supplied output award, live exchange rate, LP value, old rewards,
   routed intermediate DTF or current balance substitutes for those inputs.
   Unknown is rejection, not zero. Known zero components remain valid.
3. In the protected surrender operation, require a nonempty matching
   configuration and `msg.sender == configured original wallet` **before**
   transfer, consumption or issuance. Require that wallet's actual control,
   its approval to MIG and positive eligible units remaining. Beneficiary
   and receiving custody are fixed to that wallet and MIG respectively.
   Ordinary transfers do not move configuration. Returning tokens to the
   original wallet requires no intermediate-holder proof, but restores no
   already consumed units or credit.
4. Use the plan's remaining-record arithmetic, after the source defines the
   measured unit `q`: with remaining eligible units `Q` and prequoted credit
   `C`, require `0 < q <= Q`; deliver `C` when `q == Q`, otherwise
   `floor(C*q/Q)` by full-precision mulDiv; store `Q-q` and `C-delivered`.
   Rounding residue stays in that record. A zero-credit operation reverts.
   Do not replace this with independent rounding of the original total on
   each call, or rerun the nonlinear original quote on a partial contribution.
5. Pull and measure the authentic source into MIG; record consumption and
   recovery inventory separately from donation, reserve and funded-bond
   backing. Create exactly one fresh, exactly funded bond for each successful
   surrender, for the same wallet, with its own 90-day clock. Any transfer,
   receipt/unit check, consumption, mint, stake or bond failure rolls back
   that entire transaction, including allowance changes made inside it.
   An earlier wallet approval transaction is not undone by a failed surrender.
6. Stage 1 replacement must retain surrendered units, delivered amounts,
   existing bonds and custody. Only the still-unconsumed portion can use
   corrected configuration; never pay `newTotal-oldPaid`, reopen a consumed
   original or count a claimed descendant beside its parent. Configuration
   selectors disappear at activation; configured surrender remains usable
   after activation without new admission approvals or trusted updates.
   Independent compensation remains recipient-keyed and **no-surrender**,
   not a workaround for absent source configuration.

No approved operational fungible-entitlement dataset was found in these
admitted artifacts. This is a concrete configuration limitation, not a demand
to repeat ancestry research. New records must supply the fields above before
operational loading; absent original records must reject.

## 4. Earlier liquid DETF

### 4.1 Exact ABI and source identity

ED's ERC20 routing is in section 2. Its core
`UniswapV4SingleStandardExchangeDETFFacet.sol` is archived at
`0x8333749Cc7b1f66b5be568257d362aA749497Cf0`, hash
`0x5b5f12902a0baeb235ec2dc91794c425a0c60a439a7d9070cb1abb17b094389d`.
Source lines 25204-25236 define
`exchangeIn(address,uint256,address,uint256,address,bool,uint256)`
(`0xd02d3063`) returning **one uint256 amountOut**, not the current
multiword exchange receipt used elsewhere.

### 4.2 Wallet/source key and original configured inputs

Use `(ED, original wallet, original entitlement ID)` within section 3's domain.
`I/positions.csv:384-389` has six earlier liquid observations with account,
source S010, raw quantity and `manual_cost_basis_required`; original
contribution fields and DETF-equivalent valuation are blank. Example account
`0x495d9d8bc7b1d00cfb3dfe8aa3666c64771910ed` has observed ED quantity
`675953787992657311713377297045`, not a proved original qualifying quantity
or original ETH/DTF input. The source exposes balances/allowances, not the
original wallet/contribution join. Do not borrow this wallet's EN purchase
inputs as cost basis for its whole liquid balance.

### 4.3 Native units and frozen-credit mapping

For an approved original ED entitlement, `Q` and `q` are native **18-decimal
ED token units**. Require exact debit/receipt deltas, cap by configured remaining
units and use section 3's partial-credit arithmetic. The missing numeric
mapping is each original's qualifying ED quantity and its verified original
ETH/DTF components; no common ED-to-new-DETF conversion rate is established.
The large observed balance above is not permission to set `Q` to that amount.
Old rewards recovered after EN surrender are recovery inventory, not another
personal liquid entitlement.

### 4.4 Custody, caller, approval and atomicity

Original wallet approves MIG on ED; MIG calls
`ED.transferFrom(wallet,MIG,amount) -> bool`. Measure both wallet debit and
MIG receipt equal to `amount`, then apply the immutable consumption ledger
and exact fresh-bond funding under one operation lock. Source transfer alone
has no Migration callback; a direct send followed by a second issuance
transaction does not satisfy atomic surrender.

### 4.5 Recovery and fixed destination

The source-observed candidate is MIG -> ED
`exchangeIn(ED,q,DTF,minDtf,MIG,false,deadline)`. Lines 25137-25174 require
a live reserve, burning eligibility, protocol LP and nonzero proportional LP;
they burn ED and invoke reserve withdrawal. No successful earlier-ED
liquidation exists in the consumed evidence. Do not label it PASS or assert a
newly observed revert. Hold measured ED separately; admit this conversion
only after actual-source execution and delta/rollback proof. Any future
allowance is exact, temporary and only to the fixed source spender, cleared
on success. Outputs remain at MIG for its fixed eventual donation route;
there is no arbitrary recipient or ordinary bond purchase with recovered ED.

### 4.6 Existing executable evidence and new tests

`CP execution .checks[name="liquid-DETF-custody"]` passes:
transaction
`0xb93cca719623ffb0014880437a5eabe5def921684a8d19fa3d6860e24b676f46`
transfers `1000000000000000000` ED from the observed wallet to the local
EOA fixture, with that exact receipt. This is **transfer**, not an executed
MIG `transferFrom` plus credit test.

Future tests: configured original wallet's approved pull and partial/remainder
delivery; unconfigured holder and transferred-to holder rejection before any
movement; transferred-back original wallet without credit reset; source
allowance failure; exact bond-funding failure rollback; separate reward
inventory versus personal credit; actual ED exit and rollback before any
liquidation claim. Shared postactivation/replacement tests are in section 9.

### 4.7 Disposition

**Usable legacy custody primitive; missing original configuration/unit
mapping; liquid recovery unproved.** Neither old E2 nor absent future
integration makes the ERC20 primitive unusable. Actual earlier liquidation
and operational allocations remain unaccepted.

## 5. Earlier rebasing receipt

### 5.1 Exact ABI and source identity

ER uses `RebasingClaimTokenFacet.sol` at
`0x25E611FB63Eb904776678286EF5cbe2a931B4f9A`, hash
`0x31151be4bf8ff8e79f448872f9a0a5c37ee413ce7d2b15206f2debcc59d86ccc`.
CP source `.proxies[ER].facets` binds the ERC20 transfer selectors to this
facet, not the generic ERC20 facet.

| Call | Selector | Exact archived return |
| --- | --- | --- |
| `sharesOf(address)` | `0xf5eb42dc` | uint256 external shares |
| `totalShares()` | `0x3a98ef39` | uint256 external shares |
| `redemptionRate()` | `0x540385a3` | uint256 WAD-denominated rate |
| `convertToShares(uint256)` | `0xc6e6f592` | uint256 external shares |
| `convertToClaim(uint256)` | `0x2fbc6fea` | uint256 displayed amount |
| `redeem(uint256,address,bool)` | `0x5236be40` | uint256 pair-token output |
| ED `redeemClaim(uint256,address,uint256,address,uint256)` | `0xbfe55606` | uint256 ED output; not direct DTF |

### 5.2 Wallet/source key and original configured inputs

Use `(ER, original wallet, original entitlement/claim ID)`, keeping the same
economic-origin collision key if this receipt represents an EN sale or other
already credited claim. `I/positions.csv:390-396` contains seven displayed
receipt observations, all `manual_cost_basis_required`; no configured
contribution/share basis follows from them. Example
`0xbedf78eb17a054d972c85ce222e2175f19899cd6` has displayed
`57038479047302700353` at the observed pin. CP `.receiptCustody.before`
also reads `25961984090715839942533986730135304` external shares.
Neither observation proves that whole amount qualifies for one original
entitlement. EN purchase records are useful original evidence only for their
specific exposure; converting an EN already consumed by MIG cannot create a
second ER award. The legacy receipt does not expose original payer identity.

### 5.3 Native/share units and exact missing mapping

Archived source lines 9609-9610, 9852-9878, 9966-9975 and 10125-10148 define:

```text
SHARE_SCALE = 10^9; SHARE_UNIT = 10^27
internalMoved = floor(displayedAmount * 10^27 / currentSourceRate)
externalShares = floor(internalShares / 10^9)
displayedBalance = floor(internalShares * currentSourceRate / 10^27)
```

These are source representation conversions, **not frozen compensation
valuation rates**. ER is not weighted sDETF; its units are not gons.

The exact unresolved credit inputs are (a) each original wallet's eligible
receipt-share denominator attributable to its original contribution, with
(b) verified original ETH/DTF components and (c) how sub-external-share
fractions are represented by that approved denominator. Existing records give
display balances, not this configured mapping. Therefore no operational
receipt `Q`, `q` or award is asserted here.

The public `sharesOf` floors internal shares. With existing fractional
inventory, `sharesOf(MIG)_after-before` can include a carry from MIG's old
fraction, and the sender's floored debit can differ. It is not automatically
the exact new internal receipt amount. The archive's ABI exposes external
share reads, not a public exact internal-share transfer/read used by this
evidence. A future measured-share adapter must establish conservative
attributed-unit/fraction accounting against the approved denominator before
using section 3's formula. Reject unresolvable/zero-unit cases rather than
spending unbooked fractions or pretending the displayed amount is exact.
This is a **specific unit-mapping/proof gap**, not renewed ancestry research.
EN sale mints whole external shares times `10^9`; that proven recovery
measurement does not by itself solve arbitrary ERC20 receipt transfer rounding.

### 5.4 Custody, caller, approval and rollback

Source lines 10100-10119: original wallet `approve(MIG,displayAmount)`,
then MIG `ER.transferFrom(wallet,MIG,displayAmount) -> bool`;
allowance is spent in displayed units and `_transfer` moves internal shares
at the source's current rate. Read wallet and MIG balances **and external
shares**, plus conversion observations, before/after. Do not require displayed
receipt delta to equal calldata or credit the calldata amount. Tie only
proved eligible shares to the record; final bond failure must revert the
source transfer and source allowance consumption. This caller-pull behavior
is source-observed; integrated receipt surrender remains unimplemented.

### 5.5 Recovery and retained actual failures

MIG -> ER `redeem(displayAmount,MIG,false)` nominally pays DTF, despite the
legacy return variable name `wethOut`. Source lines 10194-10204 and
10382-10410 move/burn receipt shares and call ED `claimLiquidity` for LP
unwind. ED `redeemClaim(displayAmount,ED,minEd,MIG,deadline)` is a different
route paying ED, source lines 25450-25509. Both actual attempts reach:

```text
0x1ba84b43000000000000000000000000b7d4bb379d361ad442cddee53ea71a33957826a7
VaultDisabled(0xb7D4Bb379d361aD442Cddee53EA71A33957826A7)
```

CP parent redemption
`0xe4359e06c585390d0c6e33cfb105c2384f58c4f9b44d75e1e0c566a2a97109e9`
is **FAIL**; direct redemption
`0x22fb95c8bfd0b3f7c58faa20f4672371f4740ffb8a3276cccb3ff2a731880a0d`
retains the historical **UNPROVEN** label with that same actual revert.
Assets/shares remain held; neither route is installed as an admitted
Migration liquidation stage. No pretransfer fallback, source-owner
impersonation or registry enable is permitted.

### 5.6 Existing executable evidence and new tests

CP `.receiptCustody` transaction
`0xd68774706044a88abb5a8455f466371da0244623dc5795b034aea8e26dcfbbd6`
successfully transfers displayed `1000000000000000000` at observed rate
`2197`, receiving displayed `999999999999999999` and external shares
`455166135639508420573509330905780`. That rounding is an actual result,
not a 1:1 policy. It is direct holder transfer, not integrated MIG issuance.
The receipt holder-sum/supply discrepancy in P1 remains unresolved; source
custody is not proof that all observed balances form approved allocations.

Future tests: approved pull through actual MIG; partial/remainder credit
using an approved share denominator; nonzero preexisting fractional custody
and unrelated receipt inventory; both directions of floor carry; source rate
movement without repricing C0; no double credit after EN sale/claim; zero
share/zero credit rejection and failed funding rollback; disabled conversion
preserves already committed custody and earlier successful recovery stages.
Do not rerun the unchanged disabled probe as new successful coverage.

### 5.7 Disposition

**Usable receipt-transfer primitive; missing approved contribution/share
mapping and fractional measurement proof; concrete disabled liquidation
dependency.** Accepted EN sale-and-hold books actual external receipt shares
without granting another personal entitlement. No complete receipt-source
support or harvest-to-DTF PASS is asserted.

## 6. Earlier underlying SE shares

### 6.1 Exact ABI and runtime identity

ES is identified by ED `standardExchangeVault()` /
`standardExchangeVaultShare()` and other-metered `.graph`/`.identities`.
Its ERC20 bindings are section 2's generic facet.
`exchangeIn(address,uint256,address,uint256,address,bool,uint256)`
(`0xd02d3063`) binds to
`0x461D94f18AfeF2C82bBffBDb63270e37c322da07`, hash
`0xd0deae3d6c52c409c2f4a57c57b81e27167dffacbca6056e81c5a18f0e879a53`.
Its `vaultTokens() -> address[]` lists WETH and DTF.
Neither ERC4626 `redeem(uint256,address,address)` (`0xba087652`) nor
`redeem(address,uint256,address,uint256,bool)` (`0x769f8e5d`) is bound.
Do not invent an ERC4626 exit.

The existing runtime evidence identifies exact exchange calldata and failed
receipts; it does not establish a successfully decoded legacy exchange
return schema. No present success decoder is authorized from that failure.
Current multiword SE interfaces are not legacy ABI proof; successful
conversion/return validation would be required before admitting an exit.

### 6.2 Wallet/source key and original configured inputs

Use `(ES, original wallet, original acquisition ID)` in section 3's domain.
P1 provenance Category coverage records **zero standalone SE position rows**,
not proof of no exposure. Existing custody uses ES held by EL, not an original
user purchase. Configuration therefore still needs the actual original
qualifying wallet, original native ES quantity and original ETH/DTF inputs.
An infrastructure balance or approval is not such a record. No record means
rejection; no all-zero approved allocation is inferred.

### 6.3 Native units and frozen-credit mapping

ES is 18-decimal **vault shares**, not 18-decimal DTF, WETH or EL. For a
verified configuration, `q` is exact ES received and debited, bounded by its
configured remaining ES units; section 3's arithmetic distributes the frozen
credit. The missing numeric mapping is original eligible ES units to that
original economic quote, not a missing ERC20 transfer method. Neither live
redemption price nor ES total supply supplies it.

### 6.4 Custody, caller, approval and rollback

Actual original wallet approves MIG on ES; MIG pulls
`ES.transferFrom(wallet,MIG,q) -> bool`, checking exact wallet/MIG deltas.
In `other-metered.json`, named case
`earlier underlying SE: partial exact custody` uses infrastructure holder
EL, takes `2402083350942343165016427703439986226` ES and leaves
`237806251743291973336626342640558636382` there; MIG-like EOA custody
receives exactly q. Transaction:
`0xec2ebbf5c36f0a606f7afc4fee3373679f54ee37c04a2cc1071c784b4db33a54`.
Unauthorized pull rejects; named failed-transfer outer-rollback case passes.
This authentic mechanism does not prove a user can command EL to approve
anything; no EL or other infrastructure impersonation is an eligibility path.

### 6.5 Recovery and fixed custody

Tested exits are fixed ES exact-in calls with ES input, output WETH or DTF,
recipient the recovery custodian, `pretransferred=false` and a deadline.
`earlier underlying SE: harvest` is **FAIL**, with exact
`VaultDisabled(ES)` bytes in section 5.5. Custody q remains unchanged and
output deltas are zero. Preserve staged ES holding in MIG; no successful
conversion or donation is asserted. A future admitted conversion must
consume only booked shares and send measured output to MIG's fixed recovery/
donation accounting, never reissue personal credit.

### 6.6 Existing executable evidence and new tests

Historical independent custody, approval-negative and outer rollback pass;
harvest fails. Eligible end-user exposure and original configuration are
absent, not proved impossible. Future tests must use an approved original
wallet record with real control (not an infrastructure impersonation), prove
configured pull/partial credit/remainder/funding rollback, preserve disabled
exit failure and protect unrelated ES inventory. If no approved original
user record exists, configuration loading rejects; it must not erase the
required category or fabricate a user fixture as operational proof.

### 6.7 Disposition

**Usable legacy custody primitive; missing original-wallet acquisition/unit
configuration; concrete disabled ES exit.** The generic implementation gap
is finite and distinct from those unavailable operational inputs.

## 7. Earlier fungible LP

### 7.1 Exact ABI and runtime identity

EL is ED `reservePool()` and EN `lpToken()`, independently observed in P1.
Its ERC20 bindings are section 2's generic facet. Exact-in exchange
`0xd02d3063` binds to
`0x6B771DD3Fa9d577B5A7f3b52Eb95234DA5FB5E0f`, hash
`0x57ae69f784fdfe10d2d94f0625f6edc92f37510453500e697b257b8fb2b40a7f`.
`withdrawSeShares(uint256,address,uint256,uint256,uint256)` (`0x84eb9bce`)
binds to `0x81Fb72511016B42437FE1ac2d5Bdb0bA82f14A35`, hash
`0xca224a1792b0b9339c1c5c999c4d5e99bd33f25f8387da864d6eabb4d1d6b398`.
`exitProportional` (`0x8b72d9e5`) and `exitProportionalFlexible`
(`0x94b74d12`) have zero bindings on EL.

The local matching-signature interface
`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol:164-170`
declares `(uint256 amountRaw,uint256 amountSe)` for `withdrawSeShares`;
the current target at `:492-499` is restricted by `onlyLiquidityRemover`.
This explains a candidate two-word schema, **not byte-identical legacy source
or a decoded successful legacy return**. Existing runtime tests reverted
before any output; admitting a successful decoder/route requires its own
source/receipt evidence. The exact currently retained blocker needs no
invented success ABI.

### 7.2 Wallet/source key and original configured inputs

Use `(EL, original wallet, original acquisition ID)`, **not EN tokenId**.
P1 provenance has zero standalone fungible LP rows, not proof of absence.
The actual holder fixture is EN escrow. It proves EL mechanics only; end
users cannot be presumed able to approve on EN's behalf. Required
configuration is original acquiring wallet, qualifying EL token quantity,
original ETH/DTF contributions, evidence identity and frozen credit basis.
Do not use `earlier-cp-bonds.csv.original_lp_shares_raw` as this quantity.

### 7.3 Native units and frozen-credit mapping

EL uses 18-decimal physical LP token units. EN's `originalShares` are a
separate accounting claim on pooled LP, `effectiveShares` are boosted reward
weight, and ER external shares are another representation. P7 earlier
contract section 2 retains EN ID 12 original shares
`47848240999749918187208884` versus physical LP conversion
`47848240999749918187208985`; they are observably not identical.
For an approved direct EL entitlement, `q` is the exact EL token receipt,
not any of those other share types. Section 3 distributes frozen credit
against configured EL `Q`; original qualifying EL units/contribution
mapping is currently missing.

### 7.4 Custody, caller, approval and rollback

Original wallet approves MIG; MIG calls `EL.transferFrom(wallet,MIG,q)`.
Named historical case `earlier fungible LP: partial exact custody` passes
for `q = 1075167226680908457977200216751522`; EN escrow falls from
`107516722668090845797720021675152213` to
`106441555441409937339742821458400691`, custody gains q.
Transaction:
`0x0ec294a95fd119e4074bb0dfd475998d985bcf8588d36b5bcd5c00c151cbaf03`.
Unauthorized pull rejects and the named outer-rollback case passes.
The integrated original-wallet pull, consumption and funded bond remain
future work; an infrastructure fixture is not proof of user authorization.

### 7.5 Recovery and actual source-owner errors

Exact-in EL exits to ED and DTF fail `UnsupportedRoute()` (`0x5d5fe824`).
The actual native exit from new custody,
`EL.withdrawSeShares(q,custody,0,0,deadline)`, fails
`NotOwner(custodian)` (`0x245aecd3`). EL `owner()` (`0x8da5cb5b`)
returns ED, **not EN and not MIG**. `standardExchange()` (`0xafe78a3b`)
returns ES. Earlier EL `ownerOnlyLiquidity()` is unbound; do not copy the
weighted LP's true flag onto EL.

The independent native failed receipt is
`0xef58704e0f466bc121512b940c5b31e13434c28f3581071ada88a53965565e0e`
at the historical pin; the producer's separately pinned native failure
`0x1fc18e1c68581f11d2eab00d4e6ee1020bd699dd6d4b124f1bd5e92726ab9b36`
is retained, not substituted for it. Native-replay's before/after/received
maps show unchanged custodied EL q and zero outputs. Receipt ownership does
not confer the old contract-owner role. No legacy-owner-mediated direct
fungible EL recovery is proved; do not route a user's EL through EN sale,
impersonate ED or install a generic executor. Hold EL at MIG until a finite
admissible owner-mediated recovery is actually evidenced.

### 7.6 Existing executable evidence and new tests

Authentic approved custody, wrong-operator rejection and outer rollback
pass. Both tested liquidation modes fail as above. Future tests are:
approved direct original-wallet EL exposure and configured partial/remainder
credit; absent-record/wrong-wallet rejection; exact funding failure rollback;
explicit rejection of confusing EN tokenId/accounting shares with EL units;
preserved `NotOwner`/`UnsupportedRoute` failures without changing owner;
no donation/credit from the unchanged EL inventory on failed harvest.
An alternative liquidation proof is a separate missing source path, not
permission to repeat unchanged failed probes or imply success.

### 7.7 Disposition

**Usable legacy custody primitive; missing standalone original acquisition/
unit configuration; concrete new-custodian liquidation blocker.**
No category omission, zero-exposure assumption or source substitution follows.

## 8. LP-lock NFT and accepted claim-and-hold boundary

EN remains a distinct required category handled by its own surrender lane.
It is included here to prevent an invalid shortcut for these four fungibles.
`getPosition(uint256)` (`0xeb02c301`) returns five uint256 words:
`originalShares,effectiveShares,bonusMultiplier,unlockTime,rewardDebt`;
none is fixed funded-DETF principal or a generic claimed-principal field.
The accepted adapter requires actual positive original accounting shares
equal to the purchased baseline, allows still-locked custody and consumes
the whole identity; sale/burn clears it. The fixed-principal NFT fraction
must not be transplanted onto EN reward weight or physical LP value.

`I/evidence/earlier-cp-bonds.csv:2-17` supplies the 16 purchased EN IDs 3-18,
recorded wallets, original LP accounting shares, direct DTF/WETH and
purchase transactions. CP `.purchases` independently verifies the receipts.
For ID 3, wallet `0x495d9d8bc7b1d00cfb3dfe8aa3666c64771910ed`,
original shares `562524912595035608166`, direct WETH
`2000000000000000000`, direct DTF `0`; routed DTF
`1778859964387451305574664` is **not** another contribution.
For ID 4, wallet `0x230f95db9644c5b3608ba676d18426d03e435b1d`,
shares `2281854312954086546`, direct DTF
`7215852540309913726431`, direct WETH `0`.
These inputs do not assign that wallet's independent liquid/receipt balances
to this same contribution. Native ETH not reconstructed in provenance remains
unknown; WETH purchase evidence is not invented native-value evidence.

P7 independent section 2 confirms actual MIG:

- `EN.claimRewards(id,MIG)` (`0x6c7b69cb -> uint256 ED`) claims while
  retaining NFT ownership and original accounting shares. Locked ID 3
  pays `124873542679524901` ED, zero repeat and later genuine accrual;
  mature ID 4 pays `309005608995105` ED.
- `ED.sellPositionToDetfNft(id,MIG)` (`0x6b7d927e -> uint256 retired
  original accounting shares`) is optional after maturity. Its child
  three-argument call `0x2115e3dc` is ED-only, not a MIG holder API.
  ID 4 retires `2281854312954086546` original shares, clears/burns the
  identity and delivers `1967558883021387942` external ER shares.
  EL remains in legacy custody. No MIG NFT approval is needed for these
  admitted recovery calls.

MIG fixes all receivers to itself, measures ED deltas and ER external shares,
and books these as **recovery**, not fresh compensation. The current recovery
enum admits EarlierClaim/EarlierSale but no earlier liquidation stage.
ED rewards and ER shares remain held. A failed later batch cannot undo
earlier committed claim/sale transactions; a failed step rolls back all steps
of its own transaction.

Mature close `ED.closeBondMature(id,[0,minDtf],MIG,deadline)`
(`0x7c212893 -> uint256[]`) retains the disabled ES failure:
`0x61fb08ec01b576756fa25ae3ab9631613f140471c843576a2eac3774a7ff37a1`.
Archived core source 25644-25691 lacks a public holder check before
old-parent-authorized child retirement. Wrong-owner close
`0xbecb8677c003a5a4a58dfbc511237973681cb0250ba6a78fc6928ce1a03ab528`
also reaches the disable error. **Ownership safety is masked, not passed.**
Bounded claim/sale admission neither proves theft nor guarantees safety if
legacy conditions later change. Do not enable ES or erase this qualification.

## 9. Current code seam and finite future integration

Source observations at verified W base (paths relative to M):

| Current location | Observed seam | Narrow future change |
| --- | --- | --- |
| `interfaces/IUniswapV4DetfMigration.sol`, `NftEntitlementInput` and `NftEntitlement` | Original collection/id, units, contributions/evidence; **no original wallet field** | Add original acquiring wallet to configured source records and their configuration identity; do not derive it from current `ownerOf` |
| Same interface, `IndependentAllocationInput` / `OriginalEntitlement` | Recipient-keyed no-surrender configuration; no fungible source/units consumption API | Keep independent compensation separate; introduce only finite fixed-source fungible configuration, queries and measured surrender semantics from section 3 |
| `UniswapV4DetfMigrationAllocationTarget.sol`, `configureNftEntitlements` | Quotes known original inputs, records collection/id config; cannot bind original wallet | Validate/store original wallet from approved original records before activation; do not populate from a current holder read |
| `legacy/MigrationLegacyNftLib.sol:46-67`, `preview` | Rejects missing config/consumed/invalid position; returns current owner and credit | Retain those rejections and add original-wallet identity to the surrender authorization path |
| `UniswapV4DetfMigrationTarget.sol`, `surrenderMigrationNft` | Requires `msg.sender == holder_`, then safe-pulls; any configured current holder can currently reach custody | Require matching recorded original wallet as well **before** `safeTransferFrom`; bind bond receiver to it. No unconfigured fallback |
| `UniswapV4DetfMigrationRepo.sol`, `Storage` | NFT config/consumption/custody and independent allocations are separate; no per-original fungible Q/C ledger | Add separate source-native fungible remaining units/credit and immutable delivered/custody facts; preserve collision checks with independent/NFT exposure |
| `UniswapV4DetfMigrationAllocationTarget.sol`, `_administrationSelectors` | Removes six current admin selectors at activation | Include new configuration selectors in removal and interface/package wiring; leave only configured surrender/queries/recovery available |
| `UniswapV4DetfMigrationRepo.sol`, `_fundBond` | Exact mint, temporary child approval, fresh migration position, approval clear | Reuse after measured surrender; failure reverts custody/consumption and does not issue a stub/empty bond |
| `UniswapV4DetfMigrationRecoveryTarget.sol` and `legacy/MigrationLegacyRecoveryLib.sol` | Fixed EarlierClaim/EarlierSale; recovery custody tied to immutable NFT surrender, inventories segregated | Preserve accepted stages; book future standalone ED/ER/ES/EL custody separately in correct units. Do not admit disabled/unproved conversions merely to create an enum row |

The four fungible routes are **ordinary finite implementation work once
their required configuration/unit inputs exist**. There is no missing
ancestry verifier to design. Conversely, adding this configuration seam does
not repair the actual disabled ES or confer ED's EL-owner authority.

Required new integration coverage, in the repository's Migration tests,
after a separately authorized implementation:

| Test set | Observable obligation |
| --- | --- |
| Wallet/config boundary, all four sources and both NFT models | Correct original wallet with approved record succeeds only for controlled units; missing config and a different approved/current holder revert with no balance, allowance, consumed credit, supply or bond changes |
| Source and record isolation | Wrong token/category/claim/original ID cannot select another record; wrong chain/source identity rejects; balances alone never create configuration |
| Partial/remainder/rounding | Apply section 3 Q/C formula for each selected original; exact final remainder pays remaining credit; zero-credit surrender reverts; ordinary transfers neither move nor reset the record |
| Receipt precision | Source-native share mapping, preexisting internal fractions, floor carries, rate movement and mixed inventory cannot add credit or spend unbooked receipt value; no synthetic receipt model substitutes for actual source |
| Atomic funded issuance | Approved pull, consumption and exactly backed fresh 90-day bond succeed together; transfer, minimum, unit check and bond funding failures each restore the operation; later surrender creates a distinct clock |
| Stage 1 replacement and activation | Replace full config without changing delivered facts/bonds; apply corrections only to unconsumed exposure; remove all new configuration selectors irreversibly; same configured wallet can surrender before and after activation |
| Representation/independent separation | EN-to-ER sale and claimed ED do not reopen parent exposure or create a second independent award; wallet transfer cannot carry another wallet's configured credit |
| Recovery preservation | Accepted EN claim/sale-and-hold stays working; disabled ES/receipt and owner-restricted EL failures keep inventory intact; only measured booked proceeds ever enter fixed donation custody |

These are specified tests, **not executed results**. No new generic native
surface, transfer-history or gas investigation is part of this handoff.

## 10. Complete assigned-category disposition

| Required category | Custody/claim primitive | Exact remaining blocker or implementation input |
| --- | --- | --- |
| Earlier liquid DETF | Actual 18-decimal transfer passes; fixed approved pull is source-defined | Missing per-original wallet/contribution/native-ED mapping and fungible integration; earlier ED liquidation has no passing execution |
| Earlier rebasing receipt | Actual rounded displayed-token transfer/internal-share movement passes; accepted EN sale mints measurable external shares | Missing approved original share denominator/contribution mapping and fractional-transfer measurement proof; actual receipt liquidation reaches disabled ES |
| Earlier underlying SE shares | Actual approved ERC20 pull and outer rollback pass | Missing original user acquisition/native-share config; infrastructure fixture is not user authority; actual WETH/DTF exits fail `VaultDisabled(ES)` |
| Earlier fungible LP | Actual approved ERC20 pull and outer rollback pass, distinct from EN | Missing original direct-LP acquisition/native-token config; exact-in fails `UnsupportedRoute`, native share exit fails `NotOwner(custodian)` with ED owner; alternate owner-mediated route unproved |
| Earlier LP-lock NFT, boundary retained | Existing purchased-accounting-share surrender, ER1 claim-and-hold and ER2 mature sale-and-hold | Current config lacks original-wallet binding; earlier liquidation/authorization qualifications remain. This contextual row does not replace the separate NFT category |

Every assigned category therefore has either a finite custody/configuration
implementation contract or an exact source/unit blocker above. This is not
all-source support, complete recovery, an allocation approval, a gas verdict
or deployment readiness. The held phase09 work was neither inspected nor
resumed.

Only this owned `earlier/contract.md` was authored. No production, script,
test, configuration, dependency or prior evidence edits; no compile, test,
RPC, node, deployment, transaction, commit or delegation. No owned runtime,
port, temporary execution root, approval or impersonation requires teardown.
