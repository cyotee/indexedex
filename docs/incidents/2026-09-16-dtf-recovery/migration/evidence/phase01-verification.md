# Phase 01 independent verification

Date: 2026-11-10. Scope: implementation-plan sections 1-6 and task 1, including
the caller's clarification that E1 concerns source prerequisites, not completion
of the future Migration implementation. No producer claim was accepted merely
because its report or PASS token existed.

## AdversarialVerify

```json
{
  "verdict": "needs-fix",
  "failure_class": "product",
  "confidence": "high",
  "task1_source_and_attribution_closure": false,
  "E1": "Usable source primitives demonstrated; specific caller and harvest routes remain unproved or restricted",
  "E2": "Balance-only attribution fails; a compliant authenticated-history construction is not established",
  "later_Migration_integration_is_task1_blocker": false
}
```

The central blocker is **missing compliant postactivation attribution**, not
universal cryptographic impossibility. The bundle is substantially a faithful
record of blockers, but that is not a verified implementation path. Its
blanket E1 explanation based on absent custody-plus-new-bond integration is too
broad for task 1 and is not adopted here.

All artifact references below are relative to this report. Exact absolute
commands, cwd, runtime paths, binary observables and exit codes are in
`verification/*.command.json` and `*.exit.json`. Failed stdout/stderr remains
verbatim apart from credential redaction.

## 1. Executed evidence and reproduction

The worktree was
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01`.
Public RPC used `robinhood_mainnet_alchemy` read-only. Every transaction ran on
an owned loopback Anvil fork. Runtime was Bun 1.4.2; the source runners recorded
Anvil 1.9.0-Homebrew. No Forge build, Foundry test suite, product deployment,
public transaction, commit, dependency install or product edit was performed.
No compilation was needed to exercise existing source bytecode.

All successful fork runs used chain **4663**, block **108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
This is the historical evidence pin, not a funded mint snapshot.

| Invocation receipt / artifact | Actual outcome |
| --- | --- |
| `verification/weighted-original.*` | Original runner exits 1 when `--output` targets verification: `Output outside weighted evidence boundary`. |
| `verification/earlier-cp-original.*` | Original runner exits 1: `Output must be in the owned evidence directory`. |
| `verification/other-sources-original.*` | Original runner exits 2 with output-boundary error. Its finally block nevertheless persists the UNPROVEN result to that rejected path. |
| `verification/witness-original.*` | Original witness has no output-option parser; hardcoded output and TMPDIR assertion prevent a safe unchanged replay into verification. Exit 1 before producer writes. |
| `verification/weighted-replay.*` | Path-only copy exits 0; 34 PASS, 1 FAIL, 2 UNPROVEN. Actual 28 local transactions: 22 successful, 6 reverted. |
| `verification/cp-replay.*` | Path-only copy exits 2; 18 PASS, 2 FAIL, 4 UNPROVEN. Actual 24 transactions: 10 successful, 14 reverted. No historical fallback. |
| `verification/other-replay.*`, `witness-replay.*` | HTTP 429 acquisition failures, retained as harness failures. |
| `verification/other-metered.*` | Transport-metered replay completes historical acquisition of 43 identities and actual custody/rollback: 21 PASS, 4 FAIL, 3 UNPROVEN; exit 2. The historical custody acquisition gap is now resolved. |
| `verification/witness-r4.results.json`, `witness-metered.*` | Exit 0, `ATTRIBUTION_COUNTEREXAMPLE_PASS`; six mined transfers, distinct histories, identical queried token state, unequal required credits and restored source state. |
| `verification/native-replay.*` | Two native-LP harvest cases FAIL with actual mined `NotOwner` errors; exit 2. |
| `verification/tokenstaking-caller.*` | Exit 0; two focused actual-source caller/callback assertions PASS; source state restored. |
| `verification/reconciliation*.json` | Two original reconciler invocations exit 0 and reproduce the producer output byte-for-byte. |
| `verification/independent-reconciliation.json` | Independent Python integer oracle: 19,082 comparisons, zero failures; no producer functions imported. |
| `verification/receipt-audit-r2.json` | 370 raw receipt, identity, integer, fingerprint and copy-fidelity checks; zero failures. Earlier successful audit retained separately. |

Original source-runner invocation shape was:

```text
bun <absolute scripts/recovery/dtf-migration/phase01/LANE/probe.mjs>
  --chain-id 4663 --block 108944663
  --rpc-alias robinhood_mainnet_alchemy --local-fork
  --output <absolute verification prefix>
