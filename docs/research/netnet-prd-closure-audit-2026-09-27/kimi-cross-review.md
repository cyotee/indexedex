# Kimi K3 — Closure-audit CROSS-REVIEW (Astra / Grok / MiniMax M3)

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 |
| Basis | Full reads of the three originals (untrusted evidence); my unchanged original; moderator's challenge list treated as the review rubric. |

## 1. Broad agreement (four-way)

The tracker is an engineering/evidence register, not twenty owner questions; no demonstrated source incompatibility exists; missing code ≠ missing PRD; dispositions converge on A/S/P/E/M classes with no genuine blockers beyond evidence gates. All agree: NN-03 stays closed (v0.27 failure scope — no hostile-balance-survival requirement reintroduced, including into NN-19 acceptance); NN-13 is separate maintenance; Sourcify exact_match is verification-service evidence, not a current-runtime check.

## 2. Corrections to my original (moderator-directed)

- **C1 (NN-12 — I overclaimed):** I wrote that the NN-12 reference "exists in code" as `RebasingDETFTokenRepo.sol:151–166`. Per the moderator's challenge: that component is a **cached/extractable-rate receipt** model (`_cachedRedemptionRate`, `_lastRateUpdateBlock`, ERC-4626-shaped surface, owner setters) — not the mandatory **live `DETF.balanceOf`-driven B/U** semantics of §10.2 (fundedBalance recomputed from current custody, no cached rate). Exact-semantics proof is absent, so it must not be named the intended reference. Correct disposition (Astra/Grok): the B/U model is settled **by §10.2 itself**; the intended normative reference document was **not located** (`docs/plans/detf/` empty/nonexistent — no files found either way); restate the adopted recipient/zero-share/top-up formulas in the normative spec with provenance (standing-weight algebra source: `DETFSeigniorageShareLib` per Astra; funded-staking plan §4.4 :198–218 per my earlier read). The RebasingDETFToken component may serve only as a *structural* share-scaling reference, with its cached-rate semantics explicitly not imported. I do not claim the missing doc was found.
- **C2 (NN-08 bootstrap):** my "partial-book first mint exists" note must carry the moderator's guard: bootstrap funds **all four legs including a real SY seed** (direct SY capital is allowed — Astra, `UniswapV4DetfTarget.sol:629–668` peer-cited), and the partial helper must **not** be used to bypass the full-book liveness requirement (`...HookTarget.sol:371–373`).
- **C3 (NN-09 reference):** I pointed at the truncated-tick TWAP library as the structural reference. Astra's is better and correct: the **arithmetic price×time cumulative pattern** exists in the V2 stub (`UniV2Pair.sol:215–224`, peer-cited) plus NetNet's `PairOracle.sol:118–130` counterfactual extension — matching the selected arithmetic series; the V4 tick library integrates truncated ticks (wrong content model). No invented ring-size bound (e.g., 3601) and no unsampled-history replay: external valuation changes are sampled at checkpoints; nobody may claim reconstruction of an unobserved continuous trajectory (Astra :77).

## 3. Peer claims specifically rejected

