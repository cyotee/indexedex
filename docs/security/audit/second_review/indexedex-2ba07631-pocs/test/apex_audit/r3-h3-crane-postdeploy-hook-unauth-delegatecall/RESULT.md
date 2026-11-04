# r3 h3-crane-postdeploy-hook-unauth-delegatecall: CONFIRMED (executed on t4, 4/4 PASS)

This is the same root cause as hunt3 NEW-1 (h3-crane-bundled-facets/PostDeployHookHijack.t.sol). It is a re-execution with stronger checks, not a new finding.

File: R3PostDeployHook.t.sol. Run: `forge test .../R3PostDeployHook.t.sol -vvv`. Suite result: ok, 4 passed.

## Tests
- **test_unprivilegedDeployerBackdoorsRegisteredPoolAndDrainsLP (PASS)**
  - Setup: the owner registers the ConstProd pkg.
  - The attacker calls `cpPkg.deployVault([DAI,USDC], EvilHooks)`. `EvilHooks.onRegister` calls `pool.postDeploy()`. The pool delegatecalls `EvilHooks.postDeploy(address)`, which cuts in `exec`.
  - After deploy, `isVault` is true and the hook facet has been removed, but the backdoor stays.
  - The victim LPs 1000 DAI + 1000 USDC.
  - The attacker calls `exec` to Replace `onSwap`, then swaps 1e12 wei DAI and receives 990e18 USDC.
  - The victim then withdraws all BPT and gets back 1010.000000001e18 total, so the loss is about 990e18 at a fair 1:1 price. The attacker's net profit is 989.999999e18.
- **test_control_honestPoolHasNoBackdoor (PASS)**: with `hooks = 0`, the pool is registered, has no foreign selectors, and the hook facet is removed.
- **test_variant_tokenDecimalsPathBlockedByStaticcall (PASS)**: a token whose `decimals()` changes state makes `registerPool` revert with `FailedCall()` (0xd6bda275), because Balancer calls `decimals()` via STATICCALL. The token-decimals route suggested in hunt3 is therefore not viable. Only the `onRegister` hook route (non-view) works.
- **test_fixControl_factoryOnlyHookBlocksAttack (PASS)**
  - The setup etches a patched facet that adds `require(msg.sender == factory)`.
  - The same attack then reverts with "PostDeployHook: not factory".
  - Honest `deployVault` calls still succeed.

## Severity / caveats
- MEDIUM.
- The victim has to LP into an attacker-deployed pool. The trust signal is the registry's `isVault` and the canonical pkg. The pool's hooks address is visible on the Balancer side, but it reports no flags.
- Live 4663: no Balancer pool pkgs are deployed on Robinhood, so live exposure is nil there. Exposure applies wherever base_main Script_04 is deployed.
- Fix: guard the Crane facet with factory-only access, or remove it before `pkg.postDeploy`. In indexedex, also restrict `hooksContract` in the permissionless `deployVault`.
