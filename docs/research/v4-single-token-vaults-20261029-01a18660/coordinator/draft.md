# Council comparison: fee-earning Uniswap V4 vaults with single-token entry and exit

Frozen advisory revision: **v4-vault-comparison-r1**, 2026-10-29. This file will not be revised after advisory dispatch; corrections belong in REPORT.md and resolution.md.

## Answer and scope

Seven independent implementations are useful comparisons: **lpTOKEN, Weir, The Pool, ALPS, USDa/Ascnt, Unoxi, and ZapVault**. They are not seven equally established production matches. Five are pooled-share architectures; Unoxi adds asynchronous confidential settlement; ZapVault is per-user position custody rather than a pooled fungible vault. Counting architecture families, the seven comprise six shared-capital designs and one separately accounted per-user design. Names, wrappers and deployments within one family are not counted separately.

The strongest starting comparisons are lpTOKEN's two-currency core plus explicit zap, Weir's integrated conversion, and The Pool's fixed-asset NAV plus configured adapter. ALPS adds managed multi-pool exposure; USDa adds stable-pair fee-slicing and degraded settlement; Unoxi adds batch netting. ZapVault shows a simple fixed-USDC path but has substantial execution-protection limitations.

Research means public source/document inspection, not executed deposits, bytecode rebuilds, live liquidity checks or an audit. A verifier match establishes a verification record, not a funded position or present app availability. No current TVL/APR or safety claim is adopted. Sources were accessed October 29, 2026.

## Qualification table

| Family | Held liquidity and fee exposure | One-token input | One-token output | Qualification / evidence |
|---|---|---|---|---|
| lpTOKEN + official ZapRouter | One fixed-range V4 position; ERC20 portfolio shares; accrued fees and idle balances in claim | Either leg; restricted native/stable routed entry | Either leg; incomplete conversion reverts | Code-backed both directions through separate periphery. Publisher manifests for Base/Robinhood/Arc; current main not reconciled to every deployed version. [P1-P3] |
| WeirVaults | Full-range direct PoolManager position per pool; internal share ledger; reinvest before I/O | Either leg, native zap branch | Either leg intended; partial fill can leave second leg | Verified-source native mechanism; no all-or-revert one-output postcondition. Advertised Robinhood manager, UI showed zero vaults; no populated vault independently established. [P4-P6] |
| The Pool / LiquidityVaultV2 | V4 position NFT; fixed ERC4626 asset; idle and reserve-sale inventory/proceeds in NAV | Fixed asset via depositWithZap | Fixed asset via withdrawWithZap/redeemWithZap, or revert | Verified-source zap methods on Arbitrum. Configured adapter, current funding and live use not queried. [P7-P8] |
| ALPS | Managed V3+V4 position basket; USDC ERC4626 shares; trading fees in portfolio | USDC; capital can remain idle pending allocation | USDC if idle/unwind proceeds suffice; separate in-kind escape | Conditional cash exit: current V4 adapter returns zero TWAP and automatic V4 conversion is skipped. Base deployment/rebalance evidence is publisher-provided. [P9-P11] |
| USDa / Ascnt | Four USDC/USDT V4 NFTs; ERC20 NAV shares; proportional fee-surplus retention | USDC custom entry | USDC or USDT normally; automatic two-token fallback on swap failure | Conditional, not strict one-output guarantee. Standard ERC4626 mutators disabled; testnet deployment evidence only. [P12-P13] |
| Unoxi | One full-range V4 position; plain shares/confidential wrapper; balanced fees compounded | Individual one-token order; entry round needs both sides | Requested leg via asynchronous exit round; may refuse and refund shares | Conditional asynchronous comparison, not atomic zap. Sepolia only; confidentiality infrastructure/reference dependency. [P14-P16] |
| ZapVault | Per-user direct V4 concentrated position; no pooled share token | USDC; optional external LI.FI preprocessing | USDC by removing and selling ETH in same pool | Code-backed per-user design/prototype. No user min-out or deadline on withdrawal; published Base addresses not independently reconciled. [P17-P19] |

## Profiles: features and limitations

### lpTOKEN: proportional vault with an explicit conversion layer

The vault owns a salt-zero V4 position and mints transferable ERC20 claims. Native `mintPair` and `redeem` operate in both currencies. Official `zapIn`/`zapInTarget` swap a caller-sized portion then mint; `zapOut`/`zapOutTarget` redeem then sell the unwanted leg. The router checks factory registration, deadlines, minima and full input consumption. It refunds unused mint assets rather than silently retaining route balances. [P1-P3]

