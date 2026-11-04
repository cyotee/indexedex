# balancer-router-permit-overpull: CONFIRMED (code-level; router not deployed on 4663)

Test: BalancerRouterPermitOverpull.t.sol (fixture: TestBase_BalancerV3StandardExchangeRouter, real Balancer V3 vault + Permit2 + SE router diamond)
Run: FOUNDRY_PROFILE=audit forge test --match-path test/apex_audit/balancer-router-permit/BalancerRouterPermitOverpull.t.sol -vvv  -> 2/2 PASS

## R1: over-pull strands victim funds
In `swapSingleTokenExactOutWithPermit`, `_permitTransferIn` pulls `swapParams.limit`. The Balancer branch forwards only `amountIn` (`_takeTokenIn`). Nothing refunds the difference.
- victim1: 1000 USDC exact-out, 1% slippage. True cost 1114.45 DAI, 1125.60 DAI pulled, 11.14 DAI stranded.
- victim2: 500 USDC exact-out, 0.5% slippage. 3.28 DAI stranded.
- Router balance afterwards is 14.42 DAI, exactly the sum of the over-pulls (asserted).

## Theft: pass-through branch spends the router's balance
In ExactOutSwapTarget, the limit check at :329-331 is commented out. In permit mode `_transferTokenIn` does `safeTransfer` from the router's own balance. `tokenInVault` is never validated.
- Test 1: the attacker's own FakeSEVault (previewExchangeOut = router balance) is used as pool, tokenInVault and tokenOutVault. The attacker signs a permit with limit=1 and amount=1 wei. Result: the router drained to 0, attacker net profit 14423338324477105836 wei DAI, equal to the victims' loss (asserted).
- Test 2: the real daiUsdcVault, limit=1. The attacker pays 1 wei DAI. The router pays 14.42 DAI and the attacker gets 14.36 USDC.

Valid under the rules: the attacker is an unprivileged EOA, with no prank, mock or store on protocol contracts. Cost is 1 wei plus gas.
Impact: every permit exact-out user loses their slippage headroom, and anyone can take it. Funds at risk are bounded by accumulated residue.
Deployment: the skeptic votes say the SE router is absent from the deployment manifests for chain 4663. I did not check this myself. If true, this is latent: live only where the router is deployed, e.g. the base_main scripts.
Not executed: R2 (batch exact-in buffer-first double Permit2 pull) and the batch exact-out wrong-flag DoS.
Fix: pull only what is needed, or refund `limit - amountIn` to the sender at the end of the permit call. Restore the `estimatedAmountIn > limit` check. In permit mode, require amount used <= amount pulled. Validate `tokenInVault` against the registry. Have `_takeTokenIn` honour the batch permit flag.
