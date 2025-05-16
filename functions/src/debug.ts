// Diagnostic script to check actual exports from genkit packages
// This won't be used in production, just for debugging

// Import packages directly instead of using require()
import * as genkitPkg from "genkit";
import * as corePkg from "@genkit-ai/core";
import * as aiPkg from "@genkit-ai/ai";
import * as firebasePkg from "@genkit-ai/firebase";

// Try importing different things to see what's available
try {
  // 1. Log main genkit package
  console.log("------ genkit exports ------");
  console.log(Object.keys(genkitPkg));

  // 2. Log core package
  console.log("------ @genkit-ai/core exports ------");
  console.log(Object.keys(corePkg));

  // 3. Log ai package
  console.log("------ @genkit-ai/ai exports ------");
  console.log(Object.keys(aiPkg));

  // 4. Log firebase package
  console.log("------ @genkit-ai/firebase exports ------");
  console.log(Object.keys(firebasePkg));
} catch (error) {
  console.error("Error inspecting packages:", error);
}
