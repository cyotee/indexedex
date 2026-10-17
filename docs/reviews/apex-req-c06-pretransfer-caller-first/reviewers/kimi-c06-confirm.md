# Kimi K3 — confirmation: REQ-C06 plan execution

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No reviewers' notes were read. Nothing was edited.
- **Date:** 2026-10-14.
- **Question:** was `docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.plan.md` completed completely and accurately against the current tree?
- **Documents:** the plan (129 lines) and its controlling PRD (98 lines) re-read in full; the claim `EXECUTION_REPORT.md` (73 lines) read as untrusted and checked line by line against current source and the preserved logs. The logs are the implementation session's records, not an independent rerun; I did not run Forge.

## Verdict: complete. No gap found.

Every plan element I checked against current source matches; the report's commands match the plan's; the report's counts match the source state I counted independently. The runtime results are recorded in `.scratch/c06-caller-first/` logs with exit-code files, not re-executed by me.

## Plan-step verification

### Step 1 (stop-on-drift preflight)

The report records that all 21 named lines matched before editing (`EXECUTION_REPORT.md:7`). Current line numbers have drifted exactly as the insertions predict (each measurement line moved down by the inserted block); nothing indicates the preflight claim is false.

### Step 2 — production edits: 20 guarded insertions, one V3 move, four imports — all verified in current source

- **Uniswap V2** (`UniswapV2StandardExchangeOutTarget.sol`): import at `:17`; seven guarded checks at `:464,552,631,704,808,922,992`, each immediately before its `_pretransferCredit` assignment (`:466,554,633,706,810,924,994`). The guarded shape was read directly at `:463-465` (`if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender); }`).
- **Camelot** (`CamelotV2StandardExchangeOutTarget.sol`): import at `:9`; five guarded checks at `:413,518,604,674,780` before the measurements at `:415,520,606,676,782`.
- **Rocket Pool** (`RocketPoolRETHStandardExchangeOutTarget.sol`): import at `:5`; guarded checks at `:61-63` (read directly) and `:87` before measurements at `:64`, `:89`.
- **Lido** (`LidoWstETHStandardExchangeOutTarget.sol`): import at `:5`; guarded checks at `:65-67` (read directly) and `:90` before measurements at `:68`, `:92`.
- **Hookless** (`…Hookless…OutExecuteTarget.sol`): guarded checks read directly at `:94-96` (`pretransferred`, mint) and `:168-170` (`prepaid`, direct-out), before the measurements at `:97` and `:171`; `_requirePrepaidCredit`'s internal gate and comparison remain at `:143`.
- **Pons** (`…PonsFamilyHookOutExecuteTarget.sol`): the same pattern at `:95/:97` and `:169/:171` (grep-verified line positions; bodies not re-read line-by-line this round — the one partial spot-check, flagged honestly).
- **V3 mint move** (`UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol`): the gate now sits in a new guarded block at `:102-104`, before the measurement at `:105`; the later block at `:111-114` keeps the `TransferDeltaInsufficient` comparison and `pullAmount = credit;` with no duplicate gate. The file contains exactly two `requirePretransferCaller` calls (count-verified), so the withdrawal function's gate is intact and no duplicate exists.
- **Helpers untouched:** `_requirePrepaidCredit`, `_secureTokenTransfer`, `_securePull`, `_secureSelfBurn` retain their internal checks (verified at hookless `:143` and in the Commons reads from the review round; the Commons were not edited per the report's diff claim and nothing in my current reads contradicts it).

### Exclusions — verified

- EtherFi `EtherFiWeETHStandardExchangeOutTarget.sol:61,84` still measure with no added gate (read this round).
- The V3 quoted-swap caller-first site is unchanged at `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:82-83` (read this round). The other nine caller-first sites were not re-read this round; they are outside the seven-file edit set and the report's recorded diff is consistent with their being untouched.
- No hit under `contracts/protocols/dexes/uniswap/v4` appears in this item's scope; my review-round inventory found no `_pretransferCredit` calls there to repair, and nothing in the report's recorded file set touches that tree.

### Step 3 — tests: all four controls per branch, no bare reverts, exact counts

- A repo-wide grep for `function test_C06` finds exactly **86** new test functions in exactly the seven named files — V2 28, Camelot 20, Rocket 8, Lido 8, hookless 9, Pons 9, V3 4 — matching the report's table (`EXECUTION_REPORT.md:58-67`) count for count.
- A direct grep across the seven files finds **no bare `vm.expectRevert()`** (independent of the scanner artifact).
- The hookless file was read in detail: `_c06Reject` (`:71-90`) pins `EOAPretransferNotAllowed` for code-less and the fully-encoded `TransferDeltaInsufficient(quoted, 0)` for contract callers with a full state snapshot (tokens, supply, books, deployed reserves); `_c06Success` (`:92-125`) reconciles quote parity, maximum, exact output, exact share issue, and refund; the idle false-flag mint control pins `InvalidRoute` (`:134-147`) per plan `:70`; the nested-session contract path uses the real `_nested` helper per plan `:68`. The other six files' C06 cases were counted, not body-read — flagged as the partial-coverage boundary of this confirmation.
- The current scanner output (`docs/audits/apex-2026-09-17-evidence/bare-expectrevert.txt`) contains no site in any of the seven files; its only family-adjacent hits are the pre-existing decimals variants, which this item did not edit.

### Step 4 — commands and results: recorded and internally consistent

- The report's helper command (`EXECUTION_REPORT.md:20-21`) matches the plan's Step 4 command (`REMEDIATION_PRD.plan.md:100-115`) exactly — same seven sources, same seven test roots.
- The preserved logs exist and agree with the report: `.scratch/c06-caller-first/test-final-exit.txt` records `0`; `test-final.log` shows every suite passing with the report's exact per-suite counts (Camelot 28, Lido 39, Rocket 25, V2 39, V3 15, Pons 15, hookless 15; `:262` totals 176/0/0); `scanner-final.log:318` records `317 bare expectations in 3160 files` — the pre-existing count, so this item added no scanner site. The initial sandbox crash (exit 250, macOS `system-configuration` panic) and the approved unsandboxed retry are recorded with separate exit files, matching the pattern of the earlier REQ-02/REQ-03 rounds.
- The report's arithmetic is consistent: 86 controls = 28+20+8+8+4+9+9; 176 = 15+15+15+39+28+25+39.
- The plan's done-when bullets (`:121-125`) are all evidenced: the diff contents (20 insertions, 1 move, 4 imports), the 21 branches' controls, and the recorded artifact/scanner runs.

## Notes on the corrections the report records

The report discloses two rounds of test-fixture corrections (V2 payer funding, LST fee-share supply reconciliation, `:42-50`). I verified the property that matters: no error expectation was relaxed — the seven files contain no bare `expectRevert()`, and the hookless helpers I read pin exact errors and state. The fee-share reconciliation claim (usage fee included in supply accounting) was not independently re-derived against production code; that is a runtime/logic claim from the report, not something I verified, and no production file changed, so the risk surface is the test oracle only.

## Caveats

- Saved logs are not an independent rerun; I did not run Forge. Provenance of the `.scratch/` records rests on the implementation session's disclosure, including the approved unsandboxed retry.
- The Pons production file's two insert bodies and the six non-hookless test files' C06 case bodies were verified by position/count, not full body reads.

I did not run Forge.
