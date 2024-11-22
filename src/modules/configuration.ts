// src/modules/configuration.ts

/**
 * @file src/modules/configuration.ts
 * Handles configuration parsing and management for DocuWrite.
 */

import yargs from "yargs";
import { hideBin } from "yargs/helpers";

export interface DocuWriteConfig {
  inputDir: string;
  outputDir: string;
  outputFile: string;
  orderFile: string;
  title?: string;
  sourceUrl?: string;
  message?: string;
  todoMessage?: string;
  ignoreMermaidErrors: boolean;
  pdfOptions: {
    includeTableOfContents: boolean;
    includeListOfTables: boolean;
    includeListOfFigures: boolean;
    numberSections: boolean;
    pageMarginInches: number;
    maxHeaderLevel: number;
  };
}

interface YargsOutput {
  [x: string]: unknown;
  input: string;
  outputDir: string;
  output: string;
  order: string;
  title?: string;
  sourceUrl?: string;
  message?: string;
  todoMessage?: string;
  ignoreMermaidErrors: boolean;
  includeTableOfContents: boolean;
  includeListOfTables: boolean;
  includeListOfFigures: boolean;
  numberSections: boolean;
  pageMarginInches: number;
  maxHeaderLevel: number;
}

/**
 * Parses command-line arguments using yargs.
 * @returns {YargsOutput} Parsed command-line arguments.
 */
function parseArguments(): YargsOutput {
  return (
    yargs(hideBin(process.argv))
      .option("input", {
        alias: "i",
        type: "string",
        description: "Input directory containing markdown files",
        demandOption: true,
      })
      .option("outputDir", {
        type: "string",
        description: "Output directory for intermediate files",
        default: "./output",
      })
      .option("output", {
        alias: "o",
        type: "string",
        description: "Output PDF file path",
        default: "./output.pdf",
      })
      .option("order", {
        type: "string",
        description: "Order file name",
        default: ".order",
      })
      .option("title", {
        type: "string",
        description: "Document title",
      })
      .option("sourceUrl", {
        type: "string",
        description: "Document source URL",
      })
      .option("message", {
        type: "string",
        description: "Custom message to include in the document",
      })
      .option("todoMessage", {
        type: "string",
        description: "Custom message for the TODO list",
      })
      .option("ignoreMermaidErrors", {
        type: "boolean",
        description: "Ignore Mermaid syntax errors and continue processing",
        default: false,
      })
      // New PDF-specific options
      .option("includeTableOfContents", {
        type: "boolean",
        description: "Include table of contents in the PDF",
        default: true,
      })
      .option("includeListOfTables", {
        type: "boolean",
        description: "Include list of tables in the PDF",
        default: true,
      })
      .option("includeListOfFigures", {
        type: "boolean",
        description: "Include list of figures in the PDF",
        default: true,
      })
      .option("numberSections", {
        type: "boolean",
        description: "Number sections in the PDF",
        default: true,
      })
      .option("pageMarginInches", {
        type: "number",
        description: "Page margin in inches",
        default: 1,
      })
      .option("maxHeaderLevel", {
        type: "number",
        description: "Maximum header level for table of contents",
        default: 3,
      })
      .help()
      .alias("help", "h")
      .parseSync() as YargsOutput
  );
}

/**
 * Retrieves the configuration for DocuWrite.
 * @returns {DocuWriteConfig} Configuration object for DocuWrite.
 */
export function getConfig(): DocuWriteConfig {
  const args = parseArguments();
  return {
    inputDir: args.input,
    outputDir: args.outputDir,
    outputFile: args.output,
    orderFile: args.order,
    title: args.title,
    sourceUrl: args.sourceUrl,
    message: args.message,
    todoMessage: args.todoMessage,
    ignoreMermaidErrors: args.ignoreMermaidErrors,
    pdfOptions: {
      includeTableOfContents: args.includeTableOfContents,
      includeListOfTables: args.includeListOfTables,
      includeListOfFigures: args.includeListOfFigures,
      numberSections: args.numberSections,
      pageMarginInches: args.pageMarginInches,
      maxHeaderLevel: args.maxHeaderLevel,
    },
  };
}