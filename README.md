# Figure 2 — laboratory exposures vs. recognized infections

Code and data for Figure 2 of:

> Okosun BO, Mughe HC, Essilfie EG, Yolandia JNE, Musongong JA, Oga E.
> *Laboratory Injuries and Occupational Health Risks: Causes and Prevention Strategies.*
> Laboratories, 2027.

**Figure 2.** "Reported laboratory exposures far outnumber recognized infections." Three panels, two national mandatory-reporting systems, plotted by the authors from published counts (Table S2). Compiled 11 November 2026. All source numbers are from public government reports.

```
figure2.R      draws the figure -> figures/figure2a.png, figure2b.png, figure2c.png
update_data.R  optional: parse a newly published report into data/
data/          the counts, as tidy CSV
```

## Run it

```r
install.packages(c("readr", "dplyr", "tidyr", "ggplot2", "ragg"))
source("figure2.R")
```

Three 600-dpi PNGs are written to `figures/`, which the script creates. The printed totals should read 1405 / 1207 / 5334 / 2, then 361 / 781 / 25 / 8, with panel C at N = 486 and 64.6% flagged.

**Font.** The journal specifies Palatino. The script takes the first of `Palatino`, `Palatino Linotype`, `Palatino LT Std`, `URW Palladio L`, `P052`, `TeX Gyre Pagella` that is installed, and warns if none is. macOS ships Palatino and Windows ships Palatino Linotype; on Linux install [TeX Gyre Pagella](https://ctan.org/pkg/tex-gyre-pagella), a free metric-compatible clone (`apt install texlive-fonts-extra` or `fonts-texgyre`).

## Keeping it current

`REPRODUCE_SUBMITTED <- TRUE` (the default) pins the figure to the published ranges: FSAP 2018–2024 and LINC 2016–2022. Set it to `FALSE` and the figure uses every year present in `data/`, so it extends itself as later years are added.

Data loading is remote-first: the script downloads `data/*.csv` from `DATA_URL`, caches the files in `cache/`, and falls back to the bundled copies when offline. Point `DATA_URL` at this repository's `raw.githubusercontent.com` path and anyone running `figure2.R` picks up new years without editing the script.

To add a year:

```r
source("update_data.R")
row <- fetch_fsap(2026)   # finds and parses the FSAP annual report PDF
append_fsap(row)          # writes to data/ only if the internal balances hold

linc_tables("https://www.canada.ca/...the CCDR article for the new year...")
```

`fetch_fsap()` prints every parsed number for checking and refuses to append unless registered + non-registered equals release reports, and the three other balances hold. It targets the 2020-onward wording of the "Theft, Loss, and Release of BSAT" section; 2018 and 2019 are worded differently and are already in `data/`. LINC publishes one CCDR article per year at an unpredictable URL and changes its table layout between issues, so `linc_tables()` prints the tables and the yearly row is added by hand rather than guessed at.

Always read a parsed row against the report before committing it.

## Data

| File | Rows | Contents |
|---|---|---|
| `fsap_annual.csv` | 2018–2025 | Release reports, registered/non-registered split, minimal-risk and occupational-exposure split, individuals given occupational health services, illnesses |
| `linc_annual.csv` | 2016–2024 | Active licences, confirmed exposure incidents, suspected and confirmed LAI **incidents**, exposed individuals (2023–) |
| `linc_occurrence.csv` | 2016–2024 | Occurrence-type citations, long format |
| `linc_period_totals.csv` | 2016–2022 | Pooled totals where LAIs are counted **per person** |
| `coding.csv` | 10 types | The behavior-dependent flag and control-failure mapping (Table S2 Part B) |

Two cautions that the structure of the data encodes:

1. **The two systems count different things.** FSAP counts people given *post-exposure* care; LINC counts people *exposed*. Their denominators are not comparable, and the manuscript does not pool them.
2. **LINC reports LAIs two ways.** For 2016–2022 the published person-level counts are 17 suspected and 8 confirmed; the incident-level counts for the same period are 15 and 10. Panel B uses the person-level figures, which is why `linc_period_totals.csv` exists separately. Person-level counts are not published after 2022, so any extended total switches to incidents and the axis label says so.

## Sources

**FSAP** — Annual Reports of the Federal Select Agent Program, 2018–2025, "Theft, Loss, and Release of BSAT". <https://www.selectagents.gov/resources/publications/index.htm>. Per-year URLs are in `source_url` in `fsap_annual.csv`.

**LINC** — Public Health Agency of Canada, *Canada Communicable Disease Report*:

- Balbontin N, Gauthier A, Abalos C, Davis AN, Lister M. Canadian laboratory incidents with human pathogens and toxins: an overview of reports, 2016–2022. *CCDR* 2024;50(5):144–52. [doi:10.14745/ccdr.v50i05a04](https://doi.org/10.14745/ccdr.v50i05a04)
- Nafees A, et al. Surveillance of laboratory exposures to human pathogens and toxins, Canada, 2023. *CCDR* 2025;51(1):16–25. [doi:10.14745/ccdr.v51i01a03](https://doi.org/10.14745/ccdr.v51i01a03)
- Tran EF, Gauthier A, Davis AN, Abalos C, Bonti-Ankomah S. Surveillance of laboratory exposures to human pathogens and toxins, Canada, 2024. *CCDR* 2025;51(10/11/12):401–12. [doi:10.14745/ccdr.v51i101112a04](https://doi.org/10.14745/ccdr.v51i101112a04)

## Licence

Code: MIT. The underlying counts are United States public-domain government works and Crown copyright (Canada), reproduced here with attribution.
