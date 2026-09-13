// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {ICLFactory} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLFactory.sol";
import {ICLPool} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLPool.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {ISlipstreamStandardExchangeDFPkg} from "contracts/protocols/dexes/aerodrome/slipstream/ISlipstreamStandardExchangeDFPkg.sol";
import {
    Slipstream_Component_FactoryService
} from "contracts/protocols/dexes/aerodrome/slipstream/Slipstream_Component_FactoryService.sol";
import {
    SlipstreamHermeticClBook
} from "contracts/protocols/dexes/aerodrome/slipstream/test/SlipstreamHermeticClBook.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SlipstreamFactoryStub} from
    "contracts/protocols/dexes/aerodrome/slipstream/test/bases/TestBase_SlipstreamStandardExchange.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

/**
 * @title TestBase_SlipstreamStandardExchange_Decimals
 * @notice Hermetic Slipstream SE with combo-decimal pair tokens. Does not call gold setUp
 *         (gold constructs 18-dec ERC20PermitMintableStub). pairToken = tokenA role.
 */
abstract contract TestBase_SlipstreamStandardExchange_Decimals is TestBase_Permit2, TestBase_VaultComponents {
    using Slipstream_Component_FactoryService for ICreate3FactoryProxy;
    using Slipstream_Component_FactoryService for IIndexedexManagerProxy;

    uint24 internal constant DEFAULT_WIDTH_MULTIPLIER = 10;
    uint24 internal constant FEE_LOW = 500;

    IFacet slipstreamStandardExchangeInFacet;
    IFacet slipstreamStandardExchangeOutFacet;
    ISlipstreamStandardExchangeDFPkg internal slipstreamStandardExchangeDFPkg;

    MintableERC20Decimals internal pairToken;
    MintableERC20Decimals internal otherToken;
    MintableERC20Decimals internal pairToken0;
    MintableERC20Decimals internal pairToken1;
    ICLFactory internal slipstreamFactory;
    SlipstreamHermeticClBook internal clBook;
    IStandardExchangeProxy internal vault;

    function _tokenADecimals() internal pure virtual returns (uint8);
    function _tokenBDecimals() internal pure virtual returns (uint8);

    function _uA(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_tokenADecimals()));
    }

    function _uB(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_tokenBDecimals()));
    }

    function _u0(uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(pairToken0.decimals()));
    }

    function _u1(uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(pairToken1.decimals()));
    }

    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();
        slipstreamStandardExchangeInFacet = create3Factory.deploySlipstreamStandardExchangeInFacet();
        slipstreamStandardExchangeOutFacet = create3Factory.deploySlipstreamStandardExchangeOutFacet();

        pairToken = new MintableERC20Decimals("PairToken", "PT", _tokenADecimals());
        otherToken = new MintableERC20Decimals("OtherToken", "OT", _tokenBDecimals());
        if (address(pairToken) < address(otherToken)) {
            pairToken0 = pairToken;
            pairToken1 = otherToken;
        } else {
            pairToken0 = otherToken;
            pairToken1 = pairToken;
        }

        slipstreamFactory = ICLFactory(address(new SlipstreamFactoryStub()));
        clBook = new SlipstreamHermeticClBook(
            address(pairToken0), address(pairToken1), FEE_LOW, int24(1), address(slipstreamFactory)
        );
        uint160 sqrtP = _oneToOneHumanSqrtPriceX96();
        clBook.initialize(sqrtP);
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtP);
        clBook.addLiquidity(tick - 10_000, tick + 10_000, 1e24);
        pairToken0.mint(address(clBook), _u0(1_000_000_000));
        pairToken1.mint(address(clBook), _u1(1_000_000_000));

        ISlipstreamStandardExchangeDFPkg.PkgInit memory pkgInit = ISlipstreamStandardExchangeDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            slipstreamStandardExchangeInFacet: slipstreamStandardExchangeInFacet,
            slipstreamStandardExchangeOutFacet: slipstreamStandardExchangeOutFacet,
            vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            permit2: permit2,
            slipstreamFactory: slipstreamFactory
        });

        vm.startPrank(owner);
        slipstreamStandardExchangeDFPkg = indexedexManager.deploySlipstreamStandardExchangeDFPkg(pkgInit);
        vm.stopPrank();

        vault = IStandardExchangeProxy(
            slipstreamStandardExchangeDFPkg.deployVault(ICLPool(address(clBook)), DEFAULT_WIDTH_MULTIPLIER)
        );
        vm.label(address(vault), "SlipstreamSE");
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    /// @dev sqrtPriceX96 for 1 human token0 = 1 human token1 (decimal-adjusted). Gold uses tick 0 at 18/18.
    function _oneToOneHumanSqrtPriceX96() internal view returns (uint160) {
        uint256 a0 = 10 ** uint256(pairToken0.decimals());
        uint256 a1 = 10 ** uint256(pairToken1.decimals());
        uint256 sqrt1 = Math.sqrt(a1);
        uint256 sqrt0 = Math.sqrt(a0);
        return uint160((sqrt1 << 96) / sqrt0);
    }
}
