# =============================================================================
# FulfillIQ Stage 4 — R Workflow Engine analysis
# File: Stage_04_FulfillIQ_R_Analysis.R
#
# Product: one CONFIG in; Excel evidence workbook out. Same tibbles at Publish.
# Engine: https://github.com/markjamesc/r-workflow-engine/blob/main/ENGINE.md
# Source repo: https://github.com/markjamesc/fulfilliq
#
# Controlling specs (do not reopen):
#   Stage_03_Measurement_Design.md  — grain, KPI, peer bar, guardrails, actions
#   Stage_04_FulfillIQ_Analysis.sql — flag CASE / action / action_reason (exact)
#   Stages_01_02_Dialogue_and_Handoff.md
#   FulfillIQ_Database_Context_Package.md
#   FulfillIQ_Data_Profile.md
#
# This script does NOT: generate SQL; reconnect to MySQL; forecast; use ML/caret;
# redesign Stage 3; emit business recommendations; use p-values / regression /
# CI decision rules; synthesize generic sellers when the export CSV exists.
#
# Grain is seller-window (Stage 3 decision grain), NOT entity-day.
# Complete MUST skip. Expand MUST skip. pack = short (counts + rates only).
# =============================================================================

# ---- 1) Libraries and engine operator ---------------------------------------
library(tidyverse)
library(janitor)
library(lubridate)
library(readr)
library(openxlsx)
library(ggplot2)
library(purrr)

`%not_in%` <- Negate(`%in%`)

# Mechanical helpers (not workflow stages). ENGINE forbids positional keys
# (df[[1]], names(df)[1]) and positional col_types.

# MySQL ROUND half-away-from-zero for 1-decimal percent recon
# (Stage 4 SQL: ROUND(100 * lfr, 1)).
round_half_up <- function(x, digits = 1L) {
  p <- 10^digits
  ifelse(is.na(x), NA_real_, sign(x) * floor(abs(x) * p + 0.5) / p)
}

# Nearest-rank percentile. NOT stats::quantile().
# Stage 4 SQL: ROW_NUMBER() OVER (ORDER BY lfr ASC, seller_id ASC);
#              rn = GREATEST(1, CEIL(p * n)); return LFR at that row.
nearest_rank_value <- function(values, ids, p) {
  n <- length(values)
  if (n < 1L) {
    return(NA_real_)
  }
  ord <- order(values, ids, method = "radix", na.last = TRUE)
  rnk <- max(1L, as.integer(ceiling(p * n)))
  rnk <- min(rnk, n)
  sorted <- values[ord]
  sorted[rnk]
}

empty_problems <- function() {
  tibble::tibble(
    gate     = character(),
    check    = character(),
    severity = character(),
    n        = integer(),
    detail   = character()
  )
}

add_problem <- function(problems, gate, check, severity, n, detail) {
  dplyr::bind_rows(
    problems,
    tibble::tibble(
      gate     = gate,
      check    = check,
      severity = severity,
      n        = as.integer(n),
      detail   = detail
    )
  )
}

# Named col_types for every export column (ENGINE: never positional).
# IDs/categories character; counts/flags integer; rates/revenue/peers double.
# Literal SQL NULL tokens become NA.
seller_export_cols <- function() {
  readr::cols(
    seller_id                  = readr::col_character(),
    seller_state               = readr::col_character(),
    seller_city                = readr::col_character(),
    eligible_n                 = readr::col_integer(),
    late_n                     = readr::col_integer(),
    on_time_n_date             = readr::col_integer(),
    lfr_date                   = readr::col_double(),
    lfr_date_pct               = readr::col_double(),
    late_over_eligible         = readr::col_character(),
    late_n_ts                  = readr::col_integer(),
    lfr_timestamp              = readr::col_double(),
    lfr_timestamp_pct          = readr::col_double(),
    median_days_vs_estimate    = readr::col_double(),
    median_days_late           = readr::col_double(),
    eligible_n_jan_apr         = readr::col_integer(),
    late_n_jan_apr             = readr::col_integer(),
    lfr_jan_apr                = readr::col_double(),
    eligible_n_may_aug         = readr::col_integer(),
    late_n_may_aug             = readr::col_integer(),
    lfr_may_aug                = readr::col_double(),
    eligible_n_single          = readr::col_integer(),
    late_n_single              = readr::col_integer(),
    lfr_single_seller          = readr::col_double(),
    multi_seller_order_n       = readr::col_integer(),
    multi_seller_order_share   = readr::col_double(),
    item_revenue               = readr::col_double(),
    item_revenue_plus_freight  = readr::col_double(),
    anomaly_n                  = readr::col_integer(),
    meets_volume_floor         = readr::col_integer(),
    volume_band                = readr::col_character(),
    n_floor_sellers            = readr::col_integer(),
    peer_weighted_mkt_lfr      = readr::col_double(),
    peer_equal_wt_lfr          = readr::col_double(),
    peer_p25_lfr               = readr::col_double(),
    peer_median_lfr            = readr::col_double(),
    peer_p75_lfr               = readr::col_double(),
    peer_p90_lfr               = readr::col_double(),
    peer_p95_lfr               = readr::col_double(),
    pass_p75                   = readr::col_integer(),
    pass_p90                   = readr::col_integer(),
    attribution_conflict       = readr::col_integer(),
    date_ts_action_conflict    = readr::col_integer(),
    split_window_unstable      = readr::col_integer(),
    raise_bar_to_p90           = readr::col_integer(),
    rank_if_candidate          = readr::col_integer(),
    action                     = readr::col_character(),
    action_reason              = readr::col_character()
  )
}

SQL_EXPORT_COLS <- c(
  "seller_id", "seller_state", "seller_city", "eligible_n", "late_n",
  "on_time_n_date", "lfr_date", "lfr_date_pct", "late_over_eligible",
  "late_n_ts", "lfr_timestamp", "lfr_timestamp_pct", "median_days_vs_estimate",
  "median_days_late", "eligible_n_jan_apr", "late_n_jan_apr", "lfr_jan_apr",
  "eligible_n_may_aug", "late_n_may_aug", "lfr_may_aug", "eligible_n_single",
  "late_n_single", "lfr_single_seller", "multi_seller_order_n",
  "multi_seller_order_share", "item_revenue", "item_revenue_plus_freight",
  "anomaly_n", "meets_volume_floor", "volume_band", "n_floor_sellers",
  "peer_weighted_mkt_lfr", "peer_equal_wt_lfr", "peer_p25_lfr",
  "peer_median_lfr", "peer_p75_lfr", "peer_p90_lfr", "peer_p95_lfr",
  "pass_p75", "pass_p90", "attribution_conflict", "date_ts_action_conflict",
  "split_window_unstable", "raise_bar_to_p90", "rank_if_candidate",
  "action", "action_reason"
)

LEGAL_ACTIONS <- c("enroll", "watch", "standard_terms", "inconclusive")
LEGAL_BANDS   <- c("below_floor", "30_49", "50_99", "100_plus")
# DECIMAL(18,6) recon tolerance for rate columns exported from MySQL.
RATE_TOL <- 1e-6

is_rate_col <- function(nm) {
  grepl(
    paste0(
      "(lfr_|_share$|^weighted_|^equal_mean_|recalc_lfr|peer_.*lfr|",
      "anomaly_share|precision_delta|split_window_delta|attribution_delta)"
    ),
    nm
  ) & !grepl("_pct$", nm)
}

halt_if_fatal <- function(problems) {
  fatal <- problems %>% dplyr::filter(.data$severity == "fatal")
  if (nrow(fatal) > 0L) {
    print(fatal)
    stop(
      "Assure halted on material mismatch (fatal rows printed above).",
      call. = FALSE
    )
  }
  invisible(problems)
}

# Stitch the known unquoted newline in seller_city (seller cf1313c6e2c01c2f4b014f97db4bcd2b).
# Isolates the defect into a problems tibble. Recovers the seller so valid rows stay.
stitch_city_newlines <- function(path) {
  lines <- readr::read_lines(path)
  if (length(lines) < 2L) {
    return(list(
      text = paste(lines, collapse = "\n"),
      problems = empty_problems()
    ))
  }
  header <- lines[1]
  expected <- stringr::str_count(header, ",") + 1L
  out <- header
  problems <- empty_problems()
  i <- 2L
  n_lines <- length(lines)
  while (i <= n_lines) {
    n_fields <- stringr::str_count(lines[i], ",") + 1L
    if (n_fields < expected && i < n_lines) {
      combined <- paste0(lines[i], lines[i + 1L])
      n_comb <- stringr::str_count(combined, ",") + 1L
      if (n_comb == expected) {
        seller_guess <- stringr::str_extract(lines[i], "^[0-9a-f]{32}")
        problems <- add_problem(
          problems, "load", "csv_embedded_newline_seller_city", "info", 2L,
          paste0(
            "Unquoted newline in seller_city; stitched physical lines ",
            i, "-", i + 1L, " into one seller row (",
            ifelse(is.na(seller_guess), "unknown id", seller_guess), ")."
          )
        )
        out <- c(out, combined)
        i <- i + 2L
        next
      }
    }
    out <- c(out, lines[i])
    i <- i + 1L
  }
  list(text = paste(out, collapse = "\n"), problems = problems)
}

