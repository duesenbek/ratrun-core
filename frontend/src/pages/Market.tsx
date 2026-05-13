import { ShoppingCart } from "lucide-react";
import ngmiSticker from "../assets/stickers/ngmi.png";

export default function Market() {
  return (
    <div className="max-w-4xl mx-auto space-y-8">
      <div className="flex justify-between items-center mb-8 border-b border-muted pb-4">
        <h1 className="text-3xl font-bold text-primary tracking-widest">BLACK MARKET</h1>
      </div>
      <div className="term-box flex flex-col items-center p-12 text-center border-red-900/30">
        <img src={ngmiSticker} alt="Market Closed" className="w-48 h-48 object-contain mb-6 opacity-80" />
        <h2 className="text-2xl font-bold text-red-500 mb-2">ACCESS DENIED</h2>
        <p className="text-muted max-w-md mx-auto">
          The Black Market is currently shifting locations to avoid the exterminators. Check back next epoch.
        </p>
      </div>
    </div>
  );
}
