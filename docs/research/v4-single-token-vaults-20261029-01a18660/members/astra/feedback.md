# Astra advisory on v4-vault-comparison-r1

## Identity and draft under review

- Independent Astra council member; the original research remains preserved.
- Reviewed revision: **v4-vault-comparison-r1**, dated 2026-10-29.
- Frozen draft: `docs/research/v4-single-token-vaults-20261029-01a18660/coordinator/draft.md`.
- Read the complete draft and complete originals at `members/grok/response.md`, `members/minimax/response.md`, and `members/kimi/response.md`. MiniMax's first read was truncated; its remaining lines 265-342 were read separately.
- No peer feedback, coordinator source-notes, resolution, or final report was read.
- This is the one requested advisory. It neither replaces my original nor authorizes implementation.

## Disposition: SUPPORT WITH CORRECTIONS

The draft is a substantially fair comparison of **seven useful architectural families, not seven established production matches**. Its separation of periphery, integrated conversion, conditional cash settlement, automatic in-kind fallback, asynchronous settlement, and per-user custody is sound. Keeping six shared-capital designs and one explicitly adjacent per-user design is defensible under the original broad vault question.

Before final publication, correct two output-semantics omissions: ZapVault can retain unconverted ETH while deleting the user's position, and Unoxi's exit-round payout uses confidential wrappers rather than directly delivering the plain pool token. Also qualify ALPS's in-kind escape more precisely and restore compact deployment evidence in the aggregate report. These are bounded corrections; I do not request another research or advisory round.

## Substantive concerns and proposed corrections

### A1. High: ZapVault's USDC-only payment is not proof of complete asset consolidation

**Draft locations:** qualification-table ZapVault row; “ZapVault: fixed-USDC per-user custody”; comparison conclusion 2.

**Observed:** In `ZapVault.sol`, `_executeWithdraw` attempts an ETH sale, then takes any positive remaining `netEth` into the vault at lines 326-330. It sends only positive USDC to the user and deletes the position/config at lines 333-342. No full-spend assertion or per-user residual claim appears in this path. [A-S1]

**Inference:** A partial fill can leave economically attributable ETH in contract custody without a surviving position record. This is more consequential than generic “residual accounting” or poor execution pricing.

**Proposed replacement:**

> Withdrawal attempts USDC consolidation, but does not enforce complete ETH consumption. Positive residual ETH is retained by the vault while the user's position is deleted. Classify it as a prototype USDC-payment path, not a complete-value single-token redemption guarantee.

Add this failure mode to conclusion 2. Keep the family as a comparison, but do not rank its exit guarantee alongside lpTOKEN's full-spend-or-revert path. This is source reasoning, not a reproduced transaction.

### A2. Medium: Unoxi's requested denomination is paid as a confidential wrapper

**Draft locations:** qualification-table Unoxi output column; Unoxi profile.

**Observed:** `UnoxiExitRounds._deliver` wraps the underlying proceeds into `cToken0`/`cToken1`; `_payoutToken` selects one of those ERC-7984 wrappers. The constructor binds the vault and these wrappers. The user-facing settlement denomination therefore needs another distinction beyond “requested leg.” [A-S2]

**Proposed insertion:**

> Exit-round claims are denominated in the selected confidential wrapper, cToken0 or cToken1. This is exposure to one requested pool currency, not direct delivery of its plain ERC-20 form; the wrapper's unwrap/redemption workflow is a separate dependency and was not verified here.

Change the output-table cell to “Selected confidential currency wrapper after asynchronous settlement; refusal can refund shares.”

This does not disqualify Unoxi as a useful asynchronous comparison. It prevents readers from assuming the same wallet output or transaction count as lpTOKEN and The Pool.

### A3. Medium: ALPS's escape hatch and fee/control surface need explicit limits

**Draft locations:** ALPS profile, especially “the separately invoked in-kind route is the escape”; comparison conclusion 2.