Fees accumulate in the portfolio; capped, permissionless, swapless compounding invests matched balances, leaving unmatched assets idle. A fixed range is not automatically always active. The core charges 30 bps in backed shares on mint and redeem, separate from swap fees. Conversion occurs through the vault pool after liquidity removal on exit, so post-removal market depth matters. Routes are not arbitrary-token: routed entry admits native/canonical stable through at most three hookless static-fee V4 hops; exit is either underlying token. Caller minima are not a fair-value oracle or MEV defense. [P1-P3]

Publisher manifests support deployed-address claims, but current source and all historic deployment versions are not assumed identical. No independently reviewed audit was established. The compound cap is not adopted as a universal flash-manipulation theorem.

### Weir: integrated full-range vault

Source tied to the advertised Robinhood manager confirms native `deposit` with `zap=true` and `withdraw` with `zapTo=1/2`. It compounds before each flow, takes a default 5% performance fee capped at 10%, then retains balanced liquidity plus idle dust. Shares are transferable in its own address-indexed ledger, not ERC20. `_balance` uses spot conversion of excess value; calling this a naive sum of mismatched raw-token units would be incorrect. [P4-P6]

Full-range avoids routine range management but sacrifices concentration and does not make idle dust fee-earning. Pause blocks deposit, not the vault's withdrawal entrypoint; hooks and mandatory pre-exit compounding can still fail. The key output limitation is structural: after attempting the unwanted-leg swap, it settles both deltas and never asserts the unwanted leg was fully spent. A partial fill can therefore leave a second token instead of reverting. Its UI's zero-vault display is an observed page result, not an authoritative RPC assertion that no instances exist. No funded active vault was established. [P4-P6]

The owner can change bounded fee/treasury and pause deposits. No independent audit or live round trip was verified.

### The Pool: fixed-asset ERC4626 with native zap entrypoints

Sourcify records a matching Arbitrum deployment of `LiquidityVaultV2`; `VaultLP` actually mints/increases V4 positions to the vault and collects via zero-decrease. `depositWithZap` prices shares from net added NAV after conversion/deployment, rather than simply gross token input. Zap exit methods remove liquidity, sell other-token inventory through configured `IZapRouter` and require sufficient fixed asset before payout. There is no automatic two-token payout fallback. [P7-P8]

This is not self-contained native swapping: the external adapter is an owner-controlled configuration and its present venue/wiring was not established. Native-ETH pools are rejected. A successful ordinary deposit may remain idle if there is no matching currency; a nonzero liquidity floor matters when the user requires deployment. Range management and all entry/exit pause controls are owner dependencies. NAV uses spot bounded against an owner-refreshable reference, not a market TWAP; ordinary price changes can block the guard until refresh. [P8]

Collected balances, reserve-sale escrow and proceeds are accounted separately but not all are active LP liquidity or immediately liquid. Donation-based yield is shared with active liquidity, not automatically exclusive to vault holders. Performance-fee setter is capped at 20%; this is not a verified current fee. Deployed-source evidence is stronger than a README, but does not establish a working current adapter, active liquidity or audit.

### ALPS: USDC entry to an actively managed V3/V4 basket

USDC ERC4626 shares represent a managed basket including a V4 Alphix dynamic-fee pool. Standard USDC withdrawals harvest and try to unwind; users separately can choose `redeemInKind`. Deposits need not deploy atomically, and in-kind withdrawal is not a single-token exit. Roles divide owner, guardian and agent; normal entry/exit can pause. [P9-P11]

Code uses asymmetric book/market settlement, virtual shares and same-block restrictions. These are observed mechanisms, not proof of economic correctness. A stale vault comment says V4 TWAP equals spot, but the actual adapter returns zero; the unwind zero-reference guard skips automatic V4 non-base conversion. USDC exit can therefore fail when idle USDC/other realizable proceeds are inadequate, while a separately invoked in-kind route is the escape. This prioritizes price protection over unconditional cash withdrawal. No third-party audit or live deployment/source reconciliation was established. [P10-P11]

### USDa / Ascnt: stable-pair NAV and explicit degraded exit

Custom USDC entry mints USDa shares against tracked idle balances, position principal and fee accrual, with a peg-band check and best-effort deployment. It holds a full-range backstop and three hook-derived concentrated positions. Standard ERC4626 mutation functions revert, so inheritance alone does not make generic integrators compatible. [P12-P13]

