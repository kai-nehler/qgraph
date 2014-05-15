## Automatically computes a correlation matrix:

cor_auto <- function(
  data, # A data frame
  select, # Columns to select
  detectOrdinal = TRUE, # Detect ordinal variables
  ordinalLevelMax = 5 # Maximum amount of levels to be classified as ordinal
  )
{
  # Check for data frame:
  if (!is.data.frame(data))
  {
    data <- as.data.frame(data)
  }
  
  # Select columns:
  if (!missing(select))
  {
    data <- subset(data, select = select)
  }
  
  # Remove factors:
  Factors <- sapply(data,is,"factor") & !sapply(data,is,"ordered")
  if (any(Factors))
  {
    message(paste("Removing factor variables:",paste(names(data)[Factors], collapse = "; ")))
    data <- data[,!Factors]
  }
  
  # Detect ordinal:
  Numerics <- which(sapply(data,is,"numeric") | sapply(data,is,"integer"))
  if (detectOrdinal & length(Numerics) > 0)
  {
    isOrd <- sapply(Numerics, function(i) {
      isInt <- is.integer(data[,i]) | all(data[,i] %% 1 == 0)
      nLevel <- length(unique(data[,i]))
      return(isInt & nLevel <= ordinalLevelMax)
    } )
    
    if (any(isOrd))
    {
      message(paste("Variables detected as ordinal:",paste(names(data)[Numerics][isOrd], collapse = "; ")))
      
      for (i in Numerics[isOrd])
      {
        data[,i] <- ordered(data[,i])
      } 
    }
    
  }
  

  ### START COMPUTING CORRELATIONS ###
  # IF ALL NUMERIC OR INTEGER, NONPARANORMAL SKEPTIC:
  if (all(sapply(data,is,"numeric") | sapply(data,is,"integer") ))
  {
    message("All variables detected to be continuous, computing nonparanormal skeptic!")
    
    for (i in seq_len(ncol(data))) data[,i] <- as.numeric(data[,i])
    CorMat <- huge.npn(data, "skeptic")
    return(CorMat)
  }
  
  ## If all ordinal, do tetrachoric or polychoric:
  if (all(sapply(data,is,"ordered")))
  {
    nLevel <- sapply(data,nlevels)
    
    # Tetrachoric:
    if (all(nLevel == 2))
    {
      message("Binary data detected, computing tetrachoric correlations!")
      for (i in seq_len(ncol(data))) data[,i] <- as.numeric(data[,i])
      res <- tetrachoric(as.matrix(data))
      CorMat <- as.matrix(res$rho)
      attr(CorMat, "thresholds") <- res$tau
      return(CorMat)
      
    } else {
      message("Polytomous data detected, computing polychoric correlations!")
      for (i in seq_len(ncol(data))) data[,i] <- as.numeric(data[,i])
      res <- polychoric(as.matrix(data))
      CorMat <- as.matrix(res$rho)
      attr(CorMat, "thresholds") <- res$tau
      return(CorMat)
    }
    
  } 
  
  # Else shared data detected, use muthen1984 from lavaan:
  message("Both continuous and ordinal data detected, using muthen1984 from Lavaan package!")
  ov.names <- names(data)
  ov.types <- lavaan:::lav_dataframe_check_vartype(data, ov.names=ov.names)
  ov.levels <- sapply(lapply(data, levels), length)
  mutRes <- lavaan:::muthen1984(data, ov.names, ov.types, ov.levels)
  
  CorMat <- mutRes$COR
  attr(CorMat,"thresholds") <- mutRes$TH
  return(CorMat)
}