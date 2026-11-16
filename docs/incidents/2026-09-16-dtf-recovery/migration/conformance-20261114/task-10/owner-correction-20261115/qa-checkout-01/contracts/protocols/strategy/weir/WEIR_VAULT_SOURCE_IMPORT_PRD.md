# WeirVaults baseline source-import PRD

Owner-clarified revision **weir-import-prd-owner-clarifications-20261029**, 2026-10-29. Extends the published council synthesis (weir-import-prd-final), preserving the frozen advisory draft. No production Weir Solidity has been copied; the owner follow-up verifies license/deployment evidence and updates the shared Robinhood fork pin.

## Objective and scope

Faithfully import the three pinned Weir domain files into `contracts/protocols/strategy/weir/`, preserve their source behavior, and prove the local copy with production-first real-manager tests. This is the owner-requested baseline-copy stage, not the later ERC20, Rate Provider, SE/Diamond or unlocked-hook adaptation. No previously retired IndexedEx vault family is restored. The user-selected destination overrides generic external/ layout preferences; do not create a duplicate domain tree.

“Correct” means faithful source/ABI/arithmetic and characterized limitations—not an unsupported assertion of economic safety. A risky behavior is not repaired by this PRD. A license gate is not legal clearance.

## Source identity, evidence and terminology

- Verified-source registry: chain **4663**, contract **0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110**.
- Public source record: `https://sourcify.dev/server/v2/contract/4663/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110?fields=sources,metadata`. Coordinator GET returned HTTP 200; record reports creation/runtime match and verification 2026-09-30T03:34:14Z. Retrieval: 2026-10-29T18:00:30.870Z. No independent bytecode reproduction or live-chain transaction was performed.
- Frozen corpus: `docs/research/weir-source-import-prd-20261029-01a18660/source-snapshot/manifest.json` and its 39 `.sol.txt` reference files. Coordinator re-read all saved files and verified 39/39 SHA-256 matches. The corpus contains no PoolManager implementation, upstream Git pin, upstream tests or audit.
- Content pin for the three domain files:

| Original file | SHA-256 |
|---|---|
| `src/WeirVaults.sol` | `23de61301729d2950ba110e15cdce5e383fc4e5aacb0b906ee845390bd0e0180` |
| `src/base/WeirBase.sol` | `f14c1ef0fe9913f0d99e872f108ab3d7b84f44050d449d2b72049ad20a08b498` |
| `src/libraries/LiquidityAmounts.sol` | `f482702fecb1b6dc5c82b9ad918a4f991ce5b8c4d0c1144b448c25fbaad3093d` |

The following locators refer to original frozen source lines under the corpus's `sources/` directory, not future post-import line numbers:

| Alias | Source |
|---|---|
| W | src/WeirVaults.sol.txt (427 lines) |
| B | src/base/WeirBase.sol.txt (88 lines) |
| L | src/libraries/LiquidityAmounts.sol.txt (68 lines) |
| O / O2 | lib/openzeppelin-contracts/contracts/access/Ownable.sol.txt / Ownable2Step.sol.txt |
| P / R / Ctx / SE | corresponding frozen utils/Pausable.sol.txt, utils/ReentrancyGuard.sol.txt, utils/Context.sol.txt and token/ERC20/utils/SafeERC20.sol.txt |
| PM / SL / Pos / FM / Cur / CR | corresponding frozen lib/v4-core/src/interfaces/IPoolManager.sol.txt and libraries/StateLibrary.sol.txt, Position.sol.txt, FullMath.sol.txt, types/Currency.sol.txt and libraries/CustomRevert.sol.txt |
| Manifest | source-snapshot/manifest.json, including metadata.output.abi |
| CPM | current lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol |

All four members read the three complete domain sources and manifest independently. Further dependency observations are attributed in their preserved originals and coordinator source notes. Static comparisons are not runtime equivalence. Selected live repository files can change; this is a pinned upstream corpus, not an atomic repository snapshot.

Primary language reference for explicit cast semantics: `https://docs.soliditylang.org/en/v0.8.35/types.html#explicit-conversions`. Source narrowing drops high bits; converting negative signed values to unsigned preserves the bit pattern. The surrounding checked arithmetic is a separate operation.

Repository authority: CLAUDE.md, .github/ASSISTANT_{RULES,CODING,TESTS,DEPLOYMENT}.md, canonical crane-porting/crane-porting-verification/crane-testing skills, foundry.toml, remappings.txt and docs/testing/ARTIFACT_BUILDS.md. Explicit scope overrides generic wrapper/Service/facet requirements. Warm-artifact and default/fork profile law override older skill examples that delete caches, place forks under spec or enable viaIR.

## Verified Robinhood deployment and fork pin (2026-10-29)

Sourcify deployment metadata and independent read-only calls through the foundry.toml robinhood_mainnet alias agree:

| Field | Verified value |
|---|---|
| Chain ID | 4663 (RPC 0x1237) |
| Reference WeirVaults | 0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110 |
| Deployment transaction | 0xa92ae44ce73b159a3aa3d6c8e2920b4c4771d784a253313a35d2fd9c4fad351a |
| Deployment block | 76,197,114 (0x48aacfa), transaction index 1 |
| Block hash | 0x07be1214c2742ebcea7a61d8065020e88c4b66b5fc96a753ff022a00aa2c8c1d |
| Block timestamp | 2026-09-30T03:33:23Z |
| Sender/deployer | 0x3234DEA52cc05cba7830B5305151C50AD34e9018 |
| Deployment kind | Top-level creation: transaction.to=null; successful receipt status=0x1; receipt.contractAddress equals reference WeirVaults |
| Constructor manager | 0x8366a39CC670B4001A1121B8F6A443A643e40951 |
| Constructor owner and treasury | Both 0x3234DEA52cc05cba7830B5305151C50AD34e9018 |
| Old shared fork pin | ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK=20,714,383, before deployment |
| Updated shared fork pin | ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK=76,197,114 |

The verified reference contract was deployed independently, so the conditional factory search is unnecessary. Its permissionless createVault records a PoolId/key and ledger in that existing contract; it does not deploy a separate per-pool vault contract. Constructor arguments were decoded from the creation-input tail using the frozen constructor ABI; an archival poolManager() read at this block was not obtained.

Evidence: `https://sourcify.dev/server/v2/contract/4663/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110?fields=deployment`, then eth_getTransactionByHash, eth_getTransactionReceipt and eth_getBlockByNumber through the configured alias. The block contains the successful receipt; deployment time is not Sourcify verifiedAt (2026-09-30T03:34:14Z). No live transaction was sent. eth_getCode at both candidate pins failed because the public endpoint lacks that historical state; this does not contradict the receipt and is not a completed fork test.

## Acceptance interpretation

- **Fidelity:** preserve baseline business logic exactly except the enumerated import/type-resolution adjustments and the owner-authorized compilation-only scopes/internal memory structs in WI-06.
- **Limitation/characterization:** assert what source actually does; isolate hostile assumptions and report unreachable paths rather than inject state.
- **Excluded change:** a new product behavior, not an implicit remediation work item.

Use raw token/share units. Exact-transfer non-rebasing tokens and ordinary hooks define the base conservation domain. FoT/rebasing assets are unsupported; hostile peripherals serve only characterization. All tracked share recipients, including Weir itself, must be included in ghost accounting. End-of-transaction invariants are not claims about intermediate callback views.

## Normative requirements

The following SHALL/SHALL NOT requirements define the future faithful baseline import. This document requests no implementation, production deployment or later adaptation. Source quirks are preservation/characterization requirements, not permission to repair them.

### Import, provenance, dependencies, and release scope

**WI-01 - Domain destination.** The future import SHALL contain the three domain files at:

