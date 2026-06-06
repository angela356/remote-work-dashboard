# Remote Work in Europe: Productivity & Well-being
### Interactive Web Dashboard — GitHub Pages

> *Data Visualization Project · D1 Group 19*

**Live:** `https://[your-username].github.io/[repo-name]/`

---

## Deploy in 3 steps

```bash
# 1. Create a new GitHub repo (e.g. "remote-work-dashboard")

# 2. Push this folder
git init
git add .
git commit -m "Initial dashboard"
git remote add origin https://github.com/YOUR_USERNAME/remote-work-dashboard.git
git push -u origin main

# 3. Enable GitHub Pages
# → Settings → Pages → Source: Deploy from branch → main / (root) → Save
# Your dashboard will be live at https://YOUR_USERNAME.github.io/remote-work-dashboard/
```

No server, no build step, no dependencies to install. Pure HTML + JS.

---

## Repository structure

```
/
├── index.html          ← The entire dashboard (HTML + JS + CSS)
├── data/               ← Pre-aggregated JSON files (~780 KB total)
│   ├── euro_trend.json          Eurostat: % WFH per country per year
│   ├── euro_eu.json             Eurostat: EU average trend
│   ├── euro_gender.json         Eurostat: by gender (latest year)
│   ├── euro_age.json            Eurostat: by age group (latest year)
│   ├── euro_freq.json           Eurostat: by frequency (latest year)
│   ├── euro_country_ts.json     Eurostat: full time series per country
│   ├── who5_waves.json          Eurofound: WHO-5 by WFH × wave
│   ├── who5_gender.json         Eurofound: WHO-5 by WFH × gender
│   ├── who5_sector.json         Eurofound: WHO-5 by WFH × NACE sector
│   ├── who5_country_sector.json Eurofound: WHO-5 by country × sector × WFH
│   ├── burnout.json             Eurofound EWCTS 2021: burnout by WFH
│   ├── stress_2024.json         Eurofound EWCS 2024: stress by WFH
│   ├── wfh_dist.json            Eurofound: WFH distribution across waves
│   ├── hours_waves.json         Eurofound: working hours across waves
│   ├── rmap_overall.json        R-MAP: overall Likert means
│   ├── rmap_sector.json         R-MAP: Likert by industry sector
│   ├── rmap_country.json        R-MAP: Likert by country
│   ├── rmap_gender.json         R-MAP: Likert by gender
│   ├── rmap_scatter.json        R-MAP: productivity × WLB by sector & % remote
│   ├── pct_remote_dist.json     R-MAP: distribution of % time remote
│   ├── commute_by_remote.json   R-MAP: commute time by remote intensity
│   ├── hi_arrangement.json      Health Impact 2025: outcomes by arrangement
│   ├── hi_burnout.json          Health Impact 2025: burnout by arrangement
│   ├── hi_mental.json           Health Impact 2025: mental health by arrangement
│   ├── hi_sector.json           Health Impact 2025: outcomes by sector
│   ├── hi_hours_dist.json       Health Impact 2025: hours distribution
│   └── centroids.json           Country centroids for map
└── README.md
```

---

## Dashboard tabs

| Tab | Content | Source |
|-----|---------|--------|
| **Overview** | EU trend, country ranking, gender gap, employment status | Eurostat |
| **Map** | Interactive bubble map — year, frequency, gender filters | Eurostat |
| **Well-being** | WHO-5 by WFH level, burnout, stress — filterable by wave, gender, sector | Eurofound |
| **Productivity** | Scatter prod × WLB, burnout/mental health/hours by arrangement | R-MAP + HI2025 |
| **Perceptions** | Likert items — split by gender, sector, country; commute savings | R-MAP |
| **Country Deep-Dive** | Full trend, freq/gender/age breakdown per country | Eurostat |
| **2015→2024** | Longitudinal: WHO-5 trend, distribution shift, hours, sector heatmap | Eurofound |
| **About** | Data sources, methodology, notes | — |

---

## Data sources

- **Eurostat LFSA_EHOMP** — Labour Force Survey, % employed working from home
- **R-MAP Project** (Horizon Europe 101132497) — N=20,959 survey respondents
- **Eurofound EWCS 2015** — N=43,850 (pre-COVID)
- **Eurofound EWCTS 2021** — N=71,758 (COVID peak)
- **Eurofound EWCS 2024** — N=36,644 (post-COVID)
- **Post-Pandemic Remote Work Health Impact 2025** — N=3,157

> Only aggregated statistics are included in the repository. No individual-level microdata is distributed.
