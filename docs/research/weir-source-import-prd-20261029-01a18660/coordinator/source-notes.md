# Coordinator source checks — Weir source-import PRD

These are source observations, not compilation/runtime results. Originals remain independent; these notes contain no peer findings.

## Exact baseline and ABI

- Read all of frozen WeirVaults (427 source lines), WeirBase (88) and Weir LiquidityAmounts (68), not merely source NatSpec.
- Sourcify metadata supplies the compiled ABI, inherited errors/events and original compiler settings. Use its complete ABI as the manifest, including receive, inherited owner/pause getters and public constant/mapping/array accessors.
- The original bundle uses nested `IPoolManager.ModifyLiquidityParams` and `IPoolManager.SwapParams`; Weir uses these at vault lines 264, 292, 323, 349 and 397.
- Original StateLibrary and current canonical StateLibrary both declare POOLS_SLOT=6. Matching that constant alone is not proof of complete manager storage compatibility.

## Concrete import incompatibilities

1. Current Crane `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol` imports free `ModifyLiquidityParams`/`SwapParams` from `types/PoolOperation.sol`. They are not declared as nested IPoolManager types. The free struct fields read are equivalent to the tuples Weir uses. A documented mechanical type-name/import migration is required if this canonical type family is selected. A pure string path rewrite is insufficient; no ABI change is intended.
2. Current Crane V4 `libraries/LiquidityAmounts.sol` contains liquidity-for-amount functions only. It does **not** contain the amount-for-liquidity functions Weir's `previewRedeem` calls. Its checked-cast/unchecked implementation also differs from the frozen GPL helper. Do not point Weir at this incomplete MIT library and claim an import-only adaptation or license clearance.
3. Current Crane V3 periphery LiquidityAmounts has both directions, but has not yet been compared completely. No replacement is approved by a matching symbol alone.
4. Original Ownable is OZ v5.0.0-style (`constructor(address initialOwner)` plus typed errors). Crane has canonical OZ, OZ-v4 and OZ-v5 trees. Pick the tree whose ownership/pause/reentrancy/SafeERC20 semantics actually match; do not choose OZ-v4 or native ownership by name.
5. Current canonical Position and PoolManager headers say `BSL-1.1`; original frozen Position says `BUSL-1.1`. Do not silently normalize away that provenance difference or describe a canonical remap as legal clearance.
6. Frozen source compiled viaIR=true with solc 0.8.26/optimizer800. Current project uses solc0.8.35/optimizer1/via_ir=false. Source compatibility and bytecode reproduction are different gates. No compile was run, so no stack-depth outcome is known.

### Versioned OpenZeppelin route verified after a root-tree mismatch

The generic `external/openzeppelin-contracts/` is not uniformly compatible: its Pausable declares v4.7.0, ReentrancyGuard v5.5.0, and SafeERC20 v4.9.3. Do not infer all repository OZ routes are blocked from that one mixed tree.

Coordinator read the corresponding existing `external/openzeppelin-contracts-v5/` candidates. Ownable2Step, Ownable, Context, Pausable, ReentrancyGuard and IERC20 are byte-identical to their frozen counterparts. Its SafeERC20 declares v5.2.0 rather than frozen v5.1.0, but the two functions Weir uses (`safeTransfer` and `safeTransferFrom`) and `_callOptionalReturn` including the remaining tail are text-identical. This supplies a concrete consistent V5 family for the PRD's import map, subject to actual compiler/artifact and focused compatibility tests; it is not a claim that the entire transitive graph has been compiled or legally cleared. Do not mix inheritance identities between the generic and versioned Context/Ownable trees or replace storage semantics.

## Source-fidelity cautions

- The 1,000 MIN_SHARES are added to totalShares without crediting any wallet, not minted to a dead ERC20 address.
- New deposit leftovers are refunded to the payer through amount-minus-used accounting; booked idle principally comes from compound residue, and deposit issuance still uses liquidity, not NAV/idle-inclusive capital.
- Withdraw predebits the caller's ledger, then callback compounds, removes pro-rata liquidity/idle and pays to recipient. Preserve this observable order and rollback.
- Withdraw zap modes may return both currencies after partial fill. min0/min1 are independent lower bounds, not exact absence predicates.
- previewRedeem excludes pending fees, does not compound or zap, and accepts arbitrary share quantities without a balance check. Do not require general preview==withdraw-with-maintenance equality or introduce new bounds.
- Guarded external actions are deposit/withdraw/compound. transferShares/createVault/admin surfaces are not automatically protected by that guard; paused blocks deposit, not every operation.
- compound sets lastCompound before zero-liquidity early return; Compounded is conditional on nonzero harvested fee, not on every compound/idle movement.
- The full-range position belongs to the Weir contract, salt zero, per PoolId.

## Requirements versus characterization

Baseline fidelity must not be mistaken for production approval. Economic quirks (including unpriced idle ownership, hook-return-delta behavior, donations and shared-currency custody) need exact characterization and recorded risk, not invented “always safe” invariants. Positive source-fidelity cases must pass a faithful implementation; a newly observed hazard is preserved as evidence and requires a separate remediation decision.

### Cast/error checks for the final test expectations

- Raw explicit casts are not SafeCast. Narrow uint128/uint64 conversions truncate high bits; same-width signed/unsigned conversion preserves the bit representation. Checked arithmetic surrounding a cast can revert independently, but the cast itself does not impose a range validation.
- Consequently `_compound`'s `uint256(int256(oldIdle)+net)` does not prove fail-closed accounting when that signed sum is negative. The signed addition can be valid, the unsigned conversion can create a huge recorded idle, and a later payment might succeed from other physical inventory or fail separately. Require exact real-hook characterization and do not promise an automatic cast revert.
- A 1,000-bps treasury fee is 10%, not 100%. Fee-rounding vectors must use denominator 10,000.
- A real price-moving fee-bearing swap can also change pending fees; isolate zero-fee movement or account for newly generated fees.
- Library zero denominators must be classified at the actual failing expression: frozen FullMath's empty revert differs from Solidity division-by-zero Panic(0x12).
- Primary language reference checked for these distinctions: `https://docs.soliditylang.org/en/v0.8.35/types.html#explicit-conversions`, specifically explicit narrowing and negative signed-to-unsigned examples. It supports cast semantics, not a runtime claim about a reachable attack or completed tests.
