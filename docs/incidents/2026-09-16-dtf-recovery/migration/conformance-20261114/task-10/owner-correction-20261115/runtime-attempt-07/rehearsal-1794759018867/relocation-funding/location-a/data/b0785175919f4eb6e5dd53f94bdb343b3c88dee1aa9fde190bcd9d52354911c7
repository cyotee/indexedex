# Complete-original claimed-SY candidate admission contract

Date: 2026-11-12. Subject: unchanged
`4eaa7decab80d24cf37cb3781eff5ffaf9362942`.
**Disposition: bounded admitted-proposal for the complete-original subset
below, not operational admission, implementation authorization, or closure
of the raw TokenStaking category.**

## 1. Proposition actually tested

A recorded original wallet can consume all of a separately established
eligible native18 weight original through the deployed Wrapped-phase
TokenStaking source, receive native9 SY itself, and measure the complete
descendant quantity before Stage 1 configuration. One candidate SY record
can then retain that original's identity and complete original contribution
inputs. This avoids needing an inherited-credit field only when the entire
original is represented, none of its credit was previously delivered, and
all overlapping representations are excluded.

The new witness establishes the source mechanics using real source holdings
and signed controlled-wallet claims. Its allocation of eligible versus
unrelated weights is disclosed synthetic bookkeeping, not historical
eligibility. It does not establish any operational original's wallet,
contributions, eligible weight, previous compensation, or economic aliases.
Those remain required reviewed owner inputs. The source has no original
contribution registry.

The current loader does not verify the proposed parent-to-descendant
certificate. This is a candidate intake contract for that offchain gate,
not a claim that ordinary SY support already admits raw-weight descendants.

## 2. Fixed source, phase, units and evidence

Only Robinhood chain 4663, block 108944663, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`
was forked. The disposable endpoint was `http://127.0.0.1:18572`.
This historical source pin is not a funded Migration pricing snapshot.

| Item | Exact source contract or behavior |
| --- | --- |
| Weight source T | `0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00`; caller-owned native18 accounting weights, not ERC20 |
| T phase and backing | Actual `phase()` = 2, Wrapped; `claimVault()` = V |
| Claim vault V | `0xAf5C0cD3fDEdd10bee00Eff77Fa0429Bacdb41f0`; actual decimals 19; source-held shares are infrastructure backing, not direct user shares |
| Vault asset Y | Actual `asset()` = `0xB55604CF4dcdABB362078e106D20F98512391EdF`; actual SY decimals 9 |
| T reassignment | `reassign(address,uint256)`, selector `0xcc447fba`, no return; consumes caller balance and credits recipient balance, with associated reward bookkeeping |
| T claim | `withdrawClaim(uint256)`, selector `0xa224dcb7`, one uint256 SY return; consumes caller weight and sends SY to that same caller |
| Vault redemption | `redeem(uint256,address,address)`, selector `0xba087652`, one uint256 SY return; actual nested calls use receiver = claimant and owner = T |
| Direct approved raw pull | T's `approve` and `transferFrom` routes are absent; retained caller-negative evidence remains controlling |

All three proxies have code hash
`0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`.
T's balance, supply, phase, vault, preview, reassign and claim routes bind to
facet `0x9C90d4a476f3473b9a0e32B530aF3474271a80B1`, code hash
`0x5628dcb4bb0a1a24e6bde3b985f92c2ef0894ddd6006a55ddaffccc877a52742`.
Vault redemption/preview bind to
`0x517234F78A4BcAfc5F880024A3E45D49cF43b305`, code hash
`0x8c1ea71d607b09b21c4e78f850647a059dc7935b6772f7cd3aeaa700a995439f`.
SY balance/transfer routes bind to
`0x4b6e65cfc9a16aae0dfa4257a680f4697275e5fc`, code hash
`0x6da9227c829765d0464b5eeee02c55ea45883e3af2767aea546f5e906e8b143d`.
Complete runtime bytes, selector bindings and the historical header are in
`raw/source-identities.json`; post-witness runtime equality is recorded in
`raw/reconciliation.json`.

