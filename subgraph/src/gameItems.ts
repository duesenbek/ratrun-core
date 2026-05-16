import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { ItemMinted, ItemBurned } from "../generated/GameItems/GameItems";
import { Player, ItemBalance, ItemMintEvent, ItemBurnEvent, Protocol } from "../generated/schema";

function loadOrCreatePlayer(address: Bytes): Player {
  let id = address.toHex();
  let player = Player.load(id);
  if (!player) {
    player = new Player(id);
    player.address = address;
    player.totalCrafted = BigInt.fromI32(0);
    player.totalMazeRuns = BigInt.fromI32(0);
    player.totalSurvived = BigInt.fromI32(0);
    player.totalScrapEarned = BigInt.fromI32(0);
    player.vaultShares = BigInt.fromI32(0);
    player.save();
  }
  return player;
}

function loadOrCreateProtocol(): Protocol {
  let p = Protocol.load("1");
  if (!p) {
    p = new Protocol("1");
    p.totalItemsMinted = BigInt.fromI32(0);
    p.totalItemsBurned = BigInt.fromI32(0);
    p.totalCrafts = BigInt.fromI32(0);
    p.totalMazeRuns = BigInt.fromI32(0);
    p.totalVaultDeposits = BigInt.fromI32(0);
    p.save();
  }
  return p;
}

export function handleItemMinted(event: ItemMinted): void {
  let player = loadOrCreatePlayer(event.params.to);

  let balId = player.id + "-" + event.params.id.toString();
  let balance = ItemBalance.load(balId);
  if (!balance) {
    balance = new ItemBalance(balId);
    balance.player = player.id;
    balance.itemId = event.params.id;
    balance.amount = BigInt.fromI32(0);
  }
  balance.amount = balance.amount.plus(event.params.amount);
  balance.lastUpdated = event.block.timestamp;
  balance.save();

  let mintEvent = new ItemMintEvent(event.transaction.hash.toHex() + "-" + event.logIndex.toString());
  mintEvent.to = event.params.to;
  mintEvent.itemId = event.params.id;
  mintEvent.amount = event.params.amount;
  mintEvent.rarity = event.params.rarity;
  mintEvent.blockNumber = event.block.number;
  mintEvent.timestamp = event.block.timestamp;
  mintEvent.transactionHash = event.transaction.hash;
  mintEvent.save();

  let proto = loadOrCreateProtocol();
  proto.totalItemsMinted = proto.totalItemsMinted.plus(event.params.amount);
  proto.save();
}

export function handleItemBurned(event: ItemBurned): void {
  let player = loadOrCreatePlayer(event.params.from);

  let balId = player.id + "-" + event.params.id.toString();
  let balance = ItemBalance.load(balId);
  if (balance) {
    balance.amount = balance.amount.minus(event.params.amount);
    if (balance.amount.lt(BigInt.fromI32(0))) balance.amount = BigInt.fromI32(0);
    balance.lastUpdated = event.block.timestamp;
    balance.save();
  }

  let burnEvent = new ItemBurnEvent(event.transaction.hash.toHex() + "-" + event.logIndex.toString());
  burnEvent.from = event.params.from;
  burnEvent.itemId = event.params.id;
  burnEvent.amount = event.params.amount;
  burnEvent.blockNumber = event.block.number;
  burnEvent.timestamp = event.block.timestamp;
  burnEvent.transactionHash = event.transaction.hash;
  burnEvent.save();

  let proto = loadOrCreateProtocol();
  proto.totalItemsBurned = proto.totalItemsBurned.plus(event.params.amount);
  proto.save();
}
