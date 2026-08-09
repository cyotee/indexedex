// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";

import {BasicVaultCommon} from "contracts/vaults/basic/BasicVaultCommon.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

/* -------------------------------------------------------------------------- */
/*                               Mock Tokens                                  */
/* -------------------------------------------------------------------------- */

/// @notice Standard mock ERC20 for trust-flag catalog tests.
contract TrustFlagMockToken is IERC20 {
    string public name = "TrustFlagMock";
    string public symbol = "TFM";
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

/// @notice Delivers only `shortAmount` on transferFrom (short delivery for I2).
contract ShortDeliveryMockToken is IERC20 {
    string public name = "ShortDelivery";
    string public symbol = "SHORT";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public shortAmount;

    constructor(uint256 shortAmount_) {
        shortAmount = shortAmount_;
    }

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

    /// @dev Always delivers only `shortAmount` to `to` (pulls `shortAmount` from `from`).
    function transferFrom(address from, address to, uint256 /* amount */) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            // Do not require full claimed allowance accounting for short path
            allowance[from][msg.sender] = 0;
        }
        balanceOf[from] -= shortAmount;
        balanceOf[to] += shortAmount;
        return true;
    }
}

/* -------------------------------------------------------------------------- */
/*                               Harness                                      */
/* -------------------------------------------------------------------------- */

/// @notice Minimal harness exposing BasicVaultCommon._secureTokenTransfer for I-catalog tests.
contract BasicVaultCommonTrustFlagsHarness is BasicVaultCommon {
    constructor(IPermit2 permit2_) {
        Permit2AwareRepo._initialize(permit2_);
    }

    function secureTokenTransfer(IERC20 tokenIn_, uint256 amount_, bool pretransferred_) external returns (uint256) {
        return _secureTokenTransfer(tokenIn_, amount_, pretransferred_);
    }
}

/* -------------------------------------------------------------------------- */
/*                               Test Suite                                   */
/* -------------------------------------------------------------------------- */

/**
 * @title BasicVaultCommon_TrustFlags_Test
 * @notice Catalog I1/I2/I3: pretransfer trust flags must not free-credit inventory (L-GAPS-9/10).
 * @dev I1: pretransferred=true, no transfer in-call, inventory present → TransferDeltaInsufficient(claimed, 0)
 *      I2: claimed > observedDelta (short / zero delta)
 *      I3: residual inventory after a prior path cannot fund a second free pretransfer credit
 */
contract BasicVaultCommon_TrustFlags_Test is Test {
    BasicVaultCommonTrustFlagsHarness internal harness;
    TrustFlagMockToken internal token;

    IPermit2 internal constant PERMIT2_PRODUCTION = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    address internal alice = makeAddr("alice");
    address internal attacker = makeAddr("attacker");

    uint256 internal constant INVENTORY = 50e18;
    uint256 internal constant CLAIMED = 100e18;
    uint256 internal constant DEPOSIT = 100e18;

    function setUp() public {
        harness = new BasicVaultCommonTrustFlagsHarness(PERMIT2_PRODUCTION);
        token = new TrustFlagMockToken();
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: inventory present, no in-call transfer, pretransferred=true       */
    /* ---------------------------------------------------------------------- */

    /// @notice I1: mint inventory to harness; attacker does not transfer; pretransferred=true;
    ///         claimed <= inventory still reverts TransferDeltaInsufficient(claimed, 0).
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        // Inventory >= claimed so absolute-balance theater would have passed
        token.mint(address(harness), CLAIMED);
        assertEq(token.balanceOf(address(harness)), CLAIMED);
        assertEq(token.balanceOf(attacker), 0);
        assertEq(token.allowance(attacker, address(harness)), 0);

        uint256 balBefore = token.balanceOf(address(harness));

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, CLAIMED, uint256(0)
            )
        );
        harness.secureTokenTransfer(token, CLAIMED, true);

        // No in-call transfer: inventory unchanged
        assertEq(token.balanceOf(address(harness)), balBefore, "I1 must not transfer in-call");
        assertEq(token.balanceOf(attacker), 0);
    }

    /// @notice I1 variant: claimed strictly less than inventory still fails (absolute coverage forbidden).
    function test_I1_pretransferred_claimedLeInventory_stillReverts() public {
        token.mint(address(harness), INVENTORY + CLAIMED);
        uint256 claimed = INVENTORY; // claimed < inventory

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, uint256(0)
            )
        );
        harness.secureTokenTransfer(token, claimed, true);
    }

    /* ---------------------------------------------------------------------- */
    /*  I2: short delivery — claimed > observedDelta                          */
    /* ---------------------------------------------------------------------- */

    /// @notice I2: claimed > 0 with observedDelta 0 (pretransferred, no inbound).
    function test_I2_pretransferred_claimedGtDelta0_reverts() public {
        token.mint(address(harness), DEPOSIT);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, DEPOSIT, uint256(0)
            )
        );
        harness.secureTokenTransfer(token, DEPOSIT, true);
    }

    /// @notice I2: short delivery under !pretransferred returns partial delta (FoT-safe path),
    ///         not free credit of inventory. Demonstrates delta observation, not absolute balance.
    function test_I2_pull_shortDelivery_returnsObservedDeltaOnly() public {
        uint256 shortAmt = 40e18;
        ShortDeliveryMockToken shortToken = new ShortDeliveryMockToken(shortAmt);
        shortToken.mint(alice, DEPOSIT);

        // Seed extra inventory so absolute balance >> short delivery
        shortToken.mint(address(harness), INVENTORY);

        vm.startPrank(alice);
        shortToken.approve(address(harness), DEPOSIT);
        uint256 actual = harness.secureTokenTransfer(IERC20(address(shortToken)), DEPOSIT, false);
        vm.stopPrank();

        assertEq(actual, shortAmt, "must credit observed delta only, not claimed or absolute inventory");
        assertEq(shortToken.balanceOf(address(harness)), INVENTORY + shortAmt);
    }

    /* ---------------------------------------------------------------------- */
    /*  I3: residual inventory cannot fund second free pretransfer credit     */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: after an honest pull leaves residual inventory, a second pretransferred call
    ///         with no new inbound delta cannot free-credit residual.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        token.mint(alice, DEPOSIT);
        // Pre-seed residual that will remain after first pull
        token.mint(address(harness), INVENTORY);

        vm.startPrank(alice);
        token.approve(address(harness), DEPOSIT);
        uint256 first = harness.secureTokenTransfer(token, DEPOSIT, false);
        vm.stopPrank();

        assertEq(first, DEPOSIT);
        uint256 residual = token.balanceOf(address(harness));
        assertEq(residual, INVENTORY + DEPOSIT);
        assertGe(residual, DEPOSIT);

        // Second call: pretransferred=true, claim against residual, no new transfer
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, DEPOSIT, uint256(0)
            )
        );
        harness.secureTokenTransfer(token, DEPOSIT, true);

        assertEq(token.balanceOf(address(harness)), residual, "I3 second call must not move inventory");
    }
}
