# Independent direct claim-vault verification

Date: 2026-11-12.

**Verdict: needs-fix. Direct claim-vault integration is not implemented or
runtime-confirmed.** The final sealed producer report stops before implementation
because exact archived deposit semantics were not authenticated. Independent
inspection agrees that the candidate has no source/test/operator delta and no
controlled-wallet acquisition or direct-share execution receipts. This is not a
defect finding against the previously accepted phase15 W-SD integration.

All six producer seal entries and eleven input bindings independently match.
The retained 6,154-byte facet runtime independently hashes correctly. These
checks authenticate the bounded handoff, not a working direct-share product.
**No verifier-owned runtime or pending operation remains.**

## 1. Blocking findings

### F1. Required acquisition/source gate remains open

Location: `../implementation/report.md` sections 2-4 and
`../implementation/source-admission.json:deposit`.

No authenticated archived deposit implementation or actual controlled direct
holder/acquisition is supplied. The observed deposit selector, routed facet,
unbounded `maxDeposit` and matching runtime hash do not establish payment,
caller, rounding or mint semantics. The producer did not attempt a deposit.
Therefore this evidence cannot authorize substituting infrastructure-owned
shares, raw TokenStaking weights, a current local ERC4626 implementation, or a
generic ABI for the required controlled-wallet proof.

Required closure: authenticate the exact deployed facet's complete
deposit/redeem semantics and establish real controlled-wallet acquisition with
actual underlying payment, or substantiate a legitimate direct holder. This
verifier makes no production fix and does not choose a source workaround.

### F2. Direct-share configuration, surrender and recovery are absent

Let M denote
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
Actual source observations:

- `M/interfaces/IUniswapV4DetfMigration.sol:134-225,318-340` exposes WD, WY
  and native28 W-SD records/surrender, not a native19 claim-vault record or
  surrender method. Literal searches across Migration production and the
  operator find no claim-vault integration.
- `M/interfaces/IUniswapV4DetfMigrationRecovery.sol:6-17` ends its stage enum
  at `DtfCustodySeRedeem`; there is no claim-vault-share-to-SY stage.
- `scripts/recovery/dtf-migration/payloads.ts:38-47` explicitly blocks
  claim-vault support because direct-user native19 records and integration are
  absent. It separately retains the raw-weight caller restriction.
- `scripts/recovery/dtf-migration/rehearse.ts:37-44` still requires port18565
  and `.omo-runtime/dtf-migration-dtf-custody-se/checkpoints`, not the phase16
  port18566/checkpoint contract.

Both tracked and staged diffs are empty at the exact audited base. Before this
verifier's writes, full untracked status contains exactly the producer's seven
implementation evidence files. Thus there is no changed production code to
accept or final integrated runtime to replay. Required closure is an actual
sealed phase16 implementation and its evidence, not changing a blocked flag.

### F3. Required independent runtime gates are unmet

Location: phase16 brief, "Scope and verification"; producer report section 5.

Complete artifact-first Migration specs/forks, affected operator-stage builds,
operator tests/types and the fixed18566 CLI with three raw-receipt/signature
reconciled resumes were **not executed by this verifier**. There are no actual
changed production roots for an artifact-first phase16 build and the present CLI
rejects the requested phase16 domain. Replaying the old18565 scenario or
unchanged base tests would not establish the missing feature.

All-exit0 acceptance remains unmet, not waived. No fresh custody, partial/final
credit, callback/funding rollback, selected redemption or protected mixed-
inventory result is claimed.

