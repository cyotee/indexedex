// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";
import {IUniswapV4DualStandardExchangeBufferConstantProductHookPackage as IPkg}
    from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol";
import {IUniswapV4DualStandardExchangeBufferConstantProductHook as IHook}
    from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService as DualFactory}
    from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {
    SeMatrix_RebasingAwareFixture
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_RebasingAwareFixture.sol";
import {
    UniswapV4DualSEBCPHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol";

/// @notice D20: dual × RebasingAwareERC4626 (COMPATIBLE). Face: an 18-decimal hermetic asset held in
///         custody by the production RebasingAwareERC4626 package (SE shares are 28-decimal: asset 18 +
///         offset 10); the custody SE rejects asset pretransfer, the hook uses the pull route (PRD §5).
contract UniswapV4DualSEBCPHook_SeMatrix_RebasingAwareERC4626 is UniswapV4DualSEBCPHook_SeMatrixBehavior {
    address internal sharedPkg;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_RebasingAwareFixture f = new SeMatrix_RebasingAwareFixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }
    /// @notice An identity leg's local book protects held shares even when its provider rate grows.
    function test_APEX008_identityLeg_ratedBackingIsNotPretransferCredit() public {
        RateProviderMock provider = new RateProviderMock();
        provider.mockRate(1.5e18);
        IPkg.PkgArgs memory args = IPkg.PkgArgs({
            poolManager: address(pm), feeOracle: address(indexedexManager),
            standardExchange0: seUT, token0: seUT,
            standardExchange1: seUT1, token1: seUT1,
            rateProvider0: address(provider), rateProvider1: address(provider)
        });
        uint256 mineNonce = DualFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = DualFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(hook, seUT, seUT1);
        dual = IHook(hook);

        vm.startPrank(user);
        IERC20(face).approve(seUT, 300 ether);
        IStandardExchangeIn(seUT).exchangeIn(IERC20(face), 300 ether, IERC20(seUT), 0, user, false, block.timestamp);
        IERC20(other).approve(seUT1, 300 ether);
        IStandardExchangeIn(seUT1).exchangeIn(IERC20(other), 300 ether, IERC20(seUT1), 0, user, false, block.timestamp);
        IERC20(seUT).approve(hook, type(uint256).max);
        IERC20(seUT1).approve(hook, type(uint256).max);
        dual.deposit(100e28, 100e28, user, 0, block.timestamp + 1 hours);
        vm.stopPrank();

        bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(seUT), 1e28, IERC20(seUT1), 0, address(rowCaller), true, block.timestamp + 1 hours));
        uint256 booked = IERC20(seUT).balanceOf(hook);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1e28, 0));
        rowCaller.execute(hook, data);
        assertEq(IERC20(seUT).balanceOf(hook), booked, "identity backing unchanged");
        assertEq(IERC20(seUT1).balanceOf(address(rowCaller)), 0, "unfunded caller receives nothing");

        vm.prank(user);
        IERC20(seUT).approve(address(rowCaller), 1e28);
        rowCaller.consumePretransfer(IERC20(seUT), user, hook, 1e28, data);
        assertGt(IERC20(seUT1).balanceOf(address(rowCaller)), 0, "funded identity credit succeeds");
        assertEq(IERC20(seUT).balanceOf(hook), booked + 1e28, "funded shares become backing");
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1e28, 0));
        rowCaller.execute(hook, data);
    }

}
