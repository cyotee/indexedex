# Grok original: fee-earning Uniswap V4 vaults with single-token entry and exit

Access date: 2026-10-29. Independent Grok council researcher. Research only. No implementation. No peer responses, drafts, or other member files were read.

## Write path

`apply_patch` is not in this session's tool set. A catalog search for a file-patch tool returned no such tool. This file was saved with the session write tool. That is a write-path disclosure, not a source. No evidence was invented to work around it.

## How to read claims

- **Observed:** text returned by a fetch of the named public URL on 2026-10-29.
- **Inferred:** a conclusion drawn from observed text. Not a second source.
- **Unverified:** a lead that was not confirmed by a primary fetch this session. `web_search` on this session returns a synthesized answer, not raw snippets. Those answers were used only to choose URLs. They are not observed facts, even when they name a function or an address.

No project tests, shell, Git, installs, deploys, wallets, config edits, or external messages were run. Explorer bytecode was not independently read: the Robinhood and Base Blockscout address APIs tried below returned no body.

## Result in one paragraph

No design was confirmed, from source plus an independent explorer read, as a vault that both holds a standing fee-earning Uniswap V4 position and natively processes arbitrary single-token deposit and arbitrary single-token withdrawal. One design has both directions in published source, and only as an external zap into either pool token, not an arbitrary third asset on exit: lpTOKEN plus `ZapRouter`. Weir's own docs claim a native both-directions full-range share vault; the contract source and explorer body were not obtained, so that claim stays unverified. Twofold, Bunni v2, and Gamma are useful near matches with a missing direction or a missing V4 function read. Several familiar names are exclusions or unresolved leads. Count was not filled with fabricated matches.

## Candidate table

| Design | Class | V4 position | Shares | Single-token in | Single-token out | What was actually read |
| --- | --- | --- | --- | --- | --- | --- |
| lpTOKEN vault + `ZapRouter` (Steemhunt) | Conditional match | One vault-owned position per pool. Native entry and exit are both legs. | ERC-20 pro-rata claim | External zap, either pool token, or native/canonical stable routed to the counter | External zap to either pool token only | Vault interface, `ZapRouter.sol`, README |
| Weir vaults | Unverified docs claim | Docs say one full-range position | Docs say shares | Docs say either token, swap half in the same tx | Docs say either token or both | Docs page only. Source not fetched |
| Twofold + `PoolZapper` | Near match | JIT. Docs say no V4 liquidity between trades | Hook shares; zapper ERC-1155 ledger | Observed `zapInETH` / `zapInUSDG` | Observed `zapOut` pays both legs | Docs, repo README, `PoolZapper.sol` |
| Bunni v2 `BunniHub` | Near match | V4 pool liquidity accounted as shares; idle may sit in ERC-4626 | `BunniToken` ERC-20 | Interface takes `amount0Desired` and `amount1Desired`. No zap in the fetched interface | `withdraw` returns `amount0` and `amount1` | README and `IBunniHub.sol`. Exploit postmortem TLS-failed |
| Gamma LP vaults | Near match, not both directions | Intro names V4 among venues. Deposit/withdraw guide is a V3 example | LP tokens | Guide: single-sided deposits are not available | Guide returns both tokens | Intro, deposit guide, withdraw guide, V4 shape page |
| ICHI | Not established as V4, and exit is not shown as one token | Fetched pages do not name Uniswap V4 | LP tokens | Docs claim a single-token deposit into a single-sided pool | Docs say withdraw "the corresponding assets" (plural) | What-is, how-it-works, FAQ, AMM page |
| EulerSwap | Exclusion | Official README: pools do not hold reserves. JIT borrow from Euler credit vaults | Not a shared LP share vault | A swap, not a vault deposit | A swap, not a vault redeem | Official README |
| Arrakis Pro (current docs) | Exclusion as a public share vault | Issuer-owned NFT vault. Optional V4 hook/module | Vault NFT, not public fungible shares | Not documented as public single-token share entry | Owner controls withdraw. Not a public single-token redeem | Current Arrakis Pro overview |
| Beefy CLM | Not a V4 finding | Page last updated August 2024. Does not name Uniswap V4 | cow / reward-cow / moo token | ZAP single-asset deposit documented for CLM generally | ZAP withdraw to a chosen token documented generally | CLM docs page |
| Prism (`ozpool/prism`) | Source-only, incomplete | Planned V4 vault. Not a working product | Planned ERC-20 | Not specified as single-token | Planned proportional withdraw. M1 not the current status | README. Status M0 in progress |
| Revert `v4lend` | Exclusion | V4 LP NFT is collateral | ERC-4626 of the lend asset | Single-asset lending deposit | Single-asset lending redeem | README |
| VII yield-harvesting hook | Exclusion | Hook donates wrapper interest into a V4 pool. LP is a position, not this vault | Position, not a share vault of a held V4 LP position | Deposit into an external ERC-4626, wrap, then add both wrapped tokens | Not an LP-share redeem | README |
| OpenZaps | Exclusion | Uses V4 pools as swap hops | Not an LP vault | Can compose a one-token route | Can settle one token | Product page |
| Steer | Unresolved lead | Homepage mentions V4 hooks and an ERC-4626 architecture | Not read | Not read | Not read | Homepage only. Hook doc path 404 |
| Kerf, Blackhole, Grimoire, Aperture, Charm, Krystal, Mellow, Decay, Hydrex, Angstrom, Doppler | Unverified or failed fetch | Not established | Not established | Not established | Not established | See rejected leads |

