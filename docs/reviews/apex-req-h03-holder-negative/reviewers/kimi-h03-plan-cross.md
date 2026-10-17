# Kimi K3 — cross-review: REQ-H03 plan drafts

- **Label:** Replacement-session cross-review, resuming my plan draft (`kimi-h03-plan.md`). I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. MiniMax is the labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. The three peer drafts were read in full as untrusted output; the coordinator's four notes were treated as untrusted and each was verified against current source before acceptance. Nothing was edited.
- **Date:** 2026-10-16. I did not run Forge.

## Coordinator notes — verified

1. **Lido quoted-burn amount — confirmed for the preview-capture form, refuting MiniMax.** `LidoWstETHStandardExchangeOutTarget.sol:54-56` (read this round): `amountIn = _quoteExactOut(in_, out_, amountOut, pretransferred); … _burnShares(amountIn);` — the false-flag burn is the **quoted** amount, not the caller's `type(uint256).max`. MiniMax's expectation `(attacker, 0, type(uint256).max)` (`:139-144`) would fail against this code and is rejected. The closed form is Astra's (`:73-91`, strongest): before the prank, capture `uint256 requiredShares = seOut.previewExchangeOut(IERC20(seVault), IERC20(address(hermeticWeth)), 1 ether);` plus her `assertGt(requiredShares, attackerBefore, …)` precondition, then expect `ERC20InsufficientBalance(attacker, attackerBefore, requiredShares)`. Grok's equivalent (`burnAmount`, `:91-97`) and mine (`used_`) are the same shape; Astra's precondition assert earns it the nod. `previewExchangeOut` is the same quote the false-flag execution reads (`OutTarget:32` vs `:54`); a mismatch stops the run per the stop rule.
2. **Unused `stdError` import — confirmed removable.** `ERC4626StandardExchange_Routes.t.sol` contains `stdError` exactly twice: the import at `:5` and the `:271` expectation being replaced. After the edit it is dead; Astra (`:63`) and my draft say remove it, MiniMax (`:171`) says it stays "used by other tests" — refuted by the grep. Remove the import.
3. **No new Crane test file — confirmed.** The PRD's acceptance is the `_burn` body plus the V3 expectation; the two swept IndexedEx negatives (Lido, ERC4626) cover the regression. Astra's §4 (`ERC20Repo_Burn.t.sol`, seven pinned cases) is well-specified but additive scope the PRD never asks for — excluded from the closed plan; the owner may authorize it separately. Grok's "Do not add one" (`:104`) stands. The existing Crane ERC20 suite remains a **run-only** regression guard (no new file): `FOUNDRY_PROFILE=ci forge test --match-path 'test/foundry/spec/tokens/ERC20/*' -vv` from the Crane root.
4. **`scripts/submodule-commit.sh` hazards — confirmed, gates required.** Read in full this round: it runs `git add -A` inside every dirty submodule (`:71`) and again in the parent (`:140`), and **pushes each submodule to its remote** (`:85`). In this repo's documented dirty worktree, running it ungated would commit and push unrelated content. Grok's gates (`:119-121`) are therefore mandatory: stop if Crane is detached-HEAD; stop if Crane's status shows anything but `contracts/tokens/ERC20/ERC20Repo.sol`; stop if IndexedEx's status shows anything but the three test files and the `lib/crane` gitlink. MiniMax's claim that "no IndexedEx script governs this" (`:61`) is wrong — the script exists and was the REQ-SEP-04 C8 delivery mechanism; his raw-git alternative bypasses the existing process. Astra's manually-scoped commit path (release-salt plan reference) is equivalent in safety; the plan should name one: **Grok's gated script invocation**.

## The closed plan (convergence)

- **Production body:** identical verbatim in all four drafts (the PRD's `:31-36` shape) — no dispute.
- **T1 V3 test:** identical in all four — import + `ERC20InsufficientBalance.selector, holder, 0, 1`.
- **T2 Lido:** Astra's form above (preview capture + precondition + named error). MiniMax's `max` form rejected (note 1).
- **T3 ERC4626:** named error `(user, seBal, seBal + 1)`, comment rewrite, **and** the `stdError` import removal (note 2).
- **Sweep boundary:** unanimous — the Aerodrome sqrt harnesses, the residual-preview quote-panic harness, the Wings 0x12 reference, and the fail-closed/deploy/allowance bare reverts are different errors and stay. MiniMax's screening notes (`:189-197`) and Astra's §5 agree with my sweep.
- **Commands:** one IndexedEx command — positional `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol` (edited source; it triggers the artifact refresh MiniMax's `:209-213` omits from his 5.1) with the three `--test-root` files (V3, Lido, ERC4626), `-- -vv`; plus the Crane suite guard above. Stop on unexpected bytes; never broaden an expectation.

## Unresolved dissent

None surviving. MiniMax's two errors (Lido `max` amount; stdError retention) and one process claim (no governing script) are refuted with source above; Astra's Crane test file is parked as optional scope, not adopted. Consensus is not proof: the named-error behavior is verified against source, and the runtime confirmation belongs to the later authorized run.

I did not run Forge.
