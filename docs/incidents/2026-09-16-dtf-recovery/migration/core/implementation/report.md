# Migration core implementation evidence

Date: 2026-11-10. Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-04`.
Branch: `work/dtf-migration-phase-04`. Verified integration base: `6e27ecaa242c4acca132e3575a160514aad07b11`.

## DoneClaim

**Implementation producer: complete; ready for independent verification.** The actual registry-deployed core, focused proxy proofs, combined regressions, final two-stage mined-chain rehearsal, metadata inspection, source/runtime bindings, and owned cleanup are complete. This is not independent core acceptance. Root's separate `verify-core` node must produce `verification/report.md`; no original plan checkbox or operational gate is closed by this report. Root's partial visual inspection is recorded below, not represented as acceptance.

No implementation blocker remains in this node's bounded scope. E1/E2 source-dependent entrypoints and configuration, historical recovery E3 bindings, legacy surrender, harvest/operator-resume work, and full-release/operational gates remain outside this core. No placeholder ABI for those categories is installed. No public broadcast, private key, fork, commit, delegation, shared dependency/configuration change, or unrelated gold-TestBase edit was made.

## Implemented production contract

The phase04 brief, complete main-checkout plan, accepted phase03 `egress-contract-r3.md` and verification, ownership/bootstrap handoff, and all component source/reports were read. R3 and current-owner-only pooled genesis are preserved. The receipt, bond, both SY wrappers, RT, parent, registry, reserve, providers, and SEs are production implementations. Mintable contribution currencies and hostile ERC20/callback actors are explicitly external test dependencies, not historical-recovery provenance.

- The distinct Migration package deploys through FactoryServices/CREATE3 and the manager registry, salts with owner-aware arguments, validates one-time initialization, and fixes all five child identities. Independent owner deployments receive isolated hooks.
- The parent measures all-leg and native contribution receipts, tracks contribution/residual budgets separately, and restricts empty-reserve genesis selection/execution to the current Crane owner. Self supply, LP custody, fees, residuals, refunds, and pre-existing inventory are reconciled through the real paths.
- The verified frozen-snapshot implementation is a read-only consumer. Capture is immutable and binds configured ETH/WETH and DTF identities. Each original entitlement is quoted separately against that book; stored components sum to stored user credit. No caller price, arbitrary credit, public-preview fallback, or broadened route admission substitutes for it.
- Full-value allocation replacement is idempotent, including after issuance. Configuration creates no supply. Genuine independent execution issues once, supplies exact backing to the actual bond/receipt, uses a fresh cliff clock, preserves execution history, and rolls back a whole batch when a later recipient fails.
- New principal settles old participants first. An empty system gets a fresh epoch baseline. Standing fee/creator weights continue participating after ordinary principal exits. Ordinary acquisition and bonding are closed before primary/swap branch selection; active ordinary bonds remain unmarked and linear.
- The integrated handshake remains Idle=0, Synchronizing=1, Acquiring=2, Accounting=3, Paying=4. Bond funding and outbound delivery/retirement use the fixed Accounting admission. SY publishes a measured incoming packet into A once, pins final k, checkpoints the old holder, and debits earned gons before receipt accounting. Only the actual fixed receipt/bond graph gets the locked-parent synchronization no-op.
- Stage 1 preserves mature-principal exits while withholding reward receipts and RT. R0/R1/R2, E/U, old holders, creator changes, wrapper self balances, allowances/permits, and canonical retirement retain ownership across actual ingress, transfer, both internal-burn modes, and every configured output. Active rewards, RT redemption, and retained native remainders have positive executable coverage.
- Activation is current-owner-only, atomic, and irreversible. It removes all five actual administration selectors, including its own, while retaining queries and Ownable. Production tests cover absent initializer/updater/restoration routes and callback-owner/cross-child rejection.

The implementation state is bound by 45 explicitly supplied production source paths in `source-artifact-binding.json`, including the permitted common hooks and all integrated component sources. Existing snapshot, weighted-hook, V3 pricing, shared Crane/dependencies/configuration, and ordinary gold TestBases were not edited.

## Executed verification

| Scope | Executed result | Authoritative evidence |
| --- | --- | --- |
| Complete TM root | **59 passed; 10 suites; 0 failed; 0 skipped; exit 0** | `logs/focused-15.log` |
| Exact combined ordinary/common/pricing roots plus TM | **10,078 passed; 609 suites; 0 failed; 0 skipped; exit 0** | `logs/combined-01.log` |
| Final QA script artifact build | Exit 0; current artifacts already compiled | `logs/qa-build-03.log` |
| Final local Stage A | 230 fresh successful mined receipts | `logs/local-stage-a-05.log`, `release-stage-a-readback.json` |
| Final local early reward claim | One intentionally failed mined transaction; exact `MigrationRewardsClosed()` selector | `release-early-reward-rejection.json` |
| Final local Stage B | 16 fresh successful mined receipts | `logs/local-stage-b-02.log`, `release-stage-b-readback.json` |
| Final Solidity diagnostics | All 45 supplied production files: no diagnostics | `diagnostics.json` |

The combined baseline was 10,035 tests in 602 suites. This node adds 43 tests in seven suites; the unchanged 16 snapshot tests remain in the focused total. The full executed test names, suite counts, exact roots, and exit statuses are in `verification-summary.json`. This is executed coverage, not a test-source census.

| New suite | Tests | Principal proof |
| --- | ---: | --- |
| `MigrationCore.t.sol` | 9 | Registry deployment, isolated hooks, measured funding, immutable book, no configuration mint, fresh/delayed clocks, cliff edge, early gates, activation |
| `MigrationAdministration.t.sol` | 7 | Crane owner acceptance, invalid arguments, separately quoted originals, history/duplicate protection, batch rollback, callback owner, no retroactive reward |
| `MigrationEgress.t.sol` | 14 | Positive principal exits, parent inventory, earned-position ingress, old holders, bearer/self behavior, every configured output/input, both burn modes, rollback, actual role release, ordinary active bond |
| `MigrationPermitAndRetirement.t.sol` | 4 | Real permits/native allowances, canonical fractional retirement, RT owner's retained gons |
| `MigrationSurface.t.sol` | 4 | Actual cuts/interfaces/loupe, EIP-170, whole administration removal/restoration negatives, tokenURI numbers, fixed-caller/stale-index rejection |
| `MigrationHostileContribution.t.sol` | 2 | Short external receipt and callback/cross-child rejection with real SUT state rollback |
| `MigrationRetainedAccounting.t.sol` | 3 | Standing-only participants, prior creator ownership after role transfer, positive native payout of a sub-RT remainder when k is below the RT quantum |

Exact combined roots: common DETF and ordinary V4 DETF directories; the TM directory; six weighted-hook files (Fees, OwnerDuringLock, RefundCallback, Scale, SeBufferAbi, Swap); the ERC4626 transition-quote test; and V3 InQuery IFacet, FullRangeBook, and Previews. All paths are enumerated in `verification-summary.json` and `logs/artifact-plan.json`.

## Commands and current-source bindings

All compilation used the selected `/Users/cyotee/.foundry/bin/forge`, 1.9.1-nightly commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`, with Solar 0.8.38. The inherited Homebrew Forge was not used for final proof. No viaIR/profile/source-path changes were introduced. The artifact-aware helper received every supplied production source and the complete TM root before testing. The final exact expanded build/test selection is in `logs/artifact-plan.json`; original recorded commands remain in `final-check-commands.txt`, and the final focused invocation is identifiable in its log.

