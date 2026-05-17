import { useReadContract, useWriteContract, useAccount, useWaitForTransactionReceipt } from "wagmi";
import { parseAbi } from "viem";
import { CONTRACT_ADDRESSES } from "../contracts/addresses";
import { BurrowVaultABI } from "../contracts/abis";

export function useBurrow() {
  const { address, isConnected } = useAccount();

  // Read shares
  const { data: sharesData } = useReadContract({
    address: CONTRACT_ADDRESSES.burrowVault,
    abi: parseAbi([...BurrowVaultABI]),
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: {
      enabled: isConnected && !!address,
      refetchInterval: 5000,
    }
  });

  // Convert shares to assets to calculate earned yield
  const { data: assetsData } = useReadContract({
    address: CONTRACT_ADDRESSES.burrowVault,
    abi: parseAbi([...BurrowVaultABI]),
    functionName: "convertToAssets",
    args: sharesData ? [sharesData] : undefined,
    query: {
      enabled: isConnected && !!sharesData && sharesData > 0n,
      refetchInterval: 5000,
    }
  });

  const { writeContract, data: txHash, isPending } = useWriteContract();
  
  const { isLoading: isTxConfirming, isSuccess: isTxSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  const deposit = (amount: bigint) => {
    if (!address) return;
    writeContract({
      address: CONTRACT_ADDRESSES.burrowVault,
      abi: parseAbi([...BurrowVaultABI]),
      functionName: "deposit",
      args: [amount, address],
    });
  };

  const withdraw = (amount: bigint) => {
    if (!address) return;
    writeContract({
      address: CONTRACT_ADDRESSES.burrowVault,
      abi: parseAbi([...BurrowVaultABI]),
      functionName: "withdraw",
      args: [amount, address, address],
    });
  };

  return {
    shares: sharesData ? Number(sharesData) : 0,
    assets: assetsData ? Number(assetsData) : 0,
    deposit,
    withdraw,
    isPending: isPending || isTxConfirming,
    isTxSuccess
  };
}
