# Introduction DocuWrite

Bifrost DocuWrite aims to solve the problem of outdated documentation by providing a way to create a PDF document from the Wiki you have created in Azure DevOps or any other collection of markdown files.
This ensures that the complete documentation is always up to date and can be shared with stakeholders who may not have access to the Wiki or just need a snapshot of the documentation at a certain point in time.

DocuWrite will create a professional looking PDF document from the Wiki (or Markdown files). The PDF document will have:


* Great looking table of contents
* All pages numbered and marked with date and time of generation
* PDF is fully searchable, making it easy to find information
* Appendix that list all TODOs in the document
* Appendix that list all figures in the document

DocuWrite ensures that the next project meeting everyone will not only have the document. They will have the same version of the document. And after the meeting you can tell them to delete the document so that they will have a fresh copy next time you meet.

## Getting Started

Check prerequisites first.

1) Clone the repository
   ```
   git clone https://github.com/your-repo/bifrost-docuwrite.git
   cd bifrost-docuwrite
   ```

2) Build the docker image
   ```
   ./docuwrite.sh build
   ```
    Once you have build the image you can run the container without building again.

3) Run the container on the test wiki documentation
   ```
   ./docuwrite.sh -i ./test-repo -d ./output.pdf -t "Test Document" -todo
   ```
    There is a folder called test-repo with a sample wiki you can use to test the script.

4) Check the result
   Open the generated `output.pdf` file to see the result.

## How to Use It on Your Wiki / Markdown Files

1. Prepare your markdown files in a directory.
    Check out your wiki in Azure DevOps (see how in [howto-document.md](./howto-document.md)).
2. (Optional) Create a `.order` file in the root of your directory to specify the order of the markdown files. If you dont have .order file then look in the .order file in the test-repo folder.
3. Run the DocuWrite script:
   ```
   ./docuwrite.sh -i /path/to/your/markdown/files -d /path/to/output.pdf [OPTIONS]
   ```

### Automatic TODO List

Just start a line with TODO: and Bifrost DocuWrite creates a nice looking TODO list appendix in the PDF document.

### Figures Using Mermaid

Read the [howto-document.md file](./howto-document.md) to learn how to use mermaid to create figures in your document.

## How to Use Parameters

The `docuwrite.sh` script supports several parameters:

- `build`: Build the Docker image before running
- `-i, --input`: Path to the input repository (required)
- `-d, --document`: Document name and path (optional, default: ./docuwrite-document.pdf)
- `-t, --title`: Document title (optional)
- `-u, --url`: Document source URL (optional)
- `-m, --message`: Document message (optional)
- `--todo-message`: TODO list message (optional)
- `--skip-mermaid`: Skip Mermaid diagram generation (optional)
- `-todo [<file>]`: Generate a separate TODO file (optional, default: ./todo.md)

Example:
```
./docuwrite.sh -i ./my-repo -d ./output.pdf -t "My Documentation" -todo
```

## How It Works

1. The `docuwrite.sh` script builds a Docker image (if necessary) and runs a container.
2. Inside the container, the `builddoc.sh` script:
   - Merges all markdown files into a single file
   - Extracts TODOs
   - Generates a PDF using Pandoc and LaTeX
   - Creates a separate TODO list file
3. The resulting PDF and TODO list are output to the specified directory.

## Prerequisites

You need to have Docker installed on your machine. Download it from [here](https://www.docker.com/products/docker-desktop/).

## Technologies

The application is a containerized application that can be run on any platform that supports Docker.
It uses the following technologies:

- Docker: For containerization and cross-platform compatibility
- Bash: For scripting and orchestration
- Node.js: As the base for the Docker image and for running mermaid-filter
- Pandoc: For converting Markdown to PDF
- LaTeX (TinyTeX): For PDF generation and styling
- Mermaid: For generating diagrams from text descriptions

## Future Feature Ideas

* Use git repository as input. No need to download the wiki/markdown files to a folder first.
* Push the PDF and the TODO list to the Wiki.
* Create a service that run every time a commit is made to the repository. The service will merge the markdown files and convert it to PDF. The PDF will be stored in the repository and can be downloaded from the repository.

## Contribute

The project is open source and we welcome contributions. Please submit pull requests or open issues on our GitHub repository.
