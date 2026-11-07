# Coordinator draft

## Draft identity

- Draft ID: draft-fs-failure-causes-20261105-r1
- Path: docs/research/fs-failure-causes-20261105/coordinator/draft.md
- Run ID: fs-failure-causes-20261105
- Status: pending advisory review. This file is not the final.
- Fingerprint: 26c3a0f02241d084d81ed8ccdc3953d49c5d720b21888b546041a953d1c05e7e
- Fingerprint source: `shasum -a 256` of this file before this fingerprint line was filled. The hash does not cover the filled fingerprint line.
- Sources: members/astra/response.md, members/grok/response.md, members/minimax/response.md, members/kimi/response.md, and the coordinator locator checks named below

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: astra, grok, minimax, kimi
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

## Question

What distinct causes produce the supplied IndexedEx full-spread test failures?

## Proposed text

The supplied failures are not one story. They reduce to one vault plan, five hook-side surfaces of that plan, and two dual-fixture causes that do not use the plan.

### 1. The one-sided face-to-share plan returns zero shares and refunds the whole input

Face-to-share preview and execution use `Planner.planIn` / `_mintOne` / `_size`. When `_size` rejects the candidate it sets the remainder to the whole input and adds no liquidity. `_shares` then returns without minting. Execution pays that remainder back. Coordinator check: `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:196-227` and `:230-232`.

This plan is the direct cause of:

- `test_oneSidedDepositThenExit` asserting `0 <= 0`
- AlreadyUnlocked `test_borrowedExchangeInMintsAndClearsDeltas` asserting `0 <= 0`
- Native `test_wethFaceDepositsAgainstNativeCurrency` asserting `0 <= 0`, with the limit below
- `SE quotes the face: 0 <= 0` on the constant-product, single-buffer, and BufferHookIntegration bind tests
- the partial-consumption failures, which assert a small residue and observe the whole input, or assert that a one-sided mint cannot fully consume

The borrowed-unlock context and the WETH face mapping are not separate zero-share causes. Native's supplied string does not say which of its `assertGt` calls failed. Grok and Kimi both leave that call unidentified. The one-sided call is the plan above. The bundle call was not traced.

The rejecting predicate inside `_size` is not agreed.

- Kimi evaluates the package and matrix formulas and gets a nonzero root whose floored gross-up then applies exactly `n - 1`, so the `quote.applied < n` exit rejects. Astra also treats a one-wei applied shortfall as the numerical trigger.
- MiniMax's hand evaluation says token0 leaves because gross exceeds the input, and token1 leaves because the root is zero.
- Grok cites the five reject exits and does not isolate which one fired.

Coordinator-supplied runtime, not a member observation: an earlier temporary revert on the single-buffer 1 ether face preview, since removed, returned `SizeReject(1, 99845250072044401495, 99845250072044401494, ...)`. Kind 1 was the `applied < n` exit, and the gap was one wei. That supports Kimi and Astra for that preview. It does not prove MiniMax's other exits never fire on another amount or direction. This draft adopts the zero plan as the cause and does not adopt one predicate as proved for every fixture.

### 2. Hook families surface that zero at different sites

These are not one `beforeSwap` wrap, and they are not five extra vault defects.

- Constant product, including BufferHookIntegration's inherited rows: the buffer treats a zero quote as "do not exchange". First mint then reverts `InsufficientLpOut` because the pair-side claim is zero. This is a deposit path, not `beforeSwap`.
- Single buffer: `beforeSwap` reads the zero wrap quote and reverts `MinAmountNotMet(1, 0)`. PoolManager wraps that as `HookCallFailed`.
- Balancer quad, Balancer quad 5, Curve quad, and two-leg weighted: first-mint inventory validation reverts `ZeroAmount` before buffering.
- Weighted N3: the weaker first-mint count check can pass, then the buffer commit reverts `BufferFailed` because the quote's minimum is zero.
- Orbital: the seed accepts a zero quote. A later face swap reverts `NotLive` because the effective reserve or `R` is zero. PoolManager wraps that as `HookCallFailed`. Which of those two liveness inputs was zero was not traced.

