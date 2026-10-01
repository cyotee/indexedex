# G5 guard and stateful preservation — bounded source handoff

## Reconciled parent execution checkpoint — 2026-09-30

**Latest G5: both 14-test leaves passed**, including the new three-actor mixed
money/reentry history and strengthened ledgers, in
`tool_0f2ac962b001saQBFZEqpb2RyO`. That combined selection passed 66 tests:
28 G5 + 16 G6 lifecycle + 22 then-current G4. The latest G5 fuzz lines explicitly
report **16 runs**, so the inline annotation is not execution evidence of 128.
The earlier 436-family run (`tool_0f28e99a80017hutLncSKOzlpl`) passed at 128 runs
but predates these enhancements. Final refreshed 128-run validation is pending.

The 24 legacy actions are now mapped by their actual predicates to C32, C48,
the passing mixed histories and G3/G4/G6 controls below. A literal replacement
24-action class or every route×actor×decimal Cartesian product is not an
additional requirement. The old ordinary own-share allowance expectation is
superseded by the owner's confirmed current behavior; third-party ERC20 approval,
booked-share isolation and exact caller-share debit remain tested.

This supersedes “added, pending execution” and the follow-up compilation blocker
below for the scoped cases. It does not promote the 16-run result to 128 or grant
overall readiness/retirement approval. This reconciliation executed no tests.

**2026-09-30 — parent reports previous G5 source 26/26 passed at 128 fuzz runs,
and full family 436 green. This follow-up source is pending parent validation.**

This note scopes G5 in [the acceptance map](UNISWAP_V4_FULLSPREAD_ACCEPTANCE_MAP.md).
The preceding result is parent-reported execution evidence, not a run performed by
this worker and not a result for the changes below. No source/artifact hash or new
log was supplied with this checkpoint; do not attach the old pass to this new tree.
This note does not promote overall readiness or retirement to PASS. No Forge, compiler,
LSP compilation, delegation, commit or production edit was performed for this work.
The parent owns the sole combined Forge run after all workers are ready.

## Owned additions

- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/GuardClosure.t.sol`
  — `HooklessG5GuardClosureTest`.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/GuardClosure.t.sol`
  — `PonsFamilyG5GuardClosureTest`.
- `contracts/test/bases/TestBase_FullSpreadG5GuardClosure.sol` — new assertion adapter only.
- `contracts/test/stubs/FullSpreadG5GuardToken.sol` — controlled external underlying,
  with actual balances/allowances, metadata failure, FoT and callbacks.
- `contracts/test/stubs/FullSpreadG5CreditHandler.sol` — distinct three-wallet credit histories.
- This note.

No existing Acceptance/TestBase, shared behavior, campaign, acceptance map, Foundry
configuration, or other worker's files were edited. Both leaves reuse the existing
registry-deployed Acceptance fixtures and their real PoolManager. P uses the real
hermetic Pons hook with registered pool, not a mock or a claim of live graduated-launch
execution. Only token/caller behavior is controlled. No SUT state is fabricated.

Authority: current PRD §3/§6, implementation plan §§2.1/4/5/8, and actual guard
implementations. New tests use supported F0/F1/F3/F6 domains; no two-backed-leg R6
success, idle R4 success, or retired percentage-of-total sleeve assertion is restored.

## New assertion mapping

All names below are inherited separately by **both** family leaves. The initial
twelve deterministic functions and one fuzz function comprise the parent-reported
26 passing instances. The follow-up adds one mixed-history test per family and
strengthens the existing helper's holder/rollback ledgers: **14 functions per family,
28 intended instances now**, with the changed source pending validation. The FoT
test is part of the already-passing checkpoint; it was not rewritten.

