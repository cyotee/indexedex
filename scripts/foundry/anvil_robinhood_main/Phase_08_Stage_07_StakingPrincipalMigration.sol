// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";
import {
    TokenStakingMigrationAdapter as Adapter
} from "contracts/protocols/staking/token/TokenStakingMigrationAdapter.sol";
import {IDETFStandardizedYield} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";

/// @notice One bounded conversion of principal AND remaining rewards through TokenStaking.
/// @dev Internal script library: the transaction caller remains the existing staking owner.
library Phase_08_Stage_07_StakingPrincipalMigration {
    struct Snapshot {
        uint256 principal;
        uint256 remaining;
        uint256 rewardReserve;
        uint256 rewardRate;
        address claimVault;
        uint256 vaultShares;
        ITokenStaking.Phase phase;
    }

    struct Result {
        uint256 amountIn;
        uint256 claimOut;
        uint256 sharesOut;
        Snapshot beforeState;
        Snapshot afterState;
    }

    /// @notice Cap each weighted-reserve migration at one quarter of its current DTF book.
    /// @dev The hook permits at most 30% for swaps. A 25% cap leaves room for rounding
    ///      and applies whether the DETF chooses issuance or its price-gate swap fallback.
    function nextChunkAmount(ITokenStaking staking, address target, uint256 maximum)
        internal
        view
        returns (uint256 amount)
    {
        require(maximum > 0, "Migration: zero chunk limit");
        IUniswapV4StandardExchangeWeightedBufferHook hook =
            IUniswapV4StandardExchangeWeightedBufferHook(IUniswapV4Detf(target).hook());
        address[] memory tokens = hook.tokens();
        address asset = address(staking.stakingToken());
        uint256 reserveCap;
        for (uint256 i; i < tokens.length; ++i) {
            if (tokens[i] == asset) {
                reserveCap = hook.ratedBalance(i) / 4;
                break;
            }
        }
        require(reserveCap > 0, "Migration: no usable DTF reserve");
        amount = staking.reserveRemaining();
        if (amount > maximum) amount = maximum;
        if (amount > reserveCap) amount = reserveCap;
    }

    function snapshot(ITokenStaking staking) internal view returns (Snapshot memory state) {
        state.principal = staking.totalSupply();
        state.remaining = staking.reserveRemaining();
        require(
            state.remaining == staking.stakingToken().balanceOf(address(staking)), "Migration: reserve/balance mismatch"
        );
        state.rewardReserve = staking.rewardReserve();
        state.rewardRate = staking.rewardRate();
        state.claimVault = address(staking.claimVault());
        if (state.claimVault != address(0)) {
            state.vaultShares = IERC20(state.claimVault).balanceOf(address(staking));
        }
        state.phase = staking.phase();
    }

    function validateTarget(ITokenStaking staking, address target) internal view returns (address claim) {
        require(target.code.length > 0, "Migration: target has no code");
        require(IUniswapV4Detf(target).isReserveLive(), "Migration: bootstrap required");
        claim = IUniswapV4Detf(target).rebasingClaimToken();
        require(claim.code.length > 0, "Migration: sDETF has no code");
        require(IStakedDETF(claim).detf() == target, "Migration: sDETF backing mismatch");
        address current = address(staking.targetDetf());
        if (current != address(0) && current != target) {
            require(current.code.length > 0, "Migration: adapter has no code");
            Adapter adapter = Adapter(current);
            require(adapter.staking() == address(staking), "Migration: adapter staking mismatch");
            require(
                address(adapter.stakingToken()) == address(staking.stakingToken()), "Migration: adapter asset mismatch"
            );
            require(address(adapter.detfToken()) == target, "Migration: adapter DETF mismatch");
            require(adapter.fundedStakingToken() == claim, "Migration: adapter sDETF mismatch");
            claim = adapter.rebasingClaimToken();
            require(claim == IDETFStandardizedYield(target).stakingSY(), "Migration: adapter SY mismatch");
        }
        if (staking.phase() != ITokenStaking.Phase.Staking) {
            require(current != address(0), "Migration: missing target after cutover");
        }
        if (address(staking.claimVault()) != address(0)) {
            require(staking.claimVault().asset() == claim, "Migration: claim vault asset mismatch");
        }
    }

    function execute(
        ITokenStaking staking,
        address target,
        uint256 amount,
        uint256 maxChunkInput,
        uint256 minClaimOut,
        uint256 deadline
    ) internal returns (Result memory result) {
        address claim = validateTarget(staking, target);
        require(address(staking.targetDetf()) != address(0), "Migration: set target first");
        require(amount > 0 && amount <= maxChunkInput, "Migration: invalid chunk");
        require(minClaimOut > 0, "Migration: zero minimum");
        require(deadline > block.timestamp, "Migration: expired deadline");
        result.beforeState = snapshot(staking);
        require(result.beforeState.phase != ITokenStaking.Phase.Wrapped, "Migration: already wrapped");
        require(result.beforeState.principal > 0, "Migration: no principal weights");
        require(amount <= result.beforeState.remaining, "Migration: insufficient reserve");
        result.amountIn = amount;
        (result.claimOut, result.sharesOut) = staking.migrateToClaimVault(amount, minClaimOut, deadline);
        result.afterState = snapshot(staking);
        require(result.claimOut >= minClaimOut && result.sharesOut > 0, "Migration: zero/short output");
        require(result.afterState.principal == result.beforeState.principal, "Migration: principal changed");
        require(result.afterState.remaining == result.beforeState.remaining - amount, "Migration: input mismatch");
        require(result.afterState.rewardRate == 0, "Migration: rewards still streaming");
        require(result.afterState.claimVault != address(0), "Migration: missing claim vault");
        if (result.beforeState.claimVault != address(0)) {
            require(result.afterState.claimVault == result.beforeState.claimVault, "Migration: vault changed");
        }
        require(
            result.afterState.vaultShares == result.beforeState.vaultShares + result.sharesOut,
            "Migration: wrapper shares mismatch"
        );
        require(IERC4626(result.afterState.claimVault).asset() == claim, "Migration: wrong wrapped asset");
        require(IERC20(claim).balanceOf(address(staking)) == 0, "Migration: unwrapped claim asset");
        _verifyAllowances(staking, target, claim);
        require(
            IERC20(claim).allowance(address(staking), result.afterState.claimVault) == 0,
            "Migration: claim asset allowance"
        );
        ITokenStaking.Phase expected =
            result.afterState.remaining == 0 ? ITokenStaking.Phase.Wrapped : ITokenStaking.Phase.Migrating;
        require(result.afterState.phase == expected, "Migration: unexpected phase");
    }

    function _verifyAllowances(ITokenStaking staking, address target, address claim) private view {
        address endpoint = address(staking.targetDetf());
        require(staking.stakingToken().allowance(address(staking), endpoint) == 0, "Migration: DTF allowance");
        if (endpoint == target) {
            require(IERC20(target).allowance(address(staking), claim) == 0, "Migration: DETF allowance");
        } else {
            Adapter adapter = Adapter(endpoint);
            require(
                adapter.totalSupply() == 0 && adapter.balanceOf(address(staking)) == 0,
                "Migration: outstanding receipts"
            );
            require(adapter.allowance(address(staking), endpoint) == 0, "Migration: receipt allowance");
            require(staking.stakingToken().allowance(endpoint, target) == 0, "Migration: adapter DTF allowance");
            require(IERC20(target).allowance(endpoint, claim) == 0, "Migration: adapter DETF allowance");
        }
    }

    function verifyComplete(ITokenStaking staking, address target) internal view returns (Snapshot memory state) {
        validateTarget(staking, target);
        state = snapshot(staking);
        require(state.phase == ITokenStaking.Phase.Wrapped, "Migration: incomplete phase");
        require(state.remaining == 0, "Migration: unconverted DTF remains");
        require(state.claimVault != address(0), "Migration: missing claim vault");
        require(state.principal == 0 || state.vaultShares > 0, "Migration: unbacked principal weights");
    }
}
