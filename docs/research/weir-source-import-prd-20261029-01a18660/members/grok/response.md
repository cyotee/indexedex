I read this as a format repair to re-emit the retained original verbatim. I'll stop when that exact contribution is in this response.

# WeirVaults source-import PRD contribution — Grok

Identity: independent Grok council author, `xai/grok-4.7:xhigh`, initial original only. This contribution does not replace the coordinator's final PRD and does not authorize implementation, deployment, or a dependency waiver.

Disposition of this pass: complete contribution for coordinator synthesis. No peer original was read. No production source was copied. No code, config, or other PRD was edited.

## 1. Question and targets

Produce the requirements for a faithful baseline import of the verified WeirVaults sources into `contracts/protocols/strategy/weir/`, plus tests that prove the copy behaves as the frozen source behaves, including awkward and unsafe behavior. The eventual coordinator file is `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_PRD.md`. This author does not write that file.

Three classes, used on every requirement:

- Class F: fidelity. The copy must do this, including awkward behavior.
- Class L: upstream limitation. Document it and characterize it with an executable test where feasible. Do not repair it in this import.
- Class X: excluded improvement. Not a requirement. A failing test that demands it is an invalid test.

## 2. Evidence actually read

Frozen domain files, read completely, SHA-256 of the file bytes computed in-process (not a shell `shasum`). All three match the brief and `manifest.files`:

| Frozen path | Lines read | SHA-256 |
|---|---|---|
| `source-snapshot/sources/src/WeirVaults.sol.txt` | 1–427 | `23de61301729d2950ba110e15cdce5e383fc4e5aacb0b906ee845390bd0e0180` |
| `source-snapshot/sources/src/base/WeirBase.sol.txt` | 1–91 | `f14c1ef0fe9913f0d99e872f108ab3d7b84f44050d449d2b72049ad20a08b498` |
| `source-snapshot/sources/src/libraries/LiquidityAmounts.sol.txt` | 1–76 | `f482702fecb1b6dc5c82b9ad918a4f991ce5b8c4d0c1144b448c25fbaad3093d` |

`source-snapshot/manifest.json` was parsed in full: retrieval record, compiler settings, metadata ABI, and all 39 `files[]` plus `metadata.sources` license/keccak rows. `brief.md` and `RUN.md` were read completely. `RUN.md` is operational; it contains no peer original.

Also read for inherited behavior and dependency claims, not as production sources to copy: frozen `Ownable.sol.txt`, `Ownable2Step.sol.txt`, `Pausable.sol.txt`, `ReentrancyGuard.sol.txt`, `SafeERC20.sol.txt` (through the revert path), `IUnlockCallback.sol.txt`, `BalanceDelta.sol.txt`, `PoolKey.sol.txt`, `PoolId.sol.txt`, `FixedPoint96.sol.txt`, `FixedPoint128.sol.txt`, and the executable portions of frozen `Currency.sol.txt`, `IPoolManager.sol.txt`, `StateLibrary.sol.txt`, `TickMath.sol.txt`, and `Position.sol.txt` (`calculatePositionKey`, license, `State`).

Repository context actually read before compatibility claims: `foundry.toml` profile law, `remappings.txt`, `.github/ASSISTANT_TESTS.md` opening rules, crane `PoolManager.sol` unlock/constructor, crane `IPoolManager.sol` / `PoolOperation.sol` / `StateLibrary.sol` / `TickMath.sol` / `LiquidityAmounts.sol` used symbols, crane `Pausable.sol` / `ReentrancyGuard.sol` / `SafeERC20.sol` / `Ownable.sol` / `Ownable2Step.sol` / `Context.sol`, crane `FixedPoint96.sol` and `FixedPoint128.sol` constants, and the hermetic `new PoolManager(...)` sites in crane `Deployers.sol` and `UniversalRouter_VendorSmoke.t.sol`. `TestBase_UniswapV4Fork.sol` was read far enough to see it is an Ethereum-mainnet fork base at block 21_900_000, not a chain-4663 or hermetic base.

Not read: peer originals, peer feedback, upstream git, upstream tests, any audit, Sourcify over the network. No Forge, Git, shell, install, deploy, or wallet operation was run. Selector values below were computed in-process with `ethers.id` (keccak256 of the canonical signature, first 4 bytes). They are signature predictions, not compiler output. Tests must assert the compiled artifact.

Provenance limit, normative: the pin is the Sourcify match retrieved by the coordinator on 2026-10-29, HTTP 200, `verifiedAt` `2026-09-30T03:34:14Z`, chain `4663`, address `0x9bb6A517a8dB43a55e4A873C0313D7bFADd70110`, creation and runtime match. Manifest `retrievedAt` is `2026-10-29T18:00:30.870Z`. That record is registry metadata. It is not an independent bytecode reproduction, audit, live transaction trace, or git revision. No upstream repository, test suite, or audit was supplied. Do not invent one.

Upstream compilation, not an acceptance target: solc `0.8.26+commit.8a97fa7a`, optimizer 800, Cancun, `viaIR=true`, `bytecodeHash=none`, target `src/WeirVaults.sol:WeirVaults`. IndexedEx default and fork profiles stay solc `0.8.35`, optimizer runs 1, `via_ir=false`. Do not change `foundry.toml`, `remappings.txt`, or those settings. Exact deployed bytecode equality is not an acceptance criterion.

## 3. Import scope

R-01 (F). Copy only these three domain sources, preserving license headers and notices byte-for-byte, into:

- `contracts/protocols/strategy/weir/WeirVaults.sol`
- `contracts/protocols/strategy/weir/base/WeirBase.sol`
- `contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol`

Do not copy the other 36 frozen files into the repo. Do not compile the `.sol.txt` research snapshots. Do not add a second production tree under `external/`.

R-02 (F). The only source edits allowed without a separate recorded decision are:

1. Import-path rewrites that resolve to a dependency this PRD has accepted.
2. Replacing the type qualifications `IPoolManager.ModifyLiquidityParams` and `IPoolManager.SwapParams` with the field-identical structs crane already declares in `lib/crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol`.

Call arguments, field order, and field types stay identical. No other identifier, comment, constant, formula, visibility, mutability, or modifier change is allowed. A stack-too-deep split is not preauthorized. If the faithful text does not compile under the default profile, stop and record the compiler error. Do not enable `via_ir`. Do not raise optimizer runs. A later behavior-preserving frame split requires its own recorded decision and a differential test; it is not part of the default import.

R-03 (X). Do not implement, and do not write a test that fails the faithful source for: an ERC20 or ERC4626 wrapper, a rate provider, a Diamond or Standard Exchange conversion, registry integration, fee removal, dead-share removal, an already-unlocked fast path, a strict single-token exit, a new simulator, gas optimization, economic repair, fee-on-transfer or rebasing support, `previewRedeem == withdraw`, NAV safety, CREATE3, proxy, or package-registry wiring. This contract is a standalone upstream contract. Deploy it with `new WeirVaults(poolManager, treasury, owner)`.

R-04 (F). Tests live at `test/foundry/spec/protocols/strategy/weir/`. Test infrastructure lives with the protocol: `contracts/protocols/strategy/weir/test/bases/TestBase_WeirVaults.sol`, plus a Behavior library and a Handler beside it. Fork tests, if attempted, live under `test/foundry/fork/protocols/strategy/weir/` and are not part of hermetic CI. `TestBase_WeirVaults` may extend `CraneTest`. It must not extend a DETF, Wings, Pons, registry, or `TestBase_UniswapV4Fork` fixture. Those pull unrelated product wiring or the wrong chain.

R-05 (F). Hermetic tests deploy the real crane `PoolManager` with `new PoolManager(address(this))`, the same constructor shape already used by `UniversalRouter_VendorSmoke.t.sol` and crane `Deployers.sol`. No mock, etch, `vm.mockCall`, `vm.store`, or subclass replacement of WeirVaults, WeirBase, LiquidityAmounts, or the manager. Peripheral tokens, receivers, and hooks may be hostile. A hook must be a real deployed hook whose address satisfies the manager's hook-address check, using the existing crane HookMiner pattern. Do not etch a hook flag onto an arbitrary address.

## 4. Dependency decision

Current crane copies are not byte-identical to the frozen dependencies. Hash inequality alone is not a behavior finding, because crane rewrites imports. These findings are from the executable text.

Accepted as import-path equivalent, after an import-line-normalized diff in this pass:

- `Ownable` v5.0.0. Sequential `address private _owner`. Constructor reverts `OwnableInvalidOwner(address(0))` (`0x1e4fbdf7`). `renounceOwnership` is present and sets owner to 0.
- `Ownable2Step` v5.1.0. Sequential `address private _pendingOwner`. `transferOwnership` does not change owner; `newOwner == address(0)` cancels a pending transfer; `acceptOwnership` reverts `OwnableUnauthorizedAccount` (`0x118cdaa7`) for any other caller. `_transferOwnership` clears the pending owner, so renounce clears it too.
- `Context` v5.0.1. Byte-identical to the frozen file, including imports.

Rejected as silent substitutions. Binding to these fails the import:

