Ask: Independently research fee-earning Uniswap V4 vaults with single-token entry and exit - wanted: a sourced original saved to the assigned response path. For you: Research is complete with six useful designs and primary-source classifications. **The file was not saved**: `apply_patch` is registered but inactive, exact tool search did not expose it, and no permitted activation route exists. I did not substitute another write mechanism. The substantive original follows inline. Now: none - all tasks closed. Next: none.

# Independent Kimi research: fee-earning Uniswap V4 vaults with single-token entry and exit

**Source access date:** 2026-10-29  
**Intended path:** `/Users/cyotee/Projects/indexedex/docs/research/v4-single-token-vaults-20261029-01a18660/members/kimi/response.md`

## Bottom line

I found six materially different designs with primary evidence for single-token entry and some form of single-token exit.

Only lpTOKEN, Weir, and ZapVault have a straightforward either-pool-token/native-USDC flow without an intended in-kind or asynchronous fallback, and each has an important caveat:

- lpTOKEN uses a separate official zap.
- Weir currently shows zero live vault instances.
- ZapVault does not enforce its slippage parameter.

USDa/Ascent, ALPS, and Unoxi are **conditional matches**, not guaranteed single-token exits under all market conditions.

The main implementation lesson is that withdrawal is not merely entry reversed. V4 fee settlement, non-base inventory, manipulation-resistant valuation, and insufficient swap liquidity all affect whether a holder can actually leave in one asset. A two-token in-kind fallback is useful, but must be disclosed rather than counted as single-token withdrawal.

### Claim labels

- **Observed:** directly read in cited public documentation or source.
- **Inferred:** my conclusion from observed code/docs.
- **Unverified:** not established in this pass. Project-published addresses and transaction hashes are deployment evidence, but not independent on-chain verification.

## Candidate classification

| Design | V4 custody and accounting | Single-token entry | Single-token exit | Classification and status |
|---|---|---|---|---|
| **lpTOKEN / lpTOKEN.fun** | Immutable ERC-20-share clone owns one salt-0 V4 position per pool | Either pool leg through official `ZapRouter`; native/stable routed entry | Either pool leg through `zapOut` / `zapOutTarget` | **Confirmed match via integrated, separately verified zap.** Base, Robinhood Chain, and Arc manifests |
| **Weir Vaults** | Shared full-range V4 position with shares | Native either-token deposit with balancing swap | Native either-token or both | **Confirmed documented mechanism; no live instance observed.** Manager deployed, official page showed `0 vaults` |
| **USDa / Ascent Vault** | ERC-4626-derived USDa shares; four V4 positions owned through PositionManager | Native USDC | USDC or USDT after off-pool consolidation; can degrade to dual-token payout | **Conditional match.** Sepolia addresses and deposit transactions published |
| **ZapVault** | Per-user accounting for one V4 position per user; no fungible share token | Native USDC on Base; arbitrary source assets only through LI.FI preprocessing | Native fixed USDC after same-pool ETH sale | **Confirmed code-level match with serious protection caveats.** Base addresses project-published |
| **ALPS** | ERC-4626 USDC shares over a managed V3+V4 basket | Native USDC | Standard USDC redemption when idle/unwind liquidity permits; in-kind fallback | **Conditional match.** Base vault and V4 rebalance transaction published |
| **Unoxi** | Aggregated full-range V4 position; plain shares wrapped into confidential ERC-7984 shares | Individually one pool token, but entry settles only when both round sides meet thresholds | Requested pool token through asynchronous exit round; conversion can be refused | **Conditional asynchronous match.** Ethereum Sepolia deployment and lifecycle transactions published |

No two entries are merely wrappers of the same code family. Twofold/Uniswap DualPool, Kyber Earn, RangePilot, CuratedLP, UniSD, Steer, and the other leads below are not counted as additional matches.

## Detailed profiles

### 1. lpTOKEN: passive two-asset NAV plus an official two-way V4 zap

**Observed — V4 position, shares, and fees.** `LpTokenVault` owns exactly one static-fee V4 position at salt 0 and issues ERC-20 shares. `mintPair` scales the existing position and idle assets proportionally; `redeem` burns shares and removes a pro-rata liquidity slice. `_collectPositionFees` uses zero-delta `modifyLiquidity`; fees become vault NAV and permissionless `compound` later deploys matched free balances without minting shares.