- `contracts/protocols/strategy/weir/WeirVaults.sol`
- `contracts/protocols/strategy/weir/base/WeirBase.sol`
- `contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol`

It SHALL NOT create a second production domain tree. Frozen `.sol.txt` research references SHALL remain references, outside production compilation.

**WI-02 - Source preservation.** Domain business logic, storage declarations and inheritance order, public ABI, constants, validation order, arithmetic evaluation order, casts, event attribution, original comments and SPDX headers SHALL be preserved. The enumerated import/type-resolution adjustments and WI-06 compilation-only lexical scopes/internal memory structs are the only authorized structural exceptions. Record each adjustment in the import/refactor manifest; no arbitrary rewrite or cleanup is allowed merely because tests still pass. [W:1-427; B:1-88; L:1-68]

**WI-03 - Provenance record.** A co-located VENDOR.md SHALL record the frozen identifiers and all 39 transitive entries, original-to-local mapping, metadata keccak256 and SHA-256 values, import/type adjustments, each necessary WI-06 compilation refactor and its compiler diagnostic, compiler differences, the actual full license declarations/version links, verified deployment transaction/block/hash/constructor bindings, chosen foundry.toml RPC alias, and missing upstream Git/tests/audit evidence. Distinguish frozen-byte integrity from adjusted production hashes. The allowlisted transformation comparison SHALL explain the business-logic equivalence of approved edits, rather than expect original hashes after edits.

**WI-04 - Dependency routing.** Shared dependencies SHALL use canonical repository code only after ABI, Solidity type, storage-read layout, arithmetic, error, and behavior compatibility is established for the used surface. No private OZ/v4 clone, new submodule, global alias, or compiler-profile change is part of this import. In particular:

- The frozen PM declares `IPoolManager.ModifyLiquidityParams` and `IPoolManager.SwapParams` inside the interface [PM:122-154]. The canonical candidate imports top-level structs from `types/PoolOperation.sol` [canonical interface:13; PoolOperation:9-27]. Import-string replacement alone will not resolve W's qualified type references.
- This PRD explicitly permits importing those canonical free types and replacing only the obsolete qualifications at W:264,292,323,349 (ModifyLiquidityParams) and W:397 (SwapParams): five constructions in total. It requires a recorded field-order/type/ABI equivalence proof and a complete diff. It SHALL NOT change parameter values, calls, storage, arithmetic, tuple encoding or external selectors. This is a controlled compatibility adjustment, not a redesign.
- The canonical `LiquidityAmounts` candidate has only liquidity-from-amount functions, lacks W's reverse amount functions, uses `unchecked` sections and SafeCast instead of the frozen `"liquidity overflow"` check. It SHALL NOT replace Weir's L by name similarity. [L:11-68; canonical library:19-81]
- Canonical SL uses an additional hashing helper. Matching `POOLS_SLOT = 6` and the visible offsets alone is not a complete compatibility proof. Its position key, signed tick encoding, hashing, and actual manager layout SHALL be checked. [SL:11-28,230-348; canonical SL:15-32,231-351]

**WI-05 - License disposition.** Preserve the complete frozen license inventory and inspect the full declarations, not SPDX labels alone. GPL/AGPL are open-source licenses; Business Source License 1.1 is source-available with a time-limited production restriction. Record its actual licensor/work/version, Additional Use Grant, Change Date and Change License, including the ENS and fourth-anniversary qualifications summarized below. Preserve notices and full applicable license texts; do not infer an expiry date from the Weir deployment date or assume a grant covers IndexedEx. Unresolved source-version/parameter links and production-use disposition block release-clearance claims, not completion of this PRD. No blanket MIT label, license scrubbing, clean-room or automatic clearance claim.

**WI-06 - Compiler contract and authorized compilation refactors.** Retain the repository default/fork configuration: solc 0.8.35, optimizer 1, viaIR=false. The upstream record remains solc 0.8.26+commit.8a97fa7a, optimizer 800, Cancun, viaIR=true, metadata bytecodeHash=none; this historical true setting is not an instruction to enable it locally. If copied source cannot compile, the owner authorizes explicit lexical block scopes and gathering common temporary variables into internal memory structs, without another approval request for those techniques. Record the original diagnostic and exact diff. Such edits SHALL preserve business logic, ABI/selectors, persistent storage/inheritance, checked operations and rounding order, casts, validation/external-call order, fees, recipients, events and revert behavior; no storage-struct or public-parameter redesign. Run fidelity/behavior checks after refactoring. An unrelated or behavior-changing fix remains a separate decision. Default-build bytecode identity is not required. This authorization does not change foundry.toml or enable viaIR.

**WI-07 - Exclusions.** The baseline SHALL NOT add ERC20/ERC4626 wrapping, rate providers, NAV-based issuance, SE/Diamond conversion, registry wiring, fee or genesis-share removal, a hook-only unlocked path, a new production simulator, strict single-token completion, optimization, or economic/security repair. Neither a discovered limitation nor a characterization test authorizes remediation.

### Canonical import decision

Use the existing versioned `@crane/contracts/external/openzeppelin-contracts-v5/` family consistently for Ownable2Step/Ownable, Pausable, ReentrancyGuard, IERC20 and SafeERC20. Coordinator read Ownable2Step, Ownable, Context, Pausable, ReentrancyGuard and IERC20 and compared their text: each is byte-identical to its frozen counterpart. The versioned SafeERC20 declares v5.2.0 rather than frozen v5.1.0, but safeTransfer, safeTransferFrom and the complete _callOptionalReturn path used by Weir are text-identical. This is a used-surface static observation, not full runtime/graph certification; compile, ABI, layout and token-return tests remain gates. Do not mix distinct Context/Ownable identities across trees.

Reject the generic `external/openzeppelin-contracts/` route for the mismatching pause/guard/token helpers; it contains mixed versions. Reject the proposed `@crane/lib/openzeppelin-contracts/` 5.6.1 upgrade and its namespaced guard/storage shift. No such change is necessary to select the existing compatible versioned family. No shared source is changed by this PRD.

Use `@crane/contracts/protocols/dexes/uniswap/v4/` for manager interfaces, PoolOperation types, state/tick libraries and V4 types. FullMath and FixedPoint96/128 resolve to `@crane/contracts/protocols/dexes/uniswap/libraries/`. Keep the copied Weir-specific LiquidityAmounts with its GPL header and original relative Weir imports. All used dependency bodies, revert behavior and state-read semantics still require the WI-04 tests; path resolution alone does not certify them. No private dependency tree, new alias or config change.

### Complete direct-import allowlist

WI-03's future manifest SHALL record each of the following path rewrites and original/adjusted hashes. These are 22 existing import statements, not copied dependency files. There is no src/ level inside the canonical V4 route or contracts/ level inside the chosen versioned OZ route. FullMath/FixedPoint96/128 are in the common Uniswap libraries directory, not v4/libraries. Relative Weir imports retain their shape.