- Crane `Pausable` is v4.7.0. It reverts with the strings `Pausable: paused` and `Pausable: not paused`. The frozen file is v5.0.0 and reverts `EnforcedPause()` (`0xd93c0665`) and `ExpectedPause()` (`0x8dfc202b`). The frozen ABI includes those custom errors.
- Crane `ReentrancyGuard` is v5.5.0 and stores status at ERC-7201 slot `0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00`. The frozen file is v5.1.0 and uses a sequential `uint256 private _status`, with `NOT_ENTERED = 1` and `ENTERED = 2`. The revert name matches; the storage layout does not. Binding it moves `treasury` and `perfFeeBps`.
- Crane `SafeERC20` is v4.9.3. Failure reverts with `SafeERC20: low-level call failed` or `SafeERC20: ERC20 operation did not succeed`. Frozen v5.1.0 bubbles the token revert and otherwise reverts `SafeERC20FailedOperation(address)` (`0x5274afe7`). The frozen ABI includes that error.
- Crane `LiquidityAmounts` is MIT, uses `SafeCast`, and does not expose `getAmountsForLiquidity` / `getAmount0ForLiquidity`. It is a different library. Do not bind Weir to it. Weir's GPL library is part of the import.

Conditionally usable, not yet body-proved:

- Crane v4 `IPoolManager` has `unlock`, `modifyLiquidity(PoolKey, ModifyLiquidityParams, bytes) returns (BalanceDelta, BalanceDelta)`, `swap`, `sync`, `take`, `settle`, `AlreadyUnlocked` (`0x5090d6c6`), `CurrencyNotSettled` (`0x5212cba1`), and `ManagerLocked` (`0x54e3ca0d`). The structs are not declared inside the interface; they are imported from `PoolOperation.sol`. Field order matches the frozen interface: `tickLower`, `tickUpper`, `liquidityDelta`, `salt`; and `zeroForOne`, `amountSpecified`, `sqrtPriceLimitX96`. This is why R-02.2 exists. It is a name-resolution edit, not a behavior edit, only while those fields stay identical.
- Crane `PoolManager.unlock` reverts `AlreadyUnlocked` if locked-open, calls `IUnlockCallback(msg.sender).unlockCallback(data)`, then reverts `CurrencyNotSettled` if `NonzeroDeltaCount != 0`. That is the real manager behavior hermetic tests must use. It is a port ("compatibility with Solidity 0.8.30"), not the PoolManager bytecode that chain 4663 used. The frozen snapshot does not contain `PoolManager.sol`. Hermetic tests prove the copy against this port. They do not prove chain-4663 manager parity.
- `StateLibrary.getSlot0` returns `(uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee)`. `getPositionInfo(manager, id, owner, tickLower, tickUpper, salt)` returns `(uint128, uint256, uint256)` and uses `Position.calculatePositionKey`. `getFeeGrowthInside(manager, id, tickLower, tickUpper)` returns two `uint256`s. Those arities match the calls in `WeirVaults.sol.txt` lines 113, 127–128, and 131. A full body diff against the frozen library is still a release check, because the file hashes differ.
- `TickMath.minUsableTick` / `maxUsableTick` match the frozen formulas, including toward-zero division: `(MIN_TICK / tickSpacing) * tickSpacing` and the max equivalent. `MIN_SQRT_PRICE = 4295128739`, `MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342`, `MIN_TICK = -887272`, `MAX_TICK = 887272`.
- `FixedPoint96.Q96` and `RESOLUTION`, and `FixedPoint128.Q128`, match the frozen constants. Crane `FullMath.mulDiv(uint256,uint256,uint256)` exists, but its body was not byte-compared. LiquidityAmounts and the zap heuristic depend on it. Binding is blocked until a body-level diff, or an independent vector set, shows identical revert and rounding to the frozen `FullMath.sol.txt`.

R-06 (F). Domain imports may resolve only to the accepted or body-proved targets above. `remappings.txt` and `foundry.toml` are not edited. There is no `@openzeppelin/contracts/` or `v4-core/` remapping today, so the original import strings will not compile unchanged. Rewrite them to existing `@crane/...` paths. Do not add a remap to make the old strings work.

R-07 (F). Do not bind Pausable, ReentrancyGuard, or SafeERC20 to the current crane files. Do not vendor a private OZ or v4 tree under `weir/` or anywhere else. Do not upgrade crane's shared OZ as part of this import. Those three frozen files are the semantic authority for pause errors, reentrancy storage, and transfer failure. Until a separately recorded decision places equivalent sources on an already-resolvable path, the Solidity import is not releasable. Specifying the tests is still required. Weakening a test so the crane v4.7/v5.5/v4.9 files pass is a failed import, not a waiver.

R-08 (X). A waiver that accepts crane's string pause errors, namespaced reentrancy slot, or string SafeERC20 errors is a behavior change. This PRD does not grant it.

## 5. License map and release gate

R-09 (F). Preserve every copied header. Do not scrub, relicense, or label the tree MIT. Do not make a clean-room claim. No legal clearance is asserted here.

Manifest inventory, 39 files. License counts: MIT 37, BUSL-1.1 1, GPL-2.0-or-later 1. Metadata keccak256 is the Sourcify content id; SHA-256 is `manifest.files`.

