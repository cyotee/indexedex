// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookTarget
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookTarget.sol";

/**
 * @title UniswapV4DualStandardExchangeBufferConstantProductHook
 * @notice CREATE3-mined dual SE buffer + CP pricing hook (pair-token pool) + LP ERC-20.
 */
contract UniswapV4DualStandardExchangeBufferConstantProductHook is
    UniswapV4DualStandardExchangeBufferConstantProductHookTarget,
    IERC20,
    IERC20Metadata
{
    constructor(
        IPoolManager poolManager_,
        IVaultFeeOracleQuery feeOracle_,
        address se0_,
        address token0_,
        address se1_,
        address token1_
    )
        UniswapV4DualStandardExchangeBufferConstantProductHookTarget(
            poolManager_, feeOracle_, se0_, token0_, se1_, token1_
        )
    {
        if (
            address(poolManager_) == address(0) || address(feeOracle_) == address(0)
                || se0_ == address(0) || token0_ == address(0) || se1_ == address(0)
                || token1_ == address(0)
        ) {
            revert ZeroAddress();
        }
        if (se0_ == se1_) revert SameStandardExchange();
        if (token0_ == token1_) revert SamePairToken();
        _requireTokenInVaultTokens(se0_, token0_);
        _requireTokenInVaultTokens(se1_, token1_);

        (string memory name_, string memory symbol_) = _buildLpMetadata();
        Repo._setMetadata(
            name_,
            symbol_,
            _readDecimals(_currency0),
            _readDecimals(_currency1)
        );
        Hooks.validateHookPermissions(this, getHookPermissions());
    }

    /* ---------------------------------------------------------------------- */
    /*                              Liquidity API                             */
    /* ---------------------------------------------------------------------- */

    function deposit(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        _pullErc20Dual(amount0, amount1);
        return _deposit(amount0, amount1, to, minLpAmount, deadline);
    }

    function depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpAmount) {
        _pullErc20Single(tokenIn, amountIn);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }

    function depositWithPermit2Signature(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        _pullPermit2SignatureDual(amount0, amount1, permit2Data);
        return _deposit(amount0, amount1, to, minLpAmount, deadline);
    }

    function depositWithPermit2Allowance(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        _pullPermit2AllowanceDual(amount0, amount1);
        return _deposit(amount0, amount1, to, minLpAmount, deadline);
    }

    function depositSingleWithPermit2Signature(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 lpAmount) {
        _pullPermit2SignatureSingle(tokenIn, amountIn, permit2Data);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }

    function depositSingleWithPermit2Allowance(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpAmount) {
        _pullPermit2AllowanceSingle(tokenIn, amountIn);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }

    function withdraw(
        uint256 lpAmount,
        address to,
        uint256 minAmount0,
        uint256 minAmount1,
        uint256 deadline
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        return _withdraw(lpAmount, to, minAmount0, minAmount1, deadline);
    }

    /* ---------------------------------------------------------------------- */
    /*                                Previews                                */
    /* ---------------------------------------------------------------------- */

    function previewDeposit(uint256 amount0, uint256 amount1)
        external
        view
        returns (uint256 lpAmount, uint256 used0, uint256 used1)
    {
        return _previewDeposit(amount0, amount1);
    }

    function previewDepositSingle(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 lpAmount)
    {
        return _previewDepositSingle(tokenIn, amountIn);
    }

    function previewZapSplit(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 amountToSwap, uint256 amountOtherOut, uint256 amountKeptIn)
    {
        return _previewZapSplit(tokenIn, amountIn);
    }

    function previewWithdraw(uint256 lpAmount)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return _previewWithdraw(lpAmount);
    }

    function previewSwapExactIn(bool zeroForOne, uint256 amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        return _previewSwapExactIn(zeroForOne, amountIn);
    }

    function previewSwapExactOut(bool zeroForOne, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        return _previewSwapExactOut(zeroForOne, amountOut);
    }

    /* ---------------------------------------------------------------------- */
    /*                                 ERC-20                                 */
    /* ---------------------------------------------------------------------- */

    function name() public view override returns (string memory) {
        return Repo._layout().name;
    }

    function symbol() public view override returns (string memory) {
        return Repo._layout().symbol;
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function totalSupply() public view override returns (uint256) {
        return Repo._layout().totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return Repo._layout().balanceOf[account];
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return Repo._layout().allowance[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        Repo._layout().allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        Repo.Layout storage l = Repo._layout();
        uint256 allowed = l.allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            l.allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        Repo.Layout storage l = Repo._layout();
        l.balanceOf[from] -= amount;
        l.balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}
