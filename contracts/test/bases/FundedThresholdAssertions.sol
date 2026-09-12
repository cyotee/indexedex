// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {Test} from "forge-std/Test.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {InvalidThresholdPair} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

interface IFundedThresholdInfo {
    function mintThreshold() external view returns (uint256);
    function burnThreshold() external view returns (uint256);
    function isReserveLive() external view returns (bool);
    function isMintingAllowed() external view returns (bool);
    function isBurningAllowed() external view returns (bool);
}

/// @notice Shared deployment law, exercised through each actual family package/registry.
abstract contract FundedThresholdAssertions is Test {
    function _deployThresholdPair(uint256 mint_, uint256 burn_) internal virtual returns (address);
    function deployThresholdFixture(uint256 mint_, uint256 burn_) external returns (address) {
        require(msg.sender == address(this));
        return _deployThresholdPair(mint_, burn_);
    }
    function test_mandatoryThresholdDeploymentValidation() public {
        uint256[6] memory m_ = [uint256(0), uint256(1.1e18), uint256(2), type(uint256).max, uint256(0), uint256(1.2e18)];
        uint256[6] memory b_ = [uint256(0), uint256(0.9e18), uint256(1), uint256(1), uint256(0.8e18), uint256(0)];
        address first_;
        for (uint256 i_; i_ < m_.length; ++i_) {
            address d_ = _deployThresholdPair(m_[i_], b_[i_]);
            _assertThresholdConfiguration(d_, m_[i_] == 0 ? 1.05e18 : m_[i_], b_[i_] == 0 ? 0.95e18 : b_[i_]);
            if (i_ == 0) first_ = d_;
        }
        _assertThresholdConfiguration(first_, 1.05e18, 0.95e18);
        _assertInvalidThresholdPair(1e18, 1e18, 1e18, 1e18);
        _assertInvalidThresholdPair(0.5e18, 0.6e18, 0.5e18, 0.6e18);
        _assertInvalidThresholdPair(0, 1.2e18, 1.05e18, 1.2e18);
        _assertInvalidThresholdPair(0.9e18, 0, 0.9e18, 0.95e18);
    }
    function _assertThresholdConfiguration(address detf_, uint256 mint_, uint256 burn_) private {
        IFundedThresholdInfo info_ = IFundedThresholdInfo(detf_);
        assertEq(info_.mintThreshold(), mint_);
        assertEq(info_.burnThreshold(), burn_);
        assertFalse(info_.isReserveLive());
        assertFalse(info_.isMintingAllowed());
        assertFalse(info_.isBurningAllowed());
        bytes4[4] memory removed_ = [bytes4(keccak256("thresholdMode()")), bytes4(keccak256("setThresholdMode(uint8)")),
            bytes4(keccak256("setMintThreshold(uint256)")), bytes4(keccak256("setBurnThreshold(uint256)"))];
        for (uint256 i_; i_ < removed_.length; ++i_) {
            assertEq(IDiamondLoupe(detf_).facetAddress(removed_[i_]), address(0));
            (bool ok_,) = detf_.call(abi.encodeWithSelector(removed_[i_], uint256(1)));
            assertFalse(ok_, "immutable gates have no mode or setters");
        }
    }
    /// @dev Use actually held and approved valid payment, so an empty wallet cannot mask a live gate.
    function _assertInertRoute(address detf_, IERC20 input_, uint256 amount_) internal {
        assertFalse(IFundedThresholdInfo(detf_).isReserveLive());
        uint256 before_ = input_.balanceOf(address(this));
        assertGe(before_, amount_);
        input_.approve(detf_, amount_);
        (bool ok_, bytes memory quote_) = detf_.staticcall(abi.encodeCall(
            IStandardExchangeIn.previewExchangeIn, (input_, amount_, IERC20(detf_))
        ));
        if (ok_) assertEq(abi.decode(quote_, (uint256)), 0, "inert vault cannot quote issuance");
        vm.expectRevert();
        IStandardExchangeIn(detf_).exchangeIn(input_, amount_, IERC20(detf_), 0, address(this), false, block.timestamp);
        assertEq(input_.balanceOf(address(this)), before_);
        assertEq(IERC20(detf_).totalSupply(), 0);
        assertFalse(IFundedThresholdInfo(detf_).isReserveLive());
    }
    function _assertInvalidThresholdPair(uint256 mint_, uint256 burn_, uint256 resolvedMint_, uint256 resolvedBurn_) private {
        vm.expectRevert(abi.encodeWithSelector(InvalidThresholdPair.selector, resolvedMint_, resolvedBurn_));
        this.deployThresholdFixture(mint_, burn_);
    }
}