| License | Metadata keccak256 | SHA-256 | Path |
|---|---|---|---|
| MIT | `0x559c471af50dcb585e2ac8edb35ffa57db8f6dfde4eb0e5dcccdd76569a510ff` | `23de61301729d2950ba110e15cdce5e383fc4e5aacb0b906ee845390bd0e0180` | `src/WeirVaults.sol` |
| MIT | `0xb9b5a762941b490e82ad9b87ca3113829f3f4608fa6c368aec0d0e8e51b6fa2e` | `f14c1ef0fe9913f0d99e872f108ab3d7b84f44050d449d2b72049ad20a08b498` | `src/base/WeirBase.sol` |
| GPL-2.0-or-later | `0x5ddd94b27fbe46b0baf53424594f1699daee50733e5aff6e0c9580fdf318e71a` | `f482702fecb1b6dc5c82b9ad918a4f991ce5b8c4d0c1144b448c25fbaad3093d` | `src/libraries/LiquidityAmounts.sol` |
| MIT | `0xff6d0bb2e285473e5311d9d3caacb525ae3538a80758c10649a4d61029b017bb` | `38578bd71c0a909840e67202db527cc6b4e6b437e0f39f0c909da32c1e30cb81` | `lib/openzeppelin-contracts/contracts/access/Ownable.sol` |
| MIT | `0xdcad8898fda432696597752e8ec361b87d85c82cb258115427af006dacf7128c` | `c75345d7b9feef17ae29f2a800ca2f65f8021cf80436a41d6ec00f57f5180f36` | `lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol` |
| MIT | `0x493033a8d1b176a037b2cc6a04dad01a5c157722049bbecf632ca876224dd4b2` | `847fda5460fee70f56f4200f59b82ae622bb03c79c77e67af010e31b7e2cc5b6` | `lib/openzeppelin-contracts/contracts/utils/Context.sol` |
| MIT | `0xb2e5f50762c27fb4b123e3619c3c02bdcba5e515309382e5bfb6f7d6486510bd` | `6543160582b3c0319a180f31660faf6ba0a8444acbdb03357c09790a96256835` | `lib/openzeppelin-contracts/contracts/utils/Pausable.sol` |
| MIT | `0x11a5a79827df29e915a12740caf62fe21ebe27c08c9ae3e09abe9ee3ba3866d3` | `32fbb1c908ec1b4de85cc1bb10091aebd5816ffe80dfdd5ca5e084fbea67a462` | `lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol` |
| MIT | `0xe06a3f08a987af6ad2e1c1e774405d4fe08f1694b67517438b467cecf0da0ef7` | `30edf7394bab78d48b7db3a059248e1ea7c2c77d2ec0e37a13bb91415aafbe5a` | `lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol` |
| MIT | `0xca2ae13e0610f6a99238dd00b97bd786bc92732dae6d6b9d61f573ec51018310` | `d67b0f3d9302b2ff7cec76776fc2c1f3686082287441c15c6871c0086a8a4f74` | `lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol` |
| MIT | `0x8228692ef1ccb4cfe5b7cc58324cadd06045e10e386185f9e4d45173d6d6c633` | `8228692ef1ccb4cfe5b7cc58324cadd06045e10e386185f9e4d45173d6d6c633` | `lib/openzeppelin-contracts/contracts/utils/Address.sol` |
| MIT | `0x6afa713bfd42cf0f7656efa91201007ac465e42049d7de1d50753a373648c123` | `0704b9d6c032cca8512a3bc3f30f49f86f1f03102d2896a3d23e794b82efea66` | `lib/openzeppelin-contracts/contracts/utils/Errors.sol` |
| MIT | `0x9b6b3e7803bc5f2f8cd7ad57db8ac1def61a9930a5a3107df4882e028a9605d7` | `54f427f63724d9760211dfa9e0cc5d79d86c0724becd81f8e638e2e27b0e2669` | `lib/openzeppelin-contracts/contracts/interfaces/IERC1363.sol` |
| MIT | `0xce41876e78d1badc0512229b4d14e4daf83bc1003d7f83978d18e0e56f965b9c` | `cb42f0b4d269ba8ef2629c176a7f99bf4fb50837c92f45596b54822b26e3df4b` | `lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol` |
| MIT | `0xde7e9fd9aee8d4f40772f96bb3b58836cbc6dfc0227014a061947f8821ea9724` | `49abfb8fa26e3f1715fe05948a96e3762b805bd4a77d103eb40ba96b1acfa144` | `lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol` |
| MIT | `0x79796192ec90263f21b464d5bc90b777a525971d3de8232be80d9c4f9fb353b8` | `7c5c3f98ab876991e7dd34b84d41137e836306eb9f36f6386a631f5be3f5d6d4` | `lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol` |
| MIT | `0x3534f00531038e77ab8a7fc4d0a6e0993ee53fb7a396b1324ad917318ea46cea` | `173a3f93aeb39373271ebe2bfb961d824922378a39b7a5e983acbb1c122d296e` | `lib/v4-core/src/interfaces/IPoolManager.sol` |
| MIT | `0x58c82f2bd9d7c097ed09bd0991fedc403b0ec270eb3d0158bfb095c06a03d719` | `2e4a514730654da2e08a82eff5b3eabae12dc1c6198951396e1d466d4c0e223e` | `lib/v4-core/src/interfaces/callback/IUnlockCallback.sol` |
| MIT | `0x4c9571aed0c2b6ef11832545554fc11ffdb03746daaf5c73683c00600bfc7ec0` | `aca1db9898026d9a4b8740752fb0dbfc6a55e4bede6a949c6af4e07d626f6900` | `lib/v4-core/src/interfaces/IHooks.sol` |
| MIT | `0x32a666e588a2f66334430357bb1e2424fe7eebeb98a3364b1dd16eb6ccca9848` | `807d68adea106ec2aa51a8009155de09ebfe09e1ee7053d5a5ae448d7e840654` | `lib/v4-core/src/interfaces/IProtocolFees.sol` |
| MIT | `0x80b53ca4907d6f0088c3b931f2b72cad1dc4615a95094d96bd0fb8dff8d5ba43` | `9421ef4ba198d94058cd9a4c9fd2d663c61fc682f7dafa449a873456853f0025` | `lib/v4-core/src/interfaces/IExtsload.sol` |
| MIT | `0xc6b68283ebd8d1c789df536756726eed51c589134bb20821b236a0d22a135937` | `c21643d2c7f48d2d2407438a64a3ff0f376324cf6a0c62608977713652308c9e` | `lib/v4-core/src/interfaces/IExttload.sol` |
| MIT | `0xa586f345739e52b0488a0fe40b6e375cce67fdd25758408b0efcb5133ad96a48` | `1cd65496c829036bc6aee67bc71363ab5fb6989c65e793087d0e1e2379f7d7d8` | `lib/v4-core/src/interfaces/external/IERC6909Claims.sol` |
| MIT | `0xeccadf1bf69ba2eb51f2fe4fa511bc7bb05bbd6b9f9a3cb8e5d83d9582613e0f` | `5e966a2d22b3b234a56af4b17e36bf7be90f9b29b1ddb6a15bfefc0b6dab4282` | `lib/v4-core/src/interfaces/external/IERC20Minimal.sol` |
| MIT | `0x96db333ee126a841dd959e38e452cc59d73583cb0437a1d48b2052e33a74f952` | `eebdbc1b6e431072ce5521b9e1b603d43831e3b6e062743e6665e070d5cf8a1a` | `lib/v4-core/src/libraries/StateLibrary.sol` |
| BUSL-1.1 | `0xddab2a831f1befb6abf5567e77c4582169ca8156cf69eb4f22d8e87f7226a3f9` | `3dc4e2ad1564fa94eddf3ff06ce9ac592c9d578ea64ca194050382da454c8fcb` | `lib/v4-core/src/libraries/Position.sol` |
| MIT | `0x4e1a11e154eb06106cb1c4598f06cca5f5ca16eaa33494ba2f0e74981123eca8` | `272d4f6d3ff9ae33596ebcdb84a71a3c2d4542ae8fb5c88ddf1aca8043f5d06b` | `lib/v4-core/src/libraries/TickMath.sol` |
| MIT | `0x4fc73a00817193fd3cac1cc03d8167d21af97d75f1815a070ee31a90c702b4c2` | `a9607255a6fd604d9c92f6b7416811c38b9d86e5dfdb0c345a494ebd35f7a4a3` | `lib/v4-core/src/libraries/FullMath.sol` |
| MIT | `0xef5c3fd41aee26bb12aa1c32873cfee88e67eddfe7c2b32283786265ac669741` | `66ee26d4fb3ac639124bdfa27d3256d196970997fa127c09e9bf7154e30d4590` | `lib/v4-core/src/libraries/FixedPoint96.sol` |
| MIT | `0xad236e10853f4b4b20a35a9bb52b857c4fc79874846b7e444e06ead7f2630542` | `1ca2f55160697b73bd66fd27c8724d79a57108121ce1e8a0ab8b79f38bb58fbb` | `lib/v4-core/src/libraries/FixedPoint128.sol` |
| MIT | `0x51b9be4f5c4fd3e80cbc9631a65244a2eb2be250b6b7f128a2035080e18aee8d` | `e8a45eb3d57f9427fc47bbb2543c1a6a5f394113b378123ac7ca9f113a7502b4` | `lib/v4-core/src/libraries/BitMath.sol` |
| MIT | `0x111ed3031b6990c80a93ae35dde6b6ac0b7e6af471388fdd7461e91edda9b7de` | `9d3dbe6b742cb1ac30f57df89d879ade9649389de1165fc637114bd062d39fca` | `lib/v4-core/src/libraries/CustomRevert.sol` |
| MIT | `0x42c4a24f996a14d358be397b71f7ec9d7daf666aaec78002c63315a6ee67aa86` | `c1a815a41607be5b4c86ca588a951f368156da8ee21bdfc18b5d51b58a0f27be` | `lib/v4-core/src/libraries/SafeCast.sol` |
| MIT | `0x000ef2eadcc1eb7b2c18a77655f94e76e0e860f605783484657ef65fd6eda353` | `67a39e58732340af4870342ba9230691f35501d89ed8725ca1b338deaa0eb26a` | `lib/v4-core/src/libraries/LiquidityMath.sol` |
| MIT | `0xf89856e0580d7a4856d3187a76858377ccee9d59702d230c338d84388221b786` | `99e1afe285b5c614ebc9586ab5196db9d24a63fd924a449f5d99f490a6a6d6a9` | `lib/v4-core/src/types/PoolKey.sol` |
| MIT | `0x308311916ea0f5c2fd878b6a2751eb223d170a69e33f601fae56dfe3c5d392af` | `548424ac50ad58212545da70207283fb8990731578c115c85d5acbcb0e1d3c9f` | `lib/v4-core/src/types/PoolId.sol` |
| MIT | `0x4a0b84b282577ff6f8acf13ec9f4d32dbb9348748b49611d00e68bee96609c93` | `ba6726fd24fbc66848208dfbb2899116c10729c505e6e5552316ac2444f1dfc3` | `lib/v4-core/src/types/Currency.sol` |
| MIT | `0xa719c8fe51e0a9524280178f19f6851bcc3b3b60e73618f3d60905d35ae5569f` | `320d9c13dec135c3903729e66d3a1040fe86d537a7ee53728915012ca183af32` | `lib/v4-core/src/types/BalanceDelta.sol` |
| MIT | `0x2a774312d91285313d569da1a718c909655da5432310417692097a1d4dc83a78` | `6aee06f1553e879f5909e8f4c0eac26ec23dd4821a7e56e4d5077db39a227e12` | `lib/v4-core/src/types/BeforeSwapDelta.sol` |

R-10 (L). `LiquidityAmounts` is GPL-2.0-or-later and its functions are `internal`, so they are compiled into `WeirVaults`. `StateLibrary.getPositionInfo` calls `Position.calculatePositionKey`, and `pendingFees` calls `getPositionInfo`, so BUSL-1.1 Position code is transitively inlined if that library is linked as internal code. Crane's Position header says `BSL-1.1`, not `BUSL-1.1`; that identifier mismatch is a crane fact, not something this import edits. This contribution does not conclude that the combined artifact is or is not a GPL or BUSL work. It does require a recorded license disposition before any copied-source release. Document authoring is not blocked.

## 6. External surface

R-11 (F). The compiled ABI includes exactly the frozen metadata functions, errors, and events, plus no new ones. Predicted selectors are checks against the artifact, not a substitute for it.

Functions: `MAX_PERF_FEE_BPS()` view, `MIN_SHARES()` view, `acceptOwnership()`, `allVaults(uint256)` view, `compound(PoolKey,bytes)`, `createVault(PoolKey) returns (PoolId)`, `deposit(DepositParams)` payable returns `(uint256)`, `owner()` view, `pause()`, `paused()` view, `pendingFees(PoolId) returns (uint256,uint256)`, `pendingOwner()` view, `perfFeeBps()` view, `poolManager()` view, `previewRedeem(PoolId,uint256) returns (uint256,uint256)`, `renounceOwnership()`, `setPerfFee(uint16)`, `setTreasury(address)`, `sharesOf(PoolId,address)` view, `transferOwnership(address)`, `transferShares(PoolId,address,uint256)`, `treasury()` view, `unlockCallback(bytes) returns (bytes)`, `unpause()`, `vault(PoolId)` view, `vaultCount()` view, `withdraw(WithdrawParams) returns (uint256,uint256)`.

`deposit` selector prediction `0x2d0b9f3c`. `withdraw` prediction `0xd27c6f90`. `compound` prediction `0x4e2adfb5`. `createVault` prediction `0x5e72a0ab`. `transferShares` prediction `0x196bcaa1`. `unlockCallback` prediction `0x91dd7346`. `previewRedeem` prediction `0x9c11d3e8`. `pendingFees` prediction `0x01785603`.

Only `deposit` and `receive` accept value. A nonzero `msg.value` to any other entry reverts with the compiler's nonpayable rejection and changes nothing. Do not require a Weir custom error for that rejection.

There is no `name`, `symbol`, `decimals`, `allowance`, `approve`, `transfer`, `transferFrom`, or `totalSupply`. Do not add them. Do not write ERC20 compliance tests.