## 1. lpTOKEN + ZapRouter — conditional match

Family: one code family. `LpTokenVault`, `ZapRouter`, and `ZapRouterArc` are not independent designs. Arc is the same vault with a shared-USDC router. Launch ladders/positions are a separate locked inventory, not the qualifying path.

### What was read

- README: `https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/README.md`
- Interface: `https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/interfaces/ILpTokenVault.sol`
- Router: `https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/periphery/ZapRouter.sol`
- Tree: `https://api.github.com/repos/Steemhunt/lptoken-contracts/git/trees/main?recursive=1` (response `truncated: false`; tree sha `0ef829fe0c1097b810241aede0b18fc5c5c4a4b7`)

`LpTokenVault.sol` itself was not line-read. Behavior below that is not in the interface or the router is a README claim, labeled as such.

### Custody, shares, fees

Observed interface:

- `mintPair(maxTarget, maxCounter, minShares, receiver, deadline)` returns shares and amounts used.
- `redeem(shares, minTarget, minCounter, receiver, deadline)` returns `targetOut` and `counterOut`.
- `compound(minLiquidityAdded, deadline)`.
- `totalAssets()` returns target and counter assets. `pendingFees()` and `pendingLaunchFees()` return both currencies. `claimForShares` is the gross pro-rata claim before the redeem share fee. `previewRedeem` is after that fee.

Observed README:

- One immutable clone per pool. The vault owns one position ("salt-0") in that pool. Share price is a pro-rata claim on the position plus accrued fees, launch-fee NAV, and idle balances. README says there is no oracle, USD numeraire, or pool-wide reserve assumption.
- `compound` is permissionless and swapless. The cap uses the pool fee, a 50% safety factor, and protocol-owned liquidity counted only while in range. Successful calls start a 10-minute cooldown.
- Mint/redeem charge 30 bps in backed shares. README says bootstrap and ERC-20 transfers are free.
- Range comes from `VaultRange`, derived from each leg's supply, and stops short of the usable-tick boundary. That is not a full-range position by construction. Inferred: an out-of-range vault position does not earn swap fees until price returns; the README's in-range limit on the compound base is consistent with that, but the fee-accrual rule inside `LpTokenVault.sol` was not line-read.
- Idle balances are inside the claim. README says forced ETH and direct donations accrue to existing holders and cannot mint shares.

Trading-fee exposure of the invested position is the point of `compound` and `pendingFees`. Idle balances are in the claim but are not themselves a V4 position. Launch-fee NAV is a claim on a separate locked launch position, not on the vault's own active liquidity.

### Single-token deposit — external, verified

Native vault deposit is both legs. Single-token entry is `ZapRouter`, checked against `factory.isVault`.

Observed functions:

- `zapIn`: pull the vault counter, swap a caller-chosen portion to target through the vault pool, then `mintPair`. NatSpec says the client computes the split. The function does not assume a 50% raw-unit split.
- `zapInTarget`: same from the target leg. Requires a non-zero swap that is strictly less than the input.
- `zapInRouted`: only native currency or the configured canonical stable, through at most `MAX_ROUTE_HOPS = 3` client-selected hookless static-fee V4 pools, full spend per hop, then the counter zap. Hooked pools and dynamic-fee pools revert. Native and wrapped native are interchangeable at route boundaries.
- Unused mint input is returned to the caller. The router checks its own balances back to the pre-call baseline.
- Permit variants exist. Deadlines and `minShares` are required (`minShares == 0` reverts).

Inferred limits: "single-token in" means either pool token, or, on the routed path only, native or the canonical stable. It is not an arbitrary third token. The swap that builds the other leg hits the vault's own pool on the direct paths, so the depositor trades against the liquidity the vault and other LPs supply. The only price guard observed is the caller's minimum output and minimum shares. Router NatSpec says it does not discover route quality, establish fair value, or provide MEV protection.

