// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {DeployPermit2} from "@crane/contracts/protocols/utils/permit2/test/utils/DeployPermit2.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {WETH9} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultComponent_FactoryService as WingsComponents} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultComponent_FactoryService.sol";

/// @notice Hookless UpperLowerWings vault used where a fixture previously bound a V4 FullSpread vault.
abstract contract TestBase_UniswapV4WingsSeSurface is TestBase_VaultComponents, DeployPermit2 {
    IPoolManager internal poolManager;
    PoolKey internal graduatedPoolKey;
    IWETH internal weth;
    address internal launchToken;
    IStandardExchangeProxy internal ponsSe;
    IPermit2 internal permit2;

    function setUp() public virtual override {
        TestBase_VaultComponents.setUp();
        permit2 = IPermit2(deployPermit2());
        weth = IWETH(address(new WETH9()));
        launchToken = address(new SimpleMintableERC20("Launch", "DTF"));
        poolManager = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            keccak256("WingsSeSurface.PoolManager")
        ));
        (address token0, address token1) = launchToken < address(weth)
            ? (launchToken, address(weth))
            : (address(weth), launchToken);
        graduatedPoolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        poolManager.initialize(graduatedPoolKey, uint160(1) << 96);
        IFacet[] memory facets_ = _wingsFacets();
        IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.PkgInit memory init =
            IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.PkgInit({
                facets: facets_,
                poolManager: poolManager,
                registry: indexedexManager,
                oracle: indexedexManager,
                permit2: permit2
            });
        bytes memory creationCode = ArtifactCreationCode.creationCode(
            create3Factory,
            "UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol:UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg"
        );
        vm.prank(owner);
        IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg pkg = IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg(
            indexedexManager.deployPkg(creationCode, abi.encode(init), keccak256("WingsSeSurface.Package"))
        );
        ponsSe = IStandardExchangeProxy(pkg.deployVault(
            IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.PkgArgs({
                poolKey: graduatedPoolKey,
                targetToken: launchToken
            })
        ));
        vm.label(address(ponsSe), "UniV4Se_Wings");
        SimpleMintableERC20(launchToken).mint(address(this), 1_000_000 ether);
        deal(address(weth), address(this), 1_000_000 ether);
    }

    function _activatePonsSe() internal virtual {
        uint256 amount_ = 10_000 ether;
        IERC20(launchToken).approve(address(ponsSe), amount_);IStandardExchangeIn(address(ponsSe)).exchangeIn(IERC20(launchToken), amount_, IERC20(address(ponsSe)), 0, address(this), false, _deadline()
        );
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _wrapWeth(address to, uint256 amount) internal {
        vm.deal(to, to.balance + amount);
        vm.prank(to);
        weth.deposit{value: amount}();
    }

    function _wingsFacets() internal returns (IFacet[] memory facets_) {
        facets_ = new IFacet[](13);
        facets_[0] = IFacet(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "ERC20Facet.sol:ERC20Facet"),
            "",
            keccak256("WingsSeSurface.ERC20")
        ));
        facets_[1] = IFacet(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "ERC5267Facet.sol:ERC5267Facet"),
            "",
            keccak256("WingsSeSurface.ERC5267")
        ));
        facets_[2] = IFacet(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "ERC2612Facet.sol:ERC2612Facet"),
            "",
            keccak256("WingsSeSurface.ERC2612")
        ));
        facets_[3] = IFacet(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "MultiAssetBasicVaultFacet.sol:MultiAssetBasicVaultFacet"),
            "",
            keccak256("WingsSeSurface.Basic")
        ));
        facets_[4] = IFacet(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "MultiAssetStandardVaultFacet.sol:MultiAssetStandardVaultFacet"),
            "",
            keccak256("WingsSeSurface.Standard")
        ));
        facets_[5] = WingsComponents.deployQueryFacet(create3Factory);
        facets_[6] = WingsComponents.deployExecutionDelegate(create3Factory);
        facets_[7] = WingsComponents.deployInFacet(create3Factory);
        facets_[8] = WingsComponents.deployOutFacet(create3Factory);
        facets_[9] = WingsComponents.deploySYFacet(create3Factory);
        facets_[10] = WingsComponents.deployRebalanceFacet(create3Factory);
        facets_[11] = WingsComponents.deployTransitionFacet(create3Factory);
        facets_[12] = WingsComponents.deployEconomicFacet(create3Factory);
    }
}
