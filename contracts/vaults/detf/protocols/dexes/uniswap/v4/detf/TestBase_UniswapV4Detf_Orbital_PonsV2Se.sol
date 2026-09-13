// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4Detf_Orbital_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_ProdSe.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Orbital_PonsV2Se
 * @notice H-OR-P2: two pons v2 graduated pools (launch token = hook pair, NOT WETH).
 * @dev Same PoolManager as buffer hook + Uni V4 SE. Never PonsV2MemeHook as reserve hook.
 */
abstract contract TestBase_UniswapV4Detf_Orbital_PonsV2Se is TestBase_UniswapV4Detf_Orbital_ProdSe {
    SeLib.PonsV2Stack internal ponsV2;
    IWETH internal weth;
    address internal launchToken0;
    address internal launchToken1;
    PoolKey internal graduatedKey0;
    PoolKey internal graduatedKey1;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pairToken = new SimpleMintableERC20("Etch", "ETCH");
        pm = IPoolManager(address(IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            keccak256("TestBase_UniswapV4Detf_Orbital_PonsV2Se_PoolManager")
        ))));
        weth = SeLib.newWeth();
        ponsV2 = SeLib.deployPonsV2Stack(pm, permit2, weth);
        launchToken0 = ponsV2.launchToken;
        graduatedKey0 = ponsV2.graduatedPoolKey;
        address curve1;
        (launchToken1, curve1, graduatedKey1) = SeLib.launchAndGraduatePonsV2(
            ponsV2, weth, keccak256("wp-udsm-or-pons-v2-b"), "Pons Orb B", "POB2"
        );
        curve1;
        if (launchToken1 < launchToken0) {
            (launchToken0, launchToken1) = (launchToken1, launchToken0);
            PoolKey memory tmpKey = graduatedKey0;
            graduatedKey0 = graduatedKey1;
            graduatedKey1 = tmpKey;
        }

        SeLib.Univ4SePkg memory v4pkg = SeLib.deployUniv4SePkg(_craneCtx(), pm, weth);
        address vault0 = SeLib.deployUniv4Vault(v4pkg.pkg, graduatedKey0);
        address vault1 = SeLib.deployUniv4Vault(v4pkg.pkg, graduatedKey1);

        _finishOrbitalDetf(launchToken0, launchToken1, vault0, vault1);
        require(reserveHook != address(ponsV2.memeHook), "not PonsV2MemeHook");

        _fundPonsV2User(launchToken0);
        _fundPonsV2User(launchToken1);
        _approveUserPairs(detfUser);
        SeLib.activatePositionVault(se0, pairAddr0, detfUser, address(weth));
        SeLib.activatePositionVault(se1, pairAddr1, detfUser, address(weth));
    }

    function _fundPonsV2User(address token) internal {
        uint256 bal = IERC20(token).balanceOf(address(this));
        require(bal >= 200 ether, "pons v2 curve inventory");
        IERC20(token).transfer(detfUser, bal);
    }
}