Struct and enum layouts are normative.

`Vault` return order: `key`, `tickLower`, `tickUpper`, `liquidity`, `totalShares`, `idle0`, `idle1`, `lastCompound`, `exists`. Locators: `WeirVaults.sol.txt` lines 29–39.

`DepositParams`: `key`, `amount0`, `amount1`, `zap`, `minShares`, `recipient`, `deadline`, `hookData`. Lines 41–50.

`WithdrawParams`: `key`, `shares`, `zapTo`, `min0`, `min1`, `recipient`, `deadline`, `hookData`. Lines 52–61.

`Action`: `DEPOSIT = 0`, `WITHDRAW = 1`, `COMPOUND = 2`. Lines 63–67. Callback encoding uses this order. Do not reorder.

`PoolKey` memory encoding, the encoding `PoolIdLibrary.toId` hashes over `0xa0` bytes: `currency0`, `currency1`, `fee`, `tickSpacing`, `hooks`. Storage packing of `Vault.key` is a different layout and must still `toId` back to the vault id.

## 7. Inheritance, storage, and admin

R-12 (F). Linearization used for this derivation, most-derived first, Solidity rightmost-base-is-more-derived: `WeirVaults`, `ReentrancyGuard`, `Pausable`, `Ownable2Step`, `Ownable`, `Context`, `WeirBase`, `IUnlockCallback`. Storage is the reverse, skipping empty bases. This derivation was not confirmed with `solc --storage-layout`. The compiler layout of the copied artifact is the fidelity record. If it disagrees with the table, keep the source and record the compiler layout. Do not reshuffle inheritance to match this table.

Derived sequential layout, frozen OZ only:

| Slot | Contents |
|---|---|
| 0 | `Ownable._owner` at bytes 0–19 |
| 1 | `Ownable2Step._pendingOwner` at bytes 0–19, `Pausable._paused` at byte 20 |
| 2 | `ReentrancyGuard._status` |
| 3 | `treasury` at bytes 0–19, `perfFeeBps` at bytes 20–21 |
| 4 | `_vaults` |
| 5 | `sharesOf` |
| 6 | `allVaults` |

`poolManager` is immutable, not a storage slot. `perfFeeBps` initializer is 500, stored, not a constant. `MAX_PERF_FEE_BPS` is 1000. `MIN_SHARES` is 1000. `BPS` is internal 10000.

A namespaced reentrancy slot, or `treasury` at slot 0, fails R-07.

Inside each `_vaults` value, packed from slot `keccak256(abi.encode(id, 4))`: currency0; currency1; `fee` + `tickSpacing` + `hooks`; `tickLower` + `tickUpper` + `liquidity`; `totalShares`; `idle0`; `idle1`; `lastCompound` + `exists`. Confirm with the compiler. The normative behavioral requirement is the field set and the `toId` round trip, not a hand-derived offset if the compiler disagrees.

R-13 (F). Constructor (`WeirVaults.sol.txt` lines 93–97; `WeirBase.sol.txt` lines 33–35; frozen `Ownable.sol.txt` lines 38–43). `poolManager` is stored even if it is `address(0)` or an EOA. There is no manager zero-check; do not add one. `treasury == address(0)` reverts `ZeroAddress` (`0xd92e233d`) and does not deploy. `owner == address(0)` reverts `OwnableInvalidOwner(address(0))` and does not deploy. A nonzero owner becomes owner, pending owner is 0, `perfFeeBps` is 500, `paused` is false, `vaultCount` is 0.

R-14 (F). Ownership is Ownable2Step, not a one-step transfer. `transferOwnership` emits `OwnershipTransferStarted` and leaves `owner()` unchanged. `acceptOwnership` by the pending account emits `OwnershipTransferred` and clears pending. A second `transferOwnership`, including to `address(0)`, replaces or cancels the pending transfer. `renounceOwnership` sets owner to 0 and clears pending. After renounce, `setTreasury`, `setPerfFee`, `pause`, `unpause`, and `transferOwnership` revert `OwnableUnauthorizedAccount`. `deposit`, `withdraw`, `compound`, `createVault`, `transferShares`, and views still work. Do not disable renounce.

R-15 (F). `setTreasury` (`lines 388–392`) is `onlyOwner`, rejects 0, emits `TreasurySet`, and does not sweep already-accounted idle or pending fees. The next harvest sends the cut to the new treasury. `setPerfFee` (`lines 394–398`) rejects `bps > 1000` with `FeeTooHigh` (`0xcd4e6167`), accepts 0 and 1000, and emits `PerfFeeSet` even when the value is unchanged. The new rate applies to the next cut, not retroactively to `pendingFees`.

R-16 (F). `pause` / `unpause` (`lines 400–406`) are `onlyOwner`. Double pause reverts `EnforcedPause`. Double unpause reverts `ExpectedPause`. Events are `Paused(msg.sender)` and `Unpaused(msg.sender)`. Only `deposit` has `whenNotPaused`. `createVault`, `withdraw`, `compound`, `transferShares`, views, and admin setters work while paused. Do not extend the pause.

## 8. Share token, position, and views

R-17 (F). Shares are a per-`PoolId` mapping, not a token. `transferShares` (`lines 200–205`) is unguarded, has no pause check, no deadline, no allowance, and no vault-exists check. It reverts `ZeroAddress` for `to == address(0)` before the debit. A zero amount is allowed and emits `SharesTransferred`. A transfer larger than `sharesOf[from]` panics `Panic(uint256)` code `0x11`. Self-transfer of an owned amount succeeds and emits. Shares on pool A do not move pool B.

R-18 (F). One vault per pool id. The position owner is the vault. Ticks are `TickMath.minUsableTick(key.tickSpacing)` and `maxUsableTick(key.tickSpacing)`, using toward-zero division, not floor division. Salt is always `bytes32(0)`. A same-range position with a nonzero salt is not the vault's position and is not counted. `allVaults` is append-only. There is no removal. `allVaults(i)` out of range panics `0x32`. `vault(unknown)` returns a zero struct and does not revert. `sharesOf(unknown, anyone)` is 0.

R-19 (F). `createVault` (`lines 140–151`) is public and permissionless. It reverts `VaultExists` (`0x4239717c`) if `exists`. It reverts Weir's `PoolNotInitialized` (`0x486aa307`) if `getSlot0` returns `sqrtPriceX96 == 0`. It does not check hook permissions, fee tier, or dynamic-fee bit `0x800000`. A dynamic-fee pool can have a vault. The stored key is the caller's key. `deposit` auto-creates; `withdraw` and `compound` do not.

The manager also defines `PoolNotInitialized()`. The selector is the same. Tests must distinguish by which call reverts, not by selector alone.

R-20 (F). `previewRedeem` (`lines 110–121`) is not a redemption quote. If `totalShares == 0` it returns `(0, 0)` without calling the manager, even if `shares > 0`. Otherwise:

```
liq = uint128(liquidity * shares / totalShares)
amounts = LiquidityAmounts.getAmountsForLiquidity(slot0.sqrtPrice, tickLower, tickUpper, liq)
amount0 += idle0 * shares / totalShares
amount1 += idle1 * shares / totalShares
```

All divisions round down. The quote uses spot `slot0`, not a TWAP. It excludes pending fees, the performance fee, the zap, and the two-unit cushion. It has no `exists` check. `uint256(liquidity) * shares` can overflow, and the `uint128` cast can panic if `shares` is large enough. That view revert is source behavior. Do not assert `previewRedeem == withdraw`, `previewRedeem == post-compound redeem`, or `previewRedeem == a zapped exit`.

R-21 (F). `pendingFees` (`lines 124–135`) returns `(0, 0)` when `v.liquidity == 0`, even if a manager position exists. Otherwise it reads the manager position at `(address(this), tickLower, tickUpper, bytes32(0))`, not `v.liquidity`, then:

```
fees = mulDiv(feeGrowthInside - feeGrowthInsideLast, positionLiquidity, Q128)
```

inside an `unchecked` subtraction. The result is gross of the performance fee and excludes idle. It is not an amount `compound` will add to liquidity. If fee growth is not monotonic, the unchecked subtraction wraps. That is a limitation to characterize only if a real manager state can produce it. Do not add a checked subtraction as a repair.

## 9. Deposit, withdraw, compound

R-22 (F). `deposit` (`lines 153–174`) order is normative. Modifiers run `whenNotPaused`, then `nonReentrant`, then `checkDeadline`. Body order:

1. Reject `recipient == address(0)` with `ZeroAddress`.
2. `id = key.toId()`. If no vault, `createVault(key)`.
3. `_checkNative`, then `_pull` currency0 and currency1 from `msg.sender`, not from `recipient`.
4. `poolManager.unlock(abi.encode(DEPOSIT, id, abi.encode(params, msg.sender)))`.
5. If returned `shares < minShares` or `shares == 0`, revert `Slippage` (`0x7dd37f70`). This check happens before `sharesOf` is credited.
6. Credit `sharesOf[id][recipient]`.
7. `_send` `amount - used` of each currency to `msg.sender`, the payer, not the recipient.
8. Emit `Deposited(id, recipient, shares, used0, used1)`. The indexed user is the recipient.

`used` is the negative part of the settled net, not the recipient's balance change. Positive nets are taken to the payer inside the callback by `_settle(..., depositor)`. The payer can therefore receive a take during the callback and a refund after it. The recipient receives shares only, unless the recipient is the payer.

R-23 (F). Inside the callback, deposit order is `_compound` first, then `_deposit` (`lines 209–258`). `_deposit`:

- If `zap`, run `_balance` and replace the amounts with the post-swap amounts.
- Quote liquidity on `amount > 2 ? amount - 2 : 0` for each side, at the post-zap spot price, on the stored ticks.
- If `totalShares == 0`: require `liq > 1000`, set `shares = liq - 1000`, set `totalShares = 1000`, then add `shares`. The 1000 shares are never assigned. They are not an address's balance.
- Else `shares = liq * totalShares / liquidity`, using liquidity before the add, rounding down. `shares == 0` reverts `ZeroShares` (`0x9811e0c7`) inside the callback, so the outer `Slippage` zero-check is not the observed error for that path.
- `modifyLiquidity` with `+int256(uint256(liq))` and salt 0. Then `liquidity += liq` and `totalShares += shares`. The accounting uses the requested `liq`, not a reread of the manager.
- Net is the zap delta plus `callerDelta` of the modify. The second return, `feesAccrued`, is discarded.
- `used` is `net < 0 ? uint256(-net) : 0`. `_settle(net, payer)`.

R-24 (F). `withdraw` (`lines 176–191`, `260–293`) works while paused. Order:

1. `zapTo > 2` reverts `BadZap` (`0x06fa9fd3`) before any debit.
2. Zero recipient reverts `ZeroAddress`. Missing vault reverts `NoVault` (`0xa1b86ccf`). `shares == 0` reverts `ZeroShares` before the debit.
3. `sharesOf[msg.sender] -= shares`. Insufficient shares panic `0x11`. This debit happens before `unlock`.
4. Callback compounds first, then `_withdraw`.
5. After unlock, `out0 < min0 || out1 < min1` reverts `Slippage`. `out` is `net > 0 ? uint256(net) : 0`, not the recipient's measured balance.
6. Emit `Withdrawn(id, msg.sender, shares, out0, out1)`. The indexed user is the share owner, not the recipient.

`_withdraw` burns liquidity and idle pro rata, rounding down, before the manager call:

```
liqOut = uint128(liquidity * shares / totalShares)
idleOut = idle * shares / totalShares
```

It decreases `liquidity` and `totalShares` by those amounts. If `liqOut > 0`, it removes liquidity with salt 0 and uses `callerDelta` only. It then `_pay`s the idle amounts into the manager and adds them to the net, so idle can be zapped. It settles to `w.recipient`. A negative net is paid by the vault via `_pay`, not by the recipient. There is no check that the payment is bounded by this pool's idle.

R-25 (F). `compound` (`lines 194–198`, `297–341`) is permissionless, unpaused-capable, and has no deadline. Missing vault reverts `NoVault`. It does not take a fee on principal. `lastCompound = uint64(block.timestamp)` is written before the liquidity check, including when liquidity is 0, and including when no fees are harvested. The `uint64` cast reverts if `block.timestamp` does not fit. Do not widen it.

If `liquidity == 0`, it returns without a manager call and without `Compounded`. Otherwise it pokes `modifyLiquidity` with delta 0, then:

```
f = callerDelta > 0 ? uint128(callerDelta) : 0
cut = f * perfFeeBps / 10000
take cut to treasury
r = (f - cut) + idle
net starts at int256(f - cut), not at the raw callerDelta, and not including idle
```

Negative `callerDelta` is treated as zero harvest and is not copied into `net`. If `r0 > 2 || r1 > 2`, it quotes liquidity on the cushioned remainders and, if `liq > 0`, adds it, increases `v.liquidity`, and adds that `callerDelta` into `net`. Then:

```
idle = uint256(int256(idle) + net)
settle(net, address(this))
```

`Compounded(id, f0, f1, liq)` is emitted only when `f0 > 0 || f1 > 0`. Idle-only liquidity adds emit nothing. `liq` in the event can be 0 when fees were harvested but did not clear the cushion. `feesAccrued` is ignored. No shares are minted.

R-26 (F). Callback dispatch (`lines 209–222`) reverts `NotPoolManager` (`0xae18210a`) unless `msg.sender == poolManager`. Compound's `inner` is the raw `hookData`. Deposit's `inner` is `abi.encode(DepositParams, depositor)`. Withdraw's `inner` is `abi.encode(WithdrawParams)`. A direct `unlockCallback` does not enter the reentrancy guard. Tests use the real manager, so the payload is the vault's own encoding. Do not fabricate a manager payload.

R-27 (F). Deadline is `block.timestamp > deadline`, so equality succeeds. It applies only to `deposit` and `withdraw`. `deadline == 0` is expired at any current timestamp. An expired call does not pull, debit, or unlock.

## 10. Native, refund, and settlement

R-28 (F). Native currency is `address(0)` only. Nothing is wrapped. WETH as a pool currency is an ERC20 path. `_checkNative` (`WeirBase.sol.txt` lines 48–51) requires `msg.value` to equal the sum of the native legs of the two declared amounts, exactly. Extra value on an otherwise ERC20 deposit reverts `BadNativeAmount` (`0xe90938f3`). A short value reverts the same way. A valid pool cannot have two native currencies, because the manager rejects `currency0 >= currency1` at initialize. Do not add a both-native special case.

R-29 (F). `_pull` (`lines 42–45`) skips zero amounts and native. ERC20 uses `safeTransferFrom(payer, vault, amount)`. It does not measure the received balance. `_send` (`lines 76–84`) skips zero. Native `_send` is `to.call{value: amount}("")` with all remaining gas, and reverts `NativeTransferFailed` (`0xf4b3b1bc`) if the call returns false. ERC20 `_send` is `safeTransfer`. Refunds go to the payer.

R-30 (F). Settlement order is normative (`lines 54–73`). `_pay` of native calls `poolManager.settle{value: amount}()` and does not `sync`. `_pay` of ERC20 calls `sync`, then `safeTransfer` to the manager, then `settle()`. `_take` calls `take(currency, to, amount)` and skips zero. `_settle` pays a negative net and takes a positive net. A zero net is a no-op. The `settle` return value is ignored. Do not add a check on it. After every successful `unlock`, the real manager's nonzero-delta count is zero; otherwise the manager reverts `CurrencyNotSettled` and the whole transaction rolls back.

R-31 (F). `receive` (`line 38`) accepts ETH from anyone, including the manager's `take` to the vault. The amount is not credited to `idle`. A plain ETH transfer is not a deposit. Deposit will not absorb leftover ETH, because `_checkNative` is per-call `msg.value` and refunds only `amount - used`.

R-32 (L). Idle is an accounting claim on a shared token balance, not per-pool escrow. On compound, `idle` is updated before `_settle`, and `uint256(int256(idle) + net)` reverts if `net < -int256(idle)`. That path therefore fails closed instead of spending another pool's idle. On withdraw, a negative net after removal or zap is paid from the contract balance and is not deducted from this pool's remaining idle. A hook-altered `callerDelta`, or a fee-on-transfer shortfall when the contract already holds that token, can spend a donation or another pool's idle. Do not add escrow. Characterize both paths.

## 11. Zap, cushion, fees, and rounding

R-33 (F). The two-unit cushion is applied only when quoting liquidity for a deposit add and a compound re-add. It is not applied to withdraw, preview, or pending fees. Each side contributes `amount > 2 ? amount - 2 : 0`. If both cushioned amounts are 0, deposit liquidity is 0 and the callback reverts `ZeroShares`. Compound simply adds no liquidity and leaves the dust in idle.

R-34 (F). `_balance` (`lines 346–371`) is a one-shot heuristic, not an exact full-range ratio. The comment at lines 343–345 overclaims. Do not replace the formula.

```
a0in1 = mulDiv(mulDiv(a0, sqrtP, Q96), sqrtP, Q96)
if a0in1 > a1:
  x = (a0 - mulDiv(mulDiv(a1, Q96, sqrtP), Q96, sqrtP)) / 2
  if x == 0: no swap
  else swap zeroForOne, exact input x, limit MIN_SQRT_PRICE + 1
else if a1 > a0in1:
  x = (a1 - a0in1) / 2
  if x == 0: no swap
  else swap oneForZero, exact input x, limit MAX_SQRT_PRICE - 1
else:
  no swap
n0 = uint256(int256(a0) + swap.amount0)
n1 = uint256(int256(a1) + swap.amount1)
```

`mulDiv` rounds down. `x` rounds down. There is no second iteration and no swap-level slippage check. Deposit slippage is only `shares >= minShares`.

R-35 (F). `_swap` (`lines 373–384`) uses `amountSpecified = -int256(amountIn)` and the min/max sqrt limits above. `amountIn > uint256(type(int256).max)` reverts on the cast. Do not widen it. The pool may partially fill. A hook with a returns-delta flag may change the delta. The source does not compare the returned delta to `x`. `n0` / `n1` revert on underflow if the signed delta makes the sum negative. That revert is faithful. Do not catch it.

R-36 (L). `zapTo == 0` returns both tokens and does not swap. `zapTo == 1` swaps currency1 to currency0 only if `net1 > 0`, for `uint256(net1)`, not for a computed optimal input. `zapTo == 2` is symmetric. Partial fill, price impact, protocol fee, and hook deltas can leave a residual of the other token. `out` of the residual side can be nonzero. A caller who sets both `min0` and `min1` nonzero on a one-sided zap can revert `Slippage` even though the zap ran. There is no full-consumption guarantee and no single-token guarantee. Do not add one. Tests must show a residual rather than require it to be zero.

