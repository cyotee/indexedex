# Pilot exit — Stage 1 Security Audit

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Mode | **pilot** — MODE=full **not** started |
| Law | `docs/security/SECURITY_AUDIT_EXECUTE_PLAN.md` §6 · `SECURITY_AUDIT_PRD.md` §15.2 |

## Execute-plan §6 / PRD §15.2 checklist

- [x] Three pilot area reports present and **COMPLETE**
  - `docs/security/audit/areas/A-commons-pull.md`
  - `docs/security/audit/areas/A-detf-multi-vault.md`
  - `docs/security/audit/areas/A-se-amm-v2.md`
- [x] Two specialist reports present and **COMPLETE**
  - `docs/security/audit/specialists/S-sharp-edges.md`
  - `docs/security/audit/specialists/S-crops-trust.md`
- [x] Each area report has PRD §7.2 headings 1–11
- [x] Each specialist report has PRD §7.4 headings 1–6
- [x] Thin `AGGREGATE.md` exists
- [x] `WORK_PACKAGE_BACKLOG.md` exists with **≥5** real WPs (10 listed; 8 High this-program + 1 Medium ABI + 1 later CROPS)
- [x] OWNED_ELSEWHERE used (I-ABS helper, MultiVault I/J/K, Uni V2 I/J/ADV, Uni V3 clones, fee/manager J)
- [x] Schema issues addressed (finding IDs `SEC-*`; severity Critical/High/Medium/Low/Info; no “Blocker” label)
- [x] Runtime attempt on PAT-I-ABS at **current SHA**

## Runtime proof (criterion 4)

**Chosen path:** new repro **plus** SHA-checked historical file.

| Item | Value |
|------|--------|
| SHA | `1e0d7c48` |
| Historical | `docs/testing/coverage-audit/repro/TCA-COMMON-001/` — **stale** (2026-08-09 theater PASS on free credit) |
| New | `docs/security/audit/repro/SEC-COMMON-001/{COMMANDS.md,notes.md,forge.log}` |
| Command | `forge test --match-path 'test/foundry/spec/vaults/basic/**' --match-test 'test_I1_|test_I2_|test_I3_|test_secureTokenTransfer_pretransferred' -vv` |
| Outcome | **9 passed; 0 failed** — I1 reverts on booked inventory with no inbound transfer. Label: **not reproducible** as live Critical CODE (exploit **blocked**). |

## Summary for the owner

### Residual-risk scores

| Product | Score |
|---------|------:|
| BasicVaultCommon token pull | 4 |
| BasicVaultCommon self-burn / E6 | 2 |
| MultiVaultWeightedDetf | 3 |
| Aerodrome V1 SE | 3 |
| Camelot V2 SE | 2 |
| Uniswap V2 SE | 2 |

### Counts

| Metric | Value |
|--------|------:|
| Critical | **0** |
| High CODE (this program) | E6 commons, E6 SE, Camelot Out, Route4, A0/LP-deposit, PkgArgs; CROPS disable (mostly full-pass families) |
| High TEST | MultiVault A0; Uni V2 I/J still coverage-owned |
| OWNED_ELSEWHERE | Historical I-ABS + MV I/J/K + SE I/J/ADV + Uni V3 clones + fee/manager J |

### Top WPs (`sec_fix_*`)

1. `WP-SEC-E6-COMMON-001` (Wave 0, serial)
2. `WP-SEC-CAM-OUT-001`
3. `WP-SEC-E6-SE-001`
4. `WP-SEC-R4-SE-001`
5. `WP-SEC-A0-SE-001` / `WP-SEC-I-SE-4626-001` (pack per In Target)
6. `WP-SEC-PKG-MV-001`
7. `WP-SEC-DETF-MV-A0-001` (TEST)

### Stop

Pilot exit **passed**. Do **not** start MODE=full in this goal. After owner accept: new `/goal` for full pass (`SECURITY_AUDIT_EXECUTE_PLAN.md` O5–O7) or a thin Stage 2 using `PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md` on **pilot High WPs only**.
