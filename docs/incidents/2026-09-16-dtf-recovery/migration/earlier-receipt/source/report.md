# Earlier ER source admission report

Date: 2026-11-12. **Disposition: admitted-proposal for independent admission.**

The proposed internal-share normalization has an exact public-call
measurement proof and actual pinned custody witnesses. Both endpoint
floor-carry directions, unrelated fractional inventory, positive partial
credit, exact terminal credit, retained nontransferable residue, real rate
movement, approved pull and late rollback are demonstrated. No operational
allocation, Migration implementation, funded compensation bond or receipt
liquidation is claimed.

`contract.md` is the single proposed implementation contract. It selects
internal ER shares, retains every fractional unit, and rejects an unresolved
measurement rather than borrowing an exact getter from WS or granting a
rounding surplus. Independent admission belongs in the separate
`source-verification/` directory, which this producer did not write.

## 1. Exact work and authority bindings

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-18-earlier-receipt`.
Branch: `work/dtf-migration-phase-18-earlier-receipt`.
Accepted base and final HEAD:
`acdbe319f3a20c3af6bea594c62461b6c7988717`.

Only
`docs/incidents/2026-09-16-dtf-recovery/migration/earlier-receipt/source/`
was authored. The current tracked/index diffs are empty. No production,
existing test, operator, dependency, configuration, prior evidence, commit,
held09, merge or public-operation change was made.

Read the whole phase18 brief and current main plan/PRD, complete phase17
runtime report and final commit receipt/audit, complete phase11 earlier
contract and verification report/matrix, and the required earlier source,
execution, provenance and phase07 claim/sale evidence. The current authority
is plan r5 and PRD r22 with their latest owner corrections, not the
historical wallet-less seams or preactivation-surrender wording.

The accepted phase17 runtime report's reproduced SHA-256 is
`65108f5890f7c7371f1d8a7c2752e35a6a61705adc7ca70fd9c724ed445e9490`;
its final receipt is
`6beb85a062839fdc23e3e286a68af64afd444779eeeea5a43fc7efdc20406716`.
Their prior 134 specs,92 forks and68 operator tests were read, not rerun
or presented as this source probe's executions.

`seal.json` records exact input paths, lengths and raw SHA-256, plus all
producer evidence and probe files. It excludes only its own self-reference.
`source-evidence.json` contains exact archived source excerpts, observed
proxy/facet bytes, ABI, preserved exit identities and six actual helper
runtime comparisons. `proof.json` supplies the numerical and signed-receipt
audit rather than a verdict flag alone.

## 2. Decision and exactness proof

The source internally transfers `floor(n*10^27/rTransfer)` shares but exposes
`floor(internal/10^9)` through `sharesOf`. Neither a raw custody delta,
raw wallet debit, their minimum, nor displayed calldata is an exact internal
measurement. The source's floor affects both endpoints differently.

The final contract uses both public external-share deltas to bound actual
internal transfer t within `[L,H]`, then inverts the authenticated source
transfer formula:

```text
rLow  = floor(n*10^27/(H+1)) + 1
rHigh = floor(n*10^27/L)
```

It accepts only when both bounds equal the observed positive rate r.
That proves actual `t=q=floor(n*10^27/r)` using production-callable data.
The unchanged pre/post rate and displayed-balance checks are corroboration,
not replacements for the proof. The interval also addresses the source's
caught quote fallbacks: merely reading the same rate before and after does
not establish which rate was used inside the transfer.

Rejected alternative: booking a floored external delta times10^9 can credit
old fractional inventory. Rejected alternative: diagnostic storage reads
would require a production primitive the source does not expose. The chosen
mapping uses neither. The evidence-only storage reads independently verify
that its inferred q matches the actual source state transition.

`proof.json` recomputes all eight final successful pulls from public
observations, checks their exact internal diagnostic movements, source total
share conservation, Q/C recurrence, allowance consumption and unchanged
unbooked custody. All32 final signed operations reconcile raw hash, signer,
chain4663, target and calldata with their retained receipts; decoded nonces
are retained. All eight
failed operations have status0, no logs and identical recorded source and
local accounting state; gas/nonce changes are not called rolled back.

Supplementary reduced-unit exhaustive arithmetic covers10,530 vectors.
All public-floor intervals contain the actual transfer;7,588 uniquely
identified rate cases reproduce it exactly. These are mathematical vectors,
not fabricated source balances or substitutes for the actual witnesses.

## 3. Real pinned runtime and acquisition

All runs start from chain4663/block108944663/hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
No fresh-state fallback was used. This historical source pin is not the
funded Migration quote snapshot.

Only ER `0x4AC89aD061A531FA62ddceED53520C2750113b01` is the new subject.
The actual ER facet is
`0x25E611FB63Eb904776678286EF5cbe2a931B4f9A`, code hash
`0x31151be4bf8ff8e79f448872f9a0a5c37ee413ce7d2b15206f2debcc59d86ccc`.
The13 selected runtime bindings equal retained observed and on-chain bytes.
The archived qualification remains `match`, not `exact_match`.

| Final run | Actual Anvil instance | Owned PID | Result |
| --- | --- | ---: | --- |
| `run-03` | Recorded in `run-03/identity.json:metadata.instanceId` | 94135 | `SOURCE_PROOF_COMPLETE`; child exits0 before the next `&&` command |
| `run-05` | Recorded in `run-05/identity.json:metadata.instanceId` | 95785 | `RATE_PROOF_COMPLETE`; monitor exit0 |

Anvil is1.9.1-nightly, commit
`430523103f3e2f9ba432ffdd2031a9f966153d0d`. Execution uses installed
Bun1.4.2 and the existing `/bin/zsh -lc` archive environment. Only loopback
18568 is bound. No resolved RPC credential is printed or retained.
Existing `lib/crane` and `node_modules` links were preserved.

The controlled signer is public development derivation181,
`0x33b1ce5357959ec0043e0d77556a5093ab347862`; derivation182 is
`0x9818DBC159BCC58C7feA87E82E738BDb0fcF03F8`.
Existing EOA receipt donor
`0xbedf78eb17a054d972c85ce222e2175f19899cd6` transfers genuine ER.
The controlled original signs approvals and the actual helper pulls. It is
not an infrastructure account or impersonated Migration.

Native gas is funded by actual development-account transfers. No
`setBalance`, source storage write, `setCode`, role write, source governance
call or registry enable is used. EOA impersonation is limited to recorded
existing-token funding transfers and is stopped in `finally`.

The witnesses use disclosed synthetic original-unit allocations and frozen
arithmetic C0 parameters. The10000-display acquisition creates
Q0=4551661356395084205735093309 at rate2197; C0=1000001 is a synthetic
already-quoted test parameter, **not** a claim that an invented ETH/DTF
purchase produced that quote. Likewise terminal C0=1001, zero-credit C0=1
and residual C0=1000000000 are arithmetic fixtures. No numeric historical
ETH/DTF original was fabricated. Operational loading still requires known
original components, their exact principal/reward allocation and the actual
frozen evaluator, as specified in contract section3.

## 4. Final numerical witnesses

### Both opposite floor carries

Real pre-existing custody:
455166135639508420573509 internal shares, including420573509 fractional
internal units modulo10^9.

| Witness | Exact q | Wallet external debit | Custody external credit | Credit |
| --- | ---: | ---: | ---: | ---: |
| input4, r2197 | 1820664542558033682294037 | 1820664542558033 | 1820664542558034 | 400 |
| next input1, r2197 | 455166135639508420573509 | 455166135639509 | 455166135639508 | 100 |

Transactions:
`0xfd8ba1e04b3f6311985b40d83a5b0b966cf5b7fc600c2fec48817bb38a28b780`
and
`0xea9bae18bfd3e8e79e0b9b3a96e638d2fe0c686685e4d09daab1582607df051d`.
In both cases the public inverse interval is exactly[2197,2197], and the
unbooked internal quantity is unchanged. The sender's starting fractions
are735093309 then52799272, not a manufactured zero-fraction control.

### Partial, terminal and nontransferable remainder

Genuine acquisition of4394 display units gives2*10^27 internal shares.
Two approved pulls of2197 each deliver500 then501 from synthetic C0=1001,
ending Q=C=0. A real pre-existing receipt fraction remains unrelated.
Final transaction:
`0x9ba15cd9dd0fbe82890de2bebf7b9e860dffc0295ff5a271ba97b46e6b42c267`.

The separate2197-display acquisition gives10^27 internal shares.
Pull1 consumes455166135639508420573509, delivering455166; pull2196
consumes999544833864360491579426490, delivering999544833.
**Q=1 and C=1 remain**, and a further input1 is rejected, not clamped.
The last accepted transaction is
`0x60adfbcf1129ac843a28fe2d3fffc30d344cd8c46eff0f30d6a7e0164fac81ea`.

A separate initially empty controlled wallet executes the same source split,
actually retains internal1 with displayed balance0, and fails its next source
transfer1. No source state was fabricated to obtain this boundary.
The retained residual is not labeled a product defect or terminal payout.

### Real rate movement, unchanged original credit

`run-05` uses a genuine100000000-native weighted-liquid WD transfer from
existing EOA `0x082cb14f04d9c485473dedc00d604d7e9abca303`, then a signed
existing WD-to-DTF swap, solely to fund the probe. This does not surrender
WS, measure gons, or substitute another source for ER.

The controlled wallet then transfers100*10^18 DTF to earlier ES
`0xb7D4Bb379d361aD442Cddee53EA71A33957826A7`. The actual prior ER trace
reads this ES's DTF balance as a valuation input. Its exact increase is
measured. ER rate changes2197->4046 with no change in internal share supply.
No ES exit or enable operation is called.

A subsequent input1 pull has q=247157686604053386060306,
public interval[4046,4046], and credit54. Total delivered becomes154,
remaining C999847. Q0 and C0 stay frozen, and unrelated internal custody
455166135639508420573509 remains exactly intact.
Transaction:
`0x9d6dccdfdc8a58aaf114ce9712608f9dcce43710f2924d3fd87761e3ae84a439`.

### Actual late rollback and negatives

Late failures:

* r2197:
  `0x3d7b5b43e80e0ec18ab1884ec7f4ae954df775a7324cd0b25f29447aee552800`.
* r4046:
  `0xf29d72e111ae788c4dfa848c6661b4d55eeb97f04b2451df9d3635e74853b9df`.

Both traces show successful real ER transferFrom, post-transfer source reads,
then the helper's `DeliberateLateFailure()` (`0x96ecf629`) after local
consumption/bookkeeping. Source balances/internal shares, allowance and
Q/C/B/delivered state restore. The earlier approval remains approved.
This is not a failure before custody disguised as late rollback.

The other six retained failures are zero input, wrong wallet, zero credit,
missing allowance, residual-cap rejection and the isolated source's
nontransferable residue. All restore the recorded economic state. Future
actual Migration callback/funding failure remains an integration obligation,
not a claim made by the disposable helper.

## 5. Build, artifact, audit and diagnostics

The final helper was compiled with
`forge build --use solar` and explicit output/cache paths under this owned
directory. Solar version:
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`.
No production artifact refresh, monorepo test run, changed Foundry profile or
dependency installation was performed.

