# Claimed-SY complete-original source witness

Date: 2026-11-12. **Verdict: bounded admitted-proposal**, subject to
`contract.md`'s complete-original, zero-prior-delivery and reviewed-original
conditions. Operational intake and integrated Migration acceptance remain
not ready. No implementation or full raw-category acceptance is granted.

## 1. Scope and actual work

All new files are under this `source/` directory in
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-22-claimed-sy-source`.
HEAD remains `4eaa7decab80d24cf37cb3781eff5ffaf9362942`.
No production, test, operator, dependency, configuration, old evidence,
commit, ref or index was edited.

Read the complete phase22 and phase11 briefs, complete phase11 claims
contract, current main plan r5/PRD r22, root intake assessment and phase21
coverage snapshot, exact phase01 caller-negative and other-metered
claim/source witnesses, current TokenStaking/vault explanatory code,
accepted current SY interface/loader/surrender/origin checks, and phase21
independent runtime/immutable reports. Current r5/r22 lifecycle and wallet
rules control; historical r3/r20 transferable-entitlement or preactivation
wording is not restored.

The sole new source run used:

```sh
/bin/zsh -lc 'cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-22-claimed-sy-source && export PATH=/Users/cyotee/.foundry/bin:$PATH && exec anvil --fork-url robinhood_mainnet_alchemy --fork-block-number 108944663 --chain-id 4663 --host 127.0.0.1 --port 18572 --accounts 1 --compute-units-per-second 10 --no-fork-node-info --no-mining'
```

This uses the existing alias/login environment, standard development
account bootstrap and ordinary source state. There was no provider
switch, new metadata/IPFS fetch, public transaction, source deployment,
source/gas/storage/code/token injection, role change, owner/SUT
impersonation, special account execution or executor deployment.
All RPC work targeted loopback18572; only its fixed admitted archive
bootstrap used the existing upstream. No unchanged suite or old raw-pull
failure was replayed.

Anvil readiness and exit were subscribed through one monitor. Claims and
funding used manually mined ordinary signed transactions, not unlocked
controlled-wallet submissions. Every original signed byte string was
captured before submission. No raw signature was reconstructed afterward.
Local HTTP request/response body strings are retained exactly in
`raw/wire.json`; the JSON container itself is a new evidence serialization.

## 2. Authentic acquisition, synthetic eligibility, real signatures

At the fixed source pin the existing holder
`0x016900aa17a08a52f1cc10a9474b3bbfaeb380a3` has empty code and
64890781291192882058375 native18 weights, matching the retained phase01
holder evidence. It owns the weight it reassigns; it is not a fabricated
contract role or an impersonated source contract.

Two public disposable development derivations are controlled:

| Role | Derivation and wallet |
| --- | --- |
| One-claim complete original | `m/44'/60'/0'/0/221`, `0x202b3b724ebcbB4A3B23dCB09Ac492343f327a61` |
| Split complete original | `m/44'/60'/0'/0/222`, `0x0ECfa2395449Cb032Bbc317020B02c2f9B07fAa9` |

The standard development mnemonic is the public Anvil test mnemonic.
Development account0 actually signed three gas transfers of
1000000000000000000 wei: to the donor and both controlled claimants.
No `anvil_setBalance` was issued. Each donor reassignment is separately
labeled **local impersonated existing EOA holder**, not signed donor
consent. Impersonation ended in a `finally` path before controlled claims.

Each claimant receives 10023000000000000000017 weights through actual
`reassign`. The disclosed synthetic partition is:

```text
eligible original W0 = 10013000000000000000017
unrelated surviving weight U = 7000000000000000000
separate excluded seed weight = 3000000000000000000
acquired = W0 + U + seed
```

Each claimant first signs a claim of the excluded seed, producing 5416 SY.
That positive preexisting SY is protected and excluded from Q0. Each
eligible preparation then leaves U untouched. These synthetic originals
are two distinct fixture allocations, not two approved historical records
or duplicate real-world compensation claims.

