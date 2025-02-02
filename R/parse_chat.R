#' @title Parsing exported WhatsApp Textfiles as a Data frame
#'
#' @description Creates a data frame from an exported WhatsApp textfile containing one row per message. Some columns
#' are saved as lists using the I() function so that multiple elements can be stored per message, while still maintaining
#' the general structure of one row per message. These columns should be treated as lists or unlisted first.
#' @param name the name of the exported WhatsApp textfile to be parsed as a character string.
#' @param os operating system of the phone the chat was exported from. Default "auto" tries to automatically detect the OS. OS manually supports "android" or "iOS".
#' @param EmojiDic Dictionary for emoji matching. Can use a version included in this package when set to "internal" or
#' an updated data frame created by \code{\link[WhatsR]{download_emoji}}.
#' @param smilies 1 uses \code{\link[qdapRegex]{ex_emoticon}} to extract smilies, 2 uses a more inclusive custom list
#' of smilies containing all mentions from https://de.wiktionary.org/w/index.php?title=Verzeichnis:International/Smileys
#' and manually added ones.
#' @param anon TRUE results in the vector of sender names being anonymized, FALSE displays the actual names, "add" adds a
#' column of anonymized names next to the actual names.
#' @param media TRUE/FALSE indicates whether the chatlog was downloaded with or without media files. If TRUE, names of
#' attached media files will be extracted into a separate column.
#' @param web "domain" will shorten sent links to domains, "url" will display the full URL.
#' @param order Can be "time" or "both". Whether an indicator column for the order of messages is added
#' that the messages were exported from. "time" orders the messages according to the WhatsApp Timestamp the message received while it was sent.
#' Due to internet problems, these orders are not necessarily interchangeable. "both" gives two columns with the respective orders.
#' @param language Indicates the language setting of the phone with which the messages were exported. This is important because
#' it changes the structure of date/time columns and indicators for sent media. Default is "auto" trying to match either English or German. More languages might be supported in the future.
#' @param rpnl Replace newline. A character string for replacing line breaks within messages for the parsed message for better readability. Default is " start_newline ".
#' @param rpom Replace omitted media. A character string replacing the indicator for omitted media files for better readability. Default is " media_omitted ".
#' @param consent String containing a consent message. All messages from users who have not posted this exact message into the chat will be deleted. Default is NA.
#' @param ... Further arguments passed down to replace_emoji()
#' @importFrom readr parse_character
#' @importFrom qdapRegex rm_url rm_between ex_emoticon rm_non_words
#' @importFrom stats na.omit
#' @importFrom tokenizers tokenize_words
#' @importFrom stringi stri_extract_all_regex  stri_replace_all stri_extract_all stri_split_boundaries
#' @importFrom mgsub mgsub
#' @return A data frame containing:
#'
#'      1) A column to indicate the date and time when the message was sent \cr
#'      2) A column containing the anonymized name of the sender \cr
#'      3) A column to indicate the name of the sender \cr
#'      4) A column containing the raw message \cr
#'      5) A column containing a "flat" message, stripped of emoji, numbers, special characters, file attachments, sent Locations etc. \cr
#'      6) A column containing a tokenized version of the flat message \cr
#'      7) A column containing only URLs that were contained in the messages (optional: can be shortened to domains) \cr
#'      8) A column containing only the names of attached media files \cr
#'      9) A column containing only sent locations and indicators for shared live locations \cr
#'      10) A column containing only emoji that were used in the message \cr
#'      11) A column containing only textual descriptions of emoji that were used in the message \cr
#'      12) A column containing only emoticons (e.g. ":-)") that were used in the message \cr
#'      13) A column containing the number of tokens per message, derived from the "flattened" message \cr
#'      14) A column containing WhatsApp system messages in group chats (e.g."You added Frank to the group") \cr
#'      15) A column specifying the order of the rows according to the timestamp the messages have on the phone used for extracting the chatlog \cr
#'      16) A column for specifying the order of the rows as they are displayed on the phone used for extracting the chatlog \cr
#'
#' @examples
#' data <- parse_chat(system.file("englishandroid24h.txt", package = "WhatsR"))
#' @export