resolve_daily_path <- function(cfg_path) {
  # Locked input: output/Stage_04_seller_export.csv inside the FulfillIQ
  # project folder (repo root). Never read data/. Never rewrite CONFIG.
  # Never mutate the CSV.
  if (!identical(cfg_path, "output/Stage_04_seller_export.csv")) {
    stop(
      "CONFIG$paths$daily is locked to output/Stage_04_seller_export.csv; ",
      "got: ", cfg_path,
      call. = FALSE
    )
  }
  cmd_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", cmd_args, value = TRUE)
  script_dir <- if (length(file_arg) > 0L) {
    dirname(normalizePath(sub("^--file=", "", file_arg[1]), mustWork = FALSE))
  } else {
    getwd()
  }
  candidates <- unique(c(
    cfg_path,
    file.path(getwd(), cfg_path),
    file.path(script_dir, cfg_path),
    file.path(dirname(script_dir), cfg_path)
  ))
  # Refuse any candidate that walks into data/.
  candidates <- candidates[!grepl("(^|[\\/])data([\\/]|$)", candidates)]
  hit <- candidates[file.exists(candidates)]
  if (length(hit) < 1L) {
    stop(
      paste0(
        "Stage 4 seller export CSV is missing. Locked path is ",
        "output/Stage_04_seller_export.csv (FulfillIQ repo root, not data/). ",
        "Looked for:\n  ",
        paste(candidates, collapse = "\n  "),
        "\nDo not invent generic sellers. Do not change the CSV."
      ),
      call. = FALSE
    )
  }
  normalizePath(hit[1], winslash = "/", mustWork = TRUE)
}

# ---- 2) Thin CONFIG (owner brief only) --------------------------------------
# Script is intended to run from the FulfillIQ repo root.
# Locked CSV path: output/Stage_04_seller_export.csv (NOT data/). Do not change the CSV.
# window_days = 243 = 2018-01-01 through 2018-08-31 inclusive (Stage 3 window).
CONFIG <- list(
  entity_key  = "seller_id",
  time_key    = "analysis_window_end",
  grain       = "seller-window",  # NOT entity-day; complete skips
  window_days = 243L,
  groups      = c("overall", "seller_id", "seller_state", "volume_band", "action"),
  paths       = list(
    daily  = "output/Stage_04_seller_export.csv",
    lookup = NULL
  ),
  expand      = FALSE,
  horizon     = 30L,
  method      = NULL,
  publish     = c("excel"),
  recodes     = list(intervention_date = NULL),
  pack        = "short"
)

# ---- 3) Internal functions (nine engine stages + helpers used by them) ------

