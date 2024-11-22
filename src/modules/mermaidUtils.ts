/**
 * @file src/modules/mermaidUtils.ts
 * Handles the conversion of Mermaid diagrams to images using Puppeteer and processes Mermaid diagrams within markdown content.
 */
import puppeteer, { Browser } from "puppeteer";
import https from "https";

let browser: Browser | null = null;
let mermaidLibrary: string | null = null;

import path from "path";
import fs from "fs/promises";
import slugify from "slugify";
import {
  parseHeaders,
  findHeaderBeforePosition,
  Header,
} from "./headerUtils.js";
import { generateFileName } from "./commonUtils.js";
import { getMarkdownFiles, readMarkdownFile } from "./fileProcessing.js";

export interface Figure {
  figureNumber: number;
  startPos: number;
  endPos: number;
  diagramType: string;
  imageFile: string;
  createdOK: boolean;
  figureName: string;
  diagramTextBuffer: string;
}

/**
 * Downloads the Mermaid library from CDN.
 */
async function downloadMermaidLibrary(): Promise<void> {
  if (mermaidLibrary) return;

  const url = "https://cdn.jsdelivr.net/npm/mermaid@11.3.0/dist/mermaid.min.js";

  return new Promise((resolve, reject) => {
    https
      .get(url, (response) => {
        let data = "";
        response.on("data", (chunk) => (data += chunk));
        response.on("end", () => {
          mermaidLibrary = data;
          resolve();
        });
      })
      .on("error", reject);
  });
}

/**
 * Converts a Mermaid diagram to an image.
 * @param {string} mermaidCode - The Mermaid diagram code.
 * @param {string} pngFileName - Path to save the generated image.
 */
export async function convertMermaidToImage(
  mermaidCode: string,
  pngFileName: string,
  outputDir: string
): Promise<void> {
  await downloadMermaidLibrary();
  await initializeBrowser();

  const page = await browser!.newPage();

  const fullpathFile = path.join(outputDir, pngFileName);
  try {
    page.setDefaultTimeout(60000);

    await page.evaluate(mermaidLibrary!);

    await page.evaluate(() => {
      // @ts-ignore
      window.mermaid.initialize({
        startOnLoad: false,
        logLevel: "error",
      });
    });

    const svg = await page.evaluate((code) => {
      return new Promise((resolve, reject) => {
        // @ts-ignore
        window.mermaid
          .render("mermaid-svg", code)
          .then((result: { svg: string }) => resolve(result.svg))
          .catch((error: Error) => reject(error));
      });
    }, mermaidCode);

    await page.setContent(`
      <html>
        <head>
          <style>
            body { margin: 0; background-color: white; }
            .diagram-container { 
              display: inline-block; 
              padding: 10px; 
              border: 1px solid #ddd; 
            }
          </style>
        </head>
        <body>
          <div class="diagram-container">${svg}</div>
        </body>
      </html>
    `);

    await page.waitForSelector(".diagram-container svg", { timeout: 60000 });

    const boundingBox = await page.evaluate(() => {
      const container = document.querySelector(".diagram-container");
      return container ? container.getBoundingClientRect().toJSON() : null;
    });

    if (!boundingBox) {
      throw new Error("Could not get bounding box of diagram");
    }

    await page.setViewport({
      width: Math.ceil(boundingBox.width),
      height: Math.ceil(boundingBox.height),
      deviceScaleFactor: 2,
    });

    await page.screenshot({
      path: fullpathFile,
      clip: {
        x: 0,
        y: 0,
        width: Math.ceil(boundingBox.width),
        height: Math.ceil(boundingBox.height),
      },
    });
  } catch (error) {
    console.error("Error in convertMermaidToImage:", error);
    throw error;
  } finally {
    await page.close();
  }
}

/**
 * Closes the Puppeteer browser instance.
 */
export async function closeBrowser(): Promise<void> {
  if (browser) {
    await browser.close();
    browser = null;
  }
}

/**
 * Initializes the Puppeteer browser instance.
 */
async function initializeBrowser(): Promise<void> {
  if (!browser) {
    browser = await puppeteer.launch({
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    });
  }
}

/**
 * Processes a single markdown file, including Mermaid diagram conversion.
 * @param {string} filePath - Path to the markdown file.
 * @param {string} outputDir - Directory for output files.
 * @param {number} currentFigureCount - Current figure count.
 * @returns {Promise<{ processedContent: string; figures: Figure[] }>} Processed content of the markdown file.
 */
export async function processMarkdownFile(
  filePath: string,
  outputDir: string,
  currentFigureCount: number
): Promise<{ processedContent: string; figures: Figure[] }> {
  try {
    let content = await readMarkdownFile(filePath);
    content = preprocessMarkdown(content); // fix illegal stuff in the markdown
    const fileName = path.basename(filePath, ".md"); //remove file extension

    const { processedContent, figures } = await processMermaidDiagramsInContent(
      content,
      outputDir,
      fileName,
      currentFigureCount
    );

    return { processedContent, figures };
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") {
      console.error(`File not found: ${filePath}`);
      return { processedContent: "", figures: [] };
    }
    throw error;
  }
}

function defineFigureNameAndFilename(
  markdownFileName: string,
  figures: Figure[],
  headers: Header[]
): Figure[] {
  for (let i = 0; i < figures.length; i++) {
    const figure = figures[i];
    figure.figureName = findHeaderBeforePosition(headers, figure.startPos); // this returns the header name

    const imageFileName = generateFileName(
      markdownFileName,
      figure.figureNumber,
      figure.figureName
    );
    figure.imageFile = imageFileName;
  }
  return figures; // Add this line to return the modified figures array
}

