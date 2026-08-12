// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    UniswapV4WeightedSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookRepo.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";

/**
 * @title UniswapV4WeightedSwapHookCommon
 * @notice Shared helpers: rates fail-closed, pull/push, take/settle, fee-on growth, LP via ERC20Repo.
 * @dev No constructor immutables. Bindings live in Repo (initAccount). No BaseHook inheritance.
 *      `reserves()` public surface is MultiAssetBasicVaultFacet (selector collision avoided).
 */
abstract contract UniswapV4WeightedSwapHookCommon {
    using SafeERC20 for IERC20;

    error InvalidTokenOrder();
    error InvalidToken();
    error InvalidWeight();
    error InvalidN();
    error ZeroAmount();
    error DeadlineExpired();
    error Slippage();
    error NotFullBook();
    error PartialPathRestricted();
    error WouldZeroReserve();
    error SwapNotLive();
    error InvalidFeeWad();
    error RateProviderFailed();
    error InvalidPair();
    error InvalidPoolKey();
    error NotPoolManager();
    error LiquidityNotAllowed();
    error DonateNotAllowed();
    error HookNotImplemented();
    error Reentrancy();
    error ZeroAddress();
    error InsufficientLP();
    error InvalidPermit2Data();
    error TransferFailed();

    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    /* ---------------------------------------------------------------------- */
    /*                              public views                              */
    /* ---------------------------------------------------------------------- */

    function poolManager() public view virtual returns (IPoolManager) {
        return IPoolManager(Repo._layout().poolManager);
    }

    function feeOracle() public view virtual returns (IVaultFeeOracleQuery) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle);
    }

    function numTokens() public view virtual returns (uint8) {
        return Repo._layout().numTokens;
    }

    function tokens() public view virtual returns (address[] memory) {
        return Repo._layout().tokens;
    }

    function token(uint256 index) public view virtual returns (address) {
        return Repo._layout().tokens[index];
    }

    function getNormalizedWeights() public view virtual returns (uint256[] memory) {
        return Repo._layout().weights;
    }

    function rateProvider(uint256 index) public view virtual returns (address) {
        return Repo._layout().rateProviders[index];
    }

    function reserveOf(address token_) public view virtual returns (uint256) {
        return Repo._layout().reserves[_tokenIndex(token_)];
    }

    function dexSwapFee() public view virtual returns (uint256) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeOfVault(address(this));
    }

    function usageFee() public view virtual returns (uint256) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle).usageFeeOfVault(address(this));
    }

    function feeTo() public view virtual returns (address) {
        return address(IVaultFeeOracleQuery(Repo._layout().feeOracle).feeTo());
    }

    function kLast() public view virtual returns (uint256) {
        return Repo._layout().kLast;
    }

    function kLastMode() public view virtual returns (IUniswapV4WeightedSwapHook.KLastMode) {
        return IUniswapV4WeightedSwapHook.KLastMode(Repo._layout().kLastMode);
    }

    function isFullBook() public view virtual returns (bool) {
        return Math.isFullBookReserves(Repo._layout().reserves);
    }

    function effectiveRate(uint256 index) public view virtual returns (uint256) {
        return _effectiveRate(index);
    }

    function permit2() public pure virtual returns (address) {
        return PERMIT2;
    }

    function pairPoolTickSpacing() public view virtual returns (int24) {
        return Repo._layout().tickSpacing;
    }

    function pairPoolSqrtPriceX96() public view virtual returns (uint160) {
        return Repo._layout().sqrtPriceX96;
    }

    /* ---------------------------------------------------------------------- */
    /*                              token / rate helpers                      */
    /* ---------------------------------------------------------------------- */

    function _tokenIndex(address token_) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < l.numTokens; ++i) {
            if (l.tokens[i] == token_) return i;
        }
        revert InvalidPair();
    }

    function _effectiveRate(uint256 index) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint256 base = l.baseScales[index];
        address provider = l.rateProviders[index];
        uint256 oracleRate = Math.RATE_PRECISION;
        if (provider != address(0)) {
            oracleRate = _getRateFailClosed(provider);
        }
        return (base * oracleRate) / Math.RATE_PRECISION;
    }

    function _loadRates() internal view returns (uint256[] memory rates) {
        Repo.Layout storage l = Repo._layout();
        rates = new uint256[](l.numTokens);
        for (uint256 i; i < l.numTokens; ++i) {
            rates[i] = _effectiveRate(i);
        }
    }

    function _getRateFailClosed(address provider) internal view returns (uint256 rate) {
        (bool ok, bytes memory ret) =
            provider.staticcall(abi.encodeWithSelector(IRateProvider.getRate.selector));
        if (!ok || ret.length != 32) revert RateProviderFailed();
        rate = abi.decode(ret, (uint256));
        if (rate == 0) revert RateProviderFailed();
    }

    function _readDecimalsFailClosed(address token_) internal view returns (uint8 d) {
        (bool ok, bytes memory ret) =
            token_.staticcall(abi.encodeWithSelector(IERC20Metadata.decimals.selector));
        if (!ok || ret.length < 32) revert InvalidToken();
        uint256 raw = abi.decode(ret, (uint256));
        if (raw < 6 || raw > 18) revert InvalidToken();
        d = uint8(raw);
    }

    function _readSymbolSoft(address token_) internal view returns (string memory) {
        (bool ok, bytes memory ret) =
            token_.staticcall(abi.encodeWithSelector(IERC20Metadata.symbol.selector));
        if (ok && ret.length >= 64) {
            string memory s = abi.decode(ret, (string));
            if (bytes(s).length > 0) return s;
        }
        return _last4Hex(token_);
    }

    function _last4Hex(address token_) internal pure returns (string memory) {
        bytes16 hexChars = "0123456789abcdef";
        uint160 v = uint160(token_);
        bytes memory out = new bytes(4);
        out[0] = hexChars[uint8((v >> 12) & 0xf)];
        out[1] = hexChars[uint8((v >> 8) & 0xf)];
        out[2] = hexChars[uint8((v >> 4) & 0xf)];
        out[3] = hexChars[uint8(v & 0xf)];
        return string(out);
    }

    function _buildLpMetadata(address[] memory toks)
        internal
        view
        returns (string memory name_, string memory symbol_)
    {
        string memory body = _readSymbolSoft(toks[0]);
        for (uint256 i = 1; i < toks.length; ++i) {
            body = string.concat(body, "-", _readSymbolSoft(toks[i]));
        }
        string memory wgt = string.concat("WGT-", body);
        symbol_ = _truncateUtf8(wgt, Math.LP_SYMBOL_MAX);
        name_ = _truncateUtf8(string.concat("Weighted ", wgt), Math.LP_NAME_MAX);
    }

    function _truncateUtf8(string memory s, uint256 maxBytes) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        if (b.length <= maxBytes) return s;
        uint256 end = maxBytes;
        while (end > 0 && (uint8(b[end]) & 0xC0) == 0x80) {
            --end;
        }
        bytes memory out = new bytes(end);
        for (uint256 i; i < end; ++i) {
            out[i] = b[i];
        }
        return string(out);
    }

    /* ---------------------------------------------------------------------- */
    /*                           scale helpers                                */
    /* ---------------------------------------------------------------------- */

    function _scaleReserves(uint256[] memory rates) internal view returns (uint256[] memory scaled) {
        Repo.Layout storage l = Repo._layout();
        scaled = new uint256[](l.numTokens);
        for (uint256 i; i < l.numTokens; ++i) {
            scaled[i] = Math.scaleTo(l.reserves[i], rates[i]);
        }
    }

    function _scaleAmounts(uint256[] memory amounts, uint256[] memory rates)
        internal
        pure
        returns (uint256[] memory scaled)
    {
        scaled = new uint256[](amounts.length);
        for (uint256 i; i < amounts.length; ++i) {
            scaled[i] = Math.scaleTo(amounts[i], rates[i]);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                           fee-on / growth                              */
    /* ---------------------------------------------------------------------- */

    function _feeOnAndShare()
        internal
        view
        returns (bool feeOn, address feeTo_, uint256 ownerFeeShare, uint256 usageFeeWad)
    {
        IVaultFeeOracleQuery oracle = IVaultFeeOracleQuery(Repo._layout().feeOracle);
        feeTo_ = address(oracle.feeTo());
        usageFeeWad = oracle.usageFeeOfVault(address(this));
        ownerFeeShare = (usageFeeWad * Repo.FEE_DENOMINATOR) / Math.WAD;
        feeOn = feeTo_ != address(0) && usageFeeWad != 0 && usageFeeWad < Math.WAD
            && ownerFeeShare != 0;
    }

    /// @dev Returns (mode 0 full / 1 partial, kStored, rootK) where rootK = V or interim k.
    function _measureK(uint256[] memory rates)
        internal
        view
        returns (uint8 mode, uint256 k, uint256 rootK)
    {
        Repo.Layout storage l = Repo._layout();
        uint256[] memory scaled = _scaleReserves(rates);
        if (Math.isFullBookReserves(l.reserves)) {
            mode = 0;
            k = Math.computeV(l.weights, scaled);
            rootK = k; // rootK = V literal
        } else {
            mode = 1;
            k = Math.computeInterimK(l.weights, scaled);
            rootK = k;
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                           pull / push / settle                         */
    /* ---------------------------------------------------------------------- */

    function _onlyPoolManager() internal view {
        if (msg.sender != Repo._layout().poolManager) revert NotPoolManager();
    }

    function _requireDeadline(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert DeadlineExpired();
    }

    function _pull(address token_, uint256 amount) internal {
        if (amount == 0) return;
        _callOptionalReturn(
            token_, abi.encodeWithSelector(IERC20.transferFrom.selector, msg.sender, address(this), amount)
        );
    }

    function _push(address token_, address to, uint256 amount) internal {
        if (amount == 0) return;
        _callOptionalReturn(token_, abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
    }

    function _callOptionalReturn(address token_, bytes memory data) private {
        (bool success, bytes memory returndata) = token_.call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            }
            revert TransferFailed();
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "ERC20 op false");
        }
    }

    function _take(Currency currency, address recipient, uint256 amount) internal {
        if (amount == 0) return;
        IPoolManager(Repo._layout().poolManager).take(currency, recipient, amount);
    }

    function _settle(Currency currency, uint256 amount) internal {
        if (amount == 0) return;
        IPoolManager pm = IPoolManager(Repo._layout().poolManager);
        pm.sync(currency);
        _callOptionalReturn(
            Currency.unwrap(currency),
            abi.encodeWithSelector(IERC20.transfer.selector, address(pm), amount)
        );
        pm.settle();
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

    function _lock() internal {
        Repo.Layout storage l = Repo._layout();
        if (l.reentrancyStatus == Repo.ENTERED) revert Reentrancy();
        l.reentrancyStatus = Repo.ENTERED;
    }

    function _unlock() internal {
        Repo._layout().reentrancyStatus = Repo.NOT_ENTERED;
    }

    /* ---------------------------------------------------------------------- */
    /*                         ERC-20 mint/burn (shared)                      */
    /* ---------------------------------------------------------------------- */

    function _mint(address to, uint256 amount) internal {
        if (amount == 0) return;
        ERC20Repo._mint(to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (amount > ERC20Repo._balanceOf(from)) revert InsufficientLP();
        ERC20Repo._burn(from, amount);
    }

    function _totalSupply() internal view returns (uint256) {
        return ERC20Repo._totalSupply();
    }

    function _syncVaultReserves() internal {
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < l.numTokens; ++i) {
            MultiAssetBasicVaultRepo._updateReserve(IERC20(l.tokens[i]), l.reserves[i]);
        }
    }

    /* size-split shared internals from monotarget */
    function _snapshotKLastIfFeeOn() internal {
        (bool feeOn,,,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn) {
            l.kLast = 0;
            return;
        }
        uint256[] memory rates = _loadRates();
        (uint8 mode, uint256 k,) = _measureK(rates);
        l.kLast = k;
        l.kLastMode = mode;
    }


    function _seedNavShares(uint256[] memory used, uint256[] memory rates, uint256 supply)
        internal
        view
        returns (uint256 shares)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 vIn;
        uint256 vBook;
        for (uint256 i; i < l.numTokens; ++i) {
            uint256 rS = Math.scaleTo(l.reserves[i], rates[i]);
            uint256 uS = Math.scaleTo(used[i], rates[i]);
            vBook += (rS * l.weights[i]) / Math.WAD;
            vIn += (uS * l.weights[i]) / Math.WAD;
        }
        if (vBook == 0 || vIn == 0) revert ZeroAmount();
        shares = (supply * vIn) / vBook;
        if (shares == 0) revert ZeroAmount();
    }


}
