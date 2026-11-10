# Bounded frozen original-credit snapshot evidence

Date: 2026-11-10. Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-02`.
Base HEAD: `90ff0307a7a8e084aa073e02eff125e9c7973933`; no commit was made.

**DoneClaim: the bounded direct-pair / recognized ordinary V3-deposit / raw-DETF-output increment is implemented and proved. This is not completion of task 2 for an unidentified recovery configuration, E3, the full Migration plan, or lifecycle integration.** No receipt model is admitted. The local assets are fixtures, not historical ETH/DTF records or pinned recovery assets.

All evidence paths below are relative to `pricing/evidence/implementation/` unless stated otherwise. `source-manifest.json` lists the exact 17 authored Solidity paths, sizes and SHA-256 values. All are within the authorized list. The four receipt-production paths were deliberately not edited. Runtime evidence is confined to this evidence directory and normal phase-owned build/broadcast outputs.

## Supported configuration and implementation identity

`support-manifest.json` and `rpc-proof.json` identify the actually deployed sources:

| Role | Actual local address |
| --- | --- |
| One-shot consumer | `0x28dB1faE7d59B36aE6BBB939766F3F7F1c3eabec` |
| Real DETF proxy / raw output | `0x0Db4a30BB8A6A1873455693a33d732DBF0ABF9E2` |
| Weighted hook proxy | `0xb85cBEDF5098cCD53152386980702FD4245C6aa8` |
| Manager, registry and fee oracle | `0xAa66038Ae217b246F5bF7537104342672e56fed8` |
| ETH-quote pair A, 18 decimals | `0x9283F3Ff485698b26333120D2F24c0dDBfd5BF08` |
| Original-DTF-quote pair B, 18 decimals | `0x536dA309fa11FEF8Fc8B94F5A9f7a608cdBbF3Ee` |
| Pair A's real V3 SE | `0x29103624cFf0c4FF93f41065b08aa5bA199bDFbE` |
| Pair B's real V3 SE | `0x6704e2474fdC91BB25e608F3B6FA50cEf9b80FE1` |

The two contribution-to-pair conversions are identities. `address(0)` is the ETH contribution identity, normalized to the configured pair A for quoting. Pair A is a mintable fixture, **not an actual WETH deployment**. Both pair legs are real V3 SE-buffered legs with production rate-provider proxies; the DETF self-leg is raw and has 9 decimals. Pair weights are `3e17` each; the DETF weight is `4e17`. Thus both primary quotes execute the canonical noninteger `0.75` exponent.

V3 admission checks the installed capture and ordinary-preview facet runtime hashes against **complete compiler-produced runtime code**, through two immutable linked identity libraries. It does not trust a caller-supplied hash, a model enum alone, or ratio probes. Both recognized facets have no immutable or link-reference substitutions. RPC code read-back also matched both artifacts byte-for-byte:

- Capture selector `0xe13e2921`: facet `0xb33507fffc8f37eba70a1b8bf58b72f9cc370dda`, 15,973 bytes.
- Ordinary preview selector `0x89d61912`: facet `0xde155799f66db238883a60c6ea9b713bfa709146`, 11,012 bytes.
- Existing selectors and interface IDs remain present. The added interfaces are separate; the existing exact V3 declaration control was extended, not weakened.

The capture primitive takes composition-owned source identities, not numerical prices. The supplied subject fee-oracle identity must match its package configuration; ordinary DETF exposes no public getter for that identity. The demonstrated fixtures and script install the same real manager oracle into the DETF package and consumer. This is an explicit composition precondition, not certification of arbitrary caller-selected source contracts.

## Frozen dependency closure

Capture copies the configured mint routes and first-match pair order, provenance/version/chain/consumer/subject, both resolved contribution edges, hook raw retained reserves and attributed SE reserves, weights/scales, provider status and exact return bytes, registry registration/disable outcomes, hook fee outcome, and resolved seigniorage. Calls originate in the hook context where ordinary pricing requires it. Unsupported reachable recipes fail before snapshot storage is installed.

For enabled V3 inputs, capture stores typed direction/mode/holder, token identities, supply, and complete `_totalVaultReservesForShareMath()` totals, including position inventory and unpoked fees. Evaluation reuses canonical constant-product deposit arithmetic at the actual post-fee amount. It does not use a linear rate surrogate or later call the SE with serialized bytes.

The consumer installs one encoded book only after successful acquisition. It has no recapture or mutation setter. Snapshot identity includes the format domain, chain, consumer, subject, block/time, parent block hash and captured contents. Each original component starts from the same book. Evaluation is pure apart from reading the consumer's sealed bytes and calling linked pure weighted math. No swap fallback, partial re-quote, sequential reserve update, source callback or live metadata/fee/registry/provider/pool query is used.

`rpc-evaluation-trace.json` independently records `debug_traceCall` after the mined mutations. Its eight child calls are all `DELEGATECALL`s to `0xe5d5e6a31abecb23810e49dbb5a24ed3c399434b`; that runtime matched the canonical 6,481-byte weighted math artifact. No live source target appears. `rpc-capture-trace.json` records the separate mined capture transaction.

## Actual mined proof

The exact requested script invocation completed with exit 0, not merely a dry run:

```sh
FOUNDRY_BLOCK_GAS_LIMIT=1000000000 forge script --use solar \
  scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol:MigrationSnapshotLocalQA \
  --rpc-url http://127.0.0.1:18546 --broadcast --unlocked \
  --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
