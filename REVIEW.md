Header / Job
- I stated the agent’s job is a production-readiness review with a clear go/no-go and prioritized actionable findings for IndexedEx (Diamond + CREATE3 via Crane; high-stakes DeFi).
- Question: do you want “production ready” to mean “safe for mainnet with real value” or “safe for guarded beta (caps/allowlist)”?
CLARIFY: Production ready means ready for mainnet deployment. The deliverable for satisfying a error is one or more tests that prove the error has been fixed, or is incorrectly identified. This includes reviewing tests to identfty gaps 

What “Production Ready” Means (Definition)
- I defined production ready as meeting all of: correctness, security, deterministic deployment (no new), upgrade safety, test confidence, operational readiness, and frontend readiness (if shipped); any blocker => NOT READY.
- Questions:
  - Should “no known critical issues” also require an external audit sign-off, or is this strictly an internal engineering bar?
  CLARIFY: This is strictly internal.

  - For “frontend readiness”: is frontend/ actually shipped/critical to mainnet, or should it be out-of-scope unless explicitly requested?
  CLARIFY: The frontend will be shipped and is considered critical for mainnet.

Scope
- I included contracts/, Foundry tests, deployment tooling/scripts, frontend, and relevant Crane submodule patterns.
- Question: should the reviewer treat lib/daosys/ as trusted upstream (only check integration points) or in-scope for security review?
CLARIFY: No /lib/daosys and lib/daosys/lib/crane are not "trusteD". Those are custom tools we developed and should be included in the security and requirements review.

Hard Constraints / Project Conventions (Must Enforce)
- I hard-coded: never deploy with new in production paths; never enable viaIR; follow Crane Facet/Target/Repo and storage-slot conventions.
- Questions:
  - Is new acceptable in tests/stubs only (I assumed yes), and should that be stated explicitly?
  CLARIFY: Yes, test may use new for stubs and unit tests. But there must be test that integrate components with a production deployment pattern.
  - Is viaIR “never” for all environments, or only “never as a workaround” (I currently wrote “never”)?
  CLARIFY: Yes, viaIR is never to be used. It is forbidden in all cases. It inflates build times and acts a an indication that the code needs to be refined.

How To Raise Problems (Findings Format)
- I required each finding to include ID, severity, category, title, evidence, impact, scenario, recommendation, verification; included severity definitions and prioritization guidance.
- Question: do you want a fixed set of categories only, or should reviewers be allowed to add a repo-specific category like RegistrySemantics / Economic?
CLARIFY: Yes, reviewers are allows to add categories as they see fit if an existing category does not categorize a finding.

Required Outputs
- I required a single report with: Decision, Blockers, High Priority, Medium/Low/Info, and a concrete Release Checklist.
- Question: should the report also include a “Known Intent / Assumptions” section so reviewers explicitly state what they assumed about protocol behavior?
CLARIFY: Yes, reviewers should state their assumptions. We will use their statements to confirm understanding and as a way to correct reviewers.

Minimum Review Checklist (Use As Guidance)
- I listed security/correctness checks (reentrancy, approvals/Permit2, accounting, slippage, oracle trust, access control, upgrade safety, CREATE3, failure modes), plus testing and ops readiness and a small frontend list.
- Question: should economic/mechanism checks (peg dynamics, incentive edges, griefing vectors) be explicitly called out as first-class items, or is that out of scope for this prompt?
CLARIFY: Yes, these reviews should be as comprehensive as possible.

Suggested Commands (Run If Available)
- I suggested forge build, forge test, forge build --sizes and said only run more commands if they materially improve confidence.
- Question: do you want to require a fork test run (anvil fork) for certain packages (e.g., Balancer router paths), or keep it optional?
CLARIFY: Keep it optional, but the reviewer should review test quality and coverage. I want to know if any tests can be deprecated or improved. Tests can be deprecated if their scenario and assertions are covered by another test.

Repo-Specific Expectations (IndexedEx)
- I said the review must be grounded in actual proxy/package/facet surfaces, not “vibes”.
- No questions here—please confirm that framing is correct.

