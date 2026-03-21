# Product Guidelines

## Prose Style
Documentation and user messages should follow a **Tutorial-like** style. This means providing step-by-step instructions that are easy for both new and experienced users to follow, with clear examples of common commands and their expected outcomes.

## CLI & User Experience
The command-line interface must prioritize:
- **Pipe-friendliness (JSON/TSV):** Outputs should be structured in formats like TSV or JSON to allow for seamless integration with other UNIX-style tools and bioinformatics pipelines.
- **User-friendly Help:** Every command and script must provide clear, concise, and helpful descriptions when invoked without arguments or with `--help`.

## Robustness & Error Handling
Given the importance of reliability, the tool should implement a **Robust/Retry** strategy. When network issues or transient API failures occur, it should attempt to retry the download operation before reporting a final failure to the user.
