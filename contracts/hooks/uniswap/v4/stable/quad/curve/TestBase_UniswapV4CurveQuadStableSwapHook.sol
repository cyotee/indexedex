// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";

import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {
    IUniswapV4CurveQuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/curve/interfaces/IUniswapV4CurveQuadStableSwapHook.sol";
import {
    IUniswapV4CurveQuadStableSwapHookPackage
} from "contracts/hooks/uniswap/v4/stable/quad/curve/interfaces/IUniswapV4CurveQuadStableSwapHookPackage.sol";
import {
    UniswapV4CurveQuadStableSwapHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHook_FactoryService.sol";
import {
    UniswapV4CurveQuadStableSwapHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHookPairPoolLib.sol";

/**
 * @title TestBase_UniswapV4CurveQuadStableSwapHook
 * @notice Package path TestBase: hook factory + registry deployHookVault + six pair doors.
 * @dev Ladder: CraneTest → IndexedexTest → TestBase_VaultComponents → this.
 */
abstract contract TestBase_UniswapV4CurveQuadStableSwapHook is TestBase_VaultComponents {
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    MintableDec internal t0;
    MintableDec internal t1;
    MintableDec internal t2;
    MintableDec internal t3;

    IPoolManager internal pm;
    IUniswapV4HookDiamondPackageCallBackFactory internal hookFactory;
    IUniswapV4CurveQuadStableSwapHookPackage internal hookPkg;
    address internal hook;
    IUniswapV4CurveQuadStableSwapHook internal quad;

    address internal user = address(0xBEEF);
    address internal deployerEoa = address(0xCAFE);

    uint24 internal constant DEMO_FEE = 500;
    uint256 internal constant DEMO_AMP = 100;
    uint256 internal constant DUST = 1;

    function setUp() public virtual override {
        TestBase_VaultComponents.setUp();

        // four sorted tokens (addresses must be ascending after deploy)
        MintableDec a = new MintableDec("USD Coin", "USDC", 6);
        MintableDec b = new MintableDec("Tether", "USDT", 6);
        MintableDec c = new MintableDec("Dai Stablecoin", "DAI", 18);
        MintableDec d = new MintableDec("USDS", "USDS", 18);
        (t0, t1, t2, t3) = _sortFour(a, b, c, d);

        pm = IPoolManager(address(new PoolManager(address(this))));

        // --- Shared hook diamond factory ---
        IFacet hookFlagsFacet = HookFactoryService.deployUniswapV4HookFlagsFacet(create3Factory);
        IFacetRegistry facetReg = IFacetRegistry(address(create3Factory));
        hookFactory = HookFactoryService.deployUniswapV4HookDiamondPackageCallBackFactory(
            create3Factory,
            IUniswapV4HookDiamondPackageCallBackFactory.InitArgs({
                erc165Facet: facetReg.canonicalFacet(type(IERC165).interfaceId),
                diamondLoupeFacet: facetReg.canonicalFacet(type(IDiamondLoupe).interfaceId),
                erc8109IntrospectionFacet: facetReg.canonicalFacet(type(IERC8109Introspection).interfaceId),
                postDeployHookFacet: facetReg.canonicalFacet(type(IPostDeployAccountHook).interfaceId),
                hookFlagsFacet: hookFlagsFacet
            })
        );
        vm.prank(owner);
        IVaultRegistryDeployment(address(indexedexManager)).setHookDiamondPackageFactory(address(hookFactory));

        // --- Product package ---
        IFacet hooksFacet = PkgFactory.deployHooksFacet(create3Factory);
        IFacet liquidityFacet = PkgFactory.deployLiquidityFacet(create3Factory);
        hookPkg = PkgFactory.deployPackage(
            IVaultRegistryDeployment(address(indexedexManager)),
            owner,
            IUniswapV4CurveQuadStableSwapHookPackage.PkgInit({
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
                hooksFacet: hooksFacet,
                liquidityFacet: liquidityFacet,
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet
            }),
            abi.encode(type(IUniswapV4CurveQuadStableSwapHookPackage).name, "v1")._hash()
        );

        IUniswapV4CurveQuadStableSwapHookPackage.PkgArgs memory args = _defaultPkgArgs();
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        quad = IUniswapV4CurveQuadStableSwapHook(hook);

        _fundUser();
        vm.startPrank(user);
        t0.approve(hook, type(uint256).max);
        t1.approve(hook, type(uint256).max);
        t2.approve(hook, type(uint256).max);
        t3.approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function _defaultPkgArgs()
        internal
        view
        returns (IUniswapV4CurveQuadStableSwapHookPackage.PkgArgs memory)
    {
        address[4] memory providers;
        return IUniswapV4CurveQuadStableSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            token0: address(t0),
            token1: address(t1),
            token2: address(t2),
            token3: address(t3),
            lpFeePips: DEMO_FEE,
            baseAmp: DEMO_AMP,
            rateProviders: providers
        });
    }

    function _pkgArgs(
        address token0_,
        address token1_,
        address token2_,
        address token3_,
        uint24 fee,
        uint256 amp,
        address[4] memory providers
    ) internal view returns (IUniswapV4CurveQuadStableSwapHookPackage.PkgArgs memory) {
        return IUniswapV4CurveQuadStableSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            token0: token0_,
            token1: token1_,
            token2: token2_,
            token3: token3_,
            lpFeePips: fee,
            baseAmp: amp,
            rateProviders: providers
        });
    }

    function _deployHook(IUniswapV4CurveQuadStableSwapHookPackage.PkgArgs memory args)
        internal
        returns (address h)
    {
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        h = PkgFactory.deployHook(hookPkg, args, mineNonce);
    }

    function _poolKeys() internal view returns (PoolKey[6] memory) {
        return hookPkg.pairPoolKeys(hook);
    }

    /// @dev Human units → raw (respects each token's decimals). `human` is whole tokens.
    function _raw(MintableDec t, uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(t.decimals()));
    }

    function _balancedAmounts(uint256 human) internal view returns (uint256[4] memory amounts) {
        amounts[0] = _raw(t0, human);
        amounts[1] = _raw(t1, human);
        amounts[2] = _raw(t2, human);
        amounts[3] = _raw(t3, human);
    }

    function _fundUser() internal {
        t0.mint(user, _raw(t0, 10_000_000));
        t1.mint(user, _raw(t1, 10_000_000));
        t2.mint(user, _raw(t2, 10_000_000));
        t3.mint(user, _raw(t3, 10_000_000));
    }

    function _addLiquidityFirst(uint256 human) internal returns (uint256 shares) {
        uint256[4] memory amounts = _balancedAmounts(human);
        uint256[4] memory mins;
        vm.prank(user);
        (shares,) = quad.addLiquidity(amounts, mins, user, 0);
    }

    /// @dev Product book as fixed array (reads four reserveOf legs).
    function _bookReserves(address h) internal view returns (uint256[4] memory r) {
        IUniswapV4CurveQuadStableSwapHook q = IUniswapV4CurveQuadStableSwapHook(h);
        r[0] = q.reserveOf(q.token0());
        r[1] = q.reserveOf(q.token1());
        r[2] = q.reserveOf(q.token2());
        r[3] = q.reserveOf(q.token3());
    }

    function _bookReserves() internal view returns (uint256[4] memory) {
        return _bookReserves(hook);
    }

    function _sortFour(MintableDec a, MintableDec b, MintableDec c, MintableDec d)
        internal
        pure
        returns (MintableDec, MintableDec, MintableDec, MintableDec)
    {
        address[4] memory addrs = [address(a), address(b), address(c), address(d)];
        MintableDec[4] memory toks = [a, b, c, d];
        for (uint256 i; i < 4; ++i) {
            for (uint256 j; j + 1 < 4; ++j) {
                if (addrs[j] > addrs[j + 1]) {
                    (addrs[j], addrs[j + 1]) = (addrs[j + 1], addrs[j]);
                    (toks[j], toks[j + 1]) = (toks[j + 1], toks[j]);
                }
            }
        }
        return (toks[0], toks[1], toks[2], toks[3]);
    }

    function _registry() internal view returns (IVaultRegistryVaultQuery) {
        return IVaultRegistryVaultQuery(address(indexedexManager));
    }

    function _requiredFlags() internal pure returns (uint160) {
        return PkgFactory.requiredFlags();
    }

    function _assertPoolLive(PoolKey memory key) internal view {
        assertTrue(PairPoolLib.isPoolLive(pm, key), "pair door not initialized on PoolManager");
        assertEq(address(key.hooks), hook, "hooks must be product proxy");
        assertEq(key.fee, DEMO_FEE, "lpFeePips");
    }

    function _assertSixPoolsLiveFromPostDeploy() internal view {
        PoolKey[6] memory keys = _poolKeys();
        for (uint256 i; i < 6; ++i) {
            _assertPoolLive(keys[i]);
        }
    }
}

/// @dev Non-SUT mintable ERC-20 with configurable decimals (test funding only).
contract MintableDec {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}

/// @dev Rate provider harness (non-SUT).
contract RateProviderHarness {
    uint256 public rate = 1e18;
    bool public shouldRevert;
    bool public badReturndata;

    function setRate(uint256 r) external {
        rate = r;
    }

    function setShouldRevert(bool v) external {
        shouldRevert = v;
    }

    function setBadReturndata(bool v) external {
        badReturndata = v;
    }

    function getRate() external view returns (uint256) {
        if (shouldRevert) revert("rate fail");
        if (badReturndata) {
            assembly {
                mstore(0x00, 0x01)
                return(0x00, 0x01)
            }
        }
        return rate;
    }
}
