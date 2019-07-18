#' Convert detections and receiver metadata to a format that 
#' ATT (https://github.com/vinayudyawer/ATT) accepts.
#'
#' @param glatosObj a list from \code{read_glatos_detections}
#'
#' @param receiverObj a list from \code{read_glatos_receivers}
#'
#' @details This function takes 2 lists containing detection and
#' reciever data and transforms them into 3 \code{tibble} objects 
#' inside of a list. The input that AAT uses to get this data product
#' is located here: https://github.com/vinayudyawer/ATT/blob/master/README.md
#' and our mappings are found here: https://gitlab.oceantrack.org/GreatLakes/glatos/issues/83
#' in a comment by Ryan Gosse
#'
#' @author Ryan Gosse
#'
#' @return a list of 3 tibbles containing tag dectections, tag metadata, and
#' station metadata, to be injested by VTrack/ATT
#'
#' @examples
#'
#' #--------------------------------------------------
#' # EXAMPLE #1 - loading from the vignette data
#'
#' library(glatos)
#' wal_det_file <- system.file("extdata", "walleye_detections.csv",
#'      package = "glatos")
#' walleye_detections <- read_glatos_detections(wal_det_file) # load walleye data
#'
#' rec_file <- system.file("extdata", "sample_receivers.csv", 
#'      package = "glatos")
#' rcv <- read_glatos_receivers(rec_file) # load receiver data
#'
#' ATTData <- glatos_to_att(walleye_detections, rcv)
#' @export

glatos_to_att <- function(glatosObj, receiverObj) {
  
    tagMetadata <- unique(tibble( # Start building Tag.Metadata table
        Tag.ID=as.integer(glatosObj$animal_id),
        Transmitter=as.factor(concat_list_strings(glatosObj$transmitter_codespace, glatosObj$transmitter_id)),
        Common.Name=as.factor(glatosObj$common_name_e)
    ))
    
    tagMetadata <- unique(tagMetadata) # Cut out dupes
    
    nameLookup <- tibble( # Get all the unique common names
        Common.Name=unique(tagMetadata$Common.Name)
    )
    nameLookup <- mutate(nameLookup, # Add scinames to the name lookup
        Sci.Name=as.factor(map(nameLookup$Common.Name, query_worms_common))
    )
    tagMetadata <- left_join(tagMetadata, nameLookup) # Apply sci names to frame

    releaseData <- tibble( # Get the rest from glatosObj
        Tag.ID=as.integer(glatosObj$animal_id), 
        Tag.Project=as.factor(glatosObj$glatos_project_transmitter), 
        Release.Latitude=glatosObj$release_latitude, 
        Release.Longitude=glatosObj$release_longitude, 
        Release.Date=as.Date(glatosObj$utc_release_date_time),
        Sex=as.factor(glatosObj$sex)
    )

    releaseData <- mutate(releaseData, # Convert sex text and null missing columns
        Sex=as.factor(map(Sex, convert_sex)),
        Tag.Life=as.integer(NA),
        Tag.Status=as.factor(NA),
        Bio=as.factor(NA)
    ) 
    tagMetadata <- left_join(tagMetadata, releaseData) # Final version of Tag.Metadata

    glatosObj <- glatosObj %>%
        mutate(dummy=TRUE) %>%
        left_join(select(receiverObj %>% mutate(dummy=TRUE), glatos_array, station_no, deploy_lat, deploy_long, station, dummy, ins_model_no, ins_serial_no, deploy_date_time, recover_date_time)) %>%
        filter(detection_timestamp_utc >= deploy_date_time, detection_timestamp_utc <= recover_date_time) %>%
        mutate(ReceiverFull=concat_list_strings(ins_model_no, ins_serial_no)) %>%
        select(-dummy)

    detections <- tibble(
        Date.Time=glatosObj$detection_timestamp_utc,
        Transmitter=as.factor(concat_list_strings(glatosObj$transmitter_codespace, glatosObj$transmitter_id)),
        Station.Name=as.factor(glatosObj$station),
        Receiver=as.factor(glatosObj$ReceiverFull),
        Latitude=glatosObj$deploy_lat,
        Longitude=glatosObj$deploy_long,
        Sensor.Value=as.integer(glatosObj$sensor_value),
        Sensor.Unit=as.factor(glatosObj$sensor_unit)
    )

    stations <- tibble(
        Station.Name=as.factor(receiverObj$station),
        Receiver=as.factor(concat_list_strings(receiverObj$ins_model_no, receiverObj$ins_serial_no)),
        Installation=as.factor(NA),
        Receiver.Project=as.factor(receiverObj$glatos_project),
        Deployment.Date=receiverObj$deploy_date_time,
        Recovery.Date=receiverObj$recover_date_time,
        Station.Latitude=receiverObj$deploy_lat,
        Station.Longitude=receiverObj$deploy_long,
        Receiver.Status=as.factor(NA)
    )
    
    return(list(
        Tag.Detections=detections,
        Tag.Metadata=tagMetadata,
        Station.Information=stations
    ))
}


# Function for taking 2 lists of string of the same length and concatenating the columns, row by row.
concat_list_strings <- function(list1, list2, sep = "-") {
    if (length(list1) != length(list2)) {
        stop(sprintf("Lists are not the same size. %d != %d.", length(list1), length(list2)))
    }
    return (paste(list1, list2, sep = sep))
}

# Simple query to WoRMS based on the common name and returns the sci name
query_worms_common <- function(commonName) {

    url <- sprintf("http://www.marinespecies.org/rest/AphiaRecordsByVernacular/%s", commonName)
    tryCatch({
        payload <- fromJSON(url)
        return(payload$scientificname)
    }, error = function(e){
        stop(sprintf('Error in querying WoRMS, %s was probably not found.', commonName))
    })
}

# Convert the sex from 'F' and 'M' to 'FEMALE' and 'MALE'
convert_sex <- function(sex) {
    if (sex == "F") return("FEMALE")
    if (sex == "M") return("MALE")
    return(sex)
}
