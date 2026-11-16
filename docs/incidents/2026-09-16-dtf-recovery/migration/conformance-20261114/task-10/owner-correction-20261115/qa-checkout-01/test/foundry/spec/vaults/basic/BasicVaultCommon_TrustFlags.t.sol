// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";

import {BasicVaultCommon} from "contracts/vaults/basic/BasicVaultCommon.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
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

/// @notice Production-storage harness: MultiAssetBasicVaultRepo + BasicVaultCommon.
contract BasicVaultCommonTrustFlagsHarness is BasicVaultCommon {
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

/* -------------------------------------------------------------------------- */
/*                               Test Suite                                   */
/* -------------------------------------------------------------------------- */

/**
 * @title BasicVaultCommon_TrustFlags_Test
 * @notice Catalog I1/I2/I3 under reserve-delta law (booked inventory baseline).
 * @dev I1: R == B (booked), pretransferred=true, no new push → TransferDeltaInsufficient(claimed, 0)
 *      I2: claimed > U
 *      I3: after money route sync, residual is absorbed into R → cannot fund second free pretransfer
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
        token = new TrustFlagMockToken();
        address[] memory hold = new address[](1);
        hold[0] = address(token);
        harness = new BasicVaultCommonTrustFlagsHarness(PERMIT2_PRODUCTION, hold);
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: booked inventory, no new unbooked inflow, pretransferred=true     */
    /* ---------------------------------------------------------------------- */

    /// @notice I1: seed + sync so R==B; attacker does not transfer; pretransferred=true reverts (claimed, 0).
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        token.mint(address(harness), CLAIMED);
        harness.syncAllExpectedHoldReserves(); // book → U = 0
        assertEq(token.balanceOf(address(harness)), CLAIMED);
        assertEq(token.balanceOf(attacker), 0);
        assertEq(token.allowance(attacker, address(harness)), 0);

        uint256 balBefore = token.balanceOf(address(harness));

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, CLAIMED, uint256(0))
        );
        harness.secureTokenTransfer(token, CLAIMED, true);

        assertEq(token.balanceOf(address(harness)), balBefore, "I1 must not transfer in-call");
        assertEq(token.balanceOf(attacker), 0);
    }

    /// @notice I1 variant: claimed strictly less than booked inventory still fails.
    function test_I1_pretransferred_claimedLeInventory_stillReverts() public {
        token.mint(address(harness), INVENTORY + CLAIMED);
        harness.syncAllExpectedHoldReserves();
        uint256 claimed = INVENTORY;

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, uint256(0))
        );
        harness.secureTokenTransfer(token, claimed, true);
    }

    /* ---------------------------------------------------------------------- */
    /*  I2: claimed > U                                                       */
    /* ---------------------------------------------------------------------- */

    /// @notice I2: booked R==B so U=0; claimed > 0 reverts with observedDelta 0.
    function test_I2_pretransferred_claimedGtDelta0_reverts() public {
        token.mint(address(harness), DEPOSIT);
        harness.syncAllExpectedHoldReserves();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, DEPOSIT, uint256(0))
        );
        harness.secureTokenTransfer(token, DEPOSIT, true);
    }

    /// @notice I2: short delivery under !pretransferred returns partial delta only.
    function test_I2_pull_shortDelivery_returnsObservedDeltaOnly() public {
        uint256 shortAmt = 40e18;
        ShortDeliveryMockToken shortToken = new ShortDeliveryMockToken(shortAmt);
        address[] memory hold = new address[](1);
        hold[0] = address(shortToken);
        BasicVaultCommonTrustFlagsHarness shortHarness =
            new BasicVaultCommonTrustFlagsHarness(PERMIT2_PRODUCTION, hold);

        shortToken.mint(alice, DEPOSIT);
        shortToken.mint(address(shortHarness), INVENTORY);

        vm.startPrank(alice);
        shortToken.approve(address(shortHarness), DEPOSIT);
        uint256 actual = shortHarness.secureTokenTransfer(IERC20(address(shortToken)), DEPOSIT, false);
        vm.stopPrank();

        assertEq(actual, shortAmt, "must credit observed delta only, not claimed or absolute inventory");
        assertEq(shortToken.balanceOf(address(shortHarness)), INVENTORY + shortAmt);
    }

    /* ---------------------------------------------------------------------- */
    /*  I3: residual after moneyIn sync cannot fund second free pretransfer   */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: after honest pull + full-set sync, residual is booked; second true fails.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        token.mint(alice, DEPOSIT);
        token.mint(address(harness), INVENTORY);

        vm.startPrank(alice);
        token.approve(address(harness), DEPOSIT);
        uint256 first = harness.moneyIn(token, DEPOSIT, false);
        vm.stopPrank();

        assertEq(first, DEPOSIT);
        uint256 residual = token.balanceOf(address(harness));
        assertEq(residual, INVENTORY + DEPOSIT);
        // After moneyIn sync, residual is absorbed into R → U = 0
        assertEq(harness.bookedReserve(token), residual);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, DEPOSIT, uint256(0))
        );
        harness.secureTokenTransfer(token, DEPOSIT, true);

        assertEq(token.balanceOf(address(harness)), residual, "I3 second call must not move inventory");
    }
}
