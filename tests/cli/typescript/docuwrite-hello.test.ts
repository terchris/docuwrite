// file: tests/cli/typescript/docuwrite-hello.test.ts

import { sayHello } from "../../../src/cli/typescript/commands/docuwrite-hello";

describe("docuwrite-hello command", () => {
  let consoleLogSpy: jest.SpyInstance;

  beforeEach(() => {
    consoleLogSpy = jest.spyOn(console, "log").mockImplementation();
  });

  afterEach(() => {
    consoleLogSpy.mockRestore();
  });

  it("should print hello message with date", async () => {
    await sayHello();

    expect(consoleLogSpy).toHaveBeenCalledWith("Hello from DocuWrite!");
    expect(consoleLogSpy).toHaveBeenCalledWith(
      expect.stringContaining("Current date and time:")
    );
  });

  it("should include verbose information when verbose option is true", async () => {
    await sayHello({ verbose: true });

    expect(consoleLogSpy).toHaveBeenNthCalledWith(1, "Hello from DocuWrite!");
    expect(consoleLogSpy).toHaveBeenNthCalledWith(2, 
      expect.stringContaining("Current date and time:")
    );
    expect(consoleLogSpy).toHaveBeenNthCalledWith(3, "Running in verbose mode");
    expect(consoleLogSpy).toHaveBeenNthCalledWith(4, 
      expect.stringContaining("Node version:")
    );
    expect(consoleLogSpy).toHaveBeenNthCalledWith(5, 
      expect.stringContaining("Platform:")
    );
  });
});