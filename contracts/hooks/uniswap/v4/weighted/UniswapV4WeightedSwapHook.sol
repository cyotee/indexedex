// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    UniswapV4WeightedSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookRepo.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";
import {
    UniswapV4WeightedSwapHookTarget
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookTarget.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";

/**
 * @title UniswapV4WeightedSwapHook
 * @notice CREATE3 single-contract n-asset Weighted V4 hook + fungible LP ERC-20 + EIP-2612.
 * @dev No Facet/DFPkg. No BaseHook / BaseTokenWrapperHook / DeltaResolver inheritance.
 *      rootK = V (full Weighted invariant). Factory-immutable feeOracle.
 */
/// @dev Implements IUniswapV4WeightedSwapHook without dual-inheritance override noise.
contract UniswapV4WeightedSwapHook is UniswapV4WeightedSwapHookTarget, IERC20, IERC20Metadata {
    bytes32 private constant _PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    constructor(
        IPoolManager poolManager_,
        IVaultFeeOracleQuery feeOracle_,
        address[] memory tokens_,
        uint256[] memory normalizedWeights_,
        address[] memory rateProviders_
    ) UniswapV4WeightedSwapHookTarget(poolManager_, feeOracle_) {
        uint256 n = tokens_.length;
        if (n < Math.MIN_N || n > Math.MAX_N) revert InvalidN();
        if (
            normalizedWeights_.length != n || rateProviders_.length != n
        ) revert InvalidN();

        uint256 weightSum;
        for (uint256 i; i < n; ++i) {
            if (tokens_[i] == address(0)) revert InvalidToken();
            if (i > 0 && !(tokens_[i - 1] < tokens_[i])) revert InvalidTokenOrder();
            if (normalizedWeights_[i] < Math.MIN_WEIGHT) revert InvalidWeight();
            weightSum += normalizedWeights_[i];
        }
        if (weightSum != Math.WAD) revert InvalidWeight();

        uint256[] memory baseScales = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            uint8 d = _readDecimalsFailClosed(tokens_[i]);
            baseScales[i] = Math.baseScaleFromDecimals(d);
        }

        (string memory name_, string memory symbol_) = _buildLpMetadata(tokens_);
        Repo._initBinding(tokens_, normalizedWeights_, rateProviders_, baseScales, name_, symbol_);
        Hooks.validateHookPermissions(this, getHookPermissions());
    }

    /* ---------------------------------------------------------------------- */
    /*                    IUniswapV4WeightedSwapHook surface                  */
    /* ---------------------------------------------------------------------- */

    function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256)
    {
        return _previewSwapExactIn(tokenIn, tokenOut, amountIn);
    }

    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256)
    {
        return _previewSwapExactOut(tokenIn, tokenOut, amountOut);
    }

    function previewJoinProportional(uint256[] calldata amounts)
        external
        view
        returns (uint256 shares, uint256[] memory usedAmounts)
    {
        return _previewJoinProportional(amounts);
    }

    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256)
    {
        return _previewJoinSingleExactIn(tokenIn, amountIn);
    }

    function previewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut)
        external
        view
        returns (uint256)
    {
        return _previewJoinSingleExactOut(tokenIn, sharesOut);
    }

    function previewJoinUnbalanced(uint256[] calldata amounts) external view returns (uint256) {
        return _previewJoinUnbalanced(amounts);
    }

    function previewExitProportional(uint256 shares) external view returns (uint256[] memory) {
        return _previewExitProportional(shares);
    }

    function previewExitSingleAssetExactIn(address tokenOut, uint256 sharesIn)
        external
        view
        returns (uint256)
    {
        return _previewExitSingleExactIn(tokenOut, sharesIn);
    }

    function previewExitSingleAssetExactOut(address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256)
    {
        return _previewExitSingleExactOut(tokenOut, amountOut);
    }

    function joinProportional(
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 shares, uint256[] memory usedAmounts) {
        return _joinProportional(amounts, to, sharesMin, deadline, permit2Data);
    }

    function joinSingleAssetExactIn(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 shares) {
        return _joinSingleExactIn(tokenIn, amountIn, to, sharesMin, deadline, permit2Data);
    }

    function joinSingleAssetExactOut(
        address tokenIn,
        uint256 sharesOut,
        address to,
        uint256 amountInMax,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 amountIn) {
        return _joinSingleExactOut(tokenIn, sharesOut, to, amountInMax, deadline, permit2Data);
    }

    function joinUnbalanced(
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 shares) {
        return _joinUnbalanced(amounts, to, sharesMin, deadline, permit2Data);
    }

    function exitProportional(
        uint256 shares,
        address to,
        uint256[] calldata amountsMin,
        uint256 deadline
    ) external nonReentrant returns (uint256[] memory amounts) {
        return _exitProportional(shares, to, amountsMin, deadline);
    }

    function exitSingleAssetExactIn(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        return _exitSingleExactIn(tokenOut, sharesIn, to, amountOutMin, deadline);
    }

    function exitSingleAssetExactOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) external nonReentrant returns (uint256 sharesIn) {
        return _exitSingleExactOut(tokenOut, amountOut, to, sharesInMax, deadline);
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

    /* ---------------------------------------------------------------------- */
    /*                               EIP-2612                                 */
    /* ---------------------------------------------------------------------- */

    function nonces(address owner_) public view returns (uint256) {
        return Repo._layout().nonces[owner_];
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(Repo._layout().name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    function permit(
        address owner_,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        if (block.timestamp > deadline) revert DeadlineExpired();
        Repo.Layout storage l = Repo._layout();
        bytes32 structHash = keccak256(
            abi.encode(_PERMIT_TYPEHASH, owner_, spender, value, l.nonces[owner_]++, deadline)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), structHash));
        address recovered = ecrecover(digest, v, r, s);
        if (recovered == address(0) || recovered != owner_) revert InvalidPermit2Data();
        l.allowance[owner_][spender] = value;
        emit Approval(owner_, spender, value);
    }
}