```

`local-rpc-07-command.txt`, `local-rpc-07.log` and `local-rpc-07-exit.txt` retain argv, environment, output and exits. The log reports `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL`. The broadcast artifact is:

`broadcast/MigrationSnapshotLocalQA.s.sol/31337/run-latest.json`

It contains **233 transactions and 233 successful receipts**, all sent by the standard unlocked development account. Capture transaction `0x238268a2bccdcc7170952404fe26627b98db3a1830b2dc1d0749582039ab526b` mined in block **227**, using **3,842,683 gas**. Seven subsequent transactions mined through block **234**: real DETF exchange, hook-fee update, seigniorage update, token transfer into the real SE, approval, real SE deposit, and registry disable.

Historical `eth_call` read-back at block 227 and block 234 returned identical **5,632-byte stored snapshots**, identical intermediate results and identical user sums. `rpc-proof.json` preserves the exact RPC requests, responses, selected receipts, and the independently composed real-source primary mint oracle.

| Native integer | ETH original `2e18` | DTF original `3e18` |
| --- | ---: | ---: |
| Pair equivalent | 2000000000000000000 | 3000000000000000000 |
| Boosted at captured p = 5% | 2100000000000000000 | 3150000000000000000 |
| Net after captured hook fee | 1995000000000000000 | 2992500000000000000 |
| Rated mapped inflow | 1490988852592040823 | 2233681549914704346 |
| Frozen gross DETF | 1255270181 | 1866950978 |
| Frozen user DETF, before and after | **1192506671** | **1773603429** |
| Live user DETF after mutations | **1290890931** | **1566579720** |

The unchanged frozen sum is **2,966,110,100 native DETF units**. Both live outputs changed. The oracle used real DETF `peekPairEq`, the real oracle's p, canonical uplift, real hook `previewExchangeIn`, and the independently floored user split. Evaluation trace gas was **451,403** for both originals together.

### Local gas configuration and preserved failed attempts

The owned Anvil started fresh with:

```sh
anvil --host 127.0.0.1 --port 18546 --chain-id 31337
cast rpc --rpc-url http://127.0.0.1:18546 anvil_setBlockGasLimit 0x5f5e100
cast rpc --rpc-url http://127.0.0.1:18546 anvil_mine 0x1
```

The port was checked free before startup; no preexisting listener was touched. Node PID was **62662**. The final node reported hardfork `Bpo1`, no fork URL, and a finite **100M block gas limit**. Code-size enforcement was never disabled.

`local-rpc-01` through `local-rpc-06` preserve failed simulations, all exit 1. Initial failures exhausted gas in the unchanged ordinary DETF/SY deployment. An explicit per-call budget and shorter metadata did not solve it. The 100M Forge simulation override instead exhausted the *whole script* at 99,956,395 gas. A finite 1B simulation budget alone still encountered the old per-call constraint. Inspection then showed Anvil's configured limit was 100M while its latest **genesis header still said 30M**. Mining the configuration into a new header allowed the exact command to succeed. These failed runs mined no product transactions.

This distinction matters: the largest successful **actual** transaction used **33,584,353 gas**, not 1B. Its receipt is retained in `rpc-proof.json`. This proof does not claim deployability under a 30M block budget or any untested target-chain transaction cap.

## Verification commands and results

Every command explicitly selected `/Users/cyotee/.foundry/bin` and the owned TMPDIR/cache paths through `run.sh`. Selected binaries were Forge `1.9.1-nightly` (`430523103f3e2f9ba432ffdd2031a9f966153d0d`) and Solar `0.3.0-dev+commit.e7a91fc7`. No viaIR, solc fallback, installation, configuration/lock edit or public-chain action occurred.

`regression-final-command.txt` records the literal expanded:

```text
python3 scripts/forge-artifacts.py test <all 17 edited Solidity paths>
  --test-root <each exact selected test path, repeated> -- -vvv
