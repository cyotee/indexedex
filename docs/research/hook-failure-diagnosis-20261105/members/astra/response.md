# Hook failure diagnosis: Astra

## Identity

- Run ID: hook-failure-diagnosis-20261105
- Member label: astra
- Profile: research
- Phase: initial independent response
- Requested role: council-member
- Requested model and reasoning: `chatgpt-subscription/gpt-6-astra:high`
- Actual runtime role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no
- Owned path: `docs/research/hook-failure-diagnosis-20261105/members/astra/response.md`

## Question and targets

What shared paths explain the supplied Foundry failures, and what is the smallest fix direction without changing the live 49% one-sided fraction or making `asset()` a bind requirement?

The required targets are the supplied failure list, the shared hook leg library, the six named hook packages' bind validation, `Planner._size`, and `Math.sizeOneSided` / `_liquidityFittingOut`. Failing tests and their relevant fixtures and called hook functions provide supporting evidence. Optional implementation-plan section 3 and the family PRD were not examined; no additional requirement is inferred from them.

## Evidence

### Bind validation: membership and inventory were conflated

**Source observation.** `pairInVaultTokens` rejects zero/code-less candidates, makes an unguarded typed `vaultTokens()` call, and accepts only an exact listed address. `addPairSe` applies that predicate to `pair == se`. The separate `isWrapperShareInventory` predicate recognizes a self-share address with a different nonzero underlying, but its comment explicitly excludes it from bind admission. Thus recognizing wrapper inventory elsewhere does not rescue the membership check. Sources: `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:171-201`.

**Source observation.** The production rebasing wrapper advertises exactly its underlying in `vaultTokens()`, not its own share address. Its reserve query also distinguishes that underlying from other addresses. Source: `contracts/protocols/staking/rebasingVault/RebasingAwareVaultMetadataTarget.sol:28-38`.

**Source observation.** All six required packages use this same predicate. Their local error names explain why equivalent bindings produce different supplied errors:

| Package | Validation behavior and source |
| --- | --- |
| Single constant-product | `_validateArgs` calls membership before wrapper-decimal handling and reverts `TokenNotInVaultTokens` on false. `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol:390-415`. |
| Dual constant-product | Both legs pass through `_requireTokenInVaultTokens`; false becomes `TokenNotInVaultTokens`. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol:374-392`. |
| Orbital | Each nonzero SE must pass membership; false becomes `InvalidSE`, before token-decimal validation. `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol:390-410`. |
| Weighted | Wrapper-decimal handling exists, but each nonzero SE still reaches the membership-only helper and `InvalidSE`. `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol:402-451`. |
| Balancer quad | Wrapper-decimal handling exists; the subsequent SE validation calls the same helper and maps false to `InvalidSE`. `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg.sol:372-413`. |
| Curve quad | Wrapper-decimal handling likewise does not bypass membership; false becomes `InvalidSE`. `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol:377-423`. |

**Inference.** The wrapper-positive failures share a bind-admission cause, not independent rebase, reserve-credit, DETF, or AMM arithmetic failures. A self-share inventory leg is being required to appear in its own underlying-token list. The evidence above establishes the contradiction; the following test inputs establish its reach:

| Supplied failure group | Source observation connecting it to that cause |
| --- | --- |
| Single and dual APEX008 identity tests | The single changes `pairToken` to `seUT` and deploys before testing credit; the dual sets both token/SE pairs equal before deployment. `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_RebasingAwareERC4626.t.sol:30-45`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_RebasingAwareERC4626.t.sol:34-53`. Their later credit assertions are not the reported failure point. |
| CP F16 tests | The acceptance test calls `processArgs` with `_wrapperArgs`, which sets both `standardExchange` and `pairToken` to the wrapper. `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Buffers.t.sol:57-64,298-306`. |
| Buffer invariant setup | Setup calls `_deployWrapperHook`; that helper binds the wrapper to itself before deployment. `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_BufferInvariant.t.sol:157-170,265-273`. |
| Dual F16 tests | The acceptance cases bind one or both wrappers as their own token. `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Buffers_Dual.t.sol:40-55,207-210`. |
| Orbital F16 tests | `_wrapperLeg0Args` assigns both token0 and se0 to the wrapper. `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Buffers_Orbital.t.sol:39-46,219-223`. |
| Weighted F16 tests | The sorted wrapper entry receives that same wrapper as its SE. `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Buffers_Weighted.t.sol:40-54,240-258`. |
| Balancer and Curve F16 tests | Both mixed-argument builders assign the wrapper token its own address as SE. `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Buffers_Balancer.t.sol:214-231`; `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Buffers_Curve.t.sol:214-226`. |
| CP DETF and DETF invariant | The CP composition creates `standardExchange = pairToken = w`; the invariant setup invokes that composition helper before its handler exercise. `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Buffers_Detf.t.sol:50-69`; `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_DetfInvariant.t.sol:141-153`. |
| Weighted DETF | The wrapper-token entry receives `ses[i] = address(w)` before weighted-hook deployment. `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Buffers_Detf.t.sol:180-215`. |
| Both Wings dual consumers | Both request `Amm.Family.Dual`. That fixture deploys a rebasing-wrapper identity output and binds `standardExchange1 = token1 = output`. The suspect leg is the auxiliary wrapper, not evidence that Wings must expose a different `asset()`. `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/ApexRecurrenceConsumerConservation.t.sol:32-40,90-94`; `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultFamilyConsumers.t.sol:32-40,81-85`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadSameManagerAmmFixture.sol:109-125,186-202`. |

### Empty reverts: the membership probe can fail before the intended error

**Source observation.** The library overlap-positive test constructs `SimpleYieldERC4626` and calls `addPairSe(wrapper, wrapper)`. That stub has an `asset()` implementation; the inspected stub body has no `vaultTokens()` implementation. The library now calls `vaultTokens()` before it can return its own overlap error. Sources: `test/foundry/spec/hooks/uniswap/v4/interfaces/UniswapV4SeBufferHookLegLib.t.sol:123-133`; `contracts/test/stubs/SimpleYieldERC4626.sol:17-204`, particularly `94-96`; `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:172-178,196-201`.

**Source observation.** The four ordinary-overlap negative tests replace an SE address with the ordinary token itself and expect `InvalidSE`. They do not merely expect any revert. Sources: `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Buffers_Balancer.t.sol:58-68`; `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Buffers_Curve.t.sol:58-68`; `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Buffers_Orbital.t.sol:49-58`; `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Buffers_Weighted.t.sol:57-67`.

**Inference.** A failed/missing `vaultTokens()` call propagates from the predicate rather than returning false, so the package never executes its `InvalidSE` branch. This explains the empty-data mismatch separately from the valid-wrapper membership false result. It also explains why merely adding a wrapper-positive alternative does not, by itself, repair the negative-error cases. Sources: `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:172-178`; the six-package table above; supplied errors at `docs/research/hook-failure-diagnosis-20261105/brief.md:88-100`.

**Source observation.** The bare-protocol-vault control has a different stale premise: it substitutes `pairProtocolVault` as the SE, expects deployment and registration to succeed, and arms its empty-revert expectation only immediately before `deposit`. The current single-CP package already probes membership during validation. Sources: `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_SimpleYieldERC4626Control.t.sol:31-50`; `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol:290-293,399-400`.

**Inference.** That control fails before its intended first-buffer rejection. Preserve its rejection purpose, but update it to the current bind boundary and a deliberate package error. Do not admit arbitrary bare ERC4626s as converting SEs just to preserve an obsolete failure stage. This conclusion follows from the validation/test ordering cited immediately above.

### Index-one failures: the fixture flag does not select the sibling token address

**Source observation.** `FullSpreadV4MatrixSibling.load` always calls `deploySibling("Full spread sibling")`. It stores `sideMatched` by comparing the primary face with the sibling **share**, but never uses that boolean to select or reject a sibling. `pair()` checks sorted/disjoint faces and backing keys, not the requested side. The fixture's `deploySibling` creates two ordinary tokens and sorts them only against each other. Sources: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:42-52,108-118`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:197-205`.

**Source observation.** Dual uses `pairRecord.p0()` as `other`, but `test_row_index1` then requires `face > other`. Orbital also uses `p0()` as `face1`, while only its separately created raw `face2` is side-selected; its index-one test requires the primary face to exceed both. These address assertions occur before the direction exercises. Sources: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:232-238,307-311`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:56-64,159-166`.

**Inference.** Passing `false` after reverting the snapshot does not construct the requested sibling-face ordering. The source explains an address-order failure independently of the 49% sizer. The brief labels the supplied failures `assertLe`, whereas the relevant source assertions are `assertGt(uint160(...), uint160(...))`; without a trace I do not claim to have reconciled that diagnostic label. The supplied operand relation is consistent with the requested greater-than ordering not being achieved. Sources: the two row locators above; `docs/research/hook-failure-diagnosis-20261105/brief.md:107-108`.

### Partial consumption: 49% does not promise a sub-1% refund

**Source observation.** In the active in-range branch, `_size` requests `floor(amount * 49 / 100)`, quotes that swap, and sizes liquidity from the quote's actual spent/output amounts. `sizeOneSided` returns `amount - swapIn - needIn` as the successful remainder. It neither solves for a dust-sized input remainder nor enforces a 1% limit. Sources: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:199-220`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol:60-77`.

**Source observation.** The single-hook row previews up to eight times, subtracting the previously quoted remainder from the next proposed amount without executing a state-changing swap, then demands `refund < amount / 100`. Its subsequent assertion checks that execution leaves exactly the quoted refund with the hook. Source: `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:76-87`.

**Inference.** A fixed fractional swap can leave a proportional input remainder rather than rounding dust; rescaling the preview amount does not make that proportion disappear. The supplied nonzero partial refund is therefore not evidence that 49% was ignored. The failed sub-1% assumption should be replaced by assertions of positive mint output, strict partial consumption, tuple parity, and exact refund ownership/conservation, not by changing 49% or increasing an arbitrary percentage tolerance. Sources: the planner, math, and row locators immediately above; supplied failure at `docs/research/hook-failure-diagnosis-20261105/brief.md:109`.

**Source observation.** The required numeric guards are separate: `_size` returns the whole input when the fractional input is zero or exceeds `int256.max`; `_liquidityFittingOut` returns zero for zero/equal-bound cases or a result outside nonzero `uint128`; `sizeOneSided` then returns the whole input, and also does so when the output cannot be consumed exactly or the remaining input is insufficient. Sources: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:202-220`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol:56-77,80-98`.

**Inference.** The supplied single-row failure is a partial remainder, not the whole-input result of those guards. Nothing supplied establishes a numeric-cap failure in the index-order or sibling-supply rows. Retain these guards; this diagnosis does not support a sizer production change. Sources: the guard locators above and `docs/research/hook-failure-diagnosis-20261105/brief.md:107-110`.

### Sibling-supply failures: converting face legs still carry rejected/raw-leg assertions

**Source observation.** The three rows insert the sibling's `p0()` underlying token and bind it to `pairRecord.share()` with a provider. They are not binding a share token to itself. The setup marks this as accepted when `processArgs` succeeds:

| Row | Actual converting leg and accepted-bind branch |
| --- | --- |
| Balancer five-leg | `legTokens.push(pairRecord.p0())`, then `legSes = pairRecord.share()` for that entry. `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:65-79,105-110,129-145`. |
| Curve quad | `rowTokens` contains `p0()`, with `rowSes[i] = pairRecord.share()`. `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:62-75,84-110`. |
| Weighted N3 | `rowTokens` contains `p0()`, with `rowSes` assigning the sibling share address. `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol:61-74,83-108`. |

**Source observation.** In all three production `_bufferToken` implementations, zero SE means raw handling, `se == token` means identity handling, and a distinct nonzero SE means previewing and calling `exchangeIn(token, amount, se, ...)`. Sources: `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol:545-561`; `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol:692-707`; `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:525-539`.

**Source observation.** Despite that accepted conversion topology, each seed snapshots sibling share supply, performs a proportional join with 100 ether per leg, and unconditionally asserts `"rejected sibling supply unchanged"`. Sources: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:163-171`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:127-134`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol:123-130`.