parse_chat <- function(name,
                       EmojiDic = "internal",
                       smilies = 2,
                       anon = "add",
                       media = TRUE,
                       web = "domain",
                       order = "both",
                       language = "auto",
                       os = "auto",
                       rpnl = " start_newline ",
                       rpom = " media_omitted ",
                       consent = NA,
                       ...) {
  # Importing raw chat file
  # We use readChar so that we can do the splitting manually after replacing the
  # Emojis, special characters and newlines
  RawChat <- readChar(name, file.info(name)$size)

  # printing info
  cat("Imported raw chat file \U2713 \n")

  # Regex that detects 24h/ampm, american date format, european date format and all combinations for ios and android
  TimeRegex_android <- c("(?!^)(?=((\\d{2}\\.\\d{2}\\.\\d{2})|(\\d{1,2}\\/\\d{1,2}\\/\\d{2})),\\s\\d{2}\\:\\d{2}((\\s\\-)|(\\s(?i:(am|pm))\\s\\-)))")
  TimeRegex_ios <- c("(?!^)(?=\\[((\\d{2}\\.\\d{2}\\.\\d{2})|(\\d{1,2}\\/\\d{1,2}\\/\\d{2})),\\s\\d{1,2}\\:\\d{2}((\\:\\d{2}\\s(?i:(pm|am)))|(\\s(?i:(pm|am)))|(\\:\\d{2}\\])|(\\:\\d{2})|(\\s))\\])")


  ### reducing RawChat to workable size for detection processes if necessary ####
  if (nchar(RawChat) > 10000) {
    excerpt <- substr(RawChat, 1, 10000)
  } else {
    excerpt <- RawChat
  }


  # trying to automatically detect operating system [takes quite long for larger chats]
  if (os == "auto") {
    # getting number of os-specific timestamps from chat
    android_stamps <- length(unlist(stri_extract_all(excerpt, regex = TimeRegex_android)))
    ios_stamps <- length(unlist(stri_extract_all(excerpt, regex = TimeRegex_ios)))

    # selecting operations system
    if (android_stamps > ios_stamps) {
      os <- "android"
      cat("Operating System was automatically detected: android \U2713 \n")
      TimeRegex <- TimeRegex_android
    } else if (android_stamps == ios_stamps) {
      cat("Operating System could not be detected automatically, please enter either 'ios' or 'android' without quatation marks and press enter")
      os <- readline(prompt = "Enter operating system: ")

      if (os == "android") {
        cat("Operating System was set to: android \U2713 \n")
        TimeRegex <- TimeRegex_android
      } else if (os == "ios") {
        cat("Operating System was set to: ios \U2713 \n")
        TimeRegex <- TimeRegex_ios
      } else if (os != "android" & os != "ios") {
        warning("Parameter os must be either 'android', 'ios' or 'auto'")
        return(NULL)
      }
    } else if (android_stamps < ios_stamps) {
      os <- "ios"
      cat("Operating System was automatically detected: ios \U2713 \n")
      TimeRegex <- TimeRegex_ios
    }
  } else if (os == "ios") {
    TimeRegex <- TimeRegex_ios
  } else if (os == "android") {
    TimeRegex <- TimeRegex_android
  }


  # loading language indicators
  WAStrings <- read.csv(system.file("Languages.csv", package = "WhatsR"),
    stringsAsFactors = F,
    fileEncoding = "UTF-8"
  )

  # trying to auto-detect language
  if (language == "auto") {
    # checking presence of indicator strings (We need to delete ^ and $ from the regexes because the chat is not cut into pieces yet)
    german_a <- sum(!is.na(unlist(stri_extract_all(excerpt, regex = gsub("$", "", gsub("^", "", WAStrings[1, ], fixed = TRUE), fixed = TRUE)[3:25]))))
    german_i <- sum(!is.na(unlist(stri_extract_all(excerpt, regex = gsub("$", "", gsub("^", "", WAStrings[2, ], fixed = TRUE), fixed = TRUE)[3:25]))))
    english_a <- sum(!is.na(unlist(stri_extract_all(excerpt, regex = gsub("$", "", gsub("^", "", WAStrings[3, ], fixed = TRUE), fixed = TRUE)[3:25]))))
    english_i <- sum(!is.na(unlist(stri_extract_all(excerpt, regex = gsub("$", "", gsub("^", "", WAStrings[4, ], fixed = TRUE), fixed = TRUE)[3:25]))))

    # Best guess about language based on presence of indicator strings
    guess <- WAStrings[which(c(german_a, german_i, english_a, english_i) == max(c(german_a, german_i, english_a, english_i))), 1]

    # setting auto-detected language
    language <- unlist(stri_extract_all(guess, fixed = c("german", "english")))
    language <- language[!is.na(language)]

    # printing info
    cat(paste0("Auto-detected language setting of exporting phone: ", language, " \U2713 \n"))
  } else if (language != "english" & language != "german") {
    cat("Language was set incorrectly or could not automatically be detected. Please set language to either 'german' or 'english' without the quotation marks below")
    language <- readline(prompt = "Enter the phone's language setting from which the chat was exported: ")
  }

  # selecting indicators based on language
  Indicators <- WAStrings[WAStrings$Settings == paste0(language, os), ]

  # assigning indicator strings for message bodies
  ExtractAttached <- Indicators$ExtractAttached
  DeleteAttached <- Indicators$DeleteAttached
  OmittanceIndicator <- Indicators$OmittanceIndicator
  SentLocation <- Indicators$SentLocation
  LiveLocation <- Indicators$LiveLocation
  MissedCallVoice <- Indicators$MissedCallVoice
  MissedCallVideo <- Indicators$MissedCallVideo

  # assigning indicator strings without sender info
  StartMessage <- Indicators$StartMessage
  StartMessageGroup <- Indicators$StartMessageGroup
  GroupCreateSelf <- Indicators$GroupCreateSelf
  GroupCreateOther <- Indicators$GroupCreateOther
  GroupRenameSelf <- Indicators$GroupRenameSelf
  GroupPicChange <- Indicators$GroupPicChange
  GroupRenameOther <- Indicators$GroupRenameOther
  UserRemoveSelf <- Indicators$UserRemoveSelf
  UserAddSelf <- Indicators$UserAddSelf
  UserRemoveOther <- Indicators$UserRemoveOther
  UserAddOther <- Indicators$UserAddOther
  GroupPicChangeOther <- Indicators$GroupPicChangeOther
  UserNumberChangeKnown <- Indicators$UserNumberChangeKnown
  UserNumberChangeUnknown <- Indicators$UserNumberChangeUnknown
  DeletedMessage <- Indicators$DeletedMessage
  UserLeft <- Indicators$UserLeft
  SafetyNumberChange <- Indicators$SafetyNumberChange
  GroupCallStarted <- Indicators$GroupCallStarted
  GroupVideoCallStarted <- Indicators$GroupVideoCallStarted


  # print info
  cat(paste("Imported matching strings for: ", paste(language, os, sep = " "), " \U2713 \n", sep = ""))

  # Replacing special characters
  ReplacedSpecialCharactersChat <- parse_character(RawChat)

  # Deleting Left-to-right marker if present
  ReplacedSpecialCharactersChat <- gsub("\u200e", "", ReplacedSpecialCharactersChat)

  # Deleting zero-width no break space if present
  ReplacedSpecialCharactersChat <- gsub("\uFEFF", "", ReplacedSpecialCharactersChat)

  # printing info
  cat("Replaced special characters \U2713 \n")

  if (os == "android") {
    # Parsing the message according to android text structure
    ParsedChat <- parse_android(ReplacedSpecialCharactersChat,
      nl = "\n",
      nlreplace = rpnl,
      mediaomitted = OmittanceIndicator,
      mediaindicator = ExtractAttached,
      sentlocation = SentLocation,
      livelocation = LiveLocation,
      datetimeindicator = TimeRegex,
      mediareplace = OmittanceIndicator
    )

    # printing info
    cat("Parsed chat according to Android document structure \U2713 \n")
  } else if (os == "ios") {
    # Parsing the message according to android text structure
    ParsedChat <- parse_ios(ReplacedSpecialCharactersChat,
      nl = "\n",
      nlreplace = rpnl,
      mediaomitted = OmittanceIndicator,
      mediaindicator = DeleteAttached,
      sentlocation = SentLocation,
      livelocation = LiveLocation,
      datetimeindicator = TimeRegex,
      mediareplace = OmittanceIndicator
    )

    # printing info
    cat("Parsed chat according to iOS document structure \U2713 \n")
  }

  # Extracting WhatsApp System Messages and removing them from Message and flattened Message body
  WAStrings <- c(
    StartMessage,
    StartMessageGroup,
    GroupCreateSelf,
    GroupCreateOther,
    GroupRenameSelf,
    GroupPicChange,
    GroupRenameOther,
    UserRemoveSelf,
    UserAddSelf,
    UserLeft,
    UserRemoveOther,
    UserAddOther,
    GroupPicChangeOther,
    UserNumberChangeKnown,
    UserNumberChangeUnknown,
    DeletedMessage,
    SafetyNumberChange,
    GroupCallStarted,
    GroupVideoCallStarted
  )




  # checking whether a WhatsApp Message was parsed into the sender column
  WAMessagePresent <- unlist(stri_extract_all_regex(str = ParsedChat$Sender, pattern = paste(WAStrings, collapse = "|")))
  ParsedChat$SystemMessage <- WAMessagePresent
  ParsedChat$Sender[!is.na(WAMessagePresent)] <- "WhatsApp System Message"

  # printing info
  cat("Differentiated System Messages from User generated content \U2713 \n")

  # fixing parsing of messages with self-deleting photos:
  # selecting rows with no content where the senders contain a ":"
  ParsedChat[grepl(":", ParsedChat$Sender) &
    is.na(ParsedChat$Message) &
    is.na(ParsedChat$SystemMessage) &
    is.na(ParsedChat$Media) &
    is.na(ParsedChat$Location), ]$Sender <- gsub(
    ":",
    "",
    ParsedChat[grepl(":", ParsedChat$Sender) &
      is.na(ParsedChat$Message) &
      is.na(ParsedChat$SystemMessage) &
      is.na(ParsedChat$Media) &
      is.na(ParsedChat$Location), ]$Sender
  )



  if (!is.na(consent)) {
    # getting vector with names of consenting chat participants
    consentintg_ppts <- c(na.omit(ParsedChat$Sender[ParsedChat$Message == consent]), "WhatsApp System Message")

    # removing all messages from non-consenting participants
    ParsedChat <- ParsedChat[is.element(ParsedChat$Sender, consentintg_ppts), ]
  }

  ### We create handy vectors for used Emojis, extracted links, extracted media data
  # and one containing the message without stopwords, Emojis, linebreaks, URLs and punctuation

  # extracting links
  URL <- (rm_url(ParsedChat$Message, extract = TRUE))

  # printing info
  cat("Extracted Links from text \U2713 \n")

  if (web == "domain") {
    # Reduce the links to domain-names
    helper <- lapply(URL, strsplit, "(?<=/)", perl = TRUE)
    helper2 <- rapply(helper, function(x) {
      x <- unlist(x)[1:3]
    }, how = "list")
    helper3 <- rapply(helper2, function(x) {
      x <- paste(x, collapse = "")
    }, how = "list")
    helper4 <- lapply(helper3, unlist)
    helper4[helper4 == "NANANA"] <- NA
    URL <- helper4

    # printing info
    cat("Shortend links to domains \U2713 \n")
  }


  #### Extracting Emoji

  # importing emoji dictionary
  EmojiDictionary <- read.csv(system.file("EmojiDictionary.csv", package = "WhatsR"),
    header = TRUE,
    stringsAsFactors = FALSE,
    strip.white = FALSE,
    colClasses = "character",
    blank.lines.skip = TRUE
  )

  # isolating emoji to get a better and faster matching than using stringr,stringi, rm_default or mgsub
  # (idea from: https://github.com/JBGruber/rwhatsapp/blob/master/R/emoji_lookup.R)
  MessageNumber <- 1:length(ParsedChat$Message)
  CharSplit <- stri_split_boundaries(ParsedChat$Message, type = "character")

  # creating split data frame
  SplitFrame <- data.frame(
    MessageNumber = rep(MessageNumber, sapply(CharSplit, length)),
    Emoji = unlist(CharSplit)
  )

  # doing the matching
  R.native <- EmojiDictionary$Desc[match(SplitFrame$Emoji, EmojiDictionary$R.native)]
  SplitFrame <- cbind.data.frame(SplitFrame, R.native)

  # deleting empties
  SplitFrame <- SplitFrame[!is.na(SplitFrame$R.native), ]

  # creating list of vectors for emoji descriptions and glyphs
  EmojiSplitNames <- split(SplitFrame$R.native, SplitFrame$MessageNumber)

  EmojiSplitGlyphs <- split(SplitFrame$Emoji, SplitFrame$MessageNumber)

  # Rows in DF that contain Emojis
  EmojiRows <- as.numeric(names(EmojiSplitNames))

  # Adding to Dataframe
  Emoji <- rep(NA, dim(ParsedChat)[1])
  EmojiDescriptions <- rep(NA, dim(ParsedChat)[1])
  Emoji[EmojiRows] <- I(EmojiSplitGlyphs)
  EmojiDescriptions[EmojiRows] <- I(EmojiSplitNames)

  # printing info
  cat("Extracted emoji from text \U2713 \n")

  ### Creating a flattened Message for text mining

  # removing Emojis,newlines, media indicators
  Flat <- rm_between(ParsedChat$Message, " start_newlin", "e ", replacement = "")
  Flat <- stri_replace_all(Flat, regex = OmittanceIndicator, replacement = "")

  # printing info
  cat("Removed emoji, newlines and media file indicators from flat text column \U2713 \n")

  # printing info
  cat("Deleted filenames from flat text column \U2713 \n")

  # deleting the file attachments from flattend message
  if (os == "android") {
    Flat <- gsub(paste0("(.)*?", substring(DeleteAttached, 4, nchar(DeleteAttached) - 1), "($|\\s)"), "", Flat, perl = TRUE)
  } else if (os == "ios") {
    Flat <- gsub(x = Flat, pattern = ExtractAttached, replacement = "", perl = T)
    # We might need to fix an issue here where Filenames are not deleted properly if there is text behind them.
    # Needs further testing!
  }

  ### Smilies

  # lazy version with prebuild dictionary
  if (smilies == 1) {
    Smilies <- ex_emoticon(Flat)

    # printing info
    cat("Extracted Smilies using prebuild dictionary \U2713 \n")
  } else if (smilies == 2) { # using custom dictionary

    # package version
    smilies <- read.csv(system.file("SmileyDictionary.csv", package = "WhatsR"),
      stringsAsFactors = F
    )

    # deleting whitespace from smilies
    smilies <- smilies[, 2]
    smilies <- trimws(smilies)

    # Splitting smilies
    Smilies <- sapply(strsplit(Flat, " "), function(x) x[x %in% smilies])
    Smilies[lapply(Smilies, length) == 0] <- NA

    # printing info
    cat("Extracted smilies using custom build dictionary \U2713 \n")
  }

  # replacing sent location in flattened message
  Flat <- gsub(
    x = Flat,
    pattern = SentLocation,
    replacement = NA,
    perl = T
  )

  cat("Deleted sent location indicators from flat text column \U2713 \n")

  # replacing live location in falttened message
  Flat <- gsub(
    x = Flat,
    pattern = LiveLocation,
    replacement = NA,
    perl = T
  )

  cat("Deleted live location indicators from flat text column \U2713 \n")

  # replacing missed voice calls in flattened message
  Flat <- gsub(
    x = Flat,
    pattern = MissedCallVoice,
    replacement = NA,
    perl = T
  )

  # replacing missed video calls in flattened message
  Flat <- gsub(
    x = Flat,
    pattern = MissedCallVideo,
    replacement = NA,
    perl = T
  )

  # printing info
  cat("Deleted voice call indicators from flat text column \U2713 \n")

  # deleting URLs from messages
  Flat <- rm_url(Flat)
  Flat[Flat == "" | Flat == "NULL"] <- NA

  # printing info
  cat("Deleted URLs from flat text column \U2713 \n")

  # Deleting all non words
  Flat <- rm_non_words(Flat)

  # making all empty strings NA
  Flat[nchar(Flat) == 0] <- NA

  # printing info
  cat("Deleted all non-words from flat text column \U2713 \n")

  # tokenizing the flattened message
  TokVec <- tokenize_words(Flat, lowercase = FALSE)

  # printing info
  cat("Tokenized flat text column to individual words \U2713 \n")


  # Reassigment
  DateTime <- ParsedChat$DateTime
  Sender <- ParsedChat$Sender
  Message <- ParsedChat$Message
  Media <- ParsedChat$Media
  Location <- ParsedChat$Location
  SystemMessage <- ParsedChat$SystemMessage

  # Including everything in dataframe
  DF <- data.frame(
    DateTime = DateTime,
    Sender = Sender,
    Message = Message,
    Flat = Flat,
    TokVec = I(TokVec),
    URL = I(URL),
    Media = Media,
    Location = Location,
    Emoji = I(Emoji),
    EmojiDescriptions = I(EmojiDescriptions),
    Smilies = I(Smilies),
    SystemMessage = SystemMessage,
    stringsAsFactors = FALSE
  )


  # Creating new variable for number of Tokens
  DF$TokCount <- sapply(DF$TokVec, function(x) {
    length(unlist(x))
  })
  DF[which(DF$TokVec == "NA"), "TokCount"] <- 0
  DF$TokCount <- unlist(DF$TokCount)

  # fixing weird issue with character NAs
  DF$Flat[DF$Flat == "NA"] <- NA

  # printing info
  cat("Created Dataframe containing all columns \U2713 \n")


  # anonymizing chat participant names and mentions in SystemMesssages
  if (anon == TRUE) {
    Anons <- paste(rep("Person", length(unique(DF$Sender[DF$Sender != "WhatsApp System Message"]))),
      seq(1, length(unique(DF$Sender[DF$Sender != "WhatsApp System Message"])), 1),
      sep = "_"
    )

    # create Anon Lookup table
    AnonLookupTable <- cbind.data.frame(Sender = unique(DF$Sender[DF$Sender != "WhatsApp System Message"]), Anon = Anons, stringsAsFactors = FALSE)

    # Replacing names in SystemMesage Column
    DF$SystemMessage <- mgsub(DF$SystemMessage, AnonLookupTable$Sender, AnonLookupTable$Anon, recycle = FALSE)
    DF$SystemMessage <- gsub("\\+Person", "Person", DF$SystemMessage, perl = TRUE)

    # TODO:
    # There is still an issue with People who are added to the conversation but never send a message: We cannot anonymize them
    # because they do not show up in the Sender column, the anonimization breaks down for these cases!
    # This might be solved by applying RegEx to system messages to replace everything between certain patterns that is not Person_x

    # factorizing
    DF$Sender <- factor(DF$Sender, levels = unique(DF$Sender))

    # changing levels forcing the values to take over the anons
    levels(DF$Sender)[levels(DF$Sender) != "WhatsApp System Message"] <- AnonLookupTable$Anon

    # printing info
    cat("Anonymized names of chat participants \U2713 \n")
  }

  if (anon == "add") {
    Anons <- paste(rep("Person", length(unique(DF$Sender[DF$Sender != "WhatsApp System Message"]))),
      seq(1, length(unique(DF$Sender[DF$Sender != "WhatsApp System Message"])), 1),
      sep = "_"
    )

    # create Anon Lookup table
    AnonLookupTable <- cbind.data.frame(Sender = unique(DF$Sender[DF$Sender != "WhatsApp System Message"]), Anon = Anons, stringsAsFactors = FALSE)

    # Replacing names in SystemMesage Column
    DF$SystemMessage <- mgsub(DF$SystemMessage, AnonLookupTable$Sender, AnonLookupTable$Anon, recycle = FALSE)
    DF$SystemMessage <- gsub("\\+Person", "Person", DF$SystemMessage, perl = TRUE)

    # factorizing
    Anonymous <- factor(DF$Sender, levels = unique(DF$Sender))

    # changing levels forcing the vlaues to take over the anons
    levels(Anonymous)[levels(Anonymous) != "WhatsApp System Message"] <- AnonLookupTable$Anon

    # printing info
    cat("Anonymized names of chat participants \U2713 \n")
  }


  if (anon == "add") {
    DF <- cbind.data.frame(DF[1], Anonymous, DF[2:ncol(DF)])
  }

  # including ordering
  if (order == "time") {
    # change order to time
    DF <- DF[order(DF$DateTime), ]
  } else if (order == "both") {
    # TimeOrder
    TimeOrder <- order(DF$DateTime)

    # Displayorder
    DisplayOrder <- 1:dim(DF)[1]

    # add them
    DF <- cbind.data.frame(DF, TimeOrder, DisplayOrder)
  } else {}

  # Deleting empty rows
  DF <- DF[rowSums(is.na(DF)) <= 10, ]

  # return datframe
  return(DF)
}
