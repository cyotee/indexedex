# WeirVaults source-import PRD contribution

## Identity

- Run: `weir-source-import-prd-20261029-01a18660`.
- Member: Astra, independent initial author.
- Profile: source-grounded requirements authoring, not an implementation or a remediation review.
- Requested route: `chatgpt-subscription/gpt-6-astra:high`.
- Exposed runtime provider/model: `chatgpt-subscription` / `gpt-6-astra`. Reasoning setting was not independently exposed.
- Exposed session ID: `01a188d5-0ee8-70a7-967e-eee1bd8e7dbf`.
- Fresh assignment; no peer originals or feedback read; no delegation.
- Owned artifact: `docs/research/weir-source-import-prd-20261029-01a18660/members/astra/response.md`.

## Question and targets

Specify a faithful, testable baseline import of the supplied Weir domain source into `contracts/protocols/strategy/weir/`. Preserve what the implementation actually does, including awkward accounting and integration behavior. Do not convert a source import into a new vault design.

This contribution supplies proposed normative requirements, complete public-surface coverage, arithmetic definitions, acceptance rows, dependency/license dispositions, preservation risks, and release evidence. The coordinator owns synthesis, the one later advisory round, and publication of `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_PRD.md`.

## Evidence and source locators

All frozen source locators below are relative to:

`docs/research/weir-source-import-prd-20261029-01a18660/source-snapshot/sources/`.

| Short name | Source | Examination |
|---|---|---|
| W | `src/WeirVaults.sol.txt` | Complete executable source, lines 1-427 |
| B | `src/base/WeirBase.sol.txt` | Complete executable source |
| L | `src/libraries/LiquidityAmounts.sol.txt` | Complete executable source |
| O | `lib/openzeppelin-contracts/contracts/access/Ownable.sol.txt` | Complete |
| O2 | `lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol.txt` | Complete |
| P | `lib/openzeppelin-contracts/contracts/utils/Pausable.sol.txt` | Complete |
| R | `lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol.txt` | Complete |
| Ctx | `lib/openzeppelin-contracts/contracts/utils/Context.sol.txt` | Complete |
| SE | `lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol.txt` | Complete |
| PM | `lib/v4-core/src/interfaces/IPoolManager.sol.txt` | Complete |
| SL | `lib/v4-core/src/libraries/StateLibrary.sol.txt` | Complete |
| Pos | `lib/v4-core/src/libraries/Position.sol.txt` | Complete |
| FM | `lib/v4-core/src/libraries/FullMath.sol.txt` | Complete |
| Cur | `lib/v4-core/src/types/Currency.sol.txt` | Complete |
| CR | `lib/v4-core/src/libraries/CustomRevert.sol.txt` | Complete |
| Manifest | `../manifest.json`, relative to the source directory above | Complete: ABI, compiler settings, all 39 source/license/hash entries |

Repository candidates actually read, completely:

- `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol` (below, CPM).
- That same v4 tree's `interfaces/IPoolManager.sol`, `types/PoolOperation.sol`, `libraries/StateLibrary.sol`, and `libraries/LiquidityAmounts.sol`.
- `lib/crane/contracts/test/CraneTest.sol`.
- `lib/crane/test/foundry/fork/ethereum_main/uniswapV4/TestBase_UniswapV4Fork.sol`.

Also read: the complete common brief, `CLAUDE.md`, all four admitted `.github/ASSISTANT_*.md` documents, the canonical Crane porting, port verification, and testing skills, and the Native council member/workflow/research instructions. These are workflow constraints, not upstream source evidence.

**Evidence classification:** behavior statements are static source observations or explicitly identified inferences. No compiler, test, fork, live transaction, bytecode reproduction, or independent source-hash verification was run. No public query was used. The Sourcify retrieval and match status are coordinator-supplied provenance, not this author's independent network attestation.

The frozen manifest pins:

| Domain file | Supplied SHA-256 |
|---|---|
| `src/WeirVaults.sol` | `23de61301729d2950ba110e15cdce5e383fc4e5aacb0b906ee845390bd0e0180` |
| `src/base/WeirBase.sol` | `f14c1ef0fe9913f0d99e872f108ab3d7b84f44050d449d2b72049ad20a08b498` |
| `src/libraries/LiquidityAmounts.sol` | `f482702fecb1b6dc5c82b9ad918a4f991ce5b8c4d0c1144b448c25fbaad3093d` |

Manifest provenance: chain `4663`, address `0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110`, retrieval `2026-10-29T18:00:30.870Z`, reported creation/runtime matches, reported verification `2026-09-30T03:34:14Z`. The recorded public endpoint is:

`https://sourcify.dev/server/v2/contract/4663/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110?fields=sources,metadata`

No upstream Git pin, upstream test suite, audit, live manager address, pinned fork block, or reproducible deployed starting state has been supplied or established here.

## Assumptions and applicability

1. "Works correctly" means faithful behavior under the requirements below, not proof of an unstated economic safety property.
2. Ordinary accounting assertions use standard exact-transfer, non-rebasing tokens and a real manager. Hostile-token/hook tests characterize limitations rather than expand supported assets.
3. Shares are raw integer per-pool ledger units. Token decimals do not imply share decimals or an ERC20 surface.
4. Canonical dependency candidates are not presumed interchangeable. The observed type relocation and library mismatch below are implementation gates.
5. Generic porting skill examples that say `rm -rf cache out`, require wrapper/Service additions, place forks under `spec`, or demand unconditional preview/execution equality do not apply here. The explicit brief and `CLAUDE.md` require warm artifacts, no new wrapper, separate fork tests, and source-faithful preview semantics.

## Proposed normative requirements

The following SHALL/SHALL NOT statements are proposed PRD text. Their adoption is coordinator-owned; publication of this contribution does not authorize implementing them.

### Import, provenance, dependencies, and release scope

**WI-01 - Domain destination.** The future import SHALL contain the three domain files at:

- `contracts/protocols/strategy/weir/WeirVaults.sol`
- `contracts/protocols/strategy/weir/base/WeirBase.sol`
- `contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol`

It SHALL NOT create a second production domain tree. Frozen `.sol.txt` research references SHALL remain references, outside production compilation.

**WI-02 - Source preservation.** Domain logic, storage declarations and inheritance order, public ABI, constants, validation order, arithmetic evaluation order, casts, event attribution, comments, and SPDX headers SHALL be preserved. Import-path changes SHALL be enumerated in an import manifest rather than hidden by broad formatting or cleanup. No arbitrary rewrite is allowed merely because tests still pass. [W:1-427; B:1-89; L:1-69]

**WI-03 - Provenance record.** A co-located `VENDOR.md` SHALL record the frozen source identifiers and all 39 transitive entries, original path to local path mapping, original metadata keccak256 identifiers and supplied SHA-256 values, import adjustments, compiler differences, and missing upstream Git/tests/audit evidence. Future integrity verification SHALL distinguish checking frozen bytes from checking adjusted production bytes. An allowlisted transformation comparison SHALL explain why adjusted files do not retain the original text hash.

**WI-04 - Dependency routing.** Shared dependencies SHALL use canonical repository code only after ABI, Solidity type, storage-read layout, arithmetic, error, and behavior compatibility is established for the used surface. No private OZ/v4 clone, new submodule, global alias, or compiler-profile change is part of this import. In particular:

- The frozen PM declares `IPoolManager.ModifyLiquidityParams` and `IPoolManager.SwapParams` inside the interface [PM:122-154]. The canonical candidate imports top-level structs from `types/PoolOperation.sol` [canonical interface:13; PoolOperation:9-27]. Import-string replacement alone will not resolve W's qualified type references.
- The proposed narrowly permitted integration adjustment is importing those canonical types and replacing only their obsolete qualifications at W:264, 293, 323, 349, and 398. It requires a recorded field-order/type/ABI equivalence proof and a complete diff. It SHALL NOT change parameter values, calls, storage, or arithmetic. The final PRD must explicitly adopt this exception; otherwise the mismatch remains a blocker, not permission for an unrecorded edit.
- The canonical `LiquidityAmounts` candidate has only liquidity-from-amount functions, lacks W's reverse amount functions, uses `unchecked` sections and SafeCast instead of the frozen `"liquidity overflow"` check. It SHALL NOT replace Weir's L by name similarity. [L:11-69; canonical library:19-81]
- Canonical SL uses an additional hashing helper. Matching `POOLS_SLOT = 6` and the visible offsets alone is not a complete compatibility proof. Its position key, signed tick encoding, hashing, and actual manager layout SHALL be checked. [SL:11-28,230-348; canonical SL:15-32,231-351]

