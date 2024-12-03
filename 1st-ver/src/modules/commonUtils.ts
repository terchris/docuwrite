import { Header, findHeaderBeforePosition } from "./headerUtils.js";
import slugify from "slugify";

/**
 * Generates a filename for a Mermaid diagram image.
 * @param {string} markdownFileName - Name of the markdown file.
 * @param {number} number - Figure number.
 * @param {string} headingText - Text of the nearest heading.
 * @returns {string} Generated filename.
 */
export function generateFileName(
  markdownFileName: string,
  number: number,
  headingText: string
): string {
  const sanitizedHeading = slugify(headingText, {
    lower: true,
    strict: true,
    replacement: "-", // Explicitly set replacement to hyphen
  });
  return `${markdownFileName}-${number
    .toString()
    .padStart(2, "0")}-${sanitizedHeading}.png`;
}