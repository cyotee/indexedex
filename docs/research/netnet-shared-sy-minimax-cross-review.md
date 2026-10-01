# MiniMax M3 — combined cross-review (preserves original)

Three peer originals read in full: Astra (61 lines), Grok (87), Kimi (50). My original (`…-minimax-original.md`) preserved.

## A. Direct-source verification

**Twin Repo same slot — verified.** `BasicVaultRepo.sol:20` and `MultiAssetBasicVaultRepo.sol:21` both declare `STORAGE_SLOT = keccak256(abi.encode("indexedex.vaults.basic"))`. Both are tagged `tag:BasicVaultRepo[]`. Their structs differ in field-name only: `vaultTokens` vs `_vaultTokens` and `reserveOfToken` vs `_reserveOfToken`. Because AddressSet and `mapping(address=>uint256)` occupy the same slot+0/slot+1 layout, the two libraries read/write the **same on-disk bytes**. The libraries are storage-equivalent; mixing them is safe for the data plane but bad for readability. **Kimi line 17 verified; Astra line 16 noted the equivalence but did not pin the slot.**

**BasicVaultRepo raw balance vs economic eligibility — verified.** Contract comments at lines 25–26, 91–97, 112–117 of `BasicVaultRepo.sol`: "only to be used for locally held token reserves, not for external accounting." `_updateReserve` is an absolute setter. **All three peers agree** the Repo holds a raw local balance snapshot only — no eligibility, provenance, fee payable, claimable, or non-cash classification. Net-claimable SY, retained-incentive SY, principal-exit SY, and fee payables must live in a separate accounting layer. **Engineering gate, not owner question.**

**PLP/YT external vs held ERC20 — verified by inference.** PLP and YT are ERC-20 tokens owned by the hook at the Pendle market; the hook holds them via Pendle market custody, not local balance. The sub-reserve is internal accounting of proportional ownership (analogous to a Uniswap-V2 LP). All three peers agree: BasicVaultRepo fits the hook's **directly held SY (and held USDG SE shares)** — not the PLP/YT sub-reserve. The sub-reserve's internal shares remain separate accounting.

**Force-claim pretransfer theft — Astra line 18.** `lib/crane/contracts/protocols/perps/pendle/core/YieldContracts/InterestManagerYT.sol:43–57,63–79` permits third-party claims that pay the hook. An unsolicited force-claim between quote and execution can leave `balanceOf(hook)` > stored reserve and be miscredited as a user's pretransfer deposit if the integration is imported unchanged. **Mitigation (engineering):** sync `balanceOf` → `_updateReserve` after every state-changing call before any pretransfer credit; treat the delta as protocol-received until proven otherwise. This is a known pattern across `BasicVaultCommon.sol:28–53,80–105` and the Weighted hook target at `UniswapV4StandardExchangeWeightedBufferHookTarget.sol:455–495`. **All three peers note this; my original EG3 covers it.**

**Wrapper approximation vs Balancer BasePoolMath — Astra line 44.** `UniswapV4StandardExchangeWeightedBufferHookMath.sol:472–498` approximates single-exact-output fee treatment by grossing up whole output; `BasePoolMath:277–339` (Balancer V3 vendored) computes taxable portion from invariant. Wrapper join `:323–330` subtracts one only for positive additions; `BasePoolMath:152–154` subtracts one across the array under its scaling contract. **Compatibility gap (source-verified).** This is engineering reconciliation, not an owner question. **Astra line 44 is correct; Grok/Kimi note invariant-ratio but not this fee-subtraction delta.**

**NET pricing balance unchanged when output debits SY — verified.** NET virtual = §7.1.2 PLP/YT joint zap-out valuation depends only on PLP/YT balances. When NET output debits SY (not PLP/YT), NET virtual is **mechanically unchanged**. sNET virtual = SY provider × eligible SY **does fall** by the debited amount. Therefore NET/sNET relative price moves without Pendle LP interaction. **Grok line 60 correctly states this; all three peers agree. Recomputation is therefore required for sNET and HLP-only quotes, but NOT for the NET virtual price** — a small but real distinction that affects preview/execution-parity proofs.

## B. Agreements across all four

1. **C09 answered, C10 answered.** sNET input = Keep-YT; HLP unbalanced = existing Balancer V3 Weighted unbalanced logic. **No reopen.**
2. **NET priced by PLP/YT zap-out; NET delivered from shared held SY.** Asymmetric pricing/funding. **Preserve.**
3. **No PLP/YT liquidation for ordinary NET output.** **Preserve.**
4. **Shared-SY funding sequence (held → claim if short → retain SY → forward non-SY to `feeTo()` non-blocking → redeem needed SY).** All four agree.
5. **BasicVaultRepo holds raw local balance only**; eligibility/provenance/payables are separate accounting.
6. **Force-claim pretransfer risk must be reconciled** before any pretransfer credit.
7. **Stale PRD v0.21 locations** for replacement are essentially the same set across all four: P:91, P:171, P:175, P:192, P:310, P:349, P:353, P:367, P:393, P:838, P:874, P:886. Consolidate into one edit list.
8. **TWAPs / `floor(S0*n/200)` / participation / fee-creator shares / non-blocking forwarding / minimal-input atomic rollover / custom-family approval / 1,000 NET opening / D61-R32 encapsulation** all preserved.

## C. Dissent / corrections