R-37 (F). No fee is charged on deposit or withdraw principal. The only fee is `perfFeeBps` of the positive poke `callerDelta`, rounded down, taken to the current `treasury` before the re-add. Default 500. Cap 1000. A cut of 0 does not call `take`. Fee-on-zero-liquidity is a no-op harvest, not a stored receivable. Fees that accrue with zero recorded liquidity are not harvested by this function.

R-38 (F). `LiquidityAmounts` (`LiquidityAmounts.sol.txt`) is the quote library. Preserve the GPL header, the `require(..., "liquidity overflow")` string, and the formulas. `getAmount0ForLiquidity` divides by `sqrtA` after `mulDiv`, so it rounds down twice. `getLiquidityForAmounts` uses the smaller side when the price is inside the range, amount0-only at or below the lower price, and amount1-only at or above the upper price. Equal sqrt bounds divide by zero. The vault does not call it with equal ticks, because min and max usable ticks differ for a manager-accepted spacing. A direct library test of overflow and equal-bound division is a library fidelity test, not a vault repair.

Independent oracles must not call `WeirVaults`, `WeirBase`, or the imported `LiquidityAmounts` to manufacture expected numbers. They may use a body-proved `FullMath` and `TickMath` as dependencies. Share, fee, cushion, and zap formulas are written in the test.

## 12. Reentrancy and hooks

R-39 (F). Guard matrix. `nonReentrant` is on `deposit`, `withdraw`, and `compound` only. One guard covers all three: any reentrant call among them reverts `ReentrancyGuardReentrantCall` (`0x3ee5aeb5`). Unguarded: `createVault`, `transferShares`, `unlockCallback`, `receive`, all views, `setTreasury`, `setPerfFee`, `pause`, `unpause`, and the ownership functions. Do not add guards. The frozen guard is the sequential `_status` guard, not `ReentrancyGuardTransient` and not the crane ERC-7201 guard.

Modifier order on `deposit` checks pause before entering the guard, then deadline inside the guard. An `EnforcedPause` revert does not leave the guard entered. A revert rolls `_status` back.

R-40 (F). There is no already-unlocked path. From inside someone else's manager unlock, `deposit`, `withdraw`, or `compound` call `unlock` and the real manager reverts `AlreadyUnlocked`. From inside this vault's own unlock, a reentrant guarded call reverts `ReentrancyGuardReentrantCall` before the second `unlock`. Both selectors are required. Do not add a hook-only fast path.

R-41 (F). Observable mid-callback state is fidelity, not a defect. During `withdraw`, `sharesOf[msg.sender]` is already reduced and `totalShares` is not reduced until `_withdraw`, which runs after `_compound`. A hook on the compound poke therefore observes the debit without the supply decrease. During `deposit`, `totalShares` and `liquidity` increase inside the callback, and `sharesOf[recipient]` increases only after unlock returns. A hook cannot move the in-flight shares, because they are not credited yet. Views are unguarded, so `previewRedeem` and `pendingFees` are callable in these windows. Do not move the burn or the credit to "close" the window.

R-42 (F). Callback surfaces that can reenter unguarded functions, and must be tested with a real peripheral:

- ERC20 `transferFrom` during `_pull`, before share credit. The token is the caller of the reentering call, so `transferShares` moves the token's own shares, not the user's, unless the token is the user.
- Native `_send` to the payer after share credit, with all gas. The payer can `transferShares` the just-credited shares and can call `createVault`. Guarded functions revert.
- `take` to a contract recipient or treasury. That contract can call unguarded functions. If it is the owner, it can `setPerfFee`, `setTreasury`, `pause`, or start an ownership transfer during the operation.
- Pool hooks on poke, add, remove, and swap. `hookData` is forwarded unchanged, including empty bytes. A reverting hook bubbles. The vault does not catch it.

R-43 (L). The source trusts `callerDelta`. The frozen `IPoolManager` documents that this delta includes principal, fees, and hook deltas, and that returns-delta hooks can change swap inputs and outputs. `feesAccrued` is documented as inflatable and is ignored. A hook that returns an extra positive delta which the hook itself settles is harvested as a fee: the treasury cut is taken and the remainder follows the compound formula. A hook that returns an unfunded negative delta is not copied into `net` on the poke. The leftover manager delta then fails the unlock with `CurrencyNotSettled`, or an earlier cast or transfer fails. On withdraw, the removal or swap delta is settled as-is, so an extra negative delta is paid from the vault balance. Do not switch to `feesAccrued`, cap the delta, or ignore hook deltas. If the crane manager port does not include hook deltas in `callerDelta`, that is a dependency-fidelity finding. Do not edit Weir to match the port.

R-44 (L). `setPerfFee` and `setTreasury` are not guarded. An owner-controlled hook on the compound poke runs before the cut is computed, so it can change `perfFeeBps` and `treasury`, and the cut uses the new values. A hook on the later liquidity add runs after the cut. A non-owner hook that calls those setters reverts `OwnableUnauthorizedAccount` and rolls the compound back. Do not guard the setters.

## 13. Preservation risks

These are source facts. Class L unless noted. Tests characterize them. None authorizes a patch.

P-01. The 1000 genesis shares are unassigned forever. They dilute every later depositor, including the first. They cannot be withdrawn. Removing them is class X.

P-02. `previewRedeem` is a spot, pre-fee, no-zap, no-cushion quote. It will disagree with `withdraw`, which compounds first and may zap. Asserting equality is an invalid test.

P-03. The zap is a halved spot-value heuristic with a full-range price limit. It can move the pool, partially fill, and leave both tokens unbalanced. The full-range tick bounds are not an input to the split.

P-04. Single-sided zap does not promise a one-token exit. Residual output is faithful.

P-05. The two-unit cushion is not a solvency proof. A price move or hook between the quote and `modifyLiquidity` can make the add cost more than `idle + harvested net`. Compound then reverts on the idle cast or on settlement. That fail-closed result is the requirement. A cushion increase is class X.

P-06. Shared balances plus withdraw `_settle` of a negative hook or shortfall delta can spend donations or another pool's idle. Compound's own idle update fails closed. Do not "fix" one path by changing the other.

P-07. Fee-on-transfer and rebasing tokens are unsupported. `_pull` does not measure receipts. With no preexisting balance, a short receipt fails later settlement and rolls back. With a preexisting balance, the shortfall can be paid from that balance. Neither result is support. Do not add a balance-delta check.

P-08. `pendingFees` uses unchecked growth subtraction and manager position liquidity. It can disagree with `v.liquidity` if those ever diverge. Faithful successful operations through this contract should keep them equal, because only the vault can modify its salt-zero position and the code adds the requested `liq`. A hook that changes position liquidity rather than balance delta would break that equality. Record the manager's actual result. Do not patch the accounting.

P-09. `lastCompound` truncates to `uint64` and updates even when nothing is harvested. There is no compound deadline.

P-10. `poolManager` may be zero or an EOA. Later calls fail. Do not add a constructor check.

P-11. Renounce permanently disables admin and leaves user functions live. Do not remove `renounceOwnership`.

P-12. Read-only and unguarded-admin reentrancy windows in R-41 and R-44 are visible to hooks. Closing them is class X.

P-13. Compiling under 0.8.35 / optimizer 1 / `via_ir=false` will not reproduce upstream bytecode. That is accepted. Enabling `via_ir` is not.

P-14. Hermetic tests bind to crane's ported `PoolManager`, not to the unverified chain-4663 manager implementation. A port divergence is a dependency finding, not a Weir repair.

P-15. GPL LiquidityAmounts and BUSL Position are pulled into the compiled artifact through internal calls. Header scrubbing is forbidden. Legal disposition is a release gate, not a code change.

## 14. Acceptance rows

Preconditions use a real manager, a freshly deployed copy, standard non-rebasing ERC20s unless the row says otherwise, and an independent oracle. "Rollback" means token balances, allowances, ETH balances, `sharesOf`, `totalShares`, `liquidity`, both idles, manager position liquidity, treasury balances, and `vaultCount` equal their pre-call values. Expected selectors are the predictions in section 6; the compiled artifact wins if a signature was mis-typed, and a missing custom error does not.

