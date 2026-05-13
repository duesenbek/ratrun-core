import { useState } from "react";
import { Hammer } from "lucide-react";
import gigaPumpSticker from "../assets/stickers/giga-pump.png";

const RECIPES = [
  {
    id: 0,
    output: "GPU",
    inputs: [
      { name: "SCRAP", amount: 100 },
      { name: "BATTERY", amount: 2 },
    ],
  },
  {
    id: 1,
    output: "SERVER",
    inputs: [
      { name: "CHIP", amount: 5 },
      { name: "GPU", amount: 1 },
    ],
  },
];

export default function Craft() {
  const [isCrafting, setIsCrafting] = useState(false);

  const handleCraft = (id: number) => {
    setIsCrafting(true);
    // Simulate transaction
    setTimeout(() => setIsCrafting(false), 2000);
  };

  return (
    <div className="max-w-4xl mx-auto space-y-8">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold text-primary tracking-widest">CRAFTING ENGINE</h1>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <div className="space-y-6">
          {RECIPES.map((recipe) => (
            <div key={recipe.id} className="term-box p-6">
              <div className="flex justify-between items-center mb-4 border-b border-muted pb-2">
                <span className="font-bold tracking-widest text-lg">{recipe.output}</span>
                <span className="text-xs text-primary">RECIPE #{recipe.id}</span>
              </div>
              
              <div className="space-y-2 mb-6">
                <div className="text-xs text-muted mb-2">REQUIRES:</div>
                {recipe.inputs.map((req, idx) => (
                  <div key={idx} className="flex justify-between text-sm">
                    <span>{req.name}</span>
                    <span className="font-mono">{req.amount}</span>
                  </div>
                ))}
              </div>

              <button 
                onClick={() => handleCraft(recipe.id)}
                disabled={isCrafting}
                className="pixel-btn w-full flex items-center justify-center gap-2"
              >
                <Hammer className="w-4 h-4" />
                {isCrafting ? "CRAFTING..." : "CRAFT"}
              </button>
            </div>
          ))}
        </div>

        <div className="term-box flex flex-col items-center justify-center text-center p-8 border-primary">
          <img src={gigaPumpSticker} alt="Crafting Success" className="w-48 h-48 object-contain mb-6 drop-shadow-[0_0_15px_rgba(182,255,0,0.3)]" />
          <h2 className="text-xl font-bold text-primary mb-2">UPGRADE YOUR GEAR</h2>
          <p className="text-sm text-muted">Combine raw materials to create powerful items with rarity multipliers.</p>
        </div>
      </div>
    </div>
  );
}
