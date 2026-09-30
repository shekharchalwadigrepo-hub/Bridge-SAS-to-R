# Built-in side-by-side examples for the converter and guide.

example_catalog <- list(
  data_filter = list(
    title = "DATA step: filter + new variable",
    topic = "Data step",
    sas = "data adults;\n    set people;\n    where age >= 18 and sex = 'M';\n    bmi = weight / (height ** 2);\n    keep id age sex bmi;\nrun;",
    r = "library(dplyr)\nadults <- people %>%\n  filter(age >= 18, sex == \"M\") %>%\n  mutate(bmi = weight / (height ^ 2)) %>%\n  select(id, age, sex, bmi)"
  ),
  ifelse = list(
    title = "IF-THEN-ELSE",
    topic = "Data step",
    sas = "data flagged;\n    set people;\n    if age >= 18 then adult = 'Y';\n    else adult = 'N';\nrun;",
    r = "library(dplyr)\nflagged <- people %>%\n  mutate(adult = ifelse(age >= 18, \"Y\", \"N\"))"
  ),
  keep_drop = list(
    title = "KEEP / DROP / RENAME",
    topic = "Data step",
    sas = "data slim;\n    set people;\n    keep id age sex;\n    rename sex = gender;\nrun;",
    r = "library(dplyr)\nslim <- people %>%\n  select(id, age, sex) %>%\n  rename(gender = sex)"
  ),
  merge = list(
    title = "MERGE by key",
    topic = "Combine",
    sas = "proc sort data=demo; by id; run;\nproc sort data=labs; by id; run;\ndata both;\n    merge demo labs;\n    by id;\nrun;",
    r = "library(dplyr)\nboth <- demo %>%\n  full_join(labs, by = \"id\")"
  ),
  concat = list(
    title = "Concatenate (SET two tables)",
    topic = "Combine",
    sas = "data stacked;\n    set wave1 wave2;\nrun;",
    r = "library(dplyr)\nstacked <- bind_rows(wave1, wave2)"
  ),
  means = list(
    title = "PROC MEANS with CLASS",
    topic = "Summarise",
    sas = "proc means data=people n mean std min max;\n    class sex;\n    var age weight;\nrun;",
    r = "library(dplyr)\npeople %>%\n  group_by(sex) %>%\n  summarise(\n    n = n(),\n    across(c(age, weight),\n           list(mean = ~mean(.x, na.rm = TRUE),\n                sd   = ~sd(.x, na.rm = TRUE),\n                min  = ~min(.x, na.rm = TRUE),\n                max  = ~max(.x, na.rm = TRUE)),\n           .names = \"{.col}_{.fn}\")\n  )"
  ),
  freq = list(
    title = "PROC FREQ one-way",
    topic = "Summarise",
    sas = "proc freq data=people;\n    tables sex;\nrun;",
    r = "library(dplyr)\npeople %>%\n  count(sex, name = \"Frequency\") %>%\n  mutate(Percent = 100 * Frequency / sum(Frequency))"
  ),
  freq2 = list(
    title = "PROC FREQ two-way + chi-square",
    topic = "Summarise",
    sas = "proc freq data=people;\n    tables sex * region / chisq;\nrun;",
    r = "tab <- table(people$sex, people$region)\ntab\nprop.table(tab, margin = 1)\nchisq.test(tab)"
  ),
  sort = list(
    title = "PROC SORT",
    topic = "Data step",
    sas = "proc sort data=people out=people_s;\n    by sex descending age;\nrun;",
    r = "library(dplyr)\npeople_s <- people %>%\n  arrange(sex, desc(age))"
  ),
  print = list(
    title = "PROC PRINT first 10",
    topic = "Inspect",
    sas = "proc print data=people (obs=10);\n    var id age sex;\nrun;",
    r = "people %>%\n  dplyr::select(id, age, sex) %>%\n  head(10)"
  ),
  contents = list(
    title = "PROC CONTENTS",
    topic = "Inspect",
    sas = "proc contents data=people;\nrun;",
    r = "str(people)\ndplyr::glimpse(people)\nnames(people)"
  ),
  reg = list(
    title = "PROC REG / linear model",
    topic = "Models",
    sas = "proc reg data=people;\n    model weight = height age;\nrun; quit;",
    r = "fit <- lm(weight ~ height + age, data = people)\nsummary(fit)"
  ),
  logistic = list(
    title = "PROC LOGISTIC",
    topic = "Models",
    sas = "proc logistic data=people;\n    model adult(event='Y') = age weight;\nrun;",
    r = "fit <- glm(adult ~ age + weight, data = people, family = binomial())\nsummary(fit)\nexp(cbind(OR = coef(fit), confint(fit)))"
  ),
  glm = list(
    title = "PROC GLM / ANOVA",
    topic = "Models",
    sas = "proc glm data=people;\n    class sex;\n    model weight = sex age;\nrun; quit;",
    r = "people$sex <- factor(people$sex)\nfit <- lm(weight ~ sex + age, data = people)\nsummary(fit)\nanova(fit)"
  ),
  import = list(
    title = "PROC IMPORT CSV",
    topic = "I/O",
    sas = "proc import datafile=\"people.csv\"\n    out=people\n    dbms=csv replace;\n    getnames=yes;\nrun;",
    r = "library(readr)\npeople <- read_csv(\"people.csv\")"
  ),
  export = list(
    title = "PROC EXPORT CSV",
    topic = "I/O",
    sas = "proc export data=people\n    outfile=\"people.csv\"\n    dbms=csv replace;\nrun;",
    r = "readr::write_csv(people, \"people.csv\")"
  ),
  sgplot = list(
    title = "PROC SGPLOT scatter",
    topic = "Plots",
    sas = "proc sgplot data=people;\n    scatter x=height y=weight;\nrun;",
    r = "library(ggplot2)\nggplot(people, aes(x = height, y = weight)) + geom_point()"
  ),
  transpose = list(
    title = "PROC TRANSPOSE to wide",
    topic = "Reshape",
    sas = "proc transpose data=long out=wide;\n    by id;\n    id visit;\n    var score;\nrun;",
    r = "library(tidyr)\nwide <- long %>%\n  pivot_wider(id_cols = id, names_from = visit, values_from = score)"
  ),
  sql = list(
    title = "PROC SQL group summary",
    topic = "SQL",
    sas = "proc sql;\n    select sex,\n           count(*) as n,\n           mean(age) as mean_age\n    from people\n    group by sex;\nquit;",
    r = "library(dplyr)\npeople %>%\n  group_by(sex) %>%\n  summarise(n = n(), mean_age = mean(age, na.rm = TRUE))"
  ),
  univariate = list(
    title = "PROC UNIVARIATE",
    topic = "Summarise",
    sas = "proc univariate data=people;\n    var age;\nrun;",
    r = "summary(people$age)\nquantile(people$age, probs = c(0, .25, .5, .75, 1), na.rm = TRUE)\nhist(people$age)"
  )
)