`redeemInKind` lacks the pause modifier, but skips orphaned pools, catches failed removals, and burns the requested shares subject to caller-supplied payout minima. It is not unconditional recovery of every position. Its fee is also omitted: `entryExitFeeBps` is owner-settable, capped at 200 bps, with the in-kind path applying it too. Guardian orphaning affects valuation/distribution. [A-S3]

**Proposed insertion:**

> In-kind redemption remains callable while paused, but can omit orphaned or unsuccessfully removed positions; caller-selected token minima determine whether that incomplete payout reverts. It is not a guaranteed full-portfolio recovery route. The owner can set an entry/exit fee up to 2%, including on in-kind redemption; the current deployed setting was not checked.

Retain the existing zero-TWAP qualification. The actual adapter returns zero, and the vault's `lo == 0` guard skips automatic V4 conversion; stale comments claiming a spot fallback do not override those bodies. [A-S3, A-S4]

### A4. Medium: Aggregate deployment evidence should name the addresses and their roles

**Draft locations:** qualification table; source registry; final evidence-gap paragraph.

The draft accurately distinguishes verifier records from funded deployments, but it sends readers to the member originals for most address/chain evidence. The common brief specifically asks for deployed addresses and chains. A compact table would make the final comparison independently useful without implying additional verification.

**Proposed addition, using already-admitted original evidence:**

| Family | Minimum deployment locator to retain | Evidence status to print |
|---|---|---|
| lpTOKEN | Base 8453 factory `0x3384eD0d272dE35bF6DC516E1eA7d188CEb51793`; implementation `0x78aae2fD8f8b09994d0e936Ce4478a7EB8FE92D9`; zap `0xc4C8071D651F093C4A5c2C06e7BFfc163A057DdA` | Publisher manifest; these are infrastructure addresses, not a verified funded vault clone. Main/deployment versions were not fully reconciled. |
| Weir | Robinhood 4663 shared vault manager `0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110` | Sourcify source/bytecode match; no populated PoolId independently established. |
| The Pool | Arbitrum One 42161 vault `0xf79c2dc829cd3a2d8ceec353bdb1b2414ba1eee0` | Sourcify match; configured adapter, funding, and operation unverified. |
| ALPS | Base 8453 vault `0x3F0e6cef3a75f52F1E55806Afe40317f51199CaE`; V4 adapter `0xB6871C8cd995fF015DBa7373b371426E80cBBCF0` | Publisher addresses/transaction evidence; current source/deployment identity unverified. |
| USDa | Sepolia 11155111 vault `0x1638fcb8a56a19e8226e2d15c7b3c2cc2f3c6040` | Publisher testnet evidence only. |
| Unoxi | Sepolia 11155111 vault `0x0480Ae5a4f7d53e00e2C06cF3daA42F0894b5AdA`; exit rounds `0x2dd37c8bf3747574627e264d6b2cb0fd421742f5` | Publisher testnet manifest/lifecycle evidence; not independently replayed. |
| ZapVault | Base 8453 vault `0xc77d3CCFba9354db99972D11d994676d55709d5C`; router `0x3F75D8E28A148380B186AcedcDE476F8E1CFDd78` | Publisher prototype addresses; bytecode and operation unverified. |

Evidence: my preserved original's deployment sections; Kimi's ALPS, Unoxi, and ZapVault sections; MiniMax's corresponding sections; Unoxi's cited manifest, re-opened for this advisory [A-S6]. This is an editorial consolidation of existing evidence, not a new deployment attestation.

### A5. Low: Tighten the status vocabulary for the seven-family comparison

The opening already rejects “seven equally established production matches.” Preserve that qualification wherever the table is excerpted.

**Suggested caption:**

> Seven independent study designs: source-backed mechanisms with differing output guarantees and maturity. Inclusion is not certification of a complete-value one-token exit, a funded deployment, or current usability.

A short note can group lpTOKEN, Weir, and The Pool as the most directly relevant mechanisms; ALPS, USDa, and Unoxi as materially conditional comparators; and ZapVault as the per-user prototype counterexample. That is a fair comparison, not an attempt to meet a numerical quota with seven equivalent matches.