configure <- function(CONFIG) {
  required <- c(
    "entity_key", "time_key", "grain", "window_days", "groups",
    "paths", "expand", "horizon", "method", "publish", "recodes"
  )
  missing <- required[required %not_in% names(CONFIG)]
  if (length(missing) > 0L) {
    stop("CONFIG is missing required fields: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }
  if (is.null(CONFIG$pack) || !nzchar(CONFIG$pack)) {
    CONFIG$pack <- "usual"
  }
  if (!is.character(CONFIG$groups) || length(CONFIG$groups) < 1L) {
    stop("CONFIG$groups must be a non-empty character vector of column names.",
         call. = FALSE)
  }
  legal_publish <- c("excel", "shiny", "shinydashboard")
  bad_pub <- CONFIG$publish[CONFIG$publish %not_in% legal_publish]
  if (length(bad_pub) > 0L) {
    stop("Illegal CONFIG$publish tokens: ", paste(bad_pub, collapse = ", "),
         call. = FALSE)
  }
  if (!is.list(CONFIG$recodes) || "intervention_date" %not_in% names(CONFIG$recodes)) {
    stop("CONFIG$recodes must be a named list containing intervention_date.",
         call. = FALSE)
  }
  CONFIG
}


load <- function(CONFIG) {
  # Read the Stage 4 seller-window export. Do not synthesize generic demo
  # data: the CSV exists (ENGINE synthesizes only if files are absent).
  csv_path <- resolve_daily_path(CONFIG$paths$daily)
  read_ts <- Sys.time()

  stitched <- stitch_city_newlines(csv_path)
  daily <- readr::read_csv(
    I(stitched$text),
    col_types = seller_export_cols(),
    na = c("", "NA", "NULL", "null"),
    trim_ws = TRUE,
    progress = FALSE
  )
  parse_problems <- tibble::as_tibble(readr::problems(daily))
  if (nrow(parse_problems) > 0L) {
    parse_problems <- parse_problems %>%
      dplyr::mutate(
        gate     = "load",
        check    = "readr_parse",
        severity = "info",
        n        = 1L,
        detail   = paste0(
          "row=", .data$row, " col=", .data$col,
          " expected=", .data$expected, " actual=", .data$actual
        )
      ) %>%
      dplyr::select("gate", "check", "severity", "n", "detail")
  } else {
    parse_problems <- empty_problems()
  }

  # Drop only physically unusable parse wreckage (no seller_id). Do not drop
  # low-volume / watch / inconclusive / standard_terms sellers.
  n_read <- nrow(daily)
  daily <- daily %>%
    dplyr::filter(!is.na(.data$seller_id), .data$seller_id != "")
  n_after_id <- nrow(daily)

  # Mechanical engine anchors (NOT from SQL, NOT an order date).
  # analysis_window_end holds the Stage 3 window close so the engine has a
  # time_key on a non-panel grain. overall is the all-seller grouping column.
  daily <- daily %>%
    dplyr::mutate(
      analysis_window_end = as.Date("2018-08-31"),
      overall             = "all"
    )

  n_pre_join <- nrow(daily)

  # Lookup join is a documented no-op: seller_state / seller_city already
  # travel on the SQL export. CONFIG$paths$lookup is NULL. Do not synthesize
  # a lookup file. Do not self-join.
  lookup_status <- "NULL — documented no-op (seller_state/city already on export)"
  lookup_rows <- 0L
  lookup_distinct_keys <- 0L
  n_post_join <- n_pre_join

  load_problems <- dplyr::bind_rows(stitched$problems, parse_problems)
  if (n_read > n_after_id) {
    load_problems <- add_problem(
      load_problems, "load", "dropped_na_seller_id", "info",
      n_read - n_after_id,
      "Rows with NA/blank seller_id after parse were isolated; valid sellers kept."
    )
  }

  lineage <- tibble::tibble(
    source_repo           = "https://github.com/markjamesc/fulfilliq",
    csv_path              = csv_path,
    csv_config_path       = CONFIG$paths$daily,
    read_timestamp        = as.character(read_ts),
    stage_3_path          = "Stage_03_Measurement_Design.md",
    stage_4_sql_path      = "Stage_04_FulfillIQ_Analysis.sql",
    engine_md_url         = "https://github.com/markjamesc/r-workflow-engine/blob/main/ENGINE.md",
    window                = "2018-01-01 through 2018-08-31 (purchase timestamps)",
    window_days           = CONFIG$window_days,
    grain                 = CONFIG$grain,
    entity_key            = CONFIG$entity_key,
    time_key              = CONFIG$time_key,
    complete_skipped      = TRUE,
    expand_skipped        = TRUE,
    lookup_status         = lookup_status,
    pack                  = CONFIG$pack,
    n_rows_read           = n_read,
    n_rows_with_seller_id = n_after_id
  )

  load_meta <- list(
    csv_path             = csv_path,
    read_timestamp       = read_ts,
    n_pre_join           = n_pre_join,
    n_post_join          = n_post_join,
    lookup_rows          = lookup_rows,
    lookup_distinct_keys = lookup_distinct_keys,
    lookup_status        = lookup_status,
    problems             = load_problems,
    lineage              = lineage,
    grain                = CONFIG$grain,
    window_days          = CONFIG$window_days
  )
  attr(daily, "load_meta") <- load_meta
  daily
}

clean <- function(daily, CONFIG) {
  load_meta <- attr(daily, "load_meta")

  daily <- janitor::clean_names(daily)

  # Owner recodes only. intervention_date is NULL so no recode functions and
  # no invented replacement vectors (ENGINE).
  recodes <- CONFIG$recodes
  recode_names <- names(recodes)
  recode_names <- recode_names[recode_names %not_in% c("intervention_date", "")]
  if (length(recode_names) > 0L) {
    for (nm in recode_names) {
      vec <- recodes[[nm]]
      if (!is.null(vec) && nm %in% names(daily)) {
        daily <- daily %>%
          dplyr::mutate(
            !!nm := dplyr::recode(.data[[nm]], !!!vec, .default = .data[[nm]])
          )
      }
    }
  }

  # Helper columns only. Keep original SQL columns (do not overwrite).
  # Recalc rates use denom>0 (Stage 4 SQL NULLIF contract).
  daily <- daily %>%
    dplyr::mutate(
      recalc_lfr_date = dplyr::if_else(
        .data$eligible_n > 0L, .data$late_n / .data$eligible_n, NA_real_
      ),
      recalc_lfr_timestamp = dplyr::if_else(
        .data$eligible_n > 0L, .data$late_n_ts / .data$eligible_n, NA_real_
      ),
      recalc_lfr_jan_apr = dplyr::if_else(
        .data$eligible_n_jan_apr > 0L,
        .data$late_n_jan_apr / .data$eligible_n_jan_apr,
        NA_real_
      ),
      recalc_lfr_may_aug = dplyr::if_else(
        .data$eligible_n_may_aug > 0L,
        .data$late_n_may_aug / .data$eligible_n_may_aug,
        NA_real_
      ),
      recalc_lfr_single_seller = dplyr::if_else(
        .data$eligible_n_single > 0L,
        .data$late_n_single / .data$eligible_n_single,
        NA_real_
      ),
      recalc_multi_seller_order_share = dplyr::if_else(
        .data$eligible_n > 0L,
        .data$multi_seller_order_n / .data$eligible_n,
        NA_real_
      ),
      anomaly_share = dplyr::if_else(
        .data$eligible_n > 0L, .data$anomaly_n / .data$eligible_n, NA_real_
      ),
      precision_delta    = .data$lfr_date - .data$lfr_timestamp,
      split_window_delta = .data$lfr_jan_apr - .data$lfr_may_aug,
      attribution_delta  = .data$lfr_date - .data$lfr_single_seller,
      r_meets_volume_floor = dplyr::if_else(.data$eligible_n >= 30L, 1L, 0L),
      r_volume_band = dplyr::case_when(
        .data$eligible_n < 30L  ~ "below_floor",
        .data$eligible_n < 50L  ~ "30_49",
        .data$eligible_n < 100L ~ "50_99",
        TRUE                    ~ "100_plus"
      ),
      r_lfr_date_pct        = round_half_up(100 * .data$lfr_date, 1L),
      r_lfr_timestamp_pct   = round_half_up(100 * .data$lfr_timestamp, 1L),
      r_late_over_eligible  = paste0(.data$late_n, " / ", .data$eligible_n)
    )

  # ---- Peer nearest-rank (n>=30 cohort) + r_* shadow flags -------------------
  # Recompute independently. Do not overwrite SQL peer / flag columns.
  # Timestamp weighted / P75 / P90 computed independently (not in the export).
  floor_df <- daily %>% dplyr::filter(.data$eligible_n >= 30L)
  n_floor <- nrow(floor_df)

  if (n_floor < 1L) {
    r_n_floor <- 0L
    r_w <- r_eq <- r_p25 <- r_p50 <- r_p75 <- r_p90 <- r_p95 <- NA_real_
    r_w_ts <- r_p75_ts <- r_p90_ts <- NA_real_
  } else {
    r_n_floor <- as.integer(n_floor)
    r_w <- sum(floor_df$late_n) / sum(floor_df$eligible_n)
    r_eq <- mean(floor_df$lfr_date)
    ids <- dplyr::pull(floor_df, "seller_id")
    lfr_d <- dplyr::pull(floor_df, "lfr_date")
    lfr_t <- dplyr::pull(floor_df, "lfr_timestamp")
    r_p25 <- nearest_rank_value(lfr_d, ids, 0.25)
    r_p50 <- nearest_rank_value(lfr_d, ids, 0.50)
    r_p75 <- nearest_rank_value(lfr_d, ids, 0.75)
    r_p90 <- nearest_rank_value(lfr_d, ids, 0.90)
    r_p95 <- nearest_rank_value(lfr_d, ids, 0.95)
    r_w_ts <- sum(floor_df$late_n_ts) / sum(floor_df$eligible_n)
    r_p75_ts <- nearest_rank_value(lfr_t, ids, 0.75)
    r_p90_ts <- nearest_rank_value(lfr_t, ids, 0.90)
  }

  daily <- daily %>%
    dplyr::mutate(
      r_n_floor_sellers          = r_n_floor,
      r_peer_weighted_mkt_lfr    = r_w,
      r_peer_equal_wt_lfr        = r_eq,
      r_peer_p25_lfr             = r_p25,
      r_peer_median_lfr          = r_p50,
      r_peer_p75_lfr             = r_p75,
      r_peer_p90_lfr             = r_p90,
      r_peer_p95_lfr             = r_p95,
      r_peer_weighted_mkt_lfr_ts = r_w_ts,
      r_peer_p75_lfr_ts          = r_p75_ts,
      r_peer_p90_lfr_ts          = r_p90_ts
    )

  # Exact SQL CASE from Stage_04_FulfillIQ_Analysis.sql cte_seller_screened /
  # cte_cap_stats / cte_seller_decided (section 10 and export section 12).
  daily <- daily %>%
    dplyr::mutate(
      r_pass_p75 = dplyr::if_else(
        .data$r_meets_volume_floor == 1L &
          .data$lfr_date >= .data$r_peer_p75_lfr &
          .data$lfr_date >  .data$r_peer_weighted_mkt_lfr,
        1L, 0L
      ),
      r_pass_p90 = dplyr::if_else(
        .data$r_meets_volume_floor == 1L &
          .data$lfr_date >= .data$r_peer_p90_lfr &
          .data$lfr_date >  .data$r_peer_weighted_mkt_lfr,
        1L, 0L
      ),
      r_pass_p75_ts = dplyr::if_else(
        .data$r_meets_volume_floor == 1L &
          .data$lfr_timestamp >= .data$r_peer_p75_lfr_ts &
          .data$lfr_timestamp >  .data$r_peer_weighted_mkt_lfr_ts,
        1L, 0L
      ),
      r_single_passes_p75 = dplyr::if_else(
        !is.na(.data$lfr_single_seller) &
          .data$lfr_single_seller >= .data$r_peer_p75_lfr &
          .data$lfr_single_seller >  .data$r_peer_weighted_mkt_lfr,
        1L, 0L
      ),
      r_attribution_conflict = dplyr::if_else(
        .data$r_meets_volume_floor == 1L &
          .data$r_pass_p75 == 1L &
          (
            .data$eligible_n_single == 0L |
              is.na(.data$lfr_single_seller) |
              .data$r_single_passes_p75 == 0L
          ),
        1L, 0L
      ),
      r_date_inner = dplyr::if_else(
        .data$lfr_date >= .data$r_peer_p75_lfr &
          .data$lfr_date >  .data$r_peer_weighted_mkt_lfr,
        1L, 0L
      ),
      r_ts_inner = dplyr::if_else(
        .data$lfr_timestamp >= .data$r_peer_p75_lfr_ts &
          .data$lfr_timestamp >  .data$r_peer_weighted_mkt_lfr_ts,
        1L, 0L
      ),
      r_date_ts_action_conflict = dplyr::if_else(
        .data$r_meets_volume_floor == 1L &
          xor(.data$r_date_inner == 1L, .data$r_ts_inner == 1L),
        1L, 0L
      ),
      r_jan_hot = dplyr::if_else(
        !is.na(.data$lfr_jan_apr) &
          .data$lfr_jan_apr >= .data$r_peer_p75_lfr &
          .data$lfr_jan_apr >  .data$r_peer_weighted_mkt_lfr,
        1L, 0L
      ),
      r_may_hot = dplyr::if_else(
        !is.na(.data$lfr_may_aug) &
          .data$lfr_may_aug >= .data$r_peer_p75_lfr &
          .data$lfr_may_aug >  .data$r_peer_weighted_mkt_lfr,
        1L, 0L
      ),
      r_may_cool = dplyr::if_else(
        is.na(.data$lfr_may_aug) | .data$lfr_may_aug <= .data$r_peer_median_lfr,
        1L, 0L
      ),
      r_jan_cool = dplyr::if_else(
        is.na(.data$lfr_jan_apr) | .data$lfr_jan_apr <= .data$r_peer_median_lfr,
        1L, 0L
      ),
      r_split_window_unstable = dplyr::if_else(
        .data$r_meets_volume_floor == 1L &
          .data$r_pass_p75 == 1L &
          .data$eligible_n_jan_apr > 0L &
          .data$eligible_n_may_aug > 0L &
          (
            (.data$r_jan_hot == 1L & .data$r_may_cool == 1L) |
              (.data$r_may_hot == 1L & .data$r_jan_cool == 1L)
          ),
        1L, 0L
      )
    )

  n_clean_p75 <- daily %>%
    dplyr::filter(
      .data$r_pass_p75 == 1L,
      .data$r_attribution_conflict == 0L,
      .data$r_date_ts_action_conflict == 0L,
      .data$r_split_window_unstable == 0L
    ) %>%
    nrow() %>%
    as.integer()
  r_raise <- if (n_clean_p75 > 20L) 1L else 0L

  daily <- daily %>%
    dplyr::mutate(
      r_n_clean_p75    = n_clean_p75,
      r_raise_bar_to_p90 = r_raise
    )

  # rank_if_candidate: among pass_p75, row_number by LFR desc, late_n desc,
  # eligible_n desc, seller_id asc (Stage 3 Decision Rules / SQL).
  rank_tbl <- daily %>%
    dplyr::filter(.data$r_pass_p75 == 1L) %>%
    dplyr::arrange(
      dplyr::desc(.data$lfr_date),
      dplyr::desc(.data$late_n),
      dplyr::desc(.data$eligible_n),
      .data$seller_id
    ) %>%
    dplyr::mutate(r_rank_if_candidate = dplyr::row_number()) %>%
    dplyr::select("seller_id", "r_rank_if_candidate")

  daily <- daily %>%
    dplyr::left_join(rank_tbl, by = "seller_id")

  daily <- daily %>%
    dplyr::mutate(
      r_action = dplyr::case_when(
        .data$r_meets_volume_floor == 0L ~ "standard_terms",
        .data$r_attribution_conflict == 1L |
          .data$r_date_ts_action_conflict == 1L ~ "inconclusive",
        .data$r_split_window_unstable == 1L ~ "watch",
        .data$r_raise_bar_to_p90 == 1L & .data$r_pass_p90 == 1L ~ "enroll",
        .data$r_raise_bar_to_p90 == 1L & .data$r_pass_p75 == 1L ~ "watch",
        .data$r_raise_bar_to_p90 == 0L & .data$r_pass_p75 == 1L ~ "enroll",
        TRUE ~ "standard_terms"
      ),
      r_action_reason = dplyr::case_when(
        .data$r_meets_volume_floor == 0L ~ "usable_n_lt_30",
        .data$r_attribution_conflict == 1L &
          .data$r_date_ts_action_conflict == 1L ~
          "attribution_and_precision_conflict",
        .data$r_attribution_conflict == 1L ~
          "single_seller_lfr_does_not_support_enroll",
        .data$r_date_ts_action_conflict == 1L ~
          "date_vs_timestamp_action_conflict",
        .data$r_split_window_unstable == 1L ~ "split_window_unstable",
        .data$r_raise_bar_to_p90 == 1L & .data$r_pass_p90 == 1L ~
          "p90_and_above_weighted_after_cap",
        .data$r_raise_bar_to_p90 == 1L & .data$r_pass_p75 == 1L ~
          "p75_watch_band_after_cap",
        .data$r_raise_bar_to_p90 == 0L & .data$r_pass_p75 == 1L ~
          "p75_and_above_weighted",
        TRUE ~ "at_or_below_peer_bar"
      )
    )

  attr(daily, "load_meta") <- load_meta
  daily
}

complete <- function(daily, CONFIG) {
  # Complete fills an entity-day / entity-time panel then cuts to window_days.
  # FulfillIQ grain is seller-window (Stage 3 decision grain), NOT a panel.
  # ENGINE skip rule: if grain is not a panel, return the cleaned frame unchanged.
  panel_grains <- c("entity-day", "entity-time")
  if (CONFIG$grain %not_in% panel_grains) {
    # complete skipped — one row per seller-window; no calendar grid to fill.
    attr(daily, "complete_skipped") <- TRUE
    return(daily)
  }
  daily %>%
    dplyr::group_by(.data[[CONFIG$entity_key]]) %>%
    tidyr::complete(
      !!sym(CONFIG$time_key) := seq.Date(
        min(.data[[CONFIG$time_key]], na.rm = TRUE),
        max(.data[[CONFIG$time_key]], na.rm = TRUE),
        by = "day"
      )
    ) %>%
    tidyr::fill(tidyr::everything(), .direction = "downup") %>%
    dplyr::ungroup() %>%
    dplyr::filter(
      .data[[CONFIG$time_key]] >=
        max(.data[[CONFIG$time_key]], na.rm = TRUE) - (CONFIG$window_days - 1L)
    )
}


shape <- function(daily, CONFIG) {
  # One frame per CONFIG$groups name so one metric function can run on any group.
  # map(CONFIG$groups, ...) — never positional indexes.
  load_meta <- attr(daily, "load_meta")
  complete_skipped <- isTRUE(attr(daily, "complete_skipped"))
  problems_complete <- attr(daily, "problems_complete")

  pieces <- purrr::map(CONFIG$groups, function(group) {
    if (group %not_in% names(daily)) {
      stop("Grouping column '", group, "' is not in the cleaned frame.",
           call. = FALSE)
    }
    df <- daily
    col_vec <- dplyr::pull(df, !!sym(group))
    if (is.list(col_vec)) {
      df <- tidyr::unnest(df, cols = dplyr::all_of(group), keep_empty = TRUE)
    }
    df
  }) %>%
    purrr::set_names(CONFIG$groups)

  attr(pieces, "load_meta") <- load_meta
  attr(pieces, "complete_skipped") <- complete_skipped
  attr(pieces, "problems_complete") <- problems_complete
  pieces
}

measure <- function(pieces, CONFIG) {
  # pack = short: counts + rates only. No rolling / spells / monthly /
  # before_after (intervention_date is NULL). One reusable metric function.
  entity <- CONFIG$entity_key

  metric_fun <- function(df, group, CONFIG) {
    count_core <- function(gdf) {
      gdf %>%
        dplyr::summarise(
          seller_n                 = dplyr::n_distinct(.data[[entity]]),
          eligible_n               = sum(.data$eligible_n),
          late_n                   = sum(.data$late_n),
          on_time_n                = sum(.data$on_time_n_date),
          late_n_ts                = sum(.data$late_n_ts),
          multi_seller_order_n     = sum(.data$multi_seller_order_n),
          anomaly_n                = sum(.data$anomaly_n),
          item_revenue             = sum(.data$item_revenue),
          item_revenue_plus_freight = sum(.data$item_revenue_plus_freight),
          enroll_n                 = as.integer(sum(.data$action == "enroll")),
          watch_n                  = as.integer(sum(.data$action == "watch")),
          inconclusive_n           = as.integer(sum(.data$action == "inconclusive")),
          standard_terms_n         = as.integer(sum(.data$action == "standard_terms")),
          .groups = "drop"
        )
    }
    rate_core <- function(gdf) {
      gdf %>%
        dplyr::summarise(
          weighted_lfr_date                 = sum(.data$late_n) / sum(.data$eligible_n),
          equal_mean_seller_lfr_date        = mean(.data$lfr_date),
          weighted_lfr_timestamp            = sum(.data$late_n_ts) / sum(.data$eligible_n),
          equal_mean_seller_lfr_timestamp   = mean(.data$lfr_timestamp),
          multi_seller_order_share          = sum(.data$multi_seller_order_n) /
            sum(.data$eligible_n),
          anomaly_share                     = sum(.data$anomaly_n) / sum(.data$eligible_n),
          .groups = "drop"
        )
    }

    evidence_cols <- c(
      entity, "seller_state", "seller_city", "eligible_n", "late_n",
      "on_time_n_date", "lfr_date", "lfr_timestamp", "lfr_date_pct",
      "lfr_timestamp_pct", "late_over_eligible", "precision_delta",
      "median_days_vs_estimate", "median_days_late",
      "eligible_n_jan_apr", "late_n_jan_apr", "lfr_jan_apr",
      "eligible_n_may_aug", "late_n_may_aug", "lfr_may_aug",
      "eligible_n_single", "late_n_single", "lfr_single_seller",
      "attribution_delta", "split_window_delta",
      "multi_seller_order_n", "multi_seller_order_share",
      "item_revenue", "item_revenue_plus_freight",
      "anomaly_n", "anomaly_share",
      "meets_volume_floor", "volume_band",
      "n_floor_sellers", "peer_weighted_mkt_lfr", "peer_equal_wt_lfr",
      "peer_p25_lfr", "peer_median_lfr", "peer_p75_lfr", "peer_p90_lfr",
      "peer_p95_lfr",
      "pass_p75", "pass_p90", "attribution_conflict",
      "date_ts_action_conflict", "split_window_unstable",
      "raise_bar_to_p90", "rank_if_candidate", "action", "action_reason",
      "recalc_lfr_date", "recalc_lfr_timestamp",
      "recalc_lfr_jan_apr", "recalc_lfr_may_aug", "recalc_lfr_single_seller",
      "recalc_multi_seller_order_share",
      "r_pass_p75", "r_pass_p90", "r_pass_p75_ts",
      "r_attribution_conflict", "r_date_ts_action_conflict",
      "r_split_window_unstable", "r_raise_bar_to_p90",
      "r_rank_if_candidate", "r_action", "r_action_reason",
      "r_peer_weighted_mkt_lfr", "r_peer_equal_wt_lfr",
      "r_peer_p25_lfr", "r_peer_median_lfr", "r_peer_p75_lfr",
      "r_peer_p90_lfr", "r_peer_p95_lfr",
      "r_peer_weighted_mkt_lfr_ts", "r_peer_p75_lfr_ts", "r_peer_p90_lfr_ts",
      "r_n_clean_p75", "r_meets_volume_floor", "r_volume_band",
      "analysis_window_end", "overall"
    )
    evidence_cols <- evidence_cols[evidence_cols %in% names(df)]

    # seller_id identity path: one row per seller with evidence + counts/rates.
    # Do not aggregate evidence away.
    if (identical(group, entity) || identical(group, "seller_id")) {
      counts <- df %>%
        dplyr::mutate(
          seller_n           = 1L,
          on_time_n          = .data$on_time_n_date,
          enroll_n           = as.integer(.data$action == "enroll"),
          watch_n            = as.integer(.data$action == "watch"),
          inconclusive_n     = as.integer(.data$action == "inconclusive"),
          standard_terms_n   = as.integer(.data$action == "standard_terms")
        )
      count_keep <- unique(c(
        group,
        "seller_n", "eligible_n", "late_n", "on_time_n", "late_n_ts",
        "multi_seller_order_n", "anomaly_n", "item_revenue",
        "item_revenue_plus_freight", "enroll_n", "watch_n",
        "inconclusive_n", "standard_terms_n",
        evidence_cols
      ))
      count_keep <- count_keep[count_keep %in% names(counts)]
      counts <- counts %>% dplyr::select(dplyr::all_of(count_keep))

      rates <- df %>%
        dplyr::mutate(
          weighted_lfr_date               = .data$recalc_lfr_date,
          equal_mean_seller_lfr_date      = .data$lfr_date,
          weighted_lfr_timestamp          = .data$recalc_lfr_timestamp,
          equal_mean_seller_lfr_timestamp = .data$lfr_timestamp,
          multi_seller_order_share        = .data$recalc_multi_seller_order_share
        )
      rate_keep <- unique(c(
        group,
        "weighted_lfr_date", "equal_mean_seller_lfr_date",
        "weighted_lfr_timestamp", "equal_mean_seller_lfr_timestamp",
        "multi_seller_order_share", "anomaly_share",
        evidence_cols
      ))
      rate_keep <- rate_keep[rate_keep %in% names(rates)]
      rates <- rates %>% dplyr::select(dplyr::all_of(rate_keep))
      return(list(counts = counts, rates = rates))
    }

    grouped <- df %>% dplyr::group_by(.data[[group]])
    list(counts = count_core(grouped), rates = rate_core(grouped))
  }

  measured <- purrr::map(CONFIG$groups, function(group) {
    metric_fun(pieces[[group]], group, CONFIG)
  }) %>%
    purrr::set_names(CONFIG$groups)

  # Robustness tibbles live on overall as extra named metrics (not extra stages).
  # State is the seller_state group. Volume bands also appear as overall$volume_bands.
  entity_df <- pieces[[entity]]
  measured$overall$precision <- entity_df %>%
    dplyr::filter(
      .data$date_ts_action_conflict == 1L |
        .data$r_date_ts_action_conflict == 1L
    ) %>%
    dplyr::select(dplyr::any_of(c(
      entity, "eligible_n", "late_n", "lfr_date", "lfr_timestamp",
      "precision_delta", "pass_p75", "r_pass_p75", "r_pass_p75_ts",
      "date_ts_action_conflict", "r_date_ts_action_conflict",
      "action", "action_reason", "r_action", "r_action_reason"
    )))
  measured$overall$stability <- entity_df %>%
    dplyr::filter(
      .data$split_window_unstable == 1L |
        .data$r_split_window_unstable == 1L
    ) %>%
    dplyr::select(dplyr::any_of(c(
      entity, "eligible_n", "eligible_n_jan_apr", "eligible_n_may_aug",
      "lfr_date", "lfr_jan_apr", "lfr_may_aug", "split_window_delta",
      "peer_p75_lfr", "peer_median_lfr",
      "split_window_unstable", "r_split_window_unstable",
      "action", "action_reason"
    )))
  measured$overall$attribution <- entity_df %>%
    dplyr::filter(
      .data$attribution_conflict == 1L |
        .data$r_attribution_conflict == 1L
    ) %>%
    dplyr::select(dplyr::any_of(c(
      entity, "eligible_n", "eligible_n_single", "late_n", "late_n_single",
      "lfr_date", "lfr_single_seller", "attribution_delta",
      "multi_seller_order_share", "peer_p75_lfr", "peer_weighted_mkt_lfr",
      "attribution_conflict", "r_attribution_conflict",
      "action", "action_reason"
    )))
  measured$overall$volume_bands <- metric_fun(entity_df, "volume_band", CONFIG)$counts

  attr(measured, "load_meta") <- attr(pieces, "load_meta")
  attr(measured, "complete_skipped") <- isTRUE(attr(pieces, "complete_skipped"))
  attr(measured, "problems_complete") <- attr(pieces, "problems_complete")
  measured
}

expand <- function(measured, CONFIG) {
  # Expand binds .pred onto existing rolling/monthly rows via parsnip.
  # CONFIG$expand is FALSE for this run — skip (ENGINE skip rule).
  # pack=short has no rolling/monthly tibbles. Stage 3 forbids a forecast.
  measured
}

int_mismatch <- function(a, b) {
  !( (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b) )
}
chr_mismatch <- function(a, b) {
  !( (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b) )
}
rate_mismatch <- function(a, b, tol = RATE_TOL) {
  both_na <- is.na(a) & is.na(b)
  !both_na & (is.na(a) | is.na(b) | abs(a - b) > tol)
}

assure <- function(x, CONFIG, gate = "complete") {
  problems <- empty_problems()
  entity <- CONFIG$entity_key

  if (identical(gate, "complete")) {
    daily <- x
    load_meta <- attr(daily, "load_meta")

    req <- unique(c(SQL_EXPORT_COLS, entity, CONFIG$time_key, "overall"))
    missing <- req[req %not_in% names(daily)]
    if (length(missing) > 0L) {
      problems <- add_problem(
        problems, gate, "required_cols", "fatal", length(missing),
        paste(missing, collapse = ", ")
      )
    }

    id_vec <- dplyr::pull(daily, !!sym(entity))
    n_na_id <- sum(is.na(id_vec) | id_vec == "")
    if (n_na_id > 0L) {
      problems <- add_problem(
        problems, gate, "seller_id_na", "fatal", n_na_id,
        "seller_id has NA or blank values"
      )
    }
    n_dup <- sum(duplicated(id_vec))
    if (n_dup > 0L) {
      problems <- add_problem(
        problems, gate, "seller_id_unique", "fatal", n_dup,
        "seller_id is not unique (one row per seller required)"
      )
    }

    n_eligible_le0 <- sum(is.na(daily$eligible_n) | daily$eligible_n <= 0L)
    if (n_eligible_le0 > 0L) {
      problems <- add_problem(
        problems, gate, "eligible_n_positive", "fatal", n_eligible_le0,
        "eligible_n must be > 0"
      )
    }
    n_late_neg <- sum(is.na(daily$late_n) | daily$late_n < 0L)
    if (n_late_neg > 0L) {
      problems <- add_problem(
        problems, gate, "late_n_nonneg", "fatal", n_late_neg,
        "late_n must be >= 0"
      )
    }
    n_late_ts_neg <- sum(is.na(daily$late_n_ts) | daily$late_n_ts < 0L)
    if (n_late_ts_neg > 0L) {
      problems <- add_problem(
        problems, gate, "late_n_ts_nonneg", "fatal", n_late_ts_neg,
        "late_n_ts must be >= 0"
      )
    }
    n_late_gt <- sum(daily$late_n > daily$eligible_n, na.rm = TRUE)
    if (n_late_gt > 0L) {
      problems <- add_problem(
        problems, gate, "late_n_le_eligible", "fatal", n_late_gt,
        "late_n exceeds eligible_n"
      )
    }
    n_late_ts_gt <- sum(daily$late_n_ts > daily$eligible_n, na.rm = TRUE)
    if (n_late_ts_gt > 0L) {
      problems <- add_problem(
        problems, gate, "late_n_ts_le_eligible", "fatal", n_late_ts_gt,
        "late_n_ts exceeds eligible_n"
      )
    }
    n_ontime_neg <- sum(is.na(daily$on_time_n_date) | daily$on_time_n_date < 0L)
    if (n_ontime_neg > 0L) {
      problems <- add_problem(
        problems, gate, "on_time_n_nonneg", "fatal", n_ontime_neg,
        "on_time_n_date must be >= 0"
      )
    }
    n_sum <- sum(daily$late_n + daily$on_time_n_date != daily$eligible_n,
                 na.rm = TRUE)
    if (n_sum > 0L) {
      problems <- add_problem(
        problems, gate, "late_plus_ontime_eq_eligible", "fatal", n_sum,
        "late_n + on_time_n_date != eligible_n"
      )
    }

    rate_cols <- c(
      "lfr_date", "lfr_timestamp", "lfr_jan_apr", "lfr_may_aug",
      "lfr_single_seller", "multi_seller_order_share"
    )
    rate_cols <- rate_cols[rate_cols %in% names(daily)]
    for (nm in rate_cols) {
      v <- dplyr::pull(daily, !!sym(nm))
      n_bad <- sum(!is.na(v) & (v < 0 | v > 1))
      if (n_bad > 0L) {
        problems <- add_problem(
          problems, gate, paste0("rate_range_", nm), "fatal", n_bad,
          paste0(nm, " outside [0,1] when nonmissing")
        )
      }
    }
    pct_cols <- c("lfr_date_pct", "lfr_timestamp_pct")
    pct_cols <- pct_cols[pct_cols %in% names(daily)]
    for (nm in pct_cols) {
      v <- dplyr::pull(daily, !!sym(nm))
      n_bad <- sum(!is.na(v) & (v < 0 | v > 100))
      if (n_bad > 0L) {
        problems <- add_problem(
          problems, gate, paste0("pct_range_", nm), "fatal", n_bad,
          paste0(nm, " outside [0,100]")
        )
      }
    }
    n_rev <- sum(daily$item_revenue < 0 | daily$item_revenue_plus_freight < 0,
                 na.rm = TRUE)
    if (n_rev > 0L) {
      problems <- add_problem(
        problems, gate, "revenue_nonneg", "fatal", n_rev,
        "item_revenue or item_revenue_plus_freight < 0"
      )
    }
    n_multi <- sum(daily$multi_seller_order_n > daily$eligible_n, na.rm = TRUE)
    if (n_multi > 0L) {
      problems <- add_problem(
        problems, gate, "multi_le_eligible", "fatal", n_multi,
        "multi_seller_order_n exceeds eligible_n"
      )
    }
    n_anom <- sum(daily$anomaly_n > daily$eligible_n, na.rm = TRUE)
    if (n_anom > 0L) {
      problems <- add_problem(
        problems, gate, "anomaly_le_eligible", "fatal", n_anom,
        "anomaly_n exceeds eligible_n"
      )
    }
    n_act <- sum(daily$action %not_in% LEGAL_ACTIONS)
    if (n_act > 0L) {
      problems <- add_problem(
        problems, gate, "action_domain", "fatal", n_act,
        "action not in enroll/watch/standard_terms/inconclusive"
      )
    }
    n_band <- sum(daily$volume_band %not_in% LEGAL_BANDS)
    if (n_band > 0L) {
      problems <- add_problem(
        problems, gate, "volume_band_domain", "fatal", n_band,
        "volume_band not in below_floor/30_49/50_99/100_plus"
      )
    }

    n_end <- sum(daily$analysis_window_end != as.Date("2018-08-31"), na.rm = TRUE) +
      sum(is.na(daily$analysis_window_end))
    if (n_end > 0L) {
      problems <- add_problem(
        problems, gate, "analysis_window_end_constant", "fatal", n_end,
        "analysis_window_end must be constant Date 2018-08-31"
      )
    }
    if (!identical(CONFIG$grain, "seller-window")) {
      problems <- add_problem(
        problems, gate, "grain_unchanged", "fatal", 1L,
        paste0("CONFIG$grain is '", CONFIG$grain, "'; expected seller-window")
      )
    }
    if (!isTRUE(attr(daily, "complete_skipped"))) {
      problems <- add_problem(
        problems, gate, "complete_must_skip", "fatal", 1L,
        "seller-window grain must skip Complete"
      )
    }
    if (!identical(as.integer(CONFIG$window_days), 243L)) {
      problems <- add_problem(
        problems, gate, "window_days", "fatal", 1L,
        paste0("window_days=", CONFIG$window_days, "; expected 243")
      )
    }

    if (!is.null(load_meta)) {
      if (!identical(load_meta$n_pre_join, load_meta$n_post_join)) {
        problems <- add_problem(
          problems, gate, "join_explode", "fatal",
          load_meta$n_post_join - load_meta$n_pre_join,
          "lookup join multiplied rows; lookup is a documented no-op"
        )
      }
      if (load_meta$lookup_rows > 0L &&
          load_meta$lookup_rows != load_meta$lookup_distinct_keys) {
        problems <- add_problem(
          problems, gate, "lookup_key_cardinality", "fatal",
          load_meta$lookup_rows - load_meta$lookup_distinct_keys,
          "lookup keys are not one-per-entity"
        )
      }
    }

    # KPI recon vs SQL export (DECIMAL float tolerance).
    n_lfr <- sum(rate_mismatch(daily$lfr_date, daily$recalc_lfr_date))
    if (n_lfr > 0L) {
      problems <- add_problem(
        problems, gate, "lfr_date_recalc", "fatal", n_lfr,
        "lfr_date does not match late_n/eligible_n"
      )
    }
    n_lfr_ts <- sum(rate_mismatch(daily$lfr_timestamp, daily$recalc_lfr_timestamp))
    if (n_lfr_ts > 0L) {
      problems <- add_problem(
        problems, gate, "lfr_timestamp_recalc", "fatal", n_lfr_ts,
        "lfr_timestamp does not match late_n_ts/eligible_n"
      )
    }
    # Display percents (0-100). SQL ROUND vs R half-up can differ by 0.1 pp.
    # Not a KPI lock. Info if tiny; fatal only if off by >= 0.5 pp.
    n_pct <- sum(rate_mismatch(daily$lfr_date_pct, daily$r_lfr_date_pct, 0.5))
    if (n_pct > 0L) {
      problems <- add_problem(
        problems, gate, "lfr_date_pct_round", "fatal", n_pct,
        "lfr_date_pct differs from 100*lfr_date by >= 0.5 pp"
      )
    } else {
      n_pct_info <- sum(rate_mismatch(daily$lfr_date_pct, daily$r_lfr_date_pct, 0.05))
      if (n_pct_info > 0L) {
        problems <- add_problem(
          problems, gate, "lfr_date_pct_round", "info", n_pct_info,
          "lfr_date_pct SQL/R display rounding differs by < 0.5 pp"
        )
      }
    }
    n_pct_ts <- sum(rate_mismatch(daily$lfr_timestamp_pct, daily$r_lfr_timestamp_pct, 0.5))
    if (n_pct_ts > 0L) {
      problems <- add_problem(
        problems, gate, "lfr_timestamp_pct_round", "fatal", n_pct_ts,
        "lfr_timestamp_pct differs from 100*lfr_timestamp by >= 0.5 pp"
      )
    } else {
      n_pct_ts_info <- sum(rate_mismatch(daily$lfr_timestamp_pct, daily$r_lfr_timestamp_pct, 0.05))
      if (n_pct_ts_info > 0L) {
        problems <- add_problem(
          problems, gate, "lfr_timestamp_pct_round", "info", n_pct_ts_info,
          "lfr_timestamp_pct SQL/R display rounding differs by < 0.5 pp"
        )
      }
    }
    n_frac <- sum(chr_mismatch(daily$late_over_eligible, daily$r_late_over_eligible))
    if (n_frac > 0L) {
      problems <- add_problem(
        problems, gate, "late_over_eligible", "fatal", n_frac,
        "late_over_eligible != paste(late_n, '/', eligible_n)"
      )
    }
    n_floor_flag <- sum(int_mismatch(daily$meets_volume_floor, daily$r_meets_volume_floor))
    if (n_floor_flag > 0L) {
      problems <- add_problem(
        problems, gate, "meets_volume_floor", "fatal", n_floor_flag,
        "meets_volume_floor != (eligible_n >= 30)"
      )
    }
    n_vb <- sum(chr_mismatch(daily$volume_band, daily$r_volume_band))
    if (n_vb > 0L) {
      problems <- add_problem(
        problems, gate, "volume_band_rule", "fatal", n_vb,
        "volume_band does not match eligible_n cuts"
      )
    }

    # Exported peer fields must be constant across rows.
    peer_sql <- c(
      "n_floor_sellers", "peer_weighted_mkt_lfr", "peer_equal_wt_lfr",
      "peer_p25_lfr", "peer_median_lfr", "peer_p75_lfr", "peer_p90_lfr",
      "peer_p95_lfr", "raise_bar_to_p90"
    )
    for (nm in peer_sql) {
      n_u <- dplyr::n_distinct(dplyr::pull(daily, !!sym(nm)))
      if (n_u != 1L) {
        problems <- add_problem(
          problems, gate, paste0("peer_constant_", nm), "fatal", n_u,
          paste0(nm, " is not constant across seller rows")
        )
      }
    }

    # Nearest-rank vs SQL peers; r_* flags vs SQL flags.
    recon_rate <- list(
      n_floor_sellers         = list(daily$n_floor_sellers, daily$r_n_floor_sellers, 0.5),
      peer_weighted_mkt_lfr   = list(daily$peer_weighted_mkt_lfr, daily$r_peer_weighted_mkt_lfr, RATE_TOL),
      peer_equal_wt_lfr       = list(daily$peer_equal_wt_lfr, daily$r_peer_equal_wt_lfr, RATE_TOL),
      peer_p25_lfr            = list(daily$peer_p25_lfr, daily$r_peer_p25_lfr, RATE_TOL),
      peer_median_lfr         = list(daily$peer_median_lfr, daily$r_peer_median_lfr, RATE_TOL),
      peer_p75_lfr            = list(daily$peer_p75_lfr, daily$r_peer_p75_lfr, RATE_TOL),
      peer_p90_lfr            = list(daily$peer_p90_lfr, daily$r_peer_p90_lfr, RATE_TOL),
      peer_p95_lfr            = list(daily$peer_p95_lfr, daily$r_peer_p95_lfr, RATE_TOL)
    )
    for (nm in names(recon_rate)) {
      pair <- recon_rate[[nm]]
      n_bad <- sum(rate_mismatch(pair[[1]], pair[[2]], pair[[3]]))
      if (n_bad > 0L) {
        problems <- add_problem(
          problems, gate, paste0("peer_recompute_", nm), "fatal", n_bad,
          paste0("SQL ", nm, " does not match nearest-rank / weighted recompute")
        )
      }
    }

    flag_pairs <- list(
      pass_p75                = list(daily$pass_p75, daily$r_pass_p75),
      pass_p90                = list(daily$pass_p90, daily$r_pass_p90),
      attribution_conflict    = list(daily$attribution_conflict, daily$r_attribution_conflict),
      date_ts_action_conflict = list(daily$date_ts_action_conflict, daily$r_date_ts_action_conflict),
      split_window_unstable   = list(daily$split_window_unstable, daily$r_split_window_unstable),
      raise_bar_to_p90        = list(daily$raise_bar_to_p90, daily$r_raise_bar_to_p90),
      rank_if_candidate       = list(daily$rank_if_candidate, daily$r_rank_if_candidate)
    )
    for (nm in names(flag_pairs)) {
      pair <- flag_pairs[[nm]]
      n_bad <- sum(int_mismatch(pair[[1]], pair[[2]]))
      if (n_bad > 0L) {
        problems <- add_problem(
          problems, gate, paste0("flag_", nm), "fatal", n_bad,
          paste0("SQL ", nm, " does not match r_", nm)
        )
      }
    }
    n_action <- sum(chr_mismatch(daily$action, daily$r_action))
    if (n_action > 0L) {
      problems <- add_problem(
        problems, gate, "action_match", "fatal", n_action,
        "SQL action does not match r_action CASE"
      )
    }
    n_reason <- sum(chr_mismatch(daily$action_reason, daily$r_action_reason))
    if (n_reason > 0L) {
      problems <- add_problem(
        problems, gate, "action_reason_match", "fatal", n_reason,
        "SQL action_reason does not match r_action_reason CASE"
      )
    }

    if (!is.null(load_meta) && !is.null(load_meta$problems)) {
      problems <- dplyr::bind_rows(load_meta$problems, problems)
    }
    halt_if_fatal(problems)
    attr(daily, "problems_complete") <- problems
    return(invisible(daily))
  }

  if (identical(gate, "measure")) {
    measured <- x
    seller <- measured[[entity]]$counts
    overall_c <- measured$overall$counts
    overall_r <- measured$overall$rates

    n_dup <- sum(duplicated(dplyr::pull(seller, !!sym(entity))))
    if (n_dup > 0L) {
      problems <- add_problem(
        problems, gate, "one_seller_per_id", "fatal", n_dup,
        "measured seller_id frame is not one row per seller"
      )
    }

    if (nrow(overall_c) != 1L) {
      problems <- add_problem(
        problems, gate, "overall_one_row", "fatal", nrow(overall_c),
        "overall counts must be one row"
      )
    } else {
      if (overall_c$seller_n != nrow(seller)) {
        problems <- add_problem(
          problems, gate, "group_total_seller_n", "fatal",
          abs(overall_c$seller_n - nrow(seller)),
          "overall seller_n != nrow(seller_id)"
        )
      }
      if (overall_c$eligible_n != sum(seller$eligible_n)) {
        problems <- add_problem(
          problems, gate, "group_total_eligible_n", "fatal",
          abs(overall_c$eligible_n - sum(seller$eligible_n)),
          "overall eligible_n != sum(seller eligible_n)"
        )
      }
      if (overall_c$late_n != sum(seller$late_n)) {
        problems <- add_problem(
          problems, gate, "group_total_late_n", "fatal",
          abs(overall_c$late_n - sum(seller$late_n)),
          "overall late_n != sum(seller late_n)"
        )
      }
      if (overall_c$enroll_n != sum(seller$action == "enroll")) {
        problems <- add_problem(
          problems, gate, "group_total_enroll_n", "fatal",
          abs(overall_c$enroll_n - sum(seller$action == "enroll")),
          "overall enroll_n != count(action==enroll)"
        )
      }
    }

    w_all <- sum(seller$late_n) / sum(seller$eligible_n)
    if (nrow(overall_r) == 1L &&
        rate_mismatch(overall_r$weighted_lfr_date, w_all)) {
      problems <- add_problem(
        problems, gate, "weighted_lfr_vs_sums", "fatal", 1L,
        "overall weighted_lfr_date != sum(late_n)/sum(eligible_n)"
      )
    }

    n_floor <- as.integer(sum(seller$eligible_n >= 30L))
    sql_n_floor <- seller %>%
      dplyr::distinct(.data$n_floor_sellers) %>%
      dplyr::pull("n_floor_sellers")
    if (length(sql_n_floor) != 1L || sql_n_floor != n_floor) {
      problems <- add_problem(
        problems, gate, "n_floor", "fatal",
        abs(n_floor - ifelse(length(sql_n_floor) == 1L, sql_n_floor, NA_integer_)),
        "n_floor_sellers != count(eligible_n>=30) or is not constant"
      )
    }

    n_lfr <- sum(rate_mismatch(seller$lfr_date, seller$recalc_lfr_date))
    if (n_lfr > 0L) {
      problems <- add_problem(
        problems, gate, "recalc_kpi_lfr_date", "fatal", n_lfr,
        "seller lfr_date != recalc_lfr_date"
      )
    }

    n_p75 <- sum(int_mismatch(seller$pass_p75, seller$r_pass_p75))
    n_p90 <- sum(int_mismatch(seller$pass_p90, seller$r_pass_p90))
    n_attr <- sum(int_mismatch(seller$attribution_conflict, seller$r_attribution_conflict))
    n_prec <- sum(int_mismatch(seller$date_ts_action_conflict, seller$r_date_ts_action_conflict))
    n_split <- sum(int_mismatch(seller$split_window_unstable, seller$r_split_window_unstable))
    n_raise <- sum(int_mismatch(seller$raise_bar_to_p90, seller$r_raise_bar_to_p90))
    n_rank <- sum(int_mismatch(seller$rank_if_candidate, seller$r_rank_if_candidate))
    n_act <- sum(chr_mismatch(seller$action, seller$r_action))
    n_rsn <- sum(chr_mismatch(seller$action_reason, seller$r_action_reason))
    flag_n <- c(
      pass_p75 = n_p75, pass_p90 = n_p90, attribution = n_attr,
      precision = n_prec, split = n_split, raise_bar = n_raise,
      rank = n_rank, action = n_act, action_reason = n_rsn
    )
    for (nm in names(flag_n)) {
      if (flag_n[[nm]] > 0L) {
        problems <- add_problem(
          problems, gate, paste0("measure_flag_", nm), "fatal", flag_n[[nm]],
          paste0("measured seller frame SQL vs r_* mismatch on ", nm)
        )
      }
    }

    n_peer <- sum(rate_mismatch(seller$peer_p75_lfr, seller$r_peer_p75_lfr))
    if (n_peer > 0L) {
      problems <- add_problem(
        problems, gate, "nearest_rank_vs_sql_p75", "fatal", n_peer,
        "nearest-rank P75 does not match SQL peer_p75_lfr"
      )
    }

    # Compact: keep fatal + load info rows.
    prior <- attr(measured, "problems_complete")
    if (is.null(prior)) prior <- empty_problems()
    problems <- dplyr::bind_rows(prior, problems)
    halt_if_fatal(problems)
    attr(measured, "problems") <- problems
    return(invisible(measured))
  }

  stop("Unknown assure gate: ", gate, call. = FALSE)
}

build_four_figures <- function(seller) {
  p75 <- unique(dplyr::pull(seller, "peer_p75_lfr"))[1]
  p90 <- unique(dplyr::pull(seller, "peer_p90_lfr"))[1]
  p95 <- unique(dplyr::pull(seller, "peer_p95_lfr"))[1]
  wtd <- unique(dplyr::pull(seller, "peer_weighted_mkt_lfr"))[1]

  p1 <- ggplot2::ggplot(
    seller,
    ggplot2::aes(x = .data$eligible_n, y = .data$lfr_date, color = .data$action)
  ) +
    ggplot2::geom_point(alpha = 0.75, size = 1.7) +
    ggplot2::geom_vline(xintercept = 30, linetype = "dashed") +
    ggplot2::geom_hline(yintercept = p75, linetype = "dashed") +
    ggplot2::labs(
      title = "Seller late-fulfillment rate versus eligible volume",
      subtitle = "Dashed lines: volume floor n = 30 and date-rule P75 peer bar",
      x = "Eligible seller-orders (n)",
      y = "LFR (date rule)",
      color = "action"
    ) +
    ggplot2::theme_minimal()

  floor_s <- seller %>% dplyr::filter(.data$eligible_n >= 30L)
  p2 <- ggplot2::ggplot(floor_s, ggplot2::aes(x = .data$lfr_date)) +
    ggplot2::geom_histogram(
      ggplot2::aes(y = ggplot2::after_stat(density)),
      bins = 30, alpha = 0.45, fill = "grey70", color = "white"
    ) +
    ggplot2::geom_density() +
    ggplot2::geom_vline(xintercept = wtd) +
    ggplot2::geom_vline(xintercept = p75, linetype = "dashed") +
    ggplot2::geom_vline(xintercept = p90, linetype = "dotted") +
    ggplot2::geom_vline(xintercept = p95, linetype = "dotdash", alpha = 0.45) +
    ggplot2::labs(
      title = "LFR distribution among sellers with n >= 30",
      subtitle = "Vertical lines: weighted LFR, P75, P90; P95 descriptive only",
      x = "LFR (date rule)",
      y = "Density"
    ) +
    ggplot2::theme_minimal()

  p3 <- ggplot2::ggplot(
    seller,
    ggplot2::aes(x = .data$lfr_date, y = .data$lfr_timestamp)
  ) +
    ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
    ggplot2::geom_point(
      ggplot2::aes(color = .data$date_ts_action_conflict == 1L),
      alpha = 0.75, size = 1.7
    ) +
    ggplot2::labs(
      title = "Date-rule LFR versus timestamp-rule LFR",
      subtitle = "Highlighted points: date_ts_action_conflict = 1",
      x = "LFR (date rule)",
      y = "LFR (timestamp rule)",
      color = "date vs ts conflict"
    ) +
    ggplot2::theme_minimal()

  split_df <- seller %>%
    dplyr::filter(!is.na(.data$lfr_jan_apr), !is.na(.data$lfr_may_aug))
  p4 <- ggplot2::ggplot(
    split_df,
    ggplot2::aes(x = .data$lfr_jan_apr, y = .data$lfr_may_aug)
  ) +
    ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
    ggplot2::geom_point(
      ggplot2::aes(color = .data$split_window_unstable == 1L),
      alpha = 0.75, size = 1.7
    ) +
    ggplot2::labs(
      title = "Jan-Apr LFR versus May-Aug LFR",
      subtitle = "Highlighted points: split_window_unstable = 1",
      x = "LFR Jan-Apr",
      y = "LFR May-Aug",
      color = "split-window unstable"
    ) +
    ggplot2::theme_minimal()

  list(volume = p1, distribution = p2, precision = p3, stability = p4)
}

publish <- function(measured, CONFIG) {
  # Same nested tibbles. No recomputation. Flatten sheet names here only.
  if ("excel" %not_in% CONFIG$publish) {
    return(invisible(measured))
  }
  entity <- CONFIG$entity_key
  run_date <- Sys.Date()
  date_txt <- format(run_date, "%Y-%m-%d")
  out_dir <- file.path("results", date_txt)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_path <- file.path(out_dir, paste0("FulfillIQ_R_Evidence_", date_txt, ".xlsx"))

  seller <- measured[[entity]]$counts
  load_meta <- attr(measured, "load_meta")
  problems <- attr(measured, "problems")
  if (is.null(problems)) problems <- empty_problems()

  wb <- openxlsx::createWorkbook()
  pct_style <- openxlsx::createStyle(numFmt = "0.00%")

  add_tbl_sheet <- function(sheet, tbl) {
    sheet <- substr(sheet, 1L, 31L)
    if (sheet %in% wb$sheet_names) {
      sheet <- substr(paste0(sheet, "_2"), 1L, 31L)
    }
    openxlsx::addWorksheet(wb, sheet)
    if (is.null(tbl) || !is.data.frame(tbl)) {
      tbl <- tibble::tibble(note = "empty")
    }
    openxlsx::writeData(wb, sheet, tbl)
    if (nrow(tbl) > 0L && ncol(tbl) > 0L) {
      openxlsx::freezePane(wb, sheet, firstRow = TRUE, firstCol = TRUE)
      nms <- names(tbl)
      for (nm in nms) {
        if (is_rate_col(nm)) {
          j <- match(nm, nms)
          openxlsx::addStyle(
            wb, sheet, pct_style,
            rows = 2:(nrow(tbl) + 1L), cols = j,
            gridExpand = TRUE
          )
        }
      }
    }
    invisible(sheet)
  }

  # Engine sheets: flatten paste(group, metric, sep = "__") only at Publish.
  purrr::iwalk(measured, function(metrics, group_name) {
    purrr::iwalk(metrics, function(tbl, metric_name) {
      add_tbl_sheet(paste(group_name, metric_name, sep = "__"), tbl)
    })
  })

  # Additional filtered views from already-measured objects (no second compute).
  lineage <- if (!is.null(load_meta) && !is.null(load_meta$lineage)) {
    load_meta$lineage
  } else {
    tibble::tibble(note = "lineage unavailable")
  }
  qa <- dplyr::bind_rows(
    problems,
    tibble::tibble(
      gate = "publish", check = "lineage", severity = "info", n = nrow(lineage),
      detail = paste(
        "source", lineage$source_repo[1],
        "csv", lineage$csv_path[1],
        "read", lineage$read_timestamp[1]
      )
    )
  )
  add_tbl_sheet("QA", qa)
  add_tbl_sheet("lineage", lineage)

  overall_view <- dplyr::left_join(
    measured$overall$counts, measured$overall$rates, by = "overall"
  )
  add_tbl_sheet("overall", overall_view)
  add_tbl_sheet("seller", seller)

  peer_cols <- c(
    "n_floor_sellers", "peer_weighted_mkt_lfr", "peer_equal_wt_lfr",
    "peer_p25_lfr", "peer_median_lfr", "peer_p75_lfr", "peer_p90_lfr",
    "peer_p95_lfr", "raise_bar_to_p90",
    "r_n_floor_sellers", "r_peer_weighted_mkt_lfr", "r_peer_equal_wt_lfr",
    "r_peer_p25_lfr", "r_peer_median_lfr", "r_peer_p75_lfr",
    "r_peer_p90_lfr", "r_peer_p95_lfr",
    "r_peer_weighted_mkt_lfr_ts", "r_peer_p75_lfr_ts", "r_peer_p90_lfr_ts",
    "r_n_clean_p75", "r_raise_bar_to_p90"
  )
  peer_cols <- peer_cols[peer_cols %in% names(seller)]
  peer_view <- seller %>% dplyr::distinct(dplyr::across(dplyr::all_of(peer_cols)))
  add_tbl_sheet("peer", peer_view)

  vol_view <- dplyr::left_join(
    measured$volume_band$counts, measured$volume_band$rates, by = "volume_band"
  )
  add_tbl_sheet("volume", vol_view)

  state_view <- dplyr::left_join(
    measured$seller_state$counts, measured$seller_state$rates, by = "seller_state"
  )
  add_tbl_sheet("state", state_view)

  add_tbl_sheet("precision", measured$overall$precision)
  add_tbl_sheet("stability", measured$overall$stability)
  add_tbl_sheet("attribution", measured$overall$attribution)

  add_tbl_sheet("enroll", seller %>% dplyr::filter(.data$action == "enroll"))
  add_tbl_sheet("watch", seller %>% dplyr::filter(.data$action == "watch"))
  add_tbl_sheet("inconclusive", seller %>% dplyr::filter(.data$action == "inconclusive"))
  add_tbl_sheet(
    "below_floor_appendix",
    seller %>% dplyr::filter(.data$volume_band == "below_floor")
  )

  figs <- build_four_figures(seller)
  fig_dir <- file.path(out_dir, "figures")
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
  f1 <- file.path(fig_dir, "fig1_volume.png")
  f2 <- file.path(fig_dir, "fig2_distribution.png")
  f3 <- file.path(fig_dir, "fig3_precision.png")
  f4 <- file.path(fig_dir, "fig4_stability.png")
  ggplot2::ggsave(f1, figs$volume, width = 9, height = 5, dpi = 150, bg = "white")
  ggplot2::ggsave(f2, figs$distribution, width = 9, height = 5, dpi = 150, bg = "white")
  ggplot2::ggsave(f3, figs$precision, width = 9, height = 5, dpi = 150, bg = "white")
  ggplot2::ggsave(f4, figs$stability, width = 9, height = 5, dpi = 150, bg = "white")
  openxlsx::addWorksheet(wb, "charts")
  openxlsx::insertImage(wb, "charts", f1, startRow = 1, startCol = 1, width = 9, height = 5)
  openxlsx::insertImage(wb, "charts", f2, startRow = 28, startCol = 1, width = 9, height = 5)
  openxlsx::insertImage(wb, "charts", f3, startRow = 55, startCol = 1, width = 9, height = 5)
  openxlsx::insertImage(wb, "charts", f4, startRow = 82, startCol = 1, width = 9, height = 5)

  openxlsx::saveWorkbook(wb, out_path, overwrite = TRUE)
  invisible(measured)
}

run_report <- function(CONFIG) {
  CONFIG <- configure(CONFIG)
  daily <- load(CONFIG)
  daily <- clean(daily, CONFIG)
  daily <- complete(daily, CONFIG)
  daily <- assure(daily, CONFIG, gate = "complete")
  pieces <- shape(daily, CONFIG)
  measured <- measure(pieces, CONFIG)
  measured <- assure(measured, CONFIG, gate = "measure")
  if (isTRUE(CONFIG$expand)) {
    measured <- expand(measured, CONFIG)
  }
  # Expand skipped when CONFIG$expand is FALSE (this run).
  publish(measured, CONFIG)
  invisible(measured)
}

# Not a synthetic demo. CSV must exist at the locked output/ path.
run_report(CONFIG)
