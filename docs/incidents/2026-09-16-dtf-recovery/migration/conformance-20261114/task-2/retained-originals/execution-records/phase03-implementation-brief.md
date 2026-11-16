# Phase 3 continuation: preparation and receipt accounting

Read `phase03-brief.md` and the complete phase-03 `migration/package/implementation-handoff.md` first. This continuation explicitly advances the source allowlist only to handoff section 5's five paths. It does not authorize complete package composition yet.

## Preparation implementation

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`.
Base remains `90ff0307a7a8e084aa073e02eff125e9c7973933`; the independently verified phase-02 pricing commit `215c2bba6aa75e3e79bf68b7980b730927a85817` has not been merged or copied here.

Allowed source paths:

1. `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol`
2. `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol`
3. `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol`
4. `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol`
5. `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Deploy.t.sol`

Implement the consumed initializer, funded creation/claim dispatch and distribution dispatch exactly as specified in handoff sections 5.1-5.2. Preserve default behavior, order, storage, external ABI, declarations, salts, callbacks and ordinary economics. Add only genuine missing real-proxy initialization assertions in the existing deployment test. No unused/no-op policy hooks, fake Migration package, arbitrary-credit issuer, source adapter, owner policy, receipt partition or pricing integration.

Implementation evidence: `migration/package/evidence/preparation/`.
Independent verification evidence: `migration/package/evidence/preparation-verification/`.
Both are relative to the phase-03 incident directory.

Use the exact focused and broad artifact-first commands from handoff section 6, Solar-capable `/Users/cyotee/.foundry/bin`, existing gold real-proxy fixtures and actual executed counts. Do not weaken failures. Every new attributable failure must be fixed; demonstrated pre-existing failures need reproducible evidence and explicit reporting.

Root is seeding phase-03 `out/` and `cache_forge/` from verified warm phase-02 outputs and adding a read-only-use `node_modules` link. Do not start compilation until root confirms `PACKAGE_WARM_SEED_READY`. If the evidence has not arrived, finish source edits and report readiness; do not cold-compile or start another seed.

No RPC/broadcast is needed. Use an owned temporary root below `/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/`, explicit runtime cache variables, monitored long commands and cleanup receipts. Preserve warm artifacts and shared dependencies. No commits in these production nodes; root lands only independently verified increments.

## Parallel T5-EGRESS accounting contract

This is an engineering construction, not an owner-policy question. Write one exact implementable principal/reward accounting contract covering every path named in handoff section 4. Do not offer a menu or postpone the central invariant.

Specify storage units, authority, initialization, reward funding/index changes, bond-principal delivery, direct staking, partial/full withdrawals, transfer/transferFrom and allowances, mixed balances, parent/router intermediates, raw and staking SY deposit/transfer/redemption, `burnInternalBalance`, each configured output, pending role receipts, fractional retirement and activation release. Preserve mature-principal access, actual funded participation and retained reward ownership. No unrestricted conversion of gated growth into a new account's principal; no blanket pause; no fake funding or loss of rounding residue.

All proposals must fit the existing production APIs or name the exact minimal ABI change justified by the plan. Distinguish economic right transfer from payout and explain actual custody at each step. Supply precise integer transition equations and conservation invariants, adverse state sequences and successful principal-exit/activation-release examples. Use deterministic BigInt/integer checks when useful and preserve their actual results; no timing-based tests.

Author path: `migration/package/egress-contract.md`.
Optional executable arithmetic evidence only under `migration/package/evidence/egress/`.
Independent reviewer path: `migration/package/egress-verification.md`.
Reviewer evidence only under `migration/package/evidence/egress-verification/`.

These lanes read source and may write only their reports and bounded arithmetic evidence. No production/test/config edits, Forge build/test, installs, Git, deployment or delegation. Preparation may concurrently refactor the four shared source files without changing behavior; cite the inspected version and distinguish invariant semantics from moving line numbers.

The accounting verifier must actively try split/merge/transfer/wrapper/dust and reentrancy/caller counterexamples, check machine-consumed equations independently, and return ready-for-implementation or needs-fix with an exact corrective direction. A report alone is not E5 runtime acceptance.

## Unresolved product gates

BOOTSTRAP-AUTH is resolved by the current user's answer, `Genesis: Current owner only (Recommended)`: only the current Crane owner selects and executes the one-time genesis amounts/anchor from pooled donations. Contributions and subsequent ordinary donations remain permissionless. This resolves caller authority, not runtime E4 acceptance. Existing E1/E2 and actual recovery E3 remain open.

One same phase run contains preparation -> independent preparation verification and egress construction -> independent accounting verification, after the already completed handoff. Root reads both final verdicts before advancing to functional composition. The earlier four preflight nodes must remain cached with their complete original definitions.

## Independent accounting review focus

Root read the completed `t5-egress-principal-sy-r1` construction. Its deliberate
changes include principal-denominated staking SY, constant `exchangeRate`,
nonempty reward API, reward indexes denominated in gons, and caller-attributed
internal share burns. Treat these as concrete compatibility obligations, not
mere storage implementation details.

The independent verifier must check the actual `IStandardizedYield` contract
and relevant in-repository consumers for required units, rate/reward semantics
and internal-balance behavior. Determine whether the proposed representation
satisfies those contracts and the Migration plan, or requires a narrow
engineering correction or a genuinely new product decision. Do not infer
compatibility from unchanged selector signatures or from the 648 arithmetic
cases. Do not silently approve a product change or demand an owner decision
where the admitted requirements already settle the engineering question.

Root inspected local `IStandardizedYield.sol:60-139`: the rate comment defines
asset balance using `exchangeRate * syBalance / 1e18`, the internal-burn flag
names the wrapper's balance, and the reward-index declarations themselves give
no unit. Therefore do not assert a WAD reward-index requirement from that
interface alone; inspect actual consumers before concluding compatibility or
incompatibility of the construction's gon-denominated indexes.
