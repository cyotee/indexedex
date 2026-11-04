# Council comparison: fee-earning Uniswap V4 vaults with single-token entry and exit

Final coordinator report, 2026-10-29. Derived from frozen advisory revision **v4-vault-comparison-r1**. The original draft, four originals, four advisories and resolution ledger are preserved. Final corrections are coordinator revisions, not text re-approved by the members.

## Answer and scope

Seven independent study designs are useful comparisons: **lpTOKEN, Weir, The Pool, ALPS, USDa/Ascnt, Unoxi, and ZapVault**. They comprise six shared-capital systems, including Unoxi's asynchronous confidential settlement, and one per-user custody prototype, ZapVault. They are not seven equally established production matches, nor seven unconditional complete-value one-token exits. Names, wrappers and deployments within one family are not counted separately.

The strongest starting comparisons are lpTOKEN's two-currency core plus explicit zap, Weir's integrated conversion, and The Pool's fixed-asset NAV plus configured adapter. ALPS adds managed multi-pool exposure; USDa adds stable-pair fee-slicing and degraded settlement; Unoxi adds batch netting. ZapVault shows a simple fixed-USDC path but has substantial execution-protection limitations.

Research means public source/document inspection, not executed deposits, bytecode rebuilds, live liquidity checks or an audit. A verifier match establishes a verification record, not a funded position or present app availability. No current TVL/APR or safety claim is adopted. Sources were accessed October 29, 2026.

## Qualification table

| Family | Held liquidity and fee exposure | One-token input | One-token output | Qualification / evidence |
|---|---|---|---|---|
| lpTOKEN + official ZapRouter | One fixed-range V4 position; ERC20 portfolio shares; accrued fees and idle balances in claim | Either leg; restricted native/stable routed entry | Either leg; incomplete conversion reverts | Code-backed both directions through separate periphery. Publisher manifests for Base/Robinhood/Arc; current main not reconciled to every deployed version. [P1-P3] |
| WeirVaults | Full-range direct PoolManager position per pool; internal share ledger; reinvest before I/O | Either leg, native zap branch | Either leg intended; partial fill can leave second leg | Verified-source native mechanism; no all-or-revert one-output postcondition. Creation/runtime source match for Robinhood manager; UI showed zero vaults; no populated PoolId independently established. [P4-P6] |
| The Pool / LiquidityVaultV2 | V4 position NFT; fixed ERC4626 asset; idle and reserve-sale inventory/proceeds in NAV | Fixed asset via depositWithZap | Fixed asset via withdrawWithZap/redeemWithZap, or revert | Verified-source zap methods on Arbitrum. Configured adapter, current funding and live use not queried. [P7-P8] |
| ALPS | Managed V3+V4 position basket; USDC ERC4626 shares; trading fees in portfolio | USDC; capital can remain idle pending allocation | USDC if idle/recovered USDC and other convertible proceeds suffice; V4 non-base sale skipped; separate limited in-kind exit | Conditional cash exit: current V4 adapter returns zero TWAP and automatic V4 conversion is skipped. Base deployment/rebalance evidence is publisher-provided. [P9-P11] |
| USDa / Ascnt | Four USDC/USDT V4 NFTs; ERC20 NAV shares; proportional fee-surplus retention | USDC custom entry | USDC or USDT normally; automatic two-token fallback on swap failure | Conditional, not strict one-output guarantee. Standard ERC4626 mutators disabled; testnet deployment evidence only. [P12-P13] |
| Unoxi | One full-range V4 position; plain shares/confidential wrapper; balanced fees compounded | Individual one-token order; entry round needs both sides | Selected confidential currency wrapper via asynchronous exit round; may refuse and refund shares | Conditional asynchronous comparison, not atomic zap. Sepolia only; confidentiality infrastructure/reference dependency. [P14-P16] |
| ZapVault | Per-user direct V4 concentrated position; no pooled share token | USDC; optional external LI.FI preprocessing | USDC payment after attempted ETH sale; residual ETH can be retained when user record is deleted | Code-backed per-user design/prototype. No user min-out or deadline on withdrawal; published Base addresses not independently reconciled. [P17-P19] |