**WI-05 - License disposition.** Preserve the full license map in the dedicated section below. The future import/release SHALL carry original notices and a documented disposition for GPL-2.0-or-later, BUSL-1.1, and any additional canonical dependency licenses. A document can be completed while disposition is unresolved; unresolved license disposition blocks declaring the copied-source release cleared. No blanket MIT label, license scrubbing, clean-room claim, or automatic legal-clearance claim is permitted.

**WI-06 - Compiler contract.** The normal implementation validation SHALL retain the current default/fork configuration described in the brief: solc 0.8.35, optimizer 1, no viaIR. The upstream setting record remains solc `0.8.26+commit.8a97fa7a`, optimizer 800, Cancun, viaIR=true, metadata bytecodeHash=none. Source/ABI/behavior fidelity is required; default-build bytecode equality is not. If faithful source cannot compile under allowed settings, report the exact blocker and obtain a separate decision for any non-allowlisted source change. Do not silently refactor or enable viaIR.

**WI-07 - Exclusions.** The baseline SHALL NOT add ERC20/ERC4626 wrapping, rate providers, NAV-based issuance, SE/Diamond conversion, registry wiring, fee or genesis-share removal, a hook-only unlocked path, a new production simulator, strict single-token completion, optimization, or economic/security repair. Neither a discovered limitation nor a characterization test authorizes remediation.

### Data model and public/inherited surface

**WI-08 - Pool identity and position.** Every full `PoolKey` SHALL identify its own vault using the source PoolId calculation. Creation SHALL require a nonzero manager slot0 sqrt price, reject an existing vault, record `minUsableTick(key.tickSpacing)` and `maxUsableTick(key.tickSpacing)`, append once to `allVaults`, and emit `VaultCreated`. Creation is permissionless and unpaused. The managed position owner SHALL be the Weir address, with salt zero and the stored full-range ticks, not the depositor or recipient. [W:130-156,263-265,290-295,322-324]

**WI-09 - Struct and enum layout.** Preserve these ordered tuples:

| Type | Ordered fields |
|---|---|
| PoolKey | `currency0:address`, `currency1:address`, `fee:uint24`, `tickSpacing:int24`, `hooks:address` with original Solidity wrapper/interface identities |
| Vault | `key:PoolKey`, `tickLower:int24`, `tickUpper:int24`, `liquidity:uint128`, `totalShares:uint256`, `idle0:uint256`, `idle1:uint256`, `lastCompound:uint64`, `exists:bool` |
| DepositParams | `key`, `amount0:uint256`, `amount1:uint256`, `zap:bool`, `minShares:uint256`, `recipient:address`, `deadline:uint256`, `hookData:bytes` |
| WithdrawParams | `key`, `shares:uint256`, `zapTo:uint8`, `min0:uint256`, `min1:uint256`, `recipient:address`, `deadline:uint256`, `hookData:bytes` |
| Action | `DEPOSIT=0`, `WITHDRAW=1`, `COMPOUND=2` |

The `_vaults` mapping, nested `sharesOf` mapping, and `allVaults` array SHALL remain independent of ERC20 accounting. [W:38-82; Manifest ABI]

**WI-10 - Surface inventory.** The implementation SHALL expose exactly the baseline ABI, including the 27 function entries below, its constructor, and payable receive function. Preserve mutability, tuple types, outputs, errors, and event indexing; use the frozen manifest ABI as an independent inventory, not just the edited contract.

| Group | Methods/surface | Required behavior |
|---|---|---|
| Construction | `(IPoolManager,address treasury,address owner)` | Immutable manager assignment; nonzero treasury; inherited nonzero owner; no added manager-address validation |
| Views | `vault`, `vaultCount`, `previewRedeem`, `pendingFees` | WI-24 and WI-25; unknown records retain source defaults |
| Generated getters | `MAX_PERF_FEE_BPS`, `MIN_SHARES`, `treasury`, `perfFeeBps`, `sharesOf`, `allVaults`, `poolManager` | Exact types/values; `allVaults` is indexed, not a whole-array getter |
| Users | `createVault`, `deposit`, `withdraw`, `compound`, `transferShares` | WI-08 and WI-12 through WI-23 |
| Callback | `unlockCallback` | Only immutable manager; WI-11 |
| Admin | `setTreasury`, `setPerfFee`, `pause`, `unpause` | WI-26 |
| Inherited ownership | `owner`, `pendingOwner`, `transferOwnership`, `acceptOwnership`, `renounceOwnership` | WI-27 |
| Inherited pause view | `paused` | Initially false; source transition semantics |
| Native receive | Empty calldata, payable | Accept native transfers without ledger assignment |

There SHALL be no invented ERC20 `balanceOf`, allowance, approval, metadata, permit, or ERC4626 compliance requirement. [W:101-216,221-236,408-426; B:18,35-40; O/O2/P; Manifest]

**WI-11 - Unlock and callback provenance.** Deposit, withdrawal, and compound SHALL use ordinary `poolManager.unlock`; their callback SHALL reject any other caller with `NotPoolManager()` before decoding. Deposit/withdraw callback handling SHALL compound first, then execute the requested action, passing the supplied hookData through unchanged. COMPOUND inner bytes are the hookData themselves and return empty bytes. No active-operation guard, user authorization, pause modifier, or existence guard SHALL be added to the callback. Ordinary calls made while the manager is already unlocked SHALL preserve the real manager's nested-unlock failure. [B:25-28; W:175-177,199,209,221-236; CPM:55-64]

### Deposits, shares, and withdrawals

**WI-12 - Deposit ordering and attribution.** Deposit SHALL run pause, reentrancy, then deadline modifiers; reject a zero recipient; auto-create when absent; check exact native value; pull currency0 then currency1 from `msg.sender`; unlock; check returned shares against `minShares` and zero; credit only `p.recipient`; refund unused input to `msg.sender`; and emit `Deposited` naming the recipient. Manager credits during deposit SHALL also go to the payer, not the share recipient. [W:159-184; B:44-53]

**WI-13 - Liquidity sizing and genesis.** Deposit liquidity SHALL be the frozen L calculation at the post-zap pool price, with each candidate amount replaced by `amount > 2 ? amount - 2 : 0`. At first issuance, liquidity `l <= 1,000` SHALL revert `ZeroShares()`. Otherwise issue `l - 1,000`, set total shares to `l`, and assign the 1,000 reserve shares to no address. Do not credit address zero, treasury, or a burn address. [W:245-261]

**WI-14 - Subsequent issuance.** After pre-deposit compounding, subsequent shares SHALL be `floor(l * T / Lp)` using checked uint256 multiplication and division, where `T` and `Lp` are the stored total shares and liquidity immediately before the new liquidity addition. Zero shares SHALL revert `ZeroShares()`. Idle balances SHALL NOT enter the denominator or purchase price; new shares consequently participate in existing idle balances. Do not replace this with NAV issuance or an idle buy-in charge. [W:254-267]

**WI-15 - Signed deposit settlement.** Let each signed deposit net be balancing-swap delta plus the first return value of the add-liquidity call. Used input SHALL be the negative part of that net; positive net SHALL be taken directly to the depositor. The outer refund SHALL remain declared input minus used input, with checked subtraction. The add-liquidity caller delta can include fees and hook effects: it SHALL NOT be silently replaced with a principal-only amount or the second `feesAccrued` return. [W:238-275; PM:132-144; CPM:94-132]

**WI-16 - Per-pool transfers.** `transferShares` SHALL reject only zero recipient explicitly, subtract the sender balance with checked arithmetic, add to the recipient, and emit `SharesTransferred`. It SHALL remain unpaused, unguarded, and without an existence check, approvals, or manager calls. Zero transfers to a nonzero recipient on unknown pools succeed; self-transfers still require sufficient balance for the initial subtraction. [W:212-216]

**WI-17 - Withdrawal entry.** Withdrawal SHALL remain nonpayable, unpaused, nonReentrant and deadline-checked; validate zap choice before recipient, then vault existence, then nonzero shares; debit the caller's shares before unlock; compound before calculating withdrawal proportions; enforce both output minima only after callback settlement; emit `Withdrawn` naming the share owner/caller, not the recipient. Insufficient balance SHALL retain checked-subtraction panic behavior. [W:186-203,233-236]

**WI-18 - Proportional burn and idle.** With post-compound state `(Lp,T,I0,I1)` and requested shares `s`, withdrawal SHALL use:

