# Candidate register

Source proposals remain in `docs/research/uniswap-v4-zapin-plan-2026-09-27/`. They were not edited.

| ID | Equation tested | Domain used | Status |
|---|---|---|---|
| CF-R | Astra §5.2 quadratic, then production `SwapMath` to that sqrt price | One step, fee 0–10,000 pips, owned liquidity 0–100% | Refuted for 1 bp integer repair |
| CF-M | Pre-swap `ceil(shares * reserve / supply)` shortcut | One 3,000-pip swap | Shortcut refuted; full chain unresolved |
| CF-D | Exact output after CF-R | Inherited from CF-R | Not adoptable |
| CF-X | Astra §5.5 external redemption | Not executed | Unresolved |
| CF-B | `S - floor(sqrt(S^2 * (R-o) / R))` | 76 integer cases plus one production case | Refuted as a universal inverse |
| CF-U | Equal-burn plus CF-R | Not executed | Unresolved |
| CF-G | `1 - sqrt(1-q)` plus one extra forward check | 6 small cases plus the CF-B failure set | Two-check claim refuted |
| CF-Q | Quoter exact-output plus liquidity delta | Source audit | Refuted |

No corrected `CF-R2` was adopted. The 25 bp clamp was measured and left as a non-adopting observation.