| New test | Actual predicate and bounded dimensions | Legacy obligation |
|---|---|---|
| `test_G5_bootstrapMinimumPlusOneIdleAndBlocked` | 18/18 minimum `1e15`: preview and funded execution at minimum reject exact `(raw,minimum)`; `minimum+1` preview/execution issue exactly one caller share; exact dead sink, supply, both payer debits and all books. Separate restored idle and real outer-unlock executions. | A0 minimum and minimum+1 proxy assertions. |
| `test_G5_bootstrapMetadataFailureAndRetry` | Real underlying `decimals()` dependency error propagates through preview and idle/blocked activation; both payer/vault balances, supply and sink remain unchanged; disarm and activate successfully. | D34 dependency error and retry; no fallback invented. |
| `test_G5_bootstrapDonationCannotBeCaptured` | Donate either currency before first mint, no shares issued by donation; blocked dual activation has exact independent residual sink arithmetic; each token's first-minter ownership is bounded by its actual contributed amount, via cross-products; complete booking. | Ordinary activation donation exclusion and residual dead shares. This is an ownership inequality, not a claim of a newly tested full donation→victim→redemption attack cycle. |
| `test_G5_sharePermitReplayAndSpentAllowance` | EIP-712 owner/spender/value/nonce/deadline signature on actual proxy; wrong spender exact allowance failure; authorized spend exact balances, zero remaining allowance and nonce one; replay exact error **selector** (recovered signer is not asserted); second spend exact allowance payload; nonce/balance unchanged by rejects. | Release permit replay and spent allowance. |
| `test_G5_ordinarySharePullNeedsAllowanceAndHolderExitUsesOwnShares` | Third-party ERC20 `transferFrom` rejects without allowance, succeeds after exact approval, consumes it fully; separately proves current contract-holder `exchangeIn` exits its own shares without vault allowance and pays a distinct recipient exactly the quote. | Ordinary ERC20 pull authorization, plus current holder-exit semantics. See conflict disposition below. |
| `test_G5_feeOnTransferRollback` | One-percent short actual pull rejects exact `TransferDeltaInsufficient(1e18,.99e18)` in supported blocked mint; full observed digest and token burn/supply roll back; ordinary token retry succeeds. | FoT forbidden and failed delivery atomicity. |
| `test_G5_nestedSyAndExchangeCallbackRollback` | Token owns 2e18 real vault shares. Transfer callback attempts external SY redemption and ordinary share exchange during blocked deposit; successful outer deposit records exactly one callback and exact `IsLocked`; token claims remain 2e18 and recipient receives nothing. Propagating mode rejects outer deposit with exact `IsLocked`, restores digest and callback counter. | Nested money-path lock, held-claim isolation and propagating rollback, beyond maintenance-only reentry. |
| `test_G5_packageDisablePreservesValidExitsAndReenable` | Real manager `setPackageDisabled`: SE and SY input reject exact `VaultDisabled(vault)`; blocked F3 pays both exact outputs and burns exact shares; blocked external SY matches its quote; re-enable supports funded SY mint with exact recipient/supply effects. | Package-wide flag (not address flag), valid EO and SY exits, re-enable. One instance is exercised; no second-instance propagation claim. |
| `test_G5_removedPreparationAndDiamondCutUnavailable` | Removed prepare and cut selectors have zero loupe targets, no corresponding ERC165 support and exact `Proxy.NoTargetFor(selector)` on actual calls; share decimals stay 18. | Removed preparation and immutable no-cut surface. Not a full facet metadata test. |
| `test_G5_zeroDeadlineUnsupportedAndRecipientGuards` | Positive-domain SE deposit zero, SE EI deadline, **blocked F1** EO deadline, unsupported SE token, zero SY deposit, unsupported SY output and zero SY receiver: exact errors and complete observed rollback. | E5 guards and receiver semantics. Does not impose money-path zero errors on numeric views. |
| `test_G5_idleSyMinimumRetryContextAndBookedSurplus` | Book three donated self-shares via funded join; each output face's failed internal SY minimum preserves digest; retry pays exact preview, burns once, retains/books remainder. No-share ordinary caller gets exact own-balance error, and code-bearing push cannot claim booked surplus. | Idle internal surplus, recipient, failure/retry and observable context isolation. No test-only context reader installed. |
| `test_G5_idleExternalSyMinimumRetryBothFaces` | Each output face: failed external SY minimum preserves digest; no-allowance retry matches exact quote, payer share debit, supply burn, recipient receipt and zero self-share residue. | Idle external SY late minimum/retry. |
| `testFuzz_G5_threeActorCreditHistories` | See scoped handler below. | Missing multi-actor custody/credit histories, not wholesale legacy handler closure. |
| `test_G5_threeActorMixedMoneyAndReentryHistories` | One persistent real owned-position fixture: all three wallets execute both-face pull/push idle deposits/direct EI, idle/blocked share EI exits, both-face direct EO budgets; staged-short recovery; real trade followed by five no-credit rejects before sync; token-owned SY/SE recorded and propagating callbacks followed by funded reuse; idle atomic swap slippage; donation/repair and live sleeve history. | Follow-up source fills the specific combined-history predicates missing after mapping existing G3/G4/G6/core tests. |

