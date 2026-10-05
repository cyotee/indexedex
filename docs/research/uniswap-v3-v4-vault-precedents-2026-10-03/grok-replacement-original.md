# Grok replacement original: V3/V4 vault precedents

**Date:** 2026-10-03. **Author:** fresh Grok (`xai/grok-4.7`), retained replacement session. Independent first pass for this search. No peer artifacts read. Not consensus. No implementation or gas claim. `main` is not a deployment pin. Basket-only is not an acceptable product substitute; it is the class most public vaults actually implement.

## 1. Result

No traced public vault is class A for both directions: an on-chain, search-free, autonomous single-token deposit and a matching single-token withdrawal against a live two-token concentrated book, without a caller-supplied swap, a keeper payload, or a same-pool spot mark.

The useful counterexamples are narrower:

- **Gamma Hypervisor** (commit `5191177`, Solidity 0.7.6, header `BUSL-1.1`) mints fungible shares for a one-sided deposit by marking token0 at the pool spot. Withdrawal pays both tokens. Rebalance swap size is owner-supplied.
- **ICHI vault** (verified-source excerpt, Celo `0x07fddb65…`) mints one-sided deposits using the more conservative of spot and TWAP, and can forbid one side. Withdrawal was not in the fetched excerpt.
- **Bunni v2** (`main`, MIT, Timeless Foundation 2025) values an initializing unbalanced deposit through a liquidity-density function, then mints later deposits at the inventory ratio and withdraws both tokens pro rata. No sizing loop in `deposit`.
- **Uniswap DualPool** (v4-hooks-public) and **Arrakis V1** separate share math from placement. Both are proportional. DualPool is the cleanest V4 statement that JIT ranges are not the share formula.

Failure to find class A is not a proof none exists.

## 2. Inventory

| # | Product | Chain math | Class | Sizing location | Scalar in / out |
|---|---|---|---|---|---|
| 1 | Gamma Hypervisor `5191177` | V3 | D deposit, C exit | On-chain spot. Owner `swapQuantity` on rebalance | Deposit yes. Withdraw both |
| 2 | ICHI vault, Celo verified excerpt | V3 | D deposit | On-chain min/max of spot and TWAP. No swap in `deposit` | Deposit yes if `allowToken*`. Withdraw not traced |
| 3 | Bunni v2 `BunniHubLogic` | V4 | C after init; LDF only at zero book | On-chain ratio or `queryLDF`. No probe loop | One token only if the other reserve is zero. Withdraw both |
| 4 | Uniswap DualPool / PoolVault | V4 | C | `previewDeposit` off-chain; pull is proportional | No |
| 5 | Arrakis V1 `ArrakisVaultV1.mint` | V3 | C | `getMintAmounts` / `_computeMintAmounts` | No. Burn both |
| 6 | Arrakis V2 `rebalance` | V3 | B for the swap; C for shares if mint matches V1 | Manager `swap.payload` to an allowlisted router | Not an autonomous scalar route |
| 7 | Range Protocol `RangeProtocolVault` | V3 | C user; B manager | `getMintAmounts`. Manager `swap(zeroForOne, swapAmount, …)` | No |
| 8 | Gamma UniProxy (current docs) | V3 | C wrapper | Caller must pass both quantities inside `getDepositAmount` band | Frontend single-token button is not class A |
| 9 | Popsicle V3 Optimizer interface | V3 | C | `deposit(amount0Desired, amount1Desired)` “in proportion to current ticks” | No |
| 10 | Steer periphery / `tend` | V3 ALM + ERC-4626 template | B | SDK computes both amounts. `tend(bytes)` is manager calldata | No |
| 11 | Revert `AutoRangeAndCompound` | V3 NFT | E / B | Operator supplies `amountIn`. Positions are NFTs, not fungible SE shares | No |
| 12 | Charm Alpha Pro | V3 | C, lines not re-pinned | Docs say proportional deposit, separate rebalance. Raw `AlphaProVault.sol` 404 this pass | No |
| 13 | Beefy CLM, DefiEdge, Aperture, Mellow, Sommelier | names only | Unclassified | Not traced. Do not treat marketing as class A | Unknown |

## 3. Deep trace: Gamma Hypervisor

Primary: `https://github.com/GammaStrategies/hypervisor/blob/519117704a67659273b78658ad43bcad8a8073ce/contracts/Hypervisor.sol`, fetched 2026-10-03. Header license `BUSL-1.1`. Do not copy source without a license review. This commit is not a claim about today’s UniProxy deployment.

`deposit(deposit0, deposit1, to, from)` allows either amount to be zero. It pokes both positions with `pool.burn(..., 0)`, reads `currentTick()`, and sets

```text
price = mulDiv(sqrtPrice^2, 1e36, 2^(96*2))
shares = deposit1 + deposit0 * price / 1e36
```

If supply is nonzero, it scales by `totalSupply / (pool0*price/1e36 + pool1)`, using `getTotalAmounts()` (local balances plus both position amounts plus tokens owed). It then mints liquidity into the existing base and limit ranges with `getLiquidityForAmounts` of whatever balances remain. No binary search. No swap on the user path.

