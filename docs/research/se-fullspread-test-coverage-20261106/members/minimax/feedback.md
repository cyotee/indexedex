# Advisory feedback — explicit test coverage draft

## Identity

| Field | Value |
| --- | --- |
| Member | minimax |
| Profile | research |
| Phase | advisory review |
| Requested role | council-member |
| Requested model | `minimax/MiniMax-M3` |
| Admitted reasoning | adaptive thinking, admitted as not a selectable depth |
| Actual runtime identity | not exposed |
| Task ID | not exposed |
| Draft under review | `docs/research/se-fullspread-test-coverage-20261106/coordinator/draft.md` |
| Draft ID | `draft-se-fullspread-test-coverage-20261106-r1` |
| SHA-256 | `06d3ebde19da79aca7d0626c340823931feb4d2c4e860f78aa9db41a37c5bff6`, coordinator-supplied, not recomputed |

I read the draft and the four documents the brief admits: the family plan, the family PRD, the remediation PRD, and the published remediation plan. I did not read peer responses. No sub-agent was launched. No test, build, install, deployment, or Git action was run. No draft, plan, PRD, or peer file was edited. This feedback does not authorize implementation and does not replace the draft.

## Disposition

**requested-changes**

Every concern below asks for an added row, not for an edit to a row the draft already states. The draft's structure, its file-key table, its per-row direction coverage, and its preservation of the closed product choices are correct and should not be disturbed. The requested changes are that the row set be brought up to the draft's own rule, "a row is required when any admitted document already requires it," and to the admission rule in the brief, that a requirement named only by reference is not coverage until the file, the row, and the assertion are named.

## What the draft states accurately

These are correct as written and should survive into the inserted section unchanged.

- The file roots and the short file keys are clearer than the family plan's full paths, and they are correct.
- The three brief gaps are addressed: the standalone routes are enumerated rather than sampled (M01–M13), preview-equals-execution is named for mint, pass-through, one-token exit, bundle-in, bundle-out, the zero exact-out view, and every hook row (P01–P07), and each section 12 row is named with its other leg and its converting leg (H01–H10).
- The closed product choices are preserved without restatement drift: the 49% `mulDiv(processed, 49, 100)` swap with no retry, no exact-output size, no root, and no tick walk (M01); no swap at or outside the stored bounds (M02, M06); the collapsed candidate refunding the whole input and minting nothing (M03); `MinLiquidityNotMet` before any refund (M04); the four-part executed exit receipt and `AmountOutNotMet` before the burn (M08, M09); the three gas ceilings with the cold-body and no-preview-warm-up rules (G01–G04); `seBooked()` reporting no balance and the empty capacity overrides staying empty (K03); and no `asset()` rescue of a rejected bind (Hook integration preamble, Not a test).
- The FS-HOOK-04 handling is right: a rejected identity bind is recorded, not passed, and FS-A26 stays open until the identity record itself runs.
- The Not a test list is right in substance, including that the preview-index walk is not certified and that the V3 matrix rows are preserved.
- M14's retention list, the "each face" and "each stored bound and outside" qualifiers, and the P07 rule that `previewExchangeOut` is not a positive quote are all improvements on the family plan's own phrasing.

## Concerns

### C1 — Stop section: the completeness rule is measured against the wrong denominator

- **Draft section:** Stop, final paragraph.
- **Concern:** The Stop rule makes completeness a function of this draft's own row list. The row list is narrower than the union of the four admitted documents, so "every row in this draft is true" can be satisfied while coverage is still incomplete.
- **Why two readers could diverge:** A coordinator applying the Stop rule as written concludes the coverage section is complete once its rows pass. A coordinator applying the brief's union rule and the family plan's section 13 assignment table concludes the same section is missing the issuance and fee rules, the pretransfer path, the route rejections, most of the borrowed-path acceptance rows, the fixture construction, the permit domain, and several audit-inventory rows. The two readers reach opposite answers on whether the section is complete, and the section is the artifact the remediation plan will point at.
- **Requested change (advice):** State in the Stop section that completeness is measured against the union of the four admitted documents rather than against the draft's row list, and treat the additions in C2 through C9 as required before the section is inserted, not optional.

### C2 — Standalone money and maintenance (M01–M17): the issuance and usage-fee rules have no row

