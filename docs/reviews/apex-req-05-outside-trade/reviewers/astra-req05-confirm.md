# Astra — REQ-05 execution confirmation

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. No other reviewers' notes were read for this independent confirmation. Read the current controlling PRD, implementation plan and existing execution report in `docs/reviews/apex-req-05-outside-trade/`. The execution report and saved logs are untrusted evidence, not proof by themselves.

## Verdict

**No implementation gap.** The inspected current tests implement the plan's held-token credit sequence separately for hookless, Pons and wings. V3 LocalBook still contains its cited existing sequence. Credit is token custody minus stored book, not a minted-share delta. The three exact-error and post-rejection checks are present, with the original outside trades and later preview/deposit continuations retained.

The hookless/Pons metadata-interface casts are a justified compile-time adaptation of the plan's decimal expression, not a change in amount, route or oracle. The saved final log records **24 passes, zero failures/skips** across the three complete selected suites; this is not an independent rerun.

**Historical scope limitation:** the report claims V3 is byte-identical to its starting HEAD and no production file changed. Current reads confirm the cited V3 sequence matches my earlier direct read, but I did not independently compute a whole-file baseline comparison or a repository-wide production diff. No unauthorized edit is established; I do not promote the report's scope claim to independently verified history.

## Plan-to-source checks

Paths in the following table are under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/`.

| Family/file | Current source facts | Result |
|---|---|---|
| `v4/fullSpread/hookless/AttributionAndBooking.t.sol` | Amount at **40** uses actual token0 decimals through `IERC20Metadata`; held tokens recorded at **41**, outside trade at **42**, unchanged books/supply at **43–45**, no custody added at **46**. Prior surplus at **47**, transfer at **48**, balance-minus-book credit and exact increment at **49–50**. Full error expectation at **54–56**, rejecting true-flag call at **57**, custody/book/supply assertions at **58–60**. | Confirmed |
| `v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol` | Decimal-derived amount at **43**, held tokens at **44**, outside trade at **45**, book/supply invariance at **46–48**, custody invariance at **49**. Prior surplus, transfer and credit equality at **50–53**. Full error at **57–59**, rejecting call at **60**, three rollback checks at **61–63**. | Confirmed independently for Pons |
| `v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol` | Amount at **33** is `7 * 10 ** uint256(token0.decimals())`; held tokens recorded at **34**, separate actor trade at **35**, book/supply invariance at **36–38**, custody invariance at **39**. Prior surplus/transfer/credit at **40–43**; exact error at **47–49**, rejecting target-token call at **50–52**, three rollback checks at **53–55**. | Confirmed with actual post-sort token decimals |

For all three:

- The token is `token0` and the caller/recipient is the existing Solidity test contract `address(this)`. No new prank or EOA caller appears in the new sequence.
- `ISecurePullErrors` is imported. The expected error encodes both `credit + 1` and `credit`, not merely a selector or generic revert.
- No successful deposit intervenes between the new transfer and rejecting call. The only new `exchangeIn` is the rejection control.
- The rollback snapshots are taken after the explicit transfer, correctly preserving that separately transferred custody when the later call reverts.
- Existing successful continuations follow the new block: hookless **61–66**, Pons **64–69**, wings **56–58**. Their preview equality is supplementary, not the new credit oracle.

The existing outside-trade helper/actor paths were directly traced during the earlier independent verification: they perform pool/manager swaps rather than calling the vault. Their invocations remain in these current tests. This confirmation does not claim a fresh runtime trace.

## V3 LocalBook preservation

Re-read `v3/UniswapV3FullSpreadLocalBook.t.sol:49–142`:

- **63–66:** existing explicit token transfers and credit boundary checks.
- **68–75:** direct outside swap, changed deployed inventory, unchanged token books, and repeated credit boundary checks.
- **115–136:** reads actual balance/book/supply, asserts the expected custody surplus, requires the full delivery-insufficiency error, and checks unchanged custody/book/supply on rejection; also checks no pool storage access in the rejection.

These ranges match the earlier source read in this session. V3 remains cited rather than duplicated or replaced by the reserve-reconcile supplement. The report's stronger whole-file byte-identity assertion at `EXECUTION_REPORT.md:19` was not independently hashed or diffed here.

## Decimal-expression adjustment

The plan spells `token0.decimals()` at **39**. Hookless and Pons declare `token0` as `IERC20` in their respective acceptance bases at **26**. The implemented test files add `IERC20Metadata` at **6** and read `IERC20Metadata(address(token0)).decimals()`. The interface forwarding path exists at `lib/crane/contracts/interfaces/IERC20Metadata.sol`.

This reads the same token's decimals and preserves the exact seven-whole-token amount. It is not hardcoding a decimal count, selecting another token or changing production. Wings retains the literal expression on its concrete token type. The report at **15,33–34** explains the initial member-lookup failure and correction; that explanation is consistent with the inspected types. No corrective finding is warranted for this necessary interface cast.

## Validation and scope evidence

`EXECUTION_REPORT.md` exists and records the prescribed command at **25–30**, with exactly the three `--test-root` paths and no production positional source or test-name filter. It reports an initial compile error, a subsequent host-proxy crash, and an approved same-command retry with success. Those are historical claims, not commands run by this reviewer.

Direct search of `forge-validation.log` found:

- All three named outside-trade tests marked passing at **65,73,81**.
- Suite totals of **14**, **5**, and **5** passes at **70,78,86**.
- Aggregate **24 passed, 0 failed, 0 skipped** at **88**.

This corroborates the saved result, not the authenticity of the run environment, current reproducibility or whole-repository safety. No V3 rerun is claimed by the report or this review.

The report's **41** says production, V3, configuration and deployment helpers were unchanged, unrelated documentation edits preserved and the deleted legacy tree not restored. No independently inspected item-specific before/after production diff was available in the evidence read here. Source inspection confirms the requested additions are in the three tests, not that every other repository file remained untouched historically. This is an evidence boundary, not a demonstrated scope violation or a reason to invent production repair.

The plan header still says “Not executed” at **4**. Current source and the separate execution report establish a later state; the stale header alone is not a failed implementation. No PRD/plan rewrite is performed here.

## Findings and disposition

No corrective source finding was established. The earlier missing held-credit oracle is now present in the three named tests, and the owner-selected stronger acceptance scope is met at source level. Historical no-production-edit attribution and whole-file V3 identity remain qualified as above; a saved pass does not replace an independent run.

Files examined without an implementation defect: both complete FullSpread attribution/booking test files, wings Money **1–83**, V3 LocalBook **49–142**, the two FullSpread token-type declarations, and the metadata interface forwarding file. Also read the PRD, plan and execution report in full and the named saved-log results. All supplied input paths were present. The assigned output did not exist before writing.

Only this assigned Markdown confirmation was created. No code, test, PRD, plan, execution report, original review, configuration or instructions were edited. No delegation, shell, build, test or deployment was performed. Return to the coordinator/human and stop.

I did not run Forge.
