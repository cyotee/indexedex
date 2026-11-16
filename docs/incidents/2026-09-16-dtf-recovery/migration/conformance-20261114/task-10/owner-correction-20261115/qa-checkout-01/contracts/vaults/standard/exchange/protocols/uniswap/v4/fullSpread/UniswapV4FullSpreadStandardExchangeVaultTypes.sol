// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

library UniswapV4FullSpreadStandardExchangeVaultTypes {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant FEE_CAP = 3e17;
    uint256 internal constant MIN_SHARES = 1_000;
    uint8 internal constant MAX_ACTIONS = 3;

    enum Kind {
        Unsupported,
        PassThrough,
        OneSidedMint,
        BundleMint,
        OneTokenExit,
        BundleExit,
        Donate,
        Compound
    }

    enum ActionKind {
        None,
        Swap,
        Modify
    }

    struct Action {
        ActionKind kind;
        bool zeroForOne;
        uint256 amountIn;
        int256 liquidityDelta;
    }

    struct Plan {
        Kind kind;
        uint256 amountOut;
        uint256 amountRefunded;
        uint256 refund0;
        uint256 refund1;
        uint256 out0;
        uint256 out1;
        uint256 grossShares;
        uint256 netShares;
        uint256 feeShares;
        uint256 sharesBurned;
        uint256 feeClaim0;
        uint256 feeClaim1;
        uint256 feeRemainder0;
        uint256 feeRemainder1;
        uint256 bookedClaim0;
        uint256 bookedClaim1;
        uint128 liquidityAdded;
        bool mintFloor;
        bool emitDonation;
        bool emitCompounded;
        bool emitPairDeposited;
        bool emitPairRedeemed;
        bool failed;
        uint8 actionCount;
        Action[3] actions;
    }

    struct SwapQuote {
        uint256 spent;
        uint256 received;
        uint256 applied;
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 liquidity;
    }
}
