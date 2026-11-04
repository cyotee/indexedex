Ask: Review the frozen synthesized Weir plan and three peer originals, then issue one MiniMax advisory - wanted: a complete, traceable disposition with exact corrections and adopted/non-adopted proposal dispositions. For you: active `apply_patch` was unavailable, so the complete advisory is delivered inline under the brief’s fallback. No file was changed. Now: Draft traceable MiniMax advisory feedback. Next: No task remains.

# MiniMax advisory on `weir-import-plan-draft-r1`

## Identity

Member: MiniMax, acting as the independent council member for this one advisory pass. Assigned Native route: `minimax/MiniMax-M3`. This advisory does not inspect private runtime/authentication metadata or independently attest provider execution.

This is the single advisory on the frozen synthesized draft and the three peer originals. It is not a new original, a second debate round, an implementation pass, or authorization to implement.

## Draft under review

- Draft: `docs/research/weir-source-import-plan-20261029-01a18660/coordinator/draft.md`
- Revision: `weir-import-plan-draft-r1`
- Coordinator-supplied SHA-256: `5515502e83176fc1423d68bea8f73af8e9bea0efa98c2bdde6bdba92993e7942`
- The draft was readable and was read completely. I did not recompute the supplied hash.
- Peer originals read completely: `members/astra/response.md`, `members/grok/response.md`, and `members/kimi/response.md`. I did not read peer feedback.

## Disposition

**SUPPORT WITH CORRECTIONS.**

The draft is a strong, decision-complete synthesis: it preserves the standalone scope and all 37 WI/69 AC rows, separates compile/hermetic/fork/security/license gates, rejects mocks and forbidden state injection, uses an independent oracle, provides explicit callback and rollback boundaries, and records honest blocked/gap states.

The corrections below are localized but material: one acceptance fallback must become a compatibility stop, two subcases need exact execution constructions, campaign coverage needs objective dimension gates, and the fork hash check needs an exact API-level instruction.

## Concerns and exact corrections

### 1. F0 must not absorb a canonical manager rounding mismatch

**Draft sections:** §2 selected decision 1; §4 WP-00 and WP-05; §5 “Anchors”; §6 AC09.

The draft currently says that if the real add delta is not `K`, “used and refund follow the real delta,” and makes AC09 conditional on real liquidity being `K`. That is not an authorized fallback. The frozen F0 anchor requires exact manager costs `K` per currency and refunds `2` per currency. The current canonical manager source makes this a live compatibility question: `Pool.modifyLiquidity` derives positive add deltas through `SqrtPriceMath.getAmount0Delta`/`getAmount1Delta`, whose add path rounds up.

**Exact correction:** restore the frozen F0 values as mandatory AC09 assertions: `L=T=K`, recipient shares `K-1,000`, manager caller deltas `K/K`, and payer refunds `2/2`. Add a WP-00 compatibility vector for canonical positive-liquidity amount rounding before money-path acceptance. If the canonical manager produces a different delta, stop and report a dependency compatibility mismatch for owner decision; do not rewrite the F0 expectation to “whatever the manager returns,” do not change Weir, and do not relabel the fixture.

### 2. AC36 must name the selected token's exact failures

**Draft sections:** §2 selected decision 5; §6 AC36; §7 WI-31.

The draft selects `SimpleMintableERC20` for ordinary fixtures, but AC36 says only “Token-specific exact failure.” The selected token currently reverts with the string error `Error("allowance")` for insufficient allowance and `Error("balance")` for insufficient balance. A generic phrase does not satisfy the frozen exact-error requirement.

**Exact correction:** in AC36, require `Error("allowance")` for the missing-allowance fixture and `Error("balance")` for the missing-balance fixture when `SimpleMintableERC20` is used. If another ordinary token is selected, name that token's exact revert bytes instead. Preserve full rollback and the no-inventory-substitution assertion already present.

### 3. AC63/WP-07 need objective coverage gates for every WI-36 dimension

**Draft sections:** §2 selected decision 10; §4 WP-07; §6 AC63; §7 WI-36.

The draft says handlers “must hit their dimensions,” but WP-07 exits on a nonzero success count and AC63 omits native/ERC-20 paths, both currency directions, pause, and owner transitions from its construction. A campaign with one successful deposit could therefore pass the written gate without spanning the dimensions required by WI-36 and the brief.

**Exact correction:** make WP-07 and AC63 require recorded successful-action counters for each mandatory dimension: at least three users; at least two pools including one shared currency; both currency directions; native and ERC-20 paths; deposit, transfer, withdrawal, compound, and donation; pause transition; and owner transition. Keep the configured 16 runs/depth 8, but add deterministic scripted multi-action regressions for any dimension not reliably reached inside that budget. Success count greater than zero alone is insufficient.

### 4. AC49 and AC67 need concrete real constructions before a gap is declared

**Draft sections:** §6 AC49 and AC67; §4 WP-06; §11 named gap points.

AC49 names a zero-refund subcase but does not explain how a successful deposit can have zero refund without assuming the mint debt. AC67 likewise names the desired `oldIdle + net = -1` state without carrying forward the peer-original candidate that gives the implementer a concrete route to attempt.

**Exact correction:**