- removed liquidity `uint128(floor(Lp*s/T))`;
- idle claims `floor(I0*s/T)` and `floor(I1*s/T)`;
- new state `Lp-removed`, `T-s`, and each idle less its claim.

If removed liquidity is zero, skip manager removal. Pay claimed idle into the manager before any zap, add it to the signed removal net, then perform the selected swap and settle each final net. Minima apply to the positive parts returned, not to hypothetical full-consumption outputs. [W:278-315]

**WI-19 - Zap heuristic.** Deposit balancing SHALL preserve the nested-floor arithmetic in the arithmetic section, use at most one swap, then use the returned deltas and new pool price. Withdrawal zap `1` SHALL attempt to sell positive currency1 for currency0; zap `2` SHALL attempt to sell positive currency0 for currency1; zap `0` SHALL not swap. A zero amount SHALL not trigger a swap. [W:244,302-310,365-388]

**WI-20 - Swap limits and partial fills.** Swaps SHALL specify negative `int256(amountIn)` and use `MIN_SQRT_PRICE+1` for zero-for-one, `MAX_SQRT_PRICE-1` otherwise. Returned signed deltas, not requested input, determine accounting. No consumption equality check, retry, refund sweep, arbitrary route, or single-token completion guarantee SHALL be added. Both returned output currencies can remain positive after a withdrawal zap. [W:302-315,391-403]

### Compounding, inventory, and views

**WI-21 - Compound order and zero liquidity.** Every compound attempt SHALL first write `uint64(block.timestamp)`. If stored liquidity is zero it SHALL return immediately: no position poke, fee take, idle deployment, or `Compounded` event. Nonzero-liquidity compounding SHALL poke with zero liquidity delta before any reinvestment. It SHALL use the positive portions of the poke's first caller-delta return as gross fees; negative components are not converted into expenses by this code. [W:319-326]

**WI-22 - Fee and reinvestment accounting.** Default performance fee SHALL be 500 bps with denominator 10,000 and hard cap 1,000 bps. For each currency, cut is `floor(grossPositiveFee * perfFeeBps / 10,000)`. Take currency0 cut then currency1 cut to the treasury addresses read at those call sites. Reinvestable amounts are net fees plus that vault's recorded idle. Apply the same per-currency two-unit cushion, and add liquidity only if positive. Update idle by its old signed value plus retained-fee net plus the add-liquidity caller delta, cast back exactly as the source does, then settle to the Weir address. Shares SHALL not change. [W:34-36,79,327-359]

**WI-23 - Events and phase attribution.** Emit `Compounded(id,f0,f1,liqAdded)` only when a harvested positive fee component is nonzero, even if liquidity added is zero. An idle-only liquidity addition can occur without this event. Deposit's pre-compound event precedes its deposit event; withdrawal's precedes its withdrawal event. Fees earned during a deposit's own balancing swap and returned by its later add-liquidity call SHALL remain in deposit settlement, without a second performance-fee cut. Fees earned during a withdrawal's post-burn swap SHALL remain attributable to the remaining position rather than being harvested again automatically. [W:224-235,263-274,290-315,360; PM:132-144; Pos:76-105]

**WI-24 - Inventory partition.** Recorded `idle0/idle1` SHALL remain per-vault accounting, not a live balance sweep. Direct ERC20/native donations to Weir SHALL not automatically create shares, increase liquidity, set idle, enter preview, or generate a performance fee. Multiple pools can physically share a currency in the same contract balance; tests SHALL account for the sum of their separate idle claims and unassigned inventory. A manager `donate` operation is different: it changes pool fee growth and can be harvested and charged. No rescue/sweep method SHALL be added. [W:117-139,245-267,281-300,332-359; B:40]

**WI-25 - View semantics.** `vault` SHALL return the stored struct even for unknown IDs; `vaultCount` SHALL return array length; indexed array access retains out-of-bounds panic. `previewRedeem` SHALL return zero immediately when total shares are zero; otherwise it SHALL use current sqrt price, truncated uint128 proportional stored liquidity, the frozen downward amount conversion, and independently floored idle fractions. It SHALL not compound, include pending fees, zap, check ownership, or cap the input at total shares. `pendingFees` SHALL return zero immediately for stored zero liquidity; otherwise it SHALL use the actual manager position liquidity and fee-growth checkpoints, with modular uint256 fee-growth subtraction and Q128 flooring. It returns gross pending fees before performance fee, not idle or withdrawable net assets. [W:108-139; SL:230-322]

### Access control, payment behavior, and failure fidelity

**WI-26 - Administration.** Only the current owner SHALL call treasury/fee/pause setters. Treasury zero SHALL revert `ZeroAddress`; fee above 1,000 SHALL revert `FeeTooHigh`; accepted setters SHALL emit even if the value is unchanged. `pause` SHALL affect only deposits, not create/withdraw/compound/transfers/views/receive. Repeated pause and unpause SHALL retain `EnforcedPause` and `ExpectedPause` respectively. [W:408-426; P:43-118]

**WI-27 - Ownership.** Preserve constructor rejection of zero owner; current/pending owner views; owner-only two-step transfer; replacement or cancellation of pending ownership by setting a new address including zero; acceptance only by pending owner; clearing pending owner on acceptance or renunciation; inherited ownership events; and loss of admin access on renunciation. A pending owner SHALL NOT gain current-owner powers before acceptance. [O:26-99; O2:26-66]

**WI-28 - Guard coverage.** Only deposit, withdraw, and compound SHALL have the source nonReentrant guard. Views, receive, createVault, transferShares, ownership methods, and admin setters SHALL not be assumed guarded. Tests SHALL exercise callback-driven reentry into both groups and distinguish pause/access failures from reentrancy errors. Read-only callbacks can observe intermediate states; tests SHALL not assert an unstated atomic-view invariant. [W:159-216,221-236,408-426; R:45-85]

**WI-29 - Native and ERC20 plumbing.** Native currency SHALL be address zero with no wrapping. Deposit msg.value SHALL equal the exact sum of native input legs; an ERC20/ERC20 deposit requires zero. Zero/native pulls SHALL skip ERC20 calls. ERC20 payment SHALL sync the currency, transfer to the manager, then settle; native payment SHALL call payable settle without adding a native sync. Positive net SHALL use manager take, negative net SHALL pay from Weir inventory, and zero net SHALL do neither. Refunds SHALL use SafeERC20 or a native call that wraps failure in B's `NativeTransferFailed()`. Manager-take failures SHALL preserve the manager's own error envelope, not be mislabeled as B's refund error. [B:40-87; SE:160-178; Cur:40-87; CR:83-125]

**WI-30 - Deadline and rollback.** Deposit and withdraw SHALL accept equality with the current timestamp and reject only a strictly expired deadline. Any propagated revert SHALL roll back vault creation, share changes, liquidity changes, idle, timestamps, token transfers/allowances, native payments/refunds, treasury cuts, hooks' state changes, and all transaction logs. No minimum check SHALL be moved earlier to avoid source-order external calls. [B:30-33; W:159-203]

**WI-31 - Errors and arithmetic fidelity.** Preserve the 18 ABI-listed errors and exact inherited argument types, plus all propagated dependency errors, strings, empty revert data, and Solidity panics where exercised. Tests SHALL not replace exact assertions with `expectRevert()` accepting any error. Preserve checked multiplication/addition/subtraction, explicit narrowing and signed casts, the checked liquidity sum, the uint64 timestamp truncation, and modular fee-growth subtraction. No "safer" cast or FullMath substitution is implicitly permitted.

The ABI-listed errors are:

- W: `NoVault()`, `VaultExists()`, `PoolNotInitialized()`, `Slippage()`, `ZeroShares()`, `ZeroAddress()`, `FeeTooHigh()`, `BadZap()`.
- B: `NotPoolManager()`, `Expired()`, `BadNativeAmount()`, `NativeTransferFailed()`.
- Inherited/dependency ABI: `OwnableInvalidOwner(address)`, `OwnableUnauthorizedAccount(address)`, `EnforcedPause()`, `ExpectedPause()`, `ReentrancyGuardReentrantCall()`, `SafeERC20FailedOperation(address)`.

### Testing and evidence obligations

**WI-32 - Real system under test.** Hermetic tests SHALL deploy the actual copied standalone Weir and a real canonical manager after the dependency gate. A reusable `TestBase_WeirVaults` SHALL inherit CraneTest or an appropriate established chain, call parent setup first, and use existing manager infrastructure if suitable. No subclass replacement of Weir, manager mock, `vm.mockCall` for its accounting, SUT etching, SUT/manager storage injection, or fabricated manager return delta is allowed. Peripheral mintable/hostile tokens, receivers, legitimate hooks, and transaction routers are permitted. A pure exposure wrapper around the actual L library is permitted for library tests; it is not a replacement vault.

