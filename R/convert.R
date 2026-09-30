# -----------------------------------------------------------------------------
# SAS <-> R teaching converter
# Heuristic / pattern-based. Not a full language compiler.
# Designed for common DATA step and PROC patterns used while learning.
# -----------------------------------------------------------------------------

trim_ws <- function(x) {
  gsub("^\\s+|\\s+$", "", x)
}

normalize_newlines <- function(code) {
  code <- gsub("\r\n", "\n", code, fixed = TRUE)
  code <- gsub("\r", "\n", code, fixed = TRUE)
  code
}

strip_trailing_semicolons <- function(x) {
  gsub(";+\\s*$", "", x)
}

# Split SAS into statement-ish chunks ending with ;
split_sas_statements <- function(code) {
  code <- normalize_newlines(code)
  # Protect quoted strings so internal ; is not a splitter (simple heuristic)
  parts <- unlist(strsplit(code, ";"))
  parts <- trim_ws(parts)
  parts <- parts[nzchar(parts)]
  parts
}

extract_data_opt <- function(text, default = "df") {
  m <- regexpr("data\\s*=\\s*([A-Za-z_][A-Za-z0-9_.]*)", text, ignore.case = TRUE, perl = TRUE)
  if (m[1] > 0) {
    cap <- regmatches(text, m)
    return(sub("(?i)data\\s*=\\s*", "", cap, perl = TRUE))
  }
  default
}

extract_named <- function(text, name, default = NA_character_) {
  pat <- paste0("(?i)\\b", name, "\\s*=\\s*([^\\s;]+)")
  m <- regexpr(pat, text, perl = TRUE)
  if (m[1] > 0) {
    cap <- regmatches(text, m)
    return(sub(paste0("(?i)", name, "\\s*=\\s*"), "", cap, perl = TRUE))
  }
  default
}

first_ident_after <- function(text, keyword) {
  pat <- paste0("(?i)\\b", keyword, "\\s+([A-Za-z_][A-Za-z0-9_.]*)")
  m <- regexpr(pat, text, perl = TRUE)
  if (m[1] > 0) {
    cap <- regmatches(text, m)
    return(sub(paste0("(?i)", keyword, "\\s+"), "", cap, perl = TRUE))
  }
  NA_character_
}

vars_after <- function(text, keyword) {
  pat <- paste0("(?i)\\b", keyword, "\\s+(.+)$")
  m <- regexpr(pat, text, perl = TRUE)
  if (m[1] < 0) return(character(0))
  rest <- sub(paste0("(?i)", keyword, "\\s+"), "", regmatches(text, m), perl = TRUE)
  rest <- gsub("/.*$", "", rest)
  toks <- unlist(strsplit(rest, "[,\\s]+"))
  toks <- toks[nzchar(toks)]
  toks
}

r_ident <- function(x) {
  x <- gsub("\\.", "_", x)
  x
}

sas_eq_to_r <- function(expr) {
  expr <- trim_ws(expr)
  expr <- gsub("(?i)\\beq\\b", "==", expr, perl = TRUE)
  expr <- gsub("(?i)\\bne\\b", "!=", expr, perl = TRUE)
  expr <- gsub("(?i)\\bgt\\b", ">", expr, perl = TRUE)
  expr <- gsub("(?i)\\blt\\b", "<", expr, perl = TRUE)
  expr <- gsub("(?i)\\bge\\b", ">=", expr, perl = TRUE)
  expr <- gsub("(?i)\\ble\\b", "<=", expr, perl = TRUE)
  expr <- gsub("(?i)\\band\\b", "&", expr, perl = TRUE)
  expr <- gsub("(?i)\\bor\\b", "|", expr, perl = TRUE)
  expr <- gsub("(?i)\\bnot\\b", "!", expr, perl = TRUE)
  expr <- gsub("=", "==", expr)
  expr <- gsub(">==", ">=", expr)
  expr <- gsub("<==", "<=", expr)
  expr <- gsub("!==", "!=", expr)
  expr <- gsub("(?i)\\bmissing\\s*\\(([^)]+)\\)", "is.na(\\1)", expr, perl = TRUE)
  expr <- gsub("(?i)\\bin\\s*\\(", "%in% c(", expr, perl = TRUE)
  expr
}

sas_expr_to_r <- function(expr) {
  expr <- trim_ws(expr)
  expr <- gsub("\\*\\*", "^", expr)
  expr <- gsub("(?i)\\blog\\s*\\(", "log(", expr, perl = TRUE)
  expr <- gsub("(?i)\\bexp\\s*\\(", "exp(", expr, perl = TRUE)
  expr <- gsub("(?i)\\bsqrt\\s*\\(", "sqrt(", expr, perl = TRUE)
  expr <- gsub("(?i)\\babs\\s*\\(", "abs(", expr, perl = TRUE)
  expr <- gsub("(?i)\\bround\\s*\\(", "round(", expr, perl = TRUE)
  expr <- gsub("(?i)\\bint\\s*\\(", "trunc(", expr, perl = TRUE)
  expr <- gsub("(?i)\\bsum\\s*\\(", "sum(", expr, perl = TRUE)
  expr <- gsub("(?i)\\bmean\\s*\\(", "mean(", expr, perl = TRUE)
  expr <- gsub("(?i)\\bmin\\s*\\(", "min(", expr, perl = TRUE)
  expr <- gsub("(?i)\\bmax\\s*\\(", "max(", expr, perl = TRUE)
  expr <- gsub("(?i)\\bsubstr\\s*\\(", "substr(", expr, perl = TRUE)
  expr <- gsub("(?i)\\bupcase\\s*\\(", "toupper(", expr, perl = TRUE)
  expr <- gsub("(?i)\\blowcase\\s*\\(", "tolower(", expr, perl = TRUE)
  expr <- gsub("(?i)\\btrim\\s*\\(", "trimws(", expr, perl = TRUE)
  expr <- gsub("(?i)\\btoday\\s*\\(\\s*\\)", "Sys.Date()", expr, perl = TRUE)
  expr <- gsub("(?i)\\bdatetime\\s*\\(\\s*\\)", "Sys.time()", expr, perl = TRUE)
  expr <- gsub("(?i)\\bcatt?x?\\s*\\(", "paste0(", expr, perl = TRUE)
  expr <- gsub("(?i)\\bcoalesce\\s*\\(", "dplyr::coalesce(", expr, perl = TRUE)
  expr
}

# ---------------------------------------------------------------------------
# SAS -> R
# ---------------------------------------------------------------------------