Source Of Truth: Proxy Surfaces
- I listed composite proxy interfaces in contracts/interfaces/proxies/*.sol and required checking DFPkg facetInterfaces()/facetCuts() consistency, selector coverage, and auth/invariants/events for each exposed selector.
- Questions:
  - Are these proxy interfaces intended to be exact ABI surfaces (no extra selectors), or is a superset acceptable if still safe?
  CLARIFY: Yes, the proxy interfaces are intended to be exact and full ABI surfaces for all function exposed by a proxy configuration. Gaps should be identified by the reviewer. Fo example, all proxy interfaces must inherit the IERC165, IDiamondLoupe, and IERC8109Introspection interfaces because ll proxies are configured to expose that functionality.

  - Should the reviewer treat any selector present on-chain but absent from these interfaces as a blocker?
  CLARIFY: Yes, all functions exposed by a proxy configuration MUST be included int he proxy function, preferably via inheriting the declaring interface.

Package (DFPkg) Composition Expectations
- I wrote “what must be configured” per DFPkg (manager/fees/registry, each DEX standard exchange pkg, Balancer router pkg, rate provider pkg, protocol vault pkgs, seigniorage pkgs), and emphasized processArgs() trust boundaries, initAccount() initialization completeness, and postDeploy() proxy-context + idempotence.
- Questions:
  - Are the listed facet/interface expectations meant to be normative requirements, or just “current intended composition” (i.e., can they drift without being wrong)?
  CLARIFY: Yes, they are normative. New Facets may be added to meet requirements is a gap is identified.

  - For postDeploy() idempotence: do you require it, or are one-shot postDeploy() flows acceptable if protected and tested?
  CLARIFY: The postDeploy() function is one-shot. It is only called once sure a proxy deployment by the Diamond Callback Factory.

Facet Inventory And What Each Is Expected To Do
- I enumerated every contracts/**/*Facet.sol and wrote what a reviewer should verify (interfaces/selectors, correct routing into proxies, strict access control, correct repo storage slot usage, view/query facets are non-mutating, preview vs exec parity, slippage/refunds, reentrancy, etc.).
- Questions:
  - For VaultFeeOralceQueryAwareFacet typo: is the misspelling intentional and stable (API surface), or should it be treated as a correctness/maintainability issue to fix?
  CLARIFY: yes, this a typo. It should be corrected to VaultFeeOracleQueryAwareFacet, including the file name and all imports. All similar misspelling should be identified for fix.

  - Should the prompt require every facet to have a matching TestBase_IFacet-style selector/interface compliance test, or is partial coverage acceptable?
  CLARIFY: Yes, there should be a TestBase_IFacet style test for every Facet. But this is low priority.

Registry Query Semantics (Append-Only Indexes)
- I added explicit expectations that some registry indexes are append-only and can return stale entries after unregister; reviewers must confirm which are append-only vs active-only, ensure consumers filter via isPackage/isVault, and raise risk findings if anything treats append-only sets as “active”.
- Question: is the append-only behavior an intentional long-term design (keep forever), or a temporary compromise you expect to change (in which case the prompt should treat it as a “known debt” rather than “expected behavior”)?
CLARIFY: Presume all registry indexes are active-only. Registries must have a owner restrict way to deregister an entry. And the registry indexes must be updated to remove deregistered members. Any gap should be identified. This requirement can only be overridden by a NatSpec comment of @dev tag that clearly states the registry is append-only and provided the reasoning why.

Inventory (Recent Findings)
- Source: file inventory via globs `contracts/**/*Target.sol`, `contracts/**/*Facet.sol`, `contracts/**/*DFPkg.sol`, `contracts/interfaces/proxies/*.sol`.

Proxy Composite Interfaces (contracts/interfaces/proxies) [9]
- IIndexedexManagerProxy.sol
- IVaultRegistryProxy.sol
- IVaultFeeOracleProxy.sol
- IFeeCollectorProxy.sol
- IStandardExchangeProxy.sol
- IBalancerV3StandardExchangeRouterProxy.sol
- IProtocolDETFProxy.sol
- IProtocolNFTVaultProxy.sol
- IRICHIRProxy.sol

Packages (DFPkg) (contracts/**/*DFPkg.sol) [12]
- Manager/Fee: IndexedexManagerDFPkg.sol, FeeCollectorDFPkg.sol
- DEX: UniswapV2StandardExchangeDFPkg.sol, CamelotV2StandardExchangeDFPkg.sol, AerodromeStandardExchangeDFPkg.sol
- Balancer V3: BalancerV3StandardExchangeRouterDFPkg.sol, StandardExchangeRateProviderDFPkg.sol
- Vaults: ProtocolDETFDFPkg.sol, ProtocolNFTVaultDFPkg.sol, RICHIRDFPkg.sol, SeigniorageDETFDFPkg.sol, SeigniorageNFTVaultDFPkg.sol

