# Grok replacement cross-review — V3/V4 vault precedents

**Date:** 2026-10-03. **Author:** fresh Grok (`xai/grok-4.7`), retained replacement session. Peer-informed review of the three other originals. Not continuity with the replaced Grok, not consensus, and not a proof that no solution exists. No implementation or gas claim.

## 1. Corrections to my original

I traced Gamma at commit `5191177`, where `whitelisted` starts false and `deposit` is a public spot-NAV mint. That is not the current public path. Consensys Diligence (2022-02) records that open `deposit` as a critical spot-manipulation hole, later restricted to `whitelistedAddress`. Astra and Kimi are right about the later gate. My class-D reading applies to that old commit only.

I also missed Aperture. It is the strongest no-binary-search lead and still not a fungible scalar vault. I understated Charm: `AlphaStrategy.rebalance` calls `vault.rebalance(0, 0, ...)` after an on-chain TWAP check. That zero-swap strategy is verified this pass.

## 2. Aperture — analytic, then a discovery walk

Fetched `https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/main/src/libraries/OptimalSwap.sol` on 2026-10-03. Header is `SPDX-License-Identifier: BUSL-1.1`, not MIT. MiniMax’s MIT claim is false for this file. Astra’s separate LICENSE claim (GPL-2.0-or-later after 2026-07-01) was not re-fetched here; do not treat the file SPDX as the whole-repo license.

`getOptimalSwap` solves one NFT range’s desired amounts, not a vault book with incumbent `F`, `E`, share supply, or a second position. `solveOptimalZeroForOne` is a quadratic on the last constant-liquidity segment. Before that, `crossTicks` is `do { ... } while (true)`: it walks initialized ticks and simulated swap steps until the optimal direction flips or the input cannot reach the next tick. That is sizing discovery of the terminal segment. It is not binary search over amounts, and it is not traversal of an already-sized swap.

So: no binary search, yes discovery, not class A. An owner who accepts only “no binary search” can study the terminal solver. Strict no-discovery still requires a certified single segment and a revert if the walk would continue. Wrapping the NFT in ERC-20 does not price Hookless shares. The library’s gas sentence is a comment, not a measurement.

## 3. Beefy — docs overclaim the source

Fetched audit snapshot `BeefyVaultConcLiq.sol` at `42ef5f0eac1bc954e888cf5bfb85cbf24c08ec76`, 2026-10-03. Header MIT, Solidity 0.8.23. This is not proof of later deployed bytecode.

`_getTokensRequired` accepts the scarce side up to the value deficit. If the deposited token is already the heavy side, the function pulls the other token or shrinks the deposit. It does not mint an arbitrary one-token deposit against a two-sided book. MiniMax’s class A, and the docs sentence that a one-token deposit “swaps freely” into the other asset, do not match this function. Astra’s deficit-only reading does.

`withdraw` pays both tokens pro rata. No scalar exit. The vault source I read has no imbalance-swap fee. Later CLM docs must not be merged into this snapshot. Main-plus-alt placement is real and, on the Velodrome strategy excerpt, uses `getLiquidityForAmounts` twice with no swap. That is a wing precedent, not admission.

## 4. ICHI — do not merge products

ICHI **oneToken** is a collateral mint/redeem with `MintMaster` and oracles. It is not a Uniswap V3 LP-share vault. MiniMax’s class-D row mixes that product with YieldIQ and Chainlink `execute()`.

ICHI **vault** is the CL product: `allowToken0` / `allowToken1`, base and limit positions, and a spot-versus-TWAP hysteresis check. Kimi and Astra classify that correctly as gated scalar entry. The exact mint arithmetic was not closed by Kimi and was not in my Celo excerpt’s full function. Do not quote a formula that was not captured. SDK evidence says withdrawal returns both tokens. That is not scalar exit. Blueberry issues are about an external lending oracle on `getTotalAmounts`, not a proof that the vault mint itself was exploited. Use them as manipulation evidence, not as an incident history of the vault.

## 5. Gamma, Arrakis, Charm, Bunni, DualPool

