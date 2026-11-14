# -----------------------------------------------------------------------------
# Manuscript: Laboratory Injuries and Occupational Health Risks: Causes and
#             Prevention Strategies (Okosun et al., Laboratories 2027)
#
# Figure 2:   "Reported laboratory exposures far outnumber recognized
#             infections." Three panels, two national mandatory-reporting
#             systems, plotted by the authors from published counts (Table S2).
#
# Compiled:   11 November 2026
#             All source numbers are from  the U.S. Federal Select Agent Program
#             (FSAP) and the Laboratory Incident Notification Canada.
#
# Usage:      source("figure2.R")
#             Writes figure2a.png, figure2b.png, figure2c.png to figures/.
#
# Data:       data/*.csv. The script prefers a fresh copy from DATA_URL, falls
#             back to cache/, then to the bundled files, so it works offline
#             and picks up later years without edits. See update_data.R.
#
# Requires:   R >= 4.1, readr, dplyr, tidyr, ggplot2, ragg
# Licence:    MIT (code). Source counts are public domain / Crown copyright.
# -----------------------------------------------------------------------------
#install.packages(c("readxl","dplyr","tidyr","ggplot2","patchwork","scales"))
library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ragg)

# ---- settings ---------------------------------------------------------------

# TRUE  reproduces the submitted figure exactly (FSAP 2018-2024, LINC 2016-2022,
#       LAIs as published person counts).
# FALSE uses every year present in the data, so the figure extends itself as
#       later years are added. LAIs then count incidents, not people, because
#       person-level LAI counts are not published after 2022.
REPRODUCE_SUBMITTED <- TRUE

DATA_URL <- "https://raw.githubusercontent.com/USER/REPO/main/data"  # <- set this
OUT_DIR  <- "figures"
FONT     <- c("Palatino", "Palatino Linotype", "Palatino LT Std",
              "URW Palladio L", "P052", "TeX Gyre Pagella")  # journal: Palatino

PALETTE <- c(reports = "#9ECAE1", exposure = "#3182BD", assessed = "#08519C",
             illness = "#CB181D", linc_a   = "#FDD0A2", linc_b   = "#FD8D3C",
             linc_c  = "#E6550D", linc_d   = "#A63603", flag     = "#6A51A3",
             plain   = "#BDBDBD")

# ---- helpers ----------------------------------------------------------------

# First installed font from FONT, or "" (device default) with a warning.
pick_font <- function(candidates = FONT) {
  hit <- candidates[candidates %in% systemfonts::system_fonts()$family]
  if (length(hit)) return(hit[[1]])
  warning("No Palatino found (tried: ", paste(candidates, collapse = ", "),
          "). Using the device default. Install TeX Gyre Pagella, a free ",
          "metric-compatible clone, before submitting.", call. = FALSE)
  ""
}

# Fresh copy from DATA_URL, else cache/, else the bundled data/.
read_data <- function(name) {
  cached <- file.path("cache", name)
  if (!grepl("USER/REPO", DATA_URL, fixed = TRUE)) {
    tmp <- tempfile(fileext = ".csv")
    ok  <- tryCatch({
      download.file(paste(DATA_URL, name, sep = "/"), tmp, quiet = TRUE)
      file.size(tmp) > 0
    }, error = function(e) FALSE, warning = function(w) FALSE)
    if (ok) {                       # cache only a complete download
      dir.create("cache", showWarnings = FALSE)
      file.copy(tmp, cached, overwrite = TRUE)
      return(read_csv(cached, show_col_types = FALSE))
    }
    message("Could not reach DATA_URL; using the local copy of ", name, ".")
  }
  path <- if (file.exists(file.path("data", name))) file.path("data", name) else cached
  if (!file.exists(path)) stop("No copy of ", name, " found.", call. = FALSE)
  read_csv(path, show_col_types = FALSE)
}

save_panel <- function(plot, file, width, height) {
  ggsave(file.path(OUT_DIR, file), plot, device = agg_png, units = "in",
         width = width, height = height, dpi = 1500, bg = "white")
}

# ---- data -------------------------------------------------------------------

fsap   <- read_data("fsap_annual.csv")
linc   <- read_data("linc_annual.csv")
occ    <- read_data("linc_occurrence.csv")
pooled <- read_data("linc_period_totals.csv")[1, ]
coding <- read_data("coding.csv")

if (REPRODUCE_SUBMITTED) {
  fsap_years <- 2018:2024
  linc_years <- 2016:2022
} else {
  fsap_years <- sort(fsap$year)
  linc_years <- sort(linc$year)
}

