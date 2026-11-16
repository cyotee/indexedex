# Weighted WS receipt source-unit contract

Date: 2026-11-12. **Disposition: not-ready. No production implementation is admitted.**

This specifies one exact canonical-gon mapping and proves its boundary. It does
not quietly convert an untransferable eligible remainder into surrendered units.
Section 7 identifies the remaining original-unit/terminal reading that the
current requirements do not resolve. Missing numerical operational allocations
are a separate input gap, not the reason for this disposition.

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

## 2. Original inputs and the one canonical-gon mapping

An original record must identify the original wallet, fixed chain/WS source,
wallet-independent canonical economic origin, original economic quote unit,
snapshot identity and evidence identity. ETH and DTF original components must
both be explicitly known; verified zero is valid and unknown is not zero.
The owner supplies original quantities and their documentary allocation, not
caller-selected credit, a live price, or a fabricated historical balance.

For this mapping the eligible original quantity is **Q0 eligible original
ownership gons**, not today's displayed WS balance. Supply Q0 directly with its
original receipt allocation evidence. Where that evidence starts with a genuine
funded principal receipt, retain its eligible native principal P0, original
operation divisor kOriginal and exact relation `Q0=P0*kOriginal`. Do not use the
incident pin's divisor in place of an unproved original-operation divisor.
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
the Q0 of this mapping. The actual original-unit choice is the issue in section 7;
an owner-selectable native-versus-gon mode is **not** proposed.

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

## 7. Exact unresolved reading and admission consequence

The plan sections5.3-5.4 require **source-defined eligible units**, measured q,
`q<=Q`, proportional partial credit, preservation of residue and all remaining C
on whole-remainder surrender. PRD MIG-R36/section6.2 require a preserved
fungible remainder and source-normalized units. Phase11 weighted section5.2-5.3
explicitly leaves the original receipt/gon denominator and principal mapping
unadmitted. Neither current text equates "whole remainder" expressly with
invariant original gons rather than a fixed original native-principal count.

That distinction is economically observable even though both readings freeze
the same original ETH/DTF quote and never increase C0 for rewards:

* Under the canonical-gon mapping above the actual101 transferred native units
  deliver1000 of synthetic C0=1001 and retain the demonstrated Q/C fraction.
* Reading original eligible principal as fixed101 native units instead makes
  the same first1 and next100 native units consume1/101 then the whole native
  remainder:9+992=1001. It classifies the leftover ownership gons differently.

The second row is a **counter-reading**, not an offered implementation mode.
The source exposes no per-holder principal ledger that chooses it. Conversely
the first row cannot pretend its remaining eligible gons were transferred.
The smallest abstract counterexample is original1 native at10 gons/native,
later k=6, C0=10: the identical1-native custody moves6 gons, giving either
terminal10 credit or partial6 credit with4 gons/4 credit remaining.
The actual pinned101-native witness demonstrates the same split without
fabricating a source divisor.

The minimal missing requirement is which original source-unit denominator
defines eligible principal and, if invariant gons govern, what constitutes
terminal consumption when 0<Q<k. No existing text authorizes paying C on q<Q,
discarding C/Q, taking extra native custody, or requiring future funding.
This contract does not choose any of those policies or ask for new numerical
allocations. **Not-ready** is therefore the source-contract admission result,
not a failure of ERC20 custody and not a declaration that all future recovery
is impossible. Implementation must not consume this as an admitted contract.
