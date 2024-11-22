/**
 * @file src/modules/fileProcessing.ts
 * Handles file reading, writing, and processing operations for DocuWrite.
 */

import fs from "fs/promises";
import path from "path";

/**
 * Reads and returns the content of a single markdown file.
 *
 * @param {string} filePath - The path to the markdown file.
 * @returns {Promise<string>} A promise that resolves to the content of the file.
 * @throws {Error} If the file cannot be read or doesn't exist.
 */
export async function readMarkdownFile(filePath: string): Promise<string> {
  try {
    const content = await fs.readFile(filePath, "utf-8");
    return content;
  } catch (error) {
    console.error(`Error reading file ${filePath}:`, error);
    throw new Error(`Failed to read file: ${filePath}`);
  }
}

/**
 * Retrieves an array of markdown file paths based on the given input.
 *
 * This function handles both single file and directory inputs:
 * - For a single file input, it returns an array with that file path.
 * - For a directory input, it checks for a '.order' file and processes files accordingly:
 *   - If a '.order' file exists, it returns file paths in the specified order.
 *   - If no '.order' file exists or can't be read, it returns all markdown files in alphabetical order.
 *
 * @param {string} input - The path to a file or directory to process.
 * @returns {Promise<string[]>} A promise that resolves to an array of file paths.
 *
 * @throws {Error} If the input is neither a file nor a directory.
 *
 * @example
 * // Single file
 * const files = await getMarkdownFiles('/path/to/file.md');
 * // Result: ['/path/to/file.md']
 *
 * @example
 * // Directory with .order file
 * const files = await getMarkdownFiles('/path/to/directory');
 * // Result: ['/path/to/directory/file1.md', '/path/to/directory/file2.md', ...]
 *
 * @example
 * // Directory without .order file
 * const files = await getMarkdownFiles('/path/to/directory');
 * // Result: ['/path/to/directory/a.md', '/path/to/directory/b.md', ...]
 */
export async function getMarkdownFiles(input: string): Promise<string[]> {
  try {
    const stats = await fs.stat(input);

    if (stats.isFile()) {
      console.log(`Single file specified: ${input}`);
      return [input];
    } else if (stats.isDirectory()) {
      const orderFilePath = path.join(input, ".order");
      try {
        const orderContent = await fs.readFile(orderFilePath, "utf-8");
        const fileOrder = orderContent
          .split("\n")
          .map((line) => line.trim())
          .filter((line) => line !== "");

        // Filter out non-existent files and return full paths
        const existingFiles = await Promise.all(
          fileOrder.map(async (file) => {
            const filePath = path.join(input, file);
            try {
              await fs.access(filePath);
              return filePath;
            } catch {
              console.warn(`File not found, skipping: ${file}`);
              return null;
            }
          })
        );

        const finalFileOrder = existingFiles.filter(
          (file): file is string => file !== null
        );
        //console.log("Valid files specified in .order file:", finalFileOrder);
        console.log(
          "Total files specified in .order file:",
          finalFileOrder.length
        );
        return finalFileOrder;
      } catch (error) {
        console.error(
          "Error reading .order file, processing all existing markdown files:",
          error
        );
        const files = await fs.readdir(input);
        const markdownFiles = files
          .filter((file) => file.endsWith(".md"))
          .sort((a, b) => a.localeCompare(b)) // Add this line for alphabetical sorting
          .map((file) => path.join(input, file));
        //console.log("Markdown files found in directory:", markdownFiles);
        console.log(
          "Total markdown files found in directory:",
          markdownFiles.length
        );
        return markdownFiles;
      }
    } else {
      throw new Error(`Input is neither a file nor a directory: ${input}`);
    }
  } catch (error) {
    console.error(`Error processing input ${input}:`, error);
    return [];
  }
}