**Inference.** The shared failure is a stale no-conversion expectation applied to a real converting sibling-face leg. Successful face-to-share intake can increase sibling supply; enforcing zero change would contradict that topology. The full-spread planner calculates mint shares from added liquidity rather than preserving supply during a mint. Sources: the row and buffering locators above; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:224-239`.

**Source observation and qualification.** The same assertion text also appears in later direction helpers, so the brief alone does not identify which occurrence failed. Critically, the seed assertions above precede the direction helpers' zero-call expectations; the five-leg identity test explicitly seeds before arming its own expectations. Weighted N3 additionally arms its direction-level zero-call checks against `pairRecord.p0()`, not the sibling SE/share address. Sources: `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol:30-43`; its parent row `:174-201`; Curve row `:137-162`; weighted N3 row `:133-158`, using the full paths in the preceding tables.

**Inference.** Reaching a supply assertion is not evidence of a hidden conversion that bypassed an already-valid zero-call watch. An earlier seed assertion can fail before those watches are armed, and N3's wrong target would not observe calls to the sibling vault anyway. The supplied results do not justify a selector-bypass or unexpected-mint mechanism. Sources: the sequencing/target locators immediately above and `docs/research/hook-failure-diagnosis-20261105/brief.md:110`.

## Assumptions

- The supplied runtime results correspond closely enough to the live source to support static diagnosis. They were not independently reproduced.
- “Restore” means restore correct positive/negative behavior and meaningful assertions, not preserve assertions whose setup no longer tests what their names claim.
- An optional wrapper-inventory recognition path must remain distinct from the general membership path. This is not permission to require `asset()` on asset-free SEs or to require `asset() == pair`.

## Coverage

| Required target | Status | Scope examined |
| --- | --- | --- |
| Failure list in `docs/research/hook-failure-diagnosis-20261105/brief.md` | examined | Both clusters, supplied errors, constraints, and response rules. |
| `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol` | examined | Shared membership, inventory recognition, overlap admission, and surrounding library context. |
| Dual package bind checks | examined | `processArgs` dispatch and both-leg validation; exact path and lines in the package evidence table. |
| Single constant-product package bind checks | examined | `processArgs`, membership gate, provider and decimal checks; exact path and lines in the package evidence table. |
| Orbital package bind checks | examined | Nonzero-SE membership and validation ordering; exact path and lines in the package evidence table. |
| Weighted package bind checks | examined | Wrapper decimals, nonzero-SE membership, and error mapping; exact path and lines in the package evidence table. |
| Balancer quad package bind checks | examined | Wrapper decimals, nonzero-SE membership, and error mapping; exact path and lines in the package evidence table. |
| Curve quad package bind checks | examined | Wrapper decimals, nonzero-SE membership, and error mapping; exact path and lines in the package evidence table. |
| Full-spread `Planner._size` | examined | Fixed fraction, quote inputs, boundary/active-liquidity branches, and whole-input returns. |
| Full-spread `Math.sizeOneSided` and `_liquidityFittingOut` | examined | Exact-output fit, input sufficiency, remainder formula, and width checks. |
| Named failing tests and reachable supporting code | partially examined | Relevant argument builders, bind calls, setup paths, failed assertions, sibling construction, and buffering functions cited above; not every test body or downstream route. |
| Optional implementation-plan section 3 and family PRD FS-OWN-33 lock | not examined | Not needed to establish these source-level causes; the live fraction is preserved by the assignment. |

## Conclusions

The smallest fix direction is a shared bind correction plus focused test/fixture corrections, not a change to the live 49% sizing fraction.

1. **Separate converting membership from wrapper-share inventory acceptance.** Keep `pair in se.vaultTokens()` sufficient without requiring `asset()`. Add the existing recognized self-wrapper inventory case as an alternative for the shared admission used by the packages and `addPairSe`, rather than requiring the wrapper share to be an underlying token. The optional wrapper recognition must not become a prerequisite for ordinary membership binds. Preserve ordinary-overlap rejection, duplicate/cross-set exclusions, and the existing family decimal checks. This is advice grounded in the distinction already present in `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:171-217` and the six package gates cited above; it does not propose changing a vault's advertised underlyings.

2. **Make an unsupported membership query a false admission result.** Handle a missing/reverting `vaultTokens()` at the shared probe boundary so the caller emits its intended `InvalidSE`, `TokenNotInVaultTokens`, or `PairSeOverlap`. Ensure the valid wrapper alternative is not preceded by an uncaught call that defeats it. Keep the ordinary-overlap negative tests strict. Update the bare-vault control to assert rejection at bind rather than expecting deployment to succeed. Basis: `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:172-178,196-201`; the ordinary-overlap test locators above; `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_SimpleYieldERC4626Control.t.sol:38-50`.

3. **Construct the address order the index rows claim to exercise.** Select/deploy sibling underlying tokens relative to the primary face before initializing that sibling market. Assert the order against the actual `p0()` counter leg, not the share address. Keep both index assertions; do not skip the failing index-one route or merely invert its comparison. Basis: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:42-50,232-238,307-311`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:197-205`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:56-64,159-166`.