**WI-33 - Exact observations.** Tests SHALL assert integer values for every affected user balance, share ledger, total shares, recorded idle, position liquidity, timestamp, treasury receipt, manager currency delta, event field, and returned value. Record actual manager calls/order and hookData where order is material. Use Foundry recording/expectations for view-call evidence rather than a mock that mutates during static calls. After successful top-level calls, manager address/currency deltas SHALL be closed and the manager locked; this is not a claim that Weir's physical balances are zero.

**WI-34 - Independent expectations.** Expected amounts SHALL come from independently derived integer arithmetic and pre-operation state, not from calling the same production helper or `previewRedeem` as an oracle for execution. Tests SHALL keep principal, fees, hook deltas, idle, and refunds separate. Deterministic fixtures SHALL include numeric vectors below; swap fixtures SHALL independently compute exact tick traversal and rounding or use independently justified committed golden values with recorded provenance. No loose price tolerance is a fidelity substitute.

**WI-35 - Characterization discipline.** Tests of source limitations SHALL pass by asserting the limitation's actual behavior or exact failure. If a scenario is not reachable without forbidden state injection, report that reachability gap rather than manufacture a pass or repair the source. A supported-domain invariant and an adversarial characterization SHALL be separate tests, with explicit token/hook assumptions.

**WI-36 - Campaigns and release record.** Deterministic fuzz/invariant campaigns SHALL span users, multiple pools, both currency directions, native/ERC20 paths, donations, transfers, compounding, pause and owner transitions. Record seed, run/depth settings, scenario-to-test traceability, successful action counts, expected revert classes, and the smallest failing sequence. A campaign composed entirely of rejected calls is insufficient.

**WI-37 - Build and local fork gates.** Build SHALL precede tests using the current artifact workflow. Hermetic tests SHALL use default profile with no RPC or secrets. Fork parity SHALL be local-only under `test/foundry/fork/` and `FOUNDRY_PROFILE=fork`, with pinned chain, block/hash, reference address/code, manager, pools, roles, position/inventory/fee state, and input provenance. Missing RPC/state SHALL be recorded as NOT RUN/BLOCKED, never passed or silently skipped. Source verification alone SHALL not satisfy transaction parity.

## Arithmetic contract and independent expected values

These mathematical definitions describe integer behavior, not replacement production pseudocode.

Let `Q = 2^96`, `H = 2^128`, `A <= B` be the two sqrt bounds, and `P` the current sqrt price. Define `MD(x,y,d) = floor(x*y/d)` with a full-width product and a uint256 result. Frozen FM rejects `d=0` or an overflowing result using empty revert data. Ordinary checked uint256 multiplication elsewhere is not MD.

### LiquidityAmounts

- `L0(A,B,a) = U128(MD(a, MD(A,B,Q), B-A))`.
- `L1(A,B,a) = U128(MD(a,Q,B-A))`.
- `U128` requires exact representability and reverts `Error("liquidity overflow")` otherwise.
- If `P <= A`, liquidity-for-amounts is `L0(A,B,a0)`.
- If `A < P < B`, compute `L0(P,B,a0)` first and `L1(A,P,a1)` second, then take their minimum. Each branch narrows before taking the minimum; an overflowing unused larger candidate still reverts.
- If `P >= B`, liquidity-for-amounts is `L1(A,B,a1)`.
- `A0(A,B,l) = floor(MD(l*Q,B-A,B)/A)`.
- `A1(A,B,l) = MD(l,B-A,Q)`.
- Amounts-for-liquidity uses all token0 at `P <= A`, `(A0(P,B,l),A1(A,P,l))` strictly inside, and all token1 at `P >= B`.
- Each function sorts its two bounds as the source does. Zero denominators and final division by zero retain the exact call-stage failure, not a new range-validation error. [L:11-69; FM:14-103]

Do not collapse nested operations just because the real-number formulas look equivalent. `MD(A,B,Q)` and nested conversions lose fractional information at their own stages.

### Deposit balancing

Let `V = MD(MD(a0,P,Q),P,Q)`.

- If `V > a1`, token0 sale input is `floor((a0 - MD(MD(a1,Q,P),Q,P))/2)`.
- If `a1 > V`, token1 sale input is `floor((a1-V)/2)`.
- Otherwise no swap.
- A chosen zero input also returns without a swap.
- New sizing amounts are the original inputs cast to int256 plus the signed returned swap deltas, then cast back to uint256. Use the source's signed arithmetic behavior.

The heuristic uses pre-swap spot price; sizing uses post-swap spot price. It is not an exact ratio solver, NAV calculation, TWAP protection, or an optimal execution guarantee. [W:365-388]

### Compound and settlement ledger

For currency `j`, let `Fj` be the positive part of the zero-poke caller delta, `Cj=floor(Fj*bps/10000)`, `Ij` old recorded idle, and `Dj` the signed first caller delta from reinvestment, or zero if no reinvestment:

- sizing inventory is `Rj=Fj-Cj+Ij`;
- settlement net is `Nj=Fj-Cj+Dj`;
- recorded idle becomes the source cast of `int256(Ij)+Nj`;
- the treasury receives `Cj`;
- positive `Nj` is taken to Weir, negative `Nj` is paid from Weir.

For ordinary exact-transfer, non-adversarial-hook success, the physical Weir balance change for that phase equals `Nj`, so idle and backing remain aligned. The same formula is not a theorem of safety for malicious token/hook behavior.

For deposit final settlement, payer net spend in a currency is `used - positiveCredit`, because unused declared input is returned and a positive manager credit can also be delivered. It is not necessarily the event's `used` field alone. For ordinary no-hook/no-extra-fee additions, each net is normally a liability; tests must still cover positive credit paths.

### Numeric anchor fixtures

**F0:** Initialize a real hookless fee-zero pool at `P=Q`, tick spacing 1, with sorted exact-transfer ERC20 currencies and no prior liquidity. Let `K=2^20=1,048,576`. Deposit `K+2` of each token without zap. The full-range bounds are TickMath's extrema. Independent arithmetic gives:

- liquidity `K`;
- total shares `K`;
- recipient shares `K-1,000 = 1,047,576`;
- manager add costs `K` of each token;
- refund `2` of each token to payer;
- idle `(0,0)`.

Mint costs round up; redemption principal rounds down. A full user-balance withdrawal from this state, without fees/zap, removes `K-1,000` liquidity and returns `K-1,001 = 1,047,575` of each token; 1,000 liquidity and 1,000 unassigned total shares remain. The two-unit cushion is not itself an idle deposit.

**F1:** From F0, use a real auxiliary router to donate exactly 20 currency0 units through the manager. Weir is the sole active position and `K` divides H, so gross accrued currency0 fees are exactly 20. At 500 bps, compound produces treasury cut 1, idle0 19, no added liquidity, and `Compounded(id,20,0,0)`. A second compound without intervening changes has no event and leaves idle0 19.

**F2:** From F1's post-compound state, donate exactly 20 currency1 units through the manager and compound. Gross fees `(0,20)`, cut `(0,1)`, candidate inventories `(19,19)`, cushioned amounts `(17,17)`, added liquidity 17, final idle `(2,2)`, unchanged total shares K, and event `Compounded(id,0,20,17)`.

**F3:** Instead, from F1's post-compound state, a second user deposits `K+2` of both tokens without zap. Pre-compound cannot deploy the one-sided idle at tick zero. The second user receives K shares, total shares become `2K`, liquidity becomes `2K`, idle0 remains 19, and the second user's proportional idle0 claim is `floor(19/2)=9`. This is a characterization of idle dilution, not an expectation of NAV fairness.

These are static arithmetic derivations to implement and verify, not reported test results.

## Acceptance and test matrix

Every successful row includes WI-33's balance/ledger/position/delta/event checks. Every failure row includes complete WI-30 rollback. Preconditions that mention a fee or delta mean one produced by real swaps/donations/hooks, never manager mocking or storage injection.

`Panic(0x11)` means checked arithmetic overflow/underflow; `Panic(0x12)` division by zero; `Panic(0x32)` array bounds. Custom errors mean their full ABI encoding with the named arguments. Event assertions include emitter, topic ordering/indexing, and full data.

### Source and surface gates

