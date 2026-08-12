// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4BalancerQuadStableSwapHook,
    MintableDec
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/TestBase_UniswapV4BalancerQuadStableSwapHook.sol";
import {
    IUniswapV4BalancerQuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/interfaces/IUniswapV4BalancerQuadStableSwapHook.sol";

/**
 * @title UniswapV4BalancerQuadStableSwapHook_Reentrancy_Test
 * @notice Hostile ERC-20 bound leg reenters add/remove/zap → nested `Reentrancy()`.
 * @dev Nested selector is recorded on the hostile token (peer DETF/V3 pattern). Outer
 *      SafeERC20 may wrap the bubbled error; law is nested Reentrancy() + outer fails.
 */
contract UniswapV4BalancerQuadStableSwapHook_Reentrancy_Test is TestBase_UniswapV4BalancerQuadStableSwapHook {
    bytes4 internal constant REENTRANCY_SEL = bytes4(keccak256("Reentrancy()"));

    function test_A1_reentrancy_addLiquidity() public {
        HostilePullToken hostile = new HostilePullToken("H", "H", 18);
        (address h, IUniswapV4BalancerQuadStableSwapHook q) = _deployWithHostilePull(hostile, "add");

        uint256[4] memory amounts = [uint256(1000 ether), 1000 ether, 1000 ether, 1000 ether];
        uint256[4] memory mins;
        hostile.arm(
            h,
            abi.encodeWithSelector(
                IUniswapV4BalancerQuadStableSwapHook.addLiquidity.selector, amounts, mins, user, uint256(0)
            )
        );

        // Nested reenter hits Reentrancy(); hostile bubbles it; SafeERC20 reverts with same
        // returndata. Token SSTOREs (reentryAttempts) roll back with the outer call — assert
        // the bubbled Reentrancy() selector on the user-facing call (trace proves nested path).
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("Reentrancy()"));
        q.addLiquidity(amounts, mins, user, 0);
    }

    function test_A1_reentrancy_zapIn() public {
        HostilePullToken hostile = new HostilePullToken("H", "H", 18);
        (address h, IUniswapV4BalancerQuadStableSwapHook q) = _deployWithHostilePull(hostile, "zap");

        uint256[4] memory first = [uint256(5000 ether), 5000 ether, 5000 ether, 5000 ether];
        uint256[4] memory mins;
        vm.prank(user);
        q.addLiquidity(first, mins, user, 0);

        address[4] memory toks = q.tokens();
        uint256 hi;
        for (uint256 i; i < 4; ++i) {
            if (toks[i] == address(hostile)) hi = i;
        }
        uint256[4] memory zapAmts;
        zapAmts[hi] = 100 ether;
        zapAmts[hi == 0 ? 1 : 0] = 10 ether;

        hostile.arm(
            h, abi.encodeWithSelector(IUniswapV4BalancerQuadStableSwapHook.zapIn.selector, zapAmts, user, uint256(0))
        );

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("Reentrancy()"));
        q.zapIn(zapAmts, user, 0);
    }

    function test_A1_reentrancy_removeLiquidity() public {
        HostilePushToken hostile = new HostilePushToken("H", "H", 18);
        (address h, IUniswapV4BalancerQuadStableSwapHook q) = _deployWithHostilePush(hostile, "rm");

        uint256[4] memory first = [uint256(2000 ether), 2000 ether, 2000 ether, 2000 ether];
        uint256[4] memory mins;
        vm.prank(user);
        (uint256 sh,) = q.addLiquidity(first, mins, user, 0);

        uint256[4] memory minOut;
        hostile.arm(
            h,
            abi.encodeWithSelector(
                IUniswapV4BalancerQuadStableSwapHook.removeLiquidity.selector, sh / 2, user, minOut
            )
        );

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("Reentrancy()"));
        q.removeLiquidity(sh / 2, user, minOut);
    }

    function _deployWithHostilePull(HostilePullToken hostile, string memory tag)
        internal
        returns (address h, IUniswapV4BalancerQuadStableSwapHook q)
    {
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        MintableDec c = new MintableDec("C", "C", 18);
        address[4] memory addrs = _sort4(address(a), address(b), address(c), address(hostile));
        h = _factoryDeploy(addrs, tag);
        q = IUniswapV4BalancerQuadStableSwapHook(h);
        _fundApprove(addrs, h, address(hostile), true);
    }

    function _deployWithHostilePush(HostilePushToken hostile, string memory tag)
        internal
        returns (address h, IUniswapV4BalancerQuadStableSwapHook q)
    {
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        MintableDec c = new MintableDec("C", "C", 18);
        address[4] memory addrs = _sort4(address(a), address(b), address(c), address(hostile));
        h = _factoryDeploy(addrs, tag);
        q = IUniswapV4BalancerQuadStableSwapHook(h);
        _fundApprove(addrs, h, address(hostile), false);
    }

    function _factoryDeploy(address[4] memory addrs, string memory tag) internal returns (address h) {
        tag; // binding salt is product args only (no saltNamespace)
        address[4] memory providers;
        h = _deployHook(
            _pkgArgs(addrs[0], addrs[1], addrs[2], addrs[3], DEMO_FEE, DEMO_AMP, providers)
        );
    }

    function _fundApprove(address[4] memory addrs, address h, address hostile, bool isPull)
        internal
    {
        isPull; // mint interface differs only by type — both expose mint
        for (uint256 i; i < 4; ++i) {
            (bool ok,) =
                addrs[i].call(abi.encodeWithSignature("mint(address,uint256)", user, uint256(10_000_000 ether)));
            require(ok);
        }
        vm.startPrank(user);
        for (uint256 i; i < 4; ++i) {
            IERC20(addrs[i]).approve(h, type(uint256).max);
        }
        vm.stopPrank();
        hostile; // silence
    }

    function _sort4(address a, address b, address c, address d)
        internal
        pure
        returns (address[4] memory addrs)
    {
        addrs = [a, b, c, d];
        for (uint256 i; i < 4; ++i) {
            for (uint256 j; j + 1 < 4; ++j) {
                if (addrs[j] > addrs[j + 1]) (addrs[j], addrs[j + 1]) = (addrs[j + 1], addrs[j]);
            }
        }
    }
}