| File | Frozen specifier | Selected specifier |
|---|---|---|
| W | `@openzeppelin/contracts/access/Ownable2Step.sol` | `@crane/contracts/external/openzeppelin-contracts-v5/access/Ownable2Step.sol` |
| W | `@openzeppelin/contracts/utils/Pausable.sol` | `@crane/contracts/external/openzeppelin-contracts-v5/utils/Pausable.sol` |
| W | `@openzeppelin/contracts/utils/ReentrancyGuard.sol` | `@crane/contracts/external/openzeppelin-contracts-v5/utils/ReentrancyGuard.sol` |
| W | `v4-core/src/interfaces/IPoolManager.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol` |
| W | `v4-core/src/libraries/StateLibrary.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol` |
| W | `v4-core/src/libraries/TickMath.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol` |
| W | `v4-core/src/libraries/FullMath.sol` | `@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol` |
| W | `v4-core/src/libraries/FixedPoint96.sol` | `@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint96.sol` |
| W | `v4-core/src/libraries/FixedPoint128.sol` | `@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint128.sol` |
| W | `v4-core/src/types/PoolKey.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol` |
| W | `v4-core/src/types/PoolId.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol` |
| W | `v4-core/src/types/Currency.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol` |
| W | `v4-core/src/types/BalanceDelta.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol` |
| W | `./base/WeirBase.sol` | `./base/WeirBase.sol` |
| W | `./libraries/LiquidityAmounts.sol` | `./libraries/LiquidityAmounts.sol` |
| B | `@openzeppelin/contracts/token/ERC20/IERC20.sol` | `@crane/contracts/external/openzeppelin-contracts-v5/token/ERC20/IERC20.sol` |
| B | `@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol` | `@crane/contracts/external/openzeppelin-contracts-v5/token/ERC20/utils/SafeERC20.sol` |
| B | `v4-core/src/interfaces/IPoolManager.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol` |
| B | `v4-core/src/interfaces/callback/IUnlockCallback.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol` |
| B | `v4-core/src/types/Currency.sol` | `@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol` |
| L | `v4-core/src/libraries/FullMath.sol` | `@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol` |
| L | `v4-core/src/libraries/FixedPoint96.sol` | `@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint96.sol` |

Additionally, W imports `{ModifyLiquidityParams, SwapParams}` from `@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol` and uses those free types at the five allowlisted constructions. Do not invent a PoolOperation library namespace or edit/copy the frozen interface to relocate its structs; the chosen dependency is the existing canonical interface. Used-body compatibility remains a gate.

Six chosen OZ files are byte-identical to their frozen counterparts: Ownable2Step, Ownable, Context, Pausable, ReentrancyGuard and token/ERC20/IERC20. SafeERC20 is compared only for its used paths, not whole-file equality; its version header/import context differs. The existing canonical SafeERC20 is not copied or edited to reintroduce an unused Address import. The complete resolved graph, rather than the frozen corpus alone, determines runtime dependency licensing.

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

**WI-21 - Compound order and zero liquidity.** Every compound attempt SHALL first write `uint64(block.timestamp)`. If stored liquidity is zero it SHALL return immediately: no position poke, fee take, idle deployment, or `Compounded` event. Nonzero-liquidity compounding SHALL poke with zero liquidity delta before any reinvestment. For each signed component delta_j returned by amount0/amount1, it SHALL use Fj=0 when delta_j<=0, otherwise uint256(uint128(delta_j)), as gross fees; negative components are not converted into expenses by this code. Each accessor returns int128, so any positive delta_j is at most 2^127-1 and already fits uint128. A positive component above 2^128-1 cannot be supplied by a real BalanceDelta; do not manufacture that impossible test input. [W:319-326]

**WI-22 - Fee and reinvestment accounting.** Default performance fee SHALL be 500 bps with denominator 10,000 and hard cap 1,000 bps. For each currency, cut is `floor(grossPositiveFee * perfFeeBps / 10,000)`. Take currency0 cut then currency1 cut to the treasury addresses read at those call sites. Reinvestable amounts are net fees plus that vault's recorded idle. Apply the same per-currency two-unit cushion, and add liquidity only if positive. Update idle by its old signed value plus retained-fee net plus the add-liquidity caller delta, cast back exactly as the source does, then settle to the Weir address. Shares SHALL not change. [W:34-36,79,327-359]

**WI-23 - Events and phase attribution.** Emit `Compounded(id,f0,f1,liqAdded)` only when a harvested positive fee component is nonzero, even if liquidity added is zero. An idle-only liquidity addition can occur without this event. Deposit's pre-compound event precedes its deposit event; withdrawal's precedes its withdrawal event. Fees earned during a deposit's own balancing swap and returned by its later add-liquidity call SHALL remain in deposit settlement, without a second performance-fee cut. Fees earned during a withdrawal's post-burn swap SHALL remain attributable to the remaining position rather than being harvested again automatically. [W:224-235,263-274,290-315,360; PM:132-144; Pos:76-105]

**WI-24 - Inventory partition.** Recorded `idle0/idle1` SHALL remain per-vault accounting, not a live balance sweep. Direct ERC20/native donations to Weir SHALL not automatically create shares, increase liquidity, set idle, enter preview, or generate a performance fee. Multiple pools can physically share a currency in the same contract balance; tests SHALL account for the sum of their separate idle claims and all independently tracked unassigned receipts, including direct donations, treasury cuts sent to Weir and withdrawal proceeds sent to Weir. A nonzero self-treasury or self-recipient is valid; do not reject, sweep or rebook these receipts as an import-only repair. A manager `donate` operation is different: it changes pool fee growth and can be harvested and charged. No rescue/sweep method SHALL be added. [W:117-139,245-267,281-300,332-359; B:40]

**WI-25 - View semantics.** `vault` SHALL return the stored struct even for unknown IDs; `vaultCount` SHALL return array length; indexed array access retains out-of-bounds panic. `previewRedeem` SHALL return zero immediately when total shares are zero; otherwise it SHALL use current sqrt price, truncated uint128 proportional stored liquidity, the frozen downward amount conversion, and independently floored idle fractions. It SHALL not compound, include pending fees, zap, check ownership, or cap the input at total shares. `pendingFees` SHALL return zero immediately for stored zero liquidity; otherwise it SHALL use the actual manager position liquidity and fee-growth checkpoints, with modular uint256 fee-growth subtraction and Q128 flooring. It returns gross pending fees before performance fee, not idle or withdrawable net assets. [W:108-139; SL:230-322]

### Access control, payment behavior, and failure fidelity

**WI-26 - Administration.** Only the current owner SHALL call treasury/fee/pause setters. Treasury zero SHALL revert `ZeroAddress`; fee above 1,000 SHALL revert `FeeTooHigh`; accepted setters SHALL emit even if the value is unchanged. `pause` SHALL affect only deposits, not create/withdraw/compound/transfers/views/receive. Repeated pause and unpause SHALL retain `EnforcedPause` and `ExpectedPause` respectively. [W:408-426; P:43-118]

**WI-27 - Ownership.** Preserve constructor rejection of zero owner; current/pending owner views; owner-only two-step transfer; replacement or cancellation of pending ownership by setting a new address including zero; acceptance only by pending owner; clearing pending owner on acceptance or renunciation; inherited ownership events; and loss of admin access on renunciation. A pending owner SHALL NOT gain current-owner powers before acceptance. [O:26-99; O2:26-66]

**WI-28 - Guard coverage.** Only deposit, withdraw, and compound SHALL have the source nonReentrant guard. Views, receive, createVault, transferShares, ownership methods, and admin setters SHALL not be assumed guarded. Tests SHALL exercise callback-driven reentry into both groups and distinguish pause/access failures from reentrancy errors. Read-only callbacks can observe intermediate states; tests SHALL not assert an unstated atomic-view invariant. [W:159-216,221-236,408-426; R:45-85]

**WI-29 - Native and ERC20 plumbing.** Native currency SHALL be address zero with no wrapping. Deposit msg.value SHALL equal the exact sum of native input legs; an ERC20/ERC20 deposit requires zero. Zero/native pulls SHALL skip ERC20 calls. ERC20 payment SHALL sync the currency, transfer to the manager, then settle; native payment SHALL call payable settle without adding a native sync. Positive net SHALL use manager take, negative net SHALL pay from Weir inventory, and zero net SHALL do neither. Refunds SHALL use SafeERC20 or a native call that wraps failure in B's `NativeTransferFailed()`. Manager-take failures SHALL preserve the manager's own error envelope, not be mislabeled as B's refund error. [B:40-87; SE:160-178; Cur:40-87; CR:83-125]

