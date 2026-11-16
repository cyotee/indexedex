# Four-row SE/LP source custody admission contract

Date: 2026-11-12. Source-only proposal; no production integration.

| Row | Fixed chain4663 source | Native eligible unit | Disposition |
| --- | --- | --- | --- |
| E-S | `0xb7D4Bb379d361aD442Cddee53EA71A33957826A7` | 18-decimal earlier SE shares | **not-ready**: no authenticated ordinary-user acquisition/control fixture established within the checked evidence |
| W-SW | `0x999DaE02D22E5FEe1c4508430D5196d31d631009` | 18-decimal weighted WETH/DTF SE shares | **admitted-proposal**, strictly for exact approved custody-and-hold from a genuinely funded controlled wallet |
| E-P | `0x923877336b14662cFb5B3A60b14e7d716d54A888` | 18-decimal physical earlier LP | **not-ready**: checked direct acquisition is owner-restricted; historical EN escrow cannot approve for a user |
| W-P | `0x46E068c2393e189Fbc86632f67210aF253a42Aa8` | 18-decimal physical weighted LP | **not-ready**: checked direct acquisition and fee-collector release require unavailable owner authority |

The W-SW proposal does **not** admit conversion, an original historical
allocation, Migration configuration, pricing, issuance or donation. All four
recovery limitations remain. A not-ready row is retained, not removed or
declared universally impossible.

