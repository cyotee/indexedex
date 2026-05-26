// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IDETF
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Canonical DETF-side pricing interface for rebasing-aware valuation.
 */
interface IDETF {
    /**
     * @notice Returns the Bond NFT vault associated with this DETF.
     * @return bondNftVault_ The Bond NFT vault address.
     */
    function bondNftVault() external view returns (address bondNftVault_);

    /**
     * @notice Returns the protocol-owned Bond NFT token id used for rebasing reserve accounting.
     * @return protocolNFTId_ The protocol-owned NFT token id.
     */
    function protocolNFTId() external view returns (uint256 protocolNFTId_);

    /**
     * @notice Returns the rebasing DETF token associated with this DETF.
     * @return rebasingDetfToken_ The rebasing token address.
     */
    function rebasingDetfToken() external view returns (address rebasingDetfToken_);

    /**
     * @notice Returns the reserve pool backing this DETF.
     * @return reservePool_ The reserve pool address.
     */
    function reservePool() external view returns (address reservePool_);

    /**
     * @notice Returns the WETH value of a reserve-pool BPT amount for rebasing valuation.
     * @param reserveBptAmount Amount of reserve-pool BPT to value.
     * @return wethValue WETH-denominated value.
     */
    function previewRebasingDetfTokenEthValue(uint256 reserveBptAmount) external view returns (uint256 wethValue);

    /**
     * @notice Returns the protocol-owned reserve-pool BPT represented by a rebasing token amount.
     * @param rebasingDetfAmount Amount of rebasing DETF token.
     * @return reserveBptAmount Reserve-pool BPT represented by that rebasing amount.
     */
    function previewRebasingDetfTokenReserveBpt(uint256 rebasingDetfAmount)
        external
        view
        returns (uint256 reserveBptAmount);

    /**
     * @notice Returns the WETH value of a Stable Pool BPT amount.
     * @param stablePoolBptAmount Amount of Stable Pool BPT.
     * @return wethValue WETH-denominated value.
     */
    function previewStablePoolBptEthValue(uint256 stablePoolBptAmount) external view returns (uint256 wethValue);

    /**
     * @notice Returns the WETH value of a Common Pool BPT amount.
     * @param commonPoolBptAmount Amount of Common Pool BPT.
     * @return wethValue WETH-denominated value.
     */
    function previewCommonPoolBptEthValue(uint256 commonPoolBptAmount) external view returns (uint256 wethValue);

    /**
     * @notice Returns the synthetic DETF price in WETH terms.
     * @return wethPerDetf WETH value per DETF, scaled to 1e18.
     */
    function syntheticDetfEthPrice() external view returns (uint256 wethPerDetf);

    /**
     * @notice Decomposes reserve-pool BPT into the DETF, Stable Pool BPT, and Common Pool BPT legs.
     * @param reserveBptAmount Amount of reserve-pool BPT.
     * @return detfAmount Decomposed DETF amount.
     * @return stablePoolBptAmount Decomposed Stable Pool BPT amount.
     * @return commonPoolBptAmount Decomposed Common Pool BPT amount.
     */
    function previewReservePoolDecomposition(uint256 reserveBptAmount)
        external
        view
        returns (uint256 detfAmount, uint256 stablePoolBptAmount, uint256 commonPoolBptAmount);
}