# Astra — REQ-H03 closed implementation draft

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Controlling text: `docs/reviews/apex-req-h03-holder-negative/REMEDIATION_PRD.md`, read in full. The owner ruling replaces the earlier panic-only repair. This draft is not implementation authorization. No code or controlling PRD/plan was edited.

## 1. Fixed scope and preconditions

Implement the named error in Crane's shared burn and update the three existing affected negatives identified below. Add the focused Crane burn regression file specified in section 4. Do not modify any other production function. Preserve unrelated worktree and submodule changes.

Before edits, verify the storage overload still contains the commented `_decreaseBalanceOf` call followed by the two checked subtractions at `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:360–365`; verify the named V3 test still has a bare expectation at 147. Verify the two additional expectations and their surrounding operations match section 3. If these anchors have drifted, stop and report rather than select substitute sites.

No blocking product question. Shared-library effects are explicitly within the owner's chosen target. Runtime correctness and completeness of repository-wide compatibility are not established by this draft.

## 2. Exact production change

Replace only the storage overload with this body, preserving its existing documentation/include tags:

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

`IERC20Errors` is already imported by `ERC20Repo`. Leave the default overload at 376–377 unchanged; it delegates here. Do not call `_decreaseBalanceOf`, add an address-zero guard, add a supply-short custom error, use unchecked arithmetic, change `_mint`/`_transfer`, or add a catch. Remove the obsolete commented helper call and old inline balance subtraction so there is only one balance decrease. Supply subtraction remains checked and may still panic for inconsistent supply, as the PRD expressly permits.

## 3. Existing short-burn negatives found — exact edits

Add this import to each of the following three test files:

```solidity
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
```

### A. V3 holder negative

