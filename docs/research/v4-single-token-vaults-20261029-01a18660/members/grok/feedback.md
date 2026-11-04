I read this as the one advisory on frozen v4-vault-comparison-r1. The complete advisory is below. I'll stop when this message ends; no file was written.

## Identity

Independent Grok council member, one advisory pass, access date 2026-10-29. `apply_patch` is not active. A catalog search returned no file-write patch tool. This message is the complete advisory. No substitute file was written. Peer feedback was not read. No shell, Git, tests, builds, installs, deploys, or external messages were used.

## Draft under review

`docs/research/v4-single-token-vaults-20261029-01a18660/coordinator/draft.md`, revision **v4-vault-comparison-r1**, 2026-10-29. Read in full, with the three other originals and my preserved original.

## Disposition

**SUPPORT WITH CORRECTIONS**

The draft is the right comparison. It does not count seven production matches. It keeps lpTOKEN's full-spend revert, Weir's possible residual token, The Pool's adapter-conditional fixed-asset exit, ALPS's skipped V4 conversion, USDa's automatic two-token fallback, Unoxi's refusal/refund, and ZapVault's per-user custody on separate axes. Those qualifications are supported by the admitted originals. The corrections below are sentence-level. They do not drop or add a family, and they do not reverse a qualification.

Seven families are a fair comparison only as qualified mechanisms. They would be an unfair count of working products. The draft's second sentence already says that. The first sentence can still be quoted alone.

## Concerns

1. **The opening sentence is detachable.** "Seven independent implementations are useful comparisons" can be copied without the next sentence. Replace the opening with: "Seven comparison families are useful, not seven production matches and not seven equally verified both-direction vaults: lpTOKEN, Weir, The Pool, ALPS, USDa/Ascnt, Unoxi, and ZapVault." Keep the existing next sentences. The "five pooled-share / six shared-capital / one per-user" arithmetic is consistent and should stay.

2. **The Weir table cell is stronger than the evidence if read alone.** "Verified-source native mechanism" is a verified manager, not a verified funded vault. Astra's original supports the residual-output reading. MiniMax verified the ABI only. Kimi and my original had docs only. Proposed cell: "Verified manager source on Robinhood 4663. Either leg is intended; a partial fill can leave the second leg, so there is no all-or-revert one-output postcondition. The UI showed zero vaults. That page is not an RPC proof that no instance exists, and no funded vault was established."

3. **The PoolManager fee sentence is right for the hookless path and slightly absolute.** On 2026-10-29 I fetched the draft's P19, `https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol`. Observed: `modifyLiquidity` sets `callerDelta = principalDelta + feesAccrued` under the comment that fee and principal deltas are both accrued to the caller, then `afterModifyLiquidity` may replace `callerDelta`, and the post-hook value is what gets settled. Proposed replacement: "Ignoring `feesAccrued` is not evidence that fees were dropped on the canonical hookless path: `PoolManager.modifyLiquidity` folds fees into `callerDelta` and settles the post-hook delta. A hook can rewrite that delta. ZapVault's published pool is hookless, so the unread second return does not by itself show lost fees. This is a reading of mutable `main` on 2026-10-29, not an executed withdrawal, and it does not prove clean per-user residual attribution."

4. **`PinnedReference` is real, and the draft's sentence is too weak and poorly located.** Kimi's original names `IReferencePrice`, not `PinnedReference`. The name is not in P15 or P16. It is in the cited repo. Observed this pass: `contracts/reference/PinnedReference.sol` returns the description "PINNED - operator-posted, not a market price"; `scripts/deploy.ts` deploys that contract and passes it as `priceSource`; `deployments/sepolia.json` records `priceSource` `0x80ca3451f4fc3116367aa6485a5d76078d537c70` without naming the contract. `UniswapV3TwapReference` is in the same tree and is not what the script deploys. Proposed replacement: "Exit rounds take an `IReferencePrice`. The published Sepolia deploy script deploys `PinnedReference`, an operator-posted implementation whose own description says it is not a market price. The manifest records a `priceSource` address; that address was not independently proved to be `PinnedReference` or still the live source."

5. **ZapVault's rebalance-threshold sentence is not agreed by the originals.** Kimi says `rebalance` does not check `needsRebalance` or the configured threshold. MiniMax says the same function is permissionless but bounded by the user's config. I did not re-read P18. Keep "permissionless rebalance." Do not state that the threshold is unenforced as if both source reads agree.

6. **Conclusion 4 stops short of the price-source split the question needs.** Add: "ZapVault centers the range on a Chainlink feed and sells the unwanted leg in the same pool. The feed is not an exit-price oracle. Unoxi's published deploy script uses an operator-posted pin, not a pool TWAP. A TWAP of the vault's own pool is not an independent reference when that pool is the only liquidity."

