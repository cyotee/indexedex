# Independent Astra original: single-token entry and exit for fee-earning Uniswap V4 vaults

## Identity, question, and scope

- Researcher: independent Astra council member.
- Requested route: `chatgpt-subscription/gpt-6-astra:high`.
- Exposed runtime metadata: `PI_PROVIDER=chatgpt-subscription`, `PI_MODEL=gpt-6-astra`. Effort/variant and agent-role metadata were not exposed by the specific environment fields inspected; I do not independently attest `high`.
- Access date for every source and query below: **2026-10-29**.
- Assignment: the complete common `brief.md` in this run, read before research.
- Original contribution, not coordinator synthesis. No peer responses were read. Coordinator-supplied public leads were treated as leads, not evidence.
- Research only. No shell, Git commands, tests, installation, deployment, wallet operations, external messages, or code/config edits were performed. The only authored file is this response.

## Conclusions

**There are useful actual implementations, but the evidence does not support presenting five independently verified, currently operational, production-grade matches.** The best code-backed examples found are:

1. **lpTOKEN / Steemhunt:** a two-currency V4 share vault plus a separately implemented, explicitly verified single-token zap in both directions. This is the cleanest separation of vault accounting from conversion. Source confirms full-input consumption on exit, rather than silently returning an unwanted residual. Deployment manifests exist, but I did not independently replay their receipts or reconcile every current source change to deployed bytecode. [S1-S4]
2. **WeirVaults:** native single-token deposit and exit branches in a shared full-range V4 vault contract. Sourcify ties the inspected source to the advertised Robinhood Chain address. Important qualification: its swap helper does not assert full input consumption, and the withdrawal settles both resulting deltas. Thus the selected one-token exit is not an unconditional one-output guarantee under partial fills. [S5-S7]
3. **The Pool / LiquidityVaultV2:** a fixed-asset ERC-4626 vault with native `depositWithZap`, `withdrawWithZap`, and `redeemWithZap`, actual V4 PositionManager liquidity, and an external narrow swap adapter. Sourcify provides deployed-source evidence on Arbitrum. The current adapter configuration, available liquidity, and active position were not independently queried. Its owner-managed reference price is not a TWAP. [S8-S11]
4. **Ascnt / USDaVault:** source-verified USDC entry, V4 positions, and intended USDC-or-USDT consolidated exit. **Only a conditional match:** failed conversion deliberately returns both tokens and ignores the requested aggregate `minOut` on that fallback. Its published deployment evidence is Sepolia, not mainnet. [S12-S14]

Two additional designs are particularly useful comparisons: **Twofold** proves why a function named `zapOut` need not be a single-token exit; **OpenZaps** illustrates an attractive periphery design whose current documentation and public route configuration do not establish an operational match. Arrakis, Bunni, PRISM, Blackhole, Kerf, Grimoire, and Steer/EARN supply further exclusions, architectural contrasts, or unresolved leads. [S15-S32]

These are implementation patterns to study, not security endorsements or instructions to deposit.

## Evidence vocabulary and qualification

- **Observed-code (OC):** the function body, interface, or verified-source record was inspected.
- **Observed-document (OD):** a primary author says it. This establishes the statement's existence, not necessarily its truth in deployed execution.
- **Observed-status (OS):** a public endpoint or verification service returned the recorded state.
- **Inference (I):** a consequence of the inspected design; not a tested outcome.
- **Unverified (U):** absent evidence, unavailable source, or a claim not checked against current state.

“Confirmed mechanism” below means both directions exist in inspected code and the V4 position path was traced. It does **not** mean a transaction was executed, an audit was reproduced, or the application is currently usable. “Conditional” is used both for separately required periphery and for explicit execution limitations; the condition is always stated.

### Candidate table

