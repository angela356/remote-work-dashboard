# Remote Work in Europe — Productivity & Well-being

Interactive dashboard for the Data Visualization project (D1 Group 19). It asks whether working from home trades well-being against productivity, combining eight European data sources.

**Version B — guided story.** Eight chapters in a fixed order with Previous/Next controls and a progress bar (arrow keys also work); every other view sits under the Explore menu.

## Publishing (GitHub Pages)

Upload the contents of this folder to the root of the repository: `index.html`, the whole `data/` folder and this README. In *Settings → Pages* choose *Deploy from a branch*, branch `main`, folder `/ (root)`. The site is plain HTML and JavaScript: there is no build step.

The map needs `data/europe.json` (country boundaries) and `data/centroids.json` (country labels). It draws everything from these two files and uses no external map tiles, so no API key is required. If the map area stays empty, check that both files are present in `data/` under exactly these names.

## Data sources

| Source | Content | Unit |
|---|---|---|
| Eurostat LFSA_EHOMP | Share of employed people working from home, 1992–2025 | Country × year × group |
| Eurofound EWCS 2015, EWCTS 2021, EWCS 2024 | WHO-5 well-being, burnout, stress, work–life items, hours | Individual (survey-weighted) |
| R-MAP (Scientific Data) | Remote/office hours, perceptions, commute | Individual (self-selected) |
| Health Impact 2025 | Work arrangement, burnout, mental health, salary | Individual (convenience sample) |
| Eurostat ICT (isoc_ci_mvis, isoc_ci_ras) | Remote meetings and remote access by firm size | Enterprise aggregates |
| IoT Analytics, *State of IoT* | Global connected devices, 2015–2025 | Global year |

Only aggregates are published in `data/`; no individual survey record leaves the analysis environment.

## Indices

All indices run from 0 to 100, with higher always meaning better. Each item is rescaled to 0–100 according to its actual coding in the source file, oriented so that higher is better, and items are averaged with equal weights.

- **Productivity (P).** R-MAP: reversed item "I feel less productive while working remotely". EWCTS 2021: work engagement plus two work–life interference items (worrying about work, difficulty concentrating). EWCS 2024: stress plus two work–life interference items (worrying about work, too tired after work). The 2021 and 2024 indices use different components, so levels are not comparable across waves.
- **Well-being (W).** Eurofound: the WHO-5 index. R-MAP: personal-life impact, work–life balance and remote-work challenges.
- **Composite (C) = (P + W) / 2.** Exploratory only.

Coding note: in EWCS 2024 the frequency items (stress, work–life items and home-working frequency) run from 1 = Always to 5 = Never, the reverse of EWCTS 2021. The scripts align them before any index is built.

## Reproducibility

`scripts/rmap_fix.R` rebuilds every R-MAP-derived file. `scripts/indices.R` rebuilds the index files. Place the original data files in a folder named `raw_data/` next to `data/`, then run both scripts from the repository root.

## Repository structure

```
index.html      the dashboard (HTML, CSS and JavaScript in one file)
data/           66 pre-aggregated JSON files, plus europe.json and centroids.json for the map
scripts/        R scripts for the R-MAP files and the productivity/well-being indices
```
