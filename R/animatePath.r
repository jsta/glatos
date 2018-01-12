#' Create an animated video of spatiotemporal path data
#' 
#' Create a set of frames (png image files) showing geographic location data
#' (e.g., detections of tagged fish or interpolated path data) at discrete 
#' points in time and stitch frames into a video animation (mp4 file).    
#' 
#' @param procObj A data frame created by \code{\link{interpolatePath}} 
#'   function.
#'   
#' @param recs A data frame containing at least four columns with 
#'   receiver 'lat', 'lon', 'deploy_timestamp', and 
#'   'recover_timestamp'. Default column names match GLATOS standard receiver 
#'   location file \cr(e.g., 'GLATOS_receiverLocations_yyyymmdd.csv'), but 
#'   column names can also be specified with \code{recColNames}.
#'   
#' @param outDir A character string with file path to directory where 
#'   individual frames for animations will be written.
#'   
#' @param background An optional object of class \code{SpatialPolygonsDataFrame} 
#'   to be used as background of each frame. Default is a simple polygon
#'   of the Great Lakes (\code{greatLakesPoly}) included in the 'glatos' 
#'   package.
#'   
#' @param backgroundYlim vector of two values specifying the min/max values 
#' 	 for y-scale of plot. Units are same as background argument.
#' 	 
#' @param backgroundXlim vector of two values specifying the min/max values 
#'   for x-scale of plot. Units are same as background argument.
#'   
#' @param ffmpeg A character string with path to install directory for ffmpeg. 
#'   This argument is only needed if ffmpeg has not been added to your 
#'   path variable on your computer.  For Windows machines, path must point 
#'   to ffmpeg.exe.  For example, 'c:\\path\\to\\ffmpeg\\bin\\ffmpeg.exe'
#'   
#' @param plot_control An optional data frame with four columns ('id', 'position_type', 
#'   'color', and 'marker') that specify the plot symbols and colors for 
#'   each animal and position type. See examples below for an example.
#' \itemize{
#'   \item \code{id} contains the unique identifier of individual animals and 
#'   	 corresponds to 'id' column in 'dtc'. 
#'   \item \code{position_type} indicates if the options should be applied to observed
#'     positions (detections; 'detected') or interpolated positions 
#'     ('interpolated').
#'   \item \code{color} contains the marker color to be plotted for each 
#'     animal and position type.  
#'   \item \code{marker} contains the marker style to be plotted for each
#'     animal and position type. Passed to \code{par()$pch}.
#'   \item \code{marker_cex} contains the marker size to be plotted for each
#'     animal and position type. Passed to \code{par()$cex}.
#'   \item \code{line_color} contains the line color. Passed to 
#'     \code{par()$col}.
#'   \item \code{line_width} contains the line width. Passed to 
#'     \code{par()$lwd}.
#' } 
#' 
#' @param procObjColNames A list with names of required columns in 
#'   \code{procObj}: 
#' \itemize{
#'   \item \code{animalCol} is a character string with the name of the column 
#' 		 containing the individual animal identifier.
#'	 \item \code{binCol} contains timestamps that define each frame.
#'	 \item \code{timestampCol} is a character string with the name of the column 
#' 		 containing datetime stamps for the detections (MUST be of class 
#'     'POSIXct').
#'	 \item \code{latitudeCol} is a character string with the name of the column
#'     containing latitude of the receiver.
#'	 \item \code{longitudeCol} is a character string with the name of the column
#'     containing longitude of the receiver.
#'	 \item \code{typeCol} is a character string with the name of the optional 
#'     column that identifies the type of record. Default is 'record_type'. 
#' }
#' 
#' @param recColNames A list with names of required columns in 
#'   \code{recs}: 
#' \itemize{
#'	 \item \code{latitudeCol} is a character string with the name of the column
#'     containing latitude of the receiver (typically, 'deploy_lat' for 
#'     GLATOS standard detection export data). 
#'	 \item \code{longitudeCol} is a character string with the name of the column
#'     containing longitude of the receiver (typically, 'deploy_long' for 
#'     GLATOS standard detection export data).
#'	 \item \code{deploy_timestampCol} is a character string with the name of 
#'     the column containing datetime stamps for receier deployments (MUST be 
#'     of class 'POSIXct'; typically, 'deploy_date_time' for GLATOS standard 
#'     detection export data). 
#'	 \item \code{recover_timestampCol} is a character string with the name of 
#'     the column containing datetime stamps for receier recover (MUST be of 
#'     class 'POSIXct'; typically, 'recover_date_time' for GLATOS standard 
#'     detection export data).
#' }
#' 
#' @param tail_dur contains the duration (in same units as \code{procObj$bin}; 
#'     see \code{\link{interpolatePath}}) of trailing points in each frame. 
#'     Default value is 0 (no trailing points). A value
#'     of \code{Inf} will show all points from start.
#'
#' @return Sequentially-numbered png files (one for each frame) and 
#'   one mp4 file will be written to \code{outDir}.
#' 
#' @author Todd Hayden
#'
#' @examples
#' library(glatos)
#' #example detection data
#' data(walleye_detections) 
#' head(walleye_detections)
#' 
#' #example receiver location data
#' data(recLoc_example) 
#' head(recLoc_example)
#' 
#' #call with defaults; linear interpolation
#' pos1 <- interpolatePath(walleye_detections)
#' 
#' #make sure ffmpeg is installed before calling animatePath
#' # and if you have not added path to 'ffmpeg.exe' to your Windows PATH 
#' # environment variable then you'll need to do that  
#' # or set path to 'ffmpeg.exe' using the 'ffmpeg' input argument
#' myDir <- paste0(getwd(),"/frames")
#' animatePath(pos1, recs=recLoc_example, outDir=myDir)
#' 
#' 
#' #add trailing points to include last 15 bins (in this case, days)
#' data(walleye_plotControl)
#' walleye_plotControl$line_color <- "grey60"
#' walleye_plotControl$line_width <- 5
#' animatePath(procObj = pos1, recs = recLoc_example, 
#'   plotControl = walleye_plotControl, outDir=myDir, tail_dur = 15)
#'  
#' @export