## 2. Authority and exact checkout

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-16-claim-vault`.

Branch: `work/dtf-migration-phase-16-claim-vault`.
Observed unchanged HEAD: `4a53299b490343ed904d70c92ecbc7360fcb7659`.

Root's `.omo/boulder.json:64-68` records exact-clean warm-worktree verification
before phase16 dispatch. Independent read-only checks confirm the branch/base,
present `out/` and configured `cache_forge/`, and prescribed links:
`lib/crane` -> `/Users/cyotee/Projects/indexedex/lib/crane`;
`node_modules` -> `/Users/cyotee/Projects/indexedex/node_modules`.
No link or cache was replaced or reseeded. These observations do not
reconstruct root's original copy operation or audit every warm artifact.

Read the complete phase16 brief; current main plan r5 and PRD r22; complete
owner-first-bond directive; complete phase15 independent runtime and commit
reports; phase11 claims authority and sections 1, 4, 5, 8 and 9; and the complete
phase11 independent report/matrix. Historical Stage1 surrender wording is
superseded by current Stage2-only surrender and the genuine paid owner-first
bond prerequisite.

`checks.json:authorityInputs` retains all eleven absolute paths and recomputed
raw SHA-256 values. The controlling identities include:

| Input | Independently recomputed SHA-256 |
| --- | --- |
| Phase16 brief | `4becd1e7004a89c1d2d0c9bd6e173b4ca869a01c4d5531ece7235440a7c20737` |
| Main plan r5 | `60d02b608c8a10f19cffce7b99838146c205a98410641e9bce45944e620dc56d` |
| Main PRD r22 | `cfe1853f49de0dc41ae106f1cc1b94eacd24d4aa8f79477c66a5b7f24a4d67ed` |
| Owner-first-bond directive | `29dca72edabe86612e98665a941d1f621cb7184e707bbfa841385fa779ccfb92` |
| Phase15 independent runtime report | `77e67678c3180b4ef487fb40567131e9aea0e6c03f7f0f0f1f66003d1226669e` |
| Phase15 independent commit audit | `8e5f291d701451e1df225078905391feb47a6d37edee5ca31b1c521e5d412b9e` |

Phase15's 122 specs, 71 forks, 62 operator tests and actual18565 resumes are
prior independent results, not executions by this phase16 verifier. Its
native28 DTF-custody shares are not this native19 vault. Its single regenerated
test JSON and unretained-old-JSON qualification remain historical; no stronger
artifact-equality assertion is made here.

## 3. Sealed producer evidence and source identity

The complete final producer report states evidence-only modifications stopped
after its nonrecursive seal, with no owned runtime. All required report,
binding and cleanup files exist; no missing-final-report wait was needed.
Root was notified through its actual thread
`01a1c343-d102-7e05-9b68-d96021c7fb4e`,
delivery `00bb43f2-8652-4916-ae95-492169177cca`.
An initial `task_send("root")` had no matching task; the later thread delivery
succeeded. No external message was sent.

| Producer file | Independently recomputed raw SHA-256 |
| --- | --- |
| report.md | `e9a77a596bd7842bb38a8f4a45c95fe95ec887eedec949206de78b0b97125efe` |
| bindings.json | `d14ba63a367280a51a4b29f6d0edd41dafb8c0c67b35c3f5bbc1e50d10056754` |
| cleanup.json | `8b42c54a7f42ca1d5aeb6c3cf18b7b6a639aac8d04d2c17a1fb88670918edfd4` |
| input-bindings.json | `a5a3635d31596c0f95be642752347dd3f35b5f83ee2599f953365c41473a0c93` |
| source-admission.json | `e3c10c52ea2aaf1e22c520e371da147980dd2a902beca0b5528fd2f4069495b6` |
| archive-attempts.json | `4e8b5fdd4b0fe92b4c3708a914be322818223db937e31d99ab1515bb718301c6` |

All six match `../implementation/seal.sha256`. All five retained unsuccessful
HTTP response bodies independently reproduce their recorded SHA-256 values.
Those are retained producer requests, not new verifier network requests.
Exact-facet lookups returned404; the IPFS request returned429. This is evidence
of unsuccessful retrieval, not proof of disabled deposits or source absence.
No retry, alternate gateway, service-worker workaround or provider bypass was
performed by this verifier.

The successful 1,208,585-byte proxy archive was not retained. Its recorded
hash/target/source-path inventory can be read, but its original response hash
cannot be independently reproduced here. Its proxy target does not authenticate
delegated vault implementation semantics. Credentials are not the producer's
final blocker; its initial credential hypothesis was explicitly retracted.

| Retained pinned identity | Independently reconciled value |
| --- | --- |
| Chain / block | 4663 /108944663 |
| Block hash | `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733` |
| Direct-share vault / units | `0xAf5C0cD3fDEdd10bee00Eff77Fa0429Bacdb41f0` /native19 |
| Underlying SY / units | `0xB55604CF4dcdABB362078e106D20F98512391EdF` /native9 |
| Deposit/redeem facet | `0x517234F78A4BcAfc5F880024A3E45D49cF43b305` |
| Independently hashed retained runtime | `0x8c1ea71d607b09b21c4e78f850647a059dc7935b6772f7cd3aeaa700a995439f` |
| Retained runtime length | 6,154 bytes |
| Redemption selector | `0xba087652` |
| Candidate deposit selector | `0x6e553f65`; semantics remain unauthenticated |

The runtime hash was independently computed with the existing installed
ethers keccak implementation from the complete retained byte string. It
agrees with the brief and historical route record; this is not a fresh
verifier RPC attestation or a recompilation match.

Historical phase01 files under
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/verification/`
were inspected at `other-metered.sources.json:203-298` and
`other-metered.json:8970-9184,9305-9322`. Their complete raw files also match
the producer input bindings. Historical custody receipt
`0xbfd713f0ff0a1fd4250cf720489d9d427f75cc98901696a4630dc17e492f9ed7`
is explicitly funded from TokenStaking infrastructure
`0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00`, marked
`fixtureMayBeInfrastructure: true`. Historical redemption
`0xd03b842118e15cfc252766d7c8150d8e099818f3c326143a1d181d5e95748ed1`
burns 2769125838408621163 shares and records 276912584 SY output.
These are historical mechanical local-fork receipts, not a controlled user's
acquisition or this phase's runtime. Their ratio is not a universal quote.

