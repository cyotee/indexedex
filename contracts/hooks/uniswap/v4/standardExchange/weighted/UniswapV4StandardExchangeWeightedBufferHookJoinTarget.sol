// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {
    toBeforeSwapDelta,
    BeforeSwapDelta
} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BeforeSwapDelta.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";
import {
    UniswapV4SeBufferHookLegLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHookTarget
 * @notice Product logic: dual-scale weighted book, SE buffer-last LP, rated V4/SE swaps, MultiAssetLiquidity.
 * @dev No BaseHook / DeltaResolver inheritance. LP via ERC20Repo; inventory = face | live SE shares.
 */
import {
    UniswapV4StandardExchangeWeightedBufferHookLiquidityLib as LiqLib
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookLiquidityLib.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookTarget
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHookJoinTarget
 * @notice Join/exit + one-token aliases (inventory domain, buffer-last).
 */
abstract contract UniswapV4StandardExchangeWeightedBufferHookJoinTarget is
    UniswapV4StandardExchangeWeightedBufferHookTarget
{
    using SafeERC20 for IERC20;

/* ---------------------------------------------------------------------- */
    /*                         liquidity: join / exit                         */
    /* ---------------------------------------------------------------------- */

    function _invToPairOutPreview(uint256[] memory invOut)
        internal
        view
        returns (uint256[] memory pairOut)
    {
        Repo.Layout storage l = Repo._layout();
        pairOut = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
            if (invOut[i] == 0) continue;
            address se = l.standardExchanges[i];
            if (se == address(0)) {
                pairOut[i] = invOut[i];
            } else {
                pairOut[i] = IStandardExchangeIn(se).previewExchangeIn(
                    IERC20(se), invOut[i], IERC20(l.tokens[i])
                );
            }
        }
    }


    function _edgeToInvPreview(uint256[] memory amounts, bool[] memory amountIsSeShare)
        internal
        view
        returns (uint256[] memory invDeltas)
    {
        Repo.Layout storage l = Repo._layout();
        invDeltas = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
            if (amounts[i] == 0) continue;
            if (amountIsSeShare[i]) {
                invDeltas[i] = amounts[i];
            } else {
                address se = l.standardExchanges[i];
                if (se == address(0)) {
                    invDeltas[i] = amounts[i];
                } else {
                    invDeltas[i] = IStandardExchangeIn(se).previewExchangeIn(
                        IERC20(l.tokens[i]), amounts[i], IERC20(se)
                    );
                }
            }
        }
    }


    function _validateSeShareFlags(bool[] memory flags) internal view {
        Repo.Layout storage l = Repo._layout();
        if (flags.length != l.numTokens) revert ArrayLengthMismatch();
        for (uint8 i; i < l.numTokens; ++i) {
            if (flags[i] && l.standardExchanges[i] == address(0)) revert SeShareNotBuffered();
        }
    }


    function _invToEdgeOutPreview(uint256[] memory invOut, bool[] memory receiveSeShare)
        internal
        view
        returns (uint256[] memory edgeOut)
    {
        Repo.Layout storage l = Repo._layout();
        edgeOut = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
            if (invOut[i] == 0) continue;
            address se = l.standardExchanges[i];
            if (se == address(0)) {
                edgeOut[i] = invOut[i];
            } else if (receiveSeShare[i]) {
                edgeOut[i] = invOut[i];
            } else {
                edgeOut[i] = IStandardExchangeIn(se).previewExchangeIn(
                    IERC20(se), invOut[i], IERC20(l.tokens[i])
                );
            }
        }
    }


    function previewJoinProportional(uint256[] calldata amounts)
        public
        view
        returns (uint256 shares, uint256[] memory usedAmounts)
    {
        return _computeJoinProportional(amounts);
    }


    function joinProportional(
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public onlyLiquidityOwner nonReentrant returns (uint256 shares, uint256[] memory usedAmounts) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        uint256 protocolBefore = _maybeMintProtocolFee();
        bool first = _totalSupply() == 0;
        (shares, usedAmounts) = _computeJoinProportional(amounts);
        if (shares < sharesMin) revert Slippage();
        _commitJoin(usedAmounts, to, shares, first);
        protocolBefore;
    }


    function _computeJoinProportional(uint256[] memory amounts)
        internal
        view
        returns (uint256 shares, uint256[] memory used)
    {
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != l.numTokens) revert InvalidN();
        uint256 supply = _totalSupply();
        // amounts are pair-token edge; map to inventory for algebra
        uint256[] memory invIn = _pairToInvPreview(amounts);
        if (supply == 0) {
            return _firstMint(invIn, amounts);
        }
        uint256[] memory natives = _nativeAll();
        if (Math.isFullBookReserves(natives)) {
            return _fullPropJoin(amounts, invIn, supply);
        }
        return _partialJoin(amounts, invIn, supply);
    }


    function _firstMint(uint256[] memory invAmounts, uint256[] memory pairAmounts)
        internal
        view
        returns (uint256 shares, uint256[] memory usedPair)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 n = l.numTokens;
        usedPair = pairAmounts;
        uint256 pos = Math.countPositive(invAmounts);
        if (n == 2) {
            if (pos != 2) revert ZeroAmount();
        } else {
            if (pos < 2) revert ZeroAmount();
        }
        uint256[] memory scaled = _scaleInvAmounts(invAmounts);
        if (pos == n) {
            for (uint256 i; i < n; ++i) {
                if (invAmounts[i] == 0) revert ZeroAmount();
            }
            (shares,) = Math.firstMintSharesFull(l.weights, scaled);
        } else {
            (shares,) = Math.firstMintSharesPartial(l.weights, scaled);
        }
    }


    function _fullPropJoin(uint256[] memory pairAmounts, uint256[] memory invIn, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256[] memory usedPair)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 n = l.numTokens;
        for (uint256 i; i < n; ++i) {
            if (pairAmounts[i] == 0) revert ZeroAmount();
        }
        uint256[] memory aS = _scaleInvAmounts(invIn);
        uint256[] memory rS = _invWadAll();
        shares = Math.proportionalJoinShares(aS, rS, supply);
        usedPair = new uint256[](n);
        // proportional used inventory → back to pair (for SE use share used; pull is pair)
        // For prop joins user supplies max pair; used inventory = prop of live book
        for (uint256 i; i < n; ++i) {
            uint256 usedS = Math.proportionalUsedScaled(shares, rS[i], supply);
            uint256 usedInv = Math.descale(usedS, l.invScales[i]);
            if (usedInv == 0) revert Slippage();
            // map inv used → pair for pull: raw face or buffer invert
            if (l.standardExchanges[i] == address(0)) {
                usedPair[i] = usedInv;
            } else {
                if (invIn[i] == 0) revert ZeroAmount();
                usedPair[i] = (pairAmounts[i] * usedInv) / invIn[i];
                if (usedPair[i] == 0 || usedPair[i] > pairAmounts[i]) revert Slippage();
            }
        }
    }


    function _partialJoin(uint256[] memory pairAmounts, uint256[] memory invIn, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256[] memory usedPair)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 n = l.numTokens;
        uint256[] memory natives = new uint256[](n);
        for (uint8 i; i < n; ++i) {
            natives[i] = _nativeAt(i);
        }
        LiqLib.PartialJoinArgs memory a;
        a.weights = l.weights;
        a.invScales = l.invScales;
        a.natives = natives;
        a.invIn = invIn;
        a.pairAmounts = pairAmounts;
        a.ses = l.standardExchanges;
        a.supply = supply;
        LiqLib.PartialJoinResult memory r = LiqLib.partialJoin(a);
        shares = r.shares;
        usedPair = r.usedPair;
    }


    function _commitJoin(uint256[] memory pairUsed, address to, uint256 shares, bool firstMint)
        internal
    {
        _pullAmounts(pairUsed);
        _bufferLast(pairUsed);
        if (firstMint) {
            _mintLp(address(0), Math.MINIMUM_LIQUIDITY);
        }
        _mintLp(to, shares);
        _snapshotKLastIfFeeOn();
        _refundBufferedDust();
        _syncVaultReserves();
        int256[] memory deltas = new int256[](pairUsed.length);
        for (uint256 i; i < pairUsed.length; ++i) {
            deltas[i] = int256(pairUsed[i]);
        }
        emit IUniswapV4StandardExchangeWeightedBufferHook.Join(msg.sender, to, shares, deltas, 0);
    }


    function previewJoinUnbalanced(uint256[] calldata amounts) public view returns (uint256 shares) {
        return _quoteUnbalancedJoin(amounts);
    }

    /// @notice Family wrapper: tokens() order pair-token amounts.
    function joinUnbalanced(uint256[] calldata amounts, address to, uint256 sharesMin, uint256 deadline)
        public
        onlyLiquidityOwner
        nonReentrant
        returns (uint256 shares)
    {
        shares = _joinUnbalancedPairAmounts(amounts, to, sharesMin, deadline);
    }

    function previewJoinUnbalanced(address[] calldata tokensIn, uint256[] calldata amounts)
        public
        view
        returns (uint256 shares)
    {
        (uint256[] memory edge, bool[] memory isSe) = _accumulateJoin(tokensIn, amounts);
        if (!_isLive() && Math.countPositive(edge) != Repo._layout().numTokens) {
            return 0;
        }
        if (_anySeShare(isSe)) {
            uint256[] memory invIn = _edgeToInvPreview(edge, isSe);
            if (_totalSupply() == 0) {
                (shares,) = _firstMint(invIn, edge);
                return shares;
            }
            uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
            if (feeWad >= Math.WAD) return 0;
            return Math.unbalancedJoinShares(
                _invWadAll(), _scaleInvAmounts(invIn), Repo._layout().weights, _totalSupply(), feeWad
            );
        }
        if (_totalSupply() == 0) {
            (shares,) = _firstMint(_pairToInvPreview(edge), edge);
            return shares;
        }
        return _quoteUnbalancedJoin(edge);
    }

    function joinUnbalanced(
        address[] calldata tokensIn,
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public onlyLiquidityOwner nonReentrant returns (uint256 shares) {
        (uint256[] memory edge, bool[] memory isSe) = _accumulateJoin(tokensIn, amounts);
        _requireFirstJoinFullBook(edge);
        if (_anySeShare(isSe)) {
            return _joinUnbalancedFlexible(edge, isSe, to, sharesMin, deadline);
        }
        return _joinUnbalancedPairAmounts(edge, to, sharesMin, deadline);
    }

    function _joinUnbalancedPairAmounts(
        uint256[] memory amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) internal returns (uint256 shares) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != l.numTokens) revert InvalidN();
        if (_totalSupply() == 0) {
            if (Math.countPositive(amounts) != l.numTokens) revert NotFullBook();
            _maybeMintProtocolFee();
            (shares,) = _firstMint(_pairToInvPreview(amounts), amounts);
            if (shares < sharesMin) revert Slippage();
            _commitJoin(amounts, to, shares, true);
            return shares;
        }
        if (!Math.isFullBookReserves(_nativeAll())) revert NotFullBook();
        _maybeMintProtocolFee();
        shares = _quoteUnbalancedJoin(amounts);
        if (shares < sharesMin) revert Slippage();
        _commitJoin(amounts, to, shares, false);
    }

    function _joinUnbalancedFlexible(
        uint256[] memory edge,
        bool[] memory isSe,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) internal returns (uint256 shares) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        bool first = _totalSupply() == 0;
        uint256[] memory invIn = _edgeToInvPreview(edge, isSe);
        if (first) {
            _maybeMintProtocolFee();
            (shares,) = _firstMint(invIn, edge);
            if (shares < sharesMin) revert Slippage();
            _commitJoinFlexible(edge, isSe, to, shares, true);
            return shares;
        }
        if (!_isLive()) revert NotLive();
        _maybeMintProtocolFee();
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        shares = Math.unbalancedJoinShares(
            _invWadAll(), _scaleInvAmounts(invIn), Repo._layout().weights, _totalSupply(), feeWad
        );
        if (shares < sharesMin) revert Slippage();
        _commitJoinFlexible(edge, isSe, to, shares, false);
    }

    function _accumulateJoin(address[] calldata tokensIn, uint256[] calldata amounts)
        internal
        view
        returns (uint256[] memory edge, bool[] memory isSe)
    {
        if (tokensIn.length != amounts.length) {
            revert IStandardExchangeErrors.InvalidRoute(address(0), address(0));
        }
        Repo.Layout storage l = Repo._layout();
        uint8 n = l.numTokens;
        edge = new uint256[](n);
        isSe = new bool[](n);
        bool[] memory sawPair = new bool[](n);
        bool[] memory sawSe = new bool[](n);
        for (uint256 i; i < tokensIn.length; ++i) {
            if (amounts[i] == 0) continue;
            UniswapV4SeBufferHookLegLib.LegKind kind =
                UniswapV4SeBufferHookLegLib.classify(l.legs, tokensIn[i]);
            if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) {
                revert IStandardExchangeErrors.InvalidRoute(tokensIn[i], address(0));
            }
            uint8 idx;
            if (kind == UniswapV4SeBufferHookLegLib.LegKind.Detf) {
                idx = _tokenIndex(tokensIn[i]);
                edge[idx] += amounts[i];
                continue;
            }
            if (kind == UniswapV4SeBufferHookLegLib.LegKind.Pair) {
                idx = _tokenIndex(tokensIn[i]);
                if (sawSe[idx]) revert PairAndShareSameLeg();
                sawPair[idx] = true;
                edge[idx] += amounts[i];
                continue;
            }
            address pair_ = l.legs.pairOfStandardExchange[tokensIn[i]];
            idx = _tokenIndex(pair_);
            if (sawPair[idx]) revert PairAndShareSameLeg();
            sawSe[idx] = true;
            isSe[idx] = true;
            edge[idx] += amounts[i];
        }
    }

    function _anySeShare(bool[] memory isSe) internal pure returns (bool) {
        for (uint256 i; i < isSe.length; ++i) {
            if (isSe[i]) return true;
        }
        return false;
    }

    function _requireFirstJoinFullBook(uint256[] memory edge) internal view {
        if (_isLive()) return;
        if (Math.countPositive(edge) != Repo._layout().numTokens) {
            revert FirstJoinMustBeFullBook();
        }
    }


    function _quoteUnbalancedJoin(uint256[] memory pairAmounts) internal view returns (uint256 shares) {
        // Taxable join uses usageFee channel for growth; swap fee on unbalanced per monomorph uses dexSwapFee
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory invIn = _pairToInvPreview(pairAmounts);
        shares = Math.unbalancedJoinShares(
            _invWadAll(), _scaleInvAmounts(invIn), Repo._layout().weights, _totalSupply(), feeWad
        );
    }


    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
        public
        view
        returns (uint256 shares)
    {
        if (!_isLive() || amountIn == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        UniswapV4SeBufferHookLegLib.LegKind kind =
            UniswapV4SeBufferHookLegLib.classify(l.legs, tokenIn);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) return 0;
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
            address pair_ = l.legs.pairOfStandardExchange[tokenIn];
            return _quoteSingleJoinExactInFlexible(pair_, amountIn, true);
        }
        return _quoteSingleJoinExactIn(tokenIn, amountIn);
    }


    function joinSingleAssetExactIn(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public onlyLiquidityOwner nonReentrant returns (uint256 shares) {
        shares = _joinSingleAssetExactIn(tokenIn, amountIn, to, sharesMin, deadline);
    }


    function depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public onlyLiquidityOwner nonReentrant returns (uint256 shares) {
        shares = _joinSingleAssetExactIn(tokenIn, amountIn, to, sharesMin, deadline);
    }


    function _joinSingleAssetExactIn(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) internal returns (uint256 shares) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (amountIn == 0) revert ZeroAmount();
        if (!_isLive()) revert NotFullBook();
        Repo.Layout storage l = Repo._layout();
        UniswapV4SeBufferHookLegLib.LegKind kind =
            UniswapV4SeBufferHookLegLib.classify(l.legs, tokenIn);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) {
            revert IStandardExchangeErrors.InvalidRoute(tokenIn, address(0));
        }
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
            address pair_ = l.legs.pairOfStandardExchange[tokenIn];
            return _joinSingleAssetExactInFlexible(pair_, amountIn, true, to, sharesMin, deadline);
        }
        _maybeMintProtocolFee();
        shares = _quoteSingleJoinExactIn(tokenIn, amountIn);
        if (shares < sharesMin) revert Slippage();
        uint8 idx = _tokenIndex(tokenIn);
        uint256[] memory used = new uint256[](l.numTokens);
        used[idx] = amountIn;
        _commitJoin(used, to, shares, false);
        emit IUniswapV4StandardExchangeWeightedBufferHook.DepositSingle(msg.sender, to, tokenIn, amountIn, shares, 0);
    }


    function previewDepositSingle(address tokenIn, uint256 amountIn)
        public
        view
        returns (uint256 shares)
    {
        return previewJoinSingleAssetExactIn(tokenIn, amountIn);
    }


    function _quoteSingleJoinExactIn(address tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 shares)
    {
        uint8 idx = _tokenIndex(tokenIn);
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory pair = new uint256[](Repo._layout().numTokens);
        pair[idx] = amountIn;
        uint256[] memory invIn = _pairToInvPreview(pair);
        shares = Math.singleJoinExactInShares(
            _invWadAll(),
            Repo._layout().weights,
            idx,
            Math.scaleTo(invIn[idx], Repo._layout().invScales[idx]),
            _totalSupply(),
            feeWad
        );
    }


    function previewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut)
        public
        view
        returns (uint256 amountIn)
    {
        return _quoteSingleJoinExactOut(tokenIn, sharesOut);
    }


    function joinSingleAssetExactOut(
        address tokenIn,
        uint256 sharesOut,
        address to,
        uint256 amountInMax,
        uint256 deadline
    ) public onlyLiquidityOwner nonReentrant returns (uint256 amountIn) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (sharesOut == 0) revert ZeroAmount();
        if (_totalSupply() == 0 || !Math.isFullBookReserves(_nativeAll())) revert NotFullBook();
        _maybeMintProtocolFee();
        amountIn = _quoteSingleJoinExactOut(tokenIn, sharesOut);
        if (amountIn > amountInMax) revert Slippage();
        uint8 idx = _tokenIndex(tokenIn);
        uint256[] memory used = new uint256[](Repo._layout().numTokens);
        used[idx] = amountIn;
        _commitJoin(used, to, sharesOut, false);
    }


    function _quoteSingleJoinExactOut(address tokenIn, uint256 sharesOut)
        internal
        view
        returns (uint256 amountIn)
    {
        uint8 idx = _tokenIndex(tokenIn);
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        Repo.Layout storage l = Repo._layout();
        uint256 aS = Math.singleJoinExactOutAmountIn(
            _invWadAll(), l.weights, idx, sharesOut, _totalSupply(), feeWad
        );
        uint256 invNeeded = Math.descaleUp(aS, l.invScales[idx]);
        if (l.standardExchanges[idx] == address(0)) {
            amountIn = invNeeded;
        } else {
            // Invert buffer: pair such that sharesOut ≈ invNeeded — use linear approx via 1-share preview
            address se = l.standardExchanges[idx];
            address t = l.tokens[idx];
            // binary search forbidden — use SE preview invert via previewExchangeOut if available
            // amountIn pair → shares: use exchangeOut preview for exact shares as amountOut of SE
            // When SE is ERC-4626 wrapper, deposit assets for shares: approximate assets = convertToAssets
            // Use iterative single closed form: previewExchangeIn(pair, X, se) ≈ invNeeded
            // Closed form for 1:1 wrappers: amountIn ≈ invNeeded when no fee; with fee gross-up via usageFee
            uint256 feeSe = _feeOracle().usageFeeOfVault(se);
            if (feeSe >= Math.WAD) feeSe = 0;
            // Try: pairIn = invNeeded if rate 1; adjust with preview
            amountIn = invNeeded;
            uint256 got =
                IStandardExchangeIn(se).previewExchangeIn(IERC20(t), amountIn, IERC20(se));
            if (got < invNeeded && got > 0) {
                amountIn = (invNeeded * amountIn + got - 1) / got;
            }
            if (feeSe != 0) {
                amountIn = Math.grossUpExactOut(amountIn, feeSe);
            }
        }
    }


    function previewJoinProportionalFlexible(uint256[] calldata amounts, bool[] calldata amountIsSeShare)
        public
        view
        returns (uint256 shares, uint256[] memory usedAmounts)
    {
        return _computeJoinProportionalFlexible(amounts, amountIsSeShare);
    }


    function joinProportionalFlexible(
        uint256[] calldata amounts,
        bool[] calldata amountIsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public onlyLiquidityOwner nonReentrant returns (uint256 shares, uint256[] memory usedAmounts) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        _validateSeShareFlags(amountIsSeShare);
        _maybeMintProtocolFee();
        bool first = _totalSupply() == 0;
        (shares, usedAmounts) = _computeJoinProportionalFlexible(amounts, amountIsSeShare);
        if (shares < sharesMin) revert Slippage();
        _commitJoinFlexible(usedAmounts, amountIsSeShare, to, shares, first);
        emit IUniswapV4StandardExchangeWeightedBufferHook.JoinFlexible(
            msg.sender, to, shares, amounts, amountIsSeShare, usedAmounts, 0
        );
    }


    function _computeJoinProportionalFlexible(uint256[] memory amounts, bool[] memory amountIsSeShare)
        internal
        view
        returns (uint256 shares, uint256[] memory used)
    {
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != l.numTokens || amountIsSeShare.length != l.numTokens) {
            revert ArrayLengthMismatch();
        }
        _validateSeShareFlags(amountIsSeShare);
        uint256[] memory invIn = _edgeToInvPreview(amounts, amountIsSeShare);
        if (_totalSupply() == 0) {
            return _firstMint(invIn, amounts);
        }
        uint256[] memory natives = _nativeAll();
        if (Math.isFullBookReserves(natives)) {
            return _fullPropJoin(amounts, invIn, _totalSupply());
        }
        return _partialJoin(amounts, invIn, _totalSupply());
    }


    function _commitJoinFlexible(
        uint256[] memory usedAmounts,
        bool[] memory amountIsSeShare,
        address to,
        uint256 shares,
        bool firstMint
    ) internal {
        Repo.Layout storage l = Repo._layout();
        // Pull edge units (pair or SE share), then buffer-last pair legs only.
        for (uint8 i; i < l.numTokens; ++i) {
            if (usedAmounts[i] == 0) continue;
            if (amountIsSeShare[i]) {
                _pull(l.standardExchanges[i], usedAmounts[i]);
            } else {
                _pull(l.tokens[i], usedAmounts[i]);
            }
        }
        for (uint8 i; i < l.numTokens; ++i) {
            if (usedAmounts[i] == 0 || amountIsSeShare[i]) continue;
            _bufferToken(i, usedAmounts[i]);
        }
        if (firstMint) {
            _mintLp(address(0), Math.MINIMUM_LIQUIDITY);
        }
        _mintLp(to, shares);
        _snapshotKLastIfFeeOn();
        _refundBufferedDust();
        _syncVaultReserves();
    }


    function previewJoinSingleAssetExactInFlexible(address tokenIn, uint256 amountIn, bool amountIsSeShare)
        public
        view
        returns (uint256 shares)
    {
        return _quoteSingleJoinExactInFlexible(tokenIn, amountIn, amountIsSeShare);
    }


    function joinSingleAssetExactInFlexible(
        address tokenIn,
        uint256 amountIn,
        bool amountIsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public onlyLiquidityOwner nonReentrant returns (uint256 shares) {
        shares = _joinSingleAssetExactInFlexible(tokenIn, amountIn, amountIsSeShare, to, sharesMin, deadline);
    }


    function depositSingleFlexible(
        address tokenIn,
        uint256 amountIn,
        bool amountIsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public onlyLiquidityOwner nonReentrant returns (uint256 shares) {
        shares = _joinSingleAssetExactInFlexible(tokenIn, amountIn, amountIsSeShare, to, sharesMin, deadline);
    }


    function previewDepositSingleFlexible(address tokenIn, uint256 amountIn, bool amountIsSeShare)
        public
        view
        returns (uint256 shares)
    {
        return previewJoinSingleAssetExactInFlexible(tokenIn, amountIn, amountIsSeShare);
    }


    function _joinSingleAssetExactInFlexible(
        address tokenIn,
        uint256 amountIn,
        bool amountIsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) internal returns (uint256 shares) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (amountIn == 0) revert ZeroAmount();
        if (_totalSupply() == 0 || !Math.isFullBookReserves(_nativeAll())) revert NotFullBook();
        uint8 idx = _tokenIndex(tokenIn);
        if (amountIsSeShare && Repo._layout().standardExchanges[idx] == address(0)) {
            revert SeShareNotBuffered();
        }
        _maybeMintProtocolFee();
        shares = _quoteSingleJoinExactInFlexible(tokenIn, amountIn, amountIsSeShare);
        if (shares < sharesMin) revert Slippage();
        uint256[] memory used = new uint256[](Repo._layout().numTokens);
        used[idx] = amountIn;
        bool[] memory flags = new bool[](Repo._layout().numTokens);
        flags[idx] = amountIsSeShare;
        _commitJoinFlexible(used, flags, to, shares, false);
        emit IUniswapV4StandardExchangeWeightedBufferHook.DepositSingleFlexible(
            msg.sender, to, tokenIn, amountIn, amountIsSeShare, shares, 0
        );
    }


    function _quoteSingleJoinExactInFlexible(address tokenIn, uint256 amountIn, bool amountIsSeShare)
        internal
        view
        returns (uint256 shares)
    {
        uint8 idx = _tokenIndex(tokenIn);
        if (amountIsSeShare && Repo._layout().standardExchanges[idx] == address(0)) {
            revert SeShareNotBuffered();
        }
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory edge = new uint256[](Repo._layout().numTokens);
        edge[idx] = amountIn;
        bool[] memory flags = new bool[](Repo._layout().numTokens);
        flags[idx] = amountIsSeShare;
        uint256[] memory invIn = _edgeToInvPreview(edge, flags);
        shares = Math.singleJoinExactInShares(
            _invWadAll(),
            Repo._layout().weights,
            idx,
            Math.scaleTo(invIn[idx], Repo._layout().invScales[idx]),
            _totalSupply(),
            feeWad
        );
    }


}
