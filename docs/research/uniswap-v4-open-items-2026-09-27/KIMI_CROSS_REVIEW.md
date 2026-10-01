# Kimi K3 — Cross-review: remaining open items (V4 FullSpread zap-in PRD)

**Date/access date:** 2026-09-27 · **Researcher:** Kimi K3 · Peer originals read in full as untrusted evidence: `ASTRA_ORIGINAL.md`, `GROK_ORIGINAL.md`, `MINIMAX_ORIGINAL.md` (same directory). No cross-review artifacts read. My original (`KIMI_ORIGINAL.md`) is preserved unchanged; corrections are recorded here only. All disputed claims re-verified against source.

## 1. Corrections to my own original

1. **A1 (hookless fee-field admission) — withdrawn as an owner question.** Grok's reading is the faithful one: the PRD enumerates the admission boundary as hook identity (§10:367-375) and preserves only *existing* structural validation (:381); adding fee-field restrictions (dynamic-flag reject, 100%-fee ban) is unlisted policy — "not approved; do not add" (Grok §2). Consequences are handled by route domain, not admission: a `hooks==0` + `0x800000` key can never initialize on the canonical manager (`Hooks.sol:126-127` → inert vault, immutable deployer error); a 100%-fee pool's exact-in yields zero output against min-out and exact-out reverts `InvalidFeeForExactOut` (`Pool.sol:315-321`). **Minimum safe answer: no owner question; ship hook-identity-only admission; document inert/dead-key consequences for deployers.** MiniMax's "add `isDynamicFee`/`isValid` rejects as engineering default" (his §2.1.C) is the position that would actually change policy; I no longer endorse it.
2. **B1 inventory accuracy — corrected.** Astra's claim is verified: `ConstProdUtils._quoteZapInToTargetLPWithFee` (:567 "Inverts via binary search"; :621,629-631 loops/search) and `_quoteZapOutToTargetWithFee` (:665 "quadratic + binary search impl"; :698-846) are **search-based — ineligible** as closed-form evidence under §6.4:214. My B1 listed them without that distinction. The genuinely closed-form entries are: `_depositQuote` (:102-115), `_saleQuote` (:149,181), `_purchaseQuote` (exact-out swap inverse, :206,235), `_quoteSwapDepositWithFee`/`_swapDepositSaleAmt` (:279-374, :428-470 — sqrt closed form), `_quoteWithdrawWithFee`/`_withdrawQuote` (:496,540). `_quoteWithdrawSwapWithFee` (:1081) unclassified — plan must classify.
3. **WIP candidate framing — corrected.** My original said the `UniswapV4FullSpreadClosedFormCandidate.sol` parity test "must first be fixed." Per this round's instruction: the candidate is **unadopted WIP**; the plan must not presume its adoption, and its state is not a blocker. The §6.4 inventory stands on the owner-designated sources (`lib/crane/contracts/utils/math/` + the unsegmented implementation), not on that candidate.
4. **Diagnostic vs executed build.** My original's compile-error note was an **editor LSP diagnostic**, explicitly not an executed build; reaffirmed here: no one in this round executed `forge build`/`forge test`; all build/compile claims in all four originals are source reads or editor diagnostics, not build evidence.
5. **Prior-round dissent resolved by D22.** My hook-package-round recommendation to defer quote-facet splitting is superseded: §10:357-361 forbids a shared Hookless/Pons quote/execution dispatcher and mandates family-specific quote/execution/maintenance paths. Since `QuoteService` is compiled into every V4 facet via `Common.sol:54,104,239,1092-1134`, each family compiles its own family-prefixed facet set; reuse is limited to genuinely hook-independent components (generic ERC20/vault facets, `StandardExchangeConstantProduct`, crane math) per §10:361. MiniMax's per-family-duplication conclusion (his E-5/E-6) is correct *under the new law*.

## 2. Corrections to peers (with evidence)

