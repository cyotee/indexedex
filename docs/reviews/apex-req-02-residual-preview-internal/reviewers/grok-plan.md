# Implementation plan — residual preview stays internal and direct

- **Date:** 2026-10-14
- **Status:** DRAFT. This plan does not authorize code, test, config, or script edits. A later session must be explicitly asked to implement it.
- **Controlling PRD:** `docs/reviews/apex-req-02-residual-preview-internal/REMEDIATION_PRD.md`
- **ID:** REQ-02. Origin is Stage-1 REQ-02 / OD-01 as narrowed by OD-08. This plan does not reopen REQ-C04.
- **Author:** Grok (`xai/grok-4.7`), plan draft only.

If this plan conflicts with the PRD, the PRD controls.

## Objective

Make `previewResidualBuffer` an internal direct `previewExchangeIn`. Keep every existing sweep stop on a returned zero. Do not put a catch back. Add two production-hook tests, one for a zero quote and one for a reverting quote. One test does not stand in for the other. If either case cannot be reached on the bound vault, stop and report that case. Do not fake it.

## What was re-read

`previewResidualBuffer` is still `external view` and returns `previewExchangeIn` of the hook's pair token into its Standard Exchange. There is no `catch` and no zero check inside the preview.

```384:389:contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol
function previewResidualBuffer(uint256 amount) external view returns (uint256 shares) {
    Repo.Layout storage l = Repo._layout();
    return IStandardExchangeIn(l.standardExchange).previewExchangeIn(
        IERC20(l.pairToken), amount, IERC20(l.standardExchange)
    );
}
```

`bufferQuotedResidual` remains `external` at `:393-400` of the same file. It approves, calls `exchangeIn` with the quoted minimum, and clears the approval. This plan does not change that function.

The four sweep copies still stop on zero, then deposit only a positive quote. Each discards `to` or has no `to`. Each skips the quote when `pairToken == standardExchange` or when the pair balance is at or below `MAX_DUST_WEI`.

| Sweep | Zero stop | Positive deposit |
| --- | --- | --- |
| `UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol` | `:367-376` | `:377` |
| `UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol` | `:131-139` | `:140` |
| `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol` | `:388-397` | `:398` |
| `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol` | `:477-486` | `:487` |

`MAX_DUST_WEI` is `10` at `UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol:19`. The sweep excess is `pair.balanceOf(hook) - MAX_DUST_WEI` only when that balance is greater.

The preview body has no authorization check. The check this item keeps is each sweep's `if (preview == 0) return`. Do not add a second zero check, and do not add a caller-bytecode check.

`ClaimLib` is a library (`ClaimLib.sol:30`). Its external functions are `DELEGATECALL`s. An `internal` `previewResidualBuffer` is inlined into each Solidity caller. Current callers are all `ClaimLib.previewResidualBuffer(excess)`. A search of `*.sol` found no other caller and no test that invokes the function by selector.

## Which production entries reach which sweep

The TestBase deploys the split package, not the monolithic target. `TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol:115-126` installs `SeFacet`, `DepositFacet`, `DepositSingleFacet`, and `WithdrawFacet` through `PkgFactory.deployPackage` and `deployHook`.

### Reached — exercise one entry each

1. **DepositCommon sweep.** `DepositFacet` is `DepositTarget`, which is `DepositCommon`. `deposit` at `DepositTarget.sol:65-73` pulls both tokens and calls `_deposit`. `_deposit` syncs reserves, sets `kLast`, then calls `_refundPairDust` at `DepositCommon.sol:489-491`. The same sweep is also reached by `depositWithSeShares` (`:582`) and by `depositSingle` / `joinSingleAssetExactIn` through `InExecutionBase._depositSingle` (`DepositCommon.sol:710-712`, `InExecutionBase.sol:29-41`, `DepositSingleTarget.sol:64-72`). One entry is enough for this copy. Use `IHook.deposit` on the TestBase hook after the hook is live. A pass of this entry does not prove the withdrawal copy.

2. **WithdrawalLib sweep.** `WithdrawFacet` is `WithdrawTarget`. `withdraw` at `WithdrawTarget.sol:477` calls `_withdraw`, which calls `_refundPairDust` at `:536`. That wrapper only calls `Withdrawal.refundPairDust()` (`WithdrawTarget.sol:338-340`). `withdrawSingle` and `Withdrawal.withdrawFrom` (`WithdrawalLib.sol:26-66`) call `refundPairDust` directly. `DepositSingleTarget._redeemVaultHeld` (`:42-45`) and `InExecutionBase._exitLiquidityExactIn` (`:44-47`) also call `withdrawFrom`. One entry is enough for this copy. Use `IHook.withdraw` on the same TestBase hook. A pass of the deposit entry does not prove this copy.