The deterministic rollback digest includes opaque live quote state, payer/recipient
asset balances, local reserve snapshots, input allowances, underlying supplies,
manager/hook custody, vault/share-holder/self-share balances, vault supply and native
residue. Metadata-failure tests use explicit custody/supply assertions because a
quote-state read can itself depend on the deliberately failing metadata.

### Ordinary share allowance: resolved current-behavior disposition

Both current family `Common.sol::_secureShareDelivery` implementations have:

```solidity
if (!pretransferred) {
    ERC20Repo._transfer(msg.sender, address(this), amountIn);
    return amountIn;
}
```

The active Native SY self-call branch is separately bounded by its context and actual
self-balance. Consequently, the old nested-caller assertion “ordinary contract holder
exchangeIn must fail without allowance” is **not current implementation behavior**.
The owner explicitly confirmed in this follow-up that no arbitrary own-share
allowance gate is required and the token ERC20 approval assertion is the relevant
check. Accordingly the old SE-own-share allowance rejection is superseded, not an
open request for production changes. Plan §5 preserves the current Native SY
adapter, and PRD §3 preserves authorization: caller-owned shares are debited;
third-party ERC20 `transferFrom` still requires approval. The passing guard tests
cover that distinction, spent allowance, and denial of access to booked self-shares.

## Existing evidence retained and inspected

- H/P `CrossModeStatefulCampaign.t.sol` and
  `contracts/test/bases/TestBase_UniswapV4FullSpreadCrossModeCampaign.sol` remain intact.
  The actual loop has **32 sequential steps, eight modes, four visits per mode**,
  one active test-contract holder and a passive incumbent. Modes include idle SE/SY
  deposits, blocked EI/exact-share mint, idle SE/SY redemption, EO success/domain
  rejection and false-credit rejection. Its observed-core mint/exit/fee attribution
  is more economically independent than the new credit handler's preview parity;
  the new handler does not duplicate or replace those calculations.
- `UNISWAP_V4_FULLSPREAD_EXECUTION_STATUS.md` records historical **128 inputs × 32
  steps per family** for that campaign. This session did not rerun or recertify it.
  The current repository `foundry.toml` has `[fuzz] runs=16`; the existing campaign
  leaves do not themselves pin 128. Thus “128 × 32” describes the recorded explicit
  run, not a guarantee for every default invocation of the current dirty tree.
- Existing `EquivalentInterfaces` and `BlockedYieldEquivalence` retain alias equality
  and blocked SY coverage; new tests target idle late-failure/context/recipient gaps.
- Existing `AdversarialReentrancy` only targets maintenance reentry; new tests target
  token-owned SY and ordinary exchange claims.
- Legacy `UniswapV4FullSpreadStandardExchangeVault_Invariant.t.sol` plus
  `StandardExchangeHandler.sol` retain 24 actions, three funded wallets, per-action
  counters and three refund modes. Their idle exact-share and general two-leg EO
  positives cannot be copied into H/P unchanged.

## New handler: exact scope

The fuzz function requests **128 runs** with an inline Foundry annotation;
each input performs **48 sequential steps without restoration**. Parent reports
the prior version passed at 128 runs. Its eight-action scheduling remains unchanged;
this follow-up strengthens shared accounting and must be rerun by the parent.

Eight actions run twice for **each of three independently funded code-bearing wallets**:

| ID | Action | Required outcomes per 48-step history |
|---|---|---|
| 0 | Share transfer to next wallet | Six exact sender/recipient ledger updates; no supply change. |
| 1 | Blocked EI pull mint | Six positive quote matches, exact input debit, finite allowance consumed. |
| 2 | Atomic blocked EI push then replay | Six positive mints plus six exact zero-credit rejects. |
| 3 | Atomic one-unit-short push | Six exact short-delivery rejects and full atomic funding rollback. |
| 4 | Different wallet supplies resting double credit; consumer fails minimum then consumes only half | Six positive mints; twelve exact minimum/replay rejects; payer loses full donation, consumer gets no token refund, unused half is booked. Prior transfer survives the rejected call. |
| 5 | Atomic pushed mint fails minimum then retries | Six exact slippage rejects, six positive retries, full first-attempt funding rollback. |
| 6 | Blocked F1 exact shares, pull | Six exact requested issuances, only used token debit and finite used allowance consumed. |
| 7 | Blocked F1 exact shares, push | Six exact issuances/net debits; two cases each of used-only, partial-budget and full-budget delivery/refund. |

Every step checks exact initial supply + issued shares - burned shares, independently maintained
wallet share ledgers, unchanged passive fixture shares, sum of **all** share holders,
zero handler/self-share holdings, both global token custody sums equal each token's
totalSupply, all three local books and zero vault ETH. Custody includes fixture,
wallets, handler, vault, manager and (for P) hook. The follow-up explicitly includes
the zero-funded contract/EOA attacker and callback-token accounts. Known attacks compare complete
expected revert bytes and before/after custody/actor digests. Unexpected reverts
propagate and fail the test; there is no permissive “caught means pass” path.
Attempts/successes/expected reverts and actor/refund-mode non-vacuity are asserted.

The handler uses real manager unlocks and real wallet calls. Previews occur before
atomic funding; selected resting credit deliberately has different semantics and
is not compared to an ordinary unprepaid preview. No tests claim source ownership
of unbooked credit; the different payer/consumer case preserves D15.

## Legacy 24-action assertion disposition (follow-up)

The prior “must integrate all 24 into one new handler” backlog above is replaced
by this **predicate-level** mapping. PRD D24/D30/D31 and plan §8 require preserved
assertions and meaningful lifecycle coverage, not the old class shape, counter
array length, or literal proposed test name. A mapped predicate may be proved by
several real tests. Different actors/contexts are identified explicitly below.

### Exact source locators and evidence labels

- **C32:** `contracts/test/bases/TestBase_UniswapV4FullSpreadCrossModeCampaign.sol`,
  H/P `CrossModeStatefulCampaign.t.sol`; existing 32-step/eight-mode campaign.
- **C48:** `testFuzz_G5_threeActorCreditHistories` and `FullSpreadG5CreditHandler.step`,
  existing 48-step three-actor campaign. Previous version parent-passed; follow-up
  adds stronger passive-account/attacker/allowance digests.
- **M:** new `test_G5_threeActorMixedMoneyAndReentryHistories` and the explicitly
  named methods of `FullSpreadG5CreditHandler` below. **Added, pending execution.**
- **G3:** `TestBase_UniswapV4FullSpreadG3RouteFunding.sol`, instantiated by the
  H/P `RouteFundingClosure.t.sol` main and linear contracts.
- **G4:** `TestBase_UniswapV4FullSpreadG4{Import,Deployment}Closure.sol`, instantiated
  by H/P `ImportDeploymentClosure.t.sol`.
- **G6:** `TestBase_FullSpreadG6TransitionLifecycleClosure.sol`, instantiated by H/P
  `TransitionLifecycleClosure.t.sol`.

The source bodies, including `_executeOut`, `_fundedCall`, `_stagedShortDelivery`,
`_otherHolders`, `stateDigest`, `assertAccounting`, and `assertCampaignCoverage`,
were read for this mapping. Suite names alone are not evidence. The parent-reported
436 checkpoint is retained as its own result; concurrently expanded G3/G4/G6 source
is not automatically certified by it.