## Profiles: features and limitations

### lpTOKEN: proportional vault with an explicit conversion layer

The vault owns a salt-zero V4 position and mints transferable ERC20 claims. Native `mintPair` and `redeem` operate in both currencies. Official `zapIn`/`zapInTarget` swap a caller-sized portion then mint; `zapOut`/`zapOutTarget` redeem then sell the unwanted leg. The router checks factory registration, deadlines, minima and full input consumption. It refunds unused mint assets rather than silently retaining route balances. [P1-P3]

Fees accumulate in the portfolio; capped, permissionless, swapless compounding invests matched balances, leaving unmatched assets idle. A fixed range is not automatically always active. The core charges 30 bps in backed shares on mint and redeem, separate from swap fees. Conversion occurs through the vault pool after liquidity removal on exit, so post-removal market depth matters. Routes are not arbitrary-token: routed entry admits native/canonical stable through at most three hookless static-fee V4 hops; exit is either underlying token. Caller minima are not a fair-value oracle or MEV defense. [P1-P3]

The Base manifest was read at receipt/source-commit level. Robinhood and Arc manifests and README deployment claims were located but not subjected to the same receipt-level read. Current source and all historical deployments are not assumed identical. No independently reviewed audit was established. The compound cap is not adopted as a universal flash-manipulation theorem.

### Weir: integrated full-range vault

Source tied to the advertised Robinhood manager confirms native `deposit` with `zap=true` and `withdraw` with `zapTo=1/2`. It compounds before each flow, takes a default 5% performance fee capped at 10%, then retains balanced liquidity plus idle dust. Shares are transferable in its own address-indexed ledger, not ERC20. `_balance` uses spot conversion of excess value; calling this a naive sum of mismatched raw-token units would be incorrect. [P4-P6]

Full-range avoids routine range management but sacrifices concentration and does not make idle dust fee-earning. Pause blocks deposit, not the vault's withdrawal entrypoint; hooks and mandatory pre-exit compounding can still fail. The key output limitation is structural: after attempting the unwanted-leg swap, it settles both deltas and never asserts the unwanted leg was fully spent. A partial fill can therefore leave a second token instead of reverting; it is paid to the recipient rather than stranded. The per-leg minima are lower bounds: neither a zero minimum nor a positive minimum on the unwanted leg enforces its absence. Its UI's zero-vault display is an observed page result, not an authoritative RPC assertion that no instances exist. No funded active vault was established. [P4-P6]

The owner can change bounded fee/treasury and pause deposits. The first deposit must exceed MIN_SHARES=1,000 and permanently leaves those shares unassigned and nonredeemable. Their proportional liquidity claim can grow through compounding; this is not a permanently fixed 1,000-unit residual or value automatically owned by other holders. No independent audit or live round trip was verified.

### The Pool: fixed-asset ERC4626 with native zap entrypoints

Sourcify records a matching Arbitrum deployment of `LiquidityVaultV2`; `VaultLP` actually mints/increases V4 positions to the vault and collects via zero-decrease. `depositWithZap` prices shares from net added NAV after conversion/deployment, rather than simply gross token input. Zap exit methods remove liquidity, sell other-token inventory through configured `IZapRouter` and require sufficient fixed asset before payout. There is no automatic two-token payout fallback. [P7-P8]

This is not self-contained native swapping: the external adapter is an owner-controlled configuration and its present venue/wiring was not established. Native-ETH pools are rejected. A successful ordinary deposit may remain idle if there is no matching currency; a nonzero liquidity floor matters when the user requires deployment. Range management and all entry/exit pause controls are owner dependencies. NAV uses spot bounded against an owner-refreshable reference, not a market TWAP; ordinary price changes can block the guard until refresh. [P8]