Facets (contracts/**/*Facet.sol) [43]
- Fee collector: FeeCollectorManagerFacet.sol, FeeCollectorSingleTokenPushFacet.sol
- Fee oracle: VaultFeeOracleManagerFacet.sol, VaultFeeOracleQueryFacet.sol, VaultFeeOralceQueryAwareFacet.sol (typo)
- Vault registry: VaultRegistryDeploymentFacet.sol, VaultRegistryVaultManagerFacet.sol, VaultRegistryVaultQueryFacet.sol, VaultRegistryVaultPackageManagerFacet.sol, VaultRegistryVaultPackageQueryFacet.sol
- Standard vaults:
  - basic: ERC4626BasedBasicVaultFacet.sol, MultiAssetBasicVaultFacet.sol
  - standard: ERC4626StandardVaultFacet.sol, MultiAssetStandardVaultFacet.sol
- Protocol vaults: ProtocolDETFBondingFacet.sol, ProtocolDETFBondingQueryFacet.sol, ProtocolDETFExchangeInFacet.sol, ProtocolDETFExchangeInQueryFacet.sol, ProtocolDETFExchangeOutFacet.sol, ProtocolNFTVaultFacet.sol, RICHIRFacet.sol
- Seigniorage vaults: SeigniorageDETFExchangeInFacet.sol, SeigniorageDETFExchangeOutFacet.sol, SeigniorageDETFUnderwritingFacet.sol, SeigniorageNFTVaultFacet.sol
- Standard exchanges: UniswapV2StandardExchangeInFacet.sol, UniswapV2StandardExchangeOutFacet.sol, CamelotV2StandardExchangeInFacet.sol, CamelotV2StandardExchangeOutFacet.sol, AerodromeStandardExchangeInFacet.sol, AerodromeStandardExchangeOutFacet.sol
- Balancer routers: BalancerV3StandardExchangeRouterExactInQueryFacet.sol, BalancerV3StandardExchangeRouterExactInSwapFacet.sol, BalancerV3StandardExchangeRouterExactOutQueryFacet.sol, BalancerV3StandardExchangeRouterExactOutSwapFacet.sol
- Balancer batch/prepay routers: BalancerV3StandardExchangeBatchRouterExactInFacet.sol, BalancerV3StandardExchangeBatchRouterExactOutFacet.sol, BalancerV3StandardExchangeRouterPrepayFacet.sol, BalancerV3StandardExchangeRouterPrepayHooksFacet.sol
- Balancer pool/rate provider: StandardExchangeRateProviderFacet.sol, DefaultPoolInfoFacet.sol, StandardSwapFeePercentageBoundsFacet.sol, StandardUnbalancedLiquidityInvariantRatioBoundsFacet.sol

Targets (contracts/**/*Target.sol) [33]
- Fee collector: FeeCollectorManagerTarget.sol, FeeCollectorSingleTokenPushTarget.sol
- Vault registry: VaultRegistryDeploymentTarget.sol, VaultRegistryVaultManagerTarget.sol, VaultRegistryVaultQueryTarget.sol, VaultRegistryVaultPackageManagerTarget.sol, VaultRegistryVaultPackageQueryTarget.sol
- Standard exchanges: UniswapV2StandardExchangeInTarget.sol, UniswapV2StandardExchangeOutTarget.sol, CamelotV2StandardExchangeInTarget.sol, CamelotV2StandardExchangeOutTarget.sol, AerodromeStandardExchangeInTarget.sol, AerodromeStandardExchangeOutTarget.sol
- Balancer routers: BalancerV3StandardExchangeRouterExactInQueryTarget.sol, BalancerV3StandardExchangeRouterExactInSwapTarget.sol, BalancerV3StandardExchangeRouterExactOutQueryTarget.sol, BalancerV3StandardExchangeRouterExactOutSwapTarget.sol
- Balancer batch/prepay routers: BalancerV3StandardExchangeBatchRouterExactInTarget.sol, BalancerV3StandardExchangeBatchRouterExactOutTarget.sol, BalancerV3StandardExchangeRouterPrepayTarget.sol, BalancerV3StandardExchangeRouterPrepayHooksTarget.sol
- Balancer vault integration: StandardExchangeSingleVaultSeigniorageDETFExchangeInTarget.sol
- Protocol vaults: ProtocolDETFBondingTarget.sol, ProtocolDETFBondingQueryTarget.sol, ProtocolDETFExchangeInTarget.sol, ProtocolDETFExchangeInQueryTarget.sol, ProtocolDETFExchangeOutTarget.sol, ProtocolNFTVaultTarget.sol, RICHIRTarget.sol
- Seigniorage vaults: SeigniorageDETFExchangeInTarget.sol, SeigniorageDETFExchangeOutTarget.sol, SeigniorageDETFUnderwritingTarget.sol, SeigniorageNFTVaultTarget.sol
