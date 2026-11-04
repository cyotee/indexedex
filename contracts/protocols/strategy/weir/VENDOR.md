# WeirVaults import provenance

Work order: `weir-import-plan-final-r2`.
PRD: `weir-import-prd-owner-clarifications-20261029`.
This file is the human provenance ledger. It is not a safety clearance and not a legal clearance.

## Frozen identity

Sourcify retrieval recorded in `docs/research/weir-source-import-prd-20261029-01a18660/source-snapshot/manifest.json`.

| Field | Value |
|---|---|
| Retrieved | 2026-10-29T18:00:30.870Z |
| Source | `https://sourcify.dev/server/v2/contract/4663/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110?fields=sources,metadata` |
| Chain | 4663 |
| Address | `0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110` |
| Match | match / creation match / runtime match |
| Verified at | 2026-09-30T03:34:14Z |
| Upstream compiler | solc 0.8.26+commit.8a97fa7a, optimizer runs 800, viaIR true, bytecodeHash none, evmVersion cancun |

The import target is not that bytecode. It compiles at solc 0.8.35, optimizer on, optimizer runs 1, viaIR false.

## Deployment table

Supplied reference. This ledger did not refetch the receipt and does not treat it as archive parity.

| Field | Value |
|---|---|
| Chain | 4663 |
| Weir | `0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110` |
| Manager | `0x8366a39CC670B4001A1121B8F6A443A643e40951` |
| Block | 76,197,114 |
| Block hash | `0x07be1214c2742ebcea7a61d8065020e88c4b66b5fc96a753ff022a00aa2c8c1d` |
| Time | 2026-09-30T03:33:23Z |
| Deploy tx | `0xa92ae44ce73b159a3aa3d6c8e2920b4c4771d784a253313a35d2fd9c4fad351a` |
| Owner and treasury at the supplied record | `0x3234DEA52cc05cba7830B5305151C50AD34e9018` |
| Creation | direct, not a factory, supplied receipt evidence |
| Chosen RPC alias | `robinhood_mainnet_alchemy` |

There is no `WEIR_RPC_URL`. `ROBINHOOD_MAIN.sol` was not edited.

## Missing upstream evidence

No upstream Git pin, upstream test suite, or upstream audit is in the frozen corpus. None is invented here. None is claimed to have run.

## License inventory

The 39 frozen entries below keep their original notices. Metadata keccak256 values are copied from the manifest. SHA-256 values are computed from the frozen snapshot bytes. Adjusted production hashes are in `evidence/import-transform.json` and are not frozen hashes.

GPL-2.0-or-later is an open-source declaration. The canonical graph also reaches `BetterEfficientHashLib`, whose header is AGPL-3.0-or-later, an open-source declaration that is not in the frozen 39. CraneTest is AGPL-3.0-or-later and is test infrastructure, not runtime.

BUSL-1.1 on frozen Position.sol is source-available, not open-source. Canonical PoolManager and Position carry literal BSL-1.1 headers. June 15, 2027 is the stated latest calendar change date in the checked upstream declarations, not an expiry proof and not a production grant. Frozen Position bytes match both the older GPL-conversion commit and the newer MIT-conversion commit, so source bytes alone cannot choose one. That ambiguity stays. Production use of BUSL code before conversion is unresolved.

