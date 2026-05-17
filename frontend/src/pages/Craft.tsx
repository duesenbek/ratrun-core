import { useState } from "react";
import { Wrench, Cpu, Zap } from "lucide-react";
import gigaPumpSticker from "../assets/stickers/giga-pump.png";
import { useCrafting } from "../hooks/useCrafting";

// We still need a mapping from Item IDs to names for the UI
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

const ICONS: Record<string, any> = {
  GPU: Cpu,
  DRILL: Wrench,
  SERVER: Zap,
};

export default function Craft() {
  const [selectedRecipe, setSelectedRecipe] = useState<number | null>(null);
  const { craft, rawRecipes, isPending, isTxSuccess } = useCrafting();

  // Parse raw recipes from chain
  const parsedRecipes = rawRecipes
    .filter(r => r.details && (r.details as any)[2]) // Only active recipes
    .map(r => {
      const details = r.details as any;
      const outputItemId = Number(details[0]);
      const outputAmount = Number(details[1]);
      const inputs = (r.inputs as readonly { itemId: bigint; amount: bigint }[] || []).map(input => ({
        name: ITEM_NAMES[Number(input.itemId)] || `ITEM_${input.itemId}`,
        amount: Number(input.amount),
        id: Number(input.itemId)
      }));

      return {
        id: r.id,
        output: ITEM_NAMES[outputItemId] || `ITEM_${outputItemId}`,
        outputAmount,
        inputs
      };
    });

  return (
    <div className="max-w-4xl mx-auto space-y-6 animate-in fade-in duration-500 pb-20">
      
      <div className="border-b border-primary/30 pb-4 mb-8">
        <h1 className="text-3xl md:text-5xl font-black text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-primary uppercase tracking-tighter mb-2">
          Fabricator
        </h1>
        <p className="text-muted flex items-center gap-2 text-sm">
          <Wrench className="w-4 h-4 text-blue-400" />
          SYNTHESIZE ADVANCED HARDWARE FROM SCAVENGED COMPONENTS
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {parsedRecipes.map((recipe) => {
          const Icon = ICONS[recipe.output] || Wrench;
          return (
            <div 
              key={recipe.id}
              className={`glass-panel p-6 cursor-pointer transition-all duration-300 border ${
                selectedRecipe === recipe.id ? 'border-primary shadow-[0_0_15px_rgba(0,255,170,0.2)]' : 'border-primary/20 hover:border-primary/50'
              }`}
              onClick={() => setSelectedRecipe(recipe.id)}
            >
              <div className="flex justify-between items-start mb-6">
                <div className="flex items-center gap-3">
                  <div className="p-3 bg-blue-950/40 rounded-sm border border-blue-500/30">
                    <Icon className="w-6 h-6 text-blue-400" />
                  </div>
                  <div>
                    <h3 className="font-bold text-xl tracking-wider text-blue-100">{recipe.output} <span className="text-xs text-muted">x{recipe.outputAmount}</span></h3>
                    <p className="text-xs text-muted">Tier {recipe.id + 1} Component</p>
                  </div>
                </div>
              </div>

              <div className="space-y-3 mb-6">
                <p className="text-xs text-primary mb-2 font-bold tracking-widest border-b border-primary/20 pb-1">REQUIRED MATERIALS</p>
                {recipe.inputs.map((input, idx) => (
                  <div key={idx} className="flex justify-between items-center bg-black/40 p-2 rounded-sm border border-white/5">
                    <span className="text-sm text-gray-300">{input.name}</span>
                    <span className="text-sm font-mono text-primary">{input.amount}</span>
                  </div>
                ))}
              </div>

              <button
                className={`w-full py-3 rounded-sm font-bold tracking-widest transition-all ${
                  selectedRecipe === recipe.id 
                    ? isPending 
                      ? 'bg-blue-500/50 text-white cursor-not-allowed'
                      : isTxSuccess && selectedRecipe === recipe.id
                      ? 'bg-green-500 text-black'
                      : 'bg-blue-500 text-black hover:bg-blue-400 hover:shadow-[0_0_20px_rgba(59,130,246,0.4)]'
                    : 'bg-blue-950/40 text-blue-400 border border-blue-500/30 hover:bg-blue-900/40'
                }`}
                onClick={(e) => {
                  e.stopPropagation();
                  setSelectedRecipe(recipe.id);
                  if (!isPending) craft(recipe.id);
                }}
                disabled={isPending}
              >
                {isPending && selectedRecipe === recipe.id ? 'FABRICATING...' : 
                 isTxSuccess && selectedRecipe === recipe.id ? 'SUCCESS' : 
                 'INITIATE SYNTHESIS'}
              </button>
            </div>
          );
        })}

        {parsedRecipes.length === 0 && (
          <div className="col-span-2 text-center p-12 glass-panel">
            <p className="text-muted">NO RECIPES AVAILABLE FROM FABRICATOR NETWORK.</p>
          </div>
        )}

        <div className="term-box flex flex-col items-center justify-center text-center p-8 border-primary">
          <img src={gigaPumpSticker} alt="Crafting Success" className="w-48 h-48 object-contain mb-6 drop-shadow-[0_0_15px_rgba(182,255,0,0.3)]" />
          <h2 className="text-xl font-bold text-primary mb-2">UPGRADE YOUR GEAR</h2>
          <p className="text-sm text-muted">Combine raw materials to create powerful items with rarity multipliers.</p>
        </div>
      </div>
    </div>
  );
}