## 4. Exact coverage boundary and preserved base

| Requested coverage | Independent phase16 disposition |
| --- | --- |
| Genuine controlled-wallet acquisition and native19/native9 units | Units reconcile in retained evidence; acquisition not executed or proven |
| Original-wallet/source/origin/known components and frozen C0 | No direct-share configuration exists; operational originals not inferred from holdings |
| Exact custody, partial/final C/Q, fresh exact-backed90-day bond | Not executed; no direct-share surrender exists |
| Cross-origin, missing/wrong wallet, transfer-away/back and no-effect negatives | Not executed for direct shares; no prior-category result substituted |
| Approval, zero-credit, deadline/minimum, callback/funding rollback | Not executed for direct shares |
| Selected own-share burn, measured returned SY and single WY admission | No installed claim-vault recovery stage; not executed |
| Mixed/booked/unbooked inventory, backing and donation protection | Existing policy inspected; no new direct-share composition proof |
| Three actual raw receipt/signature reconciled resumes on18566 | Not executed; no new interruption journals or receipts |
| Source/artifact/runtime binding | Source unchanged; retained historical facet bytes hash correctly; no phase16 compiled/deployed artifact |

`M/UniswapV4DetfMigrationAllocationTarget.sol:278-307` still requires
`ownerFirstBondTokenId != 0` before activation and removes the nine
interface-derived administration selectors before marking activation.
`M/UniswapV4DetfMigrationPolicy.sol:18-55,125-127` retains operation-local
inventory floors and activation-gated mint permission. Empty tracked diffs
establish preservation relative to the audited base. Stage1 reward closure and
irreversible administration removal retain phase15's acceptance, not a new
execution claim in this report. No new loader exists to add to that cut.

No raw-weight or infrastructure authority was substituted, no second backing
award was configured, and no live source rate was used to manufacture C0.
The phase11 caller/disabled/source/unit limits remain separate. This verdict
does not reverse the accepted first-bond, reward or Stage2-only rules.

## 5. Executed checks, generated outputs and cleanup

Actual verifier checks: complete required-document/report reading; six seal
hashes; eleven raw input hashes; five retained response-body hashes; retained
runtime keccak/length; actual source/interface/operator inspection; exact
branch/HEAD; full untracked status; empty tracked/staged diffs; whitespace;
warm-path/link presence; checkpoint absence and fixed-port listener absence.
`checks.json` retains the per-path bindings and explicit unrun gates.

The compound worktree checks in terminal `bash_4` exited0. Ordinary submodule
status had previously failed128 because `lib/crane` is the prescribed symlink;
read-only `--ignore-submodules=all` succeeds without changing configuration.
The initial `bash_1` used an unsupported working-directory parameter and
reported main-checkout status rather than this worktree. It was read-only,
was not accepted as worktree evidence, and was corrected with explicit
`cd` in all subsequent worktree commands. No main-checkout edit occurred.

No Forge build/test/script, operator test/typecheck, stage build or CLI was
run. None has an invented exit0 or passing count. No production root was
edited, no generated build/broadcast/artifact/cache output was intentionally
refreshed, and no claim of full warm-artifact equality is made. The only
verifier-authored files are this report and `checks.json`.

The JSON diagnostic hook reports Biome is not installed. No dependency or
configuration installation was made; the evidence was JSON-serialized instead.
No Solidity/TypeScript edit required a new compiler diagnostic pass.

Port18566 has no listener (`lsof` exit1, explicitly distinguished from a
successful listener query); the fixed
`.omo-runtime/dtf-migration-claim-vault/checkpoints` path is absent. All owned
short terminal probes have exited. Zero nodes, impersonations, receipt
watchers or subscriptions were started; no owned operation remains pending.
There are no runtime files to remove. Producer seals/evidence, linked
dependencies and warm caches were preserved. No public operation, source
role/storage/bytecode/token-balance fabrication, held09 content
inspection/import/replay, production fix, commit or merge occurred.

**Final disposition: needs-fix.** A valid source-blocked handoff is confirmed,
but direct-share support and its required runtime acceptance are not. No
full-category, full-plan, operational-award, target-gas or public-deployment
acceptance follows. This bounded verification is complete; implementation
remains blocked at the concrete authenticated-source/acquisition gate.
