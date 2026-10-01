# Astra — One combined hook-package cross-review

**Date:** 2026-09-27. Read all three complete unchanged originals together, as untrusted evidence, and checked disputed claims directly against executable source. No peer cross-review read; original preserved. No shell, tests, code/config changes or delegation.

## Final recommendation

Proceed with **two thin, distinctly named package products over one shared FullSpread implementation**: Hookless and the exact reviewed Pons V2 integration. Keep `PkgArgs { PoolKey }` and existing money interfaces. Bind expected hook, manager and reviewed implementation provenance at package construction/admission; do not make them caller-selectable instance arguments. Reuse identical facets/delegates only when their actual compiled behavior and immutable dependencies are identical. Use one strict shared quote implementation supporting these two admitted models; unknown or invalid nonzero-hook models must revert, not return a vanilla amount.

No global one-vault-per-pool constraint is required. No new fee type, arbitrary custom CREATE3 namespace, Pons ABI “version field,” blanket zero-LP-fee condition, or eight-item owner questionnaire is necessary. The concrete production Pons address/revision/manager tuple remains a deployment input to establish, not an invitation to redesign the approved economics.

### Path abbreviations

**F/** = `contracts/vaults/standard/exchange/protocols/uniswap/v4/`; within it, file suffixes refer to `UniswapV4FullSpreadStandardExchangeVault...sol`. **C/** = `lib/crane/contracts/`. **PonsHook** = `C/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol`.

## Corrections verified directly

### 1. CREATE3 reuse: same name plus different constructor does NOT create a new package

F/Component_FactoryService:174–187 supplies exactly `abi.encode("UniswapV4FullSpreadStandardExchangeVaultDFPkg")._hash()`, without another hash layer. `C/factories/create3/Create3Factory.sol:151–178` checks the predicted address and **returns existing code** if occupied. It neither reruns the constructor nor reaches the low-level creation primitive that might revert on collision.

Thus Kimi's “reuse reverts” claim is wrong for the actual factory wrapper. MiniMax's claims that new compiled libraries can be installed behind unchanged facet salts are also wrong: existing code stays unchanged. Its occasional double-hash salt expression is not the source formula.

Current production name-only law (`docs/create3-release-salt-input-correction.md:35–36,53–57`) does not permit Kimi's `"<name>:<family>"` production salt aliases. **Choose two actual concrete contract identifiers**, sharing a base. This resolves identity without a new salt-policy choice. Verify expected runtime/constructor bindings when an occupied component is returned; fingerprints are checks, not salt inputs.

### 2. Actual instance deployment includes the package address

Follow the execution, not interface comments:

1. F/DFPkg `deployVault` forwards through registry.
2. `contracts/registries/vault/VaultRegistryDeploymentTarget.sol:64–76` invokes the configured **ordinary DiamondPackageFactory** `.deploy(pkg,args)`.
3. `C/factories/diamondPkg/DiamondPackageCallBackFactory.sol:201–218` evaluates `pkg._calcSalt(args)`, then explicitly sets `salt = keccak256(abi.encode(pkg, salt))` before CREATE2 prediction.

The package address therefore contributes to the actual proxy identity. F/DFPkg:253–255 hashes PkgArgs, so these arguments contribute through that call too, despite the factory comment saying it does not directly use them.

Kimi's contrary assertion comes from `IVaultRegistryDeployment.sol:57–62`, which describes **deployHookVault**, a separate hook-diamond factory path—not the FullSpread SE path. The initial two package admission predicates are disjoint, but that is not what prevents an address collision.

MiniMax also misstates registry authorization: `VaultRegistryDeploymentTarget.sol:44–47` makes `deployPkg` **onlyOwnerOrOperator**; `deployVault` separately checks owner/operator/registered-package authorization and package registration. It is not permissionless package deployment.

### 3. No global one-vault-per-pool rule

Reject Grok's proposed rule “so two packages cannot both book the same pool.” Distinct vaults do not book the pool's entire liquidity. F/Common:456–459 reads the managed position using **address(this)**, ticks and salt. `C/protocols/dexes/uniswap/v4/libraries/Position.sol:35–61` includes owner in the position key. Two vault addresses can own independent positions in the same pool without double-booking.

Same package and same arguments are already idempotent at the existing proxy address. Different package versions can create separate vaults legitimately. A global restriction would be new product scope and needlessly constrain successors. A test cannot successfully deploy the exact same PoolKey through both initial Hookless/Pons packages because one predicate must reject it; use compatible successor package fixtures to test cross-package identity when needed.

### 4. Reuse is conditional; quote behavior is compiled, not magically replaceable

Kimi overstates “all facets/delegates reusable verbatim across every hook family.” Common directly calls internal QuoteService routines (for example Common:103–109), and QuoteService:18–57 contains Pons-specific parsing and arithmetic. These dependencies are part of the compiled artifacts. InTarget:32–35 also has a constructor-immutable execution delegate; a package cannot replace it by supplying unrelated PkgInit data.

MiniMax correctly identifies source coupling, but incorrectly concludes that changing the internal library leaves the deployed facet unchanged while somehow changing its behavior. Internal library code is compiled into its consumers; a different source model requires rebuilding affected artifacts and explicit new deployment identity where existing code is occupied. There is no deployable swappable QuoteService instance in the current design.

For **these two initial models**, sharing is practical: one updated, strict dual-model quote implementation can serve both package-pinned domains. Grok's preference for separate quote facets is viable but unnecessary for the user's reuse objective, and quote dependencies reach more than obvious Query-named files. Future incompatible models need actual consumer/delegate analysis, not “replace only query facets” by assumption.

**Refinement of my original:** an additional persistent profile ID/model-dispatch storage field is optional, not required for the initial split. Exact package admission plus the existing immutable-in-use PoolKey gives sufficient initial model discrimination for a strict hookless/Pons shared helper. Expose package binding metadata for discovery; do not add per-vault configuration solely for generality.

### 5. Pons `info[0]` is registration, NOT version

PonsHook:48–67 defines the getter fields. The 13 ABI return words are:

- `info[0]`: `registered` boolean;
- `info[1]`: `memecoinIsCurrency0` boolean;
- `info[2]`, `[3]`: memecoin and quote token;
- `info[7]`: creatorTaxBps;
- `info[10]`: hookFeeBps;
- `info[12]`: buybackEnabled.

MiniMax's version/layout interpretation and reversed fee fields are wrong. `info[0]==1` proves the decoded registration flag, not “Pons V1/V2/V3.” A bool encoded as 2 is not a meaningful future-version convention. Use exact hook deployment and reviewed runtime provenance for version identity, not an imagined schema version.

Grok is also wrong that feeEscrow is storage: PonsHook:121 declares it **immutable**. Owner and various operational settings are storage. Address/codehash checks remain sensible, but constructor immutables are reflected in the deployed runtime and must be included in artifact verification. A codehash alone does not establish owner/storage state or proxy implementation semantics.

### 6. Frozen fee terms versus mutable state

PonsHook:355–403 rejects re-registration and snapshots pool fee terms. Existing `_afterSwap` reads those launch terms, not global defaults. MiniMax's proposed mid-flight existing-pool fee drift test using `setHookFeeBps` is incorrect. The 10 bp shortfall protection is not a general guarantee accommodating arbitrary owner fee changes.

Not all LaunchInfo fields are immutable: `setCreatorFeeRecipient` changes creator routing (:415–422), and `setBuybackEnabled` changes the flag (:434–437). These do not change the two swapper charge rates. Independent sweeps/buybacks and live directional protocol fees can still change pool state/quotes.

Kimi's statement that quote-model bounds exactly match the hook is also too broad: F/QuoteService:35 allows hookFeeBps up to 2000, whereas PonsHook:69–74 caps it at 1000 and total trade charge at 2000. Align a pinned model to its real revision.

### 7. The fallback is not fail-closed

Kimi's recommendation to retain `_adjustHookSwap` verbatim contradicts its claimed fail-closed behavior. QuoteService:55 explicitly returns the unchanged amount on unsupported nonzero hooks. Common:103–109 gates **inventory snapshots**, not every ordinary quote call. Change the shared protected model to reject an invalid nonzero Pons model; do not rely on initialization to convert a return-unchanged fallback into a revert.

Both packages still use live protocol fees, actual fills, settled deltas, own-position fee accounting and complete local booking. Hookless/Pons identity does not alone establish quote correctness. Pons LP fee zero in a fixture does not prove the core model requires zero: the quoter already composes LP and protocol fees. Do not add Kimi's zero-fee-only restriction without a real integration-domain requirement.

## Minimally disruptive concrete architecture

- Two thin named concrete DFPkgs over a shared new-tree package base; unchanged `deployVault(PoolKey)` and PoolKey-only PkgArgs.
- Package constructor binds exact expected hook and infrastructure. Hookless uses zero; Pons uses the reviewed chain-specific direct hook deployment, runtime fingerprint and same PoolManager. Validate exact equality, code, manager, structural flags, registered launch and token orientation before initialization commits approvals/storage.
- Keep common facet sets/delegates reusable where bytecode and immutable bindings match. One strict initial dual-model quote helper; no external arbitrary adapter or runtime hook list needed.
- Preserve the existing shared V4 usage-fee type, sleeve defaults and standard interfaces. Registry package-address sets already support coexistence; discovery uses package identity plus binding metadata, not a first-match interface lookup.
- Keep authorized PositionManager/import PoolKey checks and add/retain manager consistency. Package registration is curator-controlled; spoofed expected-codehash constructor inputs are not an independent trust root. Deployment manifests must identify reviewed artifacts, not merely accept any codehash the deployer supplies.
- Preserve all existing owner requirements, especially disabled combined exact-output, 25/50/10/1 bp, maintenance stopping/progress, repeatability, pretransfer and full booking. No old-source edits, live rewiring or migration.

## Remaining evidence and dissent

The user's preference supplies the architecture direction; do not ask eight discretionary questions about test location, interface naming, or enforcement layering. Obtain the exact initial Pons deployment/manager/revision manifest and validate it. No global duplicate-pool policy or salt-policy exception is necessary with named wrappers.

Unresolved design preference: Grok prefers separate quote facets; I recommend shared strict compiled models for these initial packages, with source-level dependency and runtime-size checks determining when future versions must split. Kimi's generic-artifact/custom-salt proposal conflicts with current salt law. MiniMax's widened PkgArgs and new facet/library scheme are unnecessarily disruptive and internally inconsistent.

Confidence is **high** on the executable deployment path, CREATE3 reuse, position ownership, Pons field meanings and mutability. Runtime-size feasibility, exact deployed Pons artifact provenance and complete integration safety remain unverified. Context7/primary-source API evidence from the independent pass remains dated 2026-09-27; these disputes were resolved against direct local implementation reads. No tests or security/economic-soundness claim is made.