Collected balances, reserve-sale escrow and proceeds are accounted separately but not all are active LP liquidity or immediately liquid. Donation-based yield is shared with active liquidity, not automatically exclusive to vault holders. Performance-fee setter is capped at 20%; this is not a verified current fee. Deployed-source evidence is stronger than a README, but does not establish a working current adapter, active liquidity or audit.

### ALPS: USDC entry to an actively managed V3/V4 basket

USDC ERC4626 shares represent a managed basket including a V4 Alphix dynamic-fee pool. Standard USDC withdrawals harvest and try to unwind; users separately can choose `redeemInKind`. Deposits need not deploy atomically, and in-kind withdrawal is not a single-token exit. Roles divide owner, guardian and agent; normal entry/exit can pause. [P9-P11]

Code uses asymmetric book/market settlement, virtual shares and same-block restrictions. These are observed mechanisms, not proof of economic correctness. A stale vault comment says V4 TWAP equals spot, but the actual adapter returns zero; the unwind zero-reference guard skips automatic V4 non-base conversion. USDC exit can therefore fail when idle USDC/other realizable proceeds are inadequate, while a separately invoked in-kind route is the escape. This prioritizes price protection over unconditional cash withdrawal. V4 removal can still recover its USDC side; it is conversion of the other side that is skipped, not all V4 proceeds. The separately callable in-kind route can skip orphaned or unsuccessfully removed positions while burning the requested shares, subject to caller token minima; it is not guaranteed full-portfolio recovery. Owner-set entry/exit fee is capped at 2%, including in-kind redemption; current fee was not checked. No third-party audit or live deployment/source reconciliation was established. [P10-P11]

### USDa / Ascnt: stable-pair NAV and explicit degraded exit

Custom USDC entry mints USDa shares against tracked idle balances, position principal and fee accrual, with a peg-band check and best-effort deployment. It holds a full-range backstop and three hook-derived concentrated positions. Standard ERC4626 mutation functions revert, so inheritance alone does not make generic integrators compatible. [P12-P13]

When slicing positions it retains other holders' fee surplus rather than giving a withdrawing user all fees harvested on a partial decrease. It then consolidates via another pool/backup router. If conversion fails, it pays both currencies and bypasses the requested aggregate one-token `minOut`; this is an explicit exit contract, not a harmless implementation detail. Owner pause blocks normal withdrawal, and the owner changes peg/risk/swap settings. [P13]

The peg clamp bounds valuation under an assumed stable relationship; it is not general evidence for a volatile asset with liquidity only in the underlying pool. Extra conversion-market liquidity is a requirement. No independent audit was verified; evidence is Sepolia prototype, not mainnet operation.

### Unoxi: one-token user orders, two-sided batch settlement

A shared full-range position earns V4 fees; shares have a confidential wrapper. Individuals can contribute one currency, but the entry round requires participation on both sides and adds the combined amounts without a deposit swap. Exit rounds redeem aggregate liquidity and net requested currencies before swapping only the imbalance. Fees compound only when compatible currency balances exist. [P14-P16]

This exchanges immediacy for reduced conversion: a one-sided round does not establish one-token entry on demand. Published settings include minimum age and per-side thresholds. Exits can refuse on drift/conversion constraints and refund shares rather than settle. Dependence on confidential computation/gateway, a reference-price implementation and thin self-supplied liquidity limits portability. The published deploy script instantiates `PinnedReference`: its source explicitly implements an operator-posted price with owner updates and an age limit, not a market price or TWAP. The manifest records a priceSource address; the live address's bytecode/current wiring was not independently checked. [P36-P37] Exit claims pay cToken0 or cToken1, the selected confidential wrapper, not the plain pool ERC20; unwrapping is a separate dependency not verified here. Testnet receipts are publisher evidence; no production audit or current live settlement was verified.

### ZapVault: fixed-USDC per-user custody

The contract manages a separate position per user. It swaps USDC to ETH, adds V4 liquidity, then on withdrawal removes liquidity and sells ETH back to USDC. Range centering uses a Chainlink feed; the split uses pool state. This is not a pooled ERC20-share design. Ignoring PoolManager's second fee return is not evidence of lost fees: canonical `callerDelta` incorporates principal and fees before possible hook adjustment; ZapVault's published pool is hookless. [P17-P19]