| ID | Preconditions and action | Exact expected result | Requirements / locators |
|---|---|---|---|
| AC01 | Compare the three future domain files to the frozen bytes using the final PRD's explicit adjustment allowlist. | No unlisted change; every original header/comment retained; original and adjusted hashes recorded separately. | WI-01-04; W/B/L |
| AC02 | Resolve the complete import graph and compare generated ABI with Manifest. | Exactly the baseline 27 functions, constructor, receive, 11 events, and 18 listed errors, with unchanged tuple types/indexing/mutability; propagated errors additionally tested at call sites. | WI-09-10,31 |
| AC03 | Compile with repository default settings and inspect dependency routing evidence. | Build success without profile/config change, or an explicit blocker with compiler output; no claimed success from a viaIR build. Type-relocation exception and semantic comparisons accounted for. | WI-04,06,37 |
| AC04 | Inspect all license/import records before copied-source release. | All 39 frozen entries accounted for; GPL/BUSL dispositions and additional canonical licenses explicitly recorded; no implicit clearance. | WI-03,05 |
| AC05 | Deploy with valid owner/treasury/manager. Also separately try zero treasury, zero owner, and zero manager with otherwise valid addresses. | Valid getters match inputs, fee=500, cap=1,000, MIN_SHARES=1,000, paused=false, count=0; owner creation emits ownership event. Zero treasury: `ZeroAddress`; zero owner: `OwnableInvalidOwner(0)`; zero manager is assigned without a newly invented constructor rejection. | WI-10,26-27; W:101-104; B:35-37; O:38-43 |
| AC06 | Create two initialized pools differing in a complete key field, including a shared-currency pair; create each vault. | Correct distinct IDs/ticks, existence true, zero accounting, ordered array entries, count increments once per vault; exact `VaultCreated`. | WI-08-09; W:145-156 |
| AC07 | Duplicate creation; creation for an uninitialized key; array access at count. | Respectively `VaultExists`, `PoolNotInitialized`, `Panic(0x32)`; no extra array entries or logs. | WI-08,25 |
| AC08 | Read `vault`, `previewRedeem`, `pendingFees`, and `sharesOf` for unknown ID; repeat on an empty created vault. | Unknown struct is all zero/default; both quote pairs `(0,0)`; shares zero. Empty created struct retains key/ticks/exists but quotes remain `(0,0)`. | WI-25; W:108-139 |

### Deposits and transfers

| ID | Preconditions and action | Exact expected result | Requirements / locators |
|---|---|---|---|
| AC09 | Execute F0 with payer A and recipient B, A != B. | All F0 integers; B receives 1,047,576 shares, A receives both refunds, event user=B, salt-zero position belongs to Weir; neither A nor B owns that manager position. | WI-08,12-15 |
| AC10 | Fresh fee-zero tick-zero pool; paired raw inputs 1,002, then separate fresh fixture with 1,003 each. | First computes liquidity 1,000 and reverts `ZeroShares`; second mints liquidity 1,001 and exactly one user share, refunds two each. | WI-13; W:245-261 |
| AC11 | Fresh and existing vaults; amount pairs at 0,1,2 and one-sided non-zapped deposits at an interior price. | Zero resulting liquidity/share branches revert `ZeroShares`; no false success from token transfers or idle inventory. Include both token directions. | WI-13-14; W:245-261 |
| AC12 | F0 then second identical paired deposit without fees. | Second receives K shares; liquidity and total shares `2K`; reserve-share difference remains 1,000; original recipient ledger unchanged. | WI-14 |
| AC13 | Create real pending fees then make a paired deposit. | Pre-compound fee cuts/liquidity/idle applied first; minted shares exactly `floor(newL * postCompoundT / postCompoundL)`; old fee entitlement is not priced using pre-compound L. | WI-11,14,21-23 |
| AC14 | Execute F3. | Exactly the F3 values, including new user's nine-unit idle0 claim and no separate payment for old idle. Preserve this behavior rather than failing a NAV-safety assertion. | WI-14,24,35 |
| AC15 | Real initialized pool with external liquidity; balanced, currency0-heavy, currency1-heavy, and single-sided zap entries. Include balancing difference giving x=0. | Direction/input exactly the nested-floor rule; zero/no imbalance causes no swap; one swap otherwise; sizing uses returned deltas and post-swap price; exact shares/settlement/refunds from independent oracle. | WI-19-20; W:365-403 |
| AC16 | Existing Weir liquidity in a fee-bearing pool; another payer zaps in. Record old position's fees from that same swap separately from earlier fees. | Add-liquidity first return includes same-call swap fees earned by old liquidity; those fees reduce payer used input or become payer credits. No second fee cut, no separate incumbent-share credit; exact deposit event reflects source used values. | WI-15,23; W:263-274; CPM:94-132 |
| AC17 | Normal successful deposit with computed shares S; repeat independent fixtures using minShares=S and S+1. | Equality succeeds; S+1 reverts `Slippage` after callback work; rollback includes auto-created vault, treasury fees and refunded/pulled funds. | WI-12,30 |
| AC18 | Hold shares in one pool; transfer to another user, self, and Weir; transfer zero on unknown ID; transfer to zero; overspend. | Ledger conservation per pool and exact `SharesTransferred`; self transfer unchanged after sufficient-balance check; Weir can hold stranded ledger shares; unknown zero transfer succeeds; zero recipient `ZeroAddress`; overspend `Panic(0x11)`. | WI-16 |
| AC19 | Pause with an existing funded vault; try deposit and then create, transfer, compound, withdraw, views, and native receive. | Deposit `EnforcedPause`; all other operations retain their normal independent validation/outcomes; no invented blanket pause. | WI-26,28 |
| AC20 | Deposit with multiple simultaneous invalid conditions; repeat isolated cases. | Modifier precedence: paused before reentrant check, then deadline; in body recipient before auto-create/native check/pulls. For unpaused expired and zero recipient, `Expired`; for future deadline and zero recipient, `ZeroAddress`. | WI-12,30; W:159-173 |

### Withdrawals, compounding, and inventory

| ID | Preconditions and action | Exact expected result | Requirements / locators |
|---|---|---|---|
| AC21 | F0; user withdraws all assigned shares, zapTo=0, recipient different from owner. | Output `(1,047,575,1,047,575)`, recipient paid, user ledger zero, L=T=1,000 remain, idle zero; event user is owner/caller. | WI-17-18; F0 |
| AC22 | Existing vault after real fees/idle; withdraw a proper subset. | Compound first; burn and idle claims are separately floored against post-compound total; exact new state and recipient amounts, with no last-user sweep. | WI-17-18,21-22 |
| AC23 | Obtain fee/idle state through real actions and choose a tiny withdrawal. | Use exact integer oracle: if proportional liquidity is zero, no manager removal; if an idle claim is nonzero, it is still paid; if all claims are zero, shares can be burned for zero output when both minima are zero. If no reachable fixture exists for a branch, record that gap rather than inject state. | WI-18,35 |
| AC24 | Separate equivalent withdrawal fixtures for zapTo=0,1,2 with ample tradable liquidity. | No swap / currency1-to-0 / currency0-to-1 respectively; input equals the positive pre-zap net being sold; settlement and both returned outputs match actual signed swap deltas exactly. | WI-18-20 |
| AC25 | Set price near a usable full-range boundary with finite remaining pool liquidity; choose a real withdrawal zap whose requested input exceeds consumption before the global price limit. | Swap stops at its limit or across exhausted liquidity; unsold currency remains a positive output and is delivered; no full-consumption revert added. Verify both directions in separate constructed fixtures. | WI-20,35 |
| AC26 | Real withdrawal outputs `(a,b)`; replay equivalent starting state with minima `(a,b)`, `(a+1,b)`, `(a,b+1)`. | Equality succeeds; each one-unit violation reverts `Slippage` and restores shares, position, timestamp, fees, idle, recipient balances and logs despite payment occurring before minima. | WI-17,30 |
| AC27 | Exercise withdrawal validation combinations under a valid deadline: zapTo=3, recipient=0, unknown key, shares=0, insufficient owner balance. | Ordered failures: `BadZap`, `ZeroAddress`, `NoVault`, `ZeroShares`, `Panic(0x11)` as earlier invalid conditions are removed; under expired deadline `Expired` precedes body validation. | WI-17,30 |
| AC28 | Known empty vault; anyone calls compound at time t, then again at t+1. | lastCompound updates to each uint64 timestamp; no manager position poke, no fees or transfers, no `Compounded`; no empty-position error. | WI-21 |
| AC29 | Unknown key; anyone calls compound. | `NoVault` before unlock; no timestamp/state change. | WI-11,21 |
| AC30 | Execute F1 and its no-change second compound. | Gross 20, cut 1, idle19, L unchanged, first exact event; second no event and idle unchanged, timestamp updated. | WI-21-23; F1 |
| AC31 | Execute F2. | Gross `(0,20)`, cut `(0,1)`, added17, idle `(2,2)`, total shares unchanged, exact event and physical payments. | WI-22-23; F2 |
| AC32 | Real fee donations/swaps producing integer gross fees near fee-rounding thresholds; fee settings 0,500,1,000. | Cut exactly `floor(f*bps/10000)` independently per currency. At 500 bps, gross19 -> cut0 and gross20 -> cut1. No fee charged again merely for later spending idle. | WI-22 |
| AC33 | Accumulate one-sided idle through real fees; move price using real swaps so it can be deployed, with no newly harvested positive fee in the chosen fixture. | Idle-only addition changes L/idle by exact oracle and leaves T fixed; no `Compounded` event. Distinguish this from a no-op and from fees generated by the price-moving swaps. | WI-22-23,35 |
| AC34 | Directly transfer ERC20 and native inventory to Weir before and after F0; compare views and ordinary operations. | Donations remain unassigned physical inventory; no shares/idle/fee creation solely from donation; quote accounting unchanged at identical pool state. `receive` emits no vault event. | WI-24-25,29 |
| AC35 | Two funded vaults share a currency; independently accrue fees/idle and operate on one. | Only selected vault accounting/position changes, except explicitly authorized reentrant actions in separate hostile tests. Physical shared-currency balance reconciles to the sum of recorded idle plus independently tracked unassigned inventory. | WI-08,24,33 |
| AC36 | Pre-existing inventory plus an exact-transfer token deposit without allowance or without payer balance. | Token-specific exact failure; inventory is not a substitute for payer transfer. No new shares and no inventory loss. Separately use a deliberately short-delivering token under AC55 rather than claiming it is safe. | WI-12,24,35 |
| AC37 | Burn shares then zap in a fee-bearing pool; inspect the remaining position's fee checkpoint/growth. | Fees generated by the exit swap accrue according to remaining real liquidity and are not retroactively allocated to the burned shares or auto-compounded again; subsequent pending/compound reflect them with exact flooring. | WI-18,23,25 |

