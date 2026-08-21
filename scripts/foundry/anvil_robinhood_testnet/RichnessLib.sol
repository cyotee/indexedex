// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {PoolSeedLib, IWeth9} from "./PoolSeedLib.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ROBINHOOD_TESTNET} from "@crane/contracts/constants/networks/ROBINHOOD_TESTNET.sol";

interface IDetfCpViews {
    function isReserveLive() external view returns (bool);
    function syntheticPrice() external view returns (uint256);
    function isMintingAllowed() external view returns (bool);
    function creationPairPerDetfWad() external view returns (uint256);
}

interface IDetfMultiViews {
    function isReserveLive() external view returns (bool);
    function syntheticVs(address pair) external view returns (uint256);
    function isMintingAllowed(address pair) external view returns (bool);
}

/// @title RichnessLib
/// @notice First bond as the deployer EOA. Opening WAD is launch-rich.
/// @dev Do not impersonate the DETF diamond. Do not hook depositSingle as the diamond.
///      `ensureBalance` is nest inventory via `exchangeIn` only (not a richness LP path).
library RichnessLib {
    uint256 private constant ONE_WAD = 1e18;

    function firstBondCp(address detf, IERC20 capitalToken, uint256 amount, address bonder) internal {
        if (IDetfCpViews(detf).isReserveLive()) return;
        capitalToken.approve(detf, amount);
        IDetfBond(detf).bond(capitalToken, amount, FixtureEconomics.MIN_LOCK, bonder, false, block.timestamp + 1 days);
        require(IDetfCpViews(detf).isReserveLive(), "D47: reserve not live after first bond");
    }

    function firstBondOrbital(
        address detf,
        IERC20 pair0,
        uint256 amt0,
        IERC20 pair1,
        uint256 amt1,
        address bonder
    ) internal {
        if (IDetfMultiViews(detf).isReserveLive()) return;
        pair0.approve(detf, amt0);
        pair1.approve(detf, amt1);
        IDetfOrbitalBond(detf).bond(
            pair0, amt0, pair1, amt1, FixtureEconomics.MIN_LOCK, bonder, false, block.timestamp + 1 days
        );
        require(IDetfMultiViews(detf).isReserveLive(), "D47: reserve not live after first bond");
    }

    function firstBondMulti(
        address detf,
        IERC20[] memory tokenIns,
        uint256[] memory amountsIn,
        address capitalToken,
        address bonder
    ) internal {
        if (IDetfMultiViews(detf).isReserveLive()) return;
        for (uint256 i; i < tokenIns.length; ++i) {
            tokenIns[i].approve(detf, amountsIn[i]);
        }
        IDetfMultiBond(detf).bond(
            tokenIns, amountsIn, capitalToken, FixtureEconomics.MIN_LOCK, bonder, false, block.timestamp + 1 days
        );
        require(IDetfMultiViews(detf).isReserveLive(), "D47: reserve not live after first bond");
    }

    /// @notice Nest inventory via pair→detf exchangeIn only. Not a diamond-LP richness path.
    function ensureBalance(address detf, address pair, uint256 need, address bonder) internal {
        uint256 have = IERC20(detf).balanceOf(bonder);
        if (have >= need) return;
        require(_mintOpen(detf, pair), "D47: mint closed; enrich first");
        uint256 short = need - have;
        uint256 s = _synthetic(detf, pair);
        if (s == 0) s = ONE_WAD;
        uint256 pairIn = Math.mulDiv(short, s, ONE_WAD);
        pairIn = pairIn + pairIn / 5;
        _exchangeIn(detf, pair, pairIn, bonder);
        require(IERC20(detf).balanceOf(bonder) >= need, "D47: nest inventory short");
    }

    function _mintOpen(address detf, address pair) private view returns (bool) {
        try IDetfMultiViews(detf).isMintingAllowed(pair) returns (bool ok) {
            return ok;
        } catch {
            return IDetfCpViews(detf).isMintingAllowed();
        }
    }

    function _synthetic(address detf, address pair) private view returns (uint256) {
        try IDetfMultiViews(detf).syntheticVs(pair) returns (uint256 s) {
            return s;
        } catch {
            return IDetfCpViews(detf).syntheticPrice();
        }
    }

    function _ensurePair(address pair, uint256 amount, address bonder) private {
        if (pair == address(ROBINHOOD_TESTNET.WETH)) {
            uint256 have = IWeth9(pair).balanceOf(bonder);
            if (have < amount) {
                PoolSeedLib.wrapWeth(bonder, amount);
            }
        }
        require(IERC20(pair).balanceOf(bonder) >= amount, "D47: pair inventory short");
    }

    function _exchangeIn(address detf, address pair, uint256 amount, address bonder) private {
        _ensurePair(pair, amount, bonder);
        IERC20(pair).approve(detf, amount);
        uint256 preview = IStandardExchangeIn(detf).previewExchangeIn(IERC20(pair), amount, IERC20(detf));
        require(preview > 0, "D47: preview pair->detf is 0");
        IStandardExchangeIn(detf).exchangeIn(
            IERC20(pair), amount, IERC20(detf), FixtureEconomics.SWAP_MIN_OUT, bonder, false, block.timestamp + 1 days
        );
    }
}

interface IDetfBond {
    function bond(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, bool pretransferred, uint256 deadline)
        external
        returns (uint256 tokenId, uint256 shares);
}

interface IDetfOrbitalBond {
    function bond(
        IERC20 tokenIn0,
        uint256 amountIn0,
        IERC20 tokenIn1,
        uint256 amountIn1,
        uint256 lockDuration,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 tokenId, uint256 shares);
}

interface IDetfMultiBond {
    function bond(
        IERC20[] calldata tokenIns,
        uint256[] calldata amountsIn,
        address capitalToken,
        uint256 lockDuration,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 tokenId, uint256 shares);
}
