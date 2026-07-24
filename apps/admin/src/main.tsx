import {StrictMode} from "react";
import {createRoot} from "react-dom/client";
import {TooltipProvider} from "@asaas/ui";
import App from "./App.tsx";
import "./index.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <TooltipProvider>
      <App/>
    </TooltipProvider>
  </StrictMode>,
);
