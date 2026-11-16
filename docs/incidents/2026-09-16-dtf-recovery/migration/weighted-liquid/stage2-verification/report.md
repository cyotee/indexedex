# Independent Stage2-only surrender and W-L verification

Date: 2026-11-11.

**AdversarialVerify: needs-fix.**

The approved Stage2-only NFT/W-L surrender boundary, implemented W-L loader,
original-wallet custody, frozen partial/final credit, funded fresh bonds,
booked recovery and actual operator interruption/resume behavior are
independently confirmed for this bounded increment. **Unconditional ordinary
deposits after activation are not confirmed:** D1 reproduces on final source.
The complete Migration spec suite is not green. This is not full-category
Migration acceptance or target-chain deployment/gas acceptance.

## 1. Unresolved acceptance failure

### D1: ordinary deposit fails after activation without funded participation

Independent artifact-first execution reproduced:

```text
MigrationCoreTest.test_activationRemovesEntireAdministrationAndKeepsQueries
[FAIL: MissingRewardWeight()]
102 tests passed, 1 failed, 0 skipped
exit 1
```

Reproduction uses the real registry-deployed Migration package: donate and
bootstrap the reserve, capture the snapshot, activate without independent
issuance or surrender, then make an ordinary `exchangeIn` deposit. The
nonzero immediate reward reaches an all-zero reward-weight ledger.

Locations, relative to `contracts/vaults/detf/`:

- `common/claimToken/DETFFundedStakingRepo.sol:52-64` initializes the addresses
  and index, not funded principal or positive standing weights.
- Its `_topUpWeights` at lines 165-174 uses `totalGons`.
  `common/core/DETFSeigniorageShareLib.sol:24-26` returns zero deltas for
  zero ordinary weight.
- `protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol:227-310`
  joins the reserve self-leg and establishes liveness without creating
  staking principal.
- `protocols/dexes/uniswap/v4/migration/claimToken/UniswapV4DetfMigrationStakedDETFTarget.sol:103-125`
  funds and distributes the reward;
  `common/core/DETFFundedStakingMath.sol:79-88` rejects a positive reward
  when aggregate reward weight is zero.

The failing test's cut-failure rollback, Stage1 gate, successful activation,
selector-removal and retained-query assertions execute before its final
ordinary-deposit failure. This does not make the whole test pass. The
separate `test_ordinaryDepositOpensWithFundedIndependentParticipation`
passes actual ordinary acquisition after activation and preserves the
existing bond's start time; it does not justify requiring that participation.

**Economic-law assessment:** `DETF_ALIGNMENT_PRD.md:960-975` fixes standing
fee/creator recipients, existing weight-based allocation and funded receipt
settlement, and forbids a no-recipient carry-forward or arbitrary fixed
percentage replacement. The funded-staking implementation plan section 4.4
explicitly defines ordinary weight as actual funded gons, `O = Q`; its
ordinary first-purchase ordering funds principal before allocating rewards.
Migration's donation-only bootstrap does not supply that principal.

The inspected law and composition therefore do not specify a positive
numerical genesis-weight basis for `Q = Wf = Wc = 0`. Positive standing
weights retained after an earlier full unstake are a different state.
Inference: selecting a bootstrap-self-leg, first-reward or arbitrary-scale
seed would make an additional economic choice. The absolute persistent
weights affect subsequent top-ups and fixed-point floors, not just the
first fee/creator ratio. Root's `migration_genesis_reward_weight_basis`
question remains pending. Neither proposed basis is approved here.

No seed, fictitious principal, carry-forward, first-participant condition,
source fix or test weakening was introduced. No clean-base reproduction
was performed, so D1 is **not labeled a proven pre-existing defect**.
`d1-analysis.md` records the detailed source/law assessment.