/**
 * Processes Mermaid diagrams in the content, converting them to images and .mmd files.
 * @param {string} content - The markdown content.
 * @param {string} outputDir - Directory to save generated images and .mmd files.
 * @param {string} markdownFileName - Name of the markdown file.
 * @param {number} startingFigureNumber - Starting figure number.
 * @returns {Promise<{ processedContent: string; figures: Figure[] }>} Processed content with image references.
 */
export async function processMermaidDiagramsInContent(
  content: string,
  outputDir: string,
  fileName: string,
  startingFigureNumber: number
): Promise<{ processedContent: string; figures: Figure[] }> {
  let figures = findFigures(content);

  // if there are no figures, return the content and an empty array
  if (figures.length === 0) {
    return { processedContent: content, figures: [] };
  }

  const headers = parseHeaders(content);

  // now we have the figures and the headers. Lets set the figure name and generate a filename
  figures = defineFigureNameAndFilename(fileName, figures, headers);

  for (let i = 0; i < figures.length; i++) {
    const figure = figures[i];
    figure.figureNumber += startingFigureNumber;
    const imageFileName = figure.imageFile;

    try {
      await convertMermaidToFile(
        figure.diagramTextBuffer,
        figure.imageFile,
        outputDir
      );
      await convertMermaidToImage(
        figure.diagramTextBuffer,
        figure.imageFile,
        outputDir
      );
      figure.createdOK = true;

      const imageReference = `![${figure.figureName}](${imageFileName})`;
      //console.log("...", imageReference);

      const originalBlock = content.slice(figure.startPos, figure.endPos);
      const replacement = `\n\n${imageReference}\n`;
      content =
        content.slice(0, figure.startPos) +
        replacement +
        content.slice(figure.endPos);

      const positionDifference = replacement.length - originalBlock.length;
      for (let j = i + 1; j < figures.length; j++) {
        figures[j].startPos += positionDifference;
        figures[j].endPos += positionDifference;
      }

      //console.log(`Figure ${figure.figureNumber} - Position difference: ${positionDifference}`);
    } catch (error) {
      figure.createdOK = false;
      console.warn(
        `Warning: Unable to process diagram ${figure.figureNumber}. It will be left as-is in the document.`
      );
      console.debug(`Debug info for diagram ${figure.figureNumber}:`);
      console.debug(`Type: ${figure.diagramType}`);
      console.debug(`Content:\n${figure.diagramTextBuffer}`);
      console.debug(`Error:`, error);
    }
  }

  return { processedContent: content, figures };
}

/**
 * Converts Mermaid diagram content to a .mmd file.
 * @param {string} mermaidCode - The Mermaid diagram code.
 * @param {string} fullPathFile - The path where the image would be saved.
 * @returns {Promise<string>} The path of the created .mmd file.
 */
async function convertMermaidToFile(
  mermaidCode: string,
  fullPathFile: string,
  outputDir: string
): Promise<string> {
  const mmdPath = fullPathFile.replace(/\.[^/.]+$/, ".mmd"); //change the extension to .mmd
  const outputMermaidFile = path.join(outputDir, mmdPath);

  await fs.writeFile(outputMermaidFile, mermaidCode, "utf8");
  console.log(`Mermaid file created: ${mmdPath}`);
  return mmdPath;
}

/**
 * Finds all Mermaid diagrams in the content.
 * @param {string} content - The markdown content.
 * @returns {Figure[]} Array of found figures.
 */
function findFigures(content: string): Figure[] {
  const figureRegex =
    /(?:^|\n)[ \t]*(?::{3}|```|:::)mermaid[ \t]*\n([\s\S]*?)(?:\n[ \t]*(?::{3}|```|:::))/gm;
  const figures: Figure[] = [];
  let figureNumber = 0;
  let match;

  while ((match = figureRegex.exec(content)) !== null) {
    figureNumber++;
    const diagramContent = match[1];
    const diagramType = extractDiagramType(diagramContent);
    figures.push({
      figureNumber,
      startPos: match.index,
      endPos: match.index + match[0].length,
      diagramType,
      imageFile: "",
      createdOK: false,
      figureName: "",
      diagramTextBuffer: diagramContent,
    });
  }

  return figures;
}

/**
 * Extracts the diagram type from the Mermaid diagram content.
 * @param {string} content - The Mermaid diagram content.
 * @returns {string} The extracted diagram type.
 *
 * Note: Some diagram types have parameters, e.g., "graph TD;".
 * In such cases, only "graph" is returned as the diagram type.
 */
function extractDiagramType(content: string): string {
  const firstLine = content.trim().split("\n")[0];
  const firstWord = firstLine.trim().split(" ")[0];
  return firstWord.endsWith(";") ? firstWord.slice(0, -1) : firstWord;
}

/**
 * Preprocesses the markdown content by adding empty lines before and after headings.
 * @param {string} content - The markdown content.
 * @returns {string} The processed markdown content.
 */
function preprocessMarkdown(content: string): string {
  const lines = content.split("\n");
  const processedLines = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    const prevLine = i > 0 ? processedLines[processedLines.length - 1] : "";
    const nextLine = i < lines.length - 1 ? lines[i + 1].trim() : "";

    // If this is the first line and it's a heading, add an empty line before it
    if (i === 0 && line.match(/^#+\s/)) {
      processedLines.push("");
    }

    // If the current line is a heading and it's not preceded by an empty line
    if (line.match(/^#+\s/) && prevLine !== "") {
      processedLines.push(""); // Add an empty line before the heading
    }

    // Add the current line
    processedLines.push(line);

    // If the current line is a heading and the next line is not empty
    if (line.match(/^#+\s/) && nextLine !== "") {
      processedLines.push(""); // Add an empty line after the heading
    }
  }

  return processedLines.join("\n");
}