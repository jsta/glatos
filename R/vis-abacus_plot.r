#' Plot detection locations of acoustic transmitters over time
#' 
#' Plot detection locations of acoustic transmitters over time.
#' 
#' @param det A \code{glatos_detections} object (e.g., produced by
#'   \link{read_glatos_detections}).
#'   
#'   \emph{OR} A data frame containing detection data with at least two columns, 
#'   one of which must be named 'detection_timestamp_utc', described below,  
#'   and another column containing a location grouping variable,
#'   whose name is specified by \code{location_col} (see below).
#'   
#'   The following column must appear in \code{det}: 
#'   \describe{
#'   \item{\code{detection_timestamp_utc}}{Detection timestamps; MUST be of 
#'   class POSIXct.}
#'   }
#'   
#' @param location_col A character string indicating the column name in
#'   \code{det} that will be used as the location grouping variable (e.g.
#'   "glatos_array"), in quotes.
#'   
#' @param locations An optional vector containing a list of locations
#'   \code{location_col} to show in the plot. Plot order corresponds to order
#'   in the vector (from bottom up). Should correspond to values in
#'   \code{location_col}, but can contain values that are not in the det
#'   data frame (i.e., can use this option to plot locations fish were
#'   not detected).
#'   
#' @param ylab A character string indicating the y-axis label that will appear 
#'   on the figure (default will match \code{location_col}).
#'   
#' @param pch A numeric value corresponding to the symbol to be used for
#'   plotting. See \url{https://www.statmethods.net/advgraphs/parameters.html}.
#'   
#' @param out_file An optional character string with the name (including 
#'   extension) of output image file to be created. File extension
#'   will determine type of file written. For example, \code{"abacus_plot.png"}
#'   will write a png file to the working directory. If \code{NULL} (default)
#'   then the plot will be printed to the default plot device.
#'   Supported extensions: png, jpeg, bmp, and tiff.
#'   
#' @param outFile Deprecated. Use \code{out_file} instead.
#'   
#' @param ... Other plotting arguments that pass to "plot" function (e.g., col,
#'   lwd, type).
#'   
#' @details NAs are not allowed in any of the two required columns.
#'   
#' @details The locations vector is used to control which locations will
#'   appear in the plot and in what order they will appear. If no locations
#'   vector is supplied, the function will plot only those locations that
#'   appear in the \code{det} data frame and the order of locations on the 
#'   y-axis will be alphebetical from top to bottom.
#'   
#' @details By default, the function does not distinguish detections from
#'   different transmitters and will therefore plot all transmitters the same
#'   color. If more than one fish is desired in a single plot, a vector of
#'   colors must be passed to the function using the 'col =' argument. The color
#'   vector must be the same length as the number of rows in the detections data
#'   frame or the colors will be recycled.
#'   
#' @details Plotting options (i.e., line width and color) can be changed using
#'   optional graphical parameters 
#'   \url{http://www.statmethods.net/advgraphs/parameters.html} that are passed
#'   to "segments" (see ?segments).
#'   
#' @return An image to the default plot device or a file containing the 
#' image if \code{out_file} is specified.
#'   
#' @author T. R. Binder, edited by A. Dini
#'   
#' @examples
#' #get path to example detection file
#' det_file <- system.file("extdata", "walleye_detections.csv",
#'  package = "glatos")
#' det <- read_glatos_detections(det_file)
#' 
#' #subset one transmitter
#' det2 <- det[det$animal_id == 153, ]
#' 	
#' #plot without control table and main tile and change color to red
#' abacus_plot(det, locations=NULL, 
#'   main = "TagID: 32054", col = "red")
#' 	
#' #example with locations specified
#' abacus_plot(det, locations=c("DRF", "DRL", "FMP", "MAU", "PRS", "RAR",
#'    "DRM", "FDT"), main = "TagID: 32054", col = "red")
#'
#' #plot with custom y-axis label and lines connecting symbols
#' abacus_plot(det, main = "TagID: 32054", type = "l",
#' 	 col = "red")
#'   
#' @export

