suppressWarnings({
   suppressPackageStartupMessages({
      library(here)
      library(keyring)
      library(curl)
      library(stringr)
      library(glue)
      library(cli)
      library(blogdown)
      library(optparse)
   })
})

.service_name <- "w00dd9c5.kasserver.com"
.public <- here("public")


get_credentials <- function(service, username = NULL, password = NULL) {
   user_name <- if (!is.null(username)) {
      username
   } else {
      str_extract(service, "^[^.]+")
   }
   if (is.null(password)) {
      password <- key_get(service, user_name)
   }
   list(
      url = glue("ftp://{service}"),
      user_name = user_name,
      password = password
   )
}

get_all_files <- function(root) {
   list.files(root, recursive = TRUE)
}

parse_bool <- function(value) {
   value <- tolower(value)
   if (value %in% c("true", "t", "1", "yes", "y")) {
      TRUE
   } else if (value %in% c("false", "f", "0", "no", "n")) {
      FALSE
   } else {
      stop("Invalid boolean value: ", value, call. = FALSE)
   }
}

.cli_quiet <- FALSE

make_quiet_wrapper <- function(fun) {
   force(fun)
   
   function(..., .envir = parent.frame()) {
      if (!.cli_quiet) {
         fun(..., .envir = .envir)
      }
      invisible(NULL)
   }
}

local({
   cli_functions <- c(
      "cli_alert_info",
      "cli_alert_success",
      "cli_alert_warning",
      "cli_alert_danger",
      "cli_h2",
      "cli_progress_bar",
      "cli_progress_update",
      "cli_progress_done"
   )
   for (fname in cli_functions) {
      assign(
         paste0(fname, "_q"),
         make_quiet_wrapper(get(fname, envir = asNamespace("cli"))),
         envir = .GlobalEnv
      )
   }
})

parse_cli_args <- function(args = commandArgs(trailingOnly = TRUE)) {
   option_list <- list(
      make_option(c("-a", "--action"),
                  type = "character", default = "all",
                  help = "Which task to run [build|upload|all] (default %default)."
      ),
      make_option(c("-s", "--service"),
                  type = "character", default = .service_name,
                  help = "FTP service/host (default %default)."
      ),
      make_option(c("-r", "--root"),
                  type = "character", default = .public,
                  help = "Local public folder path (default %default)."
      ),
      make_option(c("-u", "--username"),
                  type = "character", default = NULL,
                  help = "Override FTP username."
      ),
      make_option(c("-p", "--password"),
                  type = "character", default = NULL,
                  help = "Override FTP password."
      ),
      make_option(c("-q", "--quiet"),
                  action = "store_true", default = FALSE,
                  help = "Suppress CLI output."
      ),
      make_option(c("-b", "--build-rmd"),
                  type = "character", default = "TRUE",
                  help = "Rebuild site before upload (TRUE/FALSE, default %default)."
      )
   )
   
   parser <- OptionParser(
      option_list = option_list,
      description = "Build and/or upload the blog website."
   )
   opts <- parse_args(parser, args = args)
   opts$action <- tolower(opts$action)
   if (!opts$action %in% c("build", "upload", "all")) {
      stop("Unsupported action: ", opts$action, call. = FALSE)
   }
   opts$build_rmd <- parse_bool(opts$build_rmd)
   opts
}

upload_file <- function(file, credentials, root) {
   curl_upload(
      here(root, file),
      file.path(credentials$url, file),
      verbose = FALSE,
      ftp_create_missing_dirs = TRUE,
      username = credentials$user_name,
      password = credentials$password
   )
}

upload_webpage <- function(service = .service_name, root = .public, username = NULL, 
                           password = NULL) {
   cli_h2_q("Upload Website")
   files <- get_all_files(root)
   n_files <- length(files)
   cli_alert_info_q("Found {n_files} file{?s}")
   creds <- get_credentials(service, username = username, password = password)
   msg <- paste(
      "Uploading to {.url {creds$url}}",
      "(username {.field {creds$user_name}}, password: {.field *****})"
   )
   cli_alert_info_q(msg)
   pb <- cli_progress_bar_q(
      total = n_files,
      format = paste0(
         "Uploading File {pb_current}/{pb_total} ",
         "{pb_bar} {pb_percent} ETA: {pb_eta} ",
         "| {.file {basename(file)}}"
      )
   )
   start <- Sys.time()
   err_files <- character(0L)
   for (file in files) {
      tryCatch(
         upload_file(file, creds, root),
         error = function(err) {
            err_files <<- c(err_files, file)
            cli_alert_danger_q("Error uploading file {.file {file}}")
         }
      )
      cli_progress_update_q()
   }
   elapsed <- as.numeric(Sys.time() - start, units = "secs") |>
      round(digits = 0L)
   timestamp <- sprintf(
      "%02d:%02d",
      elapsed %/% 60L,
      elapsed %% 60L
   )
   cli_progress_done_q()
   cli_alert_success_q("{n_files - length(err_files)} file{?s} uploaded in [{timestamp}]")
   if (length(err_files)) {
      cli_alert_warning_q(
         "{length(err_files)} file{?s} could not be uploaded: {.file {basename(err_files)}}"
      )
   }
}


build_webpage <- function(build_rmd = TRUE, quiet = FALSE) {
   cli_h2_q("Building Website")
   start <- Sys.time()
   if (quiet) {
      suppressWarnings({
         nf <- file(nullfile(), "wt", blocking = FALSE)
         sink(nf, type = "output")
         sink(nf, type = "message")
         on.exit({
            sink(type = "output")
            sink(type = "message")
            close(nf)
         }, add = TRUE)
         build_site(build_rmd = build_rmd, args = c("--quiet"))
      })
   } else {
      build_site(build_rmd = build_rmd)
   }
   elapsed <- as.numeric(Sys.time() - start, units = "secs") |>
      round(digits = 0L)
   timestamp <- sprintf(
      "%02d:%02d",
      elapsed %/% 60L,
      elapsed %% 60L
   )
   cli_alert_success_q("Website built in [{timestamp}]")
}

main <- function() {
   opts <- parse_cli_args()
   if (opts$action %in% c("build", "all")) {
      .cli_quiet <<- opts$quiet
      build_webpage(opts$build_rmd, opts$quiet)
   }
   if (opts$action %in% c("upload", "all")) {
      .cli_quiet <<- opts$quiet
      upload_webpage(
         opts$service,
         opts$root,
         username = opts$username,
         password = opts$password
      )
   }
}

if (!interactive()) {
   main()
}

# Interactive usage from RStudio:
# source('scripts/upload_public_to_ftp.R')
# build_website()
# upload_webpage()
# upload_webpage(service = 'example.com', username = 'user', password = 'secret')