| # | Original path | Declared license | Metadata keccak256 | Snapshot SHA-256 |
|---|---|---|---|---|
| 1 | `src/WeirVaults.sol` | MIT | `0x559c471af50dcb585e2ac8edb35ffa57db8f6dfde4eb0e5dcccdd76569a510ff` | `23de61301729d2950ba110e15cdce5e383fc4e5aacb0b906ee845390bd0e0180` |
| 2 | `src/base/WeirBase.sol` | MIT | `0xb9b5a762941b490e82ad9b87ca3113829f3f4608fa6c368aec0d0e8e51b6fa2e` | `f14c1ef0fe9913f0d99e872f108ab3d7b84f44050d449d2b72049ad20a08b498` |
| 3 | `src/libraries/LiquidityAmounts.sol` | GPL-2.0-or-later | `0x5ddd94b27fbe46b0baf53424594f1699daee50733e5aff6e0c9580fdf318e71a` | `f482702fecb1b6dc5c82b9ad918a4f991ce5b8c4d0c1144b448c25fbaad3093d` |
| 4 | `lib/openzeppelin-contracts/contracts/access/Ownable.sol` | MIT | `0xff6d0bb2e285473e5311d9d3caacb525ae3538a80758c10649a4d61029b017bb` | `38578bd71c0a909840e67202db527cc6b4e6b437e0f39f0c909da32c1e30cb81` |
| 5 | `lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol` | MIT | `0xdcad8898fda432696597752e8ec361b87d85c82cb258115427af006dacf7128c` | `c75345d7b9feef17ae29f2a800ca2f65f8021cf80436a41d6ec00f57f5180f36` |
| 6 | `lib/openzeppelin-contracts/contracts/interfaces/IERC1363.sol` | MIT | `0x9b6b3e7803bc5f2f8cd7ad57db8ac1def61a9930a5a3107df4882e028a9605d7` | `54f427f63724d9760211dfa9e0cc5d79d86c0724becd81f8e638e2e27b0e2669` |
| 7 | `lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol` | MIT | `0xde7e9fd9aee8d4f40772f96bb3b58836cbc6dfc0227014a061947f8821ea9724` | `49abfb8fa26e3f1715fe05948a96e3762b805bd4a77d103eb40ba96b1acfa144` |
| 8 | `lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol` | MIT | `0xce41876e78d1badc0512229b4d14e4daf83bc1003d7f83978d18e0e56f965b9c` | `cb42f0b4d269ba8ef2629c176a7f99bf4fb50837c92f45596b54822b26e3df4b` |
| 9 | `lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol` | MIT | `0xe06a3f08a987af6ad2e1c1e774405d4fe08f1694b67517438b467cecf0da0ef7` | `30edf7394bab78d48b7db3a059248e1ea7c2c77d2ec0e37a13bb91415aafbe5a` |
| 10 | `lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol` | MIT | `0xca2ae13e0610f6a99238dd00b97bd786bc92732dae6d6b9d61f573ec51018310` | `d67b0f3d9302b2ff7cec76776fc2c1f3686082287441c15c6871c0086a8a4f74` |
| 11 | `lib/openzeppelin-contracts/contracts/utils/Address.sol` | MIT | `0x9d8da059267bac779a2dbbb9a26c2acf00ca83085e105d62d5d4ef96054a47f5` | `8228692ef1ccb4cfe5b7cc58324cadd06045e10e386185f9e4d45173d6d6c633` |
| 12 | `lib/openzeppelin-contracts/contracts/utils/Context.sol` | MIT | `0x493033a8d1b176a037b2cc6a04dad01a5c157722049bbecf632ca876224dd4b2` | `847fda5460fee70f56f4200f59b82ae622bb03c79c77e67af010e31b7e2cc5b6` |
| 13 | `lib/openzeppelin-contracts/contracts/utils/Errors.sol` | MIT | `0x6afa713bfd42cf0f7656efa91201007ac465e42049d7de1d50753a373648c123` | `0704b9d6c032cca8512a3bc3f30f49f86f1f03102d2896a3d23e794b82efea66` |
| 14 | `lib/openzeppelin-contracts/contracts/utils/Pausable.sol` | MIT | `0xb2e5f50762c27fb4b123e3619c3c02bdcba5e515309382e5bfb6f7d6486510bd` | `6543160582b3c0319a180f31660faf6ba0a8444acbdb03357c09790a96256835` |
| 15 | `lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol` | MIT | `0x11a5a79827df29e915a12740caf62fe21ebe27c08c9ae3e09abe9ee3ba3866d3` | `32fbb1c908ec1b4de85cc1bb10091aebd5816ffe80dfdd5ca5e084fbea67a462` |
| 16 | `lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol` | MIT | `0x79796192ec90263f21b464d5bc90b777a525971d3de8232be80d9c4f9fb353b8` | `7c5c3f98ab876991e7dd34b84d41137e836306eb9f36f6386a631f5be3f5d6d4` |
| 17 | `lib/v4-core/src/interfaces/IExtsload.sol` | MIT | `0x80b53ca4907d6f0088c3b931f2b72cad1dc4615a95094d96bd0fb8dff8d5ba43` | `9421ef4ba198d94058cd9a4c9fd2d663c61fc682f7dafa449a873456853f0025` |
| 18 | `lib/v4-core/src/interfaces/IExttload.sol` | MIT | `0xc6b68283ebd8d1c789df536756726eed51c589134bb20821b236a0d22a135937` | `c21643d2c7f48d2d2407438a64a3ff0f376324cf6a0c62608977713652308c9e` |
| 19 | `lib/v4-core/src/interfaces/IHooks.sol` | MIT | `0x4c9571aed0c2b6ef11832545554fc11ffdb03746daaf5c73683c00600bfc7ec0` | `aca1db9898026d9a4b8740752fb0dbfc6a55e4bede6a949c6af4e07d626f6900` |
| 20 | `lib/v4-core/src/interfaces/IPoolManager.sol` | MIT | `0x3534f00531038e77ab8a7fc4d0a6e0993ee53fb7a396b1324ad917318ea46cea` | `173a3f93aeb39373271ebe2bfb961d824922378a39b7a5e983acbb1c122d296e` |
| 21 | `lib/v4-core/src/interfaces/IProtocolFees.sol` | MIT | `0x32a666e588a2f66334430357bb1e2424fe7eebeb98a3364b1dd16eb6ccca9848` | `807d68adea106ec2aa51a8009155de09ebfe09e1ee7053d5a5ae448d7e840654` |
| 22 | `lib/v4-core/src/interfaces/callback/IUnlockCallback.sol` | MIT | `0x58c82f2bd9d7c097ed09bd0991fedc403b0ec270eb3d0158bfb095c06a03d719` | `2e4a514730654da2e08a82eff5b3eabae12dc1c6198951396e1d466d4c0e223e` |
| 23 | `lib/v4-core/src/interfaces/external/IERC20Minimal.sol` | MIT | `0xeccadf1bf69ba2eb51f2fe4fa511bc7bb05bbd6b9f9a3cb8e5d83d9582613e0f` | `5e966a2d22b3b234a56af4b17e36bf7be90f9b29b1ddb6a15bfefc0b6dab4282` |
| 24 | `lib/v4-core/src/interfaces/external/IERC6909Claims.sol` | MIT | `0xa586f345739e52b0488a0fe40b6e375cce67fdd25758408b0efcb5133ad96a48` | `1cd65496c829036bc6aee67bc71363ab5fb6989c65e793087d0e1e2379f7d7d8` |
| 25 | `lib/v4-core/src/libraries/BitMath.sol` | MIT | `0x51b9be4f5c4fd3e80cbc9631a65244a2eb2be250b6b7f128a2035080e18aee8d` | `e8a45eb3d57f9427fc47bbb2543c1a6a5f394113b378123ac7ca9f113a7502b4` |
| 26 | `lib/v4-core/src/libraries/CustomRevert.sol` | MIT | `0x111ed3031b6990c80a93ae35dde6b6ac0b7e6af471388fdd7461e91edda9b7de` | `9d3dbe6b742cb1ac30f57df89d879ade9649389de1165fc637114bd062d39fca` |
| 27 | `lib/v4-core/src/libraries/FixedPoint128.sol` | MIT | `0xad236e10853f4b4b20a35a9bb52b857c4fc79874846b7e444e06ead7f2630542` | `1ca2f55160697b73bd66fd27c8724d79a57108121ce1e8a0ab8b79f38bb58fbb` |
| 28 | `lib/v4-core/src/libraries/FixedPoint96.sol` | MIT | `0xef5c3fd41aee26bb12aa1c32873cfee88e67eddfe7c2b32283786265ac669741` | `66ee26d4fb3ac639124bdfa27d3256d196970997fa127c09e9bf7154e30d4590` |
| 29 | `lib/v4-core/src/libraries/FullMath.sol` | MIT | `0x4fc73a00817193fd3cac1cc03d8167d21af97d75f1815a070ee31a90c702b4c2` | `a9607255a6fd604d9c92f6b7416811c38b9d86e5dfdb0c345a494ebd35f7a4a3` |
| 30 | `lib/v4-core/src/libraries/LiquidityMath.sol` | MIT | `0x000ef2eadcc1eb7b2c18a77655f94e76e0e860f605783484657ef65fd6eda353` | `67a39e58732340af4870342ba9230691f35501d89ed8725ca1b338deaa0eb26a` |
| 31 | `lib/v4-core/src/libraries/Position.sol` | BUSL-1.1 | `0xddab2a831f1befb6abf5567e77c4582169ca8156cf69eb4f22d8e87f7226a3f9` | `3dc4e2ad1564fa94eddf3ff06ce9ac592c9d578ea64ca194050382da454c8fcb` |
| 32 | `lib/v4-core/src/libraries/SafeCast.sol` | MIT | `0x42c4a24f996a14d358be397b71f7ec9d7daf666aaec78002c63315a6ee67aa86` | `c1a815a41607be5b4c86ca588a951f368156da8ee21bdfc18b5d51b58a0f27be` |
| 33 | `lib/v4-core/src/libraries/StateLibrary.sol` | MIT | `0x96db333ee126a841dd959e38e452cc59d73583cb0437a1d48b2052e33a74f952` | `eebdbc1b6e431072ce5521b9e1b603d43831e3b6e062743e6665e070d5cf8a1a` |
| 34 | `lib/v4-core/src/libraries/TickMath.sol` | MIT | `0x4e1a11e154eb06106cb1c4598f06cca5f5ca16eaa33494ba2f0e74981123eca8` | `272d4f6d3ff9ae33596ebcdb84a71a3c2d4542ae8fb5c88ddf1aca8043f5d06b` |
| 35 | `lib/v4-core/src/types/BalanceDelta.sol` | MIT | `0xa719c8fe51e0a9524280178f19f6851bcc3b3b60e73618f3d60905d35ae5569f` | `320d9c13dec135c3903729e66d3a1040fe86d537a7ee53728915012ca183af32` |
| 36 | `lib/v4-core/src/types/BeforeSwapDelta.sol` | MIT | `0x2a774312d91285313d569da1a718c909655da5432310417692097a1d4dc83a78` | `6aee06f1553e879f5909e8f4c0eac26ec23dd4821a7e56e4d5077db39a227e12` |
| 37 | `lib/v4-core/src/types/Currency.sol` | MIT | `0x4a0b84b282577ff6f8acf13ec9f4d32dbb9348748b49611d00e68bee96609c93` | `ba6726fd24fbc66848208dfbb2899116c10729c505e6e5552316ac2444f1dfc3` |
| 38 | `lib/v4-core/src/types/PoolId.sol` | MIT | `0x308311916ea0f5c2fd878b6a2751eb223d170a69e33f601fae56dfe3c5d392af` | `548424ac50ad58212545da70207283fb8990731578c115c85d5acbcb0e1d3c9f` |
| 39 | `lib/v4-core/src/types/PoolKey.sol` | MIT | `0xf89856e0580d7a4856d3187a76858377ccee9d59702d230c338d84388221b786` | `99e1afe285b5c614ebc9586ab5196db9d24a63fd924a449f5d99f490a6a6d6a9` |

