# MiniMax M3 — REQ-SEP-01 plan cross-review (replacement session)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** One cross-review on the `forge-artifacts.py` command across the four plan drafts. No code edit. No PRD edit. No Forge.
- **Method:** Read all three peer plan originals (`astra-sep01-plan.md`, `grok-sep01-plan.md`, `kimi-sep01-plan.md`) and re-read the canonical sources that govern the command: `CLAUDE.md` (item 10), `docs/testing/ARTIFACT_BUILDS.md`, and the script itself (`scripts/forge-artifacts.py`).
- **No production source is edited.** This is a hard constraint; it constrains the command but does not by itself settle the disagreement on positional source arguments.

---

## 1. The four proposed commands

| Reviewer | Positional | `--consumer` | `--test-root` | `-- -vv` |
|---|---|---|---|---|
| Astra | `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol` | — | `Adversarial_BalancerV3SinglePoolSE.t.sol` | yes |
| Grok | (none) | — | `Adversarial_BalancerV3SinglePoolSE.t.sol` | yes |
| Kimi | (none) | `Adversarial_BalancerV3SinglePoolSE.t.sol` | `Adversarial_BalancerV3SinglePoolSE.t.sol` | yes |
| MiniMax (mine, first pass) | `Adversarial_BalancerV3SinglePoolSE.t.sol` (the test file as positional) | — | `Adversarial_BalancerV3SinglePoolSE.t.sol` | no |

All four are syntactically valid against `scripts/forge-artifacts.py` (`parser` definitions at `:388–396`, validator at `:401–406`). They differ in (a) what is declared as a build root, (b) whether `--consumer` is named, and (c) verbosity.

---

## 2. Headline — agreement

All four reviewers converge on the following. I agree with each:

- Use `forge-artifacts.py test`, not `plan` or `build`. `test` is required because the executor must actually run the test, not just print the plan or refresh artifacts in isolation. `CLAUDE.md` item 10 and `ARTIFACT_BUILDS.md` (lines 10–12) prescribe `test` for this case.
- `--test-root` is mandatory. The script's parser hard-fails at `:401–402` if it is omitted for `test`. Every reviewer has it.
- The `--test-root` value is the same single test file: `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol`.
- The hermetic profile is default; `FOUNDRY_PROFILE=fork` is not set; `via_ir` is not enabled; `out/` and `cache_forge/` are not deleted. This matches CLAUDE.md item 8 (compile patience) and item 9 (cache seed). No reviewer breaks this.
- No `try/catch` is added. No production file is edited. No production allowance leak is claimed. PRD non-goals respected.

I dissent from no reviewer on any of the above.

---

## 3. The one disagreement — what to declare as a build root

