export const RatMazeABI = [
  "function enterMaze(uint8 riskLevel) external",
  "function claimLoot() external",
  "function getRemainingTime(address player) external view returns (uint256)",
  "function activeRuns(address player) external view returns (uint40 startTime, uint8 riskLevel, bool isActive)",
  "function survivalChances(uint8 zone) external view returns (uint256)",
  "function runDurations(uint8 zone) external view returns (uint256)",
  "function scrapRewards(uint8 zone) external view returns (uint256)",
] as const;

export const GameItemsABI = [
  "function balanceOf(address account, uint256 id) external view returns (uint256)",
  "function totalInventoryBalance(address account) external view returns (uint256)",
] as const;

export const BurrowVaultABI = [
  "function deposit(uint256 assets, address receiver) external returns (uint256 shares)",
  "function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares)",
  "function balanceOf(address account) external view returns (uint256)",
  "function convertToAssets(uint256 shares) external view returns (uint256)",
  "function totalAssets() external view returns (uint256)",
] as const;

export const CraftingEngineABI = [
  "function craft(uint256 recipeId) external",
  "function recipes(uint256 recipeId) external view returns (uint256 outputItemId, uint256 outputAmount, bool active)",
  "function getRecipeInputs(uint256 recipeId) external view returns (tuple(uint256 itemId, uint256 amount)[])",
] as const;

export const ResourceAMMABI = [
  "function swapExactInput(uint256 amountIn, uint256 amountOutMin, bool zeroForOne, address to, uint256 deadline) external returns (uint256 amountOut)",
  "function addLiquidity(uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, address to, uint256 deadline) external returns (uint256 amount0, uint256 amount1, uint256 shares)",
  "function reserve0() external view returns (uint256)",
  "function reserve1() external view returns (uint256)",
] as const;
