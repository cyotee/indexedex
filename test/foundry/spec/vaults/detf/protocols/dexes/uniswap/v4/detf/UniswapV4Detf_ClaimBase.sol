// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {
    IUniswapV4Detf
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";

/**
 * @title UniswapV4Detf_ClaimBase
 * @notice Shared Bond NFT sell / claim-token helpers. No extra setUp deploy.
 * @dev Sell is NFT `sellPositionToDetfNft` (onlyOwner = DETF) then `mintFromNFTSale`.
 *      Redeem is `IRebasingClaimToken.redeem`. Rewards are NFT `claimRewards`.
 */
abstract contract UniswapV4Detf_ClaimBase is TestBase_UniswapV4Detf_Policy {
    function _nft() internal view virtual returns (IDETFNFTVault) {
        return IDETFNFTVault(detfInfo.bondNftVault());
    }

    function _nftOf(address d) internal view returns (IDETFNFTVault) {
        return IDETFNFTVault(IUniswapV4Detf(d).bondNftVault());
    }

    function _claimTok() internal view returns (IRebasingClaimToken) {
        return IRebasingClaimToken(detfInfo.rebasingClaimToken());
    }

    function _claimTokOf(address d) internal view returns (IRebasingClaimToken) {
        return IRebasingClaimToken(IUniswapV4Detf(d).rebasingClaimToken());
    }

    function _lpOf(address d) internal view returns (IERC20) {
        return IERC20(IUniswapV4Detf(d).hook());
    }

    function _minOutOf(address d) internal view returns (uint256[] memory m) {
        m = new uint256[](IUniswapV4SeBufferHook(IUniswapV4Detf(d).hook()).tokens().length);
    }

    function _setPfc(address d) internal {
        vm.startPrank(owner);
        try IVaultFeeOracleManager(address(indexedexManager)).setSeigniorageIncentivePercentageOfVault(d, 5e16) {}
        catch {}
        try IVaultFeeOracleManager(address(indexedexManager)).setSeignioragePotSharesOfVault(d, 12e16, 28e16) {}
        catch {}
        vm.stopPrank();
    }

    function _fundActorForDetf(address d, address who, uint256 amt) internal {
        address[] memory toks_ = IUniswapV4SeBufferHook(IUniswapV4Detf(d).hook()).tokens();
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == d) continue;
            try SimpleMintableERC20(toks_[i]).mint(who, amt) {} catch {
                uint256 have_ = IERC20(toks_[i]).balanceOf(who);
                deal(toks_[i], who, have_ + amt);
            }
            vm.prank(who);
            IERC20(toks_[i]).approve(d, type(uint256).max);
        }
    }

    function _leadPairOf(address d) internal view returns (IERC20 tok) {
        address[] memory toks_ = IUniswapV4SeBufferHook(IUniswapV4Detf(d).hook()).tokens();
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] != d) return IERC20(toks_[i]);
        }
        return IERC20(address(pairToken));
    }

    function _liveMintOn(address d, address who, uint256 amt) internal virtual returns (uint256 userDetf) {
        _fundActorForDetf(d, who, amt);
        IERC20 tok_ = _leadPairOf(d);
        vm.startPrank(who);
        tok_.approve(d, amt);
        userDetf = IUniswapV4Detf(d).mint(tok_, amt, 0, who, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function _bondOn(address d, address who, uint256 amt) internal virtual returns (uint256 tokenId, uint256 shares) {
        _fundActorForDetf(d, who, amt);
        IERC20 tok_ = _leadPairOf(d);
        vm.startPrank(who);
        tok_.approve(d, amt);
        (tokenId, shares) = IUniswapV4Detf(d).bond(tok_, amt, DEFAULT_MIN_LOCK, who, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    /// @notice D10: NFT sell (DETF owner) then claim `mintFromNFTSale` with pre-credit originalShares.
    function _d10SellToClaimOn(address d, uint256 tokenId, address seller)
        internal
        returns (uint256 principal, uint256 claimMinted)
    {
        IDETFNFTVault nft_ = _nftOf(d);
        IRebasingClaimToken claim_ = _claimTokOf(d);
        uint256 protocolBefore_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.prank(d);
        (principal,) = nft_.sellPositionToDetfNft(tokenId, seller, seller);
        vm.prank(d);
        claimMinted = claim_.mintFromNFTSale(principal, protocolBefore_, seller);
    }

    function _warpMature(uint256 tokenId) internal {
        uint256 unlock_ = _nft().unlockTimeOf(tokenId);
        if (block.timestamp <= unlock_) vm.warp(unlock_ + 1);
    }

    function _warpMatureOf(address d, uint256 tokenId) internal {
        uint256 unlock_ = _nftOf(d).unlockTimeOf(tokenId);
        if (block.timestamp <= unlock_) vm.warp(unlock_ + 1);
    }
}