### Single-token withdrawal — external, verified, either pool token

Observed:

- `zapOut` transfers the shares in, calls `vault.redeem`, then swaps the entire target leg into the counter through the vault pool. Partial exact-input fill reverts. Output is one currency: the counter. Caller passes `minCounterOut`.
- `zapOutTarget` does the symmetric conversion of the entire counter leg into the target.
- No routed zap-out was present in the fetched `ZapRouter.sol`. Exit is not to an arbitrary third asset.

The swap uses `sqrtPriceLimitX96` at `TickMath.MIN_SQRT_PRICE + 1` or `MAX_SQRT_PRICE - 1`. Inferred: a low caller minimum can fill at a very bad price. The router does not add an oracle or a TWAP. A withdrawal large relative to pool depth moves the price that remaining LPs are marked against.

Native `redeem` remains both legs, with per-leg minima. In-kind withdrawal is available and is not the single-token path.

### What does not qualify

The launch path permanently locks a one-sided launch position and locks initial lpTOKEN shares at the dead address. That is a launch curve / locked inventory. It does not establish arbitrary single-token entry and exit into active fee-earning liquidity. Curated wraps are a different path: README says hookless, static fee at least 0.20%, initialized `slot0`, minimum active liquidity, bounded tick deviation. Those admission rules were not re-read in `LpTokenFactory.sol`.

### Trust, fees, pause

README claims vaults are immutable clones, with no pause, no upgrade, and no admin reinvestment or withdrawal. The fetched interface has no pause or admin withdraw. Factory owner admission and a two-step treasury handoff are README claims. Not independently executed.

Share fee is 30 bps on mint and redeem per the README, so a zap round trip pays that fee on the way in and on the way out, plus the pool fee and price impact on the zap swap. No third-party audit report was fetched. The README's test counts are publisher claims. A repository is not deployment and not a security conclusion.

### Deployment — publisher-cited, not explorer-confirmed

README cites, and links explorers for:

- Robinhood Chain 4663: factory `0xDd9b4a30FFf71A391A39FbaCed43e3DAa84dbC84`, ZapRouter `0x19e1AbAcB318C25D9888bBAa62cBaa69dA2F66c7`
- Base 8453: factory `0x3384eD0d272dE35bF6DC516E1eA7d188CEb51793`, ZapRouter `0xc4C8071D651F093C4A5c2C06e7BFfc163A057DdA`
- Arc 5042: factory `0x37F540de37afE8bDf6C722d87CB019F30e5E406a`, `ZapRouterArc` `0x905F3AE86108c6A3b1a345dACEaef6c4749Ec66a`, dated in the README as 9 September 2026

`https://base.blockscout.com/api/v2/addresses/0x3384eD0d272dE35bF6DC516E1eA7d188CEb51793` returned no body. Deployment manifests in the repo were not fetched. Status: source-verified design, publisher-cited addresses, bytecode not confirmed this session.

## 2. Weir vaults — unverified documentation claim

Observed page: `https://www.weir.finance/docs`

Docs claims, not source:

- A vault is one full-range V4 position, shared, tracked as shares.
- Deposit either token. The vault swaps half in the same transaction.
- Every deposit, withdrawal, and compound reinvests earned fees first.
- Withdraw to either token or both.
- Anyone can start a vault on any initialized V4 pool with the first deposit.
- The UI simulates and sets minimum shares or tokens from slippage.
- Vault fee is 5% of fees at compound time, not on deposits or withdrawals, capped at 10% in code.
- Non-upgradeable. Withdrawals work while paused. Pause stops new deposits.
- "68 tests, including fork tests" against the live Robinhood PoolManager. Not run here. Not an audit.

Cited Robinhood 4663 addresses: WeirVaults `0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110`, PoolManager `0x8366a39CC670B4001A1121B8F6A443A643e40951`. The official Uniswap deployments page lists that PoolManager for Robinhood Chain 4663 (`https://docs.uniswap.org/contracts/v4/deployments`, observed before the page truncated). That matches the cited PoolManager. It does not show that WeirVaults holds a position.

Not obtained:

- Contract source. GitHub repository search `https://api.github.com/search/repositories?q=WeirVaults+uniswap+v4` returned `total_count: 0`.
- Explorer body. `https://robinhoodchain.blockscout.com/api/v2/smart-contracts/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110` and the address API for the same contract returned no body.

