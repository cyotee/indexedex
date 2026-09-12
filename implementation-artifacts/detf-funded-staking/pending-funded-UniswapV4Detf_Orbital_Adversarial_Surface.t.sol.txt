// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Orbital_Adversarial} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_Adversarial.sol";
import {V4FundedSurfaceBehavior} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/adversarial/Adversarial_Surface.t.sol";

contract UniswapV4Detf_Orbital_Adversarial_Surface is TestBase_UniswapV4Detf_Orbital_Adversarial, V4FundedSurfaceBehavior {
    function _surfaceSubject() internal view override returns (IUniswapV4Detf) { return detfInfo; }
    function _surfaceFacets() internal view override returns (IFacet[5] memory) { return detfProductFacets; }
    function _surfaceSeed() internal override { _goLive(500 ether); }
    function _surfaceMint() internal override returns (uint256) { return _mintPairTo(detf, detfUser, 25 ether); }
    function _surfaceBuyer() internal view override returns (address) { return detfUser; }
    function _surfaceAttacker() internal view override returns (address) { return attacker; }
    function _surfacePayment() internal view override returns (IERC20) { return IERC20(address(pairToken)); }
}