### Views, arithmetic, and temporal boundaries

| ID | Preconditions and action | Exact expected result | Requirements / locators |
|---|---|---|---|
| AC38 | F0 and fee/idle variants; query preview with zero, a proper fraction, all total shares, and more than caller owns. | Exact independent downward amount calculation plus floored idle claim; no ownership check or mutation; totalShares=0 short-circuits manager reads. | WI-25 |
| AC39 | First deposit gives L=T and idle=0; call preview with `s=2^128+7`, then with a product-overflowing s. | First proportional liquidity truncates to 7 and quotes that liquidity; second reverts `Panic(0x11)` at checked multiplication. Do not replace oversized-preview behavior with a cap. | WI-25,31; W:121 |
| AC40 | Create pending fees before preview; compare preview with an actual withdrawal that first compounds, both without and with zap. | Preview omits pending fees/maintenance/zap. Assert its own exact formula and execution's separate exact formula; do not require equality. Include a no-pending/no-maintenance/no-zap equality fixture where its prerequisites actually hold. | WI-25,34 |
| AC41 | Real nonzero position with fee growth inside and last checkpoints recorded; call pendingFees. | `floor(((inside-last) mod 2^256)*positionL/H)` per currency, gross of fee; no state change. Test real below/inside/above-range states where reachable; modular-wrap arithmetic gets independent math vectors if lifecycle wrap is impractical. | WI-25,31; W:130-139 |
| AC42 | Expose actual L library with A=Q, B=2Q; input amount=3; also reverse A/B. | L0=6, L1=3 in both bound orders; reverse amount conversions at liquidity7 give amount0=3, amount1=7. | WI-31,34; L:15-50 |
| AC43 | Actual L with bounds Q/2 and 2Q, P=Q, amounts `(3,4)`; quote amounts for liquidity7. | Liquidity=min(6,8)=6; amounts `(3,3)`. At P=A and P=B select the source outer branch exactly. | WI-31,34; L:26-69 |
| AC44 | Actual L with interior P=Q, bounds Q/2 and 2Q; amounts `(2^127,1)`, then `(1,2^127)`. | Each reverts `Error("liquidity overflow")` while computing the individually overflowing branch even though the other branch fits; do not compute a wide minimum first. | WI-31,34; L:11-40 |
| AC45 | Actual L: equal nonzero bounds for liquidity calculation; separately amount0 conversion with A=0, B=Q, liquidity1. | Equal-bound liquidity path: FM empty revert for denominator zero. Second path: final `/A` causes `Panic(0x12)`. No blanket "invalid range" error. | WI-31; L:15-23,43-46; FM:14-37 |
| AC46 | Compound empty known vault at timestamps `2^64-1`, `2^64`, `2^64+7`; call deposit/withdraw at deadline equal t and t-1 in otherwise valid fixtures. | Stored timestamps respectively `2^64-1`,0,7. Deadline equality accepted; t-1 `Expired`. Reverted calls restore prior timestamp. | WI-21,30-31 |
| AC47 | Fuzz library inputs and deposit/withdraw proportions within independent valid domains, plus explicit overflow boundaries. | Exact nested-floor/cast results and exact error class; non-18-decimal token amounts remain raw units with no new decimal normalization. | WI-31,34,36 |

### Native, ownership, hooks, and reentrancy