convert_proc_means <- function(block) {
  data <- r_ident(extract_data_opt(block, "df"))
  lines <- strsplit(block, "\n")[[1]]
  class_vars <- character(0)
  var_vars <- character(0)
  by_vars <- character(0)
  for (ln in lines) {
    ln <- trim_ws(ln)
    if (grepl("(?i)^class\\b", ln)) class_vars <- vars_after(ln, "class")
    if (grepl("(?i)^var\\b", ln)) var_vars <- vars_after(ln, "var")
    if (grepl("(?i)^by\\b", ln)) by_vars <- vars_after(ln, "by")
  }
  groups <- unique(c(class_vars, by_vars))
  groups <- groups[nzchar(groups)]
  out <- "library(dplyr)\n"
  if (length(groups)) {
    out <- paste0(out, data, " %>%\n  group_by(", paste(groups, collapse = ", "), ") %>%\n")
  } else {
    out <- paste0(out, data, " %>%\n")
  }
  if (length(var_vars)) {
    out <- paste0(
      out,
      "  summarise(\n    n = n(),\n    across(c(",
      paste(var_vars, collapse = ", "),
      "), list(mean = ~mean(.x, na.rm = TRUE),\n",
      "                  sd   = ~sd(.x, na.rm = TRUE),\n",
      "                  min  = ~min(.x, na.rm = TRUE),\n",
      "                  max  = ~max(.x, na.rm = TRUE)), .names = \"{.col}_{.fn}\")\n  )"
    )
  } else {
    out <- paste0(out, "  summarise(n = n(), across(where(is.numeric), list(mean = mean, sd = sd), na.rm = TRUE))")
  }
  list(code = out, note = "PROC MEANS mapped to dplyr::group_by + summarise. Default stats: n, mean, sd, min, max.")
}

convert_proc_freq <- function(block) {
  data <- r_ident(extract_data_opt(block, "df"))
  lines <- strsplit(block, "\n")[[1]]
  tables <- NULL
  chisq <- grepl("(?i)\\bchisq\\b", block)
  for (ln in lines) {
    if (grepl("(?i)^tables\\b", trim_ws(ln))) {
      rest <- sub("(?i)^tables\\s+", "", trim_ws(ln))
      rest <- gsub("/.*$", "", rest)
      tables <- trim_ws(rest)
    }
  }
  if (is.null(tables) || !nzchar(tables)) {
    return(list(code = paste0("table(", data, ")"), note = "PROC FREQ without TABLES: table() of whole frame is only a rough analogue."))
  }
  if (grepl("\\*", tables)) {
    parts <- trim_ws(unlist(strsplit(tables, "\\*")))
    parts <- parts[nzchar(parts)]
    code <- paste0("tab <- table(", paste(paste0(data, "$", parts), collapse = ", "), ")\ntab\nprop.table(tab, margin = 1)  # row %")
    if (chisq) code <- paste0(code, "\nchisq.test(tab)")
    note <- "PROC FREQ crosstab mapped to table() + prop.table()."
  } else {
    vars <- unlist(strsplit(tables, "[,\\s]+"))
    vars <- vars[nzchar(vars)]
    if (length(vars) == 1) {
      code <- paste0(
        "library(dplyr)\n", data, " %>%\n  count(", vars[[1]], ", name = \"Frequency\") %>%\n",
        "  mutate(Percent = 100 * Frequency / sum(Frequency))"
      )
    } else {
      code <- paste0("table(", paste(paste0(data, "$", vars), collapse = ", "), ")")
    }
    note <- "PROC FREQ one-way mapped to dplyr::count() (or table())."
  }
  list(code = code, note = note)
}

convert_proc_sort <- function(block) {
  data <- r_ident(extract_data_opt(block, "df"))
  outn <- extract_named(block, "out")
  lines <- strsplit(block, "\n")[[1]]
  by_line <- lines[grepl("(?i)\\bby\\b", lines)]
  keys <- character(0)
  if (length(by_line)) keys <- vars_after(by_line[[1]], "by")
  arrange_args <- character(0)
  i <- 1
  while (i <= length(keys)) {
    if (tolower(keys[[i]]) == "descending" && i < length(keys)) {
      arrange_args <- c(arrange_args, paste0("desc(", keys[[i + 1]], ")"))
      i <- i + 2
    } else {
      arrange_args <- c(arrange_args, keys[[i]])
      i <- i + 1
    }
  }
  target <- if (!is.na(outn)) r_ident(outn) else data
  if (!length(arrange_args)) {
    code <- paste0(target, " <- ", data, "  # PROC SORT with no BY variables")
  } else {
    code <- paste0(
      "library(dplyr)\n", target, " <- ", data, " %>%\n  arrange(",
      paste(arrange_args, collapse = ", "), ")"
    )
  }
  list(code = code, note = "PROC SORT mapped to dplyr::arrange().")
}

convert_proc_print <- function(block) {
  data <- r_ident(extract_data_opt(block, "df"))
  obs <- extract_named(block, "obs")
  lines <- strsplit(block, "\n")[[1]]
  keep <- character(0)
  for (ln in lines) if (grepl("(?i)^var\\b", trim_ws(ln))) keep <- vars_after(ln, "var")
  code <- data
  if (length(keep)) code <- paste0(code, " %>% dplyr::select(", paste(keep, collapse = ", "), ")")
  if (!is.na(obs)) {
    code <- paste0("head(", if (code == data) data else paste0("(", code, ")"), ", ", obs, ")")
  } else {
    code <- paste0("print(", if (grepl("%>%", code)) paste0("\n", code) else code, ")")
    if (grepl("%>%", code)) code <- paste0("library(dplyr)\n", code)
  }
  list(code = code, note = "PROC PRINT mapped to print()/head()/select().")
}

convert_proc_contents <- function(block) {
  data <- r_ident(extract_data_opt(block, "df"))
  code <- paste0(
    "# PROC CONTENTS analogue\n",
    "str(", data, ")\n",
    "tibble::tibble(\n",
    "  name = names(", data, "),\n",
    "  type = vapply(", data, ", function(x) class(x)[1], character(1)),\n",
    "  n_missing = vapply(", data, ", function(x) sum(is.na(x)), integer(1))\n",
    ")"
  )
  list(code = code, note = "PROC CONTENTS mapped to str() plus a simple column inventory.")
}

