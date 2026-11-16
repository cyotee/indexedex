# Product Requirements Document (PRD)

## Title

**DETF alignment** — nine-decimal DETF, funded staking, vesting bonds, reserve swap fallback, and Pendle SY for V4 DETFs and in-scope SE vaults

## Status

**Refactor in progress — D32–D55 accepted on 2026-09-06; D56–D59 accepted in the subsequent owner clarification. Implementation is authorized. Balancer-hosted DETFs are excluded except compilation maintenance. V4 reserve-LP bond payment is accepted; D65 resolves restricted-mode protocol-fee LP redemption through the current Fee Collector. D66 defers unfinished Slipstream work.** This is the single working PRD for planned DETF product changes. Only decisions recorded in §0 are accepted. **D32–D66 and §24 supersede conflicting D1–D31 text for the planned refactor.** The earlier decisions and detailed sections remain as the historical baseline; their `LOCKED` labels do not override this revision. See §24.8 for the supersession map.

**Authorization and execution:** the owner authorized implementation of the plan and relocation into the main repository. The owner subsequently explicitly approved the previously rejected V4 mature-close cleanup: remove obsolete close deployment arguments, getters, storage, initialization, readers/writers and associated dead code; update callers, tests, ABIs and documentation while preserving funded claims, vesting, staking rewards and standard exchange/SY exits. This resolves the specific pending approval decision; completion and validation remain required. The unreferenced obsolete V4 bond target is also removed under this approval; the active V4 facet retains the common funded bond lifecycle. See `implementation-artifacts/detf-funded-staking/v4-close-cleanup-owner-approval.json`. D60 and D66 scope decisions remain unchanged. Production deployment and migration are outside scope.

The new [`DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md`](./DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md) covers D32–D66, including engineering design, family coverage, execution stages and A1–A42 validation. The owner authorized execution; implementation is in progress in the main repository directory. Production deployment and migration are not authorized. The existing [`DETF_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md`](./DETF_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md), opened 2026-08-19, remains the historical plan, including Stages **I–O** for D15/D25/D29/D30/D31 and N10; its completion marks do not apply to the new refactor.

