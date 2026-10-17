# Astra — REQ-SEP-01 replacement-session plan cross-review

This is one cross-review of the supplied original Grok, MiniMax and Kimi plan drafts together. I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. MiniMax is the labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`, without memory of `ses_ebdf718feffemWQNf7wuTpapqX`. Peer notes are untrusted evidence. No earlier peer cross-review artifact was read. My original `astra-sep01-plan.md` remains preserved.

## Decision: use Grok's command

**Agree with Grok's zero-positional-source command.** The other commands add unnecessary inputs for this test-only task. The repository helper itself supplies the selected test as a runtime-artifact consumer, so neither an explicit production source nor a duplicate `--consumer` is required.

### The one command the consolidated plan must use

From the repository root, after the separately authorized test-only edit:

```bash
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol \
  -- -vv
```

Use this command without additional positional sources, `--consumer`, `--no-consumer-artifacts`, test-name filters or another test root. Use the default hermetic profile and unchanged compiler/source/output configuration. Preserve `out/` and `cache_forge/`; apply the existing warm-worktree rule where needed. Do not edit production or the artifact helper.

The command executes both phases itself: prepare runtime artifacts, then run the whole selected test file. No second standalone `forge test` is required. If artifact preparation fails, it must stop before tests; if an assertion fails, report it without weakening checks, clearing allowances in the test, adding a catch or changing production.

## Direct script evidence

I read the current `scripts/forge-artifacts.py`, not external CLI examples:

- **297–312:** an exact `.t.sol` test root becomes a singleton consumer set.
- **340–357:** `test_plan` adds those test consumers to `runtime_consumers` by default unless `--no-consumer-artifacts` is supplied.
- **214–253:** the graph follows consumer imports and literal runtime artifact identifiers, resolves their source files and adds them to build roots, including linked-library dependencies. The selected test already names the production adapter's creation artifact in its deployment helpers, as inspected in the independent pass.
- **377–384:** the artifact build runs first; a nonzero build exit returns immediately; tests run only afterward.
- **389–395,401–415:** positional `sources` use `nargs="*"`, so zero is supported; `test` requires `--test-root`, not an edited production source.
- **427–428:** action `test` calls `execute_plan` with `run_tests=True`. It is not merely a build-preparation action.

These are source-based command-semantics observations, not evidence that this command was executed or passed.

## Peer agreements and corrections

### Grok

Agree with its command at `grok-sep01-plan.md:76–81` and its prohibition on disabling automatic consumer discovery. Agree with the exact helper, all five owner substitutions, five call-site arguments, and preserved lock/budget/rollback assertions.

### MiniMax replacement

Its command at `minimax-sep01-plan.md:149–153` passes the selected test both positionally as a changed source and as the test root. The current script can accept this; I do **not** claim it necessarily fails. It is redundant for this case and unnecessarily presents a test source as a changed-source build input. Use the single command above instead.

More importantly, lines 162 and 204 describe a subsequent targeted test execution as a separate step outside the plan after the helper runs. That conflicts with the actual helper behavior: `test` already executes the selected tests after preparing artifacts. Remove that separate-run requirement; record the one command's build and whole-file test outcomes.

Keep its exact assertion repair, but do not demand that the entire checkout have exactly one dirty file. The task's own edit is limited to one test file; unrelated pre-existing changes must be recorded and preserved.

### Kimi replacement

Its explicit `--consumer` at `kimi-sep01-plan.md:51–56` repeats the consumer already inserted by `--test-root`. The script collects consumers in a set, so this is not a demonstrated correctness failure. It is unnecessary, and the consolidated plan should not offer it as a second command option. Its whole-file run and stop-on-corrected-assertion-failure instructions are appropriate.

### Correction to my original

My original command named the unchanged `BalancerV3SinglePoolStandardExchange.sol` as an explicit artifact-refresh input. That did not authorize a production edit and is supported by the helper, but direct inspection establishes that automatic test-consumer discovery is sufficient and more narrowly expresses this task. **For consolidation, replace my original command with the zero-positional-source command above.** The original artifact is not rewritten and no change of production scope is implied.

## Astra plan-quality finding

**Astra-SEP01-PC1 — The draft splits testing from a command that already runs tests.**

- **Severity:** Low.
- **File and line:** `minimax-sep01-plan.md:162,203–204`.
- **Intended behavior:** One artifact-aware invocation builds required runtime artifacts and runs the whole named test file, with results reported and no production edits.
- **Broken invariant:** The prose/checklist treats targeted test execution as a later separate step even though `forge-artifacts.py test` already runs it.
- **Impact class:** Verification-workflow ambiguity / unnecessary duplicate execution.
- **Fix direction:** Use the one command above and record its build and test outcomes together; delete the subsequent independent test-run requirement.
- **Confidence:** High, based on `execute_plan` and the `test` action dispatch.

No production allowance leak or production defect is claimed. The owner subject correction remains test-only: `IStandardExchange subject_` first, `IERC20 token_` second; all five helper reads use `address(subject_)`; the four fixture calls pass `adapter` and the callback-success call passes `locked_`. There is no unresolved owner decision or test-file choice.

## Limits and preserved scope

All three supplied originals were present. The current artifact-helper functions examined above show no command-handling defect for the selected invocation. No new defect was found in the agreed helper/call-site repair or preserved assertion set. This is one command cross-review, not a new audit or a runtime pass.

No shell, delegation, Forge, tests or deployments were used. Only this assigned Markdown report was created; no code, controlling PRD, final plan, existing original, test, configuration or instruction file was edited. Return this single command recommendation to the coordinator.

I did not run Forge.