```

The failures above required **evidence-only copies**, not producer edits.
`verification/path-only-copy-audit.json` records exact replacements;
`receipt-audit-r2.json.copies` records actual executed hashes, including one
extra terminal newline from initial patch construction. Assertions, source
addresses and transaction logic were unchanged. Throttled retries separately
record a public-POST transport meter and Anvil compute-unit limit of 10 in
`transport-retry-audit.json`. They do not alter responses or manufacture PASS.

Native mode's producer label says `native-LP-replay-of-fresh-pin`; its actual
block/hash in this replay are historical, as independently checked. The label
is not evidence of a different pin.

## 2. Exact blockers and source-prerequisite findings

### B1. E2 authentication is not implemented or established

`verification/witness-r4.results.json` reproduces ordinary transfers on the
actual weighted DETF, with its transfer selector bound to facet
`0x1d17aca0e0717d90cea916372070a1be4652223f`, runtime hash
`0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50`.
The source archive's generic facet is `match`, not an invented exact metadata
match. Current repository implementations were not substituted.

Start with Alice/Bob holding 100 units each, carrying synthetic admissible
already-quoted credits 1000/3000:

| History | Actual ordinary transfers | Final balances | Required credits |
| --- | --- | --- | --- |
| H1 | Alice to Bob 50; Bob to Alice 50 | 100 / 100 | 1666 / 2334 |
| H2 | Bob to Alice 25; Alice to Bob 25 | 100 / 100 | 1400 / 2600 |

Donor balance, total supply and reciprocal allowances also agree. The logs and
whole-chain histories do **not** agree; no claim of identical global state is
made. Both branches and the initial source state were restored.

An adapter whose inputs are the same frozen checkpoint, unchanged internal
ledger and these current token observations cannot produce both required
answers. Ordinary transfers do not call that adapter. Irreversible activation
does not supply the missing history. This reasoning applies after activation,
but **no actual Migration activation was executed**.

Full authenticated history can distinguish the branches. What is absent is a
concrete admissible verifier/proof producer establishing canonical anchoring,
complete ordered transitions, current custody freshness, bounded operation,
domain separation and nonduplication without postactivation trusted updates.
Selected log inclusion, a current balance, a static allowance or a proof-shaped
argument alone does not establish that construction. This is a required
mechanism gap, not a new owner-policy choice and not proof that all
cryptographic constructions are impossible.

**Blocked:** finalizing affected fungible attribution ABI/storage and claiming
the associated surrender paths satisfy E2.

### B2. TokenStaking has a concrete ordinary-caller handoff limitation

The focused probe authenticates the pinned `reassign` facet
`0x9c90d4a476f3473b9a0e32b530af3474271a80b1`, hash
`0x5628dcb4bb0a1a24e6bde3b985f92c2ef0894ddd6006a55ddaffccc877a52742`.
See `verification/tokenstaking-caller.json`, including full loupe routing,
mined receipts and call traces:

* A real EOA with `64890781291192882058375` weight calls an ordinary forwarding
  contract, which calls `reassign(custody,quantity)`. The source reverts
  `InsufficientStake(helper,quantity,0)`, selector `0x936d426d`. The actual
  helper address is encoded in the error; the EOA's balance is untouched.
* Direct EOA reassignment of that weight to a contract whose runtime always
  reverts succeeds. The source trace contains no call to the recipient;
  EOA weight becomes zero and recipient weight becomes the exact quantity.
* ERC-20 approve/transfer/transferFrom, tested permit, and multicall selectors
  are unbound. `reassign` and `withdrawClaim` are bound.

Thus a normal future Migration contract cannot simply pull another claimant's
weight through this interface, and direct reassignment cannot invoke its
issuance through a recipient callback. Sending first and issuing in a second
transaction cannot roll back the earlier transfer if issuance fails. That is
a **source prerequisite limitation**, not a complaint that task-6 code is absent.

The source nevertheless supports real holder-authorized reassignment and
staged `withdrawClaim`: the historical replay extinguishes the weight and
receives **117153341 SY**. An outer-revert helper also proves successful inner
claim rollback. Specialized account-level execution or a separately
authenticated representation-transition route has not been proved here;
neither is declared impossible or silently selected.

The optional Sourcify request for this facet returns HTTP 404
(`tokenstaking-source.raw.json`). Current `TokenStakingTarget.sol:184-209`
and `:289-306` explain the observed caller rule but are not asserted to be
byte-identical deployed source. The focused conclusion rests on actual pinned
runtime, routing, transactions and traces.

### B3. New-custodian LP harvest remains unproved beyond failing routes

Both fungible LPs transfer into custody. That does not confer the legacy
contract-owner authority needed by the tested exits:

* Earlier LP `0x923877336b14662cfb5b3a60b14e7d716d54a888`:
  exact-in exits revert `UnsupportedRoute` (`0x5d5fe824`);
  native `withdrawSeShares` reverts `NotOwner(custodian)` (`0x245aecd3`).
  Its owner is the earlier DETF, not the impersonated NFT-escrow balance holder.
* Weighted LP `0x46e068c2393e189fbc86632f67210af253a42aa8`:
  exact-in and both native proportional exits revert `NotOwner(custodian)`;
  `ownerOnlyLiquidity()` is true and owner is the weighted DETF.

`verification/native-replay.json` preserves failed receipts, zero output
deltas and unchanged custodied LP quantities. These are real caller/route
restrictions. An alternative legacy-owner-mediated route is **UNPROVEN**,
not universally impossible. Do not promise ordinary new-custodian liquidation
through these tested entrypoints.

## 3. E1 capabilities are not circular integration blockers

The source matrix includes all accepted categories and both generations.
Ordinary NFT/ERC-20 custody primitives demonstrated on real bytecode may be
used for later implementation. An EOA custodian fixture does not invalidate
`transferFrom`; the future receiver, consumption ledger and new-bond integration
belong to tasks 3-6.

| Category | Verified source capability | Preserved limit |
| --- | --- | --- |
| Weighted fixed-principal NFT | Current owner/remaining principal, approved whole-NFT custody, claims, burned/nonexistent and reward-only states, failed-transfer rollback | Bind current owner and recovery recipient in the future adapter. Legacy approved operators can redirect payouts; this is not an unusable transfer primitive. |
| Earlier CP LP-lock NFT | Locked/mature custody, unchanged original shares, reward claim, sale into receipt, burned identity and failed-operation rollback | LP shares are not fixed DETF principal. Mature harvest presently reaches a disabled underlying SE. |
| Both liquid DETFs | Real custody in native 9/18-decimal units | Contribution ancestry is not a balance read. |
| Weighted sDETF / earlier receipt | Custody; weighted unstake; earlier internal/external-share rounding | Gons and receipt conversion units differ; earlier redemption presently reaches the disabled SE. |
| Weighted SY | Custody, share consumption and staged SY-to-sDETF-to-DETF-to-DTF | Direct SY-to-DTF and the full disabled-state matrix were not tested. Backing is not a second entitlement. |
| TokenStaking / claim-vault rights | Holder reassignment and claim; 19-decimal vault-share custody/redemption to SY; actual outer rollback | Claimant-only limitation above. Vault-share fixtures impersonate infrastructure, not proven user authority. |
| Underlying SE shares | Three concrete sources; exact custody and outer rollback; DTF-custody SE redemption works | Earlier and weighted WETH-leg SE exits are disabled. Decimals are 18, 18 and 28, not interchangeable. |
| Fungible LPs | Two concrete sources, distinct from NFT LP lock; exact custody and outer rollback | Owner-restricted harvest; eligible user exposure and alternate route unproved. |

**Current disabled policy is separate:** `VaultDisabled(address)`, selector
`0x1ba84b43`, identifies earlier SE
`0xb7d4bb379d361ad442cddee53ea71a33957826a7` and weighted WETH-leg SE
`0x999dae02d22e5fee1c4508430d5196d31d631009`. These are current exit failures,
not RPC errors or proof that custody/immutable attribution is impossible.
Staged harvesting is allowed. Wrong-owner earlier mature-close authorization
remains masked by the disable check; it is not an ownership PASS.

**Optional source archives are separate:** the earlier facet
`0x67ed019ec3f8b77bc51ed1e6403fc90e0abb15be` remains unavailable from
Sourcify. This limits a complete source audit, but does not erase authenticated
routing and executed primitive behavior or automatically block every NFT route.

**Future inputs are separate:** funded C0 and approved allocation amounts are
expected operational inputs, not newly discovered product blockers. This phase
computes no awards. It preserves once-quoted original ETH/DTF credit, the
remaining-principal fraction, zero/burned/nonexistent ineligibility, no config
premint, fresh 90-day bonds and irreversible activation configuration.

## 4. Integer, ancestry and harness results

Independent raw recomputation matches the producer, including:

| Quantity | Exact result |
| --- | ---: |
| Weighted nominal exposure | `2237832428068` |
| Held lower bound | `1674947599807` |
| Unresolved historical remainder | `562884828261` |
| Preincident NFT gons | `208200941171774511655236409911455698947144975844` |
| Observed recovery DTF | `59027441289824656686224552` |

All 43 weighted contribution joins, 16 earlier direct/routed-input joins,
382 weighted look-through positions and historical partition checks agree.
The two reconciler reruns and original share SHA-256
`874eb99734cb6f06a6c75982fbe9dcfc52f84e535c3666fb8d2f2f23b11f684f`.
These diagnostics are not approved allocations or a new complete ancestry replay.

Weighted actual claim receipt output **4308806205 sDETF**, staged recovery
**24312424763253115621623 DTF**, and SY **8094 -> 9245 sDETF** reproduce.
Earlier receipt transfer of `10^18` displays `999999999999999999`, preserving
rounding rather than assuming equality. All 84 synthesis-index fingerprints
match; the two preexisting frozen Markdown manifest mismatches remain.

The witness's 5,902 bounded partitions and independent arithmetic exercise
residue conservation; the 7-unit/10-credit example pays 1, 1, 8. NFT
600 plus automatically inferred descendant 400 plus overlapping independent
1000 would double-pay a 1000-credit origin. Wrapper 901 and backing 901 are
one claim, not 1802. **No deployed duplication-rejection mechanism is thereby
proved.** Complete fungible/claim/wrapper lineage remains unproved. Zero
standalone SE/LP ledger rows are not proof of absent exposure. Native ETH
coverage and the earlier receipt supply discrepancy remain unresolved.

Malformed float, leading-zero and exponent quantities fail with exit 2;
duplicate headers/unterminated CSV fail with exit 1. Blank stays UNKNOWN.
Signed integers are accepted; unlisted CSVs are hashed but not numerically
parsed. A failed rerun preserves an older success JSON at the same path.
Consumers must verify invocation, input fingerprint and exit, not file existence.
`WROTE`, `WEIGHTED_PROBE_PASS` and `ATTRIBUTION_COUNTEREXAMPLE_PASS` are not
task-1 closure tokens. Details and clean-fingerprint controls are retained in
`verification/runner-findings.md`.

## 5. Durable references and preservation

All **334** checked local Markdown links resolve. All 84 source-manifest index
entries have relative alternatives. Absolute cwd, process and cache paths in
archived receipts are historical provenance; payloads remain in the repository,
not deleted temporary caches.

There are real replay portability limitations:
`evidence/attribution/witness.mjs:8-16` hardcodes the worktree/output;
`verify-cleanup.mjs:6-10` hardcodes the worktree and original temporary root and
later reads absolute input paths. Earlier-CP creates its runtime directory under
a fixed host temporary parent. These need rebasing/configuration before replay
after worktree removal. The verification utilities are also deliberately rooted
to this requested worktree; they are not claimed portable production runners.
See `verification/portability-audit.json`. No producer reference was edited.

`workspace-before.json` and `workspace-after.json` cover **13,017** files:
zero changed or added files outside verification. Original incident inputs,
producer files, plan and product code are preserved. The linked Crane target
is recorded without traversal; whole linked dependency trees were not hashed.

A separately authorized recovery verifier preserved additional observations,
reran selected existing checks and performed runtime deletion. Its artifacts
remain untouched. The original verifier's subsequent cleanup launch failed
because that root was already absent; the exact ENOENT is preserved.
Independent final read-back then confirmed **45 PIDs absent, six TCP
ECONNREFUSED results and 42 directories absent**, including its own fresh
read-back root. See `cleanup.json`, `recovery-cleanup.json` and
`cleanup-independent-readback.json`.

Fresh LSP diagnostics timed out or lacked installed servers; no clean static
check is claimed. Five Node syntax checks passed. The early wrapper did not
explicitly override inherited `NODE_COMPILE_CACHE`; shared runtime-cache writes
by those checks were not measured and that shared cache was not deleted.
Owned roots/caches were verified absent. Final read-back explicitly isolated
both Node compile and Bun transpiler cache paths.

## 6. What the next implementation phase may rely on

**May proceed independently, subject to each task's own gates:**

* Task 2 frozen-quote evaluator and dependency work on verified source routes.
* Task 3 package ownership, bootstrap and lifecycle composition that does not
  freeze an unsupported fungible attribution ABI.
* Task 5 funded cliff-bond/reward-gate implementation and tests.
* NFT-specific preparation using original contribution identities and verified
  remaining-unit models; portable evidence/loader plumbing and source discovery.

**May rely on:** pinned identities, selected deployed ABIs, native-unit fixtures,
the demonstrated custody/conversion/rollback primitives, and the exact observed
caller and current exit restrictions.

**May not rely on:** balances or static wallet allowances as authenticated
lineage; a nonexistent E2 verifier; ordinary-contract pulling of another
TokenStaking claimant's weight; owner-restricted LP exits from a new custodian;
infrastructure impersonation as user authority; historical lower bounds as
credit; missing-category rows as absence; unknown ETH as zero; or PASS/file
existence as permission to issue.

Do not finalize affected task-4 fungible attribution storage/ABI or declare all
task-6 surrender/task-8 recovery routes ready until their specific mechanisms
are established. Do not pay NFT descendants, wrappers/backing or independent
allocations twice. No new policy, source omission, trusted postactivation update
or implementation authorization is supplied by this verification.

## DoneClaim

- **changed_files:** this report and authored/generated artifacts under
  `migration/evidence/verification/` only. Recovery-authored artifacts were
  preserved. `verification/artifact-index.json` inventories the final bundle.
- **exact_tests/probes:** literal invocations and binary observables in
  `verification/*.command.json`; outcomes in corresponding exit/raw logs;
  final source/receipt audit 370/370, integer oracle 19,082/19,082, pinned
  weighted/earlier/other/native/claimant/witness outcomes in section 1.
- **evidence_paths:** `weighted-replay.results.json`, `cp-replay.json`,
  `other-metered.json`, `native-replay.json`, `tokenstaking-caller.json`,
  `witness-r4.results.json`, `independent-reconciliation.json`,
  `receipt-audit-r2.json`, `portability-audit.json`, all under `verification/`.
- **cleanup_receipts:** final independent read-back PASS; no owned node, endpoint
  or runtime directory remains. Outside-boundary file comparison is clean.
- **risks:** E2 construction missing; direct claimant handoff and restricted
  harvest routes unresolved; exposure/ancestry gaps; optional source archives;
  portability and early runtime-cache limitations. None is hidden by successful
  primitive tests, and missing future integration/C0 is not used as a circular
  task-1 blocker.