| Design / family | V4 and share evidence | Single-token entry | Single-token exit | Classification and deployment evidence |
|---|---|---|---|---|
| lpTOKEN | `LpTokenVault.unlockCallback` calls `modifyLiquidity`; ERC-20 proportional shares | External `ZapRouter.zapIn` / `zapInTarget`; restricted routed entry also exists | `zapOut` to counter or `zapOutTarget` to target; full-spend assertion | **Confirmed mechanism, conditional on zap and liquidity.** Base/Robinhood/Arc deployment manifests; Base addresses below. [S1-S4] |
| WeirVaults | One direct PoolManager full-range position per PoolId; internal transferable share ledger | Native `deposit` with `zap=true` | Native `withdraw`, `zapTo=1/2`, but partial-fill residual can survive | **Confirmed native mechanism, conditional one-token postcondition.** Sourcify matched Robinhood source/address. [S5-S7] |
| The Pool / LiquidityVaultV2 | ERC-4626; `VaultLP` mints/increases V4 position NFT to vault | Native `depositWithZap`, configured external adapter | Native `withdrawWithZap` / `redeemWithZap`, fixed `asset()` | **Confirmed mechanism, conditional on configured adapter and inventory.** Sourcify matched Arbitrum source/address; current operation U. [S8-S11] |
| Ascnt / USDaVault | ERC-20 shares, four V4 position NFTs; ERC-4626 mutating standard methods disabled | Native custom USDC deposit | USDC or USDT normally; dual-token fallback when swap fails | **Conditional match, not strict single-output exit.** Published Sepolia address and deposit transaction IDs. [S12-S14] |
| Twofold / DualPool + PoolZapper | JIT V4 liquidity; hook shares, ERC-1155 zap ownership | ETH or USDG external zap | `zapOut` pays both currencies, no conversion | **Near match; exit criterion fails.** Documented Robinhood hook/zapper addresses, source inspected. [S15-S17] |
| OpenZaps / range-vault adapters | Docs describe ERC-20 full-range V4 wrappers | Docs describe aeWETH/quote input and half-swap | Docs describe USDG/HOOKR settlement routes | **Documentation-level candidate, not confirmed.** Hookr API returned unconfigured/absent, null vaults, non-live routes. Core factory address is not LP-vault deployment proof. [S18-S20] |
| Arrakis Pro / Modular | Current Pro: issuer-owned NFT vault and per-DEX module; V4 support | Token-heavy bootstrap or historical public-router swap-entry | Historical public route returns both; current Pro consolidation not established | **Near match / missing exit proof.** Do not combine legacy public vault docs with current Pro ownership model. [S21-S25] |
| Bunni V2 | ERC-20 BunniToken; V4 hook/custom accounting and ERC-6909 claims | Pair-amount interface; one-sided general conversion not established | Pair payout; conditional am-AMM queue | **Near match / historical caution.** Exploited source explicitly unrepaired; not a present-status endorsement. [S26-S28] |
| PRISM | Multi-range direct V4 `modifyLiquidity`, ERC-20 shares | Two amounts, no verified conversion | Two-asset in-kind withdrawal | **Source-only near match; exit fails.** Base Sepolia target, Base mainnet post-audit target, not mainnet proof. [S29-S30] |
| Blackhole | Whitepaper topology names `UniswapV3Adapter` | Single asset, adapter converts | Fixed-asset buffer; keeper must unwind if insufficient | **Excluded as V4 example in inspected material.** Same paper explicitly says V4 support deferred despite headline. [S31] |
| Kerf | Indexed README separately lists V4 zap and LP vault | V4 zap claimed; vault integration unproven | LP-vault consolidation described, V4 linkage unproven | **Unverified, do not compose separate products by inference.** Repository/raw source returned 404. [S32] |
| Grimoire | Site says V4 fee-compounding vaults | Explicit single-asset marketing | “Withdraw anytime” does not identify output asset | **Unverified lead.** No inspected exit source/address; docs fetch failed. [S33] |
| Steer / EARN | Official SDK supports full V4 PoolKey; EARN describes managed V4 LP vaults | EARN says supported funding-asset atomic zap | Proportional underlying assets, not single token | **Near match; one-token exit not proved.** [S34-S35] |

## Detailed findings

### 1. lpTOKEN: proportional two-asset core with explicit conversion periphery

**Custody and accounting (OC).** `LpTokenVault` uses one immutable PoolKey and one salt-zero position, with fixed boundary ticks. `unlockCallback` calls PoolManager `modifyLiquidity` and settles both currencies. Shares represent the vault's own portfolio, not the entire pool. Pending fees, idle balances, and applicable launch-fee receivables are distinguished. `compound` collects fees and invests matching balances subject to a liquidity cap and cooldown; unmatched residue remains idle and redeemable. It is not a fixed-USDC ERC-4626 vault. [S2]

**Entry and exit (OC).** `ZapRouter.zapIn` splits the counter token; `zapInTarget` splits the target. The caller supplies the split and minimum swap output/share floor, not a hard-coded 50% assumption. `_depositPair` calls the real vault's `mintPair`, clears allowances, and refunds declined amounts to the payer. `zapOut` first calls the real vault's `redeem`, then sells the entire target leg in the vault pool; `zapOutTarget` reverses that direction. The callback checks spent input equals requested input. Both exit variants enforce final selected-token output and deadline. Routed entry admits native currency or canonical stablecoin through up to three approved-by-structure hookless/static-fee V4 hops; this is not arbitrary-token routing. [S3]

**Limits and trust (I/OD/OC).** An exit sells after removing liquidity, so post-removal depth matters; an otherwise valuable in-kind claim may have an uneconomic or reverting one-token exit. The core's 30-bps share fees, ten-minute compound interval, fixed ranges, and no manager-driven repositioning are meaningful tradeoffs. Idle amounts do not earn swap fees until deployed; fixed ranges can become inactive. The README makes a strong claim that manipulation loses money, while the current `compound` comment explicitly disclaims an oracle/TWAP or flash-manipulation proof. I do not adopt the README's economic guarantee. No independent audit report was verified. [S1-S3]

**Deployment evidence (OD).** The Base manifest names factory `0x3384eD0d272dE35bF6DC516E1eA7d188CEb51793`, vault implementation `0x78aae2fD8f8b09994d0e936Ce4478a7EB8FE92D9`, and router `0xc4C8071D651F093C4A5c2C06e7BFfc163A057DdA`, chain 8453. Router creation transaction: `0x3b4178438b43282f09576f743850dfeeedaa87ef068e62fed9a8466a086d8c10`. Its source commit is separately identified as `e00a49502b2b6e45b583141273e820e55a3997f6`, while the overall manifest uses `a47972337dbf94d99d47da9ce8b1e1008a4b0877`. Repository main resolved to `0ef829fe0c1097b810241aede0b18fc5c5c4a4b7`. These are **different provenance levels**, not proof main equals deployed source. BaseScan returned 403. [S4, S36]

**Relationship:** the launch vault and Arc router are variants/support components in this family, not extra independent qualifying designs.

### 2. WeirVaults: native full-range conversion, with a residual-token caveat

