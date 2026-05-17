import { useReadContract, useWriteContract, useAccount, useWaitForTransactionReceipt } from "wagmi";
import { parseAbi } from "viem";
import { CONTRACT_ADDRESSES } from "../contracts/addresses";
import { BurrowVaultABI, ERC20ABI } from "../contracts/abis";
import { useEffect } from "react";

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

  // Read scrap token allowance for the vault
  const { data: allowanceData, refetch: refetchAllowance } = useReadContract({
    address: CONTRACT_ADDRESSES.scrapToken,
    abi: parseAbi([...ERC20ABI]),
    functionName: "allowance",
    args: address ? [address, CONTRACT_ADDRESSES.burrowVault] : undefined,
    query: {
      enabled: isConnected && !!address,
      refetchInterval: 5000,
    }
  });

  const { writeContract, data: txHash, isPending } = useWriteContract();
  
  const { isLoading: isTxConfirming, isSuccess: isTxSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  // Automatically refetch allowance on transaction success
  useEffect(() => {
    if (isTxSuccess) {
      refetchAllowance();
    }
  }, [isTxSuccess, refetchAllowance]);

  const approve = () => {
    if (!address) return;
    writeContract({
      address: CONTRACT_ADDRESSES.scrapToken,
      abi: parseAbi([...ERC20ABI]),
      functionName: "approve",
      args: [CONTRACT_ADDRESSES.burrowVault, 115792089237316195423570985008687907853269984665640564039457584007913129639935n], // max uint256
    });
  };

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
    allowance: allowanceData ? BigInt(allowanceData) : 0n,
    deposit,
    withdraw,
    approve,
    isPending: isPending || isTxConfirming,
    isTxSuccess
  };
}