# Each FSAP row must balance. A mistyped year or a bad parse fails here.
with(fsap, stopifnot(
  registered     + non_registered     == release_reports,
  minimal_risk   + occ_exposure       == release_reports,
  no_ohs_needed  + releases_with_ohs  == occ_exposure,
  ind_registered + ind_non_registered == individuals_ohs
))

# ---- theme ------------------------------------------------------------------

base_family <- pick_font()

theme_set(
  theme_classic(base_size = 9, base_family = base_family) +
    theme(plot.title         = element_text(face = "bold", size = 10),
          legend.position    = "top",
          legend.title       = element_blank(),
          legend.key.size    = unit(0.35, "cm"),
          legend.margin      = margin(b = -4),
          panel.grid.major.y = element_line(colour = "grey90", linewidth = 0.3))
)

# ---- panel A: FSAP by year --------------------------------------------------

measures <- c("Release reports (Form 3)",
              "Releases with occupational exposure",
              "Individuals given occupational health services")
dodge_w <- 0.8

a_dat <- fsap |>
  filter(year %in% fsap_years) |>
  select(year, release_reports, occ_exposure, individuals_ohs) |>
  pivot_longer(-year, names_to = "measure", values_to = "count") |>
  mutate(measure = factor(measures[match(measure, c("release_reports",
                                                    "occ_exposure",
                                                    "individuals_ohs"))],
                          levels = measures),
         year    = factor(year, levels = sort(fsap_years)))

y_max <- max(a_dat$count) * 1.25

# Illness callouts, read from the data rather than typed in. The third bar of a
# dodged group of three sits one third of the dodge width right of centre.
a_lab <- fsap |>
  filter(year %in% fsap_years, illnesses > 0) |>
  transmute(x     = match(year, sort(fsap_years)) + dodge_w / 3,
            y     = individuals_ohs,
            label = paste0(illnesses, " illness", ifelse(illnesses > 1, "es", "")))

panel_a <- ggplot(a_dat, aes(year, count, fill = measure)) +
  geom_col(position = position_dodge(width = dodge_w), width = 0.75) +
  geom_segment(data = a_lab, inherit.aes = FALSE,
               aes(x = x, xend = x, y = y + y_max * .13, yend = y + y_max * .02),
               colour = PALETTE[["illness"]], linewidth = 0.4,
               arrow = arrow(length = unit(0.12, "cm"))) +
  geom_text(data = a_lab, inherit.aes = FALSE,
            aes(x = x, y = y + y_max * .17, label = label),
            colour = PALETTE[["illness"]], family = base_family,
            fontface = "bold", size = 2.7) +
  scale_fill_manual(values = unname(PALETTE[c("reports", "exposure", "assessed")])) +
  scale_y_continuous(limits = c(0, y_max), expand = expansion(0, 0)) +
  guides(fill = guide_legend(ncol = 1)) +
  labs(x = NULL, y = "Count",
       title = sprintf("U.S. Federal Select Agent Program, %d–%d",
                       min(fsap_years), max(fsap_years)))

# ---- panel B: exposures vs. recognized infections ---------------------------

fsap_tot <- fsap |>
  filter(year %in% fsap_years) |>
  summarise(`FSAP: release reports`        = sum(release_reports),
            `FSAP: releases with exposure` = sum(occ_exposure),
            `FSAP: individuals assessed`   = sum(individuals_ohs),
            `FSAP: illnesses`              = sum(illnesses)) |>
  pivot_longer(everything(), names_to = "series", values_to = "value")

if (REPRODUCE_SUBMITTED) {
  linc_val  <- c(pooled$exposure_incidents, pooled$exposed_individuals,
                 pooled$suspected_or_confirmed_lai, pooled$confirmed_lai)
  lai_unit  <- ""                       # pooled counts are per person
  linc_span <- pooled$period
} else {
  d <- filter(linc, year %in% linc_years)
  # Exposed people are published yearly only from 2023; 2016-2022 exists as a
  # single pooled total, so add it rather than summing the NAs to nothing.
  pooled_yrs <- as.integer(strsplit(pooled$period, "-")[[1]])
  pooled_yrs <- pooled_yrs[1]:pooled_yrs[2]
  persons <- sum(d$exposed_individuals[!d$year %in% pooled_yrs], na.rm = TRUE) +
    if (all(pooled_yrs %in% linc_years)) pooled$exposed_individuals else NA_real_
  linc_val  <- c(sum(d$exposure_incidents), persons,
                 sum(d$suspected_lai_incidents + d$confirmed_lai_incidents),
                 sum(d$confirmed_lai_incidents))
  lai_unit  <- " (incidents)"           # person-level LAIs stop after 2022
  linc_span <- sprintf("%d–%d", min(linc_years), max(linc_years))
}

