'use client'

import { createContext, useContext } from 'react'

import {
  CHAIN_ID_BASE_SEPOLIA,
  CHAIN_ID_SEPOLIA,
  type CanonicalArtifactChainId,
} from './addressArtifacts'

export const SELECTED_NETWORK_STORAGE_KEY = 'indexedex:selected-network'
export const DEFAULT_SELECTED_CHAIN_ID: CanonicalArtifactChainId = CHAIN_ID_SEPOLIA

export type NetworkSelectionContextValue = {
  selectedChainId: CanonicalArtifactChainId
  setSelectedChainId: (chainId: CanonicalArtifactChainId) => void
}

export const NetworkSelectionContext = createContext<NetworkSelectionContextValue>({
  selectedChainId: DEFAULT_SELECTED_CHAIN_ID,
  setSelectedChainId: () => {},
})

export function isCanonicalArtifactChainId(value: number): value is CanonicalArtifactChainId {
  return value === CHAIN_ID_SEPOLIA || value === CHAIN_ID_BASE_SEPOLIA
}

export function useSelectedNetwork(): NetworkSelectionContextValue {
  return useContext(NetworkSelectionContext)
}