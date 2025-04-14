RICHIRDFPkg

## Intent
- Deploy and configure the RICHIR rebasing ERC20 proxy (RICHIR) used by ProtocolDETF for protocol-owned rebasing token mechanics. Responsible for mint/burn orchestration and share<->balance conversions via live redemption rate.

What this package configures
## Proxy
- `IRICHIRProxy` (immutable production proxy; child proxy deployed/configured by ProtocolDETF package)
- Facets (high level): ERC20 views & mutators, redemption-rate calculation helpers, owner-only mint/burn helpers, preview helpers for redeem conversion.

## Facets
- `ERC20_FACET`
- `ERC5267_FACET`
- `ERC2612_FACET`
- `RICHIR_FACET`

## Trust boundaries
- As a child proxy typically deployed by `ProtocolDETFDFPkg.postDeploy()`, `processArgs()` MUST be gated to prevent arbitrary deployments that could break expected wiring. Deployments are normally done via the ProtocolDETF package — tests must assert only the expected deploying package can initialize if that is the intended pattern.

## Initialization
- Must initialize ERC20 metadata, repo pointers (RICHIRRepo), totalShares/initial rate, and owner (ProtocolDETF). If any permit/allowance flow is required for seeding, `initAccount()` must record approvals and require tests that DFPkg→proxy Permit2 flows behave correctly.

Post-deploy behavior (`postDeploy()`)
- Typical child proxy `postDeploy()` actions: set owner to ProtocolDETF, seed initial totalShares if needed, and persist any rate-provider pointers. `postDeploy()` must be callable only during the Diamond Callback Factory lifecycle hook and must be proven in tests to be uncallable by arbitrary EOAs/contracts thereafter.

Runtime invariants & mainnet requirements
## Proxy
- MUST be immutable (must NOT expose `IDiamondCut`).
- Redemption rate MUST be computed fresh on each call (NO cached redemption rate). Any view that computes `redemptionRate()` must read live state (ProtocolDETF preview/exchange calls) and not rely on stale caching.
- All preview->execution invariants must be enforced: e.g., `previewRedeem(x)` then `redeem(x,...)` on same state must satisfy `previewOut <= wethReceived` (exact-in/preview parity rules apply where appropriate).

Repo-wide invariants to copy from PROMPT.md (apply to this package)
- Deterministic deployments: use Crane Diamond Callback Factory for parent-driven deployments; any deploy-with-initial-deposit helpers must include adversarial front-run tests.
- Permit2 guidance: where RICHIR interacts with ProtocolDETF exchange flows, prefer Permit2 and document fallbacks in tests.
- No cached rates: already stated above — reaffirm that consumers must compute live redemption rates and tests must assert no cached-rate behavior.

Deterministic salts & squatting guidance
- Use Diamond Callback Factory deterministic flow via the parent package. If the RICHIR package exposes any deploy-with-initial-deposit helper, tests MUST include an adversarial front-run deployment scenario.

## Required tests
- (documented, not implemented here)
- Redemption math tests: shares<->balance conversions, rounding edge cases, preview vs execute parity, ensure no cached-rate usage.
- Owner-only mint/burn tests: `mintFromNFTSale` and `burnShares` call patterns, caller restrictions (ProtocolDETF only), and rounding invariants.
- Integration test: redeem forwards correctly to ProtocolDETF.exchangeIn and WETH is returned to recipient.

## Validation
- 
- Inventory reference: `docs/components/RICHIRDFPkg.md`
- PROMPT.md placeholder: `PENDING-MAINTAINER-REVIEW`

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
