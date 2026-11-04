I read this as the same Grok advisory, delivered again because the last turn was not captured. apply_patch is not an active tool, so the complete feedback is this response. I'll stop when that feedback is delivered.

# Grok advisory: weir-import-plan-draft-r1

## Identity

Member: Grok. This is the one advisory on the frozen synthesized draft and the three other originals. It is not a new original, not a second debate, and not implementation. No peer feedback file was read. `members/grok/response.md` was not edited. No project file was written: active `apply_patch` is not available, and no alternate write was used.

## Draft under review

Path: `docs/research/weir-source-import-plan-20261029-01a18660/coordinator/draft.md`.

Revision: `weir-import-plan-draft-r1`.

Coordinator-supplied SHA-256: `5515502e83176fc1423d68bea8f73af8e9bea0efa98c2bdde6bdba92993e7942`. Not recomputed. The file was readable and was read completely, through the closing sentence that the draft neither replaces the PRD nor authorizes implementation.

Originals read completely, and not their feedback:

- `members/astra/response.md`
- `members/kimi/response.md`
- `members/minimax/response.md`

## Disposition

SUPPORT WITH CORRECTIONS.

The draft is the right work order: three-file import, allowlisted rewrites, real canonical `PoolManager`, independent oracle, separate hermetic and fork gates, and no economic repair. The corrections below are sentence-level. They do not add a WI or an AC, and they do not restore a rejected route.

## Concerns

1. Draft section 6, AC66 row, contradicts draft section 2 and WP-09.

Section 2 says AC04 and AC66 live in `VENDOR.md` and says not to add `IMPORT_EVIDENCE.md`. WP-09 says the owner of the `VENDOR.md` release section fills the AC66 map. The AC66 row still names `` `IMPORT_EVIDENCE.md` map ``.

Exact correction: change that cell to `` `VENDOR.md` release section ``. Do not create `IMPORT_EVIDENCE.md`, `VERIFICATION.md`, or `RELEASE_EVIDENCE.md`.

2. Draft section 4, fork TestBase paragraph, and section 9 step 3, still bootstrap factories on the archive fork.

Both say `createSelectFork` before `CraneTest.setUp()`, and both correctly forbid the hermetic `setUp`. Calling `CraneTest.setUp()` after the fork still runs factory bootstrap on chain 4663 state, because a fresh fork has no local diamond factory. That can revert, and it writes non-parity state into the pin before the snapshot.

Exact correction: the fork TestBase selects the fork first, does not call hermetic `TestBase_WeirVaults.setUp`, and does not run `InitDevService` factory deployment on the archive fork. Inheriting `CraneTest` is the type ladder. It is not a reason to deploy a second manager or a factory stack onto the pin. If bootstrap is still invoked, the draft must say those deployments are local-fork side effects inside the snapshot, are not comparison subjects, and a bootstrap revert is `ForkPreflightBlocked`, not a fallback to a new manager.

3. Draft section 9 step 4 requires the supplied block hash and then says `blockhash(block.number)` is not a current-header proof, without naming the replacement read.

Exact correction: add that the preflight reads the selected fork header hash through the installed forge-std cheatcode confirmed in `lib/crane/lib/forge-std/src/Vm.sol` at implementation time, and that the BLOCKHASH opcode on the current number is forbidden. Do not invent the cheatcode name in the draft without that citation. Until the name is written, hash equality is an unverified gate, not an implementable assertion.

4. Draft section 10, `check_fidelity.py` command, passes `--imported contracts/protocols/strategy/weir`.

That directory also holds `test/`, `evidence/`, and `VENDOR.md`. A directory diff against the frozen `sources/` tree would fail for reasons that are not an import defect.

Exact correction: state that the tool compares only `WeirVaults.sol`, `base/WeirBase.sol`, and `libraries/LiquidityAmounts.sol` with the frozen `.sol.txt` files, and that it ignores `test/`, `evidence/`, and `VENDOR.md`.