| Legacy action | Required predicates in its actual body/helpers | Current mapping / disposition |
|---|---|---|
| **0 — EI deposit pull** | Positive execution, exact input debit/no refund, returned amount equals actual shares, other holders' token/share/approval accounts unchanged, attributed issuance and full booking | C32 modes 0/2 independently reconstruct idle/blocked issuance; C48 `_mint(false)` blocked positive with finite approval consumption; M `_moneyIn(token,shares,...,false,false)` adds idle positive for every actor/face and `_otherHolders` exact isolation. G6 `test_externalTransitionsPreserveHolderClaimSequentially` independently carries both deposits through real swaps and a passive holder's whole claim. |
| **1 — EI deposit push** | Same predicates with atomic real delivery and no refund | C48 `_mint(true)` + replay; H/P `AttributionAndBooking::test_pullAndPushProduceIdenticalMintAndCustody`; M `_moneyIn(...,true,false)` adds all three actor/face idle histories with quote before transfer. |
| **2 — EI share redemption pull** | Exact owned-share debit and burn, positive returned/payout amount, unchanged other holders, no orphan self-shares | C32 mode 4 and `_assertExitAttribution` independent pro-rata removal/fee/conversion; G6 `test_redemptionTransitionAndSYMatchAfterExternalSequence` exact receipt, supply/remaining claim and full fields; M `_moneyIn(shares,token,...,false, idle/blocked)` preserves three-actor mixed mint/burn ledgers and passive accounts. |
| **3 — EI share redemption push** | Atomic delivery, exact share burn/no refund, exact recipient payment, other holders and global custody | M `_moneyIn(shares,token,...,true, idle/blocked)` both faces/all three actors; `consumePretransfer` performs actual wallet self-pull and transfer. Supply uses independently recorded `burned`, not only a quote comparison. C32/G6 supply the complementary independent F2/F6 economics. |
| **4 — EO mint pull** | Positive quote, exact requested shares, only used input debit, approval remainder, other-holder isolation | **Idle success superseded** by plan R4/F5; G3 `test_blockedF1AtomicPushEqualsPullOnRestoredState` and `_gF1` prove supported blocked F1, exact independent inverse input, shares/supply, distinct recipient and exact allowance debit. C48 `_exactShares(false)` adds all actors and finite used-only allowance. C32 mode 3 tests predecessor minimality. No arbitrary idle success is restored. |
| **5 — EO mint push** | Exact requested shares, full/partial/used-only actual credit, bounded refund, unchanged other holders and booking | Same R4 supersession; C48 `_exactShares(true)` covers all three budget modes twice with exact net debit and independently tracked shares; G3 `_gF1(true)` also checks explicit excess refund, prior unprepaid quote and restored pull/push whole-book equality. |
| **6 — EO redemption pull** | Exact output and burn, used-only share debit under fat max, no booked-share theft, custody/supply | **General positive-two-leg success superseded** by plan R6/F2/F6. G3 `test_linearExactOutRefundMatrixBothOrientations`, `_gExitMatrix`, `_gSuccessfulExit` cover real one-backed-leg states, independent ceil, pull exact/fat/short max, exact recipient/supply/holder effects and preserved 31 booked shares. Existing H/P `OneBackedLeg::test_idleLinearExactOutputWithClosedPlacement` preserves the idle positive. These assertions need not be copied into a third linear-fixture handler. |
| **7 — EO redemption push** | Three bounded refund modes, exact payout/burn, short credit/max rollback, unchanged booked inventory | Same supersession; G3 same natural-linear matrix explicitly covers used-only/excess/full/over-max deliveries, short delivery and max. Retained self-share amount = old booked shares + over-max remainder, exact recipient payment and complete local/custody digest. G3 F3 matrix additionally preserves algebraic dual exit refund predicates idle and blocked. |
| **8 — direct EI pull** | Exact input/output, positive swap, no share change, passive holders unchanged | H/P `QuoteExecutionParity::test_directExactInputBothDirections` and real `CoreSettlement` F4 tests; G6 external-swap sequence verifies full next-state/holder-claim projection. M `_moneyIn(token_i,token_j,...,false,false)` adds both directions with all three actor ledgers and allowance/account isolation. |
| **9 — direct EI push** | Same, actual atomic delivery and no EI refund | M `_moneyIn(token_i,token_j,...,true,false)`, quote before funding, both directions/all three wallets; complete global custody/no issuance. Existing quote/core tests provide independent swap settlement reference. |
| **10 — direct EO pull** | Positive applicable quote, exact output, only used input, fat allowance remainder and other-holder isolation | Domain narrowed by plan F4/R2, not waived. Existing `FormulaDomains::test_nonzeroDirectExactOutputAndCombinedPlacement` and `test_reverseDirectionExactOutputSucceedsInsideItsFirstStep` plus C32 mode 6. M `_directExactOut(false)` requires positive success in both directions/all actors after a real first-step-positioning trade; exact `maximum-used` approval remainder. No catch accepting `InvalidRoute` in this positive. |
| **11 — direct EO push** | Exact requested output, measured full/partial/used-only refund and cap, passive isolation | Existing `FormulaDomains::test_directExactOutputPrepaidRefundUsesOnlyCredit`; M `_directExactOut(true)` both directions and the three actor-selected credit budgets, `actual refund == delivered-used`, with `delivered <= maximum` and exact net debit. No quote taken after funding. |
| **12 — share transfer** | Exact sender decrease/next-holder increase, supply unchanged, sum of all holders | C48 `_transfer` + `assertAccounting`, each actor twice; G6/G4 also track unrelated holder/recipient shares. |
| **13 — external trade then five pre-sync probes** | Real movement before any sync; contract EI+EO on each face plus EOA EI; exact payloads, whole digest unchanged, five counted rejects | M `_postTradeFiveRejects`: actual fixture/core trade with explicit changed sqrt price; four contract probes use blocked F1 where EO mint is supported, fifth EOA EI checks bytecode guard. Only view calls and rejected economic calls intervene. Three rounds assert 15 such rejects within the exact 30-rejection total. Current domain projection replaces obsolete idle R4 success, not the delivery check. |
| **14 — donation + repair** | Actor's actual donation, no resulting mint/reward, complete booking/global custody | M `_donationAndRepair` + `_repairWithoutReward` measures exact donor debit and unchanged all-holder account digest/supply; public repair is called by zero-funded handler. H/P `MaintenanceProgress::test_holderRepairSwapsAndAllowsSameTransactionRepeats` and G2 `RegistryMaintenanceObservation` supply the stronger useful-repair/no-reward/independent-terminal proofs. Small mixed-history donations need not force a trade. |
| **15 — trade then funded deposit fee collection** | Actual deployed position/trade, positive funded mint after accrual, booking and ownership | M starts from idle activation with real owned LP; actual trade + five probes is immediately followed by positive idle `_moneyIn` deposit. H/P `AttributionAndBooking::test_priorFeesIncludedOnceAndNotCallerCredit`, C32 `_assertMintAttribution`, G6 actual core fee/checkpoint assertions, G2 pending-own-fee witness and G4 `test_G4_importEarnedFeesOnceAndApprovalsZero` preserve fee attribution, not merely positive mint. P own LP fee stays zero under plan §2.5; P fees/tax are not falsely counted as owned LP fees. |
| **16 — live sleeve changes** | Actual oracle writes to .02/.2/.5/1 and actual repair, custody/supply/no reward | M changes `.02,.5,1,.2`, asserts live target exactly, repairs, asserts unchanged holder accounts and funded blocked mint afterward. Existing `MaintenanceProgress::test_liveSleeveOneMeansHalfTheBookNotAllLocal`/zero inheritance plus G2 establish current target mechanics. Old percentage-of-total interpretation is superseded, not the lifecycle assertion. |
| **17 — contract no delivery** | EI and EO exact zero-credit payload, no free shares/assets and atomic digest | M four contract pre-sync probes each round; G4 `test_G4_importCannotManufacturePretransferCredit` separately covers after actual import on both faces; C32 mode 7 and C48 successful-push replay cover further lifecycle points. EO uses blocked supported F1. |
| **18 — EOA no delivery** | Exact EOA error, no attacker shares/assets or changed custody | M fifth pre-sync probe and `assertAccounting`; G4 imported-state EOA negatives; existing constructor/delegated-wallet tests retain bytecode lifecycle distinctions. |
| **19 — short atomic AND staged delivery** | Atomic short push restores tokens/shares/books/allowances; previously transferred short credit remains delivered/spent after failure; smaller funded retry mints positively | C48 action 3 exact atomic short rollback; **M `_stagedShort`** adds each face/every wallet's prior-transfer retention, exact short payload, consumption of `requested-1`, positive tracked issue, no token refund and all-other-holder isolation. This is the missing second half of the old `_shortAtomic` helper, not conflated with the existing excess-credit minimum failure. |
| **20 — successful push then replay** | Real positive mint followed by exact no-delivery replay rejection and unchanged actor/custody | C48 action 2, both token choices over fuzz histories/all three actors, exact counter six; existing lifecycle/Attribution tests supplement idle/bytecode dimensions. |
| **21 — token reentry** | Callback actually reached lock, outer positive deposit, no attacker asset/share gain, valid later operation | Existing H/P maintenance-reentry test and passing deterministic G5 SY/SE callback tests; **M `_callbackHistory`** integrates recorded **and propagating** SY/SE callbacks for each wallet, callback owns cumulative real shares, exact `IsLocked`, rollback attempts reset, disarm followed by positive funded reuse of the same proxy. Six propagating rejects; 3e18 token-held claims remain exact. |
| **22 — resting partial credit** | Different payer/consumer, payer pays 2× amount, consumer pays zero, consumes requested half, no EI refund, excess booked and replay denied | C48 `_restingPartial`: exact accounts/shares, failure before consume preserves prior transfer, successful consume, exact replay error/counter. D15 expressly permits source-agnostic surplus. No provenance gate invented. |
| **23 — atomic late slippage after actual swap** | Real swap path before minimum error; atomic pull/approval/custody rollback; no issuance/payout | **M `_atomicDirectSlippage`** uses idle direct EI via actual `consumePull`, exact late error, full account/self-approval/manager/hook/local/quote digest before and after. This is distinct from C48 blocked mint minimum failure. Existing G5 idle SY failures and G6 `test_partialConversionLateMinimumRollsBackBothFaces` retain other late-failure paths. |

