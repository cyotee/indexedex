// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {AaveCrossVersionLoopE2E_Test} from
    "test/foundry/spec/protocol/lending/aave/cross-version/AaveCrossVersionLoopE2E.t.sol";

interface IPermitLike {
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function allowance(address owner, address spender) external view returns (uint256);
}

/// r3 h3-aave-loop-eip712-uninit: AaveCrossVersionLoop vault (deployed through the real
/// IndexedexManager/VaultRegistry path) cuts ERC5267+ERC2612 but never initializes EIP712Repo.
contract AaveLoopEip712Uninit_Test is AaveCrossVersionLoopE2E_Test {
    bytes32 constant TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function _permitDigest(bytes32 ds, address o, address sp, uint256 val, uint256 nonce, uint256 dl)
        internal pure returns (bytes32)
    {
        return keccak256(abi.encodePacked("\x19\x01", ds, keccak256(abi.encode(PERMIT_TYPEHASH, o, sp, val, nonce, dl))));
    }

    address alice;
    uint256 pk;
    uint256 shares;
    bytes32 onchain;
    bytes32 std5267;
    bytes32 stdErc20Name;

    function _setupHolder() internal {
        _deployVaultThroughRegistry();
        _seedBorrowLiquidity();
        (alice, pk) = makeAddrAndKey("alice");
        uint256 deposit = 10e18;
        _mint(tokenA, alice, deposit);
        vm.startPrank(alice);
        tokenA.approve(vault, deposit);shares = IStandardExchangeIn(vault).exchangeIn(tokenA, deposit, IERC20(vault), 0, alice, false, block.timestamp);
        vm.stopPrank();
        assertGt(shares, 0);
        emit log_named_string("ERC20 name()", IERC20Metadata(vault).name());
    }

    function _domains() internal {
        (bytes1 fields, string memory n, string memory v, uint256 cid, address vc,,) = IERC5267(vault).eip712Domain();
        emit log_named_bytes("eip712Domain.fields", abi.encodePacked(fields));
        emit log_named_string("eip712Domain.name", n);
        emit log_named_string("eip712Domain.version", v);
        assertEq(bytes(n).length, 0, "name empty");
        assertEq(bytes(v).length, 0, "version empty");
        assertEq(vc, vault);
        onchain = IPermitLike(vault).DOMAIN_SEPARATOR();
        bytes32 zeroHashes = keccak256(abi.encode(TYPEHASH, bytes32(0), bytes32(0), cid, vc));
        std5267 = keccak256(abi.encode(TYPEHASH, keccak256(bytes(n)), keccak256(bytes(v)), cid, vc));
        stdErc20Name = keccak256(
            abi.encode(TYPEHASH, keccak256(bytes(IERC20Metadata(vault).name())), keccak256("1"), cid, vc)
        );
        emit log_named_bytes32("DOMAIN_SEPARATOR()", onchain);
        emit log_named_bytes32("built w/ bytes32(0) hashes", zeroHashes);
        emit log_named_bytes32("std signer from eip712Domain()", std5267);
        emit log_named_bytes32("std signer name()+'1'", stdErc20Name);
        assertEq(onchain, zeroHashes, "on-chain DS uses raw zero hashes");
        assertTrue(onchain != std5267, "std ERC-5267 signer domain mismatches");
        assertTrue(onchain != stdErc20Name, "std (name(),'1') signer domain mismatches");
    }

    function _tryPermit(bytes32 ds, bool expectOk) internal {
        IPermitLike p = IPermitLike(vault);
        address spender = address(0xBEEF);
        uint256 dl = block.timestamp + 1 hours;
        uint256 nonce = p.nonces(alice);
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(pk, _permitDigest(ds, alice, spender, shares, nonce, dl));
        if (!expectOk) {
            vm.expectRevert();
            p.permit(alice, spender, shares, dl, v1, r1, s1);
            assertEq(p.allowance(alice, spender), 0, "no allowance");
            assertEq(p.nonces(alice), nonce, "nonce unchanged");
        } else {
            p.permit(alice, spender, shares, dl, v1, r1, s1);
            assertEq(p.allowance(alice, spender), shares, "raw-DS permit works");
            assertEq(p.nonces(alice), nonce + 1);
        }
    }

    function test_r3_eip712_uninit_permit_dos() public {
        _setupHolder();
        _domains();
        // Standard signer using ERC-5267 discovery (keccak("") name/version) -> reverts.
        _tryPermit(std5267, false);
        // Standard signer using ERC20 name() + version "1" -> reverts.
        _tryPermit(stdErc20Name, false);
        // Control: signing over the raw on-chain DOMAIN_SEPARATOR() succeeds.
        _tryPermit(onchain, true);
    }
}
