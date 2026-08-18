/** Customer tools like Mint Test Tokens only belong on test / local chains. */
const MAINNET_CHAIN_IDS = new Set([
  1, // Ethereum
  10, // Optimism
  56, // BNB
  137, // Polygon
  42161, // Arbitrum
  43114, // Avalanche
  8453, // Base
])

export function isTestnetChainId(chainId: number | undefined): boolean {
  if (typeof chainId !== 'number' || !Number.isFinite(chainId)) return true
  return !MAINNET_CHAIN_IDS.has(chainId)
}