convert_proc_reg <- function(block) {
  data <- r_ident(extract_data_opt(block, "df"))
  model_line <- grep("(?i)\\bmodel\\b", strsplit(block, "\n")[[1]], value = TRUE)
  if (!length(model_line)) {
    return(list(code = paste0("lm(y ~ x, data = ", data, ")"), note = "PROC REG without MODEL statement; placeholder formula used."))
  }
  rest <- sub("(?i).*\\bmodel\\s+", "", model_line[[1]])
  rest <- gsub("/.*$", "", rest)
  rest <- trim_ws(strip_trailing_semicolons(rest))
  rest <- gsub("=", "~", rest)
  code <- paste0(
    "fit <- lm(", rest, ", data = ", data, ")\n",
    "summary(fit)"
  )
  list(code = code, note = "PROC REG mapped to stats::lm() + summary().")
}

convert_proc_glm <- function(block) {
  data <- r_ident(extract_data_opt(block, "df"))
  class_vars <- character(0)
  model <- NA_character_
  for (ln in strsplit(block, "\n")[[1]]) {
    ln <- trim_ws(ln)
    if (grepl("(?i)^class\\b", ln)) class_vars <- vars_after(ln, "class")
    if (grepl("(?i)^model\\b", ln)) {
      model <- sub("(?i)^model\\s+", "", ln)
      model <- gsub("/.*$", "", model)
      model <- gsub("=", "~", trim_ws(model))
    }
  }
  extra <- ""
  if (length(class_vars)) {
    extra <- paste0(
      paste0(data, "$", class_vars, " <- factor(", data, "$", class_vars, ")", collapse = "\n"),
      "\n"
    )
  }
  if (is.na(model)) model <- "y ~ x"
  code <- paste0(extra, "fit <- lm(", model, ", data = ", data, ")\nsummary(fit)\n# For classical ANOVA: anova(fit) or aov(", model, ", data = ", data, ")")
  list(code = code, note = "PROC GLM mapped to lm()/aov(). CLASS variables become factor().")
}

convert_proc_logistic <- function(block) {
  data <- r_ident(extract_data_opt(block, "df"))
  model_line <- grep("(?i)\\bmodel\\b", strsplit(block, "\n")[[1]], value = TRUE)
  if (length(model_line)) {
    rest <- sub("(?i).*\\bmodel\\s+", "", model_line[[1]])
    rest <- gsub("/.*$", "", rest)
    rest <- gsub("\\([^)]*\\)", "", rest) # drop (event='1')
    rest <- gsub("=", "~", trim_ws(rest))
  } else {
    rest <- "y ~ x"
  }
  code <- paste0(
    "fit <- glm(", rest, ", data = ", data, ", family = binomial())\n",
    "summary(fit)\n",
    "exp(cbind(OR = coef(fit), confint(fit)))  # odds ratios"
  )
  list(code = code, note = "PROC LOGISTIC mapped to glm(..., family = binomial).")
}

convert_proc_univariate <- function(block) {
  data <- r_ident(extract_data_opt(block, "df"))
  var_vars <- character(0)
  for (ln in strsplit(block, "\n")[[1]]) {
    if (grepl("(?i)^var\\b", trim_ws(ln))) var_vars <- vars_after(ln, "var")
  }
  if (!length(var_vars)) {
    code <- paste0("summary(", data, ")\npsych::describe(", data, ")  # optional")
  } else {
    v <- var_vars[[1]]
    code <- paste0(
      "summary(", data, "$", v, ")\n",
      "quantile(", data, "$", v, ", probs = c(0, 0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99, 1), na.rm = TRUE)\n",
      "hist(", data, "$", v, ")\n",
      "shapiro.test(", data, "$", v, ")  # normality, small n"
    )
  }
  list(code = code, note = "PROC UNIVARIATE mapped to summary()/quantile()/hist().")
}

convert_proc_transpose <- function(block) {
  data <- r_ident(extract_data_opt(block, "df"))
  outn <- extract_named(block, "out")
  target <- if (!is.na(outn)) r_ident(outn) else paste0(data, "_wide")
  by_vars <- character(0); id_var <- NA_character_; var_vars <- character(0)
  for (ln in strsplit(block, "\n")[[1]]) {
    ln <- trim_ws(ln)
    if (grepl("(?i)^by\\b", ln)) by_vars <- vars_after(ln, "by")
    if (grepl("(?i)^id\\b", ln)) id_var <- vars_after(ln, "id")[1]
    if (grepl("(?i)^var\\b", ln)) var_vars <- vars_after(ln, "var")
  }
  if (!is.na(id_var) && length(var_vars)) {
    code <- paste0(
      "library(tidyr)\n",
      target, " <- ", data, " %>%\n",
      "  pivot_wider(id_cols = ", if (length(by_vars)) paste(by_vars, collapse = ", ") else "everything()",
      ",\n              names_from = ", id_var, ",\n              values_from = ", paste(var_vars, collapse = ", "), ")"
    )
  } else {
    code <- paste0("tidyr::pivot_wider(", data, ")  # refine id_cols / names_from / values_from")
  }
  list(code = code, note = "PROC TRANSPOSE mapped to tidyr::pivot_wider(). Long format uses pivot_longer().")
}

convert_proc_import <- function(block) {
  file <- extract_named(block, "datafile")
  outn <- extract_named(block, "out")
  dbms <- extract_named(block, "dbms")
  target <- if (!is.na(outn)) r_ident(outn) else "df"
  file <- if (!is.na(file)) file else "\"file.csv\""
  if (is.na(dbms)) dbms <- ""
  dbms_l <- tolower(gsub("[\"']", "", dbms))
  if (grepl("xlsx|excel", dbms_l)) {
    code <- paste0("library(readxl)\n", target, " <- read_excel(", file, ")")
  } else if (grepl("sas", dbms_l)) {
    code <- paste0("library(haven)\n", target, " <- read_sas(", file, ")")
  } else {
    code <- paste0("library(readr)\n", target, " <- read_csv(", file, ")")
  }
  list(code = code, note = "PROC IMPORT mapped to readr/readxl/haven.")
}

convert_proc_export <- function(block) {
  data <- r_ident(extract_data_opt(block, "df"))
  file <- extract_named(block, "outfile")
  file <- if (!is.na(file)) file else "\"file.csv\""
  code <- paste0("readr::write_csv(", data, ", ", file, ")\n# SAS transport: haven::write_xpt(", data, ", \"file.xpt\")")
  list(code = code, note = "PROC EXPORT mapped to readr::write_csv() / haven::write_xpt().")
}