abacus_plot <- function(det, location_col = 'glatos_array', 
  locations = NULL, ylab = NA, pch = NA, out_file = NULL, outFile = NULL, ...) {
  
  #check if outFile was given
  if(!is.null(outFile)){
    out_file <- outFile
    warning(paste0("Input argument 'outFile' is deprecated and will not be ",
                   "supported in the future. Use 'out_file' instead."), 
            call. = FALSE)
  }
  
  # Check that the specified columns appear in the detections data frame
  missingCols <- setdiff(c("detection_timestamp_utc", location_col), names(det))
  if (length(missingCols) > 0){
    stop(paste0("det is missing the following ",
      "column(s):\n", paste0("       '", missingCols, "'", collapse="\n")), 
      call. = FALSE)
  }
  
  # Rename column specified in location_col to "location"
  names(det)[which(names(det)==location_col)] = "location"
  
  # Check that timestamp is of class 'POSIXct'
  if(!('POSIXct' %in% class(det$detection_timestamp_utc))){
    stop(paste0("Column 'detection_timestamp_utc' in the det must be of class 'POSIXct'."),
      call. = FALSE)
  } 
  
  # Get output directory and check if exists
  if(!is.null(out_file)){
    outDir <- ifelse(dirname(out_file) == ".", getwd(), dirname(out_file)) 
    if(!dir.exists(outDir)) stop("Output directory '", outDir, 
      "' does not exist.", call. = FALSE)
  }
  
  # If locations not supplied, create one data frame with unique values
  # (ordered alphebetically from top to bottom) of location_col values with
  # plot order appended. Otherwise append a column of plot order to locations.
  if(is.null(locations)){
    locations_table <- data.frame(
      location = sort(unique(det$location), decreasing = TRUE), 
      y_order = 1:length(unique(det$location)), 
      stringsAsFactors = FALSE)
  } else {
    locations_table <- data.frame(
      location = locations, 
      y_order = 1:length(locations), 
      stringsAsFactors = FALSE)
  }
  
  #update Ylab value if NA
  if(is.na(ylab)){ 
    Ylab <- location_col
  }
  
  # Merge det and locations_table data frames
  # Keep only locations that appear in the locations_table data frame
  det <- merge(det, locations_table, by = "location", all.y = TRUE)
  
  #sort by timestamp
  det <- det[order(det$detection_timestamp_utc), ] 
  
  # Variable which scales the height of the y-axis depending on the number of 
  # labels to appear. 
  # Assumes 24 labels is the perfect spacing for height = 1000 px.
  pngHeight <- max((nrow(locations_table)/24)*1000, 500)
  
  # Calculate a y-axis label offset to accommodate grouping variables with 
  # different string lengths (e.g., "DRM" vs "DRM-001").
  YlabOffset <- (max(nchar(det$location)) - 3) / 3
  
  
  #get file extension
  file_type <- ifelse(is.null(out_file), NA, tools::file_ext(out_file))
  
  #check file extension is supported
  ext_supp <- c(NA, "png", "jpeg", "png", "bmp", "tiff")
  if(!(tolower(file_type) %in% ext_supp))
    stop(paste0("Image type '", file_type, "' is not supported."), 
      call. = FALSE)
  
  if(!is.na(file_type) & tolower(file_type) == 'png')
    png(out_file, height = pngHeight, width = 1000, pointsize = 22)
  if(!is.na(file_type) & tolower(file_type) == 'jpeg')
    jpeg(out_file, height = pngHeight, width = 1000, pointsize = 22)
  if(!is.na(file_type) & tolower(file_type) == 'bmp')
    bmp(out_file, height = pngHeight, width = 1000, pointsize = 22)
  if(!is.na(file_type) & tolower(file_type) == 'tiff')
    tiff(out_file, height = pngHeight, width = 1000, pointsize = 22)  
  
  
  # Set inner and outer margins
  par(mar = c(1, 1, 1.5, 2), oma = c(3, 4 + YlabOffset, 0, 0))
  
  # Plot detection data
  with(det, 
    plot(detection_timestamp_utc, y_order, 
      xlim = range(detection_timestamp_utc, na.rm = TRUE), 
      ylim = c(1,nrow(locations_table)), 
      pch = ifelse(is.na(pch), 16, pch), yaxt = "n", xaxt = "n", ylab = "", 
      xlab = "", ...))
  
  # Add custom axes
  axis(2, at = locations_table$y_order, 
    labels = locations_table$location, las = 1)
  xmaj <- seq(from = min(det$detection_timestamp_utc, na.rm = TRUE), 
    to = max(det$detection_timestamp_utc, na.rm = TRUE), length.out = 5)
  axis(1, at = xmaj, labels = format(xmaj, "%Y-%m-%d"), las = 1)
  
  # Add axes titles
  mtext("Date", side = 1, line = 2.2, cex = 1.2)
  mtext(Ylab, side = 2, line = 3.5 + YlabOffset, cex = 1.2)
  
  if(!is.na(file_type))	{
    dev.off()
    
    message(paste0("Output file is located in the following directory:\n", 
      outDir))	
  }
}