Current explanatory `TokenStakingTarget.sol:184-209,289-306` describes
caller-only reassignment and `floor(q*V/T)` source-share redemption, with a
whole-supply special case. Its `:132-147` describes preview behavior.
Current `RebasingAwareERC4626Common.sol:146-159` describes the vault
conversion arithmetic. These current files are not byte-identical legacy
proof: the retained TokenStaking facet archive reports no source match.
Actual deployed calls, traces, receipts and measured deltas establish the
bounded observations here. No new metadata/IPFS request was made.

## 3. Required original and preparation certificate

Use W0 for the original eligible native18 weight and Q0 for its **measured
native9 claimed SY**, never interchange them. C0 is the native9 new-DETF
credit computed once from the original contributions on the funded frozen
snapshot. It is not a weight/SY conversion rate.

| Required field or fact | Authority and rejection boundary |
| --- | --- |
| Canonical original identity | Reviewed operational economic-origin identity, domain-bound to chain, Migration instance and snapshot; wallet-independent, shared across all representations |
| Original acquiring/contributing wallet | Reviewed original qualifying record, not current `balanceOf`, reassignment recipient, configurator or signature alone |
| Original contributions E0 and D0 | Verified historical ETH/DTF native18 components, explicitly known, including known zero; preserve original grouping and exclude routed intermediate double counts |
| Eligible original W0 | Reviewed positive original source-unit allocation, with original-versus-reward and unrelated exposure partition; current weight alone is insufficient |
| Prior delivery and competing representations | Evidence that delivered compensation for this origin is zero and no independent, NFT, receipt, liquid, vault-share, LP, backing or SY claim separately carries its credit |
| Preparation transaction set | Exact unique source transactions, chain/block/hash, successful receipts, actual signer/caller, fixed source routing, calldata q, source weight/supply debit, vault share debit, same-caller SY output/return/event |
| Completeness | Sum of eligible consumed raw weights is exactly W0, with no omission, duplicate transaction, unrelated/reward inclusion or surviving eligible part; all associated outputs remain accounted to the original wallet's controlled eligible SY budget |
| Descendant quantity Q0 | Sum of actual eligible SY outputs from that complete set, preserving each operation's rounding; positive, with excluded preexisting SY separately budgeted |
| Evidence identity | Nonzero commitment to the complete original and preparation certificate, not a claim that an evidence hash makes its contents true |

The owner supplies and reviews the historical/eligibility/origin partition.
Chain evidence supplies source identity, live control, caller signatures,
consumed q, actual outputs, receipts and rounding. Neither replaces the
other. Do not manufacture a missing original from the witness donation.

Preparation is complete when eligible-remaining-weight = 0, **not** when the
wallet's total weight is zero. Unrelated weights may remain. Conversely, a
positive SY balance or positive first output does not prove completeness.
The signed witness has both positive unrelated weights and preexisting SY.

The eligible output budget is Q0, not total wallet SY. The source is
fungible: this certificate partitions measured quantities and origins, not
serial-numbered SY coins or a requirement to reconstruct intermediate
holders. Actual control and the same configured wallet are still required
at surrender. Later unrelated acquisitions do not increase Q0 or C0.

## 4. Exact subset and reject cases

1. **Complete one-claim preparation:** admit only as a proposal when the
   certified eligible claim consumes W0 and its exact positive SY output
   is Q0. Keep complete E0/D0 and zero delivered credit.
2. **Complete split preparation:** aggregate unique eligible source claims
   under the same origin. Require `sum(q_i) = W0`, then set
   `Q0 = sum(actual SY_i)`. Do not assume this sum equals a hypothetical
   one-shot claim, and do not separately load each slice with full E0/D0.
3. **Incomplete preparation:** reject this shortcut while
   `sum(q_i) < W0`, even with positive SY. Record both prepared units and
   remaining eligible weight. Attaching full original contributions to
   only the first descendant subset would overassign credit.
4. **Repeated preparation:** never append the same transaction twice or
   create a second origin. Additional source operations are eligible only
   within previously unprepared W0. A claim against unrelated surviving
   weight or newly acquired weight does not replenish this original.