| Donor local reassignment | Exact hash |
| --- | --- |
| To one-claim wallet | `0xd4d69e770724c8eed51831e1f365d3efd4b10e4fc9002be95dc9bf07b8c9ae9a` |
| To split wallet | `0x735d6617496576535b731c54db17b0c96ee8b3ce9fbc9b85893cfb4b54b6b162` |

Donor weight ends at 44844781291192882058341. Reassignment preserves
total source weight, vault shares/assets and SY supply. Its reward
bookkeeping changes separately: immediately after acquisition the donor
and each claimant have stored rewards 915239846737831941489 and
204560011660818907782 respectively. Those rewards remain unchanged
through the subsequent claims and are **not** added to W0, SY Q0,
original ETH/DTF, or C0.

Nine transactions have original real controlled signatures: three gas
transfers, five successful own-wallet claims, and one failed repeated
claim. Two donor transactions are impersonated fixtures. All nine raw
transactions decode to the actual signer/chain4663/hash; recovered
signatures and canonical nonce/from/receipt identities agree.
`raw/transactions.json` retains all raw signatures, canonical transaction
objects, complete receipts and call traces. It does not mislabel the
donor's Anvil synthetic signatures as cryptographic proof.

## 3. Measured source preparation

All quantities below are native integers, not human decimal amounts.
The exact per-step before/after states are in
`raw/observations.json:observations`. Complete original/return/event/
recipient reconciliation is in `raw/reconciliation.json:decodedClaims`.

| Claim | Consumed native18 weight | Burned native19 vault shares | Received native9 SY |
| --- | ---: | ---: | ---: |
| One-claim wallet excluded seed | 3000000000000000000 | 54161780477508 | 5416 |
| Split wallet excluded seed | 3000000000000000000 | 54161780477508 | 5416 |
| Full eligible original, one claim | 10013000000000000000017 | 180773969307098861 | 18077396 |
| First eligible split, incomplete | 3337000000000000000005 | 60245953817815729 | 6024595 |
| Terminal eligible split | 6676000000000000000012 | 120528015489283131 | 12052801 |

| Eligible operation | Exact locally mined hash |
| --- | --- |
| One-claim complete | `0x2057df21e7d6a71960d89f2b380be26b98c92fb6ee08686dff4c63d2ffcc5194` |
| Split first | `0x4d43526f94e315f46649788f1b130c9b4eb37cf4ad37d189efe12e1a6aee76ac` |
| Split terminal | `0x10dfe431f5ebbb4ed8cfe6afe7728529a704a780124f2d13966f8f198e1bb921` |

The first split leaves **6676000000000000000012 eligible weights**
unprepared in addition to U. Its 6024595 SY is not complete-original
coverage and cannot be loaded with the complete original quote.
Only after the terminal claim is eligible coverage exactly W0.

Measured one-claim Q0 = 18077396. Independently summed split Q0 =
6024595 + 12052801 = 18077396. Both final wallet balances are
18082812 = Q0 + protected 5416, and each still holds U =
7000000000000000000 weights. Donor and the other wallet's source/SY
balances remain unchanged during each claimant's operation. No direct
claim-vault shares are given to either claimant.

The split burns 180773969307098860 vault shares, **one fewer** than the
one-claim operation, despite equal final SY output in this run. These
operations occurred sequentially against their actual changing source
books, not identical-state counterfactual forks. Equality of the SY sums
is an observation, not a general split/one-shot conversion rate.

Every successful claim's `eth_call` return, source preview, vault preview,
actual top-level trace return, `ClaimWithdrawn` event and wallet SY delta
agree exactly. The nested actual vault call is
`redeem(measured shares, same caller, TokenStaking)`. Recipient equality
is verified from actual calldata, not inferred from balance increase.

## 4. Exact books and rounding

Before each claim let T be source total weight, V the vault shares held
by TokenStaking, S the vault total supply and A the vault's actual SY.
In these observations V = S; that is not assumed universally.

