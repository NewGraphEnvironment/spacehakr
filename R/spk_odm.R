#' Construct Docker Command Arguments for ODM
#'
#' Generates arguments for running the OpenDroneMap Docker container (WHICH MUST BE RUNNING FOR THESE args to be PASSED TO IT) with a specified
#' project path. The function can produce either a vector of arguments for `processx::run` or a complete Docker command as a string ready to copy and paste into the
#' terminal, depending on the `interactive` parameter. It includes opinionated `params_default` optimized for processing
#' high-resolution imagery, producing outputs such as a digital surface model (DSM) and a digital terrain model (DTM).
#'
#' @param path_project [character] The absolute path to the directory where the project is held. Must be a valid directory.
#' @param params_default [character] or [NULL] Optional. A character vector of opinionated parameters to include in the arguments. Defaults to
#' c("--dtm", "--dsm", "--cog", "--pc-quality", "low", "--dem-resolution", "10").
#' @param params_add [character] or [NULL] Optional. A character vector of additional parameters to include in the arguments.
#' @param interactive [logical] Whether to include the `-ti` flag for interactive mode. If `TRUE`, the full command including
#' `docker` is returned as a single string for terminal use. Default is `FALSE`.
#'
#' @return [character] A vector of arguments to pass to `processx::run`, or a single string with the full command for
#' terminal use if `interactive = TRUE`.
#' @family command-builder
#'
#' @examples
#' \dontrun{
#' path_project <- "/Volumes/backup_2022/backups/new_graph/archive/uav_imagery/fraser/nechacko/2024/199174_necr_trib_dog"
#' args <- spk_odm(
#'   path_project,
#'   params_add = c("--rerun-from", "odm_dem", "--orthophoto-kmz", "--copy-to", "~/Projects"),
#'   interactive = FALSE
#' )
#' processx::run(command = "docker", args = args, echo = TRUE)
#'
#' # Generate a quick running command for interactive terminal use:
#' interactive_command <- spk_odm(
#'   path_project,
#'   params_default = NULL,
#'   params_add = c("--fast-orthophoto",
#'                "--pc-quality", "low",
#'                "--skip-report",
#'               "--orthophoto-resolution", "20"),
#'               ,
#'   interactive = TRUE
#'   )
#'
#' cat(interactive_command, "\n")
#'
#' #process multiple project files that contain `images` directory
#' paths <- c("/Volumes/backup_2022/backups/new_graph/archive/uav_imagery/skeena/bulkley/2024/8530_sandstone_test",
#'            "/Volumes/backup_2022/backups/new_graph/archive/uav_imagery/skeena/bulkley/2024/8530_sandstone_test2")
#'
#' args2 <- lapply(paths, spk_odm)
#'
#' args2 |> purrr::walk(
#'   ~ processx::run(
#'     command = "docker",
#'     args = .x,
#'     echo = TRUE
#'   )
#' )
#' }
#'
#' @details
#' By default, this function generates both DTM and DSM outputs using the `--dtm` and `--dsm` flags.  `--cog` generation
#' appears to be corrupted by metadata writing so that is left for a seperate step.
#' Additional parameters can be passed through `params_add` as a character vector. When `interactive = TRUE`, the full
#' command including `docker` is returned as a single string for terminal use.
#' For more details on the steps and arguments, see the OpenDroneMap documentation:
#' \url{https://docs.opendronemap.org/arguments/}
#'
#'
#' @importFrom chk chk_string chk_dir chk_flag
#' @importFrom fs path_dir
#' @export
spk_odm <- function(path_project, params_default = c("--dtm", "--dsm", "--pc-quality", "low", "--dem-resolution", "10"), params_add = NULL, interactive = FALSE) {
  # Validate inputs
  chk::chk_string(path_project)
  chk::chk_dir(path_project)
  chk::chk_flag(interactive)
  if (!is.null(params_default)) {
    chk::chk_character(params_default)
  }
  if (!is.null(params_add)) {
    chk::chk_character(params_add)
  }

  # Extract directory components
  project_dir_stub <- fs::path_dir(path_project)
  dir_select <- basename(path_project)

  # Construct volume mapping
  volume_mapping <- paste0(project_dir_stub, ":/datasets")

  # Construct arguments
  args <- c(
    "run", "--rm",
    "-v", volume_mapping,
    "opendronemap/odm",
    "--project-path", "/datasets/",
    dir_select
  )

  # Add `-ti` if interactive
  if (interactive) {
    args <- c("docker", "run", "-ti", args[-1])
  }

  # Add opinionated parameters if provided
  if (!is.null(params_default)) {
    args <- c(args, params_default)
  }

  # Add additional parameters if provided
  if (!is.null(params_add)) {
    args <- c(args, params_add)
  }

  # Return as a single string if interactive
  if (interactive) {
    return(paste(args, collapse = " "))
  }

  args
}
