// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721Metadata} from "@crane/contracts/interfaces/IERC721Metadata.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {Base64} from "@crane/contracts/utils/Base64.sol";
import {LibString} from "@crane/contracts/utils/LibString.sol";
import {DETFFundedBondMetadata as Metadata} from "contracts/vaults/detf/common/bondNft/DETFFundedBondMetadata.sol";
import {DETFFundedStakingMath as StakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {TestBase_UniswapV4Detf_Weighted_Univ3Se} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_Univ3Se.sol";

/// @notice One shared renderer suite covers every family without redeploying reserve fixtures.
contract DETFFundedBondMetadataTest is Test {
    uint256 private constant K = 1e36;

    function _view(uint256 claimed_, uint256 value_, uint256 time_) private pure returns (Metadata.View memory v_) {
        v_.detfName = 'Basket <&" example';
        v_.detfSymbol = "BASKET";
        v_.tokenId = 3;
        v_.position = StakingMath.BondPosition(100e9, claimed_, value_ * K, 1_000, 100);
        v_.timestamp = time_;
        v_.claim = StakingMath._claim(v_.position, time_, K);
    }

    function _json(Metadata.View memory v_) private pure returns (string memory) {
        return string(Base64.decode(LibString.slice(Metadata._uri(v_), bytes("data:application/json;base64,").length)));
    }

    function test_halfwayArtworkAndExactJSONUseFundedClaims() public view {
        Metadata.View memory v_ = _view(0, 110e9, 1_050);
        string memory json_ = _json(v_);
        assertEq(vm.parseJsonString(json_, ".attributes[6].value"), "50.000000000");
        assertEq(vm.parseJsonString(json_, ".attributes[7].value"), "10.000000000");
        assertEq(vm.parseJsonString(json_, ".attributes[8].value"), "60.000000000");
        assertEq(vm.parseJsonString(json_, ".attributes[12].value"), "50");
        string memory svg_ = Metadata._svg(v_);
        assertTrue(LibString.contains(svg_, "50.0% vested"));
        assertTrue(LibString.contains(svg_, "50 seconds remaining"));
        assertTrue(LibString.contains(svg_, "60.000000000"));
        assertFalse(LibString.contains(svg_, "APY"));
        assertFalse(LibString.contains(svg_, "gons"));
    }

    function test_newPartialRewardOnlyAndFullyVestedStates() public view {
        assertEq(vm.parseJsonString(_json(_view(0, 100e9, 1_000)), ".attributes[6].value"), "0.000000000");
        assertEq(vm.parseJsonString(_json(_view(50e9, 50e9, 1_050)), ".attributes[4].value"), "50.000000000");
        assertEq(vm.parseJsonString(_json(_view(50e9, 50e9, 1_050)), ".attributes[8].value"), "0.000000000");
        assertEq(vm.parseJsonString(_json(_view(0, 100e9, 1_050)), ".attributes[6].value"), "50.000000000");
        assertEq(vm.parseJsonString(_json(_view(0, 100e9, 1_050)), ".attributes[7].value"), "0.000000000");
        Metadata.View memory mature_ = _view(0, 110e9, 1_150);
        assertEq(vm.parseJsonString(_json(mature_), ".attributes[11].value"), "Fully vested");
        assertTrue(LibString.contains(Metadata._svg(mature_), "100.0% vested"));
    }

    function test_nameIsEscapedIndependentlyForJSONAndSVG() public view {
        Metadata.View memory v_ = _view(0, 110e9, 1_050);
        assertEq(vm.parseJsonString(_json(v_), ".attributes[0].value"), v_.detfName);
        string memory svg_ = Metadata._svg(v_);
        assertFalse(LibString.contains(svg_, v_.detfName));
        assertTrue(LibString.contains(svg_, "&lt;&amp;"));
    }

    function test_rolesHaveNoInventedVestingOrPrincipal() public view {
        Metadata.View memory v_;
        v_.detfName = "Basket";
        v_.detfSymbol = "BASKET";
        for (uint256 id_; id_ < 3; ++id_) {
            v_.tokenId = id_;
            string memory svg_ = Metadata._svg(v_);
            assertFalse(LibString.contains(svg_, "% vested"));
            assertFalse(LibString.contains(svg_, "Claimable principal"));
            string memory role_ = vm.parseJsonString(_json(v_), ".attributes[2].value");
            assertEq(role_, id_ == 0 ? "Protocol reserve" : id_ == 1 ? "Protocol fee recipient" : "Creator recipient");
        }
    }

    function test_exactNativeUnitAndBoundedLargeNumbers() public pure {
        assertEq(Metadata._amount(1), "0.000000001");
        Metadata.View memory v_ = _view(0, 100e9, 1_000);
        v_.position.principal = 1e30;
        v_.claim.principalRemaining = 1e30;
        assertTrue(LibString.contains(Metadata._svg(v_), "1.0000e21"));
        assertLt(bytes(Metadata._svg(v_)).length, 5_000);
    }

    /// @notice Export the actual Solidity renderer for visual review alongside its exact JSON.
    function test_exportRepresentativeRendererArtifacts() public {
        string memory directory_ = "implementation-artifacts/detf-funded-staking/bond-artwork/rendered/";
        vm.createDir(directory_, true);
        _export(directory_, "new", _view(0, 100e9, 1_000));
        _export(directory_, "halfway", _view(0, 110e9, 1_050));
        _export(directory_, "principal-and-rewards-claimed", _view(50e9, 50e9, 1_050));
        _export(directory_, "reward-only-claimed", _view(0, 100e9, 1_050));
        _export(directory_, "fully-vested", _view(0, 110e9, 1_100));
        Metadata.View memory role_;
        role_.detfName = "Example basket";
        role_.detfSymbol = "DETF";
        for (uint256 id_; id_ < 3; ++id_) {
            role_.tokenId = id_;
            _export(directory_, string.concat("role-", LibString.toString(id_)), role_);
        }
    }

    function _export(string memory directory_, string memory label_, Metadata.View memory v_) private {
        string memory json_ = _json(v_);
        assertEq(vm.parseJsonString(json_, ".attributes[0].value"), v_.detfName);
        vm.writeFile(string.concat(directory_, label_, ".svg"), Metadata._svg(v_));
        vm.writeFile(string.concat(directory_, label_, ".json"), json_);
    }
}

/// @notice An isolated ordinary registry fixture prevents Migration child package salts entering this control.
contract OrdinaryFundedBondMetadataTest is TestBase_UniswapV4Detf_Weighted_Univ3Se {
    /// @notice Ordinary output keeps linear structure and immediately claimable real funded rewards.
    function test_ordinaryPackageFundedMetadataRemainsUnchanged() public {
        vm.startPrank(detfUser);
        (uint256 id_,) = detfInfo.bond(IERC20(pairA), 100 ether, 90 days, detfUser, false, block.timestamp);
        detfInfo.bond(IERC20(pairA), 20 ether, 90 days, detfUser, false, block.timestamp);
        vm.stopPrank();
        IDetfBondNFT nft_ = IDetfBondNFT(detfInfo.bondNftVault());
        StakingMath.BondPosition memory p_ = nft_.positionOf(id_);
        vm.warp(p_.startTimestamp + 45 days);
        StakingMath.BondClaim memory c_ = nft_.previewClaim(id_);
        assertGt(c_.rewardsDue, 0);
        assertEq(c_.principalDue, p_.principal / 2);
        string memory uri_ = IERC721Metadata(address(nft_)).tokenURI(id_);
        string memory json_ = string(Base64.decode(LibString.slice(uri_, bytes("data:application/json;base64,").length)));
        string[] memory traits_ = abi.decode(vm.parseJson(json_, ".attributes[*].trait_type"), (string[]));
        assertEq(traits_.length, 13, "ordinary purchased attribute structure");
        assertEq(_attribute(json_, "Role"), "Staked DETF bond");
        assertEq(_attribute(json_, "Vesting status"), "Vesting");
        assertEq(vm.parseJsonUint(json_, _attributePath(json_, "Vesting start")), p_.startTimestamp);
        assertEq(vm.parseJsonUint(json_, _attributePath(json_, "Vesting end")), p_.startTimestamp + 90 days);
        assertEq(_attribute(json_, "Seconds remaining"), LibString.toString(uint256(45 days)));
        assertEq(_attribute(json_, "Claimable principal sDETF"), Metadata._amount(c_.principalDue));
        assertEq(_attribute(json_, "Claimable rewards sDETF"), Metadata._amount(c_.rewardsDue));
        assertEq(_attribute(json_, "Total claimable sDETF"), Metadata._amount(c_.principalDue + c_.rewardsDue));
        string memory image_ = vm.parseJsonString(json_, ".image");
        string memory svg_ = string(Base64.decode(LibString.slice(image_, bytes("data:image/svg+xml;base64,").length)));
        assertTrue(LibString.contains(svg_, Metadata._amount(c_.principalDue + c_.rewardsDue)));
        emit log_named_string("ordinary package claimable reward sDETF", _attribute(json_, "Claimable rewards sDETF"));
        emit log_named_string("ordinary package total sDETF", _attribute(json_, "Total claimable sDETF"));
        emit log_named_string("ordinary package metadata JSON", json_);
        IERC20 staking_ = IERC20(detfInfo.rebasingClaimToken());
        uint256 before_ = staking_.balanceOf(detfUser);
        vm.prank(detfUser);
        assertEq(nft_.claimRewards(id_, detfUser), c_.rewardsDue);
        assertEq(staking_.balanceOf(detfUser) - before_, c_.rewardsDue);
    }

    function _attribute(string memory json_, string memory trait_) private view returns (string memory) {
        return vm.parseJsonString(json_, _attributePath(json_, trait_));
    }

    function _attributePath(string memory json_, string memory trait_) private view returns (string memory) {
        string[] memory traits_ = abi.decode(vm.parseJson(json_, ".attributes[*].trait_type"), (string[]));
        for (uint256 i_; i_ < traits_.length; ++i_) {
            if (keccak256(bytes(traits_[i_])) == keccak256(bytes(trait_))) {
                return string.concat(".attributes[", LibString.toString(i_), "].value");
            }
        }
        revert(string.concat("Missing metadata trait: ", trait_));
    }
}