convert_proc_sql <- function(block) {
  body <- sub("(?i)^proc\\s+sql\\s*", "", block)
  body <- gsub("(?i)\\bquit\\b", "", body)
  body <- trim_ws(body)
  code <- paste0(
    "# PROC SQL -> dplyr (approximate) or sqldf\n",
    "library(sqldf)\n",
    "sqldf(\"", gsub("\"", "\\\\\"", body), "\")\n\n",
    "# Prefer dplyr when the query is a simple SELECT/WHERE/GROUP BY."
  )
  list(code = code, note = "PROC SQL mapped to sqldf::sqldf(). Rewrite simple queries with dplyr.")
}

convert_proc_sgplot <- function(block) {
  data <- r_ident(extract_data_opt(block, "df"))
  scatter <- regexpr("(?i)scatter\\s+x\\s*=\\s*(\\w+)\\s+y\\s*=\\s*(\\w+)", block, perl = TRUE)
  hist <- regexpr("(?i)histogram\\s+(\\w+)", block, perl = TRUE)
  vbar <- regexpr("(?i)vbar\\s+(\\w+)", block, perl = TRUE)
  series <- regexpr("(?i)series\\s+x\\s*=\\s*(\\w+)\\s+y\\s*=\\s*(\\w+)", block, perl = TRUE)
  if (scatter[1] > 0) {
    cap <- regmatches(block, scatter)
    x <- sub("(?i)scatter\\s+x\\s*=\\s*", "", cap)
    x <- sub("(?i)\\s+y\\s*=\\s*\\w+", "", x)
    y <- sub("(?i).*y\\s*=\\s*", "", cap)
    code <- paste0("library(ggplot2)\nggplot(", data, ", aes(x = ", x, ", y = ", y, ")) + geom_point()")
  } else if (hist[1] > 0) {
    v <- sub("(?i)histogram\\s+", "", regmatches(block, hist))
    code <- paste0("library(ggplot2)\nggplot(", data, ", aes(x = ", v, ")) + geom_histogram(bins = 30)")
  } else if (vbar[1] > 0) {
    v <- sub("(?i)vbar\\s+", "", regmatches(block, vbar))
    code <- paste0("library(ggplot2)\nggplot(", data, ", aes(x = ", v, ")) + geom_bar()")
  } else if (series[1] > 0) {
    cap <- regmatches(block, series)
    x <- sub("(?i)series\\s+x\\s*=\\s*", "", cap)
    x <- sub("(?i)\\s+y\\s*=\\s*\\w+", "", x)
    y <- sub("(?i).*y\\s*=\\s*", "", cap)
    code <- paste0("library(ggplot2)\nggplot(", data, ", aes(x = ", x, ", y = ", y, ")) + geom_line()")
  } else {
    code <- paste0("library(ggplot2)\nggplot(", data, ", aes(x = x, y = y)) + geom_point()")
  }
  list(code = code, note = "PROC SGPLOT mapped to ggplot2.")
}

convert_data_step <- function(block) {
  header <- strsplit(block, "\n")[[1]][[1]]
  out_ds <- first_ident_after(header, "data")
  if (is.na(out_ds)) out_ds <- "out"
  out_ds <- r_ident(out_ds)

  set_ds <- NA_character_
  where_expr <- NA_character_
  keep_vars <- character(0)
  drop_vars <- character(0)
  renames <- character(0)
  assigns <- character(0)
  if_lines <- character(0)
  merge_ds <- character(0)
  by_vars <- character(0)

  for (ln in strsplit(block, "\n")[[1]]) {
    raw <- ln
    ln <- trim_ws(gsub(";+", "", ln))
    if (!nzchar(ln)) next
    if (grepl("(?i)^data\\b", ln)) next
    if (grepl("(?i)^set\\b", ln)) {
      set_ds <- vars_after(ln, "set")
      next
    }
    if (grepl("(?i)^merge\\b", ln)) {
      merge_ds <- vars_after(ln, "merge")
      next
    }
    if (grepl("(?i)^by\\b", ln)) {
      by_vars <- vars_after(ln, "by")
      next
    }
    if (grepl("(?i)^where\\b", ln)) {
      where_expr <- sas_eq_to_r(sub("(?i)^where\\s+", "", ln))
      next
    }
    if (grepl("(?i)^keep\\b", ln)) {
      keep_vars <- vars_after(ln, "keep")
      next
    }
    if (grepl("(?i)^drop\\b", ln)) {
      drop_vars <- vars_after(ln, "drop")
      next
    }
    if (grepl("(?i)^rename\\b", ln)) {
      rest <- sub("(?i)^rename\\s+", "", ln)
      pairs <- unlist(strsplit(rest, "\\s+"))
      for (p in pairs) {
        if (grepl("=", p)) {
          kv <- strsplit(p, "=")[[1]]
          if (length(kv) == 2) renames <- c(renames, paste0(trim_ws(kv[[2]]), " = ", trim_ws(kv[[1]])))
        }
      }
      next
    }
    if (grepl("(?i)^if\\b", ln)) {
      if_lines <- c(if_lines, ln)
      next
    }
    if (grepl("=", ln) && !grepl("(?i)^(label|format|informat|length|attrib|retain)\\b", ln)) {
      assigns <- c(assigns, ln)
    }
  }

  pipes <- character(0)
  src <- if (!all(is.na(set_ds))) r_ident(set_ds[[1]]) else "df"

  if (length(merge_ds) >= 2) {
    by <- if (length(by_vars)) paste0("\"", paste(by_vars, collapse = "\", \""), "\"") else "\"id\""
    code <- paste0(
      "library(dplyr)\n",
      out_ds, " <- ", r_ident(merge_ds[[1]]), " %>%\n",
      "  full_join(", r_ident(merge_ds[[2]]), ", by = c(", by, "))"
    )
    extra <- character(0)
    if (!is.na(where_expr)) extra <- c(extra, paste0("  filter(", where_expr, ")"))
    if (length(assigns)) {
      muts <- vapply(assigns, function(a) {
        kv <- strsplit(a, "=", fixed = TRUE)[[1]]
        paste0(trim_ws(kv[[1]]), " = ", sas_expr_to_r(paste(kv[-1], collapse = "=")))
      }, character(1))
      extra <- c(extra, paste0("  mutate(", paste(muts, collapse = ", "), ")"))
    }
    if (length(extra)) code <- paste0(code, " %>%\n", paste(extra, collapse = " %>%\n"))
    return(list(code = code, note = "DATA step MERGE mapped to dplyr::full_join() (SAS merge is typically a full join). Use left_join / inner_join as needed."))
  }

  code <- paste0("library(dplyr)\n", out_ds, " <- ", src)
  steps <- character(0)
  if (!is.na(where_expr)) steps <- c(steps, paste0("filter(", where_expr, ")"))
  if (length(if_lines)) {
    # Very common pattern: if cond then var = val; else var = val2;
    combined <- paste(if_lines, collapse = " ")
    m <- regexec("(?i)if\\s+(.+?)\\s+then\\s+(\\w+)\\s*=\\s*(.+?)\\s*else\\s+\\2\\s*=\\s*(.+)$", combined, perl = TRUE)
    mm <- regmatches(combined, m)
    if (length(mm) && length(mm[[1]]) >= 5) {
      cond <- sas_eq_to_r(mm[[1]][[2]])
      var <- mm[[1]][[3]]
      yes <- sas_expr_to_r(mm[[1]][[4]])
      no <- sas_expr_to_r(mm[[1]][[5]])
      steps <- c(steps, paste0("mutate(", var, " = ifelse(", cond, ", ", yes, ", ", no, "))"))
    } else {
      m2 <- regexec("(?i)if\\s+(.+?)\\s+then\\s+(\\w+)\\s*=\\s*(.+)$", combined, perl = TRUE)
      mm2 <- regmatches(combined, m2)
      if (length(mm2) && length(mm2[[1]]) >= 4) {
        cond <- sas_eq_to_r(mm2[[1]][[2]])
        var <- mm2[[1]][[3]]
        yes <- sas_expr_to_r(mm2[[1]][[4]])
        steps <- c(steps, paste0("mutate(", var, " = ifelse(", cond, ", ", yes, ", NA))"))
      } else {
        steps <- c(steps, paste0("# TODO: review IF logic: ", combined))
      }
    }
  }
  if (length(assigns)) {
    muts <- vapply(assigns, function(a) {
      kv <- strsplit(a, "=", fixed = TRUE)[[1]]
      paste0(trim_ws(kv[[1]]), " = ", sas_expr_to_r(paste(kv[-1], collapse = "=")))
    }, character(1))
    steps <- c(steps, paste0("mutate(", paste(muts, collapse = ",\n         "), ")"))
  }
  if (length(renames)) steps <- c(steps, paste0("rename(", paste(renames, collapse = ", "), ")"))
  if (length(keep_vars)) steps <- c(steps, paste0("select(", paste(keep_vars, collapse = ", "), ")"))
  if (length(drop_vars)) steps <- c(steps, paste0("select(", paste(paste0("-", drop_vars), collapse = ", "), ")"))

  if (length(steps)) {
    code <- paste0(code, " %>%\n  ", paste(steps, collapse = " %>%\n  "))
  }
  list(code = code, note = "DATA step mapped to a dplyr pipeline. SAS implicit row loop becomes vectorized mutate().")
}

