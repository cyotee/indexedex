// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib as ClaimLib} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IUniswapV4BalancerStableLiquidityUnits as IUnits} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4BalancerStableLiquidityUnits.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo as Repo} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookMath as Math} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget as Target} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol";

abstract contract UniswapV4BalancerStableLiquidityUnitsCore is Target {
    using SafeERC20 for IERC20;

    function _entryPreviewJoinProportionalFlexible(uint256[] calldata amounts, bool[] calldata sharesIn)
        internal view returns (uint256 shares, uint256[] memory used)
    {
        return _quoteFlexibleJoin(amounts, sharesIn, _previewSupplyAfterProtocolMint());
    }

    function _entryJoinProportionalFlexible(uint256[] calldata amounts, bool[] calldata sharesIn, address to, uint256 minimum, uint256 deadline)
        internal nonReentrant returns (uint256 shares, uint256[] memory used)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        _maybeMintProtocolFee();
        bool first = _totalSupply() == 0;
        (shares, used) = _quoteFlexibleJoin(amounts, sharesIn, _totalSupply());
        if (shares < minimum) revert Slippage();
        _fundFlexibleJoin(used, sharesIn);
        if (first) _mintLp(address(0), Math.MINIMUM_LIQUIDITY);
        _mintLp(to, shares);
        _refundBufferedDust();
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        emit IUnits.JoinFlexible(msg.sender, to, shares, used, sharesIn);
    }

    function _validateUnits(bool[] memory flags) internal view {
        Repo.Layout storage l = Repo._layout();
        if (flags.length != l.tokens.length) revert InvalidN();
        for (uint256 i; i < flags.length; ++i) {
            if (flags[i] && l.standardExchanges[i] == address(0)) revert InvalidPair();
        }
    }

    function _flexibleInventory(uint256[] memory amounts, bool[] memory flags) internal view returns (uint256[] memory inv) {
        _requireAmountsLength(amounts);
        _validateUnits(flags);
        Repo.Layout storage l = Repo._layout();
        inv = new uint256[](amounts.length);
        for (uint256 i; i < amounts.length; ++i) {
            if (amounts[i] == 0) continue;
            address se = l.standardExchanges[i];
            inv[i] = flags[i] || se == address(0) ? amounts[i]
                : IStandardExchangeIn(se).previewExchangeIn(IERC20(l.tokens[i]), amounts[i], IERC20(se));
        }
    }

    function _quoteFlexibleJoin(uint256[] memory amounts, bool[] memory flags, uint256 supply)
        internal view returns (uint256 shares, uint256[] memory used)
    {
        uint256[] memory inventory = _flexibleInventory(amounts, flags);
        if (supply == 0) {
            if (!Math.isFullBookReserves(inventory)) revert NotFullBook();
            return (Math.firstMintShares(_initialLiquidityValues(amounts, flags), _amp()), amounts);
        }
        uint256[] memory reserves = _nativeAll();
        shares = Math.proportionalJoinShares(inventory, reserves, supply);
        used = new uint256[](amounts.length);
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < amounts.length; ++i) {
            uint256 required = Math.proportionalUsedWad(shares, reserves[i], supply);
            address se = l.standardExchanges[i];
            used[i] = flags[i] || se == address(0) ? required
                : ClaimLib.bufferInputForShares(se, l.tokens[i], required);
            if (used[i] == 0 || used[i] > amounts[i]) revert Slippage();
        }
    }

    function _fundFlexibleJoin(uint256[] memory amounts, bool[] memory flags) internal {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < amounts.length; ++i) {
            _pull(flags[i] ? l.standardExchanges[i] : l.tokens[i], amounts[i]);
        }
        for (uint8 i; i < amounts.length; ++i) {
            if (!flags[i]) _bufferToken(i, amounts[i]);
        }
    }

    function _entryPreviewExitProportionalFlexible(uint256 shares, bool[] calldata flags)
        internal view returns (uint256[] memory amounts)
    {
        _validateUnits(flags);
        return _flexibleOutputs(Math.proportionalExitAmounts(shares, _nativeAll(), _previewSupplyAfterProtocolMint()), flags);
    }

    function _flexibleOutputs(uint256[] memory inventory, bool[] memory flags) internal view returns (uint256[] memory amounts) {
        Repo.Layout storage l = Repo._layout();
        amounts = new uint256[](inventory.length);
        for (uint256 i; i < inventory.length; ++i) {
            address se = l.standardExchanges[i];
            amounts[i] = flags[i] || se == address(0) ? inventory[i]
                : IStandardExchangeIn(se).previewExchangeIn(IERC20(se), inventory[i], IERC20(l.tokens[i]));
        }
    }

    function _entryExitProportionalFlexible(uint256 shares, address to, bool[] calldata flags, uint256[] calldata minimum, uint256 deadline)
        internal nonReentrant returns (uint256[] memory amounts)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        _validateUnits(flags);
        _requireAmountsLength(minimum);
        _maybeMintProtocolFee();
        uint256[] memory inventory = Math.proportionalExitAmounts(shares, _nativeAll(), _totalSupply());
        amounts = _flexibleOutputs(inventory, flags);
        for (uint256 i; i < amounts.length; ++i) if (amounts[i] < minimum[i]) revert Slippage();
        _burnLp(msg.sender, shares);
        _payFlexibleExit(inventory, flags, to);
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        emit IUnits.ExitFlexible(msg.sender, to, shares, amounts, flags);
    }

    function _payFlexibleExit(uint256[] memory inventory, bool[] memory flags, address to) internal {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < inventory.length; ++i) {
            if (inventory[i] >= _nativeAt(i)) revert WouldZeroReserve();
            if (inventory[i] == 0) continue;
            if (flags[i]) IERC20(l.standardExchanges[i]).safeTransfer(to, inventory[i]);
            else if (l.standardExchanges[i] != address(0)) _unwrapSeShares(i, inventory[i], to);
            else {
                _debitRawIntentional(i, inventory[i]);
                IERC20(l.tokens[i]).safeTransfer(to, inventory[i]);
            }
        }
    }

    function _orderedInputs(address[] memory tokens_, uint256[] memory amounts)
        internal view returns (uint256[] memory ordered, bool[] memory flags)
    {
        uint256 n = Repo._numTokens();
        if (tokens_.length == 0 || tokens_.length != amounts.length || tokens_.length > n) revert InvalidN();
        ordered = new uint256[](n);
        flags = new bool[](n);
        uint256 seen;
        for (uint256 i; i < tokens_.length; ++i) {
            (uint8 index, bool shareUnit) = _indexOfPairOrSe(tokens_[i]);
            if (seen & (1 << index) != 0) revert InvalidPair();
            seen |= 1 << index;
            ordered[index] = amounts[i];
            flags[index] = shareUnit;
        }
    }

    function _entryPreviewJoinUnbalanced(address[] calldata tokens_, uint256[] calldata amounts) internal view returns (uint256) {
        (uint256[] memory ordered, bool[] memory flags) = _orderedInputs(tokens_, amounts);
        return _quoteFlexibleUnbalanced(ordered, flags, _previewSupplyAfterProtocolMint());
    }

    function _quoteFlexibleUnbalanced(uint256[] memory ordered, bool[] memory flags, uint256 supply) internal view returns (uint256) {
        uint256[] memory inv = _flexibleInventory(ordered, flags);
        if (supply == 0) {
            if (!Math.isFullBookReserves(inv)) revert NotFullBook();
            return Math.firstMintShares(_initialLiquidityValues(ordered, flags), _amp());
        }
        return Math.unbalancedJoinShares(_ratedWadAll(), _liquidityAmounts(inv), _amp(), supply, dexSwapFee());
    }

    function _entryJoinUnbalanced(address[] calldata tokens_, uint256[] calldata amounts, address to, uint256 minimum, uint256 deadline)
        internal nonReentrant returns (uint256 shares)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        _maybeMintProtocolFee();
        (uint256[] memory ordered, bool[] memory flags) = _orderedInputs(tokens_, amounts);
        bool first = _totalSupply() == 0;
        shares = _quoteFlexibleUnbalanced(ordered, flags, _totalSupply());
        if (shares == 0 || shares < minimum) revert Slippage();
        _fundFlexibleJoin(ordered, flags);
        if (first) _mintLp(address(0), Math.MINIMUM_LIQUIDITY);
        _mintLp(to, shares);
        _refundBufferedDust();
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        emit IUnits.JoinFlexible(msg.sender, to, shares, ordered, flags);
    }
}