### Cross-cutting assertions formerly embedded in the 24-action handler

- **Three funded actors/non-vacuity:** C48 still requires every action/actor pairing,
  exact attempts/successes/expected rejects and all three F1 refund modes. M runs
  every wallet through both token faces, both funding modes, actual mint/burn and
  direct swap operations, with exact `mixedMoneyCalls = [27,26,26]` and 30 known
  failures. Setup funding is not counted as execution. There is no dummy “24 actions”
  test name or duplicated action-number assertion.
- **Supply attribution:** handler now asserts `initialSupply + issued - burned`
  and each independently maintained actor share ledger. Sum includes fixture,
  immutable dead sink and real callback-token-held shares; handler, self-share,
  EOA and contract attackers remain zero. G3 separately tests nonzero **booked**
  self-share retention/refunds; these are intentionally different custody states.
- **Other-holder invariance:** M `_moneyIn`/`_directExactOut` and strengthened C48
  `_mint`/`_exactShares` compare balances of both underlyings and shares, and
  approvals to vault/self for every uninvolved wallet plus fixture, sink, handler,
  callback token and attackers. Resting-credit payer is intentionally a participant,
  not a passive account. `_stagedShort` explicitly checks all other holders.
- **Global custody:** sums equal both underlying total supplies after each completed
  action, including manager/hook/fixture/wallets/handler/token/attacker accounts;
  all local books equal actual custody, including zero self-shares and zero ETH.
