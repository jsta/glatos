#' @title Simulate detection of transmitter signals in a receiver network
#' 
#' @description
#' Simulates detection of transmitter signals in a receiver network based on
#'   detection range curve (detection probability as a function of distance),
#'   location of transmitter, and location of receivers.
#'
#' @param trnsLoc A three-column data frame with locations (numeric columns 
#'   named 'x' and 'y') and timestamps (numeric or POSIXct column named 'et')
#'   where signals were transmitted.
#'   
#' @param recLoc A two-column data frame with receiver locations (numeric 
#'   columns named 'x' and 'y')
#'   
#' @param detRngFun A function that defines detection range curve;
#'   must accept a numeric vector of distances and return a numeric vector of 
#'   detection probabilities at each distance.
#'
#' @details
#' Distances between each signal transmission location and receiver are 
#' calculated using pythagorean theorem. The probability of detecting each 
#' signal on each receiver is determined from the detection range curve. 
#' Detection of each signal on each receiver is determined stochastically by 
#' draws from a Bernoulli distribution with probability p (detection prob).  
#'  
#' This function was written to be used along with 
#'   \code{\link{transmit_along_path}}.
#' 
#' @return A data frame containing:
#' \item{trns_id}{Unique signal transmission ID}
#' \item{recv_id}{Unique receiver ID}
#' \item{recv_x}{Receiver x coordinate}
#' \item{recv_y}{Receiver y coordinate}
#' \item{trns_x}{Transmitter x coordinate}
#' \item{trns_y}{Transmitter y coordinate}
#' \item{etime}{Elapsed time}
#'
#' @seealso \code{\link{transmit_along_path}} to simulate transmissions along a 
#' path (i.e., create \code{trnsLoc}).
#'
#' @author C. Holbrook (cholbrook@usgs.gov) 
#'
#' @examples
#' #make a simple path in polygon
#' mypath <- crw_in_polygon(data.frame(x = c(0, 0, 1000, 1000), 
#'   y = c(0, 1000, 1000, 0)), stepLen=100, nsteps=50)
#' plot(mypath,type='l',xlim=c(0,1000),ylim=c(0,1000)) #view path
#' 
#' #add receivers
#' recs <- expand.grid(c(250,750),c(250,750))
#' names(recs) <- c("x","y") #needed by detect_transmissions
#' points(recs, pch=15, col="blue")
#' 
#' #simulate tag transmissions
#' mytrns <- transmit_along_path(mypath,vel=2.0,delayRng=c(60,180),burstDur=5.0)
#' points(mytrns,pch=21) #add to plot
#' 
#' #Define detection range function (to pass as detRngFun) 
#' # that returns detection probability for given distance
#' # assume logistic form of detection range curve where 
#' #   dm = distance in meters
#' #   b = intercept and slope
#' pdrf <- function(dm, b=c(0.5, -1/120)){
#'   p <- 1/(1+exp(-(b[1]+b[2]*dm)))
#'   return(p)
#' }
#' pdrf(c(100,200,300,400,500)) #view detection probs. at some distances
#' 
#' #simulate detection
#' mydtc <- detect_transmissions(trnsLoc=mytrns, recLoc=recs, detRngFun=pdrf)
#' #view transmissions that were detected
#' points(trns_y~trns_x, data=mydtc,pch=21, bg="red")
#'
#' @export
detect_transmissions <- function(trnsLoc=NA,recLoc=NA,detRngFun=NA){
	 
  #check names of trnsLoc columns
  missingCols <- setdiff(c("x","y","et"),names(trnsLoc))
  if(length(missingCols) > 0) stop(paste0("'trnsLoc' must contain the ",
    "following columns: \n",paste(missingCols,collapse="\n")))
  
  #check names of recLoc columns
  missingCols <- setdiff(c("x","y"),names(recLoc))
  if(length(missingCols) > 0) stop(paste0("'recLoc' must contain the ",
    "following columns: \n",paste(missingCols,collapse="\n")))
  
  
	 #preallocate detection data frame
	 dtc <- data.frame(
          trns_id = NA,
          recv_id = NA,
          recv_x = NA,
          recv_y = NA,
          trns_x = NA,
          trns_y = NA,
          etime = NA)[0,]
	 
	 #loop through receivers (because should be much smaller than transmissions)
	 for(g in 1:nrow(recLoc)){
		#initialize progress bar
	     if(g==1)  pb <- txtProgressBar(min=0,max=nrow(recLoc),style=3)
	  
	    #distance between gth receiver and each transmission
	    distM.g <- sqrt((trnsLoc$x-recLoc$x[g])^2 +
                    (trnsLoc$y-recLoc$y[g])^2)
        detP.g <- detRngFun(distM.g) #calculate probability of detection
        #simulate detection
        succ.g <- as.logical(rbinom(length(detP.g), 1, detP.g)) 
	 
	    #output detection data
      if(sum(succ.g) > 0){
		  dtc.g <- data.frame(
			  trns_id = which(succ.g),
			  recv_id = g,
			  recv_x = recLoc$x[g],
			  recv_y = recLoc$y[g],
			  trns_x = trnsLoc$x[succ.g],
			  trns_y = trnsLoc$y[succ.g],
			  etime = trnsLoc$et[succ.g])
		 
		  dtc <- rbind(dtc,dtc.g) #append
	  } # end if
	 
		#update progress bar
		info <- sprintf("%d%% done", round(g/nrow(recLoc)*100))
		setTxtProgressBar(pb, g)
		if(g==nrow(recLoc)) close(pb)
	 } #end g
  dtc <- dtc[order(dtc$etime),]#sort by time	 
             
  return(dtc)
}