| Field | Value |
|-------|--------|
| **Status** | **IN PROGRESS** — D32–D66 accepted; implementation authorized. Balancer DETFs excluded; V4 LP-payment rules accepted; D65 collector redemption is resolved; unfinished Slipstream is deferred by D66. Earlier launch default L1 is not a default for the new vesting bond |
| **Home** | This file, co-located with the DETF tree: `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` |
| **Scope** | Four V4 DETF bindings and the remaining SE/SY work in §24.7. D60 excludes functional Balancer-hosted DETF work; D66 defers all unfinished Slipstream work and release gates. Preserve completed work and permit only the stated maintenance exceptions. |
| **This file** | Cross-family product law. Append locked decisions here. Do not open a sibling PRD for the same questions |
| **Impl / test plan** | Current: [`DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md`](./DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md). Historical: [`DETF_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md`](./DETF_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **Related law** | Family curves, reserve token sets, and route tables remain in family PRDs (§16). Directory layout: [`DETF_DIRECTORY_REORGANIZATION_PRD.md`](./DETF_DIRECTORY_REORGANIZATION_PRD.md). Compound/expansion: [`DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](../../../docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md). Donation: [`DETF_RESERVE_DONATION_PRD.md`](./DETF_RESERVE_DONATION_PRD.md). §24 records the accepted changes to their overlapping product rules; current caller/law documentation is reconciled during implementation |

---

## 0. Locked decisions

### 0.1 Earlier decisions — D1–D31

Historical baseline. Apply the overrides in §0.2 and §24.8 when specifying the new refactor; do not combine incompatible old and new accounting models.

| ID | Topic | Decision | Date |
|----|-------|----------|------|
| **D1** | DualLiquidity | **Delete DualLiquidity entirely.** It is not a true DETF. Do not convert it. Do not keep a pro-rata BPT vault in the DETF tree. | 2026-08-18 |
| **D2** | Fee/creator shares | After any event that changes `O` (everyone’s `effectiveShares` except ids 1 and 2), top up ids **1** and **2** so they hold `f` and `c` of the new total. Award **effective shares only**. Formula in §3. Includes user bonds, sell-in, `buyClaim`, compound, and other `addToDETFNFT`. | 2026-08-19 |
| **D3** | Pot from free `userDetf` | Live mint: `U` **is** the D8 `Gross`. Split as before: user `1 - p`, pot `p`. The **entire** pot-side goes to bond-holder inventory. No DETF mint to `feeTo()` or creator; they claim that pot via ids 1 and 2 (D2). | 2026-08-19 |
| **D4** | Pot from bond join DETF; not expansion | On a bond, also mint **additional** `p * joinDetf` into the pot. Join amount into the reserve is unchanged. **Natural supply expansion does not take `p`** (it already pays the pot in full). This `p` rule **replaces** `_splitMintedDetf.inventoryDetf`. | 2026-08-18 |
| **D5** | Oracle sources for `p`, `f`, `c` | `p` **is** the resolved `seigniorageIncentivePercentageOfVault`. Bond terms stay lock-bonus only. Add oracle `f` / `c` (3-tier, same as other fees) plus tuple getters for bond/mint. Creator **address** is not on the oracle (DETF `PkgArgs`). | 2026-08-18 |
| **D6** | Initial `p`, `f`, `c` | No hardcoded product default in constants. Initial oracle globals come from **PkgArgs at oracle/manager deploy**. First values: `p = 5e16` (5% of minted DETF into the pot). Of the pot: purchasers `60%`, feeTo+creator `40%`. Of that `40%`: creator `70%` (`c = 28e16`), `feeTo` `30%` (`f = 12e16`). | 2026-08-18 |
| **D7** | Reserved bond NFT ids | Token id **0** = protocol / rebasing-claim reserve. Id **1** = `feeTo()` standing bond. Id **2** = creator standing bond. User bonds start at **3**. Ids **1** and **2** **must not** be sold to the protocol for rebasing claim. | 2026-08-18 |
| **D8** | Mint / burn quote | **Live only.** Every true DETF sizes **free** liquid DETF (and the burn return) from the **same curve and live reserves as the reserve pool**. Mint quote applies the seigniorage **capital bonus to amount in**, then runs that curve. Physical join still uses unboosted capital. Empty first bond does **not** use this quote (family creation / weights). Bonds do **not** use this bonus (D24). | 2026-08-19 |
| **D9** | DETF-owned reserve liquidity | **Uni V4:** the DETF instance must be the **only** party that can add or remove reserve liquidity. Hooks: **MultiStepOwnable** + deploy flag **owner-only add/remove LP**. DETF instances deploy hooks with that flag on; owner = the DETF. **Balancer V3:** keep the **current open public join**. Allowed to deviate for now. | 2026-08-19 |
| **D10** | Reserve shares, sell-in, rebasing claim | Bond principal is **ERC-4626** on reserve LP; lock bonus applies only to `effectiveShares`. Sell-to-claim **transfers `originalShares` to token id 0**. Claim token is 4626 on id 0 (shares of shares). Rebase quotes **DETF extractable** = **zap-out to DETF** of that holder’s slice of id 0 LP **plus** id 0 pending rewards. Conversion: physical NFT LP / `totalOriginalShares` + `decimalOffset` (no protocol-effective haircut). | 2026-08-22 |
| **D11** | Live mint vs bond join | Liquid mint does **not** mint DETF into the reserve. Bond is the **only** path that mints **new** DETF directly into liquidity. That join amount `G` is **unboosted** matching DETF (D24). Live mint may still join **non-DETF** capital; that LP sits in the NFT and **changes NAV** of existing `originalShares` (no new NFT shares for that deposit). | 2026-08-19 |
| **D12** | Burn burns DETF | `exchangeIn`/`exchangeOut` redeem of DETF **burns** that DETF. It is not a swap of DETF into the pool (Composed’s shipped path is out of spec). | 2026-08-19 |
| **D13** | LP in the NFT; 4626 like V4 SE | Reserve LP is held by the **bond NFT vault**. Liquidity add/remove goes **through the NFT**, which mints/burns 4626 `originalShares` so the ledger stays consistent (N10 conversion). DETF burn sizes LP as V4 SE: `lpOut = detfIn * nftLp / detfSupply` (after expansion mint-on-update) and **dilutes** originalShares holders. Live mint (D11) is the unassigned-LP exception. | 2026-08-22 |
| **D14** | No DETF to `feeTo` on mint/burn | Mint does not mint free DETF to `feeTo()`. Burn does not transfer DETF to `feeTo()`. `feeTo` earns only via token id 1 (D2). | 2026-08-19 |
| **D15** | Claim redeem = DETF only | Redeem **only for DETF**. Quote = pending + **zap-out to DETF** of the holder’s id 0 LP slice. Pay **pending first**. Compound leftover pending to id 0. Shortfall: proportional withdraw, then **buy DETF on the residual reserve** (exact-out = remaining shortfall) with withdrawn non-DETF, rejoin leftover to id 0. Owner host swap (D30), not the public router. | 2026-08-22 |
| **D16** | First bond | First bond **must** fund **all non-DETF** reserve legs (plus the DETF self-leg). Ungated. That is how the instance goes live. | 2026-08-19 |
| **D17** | Ids 1 and 2 | Always `claimRewards`. **Never** sell-to-protocol. **Never** redeem for capital/LP. | 2026-08-19 |
| **D18** | `buyClaim` is `exchangeIn` | DETF → claim is `exchangeIn`. **No new DETF mint.** The user’s DETF is **moved into liquidity** (self-leg join). NFT credits **id 0** 4626 for that LP. Only **bonds** mint new DETF into the pool. | 2026-08-19 |
| **D19** | `feeTo()` change | Do **not** transfer token id 1 when oracle `feeTo()` changes. Id 1 stays with the address that received it at wire. | 2026-08-19 |
| **D20** | DETF burn `tokenOut` | Unified Uni V4 DETF: burn may pay only resolved **`burnRoutes`** tokens ([`DETF_INSTANCE_IO_ROUTING_PRD.md`](./DETF_INSTANCE_IO_ROUTING_PRD.md) §16). Other families: any reserve token or SE buffer / rate asset of a vault-share leg until their I/O tables ship. Quote with D8 on the DETF–tokenOut pair. | 2026-08-26 |
| **D21** | `creator == 0` | If `PkgArgs.creator` is `address(0)`, mint token id **2** to `feeTo()`. `feeTo` then holds ids **1 and 2** (recovery if the deployer omitted a creator). Do not skip id 2 or force `c = 0`. | 2026-08-19 |
| **D22** | Claim paths ungated | `exchangeIn` DETF ↔ rebasing claim is **not** subject to mint/burn synthetic threshold gates. Live-only is enough. | 2026-08-19 |
| **D23** | Exact-out | If a **closed-form** exact-out exists on that family’s reserve curve, support it. If not, keep reverting `InvalidRoute`. No binary-search solvers. | 2026-08-19 |
| **D24** | Bonus vs bond matching | Free mint/burn and bond join are **different processes**. Live **mint** applies the **amountIn bonus** (D8) so expanding supply can move price. Live **burn** contracts supply (D12/D20; D8 bonus still off on burn). A bond mints **unboosted** proportional matching DETF (`G`) into liquidity to **deepen** the book, not to move price. Do not size `G` from a D8 boosted quote. | 2026-08-19 |
| **D25** | Mature close | Process unchanged: proportional withdraw, rejoin DETF to id 0, do not burn that DETF. Remainder: Default = full non-DETF basket. Unified Uni V4 Custom close = **exactly one** hook pair + leftover `ownerSwapExactIn` in `tokens()` order ([`DETF_INSTANCE_IO_ROUTING_PRD.md`](./DETF_INSTANCE_IO_ROUTING_PRD.md) §6 / §16.5). | 2026-08-26 |
| **D26** | `PkgArgs.creator` | Every true DETF family `PkgArgs` has `address creator`. Wire mints token id 2 to that address. `creator == 0` still follows D21. | 2026-08-19 |
| **D27** | Live-mint `U` = D8 `Gross` | Q2 locked. On a live liquid mint, `U` is the entire D8 `Gross`. D3 then splits it. The non-user slice is **only** pot (old `feeToDetf` + `inventoryDetf` destinations merge). See §9. | 2026-08-19 |
| **D28** | Ids 1–2 claim tests | Every family must prove `feeTo` (id 1) and creator (id 2) **can** `claimRewards`, and that after D2 share top-ups and pot deposits they receive **only** their `effectiveShares` share of **new** pot. No leak that pays them more than due. Ship gate. Matrix in §20. | 2026-08-19 |
| **D29** | Reserve donation | Permissionless donate of joinable capital (`pairToken` / `vaultShare` / family mint-bond tokens / DETF / already-minted reserve LP) onto the Bond NFT. **No DETF mint. New `originalShares` to id 0 only.** Public function is on the Bond NFT; Uni V4 host join stays DETF-only (D9). Distinct from D11 live mint. Full law: [`DETF_RESERVE_DONATION_PRD.md`](./DETF_RESERVE_DONATION_PRD.md). | 2026-08-22 |
| **D30** | Owner host ops while locked | Uni V4 DETF-reserve hooks (and Balancer analog inside Vault unlock) must let the **owner (the DETF diamond)** add/remove LP and **swap exact-in/exact-out** between reserve legs **while PoolManager / Vault is already unlocked**. Do not use Uniswap SwapRouter or a nested `unlock` if one is open. Required for D15’s residual DETF buy and D29 join. Owner `depositSingle` at hook `MINIMUM_LIQUIDITY` is allowed and **must mint lpOut > 0**. | 2026-08-22 |
| **D31** | Expansion then gate | Live **mint**, live **burn**, **redeemClaim**, and **closeBondMature** **realize pending natural expansion first** (Policy; Open is a no-op). Then recompute synthetic from **minted** `totalSupply` and apply Policy mint/burn gates. If the post-realize synthetic fails the gate, the **whole tx reverts** (expansion does not stick). Desired: expansion can block a mint/burn that would overshoot the band. Donate does **not** realize. | 2026-08-22 |

### 0.2 Accepted refactor decisions — D32–D66

These are product decisions, not permission to edit code. Normative detail is in §24; §24.9 records resolved questions and the engineering specification covered by the separately authorized implementation plan.

| ID | Topic | Decision | Date |
|----|-------|----------|------|
| **D32** | Pendle Standardized Yield | Add SY support to all SE vaults and DETFs while retaining `IStandardExchangeIn` and `IStandardExchangeOut`. Target **Pendle's interface**, not the differing ERC-5115 draft ABI. The rebasing staking token uses a **non-rebasing SY wrapper**. | 2026-09-06 |
| **D33** | Token decimals | `detfToken` and its rebasing staking token both use **9 decimals**. Staking and unstaking exchange equal raw amounts at **1:1**. Internal share/index and price precision may be higher. This explicitly replaces the former 18-decimal DETF/claim-token assumption. | 2026-09-06 |
| **D34** | Funded DETF staking | The rebasing token represents **held DETF**, not LP or an LP zap-out quote. User issuance requires a DETF deposit; unstaking returns held DETF at 1:1. Additional funded DETF rewards increase holder balances; no rewards means a flat rebase. Staking backing is unavailable for reserve joins or other protocol spending. | 2026-09-06 |
| **D35** | Protocol LP ownership | All reserve LP acquired by the DETF belongs to the DETF collectively. **Bonds no longer own or track redeemable LP principal.** Mint and bond payments build protocol reserves. DETF direct-redemption quotes and withdrawals use protocol-owned LP, never an LP entitlement attributed to a bond holder. | 2026-09-06 |
| **D36** | Bonds buy vesting DETF | Retain the existing proportional DETF self-leg `G`, minted and joined with actual payment as protocol-owned liquidity, and the first bond that opens the DETF. **In addition**, mint a separate vesting allocation: apply the existing duration bonus to payment for the reserve quote, then retain the existing gross/net issuance split. Stake the purchased principal in bond escrow and unlock it **linearly**. | 2026-09-06 |
| **D37** | Seigniorage and expansion destination | Seigniorage and natural-expansion rewards fund the **DETF reserve backing the staking token**. Preserve existing issuance/fee formulas and configuration except where the accepted changes require different inputs or accounting. The staking portion funds rebases; fee/creator portions fund their sDETF receipts under D40. Rewards are not automatically joined back into LP or paid twice through the former user-bond reward ledger. | 2026-09-06 |
| **D38** | Bonds stake during vesting | Stake the purchased DETF allocation on the bond holder's behalf while principal vests. **Staking rewards are claimable during vesting**, including rewards earned on unvested principal. Reward claims do not reduce original principal or accelerate its vesting. Track the bond's remaining staking shares separately from its DETF principal ledger. | 2026-09-06 |
| **D39** | Price-gate swap fallback | A failed primary mint/burn price gate **selects a reserve-pool swap instead of reverting**. Allowed mint: primary issuance; blocked mint: buy existing DETF. Allowed burn: primary burn against protocol reserves; blocked burn: sell existing DETF. The fallback swap itself neither mints nor burns DETF. Previews and execution must choose the same route and enforce user limits. | 2026-09-06 |
| **D40** | Fee/creator payouts in funded sDETF | Calculate fee/creator DETF allocations under the existing rules, stake those amounts on the recipients' behalf, and issue equal amounts of **ordinary transferable sDETF**. Apply the distribution's staking rebase before issuing its new fee receipts. Holders may **unstake 1:1 to DETF**, including their entire balance. Their fee/creator entitlement persists independently of sDETF ownership, so later applicable issuance pays new sDETF even after a full redemption. | 2026-09-06 |
| **D41** | Linear first-bond price | Use the existing **`PkgArgs` initial/opening price** as the fixed linear conversion rate for the first bond's purchased DETF allocation. Apply the agreed duration bonus to its quote input, then the existing gross/net fee split to the resulting DETF. Retain the separate unboosted liquidity self-leg and family bootstrap. Subsequent bonds use the live reserve curve. | 2026-09-06 |
| **D42** | Eight-hour expansion epochs | **Clarified by D49/D50:** the **8-hour epoch applies only to automatic expansion**. Seigniorage distributes immediately when minted. Preserve funded-only growth; D47 governs expansion participation and D48 preserves standing fee/creator reward recipients even with zero staked balances. | 2026-09-06 |
| **D43** | Bond claims pay only sDETF | Bond principal and earned staking rewards are claimed **only as sDETF** from the bond's funded staking position. The benefit is discounted DETF acquisition and staking while principal vests. No additional LP entitlement, bond-specific reward multiplier, or direct DETF/payment-token payout is created. Holders may separately unstake their claimed sDETF to DETF 1:1. | 2026-09-06 |
| **D44** | Separate DETF SY token | Expose raw DETF's SY integration through a **separate SY share-token address**. The wrapper mints/burns its own shares around acquired/released DETF, including when the DETF exchange uses a supply-neutral reserve swap. Preserve the DETF's existing SE interfaces. The previously accepted static sDETF wrapper remains the staking-yield integration. | 2026-09-06 |
| **D45** | Staking SY routes | The staking SY accepts direct **sDETF**, direct **DETF**, and all existing configured DETF input routes. It redeems to sDETF, DETF, and all existing configured DETF output routes. Compose existing exchange and stake/unstake operations, preserving direction-specific route support, fees, slippage checks and price-gate fallback. | 2026-09-06 |
| **D46** | Nine-decimal staking SY | The static staking SY also uses **9 decimals**, matching DETF and sDETF. Its WAD exchange rate converts raw SY units to raw DETF units. Use the actual DETF/sDETF metadata; the optional Scaled18 integration profile is not selected. | 2026-09-06 |
| **D47** | Expansion-epoch staking eligibility | At each **8-hour expansion boundary**, deposits already present participate proportionally without time weighting. Settle due expansion before processing new deposits or withdrawals. A deposit made before the boundary participates; new principal entering in the transaction that processes the boundary comes afterward. D49 makes seigniorage a separate immediate distribution. | 2026-09-06 |
| **D48** | Standing reward recipients remain eligible | `feeTo()` and the creator retain their standing reward entitlements **even when they hold no sDETF**. Zero staked balances do not mean zero reward recipients. Preserve their existing reward weights/allocation calculation; if only their standing weights remain eligible, distribute to those weights as usual and pay funded sDETF. No special carry-forward policy is introduced on the assumption that no recipient exists. | 2026-09-06 |
| **D49** | Immediate seigniorage distribution | Distribute the seigniorage share from every applicable DETF issuance **immediately in the issuing transaction**, including ordinary mint and both bond issuance contributions. Do not queue it for an epoch. Fund actual DETF, rebase eligible stake, then issue the fee/creator sDETF for that distribution. Preserve existing issuance bases and percentages; expansion remains its own reward source without an extra recursive seigniorage charge. | 2026-09-06 |
| **D50** | Expansion clock and combined catch-up | Start the automatic-expansion clock at the **first successful bond**, with fixed **8-hour boundaries** thereafter. After inactivity, perform **one aggregate expansion mint and distribution** for all eligible pending expansion; do not replay missed distributions or compound hypothetical historical fee receipts. Only actually minted and funded DETF participates. Settle due expansion before new principal or withdrawals; rebase eligible stake before issuing its fee/creator sDETF. | 2026-09-06 |
| **D51** | Price gating is mandatory | Every new DETF has the price-gated behavior formerly selected by **Policy**. Remove the deploy-time enable/disable choice and **Open** mode. Retain threshold configuration and D39's mandatory reserve-swap fallback when a primary gate fails. First-bond bootstrap, funded staking and bond claims retain their existing gate exemptions. | 2026-09-06 |
| **D52** | No expansion catch-up caps | **Remove all expansion catch-up caps across every DETF family:** elapsed-time limits, maximum epoch counts, supply-per-update percentages and any equivalent amount ceiling. Calculate pending expansion across the entire unsettled completed-epoch interval and mint/distribute it once under D50. Remove cap configuration rather than retaining an optional capped deployment profile. Existing implementations do not override this requirement. | 2026-09-06 |
| **D53** | Consolidate public operations into SE/SY | Use `IStandardExchangeIn` / `IStandardExchangeOut` and Pendle SY for supported fungible exchange, stake/unstake and wrapper routes. Deprecate duplicate standalone functions such as `mintClaim`, `buyClaim` and `redeemClaim`; expose their surviving routes through the standard interfaces and omit obsolete selectors from new deployments. Keep distinct NFT lifecycle operations only where their position-specific semantics cannot be expressed by SE/SY. This applies regardless of which agent introduced a function. | 2026-09-06 |
| **D54** | Remove unused storage | Remove unused members of affected `Storage` structs as part of the refactor, together with obsolete initialization, accessors and dependent dead code. Retain only state needed by the simplified DETF, funded staking, vesting bonds, standing fee rights, protocol custody and standard interfaces. New layouts do not retain dead fields solely for historical compatibility; this does not authorize upgrading or reinterpreting existing deployed storage. | 2026-09-06 |
| **D55** | Redesign bond NFT SVG and metadata | Replace the LP/effective-shares and single-unlock depiction with the current model: purchased DETF principal, linear vesting progress, remaining principal, claimable principal and independently claimable staking rewards, with payouts clearly labeled sDETF. Image and metadata must agree with funded position accounting and distinguish retained standing fee/creator NFTs from purchased bonds. | 2026-09-06 |
| **D56** | Composed Stable rich opening | Carry opening price and seed ratios into deployment arguments. The first bond uses the configured opening price linearly for purchased DETF and the configured seed ratios for reserve liquidity. Support rich launches like the other DETFs; never hardcode a 1:1 first-bond price. | Owner clarification |
| **D57** | Full-range position vaults | Uniswap V3, V4 and Slipstream deploy across the maximum usable tick range for the pool's tick spacing. Retain existing ordinary-launch full-range behavior in V3/V4, align Slipstream, and convert imported positions to the same full-range structure. **Unfinished Slipstream work is subsequently deferred by D66.** | Owner clarification |
| **D58** | Position accounting and sleeves | Use V2-style proportional ownership and constant-product accounting. Derive deployed token amounts with exact concentrated-liquidity math, then include sleeve balances and earned fees exactly once. Sleeves support operations while the underlying pool cannot be modified. | Owner clarification |
| **D59** | Two-token activation | Require both tokens for initial position-vault activation, as in V2. Preserve subsequent single-token deposits and sleeve operation during pool locks. | Owner clarification |
| **D60** | Exclude Balancer-hosted DETFs | Stop functional refactoring of Balancer-hosted DETF families; further changes there are limited to keeping the repository compiling. This does not exclude unrelated SE vault work. Retire the pending Balancer reserve-LP bond-payment question from this refactor. D56 remains historical, with further Composed functional implementation outside scope. | Subsequent owner scope decision |
| **D61** | Immutable reserve liquidity policy | Expose `ownerOnlyLiquidity` in DETF deployment arguments and user-facing creation configuration; carry and verify it against the reserve hook. `true` restricts direct additions to DETF and removals to DETF plus the current Fee Collector under D65. `false` permits public deposits and redemption of owned or authorized LP. In both modes the DETF remains hook owner with its privileged operations; creator selection grants no hook administration. No later toggle; public swaps remain available. | Subsequent owner decision |
| **D62** | Own V4 reserve LP as bond payment | Accept only the instance's own V4 reserve LP; transfer the entire LP payment into protocol custody. Value the proportional non-DETF assets with the reserve family's accounting/pricing, retaining distinct legs and buffered-SE accounting without double counting. Exclude the direct DETF self-leg from purchased-allocation valuation while retaining that DETF in acquired protocol inventory. Do not unwind LP just to quote its value. | Subsequent owner decision |
| **D63** | Funded LP-payment bond economics | Settle due expansion, snapshot LP valuation, then accept payment. Apply the duration bonus once, agreed issuance split, immediate staking, linear principal vesting and claimable rewards. Mint no additional matching DETF liquidity leg (`G = 0`); LP already supplies liquidity. Charge issuance seigniorage only on newly issued amounts, never on DETF already contained in the LP. Preserve first-bond activation. | Subsequent owner decision |
| **D64** | Custody and permissions are separate | Account for externally held LP in either permission mode. Bonding legitimately held LP transfers it to protocol ownership. Redemption, synthetic pricing and expansion count only actual protocol-owned LP, excluding external holdings until received. Permission to perform liquidity operations does not establish ownership. | Subsequent owner decision |
| **D65** | Restricted-mode Fee Collector redemption | The current `feeTo()` Fee Collector may redeem reserve LP it holds in restricted mode. Resolve `feeTo()` dynamically so rotation changes this removal permission; do not cache or grandfather the original address. Add the owner-operated Fee Collector redemption path. Additions remain DETF-only; ordinary public holders remain unable to withdraw directly in restricted mode. LP possession/allowance is still required; this grants no right to protocol-owned LP. | Owner approved after investigation |
| **D66** | Slipstream deferred from this release | Defer all unfinished Slipstream work from this release by owner decision. Robinhood targets Uniswap V4. Preserve completed Slipstream changes, existing functionality, tests and validation evidence. Permit only compilation maintenance or compatibility edits required by shared V4 changes; no pending Slipstream functional, full-range/import conversion, accounting, native SY, deployment/UI, test, fork or integration completion gate remains. Shared V4 work and other approved scope continue; no unresolved release requirement is created. | Subsequent owner scope decision |

---

## 1. Intent

The target refactor has a nine-decimal DETF ERC-20, protocol-owned reserve liquidity, a nine-decimal staking receipt backed 1:1 by held DETF, and bond NFTs representing linearly vesting DETF purchases. Bond allocations remain staked during vesting; staking rewards can be claimed before principal fully vests. The reserve prices primary issuance/redemption and supplies the swap fallback when a price gate blocks those primary operations. SY support provides the Pendle integration surface (§24).

The accepted refactor is specified in §24: ownership (§24.1), funded staking (§24.2), reward destination (§24.3), bond purchase (§24.4), vesting and reward claims (§24.5), mandatory swap fallback (§24.6), and Pendle SY (§24.7). The historical host curves, route tables, and deployment framework remain references where compatible. This document records product decisions; it does not redirect already-running implementation work.

The earlier LP-principal bond, `originalShares`/`effectiveShares`, token-id-0 claim, and LP-unwind processes described in §§3–23 are the historical baseline. They do not define the replacement staking or vesting-bond entitlements. §24.8 identifies which rules are replaced and which require reconciliation before implementation.

**In-scope families (after D1):**

| Host | Family |
|------|--------|
| Balancer V3 | Single SE, multi-vault weighted, mixed-buffer, composed stable |
| Uni V4 | Unified DETF bound to CP, Orbital, Weighted or Curve Quad Stable hooks |

---

## 2. D1 — Delete DualLiquidity (LOCKED)

`DualLiquidityLinkedCrossVersionUniswapVault` is **removed**. It has no bond NFT. Usage fees are ERC-20 share inflation to `feeTo()`. It is a pro-rata BPT vault that was only layout-co-located under `detf/`. It will not be repaired into a true DETF.

Do **not**:

- Add a bond NFT, claim token, thresholds, or seigniorage to DualLiquidity.
- Leave a deprecated-but-shipping package, facet, or DFPkg.
- Relocate the Solidity outside `detf/` as a surviving product.

### 2.1 Delete surface (inventory, not an impl checklist)

| Surface | Path / note |
|---------|-------------|
| Production Solidity | `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` |
| Fork TestBase + suite | `test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` |
| Family product docs | `docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/` |
| Agent law | [`docs/agent/INDEXEDEX_AGENT_LAW.md`](../../../docs/agent/INDEXEDEX_AGENT_LAW.md) family table, directory map, TestBase list |
| Inventories | `docs/DETF_POOL_INTEGRATION_INVENTORY.md`, content inventory, codebase map, skill catalog if they list the family |
| Research | `research/scenarios/dualLiquidityLinkedCrossVersion/`, CCA rehearsal DualLiquidity bootstrap. Historical findings may stay as history. They must stop treating DualLiquidity as a live product. |

Exact file list and link-fix width belong in a later implementation plan.

### 2.2 Consequences

- The DETF family table lists only true DETFs.
- DualLiquidity is not a behavioral reference for new families.
- Nested-SE matrices that used DualLiquidity as a leg use another production SE or true DETF instead.

### 2.3 Supersedes (product existence only)

- [`docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVault_PRD.md`](../../../docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVault_PRD.md)
- [`DualLiquidity_CrossVersion_Directory_Move_PRD.md`](../../../docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidity_CrossVersion_Directory_Move_PRD.md)

Those files stay until the delete pass removes them. Do not implement DualLiquidity features against them after 2026-08-18.

---

## 3. D2 — Fee/creator effective shares on a new user bond (LOCKED)

`feeTo()` and the DETF creator do **not** receive a DETF mint. They hold standing bond NFTs and claim the same pot every other bonder claims: inventory DETF and natural expansion paid on `effectiveShares`.

After **any** change to `O` (user bond open, sell-in to id 0, `buyClaim` / `exchangeIn` DETF→claim, protocol compound `addToDETFNFT`, other principal 4626 mint), re-run the same top-up so ids 1 and 2 stay at `f` and `c`. Mint the user’s `effectiveShares` first when the event is a user bond, then top up.

`f` and `c` are WAD fractions (`1e18` = 100%). Their values are **not** locked. Constraint: `f + c < 1e18`.

### 3.1 Symbols

| Symbol | Meaning |
|--------|---------|
| `f` | Target fraction of total `effectiveShares` for the `feeTo` NFT |
| `c` | Target fraction of total `effectiveShares` for the creator NFT |
| `F0`, `C0` | Those NFTs' `effectiveShares` **before** this top-up |
| `O` | Sum of `effectiveShares` of **everyone except** the fee and creator NFTs, **after** the user's new shares are on the ledger (other users + protocol NFT + this user bond) |
| `T` | Implied new total `effectiveShares` after the top-up |
| `dF`, `dC` | Shares to add to the fee NFT and the creator NFT |

### 3.2 Formula (normative)

```
T  = O * 1e18 / (1e18 - f - c)
F* = T * f / 1e18
C* = T * c / 1e18
dF = F* > F0 ? F* - F0 : 0
dC = C* > C0 ? C* - C0 : 0
```

Integer math: **floor** each division (`mulDiv`). Do not add shares if the target is already at or above (`dF` / `dC` are never negative on this path). Flooring may leave realized weights slightly under `f` and `c`. That is required. Do not round up.

After the add:

```
F0 + dF ≈ f * (O + dF + dC)
C0 + dC ≈ c * (O + dF + dC)
```

If `f == 0` then `dF == 0`. If `c == 0` then `dC == 0`.

### 3.3 Order

1. Open the user bond (`createPosition` / `createPositionWithEffectiveBase`). User `effectiveShares` now sit in `O`.
2. Read `O`, `F0`, `C0`.
3. Compute `dF`, `dC`.
4. Add `dF` / `dC` as **effective-share weight only** on the standing fee and creator NFTs. Do not mint DETF to `feeTo()` or the creator. Do not give those NFTs redeemable reserve principal on this path.

### 3.4 Worked example

First user bond mints `100e18` effective shares. No prior positions. `f = 0.10e18`, `c = 0.05e18`.

```
O  = 100e18
T  = 100e18 * 1e18 / 0.85e18 = 117.647...e18
F* = 11.764...e18
C* = 5.882...e18
```

Fee NFT gets `11.764...e18`, creator NFT gets `5.882...e18`. Fee is 10% of the new total, creator is 5%, user (and any protocol principal) is the remaining 85%.

### 3.5 What D2 does not lock

- How the standing NFTs are created at wire (ids 0–2). Id 1 does **not** migrate on `feeTo()` change (D19).

---

## 4. D3 — Bond-holder pot is a cut of free `userDetf` (LOCKED)

`p` is a WAD fraction of **free DETF** (`U`) **when that route mints free DETF**. On a **live liquid mint**, `U` **is** the D8 `Gross` (D27). Whether a bond mints free `U` is **not locked** (§9.2). It is **not** a fraction of:

- join / self-leg DETF minted into the reserve
- BPT or hook LP (bond principal)
- the user’s bond `originalShares` / `effectiveShares`

**Redirect, not extra inflation.** Split as before, destination unified:

```
user wallet      = U * (1e18 - p) / 1e18
bond-holder pot  = U * p / 1e18
```

The pot-side is **only** minted to the bond NFT vault as inventory (reward token). That includes what shipped code called `feeToDetf` **and** `inventoryDetf`. `feeTo()` and the creator do **not** receive a DETF mint. They claim this pot via token ids 1 and 2 (D2).

`p` is the oracle seigniorage incentive (D5/D6). Floor `mulDiv`. If `U == 0` (a route that mints no free user DETF), the pot from this rule is 0.

Whenever a route mints free `U`, this redirect applies. Bond join DETF is funded by **D4**, not by this redirect.

---

## 5. D4 — Additional pot mint on bond join DETF; expansion excluded (LOCKED)

Bond join / self-leg DETF (`detfForPool_` / `detfForJoin_`) stays in the reserve. It is not liquid user DETF. It still **counts** as minted DETF for the seigniorage share to existing bond holders.

If a bond mints `G` DETF into the reserve (the **unboosted** proportional self-leg, D24):

```
join into reserve     = G          (unchanged)
additional pot mint   = G * p / 1e18
```

That additional amount is minted to the bond NFT vault as inventory. It is **new supply**, not taken out of `G`. Floor `mulDiv`. If `G == 0` (BPT-only lock, no self-leg mint), this term is 0.

**Natural supply expansion is excluded.** Expansion is already minted wholly into the bond-holder pot. Do not mint `p * expansion` on top.

**This `p` rule replaces the current `inventoryDetf` half-incentive** in `_splitMintedDetf`. Do not keep both. `feeToDetf` remains removed (D2/D3). After D3+D4 the pot is only:

| Source | How the pot is funded |
|--------|------------------------|
| Free `userDetf` (mint or bond) | D3 redirect: `p * U` |
| Bond join DETF | D4 additional: `p * G` |
| Natural expansion | Full expansion mint into the pot; **no** extra `p` |

BPT/LP principal is still not a base (it is not DETF).

---

## 6. D5 — Vault Fee Oracle: `p` / `f` / `c` (LOCKED)

### 6.1 Existing fields (do not invent new ones for these)

| Role | Oracle field | Notes |
|------|----------------|-------|
| Lock-duration bonus for the **purchaser** | `BondTerms` (`minLockDuration`, `maxLockDuration`, `minBonusPercentage`, `maxBonusPercentage`) | Already used by `DETFBondNFTMathLib._calcBonusMultiplier`. Not `p`/`f`/`c`. |
| **`p`** (pot size) | `seigniorageIncentivePercentageOfVault` (3-tier) | Initial global from oracle PkgArgs (D6), not a Solidity constant. Replaces the old “half incentive → `inventoryDetf`” reading of this field. |
| Collector address | `feeTo()` | Owner of the fee-recipient bond NFT. Not a percentage. |

### 6.2 New fields: `f` and `c`

Add the same 3-tier pattern (vault → type → global; stored `0` = unset). WAD. **`f + c < 1e18`** at every tier that is set (reject a write that would resolve to `f + c >= 1e18`).

| Role | Proposed names (Query / Manager) |
|------|----------------------------------|
| **`f`** (`feeTo` weight of the pot) | `defaultSeigniorageFeeToSharePercentage` / `…OfTypeId` / `seigniorageFeeToSharePercentageOfVault` · `setDefault…` / `set…OfTypeId` / `setSeigniorageFeeToSharePercentageOfVault` |
| **`c`** (creator weight of the pot) | `defaultSeigniorageCreatorSharePercentage` / `…OfTypeId` / `seigniorageCreatorSharePercentageOfVault` · matching setters |

Optional atomic setters (enforce `f + c < 1e18` in one tx):

- `setDefaultSeignioragePotShares(uint256 f, uint256 c)`
- `setDefaultSeignioragePotSharesOfTypeId(bytes4, uint256 f, uint256 c)`
- `setSeignioragePotSharesOfVault(address, uint256 f, uint256 c)`

Creator **recipient address** is deploy-time `PkgArgs` on the DETF instance, not an oracle value.

### 6.3 Tuple getters (minimize oracle calls)

Keep existing singles (`bondTermsOfVault`, `seigniorageIncentivePercentageOfVault`, `feeTo`, and the new `f`/`c` singles). Add:

| Function | Returns | Call site |
|----------|---------|-----------|
| `seigniorageSplitOfVault(address)` | `(p, f, c)` | Live mint (needs `p`; `f`/`c` unused unless that path also touches shares) |
| `seigniorageSplitAndFeeToOfVault(address)` | `(feeTo, p, f, c)` | Mint or wire that also needs the collector |
| `bondTermsAndSeigniorageOfVault(address)` | `(feeTo, BondTerms terms, p, f, c)` | **Bond** (lock bonus + D3/D4 pot + D2 top-up in one call) |

Existing `seigniorageIncentivePercentageOfVaultAndFeeTo` and `bondTermsAndFeeToOfVault` stay. DETF bond/mint paths should prefer the new tuples.

### 6.4 What D5 does not lock

- Implementation of the new oracle selectors (product/API only). Initial numbers are D6. Usage fee on DETF mint/burn is **off** (D14).

---

## 7. D6 — Initial `p`, `f`, `c` from oracle PkgArgs (LOCKED)

Do **not** treat `DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE` (or any new `DEFAULT_*` for `f`/`c`) as product law. The Vault Fee Oracle’s **first** global values are written from **PkgArgs at oracle/manager deploy** (`IndexedexManagerDFPkg.PkgArgs` today). Later vault/type overrides still use the 3-tier setters.

**First PkgArgs values** (WAD), from the public nested percents:

| Public line | Stored |
|-------------|--------|
| 5% of minted DETF into the bond-holder pot | `p = 5e16` |
| Of that pot, purchasers get 60% | `1 - f - c = 0.60e18` |
| Of that pot, `feeTo` + creator get 40% | `f + c = 0.40e18` |
| Of that 40%, creator 70% | `c = 28e16` (0.28 = 0.40 × 0.70) |
| Of that 40%, `feeTo` 30% | `f = 12e16` (0.12 = 0.40 × 0.30) |

Check: `f + c = 0.40e18 < 1e18`. D2 then keeps ids 1 and 2 at those weights after each user bond.

Post-deploy, the oracle owner may still change globals / type / vault overrides. D6 only locks the **initial** PkgArgs and forbids a hardcoded constant as the source of truth.

---

## 8. D7 — Reserved bond NFT token ids (LOCKED)

On every true DETF bond vault, these ids are **fixed**:

| Token id | Role | Owner | Redeemable BPT/LP | Sell → rebasing claim |
|----------|------|-------|-------------------|------------------------|
| **0** | Protocol / rebasing-claim reserve | Bond vault (`address(this)`) | Yes (claim backing) | N/A (already protocol) |
| **1** | `feeTo()` standing reward bond | `feeOracle.feeTo()` | No | **Forbidden** |
| **2** | Creator standing reward bond | DETF `PkgArgs.creator` | No | **Forbidden** |
| **≥ 3** | User bonds | Purchaser | Yes (family principal) | Allowed when mature |

Wire path mints **0, then 1, then 2** before any user `createPosition`. User bonds must not receive ids 0–2.

`sellPositionToDetfNft` (and any equivalent) **reverts** for token ids **1** and **2**. They only `claimRewards` on the pot. Id 0 remains the only principal that backs the rebasing claim token.

**Sentinel:** today’s code often treats `detfNftId == 0` as “unwired”. Under D7, 0 is a **valid** protocol id. Wired-state must use a dedicated flag or “bond vault address set”, not `id == 0`.

---

## 9. D27 — Live-mint `U` is the D8 `Gross`; whole split to the pot (LOCKED)

Q2 is locked. This is **not** about bond `G` (D24).

### 9.1 Live mint

`p` is the oracle `seigniorageIncentivePercentageOfVault` (D5/D6). On a **live liquid mint**:

1. **D8 size.** `Gross = curve(amountIn * (1 + p))`. User deposits unboosted `amountIn`. No DETF into the pool (D11).
2. **`U = Gross`.** There is no leftover usage-fee peel and no half-incentive `inventoryDetf` as a second base.
3. **D3 split, as before**, but the **entire** non-user slice is bond-holder inventory:

```
user wallet      = Gross * (1e18 - p) / 1e18
bond-holder pot  = Gross * p / 1e18
total minted     = Gross
```

Do **not** mint `feeToDetf` to `feeTo()`. Do **not** mint DETF to the creator. Those addresses share this pot only by holding token ids **1** and **2** and calling `claimRewards` (D2, D7, D14). That is why those standing NFTs exist.

Floor `mulDiv`. Same `p` enlarges the D8 quote and then cuts the pot from `Gross`. On a linear book the user can receive slightly less than an unboosted quote; that is accepted.

### 9.2 What D27 does not lock

Whether a **bond** still mints free `U` to the bonder’s wallet (shipped families mint extra `userDetf` from a split of `G`). D24 only forbids boosting `G`. If bonds keep a free split, this same destination rule applies: user slice to the user, **all** of the old `feeToDetf` + `inventoryDetf` to the pot, plus D4’s `p * G`. If the bond incentive is only matching `G`, then `U = 0` on bonds and the pot from a bond is only D4.

The impl plan uses **launch default L1**: bonds still mint free `U = G`, D3 + D4 both run. Amend this section if product wants `U = 0` on bonds instead.

---

## 10. D8 — Quote: bonus on amount in, same curve as the reserve (LOCKED)

**Applies only when the reserve is live** (first bond done, D16). Empty-pool / first-bond sizing stays family-owned (creation rate, weights, amp + first amounts). Do not run the live-curve + amountIn bonus on an empty book.

**Applies only to free liquid mint and burn**, not to bond join `G` (D24).

Every in-scope family uses this process for **how much free liquid DETF to mint** (and the inverse spirit for **burn return**):

1. Take the user’s real capital (`amountIn`: vault shares, buffer, or pair, as the family defines).
2. Apply the seigniorage **capital bonus to amount in**: `amountInBoosted = amountIn * (1 + p)` where `p` is the oracle seigniorage incentive (D5/D6).
3. Compute amount out with the **same curve and live reserves** as the reserve host (Balancer weighted / stable math, or Uni V4 hook book).
4. That out is **gross** DETF. **`U = Gross` (D27).** D3 splits it: user `(1 - p) * Gross`, pot `p * Gross`. The pot-side is inventory only (no `feeTo` mint). The user still only **deposits unboosted** capital. The bonus is a **quote** incentive, not extra tokens into the pool. D4 (`p * G`) is a **bond** term and is not part of this mint path.

Shipped Single SE / MVW / MixedBuffer / Composed / Uni V4 already quote this way on live mint. MixedBuffer also **joins gross DETF** on live mint; that join behavior is **not** required by D8 (D11). D8 is the quote rule only.

Burn must be honest against the same book: payout is what that curve can return from reserves the DETF can actually remove. Uni V4: that is DETF-controlled LP (D9). Balancer: public join is still allowed (D9 exception); coverability is therefore not the same invariant. D20 still: capital bonus does **not** apply on burn unless a later lock says otherwise.

Do not size bond matching DETF with this process.

**D31 (mint/burn execute):** before the D8 quote and before the Policy gate, **realize pending expansion** (mint expansion DETF to the Bond NFT, Policy only). Then gate on synthetic computed from the **post-realize** `totalSupply`. Views `isMintingAllowed` / `isBurningAllowed` must match: they count pending expansion in the denominator so they equal post-realize synthetic without minting in the view. If realize + gate fails, the whole tx reverts.

---

## 11. D9 — Only the DETF may add or remove reserve liquidity (LOCKED)

If outsiders can add LP, the reserve curve sees liquidity the DETF cannot withdraw. Mint/burn quotes (D8) would then not be coverable.

**Invariant:** for every true DETF, the liquidity that appears in the reserve quote is liquidity **only that DETF instance** can add or remove.

### 11.1 Uni V4 hooks (implementation required)

Hooks used as a DETF reserve must support:

- **MultiStepOwnable** (Crane operable / ERC-8023 pattern), owner set to the **DETF diamond**.
- A **deploy-time flag** (hook `PkgArgs`) that locks add/remove liquidity to **`onlyOwner`**.
- When the flag is on: no permissionless `addLiquidity` / `removeLiquidity` / native V4 `modifyLiquidity` for third parties. Swaps may stay public (volume).
- When the flag is off: existing permissionless LP behavior (non-DETF hook uses).

**Every Uni V4 DETF instance deploys its reserve hook with the flag on.** Owner = that DETF. The DETF remains unowned/immutable; the hook is owned by the DETF, not by an EOA.

Applies to CP, Orbital, Weighted, and Curve Quad buffer hooks (package path, not leftover monomorph CREATE3 unless that hook is still the reserve).

### 11.2 Balancer V3 families (open liquidity, for now)

**Leave Balancer DETFs on their current open public join.** Outsiders may add and remove liquidity on the reserve pool. That is an allowed deviation from the Uni V4 owner-only rule. Do not add pool hooks, router allowlists, or DETF-held-only BPT in this alignment pass in order to close Balancer join.

Coverability of a D8 burn quote against Balancer reserves is therefore **not** the Uni V4 invariant. Accept that until a later lock.

Applies to Single SE, multi-vault weighted, mixed-buffer, and composed stable.

### 11.3 Owner ops while the host is locked (D30)

Public swaps stay permissionless (default **yes**). The DETF, as hook owner, also needs **private** swap and LP add/remove that work when Uniswap `PoolManager` is **already unlocked** (this transaction is inside `unlockCallback`, or a nested liquidity op). Claim redeem (D15) must **buy DETF** on the residual reserve after a proportional LP withdraw; donate (D29) must `depositSingle` in the same class of tx. Neither may call Uniswap SwapRouter or start a second `PoolManager.unlock` if one is open.

**Required on every Uni V4 hook used as a DETF reserve** (CP, Orbital, Weighted, Curve Quad buffer packages):

- Owner-only exact-in and exact-out swap between reserve legs (DETF/raw ↔ pair / buffer legs).
- Owner-only `deposit` / `depositSingle` / `withdraw` / `withdrawSingle` (already D9 `onlyOwner` when the flag is on).
- If `PoolManager` is locked: settle on the **current** unlock or use **internal book settlement** (same class as zap internal swaps). If it is not locked: the owner may open a normal unlock.
- Non-owner cannot use this path.

Balancer: the analog is a swap/join/exit **inside** an already-open Vault unlock, not a nested Router call.

### 11.4 What D9 / D30 do not lock

- Whether hook **swaps** stay permissionless for the public (default **yes**).
- Ownership transfer of the hook after DETF deploy (default: **no**; DETF is immutable owner).
- Implementation of MultiStepOwnable on each hook package.
- A later pass that might close Balancer join. Not this PRD’s current law.

---

## 14. D10 — ERC-4626 reserve shares, sell-in, rebasing claim (LOCKED)

Applies to **every** true DETF family.

### 14.1 Bond purchasers (token id ≥ 3)

Reserve LP from the join (`G`: BPT or hook LP) is the **asset**. The bond vault mints **original shares** with standard ERC-4626:

```
if totalOriginalShares == 0 or totalLp == 0:  originalShares = G
else:                                         originalShares = G * totalOriginalShares / totalLp
```

Lock-duration bonus (existing `BondTerms` curve) applies **only** to reward weight:

```
effectiveShares = originalShares * lockBonus / 1e18
```

Do **not** use open-time mids (or any other numeraire) as `effectiveBase` for this ledger. Orbital / Weighted / Quad `createPositionWithEffectiveBase(mid)` is superseded for reserve-share accounting.

Ids **1** and **2** still receive D2 **effective-share** top-ups only. They do not receive redeemable `originalShares` of reserve LP.

### 14.2 Sell bond → rebasing claim

When a mature user bond is sold to the protocol:

1. `originalShares` of that NFT are **transferred** to token id **0** (debit user, credit protocol). Not a fresh 1:1 LP mint onto id 0 if the exchange rate has moved.
2. The user’s lock **bonus weight is burned** (effective shares of the user NFT go away; id 0 is not credited the bonus).
3. Physical LP stays in the **bond NFT vault** (D13). The claim token does **not** take custody; it calls the NFT to withdraw.
4. The rebasing claim token mints to the seller with ERC-4626 against id 0 **before** the transfer:

```
if protocolOriginal == 0:  claimShares = originalSharesMoved
else:                      claimShares = originalSharesMoved * totalClaimShares / protocolOriginal
```

Ids 1 and 2 cannot take this path (D7).

### 14.3 Rebasing token: shares of shares

Claim holders own **shares of token id 0’s originalShares**. Id 0 owns a 4626 slice of reserve LP. That is shares of shares. They do not own user-bond LP until that bond is sold in.

Redeem of claim burns claim shares and releases a pro-rata slice of id 0 `originalShares` (then unwind).

### 14.4 Rebase quotes DETF extractable

The claim token **rebases in DETF**, not in rateAsset. `balanceOf` / `redemptionRate` quote how much **DETF** that holder can extract, as the sum of:

1. **Liquidity unwind (zap-out to DETF):** DETF from that holder’s slice of id 0’s reserve LP if that slice were fully unwound to DETF on the reserve curve: the DETF self-leg of a proportional withdraw **plus** converting the other exit legs to DETF on the **residual** book (other originalShares still in the pool). Not DETF-leg-only.
2. **Bond-holder rewards:** that holder’s pro-rata slice of **pending DETF** on token id 0 (`pendingRewards(0)`), the same pot D3/D4/expansion pay into.

```
totalDetf  = zapOutToDetf(lpOf(id 0)) + pendingRewards(0)
rate       = totalDetf / totalClaimShares     (1e18 if totalClaimShares == 0)
balanceOf  = claimShares * rate / 1e18
```

`zapOutToDetf` and D15 execute **must use the same identity**. The last-resort DETF buy is that zap-out’s pair→DETF leg; it is not a third product path. In the normal case (residual LP remains) the leftover non-DETF from the proportional withdraw is exactly what that buy needs.

Protocol compound may still auto-compound id 0’s pending into reserve LP (existing compound law). After compound, (2) falls and (1) rises; the DETF quote should stay continuous aside from curve fees/slippage.

Shipped claim tokens that preview **rateAsset** via `previewExchangeIn(BPT → rateAsset)`, that **omit** id 0 pending rewards, or that quote **only** the DETF leg of a proportional withdraw are **out of spec** under D10.

### 14.5 4626 conversion (N10)

`convertToAssets(s)` / `convertToShares(lp)`:

- Numerator / assets: `lpToken.balanceOf(bondNft)` (physical LP on the NFT).
- Denominator / shares: **`totalOriginalShares`**. Never `totalShares` (effective). **Do not** subtract protocol / id 0 effective shares from the denominator.
- `s` is **originalShares**, never `effectiveShares`.
- Keep existing `BetterMath` + `decimalOffset`.
- Mature close and claim `lpOut` must pass originalShares into this conversion.

Shipped `DETFNFTVaultRepo._totalLpReserveForConversion` that haircuts protocol effective shares while using all physical LP is **out of spec**. That overpays user bonds and leaks id 0 LP (donate, D25 rejoin, `buyClaim`) to users.

---

## 15. D11–D18 — mint join, burn, custody, claim, `exchangeIn` (LOCKED)

### 15.1 D11 — Liquid mint vs bond

| Action | DETF self-leg into reserve? |
|--------|------------------------------|
| User buys **newly minted DETF** (`exchangeIn` → DETF) | **No new DETF** into the pool. Non-DETF capital may join. New LP is held by the NFT **without** minting new `originalShares` for that deposit: existing bond shares’ claim on LP **changes** (4626 NAV). Free DETF size uses D8 (live + amountIn bonus). |
| User **buys a bond** | **Yes.** Newly minted join DETF `G` goes into liquidity with the non-DETF legs. `G` is **unboosted** proportional matching (D24). User gets 4626 `originalShares`. |
| `exchangeIn` DETF → claim | **No new DETF mint.** Provided DETF is joined as self-leg. NFT mints `originalShares` to **id 0**. |

D8’s boosted `amountIn` is **quote-only on free mint/burn**. Mixed-buffer live mint that joins `gross` DETF is **out of spec**. **Only bonds** mint new DETF directly into liquidity, and that amount is not D8-boosted.

### 15.2 D12 — Burn burns supply

Redeeming DETF **burns** the DETF the user provided. Composed’s shipped path (swap DETF into the reserve, supply unchanged) is **not** the product. See the discussion note in the session that recorded this lock: D8/D10 assume a smaller DETF supply and a proportional LP exit, not a DEX sale of DETF.

### 15.3 D13 — NFT holds LP; V4 SE 4626

All reserve LP (BPT or hook LP) is **owned by the bond NFT vault**. The DETF and the rebasing token do **not** hold idle LP. They call the NFT to add/remove liquidity. The NFT mints/burns 4626 `originalShares` on those movements so `originalShares` stay a claim on remaining LP.

Sizing a **DETF burn** (after expansion mint-on-update, so pending expansion is already DETF in the pot / `totalSupply`):

```
lpOut = detfIn * nftLp / detfTotalSupply
```

Same shape as Uni V4 Standard Exchange (`sharesBurned * reserves / totalShares`). Do **not** use diamond `balanceOf` BPT or `supply + unminted expansion`. Then remove along the **DETF–tokenOut** curve (D20); **rejoin all other legs**.

Live-mint capital deposits increase NFT `totalLp` **without** a matching `originalShares` mint (D11). Bond mints 4626 to the **user** id. DETF→claim, donate, protocol compound, and mature-close DETF rejoin mint 4626 to **id 0**.

Free DETF burn still sizes LP as `detfIn * nftLp / detfSupply` (this section). That second claim dilutes every originalShares holder, including id 0. Accepted.

### 15.4 D14 — No `feeTo` DETF on mint or burn

Mint does not `_mintDetf(_feeTo(), …)`. Burn does not `safeTransfer(_feeTo(), feeDetf)`. Oracle `usageFeeOfVault` is unused on these DETF mint/burn paths. `feeTo`’s DETF income is **only** `claimRewards` on token id 1.

### 15.5 D15 — Claim redeem is DETF, rewards first, zap-out fill

`exchangeIn(claim, amount, DETF, …)` / `redeem`. User receives **DETF only**.

`owed` = this holder’s claim on `pendingRewards(id 0) + zapOutToDetf(id 0 LP slice)` (D10 §14.4). Preview and execute share that identity. Zap-out’s leftover→DETF leg uses **post-withdraw** residual reserves and the **same trading fee as public swaps** (Uni V4 CP: 0.3%).

1. **Realize pending expansion** (D31). Expansion DETF is minted to the Bond NFT and enters the `rewardPerShares` ledger. Open: no-op.
2. Pull claim tokens; burn claim shares (D10 4626). `lpOut` = `convertToAssets` of the released id 0 originalShares (N10).
3. **Harvest all** id 0 pending DETF (not this holder’s pro-rata only). Pay as much as possible toward `owed`. Leftover pending: compound to id 0 (self-leg join, 4626 to id 0).
4. If harvested pending ≥ `owed`: **do not** withdraw LP. Credit that `lpOut` back to id 0 (`addToDETFNFT`). Pay `owed`. Done.
5. If still short: proportional withdraw of `lpOut`. Keep the DETF leg.
6. **Buy DETF** on the **residual** reserve. Exact-out = remaining shortfall. Pay with withdrawn non-DETF. Do **not** redeem other bonders’ `originalShares`. Owner host swap (D30), not Uniswap SwapRouter.
7. **Sell order:** after the proportional withdraw, snapshot each leftover non-DETF token’s **DETF-buying power** (preview exact-in of the full leftover → DETF on the residual book). Sort descending once. Do not re-sort after each fill. For each leftover in that order: if it cannot fill the remaining shortfall even sold in full, sell **all** of it (exact-in); else sell exact-out only the remainder and **stop**. Uni V4 CP: the only leftover is `pairToken`.
8. Rejoin leftover non-DETF and leftover DETF to the NFT; `originalShares` to id 0. Owner `depositSingle` at hook `MINIMUM_LIQUIDITY` is allowed and **must mint lpOut > 0** (same zap math as a live zap). Zero LP reverts; do not skip the rejoin.
9. Pay DETF only. `minOut` still applies. No rateAsset redeem.

Claim redeem is **not** Policy mint/burn gated (D22). Expansion realize still runs so the claim holder is paid from id 0 inventory that includes id 0’s share of that expansion.

**Last exit** (this withdraw empties NFT-held LP; hook may retain `MINIMUM_LIQUIDITY` on `address(0)`): skip the residual buy. Pay pending + DETF from the proportional withdraw. Owner `depositSingle` leftover pair to id 0 (D30 MIN exception; **lpOut > 0** or revert). Never send pair to the redeemer.

Do not auto-compound pending **before** step 3 in this transaction. Do not add a D20 user-burn of free DETF as a redeem path.

### 15.6 D16 — First bond

Permissionless first bond must supply **every non-DETF reserve leg** (and mint the DETF self-leg into the pool). That creates protocol reserve and sets live. Synthetically ungated (existing threshold law). Later bonds may be single-leg as each family already allows.

### 15.7 D17 — Token ids 1 and 2

Always allowed to `claimRewards`. Forbidden: `sellPositionToDetfNft`, mature close / capital redeem, any path that pulls their LP (they have none). User bonds (id ≥ 3) still sell-to-claim when mature (D7/D10) and close when mature (D25).

### 15.8 D18 — Claim via `IStandardExchange`

`tokenIn = DETF`, `tokenOut = rebasingClaim` is a supported `exchangeIn` (and matching preview). **Do not mint DETF.** Join the **provided** DETF as the self-leg; NFT 4626-mints `originalShares` to id 0; mint claim shares (D10). Only **bonds** mint new DETF into the pool.

### 15.9 D19 — `feeTo()` change

Token id 1 is not transferred, reminted, or reassigned when `feeOracle.feeTo()` changes. The original recipient keeps `claimRewards` on id 1. A later collector does not earn on this instance unless they already hold id 1.

### 15.10 D20 — DETF burn `tokenOut`

`exchangeIn(DETF, amount, tokenOut)`: unified Uni V4 DETF pays only **`burnRoutes`** `tokenOut` (I/O routing PRD §16.3). Other families still: any reserve token or SE buffer / rate asset until their tables ship. Size the burn with D8: capital bonus does **not** apply on burn. Invalid `tokenOut` → `InvalidRoute`.

### 15.11 D21 — Creator omitted

Wire token id 2 to `PkgArgs.creator` when nonzero. If `creator == address(0)`, mint id 2 to `feeOracle.feeTo()` (same address as id 1). Both NFTs keep their D2 weights (`f` on 1, `c` on 2). This is a deploy recovery path, not a second fee product.

### 15.12 D22 — No mint/burn gates on claim

`exchangeIn(DETF → claim)` and `exchangeIn(claim → DETF)` do **not** call `isMintingAllowed` / `isBurningAllowed`. They require the instance **live** (first bond done). Policy/Open gates stay on liquid DETF mint/burn only.

### 15.13 D23 — Exact-out

`exchangeOut` / exact-out mint or burn: implement when the reserve host has a **closed-form** `inGivenOut` (or family equivalent) on that DETF–token pair. Weighted and constant-product typically do; do not add a binary-search solver. No closed form → `InvalidRoute`.

### 15.14 D25 — Mature close (see §18)

`closeBondMature` on id ≥ 3 is the D25 process, not a D20 single-sided burn.

### 15.15 D26 — `PkgArgs.creator` (see §19)

Every family `PkgArgs` includes `creator`. D21 still covers `address(0)`.

---

## 16. Universal vs family-specific (LOCKED index)

This is the stipulation asked for: **one process**, **family-owned curve and token set**.

### 16.1 Must be the same on every true DETF

Bond NFTs (ids 0 / 1 / 2 / ≥3), D2 weights, pot funding (D3/D4), no DETF to `feeTo` on mint/burn, ERC-4626 + lock bonus, sell-in of `originalShares` to id 0, claim = shares of id 0, rebase in DETF, live mint does not mint DETF into the pool, only bonds mint new DETF into liquidity and that `G` is **unboosted matching** (D24), DETF→claim moves provided DETF in (no new mint), burn **burns** DETF, LP lives in the NFT, burn LP size `detfIn * nftLp / supply`, claim redeem pending-then-compound-then-prop-withdraw-then-buy-DETF-on-residual-then-rejoin, first bond funds **all** non-DETF legs, ids 1–2 claim-only, claim `exchangeIn` ungated, `feeTo` change does not move id 1, `creator` on every family `PkgArgs` (D26), `creator == 0` mints id 2 to `feeTo`, quote shape D8 (bonus on **live free mint** `amountIn` only), mature close is proportional withdraw then **rejoin withdrawn DETF to id 0** then send the rest (D25), exact-out only if closed-form, **D28 claim-share tests on ids 1 and 2**, **D29 reserve donation** (Bond NFT public `donate`, DETF-only host join, no DETF mint, **originalShares to id 0**), **D30 owner host swap/LP while locked**, **D31 expansion then mint/burn gate**.

Uni V4: DETF-only add/remove LP. Balancer: open public join allowed (D9).

Policy/Open gates, protocol compound (id 0 only), and natural expansion stay as in the compound/threshold PRDs, except D15’s redeem order, D22 (claim ungated), and **D31** (realize expansion on mint/burn/redeem/close before the gate).

### 16.2 Family-owned (do not “standardize away”)

| Concern | Who defines it | Law |
|---------|----------------|-----|
| **Reserve curve** | Family | D8: use **this instance’s** reserve book. Weighted, mixed-buffer stable, composed-of-BPTs, Uni V4 CP, orbital sphere, V4 weighted, quad StableSwap. |
| **Reserve token set** | Family | Which legs sit next to the DETF self-leg. |
| **Live mint `tokenIn`** | Instance tables; family **defaults** | Unified Uni V4: resolved `mintRoutes` ([`DETF_INSTANCE_IO_ROUTING_PRD.md`](./DETF_INSTANCE_IO_ROUTING_PRD.md)). Other families: vault share, buffer, pair, or SE zap into a reserve leg until I/O tables ship. Not share↔share on the DETF. Donate uses donateRoutes plus DETF and reserve `lpToken`. |
| **Burn `tokenOut`** | Instance tables ∩ D20 | Unified Uni V4: `burnRoutes` only. Other families: any reserve token or SE buffer/rate asset until tables ship. |
| **First-bond capital** | Family | The concrete non-DETF legs D16 requires (see §16.3). |
| **Empty-pool / first-bond quote** | Family | Pool is empty: **Uni V4 uses `openingPairPerDetfWad`** (0 → creation at init). Synthetic peg stays **`creationPairPerDetfWad`**. **D8 does not run here.** D8’s live curve + amountIn bonus applies **after** live, and only to free mint/burn. Balancer Single SE / MVW: weights (`detfWeight` / `vaultWeights`). Mixed-buffer: amp + first-bond amounts. Composed: existing reserve + first join. Do **not** add a Uni-style opening field to Balancer families. |
| **Closed-form exact-out?** | Family curve | D23: implement if the host has `inGivenOut`; else `InvalidRoute`. |
| **Synthetic / expansion numeraire** | Family + existing PRDs | Single synthetic vs per-route / all-legs-rich (Weighted, Quad). |
| **SE passthrough** (no DETF mint/burn) | Family extra | Not required for conformance. |
| **Mature close token set** | Family ∩ D25 | Process is universal (prop withdraw, rejoin DETF to id 0, send rest). Which non-DETF tokens appear in “the rest” is that family’s reserve list. |

Family PRDs that contradict §16.1 (e.g. MixedBuffer “burn buffer only”, MVW “first bond is BPT-only”, Uni V4 mid-based `effectiveBase`, Composed swap-not-burn, claim redeem to rateAsset) are **superseded** on those points.

### 16.3 First-bond non-DETF legs (family)

| Family | Non-DETF legs the first bond must fund |
|--------|----------------------------------------|
| Balancer Single SE | The SE **vault share** |
| Multi-vault weighted | **Every** vault-share leg (not “BPT-only first bond”) |
| Mixed-buffer | **Buffer** + **every** vault-share leg |
| Composed stable | Every non-DETF token the reserve actually lists (family PRD) |
| Uni V4 CP | The **pair** token |
| Uni V4 Orbital | **Both** external pairs |
| Uni V4 Weighted | **Every** configured pair |
| Uni V4 Curve Quad | **All three** external pairs |

Plus the DETF self-leg in every case.

### 16.4 Residual (not a new product fork)

- Wire ceremony for minting ids 0–2 (implementation).  
- Unused `UniV4DetfBondNft` package (delete or ignore; not DualLiquidity).  
- Preview == execute on closed-form routes (existing testing law).  
- Nested DETF-as-SE remains allowed and opaque.  
- Slippage `minOut` on D25 and bond free `U` are **launch-defaulted** in the impl plan (L1, L2). Amend this PRD if product rejects those defaults.

---

## 17. D24 — Free mint/burn bonus vs bond matching `G` (LOCKED)

These are two processes. Do not size one from the other.

### 17.1 Free mint / burn (price)

Purpose: **expand or contract DETF supply** so the reserve price can move.

- **Mint (live):** D8. Bonus on `amountIn`, then the live reserve curve. No new DETF into the pool (D11). Physical capital deposited is unboosted.
- **Burn:** D12 / D13 / D20. Burns DETF. Does **not** use the D8 amountIn bonus unless a later lock says so.

### 17.2 Bond join (depth)

Purpose: **deepen liquidity**, not move the price.

Given the user’s non-DETF capital (one or more legs the family allows):

```
G = unboosted DETF required to join those legs proportionally
    against live reserve balances
```

Mint `G` into the reserve with the user’s capital. Do **not** apply `(1 + p)` to the capital before this quote. Do **not** take D8 `Gross` and treat it as `G`.

First bond, empty pool: family creation / weights / first amounts (D16, §16.2). Still no D8 bonus on `G`.

D4 still applies: additional pot mint `p * G`. `G` is this unboosted matching amount.

Lock-duration bonus remains on `effectiveShares` only (D10). It is not a DETF mint bonus and not part of `G`.

### 17.3 What D24 does not lock

- Whether a bond also mints free `U` to the user’s wallet (§9.2). Live-mint `U = Gross` is D27.

---

## 18. D25 — Mature close: proportional withdraw, rejoin DETF to id 0, send the rest (LOCKED)

Global. Replaces family-specific single-sided mature close (shipped Single SE `tokenOut`, Orbital consolidate-to-capital, MixedBuffer buffer-only, and any D20-shaped close). **Overrides** any earlier D25 text that burned the withdrawn DETF.

Sell-to-claim (D10) is unchanged and remains a **different** mature path: transfer `originalShares` to id 0, mint claim shares. No LP withdraw.

### 18.1 Process (id ≥ 3, mature)

1. **Realize pending expansion** (D31). Then `claimRewards` on that NFT so the bonder receives **their `effectiveShares` slice** of that expansion (and any other pending) as free DETF. Do not destroy it with the retire.
2. `lp = convertToAssets(originalShares)` (ERC-4626, D10 / N10). Input is originalShares, not effectiveShares.
3. Through the NFT (D13): **proportional** withdraw of `lp` from the reserve. Every reserve leg comes out, including the DETF self-leg.
4. **Rejoin** the DETF that came out of that withdraw as the self-leg. Credit **originalShares to id 0** (`addToDETFNFT`, 1×). Do **not** burn that DETF. Do **not** send it to the user. Owner `depositSingle` at hook `MINIMUM_LIQUIDITY` is allowed and **must mint lpOut > 0**. D2 then runs.
5. Send **every remaining withdrawn token** (all non-DETF legs) to the user. **Default remainder is the basket.** Unified Uni V4 Custom close is the I/O PRD exception: exactly one hook pair + leftover `ownerSwapExactIn` in `tokens()` order ([`DETF_INSTANCE_IO_ROUTING_PRD.md`](./DETF_INSTANCE_IO_ROUTING_PRD.md) §16.5). Balancer family close text that swaps leftover legs into one settlement asset is **superseded** except that Uni V4 Custom path.
6. Retire the NFT (burn that id’s `originalShares` / `effectiveShares`).

Ids 1 and 2 cannot take this path (D17). Close is not Policy mint/burn gated.

### 18.2 What the user receives

Free DETF from step 1 (`claimRewards`, including their expansion share) **plus** the basket of non-DETF tokens from the proportional exit. Which non-DETF tokens exist is family-owned (§16.2). The process is not. The protocol keeps the DETF self-leg on id 0.

Do not:

- Quote D8 or D20 on this path.
- Rejoin non-DETF and pay a single `tokenOut` (that is liquid burn / old close).
- Burn withdrawn DETF or leave it in the diamond, the NFT, or the user’s wallet.

Slippage: launch default L2 (`minAmountsOut` array, DETF slot **must be 0**). Preview must match execute.

---

## 19. D26 — `creator` on every family `PkgArgs` (LOCKED)

Every true DETF family’s deploy `PkgArgs` (the interface struct, not a hidden repo field) includes:

```
address creator;
```

Wire mints token id **2** to `creator` when nonzero. If `creator == address(0)`, D21: mint id 2 to `feeTo()`.

Shipped Balancer and Uni V4 family `PkgArgs` that omit this field are **out of spec**. Add it on every in-scope family, including Single SE, MVW, mixed-buffer, composed stable, and all Uni V4 families.

Creator address is **not** an oracle value (D5). `c` (weight) is oracle; recipient is this field.

---

## 20. D28 — `feeTo` / creator claim tests (LOCKED)

Required on **every** in-scope family. Production-first gold TestBase. No mock of the DETF, bond NFT, fee oracle, manager, or registry. Do not treat Composed’s existing “fee NFT claimed > 0” smoke as this suite.

**Due amount** for a token id after a pot increment `Δ` that landed while that id held `E` effective shares and total effective was `T`:

```
due = floor(Δ * E / T)
```

Same `rewardPerShares` / `userRewardPerSharePaid` ledger as other bonds:

```
pending = floor(E * (rewardPerShares - paid) / 1e18)
```

D2 top-ups add **effective shares only** on ids 1 and 2. New shares must **not** inherit historical `rewardPerShares` as claimable (first stake: `paid = current rps`; add-to-stake: preserve prior pending only, do not invent extra).

### 20.1 Ship-gate matrix

| ID | Must prove |
|----|------------|
| **FC1** | After a live mint (D3 pot) and/or a bond (D4 pot) and/or expansion, `ownerOf(1)` can `claimRewards(1)` and `ownerOf(2)` can `claimRewards(2)`. Claimed DETF > 0 when `Δ > 0` and `E > 0`. |
| **FC2** | `claimRewards(id) == pendingRewards(id)` immediately before the call (exact). Balance delta of the recipient equals the return value. |
| **FC3** | After one closed pot deposit `Δ` and **no** intervening D2 top-up, `claimed(1) + claimed(2) + Σ claimed(user ids) + pending(0)` equals `Δ` within **one wei per position** (floor). Id 1’s take is `floor(Δ * F / T)`, id 2’s is `floor(Δ * C / T)`. |
| **FC4** | After D2 adds shares to ids 1 and 2, those **new** shares do **not** raise pending on **old** pot. Snapshot `pending` before the top-up; after top-up (and before a new pot mint) pending is unchanged except documented 1-wei rebase dust. |
| **FC5** | After that top-up, a **new** pot deposit `Δ2` is split at the **new** weights. Id 1 cannot collect more than `floor(Δ2 * F' / T')` from `Δ2` plus its preserved old pending. Same for id 2 with `C'`. |
| **FC6** | Second `claimRewards` on the same id with no new pot returns **0**. No second DETF transfer. |
| **FC7** | Non-owner of id 1 / id 2 reverts (`NotBondHolder` or family equivalent). Cannot claim another id’s rewards (feeTo cannot claim id 2 when owners differ; neither can claim a user id). |
| **FC8** | Ids 1 and 2 still cannot `sellPositionToDetfNft` or `closeBondMature`. Those paths are not a leak around the share cap. |
| **FC9** | D2 top-up does **not** mint `originalShares` on ids 1 or 2. `convertToAssets` / redeemable LP on those ids stays 0. |
| **FC10** | D19: after oracle `feeTo()` changes, the **original** owner of id 1 still claims; the new `feeTo()` cannot `claimRewards(1)`. |
| **FC11** | `creator == 0` (D21): `feeTo` owns ids 1 and 2. Claiming both pays `due(1) + due(2)` (`f + c` of `T`), not `2 * due(1)` and not the whole pot. |
| **FC12** | Conservation across two pot waves and two D2 top-ups: sum of all successful `claimRewards` (ids 0, 1, 2, ≥3) never exceeds total DETF minted into the pot. Floor dust only. |

`assertGt(claimed, 0)` alone **fails** FC3–FC6 and FC11–FC12.

### 20.2 Test files (plan)

Per family: `<Family>_Alignment_FeeCreatorClaim.t.sol` with `test_FC1_` … `test_FC12_`. Helpers on the family TestBase. See the impl plan Stage C/D/F.

---

## 21. D29 — Reserve donation (LOCKED)

Joinable capital (`pairToken` / buffer / rateAsset, `vaultShare`, family mint/bond tokens, **DETF**, or already-minted reserve LP) may be pushed into a **live** DETF without minting DETF. Physical reserve LP on the NFT rises. New 4626 `originalShares` are minted **only to token id 0** at the current conversion rate (N10). User-bond `convertToAssets` stays flat. Ids 1 and 2 still have zero redeemable LP; D2 tops up their **effectiveShares** because id 0 changed `O`.

Donate(DETF) is a self-leg join of **existing** DETF (no burn, no claim mint). That is `buyClaim` without paying the donor in claim tokens.

**Public function lives on the Bond NFT** (`detf/common/bondNft`), because that vault already holds the LP (D13). **Host join stays on the DETF diamond** (`onlyBondNft`). Uni V4 hooks remain owner-only add/remove (D9); the NFT must not call `depositSingle`. `IDetf.donate` is a FeeCollector forwarder onto the NFT (`minLpOut = 0`; pretransfer destination is the NFT; event donor is the collector).

Donate is not a bond, not live mint (D11 still unassigned LP + free DETF to the caller), not protocol compound, and not expansion realize. Full process, family join table, conversion rule (N10), and ship-gate tests: [`DETF_RESERVE_DONATION_PRD.md`](./DETF_RESERVE_DONATION_PRD.md).

Do **not** treat idle ERC-20 on the DETF diamond or a raw `vaultShare` transfer to the hook as donate.

---

## 22. D30 — Owner host ops while PoolManager / Vault is locked (LOCKED)

Normative detail is §11.3. Summary:

- DETF is the Uni V4 reserve-hook owner. Public swaps stay public. Add/remove LP stays owner-only when `ownerOnlyLiquidity` is on (D9).
- D15 must **buy DETF** on the residual book after a proportional LP withdraw. D29 must `depositSingle` in the same class of transaction. Uniswap SwapRouter / a nested `PoolManager.unlock` will fail if the manager is already unlocked.
- Every Uni V4 DETF-reserve hook (CP, Orbital, Weighted, Curve Quad buffer) exposes **owner-only** exact-in/exact-out swap and LP add/remove that settle on the **current** unlock or via internal book settlement (zap-internal class). Non-owner cannot use that path.
- Balancer analog: swap/join/exit inside an already-open Vault unlock, not a nested Router call.

Owner `depositSingle` / `deposit` when hook `totalSupply == MINIMUM_LIQUIDITY`: **allowed for the owner only**. Same zap math as a live zap (impact against dust accepted). **lpOut must be > 0** or revert. Public zaps still revert at MIN (hook D79). This is how D25 DETF rejoin and D15 leftover rejoin stay LP on the NFT.

Family hook PRDs must carry this lock. Co-located starting point: [`UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md`](../../hooks/uniswap/v4/standardExchange/constantProduct/single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md) D88–D89.

---

## 23. D31 — Realize expansion, then gate (LOCKED)

Cross-cut of the compound/expansion PRD. **Mint/burn quote, split, D11 join, D13 burn sizing, Policy vs Open inequalities, and pot rewards do not change.** What changes is **when** expansion is minted relative to the gate.

| Path | Realize expansion first? | Then Policy mint/burn gate? |
|------|--------------------------|------------------------------|
| Live mint | **Yes** | **Yes** (post-realize synthetic) |
| Live burn | **Yes** | **Yes** (post-realize synthetic) |
| `redeemClaim` | **Yes** | **No** (D22) |
| `closeBondMature` | **Yes** | **No** |
| Bond | **Yes** (already) | **No** |
| Donate | **No** | **No** |
| Open mode | Realize is a no-op | Mint/burn gates always pass when live |

Execute order on live mint/burn:

1. Require live.
2. Realize pending expansion (mint DETF to the Bond NFT; `rewardPerShares` updates). Open: skip.
3. Compute synthetic from **minted** `totalSupply` (pending expansion is now 0).
4. Policy: mint iff `synthetic > mintThreshold`; burn iff `synthetic < burnThreshold`. Fail → **revert the whole tx**, including the expansion mint. That can block the mint/burn that triggered realize. **Desired** (stops overshooting the band).
5. Proceed with the existing mint or burn process.

Views: `isMintingAllowed` / `isBurningAllowed` count pending expansion in the denominator so they equal step 3 without minting in the view.

Close: after realize, `claimRewards` on that user NFT pays **that bonder’s** expansion (and other pending) as free DETF, then the LP unwind.

Redeem: after realize, harvest **all** id 0 pending (includes id 0’s expansion slice) toward `owed`. Other bonders keep expansion on their own pending.

---

## 24. D32–D66 — Funded staking, vesting bonds, and Pendle integration

**Accepted product direction, subsequently revised by D60–D66. Implementation is authorized within the current scope.** This section is normative for the planned refactor where it conflicts with earlier sections. Open items are not implementation defaults.

### 24.1 Roles, scope, and ownership

| Role | Entitlement / responsibility |
|------|------------------------------|
| `detfToken` | Nine-decimal base token. Protocol-owned reserves support its primary mint/burn paths; the reserve pool also supplies market exchanges |
| Rebasing staking token (`sDETF` in this discussion) | Nine-decimal receipt redeemable 1:1 for held `detfToken`. It replaces the economics of `rebasingClaimToken`; final interface/type naming is a later implementation detail |
| Staking reserve | Holds the DETF that honors staking redemptions, including backing for staking tokens held in bond escrow and SY wrappers |
| Bond NFT / escrow | Records fixed DETF principal, vesting schedule, claimed principal, and the remaining staking shares belonging to that NFT |
| Protocol reserve | Owns the reserve LP acquired through DETF operations. It does not owe LP principal to bond purchasers or staking-token holders |
| Staking SY wrapper | Nine-decimal, non-rebasing shares of the sDETF position, with an exchange rate expressing DETF entitlement |
| Raw DETF SY wrapper | Separate SY shares backed by acquired DETF; its share mint/burn is independent of the DETF's primary-issuance versus reserve-swap route |

**D60 limits functional DETF work to unified Uni V4 DETF bound to CP, Orbital, Weighted or Curve Quad hooks. Balancer-hosted Single SE, multi-vault weighted, mixed-buffer and composed stable DETFs are excluded; further changes there are compilation maintenance only.** Do not resurrect deleted family DETF diamonds. SE vaults receive the additive SY surface but do not acquire DETF staking/bond economics.

Actual mint and bond payments build protocol reserves. An ordinary asset-payment bond also retains the proportional DETF self-leg minted and joined alongside its actual payment; that self-leg is additional to the DETF minted for vesting. A bond purchaser receives escrowed DETF, not an `originalShares` claim on the resulting LP. The previous problem of separating bond-owner LP from protocol LP is removed for new bonds: all LP acquired in these operations is protocol property. This does not make arbitrary third-party LP balances protocol property; preserve the distinction between actual protocol custody and the reserve pool's total LP supply.

Staking reserve DETF is allocated to outstanding staking redemptions. It must not be borrowed for LP joins, payments to bond purchasers, treasury spending, or redemptions of somebody else's DETF. A staking-token redemption transfers held DETF; it does not unwind protocol LP.

### 24.2 Nine-decimal, 1:1 staking and funded rebases

Both `detfToken.decimals()` and the staking token's `decimals()` are **9**. `10^9` raw units represent one token on both sides. The owner explicitly selected equal nine-decimal tokens instead of retaining an eighteen-decimal DETF. Percentage, synthetic-price, rebase-index and internal staking-share precision are independent of ERC-20 decimals and may retain higher precision.

Required flows:

1. **Stake:** receive `x` actual DETF units and issue `x` redeemable staking-token units. Minting a staking receipt from LP, an NFT valuation, a quoted swap output, or an unfunded promise is forbidden.
2. **Fund rewards:** deliver additional DETF from seigniorage/expansion to staking backing. This reward deposit creates no new depositor principal claim; it funds growth for existing staking positions.
3. **Rebase:** distribute seigniorage **immediately** under D49 and automatic expansion on the **8-hour epoch** schedule under D50. Both increase redeemable staking balances only to the extent funded by additional DETF and rebase eligible stake before issuing the distribution's fee/creator receipts. Zero funded rewards gives a flat rebase. Do not derive balances from a spot pool quote or force a historical high-watermark balance without backing.
4. **Unstake:** retire `x` redeemable staking-token units and transfer `x` held DETF units. This 1:1 leg has no LP-unwind dependency or DETF price gate.

The core invariant, in equal nine-decimal native units, is:

```text
held DETF allocated to staking >= outstanding redeemable staking-token units
```

Count receipt positions held by users, bond escrows and wrappers. If the chosen Olympus-style implementation retains preminted internal token inventory, distinguish unissued inventory from outstanding redemption liabilities; do not blindly substitute its ERC-20 `totalSupply` for redeemable supply.

Use fixed high-precision internal shares/gons and a funded global rebase index. An unchanged holder position must never decrease from a rebase. Deposits, withdrawals and transfers are separate balance-changing operations. Rounding must not overissue claims or take principal from another position. Quantization dust and the final exit must have an explicit policy in the implementation plan.

This guarantees nondecreasing token entitlement in **DETF units**. It does not guarantee an increasing external market price or purchasing power for DETF. Raw DETF held in the staking reserve remains outstanding DETF; staking does not burn it.

### 24.3 Seigniorage and expansion fund staking

The owner clarified that seigniorage and expansion rewards are **now added to the sDETF backing reserve**. Their destination is settled. The portion remaining after fee/creator allocation funds the same rebase for freely held stake and stake held on behalf of bond purchasers. The fee/creator portions back newly issued sDETF under D40 (§24.3.1).

- A pending reward calculation or planned expansion mint is not already-held backing. The corresponding DETF must be funded before it creates redeemable staking growth.
- **Seigniorage is immediate:** every issuance path that creates the existing seigniorage share funds and distributes that share in the same transaction. It is not an epoch queue. **Only automatic expansion uses the fixed eight-hour epochs.** For either source, the staking portion increases the index once and must not also create a deposit claim for the distributor. Fee/creator DETF allocations instead back their own receipts and are excluded from that rebase's funding.
- The former automatic protocol-reward self-leg LP join is not the destination for these rewards under the new model.
- Bond purchasers receive staking yield through their escrowed stake. Do not additionally distribute the same income through the former bond `effectiveShares` ledger.
- The lock-duration bonus determines the initial purchased allocation (§24.4). It does not, by itself, authorize a second lock multiplier on that allocation's staking rewards.

Preserve existing expansion rate calculations and eligibility conditions, fee percentages, fee-oracle configuration and the gross/net issuance rules, subject to the explicitly accepted timing changes in D49/D50, removal of Open mode in D51 and removal of all expansion catch-up caps in D52. All DETFs follow these new cross-family requirements regardless of their previous implementations. Separate the bond's liquidity and purchased-allocation inputs and settle calculated fee/creator allocations as fully funded staking receipts (§24.3.1).

The former NFT reward detector treated a positive DETF balance delta as new rewards (`DETFNFTVaultRepo._updateGlobalRewards`, now removed under the approved unused-ledger cleanup). A funded staking reserve also receives DETF principal on deposits. Its accounting must distinguish those deposits from rewards; a principal deposit must not itself rebase existing holders. This is an accounting adaptation, not a new reward-rate formula.

### 24.3.1 D40 — Funded fee/creator receipts and continuing entitlement

**Accepted:** pay the calculated fee and creator allocations as sDETF by staking their allocated DETF on their behalf. These receipts are ordinary, transferable staking tokens. **Unstaking means redeeming sDETF for the underlying DETF at 1:1**, using equal nine-decimal raw amounts. Recipients may redeem some or all of their balance without a bond vesting period, LP unwind, or primary DETF mint/burn price gate.

For any funded DETF reward distribution `R` — immediate seigniorage under D49 or automatic expansion under D50 — let `F` and `C` be the fee and creator DETF amounts determined by the preserved allocation rules. These symbols denote actual DETF amounts, not virtual reward weights. Require `F + C <= R` and account for each amount once:

```text
stakingReward = R - F - C - roundingDust
newFeeSdetf = F
newCreatorSdetf = C
additional DETF held in staking custody = R
```

`roundingDust` is the residual from the preserved fixed-point allocation/conversion rules, not a new fee. It is not a fictitious ordinary-staker allocation when only standing fee/creator weights are eligible.

Required distribution order:

1. Resolve `F`, `C`, and their entitled recipients under existing fee/creator allocation and beneficiary rules. This decision changes payout settlement; it does not introduce new percentages, silently replace the existing top-up-only reward-weight calculation, or redirect the configured entitlement.
2. Allocate `stakingReward` exclusively to the eligible staking positions and apply its funded rebase. For expansion, use the cutoff in D47/D50; for immediate seigniorage, use the stake present when that issuance's reward is distributed (§24.3.2). Previously held fee/creator sDETF participates normally alongside other eligible stake, in addition to their separate standing fee entitlements.
3. Allocate the actual `F + C` DETF to new staking principal and issue `F` sDETF to the fee recipient and `C` sDETF to the creator recipient **after that rebase**, as part of the same distribution. The recipients do not need to supply a separate DETF deposit or already own sDETF. New receipts begin participating in subsequent distributions; they do not also earn the rebase just paid from this distribution.
4. Mark the distribution settled once. Neither synchronization nor issuance of these receipts may treat the same DETF as a second reward deposit or create another fee allocation. The funded `R` is sufficient; no additional DETF mint is authorized merely to deliver its fee receipts.

Example: `R = 100 DETF`, with allocated `F = 10 DETF` and `C = 5 DETF`. The 85 DETF remainder funds the existing positions' rebase. The other 15 DETF backs 10 new sDETF for the fee recipient and 5 new sDETF for the creator. All 100 DETF enters staking custody and each part has one liability allocation. These illustrative amounts do not change configured fee rates.

**Continuing entitlement is independent of current sDETF balance.** Transferring or unstaking fee/creator sDETF must not cancel, redeem, burn, or reduce the standing right to future fee allocations. Even after a recipient redeems every sDETF for DETF and holds zero sDETF, later applicable DETF issuance/reward distributions must stake that recipient's newly allocated DETF and deliver new sDETF. The holder of transferred sDETF receives its ordinary staking entitlement; the transfer does not convey the sender's fee/creator role. A zero sDETF balance earns no ordinary holder rebase, but does not disable the recipient's separate fee entitlement.

This continuing right applies to the established fee-bearing seigniorage/expansion distributions. It does not add a second fee to all DETF mint operations, stake/unstake transfers, or supply-neutral reserve swaps. Preserve existing fee eligibility and beneficiary rules, including the creator fallback and the existing rule for a later `feeTo()` address change. Historical reserved-NFT restrictions against LP/capital redemption do not prohibit redeeming the funded sDETF paid under D40.

**D48 corrects the earlier zero-recipient premise.** The fee payout does not depend on any account maintaining stake. The existing allocation calculation includes the standing fee/creator reward weights even if their current sDETF balances, or all ordinary staking balances, are zero. Their standing weights and their actual staked balances are separate accounting inputs.

If the standing fee and creator weights are the only eligible reward weights, the existing reward-per-share calculation allocates the distributable reward between them in proportion to those weights. Conceptually their proportions are `feeWeight / (feeWeight + creatorWeight)` and `creatorWeight / (feeWeight + creatorWeight)`; retain the existing fixed-point accrual and floor rounding, rather than introducing a new percentage split. Stake the actually allocated DETF and pay sDETF under D40. Their new receipts do not participate in that same distribution as ordinary stake.

Do not reserve a fixed ordinary-staker percentage with no recipient by replacing the existing weight-based calculation with constant `F = f * R` and `C = c * R` deductions. The earlier 100/10/5 example illustrates an allocation with an eligible staking remainder; it does not establish permanent deductions independent of the eligible weights. When no ordinary stake is eligible, there is no ordinary rebase allocation; any residual from the existing floor calculations remains rounding dust, not a new unassigned reward pool. Do not block distribution solely because redeemable staking supply is zero. Virtual fee weights themselves remain nonredeemable; only the actual allocated DETF funds the new sDETF.

### 24.3.2 D49/D50/D52 — Immediate seigniorage and uncapped eight-hour automatic expansion

**The owner corrected the earlier D42 interpretation:** seigniorage does not wait for an epoch. Only automatic expansion uses epochs. Both reward sources enter the same funded staking accounting and follow D40's order: rebase eligible stake first, then issue that distribution's fee/creator sDETF.

| Reward source | Mint/funding and distribution timing |
|---------------|-------------------------------------|
| Ordinary DETF issuance seigniorage | Mint and fund the existing `p * U` reward share and distribute it immediately in the issuing transaction |
| Bond issuance seigniorage | Mint and fund the existing `p * U` and additional `p * G` contributions and distribute the bond reward pot immediately in the purchase transaction |
| Automatic expansion | At a due eight-hour boundary or later catch-up, mint the eligible pending expansion in one aggregate amount, fund staking custody, and distribute it once |

The complete expansion mint is already a reward source under D4/D37. Do not additionally mint `p * expansion`, charge seigniorage on a reward mint recursively, or charge a DETF issuance share merely for issuing sDETF receipts. Stake/unstake transfers and supply-neutral reserve swaps create no issuance reward pot.

**Expansion clock:** set the anchor when the first successful bond opens the DETF, not at deployment or a later interaction. Boundaries remain `firstBondTimestamp + n * 28,800 seconds`. The first expansion distribution is due after one full interval; first-bond seigniorage still distributes immediately. An immediate seigniorage distribution does not advance or reset this clock.

**Owner clarification — V4 multi-leg expansion (2026-09-11):** automatic expansion is eligible when any non-DETF synthetic price is strictly above the configured mint threshold. Evaluate every leg using its own creation price against the same current supply and owned reserve LP, and use the highest synthetic price in the existing premium-closure formula for one aggregate expansion. Do not require all legs to qualify, select the first leg, average the prices, or sum separate expansions. Equality to the threshold is ineligible; the positive-premium requirement above peg remains. Preview and realization must select the same highest price, and `NaturalSupplyExpanded` reports that selected price. Token-specific mint/burn gates retain their respective route prices. Test either ordered leg being highest, one or both eligible, neither eligible, threshold equality, distinct creation prices, preview/settlement parity, funded backing, catch-up, and no repeated settlement of a completed epoch.

**Combined catch-up:** if several boundaries pass without interaction, the next applicable transaction realizes all eligible pending expansion in **one aggregate DETF mint and one distribution**. Apply the expansion rate calculation across **all unsettled completed eight-hour epochs**, with no cap on elapsed time, epoch count or the resulting expansion amount. Do not loop through historical distributions, mint interest on hypothetical earlier fee receipts, or multiply already funded inventory by the number of missed epochs. Advance the processed clock through the completed boundaries, retaining any unfinished interval. For example, a first interaction at hour 25 after opening settles the completed expansion interval through hour 24; the next boundary remains hour 32, not hour 33. A repeated interaction cannot pay the same completed interval again. A completed interval with zero eligible expansion advances the clock without an unfunded mint or rebase.

**D52 applies uniformly to every DETF:** remove maximum catch-up seconds/days, maximum catch-up epoch counts, supply-relative per-update caps and equivalent absolute mint ceilings. Remove their deployment/configuration options; do not retain an optional capped variant or impose a replacement cap under another name. The prior `expansionCatchUpMaxSeconds`, `expansionCatchUpCapBps` and `expansionMaxCatchUpEpochs` settings are superseded. A seven-day unsettled interval contains 21 complete eight-hour epochs; all 21 contribute to the single expansion calculation rather than being shortened to one day, limited to a configured epoch count or clipped to a percentage of supply. Preserve the agreed expansion rate formula, price eligibility, completed-epoch rounding and funded-distribution requirements; none of these authorizes reinstating the removed caps.

Only **actually minted and funded DETF** may enter either distribution. A pending expansion estimate is not redeemable staking backing. Elapsed time alone does not execute a contract; settlement occurs in an on-chain transaction. This is the accepted simple catch-up behavior, not a requirement for a historical snapshot/replay system.

**Expansion participation and ordering:** deposits present at the due boundary participate proportionally without time weighting, including a deposit made just before it. Before admitting new principal or processing a withdrawal, settle any due expansion, rebase eligible existing stake, and issue its fee/creator receipts. A deposit in that triggering transaction enters afterward. Existing escrowed bond stake and existing stake held by SY participate under the same rule. Transfers must not manufacture a second entitlement.

**Immediate seigniorage participation and ordering:** use the eligible stake present at that issuance's distribution. Retain the purchase order in §24.4: establish the bond's funded principal position before distributing its own seigniorage pot, following the existing position-before-reward-funding order. This gives the new bond ordinary staking participation in that immediate distribution, with no second lock multiplier. For a composed ordinary mint-then-stake route, the issuance's seigniorage distributes as part of minting, before the subsequently acquired DETF is staked. An ordinary principal deposit is never itself detected as reward income.

If one transaction processes due expansion and then performs a new issuance, settle expansion before the action, and distribute the new issuance's seigniorage immediately as its own subsequent distribution. Fee receipts issued after the expansion rebase may participate in the later seigniorage distribution; neither source's new fee receipts participate in their own distribution. Do not defer the new seigniorage to the next expansion epoch or merge it backward into a completed expansion interval.

Rewards from either source are claimable once distributed, including immediate seigniorage earned during bond vesting. Bond principal continues to vest linearly between expansion boundaries. Unstaking, transfers, vested-principal claims and reward claims do not require waiting for an epoch. Standing fee/creator entitlements remain eligible even with zero ordinary stake. No time weighting, warm-up lock or no-recipient carry-forward mechanism is introduced.

### 24.4 Bond purchase and linear principal vesting

A bond buys a fixed amount of DETF, using actual payment and the selected lock duration. The purchased DETF is minted at purchase and held for the bond through staking; it is not minted incrementally when principal vests.

Let `payment` be actual payment in the quote route's input units, `bonus` the percentage from the existing lock-duration bonus calculation, and `p` the existing seigniorage fraction. Retaining D3/D4 while replacing only the old purchased-allocation basis gives the following conceptual formulas (each percentage multiplication uses the existing floor convention):

```text
G = existing proportional bond-liquidity DETF quote(actual payment)
quoteInput = payment * (1 + bonus)
U = firstBond ? linearInitialPriceQuote(quoteInput) : reserveSwapQuote(quoteInput, DETF)
principal = floor((1 - p) * U)              // fixed DETF principal that vests
rewardPot = floor(p * U) + floor(p * G)     // existing D3 + D4
liquidity deposit = actual payment + G DETF
```

`G`, purchased principal, and the reward pot are separately issued amounts. Joining `G` does not consume the purchased allocation. The existing `_splitBond(G, p)` helper assumes launch default `U = G`; the new duration-bonus quote makes `U` independent of `G`. Generalize its inputs while preserving the D3 `p * U` and D4 `p * G` rules. Fee/creator rights remain subject to the existing fee rules and settle as funded sDETF under D40 (§24.3.1).

Reuse the existing duration-to-bonus relationship, interpreting its output correctly: if a helper returns a full `1.20x` multiplier, the percentage bonus is `20%`; do not add a second base amount and quote `2.20x`. The bond quote uses the specified duration bonus. Do not silently stack the ordinary mint helper's separate `1 + p` input boost on top of it. Ordinary live mint retains its existing quote boost and gross/net split.

Required purchase behavior:

1. Validate the selected duration and accepted payment route using the resolved product configuration.
2. Determine `G` from actual payment using the existing family proportional-join formula. Determine the duration bonus and quote gross `U` from the increased input. The first bond uses the fixed linear initial-price quote in D41 (§24.4.1); live purchases use the reserve curve and its existing fee conventions, preserving quote-before-join ordering.
3. Collect **only the actual payment**, mint `G` DETF, and join both as protocol-owned liquidity using the existing family join/bootstrap path. The bonus is a quotation adjustment, not additional capital transferred by the user. The first successful bond still opens the DETF.
4. Through the authorized DETF issuance path, mint the separate purchased principal after the existing seigniorage split into bond escrow and deposit it into staking. Account separately for the D3/D4 reward pot and distribute it immediately after establishing that funded position under D49. Rebase eligible stake before issuing this distribution's fee/creator sDETF. The bond NFT controls the escrow entitlement; it is not a second issuer of a different DETF token.
5. Record fixed principal, vesting start, duration, principal already claimed, and the staking shares attributable to the NFT. The user must not receive transferable access to unvested principal outside the escrow.
6. Release original principal linearly over the selected duration; all remaining principal is vested at the end. A principal claim transfers the corresponding **sDETF** from the funded staking position under D43. It does not automatically unstake to DETF or sell/withdraw LP.

Live-bond example: a payment of 100 units with a 20% duration bonus obtains gross `U` from the pool's quote for 120 input units. Only 100 input units are paid by the user, joined with the separately minted proportional `G`. The purchased principal is the existing net-user fraction of `U` and is fixed at purchase. Because the live pool curve is nonlinear, the gross quote is not necessarily 20% more DETF than a quote for 100 input units. The first bond instead uses D41's linear price.

**Correction to the earlier draft:** the proportional `G` join is retained. Only the bond owner's LP entitlement and the old `U = G` purchased-allocation assumption are replaced. Existing initial capital requirements, creation/opening rates, family seed formulas, minimum-liquidity checks and first-bond liveness remain the baseline. D41 resolves the separate first-bond purchased-allocation quote.

### 24.4.1 D41 — First bond uses the configured initial price linearly

**Scope update:** D60 excludes further Composed/Balancer functional changes. D56's configuration design and existing work remain historical; they are not outstanding deliverables for this refactor.

**Accepted:** use the existing initial-price configuration in `PkgArgs` for the first bond. Its quoted DETF output is linear in the bonus-adjusted payment at that fixed price. The first bond does not acquire price impact from a hypothetical swap against an empty pool or from quoting the reserve after its own liquidity join. Reuse existing price parameters where available. D56 requires Composed Stable to carry its opening price and seed ratios into deployment arguments where its old payload lacked them; a hardcoded 1:1 fallback is not an accepted launch price.

For Uni V4, use the already-resolved `openingPairPerDetfWad` for the selected pair, retaining its existing fallback to `creationPairPerDetfWad`. Keep the creation/synthetic-peg meaning distinct from an explicitly supplied opening price. Preserve each family's existing initial valuation, input conversion, and required initial capital legs; their configuration representation need not be renamed to match Uni V4.

In whole-token conceptual units, with `initialPrice` expressed as payment units per DETF:

```text
quoteInput = actualPayment * (1 + durationBonus)
firstBondGrossU = quoteInput / initialPrice
vestingPrincipal = floor((1 - p) * firstBondGrossU)
```

The quote must convert units explicitly. For a WAD-normalized quote input and an initial price in payment-per-DETF WAD, the nine-decimal gross output is `floor(quoteInputWad * 10^9 / initialPriceWad)`. Retain the existing floor convention for the input bonus and fee splits. Doubling otherwise identical input doubles the unrounded quote; rounding is limited to the specified integer conversions. No amount-dependent price slope or live-pool price impact is introduced into this first-bond conversion.

Example: initial price is 2 payment tokens per DETF, actual payment is 100, and duration bonus is 20%. Quote input is 120 and gross purchased `U` is 60 DETF, before the existing gross/net split. The user still pays 100. The separately minted liquidity self-leg `G` uses actual unboosted capital and the existing family seed calculation, and remains additional to the purchased allocation and reward pot.

Preserve required first-bond liquidity and liveness validation. Once the first bond succeeds, later bonds use the live reserve-curve quote specified in §24.4. Preview and execution must select the same first-bond versus live-bond pricing branch for the same state.

### 24.4.2 D62–D64 — V4 reserve-LP payment

A live V4 DETF accepts its own reserve LP as a bond payment. Settle due expansion first, snapshot the offered LP's proportional asset entitlement using the current reserve family, and then transfer the whole payment into protocol custody. Do not remove liquidity or swap assets merely to obtain the valuation.

Exclude the direct DETF reserve leg from purchased DETF valuation. For LP representing **20 DETF plus 100 payment-token units**, the purchase quote starts from the **100 payment-token units** before the duration multiplier; the 20 DETF remains protocol inventory inside the retained LP. Keep multiple non-DETF legs distinct and use their configured pricing and buffer conversions. A buffered SE claim and the assets underlying that same claim are one entitlement, not two payments.

Apply the duration multiplier once to each eligible quoted payment leg and use the retained family quote/split rules. The LP route has no newly minted matching liquidity leg: `G = 0`. Purchased principal is minted and staked immediately, vests linearly, and earns claimable staking rewards under the existing funded-bond process. Immediate issuance seigniorage applies to newly issued amounts only. Existing self-leg DETF is neither newly minted nor a second taxable issuance. The existing first-bond process still activates an empty reserve; LP payment does not replace it.

LP ownership is independent of `ownerOnlyLiquidity`. External LP can exist in either mode and remains excluded from protocol redemption, synthetic-price and expansion calculations until actually acquired. Validate the offered token, actual received LP, caller ownership/allowance, and preview/execution agreement at the settlement snapshot.

### 24.5 Staking rewards are claimable during vesting

**D43: bond claims pay sDETF only.** Both vested principal and earned, distributed staking rewards leave the escrow as sDETF. The bond holder's economic benefits are the discount in the original DETF purchase and the staking yield earned while that principal vests. Receiving sDETF is not a second DETF issuance, LP claim, or additional bond reward stream. An owner who wants DETF can separately redeem the claimed sDETF through ordinary 1:1 unstaking.

Principal vests in fixed **DETF units**, while the escrow position is recorded in **staking shares**. Do not vest a fixed fraction of the original staking shares and thereby lock the corresponding staking rewards; the owner explicitly requires rewards to be claimable during vesting.

For a bond, let:

| Symbol | Meaning |
|--------|---------|
| `P0` | Original purchased DETF principal, from the duration-bonus quote after the existing gross/net split |
| `C` | Cumulative principal already claimed, in DETF units |
| `t0`, `T` | Vesting start and duration |
| `Q` | Current staking shares attributed to the bond, reduced as principal/rewards leave escrow |
| `value(Q)` | Current funded DETF entitlement of those staking shares, with conservative conversion rounding |

```text
elapsed = min(max(now - t0, 0), T)
vestedPrincipal = floor(P0 * elapsed / T)
claimablePrincipal = vestedPrincipal - C
remainingPrincipal = P0 - C
claimableRewards = value(Q) - remainingPrincipal
```

`remainingPrincipal` includes both unvested principal and vested-but-unclaimed principal. Both remain staked and earn rewards. Under valid funded accounting, rewards cannot consume remaining principal; any conversion dust must be handled explicitly, and a backing deficit must not be concealed by promising an unfunded 1:1 payout.

- **Reward claim:** transfer the claimable reward as sDETF and remove only its staking shares from `Q`. Do not change `P0`, `C`, `t0`, or `T`. Immediately distributed seigniorage and settled expansion rewards can both be claimed during vesting; pending, unminted expansion is not yet a claimable balance.
- **Principal claim:** transfer the vested amount as sDETF, remove its corresponding staking shares from `Q`, and increase `C` by the equal DETF-denominated principal paid. Do not reset or accelerate the original schedule.
- **Combined claim:** apply both debits once. Repeated calls cannot claim the same principal or reward twice.
- **Maturity:** release all remaining principal and claimable rewards as sDETF, subject only to defined rounding dust; no LP liquidation or sale-to-protocol conversion is needed for the ordinary exit.

Example: original principal is 100 DETF. Halfway through vesting, after completed reward distributions, the position is worth 110 sDETF and nothing has been claimed. Claimable principal is 50, unvested principal is 50, and immediately claimable rewards are 10. Claiming both principal and rewards transfers **60 sDETF** and leaves 50 sDETF in escrow for the remaining principal. Claiming only rewards transfers 10 sDETF and leaves all 100 principal staked, of which 50 is already vested.

The old mature-bond LP sale/acquisition question is resolved by the new entitlement: bonds already hold funded DETF through staking. D43 fixes the payout behavior for every supported bond claim/close path. D53 requires consolidation into standard interfaces wherever their semantics fit, with only necessary NFT-specific lifecycle entrypoints retained (§24.11). The reviewed selector map must remove obsolete LP-sale routes and duplicate fungible entrypoints; it cannot add a caller-selectable DETF or payment-token bond payout. Specifying conservative final-exit rounding does not reopen the accepted bond economics.

### 24.6 Failed price gates select reserve swaps

**D51: every DETF is price gated.** The former Policy behavior is the sole deployment behavior. Remove `ThresholdMode.Open` and the deploy-time option to enable or disable price gating; do not keep a hidden compatibility flag or another route that selects ungated primary issuance/redemption. Retain configured mint/burn thresholds, their validation and strict inequalities. This does not gate the first-bond bootstrap, funded stake/unstake or bond claims; their existing exemptions remain.

**This fallback is mandatory, not an optional caller mode.** A live, valid exchange must not revert solely because the synthetic mint/burn threshold fails.

| Request | Primary price gate passes | Primary price gate fails |
|---------|---------------------------|--------------------------|
| Mint / buy DETF | Run the primary mint path; payment builds protocol reserves | Swap actual payment through the reserve pool to acquire existing DETF |
| Burn / sell DETF | Burn user DETF and fund output from protocol-owned reserves | Swap user DETF through the reserve pool for the requested output |

The fallback swap itself does not mint or burn DETF, does not receive a seigniorage input bonus, and does not manufacture an issuance-funded reward pot. It follows actual reserve swap economics. This does not prohibit a separately required expansion realization earlier in the same transaction from changing supply.

Retain the existing realize-before-primary-gate ordering when applying the refactor to mint/burn. Evaluate the gate against the resulting supply and backing. **Replace D31's gate-failure revert with the swap branch**; a successful fallback must not undo expansion merely because the primary gate failed. Views must account for the corresponding pending state and quote the same selected route.

Apply the same selection to relevant `IStandardExchangeIn` / `IStandardExchangeOut` paths, public mint/burn entrypoints, and SY deposit/redeem routes. Enforce actual input/output amounts, recipient semantics, valid configured routes, approvals, slippage limits and existing deadline handling. A primary-issuance-allowed getter must not be mistaken for an assertion that no swap route exists.

Do not use a blanket catch of any failed mint/burn to trigger a swap. A price-gate failure is the accepted fallback trigger. Insufficient liquidity, an uninitialized reserve, unsupported routes, allowance failures and user slippage limits can still prevent execution. Preserve those existing failures; an additional fallback trigger is not part of the requested change. Use the reserve host's existing swap fees and supported routing capabilities, with no new fallback-specific surcharge or issuance bonus.

Staking unstake and funded bond principal/reward claims are independent of DETF price gates. A composed exit may unstake to DETF and then exchange that DETF for another token; market-execution constraints apply to the second leg, not the 1:1 staking entitlement.

### 24.7 Pendle SY interface and retained SE routes

The original integration scope is narrowed by D60 and D66: **the four V4 DETF bindings and in-scope SE vaults**. Balancer-hosted DETF functional work is excluded; unfinished Slipstream work is deferred. Continue the remaining native SE/SY and shared V4 requirements, with `IStandardExchangeIn` and `IStandardExchangeOut` retained. Add SY routes rather than replacing those interfaces. **D44 selects a separate SY share-token address for raw DETF.** The static wrapper of sDETF provides the staking-yield integration. SE-vault SY integrations continue to use their existing asset/share model; these DETF decisions do not change unrelated SE-vault token decimals or entitlements.

Target [Pendle's `IStandardizedYield`](https://github.com/pendle-finance/pendle-core-v2-public/blob/main/contracts/interfaces/IStandardizedYield.sol). Its current deposit is the four-argument `deposit(receiver, tokenIn, amountTokenToDeposit, minSharesOut)`, whereas the linked [ERC-5115 draft](https://eips.ethereum.org/EIPS/eip-5115) shows an additional deposit flag. Pendle redemption uses `burnFromInternalBalance = true` for shares held by the SY contract and `false` for the caller's shares. Implement Pendle's token discovery/validation, preview, exchange-rate, asset metadata, event and reward-accounting surfaces; do not copy the draft's differing flag prose.

The staking-token SY has **9 decimals and non-rebasing balances** under D46. Its accounting asset is the actual nine-decimal DETF token, and `yieldToken()` identifies the actual sDETF token. Underlying staking rebases become exchange-rate growth for static SY holders. For raw units, `floor(syAmount * exchangeRate / 1e18)` expresses the corresponding DETF entitlement, with conservative rounding in the applicable conversion direction. The economic exchange rate reflects the funded staking position; it must not treat a pending, undistributed epoch allocation as an already-redeemable balance. The optional Scaled18 representation is not part of this selected profile.

`yieldToken()` identifies the actual wrapped ERC-20 when one exists. A native SY representing positions without an underlying ERC-20 yield token may return `address(0)`; this is the applicable case for native position-based Uniswap V3/V4 vaults. A wrapper around an existing vault share or staking token returns that token's address. Do not return zero merely because the strategy uses Uniswap.

The raw DETF wrapper mints/burns its **own** SY shares around acquired/released DETF. A failed primary DETF price gate still selects a reserve swap; a swap need not mint/burn DETF for the wrapper to mint/burn SY. Report the actual wrapper share issuance and the actual DETF route correctly. Raw DETF wrapping does not itself turn the held DETF into staked principal; the staking wrapper holds the separate sDETF position. Neither wrapper changes or replaces the DETF's existing exchange interfaces.

**D45 fixes the staking SY's route profile:**

| Token supplied / requested | SY deposit | SY redemption |
|----------------------------|------------|---------------|
| sDETF | Receive sDETF and issue static SY against the acquired staking position | Burn SY and transfer the corresponding sDETF |
| DETF | Stake received DETF 1:1, then issue static SY against the acquired sDETF | Burn SY, release the corresponding sDETF and unstake it 1:1 to DETF |
| Existing configured DETF route token | Execute the existing DETF input route, stake acquired DETF, then issue static SY | Burn SY, unstake the corresponding sDETF, then execute the existing DETF output route |

`getTokensIn()` exposes sDETF, DETF and the existing supported DETF input-token set; `getTokensOut()` exposes sDETF, DETF and the existing supported output-token set. Deduplicate token addresses. Preserve direction-specific support; an input route does not imply an output route. Advertise only configured executable routes, and make validation, previews and execution agree. No new external swap routing policy, bond NFT deposit, or access to unvested bond principal is implied.

The composed exchange legs retain existing fees and mandatory price-gate fallback. Enforce the SY caller's final minimum output. Direct sDETF/DETF wrapping and unstaking do not acquire a reserve-pool dependency merely because the wrapper also supports payment-token routes. Only actual received assets may fund newly issued shares, and each redemption debits its SY and staking position once.

Both immediately distributed seigniorage and settled expansion yield are reflected in the SY exchange rate. Neither may also appear as a separately claimable SY reward token. The rate may increase between expansion boundaries when seigniorage distributes. Implement the required reward methods with the appropriate empty reward surface for this compounded staking-yield profile. Existing external reward behavior of other SE vaults must be mapped from their actual implementation rather than silently removed. The exact per-family API/metadata matrix and upstream revision pin are engineering specification work under these accepted decisions, not unresolved SY product choices.

### 24.7.1 D57–D59 — Full-range position vaults

For this release, Uniswap V3/V4 use the maximum usable tick range supported by each pool's tick spacing. V3/V4 already do this for ordinary launches; normalize imported positions into the same full-range structure. D66 defers unfinished Slipstream full-range/import conversion, accounting and SY work, preserving completed code and validation. An imported narrow-range position must not remain the backing structure of a newly activated vault.

Apply V2-style proportional ownership and constant-product accounting to the complete token book. Compute deployed token amounts using exact concentrated-liquidity math at the actual pool price and position bounds. Combine those amounts with held sleeve balances and earned fees, counting each asset once. Fee collection and liquidity deployment move assets between book components; those movements cannot create accounting gains or losses by counting the same amount twice. Do not use deployed liquidity alone as the entitlement when funded sleeves or earned fees are present.

Require both tokens for initial activation, including an imported-position launch. Retain subsequent single-token deposits. Sleeves support operations when the underlying pool cannot be modified, including pool locks; accounting and SY conversions must continue to include these balances. This does not promise unlimited output liquidity or waive actual funding and minimum-output checks.

These decisions resolve the position-vault design question. They require changes to the underlying vault accounting where needed, followed by SY integration over that same accounting; they do not authorize choosing a new one-token NAV policy. D66 explicitly defers the unfinished Slipstream adapter and its validation gates; V3/V4 remain required.

**Release scope override (D66):** Defer all unfinished Slipstream work from this release by owner decision. Robinhood targets Uniswap V4. Preserve completed Slipstream changes, existing functionality, tests and validation evidence. Permit only compilation maintenance or compatibility edits required by shared V4 changes; no pending Slipstream functional, full-range/import conversion, accounting, native SY, deployment/UI, test, fork or integration completion gate remains. Shared V4 work and other approved scope continue; no unresolved release requirement is created.

### 24.7.2 D61/D65 — Reserve liquidity permissions

The creator selects immutable `ownerOnlyLiquidity` through DETF creation configuration and deployment arguments. The deployed DETF remains the reserve hook owner in both modes; the creator acquires no hook administrator role. Validate that the DETF payload and actual hook setting agree. Expose no post-deployment toggle.

With `true`, only DETF may directly add reserve liquidity; DETF and the current Fee Collector may remove LP under D65. With `false`, users may add liquidity and redeem LP they own or are authorized to spend. Preserve the DETF's privileged operations and public swaps in both modes. Do not reinterpret restricted mode as deposits-only.

**Resolved compatibility issue (D65):** investigation found the Fee Collector could transfer LP but had no underlying redemption operation. The owner approved redemption through the current `feeTo()` Fee Collector. Permit that collector to remove LP it holds through an owner-operated collector method, with minimum outputs, deadline and ordinary LP ownership/approval enforcement. Read the live oracle `feeTo()` at each withdrawal; an old collector loses this special removal permission after rotation and may transfer remaining LP to the new collector using its existing owner-operated `pullFee`. Keep additions DETF-only and ordinary public removals restricted. This is the approved narrow withdrawal exception; a deposits-only policy remains unapproved. This dynamic hook permission does not transfer the original standing staking-reward NFT rights when `feeTo()` changes.

### 24.8 Supersession and integration map

| Earlier rule / document | Effect of D32–D66 |
|--------------------------|-----------------|
| D10, §14; D15 / §15.5 | Replace LP-valued rebasing claims and LP-zap-out redemption with funded 1:1 DETF staking |
| D11 / §15.1; D13 / §15.3 | Replace bond-owner LP principal and dilution accounting. Protocol operations build protocol-owned LP; bond liabilities are funded DETF allocations |
| D18 / §15.8 | DETF-to-staking deposits hold DETF rather than joining the DETF self-leg into liquidity |
| D24 / §17 | Preserve the proportional `G` liquidity join. Replace only old purchased allocation `U = G` with the duration-bonus-on-input quote; `G` and vested DETF are separate mints |
| D25 / §18 | Replace ordinary user-bond LP basket close with release of vested principal and independently claimable staking yield, both paid only as sDETF under D43 |
| D2–D7, D14, D17, D19, D21, D27–D28; §§3–9 and §20 | Preserve issuance formulas, fee configuration, allocation and beneficiary rules. D40 pays calculated fee/creator DETF allocations as fully funded sDETF after the staking portion's rebase. These receipts redeem 1:1 to DETF; selling or fully redeeming them does not extinguish future fee rights. Former reserved-NFT capital restrictions do not lock the paid sDETF. User-bond rewards now follow funded stake, and automatic LP compounding changes destination |
| D12, D31 / §23 | Primary burn still burns DETF; failed primary price gates now select supply-neutral swaps. The previous requirement to revert on gate failure is superseded |
| D16 / §15.6 and family first-bond rules | Retain family initial capital, self-leg seed, creation/opening rates and first-bond liveness. LP becomes protocol capital and separate purchased DETF vests. D41 uses the existing configured initial price as a fixed linear quote for that first purchased allocation |
| D29 and reserve donation PRD | Donations remain protocol capital; do not create new user LP principal or automatically issue staking receipts without depositing DETF into staking |
| D9 / §11; D30 / §22 | Preserve appropriate reserve-host settlement and access controls. Reconcile legacy public LP ownership with the new protocol-reserve model; do not import legacy claim-unwind requirements as new staking mechanics |
| Compound/expansion PRD and older Olympus flywheel draft | D37/D38 replace conflicting reward destinations and stake-vs-capital-bond assumptions. D49 distributes seigniorage immediately. D50 applies fixed eight-hour boundaries and one aggregate catch-up only to automatic expansion. D51 removes Open mode and D52 removes all expansion catch-up caps; preserve the rate formula subject to these new requirements |
| Existing family expansion caps, deployment parameters and capped-catch-up tests | D52 supersedes elapsed-time caps, maximum epoch counts, supply-relative per-update caps and equivalent amount ceilings for every DETF. Remove their configuration and specify uncapped aggregate realization over all completed unsettled epochs. Historical cap behavior is not an alternative refactor implementation |
| Standalone mint/claim/stake convenience functions and legacy selector exports | D53 makes SE/SY the canonical interfaces wherever they express the route. Deprecate duplicate standalone entrypoints, remove their exports from new deployments and migrate affected callers to standard routes. Required NFT lifecycle operations remain position-specific |
| Legacy `Storage` members and layout-compatibility placeholders | D54 requires a field-by-field cleanup of affected new-deployment layouts. Remove obsolete members and their dependent initialization/accessors; retain actual custody, funded liabilities, vesting and standing fee-right accounting. No in-place storage migration is implied |
| Bond NFT SVG and JSON metadata | D55 replaces old LP shares, boosted reward shares and all-or-nothing unlock displays with the funded staking and linear vesting model. The accepted bond and fee-receipt rules override conflicting older product-copy guidance |
| Earlier D42 all-rewards epoch interpretation and D47 scope | D49/D50 correct the scope: epoch participation applies to expansion only. Seigniorage from applicable issuance distributes immediately, with the same rebase-before-fee-receipts order |
| Threshold-mode law, related family deployment args and Open-mode tests | D51 removes the deploy-time mode choice. Every new DETF uses price gating; retain threshold values/validation, gate exemptions and D39's mandatory reserve-swap fallback. Historical Open-mode behavior is not a supported refactor profile |
| I/O routing PRD §16 and family PRDs | Retain configured token routes and host curves; update bond, staking, decimals and threshold-fallback semantics in the later implementation/documentation reconciliation |
| Earlier native-DETF SY proposal and R5a–R5c | D44 selects a separate raw-DETF SY token; D45 selects the full existing route sets plus direct DETF/sDETF for staking SY; D46 fixes staking SY to 9 decimals. These product choices are resolved |
| `.github/ASSISTANT_DEPLOYMENT.md`, `.github/ASSISTANT_TESTS.md`, agent law and decimal helpers | Former DETF/claim-token 18-decimal requirements are explicitly superseded by the owner's D33 decision for the refactor. Update those assumptions during authorized implementation; do not reinterpret 9 as an optional profile |

The historical sections remain useful for understanding current code and already-running work. Their incompatible accounting is not an alternative implementation of the new decisions. The new implementation plan is separate; historical plans and concurrent implementation work remain untouched by this documentation pass.

### 24.9 Product decisions resolved; implementation specification

The owner's formula review clarification narrows the outstanding decisions. **Preserve the current baseline unless an accepted change creates a specific conflict.** In particular:

- **Ordinary issuance:** retain the reserve-curve quote with the existing seigniorage input boost and `_splitLiveGross` output split. Reserve-host fees remain part of the quote.
- **Bond capital:** retain `_quoteBondG` / `_quoteBondJoinDetf` and the actual-payment-plus-`G` liquidity join. Retain family first-bond initialization and liveness. The existing quadratic duration-bonus formula and configured bounds remain in force.
- **Primary burn:** retain `lpToExit = floor(detfBurned * protocolOwnedLp / detfTotalSupply)` and the existing family proportional exit/DETF self-leg handling. Use actual protocol-owned LP custody and supply after required expansion realization, before the user's burn. DETF in the pool, staking reserve and bond backing remains outstanding supply. There is no additional bond-owner LP deduction under D35.
- **Scaling:** equal nine-decimal DETF amounts cancel in `detfBurned / detfTotalSupply`. Bootstrap prices, synthetic-value calculations and pool adapters that assumed 18-decimal DETF require explicit conversions, not replacement economics.
- **Expansion:** apply the retained rate formula to all unsettled completed eight-hour epochs, with one aggregate mint/distribution and no time, epoch-count or amount cap. D52 removes the former cap parameters across all families; the existing code is not authority to retain them.
- **Existing controls:** preserve fee/terms configuration sources, threshold definitions, route capabilities, NFT ownership/claim authorization and immutable-instance deployment rules. D51 removes the deploy-time gating switch and Open mode; all new DETFs are price gated with the D39 swap fallback. No migration or additional fallback trigger is implied by this refactor.

Source review: [`DETFMintSplitLib`](./common/core/DETFMintSplitLib.sol), [`DETFBondNFTMathLib`](./common/core/DETFBondNFTMathLib.sol), [`DETFSeigniorageShareLib`](./common/core/DETFSeigniorageShareLib.sol), Uni V4 [`Common`](./protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol) / [`Target`](./protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol), and Balancer Single SE [`Common`](./protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFCommon.sol) / [`BondingTarget`](./protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol). This is a formula/design review, not a completed audit of every family implementation.

**R1 is resolved by D41 (§24.4.1):** the first bond's separate purchased allocation uses the existing configured initial price as a fixed linear conversion, with the agreed duration bonus and fee split.

**R2 is resolved by D40 (§24.3.1):** fee/creator allocations are paid as funded sDETF, redeemable 1:1 to DETF, with continuing fee entitlement after full redemption. The distribution's ordinary staking rebase precedes issuance of its new fee receipts.

**R3 is resolved by D47–D50 and D52 (§§24.3.1–24.3.2):** seigniorage distributes immediately in the issuing transaction. Only automatic expansion uses eight-hour epochs, anchored to the first successful bond with fixed boundaries and one aggregate catch-up mint/distribution. All expansion catch-up caps are removed, so the entire unsettled completed-epoch interval contributes. Settle due expansion before new principal or withdrawals. Both sources require actual minted/funded DETF and rebase eligible stake before issuing fee/creator sDETF. Standing fee/creator entitlements remain eligible with zero staked balances; the existing allocation calculation covers that case. The earlier all-rewards epoch queue and no-recipient carry-forward proposals are withdrawn.

**R4 payout is resolved by D43 (§24.5):** bond holders claim only the sDETF attributable to their purchased principal and its staking yield. The remaining specification work must not reintroduce alternate bond payout assets.

**R5a–R5c are resolved by D44–D46 (§24.7):** a separate raw-DETF SY token, all existing configured DETF routes plus direct DETF/sDETF for staking SY, and a nine-decimal static staking SY.

D60 excludes Balancer-hosted DETFs and retires their reserve-LP bond-payment question. D57–D59 remain accepted for SE position vaults. D61–D64 resolve V4 reserve liquidity permissions, own-reserve LP payment and ownership accounting. **D65 is resolved: restricted liquidity can be redeemed through the current `feeTo()` Fee Collector, including after fee-recipient rotation.** D49/D50 specify the reward clocks, catch-up behavior and distribution ordering; D51 removes Open mode and D52 removes all expansion catch-up caps. D53–D55 add interface consolidation, unused-storage removal and the bond NFT artwork/metadata redesign (§24.11). The separately authorized [implementation plan](./DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md) specifies staking-share and fee-weight accounting, conversion rounding/final exits, selector replacements, storage disposition, deployment changes, SY integration rules and representative bond states. Its Stage 0 verifies the exhaustive call-site, package, selector and field manifests against the implementation baseline. The accepted requirements govern every in-scope DETF; use current code to identify necessary changes, not to preserve superseded behavior. The owner subsequently authorized execution of the plan and continuation in the main repository. Production deployment and migration remain outside that authorization.

Pendle already defines the required selectors, internal-balance flag, events and raw-unit exchange-rate convention; these are not additional product questions. The accepted staking SY profile uses DETF accounting, an sDETF position, nine-decimal static balances and both immediate seigniorage and settled expansion reflected in its exchange rate. For each SE family, derive metadata and valuation from its existing asset/share model and document the result; surface a concrete conflict if that model lacks the necessary information. Pin the reviewed upstream revision and produce the exact adapter/API matrix as engineering specification work before implementation.

SY reference review: [Pendle interface](https://github.com/pendle-finance/pendle-core-v2-public/blob/main/contracts/interfaces/IStandardizedYield.sol), [SY behavior](https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield), and [Units and Scaled18](https://docs.pendle.finance/pendle-v2-dev/Contracts/UnitAndDecimals). These sources define protocol mechanics, not permission to copy optional ownership/upgradability or change the accepted nine-decimal DETF/staking tokens.

Questions about replacement issuance rates, replacement burn-to-LP formulas, removal of the proportional bond join, a new bootstrap mechanism, new fee settings, extra fallback fees, and migration are withdrawn. Former questions about rewards auto-compounding to LP, user-bond LP ownership, payment for an LP-principal bond sale, and a distribution with no recipients despite standing fee/creator rights are also resolved. Engineering specification work is not authority for an implementer to select new economics.

### 24.10 Acceptance criteria for the later refactor

These criteria define observable implementation acceptance. The owner has authorized execution of the implementation and test plan; verification status is tracked separately from the requirements.

| ID | Required evidence |
|----|-------------------|
| **A1** | Every in-scope DETF and its staking token reports 9 decimals. Stake/unstake uses equal raw amounts; remaining 18-decimal DETF assumptions in bootstrap, pool scaling, supply, rewards and integrations are removed or converted explicitly |
| **A2** | Deposits and funded rebases never issue more redeemable staking units than held DETF backs. LP value, pending unfunded expansion, unrelated idle balances and repeated reward synchronization cannot manufacture claims |
| **A3** | For an unchanged holder position, the funded rebase index/balance never decreases. Pool swaps, DETF burns and LP valuation changes do not reduce staking inventory. Unstake transfers held DETF 1:1 independently of mint/burn gates |
| **A4** | Mint/bond capital increases protocol-owned reserve assets. A bond separately mints proportional `G` and joins it with actual payment; this does not consume the vesting allocation. The first bond still initializes the family reserve and opens the DETF. New bond NFTs have no LP-principal redemption entitlement. Protocol reserves and staking backing are conserved independently |
| **A5** | Bond principal equals the existing net-user split of the specified duration-bonus gross quote `U`, while actual received capital equals unboosted payment. The duration multiplier is not double-counted; D3 uses `U` and D4 uses independent `G`. Principal is fixed, minted and funded into staking at purchase |
| **A6** | Original principal vests linearly: no principal is claimable before its elapsed fraction, repeated/partial claims do not reset the clock, and all principal is vested at maturity |
| **A7** | The 100-principal / 110-staked-value halfway example yields 50 claimable principal and 10 independently claimable rewards. Rewards on unvested and vested-but-unclaimed principal are claimable; claiming them does not consume principal or accelerate vesting |
| **A8** | Interleaved rebases, reward-only claims, principal-only claims, combined claims and NFT ownership changes conserve each bond's staking shares and remaining principal. No cross-NFT leakage, double claim, or unrecoverable final principal dust |
| **A9** | Seigniorage and expansion reach staking backing. Their staking-reward portion benefits ordinary and bond-escrowed staking positions through the same funded index; fee/creator portions separately fund the receipts specified in D40. No duplicate payout through legacy bond reward shares or unintended second LP-compound allocation |
| **A10** | At each failing primary price threshold, including equality/deadband, mint/buy and burn/sell execute their reserve-swap branches when liquidity and user limits permit. The fallback itself has zero DETF mint/burn; a successful fallback does not revert solely because expansion changed the primary gate result |
| **A11** | Preview and execution agree on selected primary/swap route, fees and conservative outputs for the same state. Slippage, allowance, unsupported-route and liquidity failures retain their legitimate failure behavior; arbitrary errors are not swallowed as price-gate fallbacks |
| **A12** | Existing SE interfaces remain callable. Pendle-compatible SY entrypoints, internal-balance redemption, metadata and static-share accounting work with nine-decimal DETF/staking tokens and supported underlying decimal combinations. A complete SY staking deposit/reward/redemption round trip preserves backing |
| **A13** | Ordinary issuance, existing fee parameters and primary burn-to-LP proportionality retain their baseline economics under correct decimal conversion. Principal deposits are excluded from reward detection; fee-only weights cannot create unfunded redeemable principal |
| **A14** | For a 100-DETF distribution with allocated fee 10 and creator 5, exactly 85 funds the existing positions' rebase and 15 backs newly delivered 10/5 sDETF receipts. Previously held fee/creator sDETF earns the ordinary rebase; this distribution's new receipts do not. Repeated synchronization cannot redistribute the 100 or issue duplicate receipts. Fee payout remains funded and possible when no other staking positions exist |
| **A15** | Fee/creator receipts transfer and unstake to DETF 1:1 without bond maturity or DETF price-gate restrictions. After either recipient fully redeems to zero sDETF, the next applicable distribution still pays new funded sDETF under that recipient's continuing fee entitlement. Partial redemption and transfer likewise do not cancel that entitlement, and a transferee gains no fee/creator role merely by receiving sDETF |
| **A16** | First-bond gross DETF is the linear conversion of bonus-adjusted input at the configured initial/opening price, with correct native/WAD/nine-decimal scaling and existing fee splits. At initial price 2 and payment 100 with 20% bonus, gross `U` is 60 DETF. The independent liquidity self-leg remains unboosted. Preview and execution agree; first-bond pricing has no live-pool price impact, and later bonds use the live curve |
| **A17** | Only automatic expansion follows the fixed 8-hour epochs. Every applicable ordinary/bond issuance distributes its funded seigniorage immediately, including between boundaries, without moving the expansion clock. Principal deposits and unminted expansion cannot manufacture rewards. Neither distribution source can be paid twice. Both rebase eligible stake before issuing their fee/creator receipts; transfers, unstaking and funded bond claims remain available between boundaries |
| **A18** | Every supported bond principal/reward/close claim transfers only sDETF from the attributable escrow stake. The 100-principal/110-value halfway combined claim pays 60 sDETF. Claiming itself neither mints DETF nor unstakes or liquidates LP; the recipient may separately unstake claimed sDETF to DETF 1:1. No extra bond-specific reward or lock multiplier is applied to the purchased staking position |
| **A19** | The raw-DETF SY has a separate share-token address. Its deposit/redeem mints/burns SY around acquired/released DETF, including when the DETF leg selects a supply-neutral reserve swap. Existing DETF SE entrypoints remain callable and events distinguish actual SY issuance from DETF swap transfers |
| **A20** | Staking SY supports direct sDETF, direct DETF and every existing directionally configured DETF input/output route. Discovery, validation and previews match execution; composed routes enforce final minimum outputs and preserve primary/swap selection and existing fees. Direct sDETF/DETF routes preserve funded 1:1 staking without requiring a reserve swap |
| **A21** | Staking SY reports 9 decimals, non-rebasing balances, DETF accounting metadata and sDETF as its yield token. Its WAD exchange rate converts raw SY to raw DETF entitlement; immediately distributed seigniorage and settled expansion can increase that entitlement without rebasing SY balances or creating a duplicate reward-token claim. Pending unminted expansion is not already-redeemable backing. No Scaled18 metadata or unapproved changes to SE-vault decimals are introduced |
| **A22** | An ordinary or bond-escrow deposit already present at an expansion boundary participates without time weighting, including a deposit made just before the boundary. A deposit entering in the transaction that processes the due boundary is credited afterward. Due expansion precedes withdrawals. Immediate seigniorage uses the stake present at its own distribution, with the bond's funded position established before its own pot distributes. New fee receipts do not earn their own distribution, and transfers cannot duplicate entitlement |
| **A23** | After all actual sDETF balances are redeemed, standing fee/creator reward rights remain eligible. A later distribution processes their existing weights and pays newly funded sDETF even with zero ordinary staking supply. When only their standing weights remain, the existing calculation distributes between them without an invented fixed ordinary-staker remainder or a no-recipient carry-forward branch; preserve ordinary rounding-dust accounting |
| **A24** | The first successful bond anchors the expansion clock. At hour 25 with three completed intervals and no intervening interaction, process one aggregate eligible expansion mint and distribution, advance through hour 24 and retain hour 32 as the next boundary. No historical distribution replay, hypothetical fee-receipt compounding, duplicate interval payment or distribution of unminted DETF occurs; zero eligible expansion advances completed boundaries without issuing unfunded claims |
| **A25** | A transaction with both due expansion and new issuance settles expansion before the action and distributes the new seigniorage immediately afterward under the required position order. Each source rebases eligible stake before issuing its own fee/creator sDETF. Expansion fee receipts may earn the later seigniorage distribution, but no receipts earn their own distribution. Expansion does not also mint an extra `p * expansion` reward |
| **A26** | Every refactored DETF deploys with mandatory price gating. Deployment cannot select Open or disable gating through any alternate flag. Preserve configured thresholds, validation, first-bond/staking/claim exemptions and primary mint/burn semantics; failed primary gates use reserve swaps under A10/A11 |
| **A27** | Every family calculates expansion over all unsettled completed epochs without a time, epoch-count, supply-relative or absolute amount cap. Seven idle days contribute all 21 completed epochs to one mint/distribution. Cases whose formula output exceeds former per-update caps still mint the full calculated amount. No cap deployment option or equivalent hidden limiter survives, and subsequent calls cannot pay the same interval twice |
| **A28** | The final selector inventory maps every retained fungible mint/burn/stake/unstake/wrap route to SE/SY. Duplicate standalone selectors such as `mintClaim`, `buyClaim` and `redeemClaim` are absent from new deployment exports and supported callers use their standard replacements. Retained NFT-specific operations have a documented need for position/duration arguments and cannot release unvested principal |
| **A29** | Standard replacements preserve route discovery, previews, received-asset accounting, recipient/approval semantics, slippage, supported exact-out behavior, funded staking and price-gate swap fallback. SE and SY compose the same accounting operations without double minting, double reward distribution or a second bond payout route |
| **A30** | A field-by-field inventory accounts for every affected storage member as retained with an active purpose, replaced or removed. Unused fields, obsolete layouts and their initialization/getter-only dependencies are removed from the new implementation. All readers/writers use the same revised layout, while required protocol LP custody, staking backing, vesting and standing fee rights remain functional |
| **A31** | The redesigned SVG and JSON traits reflect current funded bond state. The 100-principal/110-sDETF halfway example shows 50% vested, 50 sDETF claimable principal, 10 sDETF claimable rewards and 60 sDETF total claimable. After claiming both, it shows 50 DETF remaining principal and zero immediately claimable balance at the same timestamp. Reward-only claims do not change vesting progress or principal |
| **A32** | Representative new, partially vested, partially claimed, fully vested and retained standing-role NFT states render legibly with explicit token units and nine-decimal amounts. SVG/JSON contain no obsolete user LP entitlement, boosted reward-share balance, cliff-only unlock story or unfunded projected reward. Text is escaped and artwork renders without external scripts, fonts or image requests |
| **A33 — excluded by D60** | Historical Composed requirement, no further functional work: deployment arguments carry opening price and seed ratios through validation, deterministic prediction, initialization and callers. Non-1:1 rich first-bond previews and execution agree on separate linear purchased `U` and unboosted liquidity `G`; later bonds use the live curve. |
| **A34** | V3/V4 ordinary launches and imported positions produce the maximum usable tick range for the actual tick spacing. Imports preserve credited assets through conversion; no narrow imported backing remains. |
| **A35** | For in-scope V3/V4 position vaults, independent exact concentrated-liquidity token amounts plus sleeves and earned fees reconcile to the complete V2-style proportional/constant-product book and SY rate. Fee collection, deployment, withdrawal and locked-pool sleeve operations do not double count assets. Mixed decimals, price movement and rounding are covered. |
| **A36** | For in-scope V3/V4 position vaults, initial activation requires both tokens and rejects a one-sided launch atomically. Subsequent single-token deposits and funded sleeve routes work while the underlying pool is locked; previews, credited shares and actual payouts agree. |
| **A37** | All four V4 bindings expose the creator-selected immutable liquidity policy in creation/deployment. DETF and hook agree; only DETF directly adds in restricted mode; DETF and the current fee collector may remove their LP under D65, public holders/authorized spenders may do so in public mode, unauthorized spending fails, DETF ownership/privileges persist and public swaps work in both modes. |
| **A38** | Own-reserve LP payment preserves the entire position and uses only proportional non-DETF value. Cover the 20-DETF/100-payment example, multiple distinct payment legs, buffered SE accounting without double counting, foreign-LP rejection and no valuation unwind. |
| **A39** | LP-payment preview/execution settle due expansion before snapshot/funding and agree on duration bonus once, split, funded principal, immediate rewards and linear vesting. No matching `G` is minted and no issuance fee is charged on existing DETF inside the LP. First-bond activation remains intact. |
| **A40** | External LP in both modes remains outside protocol redemption, synthetic-price and expansion calculations until actually received; acquiring LP changes custody exactly once. Actual-receipt, ownership/allowance, donation, preview and conservation controls pass. |
| **A41** | Production-path Fee Collector redemption works in restricted mode, including after `feeTo()` rotation. The old collector loses special removal authority; neither collector nor another caller can redeem unowned/unapproved LP. Collector additions and ordinary public removals remain restricted. |
| **A42** | D66 scope is reflected in the plan, manifests and release gates. Preserve completed Slipstream code, existing functionality/tests and historical validation evidence; no unfinished Slipstream functional work, new tests, fork checks or integration validation is required for release. Only compilation maintenance or compatibility with shared V4 changes may alter Slipstream. No unresolved Slipstream requirement blocks release. |

### 24.11 D53–D55 — Standard interfaces, storage cleanup and bond artwork

**These requirements apply within the current release scope: the four V4 DETF bindings and SE work remaining after D60/D66.** Additive SY coverage of SE vaults also follows D53 for routes within the existing integration scope. Work produced concurrently by another agent must be reconciled against these requirements during the authorized refactor; this documentation update does not interrupt that agent or change its implementation.

#### 24.11.1 Consolidate public operations into Standard Exchange and Standard Yield

SE/SY are the canonical public interfaces for fungible operations they can express. Consolidation must reduce duplicate API behavior, not merely rename a legacy function or add an additional standard wrapper around a separate accounting path.

| Operation | Required public route |
|-----------|-----------------------|
| Configured input token → DETF; DETF → configured output token | `IStandardExchangeIn` and, where supported under D23, `IStandardExchangeOut`, including primary issuance/redemption and the mandatory reserve-swap branch |
| DETF → sDETF; sDETF → DETF | Standard Exchange stake/unstake routes using actual held DETF at 1:1, replacing standalone claim-token mint/buy/redeem entrypoints |
| Supported token → raw-DETF SY or staking SY; SY → supported output | Pendle SY `deposit` / `redeem` on the appropriate wrapper, composing the standard DETF and staking routes under D44–D46 |
| Buy a vesting bond, claim a specific NFT's vested principal/rewards, transfer an NFT | The minimal necessary NFT lifecycle interfaces, preserving duration, token-id and ownership semantics; ERC-721 transfers remain standard |

The token called a claim token in legacy code now represents funded sDETF. A route formerly exposed as `mintClaim`, `buyClaim` or `redeemClaim` must use the accepted staking economics through the standard interface. Deprecate the duplicate public selector and omit it from the new deployment's facet exports, ABI and advertised capabilities. Remove obsolete LP-sale routes rather than preserving their old economics behind a standard name. Existing deployed instances are not modified by this change.

Produce an explicit inventory of old selector, replacement interface/route, contract address that owns the standard entrypoint, dependent callers and disposition. Update affected routers, wrappers, package registration, interfaces, previews, tests and client bindings during authorized implementation. Functions added by another agent receive the same review. Necessary authorized internal mint/burn/settlement helpers are not redundant public user routes and may remain behind the standard entrypoints.

Do not change the standard ABI to encode a bond NFT id or lock duration in a fungible token amount. The interfaces cannot replace an NFT lifecycle operation merely because it eventually pays sDETF. Retain only the necessary position-specific entrypoints and keep their payout fixed to D43. Likewise, protocol maintenance and ERC-20/ERC-721 interfaces retain their legitimate roles. Unsupported exact-out routes remain unsupported under D23.

Shared accounting operations must make SE and SY agree on funded balances, receipt issuance, reward ordering and the primary/swap route. Preserve input/output validation, safe receipt of transferred tokens, allowance and recipient handling, deadlines where present, and final user limits. A composed SY route must not execute reward settlement or liability creation twice through nested standard calls.

#### 24.11.2 Remove unused storage and its dependent code

Review every member of affected DETF, bond, staking and wrapper `Storage` structs against the final model. For each member, identify its owning contract, initialization, actual readers/writers and required product responsibility. A legacy getter that exists only to expose an otherwise obsolete field is not a reason to retain that field.

Remove unused fields, mappings, cached values and flags together with obsolete initialization, setters/getters, helper code, events and tests that exist only for the removed behavior. Specific review targets include user-bond LP principal and lock-boosted reward ledgers, LP-valued claim caches and unwind scratch state, Open-mode storage, expansion caps, obsolete mature-close output routing, and placeholders retained solely for historical storage compatibility. The currently unused `lastSelfBalance` member in the common claim-token repository is an explicit example to remove from the new layout.

The owner explicitly approved the obsolete V4 mature-close cleanup. The current repository dependency review also proves that the old common `DETFNFTVault{Target,Common,Repo,Service}` implementation and its LP lifecycle/compound helpers have no product consumer; the prior compatibility label was incorrect. Remove this dead cluster and its 17-member legacy storage layout under the same authorized A30 cleanup. Preserve the actual funded bond implementation and legacy interfaces still referenced by excluded Balancer DETFs. `obsolete-common-ledger-cleanup-prepared.json` records the reviewed import boundary and test dispositions; its application and validation status must be reported accurately.

Preserve the state actually required for protocol-owned LP custody, ordinary stake shares/index/backing, fixed bond principal and vesting, standing fee/creator weights and beneficiaries, route configuration, initialization and transfer/settlement safety. A field's LP-related name does not make it unused while protocol custody still depends on it. Replace obsolete user-bond reward accounting without deleting the distinct standing fee entitlements.

Use lean layouts for the new immutable deployments; do not keep dead members as historical padding or introduce an upgrade/migration mechanism to justify their existence. All facets, repositories, initialization structs and readers/writers must agree on the revised layout. Respect storage namespaces and shared-library users outside this refactor: a member still needed by another supported product is not globally unused. The reviewed field inventory and final layout must make the cleanup concrete before implementation.

#### 24.11.3 Redesign the bond NFT SVG and JSON metadata

The current common renderer shows a generic `PROTOCOL BOND` title, an unlock countdown, raw effective shares and old pending rewards. Replace that information hierarchy with the actual purchased-principal and staking position. Keep the existing product visual identity as the starting point, with clear typography, a vesting progress indicator and separate principal/reward amounts. The image must remain readable as a wallet or marketplace thumbnail and at full size.

For a purchased bond, the image and matching JSON traits must communicate:

| Display | Required meaning |
|---------|------------------|
| Bond identity | Actual DETF display name/symbol and NFT id; use `DETF Bond`, not a deployment-package name or `Protocol Bond` for every instance |
| Purchased principal | Fixed original net DETF allocation `P0`, labeled in DETF |
| Vesting | Linear progress from `t0` through `t0 + T`, with time remaining while vesting and a `Fully vested` status at maturity; claiming rewards does not change progress |
| Remaining principal | `P0 - C` in DETF, including vested-but-unclaimed principal |
| Claimable principal | The currently vested, unclaimed principal, labeled as payable in sDETF |
| Claimable rewards | Already distributed staking yield attributable to the NFT, separately labeled in sDETF and claimable during vesting |
| Total claimable | Claimable principal plus claimable rewards, labeled in sDETF |

Use the same funded accounting identities as §24.5, with time-based vesting evaluated at the metadata read. Do not include pending unminted expansion in the displayed reward balance. Immediate seigniorage distributions and completed expansion distributions both affect displayed claimable rewards. Format the nine-decimal amounts as readable token quantities rather than raw integers or internal shares/gons. Display rounding must not overstate what can be claimed; JSON traits must preserve the precise native-unit amounts where needed.

For the existing 100-DETF principal / 110-sDETF value example halfway through vesting, show 50% vested, 100 DETF remaining principal, 50 sDETF claimable principal, 10 sDETF claimable rewards and 60 sDETF total claimable. After the combined claim at the same timestamp, remaining principal is 50 DETF and both claimable amounts are zero. After a reward-only claim, remaining principal stays 100 DETF and claimable principal stays 50 sDETF.

Do not present reserve LP, `originalShares`, boosted `effectiveShares` or an all-or-nothing maturity countdown as the purchaser's entitlement. Do not imply a fixed future reward rate or that market value only rises. Plain labels such as `Purchased`, `Vested`, `Remaining principal`, `Claimable principal` and `Claimable rewards` are preferred over internal accounting terms.

If standing protocol/fee/creator NFT ids remain, give them role-specific metadata instead of a fabricated purchase or vesting schedule. Their continuing entitlement pays funded sDETF under D40; wallet-held fee receipts are not principal escrowed in that NFT. Internal protocol-custody metadata must likewise not advertise redeemable user LP principal.

Keep SVG and JSON generated from the same state, escape token names and other text correctly, and render without external scripts, fonts or images. Prepare representative new, partially vested, partially claimed and fully vested bond visuals, plus retained standing-role visuals, for review before the renderer is implemented. Update the metadata description and traits alongside the SVG so wallets and marketplaces do not retain the old reward model. The owner subsequently authorized executing the implementation plan, including this renderer and its required validation.

---

## 12. Non-goals (until explicitly unlocked)

- Implementing any topic before it is locked in §0 and listed in the impl plan.
- Converting DualLiquidity into a true DETF.
- Changing compound / expansion parameters beyond an explicit decision here. D37/D38 change reward destination and vesting-stake participation, not an unreviewed expansion-rate rewrite.
- Production deployment, migration, modifying existing deployed positions, or changing another agent’s task. Execution of the refactor itself has been authorized.
- The former separate decision on obsolete V4 bond/close code is resolved by the owner's explicit cleanup approval. It is authorized implementation work, subject to preserving funded claims and the D60/D66 scope boundaries.

---

## 13. How this file grows

1. Discuss one topic.
2. Write the decision into §0 with an ID and date.
3. Expand the matching section with normative text.
4. Only then open an implementation-and-test plan.

For the historical implementation, §9.2 (bond free `U`) used launch default L1 and D25/D15/D29/D30/D31 overrode earlier rows dated before 2026-08-22. For the **new refactor**, D32–D66 and §24 take precedence; neither L1 nor historical Stages **I–O** supplies missing decisions for the new bond/staking model. The new implementation plan has been written with explicit authorization. The owner subsequently authorized executing it; implementation continues in the main repository.
