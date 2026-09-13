// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/ISwapRouter.sol";

import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4Detf_Orbital_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_ProdSe.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Orbital_PonsMix
 * @notice M-OR-P1P2: tokens() skip DETF [0] pons v1 → Uni V3 SE; [1] pons v2 → Uni V4 SE.
 * @dev mintToken = pons v1 launch token. Same Uni V3 factory for v1. Same PoolManager for v2 + hook.
 */
abstract contract TestBase_UniswapV4Detf_Orbital_PonsMix is TestBase_UniswapV4Detf_Orbital_ProdSe {
    SeLib.PonsV1Stack internal ponsV1;
    SeLib.PonsV2Stack internal ponsV2;
    IUniswapV3Factory internal univ3Factory;
    IWETH internal weth;
    address internal launchTokenV1;
    address internal launchTokenV2;
    PoolKey internal graduatedKeyV2;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pairToken = new SimpleMintableERC20("Etch", "ETCH");
        pm = IPoolManager(address(new PoolManager(address(this))));
        weth = SeLib.newWeth();
        univ3Factory = SeLib.newUniv3Factory();
        ponsV1 = SeLib.deployPonsV1Stack(univ3Factory, weth);
        ponsV2 = SeLib.deployPonsV2Stack(pm, permit2, weth);
        launchTokenV2 = ponsV2.launchToken;
        graduatedKeyV2 = ponsV2.graduatedPoolKey;
        launchTokenV1 = _launchPonsV1PreferLt(launchTokenV2);
        if (launchTokenV1 > launchTokenV2) {
            (launchTokenV2, graduatedKeyV2) = _launchPonsV2UntilGt(launchTokenV1);
        }

        SeLib.Univ3SePkg memory v3pkg;
        v3pkg.factory = univ3Factory;
        v3pkg.pkg = SeLib.deployUniv3SePkg(_craneCtx(), univ3Factory);
        IUniswapV3Pool poolV1 = SeLib.ponsV1Pool(launchTokenV1);
        address seV1 = SeLib.deployUniv3Vault(v3pkg.pkg, poolV1);

        SeLib.Univ4SePkg memory v4pkg = SeLib.deployUniv4SePkg(_craneCtx(), pm, weth);
        address seV2 = SeLib.deployUniv4Vault(v4pkg.pkg, graduatedKeyV2);

        _finishOrbitalDetf(launchTokenV1, launchTokenV2, seV1, seV2);
        require(mintToken == launchTokenV1, "mintToken is pons v1");
        require(reserveHook != address(ponsV2.memeHook), "not PonsV2MemeHook");

        SeLib.warpPastPonsV1Restrictions(launchTokenV1);
        _buyPonsV1(launchTokenV1, detfUser, 20 ether);
        uint256 v2Bal = IERC20(launchTokenV2).balanceOf(address(this));
        require(v2Bal >= 200 ether, "pons v2 inventory");
        IERC20(launchTokenV2).transfer(detfUser, v2Bal);
        _approveUserPairs(detfUser);
    }

    function tryLaunchPonsV1Named(bytes32 saltStart, string calldata name, string calldata symbol)
        external
        returns (address token)
    {
        require(msg.sender == address(this), "only self");
        return SeLib.launchPonsV1Named(ponsV1, saltStart, name, symbol);
    }

    function _launchPonsV1PreferLt(address other) internal returns (address token) {
        address fallbackToken;
        for (uint256 i; i < 64; ++i) {
            bytes32 saltStart = bytes32(uint256(keccak256(abi.encodePacked("M-OR-P1P2", i))));
            (bool ok, bytes memory ret) = address(this).call(
                abi.encodeCall(this.tryLaunchPonsV1Named, (saltStart, "Pons Mix V1", "PMV1"))
            );
            if (!ok) continue;
            token = abi.decode(ret, (address));
            if (token < other) return token;
            if (fallbackToken == address(0)) fallbackToken = token;
        }
        if (fallbackToken != address(0)) return fallbackToken;
        revert("pons v1 launch failed");
    }

    function _launchPonsV2UntilGt(address other) internal returns (address token, PoolKey memory key) {
        for (uint256 i; i < 16; ++i) {
            address curve;
            (token, curve, key) = SeLib.launchAndGraduatePonsV2(
                ponsV2,
                weth,
                keccak256(abi.encodePacked("wp-udsm-or-mix-v2", i)),
                "Pons Mix V2",
                "PMV2"
            );
            curve;
            if (token > other) return (token, key);
        }
        revert("pons v2 address not above v1");
    }

    function _buyPonsV1(address token, address buyer, uint256 ethIn) internal {
        vm.deal(buyer, buyer.balance + ethIn);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(weth),
            tokenOut: token,
            fee: SeLib.PONS_V1_POOL_FEE,
            recipient: buyer,
            deadline: block.timestamp + 1 hours,
            amountIn: ethIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        vm.prank(buyer);
        ponsV1.swapRouter.exactInputSingle{value: ethIn}(params);
        require(IERC20(token).balanceOf(buyer) >= 200 ether, "need v1 launch tokens");
    }
}
