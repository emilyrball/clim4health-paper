# -----------------------------------------------------------------------------
# Global Health Resilience (GHR)
# Barcelona Supercomputing Center (BSC-CNS)
#
# Script Name: 00_utils.R
# Description: This script contains the functions that are used in the rest of
# the workflow. It is sourced from different scripts in the pipeline.
#
# Author(s): Emily Ball
# Date created: 2026-04-13
# Last updated: 2026-04-13
# Environment: local
# Requirements: Please see R version and dependencies in the repo README.
# ------------------------------------------------------------------------------

# Section 1 ----

# Calculate relative humidity from temperature and dew point temperature
rel_hum <- function(tas, tdps) {
  # Check class type
  if (!inherits(tas, "s2dv_cube") || !inherits(tdps, "s2dv_cube")){
    stop("'c4h_rel_hum' only accepts s2dv_cube objects as input.")
  }

  # Define constants
  b <- 17.625
  c <- 243.04

  # Initialize s2dv_cube for output
  hurs <- tas

  hurs$data <- 100 * exp(b * c * (tdps$data - tas$data) /
                           ((c + tdps$data) * (c + tas$data)))
  hurs$attrs$Variable$metadata[["rel_hum"]]$units <- "percent"

  return(hurs)

}