# MiniMax council original — Fee-earning Uniswap V4 vaults with single-token entry and exit

- Member: MiniMax (`minimax/MiniMax-M3`), council-member role, non-isolated shared research artifact.
- Run root: `docs/research/v4-single-token-vaults-20261029-01a18660/`.
- Source access date for every URL and query in this document: **2026-10-29** (UTC).
- Scope: research only. No implementation, no repository edits outside this file, no shell/Git/test/install/deploy, no delegation, no peer reading.

---

## 0. Identity, method, and honest tool limits

### 0.1 How I worked

1. Read the common brief at `docs/research/v4-single-token-vaults-20261029-01a18660/brief.md` in full.
2. Ran public web searches across multiple engines (DuckDuckGo HTML route and an Exa-backed route), then opened primary sources: official docs, official GitHub raw sources, GitHub REST tree/search APIs, Sourcify, and Blockscout/Sourcify explorer endpoints.
3. For every candidate I checked the **deposit direction** and the **withdrawal direction** separately, from primary text or from actual contract source/ABI. I did not accept a marketing sentence as proof of both directions.
4. Coordinator-supplied public leads (`lptoken-contracts`, `weir.finance/docs`, `kerf-contracts`, `ozpool/prism`, `twofold.fi/docs.html`, `blackhole.finance/whitepaper`, `grimoire.fi/vaults`, `openzaps.vercel.app`) were treated as leads only and independently checked; two of them turned out to be unreachable, one turned out to be a different product family than its name suggests, and one (Kerf) is explicitly *not* Uniswap v4-capable today.

### 0.2 Tool limitations actually encountered (not paraphrased away)

- **No `apply_patch` tool exists in this session.** `tool_search` for "apply_patch edit files in workspace" and for "patch file write create new file" returned *No catalog tools matched*. The only patch-capable tool exposed is the memory tool, whose `apply_patch` is restricted to paths inside the memory repository. **Workaround used: the file-write tool**, writing exactly one file — this `members/minimax/response.md` — which is the authorized deliverable path. No other file was created or modified. If the council requires a patch-format artifact, this file is the complete content and can be applied as one add-file patch verbatim.
- **No shell, Git, RPC, or test execution was available or used.** I therefore could not call `eth_call`, read balances, or confirm that any published address currently holds code. Deployment claims below are marked *project-published address* unless an independent explorer artifact (Sourcify match on the same chain id) confirms the deployment.
- **`webfetch` truncates at 50 KB.** `https://sourcify.dev/server/v2/contract/4663/0x9bb6…0110?fields=all` returned ~691 KB and was cut; I re-fetched the same endpoint with `?fields=abi` to get the complete ABI cleanly. GitHub tree-API dumps were also truncated in one case, so I did not rely on partial trees.
- **Blockscout's legacy proxy API returned an empty body** for `https://robinhoodchain.blockscout.com/api?module=contract&action=getsourcecode&address=0x9bb6…0110`, and the v2 `smart-contracts` endpoint also returned an empty body for the same address. I used Sourcify v2 instead, which returned a full ABI and a creation+runtime match for chain 4663.
- **DuckDuckGo's HTML route repeatedly served a bot challenge** ("anomaly page") and went into a cooldown; the Exa-backed route carried the remaining queries. No search-engine result was used as evidence on its own.
- **Some doc sites are unreachable by fetch:** `docs.steer.finance/llms.txt`, `docs.steer.finance/integration/uniswap` → "Page Not Found"; `docs.bunni.xyz/llms.txt` → TLS handshake failure; `raw.githubusercontent.com/itskillian/ethglobal-vault/main/AUDIT.md` → 404; `raw.githubusercontent.com/KerfFinance/kerf-contracts/main/README.md` → 404; `api.github.com/orgs/KerfFinance/repos` → 404.
- **Two coordinator leads are dead ends as fetched:** `https://www.blackhole.finance/whitepaper` → Vercel `503 DEPLOYMENT_PAUSED`; `https://www.grimoire.fi/vaults` → Vercel `404 DEPLOYMENT_NOT_FOUND`. `https://openzaps.vercel.app/` did load.
- **Coordinator corrections applied, not conflated:** Arrakis legacy public-vault docs now redirect to the current issuer-owned NFT-vault Arrakis Pro overview, so I treat "Arrakis Pro" as an issuer treasury tool, not a public retail vault. Bunni's postmortem (coordinator-fetched, `https://blog.bunni.xyz/posts/exploit-post-mortem/`, dated 2025-09-04) states deposits/swaps paused and withdrawals unpaused *at that date*; I do not treat it as proof of present status.

### 0.3 Classification rubric used (from the brief)

- **Confirmed match** — real Uniswap v4 PoolManager liquidity; a share/position model; a single-token **deposit** path verified; a single-token **withdrawal** path verified; fee path to holders described.
- **Conditional match** — the single-token direction exists but only through a **separately verified external zap/router** layered on a dual-sided vault, or the two directions have different quality (e.g. entry single-token, exit in-kind).
- **Near match** — right economics (fee-earning v4 LP) but one direction is in-kind only, one-sided-but-out-of-range, unverified, source-only, or not deployed.
- **Exclusion** — wrong AMM version, wrong model (hook/launchpad/curve), compromised code, or explicitly lacks a single-token direction.
- "Withdrawal in kind is not single-token withdrawal." "A one-sided out-of-range position or launch curve does not establish arbitrary single-token entry and exit into active fee-earning liquidity."

---

## 1. Candidate table

