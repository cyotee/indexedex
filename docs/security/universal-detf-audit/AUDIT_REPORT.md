# Universal DETF audit — working report

Status: **in progress; incomplete audit**. Owner authorized local fixes after the original report-only instruction. No deployed DETF bytecode has been reconciled or changed by this review. Read-only Robinhood manager/collector checks are recorded below.

## Latest remediation checkpoint

**Current source: 136 tests passed, one failed, none skipped, across 18 suites / 137 tests.** The matching-root build passed; the subsequent unfiltered test run skipped compilation and completed in 484.08 wall seconds. All new security regressions passed, including zero backing, atomic mint rollback and both-input/both-currency-order reserve reconstruction. The raw/pair deposit-preview minimum regression remains failing. See [current coverage](COVERAGE_MATRIX.md) and [runtime evidence](evidence/focused-harness-unfiltered.log).

All 14 selected artifacts match 212 current source hashes and pass runtime/base creation size checks. This latest checkpoint supersedes older pending-validation statements below; the earlier sections preserve the review history. Exact quoting, initial unclaimed-backing ownership, broader verification and deployed-source reconciliation remain open. This report does not establish production readiness.

## UDETF-SEC-001 — Arbitrary caller can steal mature bond proceeds

Severity: **Critical**. Evidence: **runtime reproduced** on the baseline universal DETF + selected CP hook using real manager/registry/factory deployments. Local fix verified: 36 passing tests across five suites covering CP, Orbital, Weighted and Quad D25 closure plus new holder-authorization regressions. See `evidence/close-auth-after.log`.

### Root cause and impact

`UniswapV4DetfTarget.closeBondMature` checks maturity and reserved NFT restrictions but, before this fix, did not authenticate `msg.sender` against the bond holder. It accepts a caller-selected `recipient`. Its call to `UniswapV4DetfBondNFTVaultTarget.retireMaturePosition` passes the vault's `onlyOwner` guard because the owner is the DETF diamond. That vault checks existence/maturity and retires the NFT but does not know the original caller. The DETF then pays the caller-selected recipient.

An unprivileged caller can close a victim's mature bond, burn the victim's NFT, and receive its capital and pending rewards. No victim approval or attacker capital is required. Repeating this across eligible bonds compromises their exit proceeds. The common universal DETF code is shared across hook bindings; runtime evidence here is specifically CP. Standing reward NFTs remain separately restricted. This is not evidence that an existing Robinhood instance uses the vulnerable bytecode.

### Reproduction

1. Deploy the production universal DETF with the selected CP hook through the existing gold TestBase (ERC-4626 SE fixture).
2. Victim bonds 100 pair tokens, then mints with 20 pair tokens to leave continuing reserve liquidity.
3. Advance beyond the 30-day minimum lock.
4. An unrelated account calls `closeBondMature(victimTokenId, zeroMinimums, attacker, deadline)`.
5. The call succeeds. The trace records transfer of **119880119880119879023 pair base units** (about 119.8801 tokens with 18 decimals) to the attacker, retirement of the victim's position, and a successful return. The negative authorization test therefore fails with `next call did not revert as expected`.

Command: `forge test --match-contract '^UniswapV4Detf_Close$' --match-test test_closeBondMature_rejectsUnrelatedCaller -vvvv`.

Evidence: `evidence/close-auth-before.log`. Source baseline: `BASELINE.md` and `evidence/source-manifest.json`; the only new test source at reproduction was `UniswapV4Detf_Close.t.sol`. Production source was unchanged at reproduction.

### Local correction and required verification

Authenticate the current NFT holder at the public DETF boundary before retiring or paying the bond. Reuse `Repo.NotAuthorized(msg.sender)`. This follows the existing holder-only bond helper policy, retains current-holder recipient choice, and requires no new storage or ABI selector.

Regression tests cover unrelated caller rejection, former-holder rejection after NFT transfer, and successful close by the new holder to a separate recipient. Rebuild artifacts before testing because factory services load production creation bytecode from `out/`. Also run existing CP/Orbital/Weighted/Quad D25 close suites for shared-code regressions.

Prior report linkage: the historical `audit/areas/A-detf-univ4-extra.md` described holder authorization on older Uni V4 paths. That record is not proof for this universal entrypoint. No identical current universal finding has yet been identified in the reviewed records.

## Other observations under investigation

