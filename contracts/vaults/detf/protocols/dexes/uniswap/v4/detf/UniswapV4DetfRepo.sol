// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";

/// @title UniswapV4DetfRepo
/// @notice Diamond storage for unified Uni V4 DETF. Role names only.
library UniswapV4DetfRepo {
    using AddressSetRepo for AddressSet;

    error AlreadyInitialized();
    error ReserveNotLive();
    error AlreadyLive();
    error InvalidRoute(address tokenIn, address tokenOut);
    error ZeroAmount();
    error DeadlineExpired(uint256 deadline);
    error MintingNotAllowed(uint256 syntheticPrice, uint256 mintThreshold);
    error BurningNotAllowed(uint256 syntheticPrice, uint256 burnThreshold);
    error LockDurationTooShort(uint256 lockDuration, uint256 minLockDuration);
    error FirstBondBelowMinimumLiquidity();
    error ClaimTokenNotConfigured();
    error NotAuthorized(address caller);
    error ReserveNotWired();
    error ReserveBondNftAlreadyWired();
    error ReserveClaimAlreadyWired();
    error ZeroAddress();
    error BondNotMature(uint256 unlockTime);

    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("vault.detf.uniswap.v4.detf.repo")) - 1)
    ) & ~bytes32(uint256(0xff));

    struct Table {
        AddressSet tokens;
        mapping(address token => IStandardExchange vault) vaultOf;
    }

    struct Storage {
        bool isReserveLive;
        address hook;
        IVaultFeeOracleQuery feeOracle;
        IDETFNFTVault bondNftVault;
        IRebasingClaimToken rebasingClaimToken;
        uint256 detfNftId;
        uint256 feeRecipientNftId;
        uint256[] creationPairPerDetfWad;
        uint256[] openingPairPerDetfWad;
        mapping(address pair => uint256 wad) creationOfPair;
        mapping(address pair => uint256 wad) openingOfPair;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        uint256 expansionEpochLength;
        uint256 expansionClosureRatePerYearWad;
        uint256 expansionMaxCatchUpEpochs;
        uint256 lastExpansionTimestamp;
        uint256 userBondedLp;
        address bondNftVaultPkg;
        address rebasingClaimTokenPkg;
        address creator;
        string claimName;
        string claimSymbol;
        string bondName;
        string bondSymbol;
        AddressSet hookPairTokens;
        AddressSet hookStandardExchanges;
        IUniswapV4Detf.RouteTableMode mintRouteMode;
        IUniswapV4Detf.RouteTableMode burnRouteMode;
        IUniswapV4Detf.RouteTableMode bondRouteMode;
        IUniswapV4Detf.RouteTableMode closeRouteMode;
        IUniswapV4Detf.RouteTableMode donateRouteMode;
        Table mintTable;
        Table burnTable;
        Table bondTable;
        Table closeTable;
        Table donateTable;
    }

    struct CoreInit {
        address hook;
        IVaultFeeOracleQuery feeOracle;
        uint256[] creationPairPerDetfWad;
        uint256[] openingPairPerDetfWad;
        address bondNftVaultPkg;
        address rebasingClaimTokenPkg;
        address creator;
    }

    struct PolicyInit {
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        uint256 expansionEpochLength;
        uint256 expansionClosureRatePerYearWad;
        uint256 expansionMaxCatchUpEpochs;
    }

    function _layoutStruct() internal pure returns (Storage storage layoutStruct_) {
        bytes32 slot_ = STORAGE_SLOT;
        assembly {
            layoutStruct_.slot := slot_
        }
    }

    function _initializeCore(CoreInit memory p_) internal {
        Storage storage s = _layoutStruct();
        if (s.hook != address(0)) revert AlreadyInitialized();
        s.isReserveLive = false;
        s.hook = p_.hook;
        s.feeOracle = p_.feeOracle;
        s.creationPairPerDetfWad = p_.creationPairPerDetfWad;
        s.openingPairPerDetfWad = p_.openingPairPerDetfWad;
        s.lastExpansionTimestamp = 0;
        s.userBondedLp = 0;
        s.bondNftVaultPkg = p_.bondNftVaultPkg;
        s.rebasingClaimTokenPkg = p_.rebasingClaimTokenPkg;
        s.creator = p_.creator;
    }

    function _initializePolicy(PolicyInit memory p_) internal {
        Storage storage s = _layoutStruct();
        s.mintThreshold = p_.mintThreshold;
        s.burnThreshold = p_.burnThreshold;
        s.thresholdMode = p_.thresholdMode;
        s.expansionEpochLength = p_.expansionEpochLength;
        s.expansionClosureRatePerYearWad = p_.expansionClosureRatePerYearWad;
        s.expansionMaxCatchUpEpochs = p_.expansionMaxCatchUpEpochs;
    }

    function _setChildTokenMetadata(
        string memory claimName_,
        string memory claimSymbol_,
        string memory bondName_,
        string memory bondSymbol_
    ) internal {
        Storage storage s = _layoutStruct();
        s.claimName = claimName_;
        s.claimSymbol = claimSymbol_;
        s.bondName = bondName_;
        s.bondSymbol = bondSymbol_;
    }

    function _setPairRates(address pair_, uint256 creation_, uint256 opening_) internal {
        Storage storage s = _layoutStruct();
        s.creationOfPair[pair_] = creation_;
        s.openingOfPair[pair_] = opening_;
    }

    function _addHookPair(address pair_) internal {
        _layoutStruct().hookPairTokens._add(pair_);
    }

    function _addHookStandardExchange(address se_) internal {
        _layoutStruct().hookStandardExchanges._add(se_);
    }

    function _setRouteModes(
        IUniswapV4Detf.RouteTableMode mint_,
        IUniswapV4Detf.RouteTableMode burn_,
        IUniswapV4Detf.RouteTableMode bond_,
        IUniswapV4Detf.RouteTableMode close_,
        IUniswapV4Detf.RouteTableMode donate_
    ) internal {
        Storage storage s = _layoutStruct();
        s.mintRouteMode = mint_;
        s.burnRouteMode = burn_;
        s.bondRouteMode = bond_;
        s.closeRouteMode = close_;
        s.donateRouteMode = donate_;
    }

    function _addRoute(Table storage table_, address token_, IStandardExchange vault_) internal {
        if (table_.tokens._contains(token_)) return;
        table_.tokens._add(token_);
        table_.vaultOf[token_] = vault_;
    }

    function _setBondNft(IDETFNFTVault vault_, uint256 detfNftId_, uint256 feeRecipientNftId_) internal {
        Storage storage s = _layoutStruct();
        s.bondNftVault = vault_;
        s.detfNftId = detfNftId_;
        s.feeRecipientNftId = feeRecipientNftId_;
    }

    function _setClaim(IRebasingClaimToken claim_) internal {
        _layoutStruct().rebasingClaimToken = claim_;
    }

    function _setReserveLive() internal {
        Storage storage s = _layoutStruct();
        if (s.isReserveLive) revert AlreadyLive();
        s.isReserveLive = true;
        if (s.lastExpansionTimestamp == 0) {
            s.lastExpansionTimestamp = block.timestamp;
        }
    }

    function _addUserBondedLp(uint256 amount_) internal {
        _layoutStruct().userBondedLp += amount_;
    }

    function _subUserBondedLp(uint256 amount_) internal {
        Storage storage s = _layoutStruct();
        if (amount_ >= s.userBondedLp) {
            s.userBondedLp = 0;
        } else {
            s.userBondedLp -= amount_;
        }
    }

    function _routesOf(Table storage table_) internal view returns (IUniswapV4Detf.IoRoute[] memory rows_) {
        address[] storage toks_ = table_.tokens._values();
        rows_ = new IUniswapV4Detf.IoRoute[](toks_.length);
        for (uint256 i; i < toks_.length; ++i) {
            rows_[i] = IUniswapV4Detf.IoRoute({
                token: IERC20(toks_[i]),
                vault: table_.vaultOf[toks_[i]]
            });
        }
    }
}
