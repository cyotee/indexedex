# chain-blocked-session: CONFIRMED (composite, V4 blocked-mode primitives compose in ONE unlock)

Run: FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/chain-blocked-session/ChainBlockedSession.t.sol -vv`. 3/3 pass.

## Thesis
Every FullSpread blocked-mode primitive gates on the **same** guard:
`canOpenPoolManagerUnlock() == !PoolManager.isUnlocked()`. So any contract that holds its own
`PoolManager.unlock` session forces **blocked mode on every vault that LPs the same PoolManager,
simultaneously**, for the whole duration of that one unlock. The attacker therefore does not pay
one manipulation cost per primitive-as-a-separate-transaction; it runs them all inside a single
atomic session and the profits stack.

## What the executed PoC does
One unprivileged `ChainAttacker`, one `PoolManager`, two independent hookless FullSpread vaults
(pool A and pool B, each ~45% of its pool's in-range liquidity, 0.3% fee, 1:1, 18/18 dp). All
capital is the attacker's own / settled through V4 flash accounting in-tx.

Inside **one** `attacker.run(...) -> PoolManager.unlock`:
- **Leg A = fs-blocked-entry-spot-mint** on pool A: push sqrtP x2 (k=4), blocked single-sided
  `exchangeIn(a0, 800 -> vaultA shares)` priced against the moved slot0 (mints ~35% excess
  shares), restore sqrtP exactly. Pro-rata dual exit after the unlock.
- **Leg B = fs-blocked-exit-sleeve** on pool B: push sqrtP down to r=1.30, blocked
  `exchangeIn(vaultB shares -> b0)` paid from the free sleeve at the moved `_quoteZapOutAmount`,
  restore sqrtP, clear the token1 fee debt with a tiny exact-out swap.

The two legs need **opposite** price directions, which is exactly why they live on two vaults; the
single unlock session is what lets both run in blocked mode at once.

## Results (token value at the restored price P=1; profit asserted net of all swap/LP fees)
| run | attacker net profit | victim loss |
|---|---|---|
| leg A alone (entry) | **+170.3** | 179.3 (vault A LP) |
| leg B alone (exit)  | **+154.6** | 157.7 (vault B LP) |
| **COMPOSITE (both in ONE unlock)** | **+324.8** | **337.1** (both LPs) |

Composite profit (324.8) ≈ entry (170.3) + exit (154.6) = 324.9: the legs are cleanly additive
because they hit independent pools. The composite **exceeds the best single primitive by 1.9x**
(324.8 vs 170.3), which is the goal — a single unlock compounds every blocked-mode vault on the
PoolManager. Each extra vault on the shared manager adds its own extraction at no additional
session cost.

## PoC validity
- Attacker is an unprivileged contract. `vm.prank` is used only to give it an EOA caller for the
  honest pre-deposit in vault B.
- No `vm.store`/`etch`/`mockCall`/`deal` on protocol state during the attack. Victims (this test
  contract) deposit honestly before the attack, in an earlier block.
- Every price move is a real V4 swap whose delta the attacker settles from its own balance in the
  same tx (net cost = swap fees). Both pool prices are restored (A exactly; B within 0.25%).
- Profit accounting counts the attacker's pre-bought vault-B shares at fair NAV in the pre-snapshot,
  so redeeming them is NOT mistaken for profit; the +154.6 matches the standalone fs-blocked-exit
  PoC (+155/+163).

## Which named primitives actually compose, and which do not
- **fs-blocked-entry-spot-mint, fs-blocked-exit-sleeve** (executed here): compose, additive.
- **pons-blocked-conduit, detf-spot-mint**: same V4 guard
  (`canOpenPoolManagerUnlock`/live-slot0 pricing). On the production deployment the census confirms
  one canonical PoolManager, so one attacker unlock blocks these too and they stack in the same
  session. They were not co-executed here only because each family's TestBase deploys its own
  isolated PoolManager + package set; combining all packages on one manager is a fixture-wiring
  exercise, not a protocol barrier. (All these families are also undeployed today per census, so
  this is a pre-deployment / design finding.)
- **fs-maintenance-at-spot-jit — DOES NOT join a V4 PM.unlock session (blocking mechanism differs).**
  The confirmed JIT primitive is on the **UniswapV3** FullSpread vault (`MaintenanceJit.t.sol` uses
  `IUniswapV3Pool`). Its "blocked" state is triggered by the **V3 pool lock inside a swap callback**,
  not by `PoolManager.isUnlocked()`. There is no V4 PoolManager unlock to share, so it is a separate
  atomic transaction, not part of this one unlock. It still composes as its own flashloan tx, but
  the "inside ONE PM.unlock" framing does not apply to it.
- **wings-***: the Wings family (Money.sol) is new, undeployed, and its primitives are their own
  atomic sessions; not combined here.

## Fix
Single root cause for the whole composite: do not price blocked-mode entries/exits against live
slot0, and/or do not let an external `PoolManager.unlock` holder put vaults into the privileged
"blocked" branch. A manipulation-resistant reference (stored idle-mode book / TWAP with a deviation
revert) closes every leg at once.
