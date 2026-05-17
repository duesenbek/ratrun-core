import { BrowserRouter as Router, Routes, Route } from "react-router-dom";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { http, createConfig, WagmiProvider } from "wagmi";
import { baseSepolia } from "wagmi/chains";
import WalletConnect from "./components/WalletConnect";
import Home from "./pages/Home";

import Inventory from "./pages/Inventory";
import Craft from "./pages/Craft";
import Burrow from "./pages/Burrow";
import Council from "./pages/Council";
import Market from "./pages/Market";
import LootAnimation from "./components/LootAnimation";

// Setup query client
const queryClient = new QueryClient();

// Setup Wagmi config - exclusively use Base Sepolia to prevent mainnet prompts
const config = createConfig({
  chains: [baseSepolia],
  transports: {
    [baseSepolia.id]: http(),
  },
});

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <Router>
          <div className="min-h-screen bg-background text-text flex flex-col font-mono selection:bg-primary selection:text-background cyber-grid scanlines relative z-0">
            <header className="border-b border-primary/30 p-4 flex justify-between items-center bg-black/80 backdrop-blur-md sticky top-0 z-50 shadow-[0_0_15px_rgba(182,255,0,0.1)]">
              <div className="flex items-center gap-3">
                <div className="w-2 h-2 bg-primary animate-pulse"></div>
                <a href="/" className="text-xl font-bold tracking-widest text-primary hover:text-white transition-colors uppercase glitch-text">
                  <span aria-hidden="true">RATRUN_OS v1.0</span>
                  RATRUN_OS v1.0
                  <span aria-hidden="true">RATRUN_OS v1.0</span>
                </a>
              </div>
              <WalletConnect />
            </header>
            
            <main className="flex-1 p-6 overflow-y-auto">
              <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/inventory" element={<Inventory />} />
                <Route path="/craft" element={<Craft />} />
                <Route path="/burrow" element={<Burrow />} />
                <Route path="/council" element={<Council />} />
                <Route path="/market" element={<Market />} />
                <Route path="/loot" element={<LootAnimation />} />
              </Routes>
            </main>
          </div>
        </Router>
      </QueryClientProvider>
    </WagmiProvider>
  );
}

export default App;