**MiniMax (several substantive):**
1. **MIR-1/E-4 is invalid reasoning.** "`LiquidityAmounts.getLiquidityForAmounts` is closed form ⇒ the combined route on a vanilla pool is closed form" conflates *evaluation at a known price* with *solving the combined unknowns*: the maintenance swap size moves the price, which reprices the position and the targets — a fixed point that a placement helper does not solve. PRD line 214 warns against exactly this. (His cited path `lib/crane/contracts/dexes/uniswap/v4/utils/LiquidityAmounts.sol` is also wrong; actual: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol`.) Whether any *existing* closed form covers a combined route remains an outcome of the §6.4 inventory — not established by him, and not disproven by earlier candidates (line 233).
2. **X-5 ("prepaidCredit mismatch") is a misread.** `_amountInForZapMint(.., prepaidCredit)` subtracting not-yet-credited inbound from incumbent reserves (`OutBase.sol:54-62`) is exactly the required attribution — §6.3 backing "excluding that contribution" and §6.1 credit-before-snapshot. His proposed re-derivation against gross `reserveIn` would count the caller's in-flight input as incumbent backing (mint inflation). Keep the existing shape.
3. **"fullSpread/ does not exist" (§7.1/§9.1) — factually wrong.** Both `v4/fullSpread/hookless/` and `v4/fullSpread/ponsFamilyV2Hook/` exist and are **empty** (directory read, 2026-09-27). Grok's "no Solidity under…" is the accurate formulation.
4. **V-1 wording:** the equivalence check is the locally built `PonsV2MemeHook` runtime artifact vs on-chain code at `PONS_V2_MEME_HOOK` — not "the constructed Pons package's bytecode" (his §4.1). Substance stands.
5. **ROBINHOOD_MAIN pins:** his ":422-427" range is the provenance comment block; the constants are :429-441 (`PONS_V2_LAUNCH_FACTORY` :436, `PONS_V2_FEE_ESCROW` :438, `PONS_V2_MEME_HOOK` :441). The comment (:422-424) records a 2026-09-27 `factory.memeHook()` reconfirmation — address provenance, not bytecode equivalence; C1/V-1 remains open.
6. **MIR-2** ("the blanket prohibition was mistaken") is editorializing about a settled-then-superseded owner decision; disregard — not evidence.
7. His "priority = V-1" overstates: D26 fixes the binding; §10:384 pre-specifies the mismatch response (new integration). V-1 gates *acceptance*, not *plan authorship* (acceptance 25 records evidence; the plan can be written with the gate specified). See §4.

**Astra:** no errors found. Her ConstProdUtils search claims verified (:567,:621,:629-631,:665); her "names alone are insufficient" and conditional-escalation-only framings verified against D1–D26.

**Grok:** no substantive errors. His "not approved; do not add" list (100% ban, one-vault-per-pool, registry retarget, migration) is the correct governance reading and drove my correction #1. Minor: his §3.1 "did not find those two helpers there" is consistent — `_amountInForShares`/`_sharesForSingleExit` live in the vaults tree (`StandardExchangeConstantProduct.sol`), not crane math.

## 3. Agreements (all four, verified)

- D1–D26 close the prior policy forks; no owner questionnaire is needed to author the plan (PRD line 229: the matrix "is engineering verification of the owner's rule, not a new owner choice for every selector").
- Constants verified (`ROBINHOOD_MAIN.sol:37,169,441`); hook identity closed; **deployed-runtime equivalence unproven** (PRD §10:365).
- Family trees empty/absent-of-Solidity; legacy baselines retained until the §3.1 gate.
- `_sharesForSingleExit` bisection (:113-129) and both `UniswapV3ZapQuoter`/`UniswapV4ZapQuoter` binary searches cannot underwrite closed-form eligibility.
- Highest-value near-term work: the §6.4 route/formula matrix; runtime-provenance evidence in parallel (Astra's formulation; Grok and I concur on matrix-first for plan authorship).
- Documentation reconciliation is a separate authorized task (PRD line 97); no test/build was executed by any member this round.

## 4. Remaining dissent (narrow)

1. **Priority ordering:** MiniMax puts V-1 (runtime equivalence) strictly first ("no plan item can be defensibly finalized"); Astra/Grok/me put the route matrix first with provenance evidence in parallel. Synthesis (recommended): **B1/E-1 first for plan authorship; V-1 is the highest-priority verification gate, started in parallel** — the plan's content does not depend on chain reads, but acceptance does.
2. **Fee-field admission hygiene:** resolved toward Grok (add nothing beyond the PRD's enumerated hook-identity boundary) — MiniMax's reject-by-default would be new policy. Recorded as resolved, with the deployer-error consequence documented.
3. None remaining on: address-vs-codehash (address pin closed by D26; codehash/behavioral equivalence is a verification gate with labeled hermetic-vs-production evidence — unanimous), launch-term mutability (frozen per pool — unanimous after corrections), candidate adoption (nobody adopts the WIP candidate; it enters the inventory as one artifact to evaluate).

## 5. Final prioritized open items (consolidated)

- **P0 — §6.4 route/formula/interleaving matrix** (families × directions × modes × states; corrected closed-form inventory per §2.2; exception documentation; `InvalidRoute` surfaces; preview/availability parity). Owner input: none.
- **P0 — V-1 deployed-runtime equivalence gate** for `PONS_V2_MEME_HOOK` and the PoolManager constant (fork codehash + behavioral probes; production vs hermetic labeling, acceptance 25). Parallel with P0.
- **P1 — Family component/selector/factory maps under D22 prefixes** (own quote/execution per family; enumerated generic reuse; salt-law-compliant name-only salts; occupied-salt binding assertions).
- **P1 — Numerical specs:** maintenance metric/progress ordering (D21/§8:294-304), depositor ε arithmetic (§7), composition solver bounds (§6.2), protection-constant checks (D20/D25), attribution incl. own-LP/protocol/hook fees counted once (§5, §6.2).
- **P1 — Quote/consumer parity:** transition quotes, SY, Multi, imports; removal of the unknown-hook fallback in family code (§10:385).
- **P2 — Legacy-removal manifest** (§3.1 inventory/disposition incl. shared parent files and legacy docs; regression porting; post-removal rebuild; audit pinned to the post-removal revision).
- **Documentation reconciliation (separate task):** co-located PRD supersession map; old↔new decision-ID map; historical-revision citations.
- **Human checkpoint (only one):** the §3.1 audit-submission readiness determination at gate time.

## 6. Confidence

High: all corrections (direct reads 2026-09-27), policy closure, priority synthesis. Medium-high: the corrected closed-form inventory's completeness (B1 will settle). None of this constitutes execution, a security proof, or an economic-soundness claim (PRD line 528).
