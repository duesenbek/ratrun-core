import { useAccount, useConnect, useDisconnect } from "wagmi";

export default function WalletConnect() {
  const { address, isConnected } = useAccount();
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();

  if (isConnected) {
    return (
      <div className="flex items-center gap-4">
        <div className="text-xs text-primary border border-primary px-2 py-1 bg-primary/10 rounded">
          {address?.slice(0, 6)}...{address?.slice(-4)}
        </div>
        <button
          onClick={() => disconnect()}
          className="text-xs border border-muted px-2 py-1 hover:bg-muted/30 transition-colors"
        >
          DISCONNECT
        </button>
      </div>
    );
  }

  return (
    <div className="flex gap-2">
      {connectors.map((connector) => (
        <button
          key={connector.id}
          onClick={() => connect({ connector })}
          className="text-xs border border-primary text-primary px-3 py-1 hover:bg-primary hover:text-background transition-colors uppercase"
        >
          {connector.name}
        </button>
      ))}
    </div>
  );
}