Count: 37 MIT, one GPL-2.0-or-later, one BUSL-1.1.

Checked upstream declaration texts, not re-fetched in this import:

| Declaration | SHA-256 supplied by the PRD |
|---|---|
| `https://raw.githubusercontent.com/Uniswap/v4-core/36d790b1a3af/LICENSE` | `eadc120aa29a227a13a4e1a2b1095c33c5c6b8967070a20c8a551a6b54158bf2` |
| `https://raw.githubusercontent.com/Uniswap/v4-core/0f17b65aa61e/licenses/BUSL_LICENSE` | `cd5241d8e1afe7098fa0f21059f7153348fdd25dbae5a8383a5f1dd2eb590321` |

## Import map

Twenty-two specifier rewrites, one added `PoolOperation` import, and five free-struct qualifications. Two relative Weir imports are unchanged. The machine allowlist is `evidence/import-transform.json`. WI-06 was not applied before compilation.

| File | Frozen SHA-256 | Adjusted SHA-256 |
|---|---|---|
| WeirVaults.sol | `23de61301729d2950ba110e15cdce5e383fc4e5aacb0b906ee845390bd0e0180` | `823428f620cc4695860c6e1ce15011c1d1af04b1ddec16d954d7b0d18e48a9d7` |
| base/WeirBase.sol | `f14c1ef0fe9913f0d99e872f108ab3d7b84f44050d449d2b72049ad20a08b498` | `dd3940d3bed673a11e4cc7524578b940fa70fecfc652bf51a6a133b209d59e16` |
| libraries/LiquidityAmounts.sol | `f482702fecb1b6dc5c82b9ad918a4f991ce5b8c4d0c1144b448c25fbaad3093d` | `1767ea348e039a66396258246be9f3f6a1f4b70bd979909fdcb144b25ca67092` |

