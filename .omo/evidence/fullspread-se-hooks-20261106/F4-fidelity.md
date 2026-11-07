# F4 - Ideal-state and scope fidelity

Date: 2026-11-07. Disposition: requested scope complete.

| Ideal state | Final evidence |
|---|---|
| IS-1 Native component ownership | Six LP families use actual native components, post-paid trade books, ceil acceptance/floor claims and backed gross/net fee splitting; final component and invariant suites pass. |
| IS-2 Local-first rated swaps | Seven-family real swap controls and all 36 composed FullSpread routes pass; rates price trades, not LP ownership. |
| IS-3 Permitted disabled exits | Pair-output execution remains positive; prohibited minting or impossible share-only conversion rejects atomically without inventing mixed payout. |
| IS-4 Valid binding and implicit own shares | Nine real matrix configurations pass; configured pair membership and implicit own-share processing replace asset/self-membership assumptions. |
| IS-5 Consistent facades and consumers | Native SY, DETF, wrappers and exact selector controls pass in the full default suite. Missing sequential projection is explicit while actual supported execution remains positive. |
| IS-6 Traceable verification | All 48 dispositions, 36 original identities, 103 named active controls, gas, sizes, source/toolchain and review outcomes are reconciled. |

The user's per-leg pair-or-share genesis and continuing single-leg funding
clarification is implemented. The native-component hook interface is a
necessary explicit integration addition for three families, not a new
DETF funding model or reinterpretation of old join selectors. It removes
the repeated conversion of already-owned refunds that caused the bounded
gas failures. Each family retains its own curve and accounting.

No deprecated vault was restored, no FullSpread getRate or projection
interface was invented, no live package was upgraded and no safety claim
was inferred for same-backing-pool sequential composition. Existing
provider semantics, fee policy wiring, raw-liquidity issuance and declared
capability limits remain. The global test/vendor size exceptions are
explicitly retained outside the shipped product-size result.

The starting workspace was dirty. Unrelated changes and historical/V3
audit records were preserved; no project commit, push, destructive Git
operation, deployment or migration was made. Current source fingerprints
and toolchain are recorded in `57-source-identity.json`.
