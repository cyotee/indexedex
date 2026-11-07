// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
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
    function test_APEX008_bufferedLocal_ratedBackingIsNotPretransferCredit() public {
        RateProviderMock provider = new RateProviderMock();
        provider.mockRate(1.5e18);
        IPkg.PkgArgs memory args = IPkg.PkgArgs({
            poolManager: address(pm), feeOracle: address(indexedexManager),
            standardExchange0: seUT, token0: face,
            standardExchange1: seUT1, token1: other,
            rateProvider0: address(provider), rateProvider1: address(provider)
        });
        uint256 mineNonce = DualFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = DualFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(hook, face, other);
        dual = IHook(hook);
        faceIsC0 = dual.currency0() == face;
        _seed();
        provider.mockRate(3e18);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(seUT, true);
        bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(face), 1 ether, IERC20(other), 1, address(rowCaller), true, block.timestamp + 1 hours));
        uint256 booked = IERC20(face).balanceOf(hook);
        assertGt(booked, 0, "actual locally booked seed");
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1 ether, 0));
        rowCaller.execute(hook, data);
        assertEq(IERC20(face).balanceOf(hook), booked, "booked local backing is not credit");
        assertEq(IERC20(other).balanceOf(address(rowCaller)), 0);
        vm.prank(user);
        IERC20(face).approve(address(rowCaller), 1 ether);
        rowCaller.consumePretransfer(IERC20(face), user, hook, 1 ether, data);
        assertGt(IERC20(other).balanceOf(address(rowCaller)), 0, "funded local credit succeeds");
        assertEq(IERC20(face).balanceOf(hook), booked + 1 ether, "disabled input remains booked locally");
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1 ether, 0));
        rowCaller.execute(hook, data);
    }

}
