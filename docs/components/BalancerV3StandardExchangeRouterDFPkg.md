BalancerV3StandardExchangeRouterDFPkg

## Intent
- Deploy and configure the Balancer V3 Standard Exchange router proxy used to route queries and execute swaps against Balancer pools on behalf of users and other protocol components.

What this package configures
## Proxy
- `IBalancerV3StandardExchangeRouterProxy` (immutable production router proxy)
- Facets (high level): sender-guard, ExactIn/ExactOut query facets, ExactIn/ExactOut swap facets, Prepay + PrepayHooks, Batch router facets, Permit2 wiring, WETH sentinel helpers.

## Facets
- `SENDER_GUARD_FACET`
- `BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_QUERY_FACET`
- `BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_QUERY_FACET`
- `BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_SWAP_FACET`
- `BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_SWAP_FACET`
- `BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_FACET`
- `BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_HOOKS_FACET`
- `BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_IN_FACET`
- `BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_OUT_FACET`

## Trust boundaries
- This package MAY leave `processArgs()` ungated because router deployments are deterministic via the Diamond Callback Factory and are non-vault. Still review for squatting risk on any deploy-with-initial-deposit helper.

## Initialization
- Must set Balancer Vault address, Permit2 repo pointer, WETH sentinel/address, and any router-level gas/limit defaults.
- Must initialize sender-guard and prepay hook repo entries and ensure `facetInterfaces()` ordering matches `facetAddresses()` comment where present.

Post-deploy behavior (`postDeploy()`)
- Typical routers have no unsafe postDeploy configuration. If present, `postDeploy()` must be constrained to the Diamond Callback Factory lifecycle hook and/or the expected proxy context and proven with tests that arbitrary callers cannot mutate state post-deploy.

Runtime invariants & mainnet requirements
- Router proxy MUST be immutable (must NOT expose `IDiamondCut`).
- Permit2 is mandatory for router swap flows (no ERC20 approve fallback allowed in router flows). Ensure `initAccount()` wires Permit2 correctly.
- Swaps are Permissionless: any caller may call swap entrypoints. Tests must include adversarial caller patterns and malformed-path inputs.
- Prepay routes intentionally marked Permissionless; prepay hooks that read/write Balancer hooks must enforce Vault-only auth where required (e.g., hooks receiving `unlock`/`settle` calls).

Repo-wide invariants to copy from PROMPT.md (apply to this package)
- Preview policy: all router preview/query facets MUST satisfy the exact-in/exact-out preview inequalities when they map to execution routes; fuzz tests must assert preview <= execute (exact-in) and previewIn >= executeIn (exact-out).
- Permit2 mandatory: router flows must require Permit2 (no ERC20 approve fallback). Tests must assert reverts when Permit2 allowance is missing.
- Deterministic deployments: use Crane Diamond Callback Factory; any deploy-with-initial-deposit helpers must include adversarial front-run tests.

Deterministic salts & squatting guidance
- Use the Diamond Callback Factory flow exclusively. If a deploy helper accepts a beneficiary and seeds liquidity, tests MUST include an adversarial front-run deployment scenario to prove no squatting advantage.

Preview / execution invariants
- All query facets must obey global preview policy (exact-in: `previewOut <= executeOut`; exact-out: `previewIn >= executeIn`). Document permitted buffers (if any) and require fuzz/invariant tests proving conservatism.

## Required tests
- (documented, not implemented here)
- Production-pattern deployment test: deploy pkg via CREATE3 and `IDiamondPackageCallBackFactory.deploy`, exercise `initAccount()` and ensure immutable runtime surface (no `IDiamondCut`).
- Permit2 enforcement tests: ensure router swap flows require Permit2 and revert when Permit2 allowances are not present.
- Adversarial swap tests: malformed paths, malicious sender, reentrancy attempts, prepay refund edge-cases.
- Prepay hooks: Vault-only hook auth tests proving only the Balancer Vault (or designated hook caller) can invoke protected hooks.

## Validation
- 
- Inventory reference: `docs/components/BalancerV3StandardExchangeRouterDFPkg.md`
- PROMPT.md placeholder: `PENDING-MAINTAINER-REVIEW`

## postDeploy() / Post-deploy behavior
- PENDING-MAINTAINER-REVIEW