**Verified source and custody (OC/OS).** Sourcify reports creation/runtime `match`, match ID `54166048`, verification time `2026-09-30T03:34:14Z`, for `0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110`, chain 4663. The compilation target is `src/WeirVaults.sol`. Each PoolId holds one full-range position owned directly by the contract, with `sharesOf[poolId][user]`, `totalShares`, `idle0`, and `idle1`. `transferShares` exists; these are not ERC-20 shares. [S6-S7]

**Both directions (OC).** `deposit(DepositParams)` can supply one currency with `zap=true`; `_balance` swaps half the excess value inside the same pool. The add-liquidity operation and settlement share one unlock. Minimum shares and deadline are checked, and leftover credits/refunds go to the depositor. `withdraw(WithdrawParams)` uses `zapTo=1` for currency0 or `2` for currency1: it removes proportional liquidity, includes proportional idle amounts, and swaps the unwanted leg. `_compound` runs first on deposit/withdrawal and reinvests compatible fee balances after the treasury cut. [S7]

**Critical qualification (I from OC).** `_swap` sets an extreme sqrt-price limit but does not require the entire exact-input amount to be consumed. `_withdraw` then settles both net deltas, without asserting the unwanted one is zero. Hence sufficient fill is a condition for a truly one-token exit. No transaction was run to reproduce a partial fill. Also, unpausable `withdraw` does not mean hook-independent withdrawal: it calls `_compound` first, and both compounding and removal pass `hookData` into PoolManager operations. Arbitrary hook failure can still block the flow. [S7]

**Features and trust (OD/OC).** Fees default to 5% of harvested amounts, capped at 10%; the owner changes treasury, fee, and deposit pause. Withdrawal lacks the pause modifier. No TWAP/fair-value check was found in the inspected vault/base conversion path. Full-range liquidity avoids routine range management but does not turn idle dust into fee-earning capital. Weir's separate market-hours hook can alter LP fees, so the exact PoolKey matters. The docs' test count is an author claim, not an audit. Current vault liquidity, current owner, fee setting, and pool-specific hook permissions remain U. [S5-S7]

### 3. The Pool / LiquidityVaultV2: fixed-asset NAV and native zap methods

**Source and V4 proof (OC/OS).** Sourcify reports a runtime match, verified `2026-06-19T12:22:45Z`, at Arbitrum One `0xf79c2dc829cd3a2d8ceec353bdb1b2414ba1eee0`. `VaultLP.deployLiquidity` encodes `MINT_POSITION` or `INCREASE_LIQUIDITY` plus `SETTLE_PAIR`, with the vault as NFT recipient. `removeLiquidity` uses `DECREASE_LIQUIDITY` and `TAKE_PAIR`; fee collection uses a zero-liquidity decrease. This is actual V4 LP plumbing, not only a yield-branded hook. [S9-S11]

**Entry (OC).** `depositWithZap(assets,receiver,assetsToSwap,minOtherOut,minLiquidity,minSharesOut,deadline)` pulls the fixed ERC-4626 asset, calls `IZapRouter.swapExactInput`, deploys balanced liquidity, and computes shares from post-operation NAV gain relative to pre-operation NAV/supply. This attempts to charge entry conversion cost to the entering capital. The ordinary `deposit` does not do that swap and can leave funds idle when the other leg is missing. Requiring nonzero `minLiquidity` is material if the caller needs actual deployment rather than an accepted idle deposit. Unused amounts stay in the shared portfolio, not necessarily refunded. [S10-S11]

**Exit (OC).** Ordinary `withdraw`/`redeem` can revert `InsufficientAssetUseZap`. The zap variants collect yield, remove liquidity, sell other-token inventory if necessary, and require enough fixed asset before completing `_withdraw`. They do not pay an in-kind fallback. The caller supplies a maximum other-token sale and minimum swap output. The exact external venue is **not proved** by the interface: it is an owner-configured adapter; indexed architecture mentions a SwapRouter02 adapter but the current adapter address/code was not read. [S10]

**Accounting and trust (OC/I).** `totalAssets` includes deployed position amounts, both idle currencies, and hook-held reserve escrow/proceeds. It uses live spot bounded against an owner-refreshable reference and clamps valuation of other-token reserves to range bounds. This is neither independent pricing nor a TWAP. Owner re-anchoring and stale-reference blocking are concrete dependencies. All entry/exit methods are pausable; owner controls range, zap router, TVL cap, reserve hook binding, risk bounds, and treasury/performance fee (capped at 20% in the inspected setter). [S9-S10]

**Fee exposure and limits.** The website describes fee donations shared with all in-range LPs, not exclusively this vault. The code collects fees into balances; idle balance is not continuously fee-earning liquidity. Reserve inventory escrowed for a sale is a separate exposure and may not be available for immediate redemption. Normal price moves can trip the reference guard. Because the exit uses a NAV-denominated payout and a shared other-token balance, allocation of conversion cost across withdrawing and remaining holders deserves review; I did not establish its fairness by testing. [S8-S11]

**Status:** deployed-source evidence, not current operational validation. The site showed unfilled live-data fields and low-liquidity messaging in the fetched HTML. The linked repository returned 404, so source was recovered independently from Sourcify. No independent audit report was established. “No off-chain keepers” in one site section should not erase the same site's owner/Safe range management and allowlisted reserve-quote keeper. [S8-S10]

### 4. Ascnt: source proves both intended directions, but also an in-kind fallback

**Architecture (OC/OD).** `USDaVault` uses four V4 NFTs: one full-range backstop and three hook-informed ranges. USDa is an ERC-20 share token. Despite ERC-4626 inheritance, ordinary `deposit`, `mint`, `withdraw`, and `redeem` overloads revert `VanillaEntrypointDisabled`; integration must use custom methods. Fees and tracked idle balances enter NAV. Published deployment: Sepolia vault `0x1638fcb8a56a19e8226e2d15c7b3c2cc2f3c6040`, hook `0xfba82aec5c132db641e22464d7ce7f71994d9040`. Explorer access returned 403. [S12-S14]