| Step | T before | V = S before | A before |
| --- | ---: | ---: | ---: |
| First seed | 15338080546808403036783930 | 276912583840862116302 | 27691258414 |
| Second seed | 15338077546808403036783930 | 276912529679081638794 | 27691252998 |
| Full eligible | 15338074546808403036783930 | 276912475517301161286 | 27691247582 |
| First eligible split | 15328061546808403036783913 | 276731701547994062425 | 27673170186 |
| Terminal eligible split | 15324724546808403036783908 | 276671455594176246696 | 27667145591 |

For each q, the measured burned shares are `floor(q*V/T)`.
`weightShareFloor` retains the complete numerator, denominator, quotient
and remainder. None of these claims consumes the entire global T, so the
`q == T` terminal-global-supply branch was not exercised.

The current explanatory vault formula
`floor(shares*(A+1)/(S+10^10))` reproduces all five actual preview/return
and SY deltas. Exact quotients and remainders:

| Step | Weight-division remainder, denominator T above | SY-division remainder | SY denominator S + 10000000000 |
| --- | ---: | ---: | ---: |
| First seed | 13755730989958515979153560 | 49305282906901338188 | 276912583850862116302 |
| Second seed | 13755730989958515979153560 | 49305282906901338188 | 276912529689081638794 |
| Full eligible | 5192389732740338113638132 | 263197185615581411707 | 276912475527301161286 |
| First eligible split | 8894486011900401344744548 | 107530773822707128448 | 276731701557994062425 |
| Terminal eligible split | 11627308147336971438304404 | 155679356430732813056 | 276671455604176246696 |

The observed quotient fit does not establish byte-identical deployed
source or general arithmetic equivalence outside these calls. Actual
vault preview and measured output remain authoritative. No historic
64890781291192882058375 -> 117153341 ratio was used for sizing or credit.

Aggregate initial-to-final reconciliation, including the two excluded
seed claims:

```text
source total weight:
15338080546808403036783930 -> 15318048546808403036783896
debit = 20032000000000000000034 = 2*(W0 + seed)

source-owned vault shares and vault total supply:
276912583840862116302 -> 276550927578686963565
debit = 361656262175152737

vault SY:
27691258414 -> 27655092790
debit = 36165624 = 2*5416 + 18077396 + 18077396

SY total supply: 54373903396 -> 54373903396
```

SY is transferred from the vault, not minted as a second original.
Exact operation-local deltas, source/supply equality and unchanged
unrelated balances were asserted against actual responses.

## 5. New negatives and rollback limits

After complete preparation, the one-claim wallet actually signs a repeat
of W0. Hash
`0x3944c5fe880dd8585cbaf4c5a146ece27628740fa8cd6c5c51fbdbf3b0288c05`
mines with status0, no logs and `InsufficientStake`, selector `0x936d426d`,
with caller, requested W0 and available U in the exact error bytes.
Weights, stored rewards, SY balances/supply, vault shares/supply/assets
remain unchanged. Gas is spent and nonce advances; this is not an
assertion of native-gas rollback.

This negative establishes only insufficient remaining caller balance for
that repeated quantity. TokenStaking has no canonical-original ledger:
it would not prevent spending some unrelated surviving weight. The
candidate certificate must therefore enforce W0 coverage and exclusions;
the source failure is not duplicate-entitlement enforcement.

A new **read-only** `withdrawClaim(1)` simulation returns a zero uint256.
No such dust transaction was mined; protected U remains untouched.
The raw request/response and unchanged before/after states are retained.
The preparation contract must not assume source-level positive-SY output.

The old ordinary-caller negative and absent-callback witness were read
directly from phase01 `tokenstaking-caller.json:checks`, not replayed.
Direct approved Migration pull of an EOA's raw weight remains unavailable.
The old outer-transaction claim rollback is not a demonstration of such
a pull.

No new Migration deployment, configuration, frozen quote, surrender,
funding or bond creation was attempted. In particular **new Migration
funding rollback was not exercised**. A later failed Migration SY pull/
credit/funding transaction cannot undo any of these completed source
claims; the prior source transaction and later Migration transaction
have different rollback boundaries.