- **Rollback:** account digests now also include wallet self-approvals, individual
  manager/hook balances, token supplies and all attacker/passive accounts. This
  preserves the old `_accountDigest` checks beyond merely equal aggregate custody.
  G3/G6 add their more detailed Permit2/pool/fee/state observations on their routes.
- **Unexpected revert discipline:** every required positive call propagates errors;
  only explicit negative calls catch and compare exact bytes. No success counter
  increments after a swallowed unexpected failure. C32's documented EO domain
  branch is separate and does not substitute for M's positive direct EO assertions.

### Explicit supersession, without deleting retained security predicates

| Historical expectation | Current authority and disposition |
|---|---|
| Positive `preparePretransfer` workflow/selector | PRD D15–D16, §§11–12 and plan §5 retain direct unbooked-delta attribution; no preparatory credit is required. The legacy **removed-selector negative**, however, is retained by the passing G5 `NoTargetFor`/loupe/ERC165 test. Superseding a positive preparation workflow does not waive that negative. |
| Tight/fixed center or active wing positions | PRD §3 preserves full-range ordinary/imported backing; plan §2.1 and §7 require the current canonical managed position. Old active tight/wing behavior is not current law. G6 `test_fullRangeLifecycleActivationWalkBlockedJoinRepair` **retains** exact full-range min/max usable bounds, salt zero, absence of old tight/wing positions and both alternate full-range salts at each lifecycle stage. No blanket “wing assertions retired” waiver. |
| Sink-free bootstrap, decimal fallback, or absolute dust waiver for composition | Plan §2.1 requires decimal-derived minimum/dead sink and propagated metadata failure; plan §§2.6/6.1 preserve exact relative 1bp protection and decimal-scaled sleeve floor. Passing G5 proxy minimum/metadata/donation tests and existing `BlockedFormulaReference::test_F0DecimalMinimumAndProportionalFloor` retain actual current floors. Old sink-free/fallback expectations are superseded. Valid decimal-floor security predicates are **not** erased. |
| Idle exact-share mint / general two-backed-leg EO redemption | Plan R4/R6, §§2.2/2.3/2.6/2.7 restrict positive domains to blocked F1 and natural linear exits respectively. Funding/refund/burn/recipient/rollback obligations map to those domains as above. |
| Own-share allowance gate | Owner's current instruction and plan §5/current `_secureShareDelivery`: caller may exit own shares without allowance; third-party ERC20 approval and SY context isolation remain tested. |

