// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookMath.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib as ClaimLib
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib.sol";

/**
 * @title UniswapV4DualStandardExchangeBufferConstantProductHookCommon
 * @notice Immutables, pool-order maps, claims, SE buffer/unwrap, D78 claim-in, take/settle.
 */
abstract contract UniswapV4DualStandardExchangeBufferConstantProductHookCommon {
    using SafeERC20 for IERC20;

    /// @dev Uniswap Permit2 well-known address (C18) — not a ctor arg.
    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    error ZeroAddress();
    error ZeroAmount();
    error NotPoolManager();
    error TokenNotInVaultTokens();
    error SameStandardExchange();
    error SamePairToken();
    error NotLive();
    error NotZapEligible();
    error InvalidPairToken();
    error DeadlineExpired();
    error InsufficientLpOut();
    error InsufficientTokenOut();
    error AlreadyInitialized();
    error Reentrancy();
    error LiquidityNotAllowed();
    error InvalidPoolToken();
    error InvalidPoolFee();
    error HookNotImplemented();
    error InvalidPermit2Data();

    IPoolManager internal immutable _poolManager;
    IVaultFeeOracleQuery internal immutable _feeOracle;
    address internal immutable _se0;
    address internal immutable _se1;
    address internal immutable _token0;
    address internal immutable _token1;
    address internal immutable _currency0;
    address internal immutable _currency1;

    constructor(
        IPoolManager poolManager_,
        IVaultFeeOracleQuery feeOracle_,
        address se0_,
        address token0_,
        address se1_,
        address token1_
    ) {
        _poolManager = poolManager_;
        _feeOracle = feeOracle_;
        _se0 = se0_;
        _token0 = token0_;
        _se1 = se1_;
        _token1 = token1_;
        if (token0_ < token1_) {
            _currency0 = token0_;
            _currency1 = token1_;
        } else {
            _currency0 = token1_;
            _currency1 = token0_;
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                                   views                                */
    /* ---------------------------------------------------------------------- */

    function poolManager() public view virtual returns (address) {
        return address(_poolManager);
    }

    function feeOracle() public view virtual returns (address) {
        return address(_feeOracle);
    }

    function permit2() public pure virtual returns (address) {
        return PERMIT2;
    }

    function standardExchange0() public view virtual returns (address) {
        return _se0;
    }

    function standardExchange1() public view virtual returns (address) {
        return _se1;
    }

    function token0() public view virtual returns (address) {
        return _token0;
    }

    function token1() public view virtual returns (address) {
        return _token1;
    }

    function currency0() public view virtual returns (address) {
        return _currency0;
    }

    function currency1() public view virtual returns (address) {
        return _currency1;
    }

    function claimSupply0() public view virtual returns (uint256) {
        return _claimSupply(_se0, _token0);
    }

    function claimSupply1() public view virtual returns (uint256) {
        return _claimSupply(_se1, _token1);
    }

    function claimSupplyCurrency0() public view virtual returns (uint256) {
        return _claimSupply(_seFor(_currency0), _currency0);
    }

    function claimSupplyCurrency1() public view virtual returns (uint256) {
        return _claimSupply(_seFor(_currency1), _currency1);
    }

    function tradingFeePercent() public pure virtual returns (uint256) {
        return Repo.TRADING_FEE_PERCENT;
    }

    function tradingFeeDenominator() public pure virtual returns (uint256) {
        return Repo.TRADING_FEE_DENOMINATOR;
    }

    function dexSwapFee() public view virtual returns (uint256) {
        (, uint256 feeWad) = _feeOracle.dexSwapFeeAndFeeToOfVault(address(this));
        return feeWad;
    }

    function feeTo() public view virtual returns (address) {
        (IFeeCollectorProxy ft,) = _feeOracle.dexSwapFeeAndFeeToOfVault(address(this));
        return address(ft);
    }

    function kLast() public view virtual returns (uint256) {
        return Repo._layout().kLast;
    }

    function _claimSupply(address se, address pairToken) internal view returns (uint256) {
        uint256 seBal = IERC20(se).balanceOf(address(this));
        if (seBal == 0) return 0;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seBal, IERC20(pairToken));
    }

    function _seFor(address pairToken) internal view returns (address) {
        if (pairToken == _token0) return _se0;
        if (pairToken == _token1) return _se1;
        revert InvalidPairToken();
    }

    function _isBoundPairToken(address token) internal view returns (bool) {
        return token == _token0 || token == _token1;
    }

    function _isLive() internal view returns (bool) {
        return claimSupplyCurrency0() > 0 && claimSupplyCurrency1() > 0;
    }

    function _isZapEligible() internal view returns (bool) {
        return _isLive() && Repo._layout().totalSupply > Repo.MINIMUM_LIQUIDITY;
    }

    function _requireLive() internal view {
        if (!_isLive()) revert NotLive();
    }

    function _requireZapEligible() internal view {
        if (!_isZapEligible()) revert NotZapEligible();
    }

    function _onlyPoolManager() internal view {
        if (msg.sender != address(_poolManager)) revert NotPoolManager();
    }

    function _requireNonZero(uint256 amount) internal pure {
        if (amount == 0) revert ZeroAmount();
    }

    function _requireDeadline(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert DeadlineExpired();
    }

    function _decimalsCurrency0() internal view returns (uint8) {
        return Repo._layout().decimalsCurrency0;
    }

    function _decimalsCurrency1() internal view returns (uint8) {
        return Repo._layout().decimalsCurrency1;
    }

    function _decimalsOf(address token) internal view returns (uint8) {
        if (token == _currency0) return _decimalsCurrency0();
        if (token == _currency1) return _decimalsCurrency1();
        revert InvalidPairToken();
    }

    function _toWadCurrency(address token, uint256 amount) internal view returns (uint256) {
        return Math.toWad(amount, _decimalsOf(token));
    }

    function _fromWadFloor(address token, uint256 amountWad) internal view returns (uint256) {
        return Math.fromWadFloor(amountWad, _decimalsOf(token));
    }

    function _fromWadCeil(address token, uint256 amountWad) internal view returns (uint256) {
        return Math.fromWadCeil(amountWad, _decimalsOf(token));
    }

    function _wadProduct() internal view returns (uint256) {
        uint256 xN = Math.toWad(claimSupplyCurrency0(), _decimalsCurrency0());
        uint256 yN = Math.toWad(claimSupplyCurrency1(), _decimalsCurrency1());
        return xN * yN;
    }

    function _feeOnAndShare() internal view returns (bool feeOn, address feeTo_, uint256 ownerFeeShare) {
        (IFeeCollectorProxy ft, uint256 dexFeeWad) = _feeOracle.dexSwapFeeAndFeeToOfVault(address(this));
        feeTo_ = address(ft);
        feeOn = feeTo_ != address(0) && dexFeeWad != 0;
        ownerFeeShare = (dexFeeWad * Repo.TRADING_FEE_DENOMINATOR) / 1e18;
    }

    /* ---------------------------------------------------------------------- */
    /*                         D78 claim-in composition                       */
    /* ---------------------------------------------------------------------- */

    function _previewBufferClaimIn(address se, address pairToken, uint256 amountInRaw)
        internal
        view
        returns (uint256)
    {
        return ClaimLib.previewBufferClaimIn(se, pairToken, amountInRaw, _feeOracle, address(this));
    }

    function _invertBufferClaimIn(address se, address pairToken, uint256 claimInNeeded)
        internal
        view
        returns (uint256)
    {
        return ClaimLib.invertBufferClaimIn(se, pairToken, claimInNeeded, _feeOracle, address(this));
    }

    /* ---------------------------------------------------------------------- */
    /*                              SE buffer / unwrap                        */
    /* ---------------------------------------------------------------------- */

    function _buffer(address se, address pairToken, uint256 amount) internal returns (uint256 seOut) {
        _requireNonZero(amount);
        uint256 minOut = IStandardExchangeIn(se).previewExchangeIn(
            IERC20(pairToken), amount, IERC20(se)
        );
        // ERC-4626 SE pulls via balance-delta transferFrom (peer single-buffer path).
        // pretransferred=true only works when tokens arrive after the SE's before_ snapshot.
        IERC20(pairToken).forceApprove(se, amount);
        seOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(pairToken), amount, IERC20(se), minOut, address(this), false, block.timestamp
        );
    }

    function _unwrap(address se, address pairToken, uint256 seIn) internal returns (uint256 tokenOut) {
        _requireNonZero(seIn);
        uint256 minOut = IStandardExchangeIn(se).previewExchangeIn(
            IERC20(se), seIn, IERC20(pairToken)
        );
        tokenOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(se), seIn, IERC20(pairToken), minOut, address(this), false, block.timestamp
        );
    }

    function _unwrapExactOut(address se, address pairToken, uint256 tokenOut)
        internal
        returns (uint256 seIn)
    {
        _requireNonZero(tokenOut);
        seIn = IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(pairToken), tokenOut);
        uint256 spent = IStandardExchangeOut(se).exchangeOut(
            IERC20(se), seIn, IERC20(pairToken), tokenOut, address(this), false, block.timestamp
        );
        require(spent == seIn, "unwrap exact-out");
    }

    /* ---------------------------------------------------------------------- */
    /*                         take / settle (PoolManager)                    */
    /* ---------------------------------------------------------------------- */

    function _take(Currency currency, address to, uint256 amount) internal {
        if (amount == 0) return;
        _poolManager.take(currency, to, amount);
    }

    function _settle(Currency currency, uint256 amount) internal {
        if (amount == 0) return;
        _poolManager.sync(currency);
        IERC20(Currency.unwrap(currency)).safeTransfer(address(_poolManager), amount);
        _poolManager.settle();
    }

    /* ---------------------------------------------------------------------- */
    /*                              reentrancy                                */
    /* ---------------------------------------------------------------------- */

    modifier nonReentrant() {
        Repo.Layout storage l = Repo._layout();
        if (l.reentrancyStatus == Repo.ENTERED) revert Reentrancy();
        l.reentrancyStatus = Repo.ENTERED;
        _;
        l.reentrancyStatus = Repo.NOT_ENTERED;
    }

    /* ---------------------------------------------------------------------- */
    /*                              validation helpers                        */
    /* ---------------------------------------------------------------------- */

    function _requireTokenInVaultTokens(address se, address token) internal view {
        address[] memory tokens = IBasicVault(se).vaultTokens();
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i] == token) return;
        }
        revert TokenNotInVaultTokens();
    }

    function _readDecimals(address token) internal view returns (uint8) {
        try IERC20Metadata(token).decimals() returns (uint8 d) {
            return d;
        } catch {
            return 18;
        }
    }

    function _readSymbol(address token) internal view returns (string memory) {
        try IERC20Metadata(token).symbol() returns (string memory s) {
            return s;
        } catch {
            return _addressFragment(token);
        }
    }

    function _addressFragment(address a) internal pure returns (string memory) {
        bytes16 hexSymbols = "0123456789abcdef";
        bytes memory s = new bytes(6);
        uint160 v = uint160(a);
        s[0] = "0";
        s[1] = "x";
        s[2] = hexSymbols[(v >> 156) & 0xf];
        s[3] = hexSymbols[(v >> 152) & 0xf];
        s[4] = hexSymbols[(v >> 148) & 0xf];
        s[5] = hexSymbols[(v >> 144) & 0xf];
        return string(s);
    }

    function _buildLpMetadata()
        internal
        view
        returns (string memory name_, string memory symbol_)
    {
        string memory s0 = _readSymbol(_currency0);
        string memory s1 = _readSymbol(_currency1);
        symbol_ = string.concat("DSEBCP-", s0, "-", s1);
        name_ = string.concat("Dual SE Buffer CP ", s0, "/", s1);
    }

    function _refundPairDust(address token, address to) internal {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal > Repo.MAX_DUST_WEI) {
            IERC20(token).safeTransfer(to, bal);
        }
    }

    function _refundBothPairDust(address to) internal {
        _refundPairDust(_currency0, to);
        _refundPairDust(_currency1, to);
    }
}
