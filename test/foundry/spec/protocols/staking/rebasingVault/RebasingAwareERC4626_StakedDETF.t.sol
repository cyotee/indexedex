// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";

import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {RebasingAwareERC4626_Component_FactoryService} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

/// @notice Production sDETF as wrapper asset. Transfer-triggered settlement reverts;
///         the same deposit succeeds after explicit synchronizeRewards().
contract RebasingAwareERC4626_StakedDETF is TestBase_UniswapV4Detf {
    using RebasingAwareERC4626_Component_FactoryService for ICreate3FactoryProxy;

    function test_F18_productionSdetfTransferTriggeredRevertsThenSynchronizeSucceeds() public {
        (uint256 id_,) = _firstBond(1_000 ether);
        IDetfBondNFT nft = IDetfBondNFT(address(detfInfo.bondNftVault()));
        IStakedDETF staking = IStakedDETF(detfInfo.rebasingClaimToken());
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK);
        vm.prank(detfUser);
        nft.claimBond(id_, detfUser);
        uint256 held = staking.balanceOf(detfUser);
        assertGt(held, 0);

        vm.startPrank(detfUser);
        pairToken.approve(address(pairProtocolVault), 100_000 ether);
        pairProtocolVault.simulateYield(100_000 ether);
        vm.stopPrank();
        vm.warp(block.timestamp + 8 hours);
        assertGt(detfInfo.pendingExpansionDetf(), 0);

        IERC4626 wrapped = _deployWrapperOn(IERC20Metadata(address(staking)));
        uint256 amt = held / 4;
        vm.startPrank(detfUser);
        staking.approve(address(wrapped), type(uint256).max);
        vm.expectRevert();
        wrapped.deposit(amt, detfUser);
        vm.stopPrank();

        IDETFFundedRewards(detf).synchronizeRewards();
        assertEq(detfInfo.pendingExpansionDetf(), 0);

        vm.startPrank(detfUser);
        uint256 shares = wrapped.deposit(amt, detfUser);
        assertGt(shares, 0);
        uint256 assets = wrapped.redeem(shares, detfUser, detfUser);
        assertGt(assets, 0);
        vm.stopPrank();
    }

    function test_genericWrapperNeverCallsSynchronizeRewardsSelector() public {
        IFacet erc4626F = create3Factory.deployRebasingAwareERC4626Facet();
        IFacet seF = create3Factory.deployRebasingAwareStandardExchangeFacet();
        IFacet syF = create3Factory.deployRebasingAwareStandardYieldFacet();
        bytes4 sel = bytes4(keccak256("synchronizeRewards()"));
        assertFalse(_containsSelector(address(erc4626F).code, sel));
        assertFalse(_containsSelector(address(seF).code, sel));
        assertFalse(_containsSelector(address(syF).code, sel));
    }

    function _deployWrapperOn(IERC20Metadata asset) internal returns (IERC4626) {
        IFacet erc4626F = create3Factory.deployRebasingAwareERC4626Facet();
        IFacet seF = create3Factory.deployRebasingAwareStandardExchangeFacet();
        IFacet syF = create3Factory.deployRebasingAwareStandardYieldFacet();
        IFacet metaF = create3Factory.deployRebasingAwareVaultMetadataFacet();
        IFacet quoteF = create3Factory.deployRebasingAwareStandardExchangeQuoteFacet();
        vm.prank(owner);
        IRebasingAwareERC4626DFPkg wpkg = RebasingAwareERC4626_Component_FactoryService
            .deployRebasingAwareERC4626DFPkg(
            indexedexManager,
            IRebasingAwareERC4626DFPkg.PkgInit({
                erc20Facet: erc20Facet,
                rebasingAwareErc4626Facet: erc4626F,
                diamondFactory: diamondPackageFactory,
                standardExchangeFacet: seF,
                standardYieldFacet: syF,
                vaultMetadataFacet: metaF,
                transitionQuoteFacet: quoteF,
                vaultRegistry: IVaultRegistryDeployment(address(indexedexManager))
            })
        );
        return wpkg.deployVault(asset, 10, bytes32(uint256(77)));
    }

    function _containsSelector(bytes memory code, bytes4 sel) internal pure returns (bool) {
        if (code.length < 4) return false;
        for (uint256 i; i + 3 < code.length; ++i) {
            if (
                code[i] == sel[0] && code[i + 1] == sel[1] && code[i + 2] == sel[2]
                    && code[i + 3] == sel[3]
            ) {
                return true;
            }
        }
        return false;
    }
}