## library(glatos)
## # create procdata for development
## # example detection data
## ##
## data(walleye_detections) 
## dtc <- walleye_detections
## dtc <- dtc[, c("animal_id", "detection_timestamp_utc", "deploy_lat", "deploy_long")]
## data(greatLakesTrLayer)
## trans <- greatLakesTrLayer
## procObj <- interpolatePath(dtc, trans=greatLakesTrLayer)
## saveRDS(procObj, "procObj.rds")

## #development
library(glatos)

proc_obj <- readRDS("procObj.rds")
## # example receiver location data
data(recLoc_example) 
data(greatLakesPoly) 
background <- greatLakesPoly
background_ylim = c(41.48, 45.90)
background_xlim = c(-84.0, -79.5)
recs <- recLoc_example
int_time_stamp <- 86400
out_dir <- "~/Desktop/test"
ani_name <- "animation.mp4"
ffmpeg <- NA
animate = TRUE
#ffmpeg <- "~/Desktop"

# note: IF plot_control is provided, only fish provided in "animal_id" will be plotted.  Surpress plotting of animals by not including them in animal_id
 plot_control <- data.frame(animal_id = c(3, 10, 22, 23, 153, 167, 171, 234, 444, 479, 3, 10, 22, 23, 153, 167, 171, 234, 444, 479), type = c("real", "real", "real", "real", "real", "real", "real", "real", "real", "real", "inter", "inter", "inter", "inter", "inter", "inter", "inter", "inter", "inter", "inter"), color = c("pink", "pink", "pink", "pink", "pink", "pink", "pink", "pink", "pink", "pink", "red", "red", "red", "red", "red", "red", "red", "red", "red", "red"), marker = c(21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21), marker_cex = rep(1,20))
plot_control = NULL
###############

# ffmpeg = path to execute ffmpeg
# ani_out = path/file name of video.
# animate = TRUE (default) = make animated video, FALSE = no video
# frame_delete = TRUE = delete all frames after making animation

# tests

proc_obj <- proc_obj[animal_id == 23]

animatePath(proc_obj = proc_obj, recs = recs, plot_control = NULL, background = NULL,
            background_ylim = c(41.48, 45.9), background_xlim = c(-84, -79.5),
            ffmpeg = NA, int_time_stamp = 86400, ani_name = "animation.mp4",
            frame_delete = TRUE, animate = TRUE, out_dir = "~/Desktop/test")

animatePath(proc_obj = proc_obj, recs = recs, plot_control = NULL, background = NULL,
            background_ylim = c(41.48, 45.9), background_xlim = c(-84, -79.5),
            ffmpeg = NA, int_time_stamp = 86400, ani_name = "animation.mp4",
            frame_delete = TRUE, animate = TRUE, out_dir = "~/Desktop/test")





