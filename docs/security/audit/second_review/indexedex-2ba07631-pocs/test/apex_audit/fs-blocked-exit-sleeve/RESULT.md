# fs-blocked-exit-sleeve-amgm: CONFIRMED (hookless FullSpread V4)

Run: FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/fs-blocked-exit-sleeve/FsBlockedExitSleeve.t.sol -vv`. 9/9 tests pass.

## Mechanism (confirmed by execution)
`canOpenPoolManagerUnlock()` returns `!isUnlocked(PM)`. So any contract that calls the vault from its own `PoolManager.unlock` callback forces the blocked branch.

In that branch, `_executeZapOutExactIn` (HooklessInBase.sol:169-184) works as follows:
- It pays `_quoteZapOutAmount` at the live, attacker-moved `slot0`.
- It pays from the free token0 sleeve.
- It burns only shares. No LP is removed and no real swap happens.

The attacker swaps back in the same unlock. The PoolManager's flash accounting nets the two swaps, so the price move costs only swap fees.

## Setup
- Project fixture `TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault`: real PoolManager, registry-deployed vault, default 20% liquid reserve, 0.3% fee tier, price 1:1.
- External full-range LP: 2k L (shallow case) or 20k L (deep case).
- Victim deposits 10k of each token.
- Attacker contract deposits 300 of each token at the fair price (cost 600 token0-equivalent), which gives 2.9% of supply.
- The attack runs in a later block, inside one `PM.unlock` with no external capital:
  1. Swap token0 for token1 down to sqrtP/r.
  2. Blocked `exchangeIn(vault, shares, token0)`.
  3. Swap back to sqrtP.
  4. Make a tiny exact-out swap to clear the token1 fee debt.
  5. Settle.

## Results (token0 units, valued at the original price; victim NAV includes the vault's uncollected fees)

| case | pool L | r=sqrtP/sqrtP' | attacker final value (cost 600; honest redeem ~591) | attacker profit | victim loss |
|---|---|---|---|---|---|
| zap | 10.6k (vault 81%) | 1.05 | 617.1 | +17.1 | 17.7 |
| zap | 10.6k | 1.15 | 671.1 | +71.1 | 72.8 |
| zap | 10.6k | 1.30 | 754.5 | +154.5 | 157.7 |
| zap | 28.6k (vault 30%) | 1.15 | 662.2 | +62.2 | 79.1 |
| zap | 28.6k | 1.30 | 733.3 | +133.3 | 165.3 |
| dual exit | 10.6k | 1.50 | 615.5 | +15.5 | 20.5 |
| dual exit | 28.6k | 1.50 | 570.4 | -29.6 (not profitable) | 20.5 |

- In the r=1.30 shallow case the attacker extracts 25.8% on capital in one transaction.
- The loss is capped by the free tokenOut sleeve (here 1716 token0). The attack repeats each time the sleeve is refilled.
- The dual exit gain is second-order, as predicted. It is only profitable when the vault is a large share of pool depth.

## Validity
- The attacker is an unprivileged contract. `vm.prank` is used only to set an EOA as the attacker's caller.
- There are no cheatcodes on protocol contracts.
- Swap capital comes from PoolManager flash accounting and is settled in the same unlock.
- The attacker's deposit is counted as cost.
- The victim deposited before the attack.

## Not tested
- The Pons (PonsFamilyV2Hook) variant. The code path is byte-identical, but hook fee and tax raise the cost.

## Fix
- In blocked mode, refuse single-sided zap-out and dual exit (revert `PoolManagerInteractionBlocked`).
- Or price them against the TWAP/reference with a deviation bound. For example, take min(spot, TWAP) value for the payout.
- Or pay strictly pro-rata in kind from free balances without the simulated swap. Even then the dual exit still needs a price guard.
