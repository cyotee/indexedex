// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRouter} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IRouter.sol";
import {TokenConfig, TokenType, PoolRoleAccounts} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IStablePool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/pool-stable/IStablePool.sol";
import {IStablePoolFactory} from "contracts/interfaces/IStablePoolFactory.sol";
import {IWeightedPoolFactory} from "contracts/interfaces/IWeightedPoolFactory.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IBalancerV3StandardExchangeRouterProxy} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";

import {IComposedStableCommonDetfDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfDFPkg.sol";
import {IComposedStableCommonDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfInfo.sol";
import {ComposedStableCommonDetfRepo as Repo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol";
import {ComposedStableCommonDetf_Pkg_FactoryService as Pkgs} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_Pkg_FactoryService.sol";
import {ComposedStableCommonDetf_Facet_FactoryService as Facets} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_Facet_FactoryService.sol";
import {TestBase_FundedBalancerDETF} from "contracts/test/bases/TestBase_FundedBalancerDETF.sol";
abstract contract TestBase_FundedComposedDETF is TestBase_FundedBalancerDETF {
    using Facets for ICreate3FactoryProxy;
    using Pkgs for IVaultRegistryDeployment;
    IStablePool internal composedStable;
    IStablePool internal composedCommon;
    IStandardExchangeIn internal stableAdapter;
    IStandardExchangeIn internal commonAdapter;
    IComposedStableCommonDetfDFPkg internal composedPkg;
    IComposedStableCommonDetfInfo internal composedInfo;
    IComposedStableCommonDetfBonding internal composedBonding;
    IStandardExchangeIn internal composedIn;
    IStandardExchangeOut internal composedOut;
    address internal composedDetf;
    uint256 internal shareIndex;
    function setUp() public virtual override {
        super.setUp();
        _deployInnerPools();
        IComposedStableCommonDetfDFPkg.PkgInit memory p_;
        p_.erc20Facet = erc20Facet; p_.erc5267Facet = erc5267Facet; p_.erc2612Facet = erc2612Facet;
        p_.multiAssetBasicVaultFacet = multiAssetBasicVaultFacetDetf; p_.multiAssetStandardVaultFacet = multiAssetStandardVaultFacetDetf;
        p_.composedStableCommonDetfBondingFacet = create3Factory.deployComposedStableCommonDetfBondingFacet();
        p_.composedStableCommonDetfExchangeInFacet = create3Factory.deployComposedStableCommonDetfExchangeInFacet();
        p_.composedStableCommonDetfExchangeOutQueryFacet = create3Factory.deployComposedStableCommonDetfExchangeOutQueryFacet();
        p_.rebasingDetfTokenPricingFacet = create3Factory.deployRebasingDetfTokenPricingFacet();
        p_.vaultRegistryDeployment = IVaultRegistryDeployment(address(indexedexManager)); p_.feeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        p_.balancerV3Router = IBalancerV3StandardExchangeRouterProxy(address(seRouter)); p_.balancerV3Vault = IVault(address(vault));
        p_.weightedPoolFactory = IWeightedPoolFactory(testPoolFactory); p_.bondNftVaultPkg = bondNftVaultPkg;
        p_.rebasingClaimTokenPkg = rebasingClaimTokenPkg; p_.syPkg = syPkg;
        vm.startPrank(owner); composedPkg = IVaultRegistryDeployment(address(indexedexManager)).deployComposedStableCommonDetfDFPkg(p_); vm.stopPrank();
        _useComposed(_deployComposed(100e18, 0.1e18));
    }
    function _deployInnerPools() internal {
        IStablePoolFactory factory_ = IStablePoolFactory(create3Factory.create3WithArgs(ArtifactCreationCode.creationCode(create3Factory, "StablePoolFactory.sol:StablePoolFactory"),
            abi.encode(vault, uint32(365 days), "Factory v1", "Pool v1"), keccak256("FundedComposedStableFactory")));
        IERC20[] memory tokens_ = new IERC20[](2); tokens_[0] = IERC20(address(daiUsdcVault)); tokens_[1] = weth;
        if (address(tokens_[0]) > address(tokens_[1])) (tokens_[0], tokens_[1]) = (tokens_[1], tokens_[0]);
        shareIndex = address(tokens_[0]) == address(daiUsdcVault) ? 0 : 1;
        TokenConfig[] memory config_ = new TokenConfig[](2);
        for (uint256 i_; i_ < 2; ++i_) { config_[i_].token = tokens_[i_]; config_[i_].tokenType = TokenType.STANDARD; }
        PoolRoleAccounts memory roles_;
        composedStable = IStablePool(factory_.create("Funded Composed Stable", "csBPT", config_, 200, roles_, 0.003e18, address(0), false, false, keccak256("funded-stable")));
        composedCommon = IStablePool(factory_.create("Funded Composed Common", "ccBPT", config_, 200, roles_, 0.003e18, address(0), false, false, keccak256("funded-common")));
        stableAdapter = _poolAdapter(address(composedStable), tokens_);
        commonAdapter = _poolAdapter(address(composedCommon), tokens_);
        _seedInnerPools(tokens_);
    }
    function _poolAdapter(address pool_, IERC20[] memory tokens_) internal returns (IStandardExchangeIn) {
        return IStandardExchangeIn(create3Factory.create3WithArgs(ArtifactCreationCode.creationCode(create3Factory, "BalancerV3SinglePoolStandardExchange.sol:BalancerV3SinglePoolStandardExchange"),
            abi.encode(IRouter(address(router)), pool_, IERC20(pool_), tokens_), keccak256(abi.encode("funded-composed-adapter",pool_))));
    }
    function _seedInnerPools(IERC20[] memory tokens_) internal {
        deal(address(dai), owner, 200_000e18, true); deal(address(weth), owner, 100_000e18, true);
        vm.startPrank(owner);
        dai.approve(address(daiUsdcVault), 200_000e18);
        uint256 shares_ = IStandardExchangeIn(address(daiUsdcVault)).exchangeIn(dai, 200_000e18, IERC20(address(daiUsdcVault)), 0, owner, false, block.timestamp);
        for (uint256 i_; i_ < 2; ++i_) {
            tokens_[i_].approve(address(permit2), type(uint256).max);
            IPermit2(address(permit2)).approve(address(tokens_[i_]), address(router), type(uint160).max, type(uint48).max);
        }
        uint256[] memory amounts_ = new uint256[](2); amounts_[shareIndex] = shares_ / 2; amounts_[1 - shareIndex] = 50_000e18;
        router.initialize(address(composedStable), tokens_, amounts_, 0, false, "");
        router.initialize(address(composedCommon), tokens_, amounts_, 0, false, "");
        vm.stopPrank();
    }
    function _deployComposed(uint256 mint_, uint256 burn_) internal returns (address) {
        return _deployComposed(mint_, burn_, 0);
    }
    function _deployComposed(uint256 mint_, uint256 burn_, uint256 rate_) internal returns (address) {
        IComposedStableCommonDetfDFPkg.PkgArgs memory p_ = _composedArgs(mint_, burn_, rate_);
        vm.prank(owner); return composedPkg.deployVault(p_);
    }
    function _composedArgs(uint256 mint_, uint256 burn_, uint256 rate_) internal view returns (IComposedStableCommonDetfDFPkg.PkgArgs memory p_) {
        p_.name = "Rate DETF of Composed Stable"; p_.symbol = "DETF"; p_.stablePool = composedStable; p_.commonPool = composedCommon;
        p_.rateAsset = weth; p_.stablePoolExitPricer = stableAdapter; p_.commonPoolExitPricer = commonAdapter;
        p_.reserveWeights = [uint256(0.5e18),uint256(0.25e18),uint256(0.25e18)];
        p_.openingDetfPrices = [uint256(1e18), uint256(1e18)];
        p_.reserveSeedAmounts = [uint256(2_000e9), uint256(1_000e18), uint256(1_000e18)];
        p_.mintThreshold = mint_; p_.burnThreshold = burn_; p_.expansionClosureRatePerSecond = rate_;
        p_.routes = new Repo.RouteConfig[](1);
        p_.routes[0] = Repo.RouteConfig(dai, IERC20(address(daiUsdcVault)), IStandardExchangeIn(address(daiUsdcVault)), stableAdapter, commonAdapter, shareIndex, shareIndex);
    }
    function _useComposed(address detf_) internal {
        composedDetf = detf_; composedInfo = IComposedStableCommonDetfInfo(detf_); composedBonding = IComposedStableCommonDetfBonding(detf_);
        composedIn = IStandardExchangeIn(detf_); composedOut = IStandardExchangeOut(detf_);
    }
    function _bootstrapComposed(address who_) internal returns (uint256 id_, uint256 principal_) {
        vm.startPrank(owner); IERC20(address(composedStable)).transfer(who_, 1_000e18); IERC20(address(composedCommon)).transfer(who_, 1_000e18); vm.stopPrank();
        vm.startPrank(who_); IERC20(address(composedStable)).approve(composedDetf, 1_000e18); IERC20(address(composedCommon)).approve(composedDetf, 1_000e18);
        (id_,principal_) = composedBonding.initializeReserve(1_000e18, 1_000e18, DEFAULT_MIN_LOCK, who_, block.timestamp); vm.stopPrank();
    }
}
