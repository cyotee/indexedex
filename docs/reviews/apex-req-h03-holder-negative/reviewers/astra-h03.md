# Astra — REQ-H03 replacement-session original

I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This is an independent first pass. No other reviewers' notes were read. The owner's `RES-H03` refers to **REQ-H03**, controlled by `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:138–148`. The legacy V4 twin is withdrawn and must not be restored or edited.

## Decision

**No blocking question.** The exact existing production failure for insufficient ordinary holder balance at the burn is **`Panic(uint256)` with code `0x11` (arithmetic underflow/overflow)**. It is **not** `ERC20InsufficientBalance(address,uint256,uint256)` on this burn path.

Make this exact test-only change in `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol`, inside `test_RC01_insufficientHolderBalance_reverts`:

Replace line 147:

```solidity
vm.expectRevert();
```

with:

```solidity
vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));
```

No new import is required. This fixes the full expected error data, including the panic code, rather than accepting any revert or any panic. Leave the existing ordinary redemption call and its `false` internal-balance flag unchanged. Preserve the holder/vault share-balance and recipient token-balance assertions at 149–151, and the code-less ordinary-success test at 105–122. Do not substitute a contract caller, change the production burn, add a catch, or expand this repair to V4.

## Production trace — directly inspected facts

1. `NativeStandardYieldTarget.sol:30–42` under `contracts/vaults/standard/sy/` routes `redeem(..., false)` through `_standardRoute`. The separate `_requireVaultHeldShares` check at 60–63 applies to the internal-balance route and is not this test's holder check.
2. `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardYieldExecutionTarget.sol:18–29` selects `msg.sender` as the ordinary redemption holder and passes it to `_executeZapOutExactIn` through `_settleNamedHolder`.
3. `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:212–260` carries that holder through both settlement branches. The ordinary unlocked branch reaches `ERC20Repo._burn(holder_, sharesBurned)` at **257**; the sleeve branch has the same burn at **236**.
4. `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:376–377` delegates `_burn(address,uint256)` to its storage overload.
5. That overload at **360–364** does **not** call `_decreaseBalanceOf`: the call is commented out at 361. It directly performs the checked subtraction `layoutStruct.balanceOf[account] -= amount` at **362**, followed by the supply subtraction.
6. The separate `_decreaseBalanceOf` helper at **222–231** does emit `IERC20Errors.ERC20InsufficientBalance(account, currentBalance, amount)`, but it is not called by `_burn`. Naming that custom error merely because it exists nearby would make this test expect the wrong production failure.

Solidity's checked unsigned subtraction therefore produces `Panic(uint256)` with argument `0x11` when the holder balance is insufficient. The test uses a fresh holder with no transferred shares and requests a nonzero burn. The holder-balance subtraction precedes the supply subtraction in `_burn`.

Also inspected `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:793–832`: the liquidity-burn helper skips zero-sized liquidity and the swap helper skips zero output-side conversion amounts. These are upstream settlement steps, not alternative permitted failure oracles.

**Inference:** pinning the full panic data rejects unrelated custom route, pool and quote errors that currently satisfy the bare expectation. **Limit:** a `Panic(0x11)` does not uniquely identify a source location; another arithmetic failure with that code could still match. This narrow test repair binds to the actual current holder-burn behavior, not a newly invented holder-specific custom error. It is not a claim of runtime trace verification or a demonstrated production holder-selection defect.

## Astra finding — H03-1: insufficient-holder test accepts unrelated failures

- **Severity:** Low.
- **File and line:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol:147`.
- **Intended behavior:** The controlling REQ-H03 requires the V3 insufficient-holder negative to expect the production holder-balance failure, with holder, vault and recipient balances unchanged and the code-less ordinary-success test preserved.
- **Broken invariant:** Bare `vm.expectRevert()` accepts any revert; the unchanged-balance assertions do not establish the rejection's cause.
- **Impact class:** Test-oracle specificity / regression-detection gap, not demonstrated asset loss.
- **Fix direction:** Replace only the bare expectation with the exact encoded `Panic(uint256)` / `0x11` expectation above. Preserve the existing call and assertions. If a later authorized test run fails with another error, stop and diagnose that failure; do not broaden the expectation, select a different error opportunistically, weaken production, or add a catch.
- **Confidence:** High on current source and compiler-defined error semantics; runtime not independently exercised.

## Evidence and files without another scoped defect

- Full `UniswapV3FullSpreadVaultHeldRedeem.t.sol`: ordinary-success and explicit-holder controls remain present; no additional REQ-H03 defect established.
- `NativeStandardYieldTarget.sol:30–70`: inspected ordinary/internal-balance dispatch; no additional scoped defect established.
- Full `UniswapV3FullSpreadStandardYieldExecutionTarget.sol`: inspected explicit-holder selection; no additional scoped defect established.
- `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:212–279` and `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:793–832`: inspected settlement-to-burn path; no production weakening recommended.
- `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:222–231,360–377`: establishes actual burn semantics; no production change requested for this item.
- `lib/crane/contracts/interfaces/IERC20Errors.sol`: inspected forwarding import; its existence does not change the burn's actual failure.
- Controlling PRD REQ-H03 section read directly. Repository routing and canonical testing skills were already read directly in this session. No supplied input path was missing; the assigned output was absent before this write.

For compiler semantics, used Context7 first (`/argotorg/solidity`), which returned the Solidity primary documentation: [Error handling and checked arithmetic](https://github.com/argotorg/solidity/blob/develop/docs/control-structures.rst). It specifies panic code `0x11` for underflow/overflow outside `unchecked`. Only a generic language-semantics question was sent externally; no repository code or sensitive data was sent.

Only this assigned Markdown report was created. No code, test, PRD, configuration or instruction file was edited. No shell, build, test, deployment or delegation was used. Return this exact test recommendation to the coordinator/human; review does not authorize implementation.

I did not run Forge.
