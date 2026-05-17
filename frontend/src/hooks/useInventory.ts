import { useReadContracts, useAccount } from "wagmi";
import { parseAbi } from "viem";
import { CONTRACT_ADDRESSES } from "../contracts/addresses";
import { GameItemsABI } from "../contracts/abis";

const ITEM_NAMES: Record<number, string> = {
  0: "SCRAP",
  1: "BATTERY",
  2: "WIRE",
  3: "CHIP",
  4: "RELIC",
  5: "GPU",
  6: "SERVER",
  7: "DRILL"
};

export function useInventory() {
  const { address, isConnected } = useAccount();

  const abi = parseAbi([...GameItemsABI]);

  const contracts = Array.from({ length: 8 }, (_, i) => ({
    address: CONTRACT_ADDRESSES.gameItems,
    abi,
    functionName: "balanceOf",
    args: address ? [address, BigInt(i)] : undefined,
  }));

  const { data } = useReadContracts({
    contracts: isConnected && !!address ? contracts : [],
    query: {
      refetchInterval: 5000,
    }
  });

  const balances = data?.map(d => Number(d.result ?? 0)) ?? Array(8).fill(0);
  const items = balances.map((balance, id) => ({
    id,
    name: ITEM_NAMES[id] || `ITEM_${id}`,
    balance
  }));

  return {
    scrapBalance: balances[0],
    balances,
    items,
  };
}
