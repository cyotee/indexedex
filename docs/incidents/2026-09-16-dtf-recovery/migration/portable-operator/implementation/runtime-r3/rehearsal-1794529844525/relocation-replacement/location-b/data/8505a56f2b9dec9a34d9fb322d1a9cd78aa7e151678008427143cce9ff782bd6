# Weighted WS receipt source-unit contract

Date: 2026-11-12. **Qualified producer disposition: admitted-proposal.**
Independent source-contract admission and production implementation are not authorized by this label.

This specifies one exact canonical-gon mapping and proves its boundary. It does
not quietly convert an untransferable eligible remainder into surrendered units.
Section 7 distinguishes the proposed eligible-credit mapping from mandatory
gon custody accounting, and the demonstrated source boundary from a product
requirements violation. The earlier product-not-ready inference is withdrawn.
The prior version is retained byte-exact under `history/pre-qualification/`;
`qualification-seal.json` binds this qualification and the unchanged witnesses.

## 1. Authority and fixed source

Authority is the main-checkout implementation plan
`migration-detf-implementation-plan-r5-owner-first-bond`, especially sections
1.2-1.5, 3/E1-E2, 5.1-5.4 and 8.1/8.2; main PRD
`migration-detf-discussion-r22-owner-first-bond`, especially MIG-R12/R14/R15,
MIG-R25/R26/R35/R36 and section 6.2; the phase17 brief; and phase11
`same-wallet-sources/weighted/contract.md` section 5. The later Stage2 and
owner-first-bond directives supersede historical preactivation-surrender and
partly-consumed-amendment wording. Full absolute input paths and raw SHA-256
bindings are in `seal.json:inputs`.

Only chain **4663**, block **108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
WS **0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c** is covered.
Its display/approval unit is native9: one integer is 0.000000001 WS.

`run-04/identity.json` authenticates the header, Anvil instance, proxy code,
five selected selectors and their actual runtime bytes. The receipt facet is
`0xB7581fe833a2B2380DD786B345D61FFB734D36EB`, runtime keccak256
`0xcb505aba37d6ad909d8fb33dbf0091be50c9dd37f43e5df506bd240fc711b361`.
`retained-source.json` retains the existing archive entries; no metadata was
retrieved. The seal compares the actual pinned facet bytes with the retained
onchain bytecode. Archived source is not substituted current source.

The readable `archived/*.sol.txt` files are byte-exact decoded archived source:

| Source observation | Read source location |
| --- | --- |
| Native approval; synchronized transferFrom spends native allowance | `archived/StakedDETFTarget.sol.txt:104-123` |
| Synchronization precedes source lock and calls the old WD parent | `archived/StakedDETFTarget.sol.txt:33-37,230-236` |
| Balance is floor(gons/k); transfer always moves nativeAmount*k | `archived/DETFFundedStakingRepo.sol.txt:81-88,147-161` |
| Full-account unstake, unlike transfer, retires all account gons | `archived/DETFFundedStakingRepo.sol.txt:107-124` |
| Rebase changes k; role distributions separately issue new gons | `archived/DETFFundedStakingRepo.sol.txt:182-202,225-235` |
| Only old WD can fund rewards; recipients are reserved-NFT owners | `archived/StakedDETFTarget.sol.txt:161-178` |
| Exact conversion and funded growth arithmetic | `archived/DETFFundedStakingMath.sol.txt:44-78` |

The repository deployment record at
`deployments/robinhood_main_fee_accrual/composition/phase09_stage02_fee_accrual_frontend_candidate.json:1-20`
joins WD/WS/WY and both weighted vault identities. Its history is commit
`799f28e5fd693821d8ba06aae68ab986b6a723f0`. That join is provenance, not
independent proof of deployed source equivalence.

## 2. Original inputs and the proposed canonical-gon mapping

An original record must identify the original wallet, fixed chain/WS source,
wallet-independent canonical economic origin, original economic quote unit,
snapshot identity and evidence identity. ETH and DTF original components must
both be explicitly known; verified zero is valid and unknown is not zero.
The owner supplies original quantities and their documentary allocation, not
caller-selected credit, a live price, or a fabricated historical balance.

