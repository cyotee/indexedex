// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {
    UniswapV4QuadStableSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHookRepo.sol";
import {
    UniswapV4QuadStableSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHookMath.sol";
import {
    UniswapV4QuadStableSwapHookTarget
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHookTarget.sol";
/**
 * @title UniswapV4QuadStableSwapHook
 * @notice CREATE3-mined single-contract V4 4-asset StableSwap hook + fungible LP ERC-20.
 * @dev No Facet/DFPkg. No BaseHook / BaseTokenWrapperHook / DeltaResolver inheritance.
 *      Fee-on-output (D20). Rates fail-closed (D74). Permissionless; no owner/pause/skim.
 */
/// @dev Implements IUniswapV4QuadStableSwapHook without dual-inheritance override noise.
contract UniswapV4QuadStableSwapHook is UniswapV4QuadStableSwapHookTarget, IERC20, IERC20Metadata {
    constructor(
        IPoolManager poolManager_,
        address token0_,
        address token1_,
        address token2_,
        address token3_,
        uint24 lpFeePips_,
        uint256 baseAmp_,
        address[4] memory rateProviders_
    )
        UniswapV4QuadStableSwapHookTarget(
            poolManager_,
            token0_,
            token1_,
            token2_,
            token3_,
            lpFeePips_,
            baseAmp_,
            rateProviders_
        )
    {
        (string memory name_, string memory symbol_) =
            _buildLpMetadata(token0_, token1_, token2_, token3_);
        uint8[4] memory decs = [_decimals0, _decimals1, _decimals2, _decimals3];
        uint256[4] memory scales = [_baseScale0, _baseScale1, _baseScale2, _baseScale3];
        Repo._setMetadata(name_, symbol_, decs, scales);
        Hooks.validateHookPermissions(this, getHookPermissions());
    }

    /* ---------------------------------------------------------------------- */
    /*                           IUniswapV4QuadStableSwapHook                 */
    /* ---------------------------------------------------------------------- */

    function previewAddLiquidity(uint256[4] calldata amounts)
        external
        view
        returns (uint256 shares, uint256[4] memory actualAmounts)
    {
        return _previewAddLiquidity(amounts);
    }

    function previewRemoveLiquidity(uint256 shares)
        external
        view
        returns (uint256[4] memory amounts)
    {
        return _previewRemoveLiquidity(shares);
    }

    function previewZapIn(uint256[4] calldata amounts)
        external
        view
        returns (uint256 shares, uint256[4] memory amountsUsed)
    {
        return _previewZapIn(amounts);
    }

    function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        return _previewSwapExactIn(tokenIn, tokenOut, amountIn);
    }

    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        return _previewSwapExactOut(tokenIn, tokenOut, amountOut);
    }

    function addLiquidity(
        uint256[4] calldata amounts,
        uint256[4] calldata minAmounts,
        address to,
        uint256 sharesMin
    ) external nonReentrant returns (uint256 shares, uint256[4] memory actualAmounts) {
        return _addLiquidity(amounts, minAmounts, to, sharesMin);
    }

    function zapIn(uint256[4] calldata amounts, address to, uint256 sharesMin)
        external
        nonReentrant
        returns (uint256 shares, uint256[4] memory amountsUsed)
    {
        return _zapIn(amounts, to, sharesMin);
    }

    function removeLiquidity(uint256 shares, address to, uint256[4] calldata minAmounts)
        external
        nonReentrant
        returns (uint256[4] memory amounts)
    {
        return _removeLiquidity(shares, to, minAmounts);
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

    function allowance(address owner_, address spender) public view override returns (uint256) {
        return Repo._layout().allowance[owner_][spender];
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

    function _emitTransfer(address from, address to, uint256 amount) internal override {
        emit Transfer(from, to, amount);
    }
}
