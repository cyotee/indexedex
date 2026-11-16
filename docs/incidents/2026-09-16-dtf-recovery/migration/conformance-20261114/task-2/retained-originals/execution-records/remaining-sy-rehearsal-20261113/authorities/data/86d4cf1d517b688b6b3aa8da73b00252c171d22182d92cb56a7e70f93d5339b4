# ED original-unit, custody and recovery contract

Date: 2026-11-12. Producer source proposal, not implementation authorization.

**Custody and native-unit mapping: admitted-proposal. ED-to-DTF conversion:
not-ready at the fixed historical state.** A genuine approved contract pull
works with exact native18 debit and credit, including partial/terminal units
and late rollback. The single meaningful ED exit actually reaches disabled
ES; there is no successful conversion return, proceeds or donation to admit.
Independent admission belongs to the separate `source-verification/` lane.

## 1. Authority and bounded domain

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid-source`.
Base: `acdbe319f3a20c3af6bea594c62461b6c7988717`.
This older source-only base is not future cumulative implementation delivery.
Any later implementation needs the then-current audited cumulative base in a
separate worktree; it must preserve ER work without importing this branch as
its cumulative replacement. Phase18 changing outputs were not read or edited.

The complete phase19 brief governs. Current main plan
`migration-detf-implementation-plan-r5-owner-first-bond` sections 1.3-1.5 and
5.1-5.4 and PRD `migration-detf-discussion-r22-owner-first-bond` govern
eligibility, units and credit. The complete phase11 earlier contract and its
independent report/matrix, phase01 actual CP source/execution/provenance and
phase07 earlier recovery evidence were consumed. Phase17 final runtime and
immutable commit audits establish the fixed base, not ED conversion.
Exact input paths, raw UTF-8 byte lengths and SHA-256 are in
`source-evidence.json:inputs`.

All legacy evidence and new probes use chain **4663**, block **108944663**,
hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
That source-state pin is not the new post-funding quote snapshot.

| Symbol | Fixed identity | Unit |
| --- | --- | --- |
| ED | `0xaf0E1967c8F755c747615c5427108Bc549CA1122` | Liquid earlier DETF, native18 |
| DTF | `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01` | Recovery/contribution token, native18 |
| ES | `0xb7D4Bb379d361aD442Cddee53EA71A33957826A7` | Underlying SE, distinct from ED |
| EL | `0x923877336b14662cFb5B3A60b14e7d716d54A888` | Physical reserve LP, not eligible ED units |
| EN | `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391` | Earlier LP-lock NFT, not a liquid original |
| M | Future genuine registry-deployed Migration proxy | Fixed custody and eventual donation destination |

ED is neither native9 WD/new-DETF credit, ER receipt shares, NFT original or
effective accounting shares, nor physical EL. No decimal conversion, gon
mapping, receipt index or redemption valuation defines ED eligibility.

## 2. Actual deployed source and ABI

`source-evidence.json` retains the actual archived ABI, compiler metadata,
published source/body comparison, excerpts and historical execution.
`run-02/identity.json` binds fresh pinned selector routing and actual runtime
bytes to that archive. The generic ERC20 facet is
`0x1d17acA0e0717d90cea916372070a1BE4652223F`, runtime Keccak
`0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50`.
Core ED facet is `0x8333749Cc7b1f66b5be568257d362aA749497Cf0`,
runtime Keccak
`0x5b5f12902a0baeb235ec2dc91794c425a0c60a439a7d9070cb1abb17b094389d`.
The proxy runtime Keccak is
`0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`.

| Method | Selector | Exact return |
| --- | --- | --- |
| `balanceOf(address)` | `0x70a08231` | One uint256 ED native amount |
| `allowance(address,address)` | `0xdd62ed3e` | One uint256 ED native amount |
| `approve(address,uint256)` | `0x095ea7b3` | One bool |
| `transfer(address,uint256)` | `0xa9059cbb` | One bool |
| `transferFrom(address,address,uint256)` | `0x23b872dd` | One bool |
| `decimals()` | `0x313ce567` | One uint8, observed 18 |
| `exchangeIn(address,uint256,address,uint256,address,bool,uint256)` | `0xd02d3063` | One uint256 amountOut, only on success |

Flattened archived `ERC20Facet.sol:2582-2592,2683-2694,2722-2728,3060-3085`
spends the caller's allowance, debits sender and credits recipient exactly.
This source subtracts even a maximum allowance; do not assume an infinite
allowance exception. An earlier separate approval transaction persists if a
later pull reverts, while that pull's allowance consumption rolls back.

Archives say `match`, not `exact_match`. Observed on-chain bytes match the
retained runtime; published recompilation execution bodies match after only
the terminal CBOR region is removed. No fresh legacy rebuild is claimed.
Missing optional facet `0x67ed019eC3f8b77Bc51ED1e6403Fc90E0aBb15bE`
and its four excluded selectors retain the historical source-404 qualification.
This is not a complete transitive source audit.

## 3. Original record, known inputs and frozen credit

For each distinct original, configure a nonzero original acquiring wallet,
chain/source/kind, original record/evidence identity, canonical economic origin,
positive original eligible ED quantity `Q0`, explicitly known original ETH and
DTF components `E0,D0` in native18, and the frozen-snapshot identity.
Unknown is rejection, never zero. Known zero components are valid.

The wallet-containing record lookup and wallet-independent canonical-origin
collision key are separate. Correcting a wallet during Stage1 must not
manufacture a distinct origin or evade independent/NFT/descendant collision
checks. Require origin separation in both directions against every supported
representation and independent compensation, including already-issued facts.
Opaque documentary aliases still require operational reconciliation.

Quote each original once against the same immutable post-funding book `S`:

```text
C0 = U_S(ETH,E0) + U_S(DTF,D0)       // new-DETF native9 user output
initial (Q,C) = (Q0,C0)             // Q is ED native18; C is native9
```

`U_S` is the existing frozen user-mint evaluator, including its pair routes,
scales, provider/nested quote state, fee and seigniorage rounding. Neither
caller-supplied output credit, live ED price, current balances, LP value,
routed intermediate DTF nor old rewards replaces E0/D0 or that evaluator.
Do not merge separately quoted originals before a nonlinear quote.
Configuration itself issues nothing.

There is no approved numerical operational liquid-original dataset in the
admitted evidence. Six observed ED holdings do not establish original Q0 or
cost basis. Another EN purchase by the same wallet cannot supply the liquid
balance's original components. This input limitation is not a new product
choice or a reason to remove the category.

ED rewards received after compensating an NFT are recovery inventory, not
another personal liquid original. A source transfer does not establish
historical economic disjointness.

## 4. Exact Q0/Q/q and atomic surrender

Require finalized Stage2, a matching frozen record, caller equal to its
recorded original wallet, and actual control and approval before effects.
Stage1 rejects surrender before custody or consumption. Its real paid
current-owner first ordinary bond remains a prerequisite of atomic activation;
activation opens ordinary deposits/surrender/rewards and permanently removes
all loaders/amendment and discretionary issuance selectors. No partly used
migration record can be amended.

For requested positive native ED `n`, M calls
`ED.transferFrom(originalWallet,M,n)`. Require bool true and:

```text
q = ED.balanceOf(wallet)_before - ED.balanceOf(wallet)_after
q = ED.balanceOf(M)_after - ED.balanceOf(M)_before = n
require 0 < q <= Q
delivered = C                       if q == Q
delivered = floor(C*q/Q)            otherwise, full-precision mulDiv
require delivered > 0
(Q_after,C_after) = (Q-q,C-delivered)
```

For this ED contract, all `Q0,Q,q,n` are the same native18 token unit, with
no flooring carry or hidden receipt fraction. Terminal q==Q is exactly
representable when the wallet controls that many ED units. Returning ED to
the original wallet needs no transfer-history reconstruction and restores
no consumed eligibility or credit. Other holders do not inherit its record.

One successful operation must atomically establish custody, debit this
record, mint/fund exactly delivered credit and create one fresh 90-day-cliff
bond for the same wallet. Check missing configuration/wrong wallet before
the source pull. Zero credit, insufficient balance/allowance, unit mismatch,
funding or callback failure reverts the whole operation. Use the existing
shared operation guard and actual child funding path; no direct-send/later
issuance substitute. These are future integration obligations, not methods
implemented by the disposable helper.

The genuine code-proof acquisition measured
`Q0=1000000000000000000000000`. Actual approved partial
`q1=400000000000000000000000` leaves `Q=600000000000000000000000`;
actual terminal `q2=600000000000000000000000` leaves Q=0 and allowance=0.
An arithmetic-only C0=1001 example delivers 400 then 601, leaving C=0.
**1001 is a synthetic already-quoted parameter, not a funded-snapshot quote,
known historical cost basis, issued bond or operational award.** The contract
requires actual known E0/D0 and evaluated C0 before operational loading.

## 5. Recovery holding and finite exit disposition

Admit measuring/bookkeeping of actually surrendered ED at M as recovery
inventory, separate from personal credit. Protect unsolicited ED, existing
NFT reward inventory, unrelated sources, donations and new bond/backing
budgets. The probe's preexisting 7e18 ED is unrelated inventory, not an
actual Migration NFT-reward ledger. Existing phase07 claim-and-hold remains
independently accepted; it is not silently retested or replaced here.

The only investigated exit is:

```text
M -> ED.approve(ED,q)
M -> ED.exchangeIn(ED,q,DTF,minDtf,M,false,deadline)
M -> ED.approve(ED,0)                // only after success
```

Use only booked positive input, fixed caller/source/DTF/recipient, positive
minimum and valid selected deadline. No pretransfer bypass, arbitrary route,
executor, governance change or old-owner impersonation is admitted.
Archived core `:25204-25236` selects primary burn for self-token input,
`:25023-25035` pulls through ED self-allowance, `:25137-25174` checks live
reserve/burning eligibility, sizes nonzero protocol LP, burns and withdraws,
and `:24894-24900` calls EL `withdrawSingle`.

**Not-ready:** the actual `q=100000000000000000000000` exit, min=1,
deadline=1794114512, from the owned helper to itself reaches EL withdrawal,
then ES `exchangeIn`, whose registry query returns disabled=true.
Receipt `0x32fef16e3be33c26d73ab92174023ddc65be4266765a66774a54bc8b0455a9fc`
has status0 and exact revert:

```text
0x1ba84b43000000000000000000000000b7d4bb379d361ad442cddee53ea71a33957826a7
VaultDisabled(0xb7D4Bb379d361aD442Cddee53EA71A33957826A7)
```

Burning was allowed, pending expansion was zero and proportional LP sizing
was `213783542190031470635423511`, not zero. The trace passes the approved
ED pull and reaches withdrawal. This is a structural disabled dependency at
this pin, not an amount/rounding rejection and not a copied ER finding.
All effects, including temporary allowance, ED pull/burn and LP movement,
roll back; actual DTF received is zero. Revert bytes are not an amountOut.
No successful conversion decoder, successful late-after-conversion rollback
or resulting donation is claimed.

## 6. Preservation and future acceptance

Keep previously committed custody/claims when a later recovery transaction
fails. Within a selected transaction, propagate failure and roll back every
step. Recovery accounting remains:

```text
undonatedAfter = undonatedBefore + measuredClaims + conversionOutputs
                - conversionInputs - donations
```

Never spend total raw balances as booked inventory, reissue personal credit
for reward receipts or conversion output, or buy ordinary bonds with recovery.
The fixed eventual destination remains M's supported reserve-donation path.
ED conversion cannot be installed as a demonstrated successful stage from
this evidence. A future source-state change or genuinely supported route
requires its own successful burn/debit, exact one-word return versus actual
DTF, unrelated-inventory floor and late rollback evidence.

Actual Migration original-wallet/configuration/origin checks, frozen quoting,
remaining-credit storage, funded bonds, owner recovery, activation and
donation integration were not executed here. Custody admission does not
remove those requirements. The independent verifier must rerun decisive real
custody and preserve the exact blocked conversion disposition.

Retain the unrelated missing-facet and masked mature-close authorization
qualifications separately. This proposal gives no all-source, ER/SE/LP,
raw-weight, operational-allocation, archive-portability or deployment-gas
acceptance. Parent gas 44,353,454 versus 32,000,000 remains open.
