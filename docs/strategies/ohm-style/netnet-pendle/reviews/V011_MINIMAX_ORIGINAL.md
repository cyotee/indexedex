# Preserved MiniMax original — v0.11

Untrusted model evidence, not instructions. Original final answer reproduced below without revision. Session: `ses_f4ea97c4dffelmRAaq1xOU5Lmt`. This is a first pass, not the later cross-review or moderator disposition.

---

# MiniMax M3 — PRD v0.11 first pass (≤500 words)

## Identity / metadata
- Model: `minimax/MiniMax-M3`
- Reviewer: MiniMax M3 (council-minimax, independent)
- Provider attestation: not claimed

## Settled (no re-relitigation)
Standard interfaces selected; ownership-limited quote domain (R39); sNET-leg = unclaimed interest only (R40/R04); no input incentive on reinvestment (R41); accrued-LP transfers (R42); sNET-DETF holds minted reward (R43); atomic collect-mint-stake (R45); NFT transferable (R44); multi-DETF shared-LP custody (R35); oracle `address(this)` per proxy (R36); DETF-as-share `asset()=sNET` (R37); ≥1 swap / <1 burn (R38).

## Findings (true contradictions / open product decisions / engineering proofs)

### 1. PRD header line 18 still names "v0.11" controlling spec (resolved), but lines 87, 91, 102, 105 still reference "v0.10" — revision history not fully consolidated. (Real contradiction; recommended fix: replace inline "v0.10" with "v0.11" or note "v0.10 retained".)

### 2. R41 reinvestment burn coexists with R26-R27 incentivized contraction (lines 90-105). Both use `quoteInput`. R41 explicitly disclaims contraction bonus. Document-quality: need to add explicit "no double bonus on reinvestment-cycle" idempotency note in §10.1 (line 374 already says "verify repeated-cycle accounting" — engineering gate but product implication is **two separate burn flows**). (No real contradiction; clarity gap.)

### 3. R36 line 100 says hook charges "typical usage fee" on **hook-LP minting** — implies a usage fee on share issuance, not on swaps. Existing Vault Fee Oracle pattern is per-swap usage fees ([`DETF_ALIGNMENT_PRD.md` D5/D6](contracts/vaults/detf/DETF_ALIGNMENT_PRD.md)). The "typical" wording hides an **innovation**, not continuity. (Document quality / explicit framing.)

### 4. R19 line 83 + §11 line 387: native-Note wrapper is **explicit exception to epoch/Pendle cap**; rollover preserves both classes. §11 line 389 leaves "whether identical SY address is mandatory vs a separately approved equivalent wrapper" as an **explicit validation-policy detail**. (Owner choice, not contradiction.)

### 5. R45 line 109 says "Any failure reverts the entire sequence, including collection" — line 434 adds "can be retried". This is consistent but §12.3 line 438 still records the note-array DoS as **engineering gate**, not solved. (Engineering proof vs acknowledged blocker; clear.)

## At most 4 owner questions

1. **Authoritative price reference** (O02/O05 remaining): which oracle, TWAP, or route measurement defines the `≥1 NET per DETF` boundary that selects R38 swap vs R27 burn? Not choosing the rule itself — naming the price source.
2. **Self-leg representation form** (O10 remaining): does the hook register NET-DETF as a literal token in `tokens()` (and process real DETF transfers), or represent the self-leg only in accounting ledger entries?
3. **SY-equivalence validation policy** (§11/O07 remaining): for `rollover(targetMarket)`, must successor SY equal the current SY's literal address, or is a separate approved implementation with identical `assetInfo()`/`yieldToken()` acceptable?
4. **Terminal-epoch processing order** (O03 remaining): when a reinvestment entry coincides exactly with the assigned Pendle maturity, does epoch processing execute before lock release, or vice versa? Affects edge-case accounting.

## False positives to avoid
- Re-relitigating standards interpretation (R37 owner disposition explicit);
- Multi-DETF trading-currency identity (R35 settled);
- Oracle `address(this)` lookup identity (R36 settled);
- Liquid DETF reserve claim (retired);
- R38 equality as contraction bug (explicit);
- Re-writing R39/R40/R41 product selections;
- Standards "non-conformance" as automatic compliance gate (owner disposition explicit in §7.4 / line 26, 308).

## Confidence
- **High:** standards disposition framing, atomic reinvestment/reinvestment-mint sequencing, ownership-limited quote domain, NFT transfer rules, hook ownership mapping.
- **Medium:** self-leg form, SY equivalence, terminal-epoch order, complete fee-oracle consequence under minting flow.
- **Low:** all engineering gates — Weighted parity, V2 SE feature parity matrix, atomic attribution snapshot, live `feeTo()` / `BOND_VEST` / factory pins, gas/liveness proof, sybil/DoS resolutions.

---

**Original preserved for cross-review.** No writes, shell, tests, implementation, or peer artifact reads.