b_dat <- bind_rows(fsap_tot, tibble(
  series = c("LINC: exposure incidents", "LINC: exposed individuals",
             paste0("LINC: suspected or confirmed LAI", lai_unit),
             paste0("LINC: confirmed LAI", lai_unit)),
  value  = linc_val)) |>
  mutate(colour = unname(PALETTE[c("reports", "exposure", "assessed", "illness",
                                   "linc_a", "linc_b", "linc_c", "linc_d")]),
         pos    = rev(row_number()))

# A log axis has no zero, so each bar is drawn from 1 to its value.
panel_b <- ggplot(b_dat) +
  geom_rect(aes(xmin = 1, xmax = value, ymin = pos - .38, ymax = pos + .38,
                fill = colour)) +
  geom_text(aes(x = value * 1.2, y = pos,
                label = format(value, big.mark = ",", trim = TRUE)),
            hjust = 0, size = 2.7, family = base_family) +
  scale_fill_identity() +
  scale_x_log10(breaks = 10^(0:4),
                labels = format(10^(0:4), big.mark = ",", trim = TRUE,
                                scientific = FALSE),
                limits = c(1, max(b_dat$value, na.rm = TRUE) * 4),
                expand = expansion(0, 0)) +
  scale_y_continuous(breaks = b_dat$pos, labels = b_dat$series,
                     expand = expansion(add = 0.45)) +
  labs(x = "Count (log scale)", y = NULL,
       title = "Exposures vs. recognized infections") +
  theme(panel.grid.major.y = element_blank())

# ---- panel C: LINC occurrence types -----------------------------------------

c_dat <- occ |>
  filter(year %in% linc_years) |>
  group_by(occurrence_type) |>
  summarise(citations = sum(citations), .groups = "drop") |>
  inner_join(coding, by = "occurrence_type") |>
  filter(citations > 0) |>
  mutate(share           = citations / sum(citations),
         label           = sprintf("%d (%.0f%%)", citations, 100 * share),
         occurrence_type = reorder(occurrence_type, -plot_order))

flag_share <- with(c_dat, sum(citations[behavior_dependent == "Yes"]) / sum(citations))
flag_label <- sprintf("Behavior-dependent (%.1f%%)", 100 * flag_share)

c_dat <- mutate(c_dat, flag = factor(
  ifelse(behavior_dependent == "Yes", flag_label, "Not flagged"),
  levels = c(flag_label, "Not flagged")))

panel_c <- ggplot(c_dat, aes(citations, occurrence_type, fill = flag)) +
  geom_col(width = 0.75) +
  geom_text(aes(label = label), hjust = -0.12, size = 2.7, family = base_family) +
  scale_fill_manual(values = setNames(unname(PALETTE[c("flag", "plain")]),
                                      c(flag_label, "Not flagged"))) +
  scale_x_continuous(limits = c(0, max(c_dat$citations) * 1.38),
                     expand = expansion(0, 0)) +
  labs(x = sprintf("Citations, %s (N = %d)",
                   sub("-", "–", linc_span), sum(c_dat$citations)),
       y = NULL, title = "LINC occurrence types, Canada") +
  theme(panel.grid.major.y = element_blank(),
        panel.grid.major.x = element_line(colour = "grey90", linewidth = 0.3))

# ---- write ------------------------------------------------------------------

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

save_panel(panel_a, "figure2a.png", width = 7.2, height = 3.8)
save_panel(panel_b, "figure2b.png", width = 5.4, height = 3.4)
save_panel(panel_c, "figure2c.png", width = 5.4, height = 3.6)

# Printed so the numbers can be checked against the caption. The submitted
# figure: 1405 / 1207 / 5334 / 2; 361 / 781 / 25 / 8; N = 486, 64.6% flagged.
print(b_dat[, c("series", "value")], n = Inf)
cat(sprintf("Panel C: N = %d, behavior-dependent = %.1f%%\nFont: %s\nWrote %s/\n",
            sum(c_dat$citations), 100 * flag_share,
            if (nzchar(base_family)) base_family else "device default", OUT_DIR))
