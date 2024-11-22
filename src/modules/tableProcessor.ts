import {
  parseHeaders,
  findHeaderBeforePosition,
  Header,
} from "./headerUtils.js";

export interface Table {
  tableNumber: number;
  startPos: number;
  endPos: number;
  tableName: string;
}

/**
 * Marks all tables in the content so that they can be picked op by pandoc.
 * Line over the table is marked like this:
 * Table: This is the table name
 *
 * As the tables are not given any names in markdown we find the first header before the table
 * and use that as the table name.
 *
 * It marks all tables in the content and returns the processed content and the list of tables.
 *
 * @param {string} content - The markdown content.
 * @returns {Promise<{ processedContent: string; tables: Table[] }>} Processed content with table captions.
 */
export async function markTables(
  content: string
): Promise<{ processedContent: string; tables: Table[] }> {
  const tableRegex =
    /(?:^|\n)((?:\|.+\|\r?\n)+)(?:\|[-:\| ]+\|\r?\n)((?:\|.+\|\r?\n)+)/gm;
  const headers = parseHeaders(content);
  const tables: Table[] = [];
  let tableNumber = 0;
  let lastIndex = 0;
  let processedContent = "";
  let match;

  while ((match = tableRegex.exec(content)) !== null) {
    tableNumber++;
    const tableName = findHeaderBeforePosition(headers, match.index);

    const table: Table = {
      tableNumber,
      startPos: match.index,
      endPos: match.index + match[0].length,
      tableName,
    };
    tables.push(table);

    const beforeTable = content.slice(lastIndex, match.index);
    const tableContent = match[0];
    const replacement = `
Table: ${tableName}

${tableContent}
`;

    processedContent += beforeTable + replacement;
    lastIndex = match.index + match[0].length;
  }

  processedContent += content.slice(lastIndex);

  return { processedContent, tables };
}