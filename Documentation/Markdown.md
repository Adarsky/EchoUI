# Chat Markdown

Messages and the reasoning sheet share a native SwiftUI renderer backed by Foundation's full Markdown parser. Supported formatting includes headings (ATX and Setext), bold, italic, strikethrough, inline code, fenced and indented code blocks, nested ordered/unordered lists, task lists, block quotes, thematic breaks, links (including references and autolinks), images, and tables with column alignment and empty cells/rows. Code blocks scroll horizontally and have a copy button; wide tables scroll within the message bubble. Images retain their place in the text sequence and use their description while loading or on failure.

Markdown is parsed as each transport batch appears, including during generation. Complete syntax is formatted immediately; unfinished inline delimiters remain literal until they form valid Markdown. Open code fences already render as code. The existing adaptive transport batching remains in place. Literal `\n` and `/n` sequences are preserved, including in code and URLs, and soft line breaks remain visible in chat.

Raw HTML is not executed or laid out as a web page. Math/LaTeX, Mermaid, and syntax highlighting are separate extensions and are not part of this renderer.

## Rendering costs

- Each message holds only its current parsed document and, when viewed, its reasoning document. Unchanged text never reparses, including appearance changes and scrolling.
- Appends reuse completed blocks and reparse the last two containers plus new text. This preserves list/quote continuations, Setext headings, tables, and open fences. Edits and documents containing reference definitions use a full parse so earlier references stay correct.
- SwiftUI receives stable block identities and equatable subviews. Text uses native layout without a web view, per-token fade tasks, or additional offscreen compositing layers.
- The optional fade setting applies only when inserting new blocks. It defaults off and respects Reduce Motion.
- Images are downsampled off the main actor to at most 1,200 pixels on their longest side; the decoded image cache is limited to 24 MB / 24 entries. Image loading does not delay text formatting.

A document with a single very long open paragraph, list, code fence, or reference definitions still needs to parse that container/document on each displayed batch. The optimization reduces repeated work; it does not make arbitrary documents constant cost. Reasoning is parsed only when its sheet reads it.

## Validation

`ChatMarkdownTests` covers block and inline formatting, task markers, escaped code and URLs, safe links, empty table rows, images, cache invalidation, model variants/edits, and equivalence between streaming character by character and fresh parsing. `MarkdownUITests` verifies formatted text while generation remains active and captures the real message row with a table and code block.

Run the reproducible parser benchmark from the repository root on macOS:

```sh
swiftc -O -module-cache-path /tmp/markdown-module-cache \
  FrontendAI/Features/Chat/Markdown/ChatMarkdownBlock.swift \
  FrontendAI/Features/Chat/Markdown/ChatMarkdownInline.swift \
  FrontendAI/Features/Chat/Markdown/ChatMarkdownParser.swift \
  FrontendAI/Features/Chat/Markdown/ChatMarkdownRenderer.swift \
  Scripts/MarkdownBenchmark.swift -o /tmp/markdown-benchmark
/tmp/markdown-benchmark
```

The workload appends 100 formatted paragraphs after a 200-paragraph history and compares incremental parsing with fully parsing the same source on every update. A local optimized run parsed 9,740 bytes versus 1,229,937 bytes (99.2% less), taking approximately 0.04 seconds versus 3.1 seconds. These are host parser measurements, not device CPU/GPU or battery measurements; timings vary by hardware and build configuration.