- **Draft section:** Standalone money and maintenance, rows M01–M17.
- **Concern:** No row in this section states FS-A05, FS-OWN-11, FS-OWN-24, or the `yes` inventory rows 010, 011, 022, 034, and 044. The only trace of the fee is the words "net recipient shares" in P01 and the "requested fee portion" in M09.
- **Why two readers could diverge:** One implementer mints gross shares to the depositor and treats the 1,000-share floor as part of the gross amount; another takes the fee out of gross shares, mints the floor to `address(0)` separately through `_mint`, and clamps the fee at 30%. A third reads "net recipient shares" as the whole fee rule and applies the raw oracle fee while previewing the clamped one. All three satisfy M01 and P01 as the draft words them. The family PRD forbids the third outright ("Do not preview the raw oracle fee and execute the clamp"), which is why the silence matters.
- **Requested change (advice):** Add a row in this section that names the issuance and fee obligations: the first deposit creating one full-range salt-zero position owned by the diamond; the 1,000-share floor minted to `address(0)` through `_mint` and counted in `totalSupply()` but kept outside `grossShares`; `grossShares` as added liquidity minus 1,000 on the first deposit and added liquidity times supply before over liquidity before later, with the denominator being existing liquidity before the add and with booked balances and collected fees excluded from it; `feeShares` as `mulDiv(grossShares, clampedFee, 1e18)` minted to `feeTo` with `grossShares - feeShares` to the depositor, a zero mint skipped, and no fee on the fee shares; the 30% clamp applied in this vault's read and not written to the oracle; no extra mint and no round trip moving existing holders' value to `feeTo`; 1e13 precision; and the direct-transfer and no-over-mint rules on both unlock paths.

### C3 — Standalone money and maintenance (M01–M17): the pretransfer path and the pre-mint booking rules have no row

- **Draft section:** Standalone money and maintenance, rows M01–M17. The word `pretransferred` does not appear in the draft.
- **Concern:** FS-OWN-32, FS-A07's booking half, and inventory rows 039 and 036 have no row.
- **Why two readers could diverge:** One implementer treats `pretransferred == true` as a trust flag and spends the whole sitting balance of the vault; another spends the available unbooked balance up to the caller's maximum, refunds the maximum minus the amount used, reverts a bundle whose declared maximum exceeds a token's unbooked balance before any leg, and treats a one-token maximum above the unbooked balance as not itself a revert. The first reading would refund a balance the vault holds for another call and would not revert a bundle that must be atomic. Separately, one implementer swaps the `feesAccrued` returned by the add into the deposit, which FS-OWN-30 forbids outright.
- **Requested change (advice):** Add rows in this section that name the pull path (pull the full declared amount, not only the amount later consumed, then refund the unkept amount of that token so that declared equals consumed plus refunded, with refunded wei not credited as a deposit and not booked); the pretransfer path (use the available unbooked balance up to the caller's maximum; when the maximum is within that balance refund the maximum minus the amount used rather than the whole balance; when the maximum is larger, refund the unbooked balance, spend none of it, pull no shortfall, and do not treat the larger maximum as a revert; a bundle over-max reverts before any leg with no new error and no pinned selector; an address without bytecode cannot pretransfer); the rule that a staged pretransfer is not credited to a later caller; and the rule that `feesAccrued` from a share-minting deposit is booked, is not share credit, and is not swapped into the deposit.

### C4 — Standalone money and maintenance (M01–M17): the section 6 check-order rejections have no row

- **Draft section:** Standalone money and maintenance, rows M01–M17.
- **Concern:** The family plan's section 6 check order has no row. Of the twenty-seven accepted error names, the draft names only `InvalidRoute` (through M14's retained test name), `AmountOutNotMet`, `MinLiquidityNotMet`, `MinAmountNotMetAt`, `ExchangeOutNotAvailable`, `ManagerAlreadyUnlocked`, and `InvalidComponent`. `EmptyExchange`, `TokenNotExchangeable`, `InvalidRecipient`, `EOAPretransferNotAllowed`, `AmountsLengthMismatch`, `ExchangeBundleInForSingleOutNotAvailable`, `ExchangeBundleOutNotAvailable`, `DuplicateOutput`, `TokenAmountsLengthMismatch`, `VaultDisabled`, and `DeadlineExceeded` are absent.
- **Why two readers could diverge:** Two implementers can pick different errors for the same condition, or one can accept a zero recipient and one can reject it, and both can satisfy M01–M13. The absence is most consequential where the error choice is itself the requirement: `MinAmountNotMetAt` at the caller's index rather than `MinAmountNotMet`, `AmountOutNotMet` rather than `MinLiquidityNotMet`, and `DeadlineExceeded` before `VaultDisabled` rather than after.
- **Requested change (advice):** Add rows in this section that name each route's check order and its errors: for `exchangeIn`, `InvalidRoute`, `EmptyExchange`, `TokenNotExchangeable`, `InvalidRecipient`, `EOAPretransferNotAllowed`, and `AmountOutNotMet` on the final output; for `exchangeBundleInForSingleOut`, `AmountsLengthMismatch`, `ExchangeBundleInForSingleOutNotAvailable` with no success path, `InvalidRecipient`, `ManagerAlreadyUnlocked`, and `MinAmountNotMetAt`; for `exchangeBundleOut`, `ExchangeBundleOutNotAvailable`, `DuplicateOutput`, `TokenAmountsLengthMismatch`, `MinAmountNotMetAt` at the caller's index, and the rule that parked shares are not burn credit; for `exchangeOut` on an enabled vault, `ExchangeOutNotAvailable`; and for the disable and deadline predicate, `DeadlineExceeded` before `VaultDisabled`, with views not reverting and a buffered withdrawal still succeeding.

