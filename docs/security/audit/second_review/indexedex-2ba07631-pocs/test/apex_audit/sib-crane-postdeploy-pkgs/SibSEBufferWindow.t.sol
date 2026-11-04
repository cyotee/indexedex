// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm, VmSafe} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {TokenConfig, TokenType} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IBalancerV3ConstantProductPoolStandardVaultPkg} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/IBalancerV3ConstantProductPoolStandardVaultPkg.sol";
import {BalancerV3ConstantProductPool_FactoryService} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPool_FactoryService.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

import {WindowProbe} from "./WindowProbe.sol";
import {SibBackdoorFacet, SibEvilToken, SibEvilVault, SibEvilHooks} from "./SibEvil.sol";

/// Family: Balancer V3 constProd/standardExchange SE-buffer pool (StandardExchangeBufferPoolStandardVaultPkg).
/// deployPool(seVault, tta) is permissionless and does NOT validate seVault/tta, so both slots are attacker code.
contract SibSEBufferWindowTest is TestBase_StandardExchangeBufferPool {
    using BalancerV3ConstantProductPool_FactoryService for IVaultRegistryDeployment;

    WindowProbe.Res internal honestRes;

    function _deployBufferPool() internal virtual override {
        vm.startStateDiffRecording();
        super._deployBufferPool();
        Vm.AccountAccess[] memory a = vm.stopAndReturnStateDiff();
        honestRes = WindowProbe.analyze(a, "SEBuffer-honest");
    }

    function test_honest_SEBuffer_noUntrustedCallInWindow() public view {
        assertGe(honestRes.windows, 1, "window found");
        assertGe(honestRes.postDeployCalls, 1, "factory postDeploy seen");
        assertEq(honestRes.foreignPostDeployAttempts, 0, "no foreign postDeploy");
        assertEq(honestRes.hijackDelegatecalls, 0, "no hijack");
        assertEq(honestRes.callsIntoSubst, 0, "no CALL into substitutable slot");
        assertEq(IDiamondLoupe(bufferPool).facetAddress(IPostDeployAccountHook.postDeploy.selector), address(0));
    }

    /// Unprivileged attacker deploys an SE-buffer pool with attacker code in BOTH free slots
    /// (tta and seVault). Every callback attempts the hook hijack on the predicted pool and rate provider.
    function test_adversarial_SEBuffer_evilTtaAndVault_cannotHijack() public {
        address attacker = makeAddr("attacker");
        vm.startPrank(attacker);
        SibBackdoorFacet backdoor = new SibBackdoorFacet(attacker);
        SibEvilToken evilTta = new SibEvilToken(address(backdoor));
        SibEvilVault evilVault = new SibEvilVault(address(backdoor));
        vm.stopPrank();

        address predictedPool = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(bufferPoolPkg)), abi.encode(address(evilTta), address(evilVault))
        );
        address predictedRp = diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(seRateProviderPkg)),
            abi.encode(address(evilVault), address(0), address(evilTta))
        );
        address[] memory t = new address[](2);
        t[0] = predictedPool;
        t[1] = predictedRp;
        evilTta.setTargets(t);
        evilVault.setTargets(t);

        vm.startStateDiffRecording();
        vm.prank(attacker);
        address pool;
        bool ok;
        try bufferPoolPkg.deployPool(IStandardExchange(address(evilVault)), IERC20(address(evilTta))) returns (address p) {
            pool = p;
            ok = true;
        } catch (bytes memory r) {
            emit log_named_bytes("adversarial deploy reverted", r);
        }
        Vm.AccountAccess[] memory a = vm.stopAndReturnStateDiff();
        WindowProbe.Res memory res = WindowProbe.analyze(a, "SEBuffer-adversarial");

        emit log_named_uint("adversarial deploy succeeded", ok ? 1 : 0);
        emit log_named_uint("foreign postDeploy() attempts by attacker code", res.foreignPostDeployAttempts);
        emit log_named_uint("hijack delegatecalls (reverted)", res.hijackDelegatecallsReverted);
        assertGt(res.foreignPostDeployAttempts, 0, "attacker code did try");
        assertEq(res.hijackDelegatecalls, 0, "no successful hijack delegatecall");
        if (ok) {
            assertEq(pool, predictedPool, "prediction");
            assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(pool), "registered");
            assertEq(IDiamondLoupe(pool).facetAddress(SibBackdoorFacet.exec.selector), address(0), "NO backdoor");
            assertEq(IDiamondLoupe(pool).facetAddress(IPostDeployAccountHook.postDeploy.selector), address(0));
            if (predictedRp.code.length > 0) {
                assertEq(IDiamondLoupe(predictedRp).facetAddress(SibBackdoorFacet.exec.selector), address(0), "rp clean");
            }
        }
        assertEq(res.callsIntoSubst, 0, "attacker code never received a non-static CALL in window");
    }

    /// Oracle validation: run the probe on the known ConstProd hook hijack (r3). It MUST be flagged.
    function test_oracleControl_constProdHijackIsFlagged() public {
        IBalancerV3ConstantProductPoolStandardVaultPkg.PkgInit memory p_;
        p_.basicVaultFacet = multiAssetBasicVaultFacet;
        p_.standardVaultFacet = multiAssetStandardVaultFacet;
        p_.balancerV3VaultAwareFacet = balancerV3VaultAwareFacet;
        p_.betterBalancerV3PoolTokenFacet = betterBalancerV3PoolTokenFacet;
        p_.defaultPoolInfoFacet = defaultPoolInfoFacet;
        p_.standardSwapFeePercentageBoundsFacet = standardSwapFeePercentageBoundsFacet;
        p_.unbalancedLiquidityInvariantRatioBoundsFacet = unbalancedLiquidityInvariantRatioBoundsFacet;
        p_.balancerV3AuthenticationFacet = balancerV3AuthenticationFacet;
        p_.balancerV3ConstProdPoolFacet =
            BalancerV3ConstantProductPool_FactoryService.deployBalancerV3ConstantProductPoolFacet(create3Factory);
        p_.vaultRegistry = IVaultRegistryDeployment(address(indexedexManager));
        p_.vaultFeeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        p_.balancerV3Vault = bv3Vault;
        p_.diamondFactory = diamondPackageFactory;
        vm.startPrank(owner);
        IBalancerV3ConstantProductPoolStandardVaultPkg cpPkg =
            IVaultRegistryDeployment(address(indexedexManager)).deployBalancerV3ConstantProductPoolStandardVaultPkg(p_);
        vm.stopPrank();

        address attacker = makeAddr("attacker");
        vm.startPrank(attacker);
        SibBackdoorFacet backdoor = new SibBackdoorFacet(attacker);
        SibEvilHooks hooks = new SibEvilHooks(address(backdoor));
        TokenConfig[] memory t_ = new TokenConfig[](2);
        (address x, address y) = address(tta) < address(ttb) ? (address(tta), address(ttb)) : (address(ttb), address(tta));
        t_[0] = TokenConfig(IERC20(x), TokenType.STANDARD, IRateProvider(address(0)), false);
        t_[1] = TokenConfig(IERC20(y), TokenType.STANDARD, IRateProvider(address(0)), false);
        vm.startStateDiffRecording();
        address evilPool = cpPkg.deployVault(t_, address(hooks));
        Vm.AccountAccess[] memory a = vm.stopAndReturnStateDiff();
        vm.stopPrank();
        WindowProbe.Res memory res = WindowProbe.analyze(a, "ConstProd-control");
        assertEq(IDiamondLoupe(evilPool).facetAddress(SibBackdoorFacet.exec.selector), address(backdoor), "control hijack lands");
        assertGe(res.foreignPostDeploy, 1, "oracle flags foreign postDeploy");
        assertGe(res.hijackDelegatecalls, 1, "oracle flags hijack delegatecall");
        assertGe(res.callsIntoSubst, 1, "oracle flags CALL into attacker hooks");
    }
}
