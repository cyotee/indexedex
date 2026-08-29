// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice Open-layer §7.1 IDs (gold all four later + Stage 11 Open). No setUp deploy.
abstract contract UniswapV4Detf_IoTablesOpenBase is TestBase_UniswapV4Detf {
    uint256 private constant ONE_WAD_OPEN = 1e18;

    /// @notice T7.2: Default mint/burn/bond = each hook pair + that SE share. No extra SE vaultTokens.
    function test_T7_2_defaultTables_pairAndShare_noUnderlyings() public view {
        address[] memory hookToks_ = IUniswapV4SeBufferHook(reserveHook).tokens();
        _assertDefaultInbound(detfInfo.mintRoutes(), hookToks_, "mint");
        _assertDefaultInbound(detfInfo.burnRoutes(), hookToks_, "burn");
        _assertDefaultInbound(detfInfo.bondRoutes(), hookToks_, "bond");
    }

    /// @notice T7.10: After live, one later `bond` of mintToken; one `joinUnbalanced`; G unboosted mix.
    function test_T7_10_laterBond_joinUnbalanced_unboostedG() public {
        _firstBond(80 ether);
        uint256 mintTokenIn_ = 20 ether;
        address pair_ = address(pairToken);
        uint256 p_ = IVaultFeeOracleQuery(address(indexedexManager)).seigniorageIncentivePercentageOfVault(detf);
        uint256 gExpected_ = _unboostedBondG(pair_, mintTokenIn_);
        uint256 expectedUser_ = Math.mulDiv(gExpected_, ONE_WAD_OPEN - p_, ONE_WAD_OPEN);
        (uint256 mintGross_,,) = detfInfo.previewMint(IERC20(pair_), mintTokenIn_);
        assertGt(mintGross_, 0, "mint Gross");

        uint256 userBefore_ = IERC20(detf).balanceOf(detfUser);
        vm.startPrank(detfUser);
        (uint256 tokenId, uint256 shares) = detfInfo.bond(
            IERC20(pair_),
            mintTokenIn_,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(tokenId, 0, "later tokenId");
        assertGt(shares, 0, "later lp");
        uint256 bondUser_ = IERC20(detf).balanceOf(detfUser) - userBefore_;
        assertEq(bondUser_, expectedUser_, "G unboosted mix user split");
        assertTrue(bondUser_ != mintGross_, "later bond G is not boosted mint Gross");
        detfInfo.sweepDust();
        assertEq(IERC20(reserveHook).balanceOf(detf), 0, "no hook LP on diamond");
        assertLe(IERC20(address(pairToken)).balanceOf(detf), 10, "pair dust below join min");
        assertLe(IERC20(se).balanceOf(detf), 10, "share dust below join min");
    }

    /// @notice T7.14: After mint, diamond and claim `balanceOf(hook LP)==0`. Bond NFT is the R12a package.
    function test_T7_14_commonNftUnused_claimHoldsNoHookLp() public {
        _firstBond(80 ether);
        vm.startPrank(detfUser);
        detfInfo.mint(
            IERC20(address(pairToken)),
            10 ether,
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        address nft_ = detfInfo.bondNftVault();
        address claim_ = detfInfo.rebasingClaimToken();
        assertTrue(nft_ != address(0), "R12a Bond NFT");
        assertEq(IERC20(reserveHook).balanceOf(detf), 0, "no LP on diamond");
        assertEq(IERC20(reserveHook).balanceOf(claim_), 0, "no LP on claim");
        assertGt(IERC20(reserveHook).balanceOf(nft_), 0, "LP on Bond NFT");
        _assertNoJoinableDust();
    }

    /// @notice T7.19: After mint, diamond has no joinable balances (also Stage 11 Open).
    function test_T7_19_afterMint_diamondHasNoJoinableBalances() public {
        _firstBond(80 ether);
        vm.startPrank(detfUser);
        detfInfo.mint(
            IERC20(address(pairToken)),
            10 ether,
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        _assertNoJoinableDust();
        assertEq(IERC20(reserveHook).balanceOf(detfInfo.rebasingClaimToken()), 0, "no LP on claim");
    }

    function _assertDefaultInbound(
        IUniswapV4Detf.IoRoute[] memory rows_,
        address[] memory hookToks_,
        string memory label_
    ) internal view {
        uint256 pairCount_;
        for (uint256 i; i < hookToks_.length; ++i) {
            if (hookToks_[i] == detf) continue;
            unchecked {
                ++pairCount_;
            }
        }
        assertEq(rows_.length, pairCount_ * 2, string.concat(label_, " pair+share"));
        for (uint256 r; r < rows_.length; ++r) {
            address t_ = address(rows_[r].token);
            address v_ = address(rows_[r].vault);
            assertTrue(t_ != detf, string.concat(label_, " no DETF token"));
            bool isPair_ = _isHookPair(hookToks_, t_);
            bool isShare_ = t_ == v_;
            assertTrue(isPair_ || isShare_, string.concat(label_, " pair or share only"));
            if (isPair_) {
                assertEq(v_, IUniswapV4SeBufferHook(reserveHook).standardExchangeOf(t_), "vault=SE of pair");
            }
        }
        for (uint256 h; h < hookToks_.length; ++h) {
            if (hookToks_[h] == detf) continue;
            address seOf_ = IUniswapV4SeBufferHook(reserveHook).standardExchangeOf(hookToks_[h]);
            if (seOf_ == address(0)) continue;
            address[] memory extra_ = IBasicVault(seOf_).vaultTokens();
            for (uint256 e; e < extra_.length; ++e) {
                if (_isHookPair(hookToks_, extra_[e])) continue;
                for (uint256 k; k < rows_.length; ++k) {
                    assertTrue(
                        address(rows_[k].token) != extra_[e],
                        string.concat(label_, " no extra underlying")
                    );
                }
            }
        }
    }

    function _isHookPair(address[] memory hookToks_, address token_) internal view returns (bool) {
        if (token_ == detf) return false;
        for (uint256 i; i < hookToks_.length; ++i) {
            if (hookToks_[i] == token_) return true;
        }
        return false;
    }

    function _unboostedBondG(address pair_, uint256 pairEq_) internal view returns (uint256 g_) {
        uint256 supply_ = IERC20(reserveHook).totalSupply();
        uint256[] memory amounts_ = IUniswapV4SeBufferHook(reserveHook).previewExitProportional(supply_);
        address[] memory tokens_ = IUniswapV4SeBufferHook(reserveHook).tokens();
        uint256 reserveDetf_;
        uint256 reservePair_;
        for (uint256 i; i < tokens_.length; ++i) {
            if (tokens_[i] == detf) reserveDetf_ = amounts_[i];
            if (tokens_[i] == pair_) reservePair_ = amounts_[i];
        }
        assertGt(reserveDetf_, 0, "reserve DETF");
        assertGt(reservePair_, 0, "reserve pair");
        g_ = (reserveDetf_ * pairEq_) / reservePair_;
    }
}