Six final deployed helper runtime bindings are1568 bytes each. Actual bytes
match the compiler runtime outside only its declared immutable spans;
every span's actual value is retained. Compiler metadata source hashes match
all five compiled inputs. There is no arbitrary metadata stripping or mask.
Helpers are disposable measurement contracts, not fake Migration instances.

Final strict TypeScript checks passed for all four probe/auditor files with
`strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes` and
`verbatimModuleSyntax`. `audit.ts` completed with `AUDIT_PASS`, exit0.
`commands.md` records commands, outputs and split child/outer statuses.

TypeScript LSP freshness requests timed out; this is not a clean-LSP claim.
JSON LSP is unavailable because Biome is not installed. No installation was
attempted under the explicit dependency/configuration prohibition. JSON is
parsed and hashed directly. Existing Foundry nightly and unknown `fmt.skip`
warnings remain in the command logs.

## 6. Preserved failures and changed assumptions

| Attempt | Actual result | Resolution and retained evidence |
| --- | --- | --- |
| Ordinary initial Git status | Exit128 because prescribed `lib/crane` is a symlink | Read-only status with `--ignore-submodules=all`; links untouched |
| First PRD lookup | ENOENT for `MIGRATION_DETF_PRD.md` | Read complete actual `MIGRATION_DETF_DRAFT_PRD.md` |
| First monitor registration | Rejected timeout7200000 exceeding tool maximum3600000 | No process started; subsequent bounded registrations accepted |
| First helper compile | Exit1, `` `solc` "solar" does not exist `` | Existing nightly Forge lacked Solar in that non-login PATH; `/bin/zsh -lc` plus existing Foundry PATH compiled successfully; no fallback/compiler install |
| `run-01` | Custody witnesses completed, then exit1: real DTF donor lacked amount | Retain whole run and initial recipes; do not invent donor balance |
| `run-02` | Actual raw ED transfer to LP succeeded; ER rate stayed2197; exit1 | Preserve observation, not a rate-movement PASS |
| Initial helper measurement | Diagnostic results matched, but loose floor checks did not independently isolate transfer rate | Retain `history/ReceiptCustodyProbe-v1.sol.txt`; add the inverse-rate proof and reexecute affected custody witnesses in `run-03` |
| `run-03` + `run-04` shell | Compile and source child succeeded; genuine WD swap acquired DTF, but raw DTF transfer to LP left rate2197; outer exit1 | Preserve both child results. Trace actual rate dependencies, then target DTF.balanceOf(ES) in `run-05`, which succeeds |
| First arithmetic audit | Checks reached serialization, then exit1: JSON.stringify cannot serialize BigInt | Convert audit output integers to decimal strings; rerun audit and its strict types, exit0 |

