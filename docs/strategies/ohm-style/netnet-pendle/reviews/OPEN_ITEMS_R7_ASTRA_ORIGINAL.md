# Astra — OPEN_ITEMS_R7 original first pass

**Readiness verdict:** Enough exists for a conditional milestone plan now. Economic projection semantics must be frozen before implementing their results; deployment proofs need not all precede writing the plan. Opening **1000 NET/DETF**, strict **NET price >1**, processed NET epochs, premium dependence and compounded pending supply are selected. Linear catch-up is not an alternative.

References: **Custom** = `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.16; **Compound** = `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md`.

## Three remaining economic questions

1. **What is the custom premium coefficient?** Custom `:26,368–370,460,595` leaves the prior 0.5% interpretation unresolved. **Proposal for confirmation:** `c=0.005e18` per processed NET epoch applied to `floor(S_i*(P_i-W)/P_i)`, not directly to all supply. Here `S_i` includes earlier pending issuance and `W=1e18`. At `P_i=2W`, this yields approximately 0.25% of that epoch's projected supply before rounding—not 0.5%. Do not encode an annual coefficient accidentally or change the selected reward custody.

2. **Which NET price drives the gate/premium, and how does it evolve during virtual epochs?** A marginal reserve trading quote and marked inventory per outstanding DETF are different quantities. Compound `:92–103` explicitly leaves this policy open. **Proposal:** define the authoritative NET-denominated price function, freeze external snapshot inputs, then reevaluate all genuinely supply-dependent inputs at each virtual state. If that chosen function depends only on unchanged pool balances/weights, minting outside the pool does not mechanically change its spot price. Never fabricate such a change or normalize the custom target by opening1000. This is a pricing-policy choice, not merely loop optimization.

3. **Does compounded reward allocation emulate each virtual distribution, or allocate the final compounded mint once?** Both compound supply; fee/creator receipts, index rounding and subsequent participation can differ (Compound `:105–111`). **Proposal:** evaluate sequential virtual allocations as the semantic reference, with actual funding aggregated only when demonstrably equivalent. Preserve selected beneficiaries/custody; this does not reopen who owns staking backing.

## Engineering and display proposals inside the plan

Expose explicit projected supply/staking/claim views while retaining identifiable stored supply and custody; settle actual mint/funding before projected value is spent. This satisfies pre-transaction display without pretending unminted DETF already exists. Audit every consuming quote to avoid adding pending supply twice (Compound `:58–68,117–145`). Treat any existing balance-view ABI change as an explicit compatibility decision, not a silent default.

Specify per-epoch native rounding, dust treatment, zero-result marker consumption and bounded-complexity evaluation; no skipped epochs or hidden caps (Compound `:147–158`). Demonstrate first-bond full-book compatibility with zero earned interest without inventing yield. **Proposed first-version behavior:** revert rollover to an empty successor unless a separately specified safe seed path is approved; preserve atomicity, old/new SY identity and historical claims. Neither issue reopens first-bond seeding or atomic rollover.

## Authority and documentary work

`CLAUDE.md:44–45` constraints and formal custom-family supersession remain execution gates. Compound `:23–35` explicitly reverses old noncompounding requirements; reconcile affected canonical text/tests without importing unrelated changes. Matrix `:85,88` still calls opening/compounding or USDG maturity uncertain; tracker `:7,28` predates the new decisions. These are stale labels, not owner questions.

**Confidence:** High on documented selections/gaps; economics, live pins, note-array liveness and complexity remain unproved. No external research or tests. Identity metadata: Astra, supplied `openai/gpt-6-astra`; not provider attestation. Only this assigned Markdown artifact was written.