## Resolved evidence I support retaining

| Topic | Advisory assessment |
|---|---|
| Canonical PoolManager fee return | Correct. `modifyLiquidity` forms `callerDelta = principalDelta + feesAccrued` before hook adjustment. Ignoring the second return alone does not prove lost fees. Keep the qualification about actual downstream settlement. [A-S5] |
| Weir unwanted-token residual | Correct and important. My original inspected the verified main source and base settlement helper. The draft properly rejects an unconditional one-output guarantee. |
| Weir half-swap criticism | Correctly narrowed. The verified `_balance` compares values using the pool sqrt price; a criticism based merely on different raw token decimals is unsupported. |
| ALPS zero TWAP | Confirmed in the cited adapter and unwind logic. The draft gives the implementation precedence over stale comments. [A-S3, A-S4] |
| USDa fallback | Correct. The custom exit's automatic two-token fallback and bypass of aggregate one-token `minOut` must remain explicit. |
| The Pool | Correct. My original recovered actual verified source and LP helper, not just ABI. Current adapter/venue and operational state are still unverified. |
| Unoxi PinnedReference | Supported at the published-example level: the README names `PinnedReference`, and the manifest gives the same price-source address. Do not promote that to a live independent market-price feed or infer its precise update authority from its name. [A-S6, A-S7] |
| Weir page showing zero vaults | Correctly treated as a page observation rather than authoritative RPC proof that no funded PoolId exists. |
| Bunni | Correct distinction between a real share/custom-accounting design, unrepaired public source, and dated incident status. “Exploited” does not mean it never had shares. |
| Arrakis | Correct to distinguish historical public shares from present issuer NFT ownership without making NFT ownership alone an exclusion. |
| OpenZaps | Correctly narrowed to documented LP architecture plus unavailable source/configuration evidence; not globally reduced to swap-only infrastructure. |

## Overlooked candidates from my original

**No candidate from my original needs promotion into the seven-family shortlist.** The draft retains my three strongest mechanisms, USDa, and the useful near matches: Twofold, OpenZaps, Arrakis, Bunni, PRISM, Blackhole, Kerf/Levee, Grimoire, and Steer/EARN.

Two preservation points matter:

1. Keep **Twofold** prominent as the negative control: its `zapOut` pays both currencies. Its omission from the numbered seven is justified by the exit criterion, not by a claim that JIT liquidity cannot earn swap fees.
2. Keep **OpenZaps** as unresolved documented LP infrastructure. The unconfigured Hookr endpoint is scoped evidence, not proof every lineage lacks a vault.

My unresolved ICHI/Charm/Krystal/Aperture/Mellow/Decay leads do not justify new broad searches or added matches in this advisory. Their absence from the shortlist is an evidence limit, not a finding of protocol-wide incompatibility.

## What I did not adopt from peers

### Grok

- I did not adopt the conclusion that only lpTOKEN has code-backed directions: my original supplies verified-source Weir and The Pool, and the other originals add useful conditional designs.
- I did not adopt an arbitrary-third-token or standing-position-only requirement beyond the brief. Either-pool-token settlement and transient JIT architecture are legitimate comparison axes, although Twofold still fails single-token exit.
- I did not adopt the raw-half/decimal objection to Weir without its implementation.
- I did not adopt categorical exclusions of issuer-owned Arrakis vaults or OpenZaps LP architecture.
- I did not adopt the assertion that a same-pool TWAP necessarily fails merely because it is the only liquidity source. That premise alone does not establish failure; manipulation cost, window, and execution rules would need evidence.

### MiniMax

