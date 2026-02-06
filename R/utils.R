# Global variable declarations for R CMD check
# These are column names used in NSE (non-standard evaluation) contexts
utils::globalVariables(c(
  ".data",
  "driver",
  "layer_name",
  "name",
  "time_exported"
))

#' @importFrom stats setNames
#' @keywords internal
NULL
