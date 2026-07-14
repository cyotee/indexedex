'use client'

export const protocolDetfAbi = [
  { type: 'function', name: 'pairToken', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'address' }] },
  { type: 'function', name: 'rebasingClaimToken', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'address' }] },
  { type: 'function', name: 'rateAsset', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'address' }] },
  { type: 'function', name: 'underlyingVault', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'address' }] },
  { type: 'function', name: 'protocolNFTVault', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'address' }] },
  { type: 'function', name: 'reservePool', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'address' }] },
  { type: 'function', name: 'syntheticPrice', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'uint256' }] },
  { type: 'function', name: 'mintThreshold', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'uint256' }] },
  { type: 'function', name: 'burnThreshold', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'uint256' }] },
  { type: 'function', name: 'isMintingAllowed', stateMutability: 'view', inputs: [], outputs: [{ name: 'allowed', type: 'bool' }] },
  { type: 'function', name: 'isBurningAllowed', stateMutability: 'view', inputs: [], outputs: [{ name: 'allowed', type: 'bool' }] },
  {
    type: 'function',
    name: 'exchangeIn',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenIn', type: 'address' },
      { name: 'amountIn', type: 'uint256' },
      { name: 'tokenOut', type: 'address' },
      { name: 'minAmountOut', type: 'uint256' },
      { name: 'recipient', type: 'address' },
      { name: 'pretransferred', type: 'bool' },
      { name: 'deadline', type: 'uint256' },
    ],
    outputs: [{ name: 'amountOut', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'previewExchangeIn',
    stateMutability: 'view',
    inputs: [
      { name: 'tokenIn', type: 'address' },
      { name: 'amountIn', type: 'uint256' },
      { name: 'tokenOut', type: 'address' },
    ],
    outputs: [{ name: 'amountOut', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'bond',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenIn', type: 'address' },
      { name: 'amountIn', type: 'uint256' },
      { name: 'lockDuration', type: 'uint256' },
      { name: 'recipient', type: 'address' },
      { name: 'deadline', type: 'uint256' },
    ],
    outputs: [
      { name: 'tokenId', type: 'uint256' },
      { name: 'shares', type: 'uint256' },
    ],
  },
  {
    type: 'function',
    name: 'sellNFT',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'tokenId', type: 'uint256' },
      { name: 'recipient', type: 'address' },
    ],
    outputs: [{ name: 'rebasingClaimMinted', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'mintWithRateAsset',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'rateAssetAmount', type: 'uint256' },
      { name: 'recipient', type: 'address' },
      { name: 'pretransferred', type: 'bool' },
    ],
    outputs: [{ name: 'detfMinted', type: 'uint256' }],
  },
] as const

export default protocolDetfAbi
