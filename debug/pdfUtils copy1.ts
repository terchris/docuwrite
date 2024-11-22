import path from "path";
import { execSync } from "child_process";

import { DocuWriteConfig } from "../src/modules/configuration";

/**
 * Generates a PDF file from the given input markdown file using Pandoc.
 * @param {string} inputFile - Path to the input markdown file.
 * @param {string} outputFile - Path for the output PDF file.
 * @param {DocuWriteConfig} config - Configuration object for DocuWrite.
 * @param {string} resourcePath - Resource path for Pandoc.
 */
export function generatePDF(
  inputFile: string,
  outputFile: string,
  config: DocuWriteConfig,
  resourcePath: string
): void {
  const outputDir = path.dirname(outputFile);
  const outputExt = path.extname(outputFile).toLowerCase();

  let command = `pandoc --verbose --pdf-engine=xelatex --toc --toc-depth=3 -o "${outputFile}" --resource-path="${resourcePath}" -V lot -V lof --number-sections -V links-as-notes -V geometry:margin=1in --top-level-division=chapter --wrap=none --extract-media=. "${inputFile}"`;

  if (outputExt !== ".pdf") {
    throw new Error(`Unsupported output format: ${outputExt}`);
  }

  console.log(`Executing Pandoc command: ${command}`);

  try {
    // Run Pandoc twice to resolve cross-references
    execSync(command, { stdio: "inherit", cwd: process.cwd() });
    execSync(command, { stdio: "inherit", cwd: process.cwd() });
    console.log(`Document generated successfully: ${outputFile}`);
  } catch (error) {
    console.error("Error generating document:", error);
    throw error;
  }
}
