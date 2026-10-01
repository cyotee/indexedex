# Hook-specific FullSpread V4 packages — council consolidation

Date: 2026-09-27. Research/documentation only. No code, tests, deployments or migrations executed.

## Subsequent owner correction — supersedes shared-family recommendations below

**Later deprecation/removal ruling:** the owner made legacy deprecation and source deletion part of this same effort. Once both new families are implemented, tested and considered ready for security-audit submission, remove the legacy vaults in `contracts/protocols/dexes/uniswap/v4/` and the unsegmented vault components in `contracts/vaults/standard/exchange/protocols/uniswap/v4/`, retaining the entire `hookless/` and `ponsFamilyV2Hook/` subtrees. PRD D24/§3.1 now govern the gate, removal inventory, historical evidence and post-removal validation. Earlier statements below requiring indefinite old-source retention or separately deferred deprecation are superseded for this gated work. No deletion occurred during this documentation update; no live migration/deactivation or completed audit is implied.

The owner explicitly rejected shared strict Hookless/Pons logic. The two packages must have **separate family-specific implementations**, not thin admission wrappers over a common Hookless/Pons dispatcher:

- `UniswapV4HooklessStandardExchange` components under `contracts/vaults/standard/exchange/protocols/uniswap/v4/hookless/`.
- `UniswapV4PonsFamilyHookStandardExchange` components under `contracts/vaults/standard/exchange/protocols/uniswap/v4/ponsFamilyV2Hook/`.

Generic hook-independent infrastructure/primitives may still be reused; family fee, quote, validation and execution logic remain separate. Earlier shared quote/runtime recommendations in this report and the researcher artifacts are historical and **not implementation instructions**.

Production PoolManager is fixed by `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol`, `UNISWAP_V4_POOL_MANAGER` (line 169 at inspection: `0x8366a39CC670B4001A1121B8F6A443A643e40951`, chain 4663). The owner-selected Pons source is `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/`. This supplies the reference generation and manager, not an independently verified deployed hook address. The PRD was updated to reflect the correction in D22–D23 and §10, including separate-family acceptance requirements. No code or new council round was executed for this decision-recording update.

## Decision and recommendation

The owner's latest direction is to make Uniswap V4 Standard Exchange packages integration-specific: initially hookless and a specific Pons hook, then additional packages for future supported hooks, reusing compatible facets. **Recommend this architecture.** It resolves arbitrary-hook admission ambiguity by reducing each package's supported domain to one explicitly tested integration. It does not prove the integration model correct or waive runtime protections.

The moderator recorded that direction in the target PRD as revised D14, new D22 and §10, with updated acceptance/specification requirements. The prior generic deployer-assurance admission rule is superseded explicitly. No mutable administrator hook list is introduced. Combined exact-output remains disabled; approved execution limits, maintenance policy, pretransfer law and full booking remain unchanged.

## Concrete architecture

1. Two thin, distinctly named concrete packages over shared FullSpread package/runtime components. Do not duplicate vault economics simply because admission differs.
2. Hookless package requires `PoolKey.hooks == 0`.
3. Pons package requires its fixed expected hook address, the reviewed revision/deployment provenance, matching PoolManager, and valid registered pool metadata/fee schema. The inspected local V4 integration is Pons V2; do not identify it solely through flags or `launches()` ABI.
4. Keep instance arguments centered on the PoolKey. An instance deployer must not supply its own trusted hook/codehash and thereby redefine the package's compatibility promise.
5. Shared facets and delegates are allowed when the actual compiled behavior and immutable bindings are identical and support the admitted integrations. A shared strict Hookless/Pons quote implementation is sufficient in principle; split runtime components only where a model/dependency requires it. No unknown-hook vanilla fallback.
6. Expose enough package binding metadata for callers to choose by package address, hook and PoolManager. Do not select the first registry package with a common interface ID.
7. New hooks/revisions require explicitly reviewed package identities; no runtime widening of existing instances. No automatic migration or deletion of old vaults.

## Deployment identity: important verified constraints

`docs/create3-release-salt-input-correction.md:35–36,53–57` specifies component-name-derived production salts. Changed constructor arguments do not select a new identity; occupied-salt deployment returns the existing contract with unchanged bindings. Researchers verified the same behavior in `lib/crane/contracts/factories/create3/Create3Factory.sol:151–178`.

Thus, **do not repeatedly deploy the same named package with different expected-hook arguments and assume each is distinct**. Use distinct concrete package identifiers under current salt law. A thin named wrapper may share essentially all implementation logic and all compatible facets. Supporting arbitrary same-contract multi-configuration production deployment would require an explicit separate salt-policy change; none is recommended here.

The actual ordinary vault proxy path namespaces by package address:

`lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol:201–218`

computes `keccak256(abi.encode(pkg, pkg.calcSalt(args)))`. The no-package-in-salt comment for the separate hook-diamond path does not govern these SE vaults. No new global one-vault-per-pool restriction is needed. Each vault owns a distinct position, and sharing facets does not share its storage or balances.

Facet reuse does not allow changing immutable constructor dependencies: the current FullSpread InTarget embeds its execution-delegate address (`UniswapV4FullSpreadStandardExchangeVaultInTarget.sol:32–35`). Replacing a compiled internal quote library likewise changes consumer bytecode; it cannot be installed at an occupied component identity simply by replaying constructor arguments.

## Pons model and residual obligations

Directly inspected local hook: `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol`.

