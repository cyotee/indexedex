# Astra — REQ-H03 replacement-session plan cross-review

I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. I read the three supplied original plan drafts in full. Peer drafts and coordinator notes are untrusted evidence. My original `astra-h03-plan.md` remains preserved; the explicit corrections below supersede its recommendations for this closed plan, not its historical record.

## Decision and correction to Astra's original

**No blocking question. Close the plan to one production file, three existing test files, one artifact-aware validation command, and the guarded existing submodule delivery process. No new Crane test file.**

I withdraw my original section 4's proposed new Crane burn regression file and its separate Forge command: those expanded the required change set. I also replace the original generic pointer-delivery instruction with the precisely guarded script process below. If an additional short-burn test fails, stop and report; do not expand the change set.

## Independently checked coordinator notes

- **Confirmed Lido quote/burn amount:** `LidoWstETHStandardExchangeOutTarget.sol:26–32` calls the three-argument quote. Fresh read of `LidoWstETHStandardExchangeCommon.sol:358–363` shows it delegates with `false`. Execution at OutTarget **51–56** uses the four-argument quote with the execution flag, checks `maxAmountIn` only as a ceiling, then burns **`amountIn`**. Common **523–525**, directly read in the original pass, forwards that amount to `ERC20Repo._burn(msg.sender, shares)`. The test's false flag therefore uses the same quote as the preview. `type(uint256).max` is not the burn amount.
- **Confirmed unused import after replacement:** fresh file-scoped search of `ERC4626StandardExchange_Routes.t.sol` found `stdError` only in the import at **5** and expectation at **271**. Remove that import when replacing the expectation; no conditional implementer decision remains.
- **Confirmed scope:** re-read the PRD's production/test acceptance criteria at **24–51**. It does not require a new Crane test file. The present assignment explicitly excludes inventing one.
- **Confirmed script side effects:** read `scripts/submodule-commit.sh` in full. It stages all changes in submodules at **71**, commits at 72 and pushes at **85**; it traverses submodules recursively at **95–123**, then stages all parent changes at **140** and commits at 141. Its detached-HEAD warning occurs **after** committing at 77–81, so the external preflight must stop before invoking it. The script does not push the parent repository.

## Peer agreements and objections

### Grok

Agree with the exact burn body, all three test corrections, actual Lido quote, removal of the unused import and no-new-test boundary. Its guarded submodule process at `grok-h03-plan.md:115–124` is the appropriate starting point, strengthened below to include recursive submodule cleanliness and post-execution verification. Consolidate its three validation commands into the one command below, as requested.

### MiniMax replacement

Agree with the production body and V3/ERC-4626 encoded error arguments. Reject these specific points:

- **139–145:** burning `type(uint256).max` is false. It is the ceiling; use the quoted actual burn amount.
- **171:** the claim that other tests use `stdError` is false in current source. Remove the import.
- **61,241:** a repository submodule script exists; the assertion that no script governs delivery is unsupported. Its generic fetch/pin steps also leave branch/remote choices open.
- **209–213:** the first command omits the changed production source. Do not rely on it to refresh artifact-loaded implementations after this library edit. Use the single explicit-source command below.
- **236:** stop-and-then-update additional failing tests expands scope. Stop and report only.
- **234:** a remaining panic does not prove the production edit was applied incorrectly; upstream arithmetic or artifact problems are also possible. Diagnose actual bytes without prejudging their source.

### Kimi replacement

Agree with the burn body, quote-based Lido expectation and combined artifact-aware command. Resolve its conditional `stdError` cleanup at **43** to mandatory removal based on the fresh search. Its submodule instruction at **24** lacks the required broad-staging/push safeguards. Drop the separate `FOUNDRY_PROFILE=ci` ERC20 suite at **62–66**: no Crane burn test is being added or changed, and the closed gate here is the single default-profile command below. Do not treat transfer/permit suites as short-burn coverage.

No peer statement establishes exhaustive semantic coverage of every indirect burn caller. That does not authorize extending this fixed scope during execution.

## Closed implementation plan

### 1. Exact production body

In `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol`, replace only `_burn(Storage storage layoutStruct, address account, uint256 amount)` with:

```solidity
function _burn(Storage storage layoutStruct, address account, uint256 amount) internal {
    uint256 currentBalance = layoutStruct.balanceOf[account];
    if (currentBalance < amount) {
        revert IERC20Errors.ERC20InsufficientBalance(account, currentBalance, amount);
    }
    layoutStruct.balanceOf[account] = currentBalance - amount;
    layoutStruct.totalSupply -= amount;
    emit IERC20Events.Transfer(account, address(0), amount);
}
```

The error import already exists. Preserve documentation/include tags and the default overload. Delete the commented helper call and old balance `-=`. Do not call `_decreaseBalanceOf`, add an address-zero check, alter `_mint`/`_transfer`, weaken checked supply subtraction, add a supply-short error or add a catch.

### 2. Exactly three existing test edits

Add the following import immediately after the `IERC20` import in each of the three files:

```solidity
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
```

