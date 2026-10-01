# Derivations checked

## CF-R

At zero fee the candidate inventory identities reduce to conservation:

```text
T0 = F0 - x + l * (1/t - 1/b)
T1 = F1 + y + l * (t - a)
x = L * (1/t - 1/s)
y = L * (s - t)
```

The quadratic is the position-ratio condition `T0 / T1 = amount0(t) / amount1(t)`. That continuous identity was not disproved. Integer execution was.

Production `SwapMath` charges the fee with `mulDivRoundingUp` and moves the price with rounded sqrt-price deltas. At 3,000 pips and full vault ownership, the rounded step misses the position ratio by 2 bp. At 10,000 pips the Python forward model missed by 8–9 bp. Those are outside the accepted 1 bp bound.

The fixture's unconstrained root moves price by about 465 bp. The 25 bp cap is therefore binding. Clamping the terminal sqrt price to that cap is a closed expression, and the production swap reduced mismatch, but only from 1,840 bp to 1,747 bp.

## CF-B and CF-G

`_singleExit` floors both entitlements and the conversion separately. A single radical does not invert every integer input. The production counterexample is supply 100, reserves 50, output 12. A two-evaluation check also fails for supply 1,000, reserves 50, output 5, where both neighboring candidates return 3.

## CF-Q

A closed form cannot call a search. The pinned quoter continues while output remains and the price limit has not been reached. That is route search, regardless of wrapping the result in one unlock.

## Not established

No derivation here proves that no combined closed form exists. It proves that these candidates do not meet the integer and protection requirements on the tested domain.