## 6. Current integration and original-credit result

The current SY loader's eight-field tuple was inspected directly. It has
no parent weight or inherited remaining-credit input, and initializes
full C0 against supplied native9 units after evaluating complete original
ETH/DTF. It does not validate a raw-to-SY preparation certificate.

Therefore the tested complete, zero-prior-credit subset has a finite
candidate mapping: keep one original identity and complete E0/D0; load
only aggregate measured Q0 after full W0 coverage. Partial preparation
and prior-delivered originals do not fit this shortcut. Existing origin
guards compare the same supplied canonical keys across other admitted
representations, but do not resolve opaque aliases or invent a raw
parent ledger.

Original C0 conservation is specified algebraically in `contract.md`:
quote once; partial SY surrender consumes remaining-Q/C fractions;
terminal surrender delivers the residue; delivered + remaining = C0.
No historical E0/D0, operational original, numeric C0, quote override,
new field, scaled nonlinear input or approved allocation is fabricated.
The synthetic W0 partition demonstrates source mechanics, not entitlement
provenance.

This is an admitted **proposal**, not automatic normalization of every
raw-weight original. Complete actual source preparation is necessary,
but does not itself prove reviewed original identity, contributions,
absence of earlier delivery, same-origin exclusions or later integrated
funding.

## 7. Evidence, checks and stopped cleanup

| File | Meaning |
| --- | --- |
| `raw/wire.json` | Original local HTTP JSON request/response body strings, including errors and complete source/runtime calls; no upstream credential |
| `raw/transactions.json` | All 11 mined local transactions, nine original raw controlled signatures, two labeled impersonated donor operations, complete canonical objects, receipts and call traces |
| `raw/source-identities.json` | Actual header, empty-code holder, fixed source runtime bytes and deployed selector/facet bindings |
| `raw/observations.json` | Initial/prepared/final state, all five before/after claim books, both integer divisions and new repeat/dust evidence |
| `raw/reconciliation.json` | Aggregate conservation, same-caller decoded vault calls/events, nine signature recoveries and runtime preservation |
| `raw/input-preservation.json` | Complete-byte SHA-256/length bindings for 17 read actual inputs captured before the witness |
| `raw/cleanup.json` | Exact stopped-resource/read-only Git recipe, output and unchanged input comparisons |
| `raw/offline-audit.json` | Stopped raw-file reconciliation: 574 HTTP exchanges, 11 complete transaction/receipt/trace comparisons, nine real signature checks and five claim/division checks |
| `method.md` | Bounded reproduction and offline verification recipe |
| `seal.json` | Sorted complete owned-file membership, lengths and raw SHA-256; excludes only its own self-reference |

All new successful source claims, real signatures, caller recipient,
native units, supply/vault/SY conservation, measured sums, protected floors,
exact remainders and failed repeat state were checked with direct integer
assertions against raw responses. Evidence JSON was parsed and sealed
against complete raw UTF-8 bytes. No test-suite/build success is claimed.
JSON editor diagnostics were unavailable because Biome is not installed;
no installation/configuration change was made.

The sole owned source-node monitor was killed after all evidence reads.
Its completion event reports watcher killed/exit0. The donor stop-
impersonation RPC completed before claims. No subscriptions, checkpoints,
snapshots, helper deployments, runtime directory or other node was created.
Final `lsof` for loopback18572 returns exit1 with no listener.

Read-only Git checks return unchanged HEAD above, tracked diff exit0 and
cached diff exit0, with only the new claimed-SY evidence directory
untracked. All 17 bound actual source/evidence inputs retain their
complete-byte SHA-256 and length. Every Git read uses
`GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0`, and status/diff ignore submodules.
No old artifact or evidence was rewritten, removed or relocated.

No owned operation remains pending. The bounded source result is
complete; operational originals, partial/prior-delivered mappings,
integrated certificate-to-loader/SY-bond proof, direct raw-category closure,
archive equivalence, broader recovery, deployment gas and public actions
remain explicitly unaccepted rather than pending work in this task.
