# Blog Setup In RStudio

This repository is a blogdown project using Hugo and the `hugo-coder` theme.

This file lives in the repository root and is only documentation. It is not part of the Hugo site content and does not affect the generated website.

## What This Project Uses

- R
- RStudio
- blogdown
- Hugo 0.163.3
- Project-local startup settings in `.Rprofile`

## First-Time Setup On A New Machine

### 1. Install Base Software

Install these first:

- R
- RStudio Desktop
- Git

### 2. Open The Project In RStudio

Open `Blog.Rproj` in RStudio.

Once the project opens, restart the R session once so the project `.Rprofile` is loaded cleanly.

### 3. Install Required R Packages

Run this in the R console:

```r
install.packages(c(
  "blogdown",
  "rmarkdown",
  "knitr",
  "xfun",
  "htmltools"
))
```

If a post needs extra packages, install those as required when knitting that post.

### 4. Install Hugo

This project is currently validated against Hugo `0.163.3`.

Run:

```r
blogdown::install_hugo("0.163.3")
```

After installation, check that blogdown sees the expected version:

```r
blogdown::find_hugo()
blogdown::hugo_version()
```

You should see Hugo `0.163.3`.

### 5. Confirm Project Startup Settings

The project `.Rprofile` does two important things:

- it enables project-specific blogdown behavior
- it points RStudio/blogdown to the Hugo installation under your user profile

Current project settings include:

- `blogdown.serve_site.startup = TRUE`
- `blogdown.knit.on_save = TRUE`
- `blogdown.method = "html"`
- `options(blogdown.hugo.version = "0.163.3")`

If you ever change `.Rprofile`, restart the R session afterwards.

## Validate The Setup

Run these commands in the R console:

```r
blogdown::find_hugo()
blogdown::hugo_version()
blogdown::check_site()
blogdown::build_site(build_rmd = FALSE)
```

If all of those work, the machine is ready.

## Daily Workflow In RStudio

### Live Preview

Usually the site will serve automatically on project startup because of `.Rprofile`.

If not, run:

```r
blogdown::serve_site()
```

### Edit Posts

Most content lives under `content/`.

Typical workflow:

1. open a post `.Rmd`
2. edit content or code
3. save the file
4. let blogdown rebuild and refresh the preview

Because `blogdown.knit.on_save = TRUE`, saving an `.Rmd` normally re-knits that file automatically.

### Build The Full Site

For a full local build:

```r
blogdown::build_site()
```

Generated output goes to `public/`.

### Check The Site

Use:

```r
blogdown::check_site()
```

This is the quickest general health check after package, Hugo, or theme changes.

## Hugo And Theme Notes

This project uses:

- theme: `hugo-coder`
- Hugo config: `config.toml`

The local theme templates were patched for compatibility with Hugo `0.163.3`, so avoid replacing the theme blindly without re-testing the site.

## Files Worth Knowing

- `Blog.Rproj`: RStudio project file
- `.Rprofile`: project startup behavior for blogdown/Hugo
- `config.toml`: Hugo site configuration
- `content/`: source content
- `layouts/`: local template overrides
- `themes/hugo-coder/`: theme files
- `public/`: generated site output

## If Something Stops Working

Try these in order:

```r
blogdown::find_hugo()
blogdown::hugo_version()
blogdown::check_site()
blogdown::build_site(build_rmd = FALSE)
```

If Hugo is missing, reinstall the pinned version:

```r
blogdown::install_hugo("0.163.3", force = TRUE)
```

Then restart R and try again.

## CV Workflow (Data-Driven)

The `/cv/` page is now generated from YAML data mirrored under `data/cv/`.

Single source of truth:

- `https://github.com/thothal/personal-cv-data` (private repo)

Render-time source in this repo:

- `data/cv/profile.yaml`
- `data/cv/experience.yaml`
- `data/cv/education.yaml`
- `data/cv/competencies.yaml`
- `data/cv/achievements.yaml`

### Sync CV Data Into This Repo

Run from the project root:

```text
Rscript .\scripts\sync-cv-data.R -r "thothal/personal-cv-data" -f "main"
```

For private GitHub access, set one of these environment variables first:

- `GITHUB_TOKEN`
- `GH_TOKEN`

Local override mode (useful for testing without GitHub auth):

```text
Rscript .\scripts\sync-cv-data.R -l "C:\path\to\personal-cv-data\data"
```

### CV Page Source And Rendering

- Minimal content entry point: `content/cv/index.md`
- CV layout: `layouts/cv/single.html`
- CV partials: `layouts/partials/cv/`

The old hard-coded files `content/CV.rmd` and `content/CV.html` are obsolete and removed.

### Build And Verify CV

After syncing data:

```r
blogdown::build_site(build_rmd = FALSE)
```

Then open `/cv/` in the local preview.