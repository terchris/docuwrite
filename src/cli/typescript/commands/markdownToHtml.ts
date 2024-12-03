import { promises as fs } from 'fs';
import path from 'path';
import { spawn } from 'child_process';

interface ConversionOptions {
  input: string;
  output: string;
  style?: string;
  title?: string;
}

async function convertMarkdownToHtml(options: ConversionOptions): Promise<void> {
  try {
    // Verify input file exists
    await fs.access(options.input);
    
    // Prepare pandoc arguments
    const args = [
      options.input,
      '-o', options.output,
      '--standalone',
      '--metadata', `title:${options.title || 'Document'}`,
      '--template=default'
    ];

    if (options.style) {
      args.push('--css', options.style);
    }

    // Use pandoc from base image
    const pandoc = spawn('pandoc', args);

    return new Promise((resolve, reject) => {
      pandoc.stderr.on('data', (data) => {
        console.error(`Pandoc Error: ${data}`);
      });

      pandoc.on('close', (code) => {
        if (code === 0) {
          console.log(`Successfully converted ${options.input} to ${options.output}`);
          resolve();
        } else {
          reject(new Error(`Pandoc failed with code ${code}`));
        }
      });
    });
  } catch (error) {
    console.error('Conversion failed:', error);
    throw error;
  }
}

// CLI handler
async function main() {
  const args = process.argv.slice(2);
  const options: ConversionOptions = {
    input: '',
    output: ''
  };

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--input':
      case '-i':
        options.input = args[++i];
        break;
      case '--output':
      case '-o':
        options.output = args[++i];
        break;
      case '--style':
      case '-s':
        options.style = args[++i];
        break;
      case '--title':
      case '-t':
        options.title = args[++i];
        break;
      case '--help':
      case '-h':
        console.log(`
Usage: docuwrite-md2html [options]

Options:
  -i, --input <file>   Input markdown file
  -o, --output <file>  Output HTML file
  -s, --style <file>   CSS style file (optional)
  -t, --title <title>  Document title (optional)
  -h, --help           Show this help message
        `);
        process.exit(0);
    }
  }

  if (!options.input || !options.output) {
    console.error('Error: Input and output files are required');
    process.exit(1);
  }

  try {
    await convertMarkdownToHtml(options);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

export { convertMarkdownToHtml, ConversionOptions };