`source-artifact-binding.json` checks **927 unique artifact files**, represented by 945 IDs (18 aliases), against **2,479 current source hashes**, with zero mismatch, missing artifact, non-Solar, or viaIR findings. It includes runtime artifacts, all executed test contracts, owned component artifacts, and both QA contracts. SHA-256 artifact/source hashes and metadata keccak hashes are recorded. The plan contains 312 build roots and 286 runtime artifact IDs.

`deployed-surface-and-runtime.json` captures all six actual proxy loupe surfaces and verifies 21 surviving unique facets against their current compiled bytecode with only compiler-declared links/immutables masked. `package-owner-retired-runtime.json` additionally binds the deployed package, actual contract-owner fixture, and removed administration facet. Largest owned concrete runtime: allocation facet, **19,975 bytes**, below EIP-170's 24,576 bytes. Package: 16,632 bytes; largest surviving facet: 16,210 bytes. Code-size enforcement remained enabled.

## Final mined local-chain evidence

The owned node was `http://127.0.0.1:18548`, chain 31337, 100,000,000 block gas, standard unlocked dev accounts, no fork, and no disabled code-size check. Final instance: `0x9acbcd5bdce3e90268561d142e212f1a6854e15c0c060b4c3dd2a663fbe5740c`. The script's required `FOUNDRY_BLOCK_GAS_LIMIT=1000000000` is a Forge simulation setting, not a claim that Anvil's block limit changed.