5. Draft section 8, compound step 3, says a nonzero position "pokes with delta 0" and does not repeat the dispatch rule in section 4.

Section 4 correctly says a zero-delta poke uses the remove-liquidity hooks. An implementer reading only section 8 can add a poke permission the manager will not call.

Exact correction: in section 8 step 3, add that `liquidityDelta == 0` is dispatched through the remove-liquidity hooks, not through a separate poke flag.

## Dispositions of proposals the draft did not adopt

CREATE3 manager deployment, proposed by Astra and MiniMax, is correctly not adopted. Astra's inspected Orbital route, `create3Factory.create3WithArgs` plus `ArtifactCreationCode`, is a real product-fixture route. MiniMax required that route and forbade `new` for the shared manager. The owner allowed protocol-port deployment inside the TestBase, and verified call sites already use `new PoolManager(address(this))`. The draft's `new PoolManager(address(this))` after hermetic `CraneTest.setUp()` is the smaller real deployment. Do not change the draft to require CREATE3. That rejection is not permission to mock, etch, or storage-inject the manager, and it is not permission to deploy Weir through CREATE3, a factory, or a proxy.

`PoolSwapTest` and `PoolModifyLiquidityTest` reuse, proposed by Kimi, is correctly not adopted as the Weir router. Those routers can show settlement shape. They do not donate, catch a nested failure, or hold a stale non-native sync, which AC30, AC51, and AC58 require. MiniMax's caution against copying those helpers into the Weir tree is an additional reason not to vendor them. One proposed `WeirAuxRouter`, a real `IUnlockCallback`, is the right synthesis. No correction.

Collapsing `IMPORT_EVIDENCE.md`, Kimi's `RELEASE_EVIDENCE.md`, and MiniMax's `VERIFICATION.md` into `VENDOR.md` is correct and should stand. The PRD already requires `VENDOR.md` for provenance. A second prose ledger would duplicate AC66. Astra's machine files are the part worth keeping, and the draft kept them under `evidence/`: `import-transform.json`, `dependency-compatibility.json`, `abi-baseline.json`, `storage-layout.json`, and `resolved-graphs.json`. Those stay separate from the prose ledger. The only change is Concern 1: the AC66 row must name `VENDOR.md`, not the rejected filename. MiniMax's repo-root `scripts/verify-weir-source-import.py` is also correctly not adopted; `test/tools/check_fidelity.py` keeps the verifier inside the import tree, subject to Concern 4.

Other non-adoptions, none of which should be reopened:

- Astra's concrete AC67 integer script is correctly left unexecuted. The draft still requires a real-manager attempt and a precise gap if that attempt fails. Do not promote the script to a fabricated pass.
- Astra's larger fuzz or invariant run counts are correctly not adopted. The draft keeps the observed profile values, runs 16 and depth 8, and forbids a `foundry.toml` edit.
- Astra's `WrappedError(...)` spelling for AC50 is correctly not hardcoded. The draft's rule, record the selector Currency or CustomRevert actually emits, should stand.
- A separate `WeirCallRouter`, and reuse of `SimpleMintableERC20` or `ERC20PermitMintableStub` as the ordinary token, are not required. `WeirAuxRouter` plus a new exact-transfer peripheral is enough, provided AC36 asserts that peripheral's real error rather than a stub's `Error("allowance")` string.
- Kimi's `PoolSwapTest` license-safe "use where they fit" split is already covered above. Do not add those contracts as a second router tree.

## Limits

This advisory did not recompute the supplied hash, re-read the PRD, domain sources, or canonical tree, run a command, test, build, RPC call, or Git operation, or edit the draft or any original. It does not attest that `forge-artifacts.py plan` exists beyond Astra's citation of the artifact doc, which the draft adopted; that citation was not re-opened here. It does not clear the license, the archive fork, or compilation.

This advisory neither replaces the draft nor authorizes implementation. Stop.
