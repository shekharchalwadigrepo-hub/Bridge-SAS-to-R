# Learner guide panels. Kept as functions so the UI stays readable.

guide_intro <- function() {
  tagList(
    h3("How SAS programmers should think about R"),
    p("SAS is statement-oriented: you write a DATA step or a PROC, end it with",
      tags$code("run;"), ", and the procedure prints a report. R is expression-oriented:",
      "you call functions that return objects, then print or plot those objects yourself."),
    tags$ul(
      tags$li(tags$b("DATA step implicit loop"), " → vectorized column operations (",
              tags$code("mutate()"), ", ", tags$code("ifelse()"), ")."),
      tags$li(tags$b("PROC"), " → one or more functions (", tags$code("lm()"), ", ",
              tags$code("count()"), ", ", tags$code("ggplot()"), ")."),
      tags$li(tags$b("SAS dataset in a library"), " → an R data frame / tibble in memory."),
      tags$li(tags$b("Macro variable %LET"), " → a regular R object."),
      tags$li(tags$b("ODS listing"), " → the object returned by a function, plus ",
              tags$code("summary()"), " / ", tags$code("ggplot()"), ".")
    ),
    div(class = "callout",
        tags$b("Translation rule of thumb: "),
        "do not convert line-by-line. Decide what the SAS program ", tags$i("intends"),
        ", then write that intent in R (usually a dplyr pipeline or a model function)."
    ),
    h4("Mental map"),
    tags$table(class = "guide-table",
      tags$thead(tags$tr(tags$th("SAS world"), tags$th("R world"))),
      tags$tbody(
        tags$tr(tags$td("Library.dataset"), tags$td("object name (people, adsl, mtcars)")),
        tags$tr(tags$td("Numeric / character / date"), tags$td("numeric / character or factor / Date")),
        tags$tr(tags$td("."), tags$td("NA")),
        tags$tr(tags$td("PROC PRINT"), tags$td("print(), head(), View()")),
        tags$tr(tags$td("SAS log"), tags$td("Console + warnings() + messages()")),
        tags$tr(tags$td("Macro %macro"), tags$td("function(...) { }")),
        tags$tr(tags$td("ODS HTML / RTF"), tags$td("R Markdown, Quarto, gt, flextable"))
      )
    )
  )
}

guide_setup <- function() {
  tagList(
    h3("R studio setup for a SAS programmer"),
    tags$ol(
      tags$li("Install R from cran.r-project.org, then RStudio or Positron."),
      tags$li("Install the tidyverse once:",
              tags$pre("install.packages(c(\"tidyverse\", \"haven\", \"readxl\"))")),
      tags$li("Every script starts by attaching what you need:",
              tags$pre("library(tidyverse)   # dplyr, ggplot2, readr, tidyr, ...\nlibrary(haven)       # read_sas(), write_xpt()")),
      tags$li("Read a SAS file:",
              tags$pre("people <- haven::read_sas(\"people.sas7bdat\")\ndplyr::glimpse(people)"))
    ),
    h4("Packages that feel SAS-like"),
    tags$ul(
      tags$li(tags$b("haven"), " — read/write .sas7bdat and .xpt, keep labels."),
      tags$li(tags$b("dplyr / tidyr"), " — the DATA step and PROC TRANSPOSE."),
      tags$li(tags$b("ggplot2"), " — PROC SGPLOT."),
      tags$li(tags$b("procs / sassy"), " — optional packages that mimic PROC FREQ / MEANS output."),
      tags$li(tags$b("broom"), " — tidy model tables instead of ODS OUTPUT.")
    ),
    div(class = "callout",
        "Missing values: SAS uses ", tags$code("."), " and special missings ", tags$code(".A"),
        "–", tags$code(".Z"), ". R uses ", tags$code("NA"),
        ". After ", tags$code("haven::read_sas()"), " inspect labelled missings with ",
        tags$code("haven::zap_missing()"), " or keep them via the labelled class.")
  )
}

