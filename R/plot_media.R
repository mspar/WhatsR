#' @title Visualizing media files in WhatsApp chatlogs
#' @description Creates a list of basic information about a single WhatsApp chatlog
#' @param data A WhatsApp chatlog that was parsed with \code{\link[WhatsR]{parse_chat}}.
#' @param names A vector of author names that the plots will be restricted to.
#' @param names.col A column indicated by a string that should be accessed to determine the names. Only needs to be changed when \code{\link[WhatsR]{parse_chat}} used the parameter anon = "add" and the column "Anonymous" should be used. Default is "Sender".
#' @param starttime Datetime that is used as the minimum boundary for exclusion. Is parsed with \code{\link[anytime]{anytime}}. Standard format is "yyyy-mm-dd hh:mm".
#' @param endtime Datetime that is used as the maximum boundary for exclusion. Is parsed with \code{\link[anytime]{anytime}}. Standard format is "yyyy-mm-dd hh:mm".
#' @param use.type If TRUE, shortens sent files to file types.
#' @param min.occur The minimum number of occurrences a media type has to have to be included in the visualization. Default is 1.
#' @param return.data If TRUE, returns the subsetted data frame. Default is FALSE.
#' @param MediaVec A vector of media types that the visualizations will be restricted to.
#' @param plot The type of plot that should be outputted. Options include "heatmap", "cumsum", "bar" and "splitbar".
#' @param excludeSM If TRUE, excludes the WhatsApp system messages from the descriptive statistics. Default is FALSE.
#' @import ggplot2
#' @importFrom anytime anytime
#' @importFrom dplyr %>%
#' @importFrom dplyr group_by
#' @importFrom dplyr summarise
#' @importFrom stringi stri_extract_all
#' @export
#' @return Plots and/or the subsetted data frame based on author names, datetime and emoji occurrence
#' @examples
#' data <- readRDS(system.file("ParsedWhatsAppChat.rds", package = "WhatsR"))
#' plot_media(data, plot = "heatmap")
# Visualizing sent Media files
plot_media <- function(data,
                       names = "all",
                       names.col = "Sender",
                       starttime = anytime("1960-01-01 00:00"),
                       endtime = Sys.time(),
                       use.type = TRUE,
                       min.occur = 1,
                       return.data = FALSE,
                       MediaVec = "all",
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
  # MediaVec must be in data
  if (!("all" %in% MediaVec) & any(!MediaVec %in% data$Media)) stop("MediaVec has to either be \"all\" or a vector of emojis to include.")
  # plot must be one of the the preset options
  if (any(!plot %in% c("heatmap", "cumsum", "bar", "splitbar"))) stop("The plot type has to be heatmap, cumsum, bar or splitbar.")
  # excludeSM must be bool
  if (!is.logical(excludeSM)) stop("excludeSM has to be either TRUE or FALSE.")
  # use.type must be bool
  if (!is.logical(use.type)) stop("use.type has to be either TRUE or FALSE.")

  #if names.col == "Anonymous", rename to Sender and rename Sender to placeholder
  if(names.col == "Anonymous"){
  colnames(data)[colnames(data) == "Sender"] <- "Placeholder"
  colnames(data)[colnames(data) == "Anonymous"] <- "Sender"
  }

  # muting useless dplyr message
  defaultW <- getOption("warn")
  options(warn = -1)

  # First of all, we assign local variables with NULL to prevent package build error: https://www.r-bloggers.com/no-visible-binding-for-global-variable/
  Dates <- Sender <- Media <- Frequency <- day <- hour <- n <- `Number of Media files` <- ave <- total <- Var1 <- Freq.Freq <- n <- NULL

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

  # This tells us if at least one media file is present (if it's TRUE then theres at least one media file)
  MediaPresent <- !sapply(sapply(data$Media, is.na), sum)

  # This tells us how many elements are in each list element (includes NA aswell)
  NoElements <- lengths(data$Media)

  # We take the New counter and set it to zero where-ever no media files are present
  NoElements[MediaPresent == FALSE] <- 0

  # Media
  UnlistedMedia <- unlist(data$Media)
  NewMedia <- UnlistedMedia[!is.na(UnlistedMedia)]

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
  NewFrame <- cbind.data.frame(NewDates, NewSender, NewMedia)

  # creating time data
  NewFrame$hour <- as.POSIXlt(NewFrame$NewDates)$hour
  NewFrame$year <- as.POSIXlt(NewFrame$NewDates)$year + 1900
  NewFrame$day <- weekdays(as.POSIXlt(NewFrame$NewDates), abbreviate = FALSE)

  # setting correct MediaVec
  if (length(MediaVec) == 1 && MediaVec == "all") {
    MediaVec <- unique(NewMedia)
  }

  # shorten media files to filetypes
  if (use.type == TRUE) {
    # function for shortening filenames to filetypes
    shortener <- function(x) {
      stri_extract_all(unlist(x), regex = "[^.]+$", simplify = FALSE)
    }

    NewFrame$NewMedia <- trimws(unlist(shortener(NewFrame$NewMedia)))
    MediaVec <- trimws(unlist(shortener(MediaVec)))
  } else {}

  # restricting to MediaVec range
  NewFrame <- NewFrame[is.element(NewFrame$NewMedia, MediaVec), ]

  if (dim(NewFrame)[1] == 0) {
    # exit
    warning("No media elements defined by MediaVec are contained in the chat")
    stop()
  }

  if (plot == "heatmap") {
    # shaping dataframe
    helperframe2 <- NewFrame %>%
      group_by(day, hour) %>%
      summarise("Number of Media files" = n())

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

    # formatting helperframe
    # helperframe2$hour <- factor(helperframe2$hour,
    #                            levels = 0:24,
    #                            labels = c("00:00",
    #                                       "01:00",
    #                                       "02:00",
    #                                       "03:00",
    #                                       "04:00",
    #                                       "05:00",
    #                                       "06:00",
    #                                       "07:00",
    #                                       "08:00",
    #                                       "09:00",
    #                                       "10:00",
    #                                       "11:00",
    #                                       "12:00",
    #                                       "13:00",
    #                                       "14:00",
    #                                       "15:00",
    #                                       "16:00",
    #                                       "17:00",
    #                                       "18:00",
    #                                       "19:00",
    #                                       "20:00",
    #                                       "21:00",
    #                                       "22:00",
    #                                       "23:00",
    #                                       "24:00"),
    #                            ordered = T)

    # plotting Heatmap
    out <- ggplot(helperframe2, aes(hour, day)) +
      theme_minimal() +
      geom_tile(aes(fill = `Number of Media files`), colour = "black", width = 1) +
      labs(
        title = "Links by Weekday and Hour",
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


    # plotting Heatmap
    # out <- ggplot(helperframe2, aes(hour, day)) +
    #   theme_minimal() +
    #   geom_tile(aes(fill = `Number of Media files`), colour = "black") +
    #   labs(title = "Media files by Weekday and Hour",
    #        subtitle = paste(starttime, " - ", endtime),
    #        x = "",
    #        y = "") +
    #   scale_fill_distiller(palette = "YlGnBu", direction = 1) +
    #   scale_y_discrete(drop = FALSE) +
    #   theme_minimal() +
    #   theme(axis.text.x = element_text(angle = 90, hjust = 1),
    #         axis.ticks.x = element_blank(),
    #         legend.position = "bottom",
    #         legend.key.width = unit(2, "cm"),
    #         panel.grid = element_blank()) +
    #   coord_equal()+
    #   scale_x_discrete(limits = c("00:00",
    #                               "01:00",
    #                               "02:00",
    #                               "03:00",
    #                               "04:00",
    #                               "05:00",
    #                               "06:00",
    #                               "07:00",
    #                               "08:00",
    #                               "09:00",
    #                               "10:00",
    #                               "11:00",
    #                               "12:00",
    #                               "13:00",
    #                               "14:00",
    #                               "15:00",
    #                               "16:00",
    #                               "17:00",
    #                               "18:00",
    #                               "19:00",
    #                               "20:00",
    #                               "21:00",
    #                               "22:00",
    #                               "23:00",
    #                               "24:00"))



    # print top ten Media file types at bottom of heatmap
    # if (length(MediaVec) == 1 && MediaVec == "all") {
    #
    #   print(out)
    #
    # } else {
    #
    #   if (length(MediaVec) <= 10) {
    #
    #     print(out + labs(caption = paste0(names(sort(table(NewFrame$NewMedia), decreasing = TRUE)),collapse = "\n ")) + theme(plot.caption = element_text(hjust = 0.5)))
    #
    #   } else {
    #
    #     print(out + labs(caption = paste0(names(sort(table(NewFrame$NewMedia), decreasing = TRUE))[1:10],collapse = "\n ")) + theme(plot.caption = element_text(hjust = 0.5)))
    #
    #   }
    #
    #
    # }

    # printing
    print(out)

    if (return.data == TRUE) {
      # returning
      return(as.data.frame(helperframe2))
    } else {
      return(out)
    }
  }


  if (plot == "cumsum") {
    # cumulative number of links per sender
    NewFrame$counter <- rep(1, length(NewFrame$NewMedia))
    NewFrame$total <- ave(NewFrame$counter, NewFrame$NewSender, FUN = cumsum)

    names(NewFrame) <- c("Dates", "Sender", "Media", "hour", "year", "day", "counter", "total")

    # constructing graph
    out <- suppressWarnings(ggplot(NewFrame, aes(x = Dates, y = total, color = Sender)) +
      theme_minimal() +
      geom_line() +
      labs(
        title = "Cumulative number of Media files sent",
        subtitle = paste(starttime, " - ", endtime)
      ) +
      theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
      xlab("Time") +
      ylab("Total Media files sent") +
      # theme(legend.title = element_text("Media")) +
      geom_point())

    # pinting plot
    suppressWarnings(print(out))

    if (return.data == TRUE) {
      # returning
      return(as.data.frame(NewFrame))
    } else {
      return(out)
    }
  }

  if (plot == "bar") {
    # Converting to dataframe to make it usable by ggplot
    df <- cbind.data.frame(sort(table(NewFrame$NewMedia)))

    # restructuring when we have only 1 type
    if (nrow(df) == 1) {
      names <- rownames(df)
      rownames(df) <- NULL
      df <- cbind(names, df)
    }

    # setting names
    names(df) <- c("Media", "Frequency")

    if (dim(df)[1] == 0) {
      # exit
      warning("No media elements defined by MediaVec are contained in the chat")
      stop()
    }

    # Visualizig the distribution of Mdia file types (file types sent more than x)
    out <- ggplot(df[df$Frequency >= min.occur, ], aes(x = Media, y = Frequency, fill = Media)) +
      theme_minimal() +
      geom_bar(stat = "identity") +
      labs(
        title = "Distribution of sent Media files",
        subtitle = paste(starttime, " - ", endtime),
        x = "Media file types",
        y = "Frequency"
      ) +
      theme( # legend.title = element_text("Media"),
        axis.text.x = element_text(angle = 90, hjust = 0.95, vjust = 0.2)
      )

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
    SumFrame <- group_by(NewFrame, NewSender, NewMedia) %>% summarise(n = n())
    SumFrame <- SumFrame[SumFrame$n >= min.occur, ]

    names(SumFrame) <- c("Sender", "Media", "Frequency")

    # building graph object
    out <- ggplot(SumFrame, aes(x = Sender, y = Frequency, fill = Media)) +
      theme_minimal() +
      geom_bar(stat = "identity", position = position_dodge()) +
      labs(
        title = "Media files sent per Person",
        subtitle = paste(starttime, " - ", endtime),
        x = "Sender",
        y = "Frequency"
      ) #+
    # theme(legend.title = element_text("Media"))

    # only printing legend if we have 20 unique Emoji or less
    # if (length(unique(SumFrame$Media)) <= 20) {
    #
    #   print(out)
    #
    # } else {
    #
    #   warning("Legend was dropped because it contained too many different Media files")
    #   print(out + theme(legend.position = "none")) + theme(legend.title = "Media files")
    #
    # }


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

  # unmuting useless dplyr message
  options(warn = defaultW)
}
