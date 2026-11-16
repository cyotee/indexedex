# Direct claim-vault support: executable E1 delivery

Date: 2026-11-12.

**Disposition: complete for the bounded direct-share increment.** The pinned
route works. The corrected E1 gate was met by actual controlled-wallet payment,
share mint, custody, own-share redemption and rollback, not by downloading
compiler metadata. Current complete Migration suites pass **130 specs and
81 pinned forks**. All **64 operator tests**, strict TypeScript, artifact
preparation, both operator-stage builds and the actual fixed-port18566 CLI
pass. All three mined-before-checkpoint resumes retain the same canonical
receipt without replay.

This report is in the phase16 worktree, branch
`work/dtf-migration-phase-16-claim-vault`, exact parent
`4a53299b490343ed904d70c92ecbc7360fcb7659`. The tracked starting tree was
clean; `out/`, `cache_forge/` and the verified Crane/node_modules links were
warm. No commit or merge was made.

## Authority and predecessor preservation

The complete corrected main-checkout
`.omo/ulw-execute/dtf-migration/phase16-claim-vault-brief.md`, actual current
main plan, its E1/E2 gates, current PRD and paid owner-first-bond correction
were read. The phase11 claims/source matrix and phase15 final verification
and commit handoffs were read. Existing historical acquisition-family and
staking-adapter evidence was examined without substituting current code for
the deployed source.

The sibling sealed `implementation/report.md` and `verification/report.md`
remain unchanged. They correctly record no support at their earlier handoff
under the then-added archive gate. Their nine retained files are fingerprinted
in `final-sealed-preservation.json`. This increment neither rewrites their
conclusion nor treats missing metadata as a disabled or impossible route.

`final-input-bindings.json` hashes the actual corrected brief and controlling
documents. In particular, the main plan hash is
`60d02b608c8a10f19cffce7b99838146c205a98410641e9bce45944e620dc56d`
and the PRD hash is
`cfe1853f49de0dc41ae106f1cc1b94eacd24d4aa8f79477c66a5b7f24a4d67ed`.

## Executed identity, units and call layouts

| Identity | Pinned result |
| --- | --- |
| Chain/block | 4663 / 108944663 |
| Block hash | `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733` |
| Direct share vault | `0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0` |
| Proxy runtime keccak256 | `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601` |
| Deposit/redeem routed facet | `0x517234f78a4bcafc5f880024a3e45d49cf43b305` |
| Facet runtime keccak256 | `0x8c1ea71d607b09b21c4e78f850647a059dc7935b6772f7cd3aeaa700a995439f` |
| Underlying static WY/SY | `0xb55604cf4dcdabb362078e106d20f98512391edf`, native9 |
| Direct vault shares | native19; not raw TokenStaking weights |
| Deposit | `0x6e553f65`, `deposit(uint256,address)`, single uint256 share return |
| Redeem | `0xba087652`, `redeem(uint256,address,address)`, single uint256 asset return |

The first isolated successful probe is `route-results.json`; the expanded,
completed encoding/recipient/failure proof is
`route-expanded-final/route-results.json`. Its identity record retains full
proxy/facet code and the routed ERC20 transfer/allowance facet identities.
Individual `route-tx-*.json` files retain signed payloads, before/after asset,
share, supply and allowance values, receipts, logs and call traces.

The controlled wallet is `0xd96eb0f2e106ea7c0a939e9c460a17ace65fecff`,
development derivation105. It started with zero SY and shares. The genuine
existing EOA `0x11c17f25e958e4637dd26ca362adeae12e24ed5b` funded real SY;
only its local EOA transaction was impersonated, with ETH gas funding.
Neither token storage nor source roles, code, balances or permissions were
fabricated. Infrastructure shares were not transferred to manufacture a user.

An actual signed approval and deposit paid **3000 native9 SY** and minted
**29999999967592 native19 shares**. The controlled wallet SY debit equals
the source SY increase; share balance and supply increases equal the
single-word return and mint/deposit logs. These are native integer amounts,
not 3000 whole SY tokens. Own-share redemption burned exactly that quantity
and paid **2999 native9 SY**, equal to its return, wallet increase and source
decrease, with the matching burn/withdraw logs and no self-approval.

The expanded proof also observes:

- Deposit without underlying approval reverts, leaving custody, supply,
  allowance and logs unchanged.
- A separately specified deposit recipient receives the actual minted shares,
  while the payer's share balance is unchanged.
- Third-party redemption without share allowance, over-balance redemption and
  a zero recipient revert without economic effects.
- The recipient/custodian can redeem its own actual shares to itself.
- **Zero-share redemption succeeds with a zero return at this pin.**
  Migration therefore enforces positive selection/output itself; the source
  is not misdescribed as enforcing that condition.

