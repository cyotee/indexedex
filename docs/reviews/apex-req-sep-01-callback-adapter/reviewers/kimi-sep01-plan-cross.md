# Kimi K3 — cross-review: REQ-SEP-01 plan drafts

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. MiniMax is the labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t` (does not recall `ses_ebdf718feffemWQNf7wuTpapqX`). My draft is `kimi-sep01-plan.md`. The three peer drafts were read in full as untrusted output; `scripts/forge-artifacts.py` and `docs/testing/ARTIFACT_BUILDS.md` were read directly this round to settle the command. Nothing was edited.
- **Date:** 2026-10-16. I did not run Forge.

## The edit content: unanimous, no objection

All four drafts specify byte-identical outcomes: helper signature `_assertNoMaxAllowances(IStandardExchange subject_, IERC20 token_) internal view` (the PRD-locked form, adopted by MiniMax from its own `adapter_` variant — the rename is recorded and correct), the same five `address(adapter)` → `address(subject_)` substitutions at `:110, :114, :118, :120, :121`, the same five call-site replacements (`adapter` ×4, `locked_` at `:520`), the same preserved witnesses (`:513-521`, rollback twin, fixture member), and equivalent stop conditions (MiniMax's ten enumerated stops are the most explicit and are compatible with everyone else's). No disagreement on the edit exists.

## Assigned question — the forge-artifacts.py command: dissent from Astra and MiniMax; Grok's minimal form is correct

The drafts propose four commands:

| Draft | Command shape |
|---|---|
| Astra | `test contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol --test-root <test-file> -- -vv` (production source as positional, "artifact-refresh input only") |
| Grok | `test --test-root <test-file> -- -vv` (no positional, no `--consumer`) |
| MiniMax | `test <test-file> --test-root <test-file>` (test file as positional source) |
| Mine | `test --consumer <test-file> --test-root <test-file> -- -vv` |

I verified against the script, not the drafts: `sources` is `nargs="*"` (zero allowed, `forge-artifacts.py:390`); `test` requires only `--test-root` (`:401`); and at `:352-354` the `--test-root` selection is automatically added to `runtime_consumers` — **the test file is already scanned as a consumer**, so its literal artifact references (including the `BalancerV3SinglePoolStandardExchange` creation-code literal in `_deployProbePool`) are discovered and refreshed from current source with one targeted build, while `--skip` excludes unrelated roots. Consequences:

1. **Astra's positional production source is a misuse of the positional channel**, which the tool documents as "Edited Solidity source paths" (`:390`; ARTIFACT_BUILDS.md `:5`). This item edits no production source — the assignment says so itself. Passing an unedited production file misstates what changed to the dependency planner. It is functionally harmless (it refreshes a current artifact) but unnecessary, and it teaches a wrong pattern.
2. **MiniMax's positional test file is a no-op misuse**: test files are excluded as independent roots (ARTIFACT_BUILDS.md `:55`; the script's `non_source_helper` filter). The run still works because `--test-root` drives it — but the positional argument does nothing, and MiniMax's note (`:162`) that the executor then "runs the targeted test" in a separate step misreads the tool: the `test` action builds **and** runs in one command (`:340-370`, `:425`+). There is no second step to schedule.
3. **My own `--consumer` flag is redundant**: the test root is already a consumer via `:352-354`. I withdraw it.

**The one command the plan must use** (from the repository root, after the test-only edit, warm `out/` and `cache_forge/` present, no profile/`FOUNDRY_TEST` changes, no `via_ir`, no cache deletion):

```bash
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol -- -vv
```

Zero positional sources — none is edited. One `--test-root` — the only file in scope. Failure stops the run before tests (the helper's behavior); a failed corrected assertion is reported, never patched around.

## Agreements to carry into the consolidated plan

- Stop rule before the first edit: the helper definition at `:108`, the five `address(adapter)` positions, and the five call sites must match the cited text; any drift stops the batch (all four drafts agree; MiniMax's grep-based sixth-call-site check is a good addition — adopt it).
- `IStandardExchange` is already imported (`:15` per MiniMax's read; consistent with the fixture declarations at `:58`); no import edit.
- No nonce/expiry additions; no `catch`; no fixture retargeting; no production edit; no test-name filter — the whole file runs.
- Astra's forge-patience and MiniMax's "wait for process exit" notes (cold compiles can run long) are consistent with repo rules; carry them as one sentence.

## Corrections and unresolved dissent

- Correction recorded: my draft's `--consumer` flag is withdrawn (redundant per `:352-354`).
- Astra's and MiniMax's positional-argument forms are dissented from above; neither breaks the run, but the plan should not enshrine a misuse.
- No dissent remains on the edit itself. Consensus is not proof: the corrected assertions have not been executed by any reviewer, and a green run of the fixed test is evidence still to be produced by the later authorized session — not claimed here.

I did not run Forge.