The withdrawal has no user minimum-output or deadline parameter; a slippage config field is not enforced along these paths. If the sale partially fills, positive remaining ETH is taken into vault custody while the user's position/config are deleted, with no surviving per-user claim shown in that path. Thus a USDC payment does not prove complete-value consolidation; the retained-residual scenario is source reasoning, not an executed reproduction. Coordinator inspection of both `rebalance` and `_executeRebalance` confirms permissionless calls do not check `needsRebalance` or the configured trigger threshold; range width is still taken from user config. Router rotation and arbitrary idle-token rescue are owner powers. Same-pool conversion, rough split math, residual accounting and out-of-range exposure are substantive limitations. LI.FI arbitrary-token entry is preprocessing into USDC, not arbitrary-token vault support. Published Base addresses and hackathon material are not an audit or executed validation. [P17-P19]

## Deployment and maturity evidence

These are evidence classes, not safety ratings. Verified deployment source is not proof of funding, an active position, or present usability. Publisher testnet evidence is not mainnet evidence. No independently verified audit of the exact seven shortlisted paths was established.

| Family | Chain and locator | Evidence / maturity |
|---|---|---|
| lpTOKEN | Base 8453: factory `0x3384eD0d272dE35bF6DC516E1eA7d188CEb51793`; implementation `0x78aae2fD8f8b09994d0e936Ce4478a7EB8FE92D9`; zap `0xc4C8071D651F093C4A5c2C06e7BFfc163A057DdA` | Publisher deployment manifest, including per-contract source commits and receipts. Infrastructure, not a verified funded clone. Other published networks: Robinhood and Arc. [P1, P29] |
| Weir | Robinhood 4663 shared manager `0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110` | Sourcify creation/runtime match, verified September 30, 2026. No populated PoolId independently established; UI zero-vault observation is not RPC. [P4-P6] |
| The Pool | Arbitrum One 42161 vault `0xf79c2dc829cd3a2d8ceec353bdb1b2414ba1eee0` | Sourcify creation/runtime match, verified June 19, 2026. Current adapter, funding and operation unverified. [P7-P8] |
| ALPS | Base 8453 vault `0x3F0e6cef3a75f52F1E55806Afe40317f51199CaE`; V4 adapter `0xB6871C8cd995fF015DBa7373b371426E80cBBCF0` | Publisher prototype addresses and V4 rebalance transaction. Current deployed-source identity not checked. [P9-P11] |
| USDa | Sepolia 11155111 vault `0x1638fcb8a56a19e8226e2d15c7b3c2cc2f3c6040` | Publisher testnet deployment/deposit evidence; prototype. [P12-P13] |
| Unoxi | Sepolia 11155111 vault `0x0480Ae5a4f7d53e00e2C06cF3daA42F0894b5AdA`; exit rounds `0x2dd37c8bf3747574627e264d6b2cb0fd421742f5` | Publisher testnet manifest/lifecycle records, not independently replayed. [P14-P16, P30] |
| ZapVault | Base 8453 vault `0xc77d3CCFba9354db99972D11d994676d55709d5C`; router `0x3F75D8E28A148380B186AcedcDE476F8E1CFDd78` | Publisher hackathon/prototype addresses; bytecode and operation not independently verified. [P17-P18] |

## Useful near matches and exclusions

