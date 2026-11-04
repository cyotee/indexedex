# r2 h2tb-staking-se-no-killswitch: CONFIRMED (defense-in-depth gap, no attacker profit)

File: NoKillSwitch.t.sol. All 4 suites PASS on the audit runner slot2 (hermetic fixtures, no fork needed).

## Setup
Each staking SE is deployed through its DFPkg and the registry, using TestBase_{Lido,EtherFi,RocketPool}*.
An honest LP deposits 100 WETH. The registry owner then calls setVaultAddressDisabled(se,true)
and setPackageDisabled(pkg,true), and the test asserts isDisabled(se)==true.

## Result: inbound calls by an unprivileged user after the disable
| route | Lido | EtherFi | RocketPool |
|---|---|---|---|
| exchangeIn WETH->share (10 WETH) | ok, 1.001e22 sh | ok | ok |
| exchangeOut WETH->1e18 sh | ok | ok | ok |
| SY.deposit(WETH, 5) | ok, 5.005e21 sh | ok | ok |
| exchangeInEth{5 ETH} (Lido only) | ok, 5.006e21 sh | n/a | n/a |
| IERC4626.deposit | reverts with AllowanceExpired(0), the Permit2 pull. This is not a kill-switch gate | same | same |

totalSupply grew from 1.001e23 to 1.2014e23 (Lido) and 1.1513e23 (EF/RP) while the vault was "disabled".

## Control
The sibling RebasingAwareERC4626 family is tested with the same registry call. Its deposit and exchangeIn revert with
VaultDisabled(vault) (0x1ba84b43), and redeem still works. This shows the switch is functional and that the
Lido/EtherFi/RocketPool targets simply never query it.

## Impact
Operational only. registry.disableVault/disablePackage cannot halt inflows into these three families
during an incident. So it cannot stop users from entering an SE that is being exploited through a separate bug
(par/fee externalization, requeue). There is no direct attacker profit and no victim loss in isolation.
Severity: low. Fix: add `_requireNotDisabled()` (as in RebasingAwareERC4626Common.sol:85-95) to the inbound
routes of exchangeIn, exchangeOut (share-out), exchangeInEth and the SY deposit/_standardRoute inbound path.

## Run note
Stale handlers left in the shared slots by other dirs (p4-balancer, p4-hooks, ...) fail to compile with stack-too-deep.
I ran with `--skip` globs that exclude every other apex_audit dir.
