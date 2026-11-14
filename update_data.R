# -----------------------------------------------------------------------------
# update_data.R — add a newly published year to data/
#
# Companion to figure2.R for Figure 2 of Okosun et al., Laboratories 2026.
# Kept separate so the plotting script stays small and needs no scraping
# dependencies. Run it only when a new report comes out.
#
#   source("update_data.R")
#   fsap <- fetch_fsap(2026)      # parses the FSAP annual report PDF
#   append_fsap(fsap)             # writes to data/fsap_annual.csv after checks
#
#   linc_tables("https://www.canada.ca/...surveillance-...-2025.html")
#
# Nothing is written until the parsed numbers are printed and the internal
# balance checks pass. Read the printout against the report before appending:
# an unreviewed scrape has no place in a published figure.
#
# Requires: pdftools, rvest, readr, dplyr
# -----------------------------------------------------------------------------

library(readr)
library(dplyr)

# ---- FSAP (United States) ---------------------------------------------------

# The PDF filename has changed style several times (FSAP_Annual_Report_2021_508,
# FSAP-Annual-Report-2023_508, 2024-FSAP-Annual-Report_508), so read the link
# off the year's landing page and fall back to the known patterns.
fsap_pdf_url <- function(year) {
  page <- sprintf("https://www.selectagents.gov/resources/publications/annualreport/%d.htm", year)
  html <- tryCatch(paste(readLines(page, warn = FALSE), collapse = " "),
                   error = function(e) "")
  hits <- regmatches(html, gregexpr('href="([^"]+\\.pdf)"', html, perl = TRUE))[[1]]
  hits <- sub('^href="', "", sub('"$', "", hits))
  hits <- grep("[Aa]nnual.?[Rr]eport", hits, value = TRUE)
  if (length(hits)) {
    url <- hits[[1]]
    return(if (grepl("^http", url)) url else paste0("https://www.selectagents.gov", url))
  }
  base <- "https://www.selectagents.gov/resources/publications/docs/"
  paste0(base, c(sprintf("FSAP-Annual-Report-%d_508.pdf", year),
                 sprintf("%d-FSAP-Annual-Report_508.pdf", year),
                 sprintf("FSAP_Annual_Report_%d_508.pdf", year)))
}

# Written-out numbers appear in these sentences ("seven of the 231 releases").
.words <- c(no = 0, zero = 0, one = 1, two = 2, three = 3, four = 4, five = 5,
            six = 6, seven = 7, eight = 8, nine = 9, ten = 10, eleven = 11,
            twelve = 12, thirteen = 13, fourteen = 14, fifteen = 15)

.num <- function(x) {
  if (is.na(x)) return(NA_integer_)
  x <- gsub(",", "", x)
  if (grepl("^[0-9]+$", x)) return(as.integer(x))
  unname(.words[tolower(x)])
}

.grab <- function(txt, pattern) {
  m <- regmatches(txt, regexec(pattern, txt, perl = TRUE))[[1]]
  if (length(m) < 2) NA_character_ else m[[2]]
}

