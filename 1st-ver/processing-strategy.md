# DocuWrite change on how to create the PDF documentation

We are going to change the strategy for creating the PDF documentation. The new approach will split the process into two main parts: preprocessing and PDF creation.

a) Analyze the current process that is done by builddoc.sh
b) Analyze the example code for creating images from mermaid figures written in typescript in the src folder

## Preprocessing

Mermaid Conversion in typescript:

- convert mermaid figures to images (see mermaid-converter.ts)
- replace mermaid code blocks in markdown with image references (extend mermaid-processor.ts to do this)
  - The figures does not have a name so we must use the previous heading in the markdown file to create an id for the figure. We will use the following convention: <markdown filename>-<number eg 01>-<heading text stripped of special characters and spaces and lowercased>
  - The filenames can the be uses as references to the figures in the markdown file.

## PDF creation

- Use pandoc as we have done in builddoc.sh to create the pdf.

-------------- First step finished --------------

c) Future support for external diagram integration:

- Support for integration of diagrams from tools like draw.io
- Implement export and conversion processes for these formats

d) Markdown Enhancement:

- Process custom syntax or annotations in Markdown
- Handle cross-references and link conversions
- Prepare content for LaTeX-specific features (e.g., footnotes, citations)

e) TypeScript Implementation:

- Develop modular, type-safe preprocessing scripts
- Utilize TypeScript's latest features for efficient processing
- Implement error handling and logging

## 2. PDF Creation

The PDF creation stage will continue to use LaTeX for high-quality typesetting, leveraging its superior capabilities in creating professional documents. This stage involves:

- Converting preprocessed Markdown to LaTeX
- Applying LaTeX templates and styles
- Generating the final PDF output

Key points:

a) Markdown to LaTeX Conversion:

- Use Pandoc as the primary tool for converting Markdown to LaTeX
- Implement custom Pandoc filters (in TypeScript) for specialized processing

b) LaTeX Template:

- Develop a customized LaTeX template to define document structure and style
- Include packages for handling images, cross-references, and special content types

c) PDF Generation:

- Use XeLaTeX or LuaLaTeX for improved Unicode and font support
- Implement a build process that handles temporary files and output management

d) Quality Assurance:

- Implement checks for LaTeX compilation errors and warnings
- Validate the final PDF for formatting and content integrity

## Integration and Workflow

1. Develop a main TypeScript script to orchestrate the entire process:

   - Run all preprocessing steps
   - Trigger Pandoc conversion
   - Execute LaTeX compilation

2. Use devcontainer functionality for development:
   - Include all necessary tools (Node.js, TypeScript, Pandoc, LaTeX)
   - Set up appropriate volumes for input and output

By adopting this two-stage approach with TypeScript preprocessing and LaTeX-based PDF creation, we aim to create a flexible, maintainable, and powerful documentation system that produces high-quality output while accommodating a wide range of input formats and styling requirements.