5. **Already delivered credit:** reject this shortcut if any C0 has already
   been awarded through any representation. The present loader cannot
   inherit `C0 - delivered` while retaining the complete nonlinear quote.
   An opaque prior award or unknown delivery is not zero.
6. **Earlier partial source claims, no delivered credit:** potentially
   usable only after their exact quantities/outputs are included in the
   complete certificate and all remaining W0 is prepared before loading.
   Unknown earlier output, missing control, spent/unaccounted descendants
   or an incomplete original remains not ready.
7. **Rounding/zero:** include every actually committed eligible weight
   consumption and its exact output, including a zero-output slice.
   Do not round a claim up, discard its q from coverage, or compensate it
   again as surviving raw weight. If aggregate Q0 is zero, the positive
   units requirement makes this shortcut unusable. If C0 is zero, no
   successful compensated surrender or empty bond is permitted.
8. **Incompatible representations:** do not enroll only raw remainder,
   only prepared partial SY, an already-paid descendant, a reward balance,
   direct vault backing or a second alias with full original E0/D0.
   Such cases need a separately justified conserved unit/remaining-credit
   contract; none is supplied or authorized here.

Source-level dust is not a safe automatic rejection: the new read-only
`withdrawClaim(1)` simulation returns zero at the actual final source state.
It was not mined and did not spend protected unrelated weight. Current
explanatory source would debit positive q before redeeming zero shares.
Do not infer a source-side positive-SY minimum from the positive quantity
check or from the later Migration zero-credit check.

## 5. Original C0 conservation and current loader compatibility

Inspected current code:

- `interfaces/IUniswapV4DetfMigration.sol:163-189`:
  `WeightedSyEntitlementInput` has exactly `originalId, originalWallet,
  source, originalUnits, originalEth, originalDtf, evidenceId,
  contributionsKnown`. There is **no parent-weight, preparation receipt,
  inherited-credit or supplied remaining-credit field**.
- `UniswapV4DetfMigrationAllocationTarget.sol:189-218`: validates fixed
  chain/SY, positive original units, known contributions, wallet/evidence
  and canonical exclusions; computes the complete original quote through
  `SnapshotLib.evaluateOriginals`; initializes remaining units to input
  units and remaining credit to that full quote. It does not authenticate
  a weight-to-SY relationship.
- `UniswapV4DetfMigrationTarget.sol:127-180`: previews partial credit from
  remaining SY Q/C, requires activation and original wallet, measures an
  exact SY transferFrom, debits Q/C, books SY and funds the same wallet's
  fresh bond within that transaction.

For **only the complete, uncredited subset**:

```text
originalUnits = Q0 = sum(measured complete-original eligible SY outputs)
originalEth = complete E0
originalDtf = complete D0
C0 = U(frozen snapshot, E0) + U(frozen snapshot, D0)
initial remaining units/credit = Q0/C0

c = C                         if q == Q
c = floor(C*q/Q)              otherwise
Q' = Q - q
C' = C - c
delivered' = delivered + c
delivered + C = C0
```

Terminal surrender delivers all remaining C, including residue. Quotes
are neither scaled nor reevaluated for smaller raw or SY slices. Separate
originals retain separate nonlinear evaluations; grouping is not changed
to fit an output domain. If a quote is outside its supported domain, reject
rather than split/requote it.

At the witness's measured Q0 = 18077396, a hypothetical later SY surrender
of 6024595 has `floor(C0*6024595/18077396)` credit; its terminal 12052801
has the exact remainder. Their sum is C0. This is algebra using measured
source units, **not an executed Migration award or a numerical frozen quote**.
It does not assert that each SY piece equals its former raw-weight fraction.
No funded Migration snapshot, E0/D0 allocation, C0 amount, configuration,
activation, SY pull or bond was created in this task.

Stage 1 is the last loading window; complete preparation must therefore
precede its corresponding configuration and be reconciled before activation.
Stage 1 surrender remains closed. Activation also requires the real paid
owner-first bond and permanently removes all loaders. There is no proposed
Stage 2 amendment, parent-credit override, live repricing or new executor.

