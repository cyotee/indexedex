// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {TestBase_UniswapV4Detf_Weighted_ProdSe_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_ProdSe_Decimals.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Weighted_Univ4Se_Decimals
 * @notice H-WE-GV4: Weighted n=3, two vanilla Uni V4 SE (same pm, TWAP). Dual is not bound.
 *         PonsV2MemeHook is not the reserve hook.
 */
abstract contract TestBase_UniswapV4Detf_Weighted_Univ4Se_Decimals is TestBase_UniswapV4Detf_Weighted_ProdSe_Decimals {
    IWETH internal weth;
    PoolKey internal sePoolKey0;
    PoolKey internal sePoolKey1;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pairToken = new MintableERC20Decimals("Etch", "ETCH", 18);
        pairA = address(new MintableERC20Decimals("Pair0", "P0", _pairDecimals()));
        pairB = address(new MintableERC20Decimals("Pair1", "P1", _rateDecimals()));
        MintableERC20Decimals rate0 = new MintableERC20Decimals("Rate", "RATE", 18);
        MintableERC20Decimals rate1 = new MintableERC20Decimals("Rate", "RATE", 18);
        pm = IPoolManager(address(IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            keccak256("TestBase_UniswapV4Detf_Weighted_Univ4Se_Decimals_PoolManager")
        ))));
        weth = SeLib.newWeth();

        SeLib.Univ4SePkg memory v4pkg = SeLib.deployUniv4SePkg(_craneCtx(), pm, weth);
        sePoolKey0 = SeLib.initAndSeedUniv4Pool(pm, pairA, address(rate0));
        sePoolKey1 = SeLib.initAndSeedUniv4Pool(pm, pairB, address(rate1));
        se0 = SeLib.deployUniv4Vault(v4pkg.pkg, sePoolKey0);
        se1 = SeLib.deployUniv4Vault(v4pkg.pkg, sePoolKey1);

        _finishWeightedProdSe();
        _mintMintablePairs(10_000_000);
        _approveUserForPairs();
        SeLib.activatePositionVault(se0, pairA, detfUser, address(weth));
        SeLib.activatePositionVault(se1, pairB, detfUser, address(weth));
    }
}