**Entry/exit and limiting conditions (OC).** The custom deposit takes USDC, checks a share minimum/deadline and peg band, then attempts rebalancing. `_consolidateAndPay` attempts to sell the unwanted exit token through a separate pool/backup router. On failure it calls `_payDualToken`, which sends USDC and USDT and bypasses aggregate `minOut`. Thus a successful call does not guarantee the requested token-only result. Both entry and withdrawal are pausable. The owner changes peg bands, external swap venue, backup router, and risk parameters. [S14]

**Economic distinction (I).** This assumes a stablecoin peg and another conversion venue; it is not evidence for a volatile target that has liquidity only in its own vault pool. Peg-clamped spot is not a universal manipulation proof. Code also shows deposits can remain idle: `_bestEffortRebalance` may skip, and the normal rebalance path does not unconditionally invest every newly received USDC amount. An “auto-compounding” description therefore cannot establish that every deposited dollar immediately earns trading fees. [S13-S14]

**Status/trust:** a useful open-source prototype and conditional mechanism, not a verified production match. Its repository's self-described adversarial review is not established as an independent third-party audit. Native USDC-only entry and either-stable exit are narrower than arbitrary-asset entry/exit. [S12-S14]

### 5. Twofold: explicit proof of single-input but two-output

`PoolZapper.zapInETH` wraps ETH and uses reference pools; `zapInUSDG` buys the missing leg. Both call the real hook's `addLiquidity`, mint ERC-1155 ownership, clear hook allowances, and refund remaining balances. But `zapOut` only burns the ERC-1155 entry, calls `hook.removeLiquidity`, and transfers **both** currencies. There is no exit swap. This fails the requested withdrawal criterion irrespective of the function's name. [S16]

The underlying DualPool design is nevertheless valuable: reserves are placed into actual V4 positions for each swap and recovered afterwards, while eligible idle assets sit in external ERC-4626 lending vaults. Direct hook shares and zapper-held shares are distinct custody/accounting layers. Documentation names Robinhood hook `0xd1BcbCCa41f3bdb6b4812652959c6dF725ea2Ac0` and zapper `0x8934A298d3E59a632994ac254Dee19112127f2B7`. Lending liquidity/curator restrictions add exit risk. Same-block withdrawal restrictions differ from a general queue. [S15-S17]

The docs contain conflicting pool counts and both “Not yet live” and installed Safe/timelock descriptions. I did not establish current control configuration. The claimed upstream audit and byte-for-byte deployment were not independently reconciled, and the wrappers expressly lack a claimed third-party audit. Its several pools and staking products are not independent vault designs. [S15]

### 6. OpenZaps: distinguish documented architecture from configured routes

The homepage describes aeWETH/USDG full-range shares (`ozRANGE`) with aeWETH entry and USDG exit, including principal/fees. Docs add `HookedRangeVault`, factory admission, two LP adapters, same-pool half-swaps, min-output controls, and refund-to-capsule behavior. These are compelling **documented** patterns, not inspected vault implementations. The public GitHub link returned 404. [S18-S19]

Crucially, direct GET of `/api/hookr/routes` returned HTTP 200 with `configured:false`, `contractsState:"absent"`, `contracts:null`, and all five listed pools having `vault:null`, `live:false`, `tradable:false`, and empty routes. This contradicts treating those Hookr routes as currently executable on that host. It does not prove all other OpenZaps lineages are absent. Factory `0xFC775017b25d2458623E2f3E735A4B750dD8b4E4` is a documented policy-capsule factory, not verified evidence of a seeded LP vault. [S19-S20]

The docs explicitly call vault/adapters unaudited. Their statement that rejecting removal hooks means redemption “can never be blocked” is too broad: consolidation can depend on swaps, token transfer behavior, depth, and route governance. A restricted hook-removal permission check is not a one-token exit liveness proof. Idle/capsule refunds are not automatically invested capital. [S19; I]

## Other candidates and rejected leads

### Arrakis: real V4 family, but do not splice generations

Current fetched documentation describes issuer-owned NFT vaults, offchain management, and two-day controls over core parameter changes. The current audit list names V4 private/public module work and several later reviews. These establish a serious V4 architecture, not a single-token public-vault redemption route. [S21-S22]

Search-indexed historical public-vault documentation describes `swapAndAddLiquidity` and Permit2 entry, but its withdrawal procedure explicitly returns token0 and token1. Direct current fetches redirect to Pro or fail, so the archived/indexed public model is not evidence of current Pro behavior. Historical module registries/router addresses are not a specific active V4 vault. The familiar first public WETH/USDC vault is documented as HOT AMM, so it must not be relabeled as V4. [S23-S25]

Bootstrap inventory held mostly in the issuer's token is likewise not proof of a continuously active one-token-in/one-token-out LP vault. I did not verify a current Pro output-token conversion function or an integrated exit zap. **Near match, exit unverified**, rather than a recommendation inferred from reputation.

### Bunni V2: custom liquidity plus rehypothecation, not a proved single-token exit

`BunniHub.deposit` delegates pair-amount accounting; `withdraw` returns two amounts and `_withdrawUnlockCallback` burns claims/takes both currencies. `IBunniHub` defines pair minima and conditionally requires queued withdrawal when am-AMM has a manager: one-minute delay and a fifteen-minute grace window. An external general zap for both directions was not verified. The inspected Hub uses ERC-6909 claims and hook-managed balances; a conventional persistent `modifyLiquidity` vault position should not be inferred from the Bunni name. [S26-S27]

