import { useWriteContract, useAccount, useWaitForTransactionReceipt } from "wagmi";
import { parseAbi } from "viem";
import { CONTRACT_ADDRESSES } from "../contracts/addresses";
import { ResourceAMMABI } from "../contracts/abis";

export function useMarket() {
  const { address } = useAccount();
  const { writeContract, data: txHash, isPending } = useWriteContract();
  
  const { isLoading: isTxConfirming, isSuccess: isTxSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

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
    swap,
    isPending: isPending || isTxConfirming,
    isTxSuccess
  };
}