| Lead | Reason not counted as another full match |
|---|---|
| Twofold / DualPool | Single ETH/USDG entry is real, but `zapOut` pays both legs. JIT liquidity rather than a standing position, and external lending adds withdrawal dependencies. |
| Kyber Earn / ZaaS | Official V4 single-asset zap-in/out is useful periphery precedent, but individual positions are not a pooled LP vault; partner lending vaults are a different product. |
| Arrakis Pro / historical Modular | Real V4 modules. Current issuer-owned NFT vaults must not be conflated with legacy public shares; selected-token redemption was not verified. Issuer ownership alone is not an exclusion from a generic vault search. |
| Bunni V2 | Real historical V4 fee/share architecture but custom accounting, pair I/O and unverified both-direction zap. Current public tree explicitly warns exploit issues remain unrepaired. September 4, 2025 incident status is not October 2026 live status. |
| Gamma / Steer / EARN | V4 support or SDK evidence exists, but neither direction's complete single-token conjunction was established. Negative Gamma guides include V3 examples; do not claim every V4 integration is impossible. |
| ICHI / Charm | Single-asset or one-click patterns in the inspected paths do not establish a both-direction V4 integration. |
| Beefy CLM | Inspected documentation predates V4 launch and does not name V4; useful zap pattern, not a verified V4 match. |
| Topaz | Inspected concentrated-liquidity zap path is Slipstream, not Uniswap V4. |
| OpenZaps | Documented V4 LP routes, not just swaps; however source link unavailable and Hookr API reports unconfigured/null/non-live routes. Do not broadly claim every possible lineage is absent. |
| PRISM | Source contains V4 calls but is unfinished, pair I/O and incomplete valuation; roadmap is not deployment. |
| Blackhole | Indexed technical whitepaper defers V4 and names V3 adapter, despite headline. Direct site unavailable. |
| Kerf / Levee | Separate V4 zap and V3/share-vault claims do not prove integrated V4 vault support. |
| Grimoire / unisafe / BTR / MoleSwap | Potential additional candidates, but output denomination, code, address or live integration not adequately verified in this run. |
| Revert v4lend / Uniswap lending Earn | Single-asset lending or LP-collateral loans are not fee-sharing custody of LP capital. |
| EulerSwap / VII yield-harvesting hook | JIT credit-backed swap inventory and ERC4626 yield-bearing pool assets are different from a vault holding the requested LP capital. Peer originals give primary README locators. |
| Range / Fourmate / launch curves | Wallet position management, pair deposits, or one-sided out-of-range inventory do not establish requested two-way active-LP vault behavior. Weir ladders and lpTOKEN locked launch inventory are separate from the shortlisted share-vault paths. |
| CuratedLP / UniSD / RangePilot | Peer-read designs fail one conjunction: paired deposits/proportional exits; single-stable entry but basket exit; or single-sided LP listed as roadmap. RangePilot is not generic Range. [P31-P33] |
| Grapl | Peer-reported one-token zap primitive explicitly disclaims being a strategy vault; not counted as V4 LP custody/share example. Its branding/affiliation not independently established. [P34] |
| Aperture / MaxFi | No exact current both-direction V4 vault path established. Do not promote search-level exploit claims or an unrelated AMM integration into a protocol-wide judgment. |

## Comparison conclusions

1. **Separate accounting from executable exit.** Portfolio NAV is not a withdrawal-and-sale quote. lpTOKEN's proportional core, fixed-asset NAV designs and batch netting solve different contracts.
2. **Specify conversion failure.** Full-spend-or-revert (lpTOKEN), selected-output shortfall revert (The Pool), possible residual paid to user (Weir), automatic dual-token fallback bypassing aggregate minOut (USDa), separate limited in-kind exit (ALPS), queued refusal/refund with wrapped payout (Unoxi), and possible retained residual with deleted user record (ZapVault) differ materially. These are not equally strong guarantees.
3. **Fee exposure is not universal across reserves.** Invested in-range liquidity earns swap fees. Idle balances, escrow, router refunds and external lending balances have different returns/availability.
4. **Do not assume another market or oracle exists.** USDa needs an off-pool market; Unoxi uses a reference. lpTOKEN and Weir demonstrate own-pool conversion but caller minima do not prove fair pricing. The appropriate design depends on liquidity actually available.
5. **Do not transplant unproved security claims.** Same-block controls, fees, peg clamps, economic caps and manager-set references are mechanisms, not universal manipulation proofs.
6. **Deployment evidence and audits are separate axes.** The search produced several study-worthy mechanisms, not several independently validated production-safe products.

### Canonical V4 fee-settlement rule

