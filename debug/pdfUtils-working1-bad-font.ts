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
  const outputDir = path.dirname(outputFile);
  const tempLatexFile = path.join(outputDir, "temp.tex");

  // Conversion: Markdown to LaTeX
  let command = `pandoc -s "${inputFile}" -o "${tempLatexFile}"`;
  command += ` --resource-path="${path.resolve(
    path.dirname(inputFile)
  )}:${path.resolve(resourcePath)}"`;
  command += ` --metadata title="Documentation"`;
  command += ` --pdf-engine=xelatex`;
  command += ` -V geometry:margin=${config.pdfOptions.pageMarginInches}in`;
  command += ` --standalone`;

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

  // Add LaTeX packages and options for better image and table handling
  command += ` -V header-includes="\
\\usepackage{float}\n\
\\usepackage{placeins}\n\
\\usepackage{booktabs}\n\
\\usepackage{longtable}\n\
\\usepackage{graphicx}\n\
\\usepackage{caption}\n\
\\usepackage{hyperref}\n\
\\usepackage{xcolor}\n\
\\usepackage{ulem}\n\
\\AtBeginDocument{\n\
  \\let\\origfigure\\figure\n\
  \\let\\endorigfigure\\endfigure\n\
  \\renewenvironment{figure}[1][2] {\n\
    \\expandafter\\origfigure\\expandafter[H]\n\
  } {\n\
    \\endorigfigure\n\
    \\FloatBarrier\n\
  }\n\
}\n\
\\setcounter{secnumdepth}{3}\n\
\\setcounter{tocdepth}{3}\n\
\\hypersetup{colorlinks=true,linkcolor=blue,urlcolor=blue}\n\
"`;

  console.log(`Executing Pandoc LaTeX command: ${command}`);
  execSync(command, { stdio: "inherit", cwd: outputDir });

  // Convert LaTeX to PDF
  command = `xelatex -interaction=nonstopmode -output-directory="${outputDir}" "${tempLatexFile}"`;

  console.log(`Executing XeLaTeX command: ${command}`);
  execSync(command, { stdio: "inherit", cwd: outputDir });

  // Run twice to ensure proper generation of ToC, LoF, and LoT
  execSync(command, { stdio: "inherit", cwd: outputDir });

  // Rename the output file
  fs.renameSync(path.join(outputDir, "temp.pdf"), outputFile);

  // Clean up temporary files
  // fs.unlinkSync(tempLatexFile);
  // fs.unlinkSync(path.join(outputDir, 'temp.aux'));
  // fs.unlinkSync(path.join(outputDir, 'temp.log'));
  // fs.unlinkSync(path.join(outputDir, 'temp.out'));
}