No prior failed report or source witness was rewritten to turn it green.
The final conclusions use `run-03`, `run-05` and the completed audit.
Failed runs remain explicitly failed, with their raw source transactions,
snapshots, runtime logs and cleanup. The original disabled liquidation
attempts were not rerun.

## 7. Preserved source and product limits

Custody and conversion are distinct. The direct ER redeem and parent ED
redeemClaim failures still reach
`VaultDisabled(0xb7D4Bb379d361aD442Cddee53EA71A33957826A7)`.
Their exact transaction identities, revert bytes and historical FAIL /
UNPROVEN labels remain in `contract.md` and bound prior evidence.
No alternate receipt conversion, source governance permission, success decoder
or full recovery is admitted.

Earlier NFT claim-and-hold and sale-and-hold remain accepted under their
existing contract. Standalone receipt custody does not reopen a credited
NFT origin. The historical unavailable optional ED facet and masked
mature-close authorization concern remain qualified, not repaired here.

Missing original-wallet/origin/Q0/component operational datasets remain
inputs, not evidence that the custody arithmetic is impossible. The source
receipt-holder/supply discrepancy does not allocate new user credit.
No product gap is inferred merely from the retained one-unit Q/C residue.
An unresolved future public measurement must revert under the unchanged
validity/conservation rules; no promised rate path or forced denominator
is substituted.

