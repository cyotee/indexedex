// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IUniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHook.sol";
import {
    UniswapV4OrbitalSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookRepo.sol";
import {
    UniswapV4OrbitalSwapHookCommon
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookCommon.sol";
import {
    UniswapV4OrbitalSwapHookTarget
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookTarget.sol";

/**
 * @title UniswapV4OrbitalSwapHook
 * @notice CREATE3-mined 3-asset Orbital sphere hook + fungible LP ERC-20 (EIP-2612).
 * @dev Wire: Target → Common; Repo + Math libraries. No BaseHook inheritance (D12).
 */
contract UniswapV4OrbitalSwapHook is
    UniswapV4OrbitalSwapHookTarget,
    IUniswapV4OrbitalSwapHook,
    IERC20,
    IERC20Metadata
{
    bytes32 private constant _PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    constructor(
        IPoolManager poolManager_,
        IVaultFeeOracleQuery feeOracle_,
        address token0_,
        address token1_,
        address token2_
    ) UniswapV4OrbitalSwapHookTarget(poolManager_, feeOracle_, token0_, token1_, token2_) {
        if (
            address(poolManager_) == address(0) || address(feeOracle_) == address(0)
                || token0_ == address(0) || token1_ == address(0) || token2_ == address(0)
        ) {
            revert ZeroAddress();
        }
        if (token0_ == token1_ || token1_ == token2_ || token0_ == token2_) revert SameToken();

        (string memory name_, string memory symbol_) = _buildLpMetadata();
        Repo._setMetadata(
            name_,
            symbol_,
            _readDecimals(token0_),
            _readDecimals(token1_),
            _readDecimals(token2_)
        );
        Hooks.validateHookPermissions(this, getHookPermissions());
    }

    /* ---------------------------------------------------------------------- */
    /*                              Liquidity API                             */
    /* ---------------------------------------------------------------------- */

    function addLiquidity(
        uint256 a0Max,
        uint256 a1Max,
        uint256 a2Max,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 shares, uint256 a0, uint256 a1, uint256 a2) {
        return _addLiquidity(a0Max, a1Max, a2Max, to, sharesMin, deadline, permit2Data);
    }

    function removeLiquidity(
        uint256 shares,
        address to,
        uint256 a0Min,
        uint256 a1Min,
        uint256 a2Min,
        uint256 deadline
    ) external nonReentrant returns (uint256 a0, uint256 a1, uint256 a2) {
        return _removeLiquidity(shares, to, a0Min, a1Min, a2Min, deadline);
    }

    /* ---------------------------------------------------------------------- */
    /*                                Previews                                */
    /* ---------------------------------------------------------------------- */

    function previewAddLiquidity(uint256 a0Max, uint256 a1Max, uint256 a2Max)
        external
        view
        returns (uint256 shares, uint256 a0, uint256 a1, uint256 a2)
    {
        return _previewAddLiquidity(a0Max, a1Max, a2Max);
    }

    function previewRemoveLiquidity(uint256 shares)
        external
        view
        returns (uint256 a0, uint256 a1, uint256 a2)
    {
        return _previewRemoveLiquidity(shares);
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

    /* ---------------------------------------------------------------------- */
    /*                         Interface view overrides                       */
    /* ---------------------------------------------------------------------- */

    function poolManager()
        public
        view
        override(IUniswapV4OrbitalSwapHook, UniswapV4OrbitalSwapHookCommon)
        returns (IPoolManager)
    {
        return _poolManager;
    }

    function feeOracle()
        public
        view
        override(IUniswapV4OrbitalSwapHook, UniswapV4OrbitalSwapHookCommon)
        returns (IVaultFeeOracleQuery)
    {
        return _feeOracle;
    }

    function token0()
        public
        view
        override(IUniswapV4OrbitalSwapHook, UniswapV4OrbitalSwapHookCommon)
        returns (address)
    {
        return _token0;
    }

    function token1()
        public
        view
        override(IUniswapV4OrbitalSwapHook, UniswapV4OrbitalSwapHookCommon)
        returns (address)
    {
        return _token1;
    }

    function token2()
        public
        view
        override(IUniswapV4OrbitalSwapHook, UniswapV4OrbitalSwapHookCommon)
        returns (address)
    {
        return _token2;
    }

    function radius()
        public
        view
        override(IUniswapV4OrbitalSwapHook, UniswapV4OrbitalSwapHookCommon)
        returns (uint256)
    {
        return Repo._layout().R;
    }

    function dexSwapFee()
        public
        view
        override(IUniswapV4OrbitalSwapHook, UniswapV4OrbitalSwapHookCommon)
        returns (uint256)
    {
        return _feeOracle.dexSwapFeeOfVault(address(this));
    }

    function usageFee()
        public
        view
        override(IUniswapV4OrbitalSwapHook, UniswapV4OrbitalSwapHookCommon)
        returns (uint256)
    {
        return _feeOracle.usageFeeOfVault(address(this));
    }

    function feeTo()
        public
        view
        override(IUniswapV4OrbitalSwapHook, UniswapV4OrbitalSwapHookCommon)
        returns (address)
    {
        return address(_feeOracle.feeTo());
    }

    function kLast()
        public
        view
        override(IUniswapV4OrbitalSwapHook, UniswapV4OrbitalSwapHookCommon)
        returns (uint256)
    {
        return Repo._layout().kLast;
    }

    function kLastMode()
        public
        view
        override(IUniswapV4OrbitalSwapHook, UniswapV4OrbitalSwapHookCommon)
        returns (KLastMode)
    {
        return KLastMode(Repo._layout().kLastMode);
    }

    function lSquared()
        public
        view
        override(IUniswapV4OrbitalSwapHook, UniswapV4OrbitalSwapHookCommon)
        returns (uint256)
    {
        return Repo._layout().L_SQUARED;
    }

    function reserveOf(address token)
        public
        view
        override(IUniswapV4OrbitalSwapHook, UniswapV4OrbitalSwapHookCommon)
        returns (uint256)
    {
        return Repo._layout().reserves[token];
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