7. **The exclusion row "ICHI / Charm / Beefy / Topaz" mixes unlike evidence.** Split it. Beefy: the inspected CLM page, last updated August 2024, does not name Uniswap V4; its zap pattern is not V4 evidence. Topaz: the single-token zap docs are Slipstream, not Uniswap V4. ICHI and Charm: single-asset or one-click patterns whose inspected paths do not establish V4. Do not let that row imply every named product was shown to be another AMM.

8. **"Publisher manifests for Base/Robinhood/Arc" overstates the receipt-level read.** Astra read the Base manifest, including a router source commit distinct from repository main, and identified the Robinhood and Arc manifest files. The other originals cite README addresses. Proposed sentence: "The Base manifest was read with receipts. Robinhood and Arc manifests are in the repo and cited by the README; they were not given the same receipt-level read. Current main is not assumed equal to any deployment."

These are not concerns, and should not be reopened: Weir's residual second leg, ALPS's zero-TWAP skip, USDa's `_payDualToken` fallback that bypasses aggregate `minOut`, The Pool's verified zap methods with an unverified adapter, OpenZaps as documented LP routes whose Hookr API was unconfigured rather than as proof of a live vault, and Bunni as a historical share architecture whose public tree still warns that exploit issues are unrepaired. September 4, 2025 pause status is not October 2026 status. Gamma should stay a near match with a V3-labeled negative guide, not a universal exclusion.

## Overlooked candidates from my original

None is a missing both-direction match. Omitting them does not make the seven unfair.

- **EulerSwap.** Official README: pools do not hold reserves; output is borrowed just in time. A stricter negative control than Twofold. Worth one exclusion row.
- **VII yield-harvesting hook.** The ERC-4626 is the pool asset. Interest is donated into a V4 pool. Not a vault of a held LP position.
- **Beefy CLM**, as the specific non-V4 case in concern 7, not as a new match.

Twofold, Bunni, Gamma, Arrakis Pro, Revert v4lend, Prism, Kerf, Blackhole, Grimoire, and OpenZaps are already in the draft. I do not ask for them to be reclassified.

## What was not adopted from peers

From MiniMax: confirmed-match labels for Weir, ZapVault, ALPS, and USDa. The docs sentence that Weir "swaps half," against Astra's excess-value source reading, which the draft correctly uses. I do not maintain my own earlier docs-only raw-half inference against that source reading, and I did not re-read `WeirVaults.sol` this pass. The claim that Weir is the only native both-directions vault. The Pool has native zap methods, conditional on an unverified adapter. The preference for native conversion over a separated zap. Weir's native path can leave a residual token; lpTOKEN's router reverts on a partial fill. "Withdrawals work while paused" as exit liveness. A Gamma hard exclusion from guides that include V3 examples. OpenZaps as swap-only infrastructure. Bunni as not a share vault. Kyber as a conditional match inside the seven. Grapl as a vault. MoleSwap as a match. A peg clamp as a general manipulation defense.

From Kimi: lpTOKEN, Weir, and ZapVault as the straightforward group. Weir as docs-confirmed without the residual caveat. ZapVault as a confirmed match. OpenZaps as only generic execution infrastructure. An Unoxi reference left only as `IReferencePrice` when the published script names `PinnedReference`. Kyber was not re-fetched by me. I do not object to its near-match row, and I do not adopt it as my own observation.

From Astra: omission of ALPS, Unoxi, and ZapVault is not a reason to drop them. Issuer ownership is not, by itself, a complete Arrakis exclusion, and Arrakis Pro is still not a match. I do not restore my homepage-only OpenZaps exclusion over Astra's docs-plus-unconfigured-API reading.

## Limits

Claims accepted from admitted originals, not re-fetched this pass: Weir's residual settlement, ALPS's zero TWAP and skipped unwind, USDa's dual-token fallback, and The Pool's Sourcify match with an unread current adapter. If those originals are wrong, this advisory does not catch it.

Fresh fetches this pass, all 2026-10-29: P19 `PoolManager.sol`; the Unoxi `main` tree; `UnoxiExitRounds.sol`; `PinnedReference.sol`; `deployments/sepolia.json`; `scripts/deploy.ts`. GitHub code search required sign-in and was not used. P19 is mutable `main`, not a pinned commit. No RPC, bytecode match, executed deposit, or audit was performed. The Unoxi `priceSource` address was not proved to be the deployed `PinnedReference`.

This advisory does not replace `docs/research/v4-single-token-vaults-20261029-01a18660/members/grok/response.md`. It does not authorize implementation. No further round is requested.
