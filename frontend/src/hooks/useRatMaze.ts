import { useReadContract, useWriteContract, useAccount, useWaitForTransactionReceipt } from "wagmi";
import { parseAbi } from "viem";
import { CONTRACT_ADDRESSES } from "../contracts/addresses";
import { RatMazeABI } from "../contracts/abis";
import { useEffect, useState } from "react";

export function useRatMaze() {
  const { address, isConnected } = useAccount();
  const [localPending, setLocalPending] = useState(false);

  // Read active run
  const { data: activeRunData, refetch: refetchActiveRun } = useReadContract({
    address: CONTRACT_ADDRESSES.ratMaze,
    abi: parseAbi([...RatMazeABI]),
    functionName: "activeRuns",
    args: address ? [address] : undefined,
    query: {
      enabled: isConnected && !!address,
      refetchInterval: 3000, // Poll every 3s to keep UI updated
    }
  });

  // Derived state with robust support for both array tuples and named objects
  const isActive = activeRunData
    ? (Array.isArray(activeRunData)
        ? (activeRunData[2] ?? false)
        : (activeRunData as any).isActive ?? (activeRunData as any).active ?? false)
    : false;

  const currentZone = activeRunData
    ? (Array.isArray(activeRunData)
        ? (activeRunData[1] ?? 0)
        : (activeRunData as any).riskLevel ?? 0)
    : 0;

  // Read remaining time
  const { data: remainingTimeData, refetch: refetchRemainingTime } = useReadContract({
    address: CONTRACT_ADDRESSES.ratMaze,
    abi: parseAbi([...RatMazeABI]),
    functionName: "getRemainingTime",
    args: address ? [address] : undefined,
    query: {
      enabled: isConnected && !!address && isActive === true,
      refetchInterval: 1000, // Poll every 1s for countdown
    }
  });

  const { writeContract, data: txHash, isPending, reset } = useWriteContract();
  
  const { isLoading: isTxConfirming, isSuccess: isTxSuccess, isError: isTxError } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  const enterMaze = (riskLevel: number) => {
    setLocalPending(true);
    writeContract({
      address: CONTRACT_ADDRESSES.ratMaze,
      abi: parseAbi([...RatMazeABI]),
      functionName: "enterMaze",
      args: [riskLevel],
    }, {
      onError: () => {
        setLocalPending(false);
      }
    });
  };

  const claimLoot = () => {
    setLocalPending(true);
    writeContract({
      address: CONTRACT_ADDRESSES.ratMaze,
      abi: parseAbi([...RatMazeABI]),
      functionName: "claimLoot",
    }, {
      onError: () => {
        setLocalPending(false);
      }
    });
  };

  // Turn off local pending and reset writeContract state when tx completes or errors
  useEffect(() => {
    if (isTxSuccess || isTxError) {
      refetchActiveRun();
      refetchRemainingTime();
      setLocalPending(false);
      if (reset) reset();
    }
  }, [isTxSuccess, isTxError, refetchActiveRun, refetchRemainingTime, reset]);

  // Self-healing: if contract state says we are active, we are definitely not pending deployment
  useEffect(() => {
    if (isActive) {
      setLocalPending(false);
    }
  }, [isActive]);

  const remainingTimeSeconds = remainingTimeData ? Number(remainingTimeData) : 0;
  const isFinished = isActive && remainingTimeSeconds === 0;

  return {
    isActive,
    currentZone,
    remainingTimeSeconds,
    isFinished,
    enterMaze,
    claimLoot,
    isPending: isPending || isTxConfirming || localPending,
    isTxSuccess
  };
}
