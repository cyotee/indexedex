# Consumer status

`family-suite-complete.log` passed the Wings consumer tests. No existing consumer or DETF production source was edited.

Passed money paths, not every legal mask:

- Weighted two-leg masks 1, 2 and 3, same and different PoolManager
- Weighted arities 3 through 7, alternating mask, same manager
- Homogeneous eight Wings legs, both manager relations
- Orbital, Curve quad, Balancer quad, single constant-product and dual constant-product, each bound to a Wings vault, join and share exit
- Funded V4 DETF bond against a Wings reserve vault

`fullspread-pons-controls.log` reran unchanged FullSpread Hookless and Pons-family quote/execution parity: 12 passed, 0 failed.

Still pending: every other legal weighted/Orbital/quad/CP mask, mixed existing SE families beyond the adapter's second identity leg, and a live outer receipt. Slipstream remains deprecated. A funded DETF cannot add an eighth Wings leg to a mandatory raw DETF leg.