Reserve sync on both of these paths runs before the sweep (`DepositCommon.sol:489-491`, `WithdrawTarget.sol:534-536`, `WithdrawalLib.sol:64-66`). Do not move it. Do not describe that earlier sync as a missing zero check.

### Not reached — cite and do not add an entry

- **SeTarget copy.** `SeFacet` inherits `SeTarget`, so the copy is on the installed facet. The only `_refundPairDust` hit in that file is the definition at `:477`. No production function in that file calls it. `beforeSwap` (`:572`) and `exchangeOut` (`:750`) do not. Do not add a public entry, a hook callback, or a test call just to reach this copy. The visibility change still has to compile against the unused call at `:485`.

- **Monolithic Target copy.** `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget` defines its own sweep at `:388-398` and calls it from its own `_deposit` (`:846`), `_depositSingle` (`:971`), `_withdraw` (`:1139`), and `_withdrawSingle` (`:1215`). No other contract under `contracts/` inherits that abstract contract. The TestBase package does not install it. The split facets use `DepositCommon` and `WithdrawalLib` instead. Do not deploy this contract with `new`, and do not add it to the package to manufacture a caller.

## Ordered steps

### 1. Change only the preview visibility

In `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol`, change `previewResidualBuffer` from `external` to `internal`. Keep it `view`. Keep the body as the direct `previewExchangeIn` at `:386-388`. Do not add a `catch`. Do not add a zero check. A returned zero is a successful quote.

Leave `bufferQuotedResidual` `external`.

### 2. Leave the four zero stops in place

Do not edit the four `if (preview == 0) return` lines, the three-iteration loops, the identity-pair early returns, or the `MAX_DUST_WEI` comparison. Do not deposit on zero. Do not pay the excess to `msg.sender`, the sweep's `to`, or `feeTo`.

Do not edit `bufferPair` in `WithdrawalLib.sol:70-79`. It has its own zero stop and is not this function.

### 3. Compile against the internal function

Every current caller is a Solidity `ClaimLib.previewResidualBuffer` call, so an internal library function should inline. If any caller cannot compile, stop and name that caller. Do not leave the function `external` to hide the failure. Do not add a public or external wrapper, and do not add a facet selector, so the hook can keep calling it.

After the change, the production diamond must not expose a `previewResidualBuffer` selector. It does not expose one today. Do not add one.

### 4. Add the two tests beside the deploy test

Add one file, or two files, under:

`test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/`

The existing deploy test in that directory is `UniswapV4SingleStandardExchangeBufferConstantProductHook_Deploy.t.sol`. It inherits `TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook`. The new tests inherit that same TestBase. `setUp` already deploys the ERC-4626 Standard Exchange through `_deployERC4626SE`, the hook package through the manager registry, and the hook through `PkgFactory.deployHook` (`TestBase` `:78-139`). Do not deploy the hook with `new`. Do not replace the hook, the bound Standard Exchange, the package, the manager, the registry, or the fee oracle with a mock. Do not add a token or a vault that exists only to throw.

The dust floor in assertions is `Repo.MAX_DUST_WEI`, not a second constant. The TestBase `DUST` constant is the same value (`TestBase` `:74`). Use the repo constant in the excess calculation so the test quotes what the sweep quotes.

Each test exercises both reached copies:

- Case 1 calls `deposit` and, separately, `withdraw`, on the production hook.
- Case 2 calls the same two entries. A revert on one copy does not witness the other.

### 5. How Case 1 is built

Case 1 must succeed. The excess stays in the hook.

1. Use the hook and bound vault from `setUp`. Bootstrap a live position with the TestBase's own deposit helper only if the chosen entry requires a nonzero LP supply. `deposit` can be the first mint. `withdraw` needs an existing LP balance. Do not bootstrap by calling a path that is not on this hook.
2. Put pair tokens on the hook so that, at the moment the sweep runs, `pair.balanceOf(hook) > MAX_DUST_WEI`. The excess is that balance minus `MAX_DUST_WEI`. If the chosen entry moves pair before the sweep, compute the sweep-time balance from that known movement. Do not quote some other amount and claim it witnessed the sweep.
3. Before the production call, call `previewExchangeIn` on the bound vault for the hook's pair token, that same excess, and the vault as `tokenOut`. That is the view the sweep uses (`ClaimLib.sol:386-388`). This is Case 1 only if that call returns 0.
4. Record, before the call, the hook pair balance, the excess, the hook's Standard Exchange share balance, the caller's pair balance, and the fee recipient's pair balance. Read the fee recipient from the hook's existing fee oracle. If that recipient is the zero address, record that and do not invent one.
5. Call the production entry. It must succeed. The entry's own minimum must still be met. Do not count that payout as the dust.
6. Assert the hook still holds the pair excess. Its Standard Exchange share balance did not increase by a deposit of that excess. The caller and the fee recipient did not receive the excess. The `to` argument is unused by the sweep. A refund that belongs to the deposit clamp, or a withdrawal payout that was quoted before the sweep, is not the dust and must be subtracted only if it was recorded as that operation's own payout.
7. The test fails if the sweep deposits the excess, pays it out, or reverts because the quote was zero.