- Hook bootstrap now rejects noncanonical tick spacing in `beforeInitialize`; 34 staged-init tests passed at the first combined checkpoint; final-source rerun remains pending.
- [AMM review](amm-review.md): local corrections cover the public swap callback lock and pre-intake growth fee accrual. The four callback tests passed at the first combined checkpoint. Eight fee-capital tests passed initially; the follow-up growth selection passed three and retained one raw/pair preview failure.
- [Precision review](precision-review.md): local corrections cover LP/original-share conversion, exact-output claim units, live valuation and internal precision on principal release. Zero-share mint results now revert without changing bootstrap ownership. The original five accounting regressions passed initially. Exact-output wiring was corrected after the initial failures. The latest zero-backing valuation and atomic zero-balance mint correction, with two new regressions, awaits compilation and execution. Claim purchase preview parity remains unresolved.
- [Deployment review](deployment-review.md): local packaging corrections now clear the runtime size limit in both isolated compilation and refreshed Foundry artifacts for 14 selected production components. Four universal facet-packaging and two NFT-packaging tests passed initially. Final-source validation and deployed-source identity remain unverified; see `evidence/production-sizes-final-canonical.json`.
- [Access review](access-review.md): bounded fee collector and authority review, with remaining routing/configuration questions.
- Principal issuance now rounds down consistently in the universal helper and shared NFT deposit conversions, while retaining decimal offsets and redemption rounding. User joins that cannot receive one original-share unit revert atomically; sub-share compounding preserves pending rewards, and close rejoin dust remains unassigned so exits stay available. Production regressions have been added but not yet run.
- Fee Collector manager exposes owner-only `pullFee` and permissionless reserve synchronization. Receipt at `feeTo()` alone does not prove conversion/donation into the protocol DETF; remaining routing and deployed facets still require review.
- At Robinhood mainnet block `0x34c6dc1`, manager `0x09682b00D873D913ada0bB69B4D4c9631810d0bc` returned the recorded collector `0x20af9A1e21a59a411cd3b0C40E70AF9084770b2E` from `feeTo()`. Collector `owner()` returned `0x72BeA6Fa3E68EF18c87D045Aac7C4Aa5249d933B`. Proxy code presence was checked at `latest`; this does not establish implementation identity or downstream conversion. See `evidence/robinhood-fee-route.json`.
- Default fuzz effort is 16 runs and invariant effort is 16 runs/depth 8. Adequacy requires scenario analysis, not a blanket claim that those values are sufficient or insufficient.

## Tooling evidence and limitations

Follow-up corrections after the first combined run: CP single-asset reserve reconstruction now subtracts the actual raw-currency add leg; the SE-share preview uses rounded aggregate claim growth; universal claim deployment advertises DETF, matching D15 and the actual payout token. Four unequal-decimal/currency-order tests and a claim wiring assertion were added. The first combined run was 112 pass / 19 fail; corrected fixtures preserve actual mint-event, balance, rollback and dilution assertions. The focused fee follow-up was 3 pass / 1 fail: SE-share parity passed, while the raw/pair preview remains one atomic LP unit above execution in the recorded fixture.

**Unresolved exact-quote capability:** CP single-asset preview currently uses pre-swap reserves, and generic SE previews cannot express sequential post-buffer/post-unwrap aggregate claims. The raw/pair two-asset preview also loses one unit in the nested rounding fixture. A fixed-unit haircut is not a general correction. The required state-transition quote capability and evidence are recorded in [the proposed remediation design](PREVIEW_REMEDIATION_DESIGN.md); universal claim purchase rebasing-balance preview remains separately unresolved. These items preclude a production-readiness conclusion.

- Initial `forge build` completed successfully with compilation skipped on warm artifacts.
- New regression test compilation succeeded in 28.07 seconds, then sandboxed Foundry crashed in macOS system proxy initialization (`system-configuration` / `ExternalIdentifier`). An approved run outside the sandbox completed and reproduced UDETF-SEC-001.
- Isolated production compilation passed with solc 0.8.35, optimizer 1, Prague, and no IR. The universal product facets range from 14,810 to 18,680 runtime bytes; the CP deposit facets range from 12,952 to 14,388 bytes. Internalizing six unrouted NFT methods reduced its runtime from 24,791 to 23,958 bytes while retaining proxy selectors. Nine selected regression files passed ABI typechecking. These checks do not substitute for runtime tests.
- Separate production Foundry build passed (2,331 sources; 1,563.83 seconds). Source-metadata verification passed for all 14 selected artifacts and 212 unique dependency sources. The later normal-contract-root focused run compiled 2,355 sources in 2,537.91 seconds and is executing against canonical output/cache with 128 fuzz runs. Its compiler input predates the latest zero-backing changes; a matching-root build and unfiltered rerun are required afterward.
- Full hook math, shared claim accounting, dependency review, broader test matrix, gas benchmarks and deployed-source reconciliation remain unfinished. This report is not a deployment approval.

## External references consulted

- [Uniswap V4 flash accounting](https://developers.uniswap.org/docs/protocols/v4/concepts/flash-accounting): reference for delta settlement review; no integration-correctness conclusion inferred.
- [Uniswap V4 hooks](https://developers.uniswap.org/docs/protocols/v4/concepts/hooks): reference for permission/callback review; local Crane implementation must be checked separately.
- [Robinhood network configuration](https://docs.robinhood.com/chain/connecting/): official mainnet chain ID 4663 and testnet 46630; exact deployed contract configuration remains unverified.
- [ERC-4626 conversion and deposit rounding](https://eips.ethereum.org/EIPS/eip-4626#converttoshares): downward share conversion is consistent with the project's original-principal deposit accounting; this is not a claim that the NFT vault implements the entire ERC-4626 interface.