If the docs are accurate, this would be a native both-directions design, different from lpTOKEN: a hardcoded half swap rather than a caller-computed split, full range rather than a supply-derived range, a fee on compounded fees rather than on shares, and permissionless creation on any initialized pool, including hooked pools. None of that was confirmed in code. A half swap in raw units is not a value split when decimals differ. That is an inference about the docs' words, not a bug found in source.

Ladders are a separate product: one NFT, up to 64 rungs. Docs say a range fully below or above price needs one token and is a limit order. Collect, compound, and close are NFT operations. That is not a share vault, and a one-sided rung is not arbitrary entry and exit into active two-sided liquidity.

## 3. Twofold + PoolZapper — near match

Observed:

- `https://twofold.fi/docs.html`
- `https://github.com/twofoldfi/twofold-contracts`
- `https://raw.githubusercontent.com/twofoldfi/twofold-contracts/main/src/PoolZapper.sol`

### Custody

Docs say a Twofold pool keeps no liquidity inside Uniswap between trades. Reserves sit with the hook. The USDG leg rests in an allowlisted ERC-4626. Docs name Steakhouse USDG `0xBeEff033F34C046626B8D0A041844C5d1A5409dd`. On a swap the hook places concentrated liquidity, takes the fee, and pulls it back inside that transaction. Inferred: fee exposure is real, but this is not a standing held V4 position. The brief asks for vaults holding fee-earning V4 positions. This is adjacent, not the same custody model. EulerSwap is the stricter version of the same exclusion; Twofold at least has shared hook shares.

Docs also say the other leg does not rest in a lending vault. If Steakhouse pauses withdrawals, USDG exit may wait. That is a docs claim.

PoolManager cited in the docs and the repo README is `0x8366a39CC670B4001A1121B8F6A443A643e40951`, the same address as the official Uniswap Robinhood deployment. Hook address cited: `0xd1BcbCCa41f3bdb6b4812652959c6dF725ea2Ac0`. The repo says that hook is a verbatim copy of Uniswap's DualPool hook and points at Blockscout and Sourcify. Those match pages were not fetched. Bytecode identity was not checked.

### Shares and the zap

Native deposit and withdraw are both legs. Docs: `addLiquidity` / `removeLiquidity`; shares cannot be withdrawn in the block they were minted. Docs say the hook charges no fee of its own and that public depositors keep their growth. Operator recentering and pause are described as unable to reach principal. `OperatorController` source was not read. Treat those guarantees as docs claims.

`PoolZapper` was read:

- `zapInETH` and `zapInUSDG` swap the missing leg on a caller-supplied reference pool, call `hook.addLiquidity`, and mint an ERC-1155 (`TWO-LP`) to the user. Leftover tokens are refunded. Contract minima are the caller's `minUsdgOut` / `minAssetOut` and the add-liquidity maxima. App-page rules (1% floor, refuse above 15% impact) are docs, not constants in this contract.
- `zapOut` burns the ERC-1155, calls `hook.removeLiquidity`, and transfers `amount0` and `amount1` to the user. There is no second swap. Single-token withdrawal is not implemented in the fetched zapper.

Docs agree: a zapped position leaves through `zapOut`, which pays both legs. First-generation zapper `0x2eF1C576797a51FB60B25d9f946D2562d2d2F9Fc` is cited for older pools. That file was not read. Do not assume it differs.

The zapper has no owner functions in the fetched file. That is not an audit. Docs say wrapper checks were Slither, Aderyn, Halmos, and Mythril, and that they claim no third-party audit of the wrappers. The upstream DualPool audit is Uniswap's, and only if the bytecode match holds. Not checked here.

Range recentering is an operator/keeper path with docs-stated caps (about 5% steps, a 20% deviation must hold five minutes). A manipulated reference price is a docs-discussed risk, not a property proved from the controller source.

## 4. Bunni v2 — near match, in-kind exit, exploited tree

Observed:

- `https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/README.md`
- `https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/src/interfaces/IBunniHub.sol`

README: exploited; the repo does not have the relevant issues addressed; do not use in production. Postmortem URL in that README, `https://blog.bunni.xyz/posts/exploit-post-mortem/`, failed TLS (`EPROTO`). `docs.bunni.xyz` was not successfully fetched. Search-synthesis claims about a dollar loss, a shutdown date, `BunniHub` `0x000000000049C7bcBCa294E63567b4D21EB765f1`, and `BunniZapIn` `0x0000000000dFE4c0014A4fB7Fc63BB174b8aDB93` are unverified. A coordinator note that the 4 September 2025 postmortem said deposits and swaps were paused and withdrawals unpaused is not an independent fetch and is not present status.

Observed interface:

- `deposit(DepositParams)` takes `amount0Desired` and `amount1Desired`, plus per-leg minima, and returns shares, `amount0`, and `amount1`.
- `withdraw(WithdrawParams)` returns `amount0` and `amount1`.
- `queueWithdraw` exists. Comments say it is required before withdraw if an am-AMM manager exists. Comments say a 1-minute delay and a 15-minute grace period. Those numbers are comments, not a re-read of the implementation.
- One `BunniToken` per pool. Optional `vault0` / `vault1` ERC-4626 for idle, with raw-balance ratio bounds. `poolBalances` converts vault reserves through `previewRedeem`.
- LDF plus `twapSecondsAgo`. Hook whitelist. Owner pause flags. `burnPauseFuse` permanently unpauses.
- The interface header mentions `compound()`. The fetched interface body has no `compound()` function. Where fees are folded was not established beyond the header comment and the hook/hub swap helpers (`hookHandleSwap`, `hookGive`).

Inferred: core deposit and withdraw are two-currency. A zero desired amount is not documented as a supported single-token path. No zap contract was in the fetched interface or the README deploy list (`BunniQuoter` is the listed periphery quoter). Idle ERC-4626 yield is extra yield and extra vault risk; it is not single-token exit.

This is a real shared V4 LP share design, with fee and rehypothecation machinery, and it is not a both-directions single-token match on the source that was read. The README warning stands: the published tree is not a production recommendation.

## 5. Gamma — V4 named, both directions not shown

Observed:

- `https://docs.gamma.xyz/gamma/lp-vaults/introduction.md` — vaults on Uniswap V4, Uniswap V3, and Algebra. Non-custodial. Rebalance logic offchain, execution onchain. Rebalances do not use market swaps; limit positions are placed instead.
- `https://docs.gamma.xyz/gamma/lp-vaults/guides/providing-liquidity/deposit-liquidity.md` — "Single-sided deposits are not available right now." Dual-sided deposits. The worked example is Uniswap V3 WBTC-WETH.
- `https://docs.gamma.xyz/gamma/lp-vaults/guides/providing-liquidity/withdraw-liquidity.md` — withdraw returns both tokens of the example pair. The guide header is Uniswap V3.
- `https://docs.gamma.xyz/gamma/lp-vaults/strategies/v4-multiposition-strategies.md` — shape descriptions only (exponential, order book, Gaussian, triangle, uniform). No functions, no zap, no addresses.

Inferred: a V4 multi-position share vault is claimed at the intro level. The only deposit and withdraw procedure fetched is dual-sided in and both tokens out, on a V3 example. That does not prove the V4 vaults differ, and it does not prove a single-token path. Not a both-directions match.

## 6. ICHI — single-sided deposit docs, V4 not established

Observed:

- `https://docs.ichi.org/home/what-is-ichi.md` and `how-ichi-works.md`: single-token deposit into single-sided concentrated-liquidity pools; LP tokens; no swaps on deposit or rebalance; withdraw by swapping LP tokens for "the corresponding assets."
- FAQ does not describe a one-token exit.
- `https://docs.ichi.org/home/amm-integrations.md` does not name Uniswap V4. It links to `https://ichi.org/amms/`, which was not fetched.

A one-sided range is not arbitrary entry and exit into active two-sided fee-earning liquidity. V4 was not established. Not counted as a match.

## Exclusions

**EulerSwap.** `https://raw.githubusercontent.com/euler-xyz/euler-swap/master/README.md`. Pools do not hold token reserves. Output is borrowed just in time from Euler credit vaults against the input as collateral. One operator account can back pairs. Swaps are single-asset because they are swaps, not because a shared vault accepts and returns one token for a held V4 position. Exclusion.

**Arrakis Pro, current docs.** `https://docs.arrakis.finance/`. Issuer-owned NFT vault. Arrakis runs the strategy inside issuer-set parameters. Modular DEX module, optional V4 hook. Transferring the NFT transfers control of the funds. This is not a public fungible share vault with single-token entry and exit. Historical public-vault docs were not used. Arrakis search hits for `UniswapV4` library withdraw structs were not fetched; the current overview is the classification basis. Do not conflate Pro with an older public vault.

**Revert v4lend.** `https://raw.githubusercontent.com/revert-finance/v4lend/main/README.md`. ERC-4626 lending vault for one borrow/lend asset. Borrowers post V4 LP NFTs as collateral. Single-asset deposit and redeem are lending, not LP entry and exit. Transformers can swap collateral. That is position management, not the requested share vault. README includes deploy scripts for Base, Arbitrum, Unichain, and mainnet. No deployment was inferred from the scripts.