contract HostilePullToken {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 public reentryAttempts;
    bytes4 public nestedErrorSelector;
    uint256 private _depth;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function arm(address target_, bytes memory reentryCall_) external {
        target = target_;
        reentryCall = reentryCall_;
        armed = true;
        reentryAttempts = 0;
        nestedErrorSelector = bytes4(0);
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
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (armed && _depth == 0) {
            _depth = 1;
            unchecked {
                ++reentryAttempts;
            }
            (bool ok, bytes memory ret) = target.call(reentryCall);
            if (!ok && ret.length >= 4) {
                bytes4 sel;
                assembly {
                    sel := mload(add(ret, 0x20))
                }
                nestedErrorSelector = sel;
            }
            _depth = 0;
            if (!ok) {
                assembly {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

contract HostilePushToken {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 public reentryAttempts;
    bytes4 public nestedErrorSelector;
    uint256 private _depth;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function arm(address target_, bytes memory reentryCall_) external {
        target = target_;
        reentryCall = reentryCall_;
        armed = true;
        reentryAttempts = 0;
        nestedErrorSelector = bytes4(0);
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
        if (armed && _depth == 0) {
            _depth = 1;
            unchecked {
                ++reentryAttempts;
            }
            (bool ok, bytes memory ret) = target.call(reentryCall);
            if (!ok && ret.length >= 4) {
                bytes4 sel;
                assembly {
                    sel := mload(add(ret, 0x20))
                }
                nestedErrorSelector = sel;
            }
            _depth = 0;
            if (!ok) {
                assembly {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