- I did not adopt the unconditional native-match labels for ALPS and USDa, or treat Weir ABI shape as sufficient proof of runtime output behavior.
- I did not adopt uncertainty about ZapVault fees solely from the ignored second return: canonical caller-delta semantics resolve that specific point.
- I did not adopt “Bunni is not a share vault,” “PRISM has no contracts,” or “OpenZaps is swaps only.” The admitted source evidence contradicts those categorical statements.
- I did not adopt universal recommendations for native conversion, peg clamps, or external conversion markets. These are tradeoffs and depend on available liquidity, not generally superior defaults.
- I did not adopt a claim that lpTOKEN's complete redeem-and-swap occurs in one unlock. Transactional atomicity does not imply one PoolManager unlock across the separate vault and router operations.
- I did not treat hooked intermediate-route rejection as rejection of every hooked target vault. Route pools and the target vault pool are distinct validation questions.

### Kimi

- I adopted the conditional ALPS/USDa/Unoxi distinctions and useful per-user ZapVault comparison.
- I did not adopt Weir's docs-level native-exit label without the verified-source residual caveat.
- I did not turn Unoxi's external reference interface into proof of a production oracle.
- I did not adopt unrestricted “USDC-only withdrawal” as a full-value guarantee for ZapVault; A1 identifies the missing postcondition.
- I did not adopt PRISM's M0 label as proof its current tree has no implemented liquidity calls, or any project's published test output as independently executed validation.

These are dispositions of claims, not votes against researchers. The draft generally already resolves these disagreements correctly.

## Narrow primary-source checks in this advisory

Access date: **2026-10-29**. No new broad search queries were run. Only cited project/primary-source locations were consulted to resolve fee, residual, wrapper, ALPS exit, and reference/deployment questions.

| ID | Source and inspected locator |
|---|---|
| A-S1 | https://raw.githubusercontent.com/joaoolucas/zapvault/main/contracts/src/ZapVault.sol — `_executeWithdraw`, `_modifyLiquidity`, `withdraw`, `rescue`; numbered source lines 65-104 and 302-363. |
| A-S2 | https://raw.githubusercontent.com/skar8848/unoxi/main/contracts/UnoxiExitRounds.sol — complete short contract; especially `_deliver` and `_payoutToken`, lines 79-94. |
| A-S3 | https://raw.githubusercontent.com/yanisepfl/alps/main/contracts/src/ALPVault.sol — fee fields/setter, `redeemInKind`, and `_unwindForWithdraw`; selected sections, not a whole-contract audit. |
| A-S4 | https://raw.githubusercontent.com/yanisepfl/alps/main/contracts/src/adapters/UniV4Adapter.sol — `getTwapSqrtPriceX96`, lines 319-329. |
| A-S5 | https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol — `modifyLiquidity`, lines 135-170, and unlock delta settlement. |
| A-S6 | https://raw.githubusercontent.com/skar8848/unoxi/main/deployments/sepolia.json — complete manifest; addresses and price-source identifier. |
| A-S7 | https://raw.githubusercontent.com/skar8848/unoxi/main/README.md — deployment/reference table and lifecycle claims. |

One attempted direct `https://raw.githubusercontent.com/skar8848/unoxi/main/contracts/PinnedReference.sol` fetch returned 404. I did not infer that implementation's behavior or conduct a repository-wide search to replace it. The published reference-name/address claim above is supported by A-S6/A-S7, not by that failed read.

## Limits and final disposition

- Draft and all three peer originals were read completely; no peer feedback was read.
- Narrow source checks used provider web retrieval, not shell, Git, tests, builds, installation, deployment, RPC, or wallet operations.
- Mutable public `main` source is not independently reconciled to each deployed contract. No full code audit, economic proof, or transaction reproduction was performed.
- The Weir, The Pool, USDa, lpTOKEN, and OpenZaps assessments also use my preserved original and retained source observations; they were not all re-fetched in this pass.
- Source matches, published receipts, current liquidity, route availability, and audit coverage remain separate evidence levels.
- Only this assigned `feedback.md` was written, using `apply_patch`. The frozen draft and originals remain unchanged.

**SUPPORT WITH CORRECTIONS.** Resolve A1-A4 in the coordinator's final report; A5 is a concise presentation improvement. No additional advisory round is requested. This advisory neither replaces my original nor authorizes implementation.