## 2. Authority and immutable handoff

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-13-weighted-liquid`.

Branch: `work/dtf-migration-phase-13-weighted-liquid`.
HEAD/base: `2c2b3370ded30cae1662329025d4fb58f7197330`.

The complete correction directive, original phase13 brief, main plan r4,
current PRD r21, old incomplete implementation report, old independent
needs-fix report and new producer report were read. The later approved
Stage2-only rule governs. The old partial-entitlement arithmetic question
is obsolete, not unanswered authority. Configuration and surrender are
mutually exclusive stages.

Runtime replay began only after root confirmed producer completion,
stopped modifications and no owned runtime. Report creation, temporary
idle and workflow completion were not treated as acceptance.

Independent admission checks:

| Binding | Result |
| --- | --- |
| All producer manifest entries | 1,096 raw SHA-256 matches: 4 authority inputs, 8 historical inputs, 39 source/test/operator files, 9 production/operator artifacts, 16 test artifacts, 1,020 evidence files |
| New six-entry seal | All six matched, including report, bindings, cleanup, execution index, parity and commands |
| Candidate source snapshots | All 39 matched their source hashes |
| Compiled metadata inputs | All 636 source keccak256 values matched actual bytes |
| Captured parent/package runtime | Five artifact/runtime comparisons matched after masking only compiler-declared link/immutable spans |
| Independent local runtime | Those same five captured runtime byte strings exactly matched the producer's captured bytes |
| Closing source identity | All 39 candidate source/test/operator hashes remained unchanged; HEAD and producer seal remained unchanged |

Main plan r4 SHA-256:
`c9eff8e498d1483b0166346099a15ab0930740a9febcfd727774cf2b4506ef2a`.
Current PRD r21 SHA-256:
`d4b12a742c74c08e862bf02a9315cfd706e3d117e4878bd99092b071c3c48ba3`.
Producer report SHA-256:
`deb62a122bb8949b03107ef04208f35f5c36dd1849e9ce79245d56091d369250`.
Producer bindings SHA-256:
`dd81dd32c42d05153f9e186c6671f7b080ea179e4ee33f01ccff746bbdb0e057`.

The old incomplete report/seal and old needs-fix report were preserved.
Their historical failure is not relabeled as a former pass.

**Generated-artifact qualification:** independent rebuilds changed 13 of
the 25 bound artifact JSON hashes. All admitted raw hashes matched before
execution; no claim is made that every regenerated JSON is byte-identical
afterward. Final reconciliation uses unchanged candidate source, matching
636 compiled inputs, all 16 test artifacts' matching source/metadata hashes,
and the five matched actual deployed runtimes. Exact old/new JSON hashes
are retained in `artifact-reconciliation.json`. Producer reports, seals,
source snapshots and receipt evidence were not rewritten.

## 3. Independently executed checks

| Check | Independent result | Owned evidence |
| --- | --- | --- |
| Artifact-first Solar production build and complete current Migration specs | Build succeeded; 102 pass, 1 fail, 0 skipped; exit 1 for D1 | `specs.log` |
| Artifact-first pinned actual legacy Migration forks | 52 pass, 0 fail, 0 skipped; exit 0 | `forks.log` |
| Final-source operator tests | 56 pass, 0 fail across three files in one run | `operator-tests-types.log` |
| Final-source strict TypeScript | Exit 0, chained after operator tests | Same log and monitor completion |
| Actual fixed18563 CLI rehearsal | Exit 0; `bounded-rehearsal-complete` | `rehearsal.log` and owned run below |
| Source/seal/runtime reconciliation | Results in section 2 | `binding-validation.json`, `artifact-reconciliation.json`, `runtime-index.json` |
| Read-only whitespace check | Exit 0 | Session command evidence |

`checks.json` retains exact spec/fork/operator commands and exits. The
artifact helper used the three changed Migration production inputs with
the current spec or fork directory as `--test-root`; the spec build also
included both existing operator stages as consumers. Every compiling Forge
invocation used Solar. The actual rehearsal executed the existing Foundry
environment and execution stages against the owned local chain.

The independent CLI invocation was:

```sh
bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --rpc-alias robinhood_mainnet_alchemy \
  --fork-block 108944663 \
  --port 18563 \
  --checkpoint .omo-runtime/dtf-migration-weighted-liquid/checkpoints \
  --evidence docs/incidents/2026-09-16-dtf-recovery/migration/weighted-liquid/stage2-verification
