# Astra headline recheck

Rechecked 2026-10-26 from the equations in `members/astra/response.md`, not from a member program. This is not acceptance of the whole response and not a draft.

Zero-fee idle-target case: incumbent target 100, opposing 0, external virtual reserves 100 and 100, deposit 100, swap 50, gross executed-price mint. Recomputed opposing out `100/3`, attacker final target 105, incumbent close 95, pool back at 100 and 100. The stated identity `f*(1-f)*q^2/(x+f*q)` equals 5. Both tokens close.

Fee 0.3%, same sizes, gross credit, `f=1/2`. Recomputed `u=99700/2997` and final target `10470058473/99880180`, profit `4.826187467823946653`. Both match the stated fractions.

Domain limit, as Astra labeled it: old opposing inventory is zero in this witness. It does not replace the active-liquidity self-fill ledger in `research/EXECUTED.md`.