```

This line describes the shape, not a substitute executable receipt: the complete actual argv is in that command file. The first lines of `regression-final.log` contain the helper's exact expanded `forge build --use solar` and `forge test --use solar` commands, including all generated `--skip` exclusions. The helper builds runtime artifacts before tests and stops on a failed build. Its exit 0 and passing tests therefore establish build exit 0 and test exit 0; recorder tee exit is separately 0.

Final result: **111 passed, 0 failed, 0 skipped in 15 suites**. Selection includes the new snapshot suite; both unchanged weighted DETF suites; the edited V3 declaration suite; weighted Swap, Scale, Fees, RefundCallback, OwnerDuringLock and SeBufferAbi suites; receipt TransitionQuote; and V3 FullRangeBook and Previews. These cover the shared arithmetic extraction, ordinary manager-context behavior, callback/refund behavior, source routing and unaffected receipt transitions.

The producer's original additional exact-filter invocation returned Forge exit 0 and tee exit 0 but executed **zero tests; it is not an executed PASS**:

```sh
forge test --use solar \
  --match-path test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshot.t.sol \
  --match-test '^test_MigrationSnapshot_RealProxyCaptureAndFreeze$' -vvvv
```

Preserved zero-execution receipts: `real-proxy-trace-command.txt`, `real-proxy-trace.log:94-98`, `real-proxy-trace-exit.txt`. The verifier's first invocation of that same original filter also executed **zero tests; it is not an executed PASS**: `../verification/real-proxy-command.txt`, `../verification/real-proxy.log`, `../verification/real-proxy-exit.txt`.

Actual producer coverage is the PASS at `regression-final.log:3773` within the unchanged 111-test run. Independent executed coverage is `../verification/real-proxy-exact-signature.log`: **1 passed, 0 failed, 0 skipped**, gas 13,063,518, command/tee exits 0/0. No unchanged pricing test was rerun for this correction.

For a future invocation, the contract is the exact ABI-signature regex plus the exact contract and a nonzero executed-coverage gate, not exit status alone:

```sh
set -euo pipefail
log="$TMPDIR/migration-real-proxy-exact-signature.log"
forge test --use solar \
  --match-path test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshot.t.sol \
  --match-contract '^UniswapV4DetfMigrationSnapshotTest$' \
  --match-test '^test_MigrationSnapshot_RealProxyCaptureAndFreeze\(\)$' -vvvv \
  2>&1 | tee "$log"
grep -Eq '^\[PASS\] test_MigrationSnapshot_RealProxyCaptureAndFreeze\(\) \(gas: [0-9]+\)' "$log"
grep -Eq '^Suite result: ok\. 1 passed; 0 failed; 0 skipped;' "$log"
```

### Local execution guard correction

The original hard-coded `anvil_nodeInfo` probe did not constrain Forge's selected broadcast endpoint (independent finding F1). The corrected script uses `vm.ffi` to run `scripts/recovery/dtf-migration/pricing-local-qa.sh`, which reads the actual parent Forge process argv with `ps` and permits only the complete direct CLI shown above: exact target, Solar, `http://127.0.0.1:18546`, broadcast, unlocked and the standard dev sender, in that order, without additional arguments. It accepts no environment endpoint assertion, does not select a fork, and rejects duplicate/override flags. The chain-31337/dev-sender check remains; `anvil_nodeInfo` now queries the selected RPC. All checks precede `startBroadcast` and deployment. The helper is a process guard, not a launcher; the direct Forge invocation remains the execution contract. See `../correction/report.md` for positive/negative execution, source binding and cleanup receipts.

The new tests cover every primary intermediate, both-component sum, zero components, nonlinear grouping, order-independent book reuse, one-shot capture, unsupported conversion and receipt rejection, exact revert bytes, native overflow/dust, max-in equality and the next mapped native input, p/fee endpoints, canonical 4.0/equal-weight controls, real 0.75 weighted quotes, real 6/9/18-decimal proxies, naturally open public preview versus closed-gate fallback, effective fee/registry changes, real V3 backing/supply changes, real pool price/fee-growth changes, and source-storage independence. Malformed/missing/zero/unused third-leg provider outcomes are explicitly **unit-only memory vectors**, not fake production sources.