`withdraw(shares, to, from)` burns `liquidity * shares / totalSupply` from each range and also sends the same fraction of unused balances. The user receives both tokens. That is not a scalar exit.

`rebalance(..., int256 swapQuantity)` is `onlyOwner`. A nonzero quantity is an exact-input pool swap to the min or max sqrt price. The owner chooses the amount. That is class B, and it is not a quote an Orbital hook can invent while unlocked.

Economic tradeoff: the deposit is the searched-for scalar admission, and it is same-pool spot NAV. A one-transaction spot move changes `price` and `getTotalAmounts()` together. There is no TWAP gate in this commit. Caps exist (`deposit0Max`, `deposit1Max`, `maxTotalSupply`) and can be unlimited. Immediate placement of the whole balance into base then limit can deploy the limiting token and leave the other local; the next deposit’s NAV includes that leftover. Fees are inside position `tokensOwed` after the poke, so they are in the share price, not a separate depositor claim.

V3 boundary: two ranges, NFT-less position key `keccak256(abi.encodePacked(address(this), tickLower, tickUpper))` with no salt. V4 needs salt and `modifyLiquidity` inside an unlock. The spot formula does not require V3 callbacks, but the mint callback does.

## 4. Deep trace: ICHI vault

Fetched excerpt from the verified Celo contract `0x07fddb65631529df92e87e536aa9aeec8ba1d020`, 2026-10-03. No GitHub line pin this pass. Treat line numbers as absent.

`deposit` requires `allowToken0 || deposit0 == 0` and the symmetric token1 check. It pokes base and limit positions, then:

```text
price = spot(currentTick)
twap = twap(pool, twapPeriod)
if |price-twap|/price > hysteresis: require(checkHysteresis())
depositValue = deposit1 + deposit0 * min(price, twap) / PRECISION
poolValue = pool1 + pool0 * max(price, twap) / PRECISION
shares = supply == 0 ? depositValue : depositValue * supply / poolValue
```

Deposit is marked cheap; the existing book is marked rich. That is a spread against the depositor, still inside the same pool’s spot and TWAP. It does not search a swap. It does not itself produce a one-token withdrawal. Angel Vault marketing describes buy-side ranges and later rebalance; that is keeper placement, not this function.

Reusable idea: a conservative mark plus a side allowlist. Not reusable as an independent oracle. The feed is the vault’s own pool. Hysteresis can reject, which is an availability cost. License of this bytecode was not fetched.

## 5. Deep trace: Bunni v2

Primary: `https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/src/lib/BunniHubLogic.sol` and `src/lib/QueryLDF.sol`, `main`, fetched 2026-10-03. License file is MIT, copyright 2025 Timeless Foundation. Solidity `^0.8.19` in the library; README says v4-core compiles at 0.8.26. Not a deployment pin. The August audit diff is an older share-mint shape; the fetched `main` is the authority for this note.

`deposit` reads hook `slot0s`, then `_depositLogic`. If both reserves are zero, it calls `queryLDF` with `amount0Desired` and `amount1Desired` as the balances. The LDF returns densities and the amounts that fit the shape. If rounding would exceed desired, it scales down and takes the min of each desired amount. That is closed form, not a probe. A one-token desired amount can initialize a one-sided shape only if the other added amount comes back zero.

If reserves already exist, it does not re-solve the LDF:

```text
amount0 = balance1 == 0 ? amount0Desired : min(amount0Desired, amount1Desired * balance0 / balance1)
amount1 = balance0 == 0 ? amount1Desired : min(amount1Desired, amount0Desired * balance1 / balance0)
```

Excess is not pulled. `_mintShares` then mints

```text
min(supply * added0 / existing0, supply * added1 / existing1)
```

with the zero-reserve leg ignored. First supply mints `WAD - MIN_INITIAL_SHARES` and locks `MIN_INITIAL_SHARES` at `address(0)`. Idle balance, if any, increases in proportion to the deposited side. Slippage is `amount0Min` / `amount1Min` on amounts actually added, which for a proportional deposit means “I was willing to add at least this much,” not a share minimum.

`withdraw` burns shares and pays `reserve * shares / supply + raw * shares / supply` of both tokens. Queued withdrawal is a delayed full exit when am-AMM is active, not a single-token conversion. `NeedToUseQueuedWithdrawal` is an availability break for a synchronous buffer.

`queryLDF` is the positive mechanism: total liquidity is `balance * Q96 / density` on the tighter side, and the other token’s active balance is capped by that liquidity. Idle token is removed from the active balance before the ratio. That prices an unbalanced inventory without a swap search, but only against the pool’s own LDF and tick, including an optional TWAP tick input. It does not pay the idle token out to a withdrawing shareholder as their only asset. Hook-owned liquidity also means a same-manager Orbital call cannot treat Bunni as a nested vault that unlocks again.

## 6. Deep trace: proportional cores

