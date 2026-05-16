import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { RunStarted, RunSurvived, RunCaught } from "../generated/RatMaze/RatMaze";
import { MazeRun, Player, Protocol } from "../generated/schema";

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

export function handleRunStarted(event: RunStarted): void {
  let player = loadOrCreatePlayer(event.params.player);
  player.totalMazeRuns = player.totalMazeRuns.plus(BigInt.fromI32(1));
  player.save();

  let run = new MazeRun(event.transaction.hash.toHex() + "-" + event.logIndex.toString());
  run.player = player.id;
  run.riskLevel = event.params.riskLevel;
  run.survived = null;
  run.scrapEarned = BigInt.fromI32(0);
  run.lootItemId = null;
  run.startedAt = event.block.timestamp;
  run.resolvedAt = null;
  run.transactionHash = event.transaction.hash;
  run.save();

  let proto = loadOrCreateProtocol();
  proto.totalMazeRuns = proto.totalMazeRuns.plus(BigInt.fromI32(1));
  proto.save();
}

export function handleRunSurvived(event: RunSurvived): void {
  let player = loadOrCreatePlayer(event.params.player);
  player.totalSurvived = player.totalSurvived.plus(BigInt.fromI32(1));
  player.totalScrapEarned = player.totalScrapEarned.plus(event.params.scrapEarned);
  player.save();
}

export function handleRunCaught(event: RunCaught): void {
  let player = loadOrCreatePlayer(event.params.player);
  player.save();
}