The already accepted unchanged baseline was not rerun before edits. Intermediate receipts remain:

- `regression-01`: 93 passed, exit 0.
- `regression-02`: helper exit 2, nonexistent `Permit2.sol:Permit2`; corrected to the existing `BetterPermit2`.
- `regression-03`: helper exit 2, ambiguous V3 factory basename; corrected to the exact protocol-port source path.
- `regression-04`: 93 passed, 1 failed, exit 1. The new decimal test incorrectly used the sorted mint token's decimals while its inherited first-bond helper actually pays with pair A. Corrected the new test to `_uPair(100)`; no gold fixture was changed.
- `regression-05`: 95 passed, exit 0.
- `regression-final`: 111 passed, exit 0.

## Sizes, diagnostics, scope and failure classes

`runtime-sizes.json` records EIP-170 sizes: weighted HooksFacet **13,095**, weighted DFPkg **15,835**, ClaimLib **11,627**, V3 InQueryFacet **15,973**, V3 DFPkg **6,386**, consumer **9,893**, math exposure **5,047**, capture-identity library **16,109**, preview-identity library **11,148** bytes. All are below 24,576. Actual installed V3 runtimes were also checked through RPC.

`diagnostics.json` retains actual per-file LSP results. No Solidity error remained in successful responses. The unchanged weighted DFPkg `postDeploy` has a mutability warning at line 351. Final fresh diagnostics timed out at 3,000 ms for the new test suite and QA script; these are **not** claimed clean, although both compiled and executed successfully. Earlier script import diagnostics were fixed. Bash language server and Biome were unavailable; no installation was attempted. `bash -n` and `git diff --check` passed.

`scope-status.log`, `scope-diff.log`, `final-scope.log` and `source-manifest.json` retain scope evidence. Only the listed nine tracked files changed, plus the eight explicitly new Solidity files and authorized evidence/report. Copied incident inputs were already untracked. The `lib/crane` symlink appears in an unrestricted Git stat but was not edited; both dependency links still point to the primary checkout. No initial full-worktree hash was independently captured by this executor; the accepted baseline supplies earlier unchanged-code provenance.

| Class | Evidence / disposition |
| --- | --- |
| Stale state/artifacts | Artifact-first helper; exact runtime recognition; actual RPC code comparison; stale genesis gas header diagnosed separately |
| Dirty worktree/scope | No commits, staging, resets or external-path edits; inherited incident files and shared links preserved |
| Malformed/domain | Deferred provider outcome validation, exact errors and native checked arithmetic tested |
| Callback/atomicity | Capture only static source reads; failed unsupported capture leaves empty consumer; callback and ordinary manager-context regressions pass |
| Misleading success | Primary oracle distinct from fallback; effective mutations asserted; simulation success not accepted without 233 mined receipts and historical reads |
| Interruption | Builds ran under subscriptions to natural exit; failed receipts retained; no compile was killed or duplicated |

## Remaining actual-configuration limits

There is no identified production recovery binding or approved receipt implementation identity here. Arbitrary ERC4626, SimpleYield receipt admission, native nested receipts, Morpho, partial-refund models, buffered DETF output, and V3 conversion/redemption/transition/full-curve routes are **not implemented or certified**. Their reachable unsupported directions/models fail acquisition; there is no live fallback or fabricated zero. Receipt-backing/yield-model proof is not claimed for excluded models.

The newly installed source getters work on newly composed proxies. Editing these sources does not upgrade immutable existing deployments. A real recovery composition must pin its source/oracle/routes, have the required installed getters and recognized code, and demonstrate complete dependency closure and target-chain deployment gas feasibility. Attribution and TokenStaking questions remain outside this increment. No new registry or owner policy was invented.

## Owned resources and cleanup

Owned root: `/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/pricing-implement.5beES5`, created with the requested `mktemp -d` template. Commands exported this TMPDIR, its `/node-cache` and `/bun-cache`, and the selected Forge PATH.

`owned-node-stop.log` records the listener PID/port check and SIGINT sent only to PID 62662. The Anvil recorder subsequently returned command exit 0 and tee exit 0. `cleanup.log` and `cleanup-exit.txt` record removal of the empty owned root and read-back of absent PID/root, free port 18546, retained warm `out`/`cache_forge`, unchanged shared symlink targets, unchanged HEAD and clean whitespace check. Evidence and normal phase-owned build/broadcast artifacts are intentionally retained for the independent verifier.