Examined CPM sync is external without an onlyWhenUnlocked guard, so the open-sync precondition is not limited to one router type. Its non-native _settle branch resets the synced currency after accounting the payment; native payable settle rejects a still-synced ERC20. AC51 must preserve the no-intervening-clear condition and include sync from before unlock or during an actual callback. This is a same-transaction ordering characterization, not proof of a persistent cross-transaction denial of service. No native sync is added to Weir.

**WI-30 - Deadline and rollback.** Deposit and withdraw SHALL accept equality with the current timestamp and reject only a strictly expired deadline. A failed Weir invocation SHALL revert all its effects and receipt logs in that reverting call subtree, including vault creation, share/liquidity/idle changes, timestamps, token transfers/allowances, native payments/refunds, treasury cuts and hook effects. If the revert propagates through the enclosing transaction, all transaction effects and receipt logs revert. If an outer router catches it, earlier/later successful outer effects remain; a caught rejected reentrant call does not itself revert a successful outer Weir operation. Identify the exact invocation boundary in rollback snapshots. Debug traces or instrumented log captures are not evidence that reverted receipt logs survived. No minimum check SHALL be moved earlier to avoid source-order external calls. [B:30-33; W:159-203]

Explicit narrowing truncates high bits; same-width signed/unsigned conversion preserves the bit pattern rather than validating range. Checked arithmetic surrounding the conversion can revert separately. In particular, a negative `int256(oldIdle)+net` can become a very large uint256 in WI-22, and later settlement may succeed from other physical inventory or fail independently. Neither that cast nor the two-unit cushion proves fail-closed accounting or idle<=2. See AC67 and the language reference in the evidence section.

**WI-31 - Errors and arithmetic fidelity.** Preserve the 18 ABI-listed errors and exact inherited argument types, plus all propagated dependency errors, strings, empty revert data, and Solidity panics where exercised. Tests SHALL not replace exact assertions with `expectRevert()` accepting any error. Preserve checked multiplication/addition/subtraction, explicit narrowing and signed casts, the checked liquidity sum, the uint64 timestamp truncation, and modular fee-growth subtraction. No "safer" cast or FullMath substitution is implicitly permitted.

The ABI-listed errors are:

- W: `NoVault()`, `VaultExists()`, `PoolNotInitialized()`, `Slippage()`, `ZeroShares()`, `ZeroAddress()`, `FeeTooHigh()`, `BadZap()`.
- B: `NotPoolManager()`, `Expired()`, `BadNativeAmount()`, `NativeTransferFailed()`.
- Inherited/dependency ABI: `OwnableInvalidOwner(address)`, `OwnableUnauthorizedAccount(address)`, `EnforcedPause()`, `ExpectedPause()`, `ReentrancyGuardReentrantCall()`, `SafeERC20FailedOperation(address)`.

### Testing and evidence obligations

**WI-32 - Real system under test.** Hermetic tests SHALL deploy the actual copied standalone Weir and a real canonical manager after the dependency gate. A reusable `TestBase_WeirVaults` SHALL inherit CraneTest or an appropriate established chain, call parent setup first, and use existing manager infrastructure if suitable. No subclass replacement of Weir, manager mock, `vm.mockCall` for its accounting, SUT etching, SUT/manager storage injection, or fabricated manager return delta is allowed. Peripheral mintable/hostile tokens, receivers, legitimate hooks, and transaction routers are permitted. A pure exposure wrapper around the actual L library is permitted for library tests; it is not a replacement vault.

**WI-33 - Exact observations.** Tests SHALL assert integer values for every affected user balance, share ledger, total shares, recorded idle, position liquidity, timestamp, treasury receipt, manager currency delta, event field, and returned value. Record actual manager calls/order and hookData where order is material. Use Foundry recording/expectations for view-call evidence rather than a mock that mutates during static calls. After a successful deposit, withdrawal or compound completes its own manager unlock, all deltas required by that unlock SHALL be closed and the manager relocked; this is not a claim that Weir's physical balances are zero. Unguarded createVault/transferShares/views do not acquire or close unlock and may return inside someone else's still-active unlock. Do not assert lock closure or transaction-level invariants at that checkpoint or during callbacks.

**WI-34 - Independent expectations.** Expected amounts SHALL come from independently derived integer arithmetic and pre-operation state, not from calling the same production helper or `previewRedeem` as an oracle for execution. Tests SHALL keep principal, fees, hook deltas, idle, and refunds separate. Deterministic fixtures SHALL include numeric vectors below; swap fixtures SHALL independently compute exact tick traversal and rounding or use independently justified committed golden values with recorded provenance. No loose price tolerance is a fidelity substitute.

**WI-35 - Characterization discipline.** Tests of source limitations SHALL pass by asserting the limitation's actual behavior or exact failure. If a scenario is not reachable without forbidden state injection, report that reachability gap rather than manufacture a pass or repair the source. A supported-domain invariant and an adversarial characterization SHALL be separate tests, with explicit token/hook assumptions.

**WI-36 - Campaigns and release record.** Deterministic fuzz/invariant campaigns SHALL span users, multiple pools, both currency directions, native/ERC20 paths, donations, transfers, compounding, pause and owner transitions. Record seed, run/depth settings, scenario-to-test traceability, successful action counts, expected revert classes, and the smallest failing sequence. A campaign composed entirely of rejected calls is insufficient.

**WI-37 - Build and local fork gates.** Build precedes tests using the artifact workflow. Hermetic tests use default profile with no RPC/secrets. Fork parity is local-only under test/foundry/fork/ and FOUNDRY_PROFILE=fork. Use vm.rpcUrl with an existing Robinhood mainnet alias from foundry.toml and ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK, not a separate Weir block constant or new RPC-URL variable. The shared pin is advanced from 20,714,383 to the verified direct deployment block 76,197,114; record the actual block/hash used and verify chain4663 and Weir/manager code before operations. Record pools, roles, equivalent position/inventory/fee state and input provenance. The public alias serves deployment records but failed historical-state reads; select a configured archive-capable alias for actual parity. Missing RPC/state is NOT RUN/BLOCKED, never pass/skip. Source verification and deployment receipts do not substitute for transaction parity.

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
- Each function sorts its two bounds as the source does. Zero denominators and final division by zero retain the exact call-stage failure, not a new range-validation error. [L:11-68; FM:14-103]

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

For currency `j`, let `delta_j:int128` be the zero-poke caller-delta component, and `Fj=0` for a nonpositive component or `uint256(uint128(delta_j))` otherwise (value-preserving for positive int128), `Cj=floor(Fj*bps/10000)`, `Ij` old recorded idle, and `Dj` the signed first caller delta from reinvestment, or zero if no reinvestment:

- sizing inventory is `Rj=Fj-Cj+Ij`;
- settlement net is `Nj=Fj-Cj+Dj`;
- recorded idle becomes the source cast of `int256(Ij)+Nj`;
- the treasury receives `Cj`;
- positive `Nj` is taken to Weir, negative `Nj` is paid from Weir.

For an ordinary exact-transfer compound phase without additional callback-driven asset movements, let Sj be the portion of that currency's treasury cut actually delivered to Weir. The physical Weir balance change is Nj+Sj, while recorded idle changes by the source result of int256(Ij)+Nj. An external treasury gives Sj=0; a cut delivered to Weir gives Sj=Cj. Self-directed cuts are unassigned physical inventory, not additional idle. Record independent callback-driven movements separately. This restricted phase formula is not a theorem of safety for malicious tokens/hooks.

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