| # | Design | Chain(s) | Uniswap v4 liquidity | Single-token **deposit** | Single-token **withdrawal** | Fee path to holder | Classification |
|---|---|---|---|---|---|---|---|
| 1 | **Weir Vaults** (`weir.finance`) | Robinhood Chain 4663 | Yes — one full-range v4 position per pool inside the PoolManager | **Verified native** (`deposit(..., zap: bool, ...)`) | **Verified native** (`withdraw(..., zapTo: uint8, ...)`) | Auto-compound on every deposit/withdraw/compound; perf fee taken at compound time | **Confirmed match** |
| 2 | **lpTOKEN** (`Steemhunt/lptoken-contracts`) | Robinhood 4663, Base 8453, Arc 5042 | Yes — vault owns one v4 position per pool, ERC-20 share | **Conditional** — native `mintPair` is dual-sided; single-token via verified `ZapRouter.zapIn/zapInTarget/zapInRouted` | **Conditional** — native `redeem` is dual-sided; single-token via verified `ZapRouter.zapOut/zapOutTarget` | Permissionless `compound()` folds trading fees back into liquidity | **Conditional match (separately verified zap)** |
| 3 | **ZapVault** (`joaoolucas/zapvault`) | Base 8453 | Yes — hookless ETH/USDC 0.05% v4 pool, per-user positions | **Verified native** — USDC only, swapped to ETH inside the same unlock | **Verified native** — USDC only, ETH swapped back inside the same unlock | *Unverified* (see §2.3) — no explicit fee collection path read | **Confirmed match (hackathon-grade)** |
| 4 | **ALPS** (`yanisepfl/alps`) | Base 8453 | Yes — basket: V3 USDC/USDT, V3 USDC/cbBTC, **V4 ETH/USDC with Alphix dynamic-fee hook** | **Verified native** — USDC into one ERC-4626 vault | **Verified native** — ERC-4626 redeem in USDC | "Accrues fees back to the share price" | **Confirmed match (hackathon-grade)** |
| 5 | **USDa vault** (`itskillian/ethglobal-vault`) | Sepolia (testnet only) | Yes — concentrated USDC/USDT on Uniswap v4 with a distribution hook | **Verified native** — USDC only | **Verified native** — USDC **or** USDT | Fees accrue to share price, no claiming/compounding step | **Confirmed match (testnet/hackathon)** |
| 6 | **Kyber Earn / KyberZap (ZaaS)** | multi-chain incl. v4 | Operates Uniswap v4 pools via aggregator, owns no pool | **Verified** — up to 5 input tokens, swap+deposit in one tx | **Verified** — "Zap Out (Single Asset)": withdraw then consolidate into any target token | Position-level fee claim; FairFlow EG/LM rewards on v4 pools | **Conditional match (zap layer, not a vault)** |
| 7 | **Twofold** (`twofoldfi/twofold-contracts`) | Robinhood 4663 | Yes — Uniswap's own `DualPoolHook` (byte-for-byte upstream) + JIT liquidity | **Verified native** — ETH or USDG only via `PoolZapper` | **Not single-token** — `zapOut` pays **both** legs | Fees land in reserves → shares; USDG leg rests in Morpho (Steakhouse) ERC-4626 | **Near match (entry-only single-token)** |
| 8 | **PRISM** (`ozpool/prism`) | Base Sepolia (target) | Planned (v4-core pinned) | Planned `deposit()` — single-currency not evidenced | Planned `withdraw()` | Planned | **Source-only / unbuilt (M0)** — reference design, not a match |
| 9 | **Gamma** MultiPositionManager | multi-chain incl. v4 | Yes | **No** — "Gamma currently does not offer single-sided deposits on its vaults" | In-kind (both tokens) | Compounding via `zeroBurn`; Gamma charges 14–20% of earned fees | **Exclusion** (no single-token entry) |
| 10 | **Steer Protocol** | 27+ chains | Yes (v4 hooks advertised) | v3 API is dual-sided (`queueDeposit(token0Amount, token1Amount)`); v4 deposit path **unverified** | `queueWithdrawal(LPTto0, LPTto1)` → in-kind | Strategist fee; harvest | **Near match / unverified for v4** |
| 11 | **Arrakis Pro** | multi-chain | Yes (v4 module + optional v4 hook) | Issuer treasury in-kind | Issuer NFT controls withdrawal | Dynamic-fee hook; 2-day timelock on core params | **Near match** (issuer-owned NFT vault, not a public retail vault) |
| 12 | **Range** (`docs.range.fun`) | Robinhood 4663 | Yes — user-owned v4 positions | Two tokens ("Range calculates the other amount") | In-kind; "an out-of-range position may return only one token" | Fee-earning only while in range | **Exclusion** (not a pooled vault; no single-token entry) |
| 13 | **Kerf** (`kerf.world`) | Robinhood | v3, **v4 explicitly unsupported** | ERC-4626 single-token on v3 pools | same | v3 | **Exclusion** for v4 ("the executor has no v4 settlement path") |
| 14 | **ICHI** | 10+ chains | **v4 not evidenced**; v3 + ~15 other AMMs | Single-token (v3 lineage) | single-token | v3 strategies | **Near match** (right pattern, v4 unverified) |
| 15 | **Charm / Alpha Vaults** | multi-chain | **Uniswap v3** | "one-click deposits" in app; vault itself dual-sided v3 | in-kind v3 | v3 | **Exclusion** (v3) |
| 16 | **Topaz Dex Vaults** | BSC/Aerodrome | **Slipstream (Aerodrome)**, not v4 | Single-token zap in/out — good UX reference | single-token zap out | compounds TOPAZ rewards | **Exclusion** (wrong AMM) |
| 17 | **Grapl** (`docs.grapl.io`) | — | v4 SDK/CLMM instructions | `zap_in` composes swap + add-liquidity atomically | `zap_out` composes remove + swap | position fees collected separately | **Near match** (zap primitive, explicitly "not … a strategy vault") |
| 18 | **OpenZaps** | Robinhood 4663 | v4 swap routes only | Bounded multi-step zaps (allowlisted adapters, slippage/gas caps) | same | none (no LP position custody disclosed) | **Near match** (execution infrastructure) |
| 19 | **Fourmate** | Robinhood 4663 | v4 positions | **Deliberately none** — "No swap-assisted deposits" | in-kind | uncollected fees shown | **Exclusion** |
| 20 | **Bunni v2** | Ethereum | v4 shapeshifting DEX | not a share vault | — | — | **Exclusion** (exploited; repo states issues unaddressed) |
| 21 | **MoleSwap `MolePositions`** | Robinhood 4663 | v4 positions + `MoleHook` TWAP | **Unverified** | **Unverified** | performance-fee collector | **Near match / unverified** |

---

## 2. Detailed profiles — confirmed and conditional matches

### 2.1 Weir Vaults — CONFIRMED MATCH (native single-token in and out)

**What it is.** A liquidity suite for Uniswap v4 on **Robinhood Chain (chain id 4663)**: a session-aware hook ("gates"), shaped multi-rung "ladders", and **vaults that hold one full-range position per v4 pool and track holders as shares**.
Primary source: `https://www.weir.finance/docs` (also `https://weir.finance/vaults`).

**Share model / position ownership / fee path (observed).**
- Docs: *"A vault is one full-range position on a V4 pool shared by everyone in it, tracked as shares. Deposit either token and the vault swaps half inside the same transaction. Every deposit, withdrawal and compound call first reinvests earned fees, so your shares are worth more over time without claiming. Withdraw to either token or both. Anyone can start a vault for any initialized V4 pool with the first deposit."*
- Docs: *"Your liquidity sits in the Uniswap v4 PoolManager. Ladders are an NFT in your wallet; **vault shares are recorded against your address**."*
- Fees: *"Vaults: 5% of fees at compound time. Never charged on deposits or withdrawals. Capped at 10% in code."* Ladders 5% of collected/compounded fees (cap 10%).

**Source-level verification (strongest evidence in this study).**
Sourcify v2, chain 4663, address `0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110`, `matchId 54166048`, `creationMatch: match`, `runtimeMatch: match`, `verifiedAt 2026-09-30T03:34:14Z`
(`https://sourcify.dev/server/v2/contract/4663/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110?fields=abi`).
The verified ABI of `WeirVaults` contains:

| Function | Signature (verified ABI) | Why it matters |
|---|---|---|
| `deposit` | `deposit(DepositParams{key, amount0, amount1, zap, minShares, recipient, deadline, hookData}) payable → uint256 shares` | **`zap` is a bool inside the deposit call** — the single-token path is native to the vault, not an add-on router. `MIN_SHARES` constant; errors `BadZap`, `BadNativeAmount`, `Slippage`, `ZeroShares`, `VaultExists`, `PoolNotInitialized`. |
| `withdraw` | `withdraw(WithdrawParams{key, shares, zapTo, min0, min1, recipient, deadline, hookData}) → (uint256 out0, uint256 out1)` | **`zapTo` is a uint8 selector** — the single-token exit leg is native. Error `BadZap`. |
| `compound` | `compound(PoolKey, bytes hookData)` | Fee compounding; event `Compounded(id, fees0, fees1, liquidityAdded)`. |
| `previewRedeem` | `previewRedeem(PoolId id, uint256 shares) → (uint256 amount0, uint256 amount1)` | Share→asset conversion view. |
| `vault` | `vault(PoolId) → {key, tickLower, tickUpper, liquidity, totalShares, idle0, idle1, lastCompound, exists}` | One position per pool with **explicit idle-balance accounting** and a compound timestamp. |
| shares | `sharesOf(PoolId,address)`, `transferShares(PoolId,to,shares)`, `SharesTransferred` | Internal ledger shares — **no ERC-20 share token** in the ABI. |
| fee/governance | `perfFeeBps()`, `setPerfFee(uint16)`, `MAX_PERF_FEE_BPS`, `treasury()`, `setTreasury(address)`, `PerfFeeSet`, `TreasurySet` | Perf fee capped in code; treasury owner-settable. |
| pause | `pause()`, `unpause()`, `paused()`, `EnforcedPause` | Docs: *"Vault withdrawals work even while the vault is paused. Pausing only stops new deposits."* |
| ownership | `owner()`, `transferOwnership`, `acceptOwnership`, `renounceOwnership`, `pendingOwner` | Ownable2Step. |
| v4 plumbing | `unlockCallback(bytes)` (`NotPoolManager`), `poolManager()`, `createVault(PoolKey)`, `allVaults(uint256)`, `vaultCount()` | Permissionless vault creation per initialized pool. |

