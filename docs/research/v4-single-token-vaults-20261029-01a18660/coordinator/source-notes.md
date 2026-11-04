# Coordinator public-source verification

Access date: 2026-10-29. Static public-source observations, not runtime tests or proof of present deployment state. Council originals remain independent; all four received identical additional public leads, not peer findings.

## Queries

- `Uniswap v4 vault single sided deposit withdraw Arrakis Bunni`
- `Uniswap v4 vault single token deposit withdrawal zap vault`
- `"Uniswap v4" "vault" "single" "withdraw"`
- `"Uniswap v4" "single-sided" vault`
- `"Bunni" "withdraw" "single"`
- `"Uniswap v4" "zap" "vault" -site:reddit.com`
- `site.docs.bunni.xyz deposit withdraw single token`
- `"Uniswap v4" vault "zapOut"`
- `"Uniswap v4" "single-token" vault -site:reddit.com`
- `"Uniswap v4" "vault" "single-sided" -site:reddit.com -site:gist.github.com`
- `"Uniswap v4" "vault" "single token" -site:reddit.com`
- `site:github.com/ArrakisFinance "swapAndRemoveLiquidity"`
- `site:docs.bunni.xyz "withdraw" "zap"`
- `site:github.com "WeirVaults"`
- `"Uniswap v4" "vault" "withdrawals" "single" -site:reddit.com -site:massdevelopment.com`
- `"Uniswap v4" "vault" "zap out"`
- `"Uniswap v4" "vault" "single-asset"`
- `"Uniswap v4" "ICHI" vault deposits withdrawals`

## lpTOKEN

Primary README: https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/README.md

Primary vault source: https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/LpTokenVault.sol

Primary zap source: https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/periphery/ZapRouter.sol

Observed: ERC20 shares, one fixed salt-zero V4 position, proportional two-currency accounting; native vault deliberately never swaps. `mintPair` and `redeem` are pair operations. ZapRouter supplies single-leg target/counter entry/exit; routed inputs restricted to canonical stable/native currency and up to three hookless static-fee V4 hops. Source explicitly says minima are not route discovery, fair-value establishment or MEV protection. Fixed immutable range is not literally full-range. README publishes deployment manifests/addresses across Base, Robinhood and Arc; not independently verified bytecode or transaction execution. Permissionless swapless capped compounding with cooldown can leave fee assets idle. Repository economic/security assertions are not independently proved by reading them.

## Weir

Official docs: https://www.weir.finance/docs

Observed: full-range shared V4 position, address-indexed vault shares, deposit either token via internal half swap, exit either token or both, reinvest before deposit/withdraw/compound. Documented 5% fee on earnings, cap 10%; deposit pause does not pause withdrawal. Contract address claimed for WeirVaults on chain 4663: `0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110`.

Explorer https://robinhoodchain.blockscout.com/address/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110 returned an empty static page. Fetching its API smart-contract endpoint returned no usable output. No independently inspected contract source or runtime proof yet. Treat as documented match, not code-verified match. The docs describe user simulation/slippage bounds, not an independently verified NAV manipulation defense. Do not equate share ledger with transferable ERC20.

Later verification closes the implementation-read gap: https://sourcify.dev/server/v2/contract/4663/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110?fields=sources returned the complete `src/WeirVaults.sol` before truncation occurred in later dependencies. This is source observation, not an execution test. `deposit` passes through `_balance` when `zap=true`; `_balance` uses spot sqrt price to convert the excess side's value and swaps half the excess, not a naive sum of unlike raw amounts. `withdraw.zapTo` has explicit 0=both, 1=currency0, 2=currency1 semantics. `_withdraw` burns proportional liquidity, includes proportional idle balances and swaps the unwanted currency. `_compound` harvests via zero-liquidity modification, takes a bounded performance fee and reinvests balanced amounts, retaining unmatched dust. Creation sets min/max usable ticks. Shares are transferable only through the internal share ledger, not ERC20.

Important qualification: `_swap` allows execution to extreme sqrt-price limits. `_withdraw` then settles both currency deltas and does not assert the unwanted leg is zero. Thus a partial fill can leave a residual second token; the source implements a single-token exit intent, not an unconditional all-or-revert single-token guarantee. Insufficient conversion depth is a material limitation. No TWAP/oracle guard was observed in the vault. Share issuance is proportional to added liquidity relative to stored liquidity; it does not separately add tracked idle value into that issuance denominator. That is a design/accounting distinction to examine, not an established exploit finding.

