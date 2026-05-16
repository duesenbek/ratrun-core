import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { Deposit, Withdraw } from "../generated/BurrowVault/BurrowVault";
import { VaultDeposit, VaultWithdraw, VaultPosition, Player, Protocol } from "../generated/schema";

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

function loadOrCreateVaultPosition(owner: Bytes): VaultPosition {
  let id = owner.toHex();
  let pos = VaultPosition.load(id);
  if (!pos) {
    pos = new VaultPosition(id);
    pos.owner = owner;
    pos.shares = BigInt.fromI32(0);
    pos.totalDeposited = BigInt.fromI32(0);
    pos.totalWithdrawn = BigInt.fromI32(0);
    pos.lastUpdated = BigInt.fromI32(0);
    pos.save();
  }
  return pos;
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

export function handleDeposited(event: Deposit): void {
  let owner = loadOrCreatePlayer(event.params.owner);

  let dep = new VaultDeposit(event.transaction.hash.toHex() + "-" + event.logIndex.toString());
  dep.sender = event.params.caller;
  dep.owner = owner.id;
  dep.assets = event.params.assets;
  dep.shares = event.params.shares;
  dep.blockNumber = event.block.number;
  dep.timestamp = event.block.timestamp;
  dep.transactionHash = event.transaction.hash;
  dep.save();

  let pos = loadOrCreateVaultPosition(event.params.owner);
  pos.shares = pos.shares.plus(event.params.shares);
  pos.totalDeposited = pos.totalDeposited.plus(event.params.assets);
  pos.lastUpdated = event.block.timestamp;
  pos.save();

  owner.vaultShares = owner.vaultShares.plus(event.params.shares);
  owner.save();

  let proto = loadOrCreateProtocol();
  proto.totalVaultDeposits = proto.totalVaultDeposits.plus(event.params.assets);
  proto.save();
}

export function handleWithdrawn(event: Withdraw): void {
  let withdraw = new VaultWithdraw(event.transaction.hash.toHex() + "-" + event.logIndex.toString());
  withdraw.sender = event.params.caller;
  withdraw.receiver = event.params.receiver;
  withdraw.owner = event.params.owner;
  withdraw.assets = event.params.assets;
  withdraw.shares = event.params.shares;
  withdraw.blockNumber = event.block.number;
  withdraw.timestamp = event.block.timestamp;
  withdraw.transactionHash = event.transaction.hash;
  withdraw.save();

  let pos = loadOrCreateVaultPosition(event.params.owner);
  if (pos.shares.ge(event.params.shares)) {
    pos.shares = pos.shares.minus(event.params.shares);
  } else {
    pos.shares = BigInt.fromI32(0);
  }
  pos.totalWithdrawn = pos.totalWithdrawn.plus(event.params.assets);
  pos.lastUpdated = event.block.timestamp;
  pos.save();

  let player = loadOrCreatePlayer(event.params.owner);
  if (player.vaultShares.ge(event.params.shares)) {
    player.vaultShares = player.vaultShares.minus(event.params.shares);
  } else {
    player.vaultShares = BigInt.fromI32(0);
  }
  player.save();
}
