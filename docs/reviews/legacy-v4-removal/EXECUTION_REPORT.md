# Legacy Uni V4 Standard Exchange removal

Owner-directed retirement, 2026-10-15.

The legacy Uni V4 Standard Exchange family is deleted. The earlier architecture redesign, ERC5115 remediation, and interface facet split are superseded. They must not be used to restore this family.

## Removed

- Entire `contracts/protocols/dexes/uniswap/v4/` tree: 50 Solidity files and six co-located planning documents present at removal time. This includes the package/interface, FactoryService, all facets/targets, `UniswapV4StandardYieldExecutionTarget.sol`, internal execution helpers, storage/quote helpers, and legacy TestBases.
- Entire `test/foundry/spec/protocol/dexes/uniswap/v4/` tree: 121 dedicated Solidity test/helper files, including decimal variants, adversarial tests, and the recent ERC5115 and facet-split tests.
- `scripts/adapt-fullspread-pons-tests.py`: obsolete one-shot migration tooling referencing the retired family.

178 existing files were removed. Files already deleted by the preceding legacy refactors remain deleted. The pre-removal manifest is in [dependency-check-before.json](evidence/dependency-check-before.json). A local recovery copy of the removed files, including uncommitted edits, was saved outside the source tree at `/tmp/indexedex-legacy-v4-retired-2026-10-15`.

## Preserved

- Full Spread Hookless: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`.
- Full Spread Pons: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/`.
- Upper/Lower Wings: `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`.
- V4 buffer hooks, DETFs, shared Standard Yield code, and Crane's `lib/crane/contracts/protocols/dexes/uniswap/v4/` protocol implementation.
- Existing launch scripts, which already deploy the supported Full Spread packages.

The checkout had unrelated edits before removal; these were retained. SHA-256 checks confirm all 1,077 snapshotted protected Solidity files are unchanged by this task. Product documentation received narrowly scoped retirement notices; surviving product requirements remain in force.

Frontend recognition of old immutable deployment identities and tests rejecting stale package selections remain intentional. They do not implement or enable new deployment of the deleted family. Historical review evidence, source/build snapshots, and Foundry caches are retained. Root `CLAUDE.md`, the content inventory, legacy review plans, and mixed-scope testing/product documents now identify the family as retired.

## Validation

- Current source graph: 6,619 Solidity sources inspected, with **zero imports or runtime artifact references to the retired family**. Same-name helper matches resolve to independent surviving declarations or historical comments. See [dependency-check-after.json](evidence/dependency-check-after.json).
- Supported-family artifact preparation: successful; 80 runtime artifact build roots, 475-source import closure, cached production compilation. Test compilation succeeded with solc 0.8.35, default profile, without via IR.
- Supported-family regression tests: **81 passed, zero failed, zero skipped**, across nine suites. Both Full Spread families cover core settlement, import/deployment closure, and production constructor bindings. Wings covers deployment, interface surfaces, and money paths. See [supported-families.log](evidence/supported-families.log), which includes the exact build/test commands.
- Launch consumer inventory: **nine tests passed**. See [consumer-inventory.log](evidence/consumer-inventory.log).
- `git diff --check`: passed.

The full monorepo runtime suite and network fork suites were not run. The broad source scan also records two unrelated existing unresolved imports in archived/debug/research fixtures; neither references a removed legacy file. Validation covers source isolation and the supported-family regression suites, not a full repository release certification.
