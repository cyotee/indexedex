# Kimi K3 — Plan-completion CROSS-REVIEW (Astra / Grok / MiniMax M3)

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 |
| Basis | Full reads of the three originals (untrusted evidence); my unchanged original; moderator's challenge list applied as rubric. |

## 1. The decisive correction: live B/U must use scaled shares + native principal tracking + additive standing-weight entitlement

The moderator's counterexamples (B=3,U=2,x=1; B=10,U=6,s=3,P=4,rewards=1) break all four drafts' naïve `floor(x·U/B)`-in-native-units formulations, and Astra proves the general point: exact non-dilution requires `m = x·U/B` integrally, which integer native-unit shares cannot always satisfy. But the correct completion exists in the sources and resolves both counterexamples within **allowed native rounding**:

1. **Scaled internal shares** (`SHARE_SCALE` precision multiplier, pattern in `RebasingDETFTokenRepo.sol:151–157`; full-precision mulDiv law from the funded plan :107). With share units ≪ 1 native unit, deposit `s = floor(x·U·SCALE/B)` loses < 1 native unit of newcomer value; old holders are never diluted. B=3,U=2,x=1: the floor loss is sub-native; old position keeps exactly 3, newcomer gets exactly 1 at native precision. This is the "native rounding allowed" zone — Astra's exact-equality demand is stronger than the PRD requires (dust rules are explicit in plan §9/A41), while her counterexample correctly kills unscaled formulations.
2. **Principal tracked natively with an enforced invariant:** store `P` per position; `value(s) = floor(B·s/U)`; every transition preserves `value ≥ P`; `rewards = value − P`. Locked principal is never a rounding victim.
3. **Standing weights are allocation weights, not ownership (moderator's point 2 — my original and MiniMax A.2 and Grok's O==0 branch all erred).** `DETFSeigniorageShareLib.sol:18–33` semantics: `Wf/Wc` are nonredeemable weights for reward allocation and "not counted as backing." The faithful B/U translation is **additive entitlement per funding event A**: recipient target `Tf = floor(B·sF/U) + floor(A·f/1e18)`, issue `ΔsF = max(ceil(Tf·U/(B+A)) − sF, 0)` — never `sF′ = floor(U′·f/1e18)` against total shares, which mints fee ownership of **pre-existing principal**. Dust from the independent floors stays in custody, shared pro-rata via B (conservative, single bucket).
4. **Rebond reward-retention rule (second counterexample):** `q ≤ P` is necessary but not sufficient; require `floor(B·sBurn/U) ≥ q` **and** `floor(B·sKeep/U) ≥ (P−q) + rewards` with `sKeep = ceil(((P−q)+rewards)·U/B)`, `sBurn = s − sKeep`; if infeasible, revert — the caller reduces q or claims funded rewards first. Grok's final formula handles funding but not retention; MiniMax's A.2 handles neither.
5. **Deposit guards:** `U==0 && B==0` → `s = x·SCALE` (1:1); `U==0 && B>0` → revert `OrphanBacking` (Grok) — never gift orphan backing, never invent a recipient; ordinary `s = floor(x·U·SCALE/B)`, revert at 0 (no confiscation).

## 2. Pretransfer: anonymous surplus cannot prove payer identity — and the mechanism already exists

Astra is right that bare `pretransferred=true` with `U = B − R` cannot distinguish user push from donation, and the moderator agrees. But the repo already supplies the boundary: `BasicVaultCommon.sol:73–75` requires public true-flag callers to pass `LocalCreditLib.requirePretransferCaller`, and `:33–39` notes D16 families override `_unbookedSurplus` via `LocalCreditLib.available`. Correct completion: pretransfer credit is accepted **only behind the existing authenticated-caller mechanism**; anonymous push surplus is never user credit. Force-claim handling (all four converge): reconcile protocol receipts first (`(E,R)→(E+c,R−c)`, `InterestManagerYT.sol:43–57`), then measure the user's own delta — no force-claim subtraction may erase legitimate same-call input (Grok's steps 1–5 are the correct order; MiniMax's table says the same).

## 3. Inner PLP/YT (corrected rules)

