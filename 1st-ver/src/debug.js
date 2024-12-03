const { spawn } = require("child_process");

// Define your debug variables here
const inputDir = "./test-repo";
const outputFile = "./output/documentation.pdf";

// Construct the command
const command = "npm";
const args = ["start", "--", "-i", inputDir, "-o", outputFile];

// Spawn the process
const child = spawn(command, args, { stdio: "inherit" });

// Handle the exit
child.on("exit", (code) => {
  console.log(`Child process exited with code ${code}`);
});
