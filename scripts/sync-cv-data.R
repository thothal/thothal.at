suppressWarnings({
   suppressPackageStartupMessages({
      library(curl)
      library(optparse)
   })
})

.default_repo <- "thothal/personal-cv-data"
.default_ref <- "main"
.default_source_subpath <- "data"
.default_target_dir <- "data/cv"
.default_files <- c(
   "profile.yaml",
   "experience.yaml",
   "education.yaml",
   "competencies.yaml",
   "achievements.yaml"
)

write_info <- function(text) {
   base::message(sprintf("[sync-cv-data] %s", text))
}

get_script_path <- function() {
   cmd_args <- commandArgs(trailingOnly = FALSE)
   file_arg <- "--file="
   script_arg <- grep(file_arg, cmd_args, value = TRUE)
   if (length(script_arg) > 0L) {
      return(normalizePath(sub(file_arg, "", script_arg[1L]), winslash = "/", mustWork = TRUE))
   }

   ofile <- sys.frames()[[1L]]$ofile
   if (!is.null(ofile)) {
      return(normalizePath(ofile, winslash = "/", mustWork = TRUE))
   }

   NULL
}

get_workspace_root <- function() {
   script_path <- get_script_path()
   if (!is.null(script_path)) {
      return(normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE))
   }
   normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

get_github_token <- function() {
   token <- Sys.getenv("GITHUB_TOKEN", unset = "")
   if (nzchar(trimws(token))) {
      return(trimws(token))
   }

   token <- Sys.getenv("GH_TOKEN", unset = "")
   if (nzchar(trimws(token))) {
      return(trimws(token))
   }

   NULL
}

parse_bool <- function(value) {
   value <- tolower(trimws(as.character(value)))
   if (value %in% c("true", "t", "1", "yes", "y")) {
      TRUE
   } else if (value %in% c("false", "f", "0", "no", "n")) {
      FALSE
   } else {
      stop("Invalid boolean value: ", value, call. = FALSE)
   }
}

parse_file_list <- function(value) {
   if (length(value) == 0L || !nzchar(trimws(value))) {
      return(character(0L))
   }
   parts <- unlist(strsplit(value, ",", fixed = TRUE), use.names = FALSE)
   trimws(parts[nzchar(trimws(parts))])
}

escape_json_string <- function(x) {
   x <- gsub("\\\\", "\\\\\\\\", x, fixed = TRUE)
   x <- gsub('"', '\\"', x, fixed = TRUE)
   x <- gsub("\n", "\\n", x, fixed = TRUE)
   x <- gsub("\r", "\\r", x, fixed = TRUE)
   x
}

write_manifest_json <- function(manifest, file_path) {
   files_json <- paste0(
      "[",
      paste(sprintf('"%s"', escape_json_string(manifest$files)), collapse = ", "),
      "]"
   )
   content <- c(
      "{",
      sprintf('  "synced_at_utc": "%s",', escape_json_string(manifest$synced_at_utc)),
      sprintf('  "repo": "%s",', escape_json_string(manifest$repo)),
      sprintf('  "ref": "%s",', escape_json_string(manifest$ref)),
      sprintf('  "source_path": "%s",', escape_json_string(manifest$source_path)),
      sprintf("  \"files\": %s", files_json),
      "}"
   )
   writeLines(content, con = file_path, useBytes = TRUE)
}

expand_github_archive <- function(repo_name, repo_ref, destination_dir) {
   token <- get_github_token()
   if (is.null(token)) {
      stop(sprintf("Missing token. Set GITHUB_TOKEN or GH_TOKEN to access '%s'.", repo_name), call. = FALSE)
   }

   archive_path <- file.path(destination_dir, "cv-data.zip")
   extract_path <- file.path(destination_dir, "extract")
   url <- sprintf("https://api.github.com/repos/%s/zipball/%s", repo_name, repo_ref)

   headers <- c(
      Authorization = sprintf("Bearer %s", token),
      Accept = "application/vnd.github+json",
      `User-Agent` = "cv-sync-script",
      `X-GitHub-Api-Version` = "2026-03-10"
   )

   write_info(sprintf("Downloading %s@%s", repo_name, repo_ref))
   handle <- curl::new_handle(followlocation = TRUE)
   handle <- curl::handle_setheaders(handle, .list = headers)
   curl::curl_download(url, destfile = archive_path, handle = handle, quiet = TRUE)

   write_info("Extracting archive")
   unzip(archive_path, exdir = extract_path)

   roots <- list.dirs(extract_path, recursive = FALSE, full.names = TRUE)
   if (length(roots) == 0L) {
      stop(sprintf("No root directory found in GitHub archive at %s", extract_path), call. = FALSE)
   }
   if (length(roots) != 1L) {
      stop(
         sprintf(
            "Unexpected archive structure. Expected 1 root folder, found %d: %s",
            length(roots),
            paste(basename(roots), collapse = ", ")
         ),
         call. = FALSE
      )
   }

   roots[[1L]]
}