example_choices <- setNames(
  names(example_catalog),
  vapply(example_catalog, `[[`, character(1), "title")
)

procedure_map <- data.frame(
  SAS = c(
    "DATA step SET", "WHERE / subsetting IF", "KEEP / DROP", "RENAME",
    "IF-THEN-ELSE", "RETAIN + sum", "MERGE BY", "SET two tables",
    "PROC SORT", "PROC PRINT", "PROC CONTENTS", "PROC MEANS / SUMMARY",
    "PROC FREQ", "PROC UNIVARIATE", "PROC TRANSPOSE",
    "PROC IMPORT", "PROC EXPORT", "PROC SQL",
    "PROC REG", "PROC GLM", "PROC LOGISTIC", "PROC MIXED",
    "PROC PHREG", "PROC LIFETEST", "PROC SGPLOT",
    "LIBNAME", "%LET / macro var", "SAS formats", "Missing values"
  ),
  R = c(
    "df2 <- df1", "filter() / subset()", "select() / df$x <- NULL", "rename() / names()",
    "ifelse() / case_when()", "cumsum() / accumulate", "left_join / merge()", "bind_rows() / rbind()",
    "arrange() / order()", "print() / head() / View()", "str() / glimpse() / names()",
    "summarise() / summary() / aggregate()",
    "count() / table() / prop.table()", "summary() / quantile() / hist()",
    "pivot_wider() / pivot_longer()",
    "read_csv() / read_sas() / read_excel()", "write_csv() / write_xpt()",
    "dplyr verbs or sqldf()",
    "lm()", "lm() / aov()", "glm(..., family = binomial)", "lme4::lmer() / nlme::lme()",
    "survival::coxph()", "survival::survfit()", "ggplot2",
    "A folder path string", "A regular R object", "factor() / labelled", "NA (and NaN)"
  ),
  Package = c(
    "base", "dplyr", "dplyr", "dplyr",
    "dplyr / base", "dplyr / base", "dplyr", "dplyr",
    "dplyr", "base", "base / dplyr", "dplyr",
    "dplyr / base", "base",
    "tidyr",
    "readr / haven / readxl", "readr / haven",
    "dplyr / sqldf",
    "stats", "stats", "stats", "lme4 / nlme",
    "survival", "survival", "ggplot2",
    "base", "base", "haven / forcats", "base"
  ),
  stringsAsFactors = FALSE
)