```

Only the evidence parent differs from the producer invocation, to preserve
sealed producer evidence. The unchanged CLI appends `stage2-correction/`
inside this verifier-owned directory.

Observed tools: Bun 1.4.2; Forge 1.9.1-nightly
`430523103f3e2f9ba432ffdd2031a9f966153d0d`; metadata compiler
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`.

The first independent shell wrapper failed before starting compilation
because PATH was incorrectly quoted. Corrected literal shell quoting ran
the suite. An invalid monitor regex likewise rejected before starting the
fork command; its corrected subscription ran once. Both failures are
retained in `checks.json`, not counted as test executions. Existing
compiler warnings remain. JSON LSP was unavailable because Biome is not
installed; generated evidence uses JSON serialization. No dependency was
installed.

No full ordinary/common regression suite was repeated: the admitted delta
does not edit ordinary/common production. Historical ordinary/common
evidence remains historical. This scope does not hide or excuse D1.

## 4. Concrete lifecycle and custody coverage

Here `M` means
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.

| Required behavior | Final-source observation and independent runtime coverage |
| --- | --- |
| Actual W-L setter, not selector-only publication | `M/UniswapV4DetfMigrationAllocationTarget.sol:159-197` implements current-owner Stage1 loading, fixed source/chain, complete original tuple, frozen C0 and complete Q/C initialization. Five W-L configuration specs pass, including replay, corrected replacement, no issuance, owner transitions, invalid input and atomic bad-second-row rollback. Actual CLI configuration and corrected configuration receipts succeed. Old V1 is closed. |
| Stage1 no-effects rejection, both NFT generations and W-L | `M/UniswapV4DetfMigrationTarget.sol:79-83,140-144` rejects before child queries or asset custody. Pinned forks pass exact owner/balance/allowance/configuration/consumption/supply/backing/bond checks. CLI mines seven NFT and two W-L Stage1 failures with exact `MigrationSurrenderClosed` data and unchanged measured state. |
| Current-owner atomic activation | Allocation target lines 200-213 resolves seven actual owning facets, removes their selectors and allocation-interface authority, then publishes activation. Core rollback assertions execute on a real gas-exhausted cut; owner-transfer and declaration/restoration suites pass. CLI records all seven removal logs and receipt-block routing validation. |
| Callback closure and shared gate | No external callback occurs between the internal cut and activation publication. The parent lock and fixed-child idle checks protect entry. `MigrationAdministrationTest.test_callbackOwnerCannotActivateOrReenterAnotherChild` passes; W-L receiver and NFT callback/rollback forks pass. Reward-release and ordinary-acquisition specs pass with existing funded participation. The unconditional empty-participation deposit remains D1. |
| Original-wallet and actual control | Both NFT generations reject missing record, wrong holder, approved operator and original wallet lacking custody after activation. Real transfer-back permits the recorded original wallet to surrender. W-L wrong-wallet probes possess and approve a positive-credit quantity, so dust cannot mask the guard. |
| Frozen partial/final credit | W-L target lines 59-75 uses full-precision remaining-credit division and gives the final remainder all residue. Fork execution covers three partial deliveries, delayed fresh clocks, exact total C0, exhausted record and zero-credit rejection. Actual CLI uses the corrected Stage1 Q/C baseline and two successful surrenders. |
| Exact custody, funded bond and rollback | Target lines 92-118 measures exact wallet debit and proxy receipt, books only q and funds a fresh bond. `M/UniswapV4DetfMigrationRepo.sol:66-76` mints exact delivered principal through the fixed child's funding route and clears approval. Actual-source fork receiver/funding failures restore custody, allowance, inventory, supply, gons and consumption. |
| No post-partial amendment | Actual identical and altered W-L setter calls after partial and final surrender are mined `NoTargetFor(0x256c417b)` failures. Q/C and configured identity remain unchanged. NFT consumed-origin loader/replay negatives also pass; no correction arithmetic is reachable. |
| Independent compensation retained | Stage1 configuration does not mint; explicit issuance creates exact funded 90-day bonds. Replacement preserves actual issued facts, clocks and supply. Current-owner, canonical-origin overlap in both directions and issued-origin protection pass. One unclaimed configured recipient remains unissued. |
| Selected booked recovery | Actual WD conversion uses the fixed legacy route, exact deltas and cleared self-allowance. Partial/final donation leaves unbooked WD, DTF sentinel, donation budgets and compensation protected. Forks additionally cover selected-batch failure, staged rollback, registry boundaries, both NFT recoveries and later accrued weighted receipt gons. |