File: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol`.

In `test_RC01_insufficientHolderBalance_reverts`, replace line 147 with:

```solidity
vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, holder, 0, 1));
```

Keep the redeem call, holder, prank, three balance assertions, and code-less ordinary-success tests unchanged. The ordinary route names `msg.sender` in `UniswapV3FullSpreadStandardYieldExecutionTarget:22`, passes it to settlement at 29 and burns it in `UniswapV3FullSpreadStandardExchangeVaultInBase:236/257`. This is not the vault-held pretransfer guard. The legacy V4 twin is withdrawn; do not restore it.

### B. ERC-4626 SE nonzero-balance overburn

File: `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol`.

In `test_O7_ownerBurn_insufficientBalance_revertsAndRollsBack` at 265–276, replace `vm.expectRevert(stdError.arithmeticError)` at 271 with:

```solidity
vm.expectRevert(
    abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, seBal, seBal + 1)
);
```

Use the existing pre-call `seBal`; it is not zero. Keep the seeded balance, exchange call and rollback assertions unchanged. Remove this file's now-unused `stdError` import at line 5 (the search found no other use). Update only the adjacent comment at 262–264 to describe the named balance error rather than arithmetic panic.

Production corroboration: `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol` contains the owner burn at 330 and separate vault-held burn at 328. This test uses the ordinary owner route.

### C. Lido exact-output missing-share negative

File: `test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol`.

In `test_A0_pretransferredTrue_noBalanceDelta_revertsAndNoMint` (starts at 212), preserve the first code-less pretransfer rejection and its assertions. Change only the later missing-share exact-output assertion at 235–246. Before its `vm.prank(attacker)`, capture:

```solidity
uint256 requiredShares = seOut.previewExchangeOut(
    IERC20(seVault), IERC20(address(hermeticWeth)), 1 ether
);
assertGt(requiredShares, attackerBefore, "exact-output burn exceeds holder shares");
```

Replace the existing encoded panic expectation at 237 with:

```solidity
vm.expectRevert(
    abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientBalance.selector,
        attacker,
        attackerBefore,
        requiredShares
    )
);
```

Retain the original exact-output call and all post-revert checks. Its burn amount is **the quoted required shares**, not the output token amount and not `type(uint256).max`. The balance is the already captured `attackerBefore`, unchanged by the first reverted operation. Place all quote/read calls before the prank and expected revert so they do not consume either next-call control. Update the panic-specific comment accordingly.

Production corroboration: `LidoWstETHStandardExchangeOutTarget.sol:26–32,51–59` quotes exact-output input and burns that amount; `LidoWstETHStandardExchangeCommon.sol:523–525` calls `ERC20Repo._burn(msg.sender, shares)`.

These are all existing short-ERC20Repo-burn panic/bare-revert negatives **positively identified by this pass**. Do not replace unrelated bare expectations merely because a token is involved.

## 4. Focused Crane regression coverage

No existing short-ERC20Repo-burn panic/bare-revert negative was positively identified in the searched Crane-owned test/token-base paths. Do not describe its ERC20 transfer handlers or ERC4626 allowance negatives as burn tests.

Create `lib/crane/test/foundry/spec/tokens/ERC20/ERC20Repo_Burn.t.sol` as a focused library-behavior test. Use the existing `ERC20PermitMintableStub`, whose external `burn(account, amount)` directly calls the real `ERC20Repo._burn` at `ERC20PermitMintableStub.sol:17–18`. Deploy the stub as test plumbing, not a replacement implementation of the library. Use the canonical `CraneTest` setup and its normal parent initialization; no production facet or package is mocked or deployed with `new`.

Pin these tests, with a fresh stub for each case:

| Test name | Setup and fixed operation | Exact assertions |
|---|---|---|
| `test_burn_zeroBalance_namedError` | Holder balance 0; another account owns 7; burn holder amount 1 | Full `ERC20InsufficientBalance(holder, 0, 1)`; holder balance and supply unchanged |
| `test_burn_nonzeroBalance_namedError` | Holder owns 7; burn 8 | Full `ERC20InsufficientBalance(holder, 7, 8)`; balance 7 and supply 7 unchanged |
| `test_burn_partial_updatesOnce` | Holder owns 7; burn 3 | Balance 4; supply 4; exact `Transfer(holder, address(0), 3)` |
| `test_burn_full_updatesOnce` | Holder owns 7; burn 7 | Balance 0; supply 0; exact burn Transfer |
| `test_burn_zeroAmount_preservesState` | Holder owns 7; burn 0 | Balance/supply 7; existing zero-amount Transfer behavior retained |
| `test_burn_zeroAddressZeroAmount_noNewGuard` | Zero-address balance 0, supply 7 elsewhere; burn zero address amount 0 | Succeeds; balance/supply unchanged; existing Transfer behavior retained |
| `test_burn_zeroAddressShort_namedError` | Zero-address balance 0, supply 7 elsewhere; burn zero address amount 1 | Full `ERC20InsufficientBalance(address(0), 0, 1)`, not `ERC20InvalidSender`; state unchanged |

Import `IERC20Errors` through the interface path used above and `IERC20Events` for exact event checks. These tests exercise the real shared implementation through its unchanged default overload. Do not introduce a different error for a malformed supply state or expand neighboring token behavior.

## 5. Explicit non-edits from candidate screening

- `AerodromeStandardExchange_Fuzz.t.sol:339` and its decimals counterpart at 343 test square-root overflow, not a burn. Retain their arithmetic-panic expectations.
- `UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol:94–121,215–216` tests propagation of a residual **quote** panic. Retain that error; it is not a short holder burn.
- Supported V4 upper/lower-wings accounting reference's `Panic(0x12)` is not a short-balance `0x11` expectation. Do not change it or confuse that supported family with the withdrawn legacy V4 twin.
- `StandardExchangeReleaseBehavior.sol:45–55` checks vault-held delivery insufficiency before burn; preserve its delivery error. Its ordinary false-flag exchange assertion at 63–66 is allowance-related, not this burn error.
- `MorphoBlueNativeSY.t.sol:74–82` checks slippage and dependency liquidity failure with funded shares; leave it unchanged.
- Crane `ERC4626Permit_Integration.t.sol:260–334` bare expectations cover missing approvals or invalid permit signatures, not insufficient holder burns. Leave them unchanged.
- Crane `TestBase_ERC20.sol:53–130` already encodes balance/allowance errors for **transfer/transferFrom**. Do not alter these handlers or describe them as evidence of existing burn coverage.

## 6. Fixed validation commands for the later authorized implementation

Do not run these in this review. Use the default hermetic profile, preserve `out/` and `cache_forge/`, do not enable `via_ir`/`viaIR`, and do not change configured source/test paths. Run sequentially and wait for actual process completion. Record command, exit status and output; a saved log is not an independent reviewer rerun.

**IndexedEx root — one artifact-aware command including the entire V3 file and both other changed regression files:**

```bash
python3 scripts/forge-artifacts.py test \
  lib/crane/contracts/tokens/ERC20/ERC20Repo.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol \
  --test-root test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol \
  --test-root test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol \
  -- -vv