copy_cv_data_files <- function(source_root, relative_data_path, target_path, file_list) {
   source_data_dir <- if (identical(relative_data_path, ".")) {
      source_root
   } else {
      file.path(source_root, relative_data_path)
   }

   if (!dir.exists(source_data_dir)) {
      stop(sprintf("Source data directory not found: %s", source_data_dir), call. = FALSE)
   }

   dir.create(target_path, recursive = TRUE, showWarnings = FALSE)

   for (file_name in file_list) {
      source_file <- file.path(source_data_dir, file_name)
      target_file <- file.path(target_path, file_name)

      if (!file.exists(source_file)) {
         stop(sprintf("Missing required file: %s", source_file), call. = FALSE)
      }

      ok <- file.copy(source_file, target_file, overwrite = TRUE)
      if (!isTRUE(ok)) {
         stop(sprintf("Failed to copy file: %s", file_name), call. = FALSE)
      }
      write_info(sprintf("Copied %s", file_name))
   }
}

sync_cv_data <- function(repo = .default_repo,
                         ref = .default_ref,
                         source_subpath = .default_source_subpath,
                         target_dir = .default_target_dir,
                         files = .default_files,
                         local_data_path = NULL) {
   workspace_root <- get_workspace_root()
   target_path <- file.path(workspace_root, target_dir)
   temp_root <- file.path(workspace_root, ".tmp", "cv-sync")

   if (dir.exists(temp_root)) {
      unlink(temp_root, recursive = TRUE, force = TRUE)
   }
   dir.create(temp_root, recursive = TRUE, showWarnings = FALSE)

   on.exit(
      {
         if (dir.exists(temp_root)) {
            unlink(temp_root, recursive = TRUE, force = TRUE)
         }
      },
      add = TRUE
   )

   if (!is.null(local_data_path) && nzchar(trimws(local_data_path))) {
      resolved_local <- normalizePath(local_data_path, winslash = "/", mustWork = TRUE)
      write_info(sprintf("Using local path: %s", resolved_local))

      copy_cv_data_files(
         source_root = resolved_local,
         relative_data_path = ".",
         target_path = target_path,
         file_list = files
      )
   } else {
      archive_root <- expand_github_archive(
         repo_name = repo,
         repo_ref = ref,
         destination_dir = temp_root
      )

      copy_cv_data_files(
         source_root = archive_root,
         relative_data_path = source_subpath,
         target_path = target_path,
         file_list = files
      )
   }

   manifest <- list(
      synced_at_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC"),
      repo = repo,
      ref = ref,
      source_path = source_subpath,
      files = files
   )

   manifest_path <- file.path(target_path, "_sync-manifest.json")
   write_manifest_json(manifest, manifest_path)

   write_info(sprintf("Sync complete -> %s", target_path))
   invisible(target_path)
}

parse_cli_args <- function(args = commandArgs(trailingOnly = TRUE)) {
   option_list <- list(
      make_option(c("-r", "--repo"),
         type = "character", default = .default_repo,
         help = "GitHub repo in owner/name format [default %default]"
      ),
      make_option(c("-f", "--ref"),
         type = "character", default = .default_ref,
         help = "Git ref/branch/tag [default %default]"
      ),
      make_option(c("-s", "--source-subpath"),
         type = "character", default = .default_source_subpath,
         help = "Path to data directory inside the repo/archive [default %default]"
      ),
      make_option(c("-t", "--target-dir"),
         type = "character", default = .default_target_dir,
         help = "Local target directory under the workspace root [default %default]"
      ),
      make_option(c("-l", "--local-data-path"),
         type = "character", default = NULL,
         help = "Use a local data path instead of downloading from GitHub"
      ),
      make_option(c("-F", "--files"),
         type = "character", default = paste(.default_files, collapse = ","),
         help = "Comma-separated list of required files [default %default]"
      ),
      make_option(c("-q", "--quiet"),
         action = "store_true", default = FALSE,
         help = "Suppress informational output"
      )
   )

   parser <- OptionParser(
      option_list = option_list,
      description = "Sync CV data from GitHub or a local checkout into data/cv/"
   )
   opts <- parse_args(parser, args = args)
   opts$files <- parse_file_list(opts$files)
   opts
}

main <- function() {
   opts <- parse_cli_args()
   if (isTRUE(opts$quiet)) {
      sink(tempfile(), type = "output")
      on.exit(sink(type = "output"), add = TRUE)
   }
   sync_cv_data(
      repo = opts$repo,
      ref = opts$ref,
      source_subpath = opts$source_subpath,
      target_dir = opts$target_dir,
      files = opts$files,
      local_data_path = opts$local_data_path
   )
}

if (!interactive()) {
   main()
}

# Interactive usage from RStudio:
# source('scripts/sync-cv-data.R')
# sync_cv_data(repo = 'thothal/personal-cv-data', ref = 'main')
# sync_cv_data(local_data_path = 'C:/path/to/personal-cv-data/data')