## Bounded remaining work

1. **Parent validation of this follow-up:** the new mixed-history method and shared
   ledger strengthening have not been compiled or executed here. Parent must rerun
   both G5 leaves (28 intended instances, including the existing 128-run fuzz case),
   then its appropriate combined gate. In particular collect the positive direct-EO
   first-step/CC outcomes and the mixed late-swap/callback error payloads; do not
   convert any unexpected positive failure into a caught-revert success.
2. **No additional source gap is identified for the scoped 24-action predicates**
   after this mapping plus the added M histories. This is a source-level disposition,
   conditional on successful parent validation, not a current-tree PASS. A literal
   new 24-action invariant handler is not an outstanding requirement.
3. **Bounded dimensions remain disclosed rather than invented as new G5 gates:**
   M is ordinary 18/18, G3 natural-linear budgets are blocked 6/6 with both orientations,
   existing idle linear positives are separate, G6 uses its actual 6/6 fixtures,
   and native/import/decimal evidence keeps its own scope. This is not an assertion
   of every route × actor × decimal × native × context cross-product. The broader
   acceptance-map decimal/bootstrap/import questions are not silently closed by a
   24-action disposition. Existing G3/G4/G6 documents may have later worker additions
   awaiting the parent's refreshed combined result.
4. Parent G1–G4/G6/G7, archival/readiness and remaining non-G5 acceptance work retain
   their own owners. No production source or historical control was retired.

Suggested **parent-only**, after artifact preparation and worker synchronization:

```bash
forge test --match-contract '^(HooklessG5GuardClosureTest|PonsFamilyG5GuardClosureTest)$' --fuzz-runs 128 -vv
```

This command was not run. Source review checked imports/interfaces, current guard
order, own-share authorization, real callback flow and per-action counter arithmetic;
it is not a substitute for the parent's compiler/test results.