**F1:** From F0, use a real auxiliary router implementing IUnlockCallback. It opens manager.unlock, calls manager.donate(key,20,0,hookData) inside that callback, and settles the donor's exact currency debt using sync/transfer/settle before returning; the outer manager unlock closes. Only then call Weir compound. The examined canonical manager exposes donate onlyWhenUnlocked. Directly transferring tokens to Weir or merely transferring/settling into the manager does not substitute for this pool fee-growth donation. Weir is the sole active position and `K` divides H, so gross accrued currency0 fees are exactly 20. At 500 bps, compound produces treasury cut 1, idle0 19, no added liquidity, and `Compounded(id,20,0,0)`. A second compound without intervening changes has no event and leaves idle0 19.

**F2:** From F1's post-compound state, donate exactly 20 currency1 units through the manager and compound. Gross fees `(0,20)`, cut `(0,1)`, candidate inventories `(19,19)`, cushioned amounts `(17,17)`, added liquidity 17, final idle `(2,2)`, unchanged total shares K, and event `Compounded(id,0,20,17)`.

**F3:** Instead, from F1's post-compound state, a second user deposits `K+2` of both tokens without zap. Pre-compound cannot deploy the one-sided idle at tick zero. The second user receives K shares, total shares become `2K`, liquidity becomes `2K`, idle0 remains 19, and the second user's proportional idle0 claim is `floor(19/2)=9`. This is a characterization of idle dilution, not an expectation of NAV fairness.

These are static arithmetic derivations to implement and verify, not reported test results.

## Acceptance and test matrix

Every successful row includes WI-33's balance/ledger/position/delta/event checks. Every failure row includes WI-30 rollback at its explicitly identified reverting-call boundary, distinguishing caught inner failures from an uncaught transaction failure. Preconditions that mention a fee or delta mean one produced by real swaps/donations/hooks, never manager mocking or storage injection.

`Panic(0x11)` means checked arithmetic overflow/underflow; `Panic(0x12)` division by zero; `Panic(0x32)` array bounds. Custom errors mean their full ABI encoding with the named arguments. Event assertions include emitter, topic ordering/indexing, and full data.

### Source and surface gates

| ID | Preconditions and action | Exact expected result | Requirements / locators |
|---|---|---|---|
| AC01 | Compare the future domain files against frozen bytes using enumerated imports/types and necessary WI-06 compilation refactors. | No unlisted edit; original notices/comments retained; original and adjusted hashes plus exact compiler diagnostics/refactor diffs recorded. Scopes/internal memory structs preserve all WI-02/WI-06 business behavior and storage/ABI. | WI-01-04,06; W/B/L |
| AC02 | Resolve the complete import graph and compare generated ABI with Manifest. | Exactly the baseline 27 functions, constructor, receive, 11 events, and 18 listed errors, with unchanged tuple types/indexing/mutability; propagated errors additionally tested at call sites. | WI-09-10,31 |
| AC03 | Compile with default settings; if needed apply only authorized lexical scopes/internal memory structs, then repeat build and relevant fidelity/behavior checks. | Build succeeds without viaIR/config change, or exact remaining blocker is reported. Import/type relocation and compilation refactors are recorded; no business-logic change or green claim from a failed build. | WI-02-04,06,37 |
| AC04 | Inspect frozen and actual resolved license records before release, including full BUSL parameter blocks and version provenance. | All 39 entries accounted for; distinguish open-source GPL/AGPL from BUSL, record 2027-06-15 or applicable earlier conversion, ENS/grant/anniversary qualifications and old GPL-vs-new MIT change-license ambiguity. No inferred expiry, grant or automatic clearance. | WI-03,05 |
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
| AC30 | Execute F1 and its no-change second compound. | Gross 20, cut 1, idle 19, L unchanged, first exact event; second no event and idle unchanged, timestamp updated. | WI-21-23; F1 |
| AC31 | Execute F2. | Gross `(0,20)`, cut `(0,1)`, added17, idle `(2,2)`, total shares unchanged, exact event and physical payments. | WI-22-23; F2 |
| AC32 | Real fee donations/swaps producing integer gross fees near fee-rounding thresholds; fee settings 0,500,1,000. Extend F1 with treasury=Weir. | Cut exactly floor(f*bps/10000) per currency: gross19/20 at500bps gives0/1. In self-treasury F1, gross20 and cut1 give recorded idle 19, added liquidity 0, unchanged T=K and physical Weir receipt 20; the extra 1 is unassigned. A repeated no-fee compound does not book it to idle. No second fee merely for spending idle. | WI-22-24; F1 |
| AC33 | Accumulate one-sided idle through real fees; move price using real swaps so it can be deployed, with no newly harvested positive fee in the chosen fixture. | Idle-only addition changes L/idle by exact oracle and leaves T fixed; no `Compounded` event. Distinguish this from a no-op and from fees generated by the price-moving swaps. | WI-22-23,35 |
| AC34 | Direct ERC20/native donations before/after F0; separately full assigned-share F0 withdrawal to recipient=Weir, no fees/zap. | Donations alone create no shares/idle/fee and change no quote at identical pool state. Self-recipient withdrawal returns and physically delivers 1,047,575 of each currency to Weir, leaves idle(0,0), L=T=1,000 and holder shares 0; receipts are unassigned, not newly minted shares/idle. Plain receive emits no vault event. | WI-17-18,24-25,29; F0 |
| AC35 | Two funded vaults share a currency; independently accrue fees/idle and operate on one. | Only selected vault accounting/position changes, except explicitly authorized reentrant actions in separate hostile tests. Physical shared-currency balance reconciles to the sum of recorded idle plus independently tracked unassigned inventory. | WI-08,24,33 |
| AC36 | Pre-existing inventory plus an exact-transfer token deposit without allowance or without payer balance. | Token-specific exact failure; inventory is not a substitute for payer transfer. No new shares and no inventory loss. Separately use a deliberately short-delivering token under AC55 rather than claiming it is safe. | WI-12,24,35 |
| AC37 | Burn shares then zap in a fee-bearing pool; inspect the remaining position's fee checkpoint/growth. | Fees generated by the exit swap accrue according to remaining real liquidity and are not retroactively allocated to the burned shares or auto-compounded again; subsequent pending/compound reflect them with exact flooring. | WI-18,23,25 |

### Views, arithmetic, and temporal boundaries

