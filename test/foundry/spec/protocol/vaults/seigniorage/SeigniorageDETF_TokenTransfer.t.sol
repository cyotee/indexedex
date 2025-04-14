// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {SeigniorageDETFCommon} from "contracts/vaults/seigniorage/SeigniorageDETFCommon.sol";

/* -------------------------------------------------------------------------- */
/*                               Mock Tokens                                  */
/* -------------------------------------------------------------------------- */

/// @notice Standard mock ERC20 for testing normal transfers.
contract MockToken is IERC20 {
    string public name = "MockToken";
    string public symbol = "MCK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// @notice Fee-on-transfer mock: burns 1% of every transfer as a tax.
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
        totalSupply -= fee; // burned
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
        totalSupply -= fee; // burned
        return true;
    }
}

/* -------------------------------------------------------------------------- */
/*                               Harness                                      */
/* -------------------------------------------------------------------------- */

/// @notice Minimal harness exposing SeigniorageDETFCommon._secureTokenTransfer.
/// @dev Permit2AwareRepo is not initialized here because tests only exercise
///      the ERC20 allowance path (allowance >= amount).
contract SecureTokenTransferHarness is SeigniorageDETFCommon {
    /// @notice Exposes the internal _secureTokenTransfer for testing.
    function secureTokenTransfer(IERC20 tokenIn_, uint256 amount_, bool pretransferred_) external returns (uint256) {
        return _secureTokenTransfer(tokenIn_, amount_, pretransferred_);
    }
}

/* -------------------------------------------------------------------------- */
/*                               Test Suite                                   */
/* -------------------------------------------------------------------------- */

/**
 * @title SeigniorageDETF_TokenTransfer_Test
 * @notice Regression tests for IDXEX-029: balance-delta accounting in _secureTokenTransfer.
 * @dev Ensures that pre-existing dust in the vault does not inflate deposit credits,
 *      and that fee-on-transfer tokens return the correct actual received amount.
 */
contract SeigniorageDETF_TokenTransfer_Test is Test {
    SecureTokenTransferHarness internal harness;
    MockToken internal token;
    FeeOnTransferMockToken internal feeToken;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant DUST = 50e18;
    uint256 internal constant DEPOSIT = 100e18;

    function setUp() public {
        harness = new SecureTokenTransferHarness();

        token = new MockToken();
        feeToken = new FeeOnTransferMockToken();
    }

    /* ---------------------------------------------------------------------- */
    /*  US-IDXEX-029.1: Balance-delta accounting                              */
    /* ---------------------------------------------------------------------- */

    /// @notice Vault with pre-existing dust: deposit should return delta, not full balance.
    function test_secureTokenTransfer_dustDoesNotInflateCredit() public {
        // Seed the harness (vault) with dust
        token.mint(address(harness), DUST);
        assertEq(token.balanceOf(address(harness)), DUST);

        // Alice deposits via ERC20 allowance
        token.mint(alice, DEPOSIT);
        vm.startPrank(alice);
        token.approve(address(harness), DEPOSIT);
        uint256 actual = harness.secureTokenTransfer(token, DEPOSIT, false);
        vm.stopPrank();

        // Must return only the deposit delta, not dust + deposit
        assertEq(actual, DEPOSIT, "actualIn should equal deposit, ignoring dust");

        // Total balance is now dust + deposit
        assertEq(token.balanceOf(address(harness)), DUST + DEPOSIT);
    }

    /// @notice Standard ERC20 path returns exact transfer amount (no dust).
    function test_secureTokenTransfer_erc20Path_noDust() public {
        token.mint(alice, DEPOSIT);

        vm.startPrank(alice);
        token.approve(address(harness), DEPOSIT);
        uint256 actual = harness.secureTokenTransfer(token, DEPOSIT, false);
        vm.stopPrank();

        assertEq(actual, DEPOSIT, "actualIn should match transferred amount");
        assertEq(token.balanceOf(address(harness)), DEPOSIT);
    }

    /// @notice Pretransferred path returns amount_ without performing transfer.
    function test_secureTokenTransfer_pretransferred_returnsAmount() public {
        // Transfer tokens to harness beforehand (simulating pre-transfer)
        token.mint(address(harness), DEPOSIT);

        // Also seed dust to ensure pretransferred doesn't read balance
        token.mint(address(harness), DUST);

        vm.prank(alice);
        uint256 actual = harness.secureTokenTransfer(token, DEPOSIT, true);

        // Pretransferred should return the stated amount, regardless of balance
        assertEq(actual, DEPOSIT, "pretransferred should return amount_ directly");
    }

    /* ---------------------------------------------------------------------- */
    /*  US-IDXEX-029.2: Fee-on-transfer token scenario                        */
    /* ---------------------------------------------------------------------- */

    /// @notice Fee-on-transfer token: actualIn should be less than requested amount.
    function test_secureTokenTransfer_feeOnTransfer_returnsNetAmount() public {
        uint256 expectedFee = (DEPOSIT * 100) / 10_000; // 1%
        uint256 expectedNet = DEPOSIT - expectedFee;

        feeToken.mint(alice, DEPOSIT);

        vm.startPrank(alice);
        IERC20(address(feeToken)).approve(address(harness), DEPOSIT);
        uint256 actual = harness.secureTokenTransfer(IERC20(address(feeToken)), DEPOSIT, false);
        vm.stopPrank();

        assertEq(actual, expectedNet, "actualIn should reflect fee-on-transfer deduction");
        assertEq(IERC20(address(feeToken)).balanceOf(address(harness)), expectedNet);
    }

    /// @notice Fee-on-transfer with pre-existing dust: only delta is reported.
    function test_secureTokenTransfer_feeOnTransfer_withDust() public {
        uint256 expectedFee = (DEPOSIT * 100) / 10_000; // 1%
        uint256 expectedNet = DEPOSIT - expectedFee;

        // Seed dust
        feeToken.mint(address(harness), DUST);

        feeToken.mint(alice, DEPOSIT);

        vm.startPrank(alice);
        IERC20(address(feeToken)).approve(address(harness), DEPOSIT);
        uint256 actual = harness.secureTokenTransfer(IERC20(address(feeToken)), DEPOSIT, false);
        vm.stopPrank();

        assertEq(actual, expectedNet, "actualIn should be net of fee, ignoring dust");
        assertEq(IERC20(address(feeToken)).balanceOf(address(harness)), DUST + expectedNet);
    }
}
