# SAS <-> R Learner Guide
# Shiny application: guide + instant teaching converter
#
# Run locally:
#   shiny::runApp()
# or open this file in RStudio and click Run App.

app_dir <- if (sys.nframe() > 0 && !is.null(sys.frame(1)$ofile)) {
  dirname(normalizePath(sys.frame(1)$ofile))
} else {
  getwd()
}

source(file.path(app_dir, "R", "convert.R"), local = TRUE)
source(file.path(app_dir, "R", "examples.R"), local = TRUE)
source(file.path(app_dir, "R", "guide.R"), local = TRUE)

need <- c("shiny", "htmltools")
missing <- need[!vapply(need, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop(
    "Please install required packages first:\n  install.packages(c(",
    paste(sprintf("\"%s\"", missing), collapse = ", "),
    "))",
    call. = FALSE
  )
}

library(shiny)
library(htmltools)

optional_dt <- requireNamespace("DT", quietly = TRUE)

ui <- fluidPage(
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "custom.css"),
    tags$link(
      rel = "stylesheet",
      href = "https://fonts.googleapis.com/css2?family=Source+Sans+3:wght@400;600;700&family=IBM+Plex+Mono:wght@400;500&display=swap"
    ),
    tags$title("SAS to R Learner Guide")
  ),
  navbarPage(
    title = "SAS ↔ R Learner",
    id = "main_nav",
    header = NULL,
    footer = div(
      class = "footer-note",
      "Teaching converter — pattern-based, not a full SAS compiler. Review every translation before production use."
    ),

    tabPanel(
      "Home",
      div(
        class = "hero",
        h1("Learn R from the SAS you already know"),
        p("A compact learner guide plus an instant SAS ↔ R converter for the DATA step and the procedures you use every day."),
        div(
          class = "badge-row",
          span(class = "pill", "Guide"),
          span(class = "pill", "SAS → R"),
          span(class = "pill", "R → SAS"),
          span(class = "pill", "Procedure map"),
          span(class = "pill", "GitHub ready")
        )
      ),
      div(
        class = "card-grid",
        div(class = "info-card", h4("1. Read the guide"), p("Mindset, DATA step, joins, PROCs, models, macros, and common pitfalls.")),
        div(class = "info-card", h4("2. Convert a snippet"), p("Paste a short SAS or R block. Get a teaching translation plus notes.")),
        div(class = "info-card", h4("3. Use the map"), p("Look up the R equivalent of 25+ procedures before you rewrite a program.")),
        div(class = "info-card", h4("4. Push to GitHub"), p("This folder is a complete repo. Follow README.md to publish it."))
      ),
      h3("What this app will and will not do"),
      tags$ul(
        tags$li(tags$b("Will: "), "translate common teaching patterns — DATA step subset/assign, MEANS, FREQ, SORT, REG, LOGISTIC, SGPLOT, IMPORT/EXPORT, simple dplyr pipelines."),
        tags$li(tags$b("Will not: "), "compile arbitrary SAS (macros with nested %IF, ODS OUTPUT, PROC MIXED random-effects syntax, SCAS, DS2). Rewrite those by intent."),
        tags$li(tags$b("Best results: "), "one DATA step or one PROC at a time, then compose the pieces.")
      ),
      actionButton("go_convert", "Open the converter", class = "btn-primary"),
      actionButton("go_guide", "Start the guide", class = "btn-default")
    ),

    tabPanel(
      "Guide",
      sidebarLayout(
        sidebarPanel(
          width = 3,
          radioButtons(
            "guide_section",
            "Section",
            choices = c(
              "Mindset" = "intro",
              "Setup" = "setup",
              "DATA step" = "datastep",
              "Combine tables" = "combine",
              "Summaries" = "summarise",
              "Models" = "models",
              "Input / output" = "io",
              "Macros → functions" = "macros",
              "Pitfalls" = "pitfalls",
              "7-day path" = "practice"
            )
          )
        ),
        mainPanel(
          width = 9,
          uiOutput("guide_panel")
        )
      )
    ),

    tabPanel(
      "Converter",
      fluidRow(
        column(
          12,
          div(
            class = "callout",
            tags$b("Instant teaching converter. "),
            "Pick a direction, load an example or paste your own code, then convert. Read the notes under the result."
          )
        )
      ),
      fluidRow(
        column(
          3,
          radioButtons(
            "direction",
            "Direction",
            choices = c("SAS → R" = "sas2r", "R → SAS" = "r2sas")
          ),
          selectInput(
            "example_pick",
            "Load example",
            choices = c("— choose —" = "", example_choices)
          ),
          actionButton("do_convert", "Convert", class = "btn-primary", width = "100%"),
          br(), br(),
          actionButton("swap_dir", "Swap boxes", width = "100%"),
          br(), br(),
          actionButton("clear_boxes", "Clear", width = "100%"),
          br(), br(),
          checkboxInput("show_notes", "Show translator notes", TRUE)
        ),
        column(
          9,
          class = "convert-pane",
          fluidRow(
            column(
              6,
              tags$label(textOutput("input_label", inline = TRUE)),
              textAreaInput(
                "src_code",
                NULL,
                width = "100%",
                height = "340px",
                placeholder = "Paste code here"
              )
            ),
            column(
              6,
              tags$label(textOutput("out_label", inline = TRUE)),
              div(
                style = "position: relative;",
                verbatimTextOutput("converted"),
                tags$style(HTML("#converted { min-height: 340px; white-space: pre-wrap; }"))
              )
            )
          ),
          conditionalPanel(
            "input.show_notes == true",
            h4("Notes"),
            uiOutput("convert_notes")
          )
        )
      )
    ),

    tabPanel(
      "Procedure map",
      p("The procedures that cover most day-to-day SAS work, with a practical R landing place."),
      if (optional_dt) {
        DT::dataTableOutput("proc_table")
      } else {
        tableOutput("proc_table_basic")
      },
      br(),
      p("Want SAS-looking printed reports in R? Look at the ",
        tags$b("procs"), " and ", tags$b("sassy"), " packages. Want labelled SAS columns? Use ",
        tags$b("haven"), ".")
    ),

    tabPanel(
      "Examples",
      fluidRow(
        column(
          3,
          selectInput("gallery_pick", "Example", choices = example_choices),
          p(class = "help-block", "These pairs are also loaded into the Converter tab.")
        ),
        column(
          9,
          uiOutput("gallery_view")
        )
      )
    ),

    tabPanel(
      "GitHub",
      h3("Put this app in a new GitHub repository"),
      p("Recommended name: ", tags$code("sas2r-guide"),
        ". Full click-by-click expert guide: ", tags$code("GITHUB_SETUP.md"),
        " in this project."),
      h4("1. Create the empty repo on GitHub"),
      tags$ol(
        tags$li("Sign in at github.com → + → New repository (github.com/new)."),
        tags$li("Repository name: ", tags$code("sas2r-guide"), "."),
        tags$li(tags$b("Do not"), " add a README, .gitignore, or license — those files are already here."),
        tags$li("Click Create repository and copy the HTTPS URL.")
      ),
      h4("2. From a terminal in this folder"),
      tags$pre(
        "git remote add origin https://github.com/<YOUR-USER>/sas2r-guide.git\ngit branch -M main\ngit push -u origin main"
      ),
      p("If you use GitHub CLI (creates the repo and pushes in one step):"),
      tags$pre("gh auth login\ngh repo create sas2r-guide --public --source=. --remote=origin --push"),
      h4("3. Run the app after cloning"),
      tags$pre(
        "install.packages(c(\"shiny\", \"htmltools\", \"DT\"))\n# optional but useful while learning R:\ninstall.packages(c(\"tidyverse\", \"haven\"))\nshiny::runApp()"
      ),
      h4("4. Optional: publish a live demo"),
      tags$ul(
        tags$li("shinyapps.io — ", tags$code("rsconnect::deployApp()")),
        tags$li("Posit Connect / Shiny Server if your organization hosts Shiny"),
        tags$li("GitHub only is enough if teammates run it locally")
      ),
      div(
        class = "callout",
        tags$b("Suggested repo description: "),
        "Interactive SAS ↔ R learner guide with a teaching code converter (Shiny)."
      )
    )
  )
)

