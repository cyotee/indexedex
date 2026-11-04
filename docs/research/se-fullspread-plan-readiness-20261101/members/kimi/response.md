# Identity

Kimi, independent council member (`kimi`) for run `se-fullspread-plan-readiness-20261101`. Requested route: `kimi-coding/k3.1-pro:high`, global route. Actual Native identity was not exposed. Peers read before submission: no.

# Question and targets

Question: are the locked full-spread vault requirements complete enough to write an implementation and testing plan now, without leaving a product decision to the plan author or implementor?

Required targets reviewed:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`
- `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`
- `docs/security/audit/second_review/REMEDIATION_TRACKER.md`

The future plan's scope is treated as locked: extend the integration matrix, add integration tests, and test the new vault against every applicable second-audit vulnerability. This response does not write that plan.

# Evidence

- PRD revision `fullspread-se-prd-weir-align-r1` says FS-OWN-01 through FS-OWN-33 override conflicting older text. Those locks settle, among other things, WETH-only caller faces, `PkgInit.poolManager`, the dead-share floor, booked rather than raw-balance accounting, no ERC-4626/ERC-5115/`getRate` surface, proportional reserve redemption, and the exact usage-fee formula.
- The function-review file says unmarked functions remain open. The PRD's FS-FACET-01 still marks `queryFacet` as under function review and defers the selector recount until that review closes.
- FS-HOOK-02 and FS-A26 require a canonical two-pool, exact-input, both-direction integration proof. FS-HOOK-04 says a cited rejection does not replace that proof. FS-RATE-01 and FS-A29 forbid binding the existing full-book `StandardExchangeRateProviderFacet` as this vault's rate.
- The current `RateProviderFixtureLib` states that every buffered hook leg needs a rate provider and derives the production `StandardExchangeRateProvider`. The two same-manager fixture libraries use that helper for the new vault's required hook families. Thus the provider rejection anticipated by FS-HOOK-04 is a concrete current-fixture issue, not a hypothetical one.
- The matrix PRD's M5/M6 structure is seven hook behavior contracts plus one fixture adapter per SE family. M12 names the JSON/Markdown/acceptance evidence. The current tree contains V3 full-spread rows but no V4 full-spread matrix row.
- The second audit contains 45 findings. The remediation tracker's retirement of the two older V4 FullSpread implementations closes those source trees only; it does not establish that this new design avoids the same mechanisms.

# Assumptions

- Later owner locks govern where older PRD or function-review prose conflicts with them. Stale statements already settled by FS-OWN-11 through FS-OWN-33 are not counted as open decisions.
- "Must encode a test" below means a direct vault regression, a package/proxy regression, or an integration regression involving this vault. "No" means the finding's mechanism has no corresponding component or operation in the locked product; it does not mean the finding was skipped merely because it named another family.
- An FS-HOOK-04 rejection record is not a passing integration test and cannot substitute for FS-A26.
- Security regressions must use the real vault package, PoolManager, hooks, tokens, and deployment paths required by the PRD. No test execution or exploit reproduction was performed for this research response.

# Coverage

## Current integration-matrix files to extend

The matrix root is `test/foundry/spec/hooks/uniswap/v4/standardExchange/`. The plan should extend these existing files and patterns:

1. Shared fixture API and the closest full-spread adapter example:
   - `SeMatrixFixture.sol`
   - `SeMatrix_FullSpreadV3Fixture.sol` (reference for a new V4 adapter, not a row to mislabel as V4)
2. All seven current row behavior contracts:
   - `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`
   - `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`
   - `dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`
   - `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol`
   - `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`
   - `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`
   - `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol`
3. The corresponding seven concrete row locations, adding `*_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` beside each existing `*_SeMatrix_UniswapV3FullSpreadStandardExchangeVault.t.sol`. The behaviors currently use exact-out in setup and row controls, so they must be adapted to this vault's locked `ExchangeOutNotAvailable` surface and accepted bundle bootstrap rather than silently expecting the V3 behavior. Applicable decimal rows belong under each family's existing `decimals/` directory because FS-OWN-27 requires underlying-decimal scaling.
4. Existing same-manager integration helpers:
   - `FullSpreadSameManagerAmmFixture.sol`
   - `FullSpreadSameManagerWeightedFixture.sol`
5. Matrix evidence and acceptance records:
   - `docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json`
   - `docs/audits/apex-2026-09-17-evidence.md`
   - `docs/audits/apex-2026-09-17-evidence/acceptance.json` (R10.3)

The governing matrix reference is `docs/audits/apex-2026-09-17-open-item-1-hook-se-matrix-PRD.md`; its requirement that an unresolved cell not be reported as compatible is consistent with FS-HOOK-04.

## Second-audit finding coverage

| Finding | Test required? | Required coverage or reason no vault test applies |
| --- | --- | --- |
| APEX-2026-010 | Yes | Push the pool price and attempt stale-reserve/pretransfer credit and refund. FS-OWN-19/20 require live deployed reads, a committed local snapshot, and booked requested amounts only; no existing free balance may become caller credit. |
| APEX-2026-011 | Yes | Run the no-price-move borrowed/unlocked deposit-exit loop and spot-move variants. The new common issuance/redemption engine must not over-mint or increase attacker value; merely deleting the old family is not evidence. |
| APEX-2026-012 | No | The mechanism is Wings' multi-position liquidation quote over temporary external depth. This PRD has no Wings positions or liquidation-quote share pricing; its reserve view is not the issuance formula. Spot-manipulation regressions for this vault are covered by 011/022/023. |
| APEX-2026-013 | Yes | Assert all generic ERC-4626 mutators are absent and a pre-existing token balance cannot mint through any installed selector. FS-OWN-03/05 and FS-A01 supply the direct negative surface. |
| APEX-2026-014 | Yes | In weighted, Curve quad, Balancer quad, and Orbital integrations with a raw rated leg, test rates above and below one in both swap directions. Rated input and face output must use one unit domain and round trips must not drain LPs. |
| APEX-2026-015 | Yes | In the Curve quad integration, accrue a non-unit SE rate and exercise single-sided join, SE-leg exit, and rated swap. Raw share counts must not be mixed with rated balances to transfer yield. |
| APEX-2026-016 | Yes | Use the required larger weighted setup (`n >= 3`) with a partial book. A dust non-owner seed followed by swaps and exit must not open the doors or reduce incumbent value. |
| APEX-2026-017 | No | The defect is a Balancer V3 buffer hook's caller-supplied router callback during pre-seat. This vault and its required integrations use Uniswap V4 PoolManager hooks, not that Balancer router/pool path. |
| APEX-2026-018 | No | The defect is Balancer `computeBalance` mixing math-domain and live balances on BPT exits. This vault is not a Balancer pool or BPT and exposes no such exit. |
| APEX-2026-019 | No | The defect is Balancer V3 SE-router Permit2 over-pull and pass-through residue spending. No Balancer router is in the locked package or integration surface. |
| APEX-2026-020 | No | The finding concerns DETF mint/bond pricing and bond parameters, which this SE vault PRD does not implement. Hook-leg tests do not make the vault a DETF minter or bonder. |
| APEX-2026-021 | No | The finding concerns Balancer-hosted DETF bond/mint pricing during a Balancer unlock. That product and venue are absent here. |
| APEX-2026-022 | Yes | Port the V3 blocked-callback analogue to a V4 outer unlock: displace spot, perform single-sided entry and exit, restore spot, and measure attacker and incumbent value at the initial price. FS-UNLOCK-02 must not become a fee-free spot-repriced CP loop. |
| APEX-2026-023 | Yes | Create idle excess, displace spot, and run post-operation sleeve adjustment, including the vault's own redemption swap followed by restoration. New liquidity must not be minted at the manipulated/self-moved price at incumbent expense. This conflicts with FS-OWN-12 as noted below. |
| APEX-2026-024 | Yes | Exercise a large one-token exit with a remaining holder. Although Wings' core-closing path is absent, this vault also has one-token exits and MIN/MAX swap limits; only the exiting holder's fraction may be converted and staying holders must not fund exit slippage. |
| APEX-2026-025 | No | Wings' permissionless rebalance, progress cap, and liquidation quote do not exist; FS-OWN-09 expressly excludes a rebalance facet. |
| APEX-2026-026 | No | Wings' 512-step liquidation walk and its `getRate`/liquidation-value consumers are absent. Dust-step behavior for this vault's actual swap planner is separately covered by 041. |
| APEX-2026-027 | No | Lido/EtherFi pending-withdrawal queues and staking `rebalance()` are not components of this vault. |
| APEX-2026-028 | Yes | For the Dual identity-leg attempt, prove either a correct nonzero payout or the locked cited rejection with no LP burn. A self-transfer/balance-delta path must not burn LP and return zero; FS-A24 forbids adding `asset()` to force a pass. |
| APEX-2026-029 | Yes | Assert this vault exposes no `getRate` and is not bound to the existing full-book provider. For any externally authorized provider required by a hook, manipulate subject composition and prove a pumped rate cannot increase credited inflow. The missing provider policy is a blocker below. |
| APEX-2026-030 | Yes | In the Balancer quad integration with a rated raw leg, repeat joins/exits without swaps. Rated-now and unrated-checkpoint domains must not mint phantom protocol LP; the no-trade fee mint must be zero. |
| APEX-2026-031 | No | The finding is a Balancer virtual-TTA buffer pool pricing unbalanced BPT joins. This vault has no virtual TTA, BPT, or Balancer join surface. |
| APEX-2026-032 | Yes | Exercise deployment through the shared Crane factory with adversarial post-deploy callers. The temporary hook window must not permit an unprivileged caller to add surviving selectors; verify the final proxy against the reviewed manifest. |
| APEX-2026-033 | No | DETF primary redemption, protocol-LP rejoin, and DETF burn gates are outside this SE vault's surface. |
| APEX-2026-034 | Yes | Attempt first-deposit inflation with direct token transfers and fee donations. FS-OWN-11's dead shares and FS-OWN-20's unbooked-balance exclusion must prevent zero-share theft and preserve later depositor value. |
| APEX-2026-035 | No | Aave cross-version debt/supply netting and liquidation unwind do not exist in this Uniswap position vault. |
| APEX-2026-036 | Yes | Through each required hook integration, reject EOA staged pretransfer and test the atomic contract control. Resting hook face or shares must not become another caller's credit or refund. |
| APEX-2026-037 | No | This is an operational risk from re-enabling a specific frozen legacy WETH-leg vault after reserve drift. The new vault has no legacy deployment, re-enable, or migration requirement; its ordinary disable gate is covered by 045. |
| APEX-2026-038 | No | sDETF staking weights and same-transaction stake/unstake reward accounting are not present. |
| APEX-2026-039 | Yes | Leave self-shares and unbooked tokens, then attempt exact-in/pretransfer credit and refunds from another contract. Only the requested booked amount may be consumed; no resting value may be refunded to a caller. |
| APEX-2026-040 | Yes | Make the attacker the first depositor and inflate fee growth with `PoolManager.donate`, then measure a later deposit and attacker redemption. The `MIN_SHARES` sink and issuance rule must not still permit donation-driven depositor loss. |
| APEX-2026-041 | Yes | Seed adjacent liquidity-1 ticks and sweep entry, redemption, underlying swap, and previews. The new planner must not acquire an undocumented 64-step/one-step capacity cap, and previews must match execution; exact-out remains intentionally closed. |
| APEX-2026-042 | Yes | Deploy with a no-return-`approve` ERC-20 face and operate settlement. No raw bool-decoding Permit2 approval may make package deployment impossible. |
| APEX-2026-043 | Yes | In the Orbital integration, attempt a dust first mint and fill-to-R griefing. The vault-bearing hook must not become permanently capped or lose ordinary swap/join liveness to an unprivileged griefer. |
| APEX-2026-044 | Yes | Run deposit/redeem cycles at nonzero and 100% usage fee and account for depositor, incumbent, and `feeTo` value. The required absence test is incompatible with the additive fee mint currently locked by FS-OWN-24. |
| APEX-2026-045 | Yes | Disable both vault and package and exercise every inbound issuance route, including buffered-hook entry. All must revert `VaultDisabled`; supported exits must remain available under FS-A38. |
| APEX-2026-046 | No | Balancer composite-router settlement hints and placeholder routes are outside the Uniswap V4 vault and its hook integrations. |
| APEX-2026-047 | No | StataToken/aToken zero-share deposits and stranded booked aToken backing are not components of this vault. |
| APEX-2026-048 | Yes | Seed sub-quantum one-sided fees and exercise compound followed by every LP-moving route. Dust conversion must not freeze deposit or withdrawal, and previews must not continue promising an execution that always reverts. |
| APEX-2026-049 | Yes | Assert `previewExchangeOut` and `exchangeOut` always fail closed with unchanged balances under FS-A09. That proves the Camelot exact-out rounding/equality route has no exposed analogue here. |
| APEX-2026-050 | No | The vault does not read or update the V4 truncated TWAP oracle, and the PRD does not authorize adding one. |
| APEX-2026-051 | Yes | Sweep preview versus execution over both input directions and prices/amounts that cross planner boundaries. A preview must not certify a plan execution rejects through aliased or self-compared state. |
| APEX-2026-052 | Yes | Verify `eip712Domain`, `DOMAIN_SEPARATOR`, and a standard wallet-style ERC-2612 signature agree after package initialization; an uninitialized name/version must not break `permit`. |
| APEX-2026-053 | No | MultiStepOwnable ownership-transfer buffering belongs to manager/access-control packages, not this vault's selector or money surface. No manager change is authorized by this PRD. |
| APEX-2026-054 | Yes | For every required hook that unwraps this vault's shares with `pretransferred=false`, exercise withdrawal/exit and verify the hook grants and resets the required allowance. Missing approval must not freeze user exits. |

Result: 27 finding IDs require direct or integration regression coverage; 18 have no applicable component in the locked product. Every one of the 45 IDs is accounted for above.

# Conclusions

**Not ready.** A plan author would still have to choose product behavior or accept an integration/security requirement that cannot be satisfied as written. The following decisions block a decision-free implementation and testing plan.

| Blocking decision | PRD sentence that leaves it open | One owner question that would close it |
| --- | --- | --- |
| Final query surface and selector manifest | FS-FACET-01 marks `queryFacet` as "Still under function review." It also says: "Recount from the current package after the function review closes." | What exact selectors, including the reusable Position/Protocol Aware surfaces, must the final `queryFacet` and diamond cut expose? |
| Rate policy required by current buffered-hook fixtures | FS-RATE-01: "A hook that requires a provider for this share is an unresolved FS-HOOK-04 record until a later decision names a rate policy. This lock does not name one." FS-HOOK-04 also says a cited reject cannot close FS-A26. | Which authorized external rate policy and provider should each current hook fixture use so the required canonical integration proof can execute without this vault implementing `getRate` or binding the existing full-book provider? |
| `compound()` with booked idle but no fees | FS-OWN-14 first says "`compound()` deploys booked idle," then says "If there are no fees, return without a state change and without an event." | When booked idle exists and collectable fees are zero, should `compound()` deploy that idle and run sleeve adjustment, or return with no state change? |
| Deployment mechanics for a one-token underlying donation | FS-OWN-21: "An underlying donation is deployed into the pool before `donate` returns. It is not left as idle." No rule says how a single token is converted to the pool ratio or how undeployable residue is handled. | For a one-token underlying donation that does not match the pool ratio, what exact swap and residual rule deploys the donation before return without leaving idle or minting shares? |
| Whether busy economic views revert | FS-OWN-19 says "No view reverts," while FS-A32 says "Busy-vault economic views revert. An idle vault answers while the manager is unlocked." | Does "No view reverts" apply only to ordinary/unknown-token reserve queries, preserving FS-A32's busy-vault reverts, or does it prohibit those busy-vault reverts as well? |
| Post-withdrawal maintenance versus APEX-2026-023 absence | FS-OWN-12 requires moving each local balance toward target after every withdrawal; applied after the vault's own MIN/MAX-bound redemption swap, this preserves the trailing mint at a self-displaced price identified by APEX-2026-023. | What exact post-withdrawal sleeve rule should replace or qualify FS-OWN-12 so the required APEX-2026-023 self-JIT regression can pass? |
| Additive usage-fee dilution versus APEX-2026-044 absence | FS-OWN-24 requires minting `mulDiv(sharesMinted, usageFeeOfVault(address(this)), 1e18)` additional shares to `feeTo`, which is the dilutive formula reported by APEX-2026-044. | Should the additive fee remain with APEX-2026-044 explicitly accepted as a characterization rather than an absence test, or should the fee be netted from the depositor's shares so incumbent dilution is removed? |

The matrix file targets and all finding-level test dispositions above are usable now. They do not remove these seven blockers, and no owner answer has been invented for them.

# Limits

This is a source-only readiness assessment, not an implementation plan, security clearance, or claim that the proposed tests currently pass. I did not read peer responses, the coordinator draft, or other member files; did not edit the PRD, review file, audit files, or project code; and did not run tests, Forge, Git, installs, or sub-agents. Applicability conclusions derive from the finding mechanisms and locked PRD text, not new exploit execution.