The official September 4, 2025 postmortem distinguishes active versus idle balances from rehypothecation and explains how repeated tiny withdrawals distorted their relationship. It says withdrawals were unpaused while deposits/swaps remained paused **then**. The current repository warns the relevant exploit issues are not fixed. Neither source establishes operational status on October 29, 2026. Historical exploit transactions establish real deployment/use but do not supply current safe-vault or live-zap evidence. [S28]

### PRISM: actual V4 calls, but incomplete accounting and in-kind I/O

`Vault._handleDeposit`, `_handleWithdraw`, and `_handleRebalance` call PoolManager liquidity functions across multiple ranges; `withdraw` transfers token0 and token1. No one-token exit conversion was found. More importantly, `getTotalAmounts` and `sharePrice` still read only idle balances, with position aggregation described as future integration. Stale comments call implemented methods stubs, illustrating why neither comments nor README alone should determine readiness. [S29-S30]

The README's Base mainnet entry is a post-audit future target, not a deployment. Owner-controlled deposit pause/TVL cap and permissionless strategy-gated rebalancing are useful ideas, but this source is **not a qualifying production template**. I did not run it or perform a comprehensive vulnerability review.

### Blackhole: headline contradicted by its own technical sections

The whitepaper headline includes V4, but its topology specifically uses `UniswapV3Adapter`, and its venue section explicitly says V4 support is deferred for lack of a suitable oracle. Single-asset deposits and withdrawals are described, but redemptions use an idle buffer and revert above it pending keeper unwind. Its indexed code page likewise names a V3 adapter. Accordingly **exclude as a V4 implementation on this evidence**. A direct fetch returned Vercel `503 DEPLOYMENT_PAUSED`; the technical content was available through the search index. No audit report was inspected. [S31, S37]

### Kerf and Levee: avoid a repository-level conjunction error

Kerf's indexed README separately describes `KerfZapV4` and an ERC-4626 `LPVault`; the keeper section expressly concerns V3 positions. This is not proof the vault uses the V4 zap. Repository and raw `LPVault.sol` reads returned 404. Levee's integration table separately lists V4 zap minting, ERC-4626 LP-vault methods, and two-token stock-vault withdrawal; it similarly does not prove a V4 single-token exit integration. **Unverified**, not a confirmed negative about all future/current versions. [S32, S38]

### Grimoire, Steer/EARN, Gamma, and the remaining leads

- **Grimoire:** primary page claims V4 single-asset entry, compounded fees, and anytime withdrawal, but does not identify withdrawal denomination or inspected contract code. Documentation URL ultimately returned 404. Advertised TVL/APR were not independently verified and are not used as qualification evidence. [S33]
- **Steer/EARN:** V4-aware SDK support is explicit. EARN's vault description combines paired or zapped deposits with proportional asset withdrawal. No verified one-token withdrawal route was found. [S34-S35]
- **Gamma:** the official V4 limit-order repository proves one-sided range orders and fee accounting, not arbitrary active-liquidity deposits plus chosen-token redemptions. A filled limit order does not meet the brief. Unrelated lookalike Gamma domains in search results were not treated as official sources. [S39]
- **ICHI, Charm, Krystal, Aperture, Mellow, Decay:** broad and combined queries did not yield sufficient primary evidence for the exact conjunction. These are **unresolved leads**, not findings that they cannot support the behavior. In particular, a single-sided product name, a V3 vault, or a V4 swap integration alone is insufficient. Exact search limitations are recorded below.
- **Revert Stable Hooks:** official page was found, but rendered no substantive body through the available readers. No qualification was inferred from its title. [S40]
- **Uniswap Earn / Morpho:** official documentation says borrower interest in lending vaults; not V4 trading-fee LP vaults, so excluded. [S41]
- **Launchpad/range-order-only examples:** permanent launch liquidity, an out-of-range one-sided position, or a fee-beneficiary staking token does not establish both requested vault directions. Official Uniswap docs distinguish active-range fee earning and range-order conversion. [S42]

## Strongest reusable patterns and limitations

These are research conclusions, not implementation authorization.

1. **Separate proportional ownership from conversion.** lpTOKEN makes the core a claim on two currencies and performs conversion in a narrow router. This avoids pretending a spot-valued scalar NAV is a guaranteed cash exit. The router must remain an explicit dependency in any qualification. [S2-S3; I]
2. **Specify the output postcondition, not just the function name.** lpTOKEN's full-spend check, Weir's possible residual settlement, Ascnt's in-kind fallback, and Twofold's two-token `zapOut` are four different contracts with the user. “Supports single-token withdrawal” should state whether failure reverts, pays two tokens, or waits. [S3, S7, S14, S16; I]
3. **Separate executable exit quote from accounting value.** Pool NAV and Ascnt peg-clamped value can exceed realizable conversion proceeds. A unit share's accounting value is not a large redemption's post-removal sale quote. Pool also depends on owner reference refresh, while Ascnt needs an off-pool market. None proves the general case where the target has only one pool. [S10, S14; I]
4. **Track every reserve by economic role.** Deployed position principal, uncollected fees, collected idle dust, external lending shares, escrowed sale inventory, pending proceeds, and router refunds must not be collapsed into “earning liquidity.” Pool's reserve-sale accounting, Weir's dust fields, and Bunni's exploit are useful contrasts. [S7, S10, S26, S28; I]
5. **Fee exposure follows actual LP economics, not the V4 label.** Static LP fee, dynamic LP fee, hook fee, donation, and external incentive are different cash flows. Pool donations are shared across active LPs; a hook charging traders need not pay a given vault. Idle reserves do not earn LP fees merely because shares include them. [S8, S11, S42; I]
6. **Treat hook permissions and composition as part of exit liveness.** Even an unpausable vault may call a failing hook, swap through exhausted depth, or depend on a frozen token/lending withdrawal. A pre-withdraw compound step creates another failure dependency. [S7, S15, S17; I]
7. **Deployment provenance must include the whole route.** Source code, deployment manifest, verifier match, seeded position, current routing configuration, and successful user transaction are separate evidence. OpenZaps' API and lpTOKEN's per-contract source commits make that distinction concrete. [S4, S6, S9, S20; I]

