// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
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
/// @notice D47: one closed-form `depositSingle` per pair (Script_20 fd gap), not a crumb loop.
/// @dev S = (fdPair / supply) / creationRate. `depositSingle` raises fd without minting DETF.
///      `exchangeIn` mints DETF and dilutes S — use it only to refill nest inventory.
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

    /// @notice Mint `need` DETF via pair→detf exchangeIn (nest inventory only).
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

    function previewPairNeed(address detf, address pair) internal view returns (uint256) {
        return _pairNeed(detf, pair);
    }

    function enrichCp(address detf, address pair, address bonder) internal {
        _enrichPair(detf, pair, bonder);
        require(_pairRich(detf, pair), "D47: CP not rich after sized deposit");
    }

    function enrichMulti(address detf, address[] memory pairs, address bonder) internal {
        for (uint256 p; p < pairs.length; ++p) {
            console2.log("D47 enrich pair", p);
            _enrichPair(detf, pairs[p], bonder);
            require(_pairRich(detf, pairs[p]), "D47: multi-leg not rich after sized deposit");
        }
        require(IDetfMultiViews(detf).isReserveLive(), "D47: reserve not live after enrich");
    }

    /// @dev One deposit of the closed-form fd gap (+10% zap buffer). No crumb loop.
    function _enrichPair(address detf, address pair, address bonder) private {
        if (_pairRich(detf, pair)) {
            console2.log("D47 already rich, S", _synthetic(detf, pair));
            return;
        }
        uint256 need = _pairNeed(detf, pair);
        require(need > 0, "D47: need is 0 but pair not rich");
        console2.log("D47 sized deposit", need);
        console2.log("D47 S before", _synthetic(detf, pair));
        _depositPairOnHook(detf, pair, need, bonder);
        console2.log("D47 S after", _synthetic(detf, pair));
        require(_pairRich(detf, pair), "D47: sized deposit did not reach target");
    }

    /// @dev need = (target - S) * supply * C / 1e36, plus 10% zap/AMM buffer (Script_20).
    function _pairNeed(address detf, address pair) private view returns (uint256 need_) {
        uint256 s0_ = _synthetic(detf, pair);
        if (s0_ >= FixtureEconomics.RICH_TARGET) return 0;
        uint256 fd0_ = _fdPairWad(detf, pair);
        uint256 fdT_ = Math.mulDiv(
            FixtureEconomics.RICH_TARGET, Math.mulDiv(IERC20(detf).totalSupply(), _creation(detf), ONE_WAD), ONE_WAD
        );
        if (fdT_ <= fd0_) return 0;
        need_ = fdT_ - fd0_;
        need_ = need_ + need_ / 10;
    }

    function _fdPairWad(address detf, address pair) private view returns (uint256) {
        uint256 s0_ = _synthetic(detf, pair);
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 c_ = _creation(detf);
        if (s0_ == 0 || supply_ == 0 || c_ == 0) return 0;
        return Math.mulDiv(s0_, Math.mulDiv(supply_, c_, ONE_WAD), ONE_WAD);
    }

    function _creation(address detf) private view returns (uint256) {
        try IDetfCpViews(detf).creationPairPerDetfWad() returns (uint256 c) {
            if (c > 0) return c;
        } catch {}
        return FixtureEconomics.CREATION_PAIR_PER_DETF;
    }

    function _synthetic(address detf, address pair) private view returns (uint256) {
        try IDetfMultiViews(detf).syntheticVs(pair) returns (uint256 s) {
            return s;
        } catch {
            return IDetfCpViews(detf).syntheticPrice();
        }
    }

    function _pairRich(address detf, address pair) private view returns (bool) {
        return _synthetic(detf, pair) >= FixtureEconomics.RICH_TARGET && _mintOpen(detf, pair);
    }

    function _mintOpen(address detf, address pair) private view returns (bool) {
        try IDetfMultiViews(detf).isMintingAllowed(pair) returns (bool ok) {
            return ok;
        } catch {
            return IDetfCpViews(detf).isMintingAllowed();
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

    function _depositPairOnHook(address detf, address pair, uint256 amount, address bonder) private {
        _ensurePair(pair, amount, bonder);
        address hook = IDetfHookViews(detf).reserveHook();
        address claim = IDetfHookViews(detf).rebasingClaimToken();
        address lpTo = claim == address(0) ? detf : claim;
        IERC20(pair).approve(hook, amount);
        try IReserveHookDeposit(hook).depositSingle(pair, amount, lpTo, 0, block.timestamp + 1 days) {}
        catch {
            try IReserveHookDepositOrb(hook).depositSingle(
                pair, amount, lpTo, 0, block.timestamp + 1 days, bytes("")
            ) {} catch {
                revert("D47: depositSingle failed");
            }
        }
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

interface IDetfHookViews {
    function reserveHook() external view returns (address);
    function rebasingClaimToken() external view returns (address);
}

interface IReserveHookDeposit {
    function depositSingle(address tokenIn, uint256 amountIn, address to, uint256 minLp, uint256 deadline)
        external
        returns (uint256);
}

interface IReserveHookDepositOrb {
    function depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLp,
        uint256 deadline,
        bytes calldata permit2Data
    ) external returns (uint256);
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
