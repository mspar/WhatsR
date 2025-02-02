% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plot_emoji.R
\name{plot_emoji}
\alias{plot_emoji}
\title{Plotting Emoji distributions in whatSapp chatlogs}
\usage{
plot_emoji(
  data,
  names = "all",
  starttime = anytime("1960-01-01 00:00"),
  endtime = Sys.time(),
  min.occur = 1,
  return.data = FALSE,
  EmojiVec = "all",
  plot = "bar",
  EmojiSize = 10,
  FontFamily = "Noto Color Emoji",
  excludeSM = FALSE
)
}
\arguments{
\item{data}{A WhatsApp chatlog that was parsed with code{\link[WhatsR]{parse_chat}}}

\item{names}{A vector of author names that the Plots will be restricted to}

\item{starttime}{Datetime that is used as the minimum boundary for exclusion. Is parsed with {\link[anytime]{anytime}}. Standard format is "yyyy-mm-dd hh:mm".}

\item{endtime}{Datetime that is used as the maximum boundary for exclusion. Is parsed with {\link[anytime]{anytime}}. Standard format is "yyyy-mm-dd hh:mm".}

\item{min.occur}{Minimum number of occurances for Emoji to be included in the plots. Default is 1.}

\item{return.data}{If TRUE, returns the subsetted dataframe. Default is FALSE.}

\item{EmojiVec}{A vector of Emoji that the visualizations will be restricted to}

\item{plot}{The type of plot that should be outputted. Options include "heatmap", "cumsum", "bar" and "splitbar"}

\item{EmojiSize}{Determines the size of the Emoji displayed on top of the bars for "bar" and "splitbar", default is 10.}

\item{FontFamily}{Character string for indicating font family used to plot_emoji. Fonts might need to be installed manually, see {\link[extrafont]{font_import}}}

\item{excludeSM}{If TRUE, excludes the WhatsApp System Messages from the descriptive statistics. Default is FALSE.}
}
\value{
Plots and/or the subsetted dataframe based on author names, datetime and Emoji occurance
}
\description{
Creates a list of basic information about a single WhatsApp chatlog
}
\examples{
#(Font might need to be installed first on Windows)
data <- readRDS(system.file("ParsedWhatsAppChat.rds", package = "WhatsR"))
plot_emoji(data,FontFamily="Times",excludeSM = TRUE) #FontFamily = "Noto Color Emoji" on Linux
}
