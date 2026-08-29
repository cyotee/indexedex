// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as CpHookFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Quad} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad.sol";
import {UniswapV4Detf_ReserveDonationBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ReserveDonationBase.sol";
import {UniswapV4Detf_ReserveDonationOpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ReserveDonationOpenBase.sol";

/// @notice Quad gold donation R12a. DN1 donate/I1 use pair0. DN5 extra deploy is GoldBase CP path.
contract UniswapV4Detf_Quad_ReserveDonation is
    TestBase_UniswapV4Detf_Quad,
    UniswapV4Detf_ReserveDonationOpenBase,
    UniswapV4Detf_ReserveDonationBase
{
    using BetterEfficientHashLib for bytes;

    function setUp() public override(TestBase_UniswapV4Detf_Quad, TestBase_UniswapV4Detf) {
        TestBase_UniswapV4Detf_Quad.setUp();
        _deployCpHookPkgForExtras();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf_Quad, TestBase_UniswapV4Detf)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Quad._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf_Quad, TestBase_UniswapV4Detf)
    {
        TestBase_UniswapV4Detf_Quad._assertNoJoinableDust();
    }

    function test_DN14_closeAfterDonate_userBasketUnchanged() public override {
        _ensureLiveBond();
        address bob = makeAddr("dn14bob");
        (uint256 bobId,) = _bondAs(bob, 60 ether);
        IDETFNFTVault nft_ = _nft();
        address[] memory toks_ = IUniswapV4SeBufferHook(detfInfo.hook()).tokens();
        uint256 detfIdx_;
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == detf) {
                detfIdx_ = i;
                break;
            }
        }
        uint256[] memory snap_ = detfInfo.previewCloseBondMature(bobId);
        uint256 pairIdx_ = _pairIndex(toks_);
        uint256 pairSnap_ = snap_[pairIdx_];
        assertEq(snap_[detfIdx_], 0, "DN14 snapshot DETF slot unpaid");
        assertGt(pairSnap_, 0, "DN14 snapshot pair");

        _donatePair(dnDonor, 9 ether);

        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.prank(bob);
        uint256[] memory out_ = detfInfo.closeBondMature(bobId, _minOut(), bob, _deadline());
        assertEq(out_[detfIdx_], 0, "DN14 DETF slot not paid");
        assertGt(out_[pairIdx_], 0, "DN14 pair basket");
        assertGe(out_[pairIdx_], pairSnap_, "DN14 pair >= pre-donate snapshot");
        assertGe(IERC20(detf).totalSupply(), supplyBefore_, "DN14 no DETF burn");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "DN14 DETF rejoin id0");
        _assertNoJoinableDust();
    }

    function _deployCpHookPkgForExtras() internal {
        if (address(hookPkg) != address(0)) return;
        IFacet seFacet = CpHookFactory.deploySeFacet(create3Factory);
        IFacet depositFacet = CpHookFactory.deployDepositFacet(create3Factory);
        IFacet withdrawFacet = CpHookFactory.deployWithdrawFacet(create3Factory);
        hookPkg = CpHookFactory.deployPackage(
            IVaultRegistryDeployment(address(indexedexManager)),
            owner,
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgInit({
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
                seFacet: seFacet,
                depositFacet: depositFacet,
                withdrawFacet: withdrawFacet,
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                multiStepOwnableFacet: multiStepOwnableFacet
            }),
            abi.encode(type(IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage).name, "v1")._hash()
        );
    }
}
