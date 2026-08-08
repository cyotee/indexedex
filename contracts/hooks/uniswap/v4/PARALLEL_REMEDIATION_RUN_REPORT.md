# Parallel Remediation Run Report — Uniswap V4 Hooks

**Date:** 2026-08-08  
**Orchestrator:** parent agent (≤3 concurrent implementers; linear main via rebase + `merge --ff-only`)  
**Final `main` tip:** `7a276ba292783d7861fdd4b2f64e48e26114fc54` (before this report commit)

---

## Program advances on `main` (linear, single-parent)

| Order | SHA | Summary |
|------:|-----|---------|
| (base) | `693543e` | feat(frontend): split indexedex and pachira Next apps |
| 1 | `cd61f6e` | refactor(hooks): rehome unbuffered quad stable as Curve product |
| 2 | `37887a6` | refactor(hooks): rehome SE quad stable buffer as Curve product |
| 3 | `4fee4a1` | docs: update cross-refs for Curve quad stable rehome paths |
| 4 | `1c5b1c0` | feat(h3): migrate weighted swap hook to Hook Diamond Package |
| 5 | `bac749a` | feat(hooks): greenfield Uniswap V4 Balancer quad stable swap hook (unbuffered) |
| 6 | `e4da203` | feat(h5-single-se-cp): B6 SE-share LP deposit and withdraw |
| 7 | `f009f3e` | feat(h6): Dual SE CP B6 SE-share LP + M3 IStandardExchange surface |
| 8 | `2a76b5f` | feat(hooks): SE Balancer Quad Stable Buffer Hook Diamond Package |
| 9 | `213bc74` | feat(h7): SE Orbital min ≥1 SE + B6 SE-share multipath LP |
| 10 | `5864ec0` | feat(h9-curve-se-stable): B6 SE-share LP + firm MultiAsset join/exit |
| 11 | `7a276ba` | feat(h8): SE Weighted Buffer B6 SE-share LP + firm multi-asset paths |

No merge commits in the program range. Frontend commits interleaved before Wave 1 Curve (expected).

---

## Effort status table

| Effort | Branch | Worktree (`…/indexedex-worktrees/`) | Status | Tip SHA | Notes |
|--------|--------|--------------------------------------|--------|---------|-------|
| W1-CURVE | `remediation/wave1-curve-rename-move` | `wave1-curve-rename-move` | **INTEGRATED** | `4fee4a1` | Production under `stable/quad/curve/` + `standardExchange/stable/quad/curve/`; hermetic 53+52 green |
| W1-H3 | `remediation/h3-weighted-diamond-package` | `h3-weighted-diamond-package` | **INTEGRATED** | `1c5b1c0` | Hook Diamond Package; monomorph retired; 60 green |
| W2-BAL-UNBUF | `remediation/balancer-quad-stable-unbuffered` | `balancer-quad-stable-unbuffered` | **INTEGRATED** | `bac749a` | Greenfield Balancer StableMath AMP 1e3; 52 green |
| W2-BAL-SE | `remediation/se-balancer-quad-stable-buffer` | `se-balancer-quad-stable-buffer` | **INTEGRATED** | `2a76b5f` | SE buffer + B6; 59 green |
| W2-H5 | `remediation/h5-single-se-cp-b6` | `h5-single-se-cp-b6` | **INTEGRATED** | `e4da203` | SE-share LP deposit/withdraw; 54 green |
| W2-H6 | `remediation/h6-dual-se-cp-b6-m3` | `h6-dual-se-cp-b6-m3` | **INTEGRATED** | `f009f3e` | B6 + M3 SE surface; 29 green |
| W2-H7 | `remediation/h7-se-orbital-min-se-b6` | `h7-se-orbital-min-se-b6` | **INTEGRATED** | `213bc74` | Min ≥1 SE + B6 flexible LP; 72 green |
| W2-H8 | `remediation/h8-se-weighted-b6-firm` | `h8-se-weighted-b6-firm` | **INTEGRATED** | `7a276ba` | Re-dispatched after stash loss; 62 green |
| W2-H9-CURVE-B6 | `remediation/h9-curve-se-stable-b6-firm` | `h9-curve-se-stable-b6-firm` | **INTEGRATED** | `5864ec0` | After Curve paths on main; firm + B6; 67 green |
| W3-DOCS | `remediation/v4-hooks-docs-reconcile` | — | **INTEGRATED** | (this report) | Program run report only |

---

## FAILED / SKIPPED

None for remediation efforts. All W1–W2 efforts INTEGRATED.

---

## Protocol confirmations

1. **Concurrency:** live implementer subagents never exceeded **3**.
2. **Linear main:** all integrations used **rebase → `git merge --ff-only` only**; no force-push; no non-ff merges in program range.
3. **Wave 1 Curve first:** Curve INTEGRATED before path-sensitive Wave 2 (Balancer under `balancer/`, H9 on `curve/` tree).
4. **Frontend:** frontend worktree/branches not destroyed or used for hook work; frontend commits landed on main before Curve and were rebased under.
5. **Forge cache:** worktrees seeded from PRIMARY `cache_forge/` + `out/` after create.

---

## Remaining manual steps (operator)

1. Push `main` when network available (`git fetch`/`push` may fail with DNS to github.com).
2. Optionally commit untracked compliance reports / execution guide still dirty on operator PRIMARY working tree.

---

*End of run report.*