Every other category remains required with its accepted or open disposition:
both liquid and NFT generations; WS, WY, direct claim-vault and W-SD;
raw TokenStaking; earlier and WETH-leg disabled SEs; both owner-restricted
fungible LPs; native ETH/WETH exposure. Opaque-origin reconciliation,
host/archive portability, target deployment gas and complete Migration
implementation remain open. The inherited44,353,454 parent deployment gas
is not changed or accepted by this small source helper's1568-byte runtime.

## 8. Cleanup and final boundary

All five owned Anvil instances are closed by their runner's `finally` block:
PIDs89388,91077,94135,94201,95785. Each run retains its own cleanup receipt.
Independent process and listener checks find no such PID and no port18568
listener. No checkpoint was created; the prescribed checkpoint path is absent.
All receipt subscriptions/providers close, and every impersonation is
explicitly stopped before the node exits. No snapshot, pending transaction,
owned compiler or execution monitor remains.

The final evidence retains static helper artifacts and command logs for
reproduction; they are not running services. No foreign runtime was adopted
or stopped. Only source evidence/probes were written. The accepted branch
and base remain unchanged, with no staged or tracked modifications.

**Source/probe modifications have stopped. The contract, proof and report are
sealed for the separate independent admission lane. No production
implementation or overall Migration completion is asserted.**