The four proposals split on what to pass to the script so that the **production artifact** (`BalancerV3SinglePoolStandardExchange`'s creation bytecode in `out/`) is refreshed before the test runs.

The test deploys the production adapter via CREATE3 using `ArtifactCreationCode.creationCode(create3Factory, "contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:BalancerV3SinglePoolStandardExchange")` (test file `:83`, `:312`, `:484`, `:611`). That helper reads bytecode from `out/`. CLAUDE.md item 10 mandates a `forge build` step before `forge test` so that FactoryService-created artifacts are not stale. The canonical doc `docs/testing/ARTIFACT_BUILDS.md` (lines 5–14, 30–43) gives the pattern: pass the production source whose artifact must be refreshed as a positional argument, alongside `--test-root`.

### 3.1 Why Astra's choice is the one the plan must use

Astra's command names `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol` as the positional source. This is the canonical `ARTIFACT_BUILDS.md` shape:

```
python3 scripts/forge-artifacts.py test contracts/path/EditedTarget.sol \
  --test-root test/foundry/spec/path/RelevantTest.t.sol -- -vv
```

(verbatim from `ARTIFACT_BUILDS.md` lines 10–12). Three reasons to adopt it:

1. **Doc-canonical.** `ARTIFACT_BUILDS.md` lines 5–14 show exactly this shape: positional edited-source plus `--test-root`. The doc's framing is "for a warm checkout, pass every edited production source and an exact test file." Even when the production source is *not* the edit target, naming it makes the artifact-refresh contract explicit and the command auditable.

2. **Matches `ARTIFACT_BUILDS.md` rationale.** Lines 244–248 of the script: `roots.add(artifact_source)` happens when an `ARTIFACT = ...\.sol:ContractName` literal is discovered, and the resolved production source is loaded into the build closure. With the production source declared explicitly as positional, the build root is unambiguous and the `forge build` invocation at `:265` (`["forge", "build", *sorted(roots)]`) explicitly recompiles it. Without the explicit positional, the script's auto-discovery through `ARTIFACT` regex (`scripts/forge-artifacts.py:22`) would still find the same production source via the test's `ArtifactCreationCode.creationCode(...)` literal — but only if no one has disabled the consumer-artifacts pass.

3. **`-- -vv` is canonical.** Three of four proposals include it; only mine omits it. `ARTIFACT_BUILDS.md` lines 10–12 show `-- -vv` in the canonical command. `-vv` produces per-test traces the implementer needs when the corrected `:520` assertion reports a mismatch; without it, a failure surfaces only as a count. Adopt `-- -vv`.

### 3.2 Why Grok's command is rejected (despite being functionally valid)

Grok's command (`--test-root` only, no positional) works because:

- `test_plan` (`:340`) auto-adds the test file to `runtime_consumers` via `:354` (`runtime_consumers.update(test_consumers)`).
- `graph.plan(changed, runtime_consumers, ...)` (`:357`) unions `changed` (empty) with `consumers` (the test files), populating `roots` from them.
- The closure traversal at `:230–253` finds the `ArtifactCreationCode.creationCode(...)` literal in the test source, resolves the artifact ID, and adds the production source to `roots`.
- The final `forge build` recompiles whatever the closure discovered.

It is functionally equivalent to Astra's command in a warm tree where the test file is unchanged structurally. But it is **less explicit** about the production artifact refresh, and it diverges from the canonical `ARTIFACT_BUILDS.md` shape. The script's own docstring and help text ("Edited Solidity source paths, including targets/interfaces/libraries" — `:387`) frame positional sources as the primary input. Grok's command is acceptable but not preferred.

### 3.3 Why Kimi's command is rejected

Kimi uses `--consumer` with the same path as `--test-root`. Functionally:

- `--consumer` (`scripts/forge-artifacts.py:392`) is consumed at `:412` (`consumers = expand_consumers(graph.root, args.consumer)`), passed into `test_plan` at `:414`, then unioned with `test_consumers` at `:354` into `runtime_consumers`.
- Since `--test-root` already auto-populates `test_consumers` with the same test file (`:354`), `--consumer` is **redundant**.
- Worse, `ARTIFACT_BUILDS.md` lines 30–43 explicitly frames `--consumer` as the runtime-artifact-prep mechanism for `forge script` (e.g., `python3 scripts/forge-artifacts.py build --consumer 'scripts/foundry/path/Deploy.s.sol'`). The doc says nothing about `--consumer` for `forge test`; it instead uses positional sources for that case.

Adopting Kimi's shape would be a precedent that confuses the script's intended contract. Reject.

### 3.4 Why my first-pass command is rejected (and self-corrected)

My first pass passed the test file as the positional source and omitted `-- -vv`. Two flaws:

1. **Redundant positional.** The test file is already declared via `--test-root`, which auto-adds it to `runtime_consumers`. Passing it again as positional adds nothing.
2. **Missing `-- -vv`.** Three peers had it; I did not. The canonical command includes it.

I self-correct to Astra's command.

---

## 4. The one command the plan must use

```bash
python3 scripts/forge-artifacts.py test \
  contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol \
  --test-root test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol \
  -- -vv
```

Constraints on the executor (recorded for the plan):

- Run from the repository root.
- Production source is named as an **artifact-refresh input only**, not an edit target. No file under `contracts/` is modified by this command.
- The active profile is the default hermetic profile. Do not set `FOUNDRY_PROFILE=fork`, do not enable `via_ir`, do not delete `out/` or `cache_forge/`, do not run concurrent writers to those directories.
- Follow CLAUDE.md item 9 (worktree compile seed) before the first `forge build` in a new/empty worktree: copy warm `cache_forge/` and `out/` from a warm checkout; symlink `lib/crane/` rather than reinstalling.
- Follow CLAUDE.md item 8 (Forge patience): allow the command to run for hours if needed; do not kill on silence.
- `-vv` produces per-test traces. The implementer needs them when the corrected `:520` assertion reports a mismatch; do not downgrade.
- If the command fails, stop and report. Do not edit production to make it pass. Do not weaken an exact-zero check. Do not add a `catch`.

---

## 5. Cross-PRD evidence re-checked this period

- `docs/reviews/apex-req-sep-01-callback-adapter/REMEDIATION_PRD.md` — re-read for the controlling non-goals: no `catch`, no production edit, no `== 0` weakening. None of the four proposed commands violates any of these (the production source is named as a build-root input, not edited).
- `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` REQ-SEP-01 section (lines 110–120) — re-read for the same. None of the four violates it.
- `docs/testing/ARTIFACT_BUILDS.md` lines 5–14, 30–43 — re-read. The canonical command shape (positional edited-source + `--test-root` + `-- -vv`) is reproduced verbatim at lines 10–12.
- `CLAUDE.md` items 8, 9, 10 — re-read for cache seed and patience constraints.
- `scripts/forge-artifacts.py` lines 388–406 — re-read for parser surface and validators.
- `scripts/forge-artifacts.py` lines 230–265 — re-read to confirm that artifact literals in test sources are resolved and that `forge build` is invoked on the resulting roots.

No source files were re-edited. No re-execution of any test was performed.

---

## 6. Dissent and unresolved items

None. The one command above is the consensus resolution. The disagreement on positional source is closed by `ARTIFACT_BUILDS.md` (canonical doc) and the script's own `ARTIFACT` regex + closure traversal logic. The disagreement on `--consumer` is closed by reading `ARTIFACT_BUILDS.md` lines 30–43, which frames `--consumer` for `forge script` runtime preparation, not for `forge test` selection. The disagreement on `-- -vv` is closed by reading `ARTIFACT_BUILDS.md` lines 10–12 (canonical command includes it).

---

## 7. Files examined (this cross-review)

- `docs/reviews/apex-req-sep-01-callback-adapter/reviewers/astra-sep01-plan.md` — read in full.
- `docs/reviews/apex-req-sep-01-callback-adapter/reviewers/grok-sep01-plan.md` — read in full.
- `docs/reviews/apex-req-sep-01-callback-adapter/reviewers/kimi-sep01-plan.md` — read in full.
- `docs/reviews/apex-req-sep-01-callback-adapter/reviewers/minimax-sep01-plan.md` — re-read for self-consistency. Not treated as a peer.
- `docs/reviews/apex-req-sep-01-callback-adapter/REMEDIATION_PRD.md` — re-read.
- `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` REQ-SEP-01 — re-read.
- `docs/testing/ARTIFACT_BUILDS.md` — re-read.
- `CLAUDE.md` items 8, 9, 10 — re-read.
- `scripts/forge-artifacts.py` lines 388–406 (parser surface) and lines 230–265 (artifact resolution and forge invocation) — re-read.

No Forge / build / test was executed.

---

I did not run Forge.