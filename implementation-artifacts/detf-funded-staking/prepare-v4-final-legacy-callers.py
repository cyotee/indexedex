from pathlib import Path
import re,json,hashlib,sys
R=Path.cwd();A=R/'implementation-artifacts/detf-funded-staking';D=R/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4';files={}
p=D/'bondNft/UniswapV4DetfBondNFTVaultDFPkg_Deploy.t.sol'
files[p]='''// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice Registered funded NFT package checked through its actual parent DETF.
contract UniswapV4DetfBondNFTVaultDFPkg_Deploy_Test is TestBase_UniswapV4Detf {
    function test_deployedFundedChildHasActualReserveAndParentBinding() public view {
        assertTrue(IVaultRegistryVaultPackageQuery(address(indexedexManager)).isPackage(address(bondNftVaultPkg)));
        IDetfBondNFT nft_ = IDetfBondNFT(detfInfo.bondNftVault());
        assertGt(address(nft_).code.length, 0);
        assertEq(nft_.detf(), detf);
        assertEq(address(nft_.lpToken()), reserveHook);
        IStandardVault.VaultConfig memory cfg_ = IStandardVault(address(nft_)).vaultConfig();
        assertEq(cfg_.tokens.length, 1);
        assertEq(cfg_.tokens[0], reserveHook);
        assertTrue(nft_.reservedBondNftsWired());
        for (uint256 i_; i_ < 3; ++i_) assertEq(nft_.positionOf(i_).principal, 0, "standing roles are not purchased principal");
    }

    function test_firstBondActivatesCustodyAndFundsActualStakingEscrow() public {
        IDetfBondNFT nft_ = IDetfBondNFT(detfInfo.bondNftVault());
        assertFalse(detfInfo.isReserveLive());
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, uint256(3)));
        nft_.ownerOf(3);
        (uint256 id_,) = _firstBond(80 ether);
        assertEq(id_, 3);
        assertTrue(detfInfo.isReserveLive());
        assertEq(nft_.ownerOf(id_), detfUser);
        assertGt(nft_.positionOf(id_).principal, 0);
        assertGt(IERC20(reserveHook).balanceOf(address(nft_)), 0, "actual protocol LP");
        IStakedDETF staking_ = IStakedDETF(detfInfo.rebasingClaimToken());
        assertGe(staking_.balanceOf(address(nft_)), nft_.positionOf(id_).principal, "purchased principal funded immediately");
        assertGe(IERC20(detf).balanceOf(address(staking_)), staking_.totalSupply());
    }
}
'''
p=D/'detf/UniswapV4Detf_Dust.t.sol';s=p.read_text();s=s.replace('import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";','import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";\nimport {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";')
s=s.replace('''        IDETFNFTVault nft = IDETFNFTVault(detfInfo.bondNftVault());
        uint256 origBefore = nft.originalSharesOf(tokenId);
        uint256 assetsBefore = nft.convertToAssets(origBefore);''','''        IDetfBondNFT nft = IDetfBondNFT(detfInfo.bondNftVault());
        bytes32 positionBefore = keccak256(abi.encode(nft.positionOf(tokenId)));
        IStakedDETF staking = IStakedDETF(detfInfo.rebasingClaimToken());
        bytes32 fundingBefore = keccak256(abi.encode(staking.stakingState(), IERC20(detf).totalSupply(), IERC20(detf).balanceOf(address(staking))));''')
s=s.replace('''        uint256 o = nft.totalOriginalShares();
        assertGt(o, 0, "O>0");''','')
s=s.replace('''        assertEq(nft.originalSharesOf(tokenId), origBefore, "no originalShares mint");
        uint256 assetsAfter = nft.convertToAssets(origBefore);
        assertGt(assetsAfter, assetsBefore, "convertToAssets rises");''','''        assertEq(keccak256(abi.encode(nft.positionOf(tokenId))), positionBefore, "sweep preserves fixed principal and attributed staking");
        assertEq(keccak256(abi.encode(staking.stakingState(), IERC20(detf).totalSupply(), IERC20(detf).balanceOf(address(staking)))), fundingBefore, "reserve dust creates no staking funding");''');files[p]=s
