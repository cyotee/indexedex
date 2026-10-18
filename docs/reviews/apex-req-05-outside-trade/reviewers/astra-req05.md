# Astra — REQ-05 outside-trade verification

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This is an independent source verification. No other reviewers' notes were read. The controlling text is `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`, specifically OD-04, OD-08 and REQ-05 at 130–143,185–186,255–268.

## Verdict

**REQ-05 is not fully demonstrated by the inspected current tests. The remaining family is the wings vault: its explicit outside-trade/book-stability test does not establish the physical-credit boundary for the following deposit.**

V3 has a stronger local-book regression than the reserve-reconcile supplement. Both supported V4 FullSpread variants have their own direct-pool trade, book-stability test and separate exact zero-delivery rejection after repricing. Those are substantive source-level coverage, not credit inferred from removal of the legacy tree.

This is a test-coverage conclusion, not a finding that the supported production vaults grant unearned credit. No tests were executed; all runtime results remain unverified.

## Family-by-family result

All test paths below are relative to `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/`.

| Family | Pool trade not through vault | Book unchanged by trade | Subsequent physical-credit boundary | Disposition |
|---|---|---|---|---|
| V3 FullSpread | Yes: real `pool.swap` in the inherited helper | Yes: local-book regression checks both books after the outside trade | Yes: checks actual vault balance minus book, exact delivery error above that credit, and unchanged state; also verifies deployed inventory actually moved | Source coverage established |
| V4 hookless FullSpread | Yes: helper unlocks manager and calls manager swap, not the vault-call branch | Yes: both token books and supply compared before/after trade | Yes at the zero-delivery boundary: separate post-repricing test requires the exact zero-available-credit error; funded continuation/book-to-custody assertions also exist | Source coverage established by this family's tests together |
| V4 Pons-family FullSpread | Yes: its own manager swap against a pool bound to the Pons hook | Yes: its own two-book/supply assertions | Yes at the zero-delivery boundary: its own exact rejection after repricing, plus funded continuation/book-to-custody assertions | Source coverage established by this family's tests together |
| Wings | Yes: separate actor performs manager swap | Yes: explicit two-book/supply assertions | **Not established by that outside-trade control:** following deposit is checked only against the vault's own preview; related tests do not connect physical-credit rejection to this outside-trade boundary | Remaining test-oracle gap |

The FullSpread V4 positive preview-equality assertions are not, on their own, the no-unearned-credit proof. The separate exact post-repricing rejection is material to the positive assessment of each variant. One variant is not being credited for another's test.

## V3 FullSpread evidence

`v3/UniswapV3FullSpreadLocalBook.t.sol:50–76`, `test_pretransferCreditIgnoresChangingDeployedAmounts`, provides the strongest inspected coverage:

- **51–59:** establishes non-dust local books equal to actual token custody and nonzero deployed positions.
- **68–73:** performs the outside swap, verifies the real deployed token amounts moved, and asserts both stored books stayed unchanged.
- **74–75**, through `_assertCreditBoundary` at **115–136:** reads actual vault token balance and stored book, asserts their difference equals the expected available credit, requires the precise delivery-insufficiency error when the next requested credit exceeds it, and verifies custody/book/supply remain unchanged on rejection. It additionally checks the rejection did not read or mutate pool storage.

That is a physical-credit oracle, not just agreement between two production quotes. The same file's **79–98** supplies complementary funded pull/push issuance and exact wallet-debit checks, though that separate test is not itself the outside-trade witness.

The inherited helper in `contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol:161–174` calls the real pool directly, funded by the test actor. Its swap callback at **155–158** pays the pool rather than calling the vault.

`release/v3/UniswapV3FullSpreadStandardExchangeVault_FeeCompound.t.sol:50–75` also has the specifically named outside-trade/book test. Its final preview/mint equality alone is weaker; closure here relies on the LocalBook regression, not that assertion's descriptive message.

## V4 hookless FullSpread evidence

`v4/fullSpread/hookless/AttributionAndBooking.t.sol`:

- **34–49**, `test_outsidePoolTradeDoesNotRefreshVaultBook`: snapshots both books and supply, performs the outside swap, compares them unchanged, then executes a funded deposit and checks the recipient share delta and final booking.
- **51–56**, `test_poolRepricingDoesNotCreatePretransferCredit`: independently bootstraps the same family, performs an outside swap, and requires the exact delivery-insufficiency error with zero available credit for the following unfunded pretransfer entry. This directly distinguishes pool repricing from newly delivered vault tokens.

