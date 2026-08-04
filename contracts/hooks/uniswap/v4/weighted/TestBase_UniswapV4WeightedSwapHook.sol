// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {
    UniswapV4WeightedSwapHookFactory
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookFactory.sol";
import {
    UniswapV4WeightedSwapHook_FactoryService as FactoryService
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHook_FactoryService.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";

/**
 * @title TestBase_UniswapV4WeightedSwapHook
 * @notice Gold TestBase: factory-only deploy, real PM, real Vault Fee Oracle on manager.
 * @dev Production-first. No mocks of hook/factory/Math/Repo/oracle/PoolManager under test.
 */
abstract contract TestBase_UniswapV4WeightedSwapHook is IndexedexTest {
    IPoolManager internal pm;
    UniswapV4WeightedSwapHookFactory internal factory;
    IVaultFeeOracleQuery internal vaultFeeOracle;

    address internal user = address(0xBEEF);
    address internal feeRecipient;

    uint256 internal constant DEMO_DEX_FEE = 3e15; // 0.3%
    uint256 internal constant DEMO_USAGE_FEE = 5e16; // 5% of growth share algebra

    function setUp() public virtual override {
        IndexedexTest.setUp();

        pm = IPoolManager(
            vm.deployCode(
                "lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:PoolManager",
                abi.encode(address(this))
            )
        );

        vaultFeeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        feeRecipient = address(feeCollector);

        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(feeRecipient));
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultDexSwapFee(DEMO_DEX_FEE);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(DEMO_USAGE_FEE);
        vm.stopPrank();

        factory = new UniswapV4WeightedSwapHookFactory(create3Factory, pm, vaultFeeOracle);
        IOperable(address(create3Factory)).setOperator(address(factory), true);
    }

    /* ---------------------------------------------------------------------- */
    /*                              deploy helpers                            */
    /* ---------------------------------------------------------------------- */

    function _mineAndDeploy(
        address[] memory tokens,
        uint256[] memory weights,
        address[] memory providers
    ) internal returns (address hook, PoolKey[] memory keys) {
        FactoryService.DeployParams memory p;
        p.create3Factory = create3Factory;
        p.poolManager = pm;
        p.feeOracle = vaultFeeOracle;
        p.tokens = tokens;
        p.weights = weights;
        p.rateProviders = providers;
        p.saltNamespace = "";
        (uint256 mineNonce,) = FactoryService.mineNonceFor(p);
        (hook, keys) = factory.deployWithMineNonce(tokens, weights, providers, "", mineNonce);
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
