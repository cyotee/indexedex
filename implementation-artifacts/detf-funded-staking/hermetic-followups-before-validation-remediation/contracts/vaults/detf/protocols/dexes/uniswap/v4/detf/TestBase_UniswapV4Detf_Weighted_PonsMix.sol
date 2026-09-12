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
import {TestBase_UniswapV4Detf_Weighted_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_ProdSe.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Weighted_PonsMix
 * @notice M-WE-P1P2: [0] pons v1 → Uni V3 SE; [1] pons v2 → Uni V4 SE.
 *         mintToken = pons v1 launch token (smaller pair address). Dual is not bound.
 *         PonsV2MemeHook is not the reserve hook.
 */
abstract contract TestBase_UniswapV4Detf_Weighted_PonsMix is TestBase_UniswapV4Detf_Weighted_ProdSe {
    SeLib.PonsV1Stack internal ponsV1;
    SeLib.PonsV2Stack internal ponsV2;
    IUniswapV3Factory internal univ3Factory;
    IWETH internal weth;
    address internal launchV1;
    address internal launchV2;
    IUniswapV3Pool internal ponsV1Pool;
    PoolKey internal ponsV2PoolKey;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pairToken = new SimpleMintableERC20("Etch", "ETCH");
        pm = IPoolManager(address(new PoolManager(address(this))));
        weth = SeLib.newWeth();
        univ3Factory = SeLib.newUniv3Factory();
        ponsV1 = SeLib.deployPonsV1Stack(univ3Factory, weth);

        SeLib.Univ3SePkg memory v3pkg;
        v3pkg.factory = univ3Factory;
        v3pkg.pkg = SeLib.deployUniv3SePkg(_craneCtx(), univ3Factory);
        SeLib.Univ4SePkg memory v4pkg = SeLib.deployUniv4SePkg(_craneCtx(), pm, weth);
        ponsV2 = SeLib.deployPonsV2Stack(pm, permit2, weth);

        (launchV1, launchV2) = _launchOrderedPonsMix();
        ponsV1Pool = SeLib.ponsV1Pool(launchV1);
        ponsV2PoolKey = _poolKeyOf(launchV2);

        se0 = SeLib.deployUniv3Vault(v3pkg.pkg, ponsV1Pool);
        se1 = SeLib.deployUniv4Vault(v4pkg.pkg, ponsV2PoolKey);
        pairA = launchV1;
        pairB = launchV2;

        _finishWeightedProdSe();
        require(mintToken == launchV1, "mintToken is pons v1");

        SeLib.warpPastPonsV1Restrictions(launchV1);
        _buyV1(launchV1, detfUser, 5 ether);
        _sendLaunchToUser(launchV2);
        _approveUserForPairs();
    }

    function tryLaunchPonsV1(bytes32 saltStart) external returns (address token) {
        require(msg.sender == address(this), "only self");
        return SeLib.launchPonsV1(ponsV1, saltStart);
    }

    function _launchPonsV1(string memory tag) internal returns (address token) {
        for (uint256 i; i < 64; ++i) {
            bytes32 saltStart = bytes32(uint256(keccak256(abi.encodePacked(tag, i))));
            (bool ok, bytes memory ret) =
                address(this).call(abi.encodeCall(this.tryLaunchPonsV1, (saltStart)));
            if (ok) return abi.decode(ret, (address));
        }
        revert("pons v1 vanity salt not found");
    }

    function _launchOrderedPonsMix() internal returns (address v1, address v2) {
        v2 = ponsV2.launchToken;
        for (uint256 i; i < 64; ++i) {
            v1 = _launchPonsV1(string.concat("M-WE-P1P2-", vm.toString(i)));
            if (v1 < v2) return (v1, v2);
        }
        revert("pons v1 address not below v2");
    }

    function _poolKeyOf(address token) internal view returns (PoolKey memory key) {
        if (token == ponsV2.launchToken) return ponsV2.graduatedPoolKey;
        revert("unknown v2 token");
    }

    function _buyV1(address token, address buyer, uint256 ethIn) internal {
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
        require(IERC20(token).balanceOf(buyer) >= 110 ether, "need v1 launch tokens");
    }

    function _sendLaunchToUser(address token) internal {
        uint256 bal = IERC20(token).balanceOf(address(this));
        require(bal >= 110 ether, "need v2 launch tokens");
        IERC20(token).transfer(detfUser, bal);
    }
}