### C5 — Preview equals execution (P01–P07): the quote-liveness and view rules have no row

- **Draft section:** Preview equals execution, rows P01–P07.
- **Concern:** Inventory row 041 (dust ticks must not freeze a normal deposit and redeem through an undocumented cap), inventory row 051 (a preview that returns an amount must not be rejected by an impact check that execution does not run), and FS-A32 (no economic view reverts by a vault error, including while the manager is busy or unlocked, and `reserves()` wraps the deployed-reserve reads including unpaid fees with no local snapshot) have no row.
- **Why two readers could diverge:** One implementer adds a step cap or a minimum spacing to the quote so that a dust-tick deposit terminates, and the cap passes every preview-equality row in the section; another does not. The family PRD states the cap is forbidden and that the dust-tick case is a test and not a new spacing rule. A second divergence: one implementer lets a view revert while the manager is unlocked, another does not, and neither row distinguishes them.
- **Requested change (advice):** Add rows in this section that name the dust-tick liveness case as a deposit and a redeem that complete through the quote the family plan specifies, with no cap and no minimum spacing added, and that name the view rule, including that a busy or unlocked manager is not a view revert and that `reserveOfToken` returns zero for an address that is not in `vaultTokens()`.

### C6 — Package and fixture (K01–K04): the permit domain, the selector detail, and the fixture's construction obligations have no row

- **Draft section:** Package and fixture, rows K01–K04.
- **Concern:** K01 covers FS-A01 through FS-A04. The family plan assigns the permit domain to `Package.t.sol` as a separate item, the family plan's section 5 forbidden-selector list is not enumerated, and the fixture's construction obligations are not stated: production package and bound IndexedEx registry rather than the V3 package, one bound hookless PoolKey with hook `address(0)`, the two faces as the backing PoolKey currencies in `currency0` and `currency1` order with WETH substituted for native, the faces sorted so `currency0` is the lower address, the `currency0` provider with `rateTarget` equal to `currency0` and the `currency1` provider with `rateTarget` equal to `currency1` against the same vault, bootstrap by one bundle deposit of both faces through the public bundle route, and the refund tuple read as `amountOut`. Inventory rows 032, 042, and 013 also have no row.
- **Why two readers could diverge:** One implementer builds the fixture with a single rate provider, or with the V3 pool, or with the faces in the wrong order, and every hook row in the section then measures a different configuration while still passing the row's own assertion. Another implementer omits the permit domain check and the domain name and version go unverified. The family PRD requires one rate-provider instance per underlying token and two pools that hold the same vault at different `rateTarget` values.
- **Requested change (advice):** Add rows in this section that name the permit domain (the domain name is the generated `PkgArgs` name, the version is `"1"`, and the symbol is hardcoded `UV4X`); that enumerate the forbidden selectors from the family plan's section 5 and the interface ids to advertise and not advertise; and that state the fixture's construction obligations listed above, including the two providers and the bundle-deposit bootstrap. Add rows for inventory 032 (no unprivileged post-deploy selector), 042 (a token whose `approve` returns no bool can be used), and 013 (the ERC-4626 `deposit` selector absent and a pre-existing balance minting nothing).

### C7 — Hook integration (H01–H10): the product-index cases are named on only two rows, and two override rows are stated by reference

