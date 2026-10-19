import { Address, Avatar, Identity, Name } from '@coinbase/onchainkit/identity';
import type { Address as WalletAddress } from 'viem';
import { base } from 'wagmi/chains';

export function UserProfile({ address }: { readonly address: WalletAddress }) {
  return (
    <div className="profile">
      <Identity address={address} chain={base}>
        <Avatar />
        <Name />
        <Address />
      </Identity>
      <p className="address">{address}</p>
      {!process.env.NEXT_PUBLIC_CDP_API_KEY && (
        <p className="note">Names and avatars depend on public identity services. Set a browser-safe CDP key if your deployment requires one. Your address is always shown.</p>
      )}
    </div>
  );
}
