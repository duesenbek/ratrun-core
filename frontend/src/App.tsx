import { BrowserRouter as Router, Routes, Route } from "react-router-dom";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { http, createConfig, WagmiProvider } from "wagmi";
import { mainnet, sepolia, baseSepolia } from "wagmi/chains";
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

// Setup Wagmi config
const config = createConfig({
  chains: [mainnet, sepolia, baseSepolia],
  transports: {
    [mainnet.id]: http(),
    [sepolia.id]: http(),
    [baseSepolia.id]: http(),
  },
});

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <Router>
          <div className="min-h-screen bg-background text-text flex flex-col font-mono selection:bg-primary selection:text-background">
            <header className="border-b border-muted p-4 flex justify-between items-center bg-card">
              <a href="/" className="text-xl font-bold tracking-widest text-primary glow-primary hover:text-white transition-colors">
                RATRUN_OS v0.1
              </a>
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