| # | Claim | Source | Verification |
|---|---|---|---|
| D1 | "wrapper approximations are source-compatible with BasePoolMath" (implicit in Grok/Kimi, not stated) | Astra line 44 | **Gap confirmed.** Wrapper single-exact-output `:472–498` and join `:323–330` differ from `BasePoolMath:152–154,277–339`. Engineering pin required. |
| D2 | "NET pricing balance need not change mechanically when output debits SY" | Grok line 60 / mine | **Correct, with one distinction.** NET virtual is unchanged (depends on PLP/YT only). sNET virtual falls (depends on SY). Preview/execution must read both. |
| D3 | Astra line 38 "Positive SY outflow to users remains an economic cost even when Pendle principal grows" | inference | Correct, but no peer dissent. |
| D4 | Kimi §3 "unbalanced = existing Weighted/BasePoolMath" but no fee-subtraction detail | Astra line 44 | **Astra adds detail Kimi missed.** |

## D. Recommended PRD reconciliation (consolidated edit list)

The four peers' edit lists are ~equivalent; consolidating:

**sNET-in (C09) — replace all open language:**
- P:20 ("remains explicitly unresolved"), P:91 ("awaits completion"), P:146 (R03 tail), P:180 (R37), P:230, P:310 (§5 row), P:320, P:348 (§6.1), P:476, P:479, P:576, P:837 (O-register). Replace with: "sNET input enters underlying Pendle liquidity via Keep-YT, as does NET input."

**C10 — replace all open language with existing Weighted unbalanced answer:**
- P:101, P:171, P:175, P:291, P:393, P:838. State invariant-ratio + taxable-excess per the existing `WeightedBufferHookMath` mirror; retained-leg coupon stays in the pool, not on the burner.

**NET funding override — replace PLP/YT-realization language:**
- P:51 ("NET output now realizes the separate PLP/YT leg"), P:91, P:103 (separate pricing coordinates / shared funding), P:192 (R49 "zap-out value and realization" → "zap-out valuation only"), P:349, P:353, P:367, P:874 (A27), P:814 (O09). Rewrite as: "NET priced by §7.1.2 zap-out valuation; NET delivered from shared held SY reserve under the owner's funding sequence; §7.1.2 realization remains only for NET valuation and HLP allocated position-exit math."

**Add new §7.3.x — shared-SY funding sequence:** held-SY first; if short claim pending interest/rewards; retain SY; forward non-SY rewards to dynamic `feeTo()` non-blocking; redeem needed SY to requested token; atomic revert on insufficient funding.

**BasicVaultRepo integration note (new §6.2):** SY token (and USDG SE-share) added via `_addVaultToken`; `_updateReserve(sy, balanceOf)` after every claim/swap/donation; PLP/YT external positions out-of-scope; force-claim reconciliation mandatory before pretransfer credit.

## E. Acceptance requirements (revised A-list)

- **A01 (conservation):** one SY debit schedule for NET-out, sNET-out, HLP SY-out, claims, force-claims, donations; no double credit of position-exit SY into the SY cash book; BasicVaultRepo `_reserveOfToken` updated exactly once per state-changing operation.
- **A02 (preview/execution):** NET amount from §7.1.2; delivery funded from `previewRedeem` of **eligible** SY; divergence is allowed (revert on minOut); force-claim must not create unbooked pretransfer credit.
- **A05 (force-claim safety):** mid-quote force-claims reconciled; protocol-received vs user-deposit attribution enforced.
- **A12 (economic scenarios):** zero-interest, partial accrual, low-eligible-SY, force-claim interleaving, fee-collision, recipient rotation, HLP exits interleaved with public swaps.
- **A18 (HLP proportional):** four-leg proportional with subshare→PLP/YT nested floors; direct SE-share payout (no unwrap); direct SY payout.
- **A27 (NET/sNET output):** both debit shared held SY under the owner's sequence; NET priced by PLP/YT valuation; sNET priced by SY provider; USDG redeems SE shares; no principal fallback.
- **A33 (Balancer wrapper compatibility):** reconcile wrapper fee-subtraction vs `BasePoolMath`; pin scaling context.
- **A39 (HLP join/exit):** direct DETF/SE-share/SY deposits; NET Keep-YT entry; unbalanced = existing Weighted math; no implicit SE zap; no NET/sNET/USDG-converted HLP output.
- **A46–A48 (new):** shared-SY funding under atomic failure isolation; BasicVaultRepo + balanceOf sync under callbacks; NET/sNET relative price shift without PLP/YT interaction.

## F. Genuine unanswered product decisions

**None.** C09, C10, raw DETF leg, USDG leg, asymmetric NET pricing/funding, and the funding sequence are all settled. The remaining C11 (sub-reserve lifecycle), C12 (SY provider denomination/provenance), B1 (finite SY funding vs virtual NET pricing availability spec), and Balancer wrapper-vs-BasePoolMath reconciliation are engineering specification/feasibility, not owner decisions.

## G. Tool availability and limits

Prompt asked for `apply_patch`; only `write`/`edit`/`read`/`glob`/`grep` available. Used `write` after reading directory listing. No shell, tests, deployment, signing, instruction edit, file deletion/move, browser, MCP, subagent delegation, or peer cross-review artifact read. No Context7 call this round (carrying prior verification). Originals preserved unchanged. Stopping here for the human moderator.
