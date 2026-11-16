// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

/// @dev Minimal Bridgehub surface for ZK Stack L1→L2 ETH deposits (BattleChain testnet).
interface IBridgehub {
    struct L2TransactionRequestDirect {
        uint256 chainId;
        uint256 mintValue;
        address l2Contract;
        uint256 l2Value;
        bytes l2Calldata;
        uint256 l2GasLimit;
        uint256 l2GasPerPubdataByteLimit;
        bytes[] factoryDeps;
        address refundRecipient;
    }

    function requestL2TransactionDirect(L2TransactionRequestDirect calldata _request)
        external
        payable
        returns (bytes32 canonicalTxHash);

    function l2TransactionBaseCost(
        uint256 _chainId,
        uint256 _gasPrice,
        uint256 _l2GasLimit,
        uint256 _l2GasPerPubdataByteLimit
    ) external view returns (uint256);
}

/// @notice Deposit Sepolia ETH to BattleChain testnet (chain 627) via the L1 Bridgehub.
///
/// Usage (from IndexedEx root):
///
///   L2_DEPOSIT_WEI=500000000000000000 forge script \
///     scripts/foundry/battlechain/Script_Bridge_SepoliaToBattleChain.s.sol:Script_Bridge_SepoliaToBattleChain \
///     --rpc-url sepolia_public \
///     --broadcast \
///     --account deployer \
///     --sender $(cast wallet address --account deployer) \
///     -vv
///
/// Then: cast balance $(cast wallet address --account deployer) --rpc-url battlechain-sepolia
contract Script_Bridge_SepoliaToBattleChain is Script {
    address public constant SEPOLIA_BRIDGEHUB = 0xcEa5C0ade89389Dd5FC461F69CCbD812cFb7fbd8;

    uint256 public constant BC_TESTNET_CHAIN_ID = 627;
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;

    uint256 public constant DEFAULT_L2_GAS_LIMIT = 1_000_000;
    uint256 public constant DEFAULT_L2_GAS_PER_PUBDATA = 800;
    uint256 public constant DEFAULT_BASE_COST_BPS_PAD = 2000;

    function run() external {
        require(block.chainid == SEPOLIA_CHAIN_ID, "Script_Bridge: must run against Sepolia (11155111)");

        uint256 amount = vm.envOr("L2_DEPOSIT_WEI", uint256(0.1 ether));
        require(amount > 0, "Script_Bridge: L2_DEPOSIT_WEI must be > 0");

        (uint256 mintValue, uint256 baseCost, uint256 gasPrice) = _quoteMintValue(amount);

        console2.log("=== Sepolia -> BattleChain testnet ETH deposit ===");
        console2.log("bridgehub", SEPOLIA_BRIDGEHUB);
        console2.log("l2DepositWei", amount);
        console2.log("quoteGasPrice", gasPrice);
        console2.log("baseCost", baseCost);
        console2.log("mintValue", mintValue);

        // Quote-only: skip wallet / broadcast (for CI and preflight).
        if (vm.envOr("QUOTE_ONLY", false)) {
            console2.log("QUOTE_ONLY=true - not broadcasting. Re-run with --broadcast --account deployer.");
            return;
        }

        bytes32 canonicalTxHash = _broadcastDeposit(amount, mintValue);

        console2.log("canonicalL1L2TxHash");
        console2.logBytes32(canonicalTxHash);
        console2.log("Next: wait for L2 inclusion, then cast balance on battlechain-sepolia");
        console2.log("Portal UI alternative: https://portal.battlechain.com/bridge");
    }

    function _quoteMintValue(uint256 amount)
        internal
        view
        returns (uint256 mintValue, uint256 baseCost, uint256 gasPrice)
    {
        uint256 l2GasLimit = vm.envOr("L2_GAS_LIMIT", DEFAULT_L2_GAS_LIMIT);
        uint256 l2GasPerPubdata = vm.envOr("L2_GAS_PER_PUBDATA", DEFAULT_L2_GAS_PER_PUBDATA);
        uint256 padBps = vm.envOr("BASE_COST_BPS_PAD", DEFAULT_BASE_COST_BPS_PAD);

        gasPrice = tx.gasprice;
        if (gasPrice == 0) {
            gasPrice = 1 gwei;
        }

        baseCost = IBridgehub(SEPOLIA_BRIDGEHUB).l2TransactionBaseCost(
            BC_TESTNET_CHAIN_ID, gasPrice, l2GasLimit, l2GasPerPubdata
        );
        mintValue = baseCost + (baseCost * padBps) / 10_000 + amount;
    }

    /// @dev Foundry default `msg.sender` when `--sender` is omitted.
    address internal constant FOUNDRY_DEFAULT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    function _broadcastDeposit(uint256 amount, uint256 mintValue) internal returns (bytes32 canonicalTxHash) {
        address recipient = vm.envOr("L2_RECIPIENT", address(0));
        uint256 l2GasLimit = vm.envOr("L2_GAS_LIMIT", DEFAULT_L2_GAS_LIMIT);
        uint256 l2GasPerPubdata = vm.envOr("L2_GAS_PER_PUBDATA", DEFAULT_L2_GAS_PER_PUBDATA);

        vm.startBroadcast();

        address broadcaster = msg.sender;
        if (recipient == address(0)) {
            recipient = broadcaster;
        }

        require(recipient != FOUNDRY_DEFAULT_SENDER, "Script_Bridge: L2 recipient is Foundry default sender; set L2_RECIPIENT and --sender to your deployer");
        require(broadcaster != FOUNDRY_DEFAULT_SENDER, "Script_Bridge: broadcaster is Foundry default sender; pass --sender $(cast wallet address --account deployer)");
        require(broadcaster.balance >= mintValue, "Script_Bridge: insufficient Sepolia ETH for mintValue");

        console2.log("l2Recipient", recipient);
        console2.log("broadcaster", broadcaster);

        bytes[] memory factoryDeps = new bytes[](0);
        canonicalTxHash = IBridgehub(SEPOLIA_BRIDGEHUB).requestL2TransactionDirect{value: mintValue}(
            IBridgehub.L2TransactionRequestDirect({
                chainId: BC_TESTNET_CHAIN_ID,
                mintValue: mintValue,
                l2Contract: recipient,
                l2Value: amount,
                l2Calldata: "",
                l2GasLimit: l2GasLimit,
                l2GasPerPubdataByteLimit: l2GasPerPubdata,
                factoryDeps: factoryDeps,
                refundRecipient: broadcaster
            })
        );

        vm.stopBroadcast();
    }
}
