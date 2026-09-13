// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4Detf_Weighted_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_ProdSe.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Weighted_PonsV2Se
 * @notice H-WE-P2: Weighted n=3, two pons v2 graduated Uni V4 SE. Hook pair = launch token, not WETH.
 *         Reserve hook is the Weighted SE buffer, never PonsV2MemeHook. Dual is not bound.
 */
abstract contract TestBase_UniswapV4Detf_Weighted_PonsV2Se is TestBase_UniswapV4Detf_Weighted_ProdSe {
    SeLib.PonsV2Stack internal ponsV2;
    IWETH internal weth;
    address internal launchToken0;
    address internal launchToken1;
    PoolKey internal sePoolKey0;
    PoolKey internal sePoolKey1;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pairToken = new SimpleMintableERC20("Etch", "ETCH");
        pm = IPoolManager(address(new PoolManager(address(this))));
        weth = SeLib.newWeth();

        SeLib.Univ4SePkg memory v4pkg = SeLib.deployUniv4SePkg(_craneCtx(), pm, weth);
        ponsV2 = SeLib.deployPonsV2Stack(pm, permit2, weth);
        launchToken0 = ponsV2.launchToken;
        sePoolKey0 = ponsV2.graduatedPoolKey;
        (launchToken1,, sePoolKey1) = SeLib.launchAndGraduatePonsV2(
            ponsV2,
            weth,
            SeLib.ponsV2TokenParams("Pons Se Wrap B", "PSEB", keccak256("wp-udsm-we-pons-v2-b"))
        );
        require(launchToken0 != launchToken1, "distinct launch tokens");
        se0 = SeLib.deployUniv4Vault(v4pkg.pkg, sePoolKey0);
        se1 = SeLib.deployUniv4Vault(v4pkg.pkg, sePoolKey1);
        pairA = launchToken0;
        pairB = launchToken1;

        _finishWeightedProdSe();
        require(mintToken == launchToken0 || mintToken == launchToken1, "mintToken is launch token");

        _sendLaunchToUser(launchToken0);
        _sendLaunchToUser(launchToken1);
        _approveUserForPairs();
    }

    function _sendLaunchToUser(address token) internal {
        uint256 bal = IERC20(token).balanceOf(address(this));
        require(bal >= 110 ether, "need launch tokens");
        IERC20(token).transfer(detfUser, bal);
    }
}
