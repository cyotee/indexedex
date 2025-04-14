## Progress Log (most recent first)

### 2026-02-11 — Switch to production Permit2 fork tests (Base + Ethereum)
- Implemented Permit2 branch coverage for `BasicVaultCommon._secureTokenTransfer` using fork tests that call the production Permit2 instance (no mocks).
- Updated harness initialization to support Permit2 path by injecting `IPermit2` and calling `Permit2AwareRepo._initialize(permit2_)` in the harness constructor:
  - `test/foundry/spec/vaults/basic/BasicVaultCommon_TokenTransfer.t.sol`
- Refactored spec tests to remove the previous `MockPermit2` approach; spec tests now continue to cover the ERC20 allowance path and fee-on-transfer balance-delta logic.

### 2026-02-11 — Added Base mainnet fork tests (production Permit2)
- Added `test/foundry/fork/base_main/vaults/basic/BasicVaultCommon_TokenTransfer_Permit2_BaseFork.t.sol`.
- Uses `test/foundry/fork/base_main/TestBase_BaseFork.sol` (pinned Base fork block `40_446_736`).
- Uses production Permit2 and WETH from Crane constants (`BASE_MAIN.PERMIT2`, `BASE_MAIN.WETH9`).
- Tests:
  - Permit2 path for standard ERC20 (WETH): set `token.approve(harness, amount - 1)` to force `allowance < amount`, then approve Permit2 + Permit2 spender approval, then call `secureTokenTransfer`.
  - Permit2 path for fee-on-transfer token (local mock token) with production Permit2.
- Ran:
  - `forge test --match-path test/foundry/fork/base_main/vaults/basic/BasicVaultCommon_TokenTransfer_Permit2_BaseFork.t.sol -vvvv`
  - Result: pass.

### 2026-02-11 — Added Ethereum mainnet fork tests (production Permit2)
- Added `test/foundry/fork/eth_main/vaults/basic/BasicVaultCommon_TokenTransfer_Permit2_EthFork.t.sol`.
- Added a minimal `TestBase_EthereumFork` fixture within the file (no existing eth fork base in repo).
- Uses production Permit2 and WETH from Crane constants (`ETHEREUM_MAIN.PERMIT2`, `ETHEREUM_MAIN.WETH9`).
- Uses pinned Ethereum fork block `20_000_000` (Base block `40_446_736` is not valid on Ethereum).
- Ran:
  - `forge test --match-path test/foundry/fork/eth_main/vaults/basic/BasicVaultCommon_TokenTransfer_Permit2_EthFork.t.sol -vvvv`
  - Result: pass.

## Files changed
- `test/foundry/spec/vaults/basic/BasicVaultCommon_TokenTransfer.t.sol` — keep balance-delta regression coverage; initialize Permit2-aware harness; no mock Permit2 tests.
- `test/foundry/fork/base_main/vaults/basic/BasicVaultCommon_TokenTransfer_Permit2_BaseFork.t.sol` — fork tests against production Permit2 (Base).
- `test/foundry/fork/eth_main/vaults/basic/BasicVaultCommon_TokenTransfer_Permit2_EthFork.t.sol` — fork tests against production Permit2 (Ethereum).