When slicing positions it retains other holders' fee surplus rather than giving a withdrawing user all fees harvested on a partial decrease. It then consolidates via another pool/backup router. If conversion fails, it pays both currencies and bypasses the requested aggregate one-token `minOut`; this is an explicit exit contract, not a harmless implementation detail. Owner pause blocks normal withdrawal, and the owner changes peg/risk/swap settings. [P13]

The peg clamp bounds valuation under an assumed stable relationship; it is not general evidence for a volatile asset with liquidity only in the underlying pool. Extra conversion-market liquidity is a requirement. No independent audit was verified; evidence is Sepolia prototype, not mainnet operation.

### Unoxi: one-token user orders, two-sided batch settlement

A shared full-range position earns V4 fees; shares have a confidential wrapper. Individuals can contribute one currency, but the entry round requires participation on both sides and adds the combined amounts without a deposit swap. Exit rounds redeem aggregate liquidity and net requested currencies before swapping only the imbalance. Fees compound only when compatible currency balances exist. [P14-P16]

This exchanges immediacy for reduced conversion: a one-sided round does not establish one-token entry on demand. Published settings include minimum age and per-side thresholds. Exits can refuse on drift/conversion constraints and refund shares rather than settle. Dependence on confidential computation/gateway, a reference-price implementation and thin self-supplied liquidity limits portability. The example's `PinnedReference` is not proved to be a live independent market oracle. Testnet receipts are publisher evidence; no production audit or current live settlement was verified.

### ZapVault: fixed-USDC per-user custody

The contract manages a separate position per user. It swaps USDC to ETH, adds V4 liquidity, then on withdrawal removes liquidity and sells ETH back to USDC. Range centering uses a Chainlink feed; the split uses pool state. This is not a pooled ERC20-share design. Ignoring PoolManager's second fee return is not evidence of lost fees: canonical `callerDelta` already includes principal and fees. [P17-P19]

The withdrawal has no user minimum-output or deadline parameter; a slippage config field is not enforced along these paths. Permissionless rebalance does not enforce the suggested trigger threshold. Router rotation and arbitrary idle-token rescue are owner powers. Same-pool conversion, rough split math, residual accounting and out-of-range exposure are substantive limitations. LI.FI arbitrary-token entry is preprocessing into USDC, not arbitrary-token vault support. Published Base addresses and hackathon material are not an audit or executed validation. [P17-P19]

## Useful near matches and exclusions

| Lead | Reason not counted as another full match |
|---|---|
| Twofold / DualPool | Single ETH/USDG entry is real, but `zapOut` pays both legs. JIT liquidity rather than a standing position, and external lending adds withdrawal dependencies. |
| Kyber Earn / ZaaS | Official V4 single-asset zap-in/out is useful periphery precedent, but individual positions are not a pooled LP vault; partner lending vaults are a different product. |
| Arrakis Pro / historical Modular | Real V4 modules. Current issuer-owned NFT vaults must not be conflated with legacy public shares; selected-token redemption was not verified. Issuer ownership alone is not an exclusion from a generic vault search. |
| Bunni V2 | Real historical V4 fee/share architecture but custom accounting, pair I/O and unverified both-direction zap. Current public tree explicitly warns exploit issues remain unrepaired. September 4, 2025 incident status is not October 2026 live status. |
| Gamma / Steer / EARN | V4 support or SDK evidence exists, but neither direction's complete single-token conjunction was established. Negative Gamma guides include V3 examples; do not claim every V4 integration is impossible. |
| ICHI / Charm / Beefy / Topaz | Useful single-asset/zap patterns, but inspected supporting paths are V3 or another AMM, or V4 linkage is unverified. |
| OpenZaps | Documented V4 LP routes, not just swaps; however source link unavailable and Hookr API reports unconfigured/null/non-live routes. Do not broadly claim every possible lineage is absent. |
| PRISM | Source contains V4 calls but is unfinished, pair I/O and incomplete valuation; roadmap is not deployment. |
| Blackhole | Indexed technical whitepaper defers V4 and names V3 adapter, despite headline. Direct site unavailable. |
| Kerf / Levee | Separate V4 zap and V3/share-vault claims do not prove integrated V4 vault support. |
| Grimoire / unisafe / BTR / MoleSwap | Potential additional candidates, but output denomination, code, address or live integration not adequately verified in this run. |
| Revert v4lend / Uniswap lending Earn | Single-asset lending or LP-collateral loans are not fee-sharing custody of LP capital. |
| Range / Fourmate / launch curves | Wallet position management, pair deposits, or one-sided out-of-range inventory do not establish requested two-way active-LP vault behavior. |

## Comparison conclusions