4. **Test the actual fixed-fraction refund contract.** Replace the single row's iterative dust assumption with a deterministic input, positive output, `0 < refund < input` for this partial case, preview/execution tuple equality, and exact hook/caller balance conservation. Keep `49/100`, the exact-output-consumption requirement, and numeric guards unchanged. Basis: `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:76-87`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:199-220`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMath.sol:60-98`.

5. **Align the sibling rows with their accepted converting bindings.** Preserve the real `p0 -> sibling SE` topology, but assert quoted mint/burn effects and inventory conservation instead of unconditional supply constancy and no conversion calls. Keep forbidden-route checks where they actually apply, and target the sibling SE for conversion observations. Any distinct rejected/raw-leg control must explicitly establish that nonconverting topology before asserting unchanged supply; do not label the current accepted conversion row as that control. Basis: the three topology, seed, and buffering tables above; weighted N3's mismatched watch target at `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol:138-158`.

The supplied failures do not require changing rebase accounting, pretransfer-credit protection, Wings reserves, or the full-spread sizing algorithm to explain their first observed failures. This is a static attribution to the earlier gates and assertions documented above, not proof that every downstream test will pass after those corrections.

## Limits

- No tests, builds, installs, Git operations, deployment, implementation, or sub-agents were run.
- Runtime evidence is supplied evidence from `docs/research/hook-failure-diagnosis-20261105/brief.md:86-110`. No execution trace was supplied or reproduced; exact failure-stack locations remain unverified.
- Source observations were read from a shared live workspace, not an immutable snapshot. No historical edit chronology is asserted.
- Public web/documentation queries: not used. Private source was not sent to a public query service.
- No peer response was read. This is an independent contribution, not council consensus.
- This response does not authorize implementation or replace an owner decision. Only the owned response file is written. Inherited permissions do not establish filesystem confinement.
