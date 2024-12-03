import path from 'path';
import { promises as fs } from 'fs';
import { convertMarkdownToHtml } from '../../../src/cli/typescript/commands/markdownToHtml';

const TEST_DIR = path.join(__dirname, '../fixtures');

describe('markdownToHtml Converter', () => {
  beforeAll(async () => {
    // Create test directory if it doesn't exist
    await fs.mkdir(TEST_DIR, { recursive: true });
    
    // Create test markdown file
    await fs.writeFile(
      path.join(TEST_DIR, 'test.md'),
      '# Test Document\n\nThis is a test.'
    );
  });

  afterAll(async () => {
    // Cleanup test files
    await fs.rm(TEST_DIR, { recursive: true, force: true });
  });

  it('should convert markdown to HTML', async () => {
    const inputFile = path.join(TEST_DIR, 'test.md');
    const outputFile = path.join(TEST_DIR, 'test.html');

    await convertMarkdownToHtml({
      input: inputFile,
      output: outputFile,
      title: 'Test Document'
    });

    // Verify output file exists
    const outputExists = await fs.access(outputFile)
      .then(() => true)
      .catch(() => false);
    
    expect(outputExists).toBe(true);

    // Verify content
    const content = await fs.readFile(outputFile, 'utf8');
    expect(content).toContain('<h1');
    expect(content).toContain('Test Document');
  });

  it('should handle missing input file', async () => {
    await expect(convertMarkdownToHtml({
      input: 'nonexistent.md',
      output: 'output.html'
    })).rejects.toThrow();
  });
});