split_sas_blocks <- function(code) {
  code <- normalize_newlines(code)
  code <- gsub("/\\*.*?\\*/", " ", code, perl = TRUE)
  lines <- strsplit(code, "\n")[[1]]
  # drop * comment lines
  lines <- lines[!grepl("^\\s*\\*", lines)]
  text <- paste(lines, collapse = "\n")
  # Split on run; or quit; keeping blocks
  pieces <- unlist(strsplit(text, "(?i)(?<=;)\\s*(?=proc\\b)|(?<=;)\\s*(?=data\\s+)|(?<=;)\\s*(?=%let\\b)|(?<=;)\\s*(?=libname\\b)", perl = TRUE))
  # Further split concatenated procs if needed
  blocks <- character(0)
  current <- ""
  stmts <- split_sas_statements(text)
  current <- ""
  flush_block <- function() {
    b <- trim_ws(current)
    if (nzchar(b)) blocks <<- c(blocks, b)
    current <<- ""
  }
  for (st in stmts) {
    stn <- trim_ws(st)
    if (grepl("(?i)^(proc|data)\\b", stn) && nzchar(current) && grepl("(?i)^(proc|data)\\b", trim_ws(current))) {
      # if current already contains a completed-looking block with run inside? we split on run separately
    }
    if (grepl("(?i)^(proc|data|%let|libname)\\b", stn) && nzchar(current)) {
      # start new if current looks complete-ish (contains run already handled below)
      if (grepl("(?i)\\b(run|quit)\\b", current) || grepl("(?i)^(%let|libname)\\b", trim_ws(current))) {
        flush_block()
      }
    }
    current <- if (nzchar(current)) paste0(current, "\n", stn) else stn
    if (grepl("(?i)^(run|quit)$", stn) || grepl("(?i)^%let\\b", stn) || grepl("(?i)^libname\\b", stn)) {
      flush_block()
    }
  }
  flush_block()
  blocks[nzchar(trim_ws(blocks))]
}

convert_libname <- function(block) {
  toks <- unlist(strsplit(trim_ws(block), "\\s+"))
  if (length(toks) >= 3) {
    lib <- toks[[2]]
    path <- paste(toks[-(1:2)], collapse = " ")
    code <- paste0(lib, "_path <- ", path, "\n# Then: haven::read_sas(file.path(", lib, "_path, \"dataset.sas7bdat\"))")
  } else {
    code <- "# libname: store a directory path as a string in R"
  }
  list(code = code, note = "LIBNAME is just a folder path in R.")
}

convert_let <- function(block) {
  rest <- sub("(?i)^%let\\s+", "", trim_ws(block))
  kv <- strsplit(rest, "=", fixed = TRUE)[[1]]
  if (length(kv) >= 2) {
    name <- gsub("&", "", trim_ws(kv[[1]]))
    val <- trim_ws(paste(kv[-1], collapse = "="))
    val <- gsub(";+$", "", val)
    if (!grepl("^[0-9.]+$", val) && !grepl("^[\"'].*[\"']$", val)) val <- paste0("\"", val, "\"")
    code <- paste0(name, " <- ", val)
  } else {
    code <- paste0("# ", block)
  }
  list(code = code, note = "%LET mapped to a regular R object.")
}