## Evidence gaps that affect the answer

- No live deposit/withdraw transaction, wallet interaction, simulation, fork test, or bytecode rebuild was performed.
- No current TVL, pool fee setting, owner identity, allowance state, range liquidity, or adapter availability was independently established by RPC.
- A Sourcify match establishes a source/bytecode verification record for the named address. It does not prove economic safety, active funding, canonical dependency wiring, or present application usability.
- Weir's full-input exit guarantee is absent from the inspected helper; Ascnt explicitly relaxes one-output settlement; Pool's configured adapter remains unverified.
- lpTOKEN's deployment manifests are project-authored. Main-source observations were not automatically ascribed to every historical deployment.
- OpenZaps' Hookr route status is negative evidence for that API host/path only, not proof every OpenZaps vault is undeployed.
- No fifth production-quality confirmed match was manufactured to meet the breadth target. The table deliberately includes useful near matches and unresolved candidates.
- This is not an exhaustive audit. Suspected accounting/economic concerns are labeled inferences and were not tested.

## Research process, exact queries, and actual tool limitations

### Exact public search queries

All 32 queries were submitted through the provider's `web.run` search tool. They contained public terms only, never private repository contents. Queries were batched, so a sparse combined result does not prove absence for each constituent lead.

1. `Uniswap v4 vault single token deposit withdraw vault`
2. `Bunni v2 single sided deposit withdrawal documentation`
3. `Arrakis Pro uniswap v4 single token withdraw router`
4. `Uniswap v4 ERC4626 vault single asset withdrawal github`
5. `site.docs.bunni.xyz single sided withdraw`
6. `Bunni v2 docs deposit withdraw single token`
7. `Uniswap v4 vault "single" "withdraw" Gamma ICHI Steer`
8. `"Uniswap v4" "vault" "single-sided" -site:reddit.com`
9. `site:docs.bunni.xyz "withdraw"`
10. `site:docs.arrakis.finance "swapAndRemoveLiquidity"`
11. `"Uniswap v4" "single token" vault -site:reddit.com`
12. `"Uniswap v4" "single-sided" "withdrawal"`
13. `"Uniswap v4" "vault" "zap" Arrakis`
14. `"Uniswap v4" "vault" "withdraw" "Decay"`
15. `"Uniswap v4" "vault" "withdraw" "Steer"`
16. `"Uniswap v4" "vault" "withdraw" "ICHI"`
17. `Arrakis modular router swapAndRemoveLiquidity github`
18. `Bunni v2 single sided withdrawal zap router`
19. `Decay finance uniswap v4 vault github`
20. `Gamma ICHI Uniswap v4 integration vault`
21. `"Bunni" "withdraw" "single"`
22. `"Decay" "vault" "Uniswap"`
23. `"ICHI" "v4"`
24. `"Gamma" "Uniswap v4"`
25. `"Uniswap v4" vault "single" "Revert" "withdraw"`
26. `"Uniswap v4" vault "Aperture" "Krystal"`
27. `"Uniswap v4" vault "Mellow" "Charm"`
28. `"Decay" "Uniswap" vault`
29. `"Uniswap v4" "vault" "single asset"`
30. `"Decay" "finance" "vault"`
31. `"Uniswap v4" "withdraw" "Krystal"`
32. `"Uniswap v4" "Aperture" "Mellow"`

Query 5 is recorded exactly, including the ineffective `site.docs...` spelling; query 9 supplied the proper `site:` form. Direct GETs, source navigation, and the source registry below supplement these searches.

### Access and tooling

- `web.run` supplied search results, extracted pages, and some raw source. Near the end it issued a call-limit warning, then `Too many tokens` / “Do not call this tool again.” No further `web.run` calls were made.
- The deferred-tool catalog search for another public web-search capability returned no match. No substitute search engine was claimed.
- Static `webfetch` remained usable. Several GitHub tree views failed while raw files and GitHub contents APIs worked.
- Kerf repository/raw source and The Pool's linked repository/API returned 404. That is an access observation, not proof a project never existed.
- Blockscout HTML returned no substantive body; its source API was inaccessible/empty through those readers. BaseScan and the Ascnt Sepolia Etherscan page returned 403.
- Blackhole direct access returned `503 SERVICE_UNAVAILABLE`, `DEPLOYMENT_PAUSED`; search-indexed technical sections remained accessible. Grimoire docs ultimately returned 404. Revert's official page yielded no readable body.
- The obsolete Sourcify repository-metadata URL returned an explicit API-v1-removal response. I followed its public v2 endpoint. A nested `metadata.sources` selector was rejected as invalid; no filtered response was claimed.
- Some `webfetch` responses were truncated at 50 KB. Weir's main source was fully visible before dependency truncation. Pool's main implementation was not visible in that truncated source bundle, so it was **not** inferred from the ABI: read-only in-memory JavaScript GET/JSON extraction retrieved the same public record and printed bounded function sections plus `VaultLP`. This used no shell, file creation, package installation, or project execution. The Weir base helper was similarly inspected in memory. Public GETs only.
- The Ascnt raw-file tail was truncated in one fetch; the important deposit/exit/position/admin functions were visible, and relevant tail helpers were also available in the earlier line-indexed raw source. No whole-file audit claim is made.
- Source branches are mutable unless a commit or verification record is identified. Author test counts, audit claims, and “live” labels remain author claims unless separately supported.
- Source-selection preference: official docs, author repositories, verified-source records, and official incident reports. Secondary results were discovery leads only, not proof of qualification.

