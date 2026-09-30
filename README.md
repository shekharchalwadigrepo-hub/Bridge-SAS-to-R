# SAS ↔ R Learner Guide

Interactive Shiny app for SAS programmers learning R.

- Learner guide (mindset, DATA step, joins, summaries, models, macros, pitfalls)
- Instant **SAS → R** and **R → SAS** teaching converter
- Procedure map for the 25+ PROCs you actually rewrite
- Side-by-side example gallery

The converter is **heuristic**. It is built to teach common patterns, not to compile arbitrary SAS or reconstruct production programs line-by-line.

## Screenshot of what you get

| Tab | Purpose |
| --- | --- |
| Home | How to use the app |
| Guide | Concept lessons with SAS / R pairs |
| Converter | Paste code, convert both directions |
| Procedure map | SAS PROC → R function |
| Examples | 20 ready-made translations |
| GitHub | Commands to publish this repo |

## Requirements

- R 4.1 or newer
- Packages: `shiny`, `htmltools`
- Optional: `DT` (searchable procedure map), `tidyverse`, `haven`

```r
install.packages(c("shiny", "htmltools", "DT", "tidyverse", "haven"))
```

## Run locally

```r
# from the repo root
shiny::runApp()
```

Or open `app.R` in RStudio / Positron and click **Run App**.

## Create a new GitHub repository from this folder

**Recommended repo name:** `sas2r-guide`  
**Full click-by-click guide:** [GITHUB_SETUP.md](GITHUB_SETUP.md)

Short version (GitHub repo must be **empty** — no README, no license, no .gitignore):

```bash
cd sas-to-r-learner
git remote add origin https://github.com/<YOUR-USER>/sas2r-guide.git
git push -u origin main
```

With GitHub CLI:

```bash
gh repo create sas2r-guide --public --source=. --remote=origin --push --description "Interactive SAS ↔ R learner guide with a teaching code converter (Shiny)"
```

## Project layout

```
sas-to-r-learner/
├── app.R              # Shiny UI + server
├── R/
│   ├── convert.R      # SAS ↔ R pattern converter
│   ├── examples.R     # gallery + procedure map data
│   └── guide.R        # lesson content
├── www/custom.css
├── DESCRIPTION
├── LICENSE            # MIT
└── README.md
```

## What the converter covers

**SAS → R**

- DATA step: `SET`, `WHERE`, `KEEP` / `DROP` / `RENAME`, assignments, simple `IF-THEN-ELSE`, `MERGE`
- `PROC MEANS` / `SUMMARY`, `FREQ`, `SORT`, `PRINT`, `CONTENTS`
- `PROC REG`, `GLM`, `LOGISTIC`, `UNIVARIATE`
- `PROC TRANSPOSE`, `IMPORT`, `EXPORT`, `SQL`, `SGPLOT`
- `LIBNAME`, `%LET`

**R → SAS**

- `read_csv` / `read.csv` / `read_sas` / `write_csv`
- `lm`, `glm(..., binomial)`, `aov`
- `table`, `count`, `ggplot` (point / line / hist / bar)
- `arrange`, `group_by` + `summarise`
- simple `filter` / `select` / `mutate` pipelines
- `summary`, `head`, `str` / `glimpse`

Unsupported on purpose: nested macro language, ODS OUTPUT datasets, `PROC MIXED` random syntax, DS2, CAS actions. Use the guide and rewrite those by intent.

## Deploy a live demo (optional)

```r
install.packages("rsconnect")
rsconnect::setAccountInfo(name = "...", token = "...", secret = "...")
rsconnect::deployApp()
```

## License

MIT. See [LICENSE](LICENSE).

## Acknowledgements

Mappings follow common public teaching sources used by SAS programmers moving to R, including tidyverse equivalents for DATA step verbs and the usual PROC → function pairs (`lm`, `glm`, `table`, `ggplot2`, `haven`).