No exact archived-source equivalence is established for this claim-vault
facet. Familiar interface names and selectors were candidates, not proof.
The executed return layout, routed trace and payment/mint/burn/output/log
observations supply that proof. No IPFS/Kubo, metadata fetch, installation or
provider change occurred.

## Scoped implementation and composition

`final-source-bindings.json` binds all **40 changed/new code, test, operator
and runbook files** and the exact base/branch. Their byte-exact copies are
under `final-source-snapshot/`. No ordinary/common/Crane production,
dependency, configuration, held09, commit, merge or public action is included.

The new original-wallet entitlement has the same complete-input shape as the
existing bounded source entitlements: canonical original ID, original wallet,
fixed source, explicit native19 Q0, both known ETH/DTF components and evidence
ID. Stage1 sets/replaces the complete configuration without issuance. The
configuration identity binds chain, instance, frozen snapshot and full input.
Current holdings and current source rate never infer Q0 or reprice C0.

Both-direction known-origin guards reject independent configured/issued
compensation, either NFT family, WD, WY and W-SD aliases of the same economic
origin. Wallet corrections cannot reset identity. Missing real operational
original-wallet datasets remain a separate limitation.

Stage2 requires activation and the exact original caller, valid source,
deadline, positive remaining quantity, nonzero frozen credit, caller minimum
and exact approved wallet/custody deltas. Partial credit floors remaining
C times q over remaining Q; the final surrender takes the exact residue.
Each operation creates one exact-funded new90-day bond. Callback/funding
failure rolls back source custody, accounting, issuance and the bond.

The first full spec run exposed real EIP170 excess, not a waived check. The
new loader was separated into the removable
`UniswapV4DetfMigrationClaimVaultAllocationFacet`; its selector is removed
atomically with all nine existing administration selectors. Direct-share
reads/surrender live on the existing retained Recovery facet. Package
initialization and the shared Migration TestBase deploy the additional
facet through the existing artifact-backed component/registry mechanism.
The paid owner-first-bond prerequisite, payout gates and permanent cut
restrictions remain enforced.

| Final facet | Runtime bytes |
| --- | ---: |
| Permanent Migration | 24408 |
| Existing allocation | 24310 |
| New claim-vault allocation | 7002 |
| Retained recovery | 17077 |

All deployed facets pass the actual package surface/EIP170 test.
`final-artifact-bindings.json` hashes seven compiled artifacts. Unlinked
artifact templates have explicit null bytecode hashes and retained link
references/template hashes; they are not mislabeled as deployed runtime.
Actual linked deployment code hashes and selector bindings are retained in
the successful CLI execution manifests.

Recovery ordinal10, `ClaimVaultRedeem`, debits only booked native19 shares
and calls fixed `redeem(q,MIG,MIG)`. It requires exact selected share and
supply burn, positive returned assets satisfying the caller minimum, matching
Migration SY increase and source SY decrease. It books native9 SY once into
the existing WY inventory. Existing WY -> WS gons -> WD -> DTF -> fixed new
reserve donation stages then apply, without personal credit or a second
ordinary bond.

Fork coverage observes source-rate changes without credit repricing, selected
burns and rounding, zero/output/minimum/overdraw/bad-item rejection, failed
whole batches and preservation of earlier committed work after a later
failure. Mixed NFT/WD/WY inventory, unbooked shares/SY/gon fractions/DTF,
residual/donation budgets and already-funded new bonds remain protected.
The fork donation case retains a nonzero one-DTF Stage1 donation budget;
the successful CLI direct-share rows have a zero budget after prior routes.

## Actual18566 operator result

The successful, immutable witness directory is:

`cli-run/rehearsal-1794448019639/`

Its new Migration proxy is `0xedf7d9f65b9e57d62a3c4278223170db1308f5f0`.
All earlier positive scenarios remain exercised. The command and complete
check ledger are in `checks.json`; stdout is
`actual-cli-archive-path-fixed.log`. The final result is
`bounded-rehearsal-complete`, with `fullTask9: open`, exit0.

`claim-vault-acquisition.json` retains signed actual payment/mint receipts.
The deposit transaction is
`0xa458cd3d4a1464d8954685d28fc75246f38fab013d717c09928c75e8a10b2c51`.
Stage1 configuration is replaced with an explicitly **synthetic** original
0.6 DTF component, zero ETH, and Q0 **29999999967585**, leaving seven actual
shares outside entitlement/booked custody. C0 is **277328729 native9 DETF**.
These are fixture originals, not approved awards or source-rate-derived values.

| Actual operation | Partial | Final |
| --- | ---: | ---: |
| Native19 shares surrendered/redeemed | 9999999989195 | 19999999978390 |
| Frozen native9 credit | 92442909 | 184885820 |
| New bond ID | 18 | 19 |
| Simulated start timestamp | 1825849073 | 1825935491 |
| Cliff duration seconds | 7776000 | 7776000 |
| Exact backing gons | 39935000081969955757728240225564616284591342 | 79784358935368957278151328676364117057057480 |
| Measured native9 SY received | 999 | 2000 |
| Native9 WS redeemed/unstaked | 1284 | 2573 |
| Native18 DTF converted and donated | 6884417057589069 | 13795799254657260 |