In canonical PoolManager, the first modifyLiquidity return includes principal plus accrued fees (and applicable hook adjustments); the second is informational. Ignoring the second return does not itself lose fees. Partial liquidity removal can settle all fees accrued to the position, so a share vault must allocate those fees proportionally or harvest before slicing. USDa and ALPS expose those two patterns. Fee-growth accounting is sensitive to donations, but no universal exploit is inferred merely from reading feesAccrued. [P19]

Upstream Uniswap ALF PoolVault is a useful two-asset/JIT accounting reference, not evidence that every shortlisted vault derives from it or natively converts withdrawals. [P35]

## Council participation and remaining gaps

Four independent originals settled: Astra, Grok, MiniMax, Kimi, on the requested Native routes. Coordinator read all originals, checked important sources, and corrected disagreements rather than voting on factual truth. Grok's narrower search found fewer matches; MiniMax originally classed ALPS and USDa as confirmed, then withdrew those classifications in advisory; Kimi added asynchronous Unoxi; Astra added verified-source The Pool.

Kimi's write tool was unavailable and the coordinator archived its complete inline original via apply_patch. Grok and MiniMax disclosed alternate write tools instead of the requested apply_patch; originals are preserved and the process deviation is recorded in RUN.md, without inferring evidence fabrication. No product code/configuration was edited. All four advisories settled: Astra, Grok and MiniMax SUPPORT WITH CORRECTIONS; Kimi SUPPORT. The coordinator adopted verified corrections concerning residual custody, confidential-wrapper output, in-kind limitations, deployment provenance and price references. One MiniMax correction was rejected: lower-bound min0/min1 cannot enforce zero unwanted-token output. Its locked-share description and other overbroad claims were narrowed. See coordinator/resolution.md for every material disposition. No unanimity or re-approval of final wording is claimed. Report is research only.


### Actual Native participation

Invoking-agent coordination; no delegated coordinator or substitute routes. All four original tasks and their single advisory continuations settled. Runtime metadata exposed these resolved routes (provider internals are not independently attested):

| Member | Resolved route | Task / child session | Advisory |
|---|---|---|---|
| astra | `chatgpt-subscription/gpt-6-astra:high` | `st_01a18665` / `01a18665-e8be-787f-accc-675875115506` | SUPPORT WITH CORRECTIONS |
| grok | `xai/grok-4.7:xhigh` | `st_01a18666` / `01a18665-e8fe-76e2-b79c-df80e37c6e3f` | SUPPORT WITH CORRECTIONS |
| minimax | `minimax/MiniMax-M3` | `st_01a18667` / `01a18665-e958-7624-ad13-91a933565948` | SUPPORT WITH CORRECTIONS |
| kimi | `kimi-coding/k3.1-pro:high` | `st_01a18668` / `01a18665-eb11-7234-9e58-073ac0f389d4` | SUPPORT |

All ran in process mode, parent/root session `01a18660-756f-7c57-b112-de7a5348283c`. MiniMax adaptive-thinking setting was not exposed. No member is missing.

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

- P29 https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/deployments/base-mainnet.json
- P30 https://raw.githubusercontent.com/skar8848/unoxi/main/deployments/sepolia.json
- P31 https://github.com/SakshiShah29/CuratedLP
- P32 https://ethglobal.com/showcase/unisd-au1uq
- P33 https://github.com/RangePilot/RangePilot
- P34 https://docs.grapl.io/guides/zaps (MiniMax source observation; coordinator did not independently establish affiliation)
- P35 https://github.com/Uniswap/v4-hooks-public/blob/main/src/alf/base/PoolVault.sol
- P36 https://raw.githubusercontent.com/skar8848/unoxi/main/contracts/reference/PinnedReference.sol
- P37 https://raw.githubusercontent.com/skar8848/unoxi/main/scripts/deploy.ts

The member source registries provide the remaining near-match URLs, exact search queries, per-contract deployment locators and access limitations. No RPC or executed economic verification was performed. No independently verified audit of the seven shortlisted exact paths was established.