- **R1 (MiniMax NN-12, the round's worst error):** he names **`StakedNET.sol`** as the balance-derived reference and pastes §10.2's `fundedBalance = floor(B·internalShares/U)` as if it were that file's code. StakedNET is upstream sNET — the **gons** model (`gonsPerFragment`, `balanceOf = gons/gonsPerFragment`, per mechanism docs §6 and his own quoted lines) — demonstrably different from B/U, and it is the *upstream* token, not the custom sNET-DETF. Rejected wholesale; Grok ("do not substitute gons/K") and Astra ("current gons code is demonstrably different") are correct.
- **R2 (MiniMax NN-10):** "Pendle NetNet SY is not yet implemented; a custom PendleNetNetSY must be built." Wrong on evidence: SY-sNET `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5` is deployed and used by two series (API attestation, my addresses round). The vendor tree lacking it is irrelevant — it is a configured **external** SY; the deliverable is the **reusable rate provider** (distinct component), not a new SY. His "placeholder" citation (`ExitQueryTarget.sol:144–145`) is the hook's own SY-compat shim, unrelated.
- **R3 (MiniMax NN-02):** "noteId ≠ 0 guaranteed by length-based index (:130)" — false: `noteId = notes[to].length` returns the pre-append length; a preloaded note occupies 0 and the intended purchase takes whatever index exists. Registration = the **returned** value (§12.4 already says this).
- **R4 (MiniMax NN-16):** "TaxCollector.sol is the NetNet-specific tax executor" confuses NetNet's upstream fee collector with the custom SE's per-hop tax modeling (R06: the SE owns tax; the hook consumes net quotes). Also his NN-01 row conflates the Pendle `4663-core.json` (repo file) with the Sourcify exact_match record (depository) — different artifacts.
- **R5 (Grok NN-06 inner joins):** "unused excess donates to remaining HLP (V2 leftover)" — under the moderator's no-unpriced-donation rule and §7.1.1, blindly importing `pair.mint`'s unequal-contribution donation is forbidden (Astra's formulation governs: match accepted ratios, explicitly refund/account residuals). Note the stronger point: the specified API feeds the inner reserve only via Keep-YT market-ratio acquisitions — direct unequal inner joins are **not reachable under the specified API** (tracker :31 category); the spec should say so rather than rely on the V2 default.

## 4. Adopted peer-derived mappings (peer-cited lines marked)

- **Outer HLP full BasePoolMath map (Astra):** proportional add `ceil` (:50–70), proportional exit floor (:87–107), unbalanced add (:126–205 — I verified :126–200), single-token exact-BPT-out (:224–263), exact-asset-out (:277–342 — verified by me), exact-BPT-in exit (:359–397); `Vault.sol` dispatch/rounding (:604–647, 679–726, 853–965). Don't copy `balance−1` corrections without scaled caller context.
- **Exact-output (Astra):** `WeightedMath.sol:199–234` upward exact-out input solves the **Weighted layer only** — it is not proof of the composed nonlinear SY/position-conversion inverse; incentivized-burn inversion `ceil(qQuoteRequired·WAD/(WAD+p))` then verify the forward quote. Adopted; this scopes my/Grok's looser "invert the quote."
- **Pendle entry/exit calls (Astra):** `ActionAddRemoveLiqV3.sol:236–303` (Keep-YT add variants with minLpOut/minYtOut), `ActionMiscV3.sol:129–188` (pre-expiry exit, netPtIn=0), :208–240 (post-expiry); claims `PendleYieldToken.sol:166–193,373–404`, `InterestManagerYT.sol:43–57,63–79` (:43–57 verified by me).
- **SE binding predicate (merge Astra+MiniMax):** `asset() == canonicalPair` (`ERC4626Target.sol:100–102`, DFPkg :576–601) **plus** token identities + factory + trusted package/registry provenance + directional capabilities; empty-but-correct SE allowed; seven transition/quote selector classes (`QueryFacet.sol:20–28`, `UniswapV2StandardExchangeOutTarget.sol:57–113`).

## 5. Itemwise final status (post-correction)

Unchanged from my table except: **NN-12** = "B/U settled by §10.2; reference document not found; restate formulas with provenance; structural share-scaling reference optional" (plan/editorial, not evidence); **NN-08** = add the SY-seed/full-book guard (C2); **NN-09** = V2-styled arithmetic cumulative pattern reference (C3), no tick model, no ring bound, no replay claim; **NN-10** = rate-provider deliverable against the existing external SY, conversion-semantics verification pending (evidence); **NN-16** = binding predicate per §4 above; **NN-06** = inner join donation rule + not-reachable note (R5). All other rows stand as in my original (NN-01 evidence; NN-02 custody-answered/quantification-evidence; NN-03 closed; NN-04 conditional-on-terms; NN-05 resolved; NN-07 plan with scoped exact-out; NN-11 conditional-collision-only; NN-14 plan+evidence; NN-15 terminal edges; NN-17 plan; NN-18 evidence; NN-19 plan without reintroduced survival demands; NN-20 editorial).

## 6. No new owner questions

None of the corrections identify an irreducible product conflict; the only owner-visible remainders remain the previously recorded narrow ones (NN-01 live verification execution; NN-02/NN-18 quantified envelope; NN-04 conditional on actual terms; NN-11 conditional on a real collision; NN-13 maintenance). MiniMax's "true economic gaps" §3.1 is rejected (R2); his §3.2 (MAX_N=8) is a non-issue at four legs.

## 7. Limits

Peer-only citations flagged individually above; my verified set is unchanged. Astra's broken-glob note (LayerZero paths) matches my earlier environment observation. No execution; originals unchanged; no new round initiated.
