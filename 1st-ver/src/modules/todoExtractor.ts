// src/modules/todoExtractor.ts

/**
 * @file src/modules/todoExtractor.ts
 * Extracts and formats TODO items from markdown content.
 */

import {
  parseHeaders,
  findHeaderBeforePosition,
  Header,
} from "./headerUtils.js";

interface Todo {
  section: string;
  item: string;
}

/**
 * Extracts TODO items from the content.
 * @param {string} content - The markdown content.
 * @returns {Todo[]} Array of extracted TODO items.
 */
export function extractTodos(content: string): Todo[] {
  const todos: Todo[] = [];
  const lines = content.split("\n");
  const headers = parseHeaders(content);

  lines.forEach((line, index) => {
    const trimmedLine = line.trim();
    if (trimmedLine.toLowerCase().startsWith("todo:")) {
      const nearestHeader = findHeaderBeforePosition(headers, index);
      todos.push({
        section: nearestHeader,
        item: trimmedLine.substring(5).trim(),
      });
    }
  });

  return todos;
}

/**
 * Formats the extracted TODO items into a markdown table.
 * @param {Todo[]} todos - Array of TODO items.
 * @param {string} message - Custom message for the TODO list.
 * @returns {string} Formatted TODO list as a markdown table.
 */
export function formatTodoList(todos: Todo[], message: string): string {
  let todoList = `# TODO List\n\n${message}\n\n`;
  todoList += "| Section | TODO Item | Page |\n";
  todoList += "|---------|-----------|------|\n";

  todos.forEach((todo, index) => {
    const label = `todo-item-${index + 1}`;
    todoList += `| ${todo.section} | ${todo.item} | \\pageref{${label}} |\n`;
  });

  return todoList;
}

/**
 * Adds labels to TODO items in the content.
 * @param {string} content - The markdown content.
 * @param {Todo[]} todos - Array of TODO items.
 * @returns {string} Content with added labels for TODO items.
 */
export function addTodoLabels(content: string, todos: Todo[]): string {
  todos.forEach((todo, index) => {
    const label = `todo-item-${index + 1}`;
    const todoRegex = new RegExp(`(TODO:\\s*${escapeRegExp(todo.item)})`, "g");
    content = content.replace(todoRegex, `$1 \\label{${label}}`);
  });
  return content;
}

/**
 * Escapes special characters in a string for use in a regular expression.
 * @param {string} string - The string to escape.
 * @returns {string} The escaped string.
 */
function escapeRegExp(string: string) {
  return string.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}