## Source registry

All accessed **2026-10-29**. Function names are locators; no original code listing is reproduced in this report. URLs are retained for coordinator archival.

| ID | Primary source URL | Evidence used / access note |
|---|---|---|
| S1 | https://github.com/Steemhunt/lptoken-contracts | README architecture, family relationship, deployment claims, security claims. |
| S2 | https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/LpTokenVault.sol | `unlockCallback`, `compound`, constants and proportional ownership. Selected line-indexed source sections inspected. |
| S3 | https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/periphery/ZapRouter.sol | Complete router body read: both entry directions, both exits, callback full-spend check, route validation, refunds. |
| S4 | https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/deployments/base-mainnet.json | Complete project manifest, separate router source commit and receipt/address data. |
| S5 | https://www.weir.finance/docs | Product, fee/hook behavior, advertised addresses. Direct fetch succeeded. |
| S6 | https://sourcify.dev/server/v2/contract/4663/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110?fields=metadata | Verification match, ABI, compilation target and timestamp. |
| S7 | https://sourcify.dev/server/v2/contract/4663/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110?fields=sources | `src/WeirVaults.sol`, `src/base/WeirBase.sol`; full principal contract and settlement helper inspected. |
| S8 | https://pool.nativebtc.org/ | Official product/fee/reserve descriptions and Arbitrum vault address; live-data placeholders preserved as gaps. |
| S9 | https://sourcify.dev/server/v2/contract/42161/0xf79c2dc829cd3a2d8ceec353bdb1b2414ba1eee0?fields=metadata | ABI and admin method metadata; initial display truncated. |
| S10 | https://sourcify.dev/server/v2/contract/42161/0xf79c2dc829cd3a2d8ceec353bdb1b2414ba1eee0?fields=sources | Parsed verified-source record; `LiquidityVaultV2.sol` selected lines 239-335, 341-624, 625-770, 909-941. Runtime match/timestamp read from complete JSON. |
| S11 | Same source bundle as S10, `src/libraries/VaultLP.sol` and `src/interfaces/IZapRouter.sol` | Complete linked LP helper and adapter interface inspected; distinguishes real V4 custody from unverified external swap venue. |
| S12 | https://ethglobal.com/showcase/ascnt-vault-cfe4b | Author's project description and repository link. |
| S13 | https://github.com/itskillian/ethglobal-vault | README, Sepolia addresses and deposit transaction IDs. |
| S14 | https://raw.githubusercontent.com/itskillian/ethglobal-vault/main/vault/src/USDaVault.sol | Custom deposit/withdraw, dual-token fallback, standard-entrypoint disabling, NAV, owner controls, PositionManager calls. |
| S15 | https://twofold.fi/docs.html | Full docs; shares, JIT liquidity, lending, periphery, addresses, and internal status inconsistencies. |
| S16 | https://raw.githubusercontent.com/twofoldfi/twofold-contracts/main/src/PoolZapper.sol | Complete source; single-input routes and two-currency `zapOut`. |
| S17 | https://github.com/Uniswap/v4-hooks-public/blob/main/src/alf/base/PoolVault.sol | Upstream two-asset share ledger, ERC-4626/claim inventory, withdrawal and curator/liquidity assumptions; not proof of Twofold bytecode equivalence. |
| S18 | https://openzaps.vercel.app/ | Documented aeWETH/USDG LP entry and USDG exit; live/design distinction. |
| S19 | https://openzaps.vercel.app/docs | Full docs, HookedRangeVault claims, route constraints, governance/audit gaps, release contradictions. |
| S20 | https://openzaps.vercel.app/api/hookr/routes | Direct HTTP 200 JSON: unconfigured/absent contracts, five null-vault non-live pools. |
| S21 | https://docs.arrakis.finance/text/arrakisModular/overview.html | Direct fetch resolves to current Arrakis Pro content, issuer NFT ownership and offchain management. |
| S22 | https://docs.arrakis.finance/audits.md | Current official audit inventory, reports available by request; not independent report review. |
| S23 | https://docs.arrakis.fi/text/arrakisModular/quickstart/quickstartPublic.html | Search-indexed legacy public entry/exit instructions; later direct open returned 502. |
| S24 | https://resources.arrakis.fi/text/arrakisModular/deployments.html | Indexed historical core/router deployment list; no specific current V4 vault qualification. |
| S25 | https://resources.arrakis.fi/text/modules/hotAmm/publicVaults.html | Indexed flagship public vault identifies active HOT AMM module, not V4. |
| S26 | https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/src/BunniHub.sol | Complete Hub source: pair withdrawal, claims, reserves, pause and queue paths. |
| S27 | https://raw.githubusercontent.com/Bunniapp/bunni-v2/main/src/interfaces/IBunniHub.sol | Pair I/O params and am-AMM queue requirements. |
| S28 | https://blog.bunni.xyz/posts/exploit-post-mortem/ and https://github.com/Bunniapp/bunni-v2 | Official September 4, 2025 incident analysis and current repository warning that exploit issues remain unfixed. |
| S29 | https://github.com/ozpool/prism | README architecture and network targets, not deployment proof. |
| S30 | https://raw.githubusercontent.com/ozpool/prism/main/packages/contracts/src/core/Vault.sol | Complete source: V4 calls, two-token withdrawal, idle-only views and deferred accounting. |
| S31 | https://www.blackhole.finance/whitepaper | Indexed September 2026 paper: V3 topology, buffer withdrawal, explicitly deferred V4; direct 503. |
| S32 | https://github.com/KerfFinance/kerf-contracts | Indexed author README only; direct repository and raw LPVault returned 404. |
| S33 | https://www.grimoire.fi/vaults | Primary marketing page; no verified exit denomination. Docs https://www.grimoire.fi/docs/overview returned 404. |
| S34 | https://steerprotocol.github.io/sdk/ | Official SDK documentation, V4 PoolKey/StateView support; not a verified exit zap. |
| S35 | https://earnonhood.com/docs | Primary EARN description of Steer-managed vaults, zapped entry and proportional withdrawal. |
| S36 | https://api.github.com/repos/Steemhunt/lptoken-contracts/commits/main | Public API reports main commit `0ef829fe0c1097b810241aede0b18fc5c5c4a4b7`; no Git command executed. |
| S37 | https://www.blackhole.finance/code | Indexed primary code-page result names V3 adapter and claims deployed code/audit; claim not independently confirmed. |
| S38 | https://levee.trade/docs/agents | Indexed primary integration table separates V4 zap, ERC-4626 vault, and stock-vault methods. |
| S39 | https://github.com/GammaStrategies/gamma-univ4-limit-order-hook | Official limit-order architecture, not active single-token vault exit proof. |
| S40 | https://revert.finance/stablehooks | Official result found; direct readers exposed no substantive page body. |
| S41 | https://support.uniswap.org/hc/en-us/articles/46865818181901-Earn-on-Uniswap | Official lending-only product description used for exclusion. |
| S42 | https://developers.uniswap.org/docs/liquidity/overview and https://developers.uniswap.org/docs/get-started/concepts/liquidity-providers/range-orders | Official distinction between fee-earning active liquidity, uncollected fees, and one-sided range orders. |

