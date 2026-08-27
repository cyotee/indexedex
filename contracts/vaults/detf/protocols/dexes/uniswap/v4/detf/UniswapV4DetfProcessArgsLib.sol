// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf, IUniswapV4DetfDFPkg} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfRepo as Repo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";

/// @title UniswapV4DetfProcessArgsLib
/// @notice Hook + I/O table validation for unified Uni V4 DETF (PRD §3.3 / §15.13 / §16.9).
library UniswapV4DetfProcessArgsLib {
    using AddressSetRepo for AddressSet;

    uint256 internal constant ONE_WAD = 1e18;

    function requireHookShape(address hook_) internal view {
        if (hook_ == address(0) || hook_.code.length == 0) revert IUniswapV4DetfDFPkg.InvalidHook();
        address[] memory tokens_ = IUniswapV4SeBufferHook(hook_).tokens();
        uint256 n_ = tokens_.length;
        if (n_ < 2 || n_ > 8) revert IUniswapV4DetfDFPkg.InvalidHook();
        uint256 selfLegs_;
        for (uint256 i; i < n_; ++i) {
            if (IUniswapV4SeBufferHook(hook_).standardExchangeOf(tokens_[i]) == address(0)) {
                unchecked {
                    ++selfLegs_;
                }
            }
        }
        // Dual: no DETF self-leg (all tokens have an SE). Bare pair: extra SE==0 legs.
        if (selfLegs_ != 1) revert IUniswapV4DetfDFPkg.BarePairForbidden();
    }

    function requireCustomClose(IUniswapV4Detf.PkgArgs memory args) internal view {
        if (args.closeRouteMode != IUniswapV4Detf.RouteTableMode.Custom) return;
        if (args.closeRoutes.length != 1) revert IUniswapV4DetfDFPkg.InvalidCloseRoutes();
        IUniswapV4Detf.IoRoute memory row_ = args.closeRoutes[0];
        address token_ = address(row_.token);
        address vault_ = address(row_.vault);
        if (token_ == address(0) || vault_ == address(0)) revert IUniswapV4DetfDFPkg.ZeroAddress();
        address se_ = IUniswapV4SeBufferHook(args.hook).standardExchangeOf(token_);
        if (se_ != vault_ || se_ == address(0)) revert IUniswapV4DetfDFPkg.InvalidCloseRoutes();
    }

    function requireDetfSelfLegAndOwner(address hook_, address detf_) internal view {
        address[] memory tokens_ = IUniswapV4SeBufferHook(hook_).tokens();
        uint256 hits_;
        for (uint256 i; i < tokens_.length; ++i) {
            if (tokens_[i] == detf_) {
                unchecked {
                    ++hits_;
                }
            }
        }
        if (hits_ != 1) revert IUniswapV4DetfDFPkg.DetfNotInHookTokens();
        try IMultiStepOwnable(hook_).owner() returns (address owner_) {
            if (owner_ != detf_) revert IUniswapV4DetfDFPkg.HookOwnerMismatch();
        } catch {
            revert IUniswapV4DetfDFPkg.HookOwnerMismatch();
        }
    }

    function requireCreationRates(IUniswapV4Detf.PkgArgs memory args, uint256 pairCount_) internal pure {
        if (args.creationPairPerDetfWad.length != pairCount_) {
            revert IUniswapV4DetfDFPkg.InvalidCreationRate();
        }
        for (uint256 i; i < pairCount_; ++i) {
            if (args.creationPairPerDetfWad[i] == 0) revert IUniswapV4DetfDFPkg.InvalidCreationRate();
        }
        if (
            args.openingPairPerDetfWad.length != 0
                && args.openingPairPerDetfWad.length != pairCount_
        ) {
            revert IUniswapV4DetfDFPkg.InvalidCreationRate();
        }
    }

    function resolveOpening(uint256[] memory creation_, uint256[] memory opening_)
        internal
        pure
        returns (uint256[] memory resolved_)
    {
        uint256 n_ = creation_.length;
        resolved_ = new uint256[](n_);
        bool empty_ = opening_.length == 0;
        for (uint256 i; i < n_; ++i) {
            uint256 o_ = empty_ ? 0 : opening_[i];
            resolved_[i] = o_ == 0 ? creation_[i] : o_;
        }
    }

    function pairIndexOf(address[] memory tokens_, address detf_, address pair_)
        internal
        pure
        returns (uint256 idx_)
    {
        uint256 p_ = 0;
        for (uint256 i; i < tokens_.length; ++i) {
            if (tokens_[i] == detf_) continue;
            if (tokens_[i] == pair_) return p_;
            unchecked {
                ++p_;
            }
        }
        revert IUniswapV4DetfDFPkg.InvalidHook();
    }

    function storeHookSetsAndRates(
        address hook_,
        address detf_,
        uint256[] memory creation_,
        uint256[] memory opening_
    ) internal {
        address[] memory tokens_ = IUniswapV4SeBufferHook(hook_).tokens();
        uint256 p_;
        for (uint256 i; i < tokens_.length; ++i) {
            address t_ = tokens_[i];
            if (t_ == detf_) continue;
            address se_ = IUniswapV4SeBufferHook(hook_).standardExchangeOf(t_);
            if (se_ == address(0)) revert IUniswapV4DetfDFPkg.BarePairForbidden();
            Repo._addHookPair(t_);
            Repo._addHookStandardExchange(se_);
            Repo._setPairRates(t_, creation_[p_], opening_[p_]);
            unchecked {
                ++p_;
            }
        }
    }

    function storeDefaultInbound(address hook_, address detf_, Repo.Table storage table_) internal {
        address[] memory tokens_ = IUniswapV4SeBufferHook(hook_).tokens();
        for (uint256 i; i < tokens_.length; ++i) {
            address t_ = tokens_[i];
            if (t_ == detf_) continue;
            address se_ = IUniswapV4SeBufferHook(hook_).standardExchangeOf(t_);
            Repo._addRoute(table_, t_, IStandardExchange(se_));
            if (se_ != t_) {
                Repo._addRoute(table_, se_, IStandardExchange(se_));
            }
        }
    }

    function storeDefaultClose(address hook_, address detf_, Repo.Table storage table_) internal {
        address[] memory tokens_ = IUniswapV4SeBufferHook(hook_).tokens();
        for (uint256 i; i < tokens_.length; ++i) {
            address t_ = tokens_[i];
            if (t_ == detf_) continue;
            address se_ = IUniswapV4SeBufferHook(hook_).standardExchangeOf(t_);
            Repo._addRoute(table_, t_, IStandardExchange(se_));
        }
    }

    function storeCustomTable(
        address hook_,
        address detf_,
        IUniswapV4Detf.IoRoute[] memory rows_,
        Repo.Table storage table_,
        bool closeTable_,
        bool donateTable_
    ) internal {
        for (uint256 i; i < rows_.length; ++i) {
            address token_ = address(rows_[i].token);
            address vault_ = address(rows_[i].vault);
            _requireCustomRow(hook_, detf_, token_, vault_, closeTable_);
            if (table_.tokens._contains(token_)) revert IUniswapV4DetfDFPkg.DuplicateRoute(token_);
            Repo._addRoute(table_, token_, IStandardExchange(vault_));
        }
        if (donateTable_) {
            // subset vs mint∪bond is checked after both inbound tables are stored
        }
    }

    function requireDonateSubset() internal view {
        Repo.Storage storage s = Repo._layoutStruct();
        address[] storage toks_ = s.donateTable.tokens._values();
        for (uint256 i; i < toks_.length; ++i) {
            address t_ = toks_[i];
            IStandardExchange v_ = s.donateTable.vaultOf[t_];
            bool inMint_ = s.mintTable.tokens._contains(t_) && address(s.mintTable.vaultOf[t_]) == address(v_);
            bool inBond_ = s.bondTable.tokens._contains(t_) && address(s.bondTable.vaultOf[t_]) == address(v_);
            if (!inMint_ && !inBond_) revert IUniswapV4DetfDFPkg.InvalidRouteTable();
        }
    }

    function storeDonateUnion() internal {
        Repo.Storage storage s = Repo._layoutStruct();
        _copyTable(s.mintTable, s.donateTable);
        _copyTable(s.bondTable, s.donateTable);
    }

    function _copyTable(Repo.Table storage from_, Repo.Table storage to_) private {
        address[] storage toks_ = from_.tokens._values();
        for (uint256 i; i < toks_.length; ++i) {
            Repo._addRoute(to_, toks_[i], from_.vaultOf[toks_[i]]);
        }
    }

    function _requireCustomRow(
        address hook_,
        address detf_,
        address token_,
        address vault_,
        bool closeTable_
    ) private view {
        if (token_ == address(0) || vault_ == address(0)) revert IUniswapV4DetfDFPkg.ZeroAddress();
        if (token_ == detf_) revert IUniswapV4DetfDFPkg.InvalidRouteTable();
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.hookStandardExchanges._contains(vault_)) revert IUniswapV4DetfDFPkg.InvalidRouteTable();
        if (closeTable_) {
            if (!s.hookPairTokens._contains(token_)) revert IUniswapV4DetfDFPkg.InvalidCloseRoutes();
            if (IUniswapV4SeBufferHook(hook_).standardExchangeOf(token_) != vault_) {
                revert IUniswapV4DetfDFPkg.InvalidCloseRoutes();
            }
            return;
        }
        if (token_ == vault_) {
            _requireShareRoute(IStandardExchange(vault_));
            return;
        }
        if (!_vaultListsToken(vault_, token_)) revert IUniswapV4DetfDFPkg.InvalidRouteTable();
        _requireClosedForm(IStandardExchange(vault_), IERC20(token_));
    }

    function _vaultListsToken(address vault_, address token_) private view returns (bool) {
        address[] memory toks_ = IBasicVault(vault_).vaultTokens();
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == token_) return true;
        }
        return false;
    }

    function _requireShareRoute(IStandardExchange vault_) private view {
        try vault_.previewExchangeIn(IERC20(address(vault_)), ONE_WAD, IERC20(address(vault_))) returns (uint256) {
            return;
        } catch {
            // share identity is legal even if preview of share→share reverts
        }
    }

    function _requireClosedForm(IStandardExchange vault_, IERC20 token_) private view {
        IERC20 share_ = IERC20(address(vault_));
        try IStandardExchangeIn(address(vault_)).previewExchangeIn(token_, ONE_WAD, share_) returns (uint256 out_) {
            if (out_ == 0) revert IUniswapV4DetfDFPkg.InvalidRouteTable();
        } catch {
            revert IUniswapV4DetfDFPkg.InvalidRouteTable();
        }
    }
}
