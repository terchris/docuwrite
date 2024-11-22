/**
 * @file src/modules/headerUtils.ts
 * Utility functions for parsing and working with Markdown headers.
 * This module provides functionality to extract headers from Markdown content
 * and find the nearest header before a given position in the document.
 */

/**
 * Represents a Markdown header with its level, text content, and position in the document.
 */
export interface Header {
  level: number;
  text: string;
  headerStartPosition: number; // Changed from 'position'
}

/**
 * Parses Markdown content and extracts valid headers.
 *
 * Valid headers in Markdown, according to the CommonMark spec:
 * 1. Start with 1-6 '#' characters followed by a space or a line ending.
 * 2. The '#' characters must be at the beginning of the line (ignoring up to 3 spaces of indentation).
 * 3. The header text continues until the end of the line.
 * 4. Trailing '#' characters are optional and ignored for parsing.
 *
 * @param content - The Markdown content to parse.
 * @returns An array of Header objects representing the valid headers found in the content.
 */
export function parseHeaders(content: string): Header[] {
  const lines = content.split("\n");
  const headers: Header[] = [];
  let position = 0;

  for (const line of lines) {
    const trimmedLine = line.trimStart();
    if (trimmedLine.startsWith("#")) {
      const match = trimmedLine.match(/^#{1,6}(?:[ \t]+|$)/);
      if (match) {
        const level = match[0].trim().length;
        const text = trimmedLine
          .slice(match[0].length)
          .replace(/#*$/, "")
          .trim();
        if (text.length > 0) {
          headers.push({ level, text, headerStartPosition: position });
        }
      }
    }
    position += line.length + 1; // +1 for the newline character
  }

  return headers;
}

/**
 * Finds the previous header before a given position in the document.
 *
 * Strategy:
 * 1. If the headers array is empty, return null.
 * 2. Iterate through the headers array from end to start.
 * 3. Find the first header with a position strictly less than the given position.
 * 4. If no such header is found (all headers are at or after the position), return "no header found".
 * 5. Return the found header.
 *
 * This approach ensures we find the header immediately before the given position,
 * handling edge cases like positions before all headers or after all headers.
 *
 * @param headers - An array of Header objects to search through.
 * @param position - The position in the document to search before.
 * @returns The previous Header text before the given position, or "no header found" if none found.
 */
export function findHeaderBeforePosition(
  headers: Header[],
  position: number
): string {
  for (let i = headers.length - 1; i >= 0; i--) {
    if (headers[i].headerStartPosition <= position) {
      return headers[i].text;
    }
  }
  return "no header found";
}