For this proposed mapping the eligible original quantity is **Q0 eligible original
ownership gons**, not today's displayed WS balance. Supply Q0 directly with its
original receipt allocation evidence. Where that evidence starts with a genuine
funded principal receipt, retain its eligible native principal P0, original
operation divisor kOriginal and exact relation `Q0=P0*kOriginal`. Do not use the
incident pin's divisor in place of an unproved original-operation divisor.
This is an engineering proposal grounded in invariant source ownership and an
explicit original-exposure allocation, not a requirement inferred merely from
the recovery inventory's unit. No current requirement quoted below mandates
that Q0/Q/q must be gons for every permissible receipt mapping.
For several actual source operations retain their exact individually evidenced
gon quantities and original quote grouping, not a rounded average divisor.

For an NFT claim, retain the principal and reward components separately.
`principalNative*kClaim` and `rewardNative*kClaim` are different allocation
evidence. A receipt descendant must carry only its allocated original exposure,
not the whole NFT contribution a second time. A live receipt balance cannot
derive that allocation. Preserve the existing canonical-origin exclusions
against independent compensation, both NFT families, WD, WY, W-SD and direct
claim-vault shares. No transfer ancestry or special original "molecules" are
required: current control is necessary, but never enlarges the configured cap.

Let C0 be the once-quoted original credit from the existing frozen evaluator:

```text
C0 = U(frozenSnapshot, ETH, originalEth)
   + U(frozenSnapshot, DTF, originalDtf)
Q = Q0 minus previously consumed eligible gons
C = C0 minus previously delivered frozen credit
n = approved positive native WS input
k = the divisor actually used by the source transfer
q = n*k = measured newly received transfer gons
require 0 < q <= Q
credit = C if q == Q, otherwise floor(C*q/Q)
require credit > 0 and credit >= minimumCredit
Q_after = Q-q
C_after = C-credit
```

Use full-precision multiplication/division and source-compatible overflow
checks. No multiplication of C0 by k, no live original-contribution re-quote,
no partial-contribution mint preview and no floor-to-native before computing
the eligible fraction. A configured native display observation alone is not
the Q0 of this proposed mapping. Section 7 explains its authority and limits;
an owner-selectable native-versus-gon mode is **not** proposed, and no different
mapping is selected by this qualification.

## 3. Principal, rewards and custody timing

Q0 and C0 are frozen original exposure. Ordinary funded rebasing lowers k
without minting more gons to an ordinary holder. That holder's larger native
redemption value is recovery growth, not a new original contribution.
Fee/creator rewards are different: source distribution mints extra backed role
gons after the rebase. Those mints cannot enlarge Q0, C0 or booked surrender.
Reward-only possession with no eligible original record rejects.

A future adapter must first validate Stage2, configuration, original caller,
fixed source, remaining Q/C, deadline and intended positive input under the
shared parent guard. Before measuring the transfer, settle the old WD parent's
`synchronizeRewards()` **inside that same reverting operation**. This prevents
role-reward issuance from being misclassified as received transfer gons even
if an endpoint is a role recipient. Read both endpoints' gons and native
balances, all seven staking-state words and k after that settlement.

Then execute `WS.transferFrom(originalWallet, Migration, n)` using actual native
allowance. Its own synchronization still executes. Require unchanged k across
this measured interval, wallet gon decrease and Migration gon increase both
exactly n*k, and native balances equal floor(the corresponding gons/k).
If further funding changes that interval, revert rather than infer transfer
from a combined reward/custody delta. Native differences alone are insufficient.
The public state query is a view, not a synchronization operation.

The pin probe deliberately also measures a transfer that itself performs due
synchronization. `proof.json:synchronizedPull` records both endpoint and role
before/after values and raw WS logs; only n*k goes to the controlled recipient.
Role gons and the k change are reported separately. This is executable evidence
for the source distinction, not a claim that the future adapter exists.

Only measured newly admitted transfer gons enter existing recovery inventory.
Source role mints, unsolicited balances, prior NFT/WY-derived inventory and
unbooked fractions are not another surrender. New rewards do not change the
original principal allocation or credit. After custody, recovery growth belongs
to the fixed recovery route, not another personal award.

## 4. Partial, exact terminal and minimum-unit rules