The timestamps are local-fork simulated time, not wall-clock claims.
Credit sums to C0; final remaining units/credit are zero. Seven unbooked
native shares remain outside recovery, and self-allowance remains zero.
Each phase records missing-configuration and wrong-wallet transfer-away/back
negatives, removed-loader negatives, actual surrender/bond observations,
selected recovery minimum and whole-batch failures, an actual successful
redemption trace, a later failure preserving the committed redemption, and
the onward donation receipts. The complete fork suite additionally exercises
source/deadline/minimum/approval and callback/funding rejection paths.
`claim-vault-stage1.json`, `claim-vault-partial.json`,
`claim-vault-final.json`, `fixture-receipts.json` and copied journal records
are the detailed witnesses.

| Mined interruption resumed without replay | Original transaction |
| --- | --- |
| Donation, nonce2123 | `0xee7a736d6c738aa9d318110ed6f79f8beb85b3fea73257a4fdf2a292c18b6470` |
| Independent issuance, nonce2139 | `0x46d69ecd62a0abc54ccd8d88149ffd4f89759b26e04935bdfbf0dbbcf7645e68` |
| Paid owner first bond, nonce2157 | `0x4d9f96c727c4e03b9d2a27d17292503cc068e86e198bb47dbfe9d932a56b4910` |

Each `*-resumed.json` records `sameCanonicalReceipt: true`.
The owner bond is ID6, paid with one actual configured WETH unit, with
pre-purchase activation rejection, blocked duplicate/reward/fee routes,
unchanged snapshot and unchanged administration before activation.
Final verification confirms all ten configuration selectors are removed.

## Checks, failures corrected and limits

| Required check | Final result |
| --- | --- |
| Artifact-first complete current Migration specs | 130 passed, exit0 |
| Artifact-first complete current pinned Migration forks | 81 passed, exit0 |
| All six operator test files, one full passing invocation | 64 passed, exit0 |
| Strict operator types plus evidence scripts | exit0 |
| Current production artifact preparation | exit0 |
| Both actual operator stages | exit0 |
| Actual18566 CLI including three mined resumes | exit0 |
| Scoped diff whitespace check | exit0 |

Initial failures were retained and materially corrected: configured RPC alias
interpolation in the standalone probe; an incorrect expectation that the
legacy source rejects zero redemption; actual facet size excess; a cloned
fork fixture integer literal; omission of the CLI's required alias/block
arguments; and a prior W-SD archive pointer that referred to absent untracked
evidence in the new worktree. The latter now reads the existing retained
phase15 archive in place; it did not download a new source or add a claim-vault
archive prerequisite. The failed rehearsal's cleanup record confirms PID48079
exited and its checkpoints were removed.

The evidence binder initially encountered unlinked bytecode templates and
the `.s.sol` artifact-directory convention. It was corrected to distinguish
template versus actual deployed hashes, use actual stage paths and verify
byte-identical existing bindings without overwriting them. Canonical final
bindings use the `final-` prefix; earlier partial binding snapshots are
retained as attempt witnesses, not an alternative accepted result.

Existing compiler warnings remain visible. TypeScript and Solidity diagnostics
for the changed production/operator surfaces are clean. JSON LSP diagnostics
could not run because the preconfigured Biome executable is absent; JSON was
generated/parsed directly, and no dependency or configuration was changed.

No raw TokenStaking weights, infrastructure user authority, held09,
additional SE/LP admission, approved operational dataset, full-category,
full-plan or target-gas/public-launch acceptance is claimed. Exact archived
claim-vault source correspondence remains a provenance limitation, not an
incompatible route finding.

## Final bindings and cleanup

`final-source-bindings.json`, `final-input-bindings.json`,
`final-artifact-bindings.json`, `final-runtime-bindings.json` and
`final-sealed-preservation.json` identify the accepted delta and witnesses.
The final tree manifest covers this report, the bindings, complete witness
files and both source-snapshot sets; it excludes only its own self-reference.
The new evidence tree is made read-only after that manifest is written.
Predecessor sealed artifacts are not chmodded or overwritten.

The successful cleanup witness records PID49746 exited, chain resources
closed and `.omo-runtime/dtf-migration-claim-vault/checkpoints` removed.
Independent local checks confirm both failed/successful rehearsal PIDs are
gone, port18566 has no listener and the owned checkpoint path is absent.
The isolated source probes also closed their nodes and EOA impersonation.
No owned runtime or pending public transaction remains. Source modifications
are stopped; only this final evidence seal follows.