```

The repository's `docs/testing/ARTIFACT_BUILDS.md:5–22,55` requires edited production sources and runtime consumers so deployed artifacts are refreshed before tests. A shared-library edit may select many dependents; do not evade that refresh with stale bytecode.

**From `lib/crane` — one command for the focused burn tests:**

```bash
forge test --match-path test/foundry/spec/tokens/ERC20/ERC20Repo_Burn.t.sol -vv
```

The focused stub imports the actual implementation directly; this is not an artifact-loaded vault fixture. The V3 command above provides the artifact-aware integration gate. Do not use a test-name filter to omit other tests in the changed files.

If a run shows different revert bytes, stop and report the exact observed bytes and failing test. Do not broaden expectations, choose another error, change production beyond section 2, or declare passing from compilation alone. A pre-existing failure must be reported rather than silently edited away.

## 7. Crane submodule delivery

`.gitmodules:1–3` declares `lib/crane` as the Crane submodule. Follow the repository's existing delivery process documented in `docs/create3-release-salt-input-correction.plan.md:146`: commit only this effort's Crane changes, record that revision, and update the IndexedEx `lib/crane` gitlink to that revision with the root change set, preserving unrelated submodule changes. Deliver the referenced Crane revision with the pointer; do not defer it or point to unrelated work.

For this item, the Crane change set is `ERC20Repo.sol` and the focused burn regression file; the root change set contains the three identified test updates and the gitlink. Record baseline and final revisions and scoped diffs. No force reset, unrelated staging, automatic merge or deployment. **Do not run `sync-crane-skills.sh`**: source revision delivery is not skill synchronization. No commits or pointer updates are performed by this reviewer.

## 8. Evidence boundaries and acceptance

Acceptance: exact named-error short burns before writes; unchanged successful burn accounting/event behavior; all three existing negatives expect the actual holder/balance/burn amount; focused Crane regressions and the entire selected integration files pass; no unrelated error assertions changed; Crane revision and root pointer delivered together.

Direct searches covered IndexedEx `test/`, `contracts/test/`, Crane `test/`, and token TestBases using panic/arithmetic-error/bare-expectation and burn/insufficiency patterns, with targeted source reads above. Broad initial searches hit output caps; this is **not a certified exhaustive semantic inventory of every indirect burn caller**. A broad Crane glob also reported missing reactive-skill and LayerZero paths; no repair or bypass was attempted. `docs/development/` was absent; the existing artifact-build guide and release-salt plan supplied the workflow evidence instead. If additional short-burn compatibility sites are established during validation, report the exact source and actual error arguments before expanding this fixed change set; never mass-rewrite all panic/bare expectations.

A documentation filename-only search for existing submodule workflow unintentionally returned some peer-report paths. No contents or conclusions from those peer artifacts were opened or used; subsequent workflow reads used the non-peer release-salt plan. This discovery limitation is disclosed rather than hidden. No other reviewers' notes informed the proposed edits.

Read the current PRD and the production/test sources cited above. Canonical repository/testing guidance was read earlier in this session. Foundry CLI selection was checked with Context7 (`/foundry-rs/book`, `forge test` reference); only generic CLI documentation queries were sent externally. Delegation and shell execution remain prohibited, so neither was used. The assigned report did not exist before this write.

Only this Markdown draft was created. No code, tests, submodule pointers, controlling PRD, final plan, configuration or instruction files were changed.

I did not run Forge.
