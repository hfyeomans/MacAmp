# Plan: Five-Window Documentation Guidance

## Goal
Produce actionable guidance for updating MacAmp documentation now that the Video and Milkdrop windows have shipped. Guidance must cover (a) where new content belongs, (b) detailed outlines for each doc change, and (c) what to add to the master docs index.

## Tasks

1. **Decide doc topology**
   - Evaluate whether VIDEO/MILKDROP need standalone docs or can live as sections.
   - Specify which existing docs gain new sections (Architecture Guide, Implementation Patterns, README).

2. **Draft outlines per deliverable**
   - Architecture Guide outline with subsections covering Video/Milkdrop architecture, updated diagrams, and NSWindowController pattern changes.
   - Implementation Patterns outline covering VIDEO.bmp sprite composition, GEN.bmp two-piece sprites, and AVPlayer integration.
   - Dedicated VIDEO_WINDOW.md + MILKDROP_WINDOW.md outlines to capture layout/sprite/focus/persistence details.

3. **Define README updates**
   - Provide bullets describing new stats/line counts to recalc, new doc entries, and search index keywords.

4. **Summarize for user**
   - Present doc topology decisions, outlines, and README instructions with references back to code sections.

