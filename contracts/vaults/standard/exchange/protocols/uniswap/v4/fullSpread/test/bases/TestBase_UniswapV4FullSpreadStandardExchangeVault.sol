// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {TestBase_Weth9} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/TestBase_Weth9.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultDFPkg as IPackage} from "../../interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService as Components} from "../../UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultComponentBindings as IBindings} from "../../UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol";
import {UniswapV4ProtocolAwareFacet} from "@crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4ProtocolAwareFacet.sol";
import {UniswapV4SinglePositionAwareFacet} from "@crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4SinglePositionAwareFacet.sol";

interface IFullSpreadVault {
    function exchangeIn(address tokenIn, uint256 amountIn, address tokenOut, uint256 minAmountOut, address recipient, bool pretransferred, uint256 deadline)
        external
        returns (uint256 amountOut, uint256 amountRefunded);
    function exchangeBundleInForSingleOut(uint256[] calldata amountsIn, address tokenOut, uint256 minAmountOut, address recipient, bool pretransferred, uint256 deadline)
        external
        returns (uint256 amountOut, uint256[] memory amountsRefunded);
    function vaultTokens() external view returns (address[] memory);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function positionLiquidity() external view returns (uint128);
}

abstract contract TestBase_UniswapV4FullSpreadStandardExchangeVault is IndexedexTest, TestBase_Weth9 {
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    IPoolManager internal pool;
    ERC20PermitMintableStub internal token0;
    ERC20PermitMintableStub internal token1;
    PoolKey internal key;
    IPackage internal package;
    IFullSpreadVault internal vault;

    function setUp() public virtual override(IndexedexTest, TestBase_Weth9) {
        IndexedexTest.setUp();
        TestBase_Weth9.setUp();
        pool = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            keccak256("FullSpread.Test.PoolManager")
        ));
        _deployPool(_native());
        IPackage.PkgInit memory init_ = _packageInit();
        vm.prank(owner);
        package = Components.deployUniswapV4FullSpreadStandardExchangeVaultDFPkg(indexedexManager, init_);
        vault = IFullSpreadVault(package.deployVault(IPackage.PkgArgs(key, "Full spread shares", "FS")));
        vm.label(address(vault), "FullSpreadVault");
    }

    function _native() internal pure virtual returns (bool) {
        return false;
    }

    function _deployPool(bool native_) internal {
        token1 = new ERC20PermitMintableStub("FullSpread B", "B", 18, address(this), 0);
        if (native_) token0 = ERC20PermitMintableStub(address(0));
        else {
            token0 = new ERC20PermitMintableStub("FullSpread A", "A", 18, address(this), 0);
            if (address(token0) > address(token1)) (token0, token1) = (token1, token0);
        }
        key = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, 60, IHooks(address(0)));
        pool.initialize(key, uint160(1) << 96);
    }

    function _packageInit() internal returns (IPackage.PkgInit memory init_) {
        init_.erc20Facet = create3Factory.deployERC20Facet();
        init_.erc2612Facet = create3Factory.deployERC2612Facet();
        init_.erc5267Facet = create3Factory.deployERC5267Facet();
        init_.basicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        init_.standardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();
        init_.moneyFacet = Components.deployMoneyFacet(create3Factory);
        init_.quoteFacet = Components.deployQuoteFacet(create3Factory);
        init_.outFacet = Components.deployOutFacet(create3Factory);
        init_.queryFacet = Components.deployQueryFacet(create3Factory);
        init_.callbackFacet = Components.deployCallbackFacet(create3Factory);
        init_.uniswapV4ProtocolAwareFacet = Components.deployProtocolAwareFacet(create3Factory);
        init_.uniswapV4SinglePositionAwareFacet = Components.deploySinglePositionAwareFacet(create3Factory);
        init_.poolManager = pool;
        init_.positionDescriptor = address(0xD1);
        init_.positionManager = address(0xD2);
        init_.quoter = address(0xD3);
        init_.stateView = address(0xD4);
        init_.reservesLens = address(0xD5);
        init_.universalRouter = address(0xD6);
        init_.registry = indexedexManager;
        init_.oracle = IVaultFeeOracleQuery(address(indexedexManager));
        init_.weth = IWETH(address(weth));
        init_.diamondFactory = diamondFactory;
        init_.linkedLibraries = IBindings(address(init_.moneyFacet)).linkedComponents();
    }

    function _fund(address recipient_, uint256 amount0_, uint256 amount1_) internal {
        if (address(token0) != address(0)) token0.mint(recipient_, amount0_);
        token1.mint(recipient_, amount1_);
    }

    function _approve(address vault_) internal {
        if (address(token0) != address(0)) IERC20(address(token0)).approve(vault_, type(uint256).max);
        IERC20(address(token1)).approve(vault_, type(uint256).max);
    }
}
