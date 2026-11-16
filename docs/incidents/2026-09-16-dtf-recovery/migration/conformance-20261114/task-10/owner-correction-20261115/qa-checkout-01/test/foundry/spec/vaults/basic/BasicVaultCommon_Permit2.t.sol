// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterPermit2} from "@crane/contracts/protocols/utils/permit2/BetterPermit2.sol";
import {BasicVaultCommon} from "contracts/vaults/basic/BasicVaultCommon.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

/// @notice Local harness (unique name) to avoid duplicate symbol conflicts with other test files.
contract BasicVaultCommonPermit2Harness is BasicVaultCommon {
    constructor(IPermit2 permit2_, address[] memory expectedHoldTokens_) {
        Permit2AwareRepo._initialize(permit2_);
        MultiAssetBasicVaultRepo._initialize(expectedHoldTokens_);
    }

    function secureTokenTransfer(IERC20 tokenIn_, uint256 amount_, bool pretransferred_) external returns (uint256) {
        return _secureTokenTransfer(tokenIn_, amount_, pretransferred_);
    }

    function syncAllExpectedHoldReserves() external {
        _syncAllExpectedHoldReserves();
    }

    function moneyIn(IERC20 token_, uint256 claimed_, bool pretransferred_) external returns (uint256 credit_) {
        credit_ = _secureTokenTransfer(token_, claimed_, pretransferred_);
        _syncAllExpectedHoldReserves();
    }

    function bookedReserve(IERC20 token_) external view returns (uint256) {
        return _bookedReserve(token_);
    }
}

// Local mocks (unique names to avoid symbol collisions with other test files)
contract MockTokenPermit2 is IERC20 {
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

contract FeeOnTransferMockTokenPermit2 is IERC20 {
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

contract BasicVaultCommon_Permit2 is Test {
    BasicVaultCommonPermit2Harness internal harness;
    BetterPermit2 internal permit2;
    MockTokenPermit2 internal token;
    FeeOnTransferMockTokenPermit2 internal feeToken;

    uint256 internal constant DUST = 50e18;
    uint256 internal constant DEPOSIT = 100e18;

    address internal alice = makeAddr("alice");

    function setUp() public {
        permit2 = new BetterPermit2();
        token = new MockTokenPermit2();
        feeToken = new FeeOnTransferMockTokenPermit2();

        address[] memory hold = new address[](1);
        hold[0] = address(token);
        harness = new BasicVaultCommonPermit2Harness(IPermit2(address(permit2)), hold);
    }

    /// @notice Permit2 path: when user has not given ERC20 allowance, Permit2.transferFrom is used.
    function test_permit2_transfer_success() public {
        token.mint(alice, DEPOSIT);

        vm.prank(alice);
        token.approve(address(permit2), DEPOSIT);

        vm.prank(alice);
        permit2.approve(address(token), address(harness), uint160(DEPOSIT), type(uint48).max);

        vm.startPrank(alice);
        uint256 actual = harness.moneyIn(token, DEPOSIT, false);
        vm.stopPrank();

        assertEq(actual, DEPOSIT, "actualIn should equal requested deposit");
        assertEq(token.balanceOf(address(harness)), DEPOSIT);
        assertEq(harness.bookedReserve(token), DEPOSIT, "INV-R1 after moneyIn");
    }

    /// @notice Permit2 + fee-on-transfer: vault should observe net received amount.
    function test_permit2_feeOnTransfer_returnsNetAmount() public {
        uint256 expectedFee = (DEPOSIT * 100) / 10_000;
        uint256 expectedNet = DEPOSIT - expectedFee;

        address[] memory hold = new address[](1);
        hold[0] = address(feeToken);
        BasicVaultCommonPermit2Harness feeHarness =
            new BasicVaultCommonPermit2Harness(IPermit2(address(permit2)), hold);

        feeToken.mint(alice, DEPOSIT);

        vm.prank(alice);
        feeToken.approve(address(permit2), DEPOSIT);

        vm.prank(alice);
        permit2.approve(address(feeToken), address(feeHarness), uint160(DEPOSIT), type(uint48).max);

        vm.startPrank(alice);
        uint256 actual = feeHarness.secureTokenTransfer(IERC20(address(feeToken)), DEPOSIT, false);
        vm.stopPrank();

        assertEq(actual, expectedNet, "actualIn should reflect fee-on-transfer deduction");
        assertEq(IERC20(address(feeToken)).balanceOf(address(feeHarness)), expectedNet);
    }

    /// @notice Pretransferred with booked inventory (R==B) → TransferDeltaInsufficient(claimed, 0).
    function test_pretransferred_returnsAmount() public {
        token.mint(address(harness), DUST + DEPOSIT);
        harness.syncAllExpectedHoldReserves();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, DEPOSIT, uint256(0))
        );
        harness.secureTokenTransfer(token, DEPOSIT, true);
    }

    /// @notice Pretransferred shortfall: claimed > U uses exact U args.
    function test_pretransferred_insufficientBalance_reverts() public {
        // Unbooked inventory U = DEPOSIT-1 (R=0)
        token.mint(address(harness), DEPOSIT - 1);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, DEPOSIT, DEPOSIT - 1
            )
        );
        harness.secureTokenTransfer(token, DEPOSIT, true);
    }

    /// @notice Push + pretransferred=true happy path under Permit2-initialized harness.
    function test_push_pretransferred_happy() public {
        token.mint(alice, DEPOSIT);
        vm.prank(alice);
        token.transfer(address(harness), DEPOSIT);

        vm.prank(alice);
        uint256 credit = harness.moneyIn(token, DEPOSIT, true);
        assertEq(credit, DEPOSIT);
        assertEq(harness.bookedReserve(token), DEPOSIT);
    }
}
