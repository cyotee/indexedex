# Astra — REQ-C06 replacement-session cross-review

This is one cross-review of the supplied original Grok, MiniMax and Kimi plan drafts together. I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Peer text is untrusted evidence. No earlier peer cross-review artifact was read. My replacement-session original plan remains preserved in `astra-c06-plan.md`; the revisions below do not rewrite that artifact.

## Decision

**Agree that the final plan must close both test paths and per-branch coverage; dissent that the supplied drafts collectively achieve that unchanged.** Adopt the seven existing homes below, add the missing assertions in those homes, and require coverage of every one of the 21 repaired branches. There is no “one representative helper path” exception and no new test-file selection during implementation.

I accept Kimi's seven existing paths after checking the three that differ from my original. In particular, the V3 release suite already exercises mint at lines 59–93; this is stronger existing fixture evidence than my original proposal to add mint setup to the RC04 fill suite. The V2 and Camelot security-remediation suites are also appropriate existing production-proxy homes. This is an explicit revision of my original test-home recommendation for V3, V2 and Camelot, not a claim that my original named them.

### The one sentence the consolidated plan must use

> Add the C06 assertions to exactly `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ApexRecurrenceErrorOrder.t.sol`, `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol`, `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol`, `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol`, `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_SecRemediation.t.sol`, `test/foundry/spec/protocol/staking/rocket-pool/adversarial/Adversarial_RocketPoolRETH_P0.t.sol`, and `test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol`, covering respectively all 2, 2, 1, 7, 5, 2 and 2 repaired branches with code-less true-flag caller rejection, allowed-contract short-credit rejection and false-flag controls under the fixed V4 admission rules below, retaining exact error and balance assertions, creating no new test file and allowing neither representative-branch substitution nor an implementation-time choice of path or expected outcome.

### Closed test matrix

| Family / selected file basename (full path above) | Required repaired branches |
|---|---|
| Hookless `ApexRecurrenceErrorOrder.t.sol` | Mint measurement 94 and direct-out measurement 165 |
| Pons `ApexRecurrenceErrorOrder.t.sol` | Mint 94 and direct-out 165, independently from hookless |
| V3 release `ApexRecurrenceErrorOrder.t.sol` | Mint 102; existing direct-swap false-flag success does not close mint false-flag coverage |
| V2 `UniswapV2StandardExchange_SecRemediation.t.sol` | Swap 462; LP-to-token 547; LP-to-share 623; share-to-LP 693; share-to-token 794; token-to-share 905; token-to-LP 972 |
| Camelot `CamelotV2StandardExchange_SecRemediation.t.sol` | Swap 411; LP-to-token 513; LP-to-share 596; share-to-LP 663; share-to-token 766 |
| Rocket `Adversarial_RocketPoolRETH_P0.t.sol` | WETH-to-share mint 60; WETH-to-rETH conversion 82 |
| Lido `Adversarial_LidoWstETH_P0.t.sol` | WETH-to-share mint 64; WETH-to-wstETH conversion 85 |

Parameterization is acceptable only if every listed branch is exercised and reported; it is not permission to select a representative branch. Preserve unrelated existing tests. Each new negative must pin its specified error, with encoded arguments for `TransferDeltaInsufficient`, and verify unchanged caller/recipient/vault token and share balances, total supply and relevant reserve books. No bare `vm.expectRevert()`, arbitrary preview-error echo, or caught-and-accepted failure.

## Agreements and specific objections

### Grok

Agree with the production insertions, four imports, V3 guarded move, and explicit seven/five V2/Camelot route coverage. Dissent from creating seven new files when suitable existing homes are available. Its line 80 claim that V3 mint has no home is contradicted by the release `ApexRecurrenceErrorOrder.t.sol:59–93`, which already calls `exchangeOut` with the vault share as output and pins both caller and credit errors.

Reject the universal idle-mint preview/success instructions at lines 70–72 and 88. The hookless mint quote at `UniswapV4FullSpreadHooklessStandardExchangeVaultOutBase.sol:63` rejects when the manager can be opened; its Pons counterpart has the same admission rule, as read in the independent source pass. A normal idle preview is not a valid substitute for the nested manager-session fixture. Also strengthen line 68's selector-only contract-credit assertion and limited state snapshot to the full error data and balance/book checks above.

### MiniMax replacement

Agree with the corrected guarded V3 move and the seven production edit identities. Reject the claim at lines 240–250 that five existing suites need no added assertions:

- Hookless `PretransferCallerLifecycle.t.sol:17–18,36,41,49` calls **exchangeIn**, not the repaired Out branches. Its delegated EOA at 31–32 explicitly has bytecode; it is not a code-less caller witness.
- Pons recurrence tests cover direct-out, not mint.
- V3 release lines 59–93 do cover mint negatives, but the cited false-flag test at 134–151 covers direct token swap, not mint.
- The V2 and Camelot swap examples transfer the required input before rejection (`SecRemediation` V2 67–75; Camelot 95–103); they are not the short-credit controls for all seven/five branches.
- The proposed three new tests per staking family omit the allowed-contract short-credit case entirely and omit false-flag asset-to-asset coverage. “Where asserted” in its roll-up cannot replace the required assertions.