Actual selector census removed:
`0xec55c474`, `0x161d9afc`, `0xccff9894`, `0x787642e8`,
`0xe9dc9e6d`, `0x12076202`, `0x256c417b`.
These cover bootstrap, snapshot capture, independent configuration,
independent issuance, activation, NFT configuration and W-L configuration.
Retained queries, surrender and recovery remain callable. The tested
package/initializer/update routes cannot restore administration.

## 5. Independent actual local receipt witness

Owned run:
`stage2-correction/rehearsal-1794428263929/`.

Proxy: `0xedf7d9f65b9e57d62a3c4278223170db1308f5f0`.
New funded snapshot:
`0xe9e1a480070cff37ffb3743aec30de6008affbd3e49ca7d286655114495868ce`.

Historical source domain: chain 4663, block 108944663, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
That historical pin is distinct from this run's funded snapshot and
simulated future timestamps.

The independently inspected evidence contains 39 operator receipts and
120 fixture receipts, including 43 failed-call receipts and seven
successful surrenders. Receipt status, transaction identity and block
ordering were reconciled, not inferred from observation labels alone.
All configuration and independent issuance precede activation. Last
configuration is block 108944917; activation is block 108944935.
Every positive surrender follows activation.

### Weighted liquid

Synthetic original record: wallet
`0x082cb14f04d9c485473dedc00d604d7e9abca303`, fixed WD source
`0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7`.
Stage1 correction sets Q0 = 21,225,530 native WD units, original ETH =
6,000,000,000,000,000 wei, original DTF = 0, C0 = 2,774,608 native
nine-decimal new-DETF units. These are synthetic allocation inputs.

| Operation | Actual WD | Delivered credit | Bond | Start | Remaining Q / C |
| --- | ---: | ---: | ---: | ---: | --- |
| Partial | 7,075,176 | 924,869 | 6 | 1794111232 | 14,150,354 / 1,849,739 |
| Final | 14,150,354 | 1,849,739 | 12 | 1825676127 | 0 / 0 |

Both durations are 7,776,000 seconds. Each position has exact principal,
zero initially claimed principal, actual creation-block time and measured
funded gons. Aggregate delivered credit is exactly 2,774,608.

Partial transaction:
`0xd03a3739b69471f98c94ab1fb8b42686564c2c98d41c3bd1b048859bdd94c162`.
Final transaction:
`0x19dea92e20715ffce7ade6039fdfa3ff93bac7cd535e0688168d27e6b7c49276`.

After the partial, identical and altered setter transactions
`0x0fad89dda53168f9e2e2af2ee37c0330b7c10d589f53e2617f40d7c3a7da43c3`
and
`0x0ee1853ba0a1dd3ace44d9b293aaec67e4ac2c28d446a204dc9e1a8354ba0943`
both fail with the absent W-L selector and preserve the stated remainder.
The same negative holds after final exhaustion.

Partial conversion receives 37,926,535,439,701,004,167 DTF units and donates
18,963,267,719,850,502,083. Final conversion receives
75,849,094,805,853,797,792 and donates 37,924,547,402,926,898,896.
Seven unbooked WD units, the independently transferred
1,000,000,000,000,000,000-unit DTF floor and other protected inventory
remain protected. Self-allowance is zero and personal compensation is
unchanged. These are actual conversion outputs, not compensation inputs.

