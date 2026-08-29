// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {TestBase_UniswapV4Detf_Weighted_Adversarial} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_Adversarial.sol";

/**
 * @title UniswapV4Detf_Weighted_Adversarial_A0Crops
 * @notice Weighted gold A0 / CROPS / F1.
 * @dev E6 N/A no residual-return. M* N/A no calldata forwarder. D18 not tested.
 */
contract UniswapV4Detf_Weighted_Adversarial_A0Crops is TestBase_UniswapV4Detf_Weighted_Adversarial {
    function test_A0_donateBeforeFirstBond_cannotFreeMint() public {
        _assertA0_donateBeforeFirstBond_cannotFreeMint();
    }

    function test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork() public {
        _assertCROPS_disable_inboundGated_matureCloseRedeemBurnWork();
    }

    /// @notice After postDeploy, Bond NFT and claim token have no leftover owner/minter an attacker can use.
    function test_F1_satellitesUnowned() public {
        address nft_ = detfInfo.bondNftVault();
        address claim_ = detfInfo.rebasingClaimToken();
        assertTrue(nft_ != address(0), "bond nft wired");
        assertTrue(claim_ != address(0), "claim wired");

        _assertOwnerIsDetfOrUncut(nft_, "nft");
        _assertOwnerIsDetfOrUncut(claim_, "claim");
        _assertOwnerIsDetfOrUncut(detf, "detf");

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        IRebasingClaimToken(claim_).mintFromNFTSale(1 ether, attacker);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        IDETFNFTVault(nft_).sellPositionToDetfNft(1, attacker, attacker);

        (bool cutOk_,) = detf.call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)",
                new bytes(0),
                address(0),
                ""
            )
        );
        assertFalse(cutOk_, "detf diamondCut not callable");

        (bool nftCutOk_,) = nft_.call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)",
                new bytes(0),
                address(0),
                ""
            )
        );
        assertFalse(nftCutOk_, "nft diamondCut not callable by attacker");

        (bool claimCutOk_,) = claim_.call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)",
                new bytes(0),
                address(0),
                ""
            )
        );
        assertFalse(claimCutOk_, "claim diamondCut not callable by attacker");
    }

    function _assertOwnerIsDetfOrUncut(address target_, string memory label_) internal view {
        (bool ok_, bytes memory ret_) = target_.staticcall(abi.encodeWithSignature("owner()"));
        if (!ok_ || ret_.length < 32) {
            return;
        }
        address owner_ = abi.decode(ret_, (address));
        assertTrue(
            owner_ == address(0) || owner_ == detf,
            string.concat(label_, " leftover owner attacker can use")
        );
    }
}