**Gamma.** Old commit: public spot NAV, both-token withdrawal, owner `swapQuantity`. Later path: only a whitelisted caller, and UniProxy/Clearing normally requires both legs. A privileged bypass is not a public autonomous route. Kimi’s claim that current `rebalance` is swap-free was not re-verified against master this turn; the old commit’s `rebalance` does swap if `swapQuantity != 0`. License on the old file is `BUSL-1.1`. MiniMax’s MIT “per docs” is not source evidence.

**Arrakis.** V1 user mint is proportional. V2 `rebalance` executes manager `router.call(payload)`. A periphery `calculateSwapAmount` can be direct arithmetic at a supplied price. Execution still takes `swapData.amountInSwap`. That is class B at execution, not an autonomous post-swap alignment. Refund of unused input is a different residual law from exact-in full credit.

**Charm.** `AlphaStrategy.sol` on `main`, Unlicense, 0.7.6, fetched this pass. `rebalance` is keeper-only, checks TWAP deviation, and passes swap amounts `0, 0`. Base and limit ranges are computed on-chain. This is the cleanest zero-swap wing manager. It does not admit a scalar deposit. Alpha Pro was not re-traced.

**Bunni v2 / DualPool.** After a two-leg book exists, both pull a proportional basket and withdraw both tokens. Bunni’s LDF path is the zero-book initializer, not ongoing scalar entry. Both call `poolManager.unlock`. They are not a nested-unlock sleeve. MiniMax’s class A for Bunni withdraw is a category error: pro-rata two-token exit is class C. V3 position identity is `(owner, tickLower, tickUpper)`. V4 adds `salt`. MiniMax’s claim that V3 keys include salt is wrong.

## 6. Agreements and dissent

**Agree with Astra** on the binary-search versus discovery split, Beefy’s deficit domain, Gamma’s whitelist, Charm’s zero swap, and Arrakis’s split-versus-payload distinction. **Dissent** only where the Aperture quadratic is treated as close to Hookless whole-book sizing. It is one-range NFT math.

**Agree with Kimi** that production scalar exits are proportional and then, if a single token is wanted, a sized swap of the other entitlement. ICHI hysteresis is a gate, not a mint formula. Wings are standard placement. **Dissent** that entry has exactly two families. The traced set also includes Beefy’s deficit rule, Arrakis’s fixed-price split, and Aperture’s segment solver. Internal CP still has no CL-manager example. That is coverage, not impossibility.

**Agree with MiniMax** that a core plus one-sided alt exists in production and that Aperture is not binary search. **Dissent** on class A, MIT, arbitrary single-token admission, ICHI/oneToken identity, Gamma MIT, Arrakis GPL without a fetched LICENSE, and V3 salt.

## 7. Ranked reusable shortlist

1. **Charm/Beefy swap-free base-then-limit placement.** Satisfies no discovery for placement only. Does not price shares.
2. **Aperture terminal quadratic, domain-restricted.** Satisfies no binary search. Fails strict no-discovery unless the tick walk is rejected. Does not value an incumbent book and cannot run while the same manager is unlocked.
3. **ICHI vault hysteresis.** An on-chain spot/TWAP gate for scalar entry. Not an exit. Formula still unpinned.
4. **Arrakis arithmetic split plus refund.** A residual policy, not alignment. Execution payload is not autonomous.
5. **DualPool virtual-offset, share-denominated pull.** V4 accounting. Still a basket.

Nothing here replaces `_faceForClaim` with a one-token inverse, deletes `zapSplitWad`, or pays a scalar withdrawal from local cover while unlocked.

## 8. What is still required

An owner-chosen admission rule: internal CP, a gated mark, or a certified one-segment solver. A matching single-token exit, or an explicit acceptance that exit is pro-rata plus one already-sized swap. Local-cover behavior while unlocked. A decision on whether tick-segment discovery counts as a forbidden search. License review before any copy: Aperture file is BUSL-1.1; Gamma file is BUSL-1.1; Charm strategy is Unlicense; Beefy vault file is MIT; Arrakis V1 LICENSE was 404 in my prior pass.

**Stop. This review does not authorize implementation.**
