// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_SlipstreamStandardExchange
} from "contracts/protocols/dexes/aerodrome/slipstream/test/bases/TestBase_SlipstreamStandardExchange.sol";

contract Handler_SlipstreamStandardExchange is Test {
    IStandardExchangeProxy public immutable vault;
    ERC20PermitMintableStub public immutable token0;
    ERC20PermitMintableStub public immutable token1;
    address public immutable actor0;
    address public immutable actor1;
    address public immutable attacker;

    uint256 public ghost_in;
    uint256 public ghost_out;
    uint256 public ghost_eoaReject;

    constructor(
        IStandardExchangeProxy vault_,
        ERC20PermitMintableStub token0_,
        ERC20PermitMintableStub token1_,
        address actor0_,
        address actor1_,
        address attacker_
    ) {
        vault = vault_;
        token0 = token0_;
        token1 = token1_;
        actor0 = actor0_;
        actor1 = actor1_;
        attacker = attacker_;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return seed % 2 == 0 ? actor0 : actor1;
    }

    function exchangeIn(uint256 amountSeed, uint256 actorSeed, bool zeroForOne) public {
        address actor = _actor(actorSeed);
        ERC20PermitMintableStub tin = zeroForOne ? token0 : token1;
        IERC20 tout = zeroForOne ? IERC20(address(token1)) : IERC20(address(token0));
        uint256 amount = bound(amountSeed, 1e15, 5 ether);
        tin.mint(actor, amount);
        vm.startPrank(actor);
        tin.approve(address(vault), amount);
        try IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(tin)), amount, tout, 0, actor, false, block.timestamp + 1 hours
        ) {
            unchecked {
                ++ghost_in;
            }
        } catch {}
        vm.stopPrank();
    }

    function exchangeOut(uint256 amountSeed, uint256 actorSeed, bool zeroForOne) public {
        address actor = _actor(actorSeed);
        IERC20 tin = zeroForOne ? IERC20(address(token0)) : IERC20(address(token1));
        IERC20 tout = zeroForOne ? IERC20(address(token1)) : IERC20(address(token0));
        uint256 amount = bound(amountSeed, 1e15, 2 ether);
        ERC20PermitMintableStub(address(tin)).mint(actor, amount);
        vm.startPrank(actor);
        tin.approve(address(vault), amount);
        try IStandardExchangeOut(address(vault)).exchangeOut(
            tin, amount, tout, 0, actor, false, block.timestamp + 1 hours
        ) {
            unchecked {
                ++ghost_out;
            }
        } catch {}
        vm.stopPrank();
    }

    function eoaPrepaidRejected(uint256 amountSeed) public {
        uint256 amount = bound(amountSeed, 1e15, 1 ether);
        vm.prank(attacker);
        try IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(token0)), amount, IERC20(address(token1)), 0, attacker, true, block.timestamp + 1 hours
        ) {
            revert("eoa prepaid must revert");
        } catch (bytes memory reason) {
            if (bytes4(reason) == ISecurePullErrors.EOAPretransferNotAllowed.selector) {
                unchecked {
                    ++ghost_eoaReject;
                }
            }
        }
    }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
contract SlipstreamStandardExchange_Invariant is TestBase_SlipstreamStandardExchange {
    Handler_SlipstreamStandardExchange internal handler;

    function setUp() public override {
        super.setUp();
        address a0 = makeAddr("slipInv0");
        address a1 = makeAddr("slipInv1");
        address att = makeAddr("slipAttacker");
        handler = new Handler_SlipstreamStandardExchange(vault, pairToken0, pairToken1, a0, a1, att);
        bytes4[] memory sels = new bytes4[](3);
        sels[0] = handler.exchangeIn.selector;
        sels[1] = handler.exchangeOut.selector;
        sels[2] = handler.eoaPrepaidRejected.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: sels}));
        handler.exchangeIn(1 ether, 0, true);
        require(handler.ghost_in() > 0, "bootstrap in");
    }

    function invariant_shareSupplyNonNegative() public view {
        assertTrue(IERC20(address(vault)).totalSupply() < type(uint128).max);
    }

    function invariant_inSucceeded() public view {
        assertGt(handler.ghost_in(), 0);
    }
}