On a positive partial result retain both Q-q and C-credit. A zero-credit partial
reverts all in-transaction source effects; it does not accept the asset for
zero credit. For example C=1 and q<Q gives zero under the specified floor.
The smallest positive source transfer is n=1 and moves **k gons**, not one gon.
An approved n=0 transfer may succeed at the source but moves no gons and must
never be accepted as migration.

An exact terminal transfer exists at an operation divisor k only if `Q % k=0`
and the original wallet controls Q/k native units. Then n=Q/k, q=Q, and all C
is delivered without a re-quote. `run-04/representable-terminal.json` proves
genuine acquisition and movement of exactly seven native units at unchanged k.
Its synthetic Q0=7*k and C0=1001 arithmetic gives all1001; no Migration issuance
or funded compensation bond is claimed by that source witness.

If Q=a*k+r with 0<r<k, n=a moves only a*k. Q_after=r; any remaining C stays
with the record. This is not a terminal q=Q operation. n=a+1 moves more than Q,
and is not authorized by the cap even if the wallet separately acquires more
WS. `min(n*k,Q)`, ceiling-up extra custody, silent credit extinction, and
clearing r because display is zero are not part of this contract.

Later real funding can change representability. It is not guaranteed to make
r divisible, and no further reward funding or particular future divisor is
assumed. A preserved residual is not proof of an executable final surrender.
Equally, it is not proof of a requirements violation: the rules preserve the
unconsumed entitlement and condition successful surrender on valid actual input.

## 5. Concrete actual boundary and rollback

The controlled original wallet
`0x83781cf2371117aac856621805fb83c9ca439bad` signs its own WD approval and WS
acquisition. Existing EOA WD is transferred to it; no source balance, storage,
code or role is fabricated. It genuinely stakes101 native WD into101 native WS.
Original economic classification and C0 below are disclosed synthetic proof
inputs, not historical compensation allocations.

`run-04/boundary.json` and independently recomputed `proof.json` record:

```text
kOriginal = 875481854921341751018652579115616129
Q0        = 88423667347055516852883910490677229029
kLater    = 875382550842691351767016508170887758
C0        = 1001  (synthetic already-quoted arithmetic parameter only)

approved first n=1:
q         = 875382550842691351767016508170887758
credit    = 9
Qremain   = 87548284796212825501116893982506341271
Cremain   = 992

last representable n=100:
q         = 100*kLater
credit    = 991
Qafter    = 10029711943690324415243165417565471
Cafter    = 1
native balance after transfer = 0
```

The source actually leaves that gon fraction with the wallet. A further signed
one-native transfer fails; a signed zero transfer succeeds without moving it.
One positive native unit requires875382550842691351767016508170887758 gons,
strictly more than the remaining eligible quantity. This is observed custody
and exact integer arithmetic, not an assumption that an arbitrary gon is
transferable.

The disposable helper proves late-after-pull rollback with actual successful
inner transfer followed by `LateFailure(receivedGons)`. It also proves that a
full-account unstake retires more than n*k when there is a fraction: a booked
budget excluding that fraction rejects **after** the actual source unstake and
reverts the whole transaction. Authorizing all actually held gons succeeds.
`proof.json:decodedFailures` contains the concrete errors and quantities;
every failed witness has status0, no logs and unchanged measured economic state.

These are source atomicity witnesses, not implemented WS Migration bond,
callback or selected recovery-batch acceptance.

## 6. Integration preservation, conditional on admission

No issue on loading; complete/idempotent owner-only Stage1 records; paid
owner-first-bond prerequisite; atomic activation and permanent removal of every
loader; activation-gated rewards; Stage2 original-wallet-only actual approved
custody; one exact-funded fresh90-day cliff bond; and all late-failure rollback
remain required. Ordinary transfers do not move configuration or restore credit.
Return to the original wallet creates no new original allowance.

Reuse only the fixed WS -> WD -> DTF -> new reserve path and existing measured
recovery accounting. Keep principal, source growth, role allocations, all
unbooked gons, mixed NFT/WY inventory, donation/residual budgets and new bond
backing separate. Full-account retirement must never debit unbooked fractions;
actual gon debit, not only displayed native budget, controls permission.
Existing `MigrationLegacyRecoveryLib.sol:154-195` is the retained protection.
No other category is removed, relabeled supported, or changed by this evidence.