### Both NFT generations

| Source / old ID | New bond | Native credit | Actual creation timestamp |
| --- | ---: | ---: | ---: |
| Weighted / 4 | 7 | 13,872,781 | 1794111251 |
| Weighted / 26 | 8 | 22,233,172,691 | 1794111266 |
| Earlier / 3 | 9 | 923,391,925 | 1794111278 |
| Weighted / 6, late | 10 | 36,992,599 | 1825676106 |
| Earlier / 9, late | 11 | 46,243 | 1825676118 |

All five actual transactions take the configured NFT from its recorded
original wallet and create a distinct exactly funded 90-day bond. Weighted
ID26 returns through an actual source transfer to its configured wallet,
not a replacement of the configuration with its current holder.
`runtime-index.json` retains every exact transaction hash and raw receipt
location. The late timestamps are local simulated chain times, not public
issuance dates.

### Both mined interruption/resume proofs

| Interrupted operation | Actually mined transaction | Nonce | Independent result |
| --- | --- | ---: | --- |
| Donation | `0xdb46df60da2b4bf178d4ba387f8ccd5217756808cf58e94f5d08d135059b23f3` | 2118 | Completion checkpoint absent after mining; fresh resume recovers identical canonical receipt without donation replay |
| Independent issuance | `0xf221e0e31a4b80f6e4cd9a2377c006c626bfa84a073171cf1bf33b6a9576c340` | 2131 | Completion checkpoint absent after mining; fresh resume recovers the same funded bond 3 and exact receipt |

The two genuinely outstanding issuance rows reverse order and create
bonds 4 and 5 at nonces 2132 and 2133. All three principals are 461.
Supply moves from 1,000,000,000,000 to 1,000,000,001,383. The fourth
configured recipient remains `issued=false`, bond ID zero. Stage1
replacement of an issued independent record does not change issuance
or supply. The actual default read-only resumes do not submit transactions.
Domain/payload negatives and missing-wallet preparation checks remain
executed. Original and resumed receipts were independently compared.

## 6. Limits and cleanup

Real operational original-wallet, canonical-origin, Q0 and ETH/DTF
allocation records remain prerequisites. A synthetic fixture does not
approve a real compensation amount; holdings do not establish original
allocation quantities. Known-origin collision checks do not prove opaque
aliases globally disjoint.

No additional source category is accepted. Weighted receipts/SY, earlier
liquid/receipt, TokenStaking/claim-vault, standalone SE and fungible LP
categories retain their source, unit, mapping, caller, disabled-route or
integration limitations. Earlier sale-and-hold is not proven liquidation.
The supported NFT recovery paths do not imply support for every standalone
legacy asset.

The independently observed local parent deployment uses 43,217,538 gas
on the permissive 100-million-gas node. This does not prove feasibility
against the retained historical 32,000,000 transaction limit. The prior
42,985,865-gas baseline remains historical. The existing bounded recovery
gas fork ran as part of the current fork directory; it is not held
phase09 gas work or a public deployment feasibility claim. No held
phase09 candidate was inspected, imported, changed or executed.

Owned Anvil PID 31934 exited through the scenario's cleanup. External
`lsof` found no port18563 listener (exit 1); `ps` found no owned PID
(exit 1); the fixed checkpoint is absent (test exit 0). Scenario
impersonations were stopped in `finally` paths, providers/subscriptions
closed, and the producer RPC monitor was explicitly stopped. All owned
build/test/type/rehearsal commands have completed. No owned runtime or
monitor remains pending.

Only verifier-owned evidence under this directory was authored. No
production/test fix, ordinary/common/Crane edit, dependency/configuration
or routing change, public operation, commit or merge occurred. Warm
artifacts remain local; none were copied to main.

**Final disposition: needs-fix overall because D1 remains unresolved.
The bounded approved Stage2-only NFT/W-L surrender and operator integration
is independently confirmed, with the source/allocation/gas limits above.
This report authorizes neither a reward-weight policy nor public execution.**