## 1. Authority, pin and evidence

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-20-se-lp-source`.
Branch: `work/dtf-migration-phase-20-se-lp-source`.
Unchanged base: `1df9076c73b94a4f63172395763fa8cdd48fe060`.

The complete phase20 brief governs this source lane. Current main plan r5
sections 1.3-1.5 and 5.1-5.4, and PRD r22, supersede historical
preactivation surrender and partly consumed configuration amendment wording.
Surrender is Stage2-only; the paid owner-first ordinary bond precedes atomic,
irreversible activation and loader removal. No source helper proves those
Migration behaviors.

Historical source pin: block **108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
This is not the new funded frozen quote snapshot.

Evidence files in this directory:

- `inputs.json`: exact paths, raw byte lengths and SHA-256 of the phase11
  weighted/earlier contracts, independent report/matrix, phase01 actual source,
  other-metered/native executions and provenance, current law/brief, and
  stopped cumulative phase18 implementation/verification reports.
- `source-evidence.json`: archived source excerpts with original line numbers,
  complete selected historical SE/LP cases and native failures, and the
  bounded history/current-source comparison.
- `rpc.json`: complete local RPC requests and responses, including negative
  acquisition/control observations and failed log acquisition.
- `runtime.json`: actual runtimes, selector bindings, source control reads,
  separately recorded EOA funding, raw signed development-wallet transactions,
  canonical receipts, unit measurements and successful-inner-pull late rollback.
- `probe/CustodyProbe.sol` and its isolated `probe/build/` artifact: the
  fixed-W-SW disposable witness. It is not a Migration implementation.
- `report.md`, `cleanup.json`, `seal.json`: execution, cleanup and final custody.

The earlier/weighted phase11 contracts and independent matrix are historical
source contracts, not current integration acceptance. The stopped cumulative
ER reports preserve bounded ER implementation acceptance and blocked
liquidation. No ED implementation output was used.

## 2. Exact common primitive, not common acquisition authority

Actual four-row proxies are 370 bytes, runtime keccak256
`0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`.
Their observed ERC20 routing resolves to
`0x1d17acA0e0717d90cea916372070a1BE4652223F`, runtime keccak256
`0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50`.
Actual bytes and relevant bindings were read, not inferred from the proxy hash.

| Method | Selector | Archived return |
| --- | --- | --- |
| `balanceOf(address)` | `0x70a08231` | uint256 |
| `allowance(address,address)` | `0xdd62ed3e` | uint256 |
| `approve(address,uint256)` | `0x095ea7b3` | bool |
| `transfer(address,uint256)` | `0xa9059cbb` | bool |
| `transferFrom(address,address,uint256)` | `0x23b872dd` | bool |
| `decimals()` | `0x313ce567` | uint8, observed 18 |

The actual retained CP archive is `match`, including runtimeMatch `match`,
not an asserted `exact_match` or complete transitive recompilation.
Its flattened `ERC20Facet.sol:3046-3077` binds approval to `msg.sender`,
direct transfer to the caller's balance, and approved transfer to
`ERC20Repo._transferFrom`. Lines 2722-2731 spend
`allowance(owner,msg.sender)` before transfer. Lines 2582-2591 decrement
**every** sufficient allowance, including `uint256.max`; there is no
infinite-allowance exemption. The W-SW receipts independently demonstrate
finite and maximum decrements.

For a future admitted row, original wallet W approves the actual fixed
Migration custodian M; M calls the fixed source's
`transferFrom(W,M,q)`. Both W debit and M credit must equal positive native18
q, with q bounded by that original's remaining Q. An approval from EL, WL,
EN or the fee collector is not an approval from W. A facet address is not
the token or custodian. Shared ERC20 mechanics confer no right to command an
infrastructure holder.

## 3. Original record and frozen-credit contract

Each row requires a complete original: original acquiring/contributing wallet,
fixed source and generation, original record/evidence identity, canonical
wallet-independent economic origin, positive eligible native18 Q0, separately
known original ETH and DTF components, and the immutable funded snapshot.
Unknown components or original quantity reject; current holdings cannot fill
them. A known zero component is valid. Zero standalone ledger rows are not
proof of no exposure.

Keep configuration and original components separate from live source holdings,
consumed units, delivered credit, custody and recovery. Quote each original
once: `C0 = U(snapshot, ETH, originalEth) + U(snapshot, DTF, originalDtf)`.
Do not quote current share value, old rewards, routed intermediate DTF, LP
NAV or a reduced partial contribution. Do not merge originals before nonlinear
quoting. Prevent independent/NFT/receipt/wrapper/backing/SE/LP duplicate
allocation through the same canonical origin, including wallet corrections.
Opaque origin partitioning remains an operational input.

Stage1 permits full idempotent replacement without surrender; Stage2 permits
no amendment. In Stage2 require matching configuration and caller == recorded
original wallet before any custody or consumption, then actual control and
allowance. Transfers neither move configured credit nor reset it; returning
assets requires no intermediate-transfer ancestry proof.

For measured native18 q and remaining Q/C:

```text
require 0 < q <= Q
c = C when q == Q, otherwise fullPrecisionMulDiv(C,q,Q)
require c > 0 and c >= minimumCredit; enforce deadline
Q' = Q-q; C' = C-c
```

Only measured new custody enters booked recovery inventory. Preexisting and
unsolicited holdings do not add Q or C. Custody, consumption and one exactly
funded same-wallet fresh90-day cliff bond must be atomic in a future
Migration integration. Source, minimum, funding or receiver failure must revert
the enclosing operation, including its allowance spending. An earlier
separate approval remains. Recovery is a separate owner-selected transaction
domain; it must not create credit or buy an ordinary bond.

## 4. E-S: earlier SE shares

**Disposition: not-ready for a genuine-user positive custody admission.**

The retained mechanical fixture holder is EL
`0x923877336b14662cFb5B3A60b14e7d716d54A888`, a contract, holding
`240208335094234316501642770343998622608` native18 ES shares.
Historical approved custody took
`2402083350942343165016427703439986226`; tx
`0xec2ebbf5c36f0a606f7afc4fee3373679f54ee37c04a2cc1071c784b4db33a54`.
Its exact pull, unauthorized pull and enclosing rollback are retained in
`source-evidence.json`, with their infrastructure qualification intact.

Available token primitive: the section2 ERC20 pull. **Unavailable in the
checked evidence:** a real ES-owning ordinary EOA funding transfer or
authenticated public source operation that places these shares under the
controlled original wallet. EL's approval cannot be supplied on its behalf.
The bounded EOA checks in `runtime.json.eoaChecks`, plus the earlier purchaser
read in `rpc.json`, found no ES inventory in those candidates. This is not
an exhaustive holder census or proof that another EOA/path cannot exist.

ES's retained exchange selector `0xd02d3063` routes to
`0x461D94f18AfeF2C82bBffBDb63270e37c322da07`, hash
`0xd0deae3d6c52c409c2f4a57c57b81e27167dffacbca6056e81c5a18f0e879a53`.
Both redeem selectors `0xba087652` and `0x769f8e5d` are unbound in the
retained identity archive. Direct WETH/DTF exits fail **VaultDisabled(ES)**:

```text
0x1ba84b43000000000000000000000000b7d4bb379d361ad442cddee53ea71a33957826a7
```

Fresh read-only `isDisabled(ES)` remains true. Existing failed exits were
not rerun as new coverage. No ERC4626 route or success decoder is inferred.
Original eligible shares/components and real user control are still required.
If those become available, exact native18 custody remains a finite proposal;
the disabled conversion remains a distinct blocker.

## 5. W-SW: weighted WETH/DTF SE shares

**Disposition: admitted-proposal for source-only approved exact custody-and-hold.**

The old WL infrastructure fixture remains historical. New acquisition uses
the preexisting EOA `0x72BeA6Fa3E68EF18c87D045Aac7C4Aa5249d933B`,
whose code is `0x` and whose own WE balance was `869679629029`.
A separate actual local `WE.transfer(wallet,10000)` reduced that balance to
`869679619029` and credited exactly10000 to controlled wallet
`0xc9DB8bec097C2CbdcE109e03A36f98a87E04ffEf`, development derivation120.
Funding tx:
`0x0b14dc163a26819bbec7ee38810058f2d35c0adb61e4f3b853826443f7400a6e`.

The donor also owns the legacy fee collector. Its local impersonation was
used **only as owner of its own directly held ERC20 balance**, never to
invoke a collector, governance or other contract-owner permission. No
infrastructure token balance, approval or role was impersonated. The donor
transfer is a local funding fixture, not a donor-key signature, historical
qualifying purchase, public authorization or operational compensation approval.
The new wallet's subsequent approvals and pulls have actual raw development
signatures. No source balances, storage, code, roles or gas balances were
injected; gas funding used actual development-account ETH transfers.

The fixed custody witness is
`0xe65b75e7a8de220bcfec86f58c4c25a62ab7cd9b`.
Of acquired10000,9993 native18 units form its labeled synthetic denominator;
7 are separately transferred unrelated custody. Its credit constant1001
tests recurrence only. **No original ETH/DTF quote was computed or admitted.**

| Operation | Exact wallet debit / custody credit | Remaining Q/C | Allowance |
| --- | ---: | --- | --- |
| Partial | 3331 / 3331 | 6662 / 668; delivered333 | 9993 -> 6662 |
| Terminal | 6662 / 6662 | 0 / 0; delivered668 | max -> max-6662 |

Partial tx:
`0x5690bad74da323e7a83a660c39dffc859a1ed691f6928c41b4bc52f6ff8de796`.
Terminal tx:
`0x59e2d391570ecadb187dd0991a38c971129c32ba80d1f16cc035cf239a5ea26f`.
Final custody10000 minus booked9993 remains unrelated7. Actual missing
allowance and actual absent-balance attempts revert. Signed transfer-away/back
does not alter the witness's denominator. Missing synthetic record, wrong
wallet and consumed-denominator calls reject; these are helper controls, not
proof of Migration's eligibility gates.

Late tx
`0x67797968950573c3f33f863d205a06c57481fac2fe4d242196b9f291d40a6a16`
has status0 after a successful inner fixed-source `transferFrom` returning
true. Trace and before/after readings prove restoration of both endpoint
balances, allowance, Q/C and booked inventory. Prior maximum approval remains.
The final separate approval clear leaves allowance0.

Recovery stays **blocked by VaultDisabled(WE)**:

```text
0x1ba84b43000000000000000000000000999dae02d22e5fee1c4508430d5196d31d631009
```

Retain actual SY/exchange failures, including tx
`0x1965edcd8004ff758e628ff0f2637ffeddfcdd99a6c3005e396cd9745e77427b`,
and their zero outputs/unchanged shares. The historical SY facet is
`0x614f204B98Ff2E6ba7C4a365CAf7A39f167924A6`, hash
`0x7c02a5793a00529350c466cf37009b6e046109bedb49379087daef548f4faacf`;
exchange facet is `0x4D9976E8Fd5C6f698DF0303C6056efAff47e6f48`, hash
`0x8992feb5af0dea8274c8ad51e34c4d912c8257c217205dc0b18aa85e72d49ce5`.
No successful recovery layout is invented. Native28 W-SD is a different
source and is not used here.

## 6. E-P: earlier physical LP

**Disposition: not-ready for a genuine-user positive custody admission.**

Historical physical holder EN
`0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391` is a contract escrow.
Historical approved pull
`1075167226680908457977200216751522` native18 LP, tx
`0x0ec294a95fd119e4074bb0dfd475998d985bcf8588d36b5bcd5c00c151cbaf03`,
proves mechanics, not user command of that escrow.

The archived earlier core's `_depositSinglePair`/`_depositProportional`
creates LP through the hook with protocol-selected `lpTo`. Its
`_claimLiquidity` accepts only EN, ER or the parent itself, choosing
bond/protocol inventory and paying pair output. It is not an arbitrary
external LP release. See `source-evidence.json.earlierCoreArchive`,
flattened lines24824-24850,24999-25015,25737-25744.

New, read-only acquisition observation: bound
`depositSingle(address,uint256,address,uint256,uint256)`, selector
`0x1810d846`, facet `0x4B84213E58aADa1e0747E7a16d7Ac07d3721D7B1`,
rejects ordinary development caller with **NotOwner(caller)**, before any
funded acquisition. `joinSingleAssetExactIn` selector `0x498089e8` is unbound.
The existing fee-collector EL balance is contract-owned; its actual bound
`pullFee(address,uint256,address)` rejects the same ordinary caller.
No controlled E-P-owning EOA was found among the bounded candidates.

Precisely unavailable: authority to obtain escrow/collector LP, or another
authenticated ordinary-user acquisition/EOA transfer within this evidence.
This is not proof that every acquisition is impossible. No EN accounting
`originalShares`, reward weight, ER shares or NFT sale output is substituted
for physical LP Q0.

Recovery remains separately unaccepted. EL owner is ED
`0xaf0E1967c8F755c747615c5427108Bc549CA1122`, not EN or Migration.
`ownerOnlyLiquidity()` is unbound, not weighted true by analogy.
Retain exact-in **UnsupportedRoute()**, `0x5d5fe824`, and native
`withdrawSeShares(q,custody,0,0,deadline)` **NotOwner(custody)**,
`0x245aecd3`. Native failed tx:
`0xef58704e0f466bc121512b940c5b31e13434c28f3581071ada88a53965565e0e`.
Its selected facet is `0x81Fb72511016B42437FE1ac2d5Bdb0bA82f14A35`,
hash `0xca224a1792b0b9339c1c5c999c4d5e99bd33f25f8387da864d6eabb4d1d6b398`.
The earlier exact-in facet/hash are
`0x6B771DD3Fa9d577B5A7f3b52Eb95234DA5FB5E0f` /
`0x57ae69f784fdfe10d2d94f0625f6edc92f37510453500e697b257b8fb2b40a7f`.
There is no admitted successful native return decoder or owner-mediated
recovery of these surrendered tokens.

## 7. W-P: weighted physical LP

**Disposition: not-ready for a genuine-user positive custody admission.**

Historical holder `0x20af9A1e21a59a411cd3b0c40E70AF9084770b2E` is a
370-byte contract fee collector, not an EOA. Its1516646747724649142 LP
balance and historical approved custody15166467477246491, tx
`0x7b1c7c7cb4014fcac4e101a6773aca95612953267e3a87e2b18347476b53a616`,
remain mechanical infrastructure evidence.

Actual collector owner is
`0x72BeA6Fa3E68EF18c87D045Aac7C4Aa5249d933B`.
Bound `pullFee`, selector `0x45e94ee3`, rejects ordinary caller with
NotOwner. Public reserve-sync/push functions do not transfer its LP to users.
Current collector source supports that distinction, but its compiler artifact
hash differs from deployed facet hash; byte-identical source equivalence is
not asserted. Actual routing, ownership and the rejection are recorded.
No collector withdrawal or owner-role call was made.

Both bound `depositSingle` and `joinSingleAssetExactIn` route to
`0xfb56Bc5741B530C9C0B6A73A5210D0A6c3A0054E` and reject the ordinary
caller with NotOwner. No controlled EOA LP inventory was found among the
bounded candidates. Precisely unavailable: source owner-authorized liquidity
acquisition or collector release, or a separately evidenced existing-EOA LP
transfer. The W-SW donor's personal shares are not its collector's LP.

Recovery owner is WD `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7`;
`ownerOnlyLiquidity()==true`. Retain actual direct SY/exchange and native
proportional/flexible **NotOwner(custodian)** failures. Native failed tx:
`0xa10d7a7ee0f69cf886b6cbcf5f8eede817b7ea32beafa1048bf78182ac8c372f`;
actual error:

```text
0x245aecd3000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266
```

Native exit facet `0xeF727DC325d91d4cdEa81f99fDB2c49C8eB30425` has hash
`0xde852a6db9cd08e476a589f2e6d785fff605a264188c90196f5a92b40ec51151`.
Selectors are `0x8b72d9e5` and `0x94b74d12`. Actual held LP is unchanged;
outputs are zero. Protocol-managed LP burn through WD is not recovery of
arbitrary surrendered W-P. No owner impersonation, role change, executor,
guessed success decoder or route returning unrelated LP was used.

## 8. Bounded admission and remaining gates

For W-SW, source acquisition, signed control, finite/max approved exact
native18 partial/terminal custody, unrelated7 and late rollback are demonstrated.
For E-S/E-P/W-P, those **new user-controlled positive** checks were not run
because the required fixture/authority was not established. Historical
infrastructure pulls/rollback remain retained, not relabeled as new coverage.

Any new recovery proposal must first have authenticated source support and
actual caller authority, then consume these particular booked shares/LP,
return measured positive outputs to fixed custody and preserve unrelated
inventory. Disabled output legs remain disabled even if a different leg
can exit. No conversion/debit/donation stage follows from this contract.

Separate future gates remain: approved operational original quantities and
components; canonical/opaque-origin partitioning; actual Migration loader,
Stage2-only wallet checks, frozen evaluator, funded fresh90-day bonds,
operator parity and integrated inventory protection; independent verification
of this proposal; archive portability and actual target gas. Prior cumulative
parent deployment44653392 gas exceeds the retained32000000 target cap.
This tiny source helper neither fixes nor remeasures that finding.