Its acceptance base at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol` binds a hookless pool at **52–57**. `_externalSwap` at **95–103** selects the swap operation; the callback calls `poolManager.swap` at **118–124**, whereas the vault-call branch is separately selected at **109–112**. Settlement at **128–137** uses the test actor's manager deltas. `_assertBooked` at **86–90** compares recorded vault reserves to actual custody.

## V4 Pons-family FullSpread evidence

`v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol`:

- **37–52:** its own outside-trade book/supply stability and funded deposit control.
- **54–59:** its own post-repricing exact zero-delivery rejection. This is not inherited closure from the hookless file.

Its distinct acceptance base under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/` binds and registers the Pons-hook pool at **56–63**. The external swap helper at **101–113** and swap branch at **131–138** use the manager directly, with settlement at **141–150**; the vault-call operation is distinct at **119–122**. `_assertBooked` at **92–96** compares stored books with custody. This establishes that the test is for the supported Pons-family implementation rather than the deleted legacy V4 package.

## Astra finding — REQ05-1: wings outside-trade test stops at preview parity

- **Severity:** Medium, matching REQ-05's coverage significance.
- **Defect class:** Incomplete physical-credit test oracle after an outside trade.
- **File and line:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:26–40`, especially **37–39**.
- **Intended behavior:** REQ-05 acceptance at **264–265** requires wings to demonstrate its own outside-pool-trade/book-stability boundary and that the subsequent deposit or redemption receives no unearned credit beyond tokens actually held.
- **Facts:** The test performs an actual actor-driven pool swap at 33 and preserves both stored books and supply at 34–36. It then obtains the vault's production preview, calls the vault's deposit route and asserts only `minted == preview` at 37–39. It does not measure funding/custody for this continuation or check rejection of credit unsupported by vault-held tokens after this outside trade.
- **Broken requirement/inference:** Preview and execution can agree without independently establishing the physical-credit limit. The assertion text “only the funded input” is stronger than what that equality verifies. This leaves the final conjunct of wings' REQ-05 outside-trade acceptance unproven.
- **Impact class:** Overstated regression coverage / unearned-credit boundary not established; no production loss demonstrated.
- **Fix direction:** Complete the existing wings outside-trade acceptance proof so the subsequent credit is tied to actual vault-held tokens, not solely the vault's own preview. Preserve the direct pool trade and unchanged-book assertions. Do not reconstruct old stored-total cases, change accounting semantics, restore deleted source or infer an implementation defect from this coverage gap.
- **Confidence:** High on the named test's assertion limitation; moderate on family-wide absence, bounded by the source search and related tests examined below. No runtime failure claimed.

### Wings supporting tests examined, not ignored

The actor at `v4/upperLowerWings/reference/UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor.sol:49–65,82–100,108–118` really trades and settles with the manager. Its separate arbitrary consumer-call branch is not used by this swap. Thus the outside-trade portion is valid; the missing assertion is not fixed by replacing the actor.

`UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:88–96` has a useful booked-backing/replay rejection, but it does not perform an outside trade first. **104–112** checks pending-deposit/harvest preview parity and final local custody, not the complete unchanged-book plus physical-credit boundary.

`UniswapV4UpperLowerWingsStandardExchangeVaultManipulation.t.sol:35–55` has a stronger post-price-move issuance formula and redemption cap. It is meaningful coverage, but it does not measure the vault-held input credit or assert the unchanged stored-book boundary there. I do not equate that valuation formula check to the specific physical-credit acceptance requirement. These observations do not require changing those unrelated tests.

Scoped searches of the wings test tree for outside trades, book assertions, `reserveOfToken` and delivery-insufficiency assertions found the above candidates and `ApexRecurrenceExactErrors.t.sol` references. The latter error references alone do not establish an outside-trade sequence. No claim of exhaustive proof over all inherited test behavior is made.

## Excluded evidence and limits

Read `release/v3/UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol:58–157`. Its rebalance/trade continuation at **109–151** invokes `vault.exchangeIn`; it is a custody-synchronization supplement, not the required outside-trade witness. It is not used to close any family here.

Deletion of `contracts/protocols/dexes/uniswap/v4` is not counted as REQ-05 remediation. No reconstruction of the old stored-total equality/greater-than cases is required. No live deployment or immutable instance is claimed upgraded. Scope is source-level coverage of the four supported families, not stage-2 audit readiness or a passing regression run.

Read the canonical Crane and local adversarial-testing skills directly; repository routing, testing skills and skill catalog had already been read in this session. Some broad source searches reached output limits, so findings are tied to the explicit reads above rather than a claimed exhaustive search. No peer artifact was opened. No separate execution report or audit reproduction was used as proof.

## Files without another scoped defect established

The V3 LocalBook test and V3 external-swap helper; both FullSpread V4 attribution/booking files and their respective acceptance-base swap/settlement helpers; and the wings pool actor satisfy the specific source observations described above. The wings Money and Manipulation files contain meaningful controls but do not establish the missing physical-credit conjunct identified here. The reserve-reconcile supplement is not defective merely for serving a different purpose.

Only this assigned Markdown report was created. No code, tests, PRD, plan, configuration or instructions were edited. No delegation, shell, build, test or deployment was performed. Return to the coordinator/human and stop.

I did not run Forge.