The final full focused, combined/build, and guarded local invocations are recorded verbatim in `final-executed-commands.txt`; the local commands are also in `stage-a-release-command.txt` and `stage-b-release-command.txt`. They preserve the brief's exact script/signature/RPC/broadcast/unlocked/sender argv; Stage B receives the parent decoded from this Stage A's real issuance receipt. The guard binds actual selected Forge/RPC and instance identity. `wrong-endpoint.json` proves a mismatched local endpoint was rejected before broadcast with unchanged nonce/state. Final broadcasts have their own `broadcast-release/MigrationCoreLocalQA.s.sol/31337/` directory.

| Contract | Actual address |
| --- | --- |
| Parent | `0x406cd20cb6f03f51cd303a3d14d6b1fbbcccab88` |
| Bond NFT | `0xfA53c3188BcbDaE211Fe037aCD211C4031b8fE9d` |
| Receipt | `0xEf2E550310745309Fc07B1DdE1853447e6a528bF` |
| Raw SY | `0x3af09b5667CCd422F4Cc883F4D991Bc5bFB4Af96` |
| Staking SY | `0xd5A995B3199Be66EC1b6825014CbAE48691c3425` |
| Reward token | `0x186a8c0806FACeDC673789980F7483DCCC633430` |
| Registry package | `0x642fa76f2f7a6b97ec0822d67a785379a92df347` |
| Actual contract owner | `0xd8c0e1df4cb2a23eb2949a193374f6524c12d9ae` |

Stage A independently issued token 3 with **1,201,585,232 native principal units**, equal to stored credit, actual receipt backing, and accounted backing. Snapshot, allocation, issuance clock, supply, child state, and tokenURI are in `release-stage-a-readback.json`. Its 230 receipt hashes/statuses/block hashes were independently reread from the owned node rather than trusted from simulation output.

The early reward claim mined with status 0 and exact `MigrationRewardsClosed()` return data. Then `evm_increaseTime(7776001)` and `evm_mine` advanced the actual block timestamp by **7,776,001 seconds**, recorded in `release-mined-cliff-clock.json`. No script-only warp substitutes for this step.

Stage B first paid token 3's **1,201,585,232 principal units with zero rewards while closed**, then activated through the actual contract owner and removed exactly five selectors: `0xec55c474`, `0x161d9afc`, `0xccff9894`, `0x787642e8`, `0xe9dc9e6d`. It subsequently paid **1,065,857,776** NFT reward units, **9,810,261** deferred wallet units, and **717,112,024** captured fee/creator units to the actual beneficiary `0xc02C5970BC54EB54442C421C7DE43Eec12481C5D`, not to the caller.

It tokenized **2,903,655,350,914,193,571,309,238 native RT units** and redeemed them for **5,529,754 native receipt units** to the chosen receiver. The owner's unpayable remainder stayed **394395608778125083915324042509108970 gons**; the subsequent native-remainder claim correctly paid zero at that index. This is not called a positive remainder payout: the dedicated below-quantum real-expansion test supplies that positive proof. Stage B also executes the existing token's later zero claim without inventing more rewards, and creates an unmarked ordinary active bond.