### 3. Dual `test_row_index1` exhausts a bounded address-side search

The helper tries one PairToken record and at most 32 named vaults, and reverts `no PairToken share on the requested side of the face` when none matches. `test_row_index1` requests the other side through `_configureDual(false)`. This runs before bind and before any full-spread preview. All four responses treat it as independent of the zero plan. Coordinator check: `_configureDual` calls that helper before `_bindDual` at `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:262-267`.

### 4. Dual composed gas reverts `allowance` on a stale route after a rejected bind

`_bindDual` records a rejected `processArgs`, sets `hook = address(0)`, and returns before deploying a replacement or approving the router. `test_composedRouteGasFitsCeiling` calls `_seed` and `_swapExactIn` without `_requireIdentity`. `_swapExactIn` swaps the current `poolKey` through `swapRouter`. The mintable token's `transferFrom` is the only cited source of the literal `allowance`. Coordinator check: `UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:280-299` and `:421-426`; `UniswapV4DualSEBCPHook_SeMatrixBehavior.sol:204-214`.

Astra, Grok, and Kimi adopt this stale-route reading. MiniMax found the `allowance` string in the ERC-20 stub and left the short spender unresolved. The exact unpaid pull was not traced. This draft adopts the stale route as the cause and keeps that unpaid-pull gap.

No response authorizes an implementation, a haircut, a search, or a code edit. This draft does not add one.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Which `_size` exit rejects the face-to-share plan | Kimi and Astra: floored gross-up makes `applied = n - 1`. MiniMax: token0 gross exceeds the input; token1 root is zero. Grok: exit not isolated. | The zero plan is adopted. One predicate for every fixture is not. |
| Dual `allowance` spender | Astra, Grok, and Kimi: stale base pool after rejected bind, gas test has no identity guard. MiniMax: stub `transferFrom`, spender not identified. | Stale route is adopted. The exact unpaid pull is not traced. |
| How many causes to count | Kimi: eight terminal causes, five of them surfaces of one vault cause. Grok: five, with hook surfaces under one cause letter. MiniMax: three independent causes and five hook sites. Astra: ten labeled paths, grouped as one numerical trigger plus consumer paths plus two dual causes. | The grouping above is the coordinator's comparison, not a vote. |

## Evidence gaps

- No member re-ran the suite. The failure strings are user-supplied runtime evidence.
- The one-wei `applied < n` measurement is coordinator-supplied runtime from a temporary revert that is no longer in the tree. It is not a member observation.
- Native's supplied `0 <= 0` does not identify which `assertGt` failed.
- Orbital `NotLive` was not traced to `R == 0` versus a zero effective reserve.
- Weighted N3 passing the first-mint count check was inferred from `BufferFailed` rather than `ZeroAmount`, not executed.
- The optional implementation plan and remediation PRD were not used as runtime evidence. Several members did not read them. No requirement is inferred from that absence.
- The source tree was live during the responses. Line numbers are as read by each member and as re-checked by the coordinator for the planner exits and the dual bind/gas path.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| Package `test_oneSidedDepositThenExit` | examined | all four | none on the zero share word |
| Constant-product matrix and BufferHookIntegration | examined | all four | none on `InsufficientLpOut` as a deposit surface |
| Single-buffer matrix | examined | all four | none on `MinAmountNotMet(1, 0)` |
| Orbital matrix | examined | all four | liveness input not traced |
| Balancer quad, Balancer quad 5, Curve quad, weighted | examined | all four | none on `ZeroAmount` as a first-mint surface |
| Weighted N3 | examined | all four | first-mint pass inferred |
| Dual `test_row_index1` | examined | all four | none |
| Dual composed gas | examined | all four | MiniMax does not adopt the stale route |
| AlreadyUnlocked | examined | all four | none on the zero share word |
| Native | examined | all four | which `assertGt` failed is not identified |
| Partial-consumption rows | examined | all four | same refund word, not a second sizer |

## Limits

- Static, extracted, supplied-runtime, and unverified claims stay distinguished.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