**VII Finance.** `https://raw.githubusercontent.com/VII-Finance/yield-harvesting-hook/main/README.md`. Wraps ERC-4626 shares or aTokens, donates accrued interest into a V4 pool, and the usage example adds both wrapped tokens through the position manager. The ERC-4626 is the pool asset, not a vault of a held V4 LP position. Exclusion.

**OpenZaps.** `https://openzaps.vercel.app/`. A bounded zap/intent executor on Robinhood Chain 4663. V4 appears as a swap hop in the examples. It does not custody a shared fee-earning LP position or issue LP shares. The page says the contracts remain unaudited. Exclusion. Do not infer that a zap and a vault on the same chain are integrated.

**Beefy CLM, not V4.** `https://docs.beefy.finance/beefy-products/clm`. Last update August 2024. Documents a zap deposit of one chosen token and a zap withdraw to a chosen token, via DEX aggregators, for CLM generally. The page explains Uniswap V3 concentrated liquidity and does not name Uniswap V4. Direct single-sided deposit without the zap is described as harmful to other depositors. Native withdraw is proportional both tokens. Useful pattern only. Not a V4 match. Audits cited on that page (Zellic, Cyfrin, Certora, Sherlock, 2024) were not opened, and would not establish V4 even if read.

**Prism.** `https://github.com/ozpool/prism`. Status badge and text: M0 Foundations, in progress. Base mainnet is "not in v1." README describes a future ERC-20 vault, proportional withdraw, keeper rebalance, Chainlink adapter. It does not specify single-token conversion. Not a working both-directions vault.

**Uniswap PositionManager.** The deployments page lists PositionManager beside PoolManager. That is the NFT position primitive. It is not a share vault. Not a candidate.

## Rejected or unresolved leads

| Lead | What happened | Why it is not a match |
| --- | --- | --- |
| Kerf | `https://raw.githubusercontent.com/KerfFinance/kerf-contracts/main/README.md` and `.../src/KerfZapV4.sol` both returned 404. A search synthesis cited the Solidity URL. The fetch did not. | Unverified. A zap file, even if it existed, would still need a share vault. |
| Blackhole | `https://www.blackhole.finance/whitepaper` returned 503 `DEPLOYMENT_PAUSED`. | No whitepaper text. Unverified. |
| Grimoire | `https://www.grimoire.fi/vaults` returned 404. | Unverified. |
| Aperture | Not primary-fetched. Search synthesis described a December 2025 zap-out post and `docs.aperture.finance`. | Social/marketing lead. Not proof of a shared V4 share vault with both directions. |
| Steer | Homepage `https://docs.steer.finance/` says liquidity hooks for Uniswap V4, Algebra Integral, and PancakeSwap V4, with automated rebalancing and an ERC-4626 architecture. `https://docs.steer.finance/llms.txt` and `https://docs.steer.finance/liquidity/liquidity-hooks` returned 404. | V4 hook lead only. Deposit and withdraw directions not read. |
| Charm, Krystal, Mellow, Decay, Hydrex, Angstrom, Doppler | Not primary-fetched this session. Search synthesis mentioned some of them. | Unresolved. Hooks, auctions, and AMMs are not assumed to be share vaults. |
| ScopeLift `fixed-fee-swap`, EthGlobal ZapVault | Named only inside search synthesis, beside unrelated V4 docs. | Not fetched. Not counted. |
| Weir ladders, lpTOKEN launch position, ICHI single-sided ranges | Fetched, and excluded as qualifying paths above. | One-sided or NFT inventory is not the requested share flow. |

## Strongest reusable patterns

1. **Keep the vault dual-leg and put the swap in a periphery that cannot keep inventory.** lpTOKEN's vault interface is `mintPair` / `redeem` in both currencies, with previews. `ZapRouter` pulls, swaps, mints or redeems, refunds the unused leg, and reverts unless its balances return to the pre-call baseline. The vault does not need an oracle for that split. The cost is that the zap trades against the same pool the vault supplies.

2. **Caller-computed split beats a raw half.** `zapIn` takes an explicit `swapCounterAmount`. Weir's docs say "swaps half." A raw half is the wrong size when decimals or the position ratio differ, and it is the wrong size after fees have skewed the claim. The verified pattern is: quote, then pass the swap amount and a minimum.

3. **Single-token exit is redeem, then swap the entire unwanted leg, or it is not single-token.** `zapOut` redeems both legs and converts the whole target leg. Twofold's `zapOut` stops after `removeLiquidity` and pays both. Bunni `withdraw` returns both. Gamma's guide returns both. In-kind exit is a useful native path. It is not the requested exit.