| ID | Preconditions and action | Exact expected result | Requirements / locators |
|---|---|---|---|
| AC38 | F0 and fee/idle variants; query preview with zero, a proper fraction, all total shares, and more than caller owns. | Exact independent downward amount calculation plus floored idle claim; no ownership check or mutation; totalShares=0 short-circuits manager reads. | WI-25 |
| AC39 | F0-style L=T=2^20, idle=0: query preview with s=2^128+7, then with s=2^236; separately query any s with totalShares=0. | First checked product fits; quotient truncates to liquidity 7 and quotes that value (6 units each at the F0 price/range). At s=2^236 the product is 2^256 and reverts Panic(0x11), not a cast error. Zero totalShares short-circuits to (0,0), not division panic. Keep library Error("liquidity overflow") and actual division-by-zero cases separate under AC44-45. | WI-25,31,34; W:117-127 |
| AC40 | Create pending fees before preview; compare preview with an actual withdrawal that first compounds, both without and with zap. | Preview omits pending fees/maintenance/zap. Assert its own exact formula and execution's separate exact formula; do not require equality. Include a no-pending/no-maintenance/no-zap equality fixture where its prerequisites actually hold. | WI-25,34 |
| AC41 | Real nonzero position with fee growth inside and last checkpoints recorded; call pendingFees. | `floor(((inside-last) mod 2^256)*positionL/H)` per currency, gross of fee; no state change. Test real below/inside/above-range states where reachable; modular-wrap arithmetic gets independent math vectors if lifecycle wrap is impractical. | WI-25,31; W:130-139 |
| AC42 | Expose actual L library with A=Q, B=2Q; input amount=3; also reverse A/B. | L0=6, L1=3 in both bound orders; reverse amount conversions at liquidity 7 give amount0=3, amount1=7. | WI-31,34; L:15-50 |
| AC43 | Actual L with bounds Q/2 and 2Q, P=Q, amounts `(3,4)`; quote amounts for liquidity 7. | Liquidity=min(6,8)=6; amounts `(3,3)`. At P=A and P=B select the source outer branch exactly. | WI-31,34; L:26-68 |
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
| AC51 | Real router syncs a non-native ERC20 before a positive native-pay Weir call; separately a legitimate hook/token callback leaves such a sync open during unlock before native payment. Include caught-inner and uncaught variants. | Examined CPM reaches NonzeroNativeValue because B does not sync native. Failed Weir subtree rolls back; an earlier router sync persists if the router catches the error, while uncaught propagation rolls back the enclosing transaction. An inner failure does not close an independently owned unlock. No sync(0) repair. | WI-11,29-30,33,35; B:56-65; CPM sync/_settle |
| AC52 | Owner/nonowner/pending-owner setter matrix; fee 0/500/1,000/1,001; zero and repeated treasury value. | Only current owner succeeds; unauthorized caller gets `OwnableUnauthorizedAccount(caller)` before body checks; bps1,001 `FeeTooHigh`; zero treasury `ZeroAddress`; accepted setters emit exact values, including no-change setters. | WI-26-27 |
| AC53 | Start, replace, cancel, accept and renounce ownership; test wrong accepter; pause then renounce in separate fixture. | Exact O/O2 pending/current-owner transitions and events; wrong accepter error includes caller; pending cleared on accept/renounce; renounced paused deployment cannot later be unpaused by former owner. | WI-26-27 |
| AC54 | Actual token/hook/treasury/output-recipient/payer callbacks at pull, manager hook, take or refund attempt deposit/withdraw/compound; unpaused and paused variants. | Guarded reentry fails ReentrancyGuardReentrantCall where reached; paused deposit first fails EnforcedPause. Catching the nested rejection can permit outer success; bubbling causes rollback at the actual failed boundary. Assert actual caller and propagation/wrapping; no forged manager callbacks. | WI-12,28-30 |
| AC55 | Hostile token returns false, no return data with real delivery, explicit revert, or reports success with short/no delivery; seed pre-existing same-token inventory in a separate case. | False -> `SafeERC20FailedOperation(token)` at Weir SafeERC20 sites; explicit revert bytes bubble; no-return real delivery is accepted. Short/no delivery is characterized with exact balances: source has no inbound balance-delta check and may spend pre-existing inventory or fail later. No support or no-free-share safety claim is inferred. | WI-29,31,35; B:44-46; SE:160-178 |
| AC56 | Legitimate callbacks call transferShares/createVault/views; an actual current-owner callback also calls setters/ownership methods. Give the actual token/hook/payer/receiver its needed shares/roles. | Unguarded surfaces use their own access/balance checks, not a new guard. Token-driven share transfer moves the token caller's own shares, not an unrelated user's. Assert caller, ledger, creation/event order and intermediate views; insufficient authority/balance retains exact errors. | WI-16,26-28 |
| AC57 | Native/ERC20 pool, currency0 native, both fee components present and strictly positive first cut; initial treasury receiver is current owner and changes treasury to T2 in its native callback. Or use an explicitly callback-capable peripheral with actual caller/authority recorded. | Cuts computed before either take; native first cut reaches old treasury and second cut uses newly stored T2. Ordinary ERC20 transfer alone does not imply a recipient callback. Any propagated outer failure also rolls back the setter. | WI-22,28-30; W:327-330 |
| AC58 | Outsider calls callback with valid/malformed bytes; auxiliary real-manager unlock owner calls ordinary Weir compound and either catches or propagates its failure. Separately reenter from an active Weir operation. | Outsider gets NotPoolManager before decode. Independent nested unlock reaches AlreadyUnlocked; active Weir guarded reentry reaches its guard first. Distinguish direct error from hook/manager wrapping. A caught failure leaves the owner's unlock open until it completes; no invented inner relock. | WI-11,28-30,33; B:25-28; CPM:55-64 |
| AC59 | Existing nonzero-L vault with valid non-delta hook records applicable zero-delta modifyLiquidity poke, add, remove and swap calls/hookData. Use positive reinvestment to assert ordering; separately use zero-L/zero-reinvestment cases. | Supplied bytes unchanged; actual applicable poke precedes reinvestment then user action. No dedicated poke hook is invented: record the manager's real hook callbacks and params. Zero-L skips poke; zero calculated add skips reinvestment. createVault only reads slot0, records/emits and invokes no pool hook; initialization is separate setup. Reverting hook uses exact wrapped error and boundary rollback. | WI-08,11,19,21,28-30 |
| AC60 | Legitimate return-delta hook makes zero-poke caller delta differ from informational fees; include a valid negative caller component and ensure all hook-owned debts are properly settled. | Gross fee logic uses positive first-return components, not informational fees. If a negative Weir component remains unaccounted after its source settlement, real manager rejects with `CurrencyNotSettled`; preserve actual source outcome. | WI-15,21-22,35; CPM:94-132,55-64 |
| AC61 | Hostile receiver observes Weir views and shares during treasury payment, withdrawal settlement and deposit refund. | Exact source intermediate state: e.g. withdrawal caller debit precedes callback compounding; deposit recipient credit precedes outer refunds. No claim every observable phase satisfies end-of-transaction ledger invariants. | WI-12,17,28 |
| AC62 | Invoke nonpayable baseline methods with native value through low-level calls; send empty-calldata native value separately. | Nonpayable dispatch fails without a newly added domain error; receive succeeds and leaves ledger unchanged. Assert concrete revert data in the compiled target, not a made-up payable validation selector. | WI-10,29,31 |

### Stateful and parity gates

| ID | Preconditions and action | Exact expected result | Requirements |
|---|---|---|---|
| AC63 | Deterministic supported-domain handler, at least 3 users and 2 pools including shared currency; standard exact-transfer non-rebasing tokens, no hostile return-delta/invariant-breaking callback effects; deposits/transfers/withdrawals/compounds/donations. | Only after successful top-level completion outside callbacks: recordedL equals Weir salt-zero positionL; tracked assigned-share sum=T-1,000 after genesis, zero before; physical inventory reconciles including self-directed unassigned receipts, all recipients including Weir, and closed unlock deltas. Classified failures use the actual subtree rollback boundary. Hostile cases belong in AC64, not these invariants. | WI-08,13,16,24,28-30,32-36 |
| AC64 | Separate hostile campaigns include callbacks, rejects, short delivery, return-delta hooks, partial fills, pause and owner changes. | Exact characterized success/failure ledger; supported-domain invariants are not falsely asserted across excluded hostile assumptions. Every outcome has a classified exact error or accounting trace. | WI-28-36 |
| AC65 | Local chain4663 fork via foundry.toml alias and shared ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK (76,197,114 for this revision); pin hash/archive state and verify reference Weir/manager code and equivalent selected-pool/role state. | Deployment source, receipt and block match the table below: direct CREATE, not a factory. Actual parity compares exact returns/reverts/events and mapped balances/positions. Local role impersonation needs no production private key; no live write/SUT storage injection. Pruned state or missing credentials is NOT RUN/BLOCKED, never pass or substitute chain. | WI-03,37 |
| AC66 | Review release evidence after implementation. | Every WI and AC mapped to actual tests/static checks or explicit unresolved gates; build and hermetic runs successful; dependency/license disposition complete; fork status honestly separate. No upstream-parity or production-safety claim beyond evidence. | WI-03-07,32-37 |


### Additional reconciliation acceptance rows