Start with the smallest excess the sweep can quote: hook pair balance `MAX_DUST_WEI + 1`, excess `1`. If that preview is not 0, try other excesses the hook can hold only while `previewExchangeIn` of that exact excess returns 0. The bound vault is the ERC-4626 wrapper from `_deployERC4626SE`. Its pair-to-share preview is `_previewExchangeIn` in `ERC4626StandardExchangeCommon.sol:35-54`, which uses `convertToShares` and share conversion. A positive amount can still return 0 if that conversion floors. Do not assume it does.

### 6. How Case 2 is built

Case 2 must revert the whole call. A caught revert that lets the call succeed is a failure, even if the excess remains in the hook.

1. Use the same production hook and the same bound vault.
2. Reach a state that vault already supports in which `previewExchangeIn` of the sweep's excess reverts. A pause, a disabled vault, or another rejection the production vault already exposes may be used only if it does not replace the vault and the sweep would still quote that same excess. The preview re-read at `ERC4626StandardExchangeCommon.sol:38` reverts on a zero amount, and `:69` reverts `UnsupportedRoute` for a route the sweep does not use. Neither of those is this case. Do not pass a zero excess. Do not change the token pair to force `UnsupportedRoute`.
3. Record the hook pair balance, its Standard Exchange share balance, and the caller's balances before the call.
4. Call the same kind of production entry used for that copy in Case 1. The call must revert. The revert must be the vault quote's revert, not a later unrelated minimum, deadline, or balance failure. Assert the recorded balances are unchanged.
5. Do not accept any revert. Do not add a catch so Case 1 can pass.

### 7. If Case 1 or Case 2 cannot be reached

Stop. Report which case was not reached, which sweep copy was being exercised, and the preview result that blocked it.

- If every excess the hook can hold makes `previewExchangeIn` return a positive share count, Case 1 was not reached. Do not replace the vault to force a zero. Do not mock the vault. Do not mark Case 1 passed because the sweep's zero branch exists in source.
- If no production state makes that preview revert, Case 2 was not reached. Do not mock the vault. Do not add a token or a vault that exists only to throw. Do not add a catch.
- A reached case on the deposit copy does not close the withdrawal copy, and the reverse is also false. Report each copy separately.
- Do not claim REQ-02 closed if either case, on either reached copy, was not reached.

### 8. Artifact refresh, then the test

This visibility change is a production edit. FactoryServices read creation bytecode from `out/`. After the edit, refresh artifacts before `forge test`. Use `python3 scripts/forge-artifacts.py test` with the edited ClaimLib source and `--test-root` pointed at the new test file. Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`. Do not kill a long compile for lack of progress lines.

Report the commands actually run. A present assertion is not a pass until that run is reported.

## What must not change

- Do not add another zero check on top of the four that already exist.
- Do not make a successful zero revert the parent. That rollback rule is REQ-C04, for a hook join preview of zero. This quote is a Standard Exchange preview.
- Do not change `bufferPair`.
- Do not change `bufferQuotedResidual` except to keep calling it only after a positive preview. It stays `external`.
- Do not move reserve sync from before the sweep to after it.
- Do not pay dust to `msg.sender` or `feeTo`.
- Do not add a public wrapper or a facet selector for the preview.
- Do not add an entry to reach the SeTarget copy or the monolithic Target copy.
- Do not deploy, migrate, or upgrade live instances.
- Do not mock the hook, the Standard Exchange, the package, the manager, the registry, or the fee oracle.

## Done when

- `previewResidualBuffer` is `internal`, has no `catch`, and still returns `previewExchangeIn` of the excess pair amount for that hook's Standard Exchange.
- `bufferQuotedResidual` is still `external`.
- All four sweeps still return without depositing when that quote is zero. The SeTarget and monolithic Target copies were cited. No entry was added to reach them.
- The deposit production entry and the withdrawal production entry each have a separate zero-preview test and a separate reverting-preview test, or the implementation report says which case and which copy was not reached.
- The zero test shows the excess still in the hook, no Standard Exchange deposit of that excess, and no payment of that excess to the caller or `feeTo`.
- The revert test shows the vault quote's revert and unchanged recorded balances. It does not accept an unrelated revert.
- The hook gained no `previewResidualBuffer` selector.
- Artifacts were refreshed before `forge test`. The report names the commands run. If a case was not reached, the report does not claim REQ-02 closed.

## Blocking question

None. Unreachable Case 1 or Case 2 is a stop-and-report condition in the PRD, not a question that blocks this plan.

I did not run Forge.