## OpenZaps

Official page: https://openzaps.vercel.app/

Observed route cards explicitly distinguish deployed single aeWETH entry into full-range aeWETH/USDG ozRANGE shares and single USDG exit including accrued fees from an LP-autocompound design card. Site calls software pre-audit. Site also distinguishes atomic route execution from separate setup approvals/creation/funding. Linked source repository https://github.com/0pen-Zaps/openzaps returned 404 in this retrieval. Do not count protocol catalog entries or design cards as deployed integrations. Need source/deployment linkage for stronger qualification.

## Blackhole

Official technical whitepaper: https://www.blackhole.finance/whitepaper

Observed contradiction resolved within same primary page: headline advertises V3/V4, but section 9 explicitly defers V4 due to unavailable pool oracle and deployment table lists UniswapV3Adapter. Single-asset vault holds idle withdrawal buffer; large redemption reverts until keeper unwinds. Exclude from confirmed V4 matches. Its statement about no LP fees in examined Pons pools is pool/version-specific and not evidence about all hooked pools.

## PRISM

Official repository README: https://raw.githubusercontent.com/ozpool/prism/main/README.md

Observed: reports M0 Foundations in progress; vault core and deployment listed as later milestones. Features/architecture are useful design intentions, not a deployed implementation or proof of single-token entry/exit. Exclude from confirmed matches.

## Grimoire

Official page: https://www.grimoire.fi/vaults

Observed: marketing asserts one-token deposit, auto-compounded V4 fees, no-lock withdrawals; no evidence on payout asset from this page. Linked /docs returned 404. TVL/APR display is not verified evidence and is not used for qualification.

## Arrakis

Primary current overview: https://docs.arrakis.finance/arrakis-pro

Legacy quickstart and generated router paths redirected to the current overview. Current overview describes issuer-owned NFT vaults with owner withdrawal authority and offchain management, not a fungible public vault product. Legacy indexed search excerpts establish atomic swap-before-deposit convenience only, not conversion-on-withdrawal. Do not splice those into proof of current both-direction single-token support.

Primary historical V4 audit: https://reports.chainsecurity.com/ArrakisFinance/ChainSecurity_ArrakisFinance_UniswapV4Module_Audit.pdf

Observed audit includes router-safety guidance and first-deposit front-running scenarios; need exact version linkage before applying findings to current releases.

## Bunni

Primary overview: https://docs.bunni.xyz/docs/v2/overview/

Primary postmortem: https://blog.bunni.xyz/posts/exploit-post-mortem/

Observed overview describes LDFs, shapeshifting, rehypothecation, dynamic fees and auto-compounding. Official postmortem is dated September 4, 2025 and describes September 2 exploit (~$8.4m), tiny-withdrawal rounding effects, and then-unpaused withdrawals with deposits/swaps paused. This is historical evidence, not a current state query. Active/idle allocation is orthogonal to rehypothecation. Do not label Bunni as a conventional passive V4 position wrapper without verifying custom accounting. Need both-direction zap proof and later operational status before current qualification.

## Kerf

Search index provided an apparently official repository README describing both a V4 zap and an LPVault. Direct repository/source URLs returned 404. Even a working README would not establish the LPVault uses V4 rather than V3. Retain only as unverified lead unless member evidence closes the gap.

## Generic baseline and exclusions

Uniswap official liquidity overview: https://developers.uniswap.org/docs/liquidity/overview

Uniswap support: https://support.uniswap.org/hc/en-us/articles/32233918539533-How-to-add-a-new-liquidity-position-to-Uniswap-v4

Observed: out-of-range concentrated positions are single-sided and stop earning fees. They do not meet general single-token I/O into active liquidity by themselves.

Uniswap official launch technical reference: https://github.com/Uniswap/liquidity-launcher/blob/main/docs/TechnicalReference.md

Observed: permanently locked FeeSplitter launch positions have no principal exit; not redeemable vault matches.

## Additional prototype verification after MiniMax settled