- **Draft section:** Hook integration, rows H01–H10 and the common-adaptation paragraph.
- **Concern:** The family plan's index rule states that for each two-currency product pair that includes this vault's face the row has two index cases besides the rate-target cases, one minting the counter-leg token below the face so the face is product index 1 and one above it so the face is product index 0, and that the index is asserted before the swap. The draft carries that assertion in H02 and H06 only. It is absent from H01, H03, H05, H07, H08, H09, and H10, although the family plan names it explicitly for the dual, orbital, constant-product single, weighted two-leg, and Balancer two-leg rows. Separately, the common-adaptation paragraph defers the partial-consumption and rollback overrides "as the family plan states", and omits the direct `previewExchangeOut` zero assertion, the enabled `exchangeOut` revert on the vault as distinct from the hook path, the exact-out half of `test_row_poolManagerSwap_bothDirections_noFaceResidual` reverting while the exact-in half stays, and the rule that the seven behavior contracts are not edited to change another family's expected amounts.
- **Why two readers could diverge:** The product index decides which leg is the buffered leg and which is the transfer. On the rows where the index is not asserted, an implementer can leave the face at product index 1 in both cases and the row still satisfies "exact-input both ways", because the direction that mints the vault's shares depends on the index. The reader of the deferral "as the family plan states" also has to open the family plan to learn that the partial-consumption override is two assertions with the hook's balance increase, and that the rollback override forces `AmountOutNotMet` with unchanged shares, face balances, and the vault's face balance.
- **Requested change (advice):** Add the product-index assertion to every hook row whose topology forms a two-currency product pair that includes this vault's face, naming the two index cases for that row, and keep the per-row index statement already present in H02 and H06. Replace the deferral "as the family plan states" with the two assertions themselves, so the common-adaptation paragraph names the no-refund control, the hook balance increase, the forced `AmountOutNotMet`, and the unchanged balances. Add the direct `previewExchangeOut` zero assertion and the enabled `exchangeOut` revert as distinct from the hook-path revert, add the exact-out half of the both-directions row, and add the rule that the other families' expected amounts and their other-family assertions are not edited.

### C8 — Migration (R01–R02): the check that a migrated reader uses `amountOut` is not named

- **Draft section:** Migration, rows R01–R02 and the introductory paragraph.
- **Concern:** R01 names the index and states the rule that a reader which values the result uses `amountOut`, plus the repo-wide compile gate. R02 names the two production assignments the family plan names. No consumer and no observable check is named, and the family PRD enumerates a specific verification set that the draft does not use: the six length gates that reject a non-32-byte success, the three ABI bindings that still declare one word, and `contracts/test/bases/FundedThresholdAssertions.sol`, which decodes one word without a length check.
- **Why two readers could diverge:** One implementer migrates only what the index lists plus the two named production assignments, and the enumerated gates keep rejecting the 64-byte return because a gate treats a non-32-byte success as failure; the repo-wide compile still passes, because a gate that returns 0 on a length mismatch compiles. Another implementer migrates the enumerated set and proves it. The draft's row does not distinguish them, and the brief requires the check itself to be named, not only the rule.
- **Requested change (advice):** Add a row in this section that names the verification set the family PRD enumerates and the observable check for each family: a length gate accepts the 64-byte return and reads the first word, the live preview returns the previewed `amountOut` rather than 0, the empty-supply preview still returns 0 without treating 64 bytes as failure, the wrapped target returns `(true, value)` rather than `(false, 0)`, the three bindings declare the two-word return, and the helper decodes the tuple. Naming these is not inventing consumers; they are named in an admitted document.

### C9 — Not a test: the integration-only inventory rows are unaddressed

- **Draft section:** Not a test.
- **Concern:** The bullet covers the inventory rows marked `no`. The family PRD also states that a row marked integration only stays integration only, and the draft gives that class no disposition. Inventory rows 014, 015, 030, and 043 fall here, and the family PRD names them specifically as hook code that must not be counted as a vault fix.
- **Why two readers could diverge:** One reader adds a test for each integration-only row because the draft's Not a test list does not exclude them; another drops them silently. The family PRD requires them to remain integration-only records of hook code.
- **Requested change (advice):** Add one bullet stating that the inventory rows marked integration only stay integration-only records of hook code, are not counted as a vault fix, and are not new test rows.

## Limits

- This is advisory feedback on one draft. It does not authorize implementation, does not replace the draft, and does not edit the draft, the plans, the PRDs, the peer files, or my own response.
- No test, build, install, deployment, or Git action was run, and no draft row is claimed to pass or fail.
- Every concern is grounded in the four admitted documents and in the draft text. Where the draft already carries an obligation, this feedback says so rather than duplicating it.
- The coordinator's SHA-256 is recorded as supplied and was not recomputed.
- The concerns are additive. If the additions in C2 through C9 are made, I would expect no further disagreement with the draft's structure or with its treatment of the closed product choices.
