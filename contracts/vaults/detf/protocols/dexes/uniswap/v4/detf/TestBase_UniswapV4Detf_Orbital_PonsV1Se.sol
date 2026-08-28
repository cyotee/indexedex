// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
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
 * @title TestBase_UniswapV4Detf_Orbital_PonsV1Se
 * @notice H-OR-P1: two pons v1 launches (launch token = hook pair, WETH = SE other).
 * @dev One UniswapV3Factory for both launches and Uni V3 SE PkgInit. Does not inherit TestBase_PonsFamily.
 */
abstract contract TestBase_UniswapV4Detf_Orbital_PonsV1Se is TestBase_UniswapV4Detf_Orbital_ProdSe {
    SeLib.PonsV1Stack internal ponsV1;
    IUniswapV3Factory internal univ3Factory;
    IWETH internal weth;
    address internal launchToken0;
    address internal launchToken1;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pairToken = new SimpleMintableERC20("Etch", "ETCH");
        pm = IPoolManager(address(new PoolManager(address(this))));
        weth = SeLib.newWeth();
        univ3Factory = SeLib.newUniv3Factory();
        ponsV1 = SeLib.deployPonsV1Stack(univ3Factory, weth);
        launchToken0 = _launchPonsV1Named("H-OR-P1-a", "Pons Orb A", "POA");
        launchToken1 = _launchPonsV1Named("H-OR-P1-b", "Pons Orb B", "POB");
        if (launchToken1 < launchToken0) (launchToken0, launchToken1) = (launchToken1, launchToken0);

        SeLib.Univ3SePkg memory v3pkg;
        v3pkg.factory = univ3Factory;
        v3pkg.pkg = SeLib.deployUniv3SePkg(_craneCtx(), univ3Factory);
        IUniswapV3Pool pool0 = SeLib.ponsV1Pool(launchToken0);
        IUniswapV3Pool pool1 = SeLib.ponsV1Pool(launchToken1);
        address vault0 = SeLib.deployUniv3Vault(v3pkg.pkg, pool0);
        address vault1 = SeLib.deployUniv3Vault(v3pkg.pkg, pool1);

        _finishOrbitalDetf(launchToken0, launchToken1, vault0, vault1);

        SeLib.warpPastPonsV1Restrictions(launchToken0);
        SeLib.warpPastPonsV1Restrictions(launchToken1);
        _buyLaunchTokens(launchToken0, detfUser, 20 ether);
        _buyLaunchTokens(launchToken1, detfUser, 20 ether);
        _approveUserPairs(detfUser);
    }

    function tryLaunchPonsV1Named(bytes32 saltStart, string calldata name, string calldata symbol)
        external
        returns (address token)
    {
        require(msg.sender == address(this), "only self");
        return SeLib.launchPonsV1Named(ponsV1, saltStart, name, symbol);
    }

    function _launchPonsV1Named(string memory saltPrefix, string memory name, string memory symbol)
        internal
        returns (address token)
    {
        for (uint256 i; i < 64; ++i) {
            bytes32 saltStart = bytes32(uint256(keccak256(abi.encodePacked(saltPrefix, i))));
            (bool ok, bytes memory ret) = address(this).call(
                abi.encodeCall(this.tryLaunchPonsV1Named, (saltStart, name, symbol))
            );
            if (ok) return abi.decode(ret, (address));
        }
        revert("pons v1 vanity salt not found");
    }

    function _buyLaunchTokens(address token, address buyer, uint256 ethIn) internal {
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
        require(IERC20(token).balanceOf(buyer) >= 200 ether, "need launch tokens");
    }
}
