#' Spatial Join with Optional Mask Filtering and Column Selection
#'
#' Joins a target [sf::sf] object with a mask [sf::sf] object using a specified spatial predicate.
#' Optional filtering and selection of columns from the mask can be applied.
#'
#' @param target_tbl [sf::sf] The target table to be spatially joined.
#' @param mask_tbl [character] or [sf::sf] The mask table name (if reading from `path_gpkg`) or an sf object.
#' @param target_col_return [character] A vector of target column names to retain. Use "*" to retain all.
#' @param mask_col_return [character] or [NULL] Optional. A vector of mask column names to retain. Default is `NULL`.
#' @param mask_col_filter [character] or [NULL] Optional. A single mask column name used for filtering rows.
#' @param mask_col_filter_values [character] or [NULL] Optional. Values to match (or exclude) in `mask_col_filter`.
#' @param mask_col_filter_values_negate [logical] Whether to exclude (`TRUE`) or include (`FALSE`) matching rows. Default is `FALSE`.
#' @param join_fun [function] Spatial predicate function from [sf::st_intersects()], [sf::st_within()], etc. Default is `sf::st_intersects`.
#' @param path_gpkg [character] or [NULL] Optional. Path to a GeoPackage to read `mask_tbl` from if not already an sf object.
#' @param collapse [logical] Whether to collapse results to one amalgamated row with multiple results when more than
#' one result is returned. Default is TRUE
#' @param target_col_collapse [character] or [NULL] Optional. A target column name to group by to facilitate collapsing the result.
#' @param ... Additional arguments passed to [sf::st_join()].
#'
#' @return A sf object with the result of the spatial join. If `target_col_return` is not "*", only selected columns are returned.
#'
#' @family vector
#'
#' @importFrom sf st_join st_read
#' @importFrom dplyr filter select all_of group_by summarise across
#' @importFrom chk chk_s3_class chk_string chk_flag
#' @importFrom cli cli_warn
#' @export
spk_join <- function(
    target_tbl,
    mask_tbl,
    target_col_return = '*',
    mask_col_return = NULL,
    mask_col_filter = NULL,
    mask_col_filter_values = NULL,
    mask_col_filter_values_negate = FALSE,
    join_fun = sf::st_intersects,
    path_gpkg = NULL,
    collapse = FALSE,
    target_col_collapse = NULL,
    ...
) {
  # read mask_tbl from gpkg if path provided
  if (!is.null(path_gpkg)) {
    mask_tbl <- sf::st_read(path_gpkg, layer = mask_tbl, quiet = TRUE)
  }

  chk::chk_s3_class(target_tbl, "sf")
  chk::chk_s3_class(mask_tbl, "sf")
  if (collapse) {
    chk::chk_not_null(target_col_collapse)
  }

  # filter mask if requested
  if (!is.null(mask_col_filter) && !is.null(mask_col_filter_values)) {
    mask_tbl <- dplyr::filter(
      mask_tbl,
      if (mask_col_filter_values_negate) {
        !.data[[mask_col_filter]] %in% mask_col_filter_values
      } else {
        .data[[mask_col_filter]] %in% mask_col_filter_values
      }
    )
  }

  if (!is.null(mask_col_return)) {
    mask_tbl <- dplyr::select(mask_tbl, dplyr::all_of(mask_col_return))
  }

  result <- sf::st_join(
    target_tbl,
    mask_tbl,
    left = TRUE,
    join = join_fun,
    ...
  )

  if (!identical(target_col_return, "*")) {
    result <- dplyr::select(result, dplyr::all_of(c(target_col_return, mask_col_return)))
  }

  if (collapse && nrow(result) > nrow(target_tbl)) {
    orig_type <- vapply(mask_col_return, function(col) typeof(mask_tbl[[col]]), FUN.VALUE = character(1))

    result <- result |>
      dplyr::group_by(across(all_of(target_col_collapse))) |>
      dplyr::summarise(
        dplyr::across(dplyr::all_of(mask_col_return), ~ toString(na.omit(unique(.x)))),
        .groups = "drop"
      )

    new_type <- vapply(mask_col_return, function(col) typeof(result[[col]]), FUN.VALUE = character(1))

    changed <- orig_type != new_type
    if (any(changed)) {
      changed_details <- paste0(
        mask_col_return[changed], ": ", orig_type[changed], " to ", new_type[changed]
      )
      cli::cli_warn("The following columns changed type after collapsing:\n{.val {changed_details}}")
    }
  }

  return(result)
}