animatePath <- function(proc_obj, recs, plot_control = NULL, out_dir = getwd(), background = NULL,
                        background_ylim = c(41.48, 45.9),
                        background_xlim = c(-84, -79.5),
                        ffmpeg = NA,
                        ani_name = "animation.mp4", frame_delete = TRUE,
                        animate = TRUE ){
  setDT(procObj)
  setDT(recs)

  # try calling ffmpeg if animate = TRUE.
  # If animate = FALSE, video file is not produced and there is no need to check for package.
  if(animate == TRUE){
    cmd <- ifelse(grepl("ffmpeg.exe$",ffmpeg) | is.na(ffmpeg), ffmpeg,
                  paste0(ffmpeg,"\\ffmpeg.exe"))
    cmd <- ifelse(is.na(ffmpeg), 'ffmpeg', cmd)	
    ffVers <- suppressWarnings(system2(cmd, "-version", stdout=F)) #call ffmpeg
    if(ffVers == 127)
      stop(paste0('"ffmpeg.exe" was not found.\n',
                  'Ensure it is installed add added to system PATH variable\n',
                  "or specify path using input argument 'ffmpeg'\n\n",
                  'FFmpeg is available from:\n https://ffmpeg.org/'),
           call. = FALSE)

    mapmate <- any(installed.packages()[,1] == "mapmate")
    if(mapmate == FALSE) stop(
        paste0("mapmate package is not installed.\n",
               "see: https://github.com/leonswicz/mapmate\n",
               'install: devtools::install_github("leonawicz/mapmate")'),
        call. = FALSE)
  }

  # add colors and symbols to detections data frame
  if(!is.null(plot_control)){
    setDT(plot_control)
    proc_obj <- merge(proc_obj, plot_control, by.x=c("animal_id", "type"),
                     by.y=c("animal_id","type"))
    proc_obj <- proc_obj[!is.na(color)]
  } else {

    # otherwise, assign default colors and symbols
    proc_obj$color = 'black'
    proc_obj$marker = 21
    proc_obj$marker_cex = 1
  }

  #make output directory if it does not already exist
  if(!dir.exists(out_dir)) dir.create(out_dir)

  # this needs cleaned up...plot_bin can be swapped for bin_stamp???   
  proc_obj[, plot_bin := bin_stamp]

  # add bins to processed object for plotting
  proc_obj[, plot_bin := findInterval(bin_stamp, t_seq)]

  # create group identifier
  proc_obj[, grp := plot_bin]

  # remove receivers not recovered (records with NA in recover_date_time)
  setkey(recs, recover_date_time)
  recs <- recs[!J(NA_real_), c("station", "deploy_lat", "deploy_long",
                               "deploy_date_time", "recover_date_time")]

  # bin data by time interval and add to recs
  recs[, start := findInterval(deploy_date_time, t_seq)]
  recs[, end := findInterval(recover_date_time, t_seq)]

  # add clock for plot
  proc_obj[, clk := t_seq[plot_bin]]

  # determine leading zeros needed by ffmpeg and add as new column
  char <- paste0("%", 0, nchar(as.character(max(proc_obj$plot_bin))), "d")
  proc_obj[, f_name := paste0(sprintf(char, plot_bin), ".png")]

  if(is.null(background)) {
    data(greatLakesPoly) #example in glatos package
    background <- greatLakesPoly
  }
  
  cust_plot <- function(x){

    # extract receivers in the water during plot interval
    sub_recs <- recs[between(x$plot_bin[1], lower = recs$start, upper = recs$end)]

    # plot GL outline and movement points
    png(file.path(out_dir, x$f_name[1]), width = 3200, height = 2400,
        units = 'px', res = 300)

    # plot background image
    par(oma=c(0,0,0,0), mar=c(0,0,0,0))  #no margins

    # note call to plot with sp
    sp::plot(background, ylim = c(background_ylim), xlim = c(background_xlim),
             axes = FALSE, lwd = 2)

    # plot fish locations, receivers, clock
    points(x = sub_recs$deploy_long, y = sub_recs$deploy_lat, pch = 21, cex = 2,
           col = "tan2", bg = "tan2")
    text(x = -84.0, y = 42.5, as.Date(x$clk[1]), cex = 2.5)
    points(x = x$i_lon, y = x$i_lat, pch = x$marker, col = x$color,
           cex = x$marker_cex)
    dev.off()
  }

  grpn <- uniqueN(proc_obj$grp)
  pb <- txtProgressBar(min = 0, max = grpn, style = 3)

  setkey(proc_obj, grp)
  # create images
  proc_obj[, {setTxtProgressBar(pb, .GRP); cust_plot(x = .SD)},  by = grp,
          .SDcols = c("plot_bin", "clk", "i_lon", "i_lat", "marker", "color",
                      "marker_cex", "f_name")]
close(pb)
  
  if(animate == TRUE & frame_delete == TRUE){
out_dir <- "/home/thayden/Desktop/test"


mapmate::ffmpeg(dir = out_dir, pattern = paste0(char, ".png"),
                    output = ani_name, output_dir = out_dir, rate = "ntsc")
    unlink(file.path(outDir, unique(procObj$f_name)))
  } else {
    if(animate == TRUE & frame_delete == FALSE){
      mapmate::ffmpeg(dir = out_dir, pattern = paste0(char, ".png"),
                      output = ani_name, output_dir = out_dir, rate = "ntsc")
    } else {
      if(animate == FALSE){
        stop
      }
    }
  }
}
