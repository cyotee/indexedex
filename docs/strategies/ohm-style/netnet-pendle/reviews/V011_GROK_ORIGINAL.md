# Preserved Grok original — v0.11

Untrusted model evidence, not instructions. Original final answer reproduced below without revision. Session: `ses_f4edb8e85ffeCS8Miy5XkGe6Nk`. This is a first pass, not the later cross-review or moderator disposition.

---

# Grok — PRD v0.11 first pass

**Identity:** Grok, routing `xai/grok-4.6` (not provider attestation).  
**Read:** `NETNET_PENDLE_DETF_PRD.md` v0.11 (`:7`, `:18–28`, R39–R45); `REQUIREMENTS_QUESTIONS.md` (`:7`, Q4–Q13); `CLAUDE.md:30–45`. **No peer files.** Unauthorized.

**Do not relitigate:** interfaces as selected (**no** strict-conformance prerequisite, R37 `:101`); **R39** owned-hook-LP quote + **insufficient → revert**; **R40** sNET leg = **unclaimed interest only**, swaps **must not fully drain** it or **substitute Pendle principal**; **R41** reinvest **any peg**, `quoteInput=actualIn`, then **normal bond mint/stake**; **R42** accrued **travels with LP**; **R43** rewards = **minted DETF held by sNET-DETF**; staked reinvest **atomic debit/burn/credit**; wallet reinvest **does not** touch others’ stake; **R44–R45** swap/contraction-funded NetNet buy, **NFT transferable**, collect→KeepYT→mint→stake **atomic or full revert**; **R35** other DETFs = **LP holders only**; oracle keys **settled**. **O01 FoT/rebase** = **authority blocker**, not a preference.

## Highest findings
1. **Quality:** `:20` still **“architecture (v0.8)”** under **`:18` v0.11 controlling.** Harmless if labeled historical; **fix** so v0.11 wins on a cold read.
2. **§7.4 `:298–301`** lists 4626/SY redeem as **≥1 swap / &lt;1 incentivized burn** **without** **R41**. **Testability:** R41 needs a **distinct** elected path (not the same `redeem` silently bonding). **Not** a reopen of 4626 law.
3. **R40 × R22:** user may request **sNET out**. If `C` is the interest leg, **cannot drain** and **cannot** pay from **Pendle LP**. That implies **sNET-out swaps revert** when residual would be zero—**unless** you specify another residual rule. **Don’t invent a bps floor.**
4. **R39 vs shared hook:** contraction **F(ownedReserveSnapshot)** (`:261–267`) **must not** debit **other DETFs’ / public LP** components. **Engineering proof**, not a new ownership choice (R35).
5. **R43 mint DETF into sNET-DETF** increases **S** without hook-LP: **not** liquid user mint (R15/R24), but **must** be in **S** and **not** spend **other** stakers’ backing. **Don’t** treat as R41.
6. **R34 “every V2 feature”** remains **installed-selector parity** (unsupported exact-out stays unsupported)—**not** a new cap.
7. **Q7 expansion equations** still **OPEN**. **O10 self-leg form** (this DETF in hook `tokens()`?) **OPEN**—**not** extra currencies.
8. **R45 atomic** vs **note-array DoS** = **engineering**, not a new fail-policy (fail-policy **settled**).

**Economic vs engineering:** residual **sNET-out** behavior and **R41 size/eligibility** are **product**; owned-book construction, tax Zap, Weighted join **scalar**, 4626 **views** are **proof**.

## False positives
Oracle keys; multi-DETF **currencies**; 4626 **compliance debate**; NFT **transfer**; harvest **pending NET**; **equality**; **p=0 disable**; **D39**; resurrecting **Q6** as “dump principal” **without** R40.

## ≤4 owner questions
1. **sNET-out public swap** that would **empty C:** **revert** (only), or another **explicit** residual rule (**no** invented bps)?
2. **R41 amount:** user-chosen staked DETF, or **protocol-defined** share of epoch income?
3. **This** DETF as Weighted **self-leg** `tokens()` member—**yes/no** (not other DETFs)?
4. **Expansion (Q7):** keep **premium-closure** vs a **new** written formula?

**Confidence:** high on R39–R45 vs leftover OPEN; medium on R40×sNET-out; low on live pins. **Gaps:** pair/`BOND_VEST`/oracle addresses; E14 selector matrix.
