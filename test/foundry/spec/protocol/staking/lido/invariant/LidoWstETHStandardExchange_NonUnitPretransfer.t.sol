// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ERC20} from "@crane/contracts/external/openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_LidoWstETHStandardExchange} from "contracts/test/bases/TestBase_LidoWstETHStandardExchange.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

/// @dev External receipt port with non-unit, floor-rounded conversions. The production SE
/// is deployed through its existing registry package and never replaced with a SUT mock.
contract NonUnitAccountingWstETH is ERC20 {
    IERC20 public immutable stETH;
    uint256 public constant RATE = 1.5 ether;
    constructor(IERC20 st_) ERC20("Rate wstETH", "rwst") { stETH = st_; }
    function getWstETHByStETH(uint256 assets_) public pure returns (uint256) { return Math.mulDiv(assets_, 1 ether, RATE); }
    function getStETHByWstETH(uint256 shares_) public pure returns (uint256) { return Math.mulDiv(shares_, RATE, 1 ether); }
    function stEthPerToken() external pure returns (uint256) { return RATE; }
    function tokensPerStEth() external pure returns (uint256) { return 1 ether * 1 ether / RATE; }
    function wrap(uint256 assets_) external returns (uint256 shares_) {
        stETH.transferFrom(msg.sender, address(this), assets_);
        shares_ = getWstETHByStETH(assets_); _mint(msg.sender, shares_);
    }
    function unwrap(uint256 shares_) external returns (uint256 assets_) {
        _burn(msg.sender, shares_); assets_ = getStETHByWstETH(shares_); stETH.transfer(msg.sender, assets_);
    }
}