**Arrakis V1.** `https://github.com/ArrakisFinance/vault-v1-core/blob/main/contracts/ArrakisVaultV1.sol`, fetched via search 2026-10-03. `mint(mintAmount)` pulls `ceil(underlying_i * mintAmount / supply)` of both tokens. `getMintAmounts` returns the min of the two share ratios, or the single-leg ratio if the other underlying is zero. `burn` returns both. Manager `_deposit` may swap `balance * swapAmountBPS / 10000` at a caller-supplied price limit. User path does not search. `LICENSE` at `main` returned 404. Do not copy.

**Uniswap DualPool.** `https://github.com/Uniswap/v4-hooks-public/blob/main/src/alf/DualPoolHook.sol` and the LP-shares doc, fetched 2026-10-03. `bootstrap` mints `sqrt(received0 * received1)`. Later `addLiquidity(sharesToMint, maxAmount0, maxAmount1)` pulls amounts proportional to total assets, rounded up. `removeLiquidity` returns both, rounded down. Virtual shares use an EIP-4626 offset. JIT buckets are deployed from balances with `getLiquidityForAmounts` inside the hook’s own unlock. Share price is not the bucket liquidity. A same-block withdraw can be locked by `minDepositBlocks`. This is V4-native and still class C. It is the right architecture split, not a scalar route.

**Range Protocol.** `https://github.com/Range-Protocol/contracts/blob/master/contracts/RangeProtocolVault.sol`. Manager `swap` takes an exact `swapAmount`. Users mint against the current ratio, including when the position is inactive. Burn returns both, minus a managing fee. Class C plus class B keeper.

**Arrakis V2.** Sherlock tree `v2-core/contracts/ArrakisV2.sol`. `rebalance` is `onlyManager` and `router.call(payload)` after approving the vault’s balances. The manager, or its off-chain planner, chooses the swap. Private `restrictedMint` vaults are class E for a public buffer.

## 7. What this means for Hookless / Orbital

Exact-input scalar deposit exists in the wild only as a valuation rule: Gamma spot, ICHI spot/TWAP, or Bunni’s zero-book LDF. None of those withdrawals is a single token. Exact-output single-token redemption was not found as a closed form. Queued Bunni withdrawal and DualPool’s deposit lock are availability failures for a synchronous SY.

Already-unlocked local cover is not solved by any of these. They mint by pulling tokens and calling the pool or PoolManager. A hook already inside `unlock` cannot do that on the same manager. Wings in Gamma and ICHI are base/limit positions updated by the owner, not a user-path placement that prices shares.

Reusable math, not source:

- Separate admission from placement. DualPool and Bunni both do this. Bunni’s ongoing admission is the min share ratio after the tokens have been reduced to the inventory ratio. That is Arrakis `getMintAmounts`, not a zap.
- A density or other explicit quote can convert two balances into one liquidity number and leave the surplus idle. That is a candidate for valuing a one-sided wing plus a core without searching a swap. It still needs an exit rule. Bunni’s exit ignores that and pays both.
- ICHI’s depositor-adverse mark is a spread. It is not the 50 bp pool-impact constant. Copying the idea requires a new owner constant.
- Gamma shows the manipulation if the mark is spot and the exit is later at a different price, or even at the same spot after the attacker has moved it.

Not reusable as the autonomous call: UniProxy ratio bands, Steer SDK amounts, Arrakis router payloads, Range/Gamma/Revert manager swap amounts, Revert NFT transforms. Moving the search there fails the Orbital test.

`zapSplitWad` has no precedent here that deletes it. These vaults do not compose three legs. `_faceForClaim` is unnecessary only if the SE exposes a direct exact-share inverse. None of the traced exits is that inverse for one output token.

Pons stays separate. Hook fees and am-AMM pauses in Bunni are a V4 boundary V3 vaults do not have.

## 8. Licenses and gaps

| Source | License evidence | Gate |
|---|---|---|
| Bunni v2 `main` LICENSE | MIT, 2025 Timeless Foundation | Permissive, still review before any copy |
| Gamma Hypervisor `5191177` header | `BUSL-1.1` | Do not copy implementation |
| Revert `AutoRangeAndCompound` header | `BUSL-1.1` in the fetched file; compoundor repo search said MIT | Do not assume one license covers both |
| Arrakis V1 `LICENSE` | 404 | Unknown. No copy |
| ICHI Celo excerpt | No license file fetched | Unknown |
| DualPool | Uniswap repo; license file not fetched this pass | Unknown |
| Charm raw path | 404 | Docs not re-fetched. No line pin |

Also untraced: Beefy CLM, DefiEdge, Aperture, Mellow, Sommelier, current Gamma UniProxy Solidity, ICHI `withdraw`, Charm contract body. Markaicode’s “v4 single-sided hook” article is not a deployed vault. Panoptic and Angstrom were not traced; no vault money path was opened.

## 9. Human decision

Do not expect a drop-in class A vault. The closest public mechanisms are Gamma/ICHI scalar admission by a pool-derived mark, and Bunni’s density-capped idle inventory plus proportional shares. Both still need a designed single-token exit. Adopting either mark is an owner economic choice, not a discovered invariant that makes holders safe.

Next decision: authorize a design that pairs one of those admission marks with an explicit single-token exit, or keep searching the untraced names before choosing. Do not implement from this memo. No gas improvement is claimed.
