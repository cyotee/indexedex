# Task 4 implementation notes

Specification: task 4 and the plan Scope sections Exact manual pricing ABI and arithmetic / Loaders, stable originals and rename/cut contract.

The previous snapshot acquisition tests assumed one-shot capture, installed facet-code authentication, provider RPC outcomes and six-decimal contribution tokens. These conflict with the approved manual pricing amendment: the owner replaces complete operands; no live authentication occurs; WETH and original DTF inputs are native18. The tests now exercise explicit manual inputs, retain supported observed-state differential comparisons, and cover 6/18/24/36-decimal SE operands. Shared capture support and canonical Weighted primitives are unchanged.

The existing pricing TestBase hosts a test-only observed-input converter. Production code contains only structural validation and the single renamed evaluator. The fixture supplies observations explicitly to the setter; it is not a production fallback.

The pricing bytes occupy the original storage position. The setter writes only those bytes. All twelve loaders compare the final expected-book scalar after existing authority, lifecycle and idle guards; both NFT entrypoints check before their shared routine. Configuration IDs keep their complete inputs and book ID; NFT economic IDs omit pricing.

The renamed retained facet is deployed through the existing name-based component factory. Its artifact lookup and release salt both receive the new name. Existing package cuts consume each facet's actual declaration, so no parallel selector list was added to production wiring.

The worktree already contained cache_forge and 6,216 out entries. The artifact helper rebuilt production dependents before tests. PATH explicitly selects /Users/cyotee/.foundry/bin/forge (1.9.1-nightly); the default Homebrew Forge is 1.9.0 and is not used. Solar is selected by the helper. No cache was deleted. The first test launch triggered Forge's automatic missing-submodule probe, which failed against the existing nonempty Crane directory. Subsequent runs use FOUNDRY_OFFLINE=true. No package was installed.

Existing unrelated changes and parallel task 5 files are outside this writer's edits. The already-dirty MigrationLegacySources.t.sol received only the expected-book argument at its two active loader calls; prior content was preserved. No commit, merge, push or public transaction occurred.

The new tests use deterministic inputs and Foundry state; no sleeps or wall-clock timing are introduced. Flaky timing tests are not applicable. External archive text is not executed; cancel/resume and repeated interruptions are not applicable. No Solar process was killed.

The first complete execution exposed a stale parent package: its old artifact registered the old allocation ERC-165 ID even though fresh facets carried the new ABI. The exact failure was the pre-existing activation-rollback assertion in MigrationCore.t.sol, not a failed cut. The package factory now supplies literal artifact IDs to its existing registration helper, so forge-artifacts discovers and rebuilds the parent, bond and SY packages. The final accepting helper command explicitly included UniswapV4DetfMigrationDFPkg.sol. That existing test passes without changing its gas budget or assertions.

FOUNDRY_OFFLINE=true does not suppress this Forge version's automatic missing-submodule probe. Each accepting run still reported an unsuccessful clone attempt against the existing nonempty lib/crane directory, then compiled successfully. No dependency was installed and no existing dependency directory was replaced.

The operator allocation-removability calculation in scripts/recovery/dtf-migration/execution-domain.ts uses the generated allocation ABI membership, so the new setter and twelve loader selectors remain removable through that mechanism. Its old snapshot query, and the active TypeScript fixture's old retained-facet name, remain later operator-work consumers; TypeScript writes are outside task 4's allowed scope and the parallel task 5 files were not edited.

Final happy QA: 229 tests passed across 33 suites, exit 0. Required failure QA: 29 tests passed across 15 suites, exit 0; all nine named families executed. The actual loupe census has 16 administration writers present before activation and absent afterward; all three old aliases are absent in both states; getter and preview remain installed. Complete actual lists are in proxy-census.json, not inferred from facet counts.

Production error diagnostics were clear for the pricing library, retained facet and both allocation targets. The new Solidity test's LSP request timed out; its Solar compilation and execution passed. JSON LSP diagnostics were unavailable because Biome is not installed; no installation was attempted by this writer for LSP. git diff --check passed for the owned Solidity paths.