p=D/'detf/UniswapV4Detf_Donate.t.sol';s=p.read_text();s=s.replace('import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";','import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";\nimport {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";')
s=s.replace('/// @notice T7.13 R12a: live donate when O>0 does not mint originalShares; convertToAssets rises.','/// @notice T7.13: actual capital donation increases protocol LP without changing funded bond ownership.')
s=s.replace('''        IDETFNFTVault nft = IDETFNFTVault(detfInfo.bondNftVault());
        uint256 origBefore = nft.originalSharesOf(tokenId);
        uint256 assetsBefore = nft.convertToAssets(origBefore);
        uint256 o = nft.totalOriginalShares();
        assertGt(o, 0, "O>0");''','''        IDetfBondNFT nft = IDetfBondNFT(detfInfo.bondNftVault());
        bytes32 positionBefore = keccak256(abi.encode(nft.positionOf(tokenId)));
        uint256 ownedBefore = IERC20(reserveHook).balanceOf(address(nft));
        IStakedDETF staking = IStakedDETF(detfInfo.rebasingClaimToken());
        bytes32 fundingBefore = keccak256(abi.encode(staking.stakingState(), IERC20(detf).totalSupply(), IERC20(detf).balanceOf(address(staking))));''')
s=s.replace('''        assertEq(nft.originalSharesOf(tokenId), origBefore, "no originalShares mint");
        assertEq(nft.totalOriginalShares(), o, "O unchanged");
        uint256 assetsAfter = nft.convertToAssets(origBefore);
        assertGt(assetsAfter, assetsBefore, "convertToAssets rises");''','''        assertEq(keccak256(abi.encode(nft.positionOf(tokenId))), positionBefore, "gift preserves purchased principal and attributed staking");
        assertGe(IERC20(reserveHook).balanceOf(address(nft)), ownedBefore + lpOut, "actual protocol custody receives donated LP");
        assertEq(keccak256(abi.encode(staking.stakingState(), IERC20(detf).totalSupply(), IERC20(detf).balanceOf(address(staking)))), fundingBefore, "reserve gift creates no staking funding");''');files[p]=s
p=D/'detf/UniswapV4Detf_Quad_Adversarial_Reentrancy.t.sol';s=p.read_text();s=s.replace('uint256 out_ = hostileInfo.mint(','uint256 out_ = IStandardExchangeIn(address(hostileInfo)).exchangeIn(');s=s.replace('''            50 ether,
            0,''','''            50 ether,
            IERC20(address(hostileInfo)),
            0,''')
if 'import {IStandardExchangeIn}' not in s:s=s.replace('pragma solidity ^0.8.0;','pragma solidity ^0.8.0;\nimport {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";')
files[p]=s
records=[]
for p,s in files.items():
 b=p.read_text();assert s!=b,p;records.append({'path':str(p.relative_to(R)),'before':hashlib.sha256(b.encode()).hexdigest(),'after':hashlib.sha256(s.encode()).hexdigest()})
 if '--apply' in sys.argv:p.write_text(s)
 else:(A/('pending-current-callers-'+p.name+'.txt')).write_text(s)
(A/('v4-current-caller-migration.json' if '--apply' in sys.argv else 'pending-v4-current-caller-migration.json')).write_text(json.dumps({'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','files':records,'mapping':'Legacy fake-DETF/fake-LP child package tests consolidated into two actual-parent deployment/activation cases; legitimate whole external LP donation mapped to all four reserve bindings and both policies. T7.13/T7.20 now assert immutable purchased principal, actual protocol LP and unchanged funded staking. Quad hostile-token callback retains exact IsLocked check through standard purchase.'},indent=2)+'\n')
print(len(files),'files prepared' if '--apply' not in sys.argv else 'files applied')