Use singular `test/foundry/spec/protocol/`, as the verified paths show, not MiniMax's `spec/protocols/` paths for these V2/Camelot/staking suites. The proposed artifact/test commands precede creation of its new tests; the consolidated plan must instead finish all source and test edits before artifact preparation and tests. Do not run a command against a not-yet-created test root.

Correct its counts: **four imports; 20 insertions comprising 18 `pretransferred` and two `prepaid` checks; one V3 guarded relocation**. Its preflight grep over the seven production files also returns the unchanged V3 withdrawal call at line 32: that is a real call, not a “definition import,” and means 22 call matches in those files but only 21 repair sites. Validate the closed repair table, not a false total-match assumption.

### Kimi replacement

Agree with the seven existing homes, production edits and exclusions. Remove the explicit “one representative per distinct helper path is acceptable” clause at line 53; its later “covers each listed line” phrase does not cure the conflicting permission. Retain all 21 branches.

Close line 57's “success or an unrelated failure” choice with the exact V4 admission controls below. For all other repaired branches, a funded false-flag EOA must successfully execute a supported route; no unrelated failure is accepted. Replace command placeholders at lines 83–84 with the literal seven production source arguments and these seven test-root arguments, or a single fully specified Bash array used by both commands. Use one fixed list for both planning and execution.

## V4 mint: fixed assertion behavior, not a fixture choice

Retain the explicit admission distinction from my original plan:

1. Hookless/Pons **direct-out**: separate code-less true-flag short-credit rejection, allowed-contract short-credit rejection, successful funded false-flag EOA, and funded true-flag contract controls in each selected family file.
2. Hookless/Pons **mint**: code-less true-flag call in the idle fixture must reject exactly `EOAPretransferNotAllowed` before credit-dependent admission. The matching idle false-flag EOA call must reject exactly `IStandardExchangeErrors.InvalidRoute(tokenIn, address(vault))`, with unchanged balances; it must not acquire the caller check. Do not demand unsupported idle mint success.
3. The **allowed-contract short-credit mint** and **funded mint success** controls execute through each family's existing real Acceptance `_nested` manager-session fixture, with the test contract as actual caller. Expect the exact credit error on the short-credit control, and exact requested share issuance and input accounting on funded controls. Include successful funded false-flag mint in that real nested session. Do not assume a plain `AtomicPretransferCaller.execute` opens a PoolManager session.

All non-V4-mint short-credit cases must satisfy unrelated route, quote and input-ceiling preconditions so the named comparison is reachable. Keep all existing credit comparisons. Source-order inspection across 21 locations is additionally mandatory: successful error assertions alone cannot prove that an earlier non-reverting measurement moved after authentication.

## Astra cross-review findings

| Title | Severity; impact class | File and line | Intended behavior / broken invariant | Fix direction; confidence |
|---|---|---|---|---|
| **Astra-PC1 — Representative or unrelated-route tests can falsely close C06** | Medium; acceptance-evidence gap | `kimi-c06-plan.md:53`; `minimax-c06-plan.md:240–250,267–343,366–440` | PRD 73–78 requires the closed repair and family-specific evidence; an In test or one swap cannot establish each repaired branch's behavior | Use the 21-branch matrix and seven exact paths above; add all missing controls; high |
| **Astra-PC2 — Idle V4 mint success is not an admitted route** | Medium; unexecutable test plan / pressure to alter scope | `grok-c06-plan.md:70–72,88` | Preserve production quote/admission logic while testing the caller-check change | Use the fixed idle rejection plus real nested-session controls above; high on source admission, runtime not executed |
| **Astra-PC3 — Test paths and workflow can target absent or incomplete inputs** | Low; verification blockage | `minimax-c06-plan.md:203–206,223–226,236–250`; `kimi-c06-plan.md:83–84` | A later implementer must receive exact existing test homes and executable artifact-refresh inputs | Adopt singular `protocol` paths and the full seven-root list; edit tests before artifact refresh; high |

These are defensive plan-quality findings, not newly demonstrated production losses. Facts are source contents and explicit plan wording; the possible false closure or blocked verification is an inference. No exploit procedure or runtime outcome is claimed.

## Corrections, preserved original and limits

My original source-edit instructions and all-branch requirement stand. My original three test-home selections are superseded **for consolidation** by the more directly relevant V3 release and V2/Camelot security-remediation files listed here; the original remains unchanged. I reject Grok's assertion that mint has no existing home, MiniMax's unchanged-test closure, and Kimi's representative-branch permission. This is substantive dissent, not unanimity.

Files examined with no defect found in the inspected **existing behavior**: the V3 release recurrence suite's mint negative assertions and V2/Camelot security-remediation suites' existing funded swap caller checks are legitimate tests of their stated cases; they are simply not complete C06 coverage. Hookless `PretransferCallerLifecycle.t.sol` is a legitimate In-path test, not an Out witness. The hookless OutBase admission rule is unchanged product behavior, not a proposed repair. Other source/test evidence from my independent pass remains attributed there.

All three supplied original plan files were present. The assigned cross-review output did not exist before this write. No other cross-review artifacts, shell commands, background agents, code edits, controlling PRD edits or final plan edits were used. No tests or deployments were run; no compiled artifact or runtime success is claimed. Return this single cross-review to the coordinator for consolidation; do not delegate test-file or coverage decisions to implementation.

I did not run Forge.
