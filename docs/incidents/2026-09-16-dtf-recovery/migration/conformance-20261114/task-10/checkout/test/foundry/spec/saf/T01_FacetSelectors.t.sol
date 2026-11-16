// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice T01 / L-FACET: current funded views and principal routes on actual registered DETF children.
contract T01_FacetSelectors_Test is TestBase_UniswapV4Detf {
    function test_fundedChildren_liveViewsAndUnits() public view {
        IDetfBondNFT nft_ = IDetfBondNFT(detfInfo.bondNftVault());
        IStakedDETF receipt_ = IStakedDETF(detfInfo.rebasingClaimToken());
        assertEq(nft_.detf(), detf);
        assertEq(address(nft_.lpToken()), reserveHook);
        assertTrue(nft_.reservedBondNftsWired());
        assertEq(nft_.ownerOf(1), address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo()));
        assertEq(nft_.positionOf(1).principal, 0, "standing right owns no purchased principal");
        assertEq(receipt_.detf(), detf);
        assertEq(receipt_.decimals(), 9);
        assertEq(receipt_.stakingState().gonsPerUnit, 1e36);
        assertEq(receipt_.stakingState().accountedBacking, 0, "inert backing");
    }

    function test_fundedChildren_retiredViewsAndSaleNotInstalled() public {
        address nft_ = detfInfo.bondNftVault();
        address receipt_ = detfInfo.rebasingClaimToken();
        _assertAbsent(nft_, abi.encodeWithSignature("markDETFNFTSold(uint256)", 1));
        _assertAbsent(nft_, abi.encodeWithSignature("detfNFTSold()"));
        _assertAbsent(nft_, abi.encodeWithSignature("lockInfoOf(uint256)", 0));
        _assertAbsent(nft_, abi.encodeWithSignature("rewardPerShares()"));
        _assertAbsent(receipt_, abi.encodeWithSignature("updateRedemptionRate()"));
        _assertAbsent(receipt_, abi.encodeWithSignature("redemptionRate()"));
    }

    function test_fundedChildren_currentSelectorsInstalledOnce() public view {
        address nft_ = detfInfo.bondNftVault();
        address receipt_ = detfInfo.rebasingClaimToken();
        _assertInstalled(nft_, IDetfBondNFT.positionOf.selector);
        _assertInstalled(nft_, IDetfBondNFT.previewClaim.selector);
        _assertInstalled(nft_, IDetfBondNFT.claimPrincipal.selector);
        _assertInstalled(nft_, IDetfBondNFT.claimRewards.selector);
        _assertInstalled(nft_, IDetfBondNFT.claimBond.selector);
        _assertInstalled(receipt_, IStakedDETF.stakingState.selector);
        _assertInstalled(receipt_, IStakedDETF.gonsOf.selector);
        _assertInstalled(receipt_, IStandardExchangeIn.exchangeIn.selector);
        _assertInstalled(receipt_, IStandardExchangeIn.previewExchangeIn.selector);
        _assertInstalled(receipt_, IStandardExchangeOut.exchangeOut.selector);
        _assertInstalled(receipt_, IStandardExchangeOut.previewExchangeOut.selector);
    }

    function _assertInstalled(address proxy_, bytes4 selector_) internal view {
        address facet_ = IDiamondLoupe(proxy_).facetAddress(selector_);
        assertTrue(facet_ != address(0), "current selector installed on actual proxy");
        bytes4[] memory functions_ = IFacet(facet_).facetFuncs();
        uint256 count_;
        for (uint256 i_; i_ < functions_.length; ++i_) if (functions_[i_] == selector_) ++count_;
        assertEq(count_, 1, "facet declares current selector exactly once");
    }

    function _assertAbsent(address proxy_, bytes memory call_) internal {
        bytes4 selector_;
        assembly ("memory-safe") { selector_ := mload(add(call_, 32)) }
        assertEq(IDiamondLoupe(proxy_).facetAddress(selector_), address(0), "retired selector absent");
        (bool ok_,) = proxy_.call(call_);
        assertFalse(ok_, "retired product call cannot succeed");
    }
}