**Deployment evidence (project-published addresses; WeirVaults independently confirmed deployed+verified by Sourcify on chain 4663).**
`WeirHook 0xcEdfD5DABAAfa08ce3fAF51D393FDBC4a3Da90c4` · `WeirLadders 0xd6A7FCd111019F9e871ed761A066988779fbf60F` · `WeirVaults 0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110` · `WeirRouter 0xd1402ABfc8e25DFc5FaB51ad8A05056c48726E11`; Uniswap v4 `PoolManager 0x8366a39CC670B4001A1121B8F6A443A643e40951`, `StateView 0xF3334192D15450CdD385c8B70e03f9A6bD9E673b`, `Quoter 0x8Dc178eFB8111BB0973Dd9d722ebeFF267c98F94`; USDG `0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168`. Explorer: `robinhoodchain.blockscout.com`.

**Trust model (observed).** Contracts non-upgradeable (*"Contracts are non-upgradeable. Every cap above is a constant in the code"*); the owner can set the performance fee (bounded by `MAX_PERF_FEE_BPS`), set the treasury, and pause; withdrawals are explicitly designed to keep working while paused; the owner cannot reach share balances (no admin withdrawal path appears in the ABI).

**Limitations / economic notes.**
- The deposit path swaps **half** inside the vault's own pool, so a single-token depositor pays that pool's swap fee and price impact, and the conversion is sandwichable in principle; mitigation is the `minShares`/`min0`/`min1`/`deadline`/`Slippage` guard, not an external oracle.
- The vault holds a **full-range** position (per the docs). That is capital-inefficient versus a concentrated, actively managed range: most capital sits far from the trading price. The suite's "ladder" product is where shaped ranges live, and ladders are not the pooled share vault.
- One position per pool ⇒ diversification requires many vaults; idle balances (`idle0`/`idle1`) are tracked but are not fee-earning.
- LP fees are whatever the pool charges, including hook-modified fees (Weir's own hook can change LP fee up to 10%, surge up to 5%, curator up to 1% — a vault on such a pool inherits that fee schedule).
- Share ledger is **not** an ERC-20 ⇒ shares are not composable as a token (contrast lpTOKEN below, which is ERC-20).
- No public audit of the Weir system found by me; no public GitHub source repo located (GitHub repository search for a Weir v4 liquidity repo returned only an unrelated launchpad project). Verification rests on Sourcify-verified source plus the project's own docs. The "68 tests, including fork tests against the live Robinhood Chain PoolManager" claim is the project's, and I did not run them.
- ICHI-like single-token products aside, Weir is the only candidate I found where **both** directions are native to the vault contract itself on a v4 PoolManager, with verified source.

### 2.2 lpTOKEN (`Steemhunt/lptoken-contracts`) — CONDITIONAL MATCH (verified zap periphery over a dual-sided v4 vault)

**What it is.** Wraps exactly one Uniswap v4 LP position per pool into a transferable ERC-20 share token ("lpTOKEN"), with a permissionless `compound` that folds trading fees back into liquidity.
Primary sources: `https://github.com/Steemhunt/lptoken-contracts` (README) and raw source `src/periphery/ZapRouter.sol`, `src/LpTokenVault.sol` (interface `ILpTokenVault`), `src/LpTokenFactory.sol`.

**Dual-sided core (observed).** README: *"`mintPair` / `redeem` — deposit or withdraw **both legs** at the current portfolio ratio; 30 bps fee charged in backed shares (bootstrap and ERC-20 transfers are free)."* The vault is an immutable clone owning exactly one position with a `VaultRange` derived from each leg's supply; accounting is *"an exact two-currency pro-rata claim — position principal, pending fees, launch-fee NAV allocation, idle balances — with no oracle, USD numeraire, or pool-wide reserve assumption anywhere."* Security model: *"no pause, no upgrade path, no administrative reinvestment or withdrawal privilege."* `compound` is *"permissionless and swapless"*, sized by a cap derived from the pool fee and a 50% safety factor, with a 10-minute cooldown.

**The single-token layer — verified in source, not inferred.** `src/periphery/ZapRouter.sol` (v2.0, fetched raw) exposes:

| Entry | Signature (source) | Single-token behaviour |
|---|---|---|
| `zapIn` | `zapIn(vault, counterAmount, swapCounterAmount, minSwapTargetOut, minShares, receiver, deadline)` | Deposits counter; swaps an explicit portion into target **through the vault's own pool**; then `vault.mintPair`. NatSpec: *"The client computes the split from live quotes and the vault preview; this function never assumes a 50% raw-unit split."* |
| `zapInTarget` | `zapInTarget(vault, targetAmount, swapTargetAmount, minSwapCounterOut, minShares, receiver, deadline)` | Mirror image on the target leg. |
| `zapInRouted` | `zapInRouted(vault, inputCurrency, inputAmount, PoolKey[] counterRoute, minRouteCounterOut, swapCounterAmount, minSwapTargetOut, minShares, receiver, deadline)` | Accepts **native currency or the configured canonical stablecoin only** (`UnsupportedInput`); ≤ `MAX_ROUTE_HOPS = 3`; route pools must be **hookless and static-fee** (`HookedPoolNotSupported`, `DynamicFeePoolNotSupported`); every hop must spend its full input (`InexactSwapInput`). |
| `zapOut` | `zapOut(vault, shares, minCounterOut, receiver, deadline)` | `vault.redeem(shares, 0, 0, address(this), deadline)` then swaps the withdrawn target leg into the counter leg; *"Any partial exact-input fill reverts."* |
| `zapOutTarget` | `zapOutTarget(vault, shares, minTargetOut, receiver, deadline)` | Redeem both legs, convert the counter leg to target. |

Integration with the vault is **explicit in code** (the coordinator warned not to assume co-located zap and vault code integrates): the router checks `factory.isVault(address(vault))` and `vault.factory() == address(factory)`, calls `vault.mintPair(...)` / `vault.redeem(...)`, refunds the unused leg to `msg.sender`, mints shares straight to `receiver`, and asserts post-call balance invariants (`_requireBalance`, `_requireTokenBalance`).

**Trust model (observed).** Vaults are immutable clones with no admin path; the factory owner can only admit new pools; the treasury rotates via two-step handoff. Router NatSpec is explicit about its own limits: *"Caller minima enforce accounting and slippage, but the router does not discover route quality, establish fair value, or provide MEV protection."* The project states 323 non-fork tests plus mainnet-fork dry runs against the production `PoolManager` artifact (project-reported; I did not run them).

**Deployment evidence (project-published).** Robinhood Chain 4663 — Factory `0xDd9b4a30FFf71A391A39FbaCed43e3DAa84dbC84`, Vault impl `0xBaf91d6c83fe4B325ddD818aDaa9A39D490E6C6d`, TokenLaunchpad `0xC3612550Fd0f3095B6636110e5b06dD4eb05e000`, LaunchLiquidityVault `0x7FcA8E7a8376B38f3eb23F21e8C7b7c6E5f3f077`, **ZapRouter `0x19e1AbAcB318C25D9888bBAa62cBaa69dA2F66c7`**, LpTokenLens `0x8bA19810F56E455276a0Db1eaace071D75B08Fd2`. Base 8453 — Factory `0x3384eD0d272dE35bF6DC516E1aE7d188CEb51793`, Vault impl `0x78aae2fD8f8b09994d0e936Ce4478a7EB8FE92D9`, Launchpad `0xED14eE7501fB212f876714a68308564cD6772000`, LaunchLiquidityVault `0x39f3C534E6962Fd5fb0DD3653B6c16400c49C498`, **ZapRouter `0xc4C8071D651F093C4A5c2C06e7BFfc163A057DdA`**, Lens `0x6DC57E44B995c56F91a6AD5f221F372C1c2FFBF5`. Arc 5042 — Factory `0x37F540de37afE8bDf6C722d87CB019F30e5E406a`, Vault impl `0x2c692DB9203EF651745AF2c07ebd587222D55a06`, Launchpad `0xa790B0e77FD23504342404fc8DD0c5AE4DE4e000`, LaunchLiquidityVault `0x124ed8F31A4052cA910E98e5cE9bb182C88AB365`, **ZapRouterArc `0x905F3AE86108C6A3b1a345dACEaef6c4749Ec66a`**, Lens `0x5dfA75b0185efBaEF286E80B847ce84ff8a62C2d`. I did not independently confirm code at these addresses (no RPC available).

**Limitations.**
- The single-token conversion for the direct zaps happens **inside the pool the vault is LPing in** → self-impact and sandwich surface; the routed variant is limited to native/stable and hookless static-fee pools, so a v4 pool with a hook cannot be reached through the routed path.
- Single-token exit is only into **one of the two pool tokens**, not an arbitrary third token.
- 30 bps mint fee (in backed shares) on top of the swap's own fee and price impact.
- `mintPair` reproduces the current portfolio proportionally, so the vault is not a "one token in, leveraged exposure" product; and the launchpad path creates a permanently locked **one-sided launch position** — a launch-curve seed, not user single-token entry into fee-earning liquidity (excluded per the brief).
- ZapRouter `zapIn`/`zapOut` are per-vault: only registered lpTOKEN vaults can be zapped, so this is not a general v4 zap.

### 2.3 ZapVault (`joaoolucas/zapvault`) — CONFIRMED MATCH on both directions, hackathon-grade trust

**What it is.** A standalone Uniswap v4 vault (no custom hook) that manages **per-user** concentrated positions in the hookless ETH/USDC 0.05% v4 pool on Base; entry and exit are both USDC-only.
Primary source: `https://github.com/joaoolucas/zapvault` (README) and raw `contracts/src/ZapVault.sol`.

**Verified source facts.** `ZapVault` implements `IUnlockCallback`:
- `deposit(address user, uint256 usdcAmount, UserConfig config)` — router-only (`OnlyRouter`); one position per user (`PositionAlreadyExists`); transfers USDC in, computes a **Chainlink-ETH/USD-centred** range (`_getOracleTick`, staleness > 1 h ⇒ `StaleOracle`), computes the USDC→ETH split from the **pool's own current tick vs the oracle range**, performs the swap and the liquidity add **inside one `poolManager.unlock`**, then settles the net deltas and stores `UserPosition{tickLower,tickUpper,liquidity,depositedUSDC,depositTimestamp,salt}`.
- `withdraw()` — removes liquidity, swaps the recovered ETH **back into USDC in the same pool**, `poolManager.take(usdc, user, usdcOut)`; deletes the position and config.
- `rebalance(address user)` and `needsRebalance(address user)` — **no access control on `rebalance` in the code I read**; anyone may trigger a rebalance for any user (bounded by that user's own `rangeWidth`/`rebalanceThreshold` config).
- Owner powers: `setRouter`, `rescue(token,to,amount)`, `owner()`.
- Strategy config also publishable as **ENS text records** (`vault.range`, `vault.rebalance`, `vault.slippage`; defaults 600 ticks / 500 bps / 50 bps).

**Deployment evidence (project-published addresses; I did not verify code on Base).** ZapVault `0xc77d3CCFba9354db99972D11d994676d55709d5C`, ZapVaultRouter `0x3F75D8E28A148380B186AcedcDE476F8E1CFDd78`, v4 PoolManager `0x498581fF718922c3f8e6A244956aF099B2652b2b`, USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`, Chainlink ETH/USD `0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70`.

**Trust model / limitations.**
- Entry is **USDC-only**; exit is **USDC-only**; there is no arbitrary-token path (a cross-chain arbitrary-token entry exists only through **LI.FI Composer** swapping/bridging into USDC first — i.e. the single-token conversion is partly off-chain).
- Range placement depends on a **Chainlink feed** (1 h staleness bound) while the split is computed from the **pool's own tick** — two price sources with a mismatch surface.
- The manager is an **AI keeper** (Vercel cron, Claude Opus 4.6) that calls `rebalance`; if it dies, positions simply drift (users can still withdraw).
- Owner has `rescue` over stray tokens and can repoint the router; no share token and no pooled vault, so there is no fee sharing between depositors and no compounding.
- **Unverified fee path:** in `ZapVault.sol` the helper `_modifyLiquidity` destructures only the first return value of `poolManager.modifyLiquidity(...)` and the second (`feesAccrued`) is not used in the paths I read. Whether accrued v4 trading fees are actually paid to the withdrawing user, remain owed to the position, or revert the unlock is **not established** by what I read (I did not execute the code, and I did not read v4-core's `modifyLiquidity` settlement semantics in this session). Treat "fees reach the holder" as **unverified** for ZapVault.
- No audit; no production hardening of the router/key management; one position per user (no top-ups).
- The README's "the keeper is non-custodial. If it goes down, positions stay active and users can withdraw at any time" is a project claim consistent with the code I read.

### 2.4 ALPS (`yanisepfl/alps`) — CONFIRMED MATCH on both directions (fixed asset), hackathon-grade trust

**What it is.** A **single-deposit USDC ERC-4626 vault on Base** that runs a diversified basket of concentrated-liquidity positions across **Uniswap V3 and Uniswap V4**, with an off-chain keeper + KeeperHub orchestration.
Primary source: `https://github.com/yanisepfl/alps` (README).

**Observed claims.** *"You deposit USDC into a single ERC4626 vault on Base. The vault holds CL positions across whitelisted pools (e.g. USDC/USDT V3, USDC/cbBTC V3, **ETH/USDC V4 with hooks**) and accrues fees back to the share price."* Rebalance cycle: `vault.executeRemoveLiquidity → maybe-swap → executeAddLiquidity` executed by the keeper in the vault's `agent` role, through `UniV3Adapter` (V3 NonfungiblePositionManager), `UniV4Adapter` (V4 PositionManager, `modifyLiquidities` calldata) and `URAdapter` (Universal Router calldata from the Uniswap Trading API). The V4 leg explicitly uses the **Alphix dynamic-fee hook**, i.e. hooked v4 LP, not just canonical v4.

**Deployment evidence (project-published; not independently verified on Base).** ALPVault (ERC4626) `0x3F0e6cef3a75f52F1E55806Afe40317f51199CaE`; PoolRegistry `0x6911dC2e50C4D89f244aB9D65E89A847Beee1634`; UniV3Adapter `0x145Deaf02fDd2F56630DC64afFbd4bdDf36A3D79`; UniV4Adapter `0xB6871C8cd995fF015DBa7373b371426E80cBBCF0`; UniversalRouterAdapter `0x6BeE052D58Ba95bae9fd23d81a2B96145095a962`; agent EOA with the `agent` role `0x8cf03f65ffC08a514dA09063b5632deC0b11475D`. README gives three concrete rebalance transactions on Base (two V3, one V4 hooked-pool recenter).

**Trust model (observed).** `onlyAgent` on execute functions; `PoolRegistry.isPoolKnown(key)` checked on every execute; slippage floors enforced by adapters (50 bps swap, 100 bps liquidity); the README states that even a fully compromised agent key cannot withdraw the vault's underlying USDC, transfer tokens out, change the pool whitelist, or route to an unwhitelisted pool. KeeperHub gas gate; a post-rebalance workflow audits each on-chain rebalance against `vault.poolValueExternal()`.

**Limitations.**
- Asset is fixed to **USDC** (an ERC-4626 asset), so this is "single token" in the strict sense but not arbitrary-token.
- Basket is small (3 pools), two of them V3; exposure is diversified but shallow, and IL applies across all legs.
- The keeper/agent is a **trust dependency** for range quality; the README states the agent key lives in a `.env` on a VM and that a Safe multisig and hardware-backed signer are future work.
- Two of the five keeper policies are narration-only (no actuation), so the strategy is partly aspirational.
- ERC-4626 `totalAssets` pricing must be robust to donation/price manipulation — the README does not describe a donation-proof NAV for this vault (contrast §2.5), so I flag **manipulation resistance of the share price as unverified**.
- No audit; built in a hackathon sprint (ETHGlobal OpenAgents 2026).

### 2.5 USDa vault (`itskillian/ethglobal-vault`) — CONFIRMED MATCH, testnet-only

**What it is.** A yield-bearing stablecoin vault: *"You deposit USDC and receive USDa, an ERC-20 share token. The vault supplies the deposited capital as concentrated USDC/USDT liquidity on Uniswap v4; the trading fees it earns accrue to the share price, so USDa appreciates against USDC over time with no claiming or compounding step. It's an ERC-4626 vault internally (OpenZeppelin v5), but the standard mint/redeem entrypoints are disabled in favor of custom deposit/withdraw functions."*
Primary source: `https://github.com/itskillian/ethglobal-vault` (README).

**Observed design points that matter for a single-token product.**
- *Adaptive positioning*: reads a companion v4 hook recording where swaps land, returns tick ranges covering 90%/99%/99.9% of volume; holds four positions (thin full-range backstop + three banded).
- *Self-rebalancing*: best-effort rebalance at the end of every deposit and withdrawal, plus a permissionless trigger — no keeper required.
- *Donation-proof NAV*: computed from position liquidity, uncollected fees and **internally tracked idle balances only — never from `token.balanceOf`**.
- *Oracle-free pricing with a peg clamp*: price from the pool's own `sqrtPriceX96`, clamped into a configurable peg band; deposits rejected when the pool is off peg.
- *Off-pool swaps*: rebalancing ratios are swapped on a separate deep pool with a backup router, behind a two-sided balance check (*"spent ≤ in, received ≥ out"*); *"it never swaps in its own pool (which would move the price it values itself against)"*.
- *Pro-rata fee accounting on exit*: *"A Uniswap position settles 100% of its accrued fees on any liquidity decrease; the vault withdrawal path detects this and pays each user only their proportional share of principal and fees, retaining the remainder for other holders."*
- *Dual-token exit*: withdrawals in USDC **or** USDT (the two pool tokens).

**Deployment evidence.** Sepolia only: vault `0x1638fcb8a56a19e8226e2d15c7b3c2cc2f3c6040`, hook `0xfba82aec5c132db641e22464d7ce7f71994d9040`, plus pool-init and deposit tx hashes in the README (testnet).

**Limitations / gaps.** Testnet deployment only; the README mentions *"an adversarial security review (AUDIT.md) that found and fixed two critical issues (fee over-collection on withdrawal and spot-price NAV manipulation)"* — **the `AUDIT.md` URL I tried returned 404, so I could not verify the review, its scope, or the fixes.** The "off-peg deposits rejected" rule means a **legitimately de-pegged stablecoin pool stops accepting deposits**, which is a real liveness constraint; the peg band is configurable (who can configure it, and to what, is not documented in what I read); the pool is USDC/USDT only, so capital is constrained to one pair; the distribution hook is a bespoke component whose correctness the vault depends on.

### 2.6 Kyber Earn / KyberZap (ZaaS) — CONDITIONAL MATCH (verified zap layer over Uniswap v4 positions)

Primary source: `https://docs.kyberswap.com/user-guide/kyber-earn` (and `.../kyber-earn.md`).
Observed: *"All deposit, withdrawal, migration, repositioning, and compounding operations within Kyber Earn are powered by Zap as a Service (ZaaS)… **Up to 5 input tokens** — Deposit into any pool using up to 5 different tokens in a single transaction"*, routed via the KyberSwap Aggregator; *"**Zap Out (Single Asset)** — Withdraw partially or fully remove a position, then automatically swap the underlying pool assets into a single target token of your choice"*; Uniswap **V4** is a supported protocol for liquidity pools, and FairFlow (EG + LM rewards) adds yield on v4 pools. Kyber Earn *"does not operate liquidity pools or Partner Vaults directly"*; Partner Vaults (starting with ether.fi) are single-asset auto-compounding vaults but are not v4 LP positions. Platform fee is charged on the input amount of each Zap.
**Classification rationale:** a separately verified, productized single-token-in/single-token-out path over Uniswap v4 fee-earning positions, but the fee-earning position is owned by the user (a v4 position), not a pooled vault with a share model; `Smart Exit` explicitly *"returns assets in the pool token ratio. It does not consolidate into a single token"*.
**Limitations:** third-party aggregator trust and fees; the consolidated exit swap is a normal AMM swap (price impact, slippage); partner-vault dependency for the "single-asset vault" product.

### 2.7 Twofold (`twofoldfi/twofold-contracts`) — NEAR MATCH: single-token entry verified, exit is in-kind only

Primary sources: `https://twofold.fi/docs.html`, `https://raw.githubusercontent.com/twofoldfi/twofold-contracts/main/src/PoolZapper.sol`, repo tree via the GitHub API.

**Verified entry.** `PoolZapper` (verified source, MIT, Solidity 0.8.26) offers `zapInETH(poolKey, wethRef, assetRef, sellWei, minUsdgOut, usdgForAsset, minAssetOut, sharesToMint, maxAmount0, maxAmount1, deadline)` and `zapInUSDG(poolKey, assetRef, usdgIn, usdgForAsset, minAssetOut, sharesToMint, maxAmount0, maxAmount1, deadline)`: buy the missing leg on the **deepest hookless v4 reference pool**, then `hook.addLiquidity(poolKey, sharesToMint, maxAmount0, maxAmount1, deadline)` (both legs), then `_refundAll` refunds leftovers and unwraps WETH to ETH. The zapper mints an **ERC-1155 "Twofold LP" (TWO-LP)** ledger share; only the ledger holder can withdraw.
**Verified exit is NOT single-token.** `zapOut(poolKey, sharesToBurn, minAmount0, minAmount1, deadline)` burns the ledger share, calls `hook.removeLiquidity(poolKey, sharesToBurn, minAmount0, minAmount1, deadline)` and transfers **both `amount0` and `amount1`** to the user. There is no single-token exit path in the zapper source I read. Docs confirm: *"your position … you collect by withdrawing, which burns your shares and pays you both tokens in the pool's ratio at that moment"* and *"A zapped position leaves through the zapper's `zapOut`, which burns the ledger entry and pays both legs to your wallet in one transaction."*
The underlying pool is Uniswap's **own `DualPoolHook`, deployed byte-for-byte unmodified** through Uniswap's `AllowlistedFactory`; direct (non-zapped) deposits also require both legs (`hook.addLiquidity(key, shares, maxAmount0, maxAmount1, deadline)`).
**Deployment evidence (project-published, with explorer links).** PoolZapper `0x8934A298d3E59a632994ac254Dee19112127f2B7`; first-stack PoolZapper `0x2eF1C576797a51FB60B25d9f946D2562d2d2F9Fc`; DualPoolHook (current) `0xd1BcbCCa41f3bdb6b4812652959c6dF725ea2Ac0`; DualPoolHook (first stack) `0x127B3f3b7769f659C5eDBfF8b4005443f19FAAc0`; OperatorControllerV2 `0x705F4f94344feD3f7BA98300F8bC04fdAE570340` / `0xc7295643EC5414DE243e3F9810Eb28F85e5d9ABd`; Registry `0xdF1a23B1A7507Cc3B270DfA78FDd9ddA7bC36325` / `0x1b66DD14C9281A18E696dbdb40cFB5070842c0C2`; VaultAllowlist `0x3B1B0f1812a9a09664D82238E94c604D30Bb8134` / `0xe44C0D41A1fFbF7234492bb7a3F745246c351C42`; Uniswap v4 PoolManager `0x8366a39cc670b4001a1121b8f6a443a643e40951`; Steakhouse USDG vault `0xBeEff033F34C046626B8D0A041844C5d1A5409dd`.
**Trust model (observed).** No owner on the PoolZapper (*"The contract has no owner, no admin functions and no upgrade path"*); wrappers un-audited by any third party (*"We claim no third-party audit of the wrappers"*, self-stated static-analysis battery: Slither, Aderyn, Halmos, Mythril + mutation-tested suites); owner powers queued behind a multisig + 24 h timelock; recentering limited to pre-approved shapes; the USDG leg rests in an allowlisted Morpho (Steakhouse) ERC-4626 vault, so **a pause there can delay withdrawals**.
**Why near match, not match:** entry is single-token (ETH or USDG only), exit is in-kind only. Per the brief, in-kind withdrawal is not single-token withdrawal. Also note the *fee-earning* surface: liquidity is deployed JIT per swap, so the pool's "fee-earning position" is transient; idle capital earns lending yield in the ERC-4626 vault rather than v4 swap fees.

### 2.8 PRISM (`ozpool/prism`) — SOURCE-ONLY / UNBUILT (design reference)

`https://github.com/ozpool/prism` README: *"**Status: M0 — Foundations**"*, *"Current status: **M0 · Foundations** (in progress)"*. Planned: `Vault` = ERC-20 shares + multi-position aggregator owning liquidity inside the PoolManager; M1 scope includes *"`deposit()` via `PoolManager.unlock` with slippage bounds"*, *"`withdraw()` with proportional removal across positions — never pausable"*, *"`MIN_SHARES = 1000` burned to `DEAD` on first deposit (inflation-attack mitigation)"*, *"Views: getPositions, getTotalAmounts, sharePrice, TVL cap enforcement"*; M2 adds *"optional internal swap (slippage-bounded)"* during rebalance; M3 a `ProtocolHook` with EWMA-volatility dynamic fees and a `ChainlinkAdapter` with a 1 h staleness gate; seven Foundry invariants; Base Sepolia as the launch target.
**Classification:** a well-specified *plan* for a v4 vault with share accounting, minimum-share inflation defence and a never-pausable withdrawal, but **no contracts exist yet** (M0), no deployment, and **no evidence that deposits are single-token** (the planned deposit takes both legs). Treat as a reference design, not a match.

---

## 3. Near matches and exclusions — with reasons

| Lead | What I actually verified | Why it is not a qualifying match |
|---|---|---|
| **Gamma** (MultiPositionManager, v4 multi-position vaults) | `https://docs.gamma.xyz/gamma/lp-vaults/glossary.md`: *"Single-sided deposits … Gamma currently does not offer single-sided deposits on its vaults"*; *"Dual-sided deposits … Gamma offers dual-sided deposits on all its vaults"*. Deposit guide: *"Single-sided deposits are not available right now."* Withdrawal guide: *"your LP tokens should be exchanged for WBTC and WETH"* (both legs). v4 `MultiPositionManager` ABI shows `deposit(uint256 deposit0Desired, uint256 deposit1Desired, address to, address from)`. Guardian audited MultiPositionManager (2026-01-02→2026-02-04). | Genuine v4 fee-earning vault with excellent ops, but **no single-token entry**; withdrawal is in-kind. |
| **Steer Protocol** | `https://steer-protocol.gitbook.io/docs/contracts/vaults`: `queueDeposit(uint256 token0Amount, uint256 token1Amount)`, `queueWithdrawal(uint256 _LPTto0, uint256 _LPTto1)`, `claimWithdrawal()`, `tend()`; deposit/withdraw are queued and await a tend. `https://docs.steer.finance/` homepage: *"Hooks for Uniswap V4, Algebra Integral, and PancakeSwap V4 protocols with automated rebalancing and **ERC-4626 vault architecture**"*. | The verifiable vault API is **dual-sided**; the v4 hook pages were unreachable to me (`docs.steer.finance/llms.txt` and `/integration/uniswap` → "Page Not Found"), so **v4 single-token entry/exit is unverified**. Also introduces an async queue in the deposit/withdrawal path. |
| **Arrakis Pro** | `https://docs.arrakis.finance/arrakis-pro`: *"self-custodial vaults: **the issuer owns the vault and the assets in it**"*, *"the vault is represented by an NFT, the way a Uniswap v3 position is"*, *"changes to the vault's core parameters are subject to a two-day timelock"*, optional v4 hook (dynamic fees, price convergence), Arrakis runs the strategy off-chain. ChainSecurity audited the Uniswap V4 Module. | Issuer treasury market-making, **not** a public retail vault with a share token and single-token user entry/exit. Legacy "public vault" docs now redirect here. |
| **Range** (`docs.range.fun`) | *"Range keeps your positions in your own wallet"*, *"Range does not manage these positions for you"*, *"If your positions need both tokens, Range calculates the other amount"*, withdrawal: *"an out-of-range position may return only one token"*, V4 = one transaction for up to 50 positions. Legacy Range AMM vaults (gitbook) are Uniswap **V3** share vaults with strategist fees and mint/burn pausing. | Per-wallet v4 positions with two-token deposits and in-kind withdrawal (single-token only as an out-of-range artifact) — exactly the trap the brief warns about. |
| **Kerf** (`kerf.world`) | `https://www.kerf.world/app/pools`: *"Uniswap v4 pools — listed, not supported — no adapter"*, *"Kerf does not price or route them: a v4 pool can run a hook that rewrites its fee or swap curve … and the executor has no v4 settlement path."* `github.com/KerfFinance/kerf-contracts` README raw → 404; GitHub org API → 404. Docs clone describes ERC-4626 vaults + a swap-and-mint zap on v3/v4. | The *design* is close (ERC-4626 vault + single-token zap), but the **live product has no v4 settlement path**. `kerf-contracts` was not publicly locatable by me. |
| **ICHI** | `https://www.ichi.org/`: *"turning your single-token deposits into optimized yields"*; DefiLlama: *"ICHI's main product is ICHI Vaults which accept single-token deposits and then deploy these tokens into Uniswap V3 c…"*; docs describe single-sided concentrated liquidity across "Uniswap V3 and 15 other AMMs on 10+ networks". | Single-token pattern is proven, but **no v4 support evidenced** on primary sources. Ketju research memo (2026-09-23) also notes ICHI is "Not approved" as a liquidity-pool structure. |
| **Charm / Alpha Vaults** | `charmfinance/alpha-vaults-contracts`: *"A vault that provides liquidity on Uniswap V3."* Charm v2.1 blog (2026-03-05) advertises "one-click deposits" in the app. | Underlying vault is **v3**; the one-click deposit is app-level zapping, not v4 single-token vault entry. |
| **Topaz Dex Vaults** | `https://vaults.topazdex.com/docs/zapping`: full single-token / native-BNB zap in, and zap out "to a single token" or native; `https://vaults.topazdex.com/docs/vaults`: CL vaults run on **Slipstream**, V2 vaults are ERC-4626 over LP tokens; deposits/withdrawals "never paused". | Excellent UX precedent for single-token zap in/out over a share-token vault — **but the AMM is Aerodrome/Slipstream, not Uniswap v4**. |
| **Grapl** (`docs.grapl.io`) | `https://docs.grapl.io/guides/zaps`: `zap_in` composes an exact-input swap with add-liquidity, *"The correct conversion amount depends on price, range, liquidity, fees, and price impact. There is no optimal-split planner in this instruction."*; `zap_out` *"removes a negative liquidity delta, then swaps the withdrawn principal of one asset into the other"*, *"If the conversion cannot consume all withdrawn input, the zap fails instead of claiming a one-asset exit with hidden leftovers."* | A v4 **zap primitive**, explicitly *"not automatic compounding, a strategy vault, or a multi-venue route optimizer"*; no vault custody or share model. |
| **OpenZaps** | `https://openzaps.vercel.app/`: bounded routes on Robinhood Chain (4663) with allowlisted adapters, 10–500 bps slippage cap, gas ceiling, executor/standing intents, pinned Uniswap v4 pools; *"The contracts remain unaudited."* | Execution/zap infrastructure for v4 **swaps**, not a vault holding fee-earning LP positions. |
| **Fourmate** | `https://www.fourmate.family/docs`: *"No swap-assisted deposits: amounts are deposited as entered; the remainder stays in your wallet."*; wallet-owned v4 positions; "Fourmate supplies no capital"; no fee mechanism. | Deliberately **no** zaps; not a vault. |
| **Bunni v2** | `https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/README.md`: *"**Important:** Bunni v2 has been exploited … and this repo does not have the relevant issues addressed. Please do not use this code in production as is."* | v4 shapeshifting **DEX**, not a share vault; code explicitly unpatched. |
| **MoleSwap `MolePositions`** | `https://raw.githubusercontent.com/penguinpecker/moleswap-pro/main/README.md`: *"ALM vault. Custody of LP positions, keeper-driven rebalancing"*; `MoleHook` maintains a TWAP the vault prices against; keeper bounded by range width, recentre ceiling, dwell time, per-block cap, max TWAP deviation; `MoleFeeCollector` receives vault performance fees; all "deployed and live on mainnet" per the README with addresses. | Deployed v4 ALM vault on the same chain as Weir, but **the README does not disclose whether deposits/withdrawals are single-token** ⇒ **unverified**; needs source reading of the vault to classify. |
| **Aperture** | Closed-source; a decompiled reconstruction of the contract involved in an arbitrary-call exploit exists publicly (gist). | Compromised, v3-era, no v4. |
| **Launch-curve / one-sided launch positions** (lpTOKEN's locked launch position, `sicutdeusvult/PEPE-on-Robinhood-Chain`'s "full PEPE supply as single-sided liquidity", UNILIQUID, Grapl "graduated curves", Range single-sided presets) | Read as described in each README/doc. | One-sided **out-of-range** liquidity or a launch seed; not arbitrary single-token entry and exit into **active fee-earning** liquidity. Excluded per the brief. |
| **`blackhole.finance/whitepaper`** | `503 SERVICE_UNAVAILABLE — DEPLOYMENT_PAUSED` (Vercel). | Unreachable at access time; no claim made. |
| **`grimoire.fi/vaults`** | `404 DEPLOYMENT_NOT_FOUND` (Vercel). | Unreachable at access time; no claim made. |
| **`ozpool/prism`** | See §2.8. | Source-only, M0. |
| **`twofold.fi/docs.html`** | See §2.7. | Entry-only single-token. |

---

## 4. Strongest reusable patterns (what a single-token V4 vault should copy)

1. **Make the single-token path native to the vault, not a bolt-on router.** Weir's `deposit(..., zap: bool, ...)` and `withdraw(..., zapTo: uint8, ...)` are the cleanest verified shape: one call, one min-out guard, one deadline, no cross-router trust. lpTOKEN's `ZapRouter` achieves the same but adds a second contract in the trust path.
2. **Do not hardcode a 50/50 split.** lpTOKEN's `zapIn`/`zapInTarget` take an explicit `swapCounterAmount`/`swapTargetAmount` and the NatSpec states *"this function never assumes a 50% raw-unit split"*; Grapl makes the same point ("There is no optimal-split planner in this instruction"). Weir's docs, by contrast, say the vault *"swaps half"* — simple, but strictly worse for skewed pools.
3. **Let the caller price the conversion.** Every strong implementation requires the caller to pass minima (`minShares`, `min0`/`min1`, `minSwapTargetOut`, `minRouteCounterOut`, `minOutput`) and a `deadline`, and reverts on mismatch (`Slippage`, `InsufficientSwapOutput`, `InsufficientCounterOutput`, `InsufficientTargetOutput`, `MinimumSharesRequired`).
4. **Redeem both legs, then convert one, in the same unlock.** lpTOKEN's `zapOut`/`zapOutTarget` and ZapVault's `withdraw()` both do exactly this; the aggregate output is checked against a single minimum ("*If the conversion cannot consume all withdrawn input, the zap fails instead of claiming a one-asset exit with hidden leftovers*" — Grapl).
5. **Never let a fee-extraction path block an exit.** Weir explicitly never charges on deposits/withdrawals and takes its performance fee at *compound* time; PRISM's design states *"Withdrawals never pausable"*; Topaz and lpTOKEN likewise keep exits ungated. Deposition-before-fee is the right default.
6. **Anti-manipulation: peg-clamp the pool price, and reject deposits off peg.** The USDa vault derives NAV from the pool's own `sqrtPriceX96`, clamps it into a configurable peg band, and refuses deposits when the pool is off peg — a cheap, oracle-free defense. Pair it with a donation-proof NAV ("*never from `token.balanceOf`*").
7. **Do not swap inside the pool you are LPing in, when you can avoid it.** USDa routes rebalance swaps through a separate deep pool with a two-sided balance check; lpTOKEN and ZapVault both convert inside their own pool and therefore pay self-impact — a real limitation to copy around, not to copy.
8. **Minimum-share / inflation defence.** Weir has `MIN_SHARES`; PRISM burns `MIN_SHARES = 1000` to `DEAD` on first deposit; USDa avoids `balanceOf`-based NAV entirely.
9. **Track idle balances explicitly in accounting.** Weir's `Vault` struct carries `idle0`/`idle1`; USDa tracks idle balances internally. Idle reserves are not fee-earning and must not be silently priced as if they were.
10. **Bound the manager role hard and whitelist the venues.** ALPS: `onlyAgent` + `PoolRegistry.isPoolKnown` + adapter-level slippage caps (50 bps swap / 100 bps liquidity). MolePositions: range-width, recentre-ceiling, dwell-time, per-block-cap and max-TWAP-deviation bounds. A compromised manager key should be unable to move user principal — ALPS states this explicitly.
11. **Be explicit about where the single-token conversion happens.** lpTOKEN splits it: native/stable-only routed inputs (`UnsupportedInput`), hookless static-fee route pools only (`HookedPoolNotSupported`, `DynamicFeePoolNotSupported`), ≤ 3 hops, every hop must spend its full input.
12. **Make the single-leg conversion auditable.** lpTOKEN emits `ZappedIn`/`TargetZappedIn`/`RoutedZappedIn`/`ZappedOut`/`TargetZappedOut` with a documented "do not sum these two events" rule; Twofold's `ZappedIn`/`ZappedOut` are minimal but present.

---

## 5. Evidence gaps and unverified claims (explicit)

1. **No on-chain verification.** Without RPC/`eth_call`, every address above is *project-published* except WeirVaults, whose deployment on chain 4663 is independently corroborated by a Sourcify creation+runtime match (`matchId 54166048`, verified 2026-09-30).
2. **Weir**: no public audit and no public source repository located by me; the "68 tests / fork tests" figure is the project's claim; the `zap`/`zapTo` semantics were inferred from the **verified ABI shape + official docs prose**, not from reading the vault's Solidity (Sourcify's full payload exceeded the fetch limit, so I could not read the implementation body).
3. **ZapVault**: the fee path at withdrawal is **unverified** (the `feesAccrued` return of `poolManager.modifyLiquidity` is not consumed in the code I read). Whether the position's trading fees reach the user, remain owed, or revert the unlock is unresolved by my reading.
4. **ALPS**: ERC-4626 share-price manipulation resistance (donation/flash-manipulation) is not documented in the README; treat as unverified. On-chain balances/TVL not checked.
5. **USDa**: `AUDIT.md` (404 at the path tried) — the existence, scope and fixes of the "adversarial security review" are unverified; testnet-only deployment; peg-band configuration authority unspecified.
6. **Steer**: v4 hook vault deposit/withdraw mechanics unverified (docs unreachable).
7. **MoleSwap**: v4 ALM vault deposit/withdraw currency semantics unverified (README silent; source not read).
8. **lpTOKEN**: `LpTokenVault.sol` (52 KB) was not read in full in this session; the `mintPair`/`redeem`/`compound` behaviour is README-observed, while the zap layer is source-verified. The "30 bps fee in backed shares" is README-stated.
9. **No audited, established, v4-native product with both single-token directions was found.** The three strongest matches (Weir, lpTOKEN, ZapVault/ALPS/USDa) split between a young production deployment without a published audit, and hackathon-grade builds with self-reported test suites. **That gap is itself a finding.**
10. **Coverage limits.** I did not exhaustively enumerate every 2026 v4 liquidity protocol; searches were broad (multi-engine, docs + repos + explorer APIs) but not systematic.

---

## 6. Exact search queries used (all on 2026-10-29)

Web search (Exa-backed route after DuckDuckGo's HTML route began serving bot challenges):
1. `Uniswap V4 vault single token deposit withdrawal liquidity position shares`
2. `Bunni V2 Uniswap v4 vaults rebalancing`
3. `Steer Protocol Uniswap v4 vaults rebalancing single sided deposit`
4. `Arrakis Pro Uniswap v4 vaults single-sided deposit withdraw`
5. `Gamma Uniswap v4 vaults strategies positions fee earning`
6. `ICHI v2 Uniswap v4 vault liquidity single token deposit`
7. `Revert Finance Uniswap v4 vault auto-rebalance deposit withdraw`
8. `Range Protocol Uniswap v4 vaults deposits single token Beefy Yearn v4 strategy`
9. `Krystal Charm Aperture Uniswap v4 vault ERC4626 deposit withdraw single token`
10. `Steer Protocol v4 vault deposit withdraw single token ALM Uniswap v4 docs`
11. `Kerf Finance Uniswap v4 liquidity vault single token deposit github contracts`
12. `Robinhood Chain Uniswap v4 vault single token deposit liquidity 4663 protocol`
13. `Steer Protocol "v4" hook vault deposit single token "ERC-4626" liquidity hook docs steer.finance`
14. `Uniswap v4 vault "zap in" "zap out" single token share token fee earning position 2026 launch`
15. `Charm Finance Uniswap v4 vaults 2026 single token deposit withdraw`
16. `ICHI protocol Uniswap v4 support 2026 single sided vault v4 liquidity`
17. `"Weir" liquidity suite Uniswap v4 Robinhood Chain audit contracts github`
18. `Gamma MultiPositionManager v4 vault deposit single sided source code contract`

Direct URL fetches (primary sources):
- `https://docs.gamma.xyz/gamma/llms.txt`, `.../lp-vaults/introduction.md`, `.../lp-vaults/strategies.md`, `.../lp-vaults/guides/providing-liquidity/deposit-liquidity.md`, `.../withdraw-liquidity.md`, `.../lp-vaults/glossary.md`
- `https://docs.arrakis.finance/arrakis-pro`, `https://docs.arrakis.finance/llms.txt`
- `https://docs.steer.finance/`, `https://docs.steer.finance/llms.txt`, `https://docs.steer.finance/integration/uniswap`, `https://steer-protocol.gitbook.io/docs/contracts/vaults`
- `https://www.weir.finance/docs`
- `https://docs.range.fun/llms.txt`, `.../guides/claim-and-withdraw.md`, `.../guides/multiple-positions.md`; `https://range-protocol.gitbook.io/range-protocol/amm-vaults/overview`
- `https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/README.md`, `.../src/periphery/ZapRouter.sol`; `https://api.github.com/repos/Steemhunt/lptoken-contracts/git/trees/main?recursive=1`
- `https://raw.githubusercontent.com/twofoldfi/twofold-contracts/main/src/PoolZapper.sol`; `https://api.github.com/repos/twofoldfi/twofold-contracts/git/trees/main?recursive=1`; `https://twofold.fi/docs.html`
- `https://raw.githubusercontent.com/joaoolucas/zapvault/main/README.md`, `.../contracts/src/ZapVault.sol`
- `https://raw.githubusercontent.com/yanisepfl/alps/main/README.md`
- `https://raw.githubusercontent.com/itskillian/ethglobal-vault/main/README.md`, `.../main/AUDIT.md` (404)
- `https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/README.md`
- `https://raw.githubusercontent.com/penguinpecker/moleswap-pro/main/README.md`
- `https://raw.githubusercontent.com/KerfFinance/kerf-contracts/main/README.md` (404); `https://api.github.com/orgs/KerfFinance/repos` (404)
- `https://api.github.com/search/repositories?q=weir+uniswap+v4+liquidity`
- `https://github.com/ozpool/prism` (README via fetch)
- `https://sourcify.dev/server/v2/contract/4663/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110?fields=abi` and `?fields=all` (truncated)
- `https://robinhoodchain.blockscout.com/api?module=contract&action=getsourcecode&address=0x9bb6…0110` (empty body); `https://robinhoodchain.blockscout.com/api/v2/smart-contracts/0x9bb6…0110` (empty body)
- `https://docs.bunni.xyz/llms.txt` (TLS failure)
- `https://vaults.topazdex.com/docs/zapping`, `https://vaults.topazdex.com/docs/vaults`
- `https://docs.grapl.io/guides/zaps`
- `https://docs.kyberswap.com/user-guide/kyber-earn` (+ `.md`)
- `https://www.fourmate.family/docs`
- `https://openzaps.vercel.app/`
- `https://www.kerf.world/app/pools`
- `https://www.ichi.org/`
- `https://www.blackhole.finance/whitepaper` (503 paused); `https://www.grimoire.fi/vaults` (404)
- `https://developers.uniswap.org/llms.mdx/docs/protocols/v4-hooks/dualpool/guides/create-pool` ("not found")
- `https://github.com/Uniswap/v4-hooks-public/blob/main/src/alf/base/PoolVault.sol` (seen only via search snippet: *"two-asset proportional share accounting"* — not fetched)

---

## 7. One-paragraph summary

Four designs clear the brief's bar as **native, both-direction single-token** matches over v4 fee-earning liquidity (Weir Vaults, ZapVault, ALPS, USDa), at very different maturity levels: **Weir Vaults** (Robinhood Chain 4663) is the only one where both directions live in the vault contract itself — verified from the Sourcify-verified ABI (`deposit(..., zap: bool, ...)`, `withdraw(..., zapTo: uint8, ...)`, `compound`, `previewRedeem`, `vault(id) → {liquidity, idle0, idle1, totalShares}`) — with a full-range position per pool, an internal (non-ERC-20) share ledger, a 5%-at-compound performance fee capped at 10% in code, non-upgradeable contracts, and no published audit; **ZapVault** (Base) and **ALPS** (Base) are hackathon-grade but functionally complete single-token USDC in/out designs over v4 (ZapVault per-user positions on the hookless ETH/USDC v4 pool with a Chainlink-centred range, ALPS an ERC-4626 basket spanning V3 and a v4 hooked pool); **USDa** (Sepolia) is the cleanest *accounting* example (donation-proof NAV, peg-clamped pool price, off-pool swaps, pro-rata fee payout on exit, dual-token exit) but is testnet-only and its cited audit file was unreachable. **lpTOKEN** is a strong conditional match: a dual-sided v4 vault whose single-token entry/exit is provided by a *separately verified* `ZapRouter` (source-read: `zapIn`/`zapInTarget`/`zapInRouted`/`zapOut`/`zapOutTarget`, native-or-stable inputs, hookless static-fee routes, explicit caller-supplied split and minima, no MEV protection, conversion inside its own pool). **Twofold** proves single-token *entry* on a v4 DualPool with an ownerless `PoolZapper` but its exit is in-kind only, and **Kyber Earn's ZaaS** is a productised single-token-in/single-token-out layer over v4 positions without a share model. The dominant near-misses are instructive: Gamma and Steer (excellent v4 vaults, dual-sided only), Range and Fourmate (user-owned positions, no pooled single-token entry), Kerf (right design, no v4 settlement path today), ICHI and Charm (single-token or zapped, but v3), Topaz (single-token zaps, wrong AMM), Bunni v2 (exploited, unpatched), and PRISM (well-specified but M0, unbuilt). The pattern that recurs in every credible design: native single-leg conversion inside the vault's own unlock, caller-supplied split and minima with a deadline, share accounting that never trusts `balanceOf`, minimum-share inflation defence, fee extraction that never blocks exits, and a manager role bounded by a venue whitelist.
