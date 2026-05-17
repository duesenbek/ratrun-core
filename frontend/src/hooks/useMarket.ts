import { useReadContract, useWriteContract, useAccount, useWaitForTransactionReceipt } from "wagmi";
import { parseAbi } from "viem";
import { CONTRACT_ADDRESSES } from "../contracts/addresses";
import { ResourceAMMABI, ERC20ABI } from "../contracts/abis";
import { useEffect } from "react";

export function useMarket() {
  const { address, isConnected } = useAccount();

  // Read scrap token allowance for the AMM
  const { data: allowance0Data, refetch: refetchAllowance0 } = useReadContract({
    address: CONTRACT_ADDRESSES.scrapToken,
    abi: parseAbi([...ERC20ABI]),
    functionName: "allowance",
    args: address ? [address, CONTRACT_ADDRESSES.resourceAMM] : undefined,
    query: {
      enabled: isConnected && !!address,
      refetchInterval: 5000,
    }
  });

  // Read battery token allowance for the AMM
  const { data: allowance1Data, refetch: refetchAllowance1 } = useReadContract({
    address: CONTRACT_ADDRESSES.batteryToken,
    abi: parseAbi([...ERC20ABI]),
    functionName: "allowance",
    args: address ? [address, CONTRACT_ADDRESSES.resourceAMM] : undefined,
    query: {
      enabled: isConnected && !!address,
      refetchInterval: 5000,
    }
  });

  const { writeContract, data: txHash, isPending } = useWriteContract();
  
  const { isLoading: isTxConfirming, isSuccess: isTxSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  // Automatically refetch allowances on transaction success
  useEffect(() => {
    if (isTxSuccess) {
      refetchAllowance0();
      refetchAllowance1();
    }
  }, [isTxSuccess, refetchAllowance0, refetchAllowance1]);

  const approve = (zeroForOne: boolean) => {
    if (!address) return;
    const tokenAddress = zeroForOne ? CONTRACT_ADDRESSES.scrapToken : CONTRACT_ADDRESSES.batteryToken;
    writeContract({
      address: tokenAddress,
      abi: parseAbi([...ERC20ABI]),
      functionName: "approve",
      args: [CONTRACT_ADDRESSES.resourceAMM, 115792089237316195423570985008687907853269984665640564039457584007913129639935n], // max uint256
    });
  };

  const swap = (amountIn: bigint, zeroForOne: boolean) => {
    if (!address) return;
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 60 * 20); // 20 mins
    writeContract({
      address: CONTRACT_ADDRESSES.resourceAMM,
      abi: parseAbi([...ResourceAMMABI]),
      functionName: "swapExactInput",
      args: [amountIn, 0n, zeroForOne, address, deadline],
    });
  };

  return {
    allowance0: allowance0Data ? BigInt(allowance0Data) : 0n,
    allowance1: allowance1Data ? BigInt(allowance1Data) : 0n,
    approve,
    swap,
    isPending: isPending || isTxConfirming,
    isTxSuccess
  };
}

