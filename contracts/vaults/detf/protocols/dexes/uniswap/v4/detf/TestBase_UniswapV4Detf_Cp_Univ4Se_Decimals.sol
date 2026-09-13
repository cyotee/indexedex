// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    IUniswapV4Detf
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/// @notice H-CP-GV4 decimal: CP hook + Uni V4 SE. pairToken decimals from combo; vaultShare stays 18.
abstract contract TestBase_UniswapV4Detf_Cp_Univ4Se_Decimals is TestBase_UniswapV4Detf_Decimals {
    MintableERC20Decimals internal seOther;
    IWETH internal weth;
    PoolKey internal sePoolKey;
    address internal mintToken;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pairToken = new MintableERC20Decimals("Pair", "PAIR", _pairDecimals());
        seOther = new MintableERC20Decimals("Rate", "RATE", _rateDecimals());
        detfDecimalsStub = new MintableERC20Decimals("DetfStub", "DSTUB", 18);
        pm = IPoolManager(address(IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            keccak256("TestBase_UniswapV4Detf_Cp_Univ4Se_Decimals_PoolManager")
        ))));
        weth = SeLib.newWeth();

        SeLib.Univ4SePkg memory v4pkg = SeLib.deployUniv4SePkg(_craneCtx(), pm, weth);
        sePoolKey = SeLib.initAndSeedUniv4Pool(pm, address(pairToken), address(seOther));
        se = SeLib.deployUniv4Vault(v4pkg.pkg, sePoolKey);

        _deployHookFactoryAndPkg();
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();
        _setDefaultBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        detf = _deployHookThenDetf(_defaultDetfArgs());
        detfInfo = IUniswapV4Detf(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        mintToken = _readMintToken();

        pairToken.mint(detfUser, _uPair(10_000_000));
        vm.startPrank(detfUser);
        pairToken.approve(detf, type(uint256).max);
        pairToken.approve(se, type(uint256).max);
        IERC20(se).approve(detf, type(uint256).max);
        vm.stopPrank();
        SeLib.activatePositionVault(se, mintToken, detfUser, address(weth));
    }

    function _craneCtx() internal view returns (SeLib.CraneCtx memory ctx) {
        ctx.create3Factory = create3Factory;
        ctx.indexedexManager = indexedexManager;
        ctx.diamondPackageFactory = diamondPackageFactory;
        ctx.permit2 = permit2;
        ctx.erc20Facet = erc20Facet;
        ctx.erc5267Facet = erc5267Facet;
        ctx.erc2612Facet = erc2612Facet;
        ctx.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        ctx.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        ctx.owner = owner;
    }

    function _readMintToken() internal view returns (address t) {
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] != detf) return toks[i];
        }
        revert("no mintToken");
    }

    function _firstBond(uint256 pairAmount_) internal virtual override returns (uint256 tokenId, uint256 shares) {
        vm.startPrank(detfUser);
        (tokenId, shares) = detfInfo.bond(
            IERC20(mintToken), pairAmount_, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }
}