Final receipt backing equals accounted backing: **2,696,982,231**. Snapshot identity is unchanged. All 16 Stage B receipt statuses and block hashes were reread from RPC. Events, actual state, RT supply, holder balances, and issuance history are in `release-stage-b-readback.json`.

## Metadata and visual evidence

Final `metadata/release-cliff-issued`, `release-cliff-mature-closed`, `release-cliff-active`, and `release-ordinary-active` JSON/SVG pairs come from the final chain's real tokenURI return values or mined owner-fixture capture events. The mature-closed capture is after the successful principal claim, so its remaining and claimable principal are correctly zero while accrued rewards remain unpaid. Activation changes reward claimability, not the already-paid principal. Ordinary token 4 retains the ordinary linear renderer.

The unchanged SVGs were rendered in responsive embedding and inspected in light/dark canvases. `release-light-1440.png.b64` and `release-dark-1440.png.b64` are **1440 x 1100** PNGs; the two `release-*-390.png.b64` files are **390 x 1800** PNGs. Chrome device metrics, actual `innerWidth/innerHeight`, document scroll width, and PNG IHDR dimensions all agree. No horizontal overflow, blank card, clipped text, or visible text overlap was observed; SVG text bounds also pass. Files are lossless base64-encoded PNG bytes, not SVGs renamed as PNGs. `verification-summary.json` records their headers, hashes, measured metrics, text bounds, and hashes of the final metadata JSON/SVGs.

Earlier non-release screenshots remain historical evidence only. Their filenames are **not** measured 390px viewport proof; root observed earlier PNG headers of 520x353 and 500x243. Root's partial inspection found coherent 0%/100% cliff states and locked/open reward amounts, with no visible overlap. That inspection is not independent core acceptance. No source redesign was made in response; the final capture harness explicitly fixes/measures viewport dimensions.

## Failed attempts, repairs, and tool limits

Exploratory logs and failed local receipts remain preserved; only the final runs above are the passing claim. Early artifact plans failed on ambiguous WETH/V3 names and were repaired with fully qualified artifact IDs. Integration compilation and focused failures were resolved inside the owned source/test boundaries; prior gold expectations were not weakened. The final retained-accounting fixtures use valid quote-size/standing-only preconditions and `vm.getBlockTimestamp()` for successive cheatcode clock advances, avoiding compiler reuse of `block.timestamp`. The below-quantum witness uses actual funded expansion within the admitted timestamp domain, not injected storage/index values.

Two initial local attempts and their recovery journals are archived under `attempt-01-runtime-cache/`, `attempt-02-runtime-cache/`, and corresponding broadcasts/failure records. The first fully successful rehearsal is also retained. The final release rehearsal uses the actual contract owner and resolves fee/creator beneficiaries from the real role NFTs, requiring a positive role payout. It is fresh-chain execution, not a recovery-resume claim.

Earlier Solidity symbol/patch diagnostic requests timed out or briefly reported stale symbols; these are not counted as success. Final fresh diagnostics report no issue for all 45 source paths, and Solar plus real execution prove the integrated source. Solar/Foundry warnings remain in raw output, including the existing nightly-build and fmt.skip configuration warnings; no warning/error suppression was added. The JSON/HTML Biome LSP is unavailable and was not installed or configured. Evidence JSON was parsed directly; Solidity diagnostics and compilation are the code checks. An earlier terminal-stop operation reported a state-file permission error, but the process released its port; final-node shutdown succeeded cleanly.

## Cleanup and remaining gates

`cleanup.json` records the final owned monitor stopped, no listener on port 18548, the empty owned `.migration-core-tmp` removed, and all kernel-owned WebViews closed. Warm `out/`, `cache_forge/`, shared links, raw evidence, and completed broadcast journals are preserved. No other session's process or port was stopped.

The implementation producer has no outstanding check or local resource. Independent `verify-core` acceptance remains root's next DAG node, not this producer's verdict. Source/attribution decisions, historical recovery bindings, surrender, harvest/resume scripts, eventual operator rehearsal, full-release validation, and operational authorization remain explicitly open.