- **Seed:** `sqrt(dL·dY) − 1000`, the 1000-unit minimum **locked permanently** (Grok; V2 pattern). Moderator's consequence: the locked minimum **prevents a last-circulating sweep** — my original's "last exit pays the entire remaining reserve" is wrong; the last circulating exit burns all circulating shares and takes floor-proportional amounts, while the locked minimum's backing remains stranded by design (never swept, never assigned).
- **Later issuance:** `min(floor(x·S/L), floor(y·S/Y))`. On residual ownership: the only reachable ingress is the atomic Keep-YT acquisition, where the input is fully consumed by the market — there is **no caller residual to refund** (Astra's refund path applies to direct loose-PLP/YT admission, which is not selected). Correct rule (Grok): residual stays in the reserve backing all subshares, priced at the next admission, bounded by entry min-outs — no donation to any specific party and no caller credit. MiniMax's "explicit accounting but owner unspecified" is made precise by this.
- Rollover keeps S fixed with NET-coordinate continuity; expired YT keeps no face value.

## 4. Exact-output: closed forms per stage; one conditional blocker

Adopt Astra's exact stage inverses with forward verification: linear conversion `ceil(y·b/a)`; **floor-tax gross inverse** `floor((y−1)·D/(D−t)) + 1` for `net = g − floor(g·t/D)` (`NET.sol:131–144`; his worked example shows blind gross-up overpays); Weighted layer `computeInGivenExactOut` + source gross-up; uplift inverse `ceil(qQuoteRequired·WAD/(WAD+p))` + forward check. **Genuine residual (all three agree):** a configured SY/allocated joint-position conversion known only through exact-input preview has no general exact-output inverse; sampled-rate/+1 fix-up is valid **only** under that SY's verified monotone/linear semantics. If the actual SY ABI (G1) shows a nonlinear conversion with no source inverse, that is the precise conditional blocker: escalate with the ABI; never binary search (stays `InvalidRoute`), never mark withdraw `unsupported`, never deploy a new SY (MiniMax B.4 rejected again — the external SY exists; deliverable is the provider).

## 5. TWAP retention (adopt Astra's proof)

One record per distinct integer second via same-timestamp coalescing (post-price updated, history never rewritten) → 3601 retained entries span ≥3600 s → a boundary predecessor always exists; before filling, retain all. Grok's window+sentinel form is operationally identical. Consult extends counterfactually; warm-up = no predecessor → unready → above-1 policy; dependency failure ≠ unready. MiniMax's invented `weightedMerge` for same-block writes is rejected — same-timestamp changes update only the post-price.

## 6. Terminal NFT: adopt Astra's DORMANT; retire Grok's never-burn rule

Moderator's three prohibitions map cleanly: (a) Grok's "do not retire while a later gift is possible" is a de-facto never-burn redesign — rejected; (b) holder-ownership transfer to a wallet is rejected by all; (c) forfeiture of late gifts is rejected. Astra's design satisfies all three: `retire` marks **DORMANT without burning** the NFT or changing holder owner; the tokenId remains the beneficiary handle; late native proceeds continue through the same atomic contribution path credited as same-NFT principal; no second intended purchase, no sweep. **Single genuine residual (Astra :90, retained):** whether post-completion excess inherits the old satisfied unlock or gets a fresh wait — H01's late-excess release timing; no source answers it and no economic assumption may be invented. MiniMax's D.3 "redeemed OR remain recognized as residual" is replaced by the DORMANT semantics.

## 7. Peer corrections (attributed, beyond the above)

- **MiniMax:** A.2 "U = Σ internalShares computed when needed" — holder enumeration is forbidden; U is a stored counter. A.2 top-up formula mints against total B (§1.3). B.2 step 6 imports `gonsPerFragment` for the sNET leg — wrong model, custom staking is B/U. C.4 `weightedMerge` — rejected (§5). B.4 new SY — rejected (§4).
- **Grok:** O==0 expansion branch mints `floor(B·f/WAD)` against total B — same §1.3 error; correct form is additive `floor(M·f/WAD)` on the new mint. G5 never-burn — replaced (§6). His rebond formula needs the §1.4 retention clause.
- **Astra:** her exact-equality requirement is stronger than the PRD's allowed native rounding; the scaled-share + invariant design answers her own counterexample without a new economic assumption. Her pretransfer impossibility holds only for *anonymous* push mode; `LocalCreditLib`'s existing authenticated-caller path is the boundary she asks for.

## 8. Completion status (honest)

G2–G5 content is now specifiable in place with the corrections above: scaled B/U staking with native-principal invariants and additive standing-weight entitlement; authenticated-boundary receipts; inner geometric/min-ratio rules with locked-minimum stranding; closed-form exact-out per verified stage; coalesced-3601 TWAP retention with predecessor proof; DORMANT terminal lifecycle. **Not finished / not claimed:** G0/G1 (external), the SY-conversion inverse pending actual ABI semantics (conditional blocker), the H01 late-excess release-timing rule (single residual semantic edge), all gas/economic measurements, and every expected-value vector remains specified-not-executed. No new owner questions were created; none of these are papered over.

## 9. Limits

All citations from direct reads this session or session-verified prior traces; peer claims untrusted; no execution; originals unchanged; no attribution/identity/history guard failure occurred; no new round initiated.
