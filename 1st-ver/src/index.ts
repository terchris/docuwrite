/**
 * @file src/index.ts
 * Main entry point for the DocuWrite application.
 * Handles the overall process of generating documentation from markdown files.
 */

import path from "path";
import fs from "fs/promises";

import { DocuWriteConfig, getConfig } from "./modules/configuration.js";
import { getMarkdownFiles } from "./modules/fileProcessing.js";

import { processMarkdownFile, Figure } from "./modules/mermaidUtils.js";
import {
  extractTodos,
  formatTodoList,
  addTodoLabels,
} from "./modules/todoExtractor.js";

import { generatePDF } from "./modules/pdfUtils.js";
import { markTables } from "./modules/tableProcessor.js";

/**
 * Displays the conversion status of Mermaid diagrams.
 * @param {Figure[]} figures - Array of processed figures.
 */
function displayConversionStatus(figures: Figure[]) {
  const failedFigures = figures.filter((figure) => !figure.createdOK);

  if (failedFigures.length === 0) {
    console.log("\nAll Mermaid diagrams converted successfully.");
    console.log(`Total diagrams: ${figures.length}`);
    console.log("Diagram Types Summary:");
    const typeCounts = figures.reduce((acc, figure) => {
      acc[figure.diagramType] = (acc[figure.diagramType] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    Object.entries(typeCounts).forEach(([type, count]) => {
      console.log(`  ${type}: ${count}`);
    });

    return;
  }

  console.log("\nFailed Mermaid Diagram Conversions:");
  console.log("----------------------------------");
  failedFigures.forEach((figure) => {
    console.log(`Figure #${figure.figureNumber}: Failed`);
    console.log(`  Type: ${figure.diagramType}`);
    console.log(`  Name: ${figure.figureName}`);
    console.log(`  Image: ${figure.imageFile}`);
    console.log("----------------------------------");
  });

  console.log(`Total: ${figures.length}, Failed: ${failedFigures.length}`);
}

/**
 * Main function that orchestrates the document generation process.
 */
async function main() {
  try {
    const config = getConfig();
    const inputPath = path.resolve(process.cwd(), config.inputDir);
    const outputFile = path.resolve(process.cwd(), config.outputFile);
    const outputDir = path.resolve(process.cwd(), config.outputDir);

    // Empty the output folder
    await fs.rm(outputDir, { recursive: true, force: true });
    await fs.mkdir(outputDir, { recursive: true });

    console.log(`Output folder emptied and recreated: ${outputDir}`);

    const fileOrder = await getMarkdownFiles(inputPath);

    let mergedContent = "";
    const processedFiles: string[] = [];
    const skippedFiles: string[] = [];
    let allFigures: Figure[] = [];

    for (const filePath of fileOrder) {
      try {
        const { processedContent, figures } = await processMarkdownFile(
          filePath,
          config.outputDir,
          allFigures.length
        );

        mergedContent += processedContent;
        processedFiles.push(path.relative(inputPath, filePath));
        allFigures = allFigures.concat(figures);
      } catch (error) {
        console.error(`Error processing file ${filePath}:`, error);
        mergedContent += `# File: ${path.basename(
          filePath
        )}\n\nAn error occurred while processing this file.\n\n`;
        skippedFiles.push(path.relative(inputPath, filePath));
      }
    }

    if (mergedContent.trim() === "") {
      console.error("No content was successfully merged. Exiting.");
      process.exit(1);
    }

    const todos = extractTodos(mergedContent);
    mergedContent = addTodoLabels(mergedContent, todos);
    const todoList = formatTodoList(todos, config.todoMessage || "TODO List");

    // Append the TODO list to the end of the document
    mergedContent += "\n\n" + todoList;

    const tempFilePath = path.join(outputDir, "temp_processed.md");
    await fs.writeFile(tempFilePath, mergedContent, "utf-8");

    console.log(".");
    console.log(`Processed files: ${processedFiles.length}`);
    if (skippedFiles.length > 0) {
      console.log("Skipped files:");
      skippedFiles.forEach((file) => console.log(` - ${file}`));
    }
    console.log("---- Preparing Mermaid finished ----");

    displayConversionStatus(allFigures);

    const { processedContent: finalProcessed, tables } = await markTables(
      mergedContent
    );
    console.log(".");
    console.log(`Tables marked: ${tables.length}`);
    await fs.writeFile(tempFilePath, finalProcessed, "utf-8");

    console.log(".");
    console.log(`Generating PDF file: ${outputFile}`);
    await generatePDF(tempFilePath, outputFile, config, outputDir);
    console.log("---- PDF file generated ----");
  } catch (error) {
    console.error("Error in document generation:", error);
    process.exit(1);
  }
}

main();