## 6. Same-origin exclusion

Retain one canonical `originalId` across raw rights and every descendant.
Do not generate a fresh identity from each preparation transaction, wallet
correction, output token, claim batch or wrapper. Source transaction IDs
are evidence members, not independent contribution IDs.

Current `_requireUnallocatedOrigin` at
`UniswapV4DetfMigrationAllocationTarget.sol:254-268` rejects matching
independent configured/issued, NFT, liquid, SY, DTF-custody SE, direct
claim-vault, weighted receipt, earlier receipt/liquid and held SE/LP
records. The inspected guards in the other loaders also exclude SY.
Those checks compare supplied canonical keys; they cannot discover opaque
documentary aliases or authenticate W0. No raw-weight loader/parent ledger
is invented. An operational partition must prevent this original from
appearing in another record under another key.

Exclude its raw consumed weight, T-owned backing vault shares, resulting
SY, subsequent receipt/liquid/recovery representations and independent
allocation from competing awards. Moved/accrued old rewards are not added
to original contribution or principal. Later recovery earns no second
personal credit.

## 7. Transaction and authority boundaries

**Acquisition fixture:** historical EOA
`0x016900aa17a08a52f1cc10a9474b3bbfaeb380a3` has empty code and actual
positive weight at the pin. Its two local `reassign` calls are explicitly
impersonated donor operations, not donor signatures or public consent.
Gas is supplied by actual signed development-account transfers. No
source/contract-owner/SUT impersonation, source owner operation, code,
storage, balance or role injection, special account execution, arbitrary
executor or public transaction was used.

**Preparation transaction:** the controlled original wallet itself signs
and calls T; that transaction consumes q and receives SY to itself, or its
failure rolls back source execution state. Native gas and nonce effects
of a mined failure are not rolled back.

**Later Migration transaction:** the accepted SY route requires original
wallet, configuration, Stage 2, allowance, exact SY custody, credit debit
and funded new bond atomically. Its failure cannot undo a previously
completed source claim. Prepared SY remains in the wallet if the later
transaction reverts; old weights do not reappear. This task did **not**
exercise or claim a new Migration funding rollback.

**Later recovery:** staged SY conversion/donation remains under existing
fixed custody and per-transaction rollback. Earlier completed stages are
not rolled back by later failures.

Direct raw pull remains unavailable to ordinary Migration. Retain the
actual old negative at phase01
`migration/evidence/verification/tokenstaking-caller.json:checks[0]`:
forwarded reassign fails `InsufficientStake(helper,q,0)`, selector
`0x936d426d`, hash
`0x0680e83cb5044541501f6103c8e432475e90f2db5d5671d1f289622867a03e7b`.
Its `checks[1]` proves no recipient callback on reassignment. Those old
checks were read, not replayed, replaced or relabeled as implementation.

## 8. Remaining gaps and finite handoff

The complete-original mechanics are witnessed; operational admission is
not ready without reviewed original wallet/E0/D0/W0, previous-delivery
and canonical-origin records, complete authentic preparation evidence for
those originals, and current eligible control. Current balances and this
synthetic fixture do not supply those records.

The present SY tuple is mathematically compatible with a complete,
previously uncredited original, but does not enforce this intake
certificate. A later explicitly authorized integrated witness must bind
an admitted complete certificate to the actual Stage 1 loader/frozen quote,
Stage 2 original-wallet SY pull and exact funded fresh bond; check
incomplete/duplicate/overlapping certificate rejection and preserve
unrelated floors. It must retain the separate prior-source-claim boundary
when testing later funding failure. Nothing here authorizes that work.

Partial/prior-delivered originals, direct atomic raw-weight surrender,
historical allocation/provenance closure, full-category coverage, source
archive equivalence, complete recovery, deployment gas and public
operations remain outside this bounded proposal. In particular, the
accepted phase21 registration measurement 45116678 still exceeds
32000000; this source-only witness supplies no new deployment-gas verdict.