- For AC49, require a real construction of zero refund before the subcase may pass. Use a solved zap/hook construction that makes the actual caller delta consume the declared amount, with every hook and manager delta closed, rather than declaring the input equal to an assumed debt.
- For AC67, add the source-derived candidate as the first attempt: F1 post-state, one directly donated currency0 unit to Weir as tracked unassigned physical inventory, a real 20-unit currency1 pool donation, and an after-add return-delta hook that takes three currency0 and returns `(3,0)` while settling its own debt. The expected intermediate Weir add delta is `(-20,-17)`, settlement net `(-20,2)`, and `int256(oldIdle0)+net0 = -1`; if an earlier real-manager failure prevents the state, record that exact failure and the precise reachability gap.

### 5. AC65 needs an exact fork-header hash check

**Draft sections:** §6 AC65; §9 step 4.

The draft requires the supplied block hash but does not name an exact way to obtain it and correctly warns that `blockhash(block.number)` is not a current-header proof. The installed forge-std `Vm` exposes `getRawBlockHeader(uint256)`.

**Exact correction:** make the AC65 preflight assert:

```solidity
keccak256(vm.getRawBlockHeader(ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK))
    == 0x07be1214c2742ebcea7a61d8065020e88c4b66b5fc96a753ff022a00aa2c8c1d
```

Retain the independent chain-ID, block-number, and code checks. Do not substitute `blockhash(block.number)` or a receipt response.

### 6. AC69 needs an explicit split artifact for runtime and test graphs

**Draft sections:** §3 “Production and provenance”; §4 WP-04; §6 AC69; §7 WI-03/WI-05.

The draft says the actual resolved production and test graphs are separate, but its file inventory has no named artifact for the resolved graph or storage-layout evidence. That makes the AC69 output and the later license disposition harder to audit.

**Exact correction:** either add `contracts/protocols/strategy/weir/evidence/resolved-graphs.json` with separate `production` and `test` source sets, or define those two exact fields plus the compiled storage-layout record in `dependency-compatibility.json`. Require the graph source to come from compiled artifact metadata, retain the frozen 39-file map separately, and distinguish runtime-reached BSL/AGPL declarations from test-only declarations.

## Dispositions of proposals the draft did not adopt

### CREATE3 manager deployment — support non-adoption

The draft selects direct `new PoolManager(address(this))` after `CraneTest.setUp()` rather than CREATE3 plus `ArtifactCreationCode`. I support that decision. `PoolManager` is the real canonical dependency, not a facet or DFPkg; this standalone baseline explicitly permits a real protocol-port deployment in its TestBase. Direct construction binds the test to the canonical source compiled in that run and avoids the stale-`out/` artifact risk the draft identifies. Keep the existing statement that this is a test-only protocol-port route and not a production manager deployment.

### Verifier script location — support the draft's co-location

My original proposed a root `scripts/verify-weir-source-import.py`; the draft instead selects `contracts/protocols/strategy/weir/test/tools/check_fidelity.py`. I support the draft's single co-located standard-library tool, provided the file inventory and §10 command use exactly that path and no root-level duplicate is added. The tool must compare source tokens/allowlisted hunks, compiled ABI, and resolved-graph machine data without pinning prose.

### Collapsed evidence files — support the collapse

The draft correctly collapses the overlapping human ledgers into `VENDOR.md` plus `IMPORT_EVIDENCE.md`, with machine records under `evidence/*.json`. I support this disposition. Keep the responsibilities distinct:

- `VENDOR.md`: frozen provenance, imports, licenses, deployment, and unresolved release facts.
- `IMPORT_EVIDENCE.md`: AC/WI/command/result ledger.
- JSON: transform, ABI baseline, dependency/graph, and acceptance records.

Do not recreate `VERIFICATION.md`, `RELEASE_EVIDENCE.md`, `IMPORT_TRANSFORM.json`, or a second transform markdown as parallel sources of truth.

### Other non-adopted proposals

- **Reuse `PoolSwapTest`, `PoolModifyLiquidityTest`, `CurrencySettler`, and `Deployers`:** support non-adoption. The owned `WeirPoolRouter`/`WeirCallRouter` design is needed for donation, open sync, caught nested unlock, and the required settlement/error surfaces; the draft also correctly avoids copying unlicensed helper source.
- **Kimi's proposed `v4-core/test/utils/HookMiner.sol` path:** support the draft's correction to `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMiner.sol`.
- **Fork base that selects the fork after inheriting hermetic setup:** support the draft's fork-first ordering, followed by `CraneTest.setUp()` in the selected fork context and binding the live reference manager without deploying a replacement manager.
- **Expanded invariant/fuzz budgets proposed by Astra:** support retaining the repository's 16 runs/depth 8 and not editing `foundry.toml`; require the deterministic scripted coverage correction above instead of a configuration change.

## Limits

- This advisory was read-only. Because active `apply_patch` was unavailable, this complete feedback is delivered inline and no project file was changed.
- The draft, PRD, domain sources, peer originals, and project configuration were not edited.
- No command, build, test, RPC, Git operation, deployment, wallet action, or delegation was performed. The supplied draft SHA-256 was not recomputed.
- The draft's compiler, ABI/layout, runtime, canonical manager, archive fork, upstream-suite, and license-disposition gates remain unverified. This advisory does not convert any of them into a pass.
- I did not independently attest private Native runtime/account metadata beyond the assigned MiniMax route.
- **This advisory neither replaces the draft nor authorizes implementation.** It is one advisory pass on the frozen draft and requests no additional debate round.

Now: No task remains; the complete advisory is delivered inline.

Next: No task remains.