server <- function(input, output, session) {

  observeEvent(input$go_convert, {
    updateNavbarPage(session, "main_nav", selected = "Converter")
  })
  observeEvent(input$go_guide, {
    updateNavbarPage(session, "main_nav", selected = "Guide")
  })

  output$guide_panel <- renderUI({
    switch(
      input$guide_section,
      intro = guide_intro(),
      setup = guide_setup(),
      datastep = guide_datastep(),
      combine = guide_combine(),
      summarise = guide_summarise(),
      models = guide_models(),
      io = guide_io(),
      macros = guide_macros(),
      pitfalls = guide_pitfalls(),
      practice = guide_practice(),
      guide_intro()
    )
  })

  output$input_label <- renderText({
    if (isTRUE(input$direction == "r2sas")) "R input" else "SAS input"
  })
  output$out_label <- renderText({
    if (isTRUE(input$direction == "r2sas")) "SAS output" else "R output"
  })

  observeEvent(input$example_pick, {
    req(nzchar(input$example_pick))
    ex <- example_catalog[[input$example_pick]]
    req(!is.null(ex))
    if (isTRUE(input$direction == "r2sas")) {
      updateTextAreaInput(session, "src_code", value = ex$r)
    } else {
      updateTextAreaInput(session, "src_code", value = ex$sas)
    }
  })

  result <- reactiveVal(list(code = "", notes = character(0), warnings = character(0)))

  observeEvent(input$do_convert, {
    src <- input$src_code
    if (isTRUE(input$direction == "r2sas")) {
      result(convert_r_to_sas(src))
    } else {
      result(convert_sas_to_r(src))
    }
  })

  observeEvent(input$clear_boxes, {
    updateTextAreaInput(session, "src_code", value = "")
    updateSelectInput(session, "example_pick", selected = "")
    result(list(code = "", notes = character(0), warnings = character(0)))
  })

  observeEvent(input$swap_dir, {
    current <- result()$code
    src <- input$src_code
    if (isTRUE(input$direction == "sas2r")) {
      updateRadioButtons(session, "direction", selected = "r2sas")
      if (nzchar(trim_ws(current))) updateTextAreaInput(session, "src_code", value = current)
    } else {
      updateRadioButtons(session, "direction", selected = "sas2r")
      if (nzchar(trim_ws(current))) updateTextAreaInput(session, "src_code", value = current)
    }
    result(list(code = src, notes = "Swapped. Click Convert to translate the new input.", warnings = character(0)))
  })

  output$converted <- renderText({
    code <- result()$code
    if (!nzchar(trim_ws(code))) {
      return("/* Result appears here after you click Convert */")
    }
    code
  })

  output$convert_notes <- renderUI({
    res <- result()
    note_items <- lapply(res$notes, function(n) tags$li(class = "note-ok", n))
    warn_items <- lapply(res$warnings, function(n) tags$li(class = "note-warn", n))
    if (!length(note_items) && !length(warn_items)) {
      return(p("Notes will appear after conversion."))
    }
    tags$ul(note_items, warn_items)
  })

  if (optional_dt) {
    output$proc_table <- DT::renderDataTable({
      DT::datatable(
        procedure_map,
        rownames = FALSE,
        options = list(pageLength = 15, autoWidth = TRUE)
      )
    })
  }
  output$proc_table_basic <- renderTable({
    procedure_map
  })

  output$gallery_view <- renderUI({
    ex <- example_catalog[[input$gallery_pick]]
    req(!is.null(ex))
    tagList(
      h3(ex$title),
      p(tags$span(class = "pill", style = "background:#0c2340;", ex$topic)),
      div(
        class = "pair",
        div(class = "pair-col", tags$h5("SAS"), tags$pre(ex$sas)),
        div(class = "pair-col", tags$h5("R"), tags$pre(ex$r))
      ),
      actionButton("send_to_converter", "Open this example in the Converter")
    )
  })

  observeEvent(input$send_to_converter, {
    updateNavbarPage(session, "main_nav", selected = "Converter")
    updateSelectInput(session, "example_pick", selected = input$gallery_pick)
    ex <- example_catalog[[input$gallery_pick]]
    if (!is.null(ex)) updateTextAreaInput(session, "src_code", value = ex$sas)
    updateRadioButtons(session, "direction", selected = "sas2r")
  })
}

shinyApp(ui, server)
