// src/cli/typescript/commands/docuwrite-hello.ts
interface HelloOptions {
  verbose?: boolean;
}

async function sayHello(options: HelloOptions = {}): Promise<void> {
  const currentDate = new Date();
  const dateString = currentDate.toLocaleString();

  console.log("Hello from DocuWrite!");
  console.log(`Current date and time: ${dateString}`);

  if (options.verbose) {
    console.log("Running in verbose mode");
    console.log(`Node version: ${process.version}`);
    console.log(`Platform: ${process.platform}`);
  }
}

async function main() {
  const args = process.argv.slice(2);
  const options: HelloOptions = {
    verbose: args.includes("--verbose") || args.includes("-v"),
  };

  try {
    await sayHello(options);
  } catch (error) {
    console.error("Error:", error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

export { sayHello, HelloOptions };