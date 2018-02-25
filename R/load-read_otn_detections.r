#' Read data from a OTN detection file
#' 
#' Read data from a standard OTN detection (csv) file and return
#' a data.frame of class \code{glatos_detections}.
#'
#' @param det_file A character string with path and name of detection file in 
#'  OTN detection extract format (*.csv). If only file name is given, then the 
#'  file must be located in the working directory.
#'  
#' @details 
#' Data are loaded using \code{\link[data.table]{fread}} package and timestamps
#' are coerced to POSIXct using the \code{\link[fasttime]{fastPOSIXct}}. All
#' times must be in UTC timezone per GLATOS standard.
#' 
#' @details 
#' Column names are changed to match GLATOS standard columns when possible. 
#' Otherwise, OTN columns and column names are retained.
#' 
#' @return A data.frame of class \code{glatos_detections} that includes OTN 
#' columns that do not map directly to GLATOS columns. 
#'
#' @author A. Nunes, \email{anunes@dal.ca}
#'
#' @examples
#' #get path to example detection file
#' det_file <- system.file("extdata", "blue_shark_detections.csv",
#'                          package = "glatos")
#' det <- read_otn_detections(det_file)
#'
#' @export
read_otn_detections <- function(det_file) {
  col_classes <- otn_detection_schema$type
  timestamp_cols <- which(col_classes == "POSIXct")
  date_cols <- which(col_classes == "Date")
  col_classes[c(timestamp_cols, date_cols)] <- "character"
  
  #read data
  dtc <- data.table::fread(det_file, sep = ",", colClasses = col_classes,
                           na.strings = c("", "NA"))
  
  #coerce timestamps to POSIXct; note that with fastPOSIXct raw
  #  timestamp must be in UTC; and tz argument sets the tzone attr only
  for (j in timestamp_cols) data.table::set(dtc, j = j, 
                                            value = fasttime::fastPOSIXct(dtc[[j]], tz = "UTC"))
  #coerce dates to date
  for (j in date_cols) {
    data.table::set(dtc, j = j, value = ifelse(dtc[[j]] == "", NA, dtc[[j]]))
    data.table::set(dtc, j = j, value = as.Date(dtc[[j]]))
  }
  data.table::setnames(dtc, old=otn_detection_schema$name, new=otn_detection_schema$mapping)
  dtc <- glatos_detections(dtc)
  return(dtc)
}