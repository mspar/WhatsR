#' @title Visualize Smilies used in WhatsApp chatlogs
#' @description Plots the smilies used in WhatsApp chatlogs
#' @param data A WhatsApp chatlog that was parsed with \code{\link[WhatsR]{parse_chat}}.
#' @param names A vector of author names that the plots will be restricted to.
#' @param names.col A column indicated by a string that should be accessed to determine the names. Only needs to be changed when \code{\link[WhatsR]{parse_chat}} used the parameter anon = "add" and the column "Anonymous" should be used. Default is "Sender".
#' @param starttime Datetime that is used as the minimum boundary for exclusion. Is parsed with \code{\link[anytime]{anytime}}. Standard format is "yyyy-mm-dd hh:mm".
#' @param endtime Datetime that is used as the maximum boundary for exclusion. Is parsed with \code{\link[anytime]{anytime}}. Standard format is "yyyy-mm-dd hh:mm".
#' @param min.occur The minimum number of occurrences a smiley has to have to be included in the visualization. Default is 1.
#' @param return.data If TRUE, returns a data frame of LatLon coordinates extracted from the chat for more elaborate plotting. Default is FALSE.
#' @param SmilieVec A vector of smilies that the visualizations will be restricted to.
#' @param plot The type of plot that should be outputted. Options include "heatmap", "cumsum", "bar" and "splitbar".
#' @param excludeSM If TRUE, excludes the WhatsApp system messages from the descriptive statistics. Default is FALSE.
#' @import ggplot2
#' @importFrom anytime anytime
#' @export
#' @return Plots for distribution of smilies in WhatsApp chats
#' @examples
#' data <- readRDS(system.file("ParsedWhatsAppChat.rds", package = "WhatsR"))
#' plot_smilies(data)
# Visualizing sent Links
plot_smilies <- function(data,
                         names = "all",
                         names.col = "Sender",
                         starttime = anytime("1960-01-01 00:00"),
                         endtime = Sys.time(),
                         min.occur = 1,
                         return.data = FALSE,
                         SmilieVec = "all",
                         plot = "bar",
                         excludeSM = FALSE) {


  # catching bad params
  # start- and endtime are POSIXct
  if (is(starttime, "POSIXct") == F) stop("starttime has to be of class POSIXct.")
  if (is(endtime, "POSIXct") == F) stop("endtime has to be of class POSIXct.")
  # names.col must be in preset options
  if (any(!names.col %in% c("Sender", "Anonymous"))) stop("names.col has to be either Sender or Anonymous.")
  # names in data or all names (Sender or Anonymous)
  if(names.col == "Sender"){
    if (!("all" %in% names) & any(!names %in% data$Sender)) stop("names has to either be \"all\" or a vector of names to include.")}
  else{
    if(!("all" %in% names) & any(!names %in% data$Anonymous)) stop("names has to either be \"all\" or a vector of names to include.")}
  # min.occur must be >= 1
  if (min.occur < 1) stop("Please provide a min.occur of >= 1.")
  # return.data must be bool
  if (!is.logical(return.data)) stop("return.data has to be either TRUE or FALSE.")
  # SmilieVec must be in data
  if (!("all" %in% SmilieVec) & any(!SmilieVec %in% data$Smilies)) stop("SmilieVec has to either be \"all\" or a vector of emojis to include.")
  # plot must be one of the the preset options
  if (any(!plot %in% c("heatmap", "cumsum", "bar", "splitbar"))) stop("The plot type has to be heatmap, cumsum, bar or splitbar.")
  # excludeSM must be bool
  if (!is.logical(excludeSM)) stop("excludeSM has to be either TRUE or FALSE.")

  #if names.col == "Anonymous", rename to Sender and rename Sender to placeholder
  if(names.col == "Anonymous"){
    colnames(data)[colnames(data) == "Sender"] <- "Placeholder"
    colnames(data)[colnames(data) == "Anonymous"] <- "Sender"
  }

  # First of all, we assign local variable with NULL to prevent package build error: https://www.r-bloggers.com/no-visible-binding-for-global-variable/
  day <- hour <- n <- `Number of Smilies` <- ave <- total <- Var1 <- Freq <- n <- DateTime <- Total <- Sender <- Smilies <- Amount <- NULL

  # setting starttime
  if (starttime == anytime("1960-01-01 00:00")) {
    starttime <- min(data$DateTime)
  } else {
    starttime <- anytime(starttime, asUTC = TRUE)
  }

  # setting endtime
  if (difftime(Sys.time(), endtime, units = "min") < 1) {
    endtime <- max(data$DateTime)
  } else {
    endtime <- anytime(endtime, asUTC = TRUE)
  }

  # setting names argument
  if (length(names) == 1 && names == "all") {
    if (excludeSM == TRUE) {
      # All names in the dataframe except System Messages
      names <- unique(data$Sender)[unique(data$Sender) != "WhatsApp System Message"]

      # dropping empty levels
      if (is.factor(names)) {
        names <- droplevels(names)
      }
    } else {
      # including system messages
      names <- unique(data$Sender)
    }
  }

  # limiting data to time and namescope
  data <- data[is.element(data$Sender, names) & data$DateTime >= starttime & data$DateTime <= endtime, ]

  # This tells us if at least one link is present (if it's TRUE then there's at least one smiley)
  SmiliesPresent <- !sapply(sapply(data$Smilies, is.na), sum)

  # This tells us how many elements are in each list element (includes NA aswell)
  NoElements <- lengths(data$Smilies)

  # We take the New counter and set it to zero where-ever no smilies are present
  NoElements[SmiliesPresent == FALSE] <- 0

  # Smilies
  UnlistedSmilies <- unlist(data$Smilies)
  NewSmilies <- UnlistedSmilies[!is.na(UnlistedSmilies)]

  # Senders
  NewSender <- list()

  for (i in seq_along(data$Sender)) {
    NewSender[[i]] <- rep(data$Sender[i], NoElements[i])
  }

  NewSender <- unlist(NewSender)

  # Rename Sender and Anonymous columns again to what they were initially
  if(names.col == "Anonymous"){
    colnames(data)[colnames(data) == "Sender"] <- "Anonymous"
    colnames(data)[colnames(data) == "Placeholder"] <- "Sender"
  }

  # New Dates
  NewDates <- list()

  for (i in seq_along(data$DateTime)) {
    NewDates[[i]] <- rep(data$DateTime[i], NoElements[i])
  }

  NewDates <- as.POSIXct(unlist(NewDates), origin = "1970-01-01")

  # pasting together
  options(stringsAsFactors = FALSE)
  NewFrame <- cbind.data.frame(NewDates, NewSender, NewSmilies)

  # creating time data
  NewFrame$hour <- as.POSIXlt(NewFrame$NewDates)$hour
  NewFrame$year <- as.POSIXlt(NewFrame$NewDates)$year + 1900
  NewFrame$day <- weekdays(as.POSIXlt(NewFrame$NewDates), abbreviate = FALSE)

  # setting correct SmilieVec
  if (length(SmilieVec) == 1 && SmilieVec == "all") {
    SmilieVec <- unique(NewSmilies)
  }

  # restricting to SmilieVec range
  NewFrame <- NewFrame[is.element(NewFrame$NewSmilies, SmilieVec), ]

  if (dim(NewFrame)[1] == 0) {
    # exit
    warning("No Smilie defined by SmilieVec is contained in the chat")
    stop()
  }

  if (plot == "heatmap") {
    # shaping dataframe
    helperframe2 <- NewFrame %>%
      group_by(day, hour) %>%
      summarise("Number of Smilies" = n())

    # factor ordering
    weekdays <- rev(c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"))

    # transalte to english for better compatibility
    helperframe2$day <- mgsub(helperframe2$day,
      pattern = c("Sonntag", "Samstag", "Freitag", "Donnerstag", "Mittwoch", "Dienstag", "Montag"),
      replacement = weekdays
    )

    helperframe2$day <- as.factor(helperframe2$day)

    if (sum(weekdays %in% levels(helperframe2$day)) == 7) {
      helperframe2$day <- factor(helperframe2$day, levels = weekdays)
    } else {
      helperframe2$day <- factor(helperframe2$day, c(levels(helperframe2$day), weekdays[!weekdays %in% levels(helperframe2$day)]))
      helperframe2$day <- factor(helperframe2$day, levels = weekdays)
    }

    # plotting Heatmap
    out <- ggplot(helperframe2, aes(hour, day)) +
      theme_minimal() +
      geom_tile(aes(fill = `Number of Smilies`), colour = "black") +
      labs(
        title = "Smilies by Weekday and Hour",
        subtitle = paste(starttime, " - ", endtime),
        x = "",
        y = ""
      ) +
      scale_fill_distiller(palette = "YlGnBu", direction = 1) +
      scale_y_discrete(drop = FALSE) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 90, hjust = 1),
        axis.ticks.x = element_blank(),
        legend.position = "bottom",
        legend.key.width = unit(2, "cm"),
        panel.grid = element_blank()
      ) +
      coord_equal() +
      scale_x_continuous(
        breaks = seq(-0.5, 23.5, 1),
        limits = c(-0.5, 23.5),
        labels = c(
          "00:00",
          "01:00",
          "02:00",
          "03:00",
          "04:00",
          "05:00",
          "06:00",
          "07:00",
          "08:00",
          "09:00",
          "10:00",
          "11:00",
          "12:00",
          "13:00",
          "14:00",
          "15:00",
          "16:00",
          "17:00",
          "18:00",
          "19:00",
          "20:00",
          "21:00",
          "22:00",
          "23:00",
          "24:00"
        )
      )


    if (return.data == TRUE) {
      # returning
      return(as.data.frame(helperframe2))
    } else {
      return(out)
    }
  }


  if (plot == "cumsum") {
    # cumulative number of links per sender
    NewFrame$counter <- rep(1, length(NewFrame$NewSmilies))
    NewFrame$total <- ave(NewFrame$counter, NewFrame$NewSender, FUN = cumsum)

    # setting names in dataframe
    names(NewFrame) <- c("DateTime", "Sender", "Smilies", "Hour", "Year", "Day", "Counter", "Total")

    # constructing graph
    out <- ggplot(NewFrame, aes(x = DateTime, y = Total, color = Sender)) +
      theme_minimal() +
      geom_line() +
      geom_point() +
      labs(
        title = "Cumulative number of Smilies sent",
        subtitle = paste(starttime, " - ", endtime)
      ) +
      theme(axis.text.x = element_text(angle = 90)) +
      xlab("Time") +
      ylab("Total Smilies Sent") +
      theme(legend.title = element_text("Smilies"))

    # printing plot
    print(out)

    if (return.data == TRUE) {
      # returning
      return(as.data.frame(NewFrame))
    } else {
      return(out)
    }
  }

  if (plot == "bar") {
    # Converting to dataframe to make it usable by ggplot
    df <- as.data.frame(sort(table(NewFrame$NewSmilies), decreasing = TRUE))

    # setting names in dataframe
    names(df) <- c("Smilies", "Freq")

    # Visualizig the distribution ofsmilies
    out <- ggplot(df[df$Freq >= min.occur, ], aes(x = Smilies, y = Freq, fill = Smilies)) +
      theme_minimal() +
      geom_bar(stat = "identity") +
      labs(
        title = "Distribution of sent Smilies",
        subtitle = paste(starttime, " - ", endtime),
        x = "Smilies",
        y = "Frequency"
      ) +
      theme(axis.text.x = element_text(angle = 270, hjust = 0.95, vjust = 0.2)) +
      guides(color = guide_legend(title = "Smilies")) +
      scale_color_discrete(name = "Smilies")

    # printing
    print(out)

    # return data
    if (return.data == TRUE) {
      # returning
      return(as.data.frame(df))
    } else {
      return(out)
    }
  }

  if (plot == "splitbar") {
    ## Summarize per Sender who often each domain was sent
    SumFrame <- group_by(NewFrame, NewSender, NewSmilies) %>% summarise(n = n())
    SumFrame <- SumFrame[SumFrame$n >= min.occur, ]

    # setting names in dataframe
    names(SumFrame) <- c("Sender", "Smilies", "Amount")

    # building graph object
    out <- ggplot(SumFrame, aes(x = Sender, y = Amount, fill = Smilies)) +
      theme_minimal() +
      geom_bar(stat = "identity", position = position_dodge()) +
      labs(
        title = "Smilies sent per Person",
        subtitle = paste(starttime, " - ", endtime),
        x = "Sender",
        y = "Frequency"
      )

    # printing
    print(out)

    # return data
    if (return.data == TRUE) {
      # returning
      return(as.data.frame(SumFrame))
    } else {
      return(out)
    }
  }
}