ALPS implementation: https://raw.githubusercontent.com/yanisepfl/alps/main/contracts/src/ALPVault.sol

Observed source, beyond its README: `_withdraw` harvests fees and invokes `_unwindForWithdraw` if idle USDC is short; this actually removes liquidity and attempts non-base conversion rather than merely promising standard ERC4626 redeem. Deposits remain idle until managed allocation. Deposit settlement uses max(book,market); redemption uses min(book,market), with virtual shares and same-block lockouts. Both normal deposit and withdrawal are pausable. Automatic removals use zero token minima and best-effort catches. An old ALPVault comment says V4 returns spot as TWAP; Kimi's additional adapter read establishes the actual current `UniV4Adapter.getTwapSqrtPriceX96` returns zero, and ALPVault's `lo == 0` condition skips the conversion. The actual implementation therefore overrides that stale comment. Insufficient recovered USDC can revert withdrawal; V4 non-base assets are not automatically sold by this path. A separately invoked in-kind alternative exists, so do not count that alternative as single-token exit. These observations identify design tradeoffs, not a security verdict or verified deployment linkage.

USDa actual source now inspected: https://raw.githubusercontent.com/itskillian/ethglobal-vault/main/vault/src/USDaVault.sol . Custom USDC entry is real; standard ERC4626 mutators revert. `_consolidateAndPay` explicitly calls `_payDualToken` on failed conversion and bypasses aggregate minOut in that branch. Both entry and withdrawal check pause. Owner sets peg band, swap venue and risk parameters. This upgrades the implementation evidence beyond README, but downgrades the one-output guarantee. See custom functions and `_sliceAllPositions` retaining non-redeemer fee surplus.

The Pool Sourcify bundle: https://sourcify.dev/server/v2/contract/42161/0xf79c2dc829cd3a2d8ceec353bdb1b2414ba1eee0?fields=sources . Coordinator independently fetched and parsed JSON in memory. Returned creation/runtime match and verification timestamp 2026-06-19T12:22:45Z. Read LiquidityVaultV2 lines 239-335, 341-624, 625-770, 909-941 plus complete VaultLP and IZapRouter. `depositWithZap` prices net added NAV, deploys via real V4 PositionManager; withdrawal zap variants pay fixed ERC4626 asset or revert on shortfall. External conversion adapter is owner-set; exact current adapter and active pool wiring remain unqueried. Native pools explicitly rejected. Spot NAV is bounded to owner-refreshable reference, not TWAP. Source-level match is not current usability or audit evidence.

Unoxi official README independently fetched: https://raw.githubusercontent.com/skar8848/unoxi/main/README.md . Supports Kimi's asynchronous design classification and testnet-only status. The published deployment's reference is named `PinnedReference`; do not present the example as a live independent market oracle. Runtime values and round completion not independently checked.

ZapVault: https://raw.githubusercontent.com/joaoolucas/zapvault/main/contracts/src/ZapVault.sol

Observed: per-user custody, USDC-only entry/exit, no pooled share token. Exit removes liquidity, swaps token0 into token1 and pays token1. `_modifyLiquidity` consumes the first return value and ignores the second.

Canonical Uniswap semantics: https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol

Observed: `modifyLiquidity` sets `callerDelta = principalDelta + feesAccrued` before any after-hook changes and accounts that combined delta to the caller. Therefore ignoring the second informational return is NOT by itself evidence that ZapVault omits fee payout. For its documented hookless pool, its removal path includes fees in the returned first delta. Full economic correctness, dust ownership and deployment execution remain untested. The source exit has no caller minimum-output or deadline argument; same-pool conversion liquidity and MEV are substantive limitations.

USDa repository README: https://raw.githubusercontent.com/itskillian/ethglobal-vault/main/README.md

Observed: testnet addresses and project claims of USDC deposits, USDC/USDT exits, four range positions, tracked-idle NAV, peg-clamped spot, off-pool rebalance swaps and proportional fee payout. All security adjectives in that README remain project claims until implementation verified. The claim that a peg clamp prevents all in-block share manipulation is not adopted as a proved theorem. Direct guessed `vault/src/Vault.sol` returned 404; do not infer no implementation exists from the wrong guessed filename.
