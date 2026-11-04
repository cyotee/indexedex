# Resolution: weir-import-plan-final-r2

Reviewed draft: `docs/research/weir-source-import-plan-20261029-01a18660/coordinator/draft.md`
Revision: `weir-import-plan-draft-r1`
SHA-256: `5515502e83176fc1423d68bea8f73af8e9bea0efa98c2bdde6bdba92993e7942`
That draft is unchanged.

Final: `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_IMPLEMENTATION_AND_TEST_PLAN.md`
Revision: `weir-import-plan-final-r2`
SHA-256: `118bfa0875fcc382760a5b8cb5bd76566aaf0744e9ad182ba038ace7196dff90`
92,741 characters, 719 lines. AC01-AC69 and WI-01-WI-37 are present.

Advisory is not a veto and not member approval of the final sentences. All four advisories were read. Astra requested changes. Grok, Kimi, and MiniMax supported the draft with corrections.

## Adopted

| Concern | From | Change in r2 |
|---|---|---|
| F0-F3 must stay fixed vectors | Astra C1, Kimi K-01, MiniMax 1 | Removed the "follow the real delta" fallback. A mismatch is a failed gate, not a new expected value. WP-00 adds a positive-liquidity rounding comparison before money-path acceptance. |
| Source-only fidelity before an ABI exists | Astra C2, Grok 4 | `check_fidelity.py` has a source mode that compares only the three domain files, and an ABI mode that runs after the build. The import owner writes the tool. |
| Hook delta is accounted after the callback returns | Astra C3 | Section 8 states the timing and forbids settling only the pre-return visible delta. The implementer confirms it against `Pool.modifyLiquidity`. |
| Concrete unexecuted AC60 and AC67 candidates | Astra C3, Kimi K-03, MiniMax 4 | Section 8 and the AC rows carry the candidates. They are not runtime results. A failed stage stays a gap. |
| Zero-delta poke uses remove-liquidity flags | Grok 5, confirmed in `Hooks.sol` this pass | Section 8 states `liquidityDelta <= 0` uses the remove flags. |
| Pause and stale-sync constructions | Astra C4 | AC51, AC54, and AC58 name the trigger and the boundary. Compound's `nonReentrant` precedes the exists check. That modifier order was read at frozen W:206-208. |
| Ordinary inventory is not a blanket success check | Astra C5 | Section 6 limits the inventory equality to the supported domain. |
| Campaign dimensions, not `success > 0` | Astra C5, MiniMax 3 | WP-07 and AC63 require a counter per WI-36 dimension and scripted coverage inside the observed 16-run budget. `foundry.toml` stays unchanged. |
| Fork action set, role map, and `poolManager()` | Astra C6, Kimi K-04 | Section 9 names the sequence, the role reads, and the reference binding check. |
| Do not bootstrap factories on the archive fork | Grok 2 | Fork setup selects the fork and does not call hermetic `setUp` or `InitDevService`. A framework bootstrap revert is `ForkPreflightBlocked`, not a new manager. |
| Header hash cheatcode | MiniMax 5, Grok 3 | Preflight uses `vm.getRawBlockHeader`, read at `lib/crane/lib/forge-std/src/Vm.sol:720`. `blockhash(block.number)` is forbidden. |
| AC23 and AC33 reachability guidance | Astra C7, Kimi K-07 | Ordinary `L>=T` reasoning is recorded. AC33 uses the fee-zero, spacing-greater-than-one construction. Both stay gaps if the real manager cannot reach them. |
| AC49 zero-refund construction | Astra C7, Kimi K-02, MiniMax 4 | The subcase needs a real equality of declared and used native. The hook candidate is unexecuted. |
| Repeated pause and unpause | Astra C7 | AC52 names `EnforcedPause` and `ExpectedPause`. |
| Zero delivery and owner-callback ownership | Astra C7 | AC55 and AC56 name those subcases. |
| Storage layout and resolved graphs | Astra C8, MiniMax 6 | Added `storage-layout.json` and `resolved-graphs.json`. Human ledgers stay `VENDOR.md` and `IMPORT_EVIDENCE.md`. |
| Oracle disagreement is not automatically a dependency defect | Astra C8 | The wide-integer fixture and the stage specification arbitrate first. |
| AC36 exact token errors | MiniMax 2 | `MintableERC20Decimals` uses `require(..., "allowance")` and `require(..., "balance")`. The row names `Error("allowance")` and `Error("balance")`. |
| HookMiner attribution | Astra C10, Kimi K-05 | The nonexistent v4-core test path is no longer attributed to Kimi. The selected miner remains the public utils file whose MIT header was read. |
| Rollback wording | Astra C10, Kimi K-06 | Pre/post equality is asserted before `revertToState`. AC26 does not treat `recordLogs` as a receipt. |
| Section cross-references | Astra C10 | WI-37 and the fork recipe point at section 10, not a missing section 11. AC65 points at section 9. |
| WI-34 owner | Astra C9 | WP-03 owns the oracle. WP-05 consumes it. |

## Not adopted

| Proposal | Why it stays out |
|---|---|
| CREATE3 manager deployment | Astra accepted direct construction as not a defect. Grok, Kimi, and MiniMax supported non-adoption. Direct `new PoolManager(address(this))` remains the hermetic route. The stale-artifact rationale was narrowed: CREATE3 is not intrinsically less faithful, and direct construction does not waive build-before-test. |
| Collapse `IMPORT_EVIDENCE.md` into `VENDOR.md` | Grok asked for this after misreading section 2 as forbidding `IMPORT_EVIDENCE.md`. The draft already created that ledger and forbade only `VERIFICATION.md` and `RELEASE_EVIDENCE.md`. Kimi and MiniMax supported the two-file split. It stands. |
| Reuse `PoolSwapTest` / `PoolModifyLiquidityTest` | All four advisories accept owned routers. Kimi's original proposal was narrower than the draft's attribution. The non-adoption stands. The description now says Kimi proposed reuse only where those routers fit, not as the donate, sync, and catch surface. |
| Raise fuzz or invariant runs | Astra accepted the observed 16/8 budget if dimension counters exist. Those counters were added. `foundry.toml` is not edited. |
| A second human release ledger | Not restored. Machine JSON holds layout and graph evidence. |

## Unresolved, and still not passes

Compilation, ABI, storage layout, hermetic execution, archive parity, upstream suite, and license clearance were not run. AC23, AC33, AC41 wrap, AC49 zero-refund, AC60, and AC67 remain conditional or gap-if-unreachable until a real manager attempt records a result. The AC67 and AC60 candidates are planning constructions, not demonstrated exploits or safety findings.

This resolution does not authorize implementation.
