import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { Crafted, RecipeAdded } from "../generated/CraftingEngine/CraftingEngine";
import { Player, CraftEvent, Recipe, Protocol } from "../generated/schema";

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

export function handleCrafted(event: Crafted): void {
  let player = loadOrCreatePlayer(event.params.crafter);
  player.totalCrafted = player.totalCrafted.plus(BigInt.fromI32(1));
  player.save();

  let craftEvent = new CraftEvent(event.transaction.hash.toHex() + "-" + event.logIndex.toString());
  craftEvent.crafter = player.id;
  craftEvent.recipeId = event.params.recipeId;
  craftEvent.outputAmount = event.params.outputAmount;
  craftEvent.blockNumber = event.block.number;
  craftEvent.timestamp = event.block.timestamp;
  craftEvent.transactionHash = event.transaction.hash;
  craftEvent.save();

  let recipe = Recipe.load(event.params.recipeId.toString());
  if (recipe) {
    recipe.totalCrafts = recipe.totalCrafts.plus(BigInt.fromI32(1));
    recipe.save();
  }

  let proto = loadOrCreateProtocol();
  proto.totalCrafts = proto.totalCrafts.plus(BigInt.fromI32(1));
  proto.save();
}

export function handleRecipeAdded(event: RecipeAdded): void {
  let recipe = new Recipe(event.params.recipeId.toString());
  recipe.recipeId = event.params.recipeId;
  recipe.outputItemId = event.params.outputItemId;
  recipe.outputAmount = event.params.outputAmount;
  recipe.active = true;
  recipe.createdAt = event.block.timestamp;
  recipe.totalCrafts = BigInt.fromI32(0);
  recipe.save();
}
