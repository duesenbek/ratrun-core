import { useReadContract, useWriteContract, useAccount, useWaitForTransactionReceipt } from "wagmi";
import { parseAbi } from "viem";
import { CONTRACT_ADDRESSES } from "../contracts/addresses";
import { RatMazeABI } from "../contracts/abis";
import { useEffect } from "react";

export function useRatMaze() {
  const { address, isConnected } = useAccount();

  // Read active run
  const { data: activeRunData, refetch: refetchActiveRun } = useReadContract({
    address: CONTRACT_ADDRESSES.ratMaze,
    abi: parseAbi([...RatMazeABI]),
    functionName: "activeRuns",
    args: address ? [address] : undefined,
    query: {
      enabled: isConnected && !!address,
      refetchInterval: 5000, // Poll every 5s to keep UI updated
    }
  });

  // Read remaining time
  const { data: remainingTimeData, refetch: refetchRemainingTime } = useReadContract({
    address: CONTRACT_ADDRESSES.ratMaze,
    abi: parseAbi([...RatMazeABI]),
    functionName: "getRemainingTime",
    args: address ? [address] : undefined,
    query: {
      enabled: isConnected && !!address && activeRunData?.[2] === true,
      refetchInterval: 1000, // Poll every 1s for countdown
    }
  });

  const { writeContract, data: txHash, isPending } = useWriteContract();
  
  const { isLoading: isTxConfirming, isSuccess: isTxSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  const enterMaze = (riskLevel: number) => {
    writeContract({
      address: CONTRACT_ADDRESSES.ratMaze,
      abi: parseAbi([...RatMazeABI]),
      functionName: "enterMaze",
      args: [riskLevel],
    });
  };

  const claimLoot = () => {
    writeContract({
      address: CONTRACT_ADDRESSES.ratMaze,
      abi: parseAbi([...RatMazeABI]),
      functionName: "claimLoot",
    });
  };

  // Refetch when transaction completes
  useEffect(() => {
    if (isTxSuccess) {
      refetchActiveRun();
      refetchRemainingTime();
    }
  }, [isTxSuccess, refetchActiveRun, refetchRemainingTime]);

  // Derived state
  const isActive = activeRunData?.[2] ?? false;
  const currentZone = activeRunData?.[1] ?? 0;
  const remainingTimeSeconds = remainingTimeData ? Number(remainingTimeData) : 0;
  const isFinished = isActive && remainingTimeSeconds === 0;

  return {
    isActive,
    currentZone,
    remainingTimeSeconds,
    isFinished,
    enterMaze,
    claimLoot,
    isPending: isPending || isTxConfirming,
    isTxSuccess
  };
}
