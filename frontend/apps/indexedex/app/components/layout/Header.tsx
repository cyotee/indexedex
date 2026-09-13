'use client';

import Link from 'next/link';
import { useState, useEffect, useRef } from 'react';
import Image from 'next/image';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount, useConfig, useSwitchChain } from 'wagmi';
import { useSelectedNetwork } from '@indexedex/protocol/networkSelection';
import type { CanonicalArtifactChainId } from '@indexedex/protocol/addressArtifacts';
import { useBrand } from '../../lib/brandContext';
import { isLocalRobinhoodTestnet, LOCAL_RPC_URL } from '../../lib/localRpc';
import { Button } from '../ui/Button';

export function Header() {
  const { brand } = useBrand();
  const { chainId: walletChainId, isConnected } = useAccount();
  const { chains } = useConfig();
  const { switchChainAsync, isPending: isSwitching } = useSwitchChain();
  const { selectedChainId, setSelectedChainId } = useSelectedNetwork();
  const [chainSwitchError, setChainSwitchError] = useState('');
  const [isTestnetDropdownOpen, setIsTestnetDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const close = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsTestnetDropdownOpen(false);
      }
    };
    document.addEventListener('mousedown', close);
    return () => document.removeEventListener('mousedown', close);
  }, []);

  // A supported network chosen in the wallet/RainbowKit also selects its app data.
  useEffect(() => {
    if (isConnected && chains.some((chain) => chain.id === walletChainId)) {
      setSelectedChainId(walletChainId as CanonicalArtifactChainId);
      setChainSwitchError('');
    }
  }, [walletChainId, isConnected, chains, setSelectedChainId]);

  async function selectNetwork(chainId: number) {
    setSelectedChainId(chainId as CanonicalArtifactChainId);
    setChainSwitchError('');
    if (!isConnected || walletChainId === chainId) return;
    try {
      await switchChainAsync({ chainId });
    } catch {
      setChainSwitchError('Network switch was not completed. Choose the app network in your wallet to continue.');
    }
  }

  const navLinkClass =
    'text-[var(--accent,#4FD44B)] hover:text-[var(--text-primary,#EDEDED)] px-3 py-2 text-sm font-medium transition-colors rounded-md'
  const moreItemClass =
    'block px-4 py-2 text-sm text-[var(--text-primary,#EDEDED)] hover:bg-[var(--surface-2,#1c2030)]'
  return (
    <header className="border-b border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)]">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="flex min-h-16 py-2 justify-between items-center flex-wrap gap-2">
          <div className="flex items-center flex-wrap min-w-0">
            <Link href="/" className="flex items-center flex-shrink-0 gap-2 brand-logo-link">
              <Image
                src={brand.logoSrc}
                alt={brand.logoAlt}
                width={120}
                height={32}
                priority
                className="brand-logo rounded-md object-contain"
              />
              <span className="hidden sm:inline text-sm font-semibold text-[var(--text-primary,#EDEDED)] tracking-tight">
                {brand.name}
              </span>
            </Link>
            <nav
              className="ml-2 sm:ml-4 lg:ml-10 flex flex-wrap gap-x-1 gap-y-1 items-center"
              aria-label="Primary"
            >
                <Link href="/explore" className={navLinkClass}>
                  Explore
                </Link>
                <Link href="/insights" className={navLinkClass}>
                  DETFs
                </Link>
                <Link href="/staking" className={navLinkClass}>
                  Staking
                </Link>
                <Link href="/create" className={navLinkClass}>
                  Create
                </Link>
                <Link href="/you" className={navLinkClass}>
                  You
                </Link>
                <Link href="/learn" className={navLinkClass}>
                  Learn
                </Link>
              <div className="relative" ref={dropdownRef}>
                <button
                  onClick={() => setIsTestnetDropdownOpen(!isTestnetDropdownOpen)}
                  className="text-[var(--text-muted,#9aa3b2)] hover:text-[var(--text-primary,#EDEDED)] px-3 py-2 text-sm font-medium transition-colors flex items-center"
                  aria-expanded={isTestnetDropdownOpen}
                  aria-haspopup="menu"
                >
                  More
                  <svg
                    className={`ml-1 w-4 h-4 transition-transform ${isTestnetDropdownOpen ? 'rotate-180' : ''}`}
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>

                {isTestnetDropdownOpen && (
                  <div className="absolute top-full left-0 mt-1 w-52 rounded-md shadow-lg z-50 border border-[var(--border-subtle,rgba(255,255,255,0.08))] bg-[var(--surface-1,#14171f)]">
                    <div className="py-1">
                      <Link href="/swap" className={moreItemClass} onClick={() => setIsTestnetDropdownOpen(false)}>Trade</Link>
                      <Link href="/earn" className={moreItemClass} onClick={() => setIsTestnetDropdownOpen(false)}>Vaults</Link>
                      <Link href="/protocol" className={moreItemClass} onClick={() => setIsTestnetDropdownOpen(false)}>Protocol</Link>
                      {process.env.NEXT_PUBLIC_SHOW_DEBUG === 'true' ? (
                        <>
                          <Link href="/token-info" className={`${moreItemClass} text-amber-200`} onClick={() => setIsTestnetDropdownOpen(false)}>Token Info</Link>
                          <Link href="/create/advanced" className={`${moreItemClass} text-sky-300`} onClick={() => setIsTestnetDropdownOpen(false)}>Create (lab)</Link>
                          <Link href="/admin" className={`${moreItemClass} text-sky-300`} onClick={() => setIsTestnetDropdownOpen(false)}>Admin</Link>
                        </>
                      ) : null}
                    </div>
                  </div>
                )}
              </div>

            </nav>
          </div>
          <div className="flex items-center gap-3 flex-shrink-0 flex-wrap justify-end">
            <div className="flex flex-col items-end gap-1">
              <label className="text-[10px] uppercase tracking-wide text-[var(--text-muted,#9aa3b2)]" htmlFor="header-chain-selector">
                App network
              </label>
              <select
                id="header-chain-selector"
                className="rounded-md border border-[var(--border-subtle)] bg-[var(--surface-2)] px-2 py-1 text-xs text-[var(--text-primary)]"
                value={selectedChainId}
                onChange={(event) => void selectNetwork(Number(event.target.value))}
                disabled={isSwitching || chains.length === 1}
              >
                {chains.map((chain) => <option key={chain.id} value={chain.id}>{chain.name}</option>)}
              </select>
              {(isConnected || isLocalRobinhoodTestnet()) && (
                <span className="max-w-[260px] text-right text-[10px] text-[var(--text-muted)]" title="Connected reads use the selected wallet provider. Its RPC URL is controlled by your wallet. The browsing RPC is used only while disconnected.">
                  {isConnected ? 'RPC: connected wallet' : `Browsing RPC: ${LOCAL_RPC_URL}`}
                </span>
              )}
              {chainSwitchError && <p role="alert" className="max-w-[260px] text-right text-xs text-red-300">{chainSwitchError}</p>}
            </div>
            <ConnectButton.Custom>
              {({ account, chain, mounted, openConnectModal, openAccountModal, openChainModal }) => {
                const connected = mounted && account && chain;
                const wrongNetwork = connected && (chain.unsupported || chain.id !== selectedChainId);
                return (
                  <div className="flex items-center gap-2" aria-hidden={!mounted} style={!mounted ? { opacity: 0, pointerEvents: 'none' } : undefined}>
                    {wrongNetwork && (
                      <Button variant="secondary" onClick={openChainModal}>Switch network</Button>
                    )}
                    <Button
                      className="min-h-11"
                      type="button"
                      data-testid={connected ? 'wallet-account' : 'wallet-connect'}
                      title={connected ? account.address : undefined}
                      disabled={!mounted}
                      onClick={connected ? (openAccountModal ?? openChainModal) : openConnectModal}
                    >
                      {connected ? account.displayName : 'Connect Wallet'}
                    </Button>
                  </div>
                );
              }}
            </ConnectButton.Custom>
          </div>
        </div>
      </div>
    </header>
  );
}
