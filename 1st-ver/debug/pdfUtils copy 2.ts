/**
 * @file src/modules/pdfUtils.ts
 * @description Utility functions for PDF generation using Pandoc.
 * This module provides functionality to generate PDF and other document formats
 * from Markdown files using Pandoc. It includes options for customizing the output,
 * such as including table of contents, list of tables, and list of figures.
 *
 * @requires path
 * @requires child_process
 * @requires ./configuration
 */

import path from "path";
import { execSync } from "child_process";
import { DocuWriteConfig } from "./configuration";

/**
 * Generates a document file from the given input markdown file using Pandoc.
 * @param {string} inputFile - Path to the input markdown file.
 * @param {string} outputFile - Path for the output document file.
 * @param {DocuWriteConfig} config - Configuration object for DocuWrite.
 * @param {string} resourcePath - Resource path for Pandoc.
 */
export function generatePDF(
  inputFile: string,
  outputFile: string,
  config: DocuWriteConfig,
  resourcePath: string
): void {
  const outputExt = path.extname(outputFile).toLowerCase();
  const inputDir = path.dirname(inputFile);

  let command = `pandoc -o "${outputFile}"`;

  // Set the working directory to the input file's directory
  //ORG: command += ` --resource-path="${inputDir}:${resourcePath}"`;
  command += ` --resource-path="${path.resolve(inputDir)}:${path.resolve(
    resourcePath
  )}"`; //from test 1

  // Add PDF-specific options
  if (outputExt === ".pdf") {
    //ORG: command += " --pdf-engine=xelatex";
    command += " --pdf-engine=pdflatex"; // from test 4
    command += ` -V geometry:margin=${config.pdfOptions.pageMarginInches}in`;
    command += " --variable=graphics --standalone"; // Ensure images are included
  }

  // Add common options based on config
  if (config.pdfOptions.includeTableOfContents) {
    command += " --toc";
    command += ` --toc-depth=${config.pdfOptions.maxHeaderLevel}`;
  }
  if (config.pdfOptions.includeListOfTables) {
    command += " -V lot";
  }
  if (config.pdfOptions.includeListOfFigures) {
    command += " -V lof";
  }
  if (config.pdfOptions.numberSections) {
    command += " --number-sections";
  }

  // Ensure proper handling of images
  command += ` --wrap=preserve`;

  command += " --extract-media=."; // from test 3

  // Add input file at the end
  command += ` "${inputFile}"`;

  console.log(`Executing Pandoc command: ${command}`);

  try {
    //ORG: execSync(command, { stdio: "inherit", cwd: process.cwd() });
    execSync(command, { stdio: "inherit", cwd: path.resolve(resourcePath) }); // from test 2
    console.log(`Document generated successfully: ${outputFile}`);
  } catch (error) {
    console.error("Error generating document:", error);
    throw error;
  }
}
