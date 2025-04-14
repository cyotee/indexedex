// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {IERC20MintBurnProxy} from "@crane/contracts/interfaces/proxies/IERC20MintBurnProxy.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";

contract StandardExchangeSingleVaultSeigniorageDETFCommon {
    struct ReservePoolData {
        IVault balV3Vault;
        IWeightedPool reservePool;
        uint256 reservePoolSwapFee;
        uint256 reserveVaultIndexInReservePool;
        uint256 reserveVaultRatedBalance;
        uint256 reserveVaultReservePoolWeight;
        uint256 selfIndexInReservePool;
        uint256 selfReservePoolRatedBalance;
        uint256 selfReservePoolWeight;
        uint256 resPoolTotalSupply;
        uint256 expectedBpt;
        uint256[] weightsArray;
        uint256 reserveVaultRate;
    }

    struct RBTData {
        IStandardExchangeProxy reserveVault;
        uint256 selfTotalSupply;
        // uint256 rbtSwapFee;
        uint256 selfDilutedPrice;
    }

    struct SRBTData {
        IERC20MintBurnProxy seigniorageToken;
        uint256 srbtTotalSupply;
        uint256 sRbtReserveVaultDebt;
    }

    // 7 words of memory, 21 gas if allocated first.
    struct SRBTAmounts {
        uint256 effectiveMintPriceFull;
        uint256 premiumPerRBT;
        uint256 grossSeigniorage;
        uint256 discountRBT;
        uint256 discountMargin;
        uint256 profitMargin;
        uint256 sRBTToMint;
    }

    struct VaultState {
        uint256 vaultLpReserve;
        uint256 vaultTotalShares;
        uint8 decimalOffset;
    }

    modifier onOrBeforeDeadline(uint256 deadline) {
        if (block.timestamp > deadline) {
            revert IStandardExchangeErrors.DeadlineExceeded(deadline, block.timestamp);
        }
        _;
    }

    function _secureSelfBurn(address owner, uint256 burnAmount, bool preTransferred)
        internal
        returns (uint256 actualOut)
    {
        if (preTransferred) {
            ERC20Repo._burn(address(this), burnAmount);
        } else {
            ERC20Repo._burn(owner, burnAmount);
        }
        return burnAmount;
    }
}
