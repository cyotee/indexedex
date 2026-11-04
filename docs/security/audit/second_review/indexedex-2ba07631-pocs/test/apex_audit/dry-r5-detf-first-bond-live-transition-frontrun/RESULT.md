# dry-r5-detf-first-bond-live-transition-frontrun: CONFIRMED (user loss, launch window)

Test: DryFirstBondFrontrun.t.sol (based on r5-lifecycle-transitions/DetfFirstBondTransition.t.sol; contracts renamed, attacker-profit and victim-loss assertions added)
Run: forge test -vvv. Result: "2 tests passed". DryFirstBondFrontrun_Cp ok, DryFirstBondFrontrun_Weighted ok.

## CP (single-SE buffer hook, TestBase_UniswapV4Detf, wired but not live)
- Victim previewBond pre-live: 1000e9 DETF. Control first bond: principal 950e9, realized 501.03 pair after the lock.
- Attacker (unprivileged contract) makes the first bond with 1e10 wei. Reserve becomes DETF 0 / pair 9,990,009,980 wei, and isReserveLive = true.
- The victim's identical bond(1000 pair, 30d) pays 1000 pair and gets principal = 8 wei DETF. The reserve becomes 999.99e9 DETF / 999.0 pair. g falls back to the opening quote because reserveDetf == 0, so the full payment joins POL.
- The victim realizes 13.866 pair. Loss vs control: 487.16 pair (~97%).
- The attacker realizes 15.146 pair for a cost of 1e10 wei. Net profit: 15.1457 pair (asserted).

## Weighted 3-token reserve
After the attacker's dust first bond (reserve 10 wei DETF / 9,990,009,990 pair), the victim's 1000-pair bond reverts with 0x340a4533. Funds are not lost, but the launch can be griefed.

## Scope / caveats
- The issue only exists in the window between wiring (_requireReserveWired) and the first bond. Deployed 4663 CP-DETFs are already live, so it affects future launches and any instance left wired but not live.
- The repo bootstrap script Phase_08_Stage_04 requires !isReserveLive and shares >= minBondShares. A deployer bootstrap that gets front-run therefore reverts instead of losing funds. The protocol then starts from a dust spot reserve.
- The victim is any honest first bonder, or the deployer if it bonds again in live mode. bond() has no minPrincipal.

## Fix
- Restrict the first bond to the owner/operator, or require a minimum first-bond liquidity (e.g., pairEq >= the configured bootstrap amount).
- Add a minPrincipalOut argument to bond(). Alternatively, keep opening-price pricing until the reserve reaches a minimum depth.
