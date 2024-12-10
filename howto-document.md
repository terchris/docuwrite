# HOWTO Write documentation

This is how we write the documentation.

Documentation is split up in sevaral [Markdown files](https://guides.github.com/features/mastering-markdown/). Each file is a chapter in the documentation.
The fantastic thing about Markdown is that it is easy to write and easy to read. It is also easy to convert to other formats like HTML, PDF, and Word.

Diagrams are text. We use [Mermaid](https://mermaid-js.github.io/mermaid/#/) to create diagrams. Mermaid is a simple markdown-like script language for generating charts that is visible in the markdown editor. This makes it easy to maintain the documentation and the diagrams in the same file.

Azure DevOps has a built-in wiki that supports markdown and you can read about it here [Azure DevOps Wiki support for Mermaid](https://learn.microsoft.com/en-us/azure/devops/project/wiki/markdown-guidance?view=azure-devops#add-mermaid-diagrams-to-a-wiki-page).

## howto create diagrams

We use [mermaid](https://mermaid-js.github.io/mermaid/#/) to make diagrams.
The diagrams are defined in markdown files and rendered by the mermaid plugin in the markdown editor. This makes it possible to define diagrams in the same file as the text that describes the diagram. We follow the guide defined by [Diagram Guide by kubernetes community](https://kubernetes.io/docs/contribute/style/diagram-guide/).

* Why use mermaid? Because it is easy to use and it is rendered in the markdown editor.
* Why use mermaid? Because documentation and diagrams are in the same file. And they are versioned together (git).
* Why not use draw.io? Because it is not rendered in the markdown editor and you need to use a separate program to maintain the diagram.
* Why not use powerpoint? Because it is not rendered in the markdown editor and you need to use a separate program to maintain the diagram.

**Important** In Azure DevOps the notation is `:::` but in the free world it is ``` Our doc is in DevOps so you must use the ::: notation.

### KISS - Keep It Simple Stupid

Keep the diagrams simple. Use the same style for all diagrams.
Use the mermaid live editor to create the diagrams. It is easier to create the diagrams in the live editor and then copy the code to the markdown file.
You find the mermaid live editor at [mermaid live editor](https://mermaid.live). You can [find the full documentation here](https://mermaid.js.org/intro/). If you use vscode as your editor you can view the diagrams in the preview mode.

If you want to dep dive and see how it compares to other tools [read the mermaid.js: A Complete Guide](https://swimm.io/learn/mermaid-js/mermaid-js-a-complete-guide)

### Example 1

:::mermaid
graph TD
  A[Hard edges] -->|Link text| B(Round edge)
  B --> C{Decision}
  C -->|One| D[Result one]
  C -->|Two| E[Result two]
:::

The diagram above is created from this text:

```text
graph TD
  A[Hard edges] -->|Link text| B(Round edge)
  B --> C{Decision}
  C -->|One| D[Result one]
  C -->|Two| E[Result two]
```

### Example 2

:::mermaid
graph LR;
 client([client])-. Ingress-managed <br> load balancer .->ingress[Ingress];
 ingress-->|routing rule|service[Service];
 subgraph cluster
 ingress;
 service-->pod1[Pod];
 service-->pod2[Pod];
 end
 classDef plain fill:#ddd,stroke:#fff,stroke-width:4px,color:#000;
 classDef k8s fill:#326ce5,stroke:#fff,stroke-width:4px,color:#fff;
 classDef cluster fill:#fff,stroke:#bbb,stroke-width:2px,color:#326ce5;
 class ingress,service,pod1,pod2 k8s;
 class client plain;
 class cluster cluster;
:::

The text that creates the diagram above is:

```text
graph LR;
 client([client])-. Ingress-managed <br> load balancer .->ingress[Ingress];
 ingress-->|routing rule|service[Service];
 subgraph cluster
 ingress;
 service-->pod1[Pod];
 service-->pod2[Pod];
 end
 classDef plain fill:#ddd,stroke:#fff,stroke-width:4px,color:#000;
 classDef k8s fill:#326ce5,stroke:#fff,stroke-width:4px,color:#fff;
 classDef cluster fill:#fff,stroke:#bbb,stroke-width:2px,color:#326ce5;
 class ingress,service,pod1,pod2 k8s;
 class client plain;
 class cluster cluster;
```

## howto edit Wiki in Visual Studio Code

It is possible to edit Azure DevOps wiki pages using Visual Studio Code (VSCode). This can make editing more efficient, especially if you prefer VSCode's editing environment, extensions, and tools. Here’s how you can set it up and start editing your wiki pages in VSCode:

* Step 1: Clone the Wiki Repository

Azure DevOps wikis are backed by a Git repository, making them easy to clone and edit locally.

Navigate to your Wiki in Azure DevOps: Go to the Wiki section of your Azure DevOps project.
Find the Clone URL: In the Wiki section, there should be an option to clone the wiki. Copy the URL provided.
Clone using VSCode:
Open VSCode.
Open the Command Palette (Ctrl+Shift+P or Cmd+Shift+P on macOS).
Type Git: Clone and paste the URL you copied.
Select the local directory where you want to clone the wiki repository.

* Step 2: Edit the Wiki Pages

Once the wiki is cloned, you can navigate through the folder structure in VSCode. Wiki pages are usually markdown files (.md), so you can open and edit them as you would with any markdown document in VSCode.

* Step 3: Commit and Push Changes

After editing the wiki pages, you need to commit and push your changes back to the Azure DevOps repository for them to be reflected in the online wiki.

Commit your changes:
Open the Source Control view in VSCode (the branch icon on the left panel).
Stage your changes by clicking on the + icon next to the edited files.
Enter a commit message and press Ctrl+Enter (or Cmd+Enter on macOS) to commit the changes locally.
Push your changes:
Click on the three dots in the Source Control view and select Push to push your changes to Azure DevOps.

* Step 4: Sync Changes

If multiple people are editing the wiki, ensure you pull the latest changes before starting your editing session to minimize merge conflicts. You can do this from the Source Control view in VSCode by pulling from the repository.

* Additional Tips

Use Extensions: Enhance your markdown editing experience in VSCode by installing extensions like "Markdown All in One" or "MarkdownLint" for better linting and productivity features.
Preview Changes: VSCode allows you to preview Markdown files with a live preview window (Ctrl+Shift+V or Cmd+Shift+V on macOS), which can be very useful when editing wiki pages.
By using VSCode, you can leverage a more powerful editor for managing your Azure DevOps wiki pages, along with the comfort and familiarity of your local development environment.

## howto output one PDF that contains all the documentation

The documentation is split up in several markdown files. This is great for maintaining the documentation. But sometimes you need to have the documentation in one file. To create one PDF that contains all the documentation you need to merge the markdown files into one file and then convert it to PDF.