1. **Separate accounting from executable exit.** Portfolio NAV is not a withdrawal-and-sale quote. lpTOKEN's proportional core, fixed-asset NAV designs and batch netting solve different contracts.
2. **Specify conversion failure.** Full-spend-or-revert (lpTOKEN), selected-output shortfall revert (The Pool), possible residual payout (Weir), automatic in-kind fallback (USDa), separate in-kind escape (ALPS), and queued refusal/refund (Unoxi) differ materially.
3. **Fee exposure is not universal across reserves.** Invested in-range liquidity earns swap fees. Idle balances, escrow, router refunds and external lending balances have different returns/availability.
4. **Do not assume another market or oracle exists.** USDa needs an off-pool market; Unoxi uses a reference. lpTOKEN and Weir demonstrate own-pool conversion but caller minima do not prove fair pricing. The appropriate design depends on liquidity actually available.
5. **Do not transplant unproved security claims.** Same-block controls, fees, peg clamps, economic caps and manager-set references are mechanisms, not universal manipulation proofs.
6. **Deployment evidence and audits are separate axes.** The search produced several study-worthy mechanisms, not several independently validated production-safe products.

## Council participation and remaining gaps

Four independent originals settled: Astra, Grok, MiniMax, Kimi, on the requested Native routes. Coordinator read all originals, checked important sources, and corrected disagreements rather than voting on factual truth. Grok's narrower search found fewer matches; MiniMax's initial count overstated prototype/conditional strength; Kimi added asynchronous Unoxi; Astra added verified-source The Pool.

Kimi's write tool was unavailable and the coordinator archived its complete inline original via apply_patch. Grok and MiniMax disclosed alternate write tools contrary to the brief's no-workaround boundary; originals are preserved and the deviation is recorded in RUN.md. No product code/configuration was edited. One advisory pass remains pending at this frozen draft. Report is research only.

## Primary-source registry

All accessed 2026-10-29. These locators, the member originals and coordinator source-notes preserve observation versus inference and failed-access details.

- P1 https://github.com/Steemhunt/lptoken-contracts
- P2 https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/LpTokenVault.sol
- P3 https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/periphery/ZapRouter.sol
- P4 https://www.weir.finance/docs
- P5 https://www.weir.finance/vaults
- P6 https://sourcify.dev/server/v2/contract/4663/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110?fields=sources
- P7 https://pool.nativebtc.org/
- P8 https://sourcify.dev/server/v2/contract/42161/0xf79c2dc829cd3a2d8ceec353bdb1b2414ba1eee0?fields=sources
- P9 https://github.com/yanisepfl/alps
- P10 https://raw.githubusercontent.com/yanisepfl/alps/main/contracts/src/ALPVault.sol
- P11 https://raw.githubusercontent.com/yanisepfl/alps/main/contracts/src/adapters/UniV4Adapter.sol
- P12 https://github.com/itskillian/ethglobal-vault
- P13 https://raw.githubusercontent.com/itskillian/ethglobal-vault/main/vault/src/USDaVault.sol
- P14 https://github.com/skar8848/unoxi
- P15 https://raw.githubusercontent.com/skar8848/unoxi/main/contracts/UnoxiVault.sol
- P16 https://raw.githubusercontent.com/skar8848/unoxi/main/contracts/UnoxiExitRounds.sol
- P17 https://github.com/joaoolucas/zapvault
- P18 https://raw.githubusercontent.com/joaoolucas/zapvault/main/contracts/src/ZapVault.sol
- P19 https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol
- P20 https://twofold.fi/docs.html and https://raw.githubusercontent.com/twofoldfi/twofold-contracts/main/src/PoolZapper.sol
- P21 https://docs.kyberswap.com/user-guide/kyber-earn
- P22 https://docs.arrakis.finance/arrakis-pro
- P23 https://github.com/Bunniapp/bunni-v2 and https://blog.bunni.xyz/posts/exploit-post-mortem/
- P24 https://openzaps.vercel.app/docs and https://openzaps.vercel.app/api/hookr/routes
- P25 https://github.com/ozpool/prism
- P26 https://www.blackhole.finance/whitepaper (indexed primary text; direct site unavailable)
- P27 https://docs.gamma.xyz/gamma/lp-vaults/introduction.md and https://docs.gamma.xyz/gamma/lp-vaults/guides/providing-liquidity/deposit-liquidity.md
- P28 https://steerprotocol.github.io/sdk/ and https://earnonhood.com/docs

The member source registries provide the remaining near-match URLs, exact search queries, per-contract deployment locators and access limitations. No RPC or executed economic verification was performed. No independently verified audit of the seven shortlisted exact paths was established.