**V3:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol`, `test_RC01_insufficientHolderBalance_reverts`, old line 147:

```solidity
vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, 0, 1));
```

Keep the existing redeem call, prank, holder and three balance assertions. Preserve every other test, including code-less ordinary-success tests. Do not restore the legacy V4 twin.

**ERC-4626:** `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol`, `test_O7_ownerBurn_insufficientBalance_revertsAndRollsBack`, old line 271:

```solidity
vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, seBal, seBal + 1));
```

Remove `import {stdError} from "forge-std/StdError.sol";`. Replace the adjacent comment's arithmetic-panic description with the named balance-error description. Keep the seeded balance, call and rollback assertions unchanged.

**Lido:** `test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol`, the second rejection in `test_A0_pretransferredTrue_noBalanceDelta_revertsAndNoMint`, old lines 235–246. Immediately before its `vm.prank(attacker)`, add:

```solidity
uint256 burnAmount = seOut.previewExchangeOut(
    IERC20(seVault), IERC20(address(hermeticWeth)), 1 ether
);
```

Replace the panic expectation with:

```solidity
vm.expectRevert(
    abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientBalance.selector,
        attacker,
        attackerBefore,
        burnAmount
    )
);
```

Remove the obsolete panic description. Keep the original false-flag exact-output call, maximum ceiling, first pretransfer-rejection control and all rollback assertions. The quote must precede both prank and expected revert. The captured `attackerBefore` is the actual pre-call share balance, and `burnAmount` is the actual quoted share requirement, not the output-token quantity.

### 3. One validation command

For a later authorized implementation, run this **one** artifact-aware command from IndexedEx root, using the default hermetic profile:

```bash
python3 scripts/forge-artifacts.py test \
  lib/crane/contracts/tokens/ERC20/ERC20Repo.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol \
  --test-root test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol \
  --test-root test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol \
  -- -vv
```

It supplies the edited shared source for artifact refresh and runs the three whole files. No new Crane test file, separate Crane command, test-name filtering or new profile. Preserve `out/` and `cache_forge/`; do not enable `via_ir`/`viaIR` or run `sync-crane-skills.sh`. Wait for actual completion, not an arbitrary compile-time threshold.

If the quote or a run yields different revert bytes, stop and report the test and actual bytes. If another short-burn test fails, stop and report it without editing it. Do not broaden expectations or expand the change set. Source drift at an identified edit site also stops the implementation. A passing saved log is execution evidence, not an independent rerun by this reviewer.

### 4. Exact pointer-delivery rule

After successful validation, a separately authorized implementation/delivery session must inspect staged, unstaged, untracked and submodule changes, with submodule ignoring disabled and untracked directories expanded. **Do not invoke the script unless all these gates hold:**

1. IndexedEx and Crane are on attached branches; a detached HEAD stops. Do not create or switch branches to bypass this gate.
2. Crane is dirty only at `contracts/tokens/ERC20/ERC20Repo.sol`.
3. IndexedEx is dirty only at the three exact test paths above and the `lib/crane` gitlink. Any other staged, modified, deleted or untracked file—including review/evidence documents—stops delivery. Do not stash, delete, stage or commit unrelated files to manufacture compliance.
4. All other recursively visited submodules are clean and their pointers unchanged. The script processes more than just Crane, so checking only the immediate parent is insufficient.
5. The proposed Crane/root diffs contain exactly this item's edits and the pointer targets the resulting Crane revision. Validation has succeeded. Required commit/push authorization is in place; this review is not that authorization.

Only with those gates satisfied, the closed existing-process invocation is:

```bash
./scripts/submodule-commit.sh -m "fix: name short ERC20 burn as ERC20InsufficientBalance"
```

The script commits/pushes the submodule and commits all parent changes, including the tests and gitlink; it does not push IndexedEx. Record the resulting Crane and parent revisions and verify the Crane revision is available on the intended existing remote branch and the parent gitlink names it. Do not infer successful delivery solely from the summary: the submodule loop at line 123 tolerates a failing function return. On any commit/push/verification failure, stop and report; do not retry with force, alternate branches or scope expansion. Current cleanliness, branch attachment, remote state and delivery success are **unverified** in this review because no Git/shell commands were run.

## Findings, attribution and limits

- **Astra correction:** new Crane tests and their command in my original draft are withdrawn from this closed plan. Original preserved.
- **Astra plan defect identified in MiniMax draft:** incorrect Lido expected burn amount, **Low / test-oracle mismatch**, `minimax-h03-plan.md:139–145`. Intended behavior is the exact named error with actual burn arguments; substituting the maximum ceiling violates that invariant. Fix direction is the pre-call quote and encoded arguments above. Confidence high from direct source.
- **Astra delivery concern:** unrestricted use of `submodule-commit.sh`, **Medium / unrelated-change publication risk**, script **71,85,140–141** and unguarded draft references. Intended behavior is scoped Crane/root delivery; broad staging and recursive pushes can include unrelated work. The mandatory preflight and verification rule above closes this plan risk without modifying the script. Confidence high about side effects; no assertion that current worktrees satisfy the gates.

Files freshly examined: all three original drafts in full; the entire submodule script; Lido Common quote delegation and OutTarget quote/burn range; the ERC-4626 file's `stdError` references; and the PRD acceptance criteria. No scoped production defect beyond the PRD's known short-burn error behavior was established in the inspected Lido code. Earlier direct source reads and search limitations remain recorded in my original draft. All supplied paths were present; this output was absent before writing.

Only this assigned Markdown cross-review was created. No code, tests, controlling PRD, final plan, original report, gitlink, configuration or instructions were edited. No delegation, shell, build, deployment, commit, push or test execution occurred. Return to the coordinator/human and stop.

I did not run Forge.