| ID | Preconditions and action | Exact expected result | Requirements / locators |
|---|---|---|---|
| AC48 | Native/ERC20 pool; perform paired and zapped deposits with correct value, then with one unit too little/much; ERC20/ERC20 with value1. | Correct paths settle/refund in native units without WETH; wrong value `BadNativeAmount`. Payer receives native refund even when recipient differs. | WI-12,29 |
| AC49 | Payer contract rejects a nonzero native refund after otherwise successful deposit. | B's `NativeTransferFailed()`; full deposit/fee/position rollback. Repeat with zero refund: no refund call and no failure solely from rejecting receive. | WI-29-30; B:79-87 |
| AC50 | Native output or treasury cut delivered by manager.take to a rejecting receiver with known revert bytes. | Exact manager currency-transfer error envelope and nested receiver bytes; not B's refund error. No retained share burn or fee cut after failure. | WI-29-31; Cur:40-87; CR:83-125 |
| AC51 | From a legitimate outer transaction router, call manager.sync(non-native token), then first native-pair deposit whose native payment is positive and no intervening action clears sync. | Against examined CPM, native settle reaches `NonzeroNativeValue()` because B does not sync native first. Characterize exact rollback; do not repair `_pay` in this import. | WI-29,35; B:56-65; CPM:228-237,298-312 |
| AC52 | Owner/nonowner/pending-owner setter matrix; fee 0/500/1,000/1,001; zero and repeated treasury value. | Only current owner succeeds; unauthorized caller gets `OwnableUnauthorizedAccount(caller)` before body checks; bps1,001 `FeeTooHigh`; zero treasury `ZeroAddress`; accepted setters emit exact values, including no-change setters. | WI-26-27 |
| AC53 | Start, replace, cancel, accept and renounce ownership; test wrong accepter; pause then renounce in separate fixture. | Exact O/O2 pending/current-owner transitions and events; wrong accepter error includes caller; pending cleared on accept/renounce; renounced paused deployment cannot later be unpaused by former owner. | WI-26-27 |
| AC54 | Peripheral callback at pull, hook, treasury take, recipient take, and refund attempts deposit/withdraw/compound; run unpaused and paused variants. | Guarded reentry fails `ReentrancyGuardReentrantCall` where reached; paused deposit first fails `EnforcedPause`. Catching versus bubbling the nested failure determines outer success/rollback. No forged manager calls. | WI-12,28,30 |
| AC55 | Hostile token returns false, no return data with real delivery, explicit revert, or reports success with short/no delivery; seed pre-existing same-token inventory in a separate case. | False -> `SafeERC20FailedOperation(token)` at Weir SafeERC20 sites; explicit revert bytes bubble; no-return real delivery is accepted. Short/no delivery is characterized with exact balances: source has no inbound balance-delta check and may spend pre-existing inventory or fail later. No support or no-free-share safety claim is inferred. | WI-29,31,35; B:44-46; SE:160-178 |
| AC56 | During legitimate callback, call transferShares/createVault/views; an owner-controlled receiver also calls setters or ownership methods. | No added reentrancy error on unguarded surfaces: their own checks and intermediate-state visibility govern outcomes. Verify real caller's share movement, creation event/order and authorized admin state exactly. | WI-16,26-28 |
| AC57 | Both-currency fee harvest with owner treasury receiver on first cut changing treasury to another address. | Cuts were computed before either take; first cut reaches old treasury, second uses updated treasury at its source call site. Any outer failure rolls back the administrative change too. | WI-22,28,30; W:327-330 |
| AC58 | Outsider calls callback with well-formed and malformed bytes; separately an auxiliary real-manager unlock callback calls Weir compound for an existing vault. | Outsider always `NotPoolManager` before decode. Nested ordinary compound reaches manager `AlreadyUnlocked` (when not already inside Weir's guard). A reentry from an active Weir operation instead hits the Weir guard first. | WI-11,28; B:25-28; CPM:55-64 |
| AC59 | Legitimate non-delta hook records each create/add/remove/swap stage's supplied hookData; hostile hook separately reverts with known bytes. | Bytes unchanged; pre-compound poke before reinvestment before user action; exact real-manager wrapped error/rollback for the failing hook. No assumed universal success for all hooks. | WI-11,19,21,30 |
| AC60 | Legitimate return-delta hook makes zero-poke caller delta differ from informational fees; include a valid negative caller component and ensure all hook-owned debts are properly settled. | Gross fee logic uses positive first-return components, not informational fees. If a negative Weir component remains unaccounted after its source settlement, real manager rejects with `CurrencyNotSettled`; preserve actual source outcome. | WI-15,21-22,35; CPM:94-132,55-64 |
| AC61 | Hostile receiver observes Weir views and shares during treasury payment, withdrawal settlement and deposit refund. | Exact source intermediate state: e.g. withdrawal caller debit precedes callback compounding; deposit recipient credit precedes outer refunds. No claim every observable phase satisfies end-of-transaction ledger invariants. | WI-12,17,28 |
| AC62 | Invoke nonpayable baseline methods with native value through low-level calls; send empty-calldata native value separately. | Nonpayable dispatch fails without a newly added domain error; receive succeeds and leaves ledger unchanged. Assert concrete revert data in the compiled target, not a made-up payable validation selector. | WI-10,29,31 |

### Stateful and parity gates

| ID | Preconditions and action | Exact expected result | Requirements |
|---|---|---|---|
| AC63 | Deterministic supported-domain handler across at least three users and two pools, including shared currencies; deposits, transfers, withdrawals, compounds and donations. | Per pool after successful transactions: recorded liquidity equals Weir salt-zero position liquidity; sum of tracked assigned shares equals T-1,000 after genesis and zero before genesis; ordinary inventory reconciles; manager deltas closed; rollback exact. Track all recipients, including Weir itself. | WI-08,13,16,24,32-36 |
| AC64 | Separate hostile campaigns include callbacks, rejects, short delivery, return-delta hooks, partial fills, pause and owner changes. | Exact characterized success/failure ledger; supported-domain invariants are not falsely asserted across excluded hostile assumptions. Every outcome has a classified exact error or accounting trace. | WI-28-36 |
| AC65 | Pinned local fork on chain4663 with verified reference deployment and equivalent prepared starting state available. Execute deposit, withdraw variants, compound and share transfer locally against reference and imported baseline. | Exact return values/reverts/events/balance and position changes after explicit address-role mapping; compare equivalent inventories, fees, positions and roles, not unrelated live states. If unavailable, NOT RUN with missing RPC/block/state listed. | WI-37 |
| AC66 | Review release evidence after implementation. | Every WI and AC mapped to actual tests/static checks or explicit unresolved gates; build and hermetic runs successful; dependency/license disposition complete; fork status honestly separate. No upstream-parity or production-safety claim beyond evidence. | WI-03-07,32-37 |

## Test organization and validation commands

Proposed infrastructure:

- `contracts/protocols/strategy/weir/test/bases/TestBase_WeirVaults.sol`
- Co-located Behavior and Handler helpers under `contracts/protocols/strategy/weir/test/`, with minimal peripheral routers/tokens/hooks needed for real-manager fixtures.
- `test/foundry/spec/protocols/strategy/weir/` for ABI, lifecycle, arithmetic, inventory, access/reentrancy, and deterministic invariant suites.
- `test/foundry/fork/protocols/strategy/weir/` for the separate local fork suite.

The inspected `CraneTest` performs parent setup and factory bootstrap. The inspected `TestBase_UniswapV4EthereumMainnetFork` is a `forge-std/Test`-based Ethereum-mainnet fork fixture with a fixed mainnet block and Infura alias; it is not a hermetic manager fixture and does not establish chain4663 Weir parity. Its quote-tolerance helper is not an acceptable exact arithmetic oracle. Reuse applicable helpers only; do not import unrelated product wiring or infer that no other manager fixture exists from this narrow examination.

A standalone port can be deployed as its actual contract in its TestBase under the protocol-port allowance. No proxy or registry integration is being tested. Factory helpers used by CraneTest still require fresh runtime artifacts.

Future commands, proposed but **not run in this assignment**, from repository root:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/protocols/strategy/weir/WeirVaults.sol \
  --test-root test/foundry/spec/protocols/strategy/weir

forge build
forge test --match-path 'test/foundry/spec/protocols/strategy/weir/**' -vvv
forge test

FOUNDRY_PROFILE=fork forge build
FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/protocols/strategy/weir/**' -vvv
```

The first command is the router-prescribed focused build-before-test workflow after domain edits. Full build/test commands are the broader release gate, not instructions to run redundant broad passes during authoring. Fork commands assume a future test with an explicitly required RPC environment variable such as `WEIR_RPC_URL` and a pinned block fixture; absent inputs must fail preflight or be reported as not run, never connect hermetic CI to RPC. Record the actual supported command options/tool versions during implementation rather than claiming they were verified here.

Seed new/empty worktrees from warm `out/` and `cache_forge/` under repository rules before the first future compile. Never delete warm artifacts, change FOUNDRY_TEST, add a package profile, enable viaIR, or kill a slow compiler merely for lacking progress output.

## Dependency and license disposition

### Required dependency evidence

| Dependency family | Decision for the PRD | Evidence still required before import acceptance |
|---|---|---|
| Weir L | Keep frozen protocol-specific implementation under the specified destination. | Exact source/rounding/error comparison and library tests; do not route to canonical namesake. |
| v4 manager/interface/type set | Prefer canonical real manager; account explicitly for the nested-to-top-level parameter-type relocation. | Full structural/ABI comparison, compile result, manager state-layout and hook/settlement behavior evidence. |
| v4 state/position/math/types | Prefer canonical equivalents only after checking all used semantics. | Tick extrema/rounding, FullMath overflow/revert bytes, signed packed deltas, position-key encoding, fee-growth wrapping, state slots and hashing, currency-transfer error behavior. |
| OZ owner/pause/reentrancy/SafeERC20 | Preserve the frozen versions' behavior through compatible canonical imports. | Canonical OZ equivalents were not read here; version/name alone is insufficient. Verify storage and function/event/error semantics and low-level token-return handling against frozen files. |
| Test infrastructure | CraneTest parent setup plus minimal real-manager Weir TestBase. | Existing suitable hermetic manager fixture search and concrete deployment selection; no invented proxy lifecycle. |

A canonical dependency mismatch that changes observable behavior is not a license to edit Weir to match it. Report the mismatched surface and route the separate decision before accepting the import.

### Complete frozen 39-file license inventory

Paths below are original metadata paths. All retain their original notices even where implementation later uses a proven compatible canonical counterpart.

| # | Original source path | Declared license |
|---|---|---|
| 1 | `src/WeirVaults.sol` | MIT |
| 2 | `src/base/WeirBase.sol` | MIT |
| 3 | `src/libraries/LiquidityAmounts.sol` | GPL-2.0-or-later |
| 4 | `lib/openzeppelin-contracts/contracts/access/Ownable.sol` | MIT |
| 5 | `lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol` | MIT |
| 6 | `lib/openzeppelin-contracts/contracts/interfaces/IERC1363.sol` | MIT |
| 7 | `lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol` | MIT |
| 8 | `lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol` | MIT |
| 9 | `lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol` | MIT |
| 10 | `lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol` | MIT |
| 11 | `lib/openzeppelin-contracts/contracts/utils/Address.sol` | MIT |
| 12 | `lib/openzeppelin-contracts/contracts/utils/Context.sol` | MIT |
| 13 | `lib/openzeppelin-contracts/contracts/utils/Errors.sol` | MIT |
| 14 | `lib/openzeppelin-contracts/contracts/utils/Pausable.sol` | MIT |
| 15 | `lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol` | MIT |
| 16 | `lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol` | MIT |
| 17 | `lib/v4-core/src/interfaces/IExtsload.sol` | MIT |
| 18 | `lib/v4-core/src/interfaces/IExttload.sol` | MIT |
| 19 | `lib/v4-core/src/interfaces/IHooks.sol` | MIT |
| 20 | `lib/v4-core/src/interfaces/IPoolManager.sol` | MIT |
| 21 | `lib/v4-core/src/interfaces/IProtocolFees.sol` | MIT |
| 22 | `lib/v4-core/src/interfaces/callback/IUnlockCallback.sol` | MIT |
| 23 | `lib/v4-core/src/interfaces/external/IERC20Minimal.sol` | MIT |
| 24 | `lib/v4-core/src/interfaces/external/IERC6909Claims.sol` | MIT |
| 25 | `lib/v4-core/src/libraries/BitMath.sol` | MIT |
| 26 | `lib/v4-core/src/libraries/CustomRevert.sol` | MIT |
| 27 | `lib/v4-core/src/libraries/FixedPoint128.sol` | MIT |
| 28 | `lib/v4-core/src/libraries/FixedPoint96.sol` | MIT |
| 29 | `lib/v4-core/src/libraries/FullMath.sol` | MIT |
| 30 | `lib/v4-core/src/libraries/LiquidityMath.sol` | MIT |
| 31 | `lib/v4-core/src/libraries/Position.sol` | BUSL-1.1 |
| 32 | `lib/v4-core/src/libraries/SafeCast.sol` | MIT |
| 33 | `lib/v4-core/src/libraries/StateLibrary.sol` | MIT |
| 34 | `lib/v4-core/src/libraries/TickMath.sol` | MIT |
| 35 | `lib/v4-core/src/types/BalanceDelta.sol` | MIT |
| 36 | `lib/v4-core/src/types/BeforeSwapDelta.sol` | MIT |
| 37 | `lib/v4-core/src/types/Currency.sol` | MIT |
| 38 | `lib/v4-core/src/types/PoolId.sol` | MIT |
| 39 | `lib/v4-core/src/types/PoolKey.sol` | MIT |

Count: 37 MIT, one GPL-2.0-or-later, one BUSL-1.1. The GPL library is imported by the main domain contract. The BUSL Position helper participates through SL's position-key calculation; it cannot be dismissed as merely an unused file without dependency analysis. [W:18,123,247,340; SL:6,241; Pos:48-67]

The examined canonical manager separately carries literal header `BSL-1.1`; CraneTest and the examined fork base carry `AGPL-3.0-or-later`. These are additional repository-side declarations, not replacements for the frozen map. Preserve and disposition the actual chosen transitive graph; this author supplies no legal conclusion about combined distribution rights.

## Preservation risks and characterization versus remediation

| Risk / observation | Why preservation is easy to get wrong | Baseline disposition |
|---|---|---|
| Idle dilution on issuance | Pricing only by L excludes existing idle, although withdrawal/preview assign idle pro rata. | Preserve WI-14 and F3; NAV buy-in or segregation is a separate product change. |
| Deposit's own swap-fee attribution | Pre-compounding does not harvest fees that the subsequent zap itself creates. Add-liquidity returns combined caller delta, which the depositor receives or pays against. | Preserve WI-15/23 and AC16; do not allocate these fees to all shareholders or charge another cut silently. |
| First return versus informational fees | Replacing first-return caller delta with second-return fees appears cleaner but changes hook accounting and settlement. | Preserve first-return behavior; exercise real return-delta hooks and unsettled failures. |
| Unassigned genesis shares | Source comment says "locked," but there is no holder entry for the reserve shares. | Test T minus assigned ledger = 1,000, not a zero-address balance. |
| Custody versus entitlement | Same ERC20 may back several vault idle ledgers; direct donations are not assigned, and hostile short delivery may consume pre-existing inventory. | Separate ordinary conservation from hostile characterization. No sweep or observed-delta credit repair. |
| Fee frequency and flooring | Per-harvest integer fee cuts are timing-sensitive; permissionless small harvests can produce different aggregate cuts from one large harvest. | Assert source flooring, including fee=19/20 threshold; do not promise aggregation neutrality. |
| One swap is not an exact optimizer | Spot-price half-imbalance ignores later price movement, finite-range exact ratios and fees. Partial fills are accepted. | Preserve and measure refunds/residual outputs; no strict one-token promise. |
| Views are not maintained exit simulation | Pending fees, compounding, zaps, oversized share casts and caller ownership are outside preview's checks. | Assert separate formulas; do not use preview equality as an unconditional success gate. |
| Native sync assumption | B's native pay omits sync(0); examined real manager honors an already-synced ERC20 until reset/settled. | Characterize AC51; do not add a sync as an import-only fix. |
| Global guard is not universal | Transfers, creation and owner actions can run during legitimate external callbacks; treasury destinations can change between takes. | Test exact guard/access boundaries and intermediate state; no blanket nonReentrant addition. |
| Broad hook compatibility claim | Hook deltas can invalidate simple fee and settlement assumptions despite the marketing comment "hooked or not." | Test valid hooks plus adverse outcomes; do not assert compatibility with every possible hook. |
| Casts and integer staging | Replacing direct casts with SafeCast, checked products with FullMath, or separately narrowed minima with a wide minimum changes failures and outputs. | Preserve exact stages and AC39/42-47. |
| Comment overclaims | "A share only ever grows in liquidity" and "blocks share-price inflation" are not proofs of universal economic safety. | Retain source comments as source text, but do not promote them into unsupported acceptance properties. |
| Compile differences | Upstream used viaIR; repository forbids it. Same source under another optimizer is not deployed-bytecode reproduction. | Separate compilation gate from source/behavior gate; report real blockers. |
| Thin ABI equivalence | Relocated structs can be ABI-identical while other shared helpers change storage, errors or math. | Explicitly prove used semantics; no name-based compatibility certification. |
| License inference | MIT top-level headers obscure GPL/BUSL transitives; source verification is not license clearance. | Complete inventory and documented disposition before copied-source release. |

### Improvements explicitly outside this baseline

The observations above do not authorize NAV issuance, idle buy-in, fee-attribution changes, inbound balance-delta enforcement, rescue functions, extra reentrancy guards, native-sync repair, exact-ratio zap solving, tighter or user-selected swap limits, strict single-token exits, share cap validation in preview, changing fee frequency, removing genesis shares, wrapping, or new dependency/compiler profiles. Each would require separately approved requirements and a deliberately labeled behavior deviation.

## Coverage, release status, and limits

| Target | Status | Evidence limit |
|---|---|---|
| Complete common brief | Examined | Governs scope, not implementation evidence |
| All three frozen domain files | Examined completely | Static source analysis only |
| Complete frozen manifest | Examined completely | Supplied hashes/match metadata not independently recomputed |
| Inherited externally callable behavior | Examined in complete frozen O/O2/P/R/Ctx | Canonical equivalents not certified |
| Critical fee/state/payment dependencies listed above | Examined completely | Other frozen dependency bodies were not all read |
| Selected canonical manager/interface/state/math/test candidates | Examined completely | Full canonical transitive graph, compiler output and runtime equivalence remain unverified |
| Upstream tests/audit/Git revision | Absent from admitted evidence | No claims invented |
| Real-manager execution and local fork parity | Not run | Explicit assignment prohibition; future gates specified |
| Peer originals/feedback | Not examined | Independence preserved |

The principal conclusion is that faithful import requires more than copying three names and passing a happy-path deposit test. The PRD must preserve the liquidity-only share price, independently recorded idle, phase-specific fee attribution, signed caller-delta settlement, direct casts, and ordinary unlock behavior. The canonical parameter-type relocation needs an explicit narrow integration decision, and the canonical namesake liquidity library is unsuitable as a silent replacement.

All requirements and acceptance rows here are proposed tests of the observed baseline, not evidence that tests passed. No source was copied into production, no implementation or configuration was changed, and no shell/Git/build/test/install/deploy operation was performed. Only this assigned contribution is authored.

This contribution does not authorize implementation. It is preserved for coordinator synthesis and the single later advisory round defined in the common brief; it does not demand an additional round.
