# Kimi K3 — REQ-05 plan draft (replacement session)

- **Label:** Replacement-session plan draft, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. Controlling text: `docs/reviews/apex-req-05-outside-trade/REMEDIATION_PRD.md` (50 lines, read in full; owner ruling 2026-10-17 at `:20-22` controls: add the held-token credit check to all four families; V3 already has it). Nothing was edited. This is not `REMEDIATION_PRD.plan.md`.
- **Date:** 2026-10-17.

## Spot-checks (this round)

- PRD sites current: hookless `…/fullSpread/hookless/AttributionAndBooking.t.sol:34-56`, Pons `…/ponsFamilyV2Hook/AttributionAndBooking.t.sol:37-59`, wings `…/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:26-40` — all unchanged since my verification pass. V3 `UniswapV3FullSpreadLocalBook.t.sol:68-75,114-136` already performs the full sequence; it is cited, not edited.
- Decimals (decide the fixed amount per PRD `:36`): hookless and Pons fixture tokens are 18-decimal (hookless Acceptance base and its in-file `1e18` literals; Pons base defaults `_decimalsA()/_decimalsB() == 18` at `…PonsFamilyHook_Acceptance.sol:32-33`) → `7 ether`. Wings `token0` is 6-decimal (`…/upperLowerWings/test/bases/TestBase_…Vault.sol:35`) → `7 * 10 ** 6`.
- The wings true-flag path exists and reverts with the named error: `…/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:84-87` (`requirePretransferCaller` then `TransferDeltaInsufficient(amount_, available)` where `available` is balance minus the local book — the same quantity the test reads as `balanceOf − reserveOfToken`).
- Caller: `address(this)` (the test contract) has bytecode — no EOA anywhere. In-file precedent: hookless `:20-21` reverts `TransferDeltaInsufficient(1e18, 0)` from a true-flag `address(this)` call.
- Funding: all three test contracts hold ample fixture tokens (Pons base mints `1e32`; wings mints `1e25` at `:22-23`; hookless transfers raw tokens from the test contract at `:13`), so a plain `token0.transfer(vault, amount)` needs no new import or mint.

## The edit — one block per file, same shape, no choice

Insert immediately **after** the existing unchanged-book assertions and **before** the existing deposit leg (hookless: after `:42`, before `:43`; Pons: after `:45`, before `:46`; wings: after `:36`, before `:37`). The reverted call must precede any operation that could sync the book.

Token, caller, and call per file:

| File | Token | Amount | Caller | Call |
|---|---|---|---|---|
| hookless `AttributionAndBooking.t.sol` | `token0` | `7 ether` | `address(this)` | `vault.exchangeIn(token0, credit + 1, IERC20(address(vault)), 0, address(this), true, block.timestamp)` |
| Pons `AttributionAndBooking.t.sol` | `token0` | `7 ether` | `address(this)` | same shape |
| wings `…VaultMoney.t.sol` | `token0` (6-dec) | `7 * 10 ** 6` | `address(this)` | `IStandardExchangeIn(address(wings0)).exchangeIn(token0, credit + 1, IERC20(address(wings0)), 0, address(this), true, block.timestamp)` |

The inserted block (adapt the amount and the vault handle per the table; `ISecurePullErrors` is already imported in all three files):

```solidity
        uint256 preUnbooked_ = token0.balanceOf(address(<vault>)) - IBasicVault(address(<vault>)).reserveOfToken(address(token0));
        token0.transfer(address(<vault>), <amount>);
        uint256 credit_ = token0.balanceOf(address(<vault>)) - IBasicVault(address(<vault>)).reserveOfToken(address(token0));
        assertEq(credit_, preUnbooked_ + <amount>, "credit is the held surplus only");
        uint256 postBal_ = token0.balanceOf(address(<vault>));
        uint256 postBook_ = IBasicVault(address(<vault>)).reserveOfToken(address(token0));
        uint256 postSupply_ = IERC20(address(<vault>)).totalSupply();
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, credit_ + 1, credit_));
        <call from the table>;
        assertEq(token0.balanceOf(address(<vault>)), postBal_, "rejected over-credit moves nothing");
        assertEq(IBasicVault(address(<vault>)).reserveOfToken(address(token0)), postBook_, "rejected over-credit books nothing");
        assertEq(IERC20(address(<vault>)).totalSupply(), postSupply_, "rejected over-credit mints nothing");
```

`<vault>` is `vault` for hookless/Pons and `wings0` for wings. No other line of any file changes; the existing deposit leg and `_assertBooked()` follow unchanged. `minted == preview` stays where it is and is not this proof (PRD `:40`). V3's LocalBook file is untouched. No production file, no deleted-V4 content, no `catch`.

## One command

Test-only edits, so zero positional sources (per the REQ-SEP-01 command ruling); each `--test-root` is auto-consumed. From the repository root, warm `out/`/`cache_forge/`, no profile or `via_ir` change:

```bash
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol \
  -- -vv
```

The whole files run green. If the reverted call returns different bytes — including a credit value that differs from `preUnbooked_ + amount` — stop and report the family and the bytes; do not adjust the expectation to match an observation, do not edit production.

## Stop rule

If any cited line (the PRD `:29-31` sites, the wings `_pull` at `…VaultMoney.sol:84-87`, the wings base token construction at `:35`) has drifted, stop and report the file and line; choose nothing.

I did not run Forge.