## WP-00 notes

No behavior-changing canonical mismatch was found. The written gate is `evidence/dependency-compatibility.json`.

Named selectors, computed from the source signatures:

| Signature | Selector |
|---|---|
| `CurrencyLibrary.NativeTransferFailed()` | `0xf4b3b1bc` |
| `CurrencyLibrary.ERC20TransferFailed()` | `0xf27f64e4` |
| `CustomRevert.WrappedError(address,bytes4,bytes,bytes)` | `0x90bfb865` |
| `Hooks.HookCallFailed()` | `0xa9e35b2f` |
| `IPoolManager.NonzeroNativeValue()` | `0xb0ec849e` |
| `IPoolManager.CurrencyNotSettled()` | `0x5212cba1` |
| `IPoolManager.AlreadyUnlocked()` | `0x5090d6c6` |

Positive-liquidity rounding at the fixed F0 bounds costs K per side. That expected cost was not replaced.

## Release

WP-09 record is `IMPORT_EVIDENCE.md`. Hermetic tests use a real `PoolManager` and `new WeirVaults`. Fork preflight passed on `robinhood_mainnet_alchemy` at pin `76,197,114`. No selected-pool parity trace. No parity trace was produced. No safety clearance. No legal clearance. No archive proof. BUSL production use stays unresolved.