| ID | Preconditions and action | Exact expected result | Requirements |
|---|---|---|---|
| AC67 | In a real valid return-delta-hook pool, construct an add/reinvestment whose signed oldIdle+net is -1, with enough independently tracked donated physical currency to pay the actual debt and the hook settling its own deltas. Use the F1/F2 style ordinary fee/idle fixture as a starting point; do not inject SUT/manager storage. | If the stated precondition is reached, the unsigned recorded idle is exactly 2^256-1; it is not an automatic cast revert. Assert the independent physical balance, hook/Weir deltas and any actual earlier/later revert with full rollback. If the prescribed real-manager precondition cannot be built, report that precise reachability gap rather than assert fail-closed safety or a green fabricated scenario. | WI-22,24,28,31-35 |
| AC68 | Check the six selected byte-identical V5 files separately from SafeERC20 used-path identity; then compiled ABI/layout and true/false/no-return/revert token behavior, owner/pause/guard cases. | Ownable2Step/Ownable/Context/Pausable/ReentrancyGuard/token-ERC20-IERC20 retain file identity and sequential inherited storage behavior. SafeERC20 v5.2 is not required to equal the complete frozen v5.1 file; its safeTransfer/safeTransferFrom/_callOptionalReturn used paths retain typed failures and revert behavior. No mixed Context family, namespaced upgrade or arbitrary interface-path substitution. | WI-02-06,27-34 |
| AC69 | Traverse and record the actually resolved production and test import graphs after build. | Original 39-file map retained as provenance; actual canonical runtime graph separately includes the selected StateLibrary hashing helper and literal BSL/AGPL headers where reached. Test-only dependencies are distinguished. Every license disposition and unresolved release gate is explicit. | WI-03-05,37 |

## Test organization and validation commands

Required infrastructure:

- `contracts/protocols/strategy/weir/test/bases/TestBase_WeirVaults.sol`
- Co-located Behavior and Handler helpers under `contracts/protocols/strategy/weir/test/`, with minimal peripheral routers/tokens/hooks needed for real-manager fixtures.
- `test/foundry/spec/protocols/strategy/weir/` for ABI, lifecycle, arithmetic, inventory, access/reentrancy, and deterministic invariant suites.
- `test/foundry/fork/protocols/strategy/weir/` for the separate local fork suite.

The inspected `CraneTest` performs parent setup and factory bootstrap. The inspected `TestBase_UniswapV4EthereumMainnetFork` is a `forge-std/Test`-based Ethereum-mainnet fork fixture with a fixed mainnet block and Infura alias; it is not a hermetic manager fixture and does not establish chain4663 Weir parity. Its quote-tolerance helper is not an acceptable exact arithmetic oracle. Reuse applicable helpers only; do not import unrelated product wiring or infer that no other manager fixture exists from this narrow examination.

Choose a dedicated TestBase_WeirVaults extending CraneTest and call parent setUp first. CraneTest factory bootstrap does not turn the standalone Weir SUT into a proxy/registry product; do not add such wiring. A bare forge-std/Test-only fixture is not the selected ladder. A standalone port can be deployed as its actual contract in its TestBase under the protocol-port allowance. No proxy or registry integration is being tested. Factory helpers used by CraneTest still require fresh runtime artifacts.

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

The first command is the focused build-before-test workflow after domain edits. Full builds/tests remain broader release gates. Actual forks SHALL resolve a configured alias with vm.rpcUrl, using ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK. Existing aliases are robinhood_mainnet, robinhood_mainnet_public and robinhood_mainnet_alchemy; do not introduce WEIR_RPC_URL or hardcode a new endpoint. The first two currently resolve to the same public RPC; it confirmed chain/transaction/receipt/block data but returned historical-state-unavailable for both the old and new pin. Use robinhood_mainnet_alchemy with its configured ALCHEMY_KEY, or another verified archive-capable existing alias, and record which one was exercised. No Alchemy key was available in this authoring process, so archive code reads and fork execution remain unverified. Missing archive state/credentials must fail preflight or be recorded NOT RUN/BLOCKED with a reason, never silently pass or claim another chain is equivalent.

A concrete parity construction can use fresh exact-transfer peripheral tokens and a new hookless pool on the pinned reference manager, with the selected PoolId absent from both the reference Weir and the new copy. Deploy the copy bound to that same manager, read/align actual fee/pause/role conditions with legitimate local calls, then snapshot the entire fork state before running each branch of an identical action sequence. Restore the fork snapshot between branches rather than editing SUT storage. Compare selected-pool deltas under explicit address/role mapping; global allVaults prefixes and unrelated existing positions are not assumed equal. If reference role state prevents equivalent setup, report that precise blocked parity action instead of using a production key or fabricating equality. No funds or state are written to the real chain.

Shared-currency coverage means distinct valid pools such as (A,B) and (A,C), with A<B<C and no identical currencies inside either key. For each physical currency c, reconcile its Weir-held balance against the sum of all ordinary recorded idle claims for c plus independently tracked unassigned receipts, after unlock closes. Position assets held in the manager are separate. Do not apply this ordinary-domain equality to the explicitly hostile wrapped-idle case.

Seed new/empty worktrees from warm `out/` and `cache_forge/` under repository rules before the first future compile. Never delete warm artifacts, change FOUNDRY_TEST, add a package profile, enable viaIR, or kill a slow compiler merely for lacking progress output.

## Dependency and license disposition

### Required dependency evidence

| Dependency family | Decision for the PRD | Evidence still required before import acceptance |
|---|---|---|
| Weir L | Keep frozen protocol-specific implementation under the specified destination. | Exact source/rounding/error comparison and library tests; do not route to canonical namesake. |
| v4 manager/interface/type set | Prefer canonical real manager; account explicitly for the nested-to-top-level parameter-type relocation. | Full structural/ABI comparison, compile result, manager state-layout and hook/settlement behavior evidence. |
| v4 state/position/math/types | Prefer canonical equivalents only after checking all used semantics. | Tick extrema/rounding, FullMath overflow/revert bytes, signed packed deltas, position-key encoding, fee-growth wrapping, state slots and hashing, currency-transfer error behavior. |
| OZ owner/pause/reentrancy/SafeERC20 | Preserve the frozen versions' behavior through compatible canonical imports. | Coordinator compared the selected versioned V5 inherited files and used SafeERC20 paths as stated above. Record actual compiled layout/ABI and prove token-return handling and reachable revert parity; do not claim the whole graph is certified by a header. |
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

The examined canonical manager/Position separately carry literal header `BSL-1.1`. Canonical StateLibrary also imports BetterEfficientHashLib, whose header the coordinator read as `AGPL-3.0-or-later`; the chosen runtime graph therefore adds that declaration beyond the 39-file frozen corpus. CraneTest and the examined fork base also carry `AGPL-3.0-or-later` as test-infrastructure declarations. Do not conflate runtime-linked helper licensing with test-only licensing. These are additional repository-side declarations, not replacements for the frozen map. Preserve and disposition the actual chosen transitive graph; this PRD supplies no legal conclusion about combined distribution rights.

### Verified Business Source declarations (2026-10-29)

The restricted declaration is Business Source License 1.1 (BUSL), not GPL/AGPL. Its actual terms allow copying, modification, redistribution and non-production use subject to the license; production before conversion needs an applicable Additional Use Grant or other applicable permission. Copies must carry the license. Conversion uses the declared date or the fourth anniversary of first public distribution of the specific licensed version, whichever is earlier; do not start this clock at Weir deployment.