guide_datastep <- function() {
  tagList(
    h3("The DATA step, rewritten"),
    p("A SAS DATA step is an implied loop over rows. R works on whole columns.",
      " That is the single most important mindset change."),
    h4("Copy, filter, compute"),
    div(class = "pair",
      div(class = "pair-col", tags$h5("SAS"),
          tags$pre("data adults;\n    set people;\n    where age >= 18;\n    bmi = weight / (height ** 2);\nrun;")),
      div(class = "pair-col", tags$h5("R"),
          tags$pre("adults <- people %>%\n  filter(age >= 18) %>%\n  mutate(bmi = weight / (height ^ 2))"))
    ),
    h4("IF-THEN-ELSE"),
    div(class = "pair",
      div(class = "pair-col", tags$h5("SAS"),
          tags$pre("if age >= 18 then adult = 'Y';\nelse adult = 'N';")),
      div(class = "pair-col", tags$h5("R"),
          tags$pre("mutate(adult = ifelse(age >= 18, \"Y\", \"N\"))\n# or case_when() for many branches"))
    ),
    h4("KEEP, DROP, RENAME"),
    div(class = "pair",
      div(class = "pair-col", tags$h5("SAS"),
          tags$pre("keep id age sex;\ndrop temp;\nrename sex = gender;")),
      div(class = "pair-col", tags$h5("R"),
          tags$pre("select(id, age, sex)\nselect(-temp)\nrename(gender = sex)"))
    ),
    h4("First. / Last. after BY"),
    p("SAS ", tags$code("first.id"), " / ", tags$code("last.id"),
      " become grouped window helpers:"),
    tags$pre("people %>%\n  group_by(id) %>%\n  filter(row_number() == 1)          # first.id\npeople %>%\n  group_by(id) %>%\n  filter(row_number() == n())        # last.id"),
    h4("RETAIN"),
    p(tags$code("retain total 0; total + amount;"), " is ", tags$code("mutate(total = cumsum(amount))"),
      ". For more complex row-to-row state, use ", tags$code("purrr::accumulate()"),
      " or a single pass in base R.")
  )
}

guide_combine <- function() {
  tagList(
    h3("Combining tables"),
    h4("Stack (SET a b)"),
    tags$pre("# SAS: data all; set a b; run;\nall <- bind_rows(a, b)"),
    h4("Match-merge"),
    p("Default SAS ", tags$code("merge; by id;"), " is closest to a full join.",
      " Control the join type with ", tags$code("IN="), " in SAS and with the join verb in R."),
    tags$table(class = "guide-table",
      tags$thead(tags$tr(tags$th("Want"), tags$th("SAS"), tags$th("R"))),
      tags$tbody(
        tags$tr(tags$td("All rows from both"), tags$td("merge; by id;"), tags$td("full_join(a, b, by = \"id\")")),
        tags$tr(tags$td("Rows in A"), tags$td("if a;"), tags$td("left_join(a, b, by = \"id\")")),
        tags$tr(tags$td("Rows in both"), tags$td("if a and b;"), tags$td("inner_join(a, b, by = \"id\")")),
        tags$tr(tags$td("Rows in B"), tags$td("if b;"), tags$td("right_join(a, b, by = \"id\")"))
      )
    ),
    div(class = "callout",
        "Always sort by the BY variables in SAS. dplyr joins do not require a prior PROC SORT.")
  )
}

guide_summarise <- function() {
  tagList(
    h3("Summaries: MEANS, FREQ, UNIVARIATE"),
    h4("PROC MEANS"),
    div(class = "pair",
      div(class = "pair-col", tags$h5("SAS"),
          tags$pre("proc means data=people n mean std;\n    class sex;\n    var age;\nrun;")),
      div(class = "pair-col", tags$h5("R"),
          tags$pre("people %>%\n  group_by(sex) %>%\n  summarise(n = n(),\n            mean_age = mean(age, na.rm = TRUE),\n            sd_age = sd(age, na.rm = TRUE))"))
    ),
    h4("PROC FREQ"),
    tags$pre("table(people$sex)\nprop.table(table(people$sex))\npeople %>% count(sex, region)\nchisq.test(table(people$sex, people$region))"),
    h4("PROC UNIVARIATE"),
    tags$pre("summary(people$age)\nquantile(people$age, na.rm = TRUE)\nhist(people$age)\nshapiro.test(people$age)")
  )
}

guide_models <- function() {
  tagList(
    h3("Models"),
    p("Almost every SAS linear model becomes a formula in R: ",
      tags$code("response ~ pred1 + pred2 + pred1:pred2"), "."),
    tags$table(class = "guide-table",
      tags$thead(tags$tr(tags$th("SAS"), tags$th("R"))),
      tags$tbody(
        tags$tr(tags$td("PROC REG"), tags$td(tags$code("lm(y ~ x1 + x2, data = df)"))),
        tags$tr(tags$td("PROC GLM"), tags$td(tags$code("lm()") , " or ", tags$code("aov()"))),
        tags$tr(tags$td("PROC LOGISTIC"), tags$td(tags$code("glm(y ~ x, family = binomial)"))),
        tags$tr(tags$td("PROC GENMOD"), tags$td(tags$code("glm()"), " with the matching family")),
        tags$tr(tags$td("PROC MIXED"), tags$td(tags$code("lme4::lmer(y ~ x + (1|id))"))),
        tags$tr(tags$td("PROC GLIMMIX"), tags$td(tags$code("lme4::glmer()"))),
        tags$tr(tags$td("PROC PHREG"), tags$td(tags$code("survival::coxph()"))),
        tags$tr(tags$td("PROC LIFETEST"), tags$td(tags$code("survival::survfit()")))
      )
    ),
    tags$pre("fit <- lm(weight ~ height + age + sex, data = people)\nsummary(fit)\ncoef(fit)\nbroom::tidy(fit)     # ODS OUTPUT analogue")
  )
}

