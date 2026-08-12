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
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";

import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {
    IUniswapV4WeightedSwapHookPackage
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHookPackage.sol";
import {
    UniswapV4WeightedSwapHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHook_FactoryService.sol";
import {
    UniswapV4WeightedSwapHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookPairPoolLib.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";

/**
 * @title TestBase_UniswapV4WeightedSwapHook
 * @notice Package path TestBase: hook factory + registry deployHookVault + pair doors.
 * @dev Ladder: CraneTest → IndexedexTest → TestBase_VaultComponents → this.
 *      Production-first. No mocks of hook/package/factory/Math/Repo/oracle/PoolManager under test.
 */
abstract contract TestBase_UniswapV4WeightedSwapHook is TestBase_VaultComponents {
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    IPoolManager internal pm;
    IUniswapV4HookDiamondPackageCallBackFactory internal hookFactory;
    IUniswapV4WeightedSwapHookPackage internal hookPkg;
    IVaultFeeOracleQuery internal vaultFeeOracle;

    address internal user = address(0xBEEF);
    address internal feeRecipient;

    uint256 internal constant DEMO_DEX_FEE = 3e15; // 0.3%
    uint256 internal constant DEMO_USAGE_FEE = 5e16; // 5% of growth share algebra

    function setUp() public virtual override {
        TestBase_VaultComponents.setUp();

        pm = IPoolManager(address(new PoolManager(address(this))));
        vaultFeeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        feeRecipient = address(feeCollector);

        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(feeRecipient));
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultDexSwapFee(DEMO_DEX_FEE);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(DEMO_USAGE_FEE);
        vm.stopPrank();

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
            IUniswapV4WeightedSwapHookPackage.PkgInit({
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
            abi.encode(type(IUniswapV4WeightedSwapHookPackage).name, "v1")._hash()
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                              deploy helpers                            */
    /* ---------------------------------------------------------------------- */

    function _mineAndDeploy(
        address[] memory tokens,
        uint256[] memory weights,
        address[] memory providers
    ) internal returns (address hook, PoolKey[] memory keys) {
        IUniswapV4WeightedSwapHookPackage.PkgArgs memory args = IUniswapV4WeightedSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(vaultFeeOracle),
            tokens: tokens,
            weights: weights,
            rateProviders: providers,
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        keys = PairPoolLib.computePairKeys(tokens, hook, int24(int256(Math.TICK_SPACING)));
    }

    function _deployN2() internal returns (address hook, MintableDec t0, MintableDec t1) {
        MintableDec a = new MintableDec("TokenA", "TKA", 18);
        MintableDec b = new MintableDec("TokenB", "TKB", 18);
        (t0, t1) = address(a) < address(b) ? (a, b) : (b, a);
        address[] memory tokens = new address[](2);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5e17;
        weights[1] = 5e17;
        address[] memory providers = new address[](2);
        (hook,) = _mineAndDeploy(tokens, weights, providers);
        _fundAndApprove(hook, tokens);
    }

    function _deployN3()
        internal
        returns (address hook, MintableDec t0, MintableDec t1, MintableDec t2)
    {
        MintableDec a = new MintableDec("USD Coin", "USDC", 6);
        MintableDec b = new MintableDec("Wrapped Ether", "WETH", 18);
        MintableDec c = new MintableDec("Dai", "DAI", 18);
        (t0, t1, t2) = _sortThree(a, b, c);
        address[] memory tokens = new address[](3);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        tokens[2] = address(t2);
        uint256[] memory weights = new uint256[](3);
        weights[0] = 4e17;
        weights[1] = 3e17;
        weights[2] = 3e17;
        address[] memory providers = new address[](3);
        (hook,) = _mineAndDeploy(tokens, weights, providers);
        _fundAndApprove(hook, tokens);
    }

    function _deployN4()
        internal
        returns (address hook, MintableDec t0, MintableDec t1, MintableDec t2, MintableDec t3)
    {
        MintableDec a = new MintableDec("A", "A", 6);
        MintableDec b = new MintableDec("B", "B", 8);
        MintableDec c = new MintableDec("C", "C", 18);
        MintableDec d = new MintableDec("D", "D", 18);
        (t0, t1, t2, t3) = _sortFour(a, b, c, d);
        address[] memory tokens = new address[](4);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        tokens[2] = address(t2);
        tokens[3] = address(t3);
        uint256[] memory weights = new uint256[](4);
        weights[0] = 4e17;
        weights[1] = 3e17;
        weights[2] = 2e17;
        weights[3] = 1e17;
        address[] memory providers = new address[](4);
        (hook,) = _mineAndDeploy(tokens, weights, providers);
        _fundAndApprove(hook, tokens);
    }

    function _fundAndApprove(address hook, address[] memory tokens) internal {
        for (uint256 i; i < tokens.length; ++i) {
            MintableDec(tokens[i]).mint(user, 1_000_000_000 * (10 ** MintableDec(tokens[i]).decimals()));
            vm.prank(user);
            MintableDec(tokens[i]).approve(hook, type(uint256).max);
        }
    }

    function _raw(MintableDec t, uint256 human) internal view returns (uint256) {
        return human * (10 ** uint256(t.decimals()));
    }

    function _joinFullN2(address hook, MintableDec t0, MintableDec t1, uint256 human)
        internal
        returns (uint256 shares)
    {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _raw(t0, human);
        amounts[1] = _raw(t1, human);
        vm.prank(user);
        (shares,) = IUniswapV4WeightedSwapHook(hook).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
    }

    function _joinFullN3(
        address hook,
        MintableDec t0,
        MintableDec t1,
        MintableDec t2,
        uint256 human
    ) internal returns (uint256 shares) {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = _raw(t0, human);
        amounts[1] = _raw(t1, human);
        amounts[2] = _raw(t2, human);
        vm.prank(user);
        (shares,) = IUniswapV4WeightedSwapHook(hook).joinProportional(
            amounts, user, 0, block.timestamp + 1 hours, ""
        );
    }

    function _pairPoolKeys(address hook) internal view returns (PoolKey[] memory) {
        return PairPoolLib.computePairKeys(
            IUniswapV4WeightedSwapHook(hook).tokens(), hook, int24(int256(Math.TICK_SPACING))
        );
    }

    function _poolKeyFor(address a, address b, address hook) internal pure returns (PoolKey memory key) {
        (address c0, address c1) = a < b ? (a, b) : (b, a);
        key = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: int24(int256(Math.TICK_SPACING)),
            hooks: IHooks(hook)
        });
    }

    function _registry() internal view returns (IVaultRegistryVaultQuery) {
        return IVaultRegistryVaultQuery(address(indexedexManager));
    }

    function _requiredFlags() internal pure returns (uint160) {
        return PkgFactory.requiredFlags();
    }

    function _assertPoolLive(PoolKey memory key) internal view {
        assertTrue(PairPoolLib.isPoolLive(pm, key), "pair door not initialized on PoolManager");
        assertEq(key.fee, LPFeeLibrary.DYNAMIC_FEE_FLAG, "DYNAMIC_FEE");
    }

    function _sortThree(MintableDec a, MintableDec b, MintableDec c)
        internal
        pure
        returns (MintableDec, MintableDec, MintableDec)
    {
        address[3] memory addrs = [address(a), address(b), address(c)];
        MintableDec[3] memory toks = [a, b, c];
        for (uint256 i; i < 3; ++i) {
            for (uint256 j; j + 1 < 3; ++j) {
                if (addrs[j] > addrs[j + 1]) {
                    (addrs[j], addrs[j + 1]) = (addrs[j + 1], addrs[j]);
                    (toks[j], toks[j + 1]) = (toks[j + 1], toks[j]);
                }
            }
        }
        return (toks[0], toks[1], toks[2]);
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
}

/// @dev Non-SUT mintable ERC-20 with configurable decimals.
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

    function transferFrom(address from, address to, uint256 amount) external virtual returns (bool) {
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

/// @dev Reentrancy hostile ERC-20 for adversarial suite only.
contract ReentrancyERC20 is MintableDec {
    address public target;
    bytes public payload;
    bool public armed;

    constructor() MintableDec("Reentrancy", "REENT", 18) {}

    function arm(address target_, bytes calldata payload_) external {
        target = target_;
        payload = payload_;
        armed = true;
    }

    function transferFrom(address from, address to, uint256 amount)
        external
        override
        returns (bool)
    {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        if (armed && target != address(0)) {
            armed = false;
            (bool ok,) = target.call(payload);
            ok;
        }
        return true;
    }
}
