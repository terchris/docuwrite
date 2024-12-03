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
import fs from "fs";

interface PandocCommandParams {
  pdfEngine: string;
  geometry: string;
  standalone: boolean;
  tableOfContents: boolean;
  tocDepth: number;
  listOfTables: boolean;
  listOfFigures: boolean;
  numberSections: boolean;
  headerIncludes: string[];
  markdownExtensions?: string[];
}

export function readPandocCommandParams(): PandocCommandParams {
  const filePath = path.join(process.cwd(), "src", "pandoccommandparams.json");

  try {
    const fileContent = fs.readFileSync(filePath, "utf-8");
    return JSON.parse(fileContent) as PandocCommandParams;
  } catch (error) {
    console.error(`Error reading Pandoc command params: ${error}`);
    // Return default values if file reading fails
    return {
      pdfEngine: "xelatex",
      geometry: "margin=1in",
      standalone: true,
      tableOfContents: true,
      tocDepth: 3,
      listOfTables: true,
      listOfFigures: true,
      numberSections: true,
      headerIncludes: [],
      markdownExtensions: [], // Add this line
    };
  }
}

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
  const params = readPandocCommandParams();
  const outputDir = path.dirname(outputFile);
  const tempLatexFile = path.join(outputDir, "temp.tex");

  let command = `pandoc -s "${inputFile}" -o "${tempLatexFile}"`;
  command += ` --resource-path="${path.resolve(
    path.dirname(inputFile)
  )}:${path.resolve(resourcePath)}"`;
  command += ` --metadata title="Documentation"`;
  command += ` --pdf-engine=${params.pdfEngine}`;
  command += ` -V geometry:${params.geometry}`;

  if (params.standalone) command += ` --standalone`;
  if (params.tableOfContents) {
    command += " --toc";
    command += ` --toc-depth=${params.tocDepth}`;
  }
  if (params.listOfTables) command += " -V lot";
  if (params.listOfFigures) command += " -V lof";
  if (params.numberSections) command += " --number-sections";

  if (params.markdownExtensions && params.markdownExtensions.length > 0) {
    command += ` ${params.markdownExtensions
      .map((ext) => `--from=markdown${ext}`)
      .join(" ")}`;
  }

  if (params.headerIncludes && params.headerIncludes.length > 0) {
    const headerIncludes = params.headerIncludes.join("\n");
    command += ` -V header-includes="${headerIncludes}"`;
  }

  console.log(`Executing Pandoc LaTeX command: ${command}`);
  execSync(command, { stdio: "inherit", cwd: outputDir });

  // Convert LaTeX to PDF
  const latexCommand = `${params.pdfEngine} -interaction=nonstopmode -halt-on-error -output-directory="${outputDir}" "${tempLatexFile}"`;

  // Run LaTeX multiple times
  for (let i = 0; i < 3; i++) {
    console.log(`Executing LaTeX command (pass ${i + 1}): ${latexCommand}`);
    try {
      execSync(latexCommand, { stdio: "inherit", cwd: outputDir });
    } catch (error) {
      console.warn(
        `LaTeX pass ${i + 1} encountered non-critical errors. Continuing...`
      );
    }
  }

  // Rename the output file
  fs.renameSync(path.join(outputDir, "temp.pdf"), outputFile);

  // Clean up temporary files
  const filesToClean = [
    "temp.tex",
    "temp.aux",
    "temp.log",
    "temp.out",
    "temp.toc",
    "temp.lof",
    "temp.lot",
  ];
  filesToClean.forEach((file) => {
    const filePath = path.join(outputDir, file);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }
  });

  console.log(`PDF generated successfully: ${outputFile}`);
}