guide_io <- function() {
  tagList(
    h3("Input and output"),
    tags$pre("library(haven)\nlibrary(readr)\n\n# SAS dataset\ndf <- read_sas(\"file.sas7bdat\")\nwrite_xpt(df, \"file.xpt\")\n\n# CSV\ndf <- read_csv(\"file.csv\")\nwrite_csv(df, \"file.csv\")\n\n# Excel\nreadxl::read_excel(\"file.xlsx\")"),
    p("A SAS ", tags$code("libname in \"C:\\data\";"), " is just:"),
    tags$pre("in_path <- \"C:/data\"\ndf <- read_sas(file.path(in_path, \"people.sas7bdat\"))")
  )
}

guide_macros <- function() {
  tagList(
    h3("Macros become functions"),
    div(class = "pair",
      div(class = "pair-col", tags$h5("SAS"),
          tags$pre("%macro means_by(ds, cls, var);\n  proc means data=&ds;\n    class &cls;\n    var &var;\n  run;\n%mend;\n%means_by(people, sex, age);")),
      div(class = "pair-col", tags$h5("R"),
          tags$pre("means_by <- function(ds, cls, var) {\n  ds %>%\n    group_by(.data[[cls]]) %>%\n    summarise(n = n(),\n              mean = mean(.data[[var]], na.rm = TRUE))\n}\nmeans_by(people, \"sex\", \"age\")"))
    ),
    p("%LET name = value;", " is simply ", tags$code("name <- \"value\""),
      ". There is no ampersand resolver; you pass arguments into functions.")
  )
}

guide_pitfalls <- function() {
  tagList(
    h3("Pitfalls when you come from SAS"),
    tags$ol(
      tags$li(tags$b("Row loops vs vectors. "),
              tags$code("sum(var1, var2)"), " in a DATA step is row-wise;",
              " in R ", tags$code("sum(df$var1, df$var2)"), " adds the whole vectors.",
              " Use ", tags$code("df$var1 + df$var2"), " or ", tags$code("rowSums().")),
      tags$li(tags$b("= vs ==. "), "SAS uses ", tags$code("="), " for both assignment and comparison.",
              " R assigns with ", tags$code("<-"), " and compares with ", tags$code("=="), "."),
      tags$li(tags$b("Factors vs formats. "), "A SAS format is a label overlay.",
              " An R factor changes how the variable is modeled. Convert on purpose."),
      tags$li(tags$b("Automatic character-to-numeric. "), "SAS often coerces; R does not.",
              " Use ", tags$code("as.numeric()"), " or ", tags$code("readr::parse_number()"), "."),
      tags$li(tags$b("Variable names. "), "SAS is case-insensitive. R is not.",
              " ", tags$code("Age"), " and ", tags$code("age"), " are different columns."),
      tags$li(tags$b("Output is an object. "), "Nothing prints unless you print it.",
              " Assign the result, then ", tags$code("summary()"), " or plot it."),
      tags$li(tags$b("Packages are the product. "), "Base R is small; most work lives in packages.",
              " Pin versions with renv when you share an analysis.")
    )
  )
}

guide_practice <- function() {
  tagList(
    h3("A 7-day practice path"),
    tags$ol(
      tags$li("Day 1 — Read a .sas7bdat with haven. glimpse(), count() one categorical."),
      tags$li("Day 2 — Recreate one DATA step with filter / mutate / select."),
      tags$li("Day 3 — Recreate one PROC MEANS and one PROC FREQ."),
      tags$li("Day 4 — Join two tables and reconcile row counts."),
      tags$li("Day 5 — Fit lm() or glm() for a PROC REG / LOGISTIC you already know."),
      tags$li("Day 6 — One ggplot that replaces an SGPLOT."),
      tags$li("Day 7 — Wrap the whole path in a function and an R Markdown / Quarto file.")
    ),
    p("Use the Converter tab with the built-in examples, then paste your own short SAS steps.",
      " If the converter cannot parse a block, rewrite that block by intent using the Procedure Map.")
  )
}