contract LidoWstETHStandardExchange_NonUnitPretransfer is TestBase_LidoWstETHStandardExchange {
    NonUnitAccountingWstETH internal wrapped;
    address internal vault;
    AtomicPretransferCaller internal integrator;

    function setUp() public override {
        super.setUp();
        wrapped = new NonUnitAccountingWstETH(IERC20(address(hermeticStEth)));
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        vault = lidoSeDFPkg.deployVault(address(hermeticStEth), address(wrapped), address(hermeticWeth), address(hermeticQueue));
        vm.stopPrank();
        integrator = new AtomicPretransferCaller();
        _fund(IERC20(address(wrapped)), 2 ether);
        wrapped.approve(vault, 2 ether);
        uint256 issued = IStandardExchangeIn(vault).exchangeIn(IERC20(address(wrapped)), 2 ether, IERC20(vault), 1, address(this), false, block.timestamp);
        assertEq(issued, 3 ether * 1000, "initial receipt value with package virtual offset");
    }

    function _fund(IERC20 token_, uint256 amount_) internal {
        if (address(token_) == address(wrapped)) {
            uint256 assets = Math.mulDiv(amount_, 1.5 ether, 1 ether, Math.Rounding.Ceil);
            hermeticStEth.mint(address(this), assets);
            hermeticStEth.approve(address(wrapped), assets);
            assertGe(wrapped.wrap(assets), amount_, "real receipt funding");
        } else hermeticStEth.mint(address(this), amount_);
    }

    function _required(IERC20 token_, uint256 desired_) internal view returns (uint256) {
        uint256 nav = wrapped.getStETHByWstETH(wrapped.balanceOf(vault));
        uint256 ethRequired = Math.mulDiv(desired_, nav + 1, IERC20(vault).totalSupply() + 1000, Math.Rounding.Ceil);
        uint256 receiptRequired = Math.mulDiv(ethRequired, 1 ether, 1.5 ether, Math.Rounding.Ceil);
        return address(token_) == address(wrapped) ? receiptRequired : Math.mulDiv(receiptRequired, 1.5 ether, 1 ether, Math.Rounding.Ceil);
    }

    function _mint(IERC20 token_, uint256 maximum_, uint256 desired_, bool prepaid_) internal returns (uint256) {
        _fund(token_, maximum_);
        if (!prepaid_) {
            token_.approve(vault, maximum_);
            return IStandardExchangeOut(vault).exchangeOut(token_, maximum_, IERC20(vault), desired_, address(this), false, block.timestamp);
        }
        token_.approve(address(integrator), maximum_);
        bytes memory data = abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (token_, maximum_, IERC20(vault), desired_, address(this), true, block.timestamp));
        return abi.decode(integrator.consumePretransfer(token_, address(this), vault, maximum_, data), (uint256));
    }

    function _assertExactOut(IERC20 token_) internal {
        uint256 desired = 1001; // needs 2 wei ETH, whose floor wrapped inverse would underfund by one wei.
        uint256 expected = _required(token_, desired);
        assertGt(expected, 0);
        assertEq(IStandardExchangeOut(vault).previewExchangeOut(token_, IERC20(vault), desired), expected, "independent ceil inverse");
        uint256 snapshot = vm.snapshotState();
        assertEq(_mint(token_, expected, desired, false), expected, "funded pull accepts exact quote");
        assertTrue(vm.revertToState(snapshot));
        uint256 beforeShares = IERC20(vault).balanceOf(address(this));
        uint256 maximum = expected + 7;
        assertEq(_mint(token_, maximum, desired, true), expected, "atomic quote matches prior pull");
        assertEq(IERC20(vault).balanceOf(address(this)) - beforeShares, desired, "only exact shares issued");
        assertEq(token_.balanceOf(address(integrator)), maximum - expected, "only bounded unused credit refunded");
    }

    function test_APEX_nonUnitWrappedExactOutCeilAndPretransfer() public { _assertExactOut(IERC20(address(wrapped))); }
    function test_APEX_nonUnitUnderlyingWrapExactOutCeilAndPretransfer() public { _assertExactOut(IERC20(address(hermeticStEth))); }

    function _exactIn(IERC20 token_, uint256 amount_, uint256 minimum_, bool prepaid_) internal returns (uint256) {
        _fund(token_, amount_);
        if (!prepaid_) {
            token_.approve(vault, amount_);
            return IStandardExchangeIn(vault).exchangeIn(token_, amount_, IERC20(vault), minimum_, address(this), false, block.timestamp);
        }
        token_.approve(address(integrator), amount_);
        bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (token_, amount_, IERC20(vault), minimum_, address(this), true, block.timestamp));
        return abi.decode(integrator.consumePretransfer(token_, address(this), vault, amount_, data), (uint256));
    }

    function _assertExactIn(IERC20 token_, uint256 amount_, uint256 credited_) internal {
        uint256 expected = Math.mulDiv(credited_, IERC20(vault).totalSupply() + 1000,
            wrapped.getStETHByWstETH(wrapped.balanceOf(vault)) + 1);
        uint256 quote = IStandardExchangeIn(vault).previewExchangeIn(token_, amount_, IERC20(vault));
        uint256 snapshot = vm.snapshotState();
        assertEq(_exactIn(token_, amount_, expected, false), expected, "funded pull credits native wrapped value");
        assertTrue(vm.revertToState(snapshot));
        assertEq(quote, expected, "exact-in preview normalizes wrap floor");
        uint256 beforeShares = IERC20(vault).balanceOf(address(this));
        assertEq(_exactIn(token_, amount_, quote, true), quote, "prior exact-in quote survives atomic delivery");
        assertEq(IERC20(vault).balanceOf(address(this)) - beforeShares, quote, "exact-in recipient issuance");
        assertEq(token_.balanceOf(address(integrator)), 0, "exact-in never refunds residual credit");
    }

    function test_APEX_nonUnitUnderlyingExactInPreviewAndPretransfer() public { _assertExactIn(IERC20(address(hermeticStEth)), 2, 1); }
    function test_APEX_nonUnitWrappedExactInPreviewAndPretransfer() public { _assertExactIn(IERC20(address(wrapped)), 2, 3); }
}
