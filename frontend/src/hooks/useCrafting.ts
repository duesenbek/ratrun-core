import { useWriteContract, useAccount, useWaitForTransactionReceipt, useReadContract } from "wagmi";
import { parseAbi } from "viem";
import { CONTRACT_ADDRESSES } from "../contracts/addresses";
import { CraftingEngineABI } from "../contracts/abis";

export function useCrafting() {
  const { address, isConnected } = useAccount();

  // For this prototype, we'll fetch recipes 0 and 1 since we know they exist.
  // In a full version, we'd query an indexer or emit events.
  const abi = parseAbi([...CraftingEngineABI]);

  const { data: recipe0 } = useReadContract({
    address: CONTRACT_ADDRESSES.craftingEngine,
    abi,
    functionName: "recipes",
    args: [0n],
    query: { enabled: isConnected, refetchInterval: 10000 }
  });

  const { data: recipe0Inputs } = useReadContract({
    address: CONTRACT_ADDRESSES.craftingEngine,
    abi,
    functionName: "getRecipeInputs",
    args: [0n],
    query: { enabled: isConnected, refetchInterval: 10000 }
  });

  const { data: recipe1 } = useReadContract({
    address: CONTRACT_ADDRESSES.craftingEngine,
    abi,
    functionName: "recipes",
    args: [1n],
    query: { enabled: isConnected, refetchInterval: 10000 }
  });

  const { data: recipe1Inputs } = useReadContract({
    address: CONTRACT_ADDRESSES.craftingEngine,
    abi,
    functionName: "getRecipeInputs",
    args: [1n],
    query: { enabled: isConnected, refetchInterval: 10000 }
  });

  const rawRecipes = [
    { id: 0, details: recipe0, inputs: recipe0Inputs },
    { id: 1, details: recipe1, inputs: recipe1Inputs },
  ];

  const { writeContract, data: txHash, isPending } = useWriteContract();
  
  const { isLoading: isTxConfirming, isSuccess: isTxSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  const craft = (recipeId: number) => {
    if (!address) return;
    writeContract({
      address: CONTRACT_ADDRESSES.craftingEngine,
      abi,
      functionName: "craft",
      args: [BigInt(recipeId)],
    });
  };

  return {
    craft,
    rawRecipes,
    isPending: isPending || isTxConfirming,
    isTxSuccess
  };
}
