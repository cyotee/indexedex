// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {
    UniswapV4QuadStableSwapHookFactory
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHookFactory.sol";
import {
    IUniswapV4QuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/interfaces/IUniswapV4QuadStableSwapHook.sol";
import {
    UniswapV4QuadStableSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHookMath.sol";

/**
 * @title TestBase_UniswapV4QuadStableSwapHook
 * @notice Gold TestBase for hermetic quad StableSwap hook (CREATE3 + real PoolManager).
 * @dev Peer pattern-copy (LOCKED): `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol`
 *      Do not subclass dual production types — structure/helpers only.
 */
abstract contract TestBase_UniswapV4QuadStableSwapHook is IndexedexTest {
    MintableDec internal t0;
    MintableDec internal t1;
    MintableDec internal t2;
    MintableDec internal t3;

    IPoolManager internal pm;
    UniswapV4QuadStableSwapHookFactory internal factory;
    address internal hook;
    IUniswapV4QuadStableSwapHook internal quad;
    // Note: do not store PoolKey[6] in storage (legacy solc cannot copy array-of-structs).
    // Use `_poolKeys()` helper which returns memory from factory.

    address internal user = address(0xBEEF);
    address internal deployerEoa = address(0xCAFE);

    uint24 internal constant DEMO_FEE = 500;
    uint256 internal constant DEMO_AMP = 100;
    uint256 internal constant DUST = 1;

    function setUp() public virtual override {
        IndexedexTest.setUp();

        // four sorted tokens (addresses must be ascending after deploy)
        MintableDec a = new MintableDec("USD Coin", "USDC", 6);
        MintableDec b = new MintableDec("Tether", "USDT", 6);
        MintableDec c = new MintableDec("Dai Stablecoin", "DAI", 18);
        MintableDec d = new MintableDec("USDS", "USDS", 18);
        (t0, t1, t2, t3) = _sortFour(a, b, c, d);

        pm = IPoolManager(
            vm.deployCode(
                "lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:PoolManager",
                abi.encode(address(this))
            )
        );

        factory = new UniswapV4QuadStableSwapHookFactory(create3Factory, pm);
        // create3Factory is owned by address(this) via CraneTest/InitDevService — not Indexedex `owner`
        IOperable(address(create3Factory)).setOperator(address(factory), true);

        address[4] memory providers;
        (hook,) = factory.deploy(
            address(t0),
            address(t1),
            address(t2),
            address(t3),
            DEMO_FEE,
            DEMO_AMP,
            providers,
            ""
        );
        quad = IUniswapV4QuadStableSwapHook(hook);

        _fundUser();
        vm.startPrank(user);
        t0.approve(hook, type(uint256).max);
        t1.approve(hook, type(uint256).max);
        t2.approve(hook, type(uint256).max);
        t3.approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function _poolKeys() internal view returns (PoolKey[6] memory) {
        return factory.pairPoolKeys(hook);
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
        // ample balance for 6- and 18-dec legs
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

    function _sortFour(MintableDec a, MintableDec b, MintableDec c, MintableDec d)
        internal
        pure
        returns (MintableDec, MintableDec, MintableDec, MintableDec)
    {
        address[4] memory addrs = [address(a), address(b), address(c), address(d)];
        MintableDec[4] memory toks = [a, b, c, d];
        // simple bubble sort by address
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