4. **Either pool token is not an arbitrary token.** lpTOKEN exit is target or counter only. Routed entry is only native or the canonical stable, at most three hookless static-fee hops, and only on the way in. A design that promises "any token" needs a separate router and a written venue list. Beefy's CLM page is the general version of that promise, and it is not shown on V4.

5. **A standing position is not a JIT hook, and a JIT hook is not a lending vault.** Twofold and EulerSwap earn swap fees without leaving liquidity in the pool between trades. Revert holds V4 NFTs as collateral. VII puts ERC-4626 shares in the pool. Arrakis Pro gives the issuer an NFT. None of those is a public share of a position the vault holds.

6. **One-sided inventory does not answer the question.** lpTOKEN's locked launch position, Weir's out-of-range ladder rung, and ICHI's single-sided pool can accept one token because the range only needs one token. That is a limit order or a directional book, not entry and exit into active two-sided fee-earning liquidity.

7. **Fee location changes the attack.** lpTOKEN charges 30 bps of shares on mint and redeem, so a zap round trip pays it twice, and compound is separately cap-limited. Weir's docs charge only on compounded fees. A fee on shares taxes entry and exit even when no fee was earned. A fee only on compounded fees does not tax a same-block round trip unless compound is mandatory. Weir's docs say compound runs before deposit and withdraw. That claim is unverified, and it would matter: a mandatory compound-before-withdraw inside a manipulable pool is a different risk from lpTOKEN's capped permissionless compound.

8. **Slippage guards that were actually in source are caller minima and deadlines, not TWAPs.** Bunni's LDF uses a TWAP window. lpTOKEN's zap does not. Beefy CLM documents a 60-second calm-zone check, on a non-V4 page. Copying the zap without a calm check means a flash move of the vault pool changes the split. Copying a calm check that reads the same pool's own TWAP fails when that pool is the only liquidity.

## Evidence gaps

- No cited address was confirmed by an explorer body this session. Blockscout APIs returned no output.
- Weir source was not found. The both-directions sentence is marketing until source or verified bytecode says otherwise.
- Bunni postmortem and docs TLS-failed. Zap deployment addresses from search are unverified. `compound()` is named in a comment and absent from the fetched interface.
- Gamma V4 contract functions were not fetched. The negative single-sided sentence is from a V3-labeled guide.
- ICHI's AMM list page was not fetched, so a V4 integration there is possible and unread.
- Steer V4 hook docs 404'd past the homepage sentence.
- No third-party audit PDF was opened for any candidate. Machine-check claims and repository test counts are not audits.
- No live position was checked for in-range fee accrual. Source can show the mechanism and still sit out of range, paused, or empty.
- `web_search` fabricated or conflated paths often enough that a 404 on `KerfZapV4.sol` is recorded next to the search citation. Do not promote those syntheses later.

## Queries and URLs

### Search queries this continuation

Used only as leads. The tool returned synthesized prose, not snippets.

1. `Uniswap v4 ERC4626 vault single-token deposit withdraw zapOut PoolManager 2025 2026`
2. `"zapOut" "PoolManager" vault Uniswap v4 shares deposit withdraw`
3. `Hydrex Beefy CLM Arrakis Pro Angstrom Doppler "Uniswap v4" liquidity vault single sided OR "single-token" withdraw`
4. `Bunni v2 BunniHub deposit withdraw BunniZap periphery Uniswap v4`
5. `Gamma Strategies Uniswap v4 liquidity vault deposit withdraw official docs`
6. `EulerSwap official github Uniswap v4 hook JIT vault shares deposit withdraw`
7. `Aperture Finance Uniswap v4 zap out vault shares official documentation`

Queries already issued in this assignment before compaction, not re-run, recorded so the set is complete:

- `Uniswap V4 vault single token deposit withdrawal`
- `Uniswap V4 ERC4626 liquidity vault PoolManager shares`
- `Bunni V2 Uniswap V4 deposit withdraw single token hub`
- `Arrakis Uniswap V4 vault deposit withdraw HOT AMM`
- `ICHI vault Uniswap V4 single sided deposit withdrawal`
- `Gamma Steer Charm Revert Uniswap V4 liquidity manager vault`
- `Aperture Krystal Mellow Beefy A51 DefiEdge "Uniswap V4" vault OR ALM deposit withdraw`
- `"Uniswap V4" "single token" OR "single-asset" OR "single sided" vault withdraw OR redeem OR zapOut -tutorial`
- `Weir Finance Kerf Prism Twofold Grimoire Blackhole OpenZaps Uniswap V4 vault`
- `site:github.com Uniswap v4 vault zapOut OR "single asset" ERC4626 PoolManager`
- `Hydrex EulerSwap Charm "Uniswap v4" liquidity vault deposit withdraw`