| ID | Class | Preconditions | Action | Expected result | Locator |
|---|---|---|---|---|---|
| AC-01 | F | owner and treasury nonzero | deploy | `poolManager`, `owner`, `treasury` set; `perfFeeBps == 500`; `paused == false`; `vaultCount == 0`; `pendingOwner == 0` | WeirVaults 93–97; Ownable 38–43 |
| AC-02 | F | none | deploy with treasury 0 | revert `ZeroAddress`; no code | WeirVaults 94–95 |
| AC-03 | F | none | deploy with owner 0 | revert `OwnableInvalidOwner(0)` | Ownable 39–41 |
| AC-04 | L | none | deploy with manager 0 | deploy succeeds; `poolManager() == 0` | WeirBase 33–35 |
| AC-05 | F | deployed | non-owner `setTreasury`, `setPerfFee`, `pause`, `unpause`, `transferOwnership`, `renounceOwnership` | revert `OwnableUnauthorizedAccount(caller)`; state unchanged | Ownable 48–54 |
| AC-06 | F | owner | `transferOwnership(B)` then read owner | owner unchanged; `pendingOwner == B`; `OwnershipTransferStarted` | Ownable2Step 43–47 |
| AC-07 | F | pending B | `acceptOwnership` from B | owner is B; pending is 0; `OwnershipTransferred` | Ownable2Step 60–67 |
| AC-08 | F | pending B | owner `transferOwnership(0)` | pending is 0; owner unchanged | Ownable2Step 43–46 |
| AC-09 | F | owner | `renounceOwnership` | owner 0; pending 0; later admin calls revert unauthorized; `withdraw` still succeeds | Ownable 64–66; Ownable2Step 55–58 |
| AC-10 | F | owner | `setTreasury(0)` | revert `ZeroAddress`; treasury unchanged | 388–391 |
| AC-11 | F | owner | `setTreasury(T2)` | treasury is T2; `TreasurySet(T2)`; no token movement | 388–392 |
| AC-12 | F | owner | `setPerfFee(0)`, `setPerfFee(1000)`, `setPerfFee(500)` again | each succeeds and emits `PerfFeeSet`; stored value matches | 394–398 |
| AC-13 | F | owner | `setPerfFee(1001)` | revert `FeeTooHigh`; fee unchanged | 395 |
| AC-14 | F | unpaused | owner `pause` | `paused`; `Paused(owner)` | 400–402; Pausable 99–103 |
| AC-15 | F | paused | `pause` again | revert `EnforcedPause` | Pausable 84–86 |
| AC-16 | F | paused | non-owner `unpause` | revert `OwnableUnauthorizedAccount`; stays paused | 404–406 |
| AC-17 | F | paused | owner `unpause` | not paused; `Unpaused(owner)` | Pausable 109–113 |
| AC-18 | F | unpaused | `unpause` | revert `ExpectedPause` | Pausable 92–94 |
| AC-19 | F | paused; user has shares | `deposit` | revert `EnforcedPause`; rollback | 154–156 |
| AC-20 | F | paused; user has shares | `withdraw`, `compound`, `transferShares`, `createVault` | each succeeds subject to its other rules | 140, 177, 194, 200 |
| AC-21 | F | initialized pool | `createVault` | `exists`; ticks are min/max usable; `liquidity == 0`; `totalShares == 0`; `allVaults` appended; `VaultCreated`; `vault(id).key.toId() == id` | 140–151 |
| AC-22 | F | vault exists | `createVault` again | revert `VaultExists`; `vaultCount` unchanged | 143 |
| AC-23 | F | uninitialized key | `createVault` | revert Weir `PoolNotInitialized` from `createVault`, not from `initialize` | 144–145 |
| AC-24 | F | two initialized pools | create both, including one dynamic-fee pool | two ids; independent vaults; `vaultCount == 2` | 69–73, 140–151 |
| AC-25 | F | no vault; valid deadline; recipient set; standard tokens; oracle `liq == 1000` | `deposit` | revert `ZeroShares`; rollback | 239–242 |
| AC-26 | F | no vault; oracle `liq == 1001` | `deposit` to recipient R from payer P | `shares == 1`; `sharesOf[R] == 1`; `totalShares == 1001`; manager position liquidity `== 1001`; salt 0; unassigned `== 1000`; `Deposited(id, R, 1, used0, used1)` | 239–256, 170–173 |
| AC-27 | F | AC-26 state; second deposit; oracle `newLiq * 1001 / 1001` rounds down | deposit | minted shares equal that quotient; `totalShares` and `liquidity` increase by shares and `newLiq`; no new unassigned shares | 244–248 |
| AC-28 | F | existing liquidity; oracle quotient is 0 | deposit | revert `ZeroShares`; rollback | 249 |
| AC-29 | F | payer P != recipient R; zap off; amounts not fully consumed | deposit | R's share balance increases; R's token balances unchanged; P receives `amount - used` and any positive take; event user is R | 164–172, 254–256 |
| AC-30 | F | recipient 0 | deposit | revert `ZeroAddress` before pull | 158 |
| AC-31 | F | `block.timestamp == deadline` | deposit and withdraw | deadline check passes | WeirBase 28–31 |
| AC-32 | F | `block.timestamp == deadline + 1` | deposit and withdraw | revert `Expired`; rollback | WeirBase 29 |
| AC-33 | F | neither currency native; `msg.value > 0` | deposit | revert `BadNativeAmount`; rollback | WeirBase 48–51 |
| AC-34 | F | currency0 native; `msg.value == amount0` | deposit | native leg not `transferFrom`'d; unused native refunded to payer; ERC20 leg pulled from payer | WeirBase 42–45, 76–80 |
| AC-35 | F | currency0 native; `msg.value == amount0 - 1` or `+ 1` | deposit | revert `BadNativeAmount` | WeirBase 49–50 |
| AC-36 | F | nonzero value | `withdraw`, `compound`, `createVault` | nonpayable rejection; rollback | ABI mutability |
| AC-37 | F | payer contract rejects ETH; unused native > 0 | deposit | revert `NativeTransferFailed`; rollback including the ERC20 pull | WeirBase 78–79 |
| AC-38 | F | standard ERC20 returns false | pull or refund | revert `SafeERC20FailedOperation(token)`; rollback | SafeERC20 `_callOptionalReturn` |
| AC-39 | F | token reverts with a custom error | pull | that error bubbles; no `SafeERC20FailedOperation` wrapped over it; rollback | SafeERC20 assembly bubble |
| AC-40 | F | allowance short | deposit | token or SafeERC20 failure; rollback | WeirBase 44 |
| AC-41 | F | `minShares` above oracle shares, shares > 0 | deposit | revert `Slippage`; `sharesOf` unchanged; position unchanged | 168 |
| AC-42 | F | both raw amounts in `{0,1,2}` | deposit, zap off | cushioned inputs are 0; revert `ZeroShares`; rollback | 233–236, 249 |
| AC-43 | F | one-sided deposit, zap off, price in range | deposit | the zero side quotes 0 liquidity; in-range quote is 0; revert `ZeroShares` | LiquidityAmounts 32–36; WeirVaults 233–236 |
| AC-44 | F | paired deposit, zap off, price in range, amounts > 2 | deposit | liquidity equals the independent min of the two cushioned quotes; refunds equal `amount - used`; manager deltas close | 233–256 |
| AC-45 | F | one-sided deposit, zap on, pool has other liquidity | deposit | a swap occurs only if `x > 0`; post-swap amounts follow R-34; shares follow the post-swap cushioned quote; no swap-level slippage revert | 346–384 |
| AC-46 | L | zap on; pool liquidity cannot fill `x` | deposit | partial fill stands; shares computed from the actual delta; residual refunded; no second swap | 373–380, 365–367 |
| AC-47 | F | vault exists; caller has shares | `withdraw` zapTo 0 | pro-rata liquidity and idle removed, rounding down; both outputs taken to recipient; event user is caller; manager position decreased by `liqOut` | 176–191, 260–293 |
| AC-48 | F | caller shares 0 | `withdraw` of 0 | revert `ZeroShares` before debit | 185 |
| AC-49 | F | caller shares S | `withdraw` S+1 | panic `0x11`; rollback | 186 |
| AC-50 | F | no vault | `withdraw` or `compound` | revert `NoVault`; rollback | 184, 196 |
| AC-51 | F | `zapTo == 3` | withdraw | revert `BadZap` before debit | 180 |
| AC-52 | F | output below `min0` or `min1` | withdraw | revert `Slippage`; shares restored; position restored | 189 |
| AC-53 | L | zapTo 1; other side has a balance; pool cannot swap all of it | withdraw | `out0` and `out1` match the positive nets after one partial swap; a nonzero residual is not a failure; `min` on the residual side can revert `Slippage` | 277–291 |
| AC-54 | L | zapTo 2 | withdraw | symmetric to AC-53 | 281–284 |
| AC-55 | F | first depositor withdraws all assigned shares | withdraw | `sharesOf` is 0; `totalShares == 1000`; manager liquidity equals the unassigned pro-rata remainder; that remainder is not withdrawable by any address | 26, 239–243, 263–268 |
| AC-56 | F | paused | withdraw of owned shares | succeeds | 177 |
| AC-57 | F | two pools share a currency; both have idle | withdraw on pool A, zapTo 0, no hostile hook | pool B idle and pool B token claim unchanged; contract balance decreases only by A's paid idle and settled amounts | 260–275 |
| AC-58 | F | liquidity 0; vault exists | `compound` | `lastCompound` updates; no manager liquidity call; no `Compounded`; idle unchanged | 298–300 |
| AC-59 | F | position with no new fees | `compound` | no `Compounded` if both positive fee parts are 0; `lastCompound` updates | 340 |
| AC-60 | F | swap fees have accrued; fee 500 | `compound` | treasury receives `f * 500 / 10000` of each positive poke delta; remainder plus prior idle is re-quoted with the cushion; no shares minted; `pendingFees` afterwards is the post-compound residual, not the pre-compound value; `Compounded(id, f0, f1, liqAdded)` | 301–340 |
| AC-61 | F | fee set to 0 | `compound` with fees | treasury balance unchanged by a cut; full positive harvest follows the re-add path | 305–308 |
| AC-62 | F | fee set to 1000 | `compound` | treasury receives the entire positive harvest, rounding down; shareholders receive no fee liquidity from that harvest | 305–308 |
| AC-63 | F | fees accrued; do not compound | `previewRedeem` then `pendingFees` | preview equals the pre-fee oracle; `pendingFees` is the gross growth oracle; they are not equal to a following withdraw | 110–135 |
| AC-64 | F | after AC-60 | `previewRedeem` | may increase because liquidity was added without shares; still excludes a new fee accrual | 110–121, 325 |
| AC-65 | L | donate to the pool's in-range fee growth, then `compound` | compound | donation is harvested as fees, cut goes to treasury, liquidity increases, no shares minted; this is not theft and not a defect | IPoolManager donate docs; WeirVaults 301–325 |
| AC-66 | F | ERC20 donated directly to the vault | deposit, withdraw zapTo 0, and compound with no hook | donation remains outside idle; idle accounting does not increase by the donation | 297–338; WeirBase 70–73 |
| AC-67 | F | user has shares | `transferShares` of a partial amount | balances move; `SharesTransferred`; supply unchanged | 200–205 |
| AC-68 | F | user has shares | `transferShares` of 0, including to self | succeeds and emits | 200–205 |
| AC-69 | F | user has shares | `transferShares` to 0 | revert `ZeroAddress`; balances unchanged | 201 |
| AC-70 | F | balance S | `transferShares` S+1 | panic `0x11` | 202 |
| AC-71 | F | shares on pool A and B | transfer A | B unchanged | 72, 200–204 |
| AC-72 | F | any state | direct `unlockCallback` from a non-manager | revert `NotPoolManager` | WeirBase 23–26; WeirVaults 209 |
| AC-73 | F | successful deposit | trace the callback | manager is the caller of `unlockCallback`; after return, manager nonzero-delta count is 0 | PoolManager.unlock; WeirBase 70–73 |
| AC-74 | F | ERC20 settlement | deposit or compound that pays an ERC20 debt | call order is `sync`, then token transfer to manager, then `settle` | WeirBase 58–60 |
| AC-75 | F | native settlement | operation that pays native | `settle` is called with value and without a preceding `sync` of that native leg | WeirBase 55–56 |
| AC-76 | F | during deposit unlock | hook calls `deposit`, `withdraw`, or `compound` | revert `ReentrancyGuardReentrantCall`; outer transaction rolls back | ReentrancyGuard 63–66; WeirVaults 156, 177, 194 |
| AC-77 | F | manager already unlocked by another caller | hook calls `deposit` | revert `AlreadyUnlocked`; no vault state change | PoolManager.unlock 22–23 of crane port; IPoolManager 22–23 |
| AC-78 | F | withdraw in progress, compound poke | hook reads `sharesOf` and `vault().totalShares` | `sharesOf[caller]` already reduced; `totalShares` not yet reduced; call is allowed | 186, 209–221, 266–268 |
| AC-79 | F | deposit in progress, after `_deposit` | hook reads `sharesOf[recipient]` and `totalShares` | `totalShares` includes the new shares; `sharesOf[recipient]` does not yet | 247–248, 170 |
| AC-80 | F | payer is a contract; unused native or a token callback | reenter `transferShares` and `createVault` | those succeed if otherwise valid; guarded reentry still reverts | 200–205, 140–151, 156 |
| AC-81 | L | owner is the pool hook | during compound poke, hook calls `setPerfFee(1000)` and `setTreasury(T2)` | cut uses 1000 and T2; no revert | 305–308, 394–398 |
| AC-82 | F | hook reverts on modify or swap | deposit, withdraw, and compound | hook error bubbles; rollback | 228, 272, 303, 373–383 |
| AC-83 | L | returns-delta hook settles an extra positive delta | compound | extra positive `callerDelta` is treated as harvest; cut and re-add follow R-25; manager deltas close | 301–338; IPoolManager 137–144 |
| AC-84 | L | returns-delta hook adds an unfunded negative poke delta | compound | revert, expected `CurrencyNotSettled` if no earlier cast or transfer fails; rollback; fee cut not retained | 301–304, 336–337 |
| AC-85 | L | no donation; removal hook adds an unfunded negative delta | withdraw | revert; other pool idle unchanged | 270–275, 289 |
| AC-86 | L | vault holds an unaccounted donation of size N; removal hook adds a funded-by-donation debt N | withdraw | donation decreases by N; this pool's remaining idle accounting is unchanged; manager deltas close; this is the shared-balance limitation, not a pass to patch it | 289; WeirBase 70–72 |
| AC-87 | L | two pools share a token; compound hook makes the add cost more than this pool's idle plus harvest | compound | revert on idle cast or settlement; both pools' idle and balances restored | 333–337 |
| AC-88 | L | fee-on-transfer token; vault holds none of it | deposit | revert on later settlement; rollback; test name must not say the token is supported | WeirBase 42–45, 58–60 |
| AC-89 | L | fee-on-transfer token; vault already holds a donation covering the fee | deposit | shares are computed from the requested amount, not the received amount; donation covers the shortfall; record the exact balances; do not add a measured-balance repair | 224–256 |
| AC-90 | F | price moved by a swap; no compound | `previewRedeem` before and after the swap | quote changes with spot price; `pendingFees` does not change merely because price moved | 113–118, 124–135 |
| AC-91 | F | unknown id | `previewRedeem` and `pendingFees` | `(0, 0)`; `pendingFees` does not revert | 112, 126 |
| AC-92 | F | `totalShares > 0`; `shares` so large that `liquidity * shares` overflows or the `uint128` cast fails | `previewRedeem` | panic; no state change | 114 |
| AC-93 | F | library unit, equal sqrt bounds | `getLiquidityForAmount0` | division-by-zero panic | LiquidityAmounts 15–16 |
| AC-94 | F | library unit, product above `uint128` | `getLiquidityForAmount0` | revert string `liquidity overflow` | LiquidityAmounts 8–10 |
| AC-95 | F | fuzz across users, pools, deposit, withdraw, compound, transferShares, bounded standard-token amounts | invariant handler | outside callbacks, after the first successful deposit of a pool: `sum(sharesOf) + 1000 == totalShares`; `perfFeeBps <= 1000`; `treasury != 0`; manager salt-zero position liquidity `== v.liquidity`; contract balance of each standard token `>=` sum of idle for that token. Do not claim the balance inequality for hostile tokens | 26, 239–248, 263–268 |
| AC-96 | F | same handler, guarded reentry attempted | invariant | guarded reentry never succeeds; unguarded `transferShares` is not assumed guarded | ReentrancyGuard 63–66 |
| AC-97 | X | any | assert ERC20 metadata, `preview == withdraw`, single-token exit, dead-share redemption, or pause of withdraw | invalid test. Delete it. Do not change the source to make it pass | brief exclusions |

