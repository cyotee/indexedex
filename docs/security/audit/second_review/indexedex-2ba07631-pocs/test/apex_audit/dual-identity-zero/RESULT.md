# dual-identity-outleg-zero: CONFIRMED (user fund loss + DoS of the route)

Test: DualIdentityOutlegZero.t.sol (3/3 PASS on t4 runner)
Run: FOUNDRY_PROFILE=audit forge test --match-path .../dual-identity-zero/DualIdentityOutlegZero.t.sol -vvv

Setup: a DUAL SE-CP buffer hook from the project's TestBase_UniswapV4DualSEBCPHook. currency0 is an
identity leg (token0 == se0 == a RebasingAwareERC4626 wrapper over tokenA). currency1 is tokenB behind
SimpleYieldERC4626. Two unprivileged LPs deposit normally: the attacker first, then the victim.

Results:
- previewExitSingleAssetExactBptIn(wrapper, lpV) = 6.67e29 shares (about 66.7 tokenA), which is nonzero.
- exitSingleAssetExactBptIn(wrapper, lpV, victim, preview*99%) reverts. Any caller that sets a minimum
  from the preview cannot use this route (DoS).
- With min=0: the call returns 0, the victim's LP is burned (balance 0), the victim receives nothing,
  the hook's wrapper balance stays at 2e30, and LP supply drops from 151.47e18 to 100.98e18.
- The attacker, as the remaining LP, then calls withdraw. The attacker's claim goes from 228.6 to 339.3
  tokenA-eq. Profit is 110.7 tokenA-eq. The victim lost the full claim of 116.0 tokenA-eq.
- exchangeIn(LP -> wrapper, min=0) behaves the same way: the preview is nonzero and the call pays 0.
- Control: exiting to the non-identity leg (tokenB) pays out normally.

Root cause: `_exitSingleAssetFrom` (Common.sol ~786-811) measures
`balanceOf(pair) - beforeOut` around `_withdrawFrom(to=this)`. For an identity leg, `_unwrap` does not
move anything and the transfer goes from the hook to itself. The residual swap output is re-buffered,
and `_unwrapPlanned` returns early because se == pair. The measured amountOut is therefore always 0.

Limits:
- The attacker cannot force the loss. It needs the victim or an integrator to pass min=0. The attacker's
  gain is a passive pro-rata windfall that goes to all remaining LPs.
- No DUAL deployment exists on 4663.
- Severity: medium. The route is broken for everyone, and min=0 callers lose their whole position.

Fix: for an identity out-leg, credit the identity-leg withdrawal (a0 or a1) directly and add the swap
output, instead of measuring a balance delta. Alternatively, make `_unwrapPlanned` and `_withdrawFrom`
report the amounts they keep in place.

Side note (not investigated): the victim's balanced deposit of 149.5 tokenA-eq was credited with only
116.0 of claim, and the existing LP's claim rose by about 29.6. This may be a separate deposit-ratio
issue or an artifact of the 1:1 valuation used here. The profit figure above leaves it out, because the
attacker's claim is measured after the victim's deposit.