convert_sas_to_r <- function(code) {
  code <- trim_ws(normalize_newlines(code))
  if (!nzchar(code)) {
    return(list(code = "", notes = "Paste SAS code to convert.", warnings = character(0)))
  }
  blocks <- split_sas_blocks(code)
  if (!length(blocks)) {
    blocks <- code
  }
  out_parts <- character(0)
  notes <- character(0)
  warnings <- character(0)
  for (b in blocks) {
    btrim <- trim_ws(b)
    head1 <- tolower(sub("\\s.*$", "", gsub("\n", " ", btrim)))
    res <- NULL
    if (grepl("(?i)^libname\\b", btrim)) res <- convert_libname(btrim)
    else if (grepl("(?i)^%let\\b", btrim)) res <- convert_let(btrim)
    else if (grepl("(?i)^proc\\s+means\\b|^proc\\s+summary\\b", btrim)) res <- convert_proc_means(btrim)
    else if (grepl("(?i)^proc\\s+freq\\b", btrim)) res <- convert_proc_freq(btrim)
    else if (grepl("(?i)^proc\\s+sort\\b", btrim)) res <- convert_proc_sort(btrim)
    else if (grepl("(?i)^proc\\s+print\\b", btrim)) res <- convert_proc_print(btrim)
    else if (grepl("(?i)^proc\\s+contents\\b", btrim)) res <- convert_proc_contents(btrim)
    else if (grepl("(?i)^proc\\s+reg\\b", btrim)) res <- convert_proc_reg(btrim)
    else if (grepl("(?i)^proc\\s+glm\\b", btrim)) res <- convert_proc_glm(btrim)
    else if (grepl("(?i)^proc\\s+logistic\\b", btrim)) res <- convert_proc_logistic(btrim)
    else if (grepl("(?i)^proc\\s+univariate\\b", btrim)) res <- convert_proc_univariate(btrim)
    else if (grepl("(?i)^proc\\s+transpose\\b", btrim)) res <- convert_proc_transpose(btrim)
    else if (grepl("(?i)^proc\\s+import\\b", btrim)) res <- convert_proc_import(btrim)
    else if (grepl("(?i)^proc\\s+export\\b", btrim)) res <- convert_proc_export(btrim)
    else if (grepl("(?i)^proc\\s+sql\\b", btrim)) res <- convert_proc_sql(btrim)
    else if (grepl("(?i)^proc\\s+sgplot\\b", btrim)) res <- convert_proc_sgplot(btrim)
    else if (grepl("(?i)^data\\b", btrim)) res <- convert_data_step(btrim)
    else if (grepl("(?i)^proc\\s+", btrim)) {
      pname <- sub("(?i)^proc\\s+(\\w+).*", "\\1", btrim)
      res <- list(
        code = paste0("# Unsupported PROC ", pname, " in this teaching converter.\n# Look it up on the Procedure Map tab and rewrite by intent."),
        note = paste0("PROC ", pname, " is not auto-converted.")
      )
      warnings <- c(warnings, paste("Unrecognized or unsupported PROC:", pname))
    } else {
      res <- list(
        code = paste0("# Could not parse block:\n# ", gsub("\n", "\n# ", btrim)),
        note = "Unparsed SAS block left as a comment."
      )
      warnings <- c(warnings, "Some SAS was left unconverted.")
    }
    out_parts <- c(out_parts, res$code)
    notes <- c(notes, res$note)
  }
  list(
    code = paste(out_parts, collapse = "\n\n"),
    notes = unique(notes),
    warnings = unique(warnings)
  )
}

# ---------------------------------------------------------------------------
# R -> SAS
# ---------------------------------------------------------------------------

r_formula_to_sas_model <- function(form) {
  form <- trim_ws(form)
  form <- gsub("~", "=", form)
  form
}

