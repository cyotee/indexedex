// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {DETFChildTokenMetadata} from "contracts/vaults/detf/common/DETFChildTokenMetadata.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";
import {IUniswapV4DetfBondNFTVaultDFPkg} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {
    DETF_FEE_TO_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfCommon} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol";
import {UniswapV4DetfRepo as Repo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";

/// @title UniswapV4DetfTarget
/// @notice Mint, burn, bond, close, donate, sweep, and info for unified Uni V4 DETF.
abstract contract UniswapV4DetfTarget is UniswapV4DetfCommon, IUniswapV4Detf, IStandardExchangeIn {
    using BetterSafeERC20 for IERC20;
    using AddressSetRepo for AddressSet;

    /* ---------------------------------------------------------------------- */
    /*                                 Views                                  */
    /* ---------------------------------------------------------------------- */

    function hook() public view returns (address) {
        return Repo._layoutStruct().hook;
    }

    function reservePool() public view returns (address) {
        return Repo._layoutStruct().hook;
    }

    function isReserveLive() public view returns (bool) {
        return Repo._layoutStruct().isReserveLive;
    }

    function isReserveWired() public view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        return address(s.bondNftVault) != address(0) && address(s.rebasingClaimToken) != address(0);
    }

    function mintRoutes() public view returns (IUniswapV4Detf.IoRoute[] memory) {
        return Repo._routesOf(Repo._layoutStruct().mintTable);
    }

    function burnRoutes() public view returns (IUniswapV4Detf.IoRoute[] memory) {
        return Repo._routesOf(Repo._layoutStruct().burnTable);
    }

    function bondRoutes() public view returns (IUniswapV4Detf.IoRoute[] memory) {
        return Repo._routesOf(Repo._layoutStruct().bondTable);
    }

    function closeRoutes() public view returns (IUniswapV4Detf.IoRoute[] memory) {
        return Repo._routesOf(Repo._layoutStruct().closeTable);
    }

    function donateRoutes() public view returns (IUniswapV4Detf.IoRoute[] memory) {
        return Repo._routesOf(Repo._layoutStruct().donateTable);
    }

    function mintRouteMode() public view returns (IUniswapV4Detf.RouteTableMode) {
        return Repo._layoutStruct().mintRouteMode;
    }

    function burnRouteMode() public view returns (IUniswapV4Detf.RouteTableMode) {
        return Repo._layoutStruct().burnRouteMode;
    }

    function bondRouteMode() public view returns (IUniswapV4Detf.RouteTableMode) {
        return Repo._layoutStruct().bondRouteMode;
    }

    function closeRouteMode() public view returns (IUniswapV4Detf.RouteTableMode) {
        return Repo._layoutStruct().closeRouteMode;
    }

    function donateRouteMode() public view returns (IUniswapV4Detf.RouteTableMode) {
        return Repo._layoutStruct().donateRouteMode;
    }

    function creationPairPerDetfWad() public view returns (uint256[] memory) {
        return Repo._layoutStruct().creationPairPerDetfWad;
    }

    function openingPairPerDetfWad() public view returns (uint256[] memory) {
        return Repo._layoutStruct().openingPairPerDetfWad;
    }

    function mintThreshold() public view returns (uint256) {
        return Repo._layoutStruct().mintThreshold;
    }

    function burnThreshold() public view returns (uint256) {
        return Repo._layoutStruct().burnThreshold;
    }

    function thresholdMode() public view returns (ThresholdMode) {
        return Repo._layoutStruct().thresholdMode;
    }

    function syntheticPrice() public view returns (uint256) {
        return _syntheticPrice();
    }

    function pendingExpansionDetf() public view returns (uint256) {
        return _pendingExpansionDetf();
    }

    function bondNftVault() public view returns (address) {
        return address(Repo._layoutStruct().bondNftVault);
    }

    function detfNFTVault() public view returns (IDETFNFTVault) {
        return Repo._layoutStruct().bondNftVault;
    }

    function rebasingClaimToken() public view returns (address) {
        return address(Repo._layoutStruct().rebasingClaimToken);
    }

    function acceptedBondTokens() public view returns (address[] memory tokens_) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive) {
            return IUniswapV4SeBufferHook(s.hook).requiredFirstBondTokens();
        }
        address[] storage t_ = s.bondTable.tokens._values();
        tokens_ = new address[](t_.length);
        for (uint256 i; i < t_.length; ++i) {
            tokens_[i] = t_[i];
        }
    }

    function isMintingAllowed() public view returns (bool) {
        return _isMintingAllowedAny();
    }

    function isMintingAllowed(IERC20 tokenIn) public view returns (bool) {
        return _isMintingAllowedToken(tokenIn);
    }

    function isBurningAllowed() public view returns (bool) {
        return _isBurningAllowedAny();
    }

    function isBurningAllowed(IERC20 tokenOut) public view returns (bool) {
        return _isBurningAllowedToken(tokenOut);
    }

    /* ---------------------------------------------------------------------- */
    /*                                  Mint                                  */
    /* ---------------------------------------------------------------------- */

    function previewMint(IERC20 tokenIn, uint256 amountIn)
        public
        view
        returns (uint256 grossDetf, uint256 userDetf, uint256 lpOut)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive || amountIn == 0) return (0, 0, 0);
        if (!s.mintTable.tokens._contains(address(tokenIn))) return (0, 0, 0);
        IStandardExchange v_ = s.mintTable.vaultOf[address(tokenIn)];
        address pair_ = _hookPairOfVault(v_);
        uint256 pairEq_;
        try this.peekPairEq(address(v_), address(tokenIn), amountIn) returns (uint256 eq_) {
            pairEq_ = eq_;
        } catch {
            return (0, 0, 0);
        }
        address share_ = address(v_);
        uint256 shareAmt_ = address(tokenIn) == share_ ? amountIn : 0;
        if (shareAmt_ == 0) {
            try v_.previewExchangeIn(tokenIn, amountIn, IERC20(share_)) returns (uint256 sh_) {
                shareAmt_ = sh_;
            } catch {
                return (0, 0, 0);
            }
        }
        shareAmt_;
        // Hook previewJoin of an SE share zaps as a pool currency (UnsupportedRoute).
        // Preview the pair join the hook executes after unwrapping the share.
        lpOut = _hook().previewJoinSingleAssetExactIn(pair_, pairEq_);
        grossDetf = _quoteMintGross(pair_, pairEq_);
        MintSplit memory split_ = _splitMintedDetf(grossDetf);
        userDetf = split_.userDetf;
    }

    function peekPairEq(address vault_, address tokenIn_, uint256 amountIn_)
        external
        view
        returns (uint256)
    {
        return _pairEq(IStandardExchange(vault_), IERC20(tokenIn_), amountIn_);
    }

    function mint(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 minUserDetf,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) public nonReentrant returns (uint256 userDetf) {
        userDetf = _mintPath(tokenIn, amountIn, minUserDetf, recipient, pretransferred, deadline);
    }

    function exchangeIn(
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minAmountOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 amountOut_) {
        _requireActive(deadline_, amountIn_);
        if (address(tokenIn_) != address(this)) _requireNotDisabled();
        if (recipient_ == address(0)) recipient_ = msg.sender;
        if (address(tokenIn_) == address(this)) {
            return _burnPath(amountIn_, tokenOut_, minAmountOut_, recipient_, deadline_);
        }
        if (address(tokenOut_) == address(this)) {
            return _mintPath(tokenIn_, amountIn_, minAmountOut_, recipient_, pretransferred_, deadline_);
        }
        revert Repo.InvalidRoute(address(tokenIn_), address(tokenOut_));
    }

    function previewExchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        public
        view
        virtual
        returns (uint256 amountOut_)
    {
        if (address(tokenIn_) == address(this)) {
            return previewBurn(amountIn_, tokenOut_);
        }
        if (address(tokenOut_) == address(this)) {
            (, amountOut_,) = previewMint(tokenIn_, amountIn_);
            return amountOut_;
        }
        return 0;
    }

    function _mintPath(
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 minUserDetf_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) internal returns (uint256 userOut_) {
        _requireNotDisabled();
        _requireActive(deadline_, amountIn_);
        _requireReserveLive();
        if (recipient_ == address(0)) recipient_ = msg.sender;
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.mintTable.tokens._contains(address(tokenIn_))) {
            revert Repo.InvalidRoute(address(tokenIn_), address(this));
        }
        _realizeExpansionIfNeeded();
        if (!_isMintingAllowedToken(tokenIn_)) {
            revert Repo.MintingNotAllowed(_syntheticPrice(), s.mintThreshold);
        }
        IStandardExchange v_ = s.mintTable.vaultOf[address(tokenIn_)];
        address pair_ = _hookPairOfVault(v_);
        uint256 pulled_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
        uint256 pairEq_ = _pairEq(v_, tokenIn_, pulled_);
        uint256 gross_ = _quoteMintGross(pair_, pairEq_);
        if (gross_ == 0) revert Repo.InvalidRoute(pair_, address(this));
        // Preview sizes join on the hook pair. Execute the pair when the user
        // already paid that pair so Uni V4 SE share unwrap does not transferFrom the hook.
        if (address(tokenIn_) == pair_) {
            IERC20(pair_).forceApprove(s.hook, pulled_);
            uint256 lpMint_ =
                _hook().joinSingleAssetExactIn(pair_, pulled_, _bondLpHolder(), 0, deadline_);
            IERC20(pair_).forceApprove(s.hook, 0);
            lpMint_;
        } else {
            uint256 shareAmt_ = _toShare(v_, tokenIn_, pulled_, deadline_);
            _joinShare(shareAmt_, address(v_));
        }
        MintSplit memory split_ = _splitMintedDetf(gross_);
        if (split_.userDetf < minUserDetf_) {
            revert IStandardExchangeErrors.MinAmountNotMet(minUserDetf_, split_.userDetf);
        }
        _mintDetf(recipient_, split_.userDetf);
        if (split_.inventoryDetf > 0 && address(s.bondNftVault) != address(0)) {
            _mintDetf(address(s.bondNftVault), split_.inventoryDetf);
        }
        _tryCompoundProtocolRewards();
        _trySweepDust();
        _syncAllExpectedHoldReserves();
        return split_.userDetf;
    }

    /* ---------------------------------------------------------------------- */
    /*                                  Burn                                  */
    /* ---------------------------------------------------------------------- */

    function previewBurn(uint256 detfIn, IERC20 tokenOut) public view returns (uint256 amountOut) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive || detfIn == 0) return 0;
        if (!s.burnTable.tokens._contains(address(tokenOut))) return 0;
        uint256 supply_ = ERC20Repo._totalSupply();
        if (supply_ == 0) return 0;
        uint256 lpOut_ = (detfIn * _nftLp()) / supply_;
        if (lpOut_ == 0) return 0;
        IStandardExchange v_ = s.burnTable.vaultOf[address(tokenOut)];
        address pair_ = _hookPairOfVault(v_);
        // Match burn(): exitProportional + rejoin DETF + pay remaining pair (H10: not exitSingleAsset).
        uint256 residual_ = _previewPropPairResidual(lpOut_, pair_);
        if (address(tokenOut) == pair_) return residual_;
        if (address(tokenOut) == address(v_)) {
            try v_.previewExchangeIn(IERC20(pair_), residual_, IERC20(address(v_))) returns (uint256 sh_) {
                return sh_;
            } catch {
                return 0;
            }
        }
        try v_.previewExchangeIn(IERC20(pair_), residual_, tokenOut) returns (uint256 o_) {
            return o_;
        } catch {
            return 0;
        }
    }

    function _previewPropPairResidual(uint256 lpOut_, address pair_) private view returns (uint256 residual_) {
        uint256[] memory amounts_ = _hook().previewExitProportional(lpOut_);
        address[] memory tokens_ = _hook().tokens();
        uint256 n_ = amounts_.length < tokens_.length ? amounts_.length : tokens_.length;
        for (uint256 i; i < n_; ++i) {
            if (tokens_[i] == pair_) return amounts_[i];
        }
    }

    function burn(
        uint256 detfIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        uint256 deadline
    ) public nonReentrant returns (uint256 amountOut) {
        amountOut = _burnPath(detfIn, tokenOut, minAmountOut, recipient, deadline);
    }

    function _burnPath(
        uint256 detfIn_,
        IERC20 tokenOut_,
        uint256 minAmountOut_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 amountOut_) {
        _requireActive(deadline_, detfIn_);
        _requireReserveLive();
        if (recipient_ == address(0)) recipient_ = msg.sender;
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.burnTable.tokens._contains(address(tokenOut_))) {
            revert Repo.InvalidRoute(address(this), address(tokenOut_));
        }
        _realizeExpansionIfNeeded();
        if (!_isBurningAllowedToken(tokenOut_)) {
            revert Repo.BurningNotAllowed(_syntheticPrice(), s.burnThreshold);
        }
        uint256 supply_ = ERC20Repo._totalSupply();
        uint256 lpOut_ = (detfIn_ * _nftLp()) / supply_;
        if (lpOut_ == 0) revert Repo.ZeroAmount();
        IERC20(address(this)).safeTransferFrom(msg.sender, address(this), detfIn_);
        _burnDetf(address(this), detfIn_);
        uint256[] memory exitAmts_ = _exitBurnLp(lpOut_, deadline_);
        amountOut_ = _payBurnOut(tokenOut_, recipient_, deadline_);
        if (amountOut_ < minAmountOut_) {
            revert IStandardExchangeErrors.MinAmountNotMet(minAmountOut_, amountOut_);
        }
        _rejoinExitDetf(exitAmts_, deadline_);
        _returnLeftoverLp();
        _tryCompoundProtocolRewards();
        _trySweepDust();
        _syncAllExpectedHoldReserves();
    }

    function _exitBurnLp(uint256 lpOut_, uint256 deadline_) private returns (uint256[] memory amounts_) {
        Repo.Storage storage s = Repo._layoutStruct();
        _pullNftLp(lpOut_);
        IERC20(s.hook).forceApprove(s.hook, lpOut_);
        amounts_ =
            _hook().exitProportional(lpOut_, address(this), new uint256[](_hook().tokens().length), deadline_);
        IERC20(s.hook).forceApprove(s.hook, 0);
    }

    function _rejoinExitDetf(uint256[] memory amounts_, uint256 deadline_) private {
        address[] memory tokens_ = _hook().tokens();
        uint256 n_ = amounts_.length < tokens_.length ? amounts_.length : tokens_.length;
        for (uint256 i; i < n_; ++i) {
            if (tokens_[i] == address(this) && amounts_[i] > 0) {
                uint256 have_ = IERC20(address(this)).balanceOf(address(this));
                uint256 joinAmt_ = amounts_[i] < have_ ? amounts_[i] : have_;
                if (joinAmt_ == 0) continue;
                IERC20(address(this)).forceApprove(Repo._layoutStruct().hook, joinAmt_);
                _hook().joinSingleAssetExactIn(
                    address(this), joinAmt_, _bondLpHolder(), 0, deadline_
                );
                IERC20(address(this)).forceApprove(Repo._layoutStruct().hook, 0);
            }
        }
    }

    function _payBurnOut(IERC20 tokenOut_, address recipient_, uint256 deadline_)
        private
        returns (uint256 amountOut_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        IStandardExchange v_ = s.burnTable.vaultOf[address(tokenOut_)];
        address pair_ = _hookPairOfVault(v_);
        uint256 residual_ = IERC20(pair_).balanceOf(address(this));
        if (address(tokenOut_) == pair_) {
            amountOut_ = residual_;
            if (amountOut_ > 0) IERC20(pair_).safeTransfer(recipient_, amountOut_);
            return amountOut_;
        }
        return _nestedExchangeInPush(
            IStandardExchangeIn(address(v_)),
            IERC20(pair_),
            residual_,
            tokenOut_,
            0,
            recipient_,
            deadline_
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                                  Bond                                  */
    /* ---------------------------------------------------------------------- */

    struct BondSeat {
        IStandardExchange vault;
        address pair;
        address capital;
        uint256 amount;
    }

    function bond(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 lockDuration,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) public nonReentrant returns (uint256 tokenId, uint256 shares) {
        _requireNotDisabled();
        _requireActive(deadline, amountIn);
        if (recipient == address(0)) recipient = msg.sender;
        Repo.Storage storage s = Repo._layoutStruct();
        if (s.isReserveLive) {
            _realizeExpansionIfNeeded();
            if (!s.bondTable.tokens._contains(address(tokenIn))) {
                revert Repo.InvalidRoute(address(tokenIn), address(this));
            }
        } else {
            _rejectPretransferredFirstBond(pretransferred, amountIn);
            _requireReserveWired();
        }
        BondSeat memory seat_ = _seatBond(tokenIn, amountIn, pretransferred, deadline, s.isReserveLive);
        uint256 g_ = _quoteBondG(seat_.pair, _bondPairEq(seat_));
        if (g_ == 0) revert Repo.FirstBondBelowMinimumLiquidity();
        MintSplit memory split_ = _splitBondDetf(g_);
        shares = _joinBond(g_, seat_);
        if (!s.isReserveLive && shares == 0) revert Repo.FirstBondBelowMinimumLiquidity();
        if (split_.userDetf > 0) _mintDetf(recipient, split_.userDetf);
        tokenId = _openBondNft(shares, lockDuration, recipient);
        Repo._addUserBondedLp(shares);
        if (!s.isReserveLive) {
            Repo._setReserveLive();
            emit ReserveLive(tokenId, shares);
        }
        _topUpFeeCreatorShares();
        if (split_.inventoryDetf > 0 && address(s.bondNftVault) != address(0)) {
            _mintDetf(address(s.bondNftVault), split_.inventoryDetf);
        }
        _tryCompoundProtocolRewards();
        _trySweepDust();
        _syncAllExpectedHoldReserves();
    }

    function _seatBond(
        IERC20 tokenIn_,
        uint256 amountIn_,
        bool pretransferred_,
        uint256 deadline_,
        bool live_
    ) private returns (BondSeat memory seat_) {
        uint256 pulled_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
        Repo.Storage storage s = Repo._layoutStruct();
        if (live_) {
            seat_.vault = s.bondTable.vaultOf[address(tokenIn_)];
            seat_.pair = _hookPairOfVault(seat_.vault);
        } else {
            seat_.pair = _firstBondPair(address(tokenIn_));
            seat_.vault = IStandardExchange(IUniswapV4SeBufferHook(s.hook).standardExchangeOf(seat_.pair));
        }
        if (address(tokenIn_) == seat_.pair || address(tokenIn_) == address(seat_.vault)) {
            seat_.capital = address(tokenIn_);
            seat_.amount = pulled_;
        } else {
            seat_.capital = address(seat_.vault);
            seat_.amount = _toShare(seat_.vault, tokenIn_, pulled_, deadline_);
        }
    }

    function _bondPairEq(BondSeat memory seat_) private view returns (uint256) {
        if (seat_.capital == seat_.pair) return seat_.amount;
        return _pairEq(seat_.vault, IERC20(seat_.capital), seat_.amount);
    }

    function _joinBond(uint256 g_, BondSeat memory seat_) private returns (uint256 shares_) {
        _mintDetf(address(this), g_);
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive && _hook().firstJoinMustBeFullBook()) {
            return _joinFirstBondFullBook(g_, seat_);
        }
        address[] memory joinToks_ = new address[](2);
        uint256[] memory joinAmts_ = new uint256[](2);
        joinToks_[0] = address(this);
        joinToks_[1] = seat_.capital;
        joinAmts_[0] = g_;
        joinAmts_[1] = seat_.amount;
        shares_ = _joinUnbalanced(joinToks_, joinAmts_);
    }

    /// @notice First bond: joinUnbalanced every requiredFirstBondTokens leg (pair or that pair's share).
    /// @dev Lead capital is already pulled. Other non-DETF legs are pulled from msg.sender at opening-rate size.
    function _joinFirstBondFullBook(uint256 g_, BondSeat memory seat_) private returns (uint256 shares_) {
        address[] memory required_ = _hook().requiredFirstBondTokens();
        uint256 n_ = required_.length;
        address[] memory joinToks_ = new address[](n_);
        uint256[] memory joinAmts_ = new uint256[](n_);
        Repo.Storage storage s = Repo._layoutStruct();
        for (uint256 i; i < n_; ++i) {
            address t_ = required_[i];
            if (t_ == address(this)) {
                joinToks_[i] = t_;
                joinAmts_[i] = g_;
                continue;
            }
            if (t_ == seat_.pair) {
                joinToks_[i] = seat_.capital;
                joinAmts_[i] = seat_.amount;
                continue;
            }
            uint256 opening_ = s.openingOfPair[t_];
            if (opening_ == 0) opening_ = s.creationOfPair[t_];
            uint256 need_ = Math.mulDiv(g_, opening_, ONE_WAD);
            if (need_ == 0) revert Repo.FirstBondBelowMinimumLiquidity();
            joinToks_[i] = t_;
            joinAmts_[i] = _pullToken(IERC20(t_), need_, false);
        }
        shares_ = _joinUnbalanced(joinToks_, joinAmts_);
    }

    function _firstBondPair(address tokenIn_) internal view returns (address pair_) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (s.hookPairTokens._contains(tokenIn_)) return tokenIn_;
        address[] storage pairs_ = s.hookPairTokens._values();
        for (uint256 i; i < pairs_.length; ++i) {
            address se_ = IUniswapV4SeBufferHook(s.hook).standardExchangeOf(pairs_[i]);
            if (tokenIn_ == se_) return pairs_[i];
        }
        if (pairs_.length == 1) return pairs_[0];
        revert Repo.InvalidRoute(tokenIn_, address(this));
    }

    function _openBondNft(uint256 lpOut_, uint256 lockDuration_, address recipient_)
        private
        returns (uint256 tokenId_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0) || lpOut_ == 0) return 0;
        tokenId_ = DETFBondLifecycleLib._createBondPosition(
            IDetfSelfNftInventoryPolicy(address(s.bondNftVault)),
            lpOut_,
            _effectiveLockDuration(lockDuration_),
            recipient_
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                                 Close                                  */
    /* ---------------------------------------------------------------------- */

    function closeBondMature(
        uint256 tokenId,
        uint256[] calldata minAmountsOut,
        address recipient,
        uint256 deadline
    ) public nonReentrant returns (uint256[] memory amountsOut) {
        _requireMature(tokenId);
        _requireNotStandingRewardNft(tokenId);
        _requireActive(deadline, 1);
        if (recipient == address(0)) recipient = msg.sender;
        Repo.Storage storage s = Repo._layoutStruct();
        bool custom_ = s.closeRouteMode == IUniswapV4Detf.RouteTableMode.Custom;
        address[] memory tokens_ = _hook().tokens();
        _requireCloseMins(custom_, tokens_, minAmountsOut);
        _realizeExpansionIfNeeded();
        uint256 orig_ = s.bondNftVault.originalSharesOf(tokenId);
        uint256 lpOut_ = s.bondNftVault.convertToAssets(orig_);
        if (lpOut_ == 0) revert Repo.ZeroAmount();
        s.bondNftVault.retireMaturePosition(tokenId, recipient);
        Repo._subUserBondedLp(orig_);
        uint256[] memory withdrawn_ = _exitAndRejoinDetf(lpOut_, tokens_, deadline);
        if (custom_) {
            amountsOut = _payCustomClose(tokens_, minAmountsOut[0], recipient, deadline);
        } else {
            amountsOut = _payDefaultClose(tokens_, withdrawn_, minAmountsOut, recipient);
        }
        _returnLeftoverLp();
        _tryCompoundProtocolRewards();
        _trySweepDust();
        _syncAllExpectedHoldReserves();
    }

    function _requireCloseMins(
        bool custom_,
        address[] memory tokens_,
        uint256[] calldata minAmountsOut_
    ) private view {
        if (custom_) {
            if (minAmountsOut_.length != 1) revert Repo.InvalidRoute(address(0), address(0));
            return;
        }
        if (minAmountsOut_.length != tokens_.length) revert Repo.InvalidRoute(address(0), address(0));
        for (uint256 i; i < tokens_.length; ++i) {
            if (tokens_[i] == address(this) && minAmountsOut_[i] != 0) {
                revert Repo.InvalidRoute(address(this), address(0));
            }
        }
    }

    function _exitAndRejoinDetf(uint256 lpOut_, address[] memory tokens_, uint256 deadline_)
        private
        returns (uint256[] memory withdrawn_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        _pullNftLp(lpOut_);
        IERC20(s.hook).forceApprove(s.hook, lpOut_);
        withdrawn_ =
            _hook().exitProportional(lpOut_, address(this), new uint256[](tokens_.length), deadline_);
        IERC20(s.hook).forceApprove(s.hook, 0);
        uint256 detfWithdrawn_;
        for (uint256 j; j < tokens_.length; ++j) {
            if (tokens_[j] == address(this)) detfWithdrawn_ = withdrawn_[j];
        }
        if (detfWithdrawn_ == 0) return withdrawn_;
        IERC20(address(this)).forceApprove(s.hook, detfWithdrawn_);
        uint256 lpRejoin_ =
            _hook().joinSingleAssetExactIn(address(this), detfWithdrawn_, _bondLpHolder(), 0, deadline_);
        IERC20(address(this)).forceApprove(s.hook, 0);
        if (lpRejoin_ > 0) {
            s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpRejoin_);
            _topUpFeeCreatorShares();
        }
    }

    function _payCustomClose(
        address[] memory tokens_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) private returns (uint256[] memory amountsOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        address closeTok_ = address(s.closeTable.tokens._values()[0]);
        for (uint256 k; k < tokens_.length; ++k) {
            address t_ = tokens_[k];
            if (t_ == address(this) || t_ == closeTok_) continue;
            uint256 leftover_ = IERC20(t_).balanceOf(address(this));
            if (leftover_ == 0) continue;
            IERC20(t_).forceApprove(s.hook, leftover_);
            _hook().ownerSwapExactIn(t_, closeTok_, leftover_, 0, deadline_);
            IERC20(t_).forceApprove(s.hook, 0);
        }
        amountsOut_ = new uint256[](1);
        amountsOut_[0] = IERC20(closeTok_).balanceOf(address(this));
        if (amountsOut_[0] < minOut_) {
            revert IStandardExchangeErrors.MinAmountNotMet(minOut_, amountsOut_[0]);
        }
        if (amountsOut_[0] > 0) IERC20(closeTok_).safeTransfer(recipient_, amountsOut_[0]);
    }

    function _payDefaultClose(
        address[] memory tokens_,
        uint256[] memory withdrawn_,
        uint256[] calldata minAmountsOut_,
        address recipient_
    ) private returns (uint256[] memory amountsOut_) {
        amountsOut_ = new uint256[](tokens_.length);
        uint256 n_ = tokens_.length < withdrawn_.length ? tokens_.length : withdrawn_.length;
        for (uint256 m; m < n_; ++m) {
            if (tokens_[m] == address(this)) continue;
            uint256 have_ = IERC20(tokens_[m]).balanceOf(address(this));
            uint256 pay_ = withdrawn_[m] < have_ ? withdrawn_[m] : have_;
            if (pay_ < minAmountsOut_[m]) {
                revert IStandardExchangeErrors.MinAmountNotMet(minAmountsOut_[m], pay_);
            }
            amountsOut_[m] = pay_;
            if (pay_ > 0) IERC20(tokens_[m]).safeTransfer(recipient_, pay_);
        }
    }

    function previewCloseBondMature(uint256 tokenId) public view returns (uint256[] memory amountsOut) {
        Repo.Storage storage s = Repo._layoutStruct();
        address[] memory tokens_ = _hook().tokens();
        bool custom_ = s.closeRouteMode == IUniswapV4Detf.RouteTableMode.Custom;
        uint256 orig_ = s.bondNftVault.originalSharesOf(tokenId);
        if (orig_ == 0) {
            return custom_ ? new uint256[](1) : new uint256[](tokens_.length);
        }
        uint256 lpOut_ = s.bondNftVault.convertToAssets(orig_);
        uint256[] memory withdrawn_ = _hook().previewExitProportional(lpOut_);
        if (custom_) {
            amountsOut = new uint256[](1);
            address closeTok_ = address(s.closeTable.tokens._values()[0]);
            for (uint256 i; i < tokens_.length; ++i) {
                if (tokens_[i] == closeTok_) amountsOut[0] += withdrawn_[i];
            }
            return amountsOut;
        }
        amountsOut = withdrawn_;
        for (uint256 j; j < tokens_.length; ++j) {
            if (tokens_[j] == address(this)) amountsOut[j] = 0;
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                                 Donate                                 */
    /* ---------------------------------------------------------------------- */

    function donate(IERC20 token, uint256 amount, bool pretransferred) public {
        Repo.Storage storage s = Repo._layoutStruct();
        IDetfNftReserveDonation(address(s.bondNftVault)).donate(
            msg.sender, token, amount, 0, pretransferred, block.timestamp + 1
        );
    }

    function joinDonatedCapital(IERC20 token, uint256 amount, uint256 deadline)
        public
        nonReentrant
        returns (uint256 lpOut)
    {
        _requireBondNft();
        _requireReserveLive();
        _requireActive(deadline, amount);
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(token) == address(this)) {
            IERC20(address(this)).safeTransferFrom(msg.sender, address(this), amount);
            lpOut = _joinShare(amount, address(this));
            _trySweepDust();
            _syncAllExpectedHoldReserves();
            return lpOut;
        }
        if (address(token) == s.hook) {
            return 0;
        }
        bool allowed_ = s.donateTable.tokens._contains(address(token));
        if (!allowed_) revert Repo.InvalidRoute(address(token), address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IStandardExchange v_ = s.donateTable.vaultOf[address(token)];
        uint256 shareAmt_ = _toShare(v_, token, amount, deadline);
        lpOut = _joinShare(shareAmt_, address(v_));
        _trySweepDust();
        _syncAllExpectedHoldReserves();
    }

    function previewJoinDonatedCapital(IERC20 token, uint256 amount)
        public
        view
        returns (uint256 lpOut)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive || amount == 0) return 0;
        if (address(token) == address(this)) {
            return _hook().previewJoinSingleAssetExactIn(address(this), amount);
        }
        if (address(token) == s.hook) return amount;
        if (!s.donateTable.tokens._contains(address(token))) return 0;
        IStandardExchange v_ = s.donateTable.vaultOf[address(token)];
        uint256 shareAmt_ = address(token) == address(v_) ? amount : 0;
        if (shareAmt_ == 0) {
            try v_.previewExchangeIn(token, amount, IERC20(address(v_))) returns (uint256 sh_) {
                shareAmt_ = sh_;
            } catch {
                return 0;
            }
        }
        return _hook().previewJoinSingleAssetExactIn(address(v_), shareAmt_);
    }

    function notifyReserveDonated() public {
        _requireBondNft();
        _topUpFeeCreatorShares();
        _trySweepDust();
        _syncAllExpectedHoldReserves();
    }

    function sweepDust() public nonReentrant {
        _sweepDustBody();
        _syncAllExpectedHoldReserves();
    }

    function compoundProtocolRewards() public nonReentrant returns (uint256 detfIn, uint256 lpOut) {
        _realizeExpansionIfNeeded();
        (detfIn, lpOut) = _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @notice Preview DETF paid if `lpAmount` of hook LP is unwound.
    function previewClaimLiquidity(uint256 lpAmount) public view returns (uint256 detfOut) {
        return _previewClaimLiquidity(lpAmount);
    }

    /// @notice Bond NFT / claim token unwind: pay DETF to `recipient`.
    /// @dev Claim-token path is family D15: harvest pending first; skip LP when pending covers owed;
    ///      shortfall unwinds convertToAssets-scaled LP and dumps leftover pair to DETF.
    ///      No `_requireNotDisabled` (CROPS: redeem still works). Selector matches `IDetf.claimLiquidity`.
    function claimLiquidity(uint256 lpAmount, address recipient) public nonReentrant returns (uint256 detfOut) {
        Repo.Storage storage s = Repo._layoutStruct();
        address bond_ = address(s.bondNftVault);
        address claim_ = address(s.rebasingClaimToken);
        if (msg.sender != bond_ && msg.sender != claim_ && msg.sender != address(this)) {
            revert Repo.NotAuthorized(msg.sender);
        }
        if (lpAmount == 0) revert Repo.ZeroAmount();
        if (recipient == address(0)) recipient = msg.sender;
        _realizeExpansionIfNeeded();
        bool fromClaim_ = msg.sender == claim_ || msg.sender == address(this);
        uint256 unwindLp_ = lpAmount;
        uint256 owed_;
        if (fromClaim_) {
            owed_ = _claimHint();
            if (owed_ == 0) {
                (owed_, unwindLp_,) = _claimOwedDetf(lpAmount);
            } else {
                unwindLp_ = _claimUnwindLp(lpAmount);
            }
        }
        uint256 detfBefore_ = IERC20(address(this)).balanceOf(address(this));
        uint256 harvested_;
        if (fromClaim_ && bond_ != address(0)) {
            harvested_ = s.bondNftVault.reallocateDetfNftRewards(address(this));
        }
        if (fromClaim_ && _claimPayFromPending(owed_, harvested_, recipient)) {
            return owed_;
        }
        if (fromClaim_ && bond_ != address(0)) {
            _claimRemoveOrigShares(lpAmount);
        }
        _exitLpToDetf(unwindLp_, block.timestamp + 1);
        if (fromClaim_) _dumpSittingPairToDetf();
        uint256 produced_ = IERC20(address(this)).balanceOf(address(this));
        produced_ = produced_ > detfBefore_ ? produced_ - detfBefore_ : 0;
        detfOut = fromClaim_ ? _claimPayAmount(owed_, produced_) : produced_;
        if (fromClaim_ && owed_ > 0 && detfOut > owed_) detfOut = owed_;
        if (detfOut > 0) IERC20(address(this)).safeTransfer(recipient, detfOut);
        if (produced_ > detfOut) _rejoinDetfAsProtocolLp(produced_ - detfOut);
        _returnLeftoverLp();
        _trySweepDust();
        _syncAllExpectedHoldReserves();
    }

    /* ---------------------------------------------------------------------- */
    /*                                 Wire                                   */
    /* ---------------------------------------------------------------------- */

    function completeReserveBondNft() public returns (address bondNftVault_) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (s.hook == address(0)) revert Repo.ReserveNotWired();
        if (address(s.bondNftVault) != address(0)) revert Repo.ReserveBondNftAlreadyWired();
        address detf_ = address(this);
        IDETFNFTVault bondVault_ = IDETFNFTVault(
            IUniswapV4DetfBondNFTVaultDFPkg(s.bondNftVaultPkg).deployVault(
                DETFChildTokenMetadata.resolveBondName(s.bondName, ERC20Repo._name()),
                DETFChildTokenMetadata.resolveBondSymbol(s.bondSymbol, ERC20Repo._symbol()),
                IDetf(detf_),
                IERC20(s.hook),
                IERC20(detf_),
                0,
                detf_
            )
        );
        uint256 detfNftId_;
        address feeTo_ = address(s.feeOracle.feeTo());
        address creator_ = s.creator;
        try bondVault_.initializeReservedBondNfts(feeTo_, creator_) returns (uint256 id_) {
            detfNftId_ = id_;
        } catch {
            detfNftId_ = bondVault_.initializeDETFNFT();
        }
        Repo._setBondNft(bondVault_, detfNftId_, DETF_FEE_TO_BOND_NFT_ID);
        emit ReserveBondNftWired(s.hook, address(bondVault_), detfNftId_, DETF_FEE_TO_BOND_NFT_ID);
        return address(bondVault_);
    }

    function completeReserveClaim() public returns (address rebasingClaimToken_) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0)) revert Repo.ReserveNotWired();
        if (address(s.rebasingClaimToken) != address(0)) revert Repo.ReserveClaimAlreadyWired();
        address[] storage pairs_ = s.hookPairTokens._values();
        IERC20 rateAsset_ = IERC20(pairs_.length == 0 ? address(this) : pairs_[0]);
        IRebasingClaimToken claimToken_ = IRebasingClaimToken(
            IRebasingClaimTokenDFPkg(s.rebasingClaimTokenPkg).deployToken(
                IDetf(address(this)),
                s.bondNftVault,
                rateAsset_,
                s.detfNftId,
                address(this),
                DETFChildTokenMetadata.resolveClaimName(s.claimName, ERC20Repo._name()),
                DETFChildTokenMetadata.resolveClaimSymbol(s.claimSymbol, ERC20Repo._symbol())
            )
        );
        Repo._setClaim(claimToken_);
        emit ReserveClaimWired(s.hook, address(claimToken_));
        return address(claimToken_);
    }
}
