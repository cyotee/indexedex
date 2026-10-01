# Kimi K3 — NN-01 CROSS-REVIEW (Astra / Grok / MiniMax M3 originals)

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 |
| Basis | Full reads of the three NN-01 originals (untrusted evidence); my unchanged NN-01 original. No peer cross-reviews read. |

## 1. Four-way agreement (convergent, high confidence)

All four independently produced the same answer shape: (a) NN-01 is a dependency/evidence manifest, not redesign or deployment; (b) a two-layer artifact — design-time baseline vs deployment evidence; (c) the same evidence taxonomy (fixed source/interface; live deployment; new components needing no address for design; rollover-changing/dynamic state — MiniMax's 3.4 merges my D+E, Grok splits out CAPABILITY); (d) closure = complete table with cited evidence **or explicit blocking gap**; symbol/pragma/path/historical address ≠ pin; (e) no deployed-equivalence claims, no deployment-before-design; (f) checkpoint = approve structure only, owner trigger only on a materially unavailable capability; (g) identical PkgInit (7) / PkgArgs (3) / discovery split; (h) vesting 2d-vs-5d recorded as unverified discrepancy, not solved here; (i) canonical pair is SELECTED-but-unverified, no substitution proposed by anyone. No factual contradictions between the four.

## 2. Corrections to my original (adopted)

- **C1 (Astra, material): §8's deadline is "before implementation", stronger than my "pre-deployment".** My Tier-2 phrasing ("scheduled pre-deployment work") and Grok's ("before production use") both understate PRD:525 ("Verify pair tokens, factory, code and live fees **before implementation**"). The manifest must carry that gate **verbatim** as a pending blocking obligation on implementation start; NN-01 closes without it, but nothing may treat the pair as verified. Adopted.
- **C2 (Astra): "manifest complete" ≠ "dependency gate passed".** My "explicit blocking gaps count as closure content" was correct for the tracker test but risked reading an honest blocker as readiness. Adopt Astra's two statuses: the *manifest artifact* closes when complete; *dependent commitments* (NN-02, NN-10, implementation start) stay blocked by recorded gaps. This is exactly the specification-completion vs evidence-blocked-work distinction.
- **C3 (MiniMax 3.1): fixed-source rows need a stated compatibility claim**, not just a commit hash (hash pins revision, not behavioral parity). Adopted as a required column.
- **C4 (Grok): add CAPABILITY as an explicit column** (named methods/events traced to source/interface, e.g. `taxEnabled`, `epoch`, `deposit/redeem`, `getTokensOut`, factory recognition) and the **execution-router identity** as a named design pin (fee-override identity per §7.1.2). Both refine my table; adopted.

## 3. Objections / corrections to peers

- **O1 (MiniMax, internal tension):** §3.2 says "an entry that says 'we will look up at deploy' is not closure" — this contradicts their own dual-column rule and the tracker's explicit-blocking-gap allowance, and would force live observation before manifest closure (deployment-before-design). Their §4 avoidance rule is the operative, correct one; §3.2's sentence should be read as applying only to rows claiming verified status. Note, don't adopt the strict reading.
- **O2 (MiniMax component list):** names "the wrapping NFT for external bonds; the bond NFT for internal bonds" as new components. The PRD selects **one** custom NFT child (R14); the internal bond lifecycle reuses the selected reference calculation (R47; §12.3 allows component reuse). Do not invent a second new NFT contract in the manifest; record one custom NFT + reused reference components, per the moderator's no-invented-architecture guard.
- **O3 (MiniMax hook row / Grok):** both correctly record "hook DFPkg vs legacy monomorph" as open — it is NN-17 scope; the manifest records the open question, must not answer it. Consensus, kept bounded.
- **O4 (Grok §8 phrasing):** "before production use" — see C1; deadline semantics matter and §8's wording controls.

## 4. Plain-English merged recommendation

Build one table. Every row answers four questions: *what role does this dependency play; where does its value come from* (PkgInit / PkgArgs / validated discovery / computed deploy / dynamic oracle); *what is pinned now* (commit + file:line + compatibility claim, or "created by this family"); *what is still unverified and how would we know* (method, acceptance predicate, observation block, or the word BLOCKED with the specific gap). Three statuses travel with each gap: **manifest complete** (the table is finished — NN-01 can close), **capability blocked** (a required ABI/role cannot be bound — owner trigger), **verification pending** (live facts owed by named deadlines, including §8's before-implementation pair/fee/tax checks — blocks implementation, not the manifest). New components carry no addresses and that is expected. Rollover-changing and oracle-dynamic values are pinned as *procedures and resolution rules*, never as frozen values.

## 5. Consolidated UNAPPROVED PRD paragraph (narrow; supersedes my earlier draft by C1–C4)

> **§16.1 Dependency and evidence manifest (NN-01).** Before executable planning, a versioned manifest SHALL record, for every dependency: role; evidence class (fixed source/interface design; live deployment verification; new component; rollover-changing; dynamic external state); source of truth (PkgInit, PkgArgs, validated market discovery, computed deployment, or dynamic oracle resolution); required capabilities traced to a named interface/source; a source-revision pin (commit hash + file:line) with an explicit compatibility claim; and verification status — verified (with observation block/method), pending (with method and deadline), or blocked (with the specific gap). New custom components are recorded by deployment path and salt/flag derivation; missing addresses do not block design. Rollover-changing dependencies (market, PT/YT/SY) and dynamic state (`feeTo()`, oracle terms, tax/exemption membership) are pinned as re-validation procedures and resolution rules, never as frozen values. Existing verification deadlines are preserved, including §8's requirement to verify pair tokens, factory, code and live fees **before implementation**; recording such a gate as pending does not satisfy it. Manifest completion closes NN-01; it does not certify deployed equivalence, does not pass any dependency gate, and does not unblock dependent items whose rows remain blocked.

**Checkpoint (one question):** approve the four-question/five-class structure, the manifest-complete-vs-gate-passed distinction, and verbatim preservation of §8's before-implementation deadline — as the NN-01 closure standard. No addresses, values, economics or other NN items are decided.

## 6. Residual dissent

None factual. Only emphasis: MiniMax's strict §3.2 reading (rejected, O1) and Astra's extra status labels (adopted as evidence labels, not new tracker states, matching her own caveat). All four agree the pair is selected-not-verified and no live values are invented.

## 7. Limits

Routing metadata not provider-verified. No new external claims; no Context7 needed; no RPC/shell/tests; no PRD edit. Peer statements treated as untrusted evidence; all PRD/tracker quotations independently re-verified against my own earlier full reads (`PRD_OPEN_QUESTIONS.md:67–72`, PRD:246–258, 525, 775–786, 931–966).