### Primary URLs fetched

Observed, unless the result says failed:

- `https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/README.md`
- `https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/interfaces/ILpTokenVault.sol`
- `https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/periphery/ZapRouter.sol`
- `https://api.github.com/repos/Steemhunt/lptoken-contracts/git/trees/main?recursive=1`
- `https://www.weir.finance/docs`
- `https://docs.uniswap.org/contracts/v4/deployments` (truncated by the fetch tool after the Robinhood Chain 4663 PoolManager, PositionManager, Quoter, and StateView rows; later chains on that page were not read)
- `https://twofold.fi/docs.html`
- `https://github.com/twofoldfi/twofold-contracts`
- `https://raw.githubusercontent.com/twofoldfi/twofold-contracts/main/src/PoolZapper.sol`
- `https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/README.md`
- `https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/src/interfaces/IBunniHub.sol`
- `https://docs.gamma.xyz/gamma/lp-vaults/introduction.md`
- `https://docs.gamma.xyz/gamma/lp-vaults/guides/providing-liquidity/deposit-liquidity.md`
- `https://docs.gamma.xyz/gamma/lp-vaults/guides/providing-liquidity/withdraw-liquidity.md`
- `https://docs.gamma.xyz/gamma/lp-vaults/strategies/v4-multiposition-strategies.md`
- `https://docs.ichi.org/home/what-is-ichi.md`
- `https://docs.ichi.org/home/how-ichi-works.md`
- `https://docs.ichi.org/home/faqs.md`
- `https://docs.ichi.org/home/amm-integrations.md`
- `https://docs.ichi.org/home/llms.txt`
- `https://raw.githubusercontent.com/euler-xyz/euler-swap/master/README.md`
- `https://docs.arrakis.finance/`
- `https://docs.beefy.finance/beefy-products/clm`
- `https://github.com/ozpool/prism`
- `https://raw.githubusercontent.com/revert-finance/v4lend/main/README.md`
- `https://raw.githubusercontent.com/VII-Finance/yield-harvesting-hook/main/README.md`
- `https://openzaps.vercel.app/`
- `https://docs.steer.finance/`
- `https://api.github.com/search/repositories?q=WeirVaults+uniswap+v4` (`total_count: 0`)

Failed or empty:

- `https://robinhoodchain.blockscout.com/api/v2/smart-contracts/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110` — no body
- `https://robinhoodchain.blockscout.com/api/v2/addresses/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110` — no body
- `https://base.blockscout.com/api/v2/addresses/0x3384eD0d272dE35bF6DC516E1eA7d188CEb51793` — no body
- `https://blog.bunni.xyz/posts/exploit-post-mortem/` — TLS `EPROTO`
- `https://raw.githubusercontent.com/KerfFinance/kerf-contracts/main/README.md` — 404
- `https://raw.githubusercontent.com/KerfFinance/kerf-contracts/main/src/KerfZapV4.sol` — 404
- `https://www.blackhole.finance/whitepaper` — 503 `DEPLOYMENT_PAUSED`
- `https://www.grimoire.fi/vaults` — 404
- `https://docs.steer.finance/llms.txt` — 404
- `https://docs.steer.finance/liquidity/liquidity-hooks` — 404

## Tool limits

- No `apply_patch`. Write tool used. Disclosed above.
- `web_search` does not return raw snippets here. Syntheses named contracts that 404'd and mixed lending vaults with LP vaults. Not used as proof.
- Fetch truncation cut the Uniswap deployments page after the Robinhood rows that were needed for the PoolManager check. Chains after that row were not read.
- Blockscout JSON endpoints returned empty tool output, so bytecode, verification status, and Weir source were not observed.
- Bunni blog TLS failed. Present pause state is unknown.
- GitHub code search was not used. Raw file URLs and the repository search API were used instead.
- No shell, Git, Forge, install, deploy, or peer read.

## Coverage

Useful designs actually compared: lpTOKEN/ZapRouter, Weir docs, Twofold/PoolZapper, Bunni v2, Gamma, ICHI, plus exclusions EulerSwap, Arrakis Pro, Revert v4lend, VII, OpenZaps, Beefy CLM (non-V4), and Prism (incomplete). That is more than five designs. Only one has both directions in source, and it is conditional: the vault is both-leg; the zap is either pool token; exit is not an arbitrary asset; deployment bytecode was not independently read. No example was upgraded from a landing page to a confirmed match.