| Upstream declaration checked | Licensor/work | Declared change date | License after conversion |
|---|---|---|---|
| v4-core commit 36d790b1a3af, LICENSE | Uniswap Labs; Uniswap V4 Core | Earlier of 2027-06-15 and the date at v4-core-license-date.uniswap.eth | GPL-2.0-or-later |
| v4-core commit 0f17b65aa61e, licenses/BUSL_LICENSE; also checked v4.0.0 | Universal Navigation Inc.; Uniswap V4 Core | Same date/ENS condition | MIT |

Both declarations refer Additional Use Grants to v4-core-license-grants.uniswap.eth. June 15, 2027 is the stated latest calendar change date, not an established claim that an earlier ENS conversion or particular grant exists. Current ENS records, grant applicability and the specific-version first-distribution date were not established here; no present production clearance is inferred.

Version-link limitation: frozen Position.sol is byte-identical at both checked commits (SHA-256 3dc4e2ad1564fa94eddf3ff06ce9ac592c9d578ea64ca194050382da454c8fcb). Therefore matching source bytes alone cannot choose the older GPL conversion versus the newer MIT conversion. The frozen corpus omits the full license declaration/upstream commit. Canonical Crane PoolManager/Position carry literal BSL-1.1 headers without an accompanying pinned parameter block; do not silently normalize that identifier or assign one upstream declaration by guess. Record full source/distribution provenance before release. The observed AGPL header on BetterEfficientHashLib is an open-source declaration, not a BUSL expiry or proof of a licensing conflict.

Primary declarations: `https://raw.githubusercontent.com/Uniswap/v4-core/36d790b1a3af/LICENSE`; `https://raw.githubusercontent.com/Uniswap/v4-core/0f17b65aa61e/licenses/BUSL_LICENSE`; `https://raw.githubusercontent.com/Uniswap/v4-core/v4.0.0/licenses/BUSL_LICENSE`. Their fetched SHA-256 values for the first two are eadc120aa29a227a13a4e1a2b1095c33c5c6b8967070a20c8a551a6b54158bf2 and cd5241d8e1afe7098fa0f21059f7153348fdd25dbae5a8383a5f1dd2eb590321.

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


## Compiled ABI inventory appendix

Canonical signatures below are derived from the frozen metadata, not guessed hexadecimal selectors. Preserve function mutability, return types, constructor/receive and event indexing; ignore only source qualification in internalType when a permitted type-name migration leaves the ABI unchanged. Actual selectors/topics must be verified from compiler artifacts, not invented NatSpec constants.

| Function | Mutability | Returns |
|---|---|---|
| `MAX_PERF_FEE_BPS()` | view | `uint16` |
| `MIN_SHARES()` | view | `uint256` |
| `acceptOwnership()` | nonpayable | `` |
| `allVaults(uint256)` | view | `bytes32` |
| `compound((address,address,uint24,int24,address),bytes)` | nonpayable | `` |
| `createVault((address,address,uint24,int24,address))` | nonpayable | `bytes32` |
| `deposit(((address,address,uint24,int24,address),uint256,uint256,bool,uint256,address,uint256,bytes))` | payable | `uint256` |
| `owner()` | view | `address` |
| `pause()` | nonpayable | `` |
| `paused()` | view | `bool` |
| `pendingFees(bytes32)` | view | `uint256,uint256` |
| `pendingOwner()` | view | `address` |
| `perfFeeBps()` | view | `uint16` |
| `poolManager()` | view | `address` |
| `previewRedeem(bytes32,uint256)` | view | `uint256,uint256` |
| `renounceOwnership()` | nonpayable | `` |
| `setPerfFee(uint16)` | nonpayable | `` |
| `setTreasury(address)` | nonpayable | `` |
| `sharesOf(bytes32,address)` | view | `uint256` |
| `transferOwnership(address)` | nonpayable | `` |
| `transferShares(bytes32,address,uint256)` | nonpayable | `` |
| `treasury()` | view | `address` |
| `unlockCallback(bytes)` | nonpayable | `bytes` |
| `unpause()` | nonpayable | `` |
| `vault(bytes32)` | view | `((address,address,uint24,int24,address),int24,int24,uint128,uint256,uint256,uint256,uint64,bool)` |
| `vaultCount()` | view | `uint256` |
| `withdraw(((address,address,uint24,int24,address),uint256,uint8,uint256,uint256,address,uint256,bytes))` | nonpayable | `uint256,uint256` |

Constructor: `(address poolManager,address treasury,address owner)`, nonpayable. Empty-calldata receive is payable.

| Event | Indexed input positions (1-based) |
|---|---|
| `Compounded(bytes32,uint256,uint256,uint128)` | 1 |
| `Deposited(bytes32,address,uint256,uint256,uint256)` | 1, 2 |
| `OwnershipTransferStarted(address,address)` | 1, 2 |
| `OwnershipTransferred(address,address)` | 1, 2 |
| `Paused(address)` | none |
| `PerfFeeSet(uint16)` | none |
| `SharesTransferred(bytes32,address,address,uint256)` | 1, 2, 3 |
| `TreasurySet(address)` | none |
| `Unpaused(address)` | none |
| `VaultCreated(bytes32,(address,address,uint24,int24,address))` | 1 |
| `Withdrawn(bytes32,address,uint256,uint256,uint256)` | 1, 2 |

The 18 declared ABI errors are enumerated in WI-31; propagated manager/hook/token errors and panics are additional observed call outcomes, not new Weir methods.

## Council participation, resolution and evidence limits

The owner follow-up on 2026-10-29 adds the verified declaration/deployment sections, authorizes the narrow compilation refactors and updates the shared fork pin. These are owner-directed changes after the completed council round, not another council-approved draft. The existing local viaIR=false target is retained; no compiler-configuration edit is made.

All four independent originals and single advisory responses are preserved under `docs/research/weir-source-import-prd-20261029-01a18660/members/`; the immutable draft and complete disposition ledger are in coordinator/. All requested advisory turns settled. Every advisory was SUPPORT WITH CORRECTIONS; final corrections are coordinator revisions, not a second member-approved draft.

| Member | Actual resolved Native route | Advisory |
|---|---|---|
| astra | `chatgpt-subscription/gpt-6-astra:high` | SUPPORT WITH CORRECTIONS |
| grok | `xai/grok-4.7:xhigh` | SUPPORT WITH CORRECTIONS |
| minimax | `minimax/MiniMax-M3` | SUPPORT WITH CORRECTIONS |
| kimi | `kimi-coding/k3.1-pro:high` | SUPPORT WITH CORRECTIONS |

Common outcome: faithful three-file import, preservation/characterization rather than remediation, real-manager tests, no silent ABI/math/layout change. Original disagreement on dependency routes and safety expectations is preserved, not described as unanimous agreement: the final selects the existing versioned V5 family; rejects a 5.6.1 upgrade, second-return fee basis, cast-revert assumptions, universal idle/output guarantees and missing-endpoint claim; and makes inventory, rollback and callback preconditions precise.

The final rejects impossible/wrong advisory proposals as well: fee components are int128 so cannot exceed 2^128-1; zero-supply preview returns zero before division; shared currency is across pools; local fork tests need no production owner private key. The final retains 37 WI requirements and 69 AC rows, not a nonexistent AC70. The ledger maps every material concern to its disposition.

Actual Native process ancestry/task IDs, delivery recovery and process deviations are in RUN.md. MiniMax's original used harness write despite the assigned apply_patch-or-inline boundary; its advisory returned inline correctly. Grok's original needed one same-task delivery-format repair; its complete advisory was recovered without another model turn. These limits are preserved rather than claiming uniform tool compliance or byte-level attestation of every member read. No route substitution or further advisory round.

This PRD does not implement the import or certify compiler success, actual resolved runtime licensing, manager parity, economic safety, gas, deployment readiness or legal permission. No source implementation, Forge test/build, transaction, wallet operation or deployment was performed in this authoring task. All commands and test results remain future implementation gates.
