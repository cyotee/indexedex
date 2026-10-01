# Grok — review of NETNET_PENDLE_DETF_PRD_INITIAL.md (v0.1)

- Reviewer: Grok (`xai/grok-4.6`)
- Draft: `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD_INITIAL.md` (273 lines)
- Date: 2026-09-21
- Status: independent first-pass document review. **Does not edit** the initial or consolidated PRD.

**Verdict:** Faithful **(a) reviewable draft**. **Not (b) execution-ready.** No owner decisions invented. FoT/rebase **unresolved**. Unauthorized.

**Settled captured:** R05 physical V2 `0x59F95461…` (4663); R06 tax paid, live getters, no exemption dependency; R02–R03 unified Pendle, Keep-YT vs ordinary no-YT LP bonds; R04 public swaps / income→ordinary LP; R11 **no D39**; R08 Net `epoch()`; R09 `rollover(target)`; R10 expiry LP-mint revert; R12 **must reenter+stake+same NFT**; R13 PENDLE→`feeTo()`, SY stays. Three LP types §2. Note grief §12. `BOND_VEST` 2d vs 5d prose.

## Must-fix
1. **§2 / R05:** State the V2 pair tokens are **NET/USDG**. **sNET rebase ban** is a **route** constraint, not the pair’s second token.
2. **R11 / O02:** Keep **bond-only / primary redeem / direct stake** **OPEN**. Do not imply all Keep-YT entry is bonded (§5 already OPEN—mirror in R-table footnote).
3. **§10:** Lock **release** remains **OPEN** (linear vs cliff; Net epoch vs Pendle maturity; wrapper NFT). Do not freeze “short=epoch / long=maturity” as law.
4. **§4:** Hook **OPEN** (Orbital / Quad-style / Weighted). D60 = no **Balancer-hosted** DETF.
5. **§12:** Wrapper **cannot** reject unsolicited `notes[to]` without upstream callback—leave as **engineering gate**, not a designed NFT property.
6. **O01:** Policy revision **required before code**; tax-aware Zap ≠ exception (`CLAUDE.md` 6; `NET.sol` 121–145).

## Optional
- Cross-leg USDG vs Pendle matrix after hook pick.
- Explicit “budgeted arb ≠ \(P_{ext}\)-only mint.”
- Re-pin live pair/factory/`BOND_VEST`/Pendle YT **V6** / market **V7**.

**Owner:** O01–O05 first. **Engineering:** tax V2; facades; note liveness; roll atomicity.