#' Parse one FSAP annual report into a one-row data frame.
#' Targets the 2020-onward wording of the "Theft, Loss, and Release of BSAT"
#' section. 2018 and 2019 are worded differently and are already in data/.
fetch_fsap <- function(year, url = NULL) {
  if (is.null(url)) url <- fsap_pdf_url(year)
  txt <- NULL
  for (u in url) {
    txt <- tryCatch(pdftools::pdf_text(u), error = function(e) NULL)
    if (!is.null(txt)) { url <- u; break }
  }
  if (is.null(txt)) stop("Could not download the ", year, " report.", call. = FALSE)

  # PDF extraction wraps lines mid-sentence; collapse before matching.
  t <- gsub("\\s+", " ", paste(txt, collapse = " "))
  N <- "([0-9,]+|[A-Za-z]+)"

  out <- tibble(
    year               = year,
    release_reports    = .num(.grab(t, "([0-9,]+) +reports of releases")),
    registered         = .num(.grab(t, "reports of releases, *([0-9,]+) +were submitted by registered")),
    non_registered     = .num(.grab(t, "submitted by registered entities and +([0-9,]+) +by non-registered")),
    minimal_risk       = .num(.grab(t, paste0(N, " +releases presented minimal to no risk"))),
    occ_exposure       = .num(.grab(t, "remaining +([0-9,]+) +releases involved occupational exposure")),
    no_ohs_needed      = .num(.grab(t, paste0("In +", N, " +of the [0-9,]+ releases, the reporting entity determined"))),
    releases_with_ohs  = .num(.grab(t, "In the remaining +([0-9,]+) +releases, the reporting entities provided")),
    individuals_ohs    = .num(.grab(t, "to a total of +([0-9,]+) +individuals")),
    ind_registered     = .num(.grab(t, "\\(([0-9,]+) +individuals from +[0-9,]+ +registered")),
    ind_non_registered = .num(.grab(t, "and +([0-9,]+) +individuals from +[0-9,]+ +non-registered")),
    illnesses          = if (grepl("resulted in (the )?illness of one worker", t)) 1L
                         else if (grepl("[Nn]one of the (reported )?releases resulted in illness", t)) 0L
                         else NA_integer_,
    illness_agent      = .grab(t, "illness of one worker after exposure to ([A-Z][a-z]+ [a-z]+)"),
    source_url         = url)

  cat("\nParsed", year, "from", url, "\n\n")
  print(t(out))
  cat("\nCheck every number against the report before appending.\n")
  if (is.na(out$illnesses))
    warning("Illness wording not recognised; read that paragraph and set it by hand.",
            call. = FALSE)
  out
}

#' Append a parsed year to data/fsap_annual.csv once the balances hold.
append_fsap <- function(row, path = "data/fsap_annual.csv") {
  old <- read_csv(path, show_col_types = FALSE)
  if (row$year %in% old$year) stop(row$year, " is already in ", path, call. = FALSE)
  stopifnot(
    "registered + non-registered must equal release reports" =
      isTRUE(row$registered + row$non_registered == row$release_reports),
    "minimal risk + occupational exposure must equal release reports" =
      isTRUE(row$minimal_risk + row$occ_exposure == row$release_reports),
    "no-services + with-services must equal releases with exposure" =
      isTRUE(row$no_ohs_needed + row$releases_with_ohs == row$occ_exposure),
    "individuals by entity type must equal individuals assessed" =
      isTRUE(row$ind_registered + row$ind_non_registered == row$individuals_ohs))
  row$illness_agent[is.na(row$illness_agent)] <- ""
  write_csv(bind_rows(old, row[, names(old)]), path)
  message("Added ", row$year, " to ", path, ".")
}

# ---- LINC (Canada) ----------------------------------------------------------

# LINC publishes one CCDR article per year at an unpredictable URL, so pass the
# article link from https://www.canada.ca/en/public-health/services/
# reports-publications/canada-communicable-disease-report-ccdr.html.
# This prints the article's tables; read the yearly row off the figure
# text-descriptions and add it to data/linc_annual.csv and
# data/linc_occurrence.csv by hand. The structure changes between issues often
# enough that automatic parsing would be guesswork.
linc_tables <- function(url) {
  tabs <- rvest::html_table(rvest::read_html(url))
  cat("Found", length(tabs), "tables at\n", url, "\n")
  for (i in seq_along(tabs)) {
    cat("\n--- table", i, "---\n")
    print(utils::head(as.data.frame(tabs[[i]]), 15))
  }
  cat("\nWanted: confirmed exposure incidents, suspected and confirmed LAIs,",
      "\nactive licences, affected individuals, and the occurrence-type counts.",
      "\nNote whether LAIs are reported as incidents or as people.\n")
  invisible(tabs)
}
