// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm, VmSafe} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";

/// @notice Execution oracle for the Crane PostDeployAccountHookFacet window.
/// A diamond can only be hijacked through `postDeploy()` while the facet is mounted, i.e. inside a
/// DiamondPackageCallBackFactory.deploy(...) (or hook factory deploy) call frame. The hijack needs
/// some deployer-substitutable address to receive a non-static CALL in that frame, or some account
/// other than the factory/pkg to call `postDeploy()`.
/// For every top-level deploy window in a recorded state diff, this probe counts:
///  - foreignPostDeploy: CALLs with selector postDeploy() from an accessor that is not the factory or a pkg
///  - callsIntoSubst: non-reverted CALLs into an address that was STATIC-probed as token/vault/rate/hook
///    (decimals/name/symbol/getRate/previewExchange*/vaultTokens/vaultConfig/tokens/standardExchangeOf/
///    rateProvider/owner/ownerOnlyLiquidity). These are the slots a deployer can fill with attacker code.
///  - extEdges: distinct non-static CALL targets that were neither created in the window nor a pkg/factory
library WindowProbe {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes4 internal constant DEPLOY = bytes4(keccak256("deploy(address,bytes)"));
    bytes4 internal constant DEPLOY_MINE = bytes4(keccak256("deployWithMineNonce(address,bytes,uint256)"));
    bytes4 internal constant POSTDEPLOY_HOOK = bytes4(keccak256("postDeploy()"));
    bytes4 internal constant POSTDEPLOY_PKG = bytes4(keccak256("postDeploy(address)"));

    struct Res {
        uint256 windows;
        uint256 accesses;
        uint256 postDeployCalls;
        uint256 foreignPostDeploy; // non-reverted postDeploy() calls by a non-factory/pkg accessor
        uint256 foreignPostDeployAttempts; // incl. reverted
        uint256 hijackDelegatecalls; // non-reverted DELEGATECALL postDeploy(address) into non-factory/pkg code
        uint256 hijackDelegatecallsReverted;
        uint256 callsIntoSubst;
        uint256 substCount;
        uint256 extEdges;
    }

    function _sel(bytes memory d) private pure returns (bytes4 s) {
        if (d.length < 4) return bytes4(0);
        assembly {
            s := mload(add(d, 32))
        }
    }

    function _isProbe(bytes4 s) private pure returns (bool) {
        return s == bytes4(keccak256("decimals()")) || s == bytes4(keccak256("name()"))
            || s == bytes4(keccak256("symbol()")) || s == bytes4(keccak256("getRate()"))
            || s == bytes4(keccak256("previewExchangeIn(address,uint256,address)"))
            || s == bytes4(keccak256("previewExchangeOut(address,address,uint256)"))
            || s == bytes4(keccak256("vaultTokens()")) || s == bytes4(keccak256("vaultConfig()"))
            || s == bytes4(keccak256("tokens()")) || s == bytes4(keccak256("standardExchangeOf(address)"))
            || s == bytes4(keccak256("rateProvider(address)")) || s == bytes4(keccak256("owner()"))
            || s == bytes4(keccak256("ownerOnlyLiquidity()")) || s == bytes4(keccak256("getHookFlags()"));
    }

    function _has(address[] memory xs, uint256 n, address x) private pure returns (bool) {
        for (uint256 i; i < n; ++i) if (xs[i] == x) return true;
        return false;
    }

    function _isCallish(VmSafe.AccountAccessKind k) private pure returns (bool) {
        return k == VmSafe.AccountAccessKind.Call || k == VmSafe.AccountAccessKind.DelegateCall
            || k == VmSafe.AccountAccessKind.StaticCall || k == VmSafe.AccountAccessKind.CallCode
            || k == VmSafe.AccountAccessKind.Create;
    }

    function _isDeploy(Vm.AccountAccess memory x) private pure returns (bool) {
        if (x.kind != VmSafe.AccountAccessKind.Call || x.reverted) return false;
        bytes4 s = _sel(x.data);
        return s == DEPLOY || s == DEPLOY_MINE;
    }

    function _decodePkg(bytes memory d) private pure returns (address p) {
        assembly {
            p := mload(add(d, 36))
        }
    }

    struct Ctx {
        address factory;
        address[] pkgs;
        uint256 np;
        string tag;
        address[] created;
        uint256 nc;
        address[] subst;
        uint256 ns;
        address[] edgeAcc;
        bytes4[] edgeSel;
        uint256 ne;
    }

    function analyze(Vm.AccountAccess[] memory a, string memory tag) internal view returns (Res memory r) {
        uint256 n = a.length;
        Ctx memory c;
        c.tag = tag;
        c.pkgs = new address[](64);
        for (uint256 i; i < n; ++i) {
            if (_isDeploy(a[i])) {
                address p = _decodePkg(a[i].data);
                if (!_has(c.pkgs, c.np, p) && c.np < 64) c.pkgs[c.np++] = p;
                if (!_has(c.pkgs, c.np, a[i].account) && c.np < 64) c.pkgs[c.np++] = a[i].account; // factories
            }
        }
        uint256 i0;
        while (i0 < n) {
            if (!_isDeploy(a[i0])) {
                ++i0;
                continue;
            }
            uint256 end = _end(a, i0);
            r.windows++;
            r.accesses += end - i0;
            c.factory = a[i0].account;
            _window(a, i0, end, c, r);
            i0 = end;
        }
        console2.log(string.concat("[", tag, "] windows/accesses"), r.windows, r.accesses);
        console2.log(string.concat("[", tag, "] postDeploy() calls / foreign ok / foreign attempts"), r.postDeployCalls, r.foreignPostDeploy, r.foreignPostDeployAttempts);
        console2.log(string.concat("[", tag, "] HIJACK delegatecalls ok / reverted"), r.hijackDelegatecalls, r.hijackDelegatecallsReverted);
        console2.log(string.concat("[", tag, "] substitutable addrs / CALLs into them"), r.substCount, r.callsIntoSubst);
        console2.log(string.concat("[", tag, "] distinct external CALL edges"), r.extEdges);
    }

    function _end(Vm.AccountAccess[] memory a, uint256 i0) private pure returns (uint256 end) {
        uint64 d0 = a[i0].depth;
        end = i0 + 1;
        while (end < a.length && !(_isCallish(a[end].kind) && a[end].depth <= d0)) ++end;
    }

    function _window(Vm.AccountAccess[] memory a, uint256 s, uint256 e, Ctx memory c, Res memory r) private view {
        c.created = new address[](e - s);
        c.nc = 0;
        c.subst = new address[](e - s);
        c.ns = 0;
        c.edgeAcc = new address[](e - s);
        c.edgeSel = new bytes4[](e - s);
        c.ne = 0;
        for (uint256 j = s; j < e; ++j) {
            if (a[j].kind == VmSafe.AccountAccessKind.Create) c.created[c.nc++] = a[j].account;
        }
        for (uint256 j = s; j < e; ++j) {
            if (a[j].kind != VmSafe.AccountAccessKind.StaticCall) continue;
            address acc = a[j].account;
            if (!_isProbe(_sel(a[j].data))) continue;
            if (_has(c.created, c.nc, acc) || _has(c.pkgs, c.np, acc) || _has(c.subst, c.ns, acc)) continue;
            c.subst[c.ns++] = acc;
        }
        r.substCount += c.ns;
        for (uint256 j = s; j < e; ++j) {
            if (a[j].kind == VmSafe.AccountAccessKind.Call) _onCall(a[j], c, r);
            if (a[j].kind == VmSafe.AccountAccessKind.DelegateCall && _sel(a[j].data) == POSTDEPLOY_PKG
                && !_has(c.pkgs, c.np, a[j].account)) {
                if (a[j].reverted) r.hijackDelegatecallsReverted++;
                else r.hijackDelegatecalls++;
                console2.log(string.concat("[", c.tag, "] HIJACK delegatecall postDeploy(address) ctx,code,reverted"), a[j].accessor, a[j].account, a[j].reverted ? 1 : 0);
            }
        }
        r.extEdges += c.ne;
    }

    function _onCall(Vm.AccountAccess memory x, Ctx memory c, Res memory r) private view {
        bytes4 sl = _sel(x.data);
        address acc = x.account;
        if (sl == POSTDEPLOY_HOOK) {
            r.postDeployCalls++;
            if (x.accessor != c.factory && !_has(c.pkgs, c.np, x.accessor)) {
                r.foreignPostDeployAttempts++;
                if (!x.reverted) r.foreignPostDeploy++;
                console2.log(string.concat("[", c.tag, "] foreign postDeploy() caller,target,reverted"), x.accessor, acc, x.reverted ? 1 : 0);
            }
        }
        if (!x.reverted && _has(c.subst, c.ns, acc)) {
            r.callsIntoSubst++;
            console2.log(string.concat("[", c.tag, "] CALL into substitutable addr (from,to)"), x.accessor, acc);
            console2.logBytes4(sl);
        }
        if (!_has(c.created, c.nc, acc) && !_has(c.pkgs, c.np, acc)) {
            for (uint256 k; k < c.ne; ++k) if (c.edgeAcc[k] == acc && c.edgeSel[k] == sl) return;
            c.edgeAcc[c.ne] = acc;
            c.edgeSel[c.ne] = sl;
            c.ne++;
            console2.log(string.concat("[", c.tag, "] ext CALL edge to"), acc, VM.getLabel(acc));
            console2.logBytes4(sl);
        }
    }
}