- `:48–67`: `LaunchInfo` field 0 is **registered**, not a version number. Creator tax is word 7; hook fee is word 10.
- `:70–74`: hook fee ceiling is 1000 bp; total trade charge ceiling is 2000 bp.
- `:480–524`: the swap charges two separately floored amounts on the unspecified leg. Do not combine rates before flooring or confuse these charges with the pool LP fee.
- Researchers verified registration snapshots at `:355–403`; global fee setters affect future registrations, not existing launch trade terms. Recipient/buyback configuration at `:415–437` is mutable, so it is incorrect to call all launch state frozen.

Pin the exact hook deployment/revision/PoolManager tuple and record reviewed code provenance. Runtime codehash is useful corroboration for the inspected direct nonproxy deployment; a proxy's own codehash alone would not pin an upgradeable implementation. Codehash-only matching is not a substitute for the expected address/manager binding.

Keep live directional protocol fee accounting, own-position fee recovery, actual-fill checks and approved protections. Package identity removes the need to support arbitrary hooks; it does not eliminate price movement, mutable external dependencies, callback failures or integration testing.

The specific Pons launch factory uses zero LP fee. Whether the package additionally enforces that launch provenance/zero-fee constraint belongs in the exact pinned integration specification; it must not be mistaken for a new general fee ceiling. No fabricated production address or assumed network deployment is supplied here.

## Attributed originals and cross-review

All four originals favored package separation. Their details differed:

- **Astra:** shared core with two named packages; highlighted occupied CREATE3 salt reuse and immutable delegates. Cross-review removed its initially suggested extra profile storage as unnecessary for the first two models.
- **Grok:** favored distinct packages, initially separate quote facets and a global one-vault-per-pool rule. Cross-review withdrew the global rule and accepted shared strict facet/delegate code. Recommends the Pons zero-fee binding.
- **MiniMax M3:** favored package split with family-specific quote code and initially eight owner questions. Corrected its registration/version and instance-salt readings, but still proposes unnecessary instance-supplied trust fields and broad facet duplication. Neither is adopted by the moderator. Its earlier claim that D21 means add/remove-only also contradicts approved D9 swapping repair and is not adopted.
- **Kimi K3:** favored shared runtime and one configurable package artifact. Corrected its instance-salt and CREATE3-redeploy claims and withdrew custom family salt strings in favor of actual named packages. Still recommends unchanged quote fallback as unreachable under admission; the moderator prefers explicit failure for an unexpected or invalid model.

**Agreement:** package-specific hook identity and compatible facet reuse are appropriate; constructor/salt identity must be handled explicitly; Pons launch trade terms are snapshotted; package address affects ordinary proxy identity; existing economic decisions stay intact.

**Remaining design dissent:** whether to split quote facets immediately versus use shared strict quote logic. Recommendation: shared strict logic initially, specialized components only when needed. No verified numerical count of reusable facets is adopted; compiler dependency and runtime-size evidence determine actual reuse. Package identity is not a safety proof.

## Evidence and limitations

Moderator directly read current task PRD, canonical Crane architecture/deployment skills, Pons router/architecture skill, salt law, the actual proxy deployment function and Pons field/fee implementation. Current family law was reviewed by the researchers. Context7 `/uniswap/v4-core` corroborated hook callback/return-delta semantics; primary PoolId source was consulted by researchers:

- https://context7.com/uniswap/v4-core/llms.txt
- https://github.com/Uniswap/v4-core/blob/main/src/types/PoolId.sol

Access date: **2026-09-27**. Upstream main is not a deployment pin. Observed configuration in retained source/research: Solidity 0.8.35, optimizer runs 1, via-IR false. Installed runtime/compiler execution and live hook addresses were not verified this round. Canonical Pons skill's network deployment narrative is not substituted for current on-chain evidence.

Confidence: high on source-level architecture, deployment identities and reviewed Pons arithmetic; medium on complete consumer/integration coverage; no executed validation or security guarantee.

## Preserved sessions and artifacts

Four independent passes and four same-session combined cross-reviews completed. Originals were preserved, and each cross-review read the other three full originals, not prior cross-review artifacts.

| Researcher | Original session ID | Files in this directory |
|---|---|---|
| Astra | `ses_f1c5107bfffefDJanl5lU29WfQ` | `astra-original.md`, `astra-cross-review.md` |
| Grok | `ses_f1c4d2922ffewPe5TNJvLvwfiy` | `grok-original.md`, `grok-cross-review.md` |
| MiniMax M3 | `ses_f1c42bd1cffeeUULWzxjga1tEf` | `minimax-original.md`, `minimax-cross-review.md` |
| Kimi K3 | `ses_f1c40272fffegWv5fAQexS8el4` | `kimi-original.md`, `kimi-cross-review.md` |

## Human checkpoint and implementation handoff

The package-specific standard is recorded in the PRD. The remaining concrete integration input is the exact Pons V4 revision/deployment and PoolManager intended for the first package. This can be supplied through a deployment manifest; do not invent addresses or admit every Pons-like contract in its absence.

Subsequent implementation planning should specify thin named packages, common validation, strict model dispatch, factory/registry metadata and negative/occupied-salt tests. Production-path tests must cover wrong hook, same-flags impostor, wrong manager, invalid launch, share/storage isolation, fee rounding, native/WETH, imports, blocked flows, quote parity and D17–D21 regression. No code implementation, testing or deployment is authorized by writing this report.