The position range is fixed at bootstrap rather than manager-rebalanced. Public mint/redeem charges 30 bps in backed shares. Out-of-range principal earns no swap fees, and idle fees/residue earn no LP fees until compounded.

**Observed — entry.** `ZapRouter.zapIn` accepts the counter leg, swaps an explicitly sized portion into the target through the vault pool, then calls `mintPair`; `zapInTarget` does the reverse. `zapInRouted` additionally accepts native currency or the configured canonical stable and traverses at most three client-selected hookless, static-fee V4 pools.

The router requires full exact-input spend, caller minima and deadline, validates the factory-registered vault, resets approvals, checks residual balances, and refunds unused mint legs. Direct target entry requires a nonzero partial swap, so this is not a generic arbitrary-token API.

**Observed — exit.** `zapOut` redeems both legs and converts the entire target into counter; `zapOutTarget` does the reverse. Both enforce minimum output and deadline and use exact-input V4 swaps. There is no queue. Native `redeem` remains two-token in-kind withdrawal and is not itself a match.

**Trust and limitations.** Vaults have no pause, upgrade, or administrative withdrawal path; the factory owner admits pools and treasury receives share fees. Zap route quality, fair value, and MEV protection are explicitly left to the caller. Entry and exit swaps through the vault's own pool create price impact and can interact with thin liquidity; min-out is essential.

The compound cap is an economic manipulation cost bound, not an oracle/TWAP fair-value proof. I found extensive project-reported tests but no third-party audit report in the reviewed sources; tests were not run.

**Deployment evidence.** The Base manifest records chain ID 8453, source commits, runtime hashes, creation transactions, and successful receipts:

- Factory: `0x3384eD0d272dE35bF6DC516E1eA7d188CEb51793`
- Vault implementation: `0x78aae2fD8f8b09994d0e936Ce4478a7EB8FE92D9`
- Current zap: `0xc4C8071D651F093C4A5c2C06e7BFfc163A057DdA`

The README also lists Robinhood Chain and Arc deployments. **Unverified:** I did not independently query those addresses or receipts.