convert_r_to_sas <- function(code) {
  code <- trim_ws(normalize_newlines(code))
  if (!nzchar(code)) {
    return(list(code = "", notes = "Paste R code to convert.", warnings = character(0)))
  }
  lines <- strsplit(code, "\n")[[1]]
  out <- character(0)
  notes <- character(0)
  warnings <- character(0)

  # Join dplyr pipelines that span lines for easier matching
  collapsed <- paste(lines, collapse = "\n")
  collapsed_one <- gsub("\\s+", " ", collapsed)

  # library lines
  if (grepl("\\blibrary\\s*\\(", collapsed)) {
    out <- c(out, "/* R packages have no SAS equivalent; PROCs and DATA steps replace them. */")
    notes <- c(notes, "library() calls are omitted in SAS.")
  }

  handled <- FALSE

  # readr / read.csv
  m <- regexec("(\\w+)\\s*<-\\s*(?:readr::)?read_csv\\s*\\(([^)]+)\\)", collapsed, perl = TRUE)
  mm <- regmatches(collapsed, m)
  if (!length(mm[[1]])) {
    m <- regexec("(\\w+)\\s*<-\\s*read\\.csv\\s*\\(([^)]+)\\)", collapsed, perl = TRUE)
    mm <- regmatches(collapsed, m)
  }
  if (length(mm[[1]]) >= 3) {
    out <- c(out, sprintf(
      "proc import datafile=%s\n    out=%s\n    dbms=csv replace;\n    getnames=yes;\nrun;",
      trim_ws(mm[[1]][[3]]), mm[[1]][[2]]
    ))
    notes <- c(notes, "read_csv / read.csv mapped to PROC IMPORT.")
    handled <- TRUE
  }

  m <- regexec("(\\w+)\\s*<-\\s*(?:haven::)?read_sas\\s*\\(([^)]+)\\)", collapsed, perl = TRUE)
  mm <- regmatches(collapsed, m)
  if (length(mm[[1]]) >= 3) {
    out <- c(out, sprintf(
      "/* Read a SAS dataset directly if it already lives in a library */\nlibname inlib \"<folder of %s>\";\ndata %s;\n    set inlib.<dataset>;\nrun;",
      trim_ws(mm[[1]][[3]]), mm[[1]][[2]]
    ))
    notes <- c(notes, "haven::read_sas mapped to SET of a libname.dataset.")
    handled <- TRUE
  }

  m <- regexec("(?:readr::)?write_csv\\s*\\(\\s*(\\w+)\\s*,\\s*([^)]+)\\)", collapsed, perl = TRUE)
  mm <- regmatches(collapsed, m)
  if (length(mm[[1]]) >= 3) {
    out <- c(out, sprintf(
      "proc export data=%s\n    outfile=%s\n    dbms=csv replace;\nrun;",
      mm[[1]][[2]], trim_ws(mm[[1]][[3]])
    ))
    notes <- c(notes, "write_csv mapped to PROC EXPORT.")
    handled <- TRUE
  }

  # lm
  m <- regexec("lm\\s*\\(\\s*([^,]+)\\s*,\\s*data\\s*=\\s*(\\w+)", collapsed, perl = TRUE)
  mm <- regmatches(collapsed, m)
  if (length(mm[[1]]) >= 3) {
    out <- c(out, sprintf(
      "proc reg data=%s;\n    model %s;\nrun; quit;",
      mm[[1]][[3]], r_formula_to_sas_model(mm[[1]][[2]])
    ))
    notes <- c(notes, "lm() mapped to PROC REG.")
    handled <- TRUE
  }

  # glm binomial
  if (grepl("glm\\s*\\(", collapsed) && grepl("binomial", collapsed)) {
    m <- regexec("glm\\s*\\(\\s*([^,]+)\\s*,\\s*data\\s*=\\s*(\\w+)", collapsed, perl = TRUE)
    mm <- regmatches(collapsed, m)
    if (length(mm[[1]]) >= 3) {
      out <- c(out, sprintf(
        "proc logistic data=%s;\n    model %s;\nrun;",
        mm[[1]][[3]], r_formula_to_sas_model(mm[[1]][[2]])
      ))
      notes <- c(notes, "glm(..., family = binomial) mapped to PROC LOGISTIC.")
      handled <- TRUE
    }
  }

  # aov
  m <- regexec("aov\\s*\\(\\s*([^,]+)\\s*,\\s*data\\s*=\\s*(\\w+)", collapsed, perl = TRUE)
  mm <- regmatches(collapsed, m)
  if (length(mm[[1]]) >= 3) {
    out <- c(out, sprintf(
      "proc glm data=%s;\n    class /* factor predictors here */;\n    model %s;\nrun; quit;",
      mm[[1]][[3]], r_formula_to_sas_model(mm[[1]][[2]])
    ))
    notes <- c(notes, "aov() mapped to PROC GLM.")
    handled <- TRUE
  }

  # table()
  m <- regexec("table\\s*\\(\\s*(\\w+)\\s*\\$\\s*(\\w+)(?:\\s*,\\s*(\\w+)\\s*\\$\\s*(\\w+))?", collapsed, perl = TRUE)
  mm <- regmatches(collapsed, m)
  if (length(mm[[1]]) >= 3) {
    if (length(mm[[1]]) >= 5 && nzchar(mm[[1]][[4]])) {
      out <- c(out, sprintf("proc freq data=%s;\n    tables %s * %s / chisq;\nrun;", mm[[1]][[2]], mm[[1]][[3]], mm[[1]][[5]]))
    } else {
      out <- c(out, sprintf("proc freq data=%s;\n    tables %s;\nrun;", mm[[1]][[2]], mm[[1]][[3]]))
    }
    notes <- c(notes, "table() mapped to PROC FREQ.")
    handled <- TRUE
  }

  # dplyr count
  m <- regexec("(\\w+)\\s*%>%\\s*count\\s*\\(\\s*([^)]+)\\)", collapsed, perl = TRUE)
  mm <- regmatches(collapsed, m)
  if (length(mm[[1]]) >= 3) {
    out <- c(out, sprintf("proc freq data=%s;\n    tables %s;\nrun;", mm[[1]][[2]], gsub(",", "*", mm[[1]][[3]])))
    notes <- c(notes, "dplyr::count mapped to PROC FREQ.")
    handled <- TRUE
  }

  # ggplot scatter / hist / bar / line
  if (grepl("ggplot\\s*\\(", collapsed)) {
    data_m <- regexec("ggplot\\s*\\(\\s*(\\w+)", collapsed, perl = TRUE)
    dcap <- regmatches(collapsed, data_m)
    dname <- if (length(dcap[[1]]) >= 2) dcap[[1]][[2]] else "df"
    x <- NA_character_; y <- NA_character_
    xm <- regexec("x\\s*=\\s*(\\w+)", collapsed, perl = TRUE)
    ym <- regexec("y\\s*=\\s*(\\w+)", collapsed, perl = TRUE)
    xcap <- regmatches(collapsed, xm); ycap <- regmatches(collapsed, ym)
    if (length(xcap[[1]]) >= 2) x <- xcap[[1]][[2]]
    if (length(ycap[[1]]) >= 2) y <- ycap[[1]][[2]]
    if (grepl("geom_point", collapsed) && !is.na(x) && !is.na(y)) {
      out <- c(out, sprintf("proc sgplot data=%s;\n    scatter x=%s y=%s;\nrun;", dname, x, y))
    } else if (grepl("geom_line|geom_path", collapsed) && !is.na(x) && !is.na(y)) {
      out <- c(out, sprintf("proc sgplot data=%s;\n    series x=%s y=%s;\nrun;", dname, x, y))
    } else if (grepl("geom_histogram", collapsed) && !is.na(x)) {
      out <- c(out, sprintf("proc sgplot data=%s;\n    histogram %s;\nrun;", dname, x))
    } else if (grepl("geom_bar", collapsed) && !is.na(x)) {
      out <- c(out, sprintf("proc sgplot data=%s;\n    vbar %s;\nrun;", dname, x))
    } else {
      out <- c(out, sprintf("proc sgplot data=%s;\n    /* map ggplot layers to SGPLOT statements */\nrun;", dname))
    }
    notes <- c(notes, "ggplot2 mapped to PROC SGPLOT.")
    handled <- TRUE
  }

  # join
  if (grepl("left_join|inner_join|full_join|right_join|merge\\s*\\(", collapsed)) {
    jtype <- if (grepl("left_join", collapsed)) "/* left join: consider if a=1 or if b=1 after merge */" else
      if (grepl("inner_join", collapsed)) "if a and b;" else
        if (grepl("right_join", collapsed)) "/* right join */" else "/* full join ~ default SAS merge */"
    out <- c(out, sprintf(
      "data merged;\n    merge a b;\n    by id;\n    %s\nrun;",
      jtype
    ))
    notes <- c(notes, "dplyr joins mapped to DATA step MERGE. Review IN= flags for join type.")
    handled <- TRUE
  }

  # arrange / sort
  m <- regexec("(\\w+)\\s*%>%\\s*arrange\\s*\\(([^)]+)\\)", collapsed, perl = TRUE)
  mm <- regmatches(collapsed, m)
  if (length(mm[[1]]) >= 3) {
    keys <- trim_ws(mm[[1]][[3]])
    keys <- gsub("desc\\s*\\(\\s*(\\w+)\\s*\\)", "descending \\1", keys)
    keys <- gsub(",", " ", keys)
    out <- c(out, sprintf("proc sort data=%s out=%s_sorted;\n    by %s;\nrun;", mm[[1]][[2]], mm[[1]][[2]], keys))
    notes <- c(notes, "arrange() mapped to PROC SORT.")
    handled <- TRUE
  }

  # group_by + summarise
  if (grepl("group_by\\s*\\(", collapsed) && grepl("summarise|summarize", collapsed)) {
    gm <- regexec("group_by\\s*\\(([^)]+)\\)", collapsed, perl = TRUE)
    gcap <- regmatches(collapsed, gm)
    gvars <- if (length(gcap[[1]]) >= 2) gcap[[1]][[2]] else "group"
    # try to find source df at start of pipeline
    dm <- regexec("(\\w+)\\s*%>%\\s*group_by", collapsed, perl = TRUE)
    dcap <- regmatches(collapsed, dm)
    dname <- if (length(dcap[[1]]) >= 2) dcap[[1]][[2]] else "df"
    out <- c(out, sprintf(
      "proc means data=%s n mean std min max;\n    class %s;\n    var /* numeric analysis variables */;\nrun;",
      dname, gvars
    ))
    notes <- c(notes, "group_by + summarise mapped to PROC MEANS with CLASS.")
    handled <- TRUE
  }

  # filter / select / mutate pipeline without group
  if (grepl("%>%", collapsed) && grepl("filter\\s*\\(|select\\s*\\(|mutate\\s*\\(", collapsed) &&
      !grepl("group_by", collapsed)) {
    dm <- regexec("(\\w+)\\s*<-\\s*(\\w+)\\s*%>%", collapsed, perl = TRUE)
    dcap <- regmatches(collapsed, dm)
    if (!length(dcap[[1]])) {
      dm <- regexec("(\\w+)\\s*%>%", collapsed, perl = TRUE)
      dcap2 <- regmatches(collapsed, dm)
      src <- if (length(dcap2[[1]]) >= 2) dcap2[[1]][[2]] else "df"
      dest <- paste0(src, "_out")
    } else {
      dest <- dcap[[1]][[2]]
      src <- dcap[[1]][[3]]
    }
    where <- NULL; keep <- NULL; muts <- character(0)
    fm <- regexec("filter\\s*\\(([^)]+)\\)", collapsed, perl = TRUE)
    fcap <- regmatches(collapsed, fm)
    if (length(fcap[[1]]) >= 2) {
      w <- fcap[[1]][[2]]
      w <- gsub("==", "=", w)
      w <- gsub("&", " and ", w)
      w <- gsub("\\|", " or ", w)
      w <- gsub("%in%", "in", w)
      w <- gsub("is\\.na\\((\\w+)\\)", "missing(\\1)", w)
      where <- w
    }
    sm <- regexec("select\\s*\\(([^)]+)\\)", collapsed, perl = TRUE)
    scap <- regmatches(collapsed, sm)
    if (length(scap[[1]]) >= 2 && !grepl("^-", scap[[1]][[2]])) keep <- scap[[1]][[2]]
    um <- gregexpr("mutate\\s*\\(([^)]*)\\)", collapsed, perl = TRUE)
    # simple single-line mutate
    um2 <- regexec("mutate\\s*\\(([^)]+)\\)", collapsed, perl = TRUE)
    ucap <- regmatches(collapsed, um2)
    if (length(ucap[[1]]) >= 2) {
      muts <- trim_ws(ucap[[1]][[2]])
      muts <- gsub(",", ";\n    ", muts)
    }
    body <- sprintf("data %s;\n    set %s;", dest, src)
    if (!is.null(where)) body <- paste0(body, "\n    where ", where, ";")
    if (!is.null(keep)) body <- paste0(body, "\n    keep ", gsub(",", " ", keep), ";")
    if (length(muts) && nzchar(muts)) body <- paste0(body, "\n    ", muts, ";")
    body <- paste0(body, "\nrun;")
    out <- c(out, body)
    notes <- c(notes, "dplyr pipeline mapped to a DATA step.")
    handled <- TRUE
  }

  # summary / head / str
  m <- regexec("summary\\s*\\(\\s*(\\w+)\\s*\\)", collapsed, perl = TRUE)
  mm <- regmatches(collapsed, m)
  if (length(mm[[1]]) >= 2) {
    out <- c(out, sprintf("proc means data=%s n mean std min max;\nrun;\nproc univariate data=%s;\nrun;", mm[[1]][[2]], mm[[1]][[2]]))
    notes <- c(notes, "summary() mapped to PROC MEANS / UNIVARIATE.")
    handled <- TRUE
  }
  m <- regexec("head\\s*\\(\\s*(\\w+)\\s*(?:,\\s*(\\d+))?", collapsed, perl = TRUE)
  mm <- regmatches(collapsed, m)
  if (length(mm[[1]]) >= 2) {
    n <- if (length(mm[[1]]) >= 3 && nzchar(mm[[1]][[3]])) mm[[1]][[3]] else "6"
    out <- c(out, sprintf("proc print data=%s (obs=%s);\nrun;", mm[[1]][[2]], n))
    notes <- c(notes, "head() mapped to PROC PRINT (obs=).")
    handled <- TRUE
  }
  if (grepl("\\bstr\\s*\\(|\\bglimpse\\s*\\(|\\bnames\\s*\\(", collapsed)) {
    dm <- regexec("(?:str|glimpse|names)\\s*\\(\\s*(\\w+)", collapsed, perl = TRUE)
    dcap <- regmatches(collapsed, dm)
    dname <- if (length(dcap[[1]]) >= 2) dcap[[1]][[2]] else "df"
    out <- c(out, sprintf("proc contents data=%s;\nrun;", dname))
    notes <- c(notes, "str/glimpse/names mapped to PROC CONTENTS.")
    handled <- TRUE
  }

  if (!handled) {
    out <- c(out, paste0(
      "/* Automatic R -> SAS conversion could not fully parse this snippet. */\n",
      "/* Rewrite by intent using the Learner Guide and Procedure Map. */\n",
      "/* Original R (commented): */\n",
      paste(paste0("/* ", lines, " */"), collapse = "\n")
    ))
    warnings <- c(warnings, "R snippet was only partially recognized. Use examples or simplify the code.")
  }

  list(
    code = paste(unique(out), collapse = "\n\n"),
    notes = unique(notes),
    warnings = unique(warnings)
  )
}