## 15. Test and release gates

R-45 (F). Hermetic suite is production-first. Real copied Weir, real crane `PoolManager`, real initialize/modify/swap/unlock/settle/take. No SUT mock, etch, storage injection, or subclass. Hostile peripherals are allowed only as peripherals. Expected numbers come from the independent oracle. Assertions include exact balances, `sharesOf`, `Vault` fields, manager position key and liquidity, currency-delta closure, events with indexed fields, and the selector or panic or bubbled error named in the AC row. Rollback rows compare the full pre-state, including allowances and fee cuts.

R-46 (F). Fuzz and invariant campaigns use the default profile's deterministic Foundry settings unless a command-line seed is recorded. Do not add a Foundry profile. A local deeper run may pass `--fuzz-runs` and `--fuzz-seed`, and the evidence must record both. CI uses the default profile only.

R-47 (F). Fork parity is not hermetic CI. It is a local-only `FOUNDRY_PROFILE=fork` run. The reference chain is 4663, not Ethereum mainnet, and not `TestBase_UniswapV4Fork`'s block 21_900_000. A valid comparison deploys a fresh copy against the fork's real manager, or reproduces a pinned pool state and role set, then applies the same inputs. Comparing a fresh local vault to the live balances of `0x9bb6A517a8dB43a55e4A873C0313D7bFADd70110` is invalid. Source verification is not transaction parity. If RPC or pinned state is missing, write that fact in the evidence note. Do not skip-and-pass, do not invent a block, and do not make default-profile tests read RPC or secrets.

R-48 (F). Future implementation, not this pass, runs in this order and does not delete warm `out/` or `cache_forge`:

```
forge build
forge test --match-path test/foundry/spec/protocols/strategy/weir -vv
```

Fork, only locally, only if RPC and a pinned block are actually available:

```
FOUNDRY_PROFILE=fork forge test --match-path test/foundry/fork/protocols/strategy/weir -vv
```

Build before test. Do not enable `via_ir`. Do not kill a slow compile. Do not run these commands as part of authoring this contribution.

R-49 (F). Release evidence, all required before a copied-source release, none of which is produced by this contribution:

1. Compiler storage layout matches the frozen inheritance behavior in R-12, or a recorded discrepancy explains why the compiler layout is still the unmodified source.
2. Artifact ABI contains the frozen custom errors, including `EnforcedPause`, `ExpectedPause`, and `SafeERC20FailedOperation`. String pause or SafeERC20 reverts fail the release.
3. AC-01 through AC-96 pass against the unmodified formulas. AC-97 does not exist as a required test.
4. Body-level proof for every conditionally accepted dependency in section 4, especially `FullMath.mulDiv` and `StateLibrary`.
5. R-07 is satisfied by a recorded dependency decision. A private clone, global remap, or silent crane-OZ binding does not satisfy it.
6. R-10 license disposition is recorded. No MIT blanket label.
7. Fork evidence is either a real pinned chain-4663 run or a written statement that RPC/state was unavailable. A green skip is not evidence.
8. Provenance note states the Sourcify pin, the compiler mismatch, and that no upstream git revision, test suite, or audit was verified.

## 16. Limits

This pass did not compile the sources, did not run `solc --storage-layout`, and did not byte-diff `FullMath.mulDiv` or the full `StateLibrary` body. The storage table in R-12 is a C3 derivation, not a compiler artifact. Selector values are signature predictions. Crane `PoolManager` was read at its unlock and constructor, not diffed against an upstream `PoolManager.sol`, because that implementation is not in the 39-file snapshot. Chain-4663 runtime behavior was not executed. No legal conclusion is made about GPL or BUSL. No peer finding was available or used.

The contribution stops here. It does not authorize implementation.
