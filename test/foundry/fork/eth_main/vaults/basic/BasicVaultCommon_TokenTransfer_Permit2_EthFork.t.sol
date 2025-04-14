// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {ETHEREUM_MAIN} from "@crane/contracts/constants/networks/ETHEREUM_MAIN.sol";

import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";

import {BasicVaultCommon} from "contracts/vaults/basic/BasicVaultCommon.sol";

/* -------------------------------------------------------------------------- */
/*                               Fork Fixture                                 */
/* -------------------------------------------------------------------------- */

contract TestBase_EthereumFork is Test {
    uint256 internal constant ETH_CHAIN_ID = 1;

    // Pinned fork block for determinism.
    // NOTE: Base mainnet uses 40_446_736 in its fork fixtures; Ethereum mainnet block numbers
    // are different. Keep this comfortably below current mainnet head.
    uint256 internal constant DEFAULT_FORK_BLOCK = 20_000_000;

    string internal constant ETH_RPC_ENDPOINT = "ethereum_mainnet_infura";

    uint256 internal ethForkId;
    uint256 internal forkBlock;

    function setUp() public virtual {
        forkBlock = _getForkBlock();

        if (forkBlock > 0) {
            ethForkId = vm.createSelectFork(ETH_RPC_ENDPOINT, forkBlock);
        } else {
            ethForkId = vm.createSelectFork(ETH_RPC_ENDPOINT);
            forkBlock = block.number;
        }

        assertEq(block.chainid, ETH_CHAIN_ID, "Fork should be on Ethereum mainnet (chainid 1)");
    }

    function _getForkBlock() internal view returns (uint256 blockNumber) {
        try vm.envUint("ETH_FORK_BLOCK") returns (uint256 envBlock) {
            return envBlock;
        } catch {
            return DEFAULT_FORK_BLOCK;
        }
    }
}

/* -------------------------------------------------------------------------- */
/*                               Test Tokens                                  */
/* -------------------------------------------------------------------------- */

contract FeeOnTransferMockToken is IERC20 {
    string public name = "FeeToken";
    string public symbol = "FEE";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public constant FEE_BPS = 100; // 1%

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        uint256 fee = (amount * FEE_BPS) / 10_000;
        uint256 net = amount - fee;
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += net;
        totalSupply -= fee;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        uint256 fee = (amount * FEE_BPS) / 10_000;
        uint256 net = amount - fee;
        balanceOf[from] -= amount;
        balanceOf[to] += net;
        totalSupply -= fee;
        return true;
    }
}

/* -------------------------------------------------------------------------- */
/*                               Harness                                      */
/* -------------------------------------------------------------------------- */

contract BasicVaultCommonHarness is BasicVaultCommon {
    constructor(IPermit2 permit2_) {
        Permit2AwareRepo._initialize(permit2_);
    }

    function secureTokenTransfer(IERC20 tokenIn_, uint256 amount_, bool pretransferred_) external returns (uint256) {
        return _secureTokenTransfer(tokenIn_, amount_, pretransferred_);
    }
}

/* -------------------------------------------------------------------------- */
/*                               Fork Tests                                   */
/* -------------------------------------------------------------------------- */

contract BasicVaultCommon_TokenTransfer_Permit2_EthFork_Test is TestBase_EthereumFork {
    BasicVaultCommonHarness internal harness;

    IERC20 internal constant WETH = IERC20(ETHEREUM_MAIN.WETH9);
    IPermit2 internal constant PERMIT2 = IPermit2(ETHEREUM_MAIN.PERMIT2);

    address internal alice = makeAddr("alice");

    uint256 internal constant DEPOSIT = 1e18;

    function setUp() public override {
        super.setUp();

        assertTrue(address(PERMIT2).code.length > 0, "PERMIT2 must have code");

        harness = new BasicVaultCommonHarness(PERMIT2);
    }

    function test_sanity_forkIsValid() public view {
        assertEq(block.chainid, ETH_CHAIN_ID, "Should be on Ethereum mainnet");
        assertGt(forkBlock, 0, "Fork block should be set");
        assertTrue(address(PERMIT2).code.length > 0, "PERMIT2 must have code");
        assertTrue(address(WETH).code.length > 0, "WETH must have code");
    }

    function test_fork_secureTokenTransfer_permit2Path_erc20_ethereum() public {
        deal(address(WETH), alice, DEPOSIT);

        vm.startPrank(alice);
        WETH.approve(address(harness), DEPOSIT - 1);
        WETH.approve(address(PERMIT2), DEPOSIT);
        PERMIT2.approve(address(WETH), address(harness), uint160(DEPOSIT), type(uint48).max);

        uint256 actual = harness.secureTokenTransfer(WETH, DEPOSIT, false);
        vm.stopPrank();

        assertEq(actual, DEPOSIT, "actualIn should equal amount for non-fee token");
        assertEq(WETH.balanceOf(address(harness)), DEPOSIT);
    }

    function test_fork_secureTokenTransfer_permit2Path_feeOnTransfer_ethereum() public {
        FeeOnTransferMockToken feeToken = new FeeOnTransferMockToken();
        feeToken.mint(alice, DEPOSIT);

        vm.startPrank(alice);
        IERC20(address(feeToken)).approve(address(harness), DEPOSIT - 1);
        IERC20(address(feeToken)).approve(address(PERMIT2), DEPOSIT);
        PERMIT2.approve(address(feeToken), address(harness), uint160(DEPOSIT), type(uint48).max);

        uint256 expectedFee = (DEPOSIT * 100) / 10_000;
        uint256 expectedNet = DEPOSIT - expectedFee;

        uint256 actual = harness.secureTokenTransfer(IERC20(address(feeToken)), DEPOSIT, false);
        vm.stopPrank();

        assertEq(actual, expectedNet, "actualIn should be net of fee");
        assertEq(IERC20(address(feeToken)).balanceOf(address(harness)), expectedNet);
    }

    function test_fork_secureTokenTransfer_pretransferred_erc20_ethereum() public {
        // Pre-transfer WETH to the harness and ensure pretransferred path returns amount directly
        deal(address(WETH), alice, DEPOSIT);

        vm.prank(alice);
        WETH.transfer(address(harness), DEPOSIT);

        vm.prank(alice);
        uint256 actual = harness.secureTokenTransfer(WETH, DEPOSIT, true);

        assertEq(actual, DEPOSIT, "pretransferred should return amount_ directly");
        assertEq(WETH.balanceOf(address(harness)), DEPOSIT);
    }

    function test_fork_secureTokenTransfer_pretransferred_feeOnTransfer_ethereum() public {
        // Use local fee-on-transfer token and pretransfer to harness.
        // For fee-on-transfer tokens, the harness only receives the net amount.
        // In the pretransferred path, callers must pass the *actual* amount received.
        FeeOnTransferMockToken feeToken = new FeeOnTransferMockToken();

        feeToken.mint(alice, DEPOSIT);

        vm.prank(alice);
        IERC20(address(feeToken)).transfer(address(harness), DEPOSIT);

        vm.prank(alice);
        uint256 expectedFee = (DEPOSIT * 100) / 10_000;
        uint256 expectedNet = DEPOSIT - expectedFee;

        uint256 actual = harness.secureTokenTransfer(IERC20(address(feeToken)), expectedNet, true);

        assertEq(actual, expectedNet, "pretransferred should return amount_ directly");
        assertEq(IERC20(address(feeToken)).balanceOf(address(harness)), expectedNet);
    }
}