### Supplemental access records

- `https://api.github.com/repos/itskillian/ethglobal-vault/contents/vault/src` identified `USDaVault.sol`; returned blob SHA `8a5ee621f6b35b23262bc4f1c7d363cf58b51e14`.
- `https://api.github.com/repos/ozpool/prism/contents/packages/contracts/src/core` identified `Vault.sol`; returned blob SHA `511b96ac1dac3b359811579343bd539330c87f96`.
- `https://api.github.com/repos/twofoldfi/twofold-contracts/contents/src` identified `PoolZapper.sol`; returned blob SHA `736a509559768bdfc4241822fda2b132829b3b24`.
- `https://api.github.com/repos/Steemhunt/lptoken-contracts/contents/deployments` identified Base, Robinhood, and Arc manifests; only the complete Base manifest was used for detailed receipt evidence.
- `https://docs.arrakis.finance/llms.txt` provided the current documentation index.
- `https://github.com/emilianosolazzi/The-Pool-Adaptive-Reserve-Hook`, its GitHub repository API, and raw `docs/ARCHITECTURE.md` returned 404. The indexed architecture lead was `https://github.com/emilianosolazzi/The-Pool-Adaptive-Reserve-Hook/blob/main/docs/ARCHITECTURE.md`.
- `https://github.com/0pen-Zaps/openzaps` was the primary site's GitHub link; returned 404.
- `https://raw.githubusercontent.com/KerfFinance/kerf-contracts/main/src/LPVault.sol` returned 404.
- `https://raw.githubusercontent.com/ozpool/prism/main/packages/contracts/src/PrismVault.sol` was an unsuccessful guessed filename; corrected using the public contents API to S30.
- `https://robinhoodchain.blockscout.com/address/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110` rendered no body, and its `/api/v2/smart-contracts/` path yielded no usable content.
- `https://basescan.org/address/0xc4C8071D651F093C4A5c2C06e7BFfc163A057DdA#code` and `https://sepolia.etherscan.io/address/0x1638fcb8a56a19e8226e2d15c7b3c2cc2f3c6040#code` returned 403.
- `https://arbiscan.io/address/0xf79c2dc829cd3a2d8ceec353bdb1b2414ba1eee0#code` was inaccessible through `web.run`.
- `https://repo.sourcify.dev/contracts/full_match/4663/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110/metadata.json` returned API-v1 removal guidance.
- `https://docs.sourcify.dev/llms.txt` supplied current v2/read-only retrieval guidance.
- `https://ipfs.io/ipfs/QmdLAaU48akFNaxzQGuqRe2eLkoUJnQd8pAY4GsaRMZ1X8` returned no tool output; no source claim relies on it.

## Final disposition

The brief's breadth target is met by the comparison of independent designs and near matches, not by inflating the count of confirmed products. The most useful code comparison is **lpTOKEN's separated zap**, **Weir's integrated same-pool conversion**, **The Pool's fixed-asset NAV/adapter design**, and **Ascnt's explicit degraded exit**, with **Twofold as a definitive negative control**. Current route and deployment limitations remain material. This original grants no implementation authorization.