Sources: [repository](https://github.com/Steemhunt/lptoken-contracts), [`LpTokenVault.sol`](https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/LpTokenVault.sol), [`ZapRouter.sol`](https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/periphery/ZapRouter.sol), [Base manifest](https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/deployments/base-mainnet.json).

### 2. Weir: native single-token full-range vaults, but zero live vaults shown

**Observed — mechanism.** Official documentation says each vault holds one full-range position on any initialized V4 pool, tracked as shares. Either pool token can be deposited; the vault swaps half in the same transaction. Every deposit, withdrawal, and compound first reinvests earned fees. Withdrawal supports either token or both. UI simulation supplies min-shares/min-tokens from user slippage.

A full-range position does not go out of range, although pool hooks can change LP fees and idle fees do not earn until reinvested. Weir Gates can add session, surge, and curator fees.

**Fees and trust.** Documentation states 5% of vault trading fees at compound, capped at 10% in code, no deposit/withdraw fee, non-upgradeable contracts, and pause only blocks new deposits—withdrawals remain available. It reports 68 tests including Robinhood Chain fork tests. No third-party audit was cited in the reviewed page.

**Deployment/status evidence.** Official docs list:

- Robinhood Chain `WeirVaults`: `0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110`
- PoolManager: `0x8366a39CC670B4001A1121B8F6A443A643e40951`

However, the official vault page accessed the same day explicitly displayed **“Live vaults 0 vaults.”** Therefore the mechanism is documented and the manager is published, but I found no evidence of an active vault holding user liquidity.

**Unverified:** I did not obtain Weir's function-level source, so native entry/exit claims are verified against official product documentation rather than independently read Solidity. Do not infer an audited or populated deployment from the manager address.

Sources: [Weir docs](https://www.weir.finance/docs), [official vault page](https://www.weir.finance/vaults).

### 3. USDa / Ascent: fee-safe pro-rata slicing and conditional single-stable exit

**Observed — positions and shares.** `USDaVault` is an ERC-4626-derived, USDC-denominated share vault with standard 4626 mutating entrypoints disabled in favor of custom functions. It holds one full-range backstop plus three hook-driven USDC/USDT V4 positions through PositionManager.

NAV includes position principal, uncollected fees, and internally tracked idle USDC/USDT, not raw `balanceOf`. Out-of-range bands stop earning; idle balances do not earn LP fees until deployed. No vault performance fee appears in the reviewed code.

**Observed — entry.** Custom `deposit(usdcAmount,minShares,deadline)` pulls only USDC, checks the pool is inside the owner-configured peg band, prices shares from pre-deposit NAV, and performs best-effort deployment/rebalance. Initialization uses an off-pool swap venue to balance USDC into USDT.

**Observed — withdrawal and fee accounting.** Custom `withdraw(shares,wantToken,minOut,deadline)` accepts USDC or USDT. It first uses idle USDC when possible, otherwise `_sliceAllPositions` removes a pro-rata slice of all four positions.

Because a V4 decrease settles **all** accrued position fees, the code computes and retains other holders' `(1-f)` fee surplus in idle accounting rather than overpaying the withdrawer. `_consolidateAndPay` sells the unwanted leg through a separate V4 pool or backup router. If both fail, `_payDualToken` pays USDC+USDT. **Single-token withdrawal is therefore conditional, not guaranteed.**

**Trust and limitations.** NAV clamps spot into a peg band and deposits reject off-peg spot; internal swaps use off-pool venues with min-out and balance guards. This reduces but does not eliminate stablecoin depeg, venue-liquidity, and multi-block economic risks.

The owner can change swap venue, peg/risk parameters and pause; `withdraw` checks `paused`, so pause blocks the normal exit. The README describes an adversarial self-review and fixed critical findings, not an independent audit.

**Deployment evidence.** README publishes:

- Sepolia vault: `0x1638fcb8a56a19e8226e2d15c7b3c2cc2f3c6040`
- Hook: `0xfba82aec5c132db641e22464d7ce7f71994d9040`
- Pool initialization and two USDa mint transactions

This is testnet and project-published evidence, not production deployment proof.

Sources: [repository/README](https://github.com/itskillian/ethglobal-vault), [`USDaVault.sol`](https://raw.githubusercontent.com/itskillian/ethglobal-vault/main/vault/src/USDaVault.sol), [ETHGlobal listing](https://ethglobal.com/showcase/ascnt-vault-cfe4b).

### 4. ZapVault: native fixed-USDC entry/exit, weak execution protections

**Observed — position model and fees.** `ZapVault` directly calls V4 PoolManager through `IUnlockCallback`; it does not use PositionManager NFTs or a custom hook. Each user has one recorded position and config rather than fungible shares.

Deposit swaps USDC to native ETH inside the ETH/USDC pool and adds concentrated liquidity. Withdraw removes liquidity and swaps recovered ETH back to USDC. V4 fee proceeds are included in removal deltas. Out-of-range positions stop earning until rebalanced; idle residual tokens are not part of a clear per-user NAV/share model.

**Observed — entry and exit.** Router `depositWithAmount` and Composer-compatible `deposit` transfer USDC and call vault `deposit`. Cross-chain/arbitrary-token entry is not native vault functionality: LI.FI must first bridge/swap to USDC on Base. `withdraw()` is user-initiated and pays only USDC, with no queue.

**Serious limitations observed in source.** Although the router accepts a `slippage` config value, the vault never reads it in deposit, rebalance, or withdraw. Swaps use extreme price limits and there is no min-out on user payout. `rebalance(user)` is permissionless and does not check `needsRebalance` or the configured threshold.

The owner can rotate the router and call `rescue` on arbitrary idle tokens; residual balances and donations therefore require careful trust analysis. Chainlink ETH/USD centers ranges with a one-hour staleness check, but the actual token split uses pool state and heuristic range proportions, not exact target-ratio sizing.

**Deployment and trust.** README publishes:

- Base vault: `0xc77d3CCFba9354db99972D11d994676d55709d5C`
- Router: `0x3F75D8E28A148380B186AcedcDE476F8E1CFDd78`

**Unverified:** I did not independently confirm bytecode or transactions and found no third-party audit. Treat this as a useful hackathon architecture, not a production-safe reference without added slippage, residual accounting, and permission review.

Sources: [repository](https://github.com/joaoolucas/zapvault), [`ZapVault.sol`](https://raw.githubusercontent.com/joaoolucas/zapvault/main/contracts/src/ZapVault.sol), [`ZapVaultRouter.sol`](https://raw.githubusercontent.com/joaoolucas/zapvault/main/contracts/src/ZapVaultRouter.sol), [ETHGlobal listing](https://ethglobal.com/showcase/zapvault-ax5y5).

### 5. ALPS: single-USDC ERC-4626 basket with an explicit in-kind escape hatch

**Observed — custody and fees.** `ALPVault` is an ERC-4626 USDC vault holding V3 and V4 LP NFTs through whitelisted adapters. `UniV4Adapter` uses real PositionManager `MINT_POSITION`, `DECREASE_LIQUIDITY`, `BURN_POSITION`, `TAKE_PAIR`, and fee collection actions.

Deposits and withdrawals harvest positions first. Base-side fees update `bookTAV`; non-base value enters market NAV. Idle USDC reserves earn no LP fees, and out-of-range positions wait for agent rebalancing. The deployed V4 ETH/USDC pool uses the Alphix dynamic-fee hook.

**Observed — entry.** Standard ERC-4626 `deposit`/`mint` accept USDC and issue shares. `depositWithMin` adds min-share protection. Allocation is performed afterward by the agent, not necessarily atomically with the user's deposit.

**Observed — withdrawal.** Standard `redeem`/`withdraw` pays USDC and auto-unwinds positions if idle USDC is insufficient. Crucially, V4 `getTwapSqrtPriceX96` returns 0 because V4 PoolManager has no built-in oracle; the source says this skips V4 auto-unwind swaps rather than swapping behind a spot-derived floor.

Consequently USDC exit depends on idle/available unwind liquidity and can fail where V4 conversion is required. `redeemInKind` is a separate pro-rata multi-token escape hatch that remains available while paused.

**Trust and limitations.** The vault uses asymmetric settlement: deposits price against `MAX(book,market)`, redemptions against `MIN(book,market)`, plus same-block mint/redeem lockout and optional entry/exit fee capped at 2%.

This is stronger than raw spot NAV, but market valuation still uses spot and in-kind minima must be derived externally from TWAP decomposition. Owner rotates roles; guardian pauses and manages registry; agent adds/removes/swaps only whitelisted pools. Normal withdrawal is pausable; in-kind exit is not.

README openly notes a VM `.env` hot key, future Safe/Turnkey hardening, and cap policy not yet actuating. No third-party audit was cited.

**Deployment evidence.**

- Base ALPVault: `0x3F0e6cef3a75f52F1E55806Afe40317f51199CaE`
- UniV4Adapter: `0xB6871C8cd995fF015DBa7373b371426E80cBBCF0`
- V4 recenter transaction: `0x9e108bd4e7b50bb07b5a3629f50eb2579263ea7fcdaffe5e506bd7899b581dc9`

I did not independently replay them.

Sources: [repository](https://github.com/yanisepfl/alps), [`ALPVault.sol`](https://raw.githubusercontent.com/yanisepfl/alps/main/contracts/src/ALPVault.sol), [`UniV4Adapter.sol`](https://raw.githubusercontent.com/yanisepfl/alps/main/contracts/src/adapters/UniV4Adapter.sol), [ETHGlobal listing](https://ethglobal.com/showcase/alps-1yzq7).

### 6. Unoxi: confidential asynchronous rounds that net entry and exit conversion

**Observed — V4 and shares.** `UnoxiVault` owns the pool's only full-range V4 position. Users receive plain shares wrapped into confidential ERC-7984 shares. `compound` performs zero-delta fee collection and reinvests whatever pair of idle assets is available without minting shares.

One-sided fees remain idle until the other leg appears. Because only the vault may provide liquidity, the pool can be thin and drift; that is an explicit design limitation.

**Observed — entry.** An individual contributes token0, token1, or both as encrypted orders, so one-token user input is real. But `sidesSatisfied` requires both sides to meet `minPartiesPerSide`, and settlement adds both aggregate legs without a swap. It is asynchronous, not an atomic zap.

The Sepolia deployment sets minimum round age 600 seconds and minimum three participants per side. Entry cannot settle from a one-sided round at an in-range price.

**Observed — exit.** `UnoxiExitRounds` takes shares on side 0 or side 1 according to the token requested. `redeemShares` removes aggregate liquidity, values each side at an external reference, and swaps only the mismatch between returned assets and requested assets. A balanced round performs no swap.

`_requireTradeablePool` checks post-swap drift, default 100 bps, and reverts if excessive; the round then refunds at par so users can retry. Single-token exit is therefore real but conditional and asynchronous.

**Trust and limitations.** The design depends on Nox confidential computation/gateway and an external `IReferencePrice`; it does not hide round membership, side, aggregate totals, or rates. Small anonymity sets permit subtraction attacks. Conversion refusal creates wait/liveness risk. Owner can set thresholds; permissionless dispatch/settle reduces keeper censorship. No production deployment or independent audit was found.

**Deployment evidence.** `deployments/sepolia.json` records:

- Chain ID 11155111
- PoolManager: `0xE03A1074c86CFeDd5C142C4F04F1a1536e203543`
- Vault: `0x0480Ae5a4f7d53e00e2C06cF3daA42F0894b5AdA`
- Exit rounds: `0x2dd37c8bf3747574627e264d6b2cb0fd421742f5`
- Hook: `0xE5e4f1c3F908a983B50E9fD025B4c7f4DBE58A00`

README links real Sepolia lifecycle transactions, including compound and exit. These are testnet facts, not mainnet security evidence.

Sources: [repository](https://github.com/skar8848/unoxi), [`UnoxiVault.sol`](https://raw.githubusercontent.com/skar8848/unoxi/main/contracts/UnoxiVault.sol), [`UnoxiExitRounds.sol`](https://raw.githubusercontent.com/skar8848/unoxi/main/contracts/UnoxiExitRounds.sol), [Sepolia manifest](https://raw.githubusercontent.com/skar8848/unoxi/main/deployments/sepolia.json).

## Near matches and exclusions

| Lead | Why it is not counted as a qualifying vault |
|---|---|
| **Twofold / Uniswap DualPool** | Official docs verify atomic ETH/USDG zap-in and fee/yield-bearing shares, but zapped `zapOut` pays **both legs**. Single-token entry only. [Docs](https://twofold.fi/docs.html) |
| **Kyber Earn liquidity pools** | Official docs verify V4 positions, 1–5-token zap-in, and single-asset Zap Out through the aggregator, but these are user V4 positions, not a shared vault/share design. Partner Vaults start with ether.fi and do not establish V4 LP custody. Smart Exit returns pool ratio, not one token. [Docs](https://docs.kyberswap.com/user-guide/kyber-earn) |
| **RangePilot** | Owner `deposit(poolId,amount0,amount1)` is two-sided; single-sided LP is explicitly roadmap. Owner withdraw/emergency exit is not evidence of token consolidation. [Repository](https://github.com/RangePilot/RangePilot) |
| **CuratedLP** | ERC-20 shares over a V4 hook, but deposit is wstETH+USDC and withdrawal returns both proportionally. [Repository](https://github.com/SakshiShah29/CuratedLP) |
| **UniSD** | Single whitelisted-stable deposit into JIT V4 liquidity, but burn pays a proportional basket of all stables. [ETHGlobal](https://ethglobal.com/showcase/unisd-au1uq) |
| **Steer vaults** | Official functions queue `token0Amount,token1Amount` and withdrawals specify `_LPTto0,_LPTto1`; no single-token two-way flow verified. [Docs](https://steer-protocol.gitbook.io/docs/contracts/vaults) |
| **Levee** | Its one-token V4 zap mints a position to the user's wallet; documented `LPVault` single-token vault is V3, while Levee-pool vaults are separate products. Do not infer a V4 vault+zap integration. [Zap docs](https://levee.trade/docs/zap), [vault docs](https://levee.trade/docs/vaults) |
| **Kerf / Shiro** | Official search material describes single-token `LPVault` as V3; Kerf pool page says listed V4 pools have no adapter. [Vault docs](https://kerf-clone.vercel.app/docs/vaults), [pool page](https://www.kerf.world/app/pools) |
| **PRISM** | Repository explicitly says current status M0; vault core, zaps, and launch are future milestones. [Repository](https://github.com/ozpool/prism) |
| **Arrakis migration example** | Demonstrates migrating a two-sided V4 NFT into an Arrakis vault and gives helper/beacon addresses, not single-token entry and exit. Current Pro should not be conflated with legacy public-vault docs. [Example](https://github.com/ArrakisFinance/univ4-migration-example) |
| **Bunni v2** | Real V4 code family, but repository begins with an explicit exploit warning and says issues are not addressed and code must not be used in production. I did not establish both single-token directions; it is not a reusable safe match. [Repository](https://github.com/Bunniapp/bunni-v2) |
| **Topaz vaults** | Strong single-token zap-in/out documentation, but underlying managed CL is Slipstream, not Uniswap V4. [Docs](https://vaults.topazdex.com/docs/developers/contracts) |
| **MaxFi** | Official supported venues are Uniswap V3, Aerodrome, and PancakeSwap. Single-sided limit orders are not arbitrary two-way V4 vault entry/exit. [Docs](https://www.maxfi.tech/docs) |
| **Revert v4lend** | V4 LP NFT collateral lending and automation, not a fee-share vault with single-token LP deposit/withdraw. [Repository](https://github.com/revert-finance/v4lend) |
| **Uniswap DualPool / OpenZeppelin rehypothecation** | Useful proportional-share/JIT primitives, but base flows are two-sided; an integration's zap must be verified separately, as Twofold illustrates. [DualPool docs](https://developers.uniswap.org/docs/protocols/v4-hooks/dualpool/concepts/jit-liquidity) |
| **unisafe** | Official site claims NFT-owned V4 manager vaults with single-token funding and chosen-token withdrawal on four networks. I did not obtain addresses or function-level source, so this remains an unverified additional candidate rather than a counted match. [Site](https://unisafe.envelop.is/) |
| **BTR Supply ALM** | Search index describes a single-asset ERC-4626/7540 vault with V4 adapters, but the repository page/API/raw source could not be retrieved. Both directions and deployment remain unverified. [Indexed repository URL](https://github.com/btr-supply/alm-contracts) |
| **OpenZaps** | Generic bounded execution infrastructure, not itself evidence of a V4 LP share vault or integrated two-way vault zap. [Site](https://openzaps.vercel.app/) |
| **Blackhole / Grimoire supplied URLs** | Blackhole returned Vercel `DEPLOYMENT_PAUSED`; Grimoire returned `DEPLOYMENT_NOT_FOUND`. Searches did not establish the requested vault mechanics. [Blackhole](https://www.blackhole.finance/whitepaper), [Grimoire](https://www.grimoire.fi/vaults) |
| **Gamma, ICHI, Charm, Mellow, Decay, Aperture** | Broad searches did not yield primary evidence sufficient to classify both directions. They are unresolved, not asserted incompatible. Krystal's retrieved contract/docs material was V3-oriented. |

Uniswap's own support documentation also cautions against a common false positive: adding one token because a V3/V4 range is wholly out of range is single-sided liquidity, but not arbitrary single-token entry and exit into active fee-earning liquidity. [Uniswap support](https://support.uniswap.org/hc/en-us/articles/7423759991821-Do-I-need-to-hold-both-tokens-to-provide-liquidity-using-Uniswap-v3-and-v4)

## Strongest reusable patterns

1. **Use an explicit two-layer exit.** lpTOKEN separates native two-asset redemption from a validated single-asset zap; ALPS separates USDC redemption from in-kind escape. Consolidation happens when liquidity permits, in-kind when it does not.
2. **Account for V4's all-fees settlement on partial decreases.** USDa's per-position surplus retention and ALPS's harvest-before-peel are directly reusable. A naive pro-rata decrease can give one withdrawer everyone else's accrued fees.
3. **Keep valuation and execution prices distinct.** ALPS's book/market rails, USDa's peg clamp, and Unoxi's external reference show different defenses. A min-out computed from the same manipulable spot used for NAV is not independent protection.
4. **Do not assume a V4 TWAP exists.** ALPS deliberately skips V4 auto-unwind swaps when no manipulation-resistant reference exists. A production design needs a hook-provided oracle, external market/TWAP, or disclosed asynchronous/in-kind path.
5. **Bound zaps atomically and verify residual balances.** lpTOKEN's exact-input full-spend checks, route restrictions, deadlines, minima, approval reset, and residual-balance assertions are a solid checklist. ZapVault demonstrates why a configurable slippage field alone proves nothing.
6. **Batch only when its trade-off is wanted.** Unoxi's two-sided rounds avoid self-inflicted pool displacement and net exits, at the cost of latency, participation thresholds, and possible refusal.
7. **Treat withdrawal availability as a separate trust property.** Weir documents withdrawals while paused; ALPS keeps in-kind redemption unpaused; USDa and standard ALPS redemption are pausable. These are materially different user guarantees.

## Evidence gaps and tool limitations

- No shell, Git, tests, builds, installation, deployment, wallet, or external messaging was used. No peer response was read.
- I did not independently query chain state, verify bytecode, or replay transaction hashes. “Deployed” means project-published addresses/manifests/receipts unless explicitly narrowed.
- Absence of an audit means **no third-party audit was found in the sources reviewed**, not proof none exists. Project test counts and self-reviews were not executed or treated as audits.
- Several raw files exceeded the fetch tool's 50 KB rendering limit: `ALPVault.sol`, `USDaVault.sol`, and `LpTokenVault.sol`. Functions quoted here were visible; unseen tails were not used to infer additional guarantees.
- `docs.bunni.xyz` and `blog.bunni.xyz` fetches failed TLS handshake; Bunni's public GitHub warning was accessible and used instead.
- `docs.arrakis.fi` reported an expired certificate. The Arrakis migration repository was accessible.
- BTR's indexed repository returned GitHub/API/raw 404s. Blackhole and Grimoire returned paused/not-found Vercel deployments.
- Search providers intermittently returned Exa HTTP 429 and DuckDuckGo/Startpage/Mojeek/Ecosia/Google bot challenges. Failed queries are marked below; no challenge bypass or API-key change was attempted.
- **Assigned write failure:** `tool_search` and runtime `tool_schema()` did not expose an active `apply_patch`. A dynamic `tool.apply_patch` attempt returned “Tool apply_patch is registered but inactive.” No file was created or modified.

## Exact public search queries

Successful or partially successful queries, allowing that some provider fallbacks still failed:

1. `Uniswap V4 vault "single-sided" deposit withdrawal liquidity manager`
2. `Uniswap V4 vault "single token" deposit withdraw`
3. `Uniswap V4 liquidity manager zap deposit withdraw vault`
4. `Weir finance Uniswap V4 vault GitHub WeirVaults`
5. `site:levee.trade/docs vault shares withdraw one token Uniswap V4`
6. `site:github.com/btr-supply/alm-contracts Uniswap V4 withdraw deposit single asset`
7. `Kerf Finance Uniswap V4 vault single token withdrawal Shiro`
8. `Uniswap V4 auto compounding vault "withdraw" "single token"`
9. `Blackhole Finance Uniswap V4 vault single token withdrawal whitepaper`
10. `Grimoire finance vaults Uniswap V4 single token deposit withdrawal`
11. `site:docs.bunni.xyz v2 single token deposit withdraw zap vault`
12. `MaxFi Uniswap V4 vault single token withdraw docs`
13. `"Uniswap V4" "single-asset" vault withdrawal`
14. `"Uniswap v4" vault "Deposit either token" withdraw`
15. `"Uniswap V4" "ERC-4626" "withdraw" vault fees`
16. `"Uniswap V4" "auto-compounding vault" "single"`
17. `github Uniswap V4 LP vault zapOut shares`
18. `"Uniswap v4" "one token" vault shares withdraw`
19. `site:ethglobal.com/showcase Uniswap v4 vault single token LP`
20. `Uniswap V4 managed vault single sided deposits withdrawals ERC20 shares`
21. `Alps Automated Liquidity Positions ERC4626 vault Base github`
22. `"ALPS" "Automated Liquidity Positions" Uniswap V4 withdraw USDC`
23. `Arrakis Bunni Gamma ICHI Uniswap V4 vault single token deposit withdrawal`
24. `Steer Revert Charm Aperture Uniswap V4 vault single token zap withdrawal`
25. `Mellow Decay Krystal Uniswap V4 vault single token withdrawal`
26. `Topaz Dex Vaults Uniswap V4 zapper single token`
27. `site:github.com/KyberNetwork Uniswap V4 vault zap out single asset`

Queries that failed all configured providers or produced no usable result:

28. `site:github.com Uniswap V4 ERC4626 vault single sided`
29. `site:docs.arrakis.fi Uniswap V4 single token deposit withdraw vault`
30. `"Uniswap v4" "single-token deposits" vault`
31. `"Uniswap v4" "single token withdrawals" vault`
32. `"Uniswap v4" "single asset" "shares"`
33. `site:github.com/timeless-fi bunni v2 zap single token withdraw`
34. `site:docs.kyberswap.com "Uniswap V4" "Zap Out" vault`
