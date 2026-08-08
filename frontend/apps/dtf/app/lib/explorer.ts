export function explorerAddressUrl(chainId: number, address: string): string | null {
  if (!address) return null

  // Sepolia
  if (chainId === 11155111) {
    return `https://sepolia.etherscan.io/address/${address}`
  }

  // Anvil fork (no public explorer)
  if (chainId === 31337) {
    return null
  }

  return null
}