## 7. Requirement qualification and admission consequence

The following aliases refer to the actual current main files, not stale
worktree copies:

* P: `/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`
* R: `/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_DRAFT_PRD.md`
* W: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-11-same-wallet-sources/docs/incidents/2026-09-16-dtf-recovery/migration/same-wallet-sources/weighted/contract.md`

### 7.1 Eligible-credit units are not dictated by inventory units

**Requirement:** P section5.1, line206 preserves source-specific integer units;
section5.3, line259 requires original contribution/native units and frozen
credit basis separately from source consumption and recovery custody.
Section5.4, lines286-302 applies arithmetic to the source-defined eligible
claim but does not name gons as the mandatory WS credit denominator.
R section6.2, line283 assigns source-normalized units, conversions and rounding
to the plan; R section8.2, lines395-404 treats these specifications as engineering
work, not automatically new owner product decisions.

**Source observation:** W section5, lines333-340 calls gons canonical ownership
units, expressly says they are not reward-free principal, and requires an exact
configured eligible-unit mapping. Lines344-359 distinguish measured gon custody
and recovery from credit. These facts do not themselves mandate Q0/Q/q=gons.

**Proposal and inference:** section2 uses invariant original ownership gons,
with a separately evidenced original-principal allocation, as one exact
source-backed eligible basis. That proposal must be reviewed on its original
exposure/conservation merits. Gon-denominated inventory alone is not its proof.
The original numerical allocation remains an operational input. The current
record does not establish that every other normalization is forbidden.

The earlier native-count comparison remains a semantic diagnostic, not a
second selected mapping: on the same101 native units a fixed101-native cap
would calculate9+992, whereas this gon proposal calculates9+991 and retains1.
The abstract1-native/kOriginal10/kLater6/C0=10 example likewise distinguishes
the two quantities. Neither comparison identifies an explicit requirement
that simultaneously mandates both results; it therefore does not prove a
genuine product contradiction or require an owner-selectable pricing choice.

### 7.2 A preserved currently non-transferable remainder violates no cited rule

**Requirement:** P section5.4, lines291-298 requires verified positive q<=Q
and pays all C **when q==Q**. Line300 expressly keeps rounding residue with
the remaining eligible claim. Line302 rejects zero-credit custody and permits
a larger amount only "where available." P section8.2, line560 conserves
remaining/delivered credit subject to explicitly retained integer residue.
R MIG-R36 at line255 and MIG-AC41 at line458 preserve the unconsumed remainder.
R MIG-R35 at line253 means completed surrender is irreversible; it does not
mean every remaining fraction must be transferable now.

**Observation:** at the witnessed k, 0<Q<k and C=1 remain. No positive integer
native input moves q<=Q. A zero transfer moves nothing; one native exceeds
that eligible quantity and the actual remaining source balance.

**Requirement-dependent conclusion:** this proposal must reject such a pull
and leave Q/C unchanged. That is the existing validity/preservation rule, not
forfeiture or unmatched custody. The conditional `q==Q -> credit=C` does not
assert that an executable q==Q exists at every divisor. No cited current text
mandates immediate terminal redemption, redemption by a deadline, or eventual
representability regardless of source funding. I found no explicit requirement
violated solely by preserving this positive currently non-transferable residue.
Nor did I establish two conflicting mandatory terminal readings.

This makes no indefinite-wait policy: it adds no delay, obligation to await
funding, promised eventual divisor or new redemption condition. An attempted
operation is assessed against the same existing validity rules at its actual
source state. The source boundary remains disclosed; it is not converted into
a demand for a new owner decision.

### 7.3 Qualified disposition

The prior **product not-ready** inference exceeded the evidence and is
withdrawn. The source-backed engineering mapping remains unchanged and is
delivered as **admitted-proposal for independent source-contract review**.
This producer label is not the independent verifier's admission and does not
authorize implementation. Original allocation inputs, exact principal/reward
mapping, synchronization composition and all implementation proofs remain
subject to their existing gates. Independent admission can reject an unsupported
mapping; this report does not preempt that decision with a manufactured terminal
product blocker.
