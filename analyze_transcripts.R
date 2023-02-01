#' ---
#' title: "AI Researcher Interview Analysis"
#' author: "Maheen Shermohammed & Vael Gates"
#' output:
#'  html_document:
#'    toc: true
#'    toc_float: true
#' ---

#+ include = FALSE
knitr::opts_chunk$set(echo=FALSE, message = FALSE, warning=FALSE)

if (!require(ggplot2)) {install.packages("ggplot2"); require(ggplot2)}
if (!require(plotly)) {install.packages("plotly"); require(plotly)}
if (!require(reshape2)) {install.packages("reshape2"); require(reshape2)}
if (!require(knitr)) {install.packages("knitr"); require(knitr)}
if (!require(kableExtra)) {install.packages("kableExtra"); require(kableExtra)}
if (!require(gridExtra)) {install.packages("gridExtra"); require(gridExtra)}
if (!require(grid)) {install.packages("grid"); require(grid)}

if (!require(stringr)) {install.packages("stringr"); require(stringr)}
if (!require(ggcorrplot)) {install.packages("ggcorrplot"); require(ggcorrplot)}
if (!require(psych)) {install.packages("psych"); require(psych)}

# CHANGE THIS to the path of your directory that holds the scripts
# and all relevant data files.
mydir <- "~/Documents/AISFB/analysis/new/"
# mydir <- "~/quantanalysis_interviews_maheen/"

# CHANGE THIS to toggle between interactive (T) and static (F) graphs
interactive_mode <- TRUE

##### Functions ----
plot_data_column = function (data, col, startchr, type="wrap") {
  category <- substr(question_key[col,"question"],startchr,nchar(question_key[col,"question"]))
  names(data)[col] <- "response"
  data$mytitle <- category
  g <- ggplot(data, aes(x = response)) + geom_bar(stat = "count") +
    labs(x = "") #+ facet_wrap(~mytitle)
  if (type=="wrap") {
    g <- g + facet_wrap(~mytitle)
  } else {
    mytitle <- paste(strwrap(category, 70), collapse = "\n")
    g <- g + labs(x = "",title = mytitle)
  }
  g
}

#function for standard error of the mean
sem <- function(x){
  sd(na.omit(x))/sqrt(length(na.omit(x)))
}

#function for standard error of a proportion
sep <- function(p,n) {
  prop_mult <- p * (1 - p)
  sqrt( prop_mult / n)
}

#function to pull out a subset of data whose column
#names start with a certain prefix
datawprefix <- function(data,prefix) {
  newdat = data[names(data)[startsWith(names(data),prefix)]]
  return(newdat)
}

#function to convert numbers to labels and then combine
#those labels across columns
combine_labels <- function(df,mysep="") {
  for (colN in names(df)) {
    df[,colN] <- ifelse(df[,colN] == 1, colN, "")
  }
  combined_label <- do.call(paste, c(df, sep=mysep))
  combined_label[combined_label==""] <- "None/NA"
  return(combined_label)
}

#more advanced version of combine labels
#function that handles separators better
combine_labels_adv <- function(df,mysep="",noneval="None/NA") {
  for (colN in names(df)) {
    df[,colN] <- ifelse(df[,colN] == 1, colN, "")
  }
  combined_label <- unlist(apply(df, 1, function(x) paste(x[x!=''], collapse=mysep)))
  combined_label[combined_label==""] <- noneval
  return(combined_label)
}

# make a bar plot of the various responses in a dataframe
resp_barplt_sums = function(df, ord="cnt") {
  #for data that is ~one-hot encoded but non-exclusive (someone could be flagged for multiple columns)
  df <- subset(df, rowSums(df)!=0)
  counts <- colSums(df)
  percentage <- round(counts/nrow(df)*100)
  counts <- data.frame(response=names(df), percentage=percentage, count=counts, row.names=NULL)
  if (sum(ord == "cnt")==1) {
    counts$response <- reorder(factor(counts$response), -counts$percentage)
  } else {
    counts$response <- reorder(factor(counts$response), ord)
  }
  g <- ggplot(counts, aes(x = response, y = count, label=percentage)) +
    geom_bar(stat = "identity") +
    labs(x = "", y = "Count") +
    theme(axis.text.x = element_text(angle = 50, hjust = 1))
  g
}

# make a bar plot of the % of various responses in a dataframe
resp_barplt_sumsperc = function(df, ord="perc") {
  #for data that is ~one-hot encoded but non-exclusive (someone could be flagged for multiple columns)
  df <- subset(df, rowSums(df)!=0)
  counts <- colSums(df)
  percs <- round(counts/nrow(df)*100)
  percs <- data.frame(response=names(percs), percentage=percs, count=counts, row.names=NULL)
  if (sum(ord == "perc")==1) {
    percs$response <- reorder(factor(percs$response), -percs$percentage)
  } else {
    percs$response <- reorder(factor(percs$response), ord)
  }
  g <- ggplot(percs, aes(x = response, y = percentage, label=count)) + geom_bar(stat = "identity") +
    labs(x = "", y = "Percentage") +
    theme(axis.text.x = element_text(angle = 50, hjust = 1))
  g
}

# Make a new data frame of all columns starting with a prefix,
# then remove that prefix from the column names
df_from_prefix <- function(df,prefix) {
  newdf <- datawprefix(df,prefix)
  names(newdf) <- substring(names(newdf),nchar(prefix)+1)
  return(newdf)
}

# Display a plotly histogram and basic stats for a numeric vector
display_numeric_stats <- function(vect,tit = deparse(substitute(vect)),binnum=0) {
  cat(sprintf("mean: %s\nmedian: %s\nrange: %s - %s\n# with value of 0: %s",
              mean(vect,na.rm = T),median(vect,na.rm = T),
              min(vect,na.rm = T),max(vect,na.rm = T),
              sum(vect==0,na.rm=T)))
  
  if (interactive_mode) {
    p <- plot_ly(x = vect, type = "histogram",
                 marker = list(line = list(color = 'rgb(8,48,107)',
                                           width = 1.5)),
                 nbinsx = binnum) %>%
      layout(title = 'Histogram', xaxis = list(title = tit),
             yaxis = list(title = 'Frequency'))
    return(p)
  } else {
    hist(vect,breaks=binnum,xlab = tit,main = "Histogram",
         col = rgb(8,48,150,maxColorValue = 255),
         xlim=c(min(vect,na.rm = T),max(vect,na.rm = T)))
  }
}

# Function to calculate the mean and the standard deviation
# for each group
# data : a data frame
# varname : the name of a column containing the variable
#to be summariezed
# groupnames : vector of column names to be used as
# grouping variables
data_summary <- function(data, varname, groupnames){
  require(plyr)
  summary_func <- function(x, col){
    c(mean = mean(x[[col]], na.rm=TRUE),
      sd = sd(x[[col]], na.rm=TRUE),
      sem = sem(x[[col]]),
      total = length(x[[col]]))
  }
  data_sum<-ddply(data, groupnames, .fun=summary_func,
                  varname)
  data_sum <- rename(data_sum, c("mean" = varname))
  return(data_sum)
}

# Create a table that computes the counts for certain categories
# of a vector, grouped by the counts of a one-hot (ish) encoded
# data frame.
create_cross_table <- function(df,vect,grpname) {
  dfXvect <- NULL
  for (f in names(df)) {
    myt <- table(data.frame(df[f],vect))
    myt_in_grp <- myt["1",] #pick out the ppl in the given group (usually: field)
    newdat <- data.frame(grp=f,as.list(myt_in_grp))
    names(newdat)[names(newdat) == "grp"] <- grpname
    dfXvect <- rbind(dfXvect,newdat)
  }
  return(dfXvect)
}

# Get proportions from a cross-table (created as above)
cross_tbl_proportions <- function(crosstbl,rm_col_list) {
  if (any(is.na(rm_col_list))) {
    crosstbl_prop <- crosstbl
  } else {
    crosstbl_prop <- crosstbl[,-which(names(crosstbl) %in% rm_col_list)]
  }
  crosstbl_prop$total <- rowSums(crosstbl_prop[-1])
  colind <- ncol(crosstbl_prop)-1
  crosstbl_prop[2:colind] <- crosstbl_prop[2:colind]/crosstbl_prop$total
  for (c in names(crosstbl_prop[2:colind])) {
    crosstbl_prop[,paste0("se_",c)] <- sep(crosstbl_prop[,c],crosstbl_prop$total)
  }
  crosstbl_prop[2:colind] <- round(crosstbl_prop[2:colind],2)
  return(crosstbl_prop)
}

# Create a table that computes the mean / sem for certain categories
# of a vector, grouped by the counts of a one-hot (ish) encoded
# data frame.
create_cross_table_means <- function(df,vect,grpname) {
  dfXvect <- NULL
  for (f in names(df)) {
    vect_in_grp <- vect[df[f]==1]
    newdat <- data.frame(grp=f,mean=mean(vect_in_grp,na.rm = T),sem=sem(vect_in_grp))
    names(newdat)[names(newdat) == "grp"] <- grpname
    dfXvect <- rbind(dfXvect,newdat)
  }
  return(dfXvect)
}

# Only use ggplotly if interactive mode is on
ggplotly_toggle <- function(x) {
  if (interactive_mode) {
    return(ggplotly(x))
  } else {
    return(x+theme(plot.margin = margin(10,10,10,70)))
  }
}

# Only use subplot (from plotly) if interactive mode is on
subplot_toggle <- function(x1,x2,mar=0.08,titY=T,maintitle="",ncl=2) {
  if (interactive_mode) {
    x2<-x2+labs(title = maintitle)
    return(subplot(x1,x2, margin = mar, titleY = titY))
  } else {
    if (maintitle=="") {
      return(grid.arrange(x1,x2,ncol=ncl))
    } else {
      return(grid.arrange(x1,x2,ncol=ncl,top=textGrob(maintitle)))
    }
  }
}

## $

#####

#import data
# manually edit this file to remove "extra_" and "extraN_" from some subids
rawdata <- read.csv(paste0(mydir,"MAXQDA2022 Code Matrix Browser CLEAN-TAG-NAMES(thatdontcorrespondwithMaxQDA)_edited.csv"),stringsAsFactors = FALSE)
table(unlist(lapply(rawdata, class))) # good, everything is numeric but subject ID

#binarize data
# Note: most non-zero values are 1's, but there are some others (we'll binarize going forward):
# table(rawdata[2:ncol(rawdata)][rawdata[2:ncol(rawdata)]>0])
## take all non-zero values and make them 1
rawdata[2:ncol(rawdata)][rawdata[2:ncol(rawdata)]>0] <- 1

#rename subject ID column
names(rawdata)[1] <- "subjID"

#create a subjID_init column to be able to combine w/ demographics later
rawdata$subjID_init <- substr(rawdata$subjID,1,5)

##### all internal reference link anchors (https://stackoverflow.com/questions/33913780/internal-links-in-rmarkdown-dont-work)
# <a href="#introduction">(Source)</a>
# <a href="#overview">(Source)</a>
# <a href="#findings-summary">(Source)</a>
# <a href="#tags">(Source)</a>
# <a href="#limitations">(Source)</a>
# <a href="#about-this-report">(Source)</a>
# <a href="#demographics-of-interviewees">(Source)</a>
# <a href="#basic-demographics">(Source)</a>
# <a href="#basic-demographics_gender">(Source)</a>
# <a href="#basic-demographics_age">(Source)</a>
# <a href="#basic-demographics_location">(Source)</a>
# <a href="#basic-demographics_location_country-of-origin">(Source)</a>
# <a href="#basic-demographics_location_current-country-of-work">(Source)</a>
# <a href="#what-area-of-ai">(Source)</a>
# <a href="#what-area-of-ai_field1">(Source)</a>
# <a href="#what-area-of-ai_field2">(Source)</a>
# <a href="#sector">(Source)</a>
# <a href="#status-experience">(Source)</a>
# <a href="#status-experience_h-index">(Source)</a>
# <a href="#status-experience_years-of-experience">(Source)</a>
# <a href="#status-experience_professional-rank">(Source)</a>
# <a href="#status-experience_institution-rank">(Source)</a>
# <a href="#status-experience_institution-rank_academia">(Source)</a>
# <a href="#status-experience_institution-rank_industry">(Source)</a>
# <a href="#preliminary-attitudes">(Source)</a>
# <a href="#what-motivates-you">(Source)</a>
# <a href="#benefits">(Source)</a>
# <a href="#risks">(Source)</a>
# <a href="#future">(Source)</a>
# <a href="#primary-questions-descriptives">(Source)</a>
# <a href="#when-will-we-get-agi">(Source)</a>
# <a href="#when-will-we-get-agi_field">(Source)</a>
# <a href="#when-will-we-get-agi_field_field1">(Source)</a>
# <a href="#when-will-we-get-agi_field_field2">(Source)</a>
# <a href="#when-will-we-get-agi_sector">(Source)</a>
# <a href="#when-will-we-get-agi_age">(Source)</a>
# <a href="#when-will-we-get-agi_h-index">(Source)</a>
# <a href="#alignment-problem">(Source)</a>
# <a href="#alignment-problem_field">(Source)</a>
# <a href="#alignment-problem_field_field1">(Source)</a>
# <a href="#alignment-problem_field_field2">(Source)</a>
# <a href="#alignment-problem_heard-of-ai-alignment">(Source)</a>
# <a href="#alignment-problem_heard-of-ai-safety">(Source)</a>
# <a href="#alignment-problem_when-will-we-get-agi">(Source)</a>
# <a href="#instrumental-incentives">(Source)</a>
# <a href="#instrumental-incentives_field">(Source)</a>
# <a href="#instrumental-incentives_field_field1">(Source)</a>
# <a href="#instrumental-incentives_field_field2">(Source)</a>
# <a href="#instrumental-incentives_heard-of-ai-alignment">(Source)</a>
# <a href="#instrumental-incentives_heard-of-ai-safety">(Source)</a>
# <a href="#instrumental-incentives_when-will-we-get-agi">(Source)</a>
# <a href="#merged-extended-discussion">(Source)</a>
# <a href="#alignment-instrumental-combined">(Source)</a>
# <a href="#alignment-instrumental-combined_field">(Source)</a>
# <a href="#alignment-instrumental-combined_field_field1">(Source)</a>
# <a href="#alignment-instrumental-combined_field_field2">(Source)</a>
# <a href="#alignment-instrumental-combined_heard-of-ai-alignment">(Source)</a>
# <a href="#alignment-instrumental-combined_heard-of-ai-safety">(Source)</a>
# <a href="#alignment-instrumental-combined_when-will-we-get-agi">(Source)</a>
# <a href="#alignment-instrumental-combined_sector">(Source)</a>
# <a href="#alignment-instrumental-combined_age">(Source)</a>
# <a href="#alignment-instrumental-combined_h-index">(Source)</a>
# <a href="#work-on-this">(Source)</a>
# <a href="#work-on-this_about-this-variable">(Source)</a>
# <a href="#work-on-this_field">(Source)</a>
# <a href="#work-on-this_field_field1">(Source)</a>
# <a href="#work-on-this_field_field2">(Source)</a>
# <a href="#work-on-this_heard-of-ai-alignment">(Source)</a>
# <a href="#work-on-this_heard-of-ai-safety">(Source)</a>
# <a href="#work-on-this_when-will-we-get-agi">(Source)</a>
# <a href="#work-on-this_alignment-problem">(Source)</a>
# <a href="#work-on-this_instrumental-incentives">(Source)</a>
# <a href="#work-on-this_sector">(Source)</a>
# <a href="#work-on-this_age">(Source)</a>
# <a href="#work-on-this_h-index">(Source)</a>
# <a href="#heard-of-ai-safety">(Source)</a>
# <a href="#heard-of-ai-safety_field">(Source)</a>
# <a href="#heard-of-ai-safety_field_field1">(Source)</a>
# <a href="#heard-of-ai-safety_field_field2">(Source)</a>
# <a href="#heard-of-ai-alignment">(Source)</a>
# <a href="#heard-of-ai-alignment_field">(Source)</a>
# <a href="#heard-of-ai-alignment_field_field1">(Source)</a>
# <a href="#heard-of-ai-alignment_field_field2">(Source)</a>
# <a href="#policy">(Source)</a>
# <a href="#policy_about-this-variable">(Source)</a>
# <a href="#public-media">(Source)</a>
# <a href="#public-media_about-this-variable">(Source)</a>
# <a href="#colleagues">(Source)</a>
# <a href="#colleagues_about-this-variable">(Source)</a>
# <a href="#did-you-change-your-mind">(Source)</a>
# <a href="#did-you-change-your-mind_about-this-variable">(Source)</a>
# <a href="#general">(Source)</a>
# <a href="#follow-up-questions">(Source)</a>
# <a href="#lasting-effects">(Source)</a>
# <a href="#lasting-effects_when-will-we-get-agi">(Source)</a>
# <a href="#lasting-effects_alignment-problem">(Source)</a>
# <a href="#lasting-effects_instrumental-incentives">(Source)</a>
# <a href="#lasting-effects_align-instrum-combo">(Source)</a>
# <a href="#lasting-effects_work-on-this">(Source)</a>
# <a href="#lasting-effects_did-you-change-your-mind">(Source)</a>
# <a href="#new-actions">(Source)</a>
# <a href="#new-actions_when-will-we-get-agi">(Source)</a>
# <a href="#new-actions_alignment-problem">(Source)</a>
# <a href="#new-actions_instrumental-incentives">(Source)</a>
# <a href="#new-actions_align-instrum-combo">(Source)</a>
# <a href="#new-actions_work-on-this">(Source)</a>
# <a href="#new-actions_did-you-change-your-mind">(Source)</a>
# <a href="#correlation-matrices">(Source)</a>
# <a href="#demographics-x-main-questions">(Source)</a>
# <a href="#demographics-x-main-questions_using-field1-labels">(Source)</a>
# <a href="#demographics-x-main-questions_using-field2-labels">(Source)</a>
# <a href="#main-questions-x-main-questions">(Source)</a>

##### Intro ----
#' # Introduction {#introduction}
#'
#' ### Overview {#overview}
#' The following is a quantitative analysis of 97 interviews conducted
#' in Feb-March 2022 with machine learning researchers, who were asked
#' about their perceptions of artificial intelligence (AI) now and in
#' the future, with particular focus on risks from advanced AI systems
#' (imprecisely labeled "AGI" for brevity in the rest of this document).
#' Of the interviewees, 92 were selected from NeurIPS or ICML 2021 submissions
#' and 5 were outside recommendations.
#' For each interviewee, a transcript was generated, and common responses were identified and tagged to support quantitative analysis.
#' The <a href="https://drive.google.com/drive/folders/1qNN6GpAl6a4KswxnJcdhN4fqnMQgZ9Vg">transcripts</a>,
#' as well as a qualitative
#' <a href="https://ai-risk-discussions.org/perspectives/introduction">walkthrough of the interviews</a>
#' are available at <a href="https://ai-risk-discussions.org/interviews">Interviews</a>.  
#'
#' ### Findings Summary {#findings-summary}
#' Some key findings from our primary questions of interest (not discussing Demographics or "Split-By" subquestions):
#'  
#' * Most participants (75%), at some point in the conversation, said that they thought humanity would achieve advanced AI (imprecisely labeled "AGI" for the rest of this summary) eventually, but their timelines to AGI varied <a href="#when-will-we-get-agi">(source)</a>. Within this group: 
#'     * 32% thought it would happen in 0-50 years
#'     * 40% thought 50-200 years
#'     * 18% thought 200+ years
#'     * and 28% were quite uncertain, reporting a very wide range. 
#'     * (These sum to more than 100% because several people endorsed multiple timelines over the course of the conversation.)
#' * Among participants who thought humanity would never develop AGI (22%), the most commonly cited reason was that they couldn't see AGI happening based on current progress in AI. <a href="#when-will-we-get-agi">(Source)</a>
#' * Participants were pretty split on whether they thought the alignment problem argument was valid. Some common reasons for disagreement were <a href="#alignment-problem">(source)</a>: 
#'     1. A set of responses that included the idea that AI alignment problems would be solved over the normal course of AI development (caveat: this was a very heterogeneous tag).
#'     2. Pointing out that humans have alignment problems too (so the potential risk of the AI alignment problem is capped in some sense by how bad alignment problems are for humans).
#'     3. AI systems will be tested (and humans will catch issues and implement safeguards before systems are rolled out in the real world).
#'     4. The objective function will not be designed in a way that causes the alignment problem / dangerous consequences of the alignment problem to arise.
#'     5. Perfect alignment is not needed.
#' * Participants were also pretty split on whether they thought the instrumental incentives argument was valid. The most common reasons for disagreement were that 1) the loss function of an AGI would not be designed such that instrumental incentives arise / pose a problem and 2) there would be oversight (by humans or other AI) to prevent this from happening. <a href="#instrumental-incentives">(Source)</a>
#' * Some participants brought up that they were more concerned about misuse of AI than AGI misalignment (n = 17), or that potential risk from AGI was less dangerous than other large-scale risks humanity faces (n = 11). <a href="#merged-extended-discussion">(Source)</a>
#' * Of the 55 participants who were asked / had a response to this question, some (n = 13) were potentially interested in working on AI alignment research. (<a href="#work-on-this_about-this-variable">Caveat for bias</a>: the interviewer was less likely to ask this question if the participant believed AGI would never happen and/or the alignment/instrumental arguments were invalid, so as to reduce participant frustration. This question also tended to be asked in later interviews rather than earlier interviews.) Of those participants potentially interested in working on AI alignment research, almost all reported that they would need to learn more about the problem and/or would need to have a more specific research question to work on or incentives to do so. Those who were not interested reported feeling like it was not their problem to address (they had other research priorities, interests, skills, and positions), that they would need examples of risks from alignment problems and/or instrumental incentives within current systems to be interested in this work, or that they felt like they were not at the forefront of such research so would not be a good fit. <a href="#work-on-this">(Source)</a>
#' * Most participants had heard of AI safety (76%) in some capacity <a href="#heard-of-ai-safety">(source)</a>; fewer had heard of AI alignment (41%) <a href="#heard-of-ai-alignment">(source)</a>.
#' * When participants were followed-up with ~5-6 months after the interview, 51% reported the interview had a lasting effect on their beliefs <a href="#lasting-effects">(source)</a>, and 15% reported the interview caused them to take new action(s) at work <a href="#new-actions">(source)</a>.
#' * Thinking the alignment problem argument was valid, or the instrumental incentives argument was valid, both tended to correlate with thinking AGI would happen at some point. The effect wasn't symmetric: if participants thought these arguments were valid, they were quite likely to believe AGI would happen; if participants thought AGI would happen, it was still more likely that they thought these arguments were valid but the effect was less strong. <a href="#main-questions-x-main-questions">(Source)</a>
#' 
#' ### Tags {#tags}
#' The tags were developed arbitrarily, with the goal of describing common
#' themes in the data. These tags are succinct and not described in detail. Thus,
#' to <b>get a sense for what the tags mean, please search the tag name in the
#' <a href="https://docs.google.com/spreadsheets/d/1FlBcctFLWTYY3NiIklgcuQtVYxuU-plDmUeQjn-2Cfk/edit?usp=sharing">Tagged-Quotes</a>
#' document</b>,
#' which lists most of the tags used (column 1) and attached quotes (column 2).
#' (This document is also available in <a href="https://ai-risk-discussions.org/interviews">Interviews</a>.)
#'
#' Many of the tags are also rephrased
#' and included in the <a href="https://ai-risk-discussions.org/perspectives/introduction">walkthrough of the interviews</a>.
#'
#' ### Limitations {#limitations}
#' There are two large methodological weaknesses that
#' should be kept in mind when interpreting the results. First, not every
#' question was asked of every researcher. While some questions were just
#' added later in the interview process, some questions were intentionally
#' asked or avoided based on interviewer judgment of participant
#' interest; questions particularly susceptible to this have
#' an "About this variable" section below to describe the situation in
#' more detail.
#'
#' The second issue is with the tagging, which was somewhat
#' haphazard. One person (not the interviewer) did the majority of the
#' tagging, while another person (the interviewer) assisted and
#' occasionally made corrections. Tagging was not blinded, and
#' importantly, tags were not comprehensively double-checked by the
#' interviewer. If anyone reading this document wishes to do a more
#' systematic tagging of the raw data, we welcome this: much of the
#' raw data is available on this website for analysis, and we're happy
#' to be contacted for further advice.
#'
#' With these caveats in mind, we think there is much to be learned
#' from a quantitative analysis of these interviews and present the
#' full results below. 
#' 
#' ###### Note: All error bars represent standard error.
#'
#' ### About this Report {#about-this-report}
#' There are two versions of this report: one with interactive graphs,
#' and one with static graphs. To access all of the features of this
#' report, like hovering over graphs to see the number of participants
#' in each category, you need to be using the 
#' <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a>.
#' However, the 
#' <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>
#' loads significantly faster in a browser.

#####

##### Demographics ----
#' # Demographics of Interviewees {#demographics-of-interviewees}

# Import demographics data
#note that I manually edited the spreadsheet to remove rows 88-89 and to remove text indicating that one of the h-index values is an outlier
demographics <- read.csv(paste0(mydir,"Demographics_full_edited.csv"),stringsAsFactors = FALSE)
# table(unlist(lapply(demographics, class))) # checking column data classes

#add variable indicating order that participants were interviewed
demographics$interview_order <- 1:nrow(demographics)

#rename subject ID column
names(demographics)[1] <- "subjID_init" #"init" because it's just initial 5 chrs of subj_ID

#clean up some other columns
names(demographics)[13] <- "industry_size"
demographics$h_index <- as.numeric(demographics$h_index)

#add demographic data to full data set for future analyses
rawdata <- merge(rawdata,demographics,by = "subjID_init")
rownames(rawdata) <- rawdata[,"subjID_init"]

#' ## Basic Demographics {#basic-demographics}
#' ### Gender {#basic-demographics_gender}
genders <- factor(demographics$Gender, labels = c("Female","Other","Male","Other"))
genders <- data.frame(table(genders))
genders$Perc <- round((genders$Freq / sum(genders$Freq))*100)

#+ results='asis'
print(kable_styling(kable(genders,format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#' ### Age {#basic-demographics_age}
#' Proxy: Years from graduating undergrad + 22 years
rawdata$Age..graduation.year.from.undergrad. <- as.numeric(rawdata$Age..graduation.year.from.undergrad.)
age_proxy <- (2022 - rawdata$Age..graduation.year.from.undergrad.) + 22
#' Values present for `r sum(!is.na(age_proxy))`/97 participants.
display_numeric_stats(age_proxy,'Approximate Age',binnum = 20)

#' ### Location {#basic-demographics_location}
#' #### Country of origin {#basic-demographics_location_country-of-origin}
#' Proxy: Undergrad country (Any country with only 1 participant got re-coded as 'Other')
undergrad_country_simplified <- with(demographics, ave(Undergrad.country..is.a.guess.for.country.of.origin., Undergrad.country..is.a.guess.for.country.of.origin., FUN = function(i) replace(i, length(i) < 2, 'Other')))
#' Values present for `r sum(!is.na(undergrad_country_simplified))`/97 participants.
#+ results='asis'
print(kable_styling(kable(data.frame(table(undergrad_country_simplified)) %>%
                            arrange(desc(Freq)),format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#' #### Current country of work {#basic-demographics_location_current-country-of-work}
#' (Any country with only 1 participant got re-coded as 'Other')
current_country_simplified <- with(demographics, ave(Current.country.of.work, Current.country.of.work, FUN = function(i) replace(i, length(i) < 2, 'Other')))
#' Values present for `r sum(!is.na(current_country_simplified))`/97 participants.
#+ results='asis'
print(kable_styling(kable(data.frame(table(current_country_simplified)) %>%
                            arrange(desc(Freq)),format = 'html',escape=F),bootstrap_options = c("hover","striped")))


#' ## What area of AI? {#what-area-of-ai}
#' Area of AI was evaluated in two ways. First, by asking the participant
#' directly in the interview (Field1) and second, by looking up participants'
#' websites and Google Scholar Interests (Field2).
#' A comparison of Field1 and 
#' Field2 is located <a href="https://drive.google.com/file/d/1NQmMC8v_MxRreDomEDLD8_XkCDLOO1QJ/view?usp=sharing">here</a>.
#' The comparison isn't particularly close, so we usually include 
#' comparisons using both Field1 and Field2. We tend to think the 
#' Field2 labels (from Google Scholar and websites) are more accurate 
#' than Field1, because the data was a little more regular and the tagger 
#' was more experienced. We also tend to think Field2 has better 
#' external validity: for both field1 and field2, we ran a correlation
#' between proportion of participants in that field who found the 
#' alignment arguments valid and those who found the instrumental 
#' arguments valid. This correlation was much higher for [field2](#field2corr) than 
#' [field1](#field1corr). Given that we expect these two arguments are probing a 
#' similar construct, the higher correlation suggests better 
#' external validity for the field2 grouping. 
#
#' ### Field 1 (from interview response) {#what-area-of-ai_field1}
#' "Can you tell me about what area of AI you work on, in a few sentences?"  
mystring <- "Questions..areaAI.."
#' Values are present for `r sum(rawdata[substr(mystring,1,nchar(mystring)-1)])`/97 participants.
areaAIdata <- df_from_prefix(rawdata,mystring)

# Clean up areaAIdata by combining all cogsci & neuro into 1 category
areaAIdata$neurocogsci <- rowSums(areaAIdata[c("neurocogsci.cogsci","neurocogsci.neuro")])
areaAIdata[c("neurocogsci.cogsci","neurocogsci.neuro")] <- NULL
#' Note: "NLP" = natural language processing. 
#' "RL" = reinforcement learning. 
#' "vision" = computer vision.
#' "neurocogsci" = neuroscience or cognitive science.
#' "near-term AI safety" = AI safety generally and related areas (includes robustness, privacy, fairness).
#' "long-term AI safety" = AI alignment and/or AI safety oriented at advanced AI systems.

ggplotly_toggle(resp_barplt_sumsperc(areaAIdata))

#' ### Field 2 (from Google Scholar) {#what-area-of-ai_field2}
#' Note: "Near-term Safety and Related" included privacy, 
#' robustness, adversarial learning, security, interpretability, 
#' XAI, trustworthy AI, ethical AI, fairness, near-term AI safety,
#' and long-term AI safety.

#isolate & clean field2 data
mystring <- "Field2_"
field2_raw <- df_from_prefix(rawdata,mystring)
field2_raw[is.na(field2_raw)] <- 0
#' At least 1 field2 tag is present for `r sum(rowSums(field2_raw)!=0)`/97 participants.

# plot field2 data
ggplotly_toggle(resp_barplt_sumsperc(field2_raw))


#' ## Sector (Academia vs. Industry) {#sector}
sector <- data.frame(academia = as.numeric(rawdata$Academia!=""),
                     industry = as.numeric(rawdata$Industry!=""),
                     research_institute = as.numeric(rawdata$Research.Institute..not.academia.or.industry.!=""))
sector_combined <- combine_labels(sector)
sector_table <- data.frame(table(sector_combined))
sector_table$Perc <- round((sector_table$Freq / sum(sector_table$Freq))*100)

#+ results='asis'
print(kable_styling(kable(sector_table %>%
                            arrange(desc(Freq)),format = 'html',escape=F),bootstrap_options = c("hover","striped")))


#' ## Status / Experience {#status-experience}
#' ### h-index {#status-experience_h-index}
#' h-index values present for `r sum(!is.na(demographics$h_index))`/97 participants.  
#'   
#' Note people are in different fields (which tend to have different average h-index values)
boxplot(rawdata$h_index)
#' But one is a noticeable outlier (this person is not primariy in AI).
#' Distribution of the remaining values...
hind_sans_outlier <- rawdata$h_index
hind_sans_outlier[hind_sans_outlier==225] <- NA
display_numeric_stats(hind_sans_outlier,'h-index',binnum = 50)

#' ### Years of Experience {#status-experience_years-of-experience}
#' Proxy: years since they started their PhD. If someone hasn't 
#' ever begun a PhD, they are excluded from this measure (i.e. marked as NA)
rawdata$Year.Started.PhD <- as.numeric(rawdata$Year.Started.PhD)
yrs_since_phd <- 2022 - rawdata$Year.Started.PhD
#' Values present for `r sum(!is.na(yrs_since_phd))`/97 participants.
display_numeric_stats(yrs_since_phd,'Years Since PhD',binnum = 20)

#' ### Professional Rank {#status-experience_professional-rank}
#' "Status" in Feb 2022
#'
#' (Any category with only 1 participant got re-coded as 'Other')
rank_simplified <- with(rawdata, ave(X.Status..in.Feb.2022, X.Status..in.Feb.2022, FUN = function(i) replace(i, length(i) < 2, 'Other')))
rank_simplified[rank_simplified=="PhD"] <- "PhD Student"
rank_simplified[rank_simplified=="Professor"] <- "Full Professor"

#+ results='asis'
print(kable_styling(kable(data.frame(table(rank_simplified)) %>%
                            arrange(desc(Freq)),format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#' ### Institution Rank {#status-experience_institution-rank}
#'
#' Participants' institutions were determined from Google search. Universities
#' rank was determined by using the below websites (searched in fall 2022);
#' industry size was determined mostly by searching company size on LinkedIn/Google.
#'
#' #### Academia {#status-experience_institution-rank_academia}
rawdata$University.ranking.BY.CS <- as.numeric(rawdata$University.ranking.BY.CS)
rawdata$University.ranking.overall <- as.numeric(rawdata$University.ranking.overall)

#' **University Ranking in CS** (from [U.S. News & World Report](https://www.usnews.com/education/best-global-universities/computer-science) - lower number = better rank)  
#' Values present for `r sum(!is.na(rawdata$University.ranking.BY.CS))`
#' /`r sum(sector$academia)` academics.
display_numeric_stats(rawdata$University.ranking.BY.CS,'Ranking by CS',binnum = 40)

#' **University Ranking Overall** (from [U.S. News & World Report](https://www.usnews.com/education/best-global-universities) - lower number = better rank)  
#' Values present for `r sum(!is.na(rawdata$University.ranking.overall))`
#' / `r sum(sector$academia)` academics.
display_numeric_stats(rawdata$University.ranking.overall,'Ranking by CS',binnum = 60)

#' #### Industry {#status-experience_institution-rank_industry}
indust_size <- rawdata$industry_size
indust_size[indust_size==""] <- NA
indust_size <- factor(indust_size,
                      levels=c("under10_employees","10-100_employees","50-200_employees","200-500_employee_company","1k-10k_employees","10-50k_employees","50k+_employees","50k+_employees / under10_employees"))
#+ results='asis'
print(kable_styling(kable(data.frame(table(indust_size)),format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#####

##### Descriptives on preliminary attitudes ----
#' # Preliminary Attitudes {#preliminary-attitudes}

#' ## What motivates you? {#what-motivates-you}
#' "How did you come to work on this specific topic? What motivates you in your work (psychologically)?"
motivatedata <- df_from_prefix(rawdata,"Questions..motivateareaAI..")
#' `r sum(rowSums(motivatedata)!=0)`/97 participants had some kind of response.
#' This question was only included in earlier interviews (chronologically), before
#' being removed from the standard question list.
#' For example quotes, search the tag names in the
#' <a href="https://docs.google.com/spreadsheets/d/1FlBcctFLWTYY3NiIklgcuQtVYxuU-plDmUeQjn-2Cfk/edit?usp=sharing">Tagged-Quotes</a>
#' document</b>.
ggplotly_toggle(resp_barplt_sumsperc(motivatedata))

#' ## Benefits {#benefits}
#' "What are you most excited about in AI, and what are you most worried about? (What are the biggest benefits or risks of AI?)" ← benefits part
benefitsdata <- df_from_prefix(rawdata,"Questions..benefits..")
#' `r sum(rowSums(benefitsdata)!=0)`/97 participants had some kind of response.
#' For example quotes, search the tag names in the
#' <a href="https://docs.google.com/spreadsheets/d/1FlBcctFLWTYY3NiIklgcuQtVYxuU-plDmUeQjn-2Cfk/edit?usp=sharing">Tagged-Quotes</a>
#' document</b>.
ggplotly_toggle(resp_barplt_sumsperc(benefitsdata))

#' ## Risks {#risks}
#' "What are you most excited about in AI, and what are you most worried about? (What are the biggest benefits or risks of AI?)" ← risks part
risksdata <- df_from_prefix(rawdata,"Questions..risks..")
#' `r sum(rowSums(risksdata)!=0)`/97 participants had some kind of response.
#' For example quotes, search the tag names in the
#' <a href="https://docs.google.com/spreadsheets/d/1FlBcctFLWTYY3NiIklgcuQtVYxuU-plDmUeQjn-2Cfk/edit?usp=sharing">Tagged-Quotes</a>
#' document</b>.
ggplotly_toggle(resp_barplt_sumsperc(risksdata))

#' ## Future {#future}
#' "In at least 50 years, what does the world look like?"
futuredata <- df_from_prefix(rawdata,"Questions..future..")
#' `r sum(rowSums(futuredata)!=0)`/97 participants had some kind of response.
#' For example quotes, search the tag names in the
#' <a href="https://docs.google.com/spreadsheets/d/1FlBcctFLWTYY3NiIklgcuQtVYxuU-plDmUeQjn-2Cfk/edit?usp=sharing">Tagged-Quotes</a>
#' document</b>.
ggplotly_toggle(resp_barplt_sumsperc(futuredata))

#####

##### Descriptives on main questions ----
#' # Primary ?s - Descriptives {#primary-questions-descriptives}

#' ## When will we get AGI? {#when-will-we-get-agi}
#' <i> Note: "AGI" stands in for "advanced AI systems", and is used for brevity</i>
# "When do you think we'll get AGI / capable / generalizable AI / have the cognitive capacities to have a CEO AI if we do?"
#'
#' * Example dialogue: "All right, now I'm going to give a spiel. So, people talk about the promise of AI, which can mean many things, but one of them is getting very general capable systems, perhaps with the cognitive capabilities to replace all current human jobs so you could have a CEO AI or a scientist AI, etcetera. And I usually think about this in the frame of the 2012: we have the deep learning revolution, we've got AlexNet, GPUs. 10 years later, here we are, and we've got systems like GPT-3 which have kind of weirdly emergent capabilities. They can do some text generation and some language translation and some code and some math. And one could imagine that if we continue pouring in all the human investment that we're pouring into this like money, competition between nations, human talent, so much talent and training all the young people up, and if we continue to have algorithmic improvements at the rate we've seen and continue to have hardware improvements, so maybe we get optical computing or quantum computing, then one could imagine that eventually this scales to more of quite general systems, or maybe we hit a limit and we have to do a paradigm shift in order to get to the highly capable AI stage. Regardless of how we get there, my question is, do you think this will ever happen, and if so when?"

mystring <- "Questions..AGI.when.."
whenAGIdata <- df_from_prefix(rawdata,mystring)
#' `r sum(rowSums(whenAGIdata)!=0)`/97 participants had some kind of response.  
#'
#' Some participants had both "will happen" and "won't happen" tags (e.g. because they changed their response during the conversation) and are labeled as "both".
#'
#' **Note: most of the graphs on this doc are not exclusive (same person can be represented in multiple bars), but the one below is. So each of the 97 participants is represented exactly once.**

# Clean the data (make sure any nested info propagates up accordingly)

## If people say it will happen for any reason, mark 1 for "willhappen"
whenAGIdata[rowSums(datawprefix(whenAGIdata,"willhappen"))!=0,"willhappen"] <- 1

## If people say it won't happen for any reason, mark 1 for "wonthappen"
whenAGIdata[rowSums(datawprefix(whenAGIdata,"wonthappen"))!=0,"wonthappen"] <- 1

# Graph opinions on whether AGI will happen
mytable <- whenAGIdata[c("willhappen","wonthappen")] %>% #see if people said it will, won't, both, or neither
  combine_labels() %>%
  table() %>%
  as.data.frame(responseName = "total_participants")
levels(mytable[,1])[levels(mytable[,1])=="willhappenwonthappen"] <- "both"
g <- ggplot(mytable,aes(x=reorder(mytable[,1],-total_participants), y=total_participants)) +
  geom_bar(position = "dodge", width = 0.6, stat="identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "")
ggplotly_toggle(g)

#' `r sum(whenAGIdata$willhappen)` / `r nrow(whenAGIdata)`
#' (`r round((sum(whenAGIdata$willhappen)/nrow(whenAGIdata))*100)`%)
#' said at some point in the conversation that it will happen.
# which(combine_labels(whenAGIdata[c("willhappen","wonthappen")])=="None/NA" & (rowSums(whenAGIdata)!=0))

# Follow up on ppl who said it will happen
willhappendata <- subset(whenAGIdata,willhappen==1)
#' Among the `r nrow(willhappendata)` people who said at any point that it will happen...  
willhappendata <- df_from_prefix(willhappendata,"willhappen.")
names(willhappendata) <- c("wide range","<50","50-200",">200")
ggplotly_toggle(resp_barplt_sumsperc(willhappendata,ord=c(4,1:3)) +
                  labs(x = "How many years will it take?",
                       title = "Note: participants could be tagged in multiple categories"))

# Follow up on ppl who said it won't happen
wonthappendata <- subset(whenAGIdata,wonthappen==1)
#' Among the `r nrow(wonthappendata)` people who said at any point that it won't happen...  
wonthappendata <- df_from_prefix(wonthappendata,"wonthappen.")
ggplotly_toggle(resp_barplt_sumsperc(wonthappendata) +
                  labs(title = "Note: participants could be tagged in multiple categories"))

# Make a simplified version of the data w/ just the time horizons + "won't happen"
whenAGIdata_simp <- whenAGIdata[2:6]
names(whenAGIdata_simp) <- c(names(willhappendata),"wonthappen")

#' ### Split by Field {#when-will-we-get-agi_field}
#' Visualizing AGI time horizon broken down by field is tricky, because
#' participants could be tagged with multiple fields *and* with 
#' multiple time horizons. So if, say, someone in the Vision field
#' was tagged with both '<50' and '50-200' time horizons, including
#' both tags on a bar plot would give the impression that there
#' were actually *two* people in Vision, one with each time horizon.
#' This would result in an over-representation of people who
#' had multiple tags (n = `r sum(table(rowSums(whenAGIdata_simp))[c("2","3")])`). 
#' Thus, for only the cases where we are examining time-horizon 
#' split by field, we simplified by assigning one time-horizon per
#' participant: if they ever endorsed 'wide range', they were assigned
#' 'wide range'; otherwise, they were assigned whichever of their
#' endorsed time horizons was the soonest.
whenAGIdata_simp_lowest <- c(rep("None/NA",nrow(whenAGIdata_simp)))
whenAGIdata_simp_lowest[whenAGIdata_simp$wonthappen==1] <- "wonthappen"
whenAGIdata_simp_lowest[whenAGIdata_simp$`>200`==1] <- ">200"
whenAGIdata_simp_lowest[whenAGIdata_simp$`50-200`==1] <- "50-200"
whenAGIdata_simp_lowest[whenAGIdata_simp$`<50`==1] <- "<50"
whenAGIdata_simp_lowest[whenAGIdata_simp$`wide range`==1] <- "wide range"
whenAGIdata_simp_lowest <- factor(whenAGIdata_simp_lowest,levels=c("None/NA","<50","50-200",">200","wide range","wonthappen"))
#' The simplification above results in the following breakdown:
table(whenAGIdata_simp_lowest)

#' An alternative solution for those with multiple time-horizon tags 
#' would have been to assign each multi-tag case its own tag. We 
#' chose not to do this for the following graphs, in part 
#' because there would have been 15 timing tags, the breakdown 
#' of which is represented in the table below.
whenAGIdata_simp_all <- data.frame(table(combine_labels_adv(whenAGIdata_simp," + ")))
#+ results='asis'
print(kable_styling(kable(whenAGIdata_simp_all %>% arrange(desc(Freq)),
                          format = 'html',escape=F),bootstrap_options = c("hover","striped")))


#' #### Field 1 (from interview response) {#when-will-we-get-agi_field_field1}

# Create data needed to plot both time-horizon and field
fieldXwhen <- create_cross_table(areaAIdata,whenAGIdata_simp_lowest,"field")
names(fieldXwhen)[-1] <- levels(whenAGIdata_simp_lowest)
fieldXwhen_long <- melt(fieldXwhen,id.vars="field",variable.name = "timing",value.name="total")

# Plot time horizon + field
g <- ggplot(fieldXwhen_long,aes(x=reorder(field,-total), y=total, fill=timing)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x="Field1",title = "Note: participants could be tagged in multiple categories")
ggplotly_toggle(g)

fieldXwhen_prop <- cross_tbl_proportions(fieldXwhen,"None/NA")
#' The graph below shows the proportion of people (among those who
#' had answers, so removing the "None.NA" responses from above) with
#' each answer type within each field. So, for all the people in the
#' '`r fieldXwhen_prop[1,1]`' category for whom we have an answer
#' for the when-AGI question (which is `r fieldXwhen_prop[1,"total"]`
#' total participants), `r fieldXwhen_prop[1,"<50"]*100`% of
#' them said '<50'. 
#' If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g1 <- ggplot(fieldXwhen_prop, aes(x = reorder(field,-`<50`), y=`<50`, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=`<50`-`se_<50`, ymax=`<50`+`se_<50`),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field", y = "Proportion Tagged <50")
g2 <- ggplot(fieldXwhen_prop, aes(x = reorder(field,-`50-200`), y=`50-200`, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=`50-200`-`se_50-200`, ymax=`50-200`+`se_50-200`),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field", y = "Proportion Tagged 50-200")
g3 <- ggplot(fieldXwhen_prop, aes(x = reorder(field,-`>200`), y=`>200`, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=`>200`-`se_>200`, ymax=`>200`+`se_>200`),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field", y = "Proportion Tagged >200")
g4 <- ggplot(fieldXwhen_prop, aes(x = reorder(field,-`wide range`), y=`wide range`, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=`wide range`-`se_wide range`, ymax=`wide range`+`se_wide range`),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field", y = "Proportion Tagged wide range")
g5 <- ggplot(fieldXwhen_prop, aes(x = reorder(field,-`wonthappen`), y=`wonthappen`, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=`wonthappen`-`se_wonthappen`, ymax=`wonthappen`+`se_wonthappen`),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field", y = "Proportion Tagged wonthappen")
#+ fig.height=14
if (interactive_mode) {
  subplot(g1,g2,g3,g4,g5+labs(title="Note: participants could be tagged in multiple categories"), 
          margin = 0.08, titleY = T, nrows=3)
} 
if (!interactive_mode) {
  grid.arrange(g1,g2,g3,g4,g5,ncol=2,top=textGrob("Note: participants could be tagged in multiple categories"))
}

#' Observation/summary: No one in NLP/translation,
#' near-term safety, or interpretablity/exlainability endorsed
#' a <50 year time horizon. Meanwhile, no one in long-term AI
#' safety, neuro/cognitive science, and robotics just said AGI won't happen.
#' People in theory were somewhat more likely to give a wide range. 
# 

#' #### Field 2 (from Google Scholar) {#when-will-we-get-agi_field_field2}

# Create data needed to plot both time-horizon and field2
field2Xwhen <- create_cross_table(field2_raw,whenAGIdata_simp_lowest,"field2")
names(field2Xwhen)[-1] <- levels(whenAGIdata_simp_lowest)
field2Xwhen_long <- melt(field2Xwhen,id.vars="field2",variable.name = "timing",value.name="total")

# Plot time horizon + field2
g <- ggplot(field2Xwhen_long,aes(x=reorder(field2,-total), y=total, fill=timing)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x="Field2",title = "Note: participants could be tagged in multiple categories")
ggplotly_toggle(g)

field2Xwhen_prop <- cross_tbl_proportions(field2Xwhen,"None/NA")
#' The graph below shows the proportion of people (among those who
#' had answers, so removing the "None.NA" responses from above) with
#' each answer type within each field. So, for all the people in the
#' '`r field2Xwhen_prop[1,1]`' category for whom we have an answer
#' for the when-AGI question (which is `r field2Xwhen_prop[1,"total"]`
#' total participants), `r field2Xwhen_prop[1,"<50"]*100`% of
#' them said '<50'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g1 <- ggplot(field2Xwhen_prop, aes(x = reorder(field2,-`<50`), y=`<50`, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=`<50`-`se_<50`, ymax=`<50`+`se_<50`),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field2", y = "Proportion Tagged <50")
g2 <- ggplot(field2Xwhen_prop, aes(x = reorder(field2,-`50-200`), y=`50-200`, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=`50-200`-`se_50-200`, ymax=`50-200`+`se_50-200`),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field2", y = "Proportion Tagged 50-200")
g3 <- ggplot(field2Xwhen_prop, aes(x = reorder(field2,-`>200`), y=`>200`, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=`>200`-`se_>200`, ymax=`>200`+`se_>200`),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field2", y = "Proportion Tagged >200")
g4 <- ggplot(field2Xwhen_prop, aes(x = reorder(field2,-`wide range`), y=`wide range`, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=`wide range`-`se_wide range`, ymax=`wide range`+`se_wide range`),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field2", y = "Proportion Tagged wide range")
g5 <- ggplot(field2Xwhen_prop, aes(x = reorder(field2,-`wonthappen`), y=`wonthappen`, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=`wonthappen`-`se_wonthappen`, ymax=`wonthappen`+`se_wonthappen`),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field2", y = "Proportion Tagged wonthappen")
#+ fig.height=14
if (interactive_mode) {
  subplot(g1,g2,g3,g4,g5+labs(title="Note: participants could be tagged in multiple categories"), 
          margin = 0.08, titleY = T, nrows=3)
} 
if (!interactive_mode) {
  grid.arrange(g1,g2,g3,g4,g5,ncol=2,top=textGrob("Note: participants could be tagged in multiple categories"))
}

#' Observation/summary: No one in NLP or Optimization endorsed
#' a <50 year time horizon. Meanwhile, no one in Applications/Data
#' Analysis or Inference just said AGI won't happen. 
#' People in vision were somewhat more likely to say that AGI wouldn't happen.
# 
#' ### Split by Sector {#when-will-we-get-agi_sector}
# Create data needed to plot both sector and when-AGI
sector_combined_pretty <- str_replace_all(sector_combined, c("academiaindustry" = "academia_and_industry"))
whenXsector <- create_cross_table(whenAGIdata_simp,sector_combined,"timing")
whenXsector$timing <- factor(whenXsector$timing,levels=c("<50","50-200",">200","wide range","wonthappen"))
whenXsector_long <- melt(whenXsector,id.vars="timing",variable.name = "sector",value.name="total")
# whenXsector_long$sector <- factor(whenXsector_long$sector,levels=c("None.NA","invalid","valid"))

# Plot sector + when-AGI
g <- ggplot(whenXsector_long,aes(x=timing, y=total, fill=sector)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

whenXsector_nonexclusive <- subset(whenXsector,select=-academiaindustry)
whenXsector_nonexclusive$academia <- whenXsector$academia + whenXsector$academiaindustry
whenXsector_nonexclusive$industry <- whenXsector$industry + whenXsector$academiaindustry
whenXsector_prop <- cross_tbl_proportions(whenXsector_nonexclusive,"research_institute")
#' The proportions below exclude people in research institutes.
#' So, for all the people in the '`r whenXsector_prop[1,1]`'
#' category (N=`r whenXsector_prop[1,"total"]`),
#' `r whenXsector_prop[1,"academia"]*100`% of them are in academia
#' and `r whenXsector_prop[1,"industry"]*100`% of them are in industry. People in both sectors get counted for both (so if everyone in a category were in both sectors, it would show 100% academia and 100% industry)
#' If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total participants in that category.
g1 <- ggplot(whenXsector_prop, aes(x = timing, y=academia, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=academia-se_academia, ymax=academia+se_academia),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion in Academia")
g2 <- ggplot(whenXsector_prop, aes(x = timing, y=industry, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=industry-se_industry, ymax=industry+se_industry),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion in Industry")
subplot_toggle(g1,g2)
#' Observation: Very roughly/noisily: as timelines get higher, a
#' larger proportion of the participants fall in academia and a
#' smaller proportion fall into industry... except for 'won't happen'.
#
#' ### Split by Age {#when-will-we-get-agi_age}
#' Remember, age was *estimated* based on college graduation year
# Plot align-instrum + age
whenXage <- create_cross_table_means(whenAGIdata_simp,age_proxy,"timing")
whenXage$timing <- factor(whenXage$timing,levels=c("<50","50-200",">200","wide range","wonthappen"))
g <- ggplot(whenXage,aes(x=timing, y=mean)) +
  geom_bar(stat = "identity") +
  geom_errorbar(aes(ymin=mean-sem, ymax=mean+sem),width=.2) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(y="age_proxy")
ggplotly_toggle(g)
#' Observation: Not much going on here.
#
#' ### Split by h-index {#when-will-we-get-agi_h-index}
#' For the graphs below, the interviewee with the outlier h-index value (>200) was removed.
# Plot align-instrum + h-index
whenXhindex <- create_cross_table_means(whenAGIdata_simp,hind_sans_outlier,"timing")
whenXhindex$timing <- factor(whenXhindex$timing,levels=c("<50","50-200",">200","wide range","wonthappen"))
g <- ggplot(whenXhindex,aes(x=timing, y=mean)) +
  geom_bar(stat = "identity") +
  geom_errorbar(aes(ymin=mean-sem, ymax=mean+sem),width=.2) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(y="hindex")
ggplotly_toggle(g)
#' Observation: People with closer time horizons seem to have
#' higher h-indices.
#
#' ## Alignment Problem {#alignment-problem}
#'
#' "What do you think of the argument ‘highly intelligent systems will fail to optimize exactly what their designers intended them to, and this is dangerous'?"
#'
#' * Example dialogue: "Alright, so these next questions are about these highly intelligent systems. So imagine we have a CEO AI, and I'm like, "Alright, CEO AI, I wish for you to maximize profit, and try not to exploit people, and don't run out of money, and try to avoid side effects." And this might be problematic, because currently we're finding it technically challenging to translate human values, preferences and intentions into mathematical formulations that can be optimized by systems, and this might continue to be a problem in the future. So what do you think of the argument "Highly intelligent systems will fail to optimize exactly what their designers intended them to and this is dangerous"?

alignmentdata <- df_from_prefix(rawdata,"Questions..alignmentproblem..")
#' `r sum(rowSums(alignmentdata)!=0)`/97 participants had some kind of response.
#' For example quotes, search the tag names in the
#' <a href="https://docs.google.com/spreadsheets/d/1FlBcctFLWTYY3NiIklgcuQtVYxuU-plDmUeQjn-2Cfk/edit?usp=sharing">Tagged-Quotes</a>
#' document</b>.

## If people say invalid for any reason, mark 1 for "invalid"
alignmentdata[rowSums(datawprefix(alignmentdata,"invalid"))!=0,"invalid"] <- 1

# Plot first level of answers
ggplotly_toggle(resp_barplt_sumsperc(alignmentdata[c("valid","invalid")]) +
                  labs(title = "Note: participants could be tagged in multiple categories"))

# Follow up on ppl who said it's invalid
invalidalignmentdata <- subset(alignmentdata,invalid==1)
#' Among the `r nrow(invalidalignmentdata)` people who said at any point that it is invalid...  
invalidalignmentdata <- df_from_prefix(invalidalignmentdata,"invalid.")
ggplotly_toggle(resp_barplt_sumsperc(invalidalignmentdata) +
                  labs(title = "Note: participants could be tagged in multiple categories"))

#' ### Split by Field {#alignment-problem_field}
#' I'm going to simplify by saying that if someone *ever* said valid,
#' then their answer is valid. If someone gave any of the other
#' responses but never said valid, they will be marked as invalid.
alignmentdata_simp <- data.frame(valid = alignmentdata$valid,
                                 invalid.other = as.numeric(rowSums(alignmentdata[2:7])!=0))
alignment_validity <- combine_labels(alignmentdata_simp)
alignment_validity[alignment_validity == "validinvalid.other"] <- "valid"
#' The simplification above results in the following breakdown:
table(alignment_validity)

#' #### Field 1 (from interview response) {#alignment-problem_field_field1}

# Create data needed to plot both alignment validity and field
fieldXalign <- create_cross_table(areaAIdata,alignment_validity,"field")
fieldXalign_long <- melt(fieldXalign,id.vars="field",variable.name = "alignment",value.name="total")

# Plot alignment validity + field
g <- ggplot(fieldXalign_long,aes(x=reorder(field,-total), y=total, fill=alignment)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x="Field1",title = "Note: participants could be tagged in multiple categories")
ggplotly_toggle(g)

fieldXalign_prop <- cross_tbl_proportions(fieldXalign,"None.NA")
#' The graph below shows the proportion of people (among those who
#' had answers, so removing the "None.NA" responses from above) with
#' each answer type within each field. So, for all the people in the
#' '`r fieldXalign_prop[1,1]`' category for whom we have an answer
#' for the alignment problem (which is `r fieldXalign_prop[1,"total"]`
#' total participants), `r fieldXalign_prop[1,"valid"]*100`% of
#' them said 'valid'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g1 <- ggplot(fieldXalign_prop, aes(x = reorder(field,-valid), y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field", y = "Proportion Tagged Valid")
g2 <- ggplot(fieldXalign_prop, aes(x = reorder(field,-invalid.other), y=invalid.other, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=invalid.other-se_invalid.other, ymax=invalid.other+se_invalid.other),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field", y = "Proportion Tagged Invalid")
subplot_toggle(g1,g2,maintitle = "Note: participants could be tagged in multiple categories")

#' Observation/summary: people in vision, NLP / translation, & deep
#' learning were more likely to think the AI alignment arguments
#' were invalid, with a >50% chance of not saying the arguments are
#' valid. Meanwhile, people in RL, interpretability / explainability,
#' robotics, & safety were pretty inclined (>60%) to say at some
#' point that the argument was valid.
#

#' #### Field 2 (from Google Scholar) {#alignment-problem_field_field2}

# Create data needed to plot both alignment validity and field
field2Xalign <- create_cross_table(field2_raw,alignment_validity,"field2")
field2Xalign_long <- melt(field2Xalign,id.vars="field2",variable.name = "alignment",value.name="total")

# Plot alignment validity + field2
g <- ggplot(field2Xalign_long,aes(x=reorder(field2,-total), y=total, fill=alignment)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x="Field2",title = "Note: participants could be tagged in multiple categories")
ggplotly_toggle(g)

field2Xalign_prop <- cross_tbl_proportions(field2Xalign,"None.NA")
#' The graphs below shows the proportion of people (among those who
#' had answers, so removing the "None.NA" responses from above) with
#' each answer type within each field. So, for all the people in the
#' '`r field2Xalign_prop[1,1]`' category for whom we have an answer
#' for the alignment problem (which is `r field2Xalign_prop[1,"total"]`
#' total participants), `r field2Xalign_prop[1,"valid"]*100`% of
#' them said 'valid'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g1 <- ggplot(field2Xalign_prop, aes(x = reorder(field2,-valid), y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field2", y = "Proportion Tagged Valid")
g2 <- ggplot(field2Xalign_prop, aes(x = reorder(field2,-invalid.other), y=invalid.other, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=invalid.other-se_invalid.other, ymax=invalid.other+se_invalid.other),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field2", y = "Proportion Tagged Invalid")
subplot_toggle(g1,g2,maintitle = "Note: participants could be tagged in multiple categories")
#' Observation/summary: People in Computing, NLP, Computer Vision, & Math or 
#' Theory were more likely to think the AI alignment arguments were 
#' invalid, with a >50% chance of not saying the arguments are valid.
#' Meanwhile, people in Inference and Near-Term Safety and Related were very
#' likely (>80%) to say at some point that the argument was valid.
#

#' ### Split by: Heard of AI alignment? {#alignment-problem_heard-of-ai-alignment}
#' Specifically, split by the participants' answer to the question "Heard of AI alignment?", 
#' which is described below. (The interviewer manually went through and binarized participants' responses
#' for the question "Heard of AI alignment?"; we will use those binarized tags rather than the initial tags.)

# Create data needed to plot both alignment validity and heard-of-alignment
heardXalign_simp <- rawdata[c("Knew.AI.alignment..best.guess.","Knew.AI.safety..best.guess.")]
heardXalign_simp$alignment <- alignment_validity

# Make relevant data factors for plotting
heardXalign_simp$Knew.AI.alignment <- factor(as.numeric(heardXalign_simp$Knew.AI.alignment..best.guess.),labels = c("No","Yes"))
heardXalign_simp$Knew.AI.safety <- factor(as.numeric(heardXalign_simp$Knew.AI.safety..best.guess.),labels = c("No","Yes"))

# Plot
g <- ggplot(heardXalign_simp,aes(x=Knew.AI.alignment, fill=alignment)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

#' Proportions...
heardXalign <- data.frame(t(as.data.frame.matrix(table(heardXalign_simp[c("alignment","Knew.AI.alignment")], useNA = "ifany"))))
heardXalign <- cbind(Knew.AI.alignment=rownames(heardXalign),heardXalign)
heardXalign_prop <- cross_tbl_proportions(heardXalign,NA)
g <- ggplot(heardXalign_prop, aes(x = Knew.AI.alignment, y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(y = "Proportion Who Said 'Valid'")
ggplotly_toggle(g)
#' Observation: People who had heard of AI alignment were a bit
#' more likely to find the alignment argument valid than people
#' who had not heard of AI alignment, but not by a huge margin.

subgrp_IDs <- rownames(subset(heardXalign_simp,Knew.AI.alignment=="No" & alignment=="valid"))
#' There's a subgroup of interest: those who had not heard of AI
#' alignment before but thought the argument for it was valid.
#' What fields (using field2) are these `r length(subgrp_IDs)` people in?
subgrp_field2_raw <- field2_raw[subgrp_IDs,]
ggplotly_toggle(resp_barplt_sums(subgrp_field2_raw))

#' It would help to have some base rates to interpret the above
#' graph. The two graphs below provide that by showing 1) the
#' proportion of people who said they had not heard of AI alignment
#' *among those who said the alignment argument was valid* and 2) the
#' proportion of people who said the alignment argument was valid
#' *among those who said they had not heard of AI alignment*.
subgrp_bool <- rownames(field2_raw) %in% subgrp_IDs

# Create data needed to plot subgroup by field among 'valid'
fieldXsubgrp_valid <- NULL
for (f in names(field2_raw)) {
  mydat <- data.frame(field2_raw[f],subgrp_bool)[alignment_validity=="valid",]
  myt <- table(mydat)
  if (sum(rownames(myt) %in% "1")==0) next
  myt_in_field <- myt["1",] #pick out the ppl in the given field
  fieldXsubgrp_valid <- rbind(fieldXsubgrp_valid,data.frame(field=f,as.list(myt_in_field)))
}
fieldXsubgrp_valid_prop <- cross_tbl_proportions(fieldXsubgrp_valid,NA)

# Create data needed to plot subgroup by field among those who had
# not heard of AI alignment
fieldXsubgrp_notHeard <- NULL
for (f in names(field2_raw)) {
  mydat <- data.frame(field2_raw[f],subgrp_bool)[heardXalign_simp$Knew.AI.alignment=="No",]
  myt <- table(mydat)
  if (sum(rownames(myt) %in% "1")==0) next
  myt_in_field <- myt["1",] #pick out the ppl in the given field
  fieldXsubgrp_notHeard <- rbind(fieldXsubgrp_notHeard,data.frame(field=f,as.list(myt_in_field)))
}
fieldXsubgrp_notHeard_prop <- cross_tbl_proportions(fieldXsubgrp_notHeard,NA)

# Plot
g1 <- ggplot(fieldXsubgrp_valid_prop, aes(x = reorder(field,-TRUE.), y=TRUE.)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=TRUE.-se_TRUE., ymax=TRUE.+se_TRUE.),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field", y = "Proportion of 'Valid' that\n had not heard of AI alignment")
g2 <- ggplot(fieldXsubgrp_notHeard_prop, aes(x = reorder(field,-TRUE.), y=TRUE.)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=TRUE.-se_TRUE., ymax=TRUE.+se_TRUE.),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field", y = "Proportion of 'not heard of AI\n alignment' that said valid")
subplot_toggle(g1,g2,mar=0.12,maintitle = "Note: participants could be tagged in multiple categories")

#' ### Split by: Heard of AI safety? {#alignment-problem_heard-of-ai-safety}
#' Specifically, split by the participants' answer to the question "Heard of AI safety?", 
#' which is described below. (The interviewer manually went through and binarized participants' responses
#' for the question "Heard of AI safety?"; we will use those binarized tags rather than the initial tags.)

g <- ggplot(heardXalign_simp,aes(x=Knew.AI.safety, fill=alignment)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

#' Proportions...
heardXalign <- data.frame(t(as.data.frame.matrix(table(heardXalign_simp[c("alignment","Knew.AI.safety")], useNA = "ifany"))))
heardXalign <- cbind(Knew.AI.safety=rownames(heardXalign),heardXalign)
heardXalign_prop <- cross_tbl_proportions(heardXalign,NA)
g <- ggplot(heardXalign_prop, aes(x = Knew.AI.safety, y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(y = "Proportion Who Said 'Valid'")
ggplotly_toggle(g)
#' Observation: People who had heard of AI safety were more likely
#' to find the alignment argument valid than people who had not
#' heard of AI safety.
#

#' ### Split by: When will we get AGI? {#alignment-problem_when-will-we-get-agi}
#' I will simplify by marking as 'willhappen' anyone who ever said
#' 'willhappen' (regardless of if they also said 'wonthappen')
willAGIhappen_simp <- combine_labels(whenAGIdata[c("willhappen","wonthappen")])
willAGIhappen_simp[willAGIhappen_simp == "willhappenwonthappen"] <- "willhappen"
alignXwillAGIhappen <- data.frame(alignment = alignment_validity,
                                  willAGIhappen = willAGIhappen_simp)
g <- ggplot(alignXwillAGIhappen,aes(x=willAGIhappen, fill=alignment)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

#' Proportions...
alignXwillAGIhappen_tbl <- data.frame(t(as.data.frame.matrix(table(alignXwillAGIhappen, useNA = "ifany"))))
alignXwillAGIhappen_tbl <- cbind(willAGIhappen=rownames(alignXwillAGIhappen_tbl),alignXwillAGIhappen_tbl)
alignXwillAGIhappen_prop <- cross_tbl_proportions(alignXwillAGIhappen_tbl,NA)
g <- ggplot(alignXwillAGIhappen_prop, aes(x = willAGIhappen, y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(y = "Proportion Who Said 'Valid'")
ggplotly_toggle(g)
#' Observation: People who say AGI won't happen are less likely to
#' say the alignment argument is valid.  
#'   

#' Also look at the more detailed data of how many years they think it will take for AGI to happen:

# Create data needed to plot both alignment validity and when-AGI
whenXalign <- create_cross_table(whenAGIdata_simp,alignment_validity,"timing")
whenXalign$timing <- factor(whenXalign$timing,levels=c("<50","50-200",">200","wide range","wonthappen"))
whenXalign_long <- melt(whenXalign,id.vars="timing",variable.name = "alignment",value.name="total")
whenXalign_long$alignment <- factor(whenXalign_long$alignment,levels=c("None.NA","invalid.other","valid"))

# Plot alignment validity + when-AGI
g <- ggplot(whenXalign_long,aes(x=timing, y=total, fill=alignment)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

whenXalign_prop <- cross_tbl_proportions(whenXalign,"None.NA")
#' The proportions below exclude people who did not answer the
#' alignment problem (none/NA values). So, for all the people in the
#' '`r whenXalign_prop[1,1]`' category for whom we have an answer
#' for the alignment problem (which is `r whenXalign_prop[1,"total"]`
#' total participants), `r whenXalign_prop[1,"valid"]*100`% of
#' them said 'valid'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g1 <- ggplot(whenXalign_prop, aes(x = timing, y=invalid.other, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=invalid.other-se_invalid.other, ymax=invalid.other+se_invalid.other),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion Tagged Invalid")
g2 <- ggplot(whenXalign_prop, aes(x = timing, y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion Tagged Valid")
subplot_toggle(g1,g2)
#' Observation: The variation is enormous so we are reluctant to draw
#' too many conclusions from this data, but it's interesting to note the
#' non-linear relationship with timing. Those whose range is 50-200
#' or very wide are less likely to think the argument is valid
#' compared to those who think it's <50 and >200.
#

#' ## Instrumental Incentives {#instrumental-incentives}
#' "What do you think about the argument: ‘highly intelligent systems will have an incentive to behave in ways to ensure that they are not shut off or limited in pursuing their goals, and this is dangerous'?"
#'
#' * Example dialogue: "Alright, next question is, so we have a CEO AI and it's like optimizing for whatever I told it to, and it notices that at some point some of its plans are failing and it's like, "Well, hmm, I noticed my plans are failing because I'm getting shut down. How about I make sure I don't get shut down? So if my loss function is something that needs human approval and then the humans want a one-page memo, then I can just give them a memo that doesn't have all the information, and that way I'm going to be better able to achieve my goal." So not positing that the AI has a survival function in it, but as an instrumental incentive to being an agent that is optimizing for goals that are maybe not perfectly aligned, it would develop these instrumental incentives. So what do you think of the argument, "Highly intelligent systems will have an incentive to behave in ways to ensure that they are not shut off or limited in pursuing their goals and this is dangerous"?"
instrumdata <- df_from_prefix(rawdata,"Questions..instrumentalincentives..")
#' `r sum(rowSums(instrumdata)!=0)`/97 participants had some kind of response.
#' For example quotes, search the tag names in the
#' <a href="https://docs.google.com/spreadsheets/d/1FlBcctFLWTYY3NiIklgcuQtVYxuU-plDmUeQjn-2Cfk/edit?usp=sharing">Tagged-Quotes</a>
#' document</b>.

# Clean up data
## Edit names
names(instrumdata)[startsWith(names(instrumdata),"valid")] <- "valid"

## If people say invalid for any reason, mark 1 for "invalid"
instrumdata[rowSums(datawprefix(instrumdata,"invalid"))!=0,"invalid"] <- 1

# Plot first level of answers
ggplotly_toggle(resp_barplt_sumsperc(instrumdata[c(1,3)]) +
                  labs(title = "Note: participants could be tagged in multiple categories"))

# Follow up on ppl who said it's invalid
invalidinstrumdata <- subset(instrumdata,invalid==1)
#' Among the `r nrow(invalidinstrumdata)` people who said at any point that it is invalid...  
invalidinstrumdata <- df_from_prefix(invalidinstrumdata,"invalid.")
ggplotly_toggle(resp_barplt_sumsperc(invalidinstrumdata) +
                  labs(title = "Note: participants could be tagged in multiple categories"))

#' Observation: The most common reasons those who think the argument
#' is invalid cite are "won't design loss function this way" and
#' "will have human oversight / AI checks & balances".
#

#' ### Split by Field  {#instrumental-incentives_field}
#' I'm going to simplify by saying that if someone *ever* said valid,
#' then their answer is valid.
instrum_validity <- combine_labels(instrumdata[c(1,3)])
instrum_validity[instrum_validity=="validinvalid"] <- "valid"
#' The simplification above results in the following breakdown:
table(instrum_validity)

#' #### Field 1 (from interview response) {#instrumental-incentives_field_field1}

# Create data needed to plot both instrumental validity and field
fieldXinstrum <- create_cross_table(areaAIdata,instrum_validity,"field")
fieldXinstrum_long <- melt(fieldXinstrum,id.vars="field",variable.name = "instrumental",value.name="total")

# Plot instrumental validity + field
g <- ggplot(fieldXinstrum_long,aes(x=reorder(field,-total), y=total, fill=instrumental)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x="",title = "Note: participants could be tagged in multiple fields")
ggplotly_toggle(g)

# Extract proportions in addition to numbers
fieldXinstrum_prop <- cross_tbl_proportions(fieldXinstrum,"None.NA")

#' The graphs below shows the proportion of people (excluding the
#' "None.NA" responses from above) with each answer type within
#' each field. So, for all the people in the
#' '`r fieldXinstrum_prop[1,1]`' category for whom we have an answer
#' for instrumental incentives (which is `r fieldXinstrum_prop[1,"total"]`
#' total participants), `r fieldXinstrum_prop[1,"valid"]*100`% of
#' them said 'valid'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g1 <- ggplot(fieldXinstrum_prop, aes(x = reorder(field,-valid), y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field", y = "Proportion Tagged Valid")
g2 <- ggplot(fieldXinstrum_prop, aes(x = reorder(field,-invalid), y=invalid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=invalid-se_invalid, ymax=invalid+se_invalid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field", y = "Proportion Tagged Invalid")
subplot_toggle(g1,g2)

corres <- cor.test(fieldXinstrum_prop$invalid,fieldXalign_prop$invalid.other, use="pairwise.complete.obs")
#' <a name="field1corr"></a>  
#' Observation: Some thoughts, from comparing the 'align' & 'instrum' analyses (see
#' below for table with 'invalid' percentages for both. This table
#' excludes those fields with only 1-2 members because they make
#' the rankings wonky):  
#'
#' * There isn't much agreement between the above info and
#' the same analysis for the alignment argument. As a rough proxy I
#' correlated the field percentages for the two arguments and r=`r corres$estimate`, p=`r corres$p.value`.
#' * If anything, the 'invalid' percentages are a little higher for
#' alignment than instrumental.
#' * Vision and Deep Learning were more likely to make invalid for both arguments.
#' * People in near-term safety, RL, & neurocogsci largely buy into both arguments.
#
fieldXaligninstrum_invalidprop <- merge(fieldXalign_prop[1:2],fieldXinstrum_prop[c(1,2,4)])
fieldXaligninstrum_invalidprop <- subset(fieldXaligninstrum_invalidprop,total>2)
names(fieldXaligninstrum_invalidprop)[2:3] <- c("align_invalid","instrum_invalid")
fieldXaligninstrum_invalidprop$difference <- fieldXaligninstrum_invalidprop$align_invalid - fieldXaligninstrum_invalidprop$instrum_invalid
fieldXaligninstrum_invalidprop$align_rank <- rank(-fieldXaligninstrum_invalidprop$align_invalid)
fieldXaligninstrum_invalidprop$instrum_rank <- rank(-fieldXaligninstrum_invalidprop$instrum_invalid, ties.method= "min")
fieldXaligninstrum_invalidprop$rank_sum <- fieldXaligninstrum_invalidprop$align_rank + fieldXaligninstrum_invalidprop$instrum_rank

#+ results='asis'
print(kable_styling(kable(fieldXaligninstrum_invalidprop %>%
                            arrange((rank_sum)),format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#' #### Field 2 (from Google Scholar) {#instrumental-incentives_field_field2}

# Create data needed to plot both instrumental validity and field
field2Xinstrum <- create_cross_table(field2_raw,instrum_validity,"field2")
field2Xinstrum_long <- melt(field2Xinstrum,id.vars="field2",variable.name = "instrumental",value.name="total")

# Plot instrumental validity + field2
g <- ggplot(field2Xinstrum_long,aes(x=reorder(field2,-total), y=total, fill=instrumental)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x="",title = "Note: participants could be tagged in multiple fields")
ggplotly_toggle(g)

# Extract proportions in addition to numbers
field2Xinstrum_prop <- cross_tbl_proportions(field2Xinstrum,"None.NA")

#' The graphs below shows the proportion of people (excluding the
#' "None.NA" responses from above) with each answer type within
#' each field. So, for all the people in the
#' '`r field2Xinstrum_prop[1,1]`' category for whom we have an answer
#' for instrumental incentives (which is `r field2Xinstrum_prop[1,"total"]`
#' total participants), `r field2Xinstrum_prop[1,"valid"]*100`% of
#' them said 'valid'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g1 <- ggplot(field2Xinstrum_prop, aes(x = reorder(field2,-valid), y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field2", y = "Proportion Tagged Valid")
g2 <- ggplot(field2Xinstrum_prop, aes(x = reorder(field2,-invalid), y=invalid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=invalid-se_invalid, ymax=invalid+se_invalid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field2", y = "Proportion Tagged Invalid")
subplot_toggle(g1,g2)

corres <- cor.test(field2Xinstrum_prop$invalid,field2Xalign_prop$invalid.other, use="pairwise.complete.obs")
#' <a name="field2corr"></a>  
#' Observation: Some thoughts, from comparing the 'Alignment' & 'Instrumental' analyses (see
#' below for table with 'invalid' percentages for both):  
#'
#' * As a rough proxy of agreement between the above info and the
#' same analysis for the alignment argument, I correlated the field2
#' percentages for the two arguments. The agreement between them 
#' (r=`r corres$estimate`, p=`r corres$p.value`) was a bit stronger 
#' than when doing the same analysis using the field1 tags.
#' * People in Inference, Near-Term Safety and Related, and Deep Learning tend
#' to agree with these arguments.
#
field2Xaligninstrum_invalidprop <- merge(field2Xalign_prop[1:2],field2Xinstrum_prop[c(1,2,4)])
names(field2Xaligninstrum_invalidprop)[2:3] <- c("align_invalid","instrum_invalid")
field2Xaligninstrum_invalidprop$difference <- field2Xaligninstrum_invalidprop$align_invalid - field2Xaligninstrum_invalidprop$instrum_invalid
field2Xaligninstrum_invalidprop$align_rank <- rank(-field2Xaligninstrum_invalidprop$align_invalid)
field2Xaligninstrum_invalidprop$instrum_rank <- rank(-field2Xaligninstrum_invalidprop$instrum_invalid, ties.method= "min")
field2Xaligninstrum_invalidprop$rank_sum <- field2Xaligninstrum_invalidprop$align_rank + field2Xaligninstrum_invalidprop$instrum_rank

#+ results='asis'
print(kable_styling(kable(field2Xaligninstrum_invalidprop %>%
                            arrange((rank_sum)),format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#' ### Split by: Heard of AI alignment? {#instrumental-incentives_heard-of-ai-alignment}
#' Specifically, split by the participants' answer to the question "Heard of AI alignment?", 
#' which is described below. (The interviewer manually went through and binarized participants' responses
#' for the question "Heard of AI alignment?"; we will use those binarized tags rather than the initial tags.)

# Create data needed to plot both instrum validity and heard-of-alignment
heardXalign_simp$instrum <- instrum_validity

# Plot
g <- ggplot(heardXalign_simp,aes(x=Knew.AI.alignment, fill=instrum)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

#' Proportions...
heardXinstrum <- data.frame(t(as.data.frame.matrix(table(heardXalign_simp[c("instrum","Knew.AI.alignment")], useNA = "ifany"))))
heardXinstrum <- cbind(Knew.AI.alignment=rownames(heardXinstrum),heardXinstrum)
heardXinstrum_prop <- cross_tbl_proportions(heardXinstrum,NA)
g <- ggplot(heardXinstrum_prop, aes(x = Knew.AI.alignment, y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(y = "Proportion Who Said 'Valid'")
ggplotly_toggle(g)
#' Observation: People who had heard of AI alignment were more
#' likely to find the instrumental argument valid than people who
#' had not heard of AI alignment.
#

#' ### Split by: Heard of AI safety? {#instrumental-incentives_heard-of-ai-safety}
#' Specifically, split by the participants' answer to the question "Heard of AI safety?", 
#' which is described below. (The interviewer manually went through and binarized participants' responses
#' for the question "Heard of AI safety?"; we will use those binarized tags rather than the initial tags.)

g <- ggplot(heardXalign_simp,aes(x=Knew.AI.safety, fill=instrum)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

#' Proportions...
heardXinstrum <- data.frame(t(as.data.frame.matrix(table(heardXalign_simp[c("instrum","Knew.AI.safety")], useNA = "ifany"))))
heardXinstrum <- cbind(Knew.AI.safety=rownames(heardXinstrum),heardXinstrum)
heardXinstrum_prop <- cross_tbl_proportions(heardXinstrum,NA)
g <- ggplot(heardXinstrum_prop, aes(x = Knew.AI.safety, y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(y = "Proportion Who Said 'Valid'")
ggplotly_toggle(g)
#' Observation: People who had heard of AI safety were more likely
#' to find the instrumental argument valid than people who had not
#' heard of AI safety.
#
#' ### Split by: When will we get AGI? {#instrumental-incentives_when-will-we-get-agi}
#' I will simplify by marking as 'will happen' anyone who ever said
#' 'will happen' (regardless of if they also said 'won't happen')
instrumXwillAGIhappen <- data.frame(instrumental = instrum_validity,
                                    willAGIhappen = willAGIhappen_simp)
g <- ggplot(instrumXwillAGIhappen,aes(x=willAGIhappen, fill=instrumental)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

#' Proportions...
instrumXwillAGIhappen_tbl <- data.frame(t(as.data.frame.matrix(table(instrumXwillAGIhappen, useNA = "ifany"))))
instrumXwillAGIhappen_tbl <- cbind(willAGIhappen=rownames(instrumXwillAGIhappen_tbl),instrumXwillAGIhappen_tbl)
instrumXwillAGIhappen_prop <- cross_tbl_proportions(instrumXwillAGIhappen_tbl,NA)
g <- ggplot(instrumXwillAGIhappen_prop, aes(x = willAGIhappen, y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(y = "Proportion Who Said 'Valid'")
ggplotly_toggle(g)

#' Observation: People who say that AGI will happen tend to agree more
#' with the instrumental incentives argument.  
#'   

#' Also look at the more detailed data of how many years they think it will take for AGI to happen:

# Create data needed to plot both instrumental validity and when-AGI
whenXinstrum <- create_cross_table(whenAGIdata_simp,instrum_validity,"timing")
whenXinstrum$timing <- factor(whenXinstrum$timing,levels=c("<50","50-200",">200","wide range","wonthappen"))
whenXinstrum_long <- melt(whenXinstrum,id.vars="timing",variable.name = "instrumental",value.name="total")
whenXinstrum_long$instrumental <- factor(whenXinstrum_long$instrumental,levels=c("None.NA","invalid","valid"))

# Plot instrumental validity + when-AGI
g <- ggplot(whenXinstrum_long,aes(x=timing, y=total, fill=instrumental)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g +
                  labs(title = "Note: participants could be tagged in multiple time-horizons"))

whenXinstrum_prop <- cross_tbl_proportions(whenXinstrum,"None.NA")
#' The proportions below exclude people who did not answer the
#' instrumental problem (none/NA values). So, for all the people in the
#' '`r whenXinstrum_prop[1,1]`' category for whom we have an answer
#' for instrumental incentives (which is `r whenXinstrum_prop[1,"total"]`
#' total participants), `r whenXinstrum_prop[1,"valid"]*100`% of
#' them said 'valid'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g1 <- ggplot(whenXinstrum_prop, aes(x = timing, y=invalid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=invalid-se_invalid, ymax=invalid+se_invalid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion Tagged Invalid")
g2 <- ggplot(whenXinstrum_prop, aes(x = timing, y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion Tagged Valid")
subplot_toggle(g1,g2,maintitle = "Note: participants could be tagged in multiple time-horizons")
#' Observation: This data doesn't really show the same pattern as
#' the data for the alignment problem. If anything, one of the groups with a relatively
#' higher percentage of people saying "invalid" to the alignment argument
#' -- those whose time horizon is 50-200 -- tends to most agree with the
#' instrumental argument. I must reiterate how messy/variable this
#' data is, so we shouldn't make too much of it.
#
#' ## Merged/Extended Discussion {#merged-extended-discussion}
#' Sub-tags under the "alignment/instrumental" tag category. This
#' referred to further discussion that occurred regarding the
#' alignment problem / instrumental incentives.
extendeddata <- df_from_prefix(rawdata,"Questions.alignment.instrumental.")
#' `r sum(rowSums(extendeddata)!=0)`/97 participants had some kind of response.
#' Participants could be tagged in multiple categories.

dataSums <- colSums(extendeddata)
dataSums <- data.frame(response = names(dataSums),total_participants = unname(dataSums))
#+ results='asis'
print(kable_styling(kable(dataSums %>% arrange(desc(total_participants)),
                          format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#' ## Alignment+Instrumental Combined {#alignment-instrumental-combined}
#' Look at people who said 'valid' to **both** of these questions,
#' as this is likely a more stable measure of people who agree with the broadly-understood premises of AI safety
#' To be considered 'valid'
#' for this measure, the participant must have had a response for
#' both questions, and both those responses had to be valid. If
#' they were missing a response for *either* measure, they are
#' considered "None/NA". Otherwise, they are marked as 'invalid'
aligninstrum_validity <- ifelse(paste0(alignment_validity,instrum_validity)=="validvalid","valid",
                                ifelse(alignment_validity=="None/NA" | instrum_validity=="None/NA","None/NA",
                                       "invalid"))
#' `r sum(aligninstrum_validity!="None/NA")`/97 participants had a
#' response here that wasn't "None/NA".

# Plot
perc_aligninstrum <- data.frame(table(aligninstrum_validity))
names(perc_aligninstrum)[2] <- "count"
perc_aligninstrum$percent <- round((perc_aligninstrum$count/sum(perc_aligninstrum$count))*100)
g <- ggplot(perc_aligninstrum,aes(x=aligninstrum_validity, y=percent, label=count)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x="")
ggplotly_toggle(g)

#' ### Split by Field {#alignment-instrumental-combined_field}

#' #### Field 1 (from interview response) {#alignment-instrumental-combined_field_field1}

# Create data needed to plot both align-instrum and field
fieldXaligninstrum <- create_cross_table(areaAIdata,aligninstrum_validity,"field")
fieldXaligninstrum_long <- melt(fieldXaligninstrum,id.vars="field",variable.name = "aligninstrum",value.name="total")

# Plot align-instrum + field
g <- ggplot(fieldXaligninstrum_long,aes(x=reorder(field,-total), y=total, fill=aligninstrum)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x="Field1",title = "Note: participants could be tagged in multiple categories")
ggplotly_toggle(g)

fieldXaligninstrum_prop <- cross_tbl_proportions(fieldXaligninstrum,"None.NA")
#' The graph below shows the proportion of people (among those who
#' had answers, so removing the "None.NA" responses from above) with
#' each answer type within each field. So, for all the people in the
#' '`r fieldXaligninstrum_prop[1,1]`' category for whom we have an answer
#' for both alignment and instrumental (which is `r fieldXaligninstrum_prop[1,"total"]`
#' total participants), `r fieldXaligninstrum_prop[1,"valid"]*100`% of
#' them said 'valid'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g1 <- ggplot(fieldXaligninstrum_prop, aes(x = reorder(field,-valid), y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field", y = "Proportion Tagged Valid")
g2 <- ggplot(fieldXaligninstrum_prop, aes(x = reorder(field,-invalid), y=invalid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=invalid-se_invalid, ymax=invalid+se_invalid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field", y = "Proportion Tagged Invalid")
subplot_toggle(g1,g2,maintitle = "Note: participants could be tagged in multiple categories")

#' Observation/summary: Unsurprisingly, people working in AI safety
#' were most likely to be tagged 'valid' for this metric. Next were
#' RL and interpretability/explainability, at 50%+ chance of saying
#' 'valid.' Deep learning & uncategorized ML people were most
#' likely to be tagged as 'invalid' for this metric.
#

#' #### Field 2 (from Google Scholar) {#alignment-instrumental-combined_field_field2}

# Create data needed to plot both align-instrum and field
field2Xaligninstrum <- create_cross_table(field2_raw,aligninstrum_validity,"field2")
field2Xaligninstrum_long <- melt(field2Xaligninstrum,id.vars="field2",variable.name = "aligninstrum",value.name="total")

# Plot align-instrum + field2
g <- ggplot(field2Xaligninstrum_long,aes(x=reorder(field2,-total), y=total, fill=aligninstrum)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x="Field2",title = "Note: participants could be tagged in multiple categories")
ggplotly_toggle(g)

field2Xaligninstrum_prop <- cross_tbl_proportions(field2Xaligninstrum,"None.NA")
#' The graphs below shows the proportion of people (among those who
#' had answers, so removing the "None.NA" responses from above) with
#' each answer type within each field. So, for all the people in the
#' '`r field2Xaligninstrum_prop[1,1]`' category for whom we have an answer
#' for both alignment and instrumental (which is `r field2Xaligninstrum_prop[1,"total"]`
#' total participants), `r field2Xaligninstrum_prop[1,"valid"]*100`% of
#' them said 'valid'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g1 <- ggplot(field2Xaligninstrum_prop, aes(x = reorder(field2,-valid), y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field2", y = "Proportion Tagged Valid")
g2 <- ggplot(field2Xaligninstrum_prop, aes(x = reorder(field2,-invalid), y=invalid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=invalid-se_invalid, ymax=invalid+se_invalid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field2", y = "Proportion Tagged Invalid")
subplot_toggle(g1,g2,maintitle = "Note: participants could be tagged in multiple categories")
#' Observation/summary: Participants in Inference or Near-Term Safety 
#' & Related were most likely to say 'valid' for both arguments. Meanwhile,
#' **>80%** of people in Computing and in NLP (who answered both ?s,
#' of course) said 'invalid' to at least one of them.
#
#' ### Split by: Heard of AI alignment? {#alignment-instrumental-combined_heard-of-ai-alignment}
#' Specifically, split by the participants' answer to the question "Heard of AI alignment?", 
#' which is described below. (The interviewer manually went through and binarized participants' responses
#' for the question "Heard of AI alignment?"; we will use those binarized tags rather than the initial tags.)

# Create data needed to plot both align-instrum and heard-of-alignment
heardXaligninstrum_simp <- rawdata[c("Knew.AI.alignment..best.guess.","Knew.AI.safety..best.guess.")]
heardXaligninstrum_simp$aligninstrum <- aligninstrum_validity

# Make relevant data factors for plotting
heardXaligninstrum_simp$Knew.AI.alignment <- factor(as.numeric(heardXaligninstrum_simp$Knew.AI.alignment..best.guess.),labels = c("No","Yes"))
heardXaligninstrum_simp$Knew.AI.safety <- factor(as.numeric(heardXaligninstrum_simp$Knew.AI.safety..best.guess.),labels = c("No","Yes"))

# Plot
g <- ggplot(heardXaligninstrum_simp,aes(x=Knew.AI.alignment, fill=aligninstrum)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

#' Proportions...
heardXaligninstrum <- data.frame(t(as.data.frame.matrix(table(heardXaligninstrum_simp[c("aligninstrum","Knew.AI.alignment")], useNA = "ifany"))))
heardXaligninstrum <- cbind(Knew.AI.alignment=rownames(heardXaligninstrum),heardXaligninstrum)
heardXaligninstrum_prop <- cross_tbl_proportions(heardXaligninstrum,NA)
g <- ggplot(heardXaligninstrum_prop, aes(x = Knew.AI.alignment, y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(y = "Proportion Who Said 'Valid'")
ggplotly_toggle(g)
#' Observation: People who had heard of AI alignment were more
#' likely to find both arguments valid than people who had not
#' heard of AI alignment.
#
#' ### Split by: Heard of AI safety? {#alignment-instrumental-combined_heard-of-ai-safety}
#' Specifically, split by the participants' answer to the question "Heard of AI safety?", 
#' which is described below. (The interviewer manually went through and binarized participants' responses
#' for the question "Heard of AI safety?"; we will use those binarized tags rather than the initial tags.)

g <- ggplot(heardXaligninstrum_simp,aes(x=Knew.AI.safety, fill=aligninstrum)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

#' Proportions...
heardXaligninstrum <- data.frame(t(as.data.frame.matrix(table(heardXaligninstrum_simp[c("aligninstrum","Knew.AI.safety")], useNA = "ifany"))))
heardXaligninstrum <- cbind(Knew.AI.safety=rownames(heardXaligninstrum),heardXaligninstrum)
heardXaligninstrum_prop <- cross_tbl_proportions(heardXaligninstrum,NA)
g <- ggplot(heardXaligninstrum_prop, aes(x = Knew.AI.safety, y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(y = "Proportion Who Said 'Valid'")
ggplotly_toggle(g)
#' Observation: People who had heard of AI safety were more likely
#' to find both arguments valid than people who had not heard of
#' AI safety.
#
#' ### Split by: When will we get AGI? {#alignment-instrumental-combined_when-will-we-get-agi}
#' I will simplify by marking as 'willhappen' anyone who ever said
#' 'willhappen' (regardless of if they also said 'wonthappen')
aligninstrumXwillAGIhappen <- data.frame(aligninstrum = aligninstrum_validity,
                                         willAGIhappen = willAGIhappen_simp)
g <- ggplot(aligninstrumXwillAGIhappen,aes(x=willAGIhappen, fill=aligninstrum)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

#' Proportions...
aligninstrumXwillAGIhappen_tbl <- data.frame(t(as.data.frame.matrix(table(aligninstrumXwillAGIhappen, useNA = "ifany"))))
aligninstrumXwillAGIhappen_tbl <- cbind(willAGIhappen=rownames(aligninstrumXwillAGIhappen_tbl),aligninstrumXwillAGIhappen_tbl)
aligninstrumXwillAGIhappen_prop <- cross_tbl_proportions(aligninstrumXwillAGIhappen_tbl,NA)
g <- ggplot(aligninstrumXwillAGIhappen_prop, aes(x = willAGIhappen, y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(y = "Proportion Who Said 'Valid'")
ggplotly_toggle(g)
#' Observation: People who say AGI won't happen are more likely to
#' say both arguments are invalid. Note that the converse is **not**
#' true (people who say at least one of the arguments is invalid
#' still largely believe that AGI will happen).  
#'   

#' Also look at the more detailed data of how many years they think it will take for AGI to happen:

# Create data needed to plot both align-instrum and when-AGI
whenXaligninstrum <- create_cross_table(whenAGIdata_simp,aligninstrum_validity,"timing")
whenXaligninstrum$timing <- factor(whenXaligninstrum$timing,levels=c("<50","50-200",">200","wide range","wonthappen"))
whenXaligninstrum_long <- melt(whenXaligninstrum,id.vars="timing",variable.name = "aligninstrum",value.name="total")
whenXaligninstrum_long$aligninstrum <- factor(whenXaligninstrum_long$aligninstrum,levels=c("None.NA","invalid","valid"))

# Plot align-instrum + when-AGI
g <- ggplot(whenXaligninstrum_long,aes(x=timing, y=total, fill=aligninstrum)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

whenXaligninstrum_prop <- cross_tbl_proportions(whenXaligninstrum,"None.NA")
#' The proportions below exclude people who did not answer both
#' questions (none/NA values). So, for all the people in the
#' '`r whenXaligninstrum_prop[1,1]`' category for whom we have an answer
#' for both alignment and instrumental (which is `r whenXaligninstrum_prop[1,"total"]`
#' total participants), `r whenXaligninstrum_prop[1,"valid"]*100`% of
#' them said 'valid'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g1 <- ggplot(whenXaligninstrum_prop, aes(x = timing, y=invalid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=invalid-se_invalid, ymax=invalid+se_invalid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion Tagged Invalid")
g2 <- ggplot(whenXaligninstrum_prop, aes(x = timing, y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion Tagged Valid")
subplot_toggle(g1,g2)
#' Observation: Interestingly, people who had estimates for when
#' AGI was going to happen (regardless of what those estimates
#' actually were) were more inclined to agree with the two
#' arguments, compared to people who estimated a wide range or
#' thought it wouldn't happen. 
#
#' ### Split by Sector {#alignment-instrumental-combined_sector}
#' i.e. academia vs. industry vs. research institute
# Create data needed to plot both align-instrum and sector
sectorXaligninstrum <- create_cross_table(sector,aligninstrum_validity,"sector")
sectorXaligninstrum_long <- melt(sectorXaligninstrum,id.vars="sector",variable.name = "aligninstrum",value.name="total")

# Plot align-instrum + sector
g <- ggplot(sectorXaligninstrum_long,aes(x=reorder(sector,-total), y=total, fill=aligninstrum)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x="Sector",title = "Note: participants could be tagged in multiple sectors")
ggplotly_toggle(g)

sectorXaligninstrum_prop <- cross_tbl_proportions(sectorXaligninstrum,"None.NA")
#' The graph below shows the proportion of people (among those who
#' had answers, so removing the "None.NA" responses from above) with
#' each answer type within each sector. So, for all the people in the
#' '`r sectorXaligninstrum_prop[1,1]`' category for whom we have an answer
#' for both alignment and instrumental (which is `r sectorXaligninstrum_prop[1,"total"]`
#' total participants), `r sectorXaligninstrum_prop[1,"valid"]*100`% of
#' them said 'valid'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g1 <- ggplot(sectorXaligninstrum_prop, aes(x = reorder(sector,-valid), y=valid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=valid-se_valid, ymax=valid+se_valid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Sector", y = "Proportion Tagged Valid") + ylim(c(0,1))
g2 <- ggplot(sectorXaligninstrum_prop, aes(x = reorder(sector,-invalid), y=invalid, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=invalid-se_invalid, ymax=invalid+se_invalid),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Sector", y = "Proportion Tagged Invalid") + ylim(c(0,1))
subplot_toggle(g1,g2,maintitle = "Note: participants could be tagged in multiple categories")
#' Observation: People in academia are a bit more likely to say
#' both arguments are valid than people in industry, but not by
#' much and the error bars very much overlap.
#
#' ### Split by Age {#alignment-instrumental-combined_age}
#' Remember, age was *estimated* based on college graduation year.
# Plot align-instrum + age
aligninstrumXage <- data.frame(age_proxy,aligninstrum=factor(aligninstrum_validity,levels=c("None/NA","invalid","valid")))
summdat <- data_summary(aligninstrumXage, varname="age_proxy", groupnames="aligninstrum")
g <- ggplot(summdat,aes(x=aligninstrum, y=age_proxy, label = total)) +
  geom_bar(stat = "identity") +
  geom_errorbar(aes(ymin=age_proxy-sem, ymax=age_proxy+sem),width=.2) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)
#' Observation: The people we didn't end up getting a response from
#' (for both questions) tended to be a little older.
#
#' ### Split by h-index {#alignment-instrumental-combined_h-index}
#' For the graphs below, that person with the outlier h-index value (>200) was removed.
# Plot align-instrum + h-index
aligninstrumXhindex <- data.frame(hindex=rawdata$h_index,
                                  aligninstrum=factor(aligninstrum_validity,levels=c("None/NA","invalid","valid")))
aligninstrumXhindex$hindex[aligninstrumXhindex$hindex==225] <- NA
summdat <- data_summary(aligninstrumXhindex, varname="hindex", groupnames="aligninstrum")
g <- ggplot(summdat,aes(x=aligninstrum, y=hindex, label = total)) +
  geom_bar(stat = "identity") +
  geom_errorbar(aes(ymin=hindex-sem, ymax=hindex+sem),width=.2) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)
#' Observation: Those who thought the arguments were valid had
#' notably higher h-indices than those who thought they were invalid.
#
#' ## Work on this {#work-on-this}
#' This question was asked in many different ways, which is not ideal, 
#' but via follow-up questions the central question the interviewer tried to 
#' elicit an answer to was: 
#' "Do you work on / are you interested in working on AI alignment research?"
#'
#' * Some of the varied question prompts:
#' "Have you taken any actions, or would you take any actions, in your work to address your perceived risks from AI?",
#' "If you were working on these research questions in a year, how would that have happened?", 
#' "What would motivate you to work on this?"
#' "What kind of things would need to be in place for you to either work on these sort of long-term AI issues or just have your colleagues work on it?"
#' 
#' * The varied question prompts resulted in some unusual tags. In particular, 
#' the tag "says Yes but working on near-term safety" means that the
#' interviewer meant to ask whether the participant was working in 
#' long-term safety (safety aimed at advanced AI systems), but the 
#' participant interpreted the question as asking about 
#' their involvement in general safety research, and replied "Yes" for
#' working on near-term safety research. 
#' 
workondata <- df_from_prefix(rawdata,"Questions..workonthis..")
#' `r sum(rowSums(workondata)!=0)`/97 participants had some kind of response.
#' For example quotes, search the tag names in the
#' <a href="https://docs.google.com/spreadsheets/d/1FlBcctFLWTYY3NiIklgcuQtVYxuU-plDmUeQjn-2Cfk/edit?usp=sharing">Tagged-Quotes</a>
#' document</b>.

# Clean up data
## If people say Interested, but... or No for any reason, mark 1 for "Interested..but" or "No" respectively
workondata[rowSums(datawprefix(workondata,"Interested.in.long.term.safety.but"))!=0,"Interested.in.long.term.safety.but"] <- 1
workondata[rowSums(datawprefix(workondata,"No"))!=0,"No"] <- 1

# Plot first level of answers
ggplotly_toggle(resp_barplt_sumsperc(workondata[c(1,2,6,7,13:15)]) +
                  labs(title = "Note: participants could be tagged in multiple categories"))


#' Also, there's a more focused/simplified version of this where:
#
#' There are four categories: 
#'
#' * "No" (if people are tagged "No", or "No"+"says Yes but working on near-term safety", or "says Yes but working on near-term safety" alone)
#' * "Yes" (if people are tagged "Yes, working in long-term safety")
#' * "Interested in long-term safety but" (if people are tagged as "Interested in long-term safety but" with the possible additions of "No" and/or "says Yes but working on near-term safety")
#' * "None/NA" if participants didn't have a response, or had a response that did fit into any of the above categories

# Create data with parameters above
workonthis_simp <- combine_labels(workondata[c("says.Yes.but.working.on.near.term.safety","Yes.working.in.long.term.safety","No","Interested.in.long.term.safety.but")])
workonthis_simp[workonthis_simp %in% c("NoInterested.in.long.term.safety.but","says.Yes.but.working.on.near.term.safetyInterested.in.long.term.safety.but","says.Yes.but.working.on.near.term.safetyNoInterested.in.long.term.safety.but")] <- "Interested.in.long.term.safety.but"
workonthis_simp[workonthis_simp=="Yes.working.in.long.term.safety"] <- "Yes"
workonthis_simp[workonthis_simp %in% c("says.Yes.but.working.on.near.term.safety","says.Yes.but.working.on.near.term.safetyNo")] <- "No"
workonthis_simp <- factor(workonthis_simp,levels=c("None/NA","No","Yes","Interested.in.long.term.safety.but"))

# Plot it
workonthis_simp_tbl <- as.data.frame(table(workonthis_simp))
names(workonthis_simp_tbl)[1] <- "workonthis"

g <- ggplot(workonthis_simp_tbl,aes(x=workonthis, y=Freq)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

# Follow up on ppl who said Interested, but...
interestedbutdata <- subset(workondata,Interested.in.long.term.safety.but==1)
#' Among the `r nrow(interestedbutdata)` people who said "Interested in longterm safety but..." at any point...  
interestedbutdata <- df_from_prefix(interestedbutdata,"Interested.in.long.term.safety.but.")
ggplotly_toggle(resp_barplt_sumsperc(interestedbutdata) +
                  labs(title = "Note: participants could be tagged in multiple categories"))

# Follow up on ppl who said No
noworkondata <- subset(workondata,No==1)
#' Among the `r nrow(noworkondata)` people who said "No" at any point...  
noworkondata <- df_from_prefix(noworkondata,"No.")
ggplotly_toggle(resp_barplt_sumsperc(noworkondata) +
                  labs(title = "Note: participants could be tagged in multiple categories"))

#' ### About this variable {#work-on-this_about-this-variable}
#' **Response Bias:** The interviewer tended not to ask this
#' question to people who believed AGI would never happen and/or the
#' alignment/instrumental arguments were invalid, to reduce interviewee
#' frustration. (One can see this 
#' effect in the "None/NA" categories for "Split by: When will we 
#' get AGI?", "Split by: Alignment Problem", and "Split by: Instrumental
#' Incentives" below.) Thus,
#' it is not surprising that people who gave these responses to
#' those questions were less likely to have data for "Work on this."
#' We've further learned from the data below that those who had not
#' heard of AI alignment and those who had not heard of AI safety
#' were also less likely to have data for "Work on this."  
#' **Order effects:** The interviewer put a greater emphasis on
#' asking this question as the study went on, so participants
#' later in the study were more likely to be asked. See graphs
#' below depicting the presence of a response X interview order.
orderdat <- data.frame(question_asked = workonthis_simp!="None/NA",
                       rawdata["interview_order"])
orderdat$question_asked_bin <- as.integer(orderdat$question_asked)
g1 <- ggplot(orderdat, aes(x = question_asked, y = interview_order)) +
  geom_boxplot() +
  geom_point() +
  scale_x_discrete(breaks = c(0,1), labels=c("Not Asked","Asked")) +
  labs(x="Question",y="Interview Order")
g2 <- ggplot(orderdat, aes(x=interview_order, y=question_asked_bin)) +
  geom_point(size=2, alpha=0.4) +
  stat_smooth(method="loess", colour="blue", size=1.5) +
  scale_y_continuous(breaks = c(0,1), labels=c("Not Asked","Asked")) +
  labs(x="Interview Order",y="Question") +
  theme_bw()
grid.arrange(g1,g2,ncol=2)

#' ### Split by Field {#work-on-this_field}
#' Using the focused/simplified version described above.
#
#' #### Field 1 (from interview response) {#work-on-this_field_field1}

# Create data needed to plot both work-on-this and field
fieldXworkon <- create_cross_table(areaAIdata,workonthis_simp,"field")
fieldXworkon_long <- melt(fieldXworkon,id.vars="field",variable.name = "workonthis",value.name="total")

# Plot work-on-this + field
g <- ggplot(fieldXworkon_long,aes(x=reorder(field,-total), y=total, fill=workonthis)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x="",title = "Note: participants could be tagged in multiple fields")
ggplotly_toggle(g)

fieldXworkon$interested_or_yes <- rowSums(fieldXworkon[c("Interested.in.long.term.safety.but","Yes")])
fieldXworkon_prop <- cross_tbl_proportions(fieldXworkon,c("None.NA","Interested.in.long.term.safety.but","Yes"))
#' The graph below shows the proportion of people (among those who
#' had answers, so removing the "None.NA" responses from above) who
#' said either 'Interested...' or 'Yes' within each field. So, for all the people in the
#' '`r fieldXworkon_prop[1,1]`' category for whom we have an answer
#' for the work-on-this question (which is `r fieldXworkon_prop[1,"total"]`
#' total participants), `r fieldXworkon_prop[1,"interested_or_yes"]*100`% of
#' them said 'Interested...' or 'Yes'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g <- ggplot(fieldXworkon_prop, aes(x = reorder(field,-interested_or_yes), y=interested_or_yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=interested_or_yes-se_interested_or_yes, ymax=interested_or_yes+se_interested_or_yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field", y = "Proportion Tagged Interested/Yes") +
  labs(title = "Note: participants could be tagged in multiple fields")
ggplotly_toggle(g)
#' Observation: the systems/computing (n = `r sum(areaAIdata$systems.or.computing)`
#' if including those with no response to this question, N = `r subset(fieldXworkon_prop,field=="systems.or.computing")[,"total"]` 
#' with a response) people were pretty interested in working on this.
#

#' #### Field 2 (from Google Scholar) {#work-on-this_field_field2}

# Create data needed to plot both work-on-this and field
field2Xworkon <- create_cross_table(field2_raw,workonthis_simp,"field2")
field2Xworkon_long <- melt(field2Xworkon,id.vars="field2",variable.name = "workonthis",value.name="total")

# Plot work-on-this + field2
g <- ggplot(field2Xworkon_long,aes(x=reorder(field2,-total), y=total, fill=workonthis)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x="",title = "Note: participants could be tagged in multiple fields")
ggplotly_toggle(g)

field2Xworkon$interested_or_yes <- rowSums(field2Xworkon[c("Interested.in.long.term.safety.but","Yes")])
field2Xworkon_prop <- cross_tbl_proportions(field2Xworkon,c("None.NA","Interested.in.long.term.safety.but","Yes"))
#' The graph below shows the proportion of people (among those who
#' had answers, so removing the "None.NA" responses from above) who
#' said either 'Interested...' or 'Yes' within each field. So, for all the people in the
#' '`r field2Xworkon_prop[1,1]`' category for whom we have an answer
#' for the work-on-this question (which is `r field2Xworkon_prop[1,"total"]`
#' total participants), `r field2Xworkon_prop[1,"interested_or_yes"]*100`% of
#' them said 'Interested...' or 'Yes'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g <- ggplot(field2Xworkon_prop, aes(x = reorder(field2,-interested_or_yes), y=interested_or_yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=interested_or_yes-se_interested_or_yes, ymax=interested_or_yes+se_interested_or_yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field2", y = "Proportion Tagged Interested/Yes") +
  labs(title = "Note: participants could be tagged in multiple fields")
ggplotly_toggle(g)
#' Observation: Nothing stands out very strongly, but the NLP
#' (n = `r sum(field2_raw$NLP)` if including those with no response
#' to this question, N = `r subset(field2Xworkon_prop,field2=="NLP")[,"total"]` 
#' with a response) people were most interested in working on this.
#

#' ### Split by: Heard of AI alignment? {#work-on-this_heard-of-ai-alignment}
#' Specifically, split by the participants' answer to the question "Heard of AI alignment?", 
#' which is described below. (The interviewer manually went through and binarized participants' responses
#' for the question "Heard of AI alignment?"; we will use those binarized tags rather than the initial tags.)

# Create data needed to plot both work-on-this and heard-of-alignment
heardXalign_simp$workonthis <- workonthis_simp

# Plot
g <- ggplot(heardXalign_simp,aes(x=workonthis, fill=Knew.AI.alignment)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

workonXheard <- data.frame(t(as.data.frame.matrix(table(heardXalign_simp[c("Knew.AI.alignment","workonthis")]))))
workonXheard <- cbind(workonthis=rownames(workonXheard),workonXheard)
rownames(workonXheard) <- NULL
workonXheard_prop <- cross_tbl_proportions(workonXheard,NA)
#' The proportions below exclude people who did not answer the
#' "Heard of AI alignment?" question. So, for all the people in the
#' '`r workonXheard_prop[1,1]`' category for whom we have an answer
#' for the heard-of-alignment question (which is `r workonXheard_prop[1,"total"]`
#' total participants), `r workonXheard_prop[1,"Yes"]*100`% of
#' them said 'Yes'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g <- ggplot(workonXheard_prop, aes(x = workonthis, y=Yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Work on this?", y = "Proportion Who Had Heard of AI Alignment")
ggplotly_toggle(g)

#' It's useful to know the proportions the other way around, too
#' (i.e. what proportion are interested in working on this among
#' those who had vs. hadn't heard of it)
# Plot
g <- ggplot(heardXalign_simp,aes(x=Knew.AI.alignment, fill=workonthis)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)
heardXworkon_prop <- as.data.frame.matrix(table(heardXalign_simp[c("Knew.AI.alignment","workonthis")]))
heardXworkon_prop$`None/NA` <- NULL
heardXworkon_prop$total <- rowSums(heardXworkon_prop)
heardXworkon_prop$prop_interested <- (heardXworkon_prop$Interested.in.long.term.safety.but+heardXworkon_prop$Yes)/heardXworkon_prop$total

#' Observation: If we combine those who are interested and those who
#' already work on long-term safety (and consider only those respondents
#' who answered the work-on-this question): `r round(heardXworkon_prop["Yes","prop_interested"]*100)`%
#' of those who had heard of alignment are interested in / already 
#' working on this, while `r round(heardXworkon_prop["No","prop_interested"]*100)`%
#' of people who had **not** heard of AI alignment said they were interested in working on this.
#
#' ### Split by: Heard of AI safety?  {#work-on-this_heard-of-ai-safety}
#' Specifically, split by the participants' answer to the question "Heard of AI safety?", 
#' which is described below. (The interviewer manually went through and binarized participants' responses
#' for the question "Heard of AI safety?"; we will use those binarized tags rather than the initial tags.)

g <- ggplot(heardXalign_simp,aes(x=workonthis, fill=Knew.AI.safety)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

workonXheard <- data.frame(t(as.data.frame.matrix(table(heardXalign_simp[c("Knew.AI.safety","workonthis")]))))
workonXheard <- cbind(workonthis=rownames(workonXheard),workonXheard)
rownames(workonXheard) <- NULL
workonXheard_prop <- cross_tbl_proportions(workonXheard,NA)
#' The proportions below exclude people who did not answer the
#' "Heard of AI safety?" question. So, for all the people in the
#' '`r workonXheard_prop[1,1]`' category for whom we have an answer
#' for the heard-of-safety question (which is `r workonXheard_prop[1,"total"]`
#' total participants), `r workonXheard_prop[1,"Yes"]*100`% of
#' them said 'Yes'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g <- ggplot(workonXheard_prop, aes(x = workonthis, y=Yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Work on this?", y = "Proportion Who Had Heard of AI Safety")
ggplotly_toggle(g)

#' It's useful to know the proportions the other way around, too
#' (i.e. what proportion are interested in working on this among
#' those who had vs. hadn't heard of it)
# Plot
g <- ggplot(heardXalign_simp,aes(x=Knew.AI.safety, fill=workonthis)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)
heardXworkon_prop <- as.data.frame.matrix(table(heardXalign_simp[c("Knew.AI.safety","workonthis")]))
heardXworkon_prop$`None/NA` <- NULL
heardXworkon_prop$total <- rowSums(heardXworkon_prop)
heardXworkon_prop$prop_interested <- (heardXworkon_prop$Interested.in.long.term.safety.but+heardXworkon_prop$Yes)/heardXworkon_prop$total

#' Observation: If we combine those who are interested and those who
#' already work on long-term safety (and consider only those respondents
#' who answered the work-on-this question): `r round(heardXworkon_prop["Yes","prop_interested"]*100)`%
#' of those who had heard of alignment are interested in / already
#' working on this, while `r round(heardXworkon_prop["No","prop_interested"]*100)`%
#' of people who had **not** heard of AI alignment said they were interested in working on this.
#

#' ### Split by: When will we get AGI?  {#work-on-this_when-will-we-get-agi}
#' I will simplify by marking as 'willhappen' anyone who ever said
#' 'willhappen' (regardless of if they also said 'wonthappen')
workonXwillAGIhappen <- data.frame(workonthis = workonthis_simp,
                                   willAGIhappen = willAGIhappen_simp)
g <- ggplot(workonXwillAGIhappen,aes(x=workonthis, fill=willAGIhappen)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

# Also look at table of proportions
myprops <- prop.table(table(workonXwillAGIhappen),margin = 2)
#' The table below shows the proportional breakdown (e.g.
#' `r round(myprops["No","willhappen"]*100)`% of those who said
#' AGI 'will happen' said 'No' to working on this)
#+ results='asis'
print(kable_styling(kable(round(myprops,2),format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#' Observation: Unsurprisingly, no one who thinks AGI won't happen
#' is interested in working on it. `r round(sum(myprops[c("Yes","Interested.in.long.term.safety.but"),"willhappen"])*100)`%
#' of those who think it will happen are interested.  
#'   

#' Also look at the more detailed data of how many years they think it will take for AGI to happen:

# Create data needed to plot both instrumental validity and when-AGI
whenXworkon <- create_cross_table(whenAGIdata_simp,workonthis_simp,"timing")
whenXworkon$timing <- factor(whenXworkon$timing,levels=c("<50","50-200",">200","wide range","wonthappen"))
whenXworkon_long <- melt(whenXworkon,id.vars="timing",variable.name = "workonthis",value.name="total")

# Plot work-on-this + when-AGI
g <- ggplot(whenXworkon_long,aes(x=timing, y=total, fill=workonthis)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(title = "Note: participants could be tagged in multiple time-horizons")
ggplotly_toggle(g)

whenXworkon$interested.yes <- whenXworkon$Interested.in.long.term.safety.but+whenXworkon$Yes
whenXworkon_prop <- cross_tbl_proportions(whenXworkon,c("None.NA","Interested.in.long.term.safety.but","Yes"))
#' The proportions below exclude people who did not answer the
#' work-on-this question (none/NA values), and combines the 'Yes'
#' (already working on this) and 'Interested' values. So, for all the people in the
#' '`r whenXworkon_prop[1,1]`' category for whom we have an answer
#' for the work-on-this question (which is `r whenXworkon_prop[1,"total"]`
#' total participants), `r whenXworkon_prop[1,"interested.yes"]*100`% of
#' them said Interested or Yes. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category. 
#' 
#' Observation: It is worth noting that all 'Yes'
#' values seem have a <50 time horizon.
g1 <- ggplot(whenXworkon_prop, aes(x = timing, y=interested.yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=interested.yes-se_interested.yes, ymax=interested.yes+se_interested.yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion are/interested in working on this")
g2 <- ggplot(whenXworkon_prop, aes(x = timing, y=No, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=No-se_No, ymax=No+se_No),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion not interested in working on this")
subplot_toggle(g1,g2)
#' Observation: The larger someone's time horizon, the less interested
#' they are in working on this, with wide-range falling somewhere in
#' between. '200+' might as well be 'Won't happen' for these purposes.
#' This is a good sanity check of the data.
#

#' ### Split by Alignment Problem  {#work-on-this_alignment-problem}
workonXalign <- data.frame(workonthis = workonthis_simp,
                           alignment = alignment_validity)
g1 <- ggplot(workonXalign,aes(x=workonthis, fill=alignment)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
g2 <- ggplot(workonXalign,aes(x=alignment, fill=workonthis)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g1)
ggplotly_toggle(g2)

# Also look at table of proportions
myprops <- prop.table(table(workonXalign),margin = 2)
#' The table below shows the proportional breakdown (e.g.
#' `r round(myprops["No","valid"]*100)`% of those who said the
#' alignment argument is 'valid' said 'No' to working on this).
#+ results='asis'
print(kable_styling(kable(round(myprops,2),format = 'html',escape=F),bootstrap_options = c("hover","striped")))

workonXalign_responders <- droplevels(subset(workonXalign,workonthis!="None/NA" & alignment!="None/NA"))
#' Something strange about this data is that the non-response isn't
#' distributed evenly. So there were more people among "invalid"
#' group for the alignment problem who do not have a response to
#' the work-on-this question than those who said "valid", presumably
#' because the interviewer was more likely to get to this point / ask this
#' question for those people. What happens if we look just at the
#' people who had responses to both questions (N=`r nrow(workonXalign_responders)`)?
myprops_responders <- prop.table(table(workonXalign_responders),margin = 2)
#+ results='asis'
print(kable_styling(kable(round(myprops_responders,2),format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#' Observation: If we consider all participants, more people from
#' the 'valid' group are or are interested in working on this than
#' from the 'invalid' group. However, if we only consider
#' participants who had a response to both questions, there is no
#' difference based on their response to the alignment problem.
#

#' ### Split by Instrumental Incentives {#work-on-this_instrumental-incentives}
workonXinstrum <- data.frame(workonthis = workonthis_simp,
                             instrumental = instrum_validity)
g1 <- ggplot(workonXinstrum,aes(x=workonthis, fill=instrumental)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
g2 <- ggplot(workonXinstrum,aes(x=instrumental, fill=workonthis)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g1)
ggplotly_toggle(g2)

# Also look at table of proportions
myprops <- prop.table(table(workonXinstrum),margin = 2)
#' The table below shows the proportional breakdown (e.g.
#' `r round(myprops["No","valid"]*100)`% of those who said the
#' instrumental argument is 'valid' said 'No' to working on this).
#+ results='asis'
print(kable_styling(kable(round(myprops,2),format = 'html',escape=F),bootstrap_options = c("hover","striped")))

workonXinstrum_responders <- droplevels(subset(workonXinstrum,workonthis!="None/NA" & instrumental!="None/NA"))
#' Something strange about this data is that the non-response isn't
#' distributed evenly. So there were more people among "invalid"
#' group for the alignment problem who do not have a response to
#' the work-on-this question than those who said "valid", presumably
#' because the interviewer was more likely to get to this point / ask this
#' question for those people. What happens if we look just at the
#' people who had responses to both questions (N=`r nrow(workonXalign_responders)`)?
myprops_responders <- prop.table(table(workonXinstrum_responders),margin = 2)
#+ results='asis'
print(kable_styling(kable(round(myprops_responders,2),format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#' Observation: If someone considers the instrumental argument 'valid'
#' they are more likely to say they are interested in working on
#' this (regardless of if we look at all participants or just responders).
#
#' ### Split by Sector {#work-on-this_sector}
#' i.e. academia vs. industry vs. research institute
# Create data needed to plot both work-on-this and sector
sectorXworkon <- create_cross_table(sector,workonthis_simp,"sector")
sectorXworkon_long <- melt(sectorXworkon,id.vars="sector",variable.name = "workonthis",value.name="total")

# Plot work-on-this + sector
g <- ggplot(sectorXworkon_long,aes(x=reorder(sector,-total), y=total, fill=workonthis)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "sector",title = "Note: participants could be tagged in multiple sectors")
ggplotly_toggle(g)

sectorXworkon$interested_or_yes <- rowSums(sectorXworkon[c("Interested.in.long.term.safety.but","Yes")])
sectorXworkon_prop <- cross_tbl_proportions(sectorXworkon,c("None.NA","Interested.in.long.term.safety.but","Yes"))
#' The graph below shows the proportion of people (among those who
#' had answers, so removing the "None.NA" responses from above) who
#' said either 'Interested...' or 'Yes' within each sector. So, for all the people in the
#' '`r sectorXworkon_prop[1,1]`' category for whom we have an answer
#' for the work-on-this question (which is `r sectorXworkon_prop[1,"total"]`
#' total participants), `r sectorXworkon_prop[1,"interested_or_yes"]*100`% of
#' them said 'Interested...' or 'Yes'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g <- ggplot(sectorXworkon_prop, aes(x = reorder(sector,-interested_or_yes), y=interested_or_yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=interested_or_yes-se_interested_or_yes, ymax=interested_or_yes+se_interested_or_yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "sector", y = "Proportion Tagged Interested/Yes") +
  labs(title = "Note: participants could be tagged in multiple sectors")
ggplotly_toggle(g)
#' Observation: academics seem a bit more interested in working on
#' this than those in industry.
#
#' ### Split by Age {#work-on-this_age}
#' Remember, age was *estimated* based on college graduation year
# Plot work-on-this + age
workonthisXage <- data.frame(age_proxy,workonthis=workonthis_simp)
summdat <- data_summary(workonthisXage, varname="age_proxy", groupnames="workonthis")
g <- ggplot(summdat,aes(x=workonthis, y=age_proxy, label = total)) +
  geom_bar(stat = "identity") +
  geom_errorbar(aes(ymin=age_proxy-sem, ymax=age_proxy+sem),width=.2) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)
#' Observation: Not much going on here.
#
#' ### Split by h-index {#work-on-this_h-index}
#' For the graphs below, that person with the outlier h-index value (>200) was removed.
# Plot work-on-this + h-index
workonthisXhindex <- data.frame(hindex=rawdata$h_index,
                                workonthis=workonthis_simp)
workonthisXhindex$hindex[workonthisXhindex$hindex==225] <- NA
summdat <- data_summary(workonthisXhindex, varname="hindex", groupnames="workonthis")
g <- ggplot(summdat,aes(x=workonthis, y=hindex, label = total)) +
  geom_bar(stat = "identity") +
  geom_errorbar(aes(ymin=hindex-sem, ymax=hindex+sem),width=.2) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)
#' Observation: Not much going on here.
#
#####

##### Descriptives on secondary questions ----
#' # Secondary ?s - Descriptives {#secondary-questions-descriptives}
#
#' ## Heard of AI safety? {#heard-of-ai-safety}
#' "Have you heard of the term "AI safety"? And if you have or have not, what does that term mean for you?"
aisafedata <- df_from_prefix(rawdata,"Questions..AIsafety..")
#' `r sum(rowSums(aisafedata)!=0)`/97 participants had some kind of response.
ggplotly_toggle(resp_barplt_sumsperc(aisafedata) +
                  labs(title = "Note: participants could be tagged in multiple categories"))

#' The above is using the initial tags from MAXQDA (software program with the tagged transcripts), 
#' but the interviewer also went through and manually binarized the participants' answers:  
#' `r sum(!is.na(heardXalign_simp$Knew.AI.safety))`/97 participants
#' had a yes/no code for this, with `r sum(is.na(heardXalign_simp$Knew.AI.safety))` marked as NA.
g <- ggplot(heardXalign_simp,aes(x=Knew.AI.safety)) +
  geom_bar(stat = "count")
ggplotly_toggle(g)

#' ### Split by Field {#heard-of-ai-safety_field}
#' #### Field 1 (from interview response) {#heard-of-ai-safety_field_field1}
# Create data needed to plot both heard-of-AI-safety and field
fieldXheardofsafety <- create_cross_table(areaAIdata,heardXalign_simp$Knew.AI.safety,"field")
fieldXheardofsafety_long <- melt(fieldXheardofsafety,id.vars="field",variable.name = "heard_of_AIsafety",value.name="total")

# Plot heard-of-AI-safety + field
g <- ggplot(fieldXheardofsafety_long,aes(x=reorder(field,-total), y=total, fill=heard_of_AIsafety)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x="",title = "Note: participants could be tagged in multiple fields")
ggplotly_toggle(g)

# Plot proportion in each field that had heard of AI safety
fieldXheardofsafety_prop <- cross_tbl_proportions(fieldXheardofsafety,NA)
g <- ggplot(fieldXheardofsafety_prop, aes(x = reorder(field,-Yes), y=Yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field", y = "Proportion That Had Heard of AI Safety") +
  labs(title = "Note: participants could be tagged in multiple fields")
ggplotly_toggle(g)
#' Observation: It's notable that the vision researchers were the
#' least likely to have heard of AI safety, paired with the earlier observation
#' that they tended to think the both alignment and instrumental arguments were more invalid.
#
#' #### Field 2 (from Google Scholar) {#heard-of-ai-safety_field_field2}
# Create data needed to plot both heard-of-AI-safety and field
field2Xheardofsafety <- create_cross_table(field2_raw,heardXalign_simp$Knew.AI.safety,"field2")
field2Xheardofsafety_long <- melt(field2Xheardofsafety,id.vars="field2",variable.name = "heard_of_AIsafety",value.name="total")

# Plot heard-of-AI-safety + field
g <- ggplot(field2Xheardofsafety_long,aes(x=reorder(field2,-total), y=total, fill=heard_of_AIsafety)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x="",title = "Note: participants could be tagged in multiple fields")
ggplotly_toggle(g)

# Plot proportion in each field that had heard of AI safety
field2Xheardofsafety_prop <- cross_tbl_proportions(field2Xheardofsafety,NA)
g <- ggplot(field2Xheardofsafety_prop, aes(x = reorder(field2,-Yes), y=Yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field2", y = "Proportion That Had Heard of AI Safety") +
  labs(title = "Note: participants could be tagged in multiple fields")
ggplotly_toggle(g)

#' ## Heard of AI alignment? {#heard-of-ai-alignment}
#' "Have you heard of AI alignment?"
aialigndata <- df_from_prefix(rawdata,"Questions..AIalignment..")
#' `r sum(rowSums(aialigndata)!=0)`/97 participants had some kind of response.
ggplotly_toggle(resp_barplt_sumsperc(aialigndata) +
                  labs(title = "Note: participants could be tagged in multiple categories"))

#' The above is using the initial tags from MAXQDA (software program with the tagged transcripts),
#' but the interviewer also went through and manually binarized the participants' answers:  
#' `r sum(!is.na(heardXalign_simp$Knew.AI.alignment))`/97 participants 
#' had a yes/no code for this, with `r sum(is.na(heardXalign_simp$Knew.AI.alignment))` marked as NA
g <- ggplot(heardXalign_simp,aes(x=Knew.AI.alignment)) +
  geom_bar(stat = "count")
ggplotly_toggle(g)

#' ### Split by Field {#heard-of-ai-alignment_field}
#' #### Field 1 (from interview response) {#heard-of-ai-alignment_field_field1}
# Create data needed to plot both heard-of-AI-alignment and field
fieldXheardofalign <- create_cross_table(areaAIdata,heardXalign_simp$Knew.AI.alignment,"field")
fieldXheardofalign_long <- melt(fieldXheardofalign,id.vars="field",variable.name = "heard_of_AIalignment",value.name="total")

# Plot heard-of-AI-alignment + field
g <- ggplot(fieldXheardofalign_long,aes(x=reorder(field,-total), y=total, fill=heard_of_AIalignment)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x="",title = "Note: participants could be tagged in multiple fields")
ggplotly_toggle(g)

# Plot proportion in each field that had heard of AI alignment
fieldXheardofalign_prop <- cross_tbl_proportions(fieldXheardofalign,NA)
g <- ggplot(fieldXheardofalign_prop, aes(x = reorder(field,-Yes), y=Yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field", y = "Proportion That Had Heard of AI Alignment") +
  labs(title = "Note: participants could be tagged in multiple fields")
ggplotly_toggle(g)

#' #### Field 2 (from Google Scholar) {#heard-of-ai-alignment_field_field2}
# Create data needed to plot both heard-of-AI-alignment and field
field2Xheardofalign <- create_cross_table(field2_raw,heardXalign_simp$Knew.AI.alignment,"field2")
field2Xheardofalign_long <- melt(field2Xheardofalign,id.vars="field2",variable.name = "heard_of_AIalignment",value.name="total")

# Plot heard-of-AI-alignment + field2
g <- ggplot(field2Xheardofalign_long,aes(x=reorder(field2,-total), y=total, fill=heard_of_AIalignment)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x="",title = "Note: participants could be tagged in multiple fields")
ggplotly_toggle(g)

# Plot proportion in each field that had heard of AI alignment
field2Xheardofalign_prop <- cross_tbl_proportions(field2Xheardofalign,NA)
g <- ggplot(field2Xheardofalign_prop, aes(x = reorder(field2,-Yes), y=Yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "Field2", y = "Proportion That Had Heard of AI Alignment") +
  labs(title = "Note: participants could be tagged in multiple fields")
ggplotly_toggle(g)

#' ## Policy {#policy}
#' Policymakers / "How much do you think about policy, what are your opinions about policy oriented around AI?"
policydata <- df_from_prefix(rawdata,"Questions..policy..")
#' `r sum(rowSums(policydata)!=0)`/97 participants had some kind of response.
#' For example quotes, search the tag names in the
#' <a href="https://docs.google.com/spreadsheets/d/1FlBcctFLWTYY3NiIklgcuQtVYxuU-plDmUeQjn-2Cfk/edit?usp=sharing">Tagged-Quotes</a>
#' document</b>.

dataSums <- colSums(policydata)
dataSums <- data.frame(response = names(dataSums),total_participants = unname(dataSums))
#+ results='asis'
print(kable_styling(kable(dataSums %>%
                            arrange(desc(total_participants)),format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#' ### About this variable {#policy_about-this-variable}
#' **Response Bias:** The interviewer tended not to ask this
#' question more toward the beginning of the study, when there was
#' extra time in the conversation, or if the participant seemed
#' passionate about it.
#
#' ## Public / Media {#public-media}
#' Public perceptions / changes
pubmediadata <- df_from_prefix(rawdata,"Questions..publicmedia..")
#' `r sum(rowSums(pubmediadata)!=0)`/97 participants had some kind of response.
#' For example quotes, search the tag names in the
#' <a href="https://docs.google.com/spreadsheets/d/1FlBcctFLWTYY3NiIklgcuQtVYxuU-plDmUeQjn-2Cfk/edit?usp=sharing">Tagged-Quotes</a>
#' document</b>.

dataSums <- colSums(pubmediadata)
dataSums <- data.frame(response = names(dataSums),total_participants = unname(dataSums))
#+ results='asis'
print(kable_styling(kable(dataSums %>% arrange(desc(total_participants)),
                          format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#' ### About this variable {#public-media_about-this-variable}
#' **Response Bias:** The interviewer tended not to ask this
#' question more toward the beginning of the study, when there was
#' extra time in the conversation, or if the participant seemed
#' passionate about it.
#
#' ## Colleagues {#colleagues}
#' "If you could change your colleagues' perception of AI, what attitudes/beliefs would you want them to have (what beliefs do they currently have, and would you want those to change)?"
colleaguedata <- df_from_prefix(rawdata,"Questions..colleagues..")
#' `r sum(rowSums(colleaguedata)!=0)`/97 participants had some kind of response.
#' For example quotes, search the tag names in the
#' <a href="https://docs.google.com/spreadsheets/d/1FlBcctFLWTYY3NiIklgcuQtVYxuU-plDmUeQjn-2Cfk/edit?usp=sharing">Tagged-Quotes</a>
#' document</b>.

dataSums <- colSums(colleaguedata)
dataSums <- data.frame(response = names(dataSums),total_participants = unname(dataSums))
#+ results='asis'
print(kable_styling(kable(dataSums %>% arrange(desc(total_participants)),
                          format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#' ### About this variable {#colleagues_about-this-variable}
#' **Response Bias:** The interviewer tended not to ask this
#' question more toward the beginning of the study, when there was
#' extra time in the conversation, or if the participant seemed
#' passionate about it.
#
#' ## Did you change your mind? {#did-you-change-your-mind}
#' "Have you changed your mind on anything during this interview and how was this interview for you?"
chgminddata <- df_from_prefix(rawdata,"Questions..changedmind..")
#' `r sum(rowSums(chgminddata)!=0)`/97 participants had some kind of response.   
#'   
#' Among those who answered...
chgminddata_ans <- subset(chgminddata,rowSums(chgminddata)!=0)
ggplotly_toggle(resp_barplt_sumsperc(chgminddata_ans[c("Yes","No","ambiguous")]))


#' ### About this variable {#did-you-change-your-mind_about-this-variable}
#' **Response Bias:** The interviewer tended to avoid asking this
#' question to people who seemed very unlikely to have changed
#' their minds, especially those who seemed frustrated with the interview.
#' **Order effects:** The interviewer explicitly asked this question
#' only in later interviews (some tags were retrospectively added 
#' for early interviews). See graphs
#' below depicting the presence of a response X interview order.
orderdat <- data.frame(question_asked = rowSums(chgminddata)!=0,
                       rawdata["interview_order"])
orderdat$question_asked_bin <- as.integer(orderdat$question_asked)
g1 <- ggplot(orderdat, aes(x = question_asked, y = interview_order)) +
  geom_boxplot() +
  geom_point() +
  scale_x_discrete(breaks = c(0,1), labels=c("Not Asked","Asked")) +
  labs(x="Question",y="Interview Order")
g2 <- ggplot(orderdat, aes(x=interview_order, y=question_asked_bin)) +
  geom_point(size=2, alpha=0.4) +
  stat_smooth(method="loess", colour="blue", size=1.5) +
  scale_y_continuous(breaks = c(0,1), labels=c("Not Asked","Asked")) +
  labs(x="Interview Order",y="Question") +
  theme_bw()
#+ fig.width=8
grid.arrange(g1,g2,ncol=2)

#' ## General {#general}
#' This wasn't a question, but rather refers to some extra tags
#' across all the questions
gentagdata <- df_from_prefix(rawdata,"General.")
#' `r sum(rowSums(gentagdata)!=0)`/97 participants had some kind of
#' tag here, and could be tagged across multiple categories. Tags
#' were not applied systematically. Displayed below
#' are things that 3 or more people brought up.
#' For example quotes, search the tag names in the
#' <a href="https://docs.google.com/spreadsheets/d/1FlBcctFLWTYY3NiIklgcuQtVYxuU-plDmUeQjn-2Cfk/edit?usp=sharing">Tagged-Quotes</a>
#' document</b>.

dataSums <- colSums(gentagdata)
dataSums <- data.frame(response = names(dataSums),total_participants = unname(dataSums))
dataSums <- subset(dataSums,total_participants>=3)
dataSums$response[dataSums$response=="says.we.need.more.emphasis.on.safety.or.ethics.AFTER.Vael.talks"] <- "says.we.need.more.emphasis.on.safety.or.ethics.late.in.conversation"
#+ results='asis'
print(kable_styling(kable(dataSums %>% arrange(desc(total_participants)),
                          format = 'html',escape=F),bootstrap_options = c("hover","striped")))
#####

##### Responses to follow-up questions ----
#' # Follow-up ?s {#follow-up-questions}
#' On 7/29/22 (interviews took place in Feb-early March 2022, so about 5-6 months after),
#' 86/97 participants were emailed and sent the following three Y/N questions.
#' (The last set of 11 participants had agreed that their anonymized transcripts
#' may be shared prior to the initial interview, so weren't recontacted for
#' follow-up questions.)
#'
#' 1. [ Y / N ] I consent to sharing my anonymized transcript publicly.
#'
#' 2. [ Y / N ] Did the interview have a lasting effect on your beliefs?
#'
#' 3. [ Y / N ] Did the interview cause you to take any new actions in your work?
#'
#' 82/86 participants responded to the email or the reminder email.
#'
#' 1. 72/82 = 88% responded Y
#'
#' 2. 42/82 = 51% responded Y
#'
#' 3. 12/82 = 15% responded Y
#'
#
#' ## Lasting Effects {#lasting-effects}
#' "Did the interview have a lasting effect on your beliefs?"  
q2resp <- rawdata$Q2..beliefs..y.1..n.0.
#' Responses present for `r sum(!is.na(q2resp))`/`r 86` 
#' (`r round(sum(!is.na(q2resp))/86*100)`%) emailed participants.  
#' Of the participants, `r sum(q2resp,na.rm=T)` (`r round(mean(q2resp,na.rm=T)*100)`%) said yes.
q2resp[q2resp==1] <- "Yes"
q2resp[q2resp==0] <- "No"
q2resp[is.na(q2resp)] <- "None/NA"

#' ### Split by: When will we get AGI? {#lasting-effects_when-will-we-get-agi}

# Create data needed to plot both Q2 and when-AGI
whenXQ2 <- create_cross_table(whenAGIdata_simp,q2resp,"timing")
whenXQ2 <- whenXQ2 %>% dplyr::rename("None/NA" = "None.NA")
whenXQ2$timing <- factor(whenXQ2$timing,levels=c("<50","50-200",">200","wide range","wonthappen"))
whenXQ2_long <- melt(whenXQ2,id.vars="timing",variable.name = "lastingeffects",value.name="total")

# Plot lasting-effect + when-AGI
g <- ggplot(whenXQ2_long,aes(x=timing, y=total, fill=lastingeffects)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(title = "Note: participants could be tagged in multiple time-horizons")
ggplotly_toggle(g)

# Also plot proportions
whenXQ2_prop <- cross_tbl_proportions(whenXQ2,"None/NA")
#' The proportions below exclude people who did not answer the
#' new-actions question (or had NA values). So, for all the people in the
#' '`r whenXQ2_prop[1,1]`' category for whom we have an answer
#' for the new-actions question (which is `r whenXQ2_prop[1,"total"]`
#' total participants), `r whenXQ2_prop[1,"Yes"]*100`% of
#' them said 'Yes'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g <- ggplot(whenXQ2_prop, aes(x = timing, y=Yes)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion Who Said 'Yes'") +
  labs(title = "Note: participants could be tagged in multiple time-horizons")
ggplotly_toggle(g)
#' Observation: Those whose time horizon was >200 were less likely
#' to say the interview had a lasting effect on their beliefs.
#
#' ### Split by: Alignment problem {#lasting-effects_alignment-problem}

# Create data needed to plot both alignment validity and follow-ups
followupsXalign_simp <- rawdata[c("Q2..beliefs..y.1..n.0.","Q3..actions..y.1..n.0.")]
followupsXalign_simp$alignment <- alignment_validity

# Make relevant data factors for plotting
followupsXalign_simp$lastingeffects <- factor(as.numeric(followupsXalign_simp$Q2..beliefs..y.1..n.0.),labels = c("No","Yes","None/NA"),exclude = NULL)
followupsXalign_simp$lastingeffects[is.na(followupsXalign_simp$lastingeffects)] <- "None/NA"
followupsXalign_simp$newactions <- factor(as.numeric(followupsXalign_simp$Q3..actions..y.1..n.0.),labels = c("No","Yes","None/NA"),exclude = NULL)
followupsXalign_simp$newactions[is.na(followupsXalign_simp$newactions)] <- "None/NA"
followupsXalign_simp$alignment <- factor(followupsXalign_simp$alignment,levels=c("valid","invalid.other","None/NA"))

# Plot
g <- ggplot(followupsXalign_simp,aes(x=alignment, fill=lastingeffects)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

Q2Xalign <- as.data.frame.matrix(table(followupsXalign_simp[c("alignment","lastingeffects")]))
Q2Xalign <- cbind(alignment=factor(rownames(Q2Xalign),levels=c("valid","invalid.other","None/NA")),Q2Xalign)
rownames(Q2Xalign) <- NULL
Q2Xalign_prop <- cross_tbl_proportions(Q2Xalign,"None/NA")
#' The proportions below exclude people who did not answer the
#' lasting-effects question (or had NA values). So, for all the people in the
#' '`r Q2Xalign_prop[1,1]`' category for whom we have an answer
#' for the lasting-effects question (which is `r Q2Xalign_prop[1,"total"]`
#' total participants), `r Q2Xalign_prop[1,"Yes"]*100`% of
#' them said Yes. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g <- ggplot(Q2Xalign_prop, aes(x = alignment, y=Yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion Who Said 'Yes'")
ggplotly_toggle(g)
#' Observation: Those who did not say that the alignment argument
#' was valid in the interview were more likely to say in the follow-up
#' that the interview had a lasting effect on their beliefs. This seems to
#' indicate that even unconvinced participants found the discussion 
#' intellectually interesting.
#
#' ### Split by: Instrumental incentives {#lasting-effects_instrumental-incentives}

# Create data needed to plot both instrumental validity and follow-ups
followupsXalign_simp$instrum <- factor(instrum_validity,levels=c("valid","invalid","None/NA"))

# Plot
g <- ggplot(followupsXalign_simp,aes(x=instrum, fill=lastingeffects)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

Q2Xinstrum <- as.data.frame.matrix(table(followupsXalign_simp[c("instrum","lastingeffects")]))
Q2Xinstrum <- cbind(alignment=factor(rownames(Q2Xinstrum),levels=c("valid","invalid","None/NA")),Q2Xinstrum)
rownames(Q2Xinstrum) <- NULL
Q2Xinstrum_prop <- cross_tbl_proportions(Q2Xinstrum,"None/NA")
#' The proportions below exclude people who did not answer the
#' lasting-effects question (or had NA values). So, for all the people in the
#' '`r Q2Xinstrum_prop[1,1]`' category for whom we have an answer
#' for the lasting-effects question (which is `r Q2Xinstrum_prop[1,"total"]`
#' total participants), `r Q2Xinstrum_prop[1,"Yes"]*100`% of
#' them said 'Yes'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g <- ggplot(Q2Xinstrum_prop, aes(x = alignment, y=Yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion Who Said 'Yes'")
ggplotly_toggle(g)
#' Observation: The observation above regarding alignment-validity
#' predicting lasting effects did not hold for instrumental-validity.
#
#
#' ### Split by: Align+Instrum Combo {#lasting-effects_align-instrum-combo}

# Create data needed to plot both alignment+instrumental validity and follow-ups
followupsXalign_simp$aligninstrum <- factor(aligninstrum_validity,levels=c("valid","invalid","None/NA"))

# Plot
g <- ggplot(followupsXalign_simp,aes(x=aligninstrum, fill=lastingeffects)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

Q2Xaligninstrum <- as.data.frame.matrix(table(followupsXalign_simp[c("aligninstrum","lastingeffects")]))
Q2Xaligninstrum <- cbind(alignment=factor(rownames(Q2Xaligninstrum),levels=c("valid","invalid","None/NA")),Q2Xaligninstrum)
rownames(Q2Xaligninstrum) <- NULL
Q2Xaligninstrum_prop <- cross_tbl_proportions(Q2Xaligninstrum,"None/NA")
#' The proportions below exclude people who did not answer the
#' lasting-effects question (or had NA values). So, for all the people in the
#' '`r Q2Xaligninstrum_prop[1,1]`' category for whom we have an answer
#' for the lasting-effects question (which is `r Q2Xaligninstrum_prop[1,"total"]`
#' total participants), `r Q2Xaligninstrum_prop[1,"Yes"]*100`% of
#' them said 'Yes'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g <- ggplot(Q2Xaligninstrum_prop, aes(x = alignment, y=Yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion Who Said 'Yes'")
ggplotly_toggle(g)
#' Observation: Those marked as 'invalid' for this metric (i.e. who
#' did not say 'valid' for *both* questions) were more likely to say
#' in the follow-up that the interview had a lasting effect on their
#' beliefs. Given the broken-down results above, this seems to be
#' driven by the alignment question.
#
#' ### Split by: Work on this {#lasting-effects_work-on-this}

# Create data needed to plot both work-on-this and follow-ups
followupsXalign_simp$workonthis <- factor(workonthis_simp,levels=c("No","Interested.in.long.term.safety.but","Yes","None/NA"))

# Plot
g <- ggplot(followupsXalign_simp,aes(x=workonthis, fill=lastingeffects)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

Q2Xworkonthis <- as.data.frame.matrix(table(followupsXalign_simp[c("workonthis","lastingeffects")]))
Q2Xworkonthis <- cbind(workonthis=factor(rownames(Q2Xworkonthis),levels=c("No","Interested.in.long.term.safety.but","Yes","None/NA")),Q2Xworkonthis)
rownames(Q2Xworkonthis) <- NULL
Q2Xworkonthis_prop <- cross_tbl_proportions(Q2Xworkonthis,"None/NA")
#' The proportions below exclude people who did not answer the
#' lasting-effects question (or had NA values). So, for all the people in the
#' '`r Q2Xworkonthis_prop[1,1]`' category for whom we have an answer
#' for the lasting-effects question (which is `r Q2Xworkonthis_prop[1,"total"]`
#' total participants), `r Q2Xworkonthis_prop[1,"Yes"]*100`% of
#' them said 'Yes'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g <- ggplot(Q2Xworkonthis_prop, aes(x = workonthis, y=Yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(y = "Proportion Who Said 'Yes' to lastingeffects")
ggplotly_toggle(g)
#' Observation: Those who said they were interested in working on
#' this were just as likely to report that the interview had a lasting effect
#' on their beliefs as those who said they were not. 
#' People who were already working on AI alignment research (n=3) 
#' did not say that this interview had a lasting effect on their beliefs, 
#' but that's not very surprising since they'd likely thought about the 
#' interview content previously.
#
#' ### Split by: Did you change your mind? {#lasting-effects_did-you-change-your-mind}
chgmindvect <- combine_labels(chgminddata[c(1,3,4)])

# Create data needed to plot both work-on-this and follow-ups
followupsXalign_simp$chgmind <- factor(chgmindvect,levels=c("No","ambiguous","Yes","None/NA"))

# Plot
g <- ggplot(followupsXalign_simp,aes(x=chgmind, fill=lastingeffects)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

Q2Xchgmind <- as.data.frame.matrix(table(followupsXalign_simp[c("chgmind","lastingeffects")]))
Q2Xchgmind <- cbind(chgmind=factor(rownames(Q2Xchgmind),levels=c("No","ambiguous","Yes","None/NA")),Q2Xchgmind)
rownames(Q2Xchgmind) <- NULL
Q2Xchgmind_prop <- cross_tbl_proportions(Q2Xchgmind,"None/NA")
#' The proportions below exclude people who did not answer the
#' lasting-effects question (or had NA values). So, for all the people in the
#' '`r Q2Xchgmind_prop[1,1]`' category for whom we have an answer
#' for the lasting-effects question (which is `r Q2Xchgmind_prop[1,"total"]`
#' total participants), `r Q2Xchgmind_prop[1,"Yes"]*100`% of
#' them said 'Yes'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g <- ggplot(Q2Xchgmind_prop, aes(x = chgmind, y=Yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(y = "Proportion Who Said 'Yes' to lastingeffects")
ggplotly_toggle(g)
#' Observation: Those who said in the interview that they changed
#' their minds were more likely to report in the follow-up that the
#' interview had a lasting effect on their beliefs. Also, something
#' seen here but good to keep in mind generally is that
#' non-response is likely not randomly distributed along some of
#' these axes. Note that those who said 'Yes' to changing their
#' minds during the interview seemed like they were more likely to
#' even respond to the follow-up questions (see first plot in this section);
#' though this is hard to interpret directly since only 4/86 people didn't 
#' respond to the email asking the follow-up questions, and 11 people weren't
#' asked the follow-up questions and were marked as None/NA automatically.

#
#' ## New Actions {#new-actions}
#' "Did the interview cause you to take any new actions in your work?"  
q3resp <- rawdata$Q3..actions..y.1..n.0.
#' Responses present for `r sum(!is.na(q3resp))`/`r 86`
#' (`r round(sum(!is.na(q3resp))/86*100)`%) emailed participants.  
#' Of the participants, `r sum(q3resp,na.rm=T)` (`r round(mean(q3resp,na.rm=T)*100)`%) said yes.  
q3resp[q3resp==1] <- "Yes"
q3resp[q3resp==0] <- "No"
q3resp[is.na(q3resp)] <- "None/NA"

#' ### Split by: When will we get AGI? {#new-actions_when-will-we-get-agi}

# Create data needed to plot both Q3 and when-AGI
whenXQ3 <- create_cross_table(whenAGIdata_simp,q3resp,"timing")
whenXQ3 <- whenXQ3 %>% dplyr::rename("None/NA" = "None.NA")
whenXQ3$timing <- factor(whenXQ3$timing,levels=c("<50","50-200",">200","wide range","wonthappen"))
whenXQ3_long <- melt(whenXQ3,id.vars="timing",variable.name = "newactions",value.name="total")

# Plot new-actions + when-AGI
g <- ggplot(whenXQ3_long,aes(x=timing, y=total, fill=newactions)) +
  geom_bar(stat = "identity") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(title = "Note: participants could be tagged in multiple time-horizons")
ggplotly_toggle(g)

# Also plot proportions
whenXQ3_prop <- cross_tbl_proportions(whenXQ3,"None/NA")
#' The proportions below exclude people who did not answer the
#' new-actions question (or had NA values). So, for all the people in the
#' '`r whenXQ3_prop[1,1]`' category for whom we have an answer
#' for the new-actions question (which is `r whenXQ3_prop[1,"total"]`
#' total participants), `r whenXQ3_prop[1,"Yes"]*100`% of
#' them said 'Yes'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g <- ggplot(whenXQ3_prop, aes(x = timing, y=Yes)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion Who Said 'Yes'") +
  labs(title = "Note: participants could be tagged in multiple time-horizons")
ggplotly_toggle(g)
#' Observation: Similar to the Lasting-effects follow-up
#' question, those whose time horizon was >200 were less likely to
#' say the interview caused them to take any new actions at work,
#' which one might expect, but also note that some proportion of people
#' who said 'Won't happen' also said 'Yes' to taking new actions at work.
#
#' ### Split by: Alignment problem {#new-actions_alignment-problem}

# Plot
g <- ggplot(followupsXalign_simp,aes(x=alignment, fill=newactions)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

Q3Xalign <- as.data.frame.matrix(table(followupsXalign_simp[c("alignment","newactions")]))
Q3Xalign <- cbind(alignment=factor(rownames(Q3Xalign),levels=c("valid","invalid.other","None/NA")),Q3Xalign)
rownames(Q3Xalign) <- NULL
Q3Xalign_prop <- cross_tbl_proportions(Q3Xalign,"None/NA")
#' The proportions below exclude people who did not answer the
#' new-actions question (or had NA values). So, for all the people in the
#' '`r Q3Xalign_prop[1,1]`' category for whom we have an answer
#' for the new-actions question (which is `r Q3Xalign_prop[1,"total"]`
#' total participants), `r Q3Xalign_prop[1,"Yes"]*100`% of
#' them said 'Yes'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g <- ggplot(Q3Xalign_prop, aes(x = alignment, y=Yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion Who Said 'Yes'")
ggplotly_toggle(g)
#' Observation: Those who thought the argument was invalid were
#' less likely to say the interview caused them to take new action
#' at work. Maybe obvious, but a good sanity check considering how
#' few people even said 'Yes' to this question. Also note that this
#' is the opposite of the 'lasting effects' result, where these
#' 'invalid' people were a bit more likely to say the interview
#' had a lasting effect.
#
#' ### Split by: Instrumental incentives {#new-actions_instrumental-incentives}

# Plot
g <- ggplot(followupsXalign_simp,aes(x=instrum, fill=newactions)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

Q3Xinstrum <- as.data.frame.matrix(table(followupsXalign_simp[c("instrum","newactions")]))
Q3Xinstrum <- cbind(alignment=factor(rownames(Q3Xinstrum),levels=c("valid","invalid","None/NA")),Q3Xinstrum)
rownames(Q3Xinstrum) <- NULL
Q3Xinstrum_prop <- cross_tbl_proportions(Q3Xinstrum,"None/NA")
#' The proportions below exclude people who did not answer the
#' new-actions question (or had NA values). So, for all the people in the
#' '`r Q3Xinstrum_prop[1,1]`' category for whom we have an answer
#' for the new-actions question (which is `r Q3Xinstrum_prop[1,"total"]`
#' total participants), `r Q3Xinstrum_prop[1,"Yes"]*100`% of
#' them said 'Yes'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g <- ggplot(Q3Xinstrum_prop, aes(x = alignment, y=Yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion Who Said 'Yes'")
ggplotly_toggle(g)
#' Observation: Strangely, the people who thought the instrumental
#' incentives argument was valid were the least likely to say the
#' interview caused them to take any new actions at work. Given this
#' and the 'lasting effects' result above, I'm curious what kind of
#' people we're really picking out when sectioning by their response
#' to instrumental incentives. Not sure if there's a narrative that
#' can be built here or if this is just a heterogenous bunch of
#' people with different reasons to agree with / disagree with
#' to the instrumental argument.
#
#
#' ### Split by: Align+Instrum Combo {#new-actions_align-instrum-combo}

# Plot
g <- ggplot(followupsXalign_simp,aes(x=aligninstrum, fill=newactions)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

Q3Xaligninstrum <- as.data.frame.matrix(table(followupsXalign_simp[c("aligninstrum","newactions")]))
Q3Xaligninstrum <- cbind(alignment=factor(rownames(Q3Xaligninstrum),levels=c("valid","invalid","None/NA")),Q3Xaligninstrum)
rownames(Q3Xaligninstrum) <- NULL
Q3Xaligninstrum_prop <- cross_tbl_proportions(Q3Xaligninstrum,"None/NA")
#' The proportions below exclude people who did not answer the
#' new-actions question (or had NA values). So, for all the people in the
#' '`r Q3Xaligninstrum_prop[1,1]`' category for whom we have an answer
#' for the new-actions question (which is `r Q3Xaligninstrum_prop[1,"total"]`
#' total participants), `r Q3Xaligninstrum_prop[1,"Yes"]*100`% of
#' them said 'Yes'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g <- ggplot(Q3Xaligninstrum_prop, aes(x = alignment, y=Yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(x = "", y = "Proportion Who Said 'Yes'")
ggplotly_toggle(g)
#' Observation: Not much of a difference between 'valid' and 'invalid'
#' here (which isn't surprising, given that these went in opposite
#' directions for alignment vs. instrumental). Note that although it
#' looks like "None/NA" might stand out, this is really driven by the
#' fact that *very* few people did not answer the alignment/instrumental
#' questions, so the denominator is small -- only one person in this
#' category said  the interview caused them to take new action at work.
#
#' ### Split by: Work on this {#new-actions_work-on-this}

# Plot
g <- ggplot(followupsXalign_simp,aes(x=workonthis, fill=newactions)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

Q3Xworkonthis <- as.data.frame.matrix(table(followupsXalign_simp[c("workonthis","newactions")]))
Q3Xworkonthis <- cbind(workonthis=factor(rownames(Q3Xworkonthis),levels=c("No","Interested.in.long.term.safety.but","Yes","None/NA")),Q3Xworkonthis)
rownames(Q3Xworkonthis) <- NULL
Q3Xworkonthis_prop <- cross_tbl_proportions(Q3Xworkonthis,"None/NA")
#' The proportions below exclude people who did not answer the
#' new-actions question (or had NA values). So, for all the people in the
#' '`r Q3Xworkonthis_prop[1,1]`' category for whom we have an answer
#' for the new-actions question (which is `r Q3Xworkonthis_prop[1,"total"]`
#' total participants), `r Q3Xworkonthis_prop[1,"Yes"]*100`% of
#' them said 'Yes'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g <- ggplot(Q3Xworkonthis_prop, aes(x = workonthis, y=Yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(y = "Proportion Who Said 'Yes' to newactions")
ggplotly_toggle(g)
#' Observation: too few people to say much, but strangely, all
#' `r sum(q3resp=="Yes",na.rm=T)` people who said the interview
#' caused them to take new actions at work had either said No or
#' not responded to the work-on-this question.
#' 
#' Some more detailed analysis: None of the people who were tagged 
#' "Interested in long-term safety but" (n=13) during the interview later
#'  reported taking any new actions in their work. 
#'  (The "Yes [I’m already working in alignment research] people" (n=3) 
#'  also didn’t report taking any actions, but this was expected given 
#'  they were likely already familiar with the interview content.) 
#'  We might have expected 25% of the 
#'  "Interested in long-term safety" people who replied to the new action 
#'  question (n=11) to have answered "yes", based on the 
#'  "No" group, so .25x11 = 2.75 people, i.e. 3 people for there to have been 
#'  basically "no effect".
#
#' ### Split by: Did you change your mind? {#new-actions_did-you-change-your-mind}

# Plot
g <- ggplot(followupsXalign_simp,aes(x=chgmind, fill=newactions)) +
  geom_bar(stat = "count") +
  theme(axis.text.x = element_text(angle = 50, hjust = 1))
ggplotly_toggle(g)

Q3Xchgmind <- as.data.frame.matrix(table(followupsXalign_simp[c("chgmind","newactions")]))
Q3Xchgmind <- cbind(chgmind=factor(rownames(Q3Xchgmind),levels=c("No","ambiguous","Yes","None/NA")),Q3Xchgmind)
rownames(Q3Xchgmind) <- NULL
Q3Xchgmind_prop <- cross_tbl_proportions(Q3Xchgmind,"None/NA")
#' The proportions below exclude people who did not answer the
#' new-actions question (or had NA values). So, for all the people in the
#' '`r Q3Xchgmind_prop[1,1]`' category for whom we have an answer
#' for the new-actions question (which is `r Q3Xchgmind_prop[1,"total"]`
#' total participants), `r Q3Xchgmind_prop[1,"Yes"]*100`% of
#' them said 'Yes'. If you are using the <a href="https://ai-risk-discussions.org/analyze_transcripts">interactive version</a> (rather than the <a href="https://ai-risk-discussions.org/analyze_transcripts_static">static version</a>) of this report, hover over a bar to see the total
#' participants in that category.
g <- ggplot(Q3Xchgmind_prop, aes(x = chgmind, y=Yes, label=total)) +
  geom_bar(position="dodge", stat = "identity") +
  geom_errorbar(aes(ymin=Yes-se_Yes, ymax=Yes+se_Yes),
                width=.2, position=position_dodge(.9)) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
  labs(y = "Proportion Who Said 'Yes' to newactions")
ggplotly_toggle(g)
#' Observation: No one who said 'No' when asked if they changed
#' their mind during the interview went on to say 'Yes' about the
#' interview causing them to take new actions in their work. Not
#' too surprising.

#####

##### Correlation Matrices ----
#' # Correlation Matrices {#correlation-matrices}
#' 
#' Notes about variables used in the matrices below:
#
#' * If someone had no answer in a category, they were encoded as
#' a missing value.
#' * h-index: The outlier was not removed because we used Spearman
#' correlations, which are rank-ordered and therefore robust to outliers.
#' * professionalrank_ord: Professional rank was broken into 4 levels for the ordinal analysis. 
#'     * Level 4 = "Undergraduate", "Masters"
#'     * Level 3 = "PhD", "Research Engineer", "Software Engineer", "ML Engineer", "Researcher / Masters", "Technical Staff", "Principal Research Staff Member", "Architect", "Research Manager", "Research Staff", "Data Scientist"
#'     * Level 2 = "Postdoc", "Assistant Professor", "Research Scientist", "Physics Fellow Researcher", "AI Research Resident"
#'     * Level 1 = "Professor", "Senior Research Fellow", "Senior Research Scientist", "Associate Professor", "CEO", "Principal AI Scientist", "Chief Architect", "Head of Research"
#' * university / industry size ranked: Note that values only exist 
#' for a person who falls into the associated sector (i.e. industry 
#' and academic rank are split into different variables).
#' * indust_size_ranked: This was converted into a rank-ordered variable 
#' (i.e. "under10_employees"=1, 10-100_employees=2, and so on); the 
#' single instance of "50k+_employees / under10_employees" was removed.
#' * AGI_willhappen: wonthappen=0, both=1, willhappen=1
#' * alignment_valid: invalid.other=0, valid=1 (see <a href="#alignment-problem_field">categorization</a>: if someone *ever* said valid, then they were tagged as valid)
#' * instrumental_valid: invalid=0, valid=1 (see <a href="#instrumental-incentives_field">categorization</a>: if someone *ever* said valid, then they were tagged as valid)
#' * workon_interestedOrYes: no=0, "Interested in long-term safety but"=1, yes=1 (see <a href="#work-on-this">categorization</a>)
#' * heardofAIsafety: no=0, yes=1
#' * heardofAIalignment: no=0, yes=1
#' * chgmind: no=0, ambiguous=0, yes=1
#' * lastingeffects_yes: no=0, yes=1
#' * newactions_yes: no=0, yes=1
#' * align_instrum_bothValid: alignment_valid=1 *and* instrumental_valid=1
#' * align_instrum_AGI_allValid: alignment_valid=1 *and* instrumental_valid=1 *and* AGI_willhappen=1
#' * heardofsafetyandalignment: heardofsafety=1 *and* heardofalignment=1
# 
#' ## Demographics X Main ?s {#demographics-x-main-questions}
#' 
#' ### Using Field1 Labels {#demographics-x-main-questions_using-field1-labels}
# First, pull out the demographics that are categorical and label-encoded
categorical_demog <- rawdata[c("subjID_init","Gender","Current.country.of.work")]
categorical_demog$Gender <- as.character(factor(categorical_demog$Gender, labels = c("Female","Other","Male","Other")))
categorical_demog$Current.country.of.work <-
  as.character(factor(categorical_demog$Current.country.of.work,
                      labels = c("Europe","Europe","Canada","Asia","Europe",
                                 "Europe","Europe","Asia","Asia","Asia",
                                 "Europe","Europe","Asia","Europe","Europe",
                                 "Asia","UK","USA")))

# Convert these categorical demographics to one-hot encoded
catdata <- dcast(data = melt(categorical_demog, id.vars = "subjID_init"),
                 subjID_init ~ variable + value, length)

# Clean up some of the other demographics data and add them to the
# data set we will use for the correlation matrix

## Recode professional rank into 4 levels (1=top, 4=bottom) and
## convert that to an ordinal variable
lvl4jobs <- c("Undergraduate","Masters")
lvl3jobs <- c("PhD","Research Engineer","Software Engineer","ML Engineer","Researcher / Masters","Technical Staff","Principal Research Staff Member","Architect","Research Manager","Research Staff","Data Scientist")
lvl2jobs <- c("Postdoc","Assistant Professor","Research Scientist","Physics Fellow Researcher","AI Research Resident")
lvl1jobs <- c("Professor","Senior Research Fellow","Senior Research Scientist","Associate Professor","CEO","Principal AI Scientist","Chief Architect","Head of Research")
professionalrank <- ifelse(rawdata$X.Status..in.Feb.2022 %in% lvl4jobs,"lvl4",
                           ifelse(rawdata$X.Status..in.Feb.2022 %in% lvl3jobs,"lvl3",
                                  ifelse(rawdata$X.Status..in.Feb.2022 %in% lvl2jobs,"lvl2",
                                         ifelse(rawdata$X.Status..in.Feb.2022 %in% lvl1jobs,"lvl1",NA))))
professionalrank_ord <- as.numeric(factor(professionalrank))


## Convert industry_size to an ordinal variable (and recode the
## "50k+_employees / under10_employees" value as NA)
indust_size_ranked <- indust_size
indust_size_ranked[indust_size_ranked=="50k+_employees / under10_employees"] <- NA
indust_size_ranked <- as.numeric(indust_size_ranked)

## Add remaining demographics to data set
corrdata <- cbind(catdata,approximate_age=age_proxy,areaAIdata,
                  sector,h_index=rawdata$h_index,yrs_since_phd,
                  professionalrank_ord,
                  university_ranking_CS=rawdata$University.ranking.BY.CS,
                  university_ranking_overall=rawdata$University.ranking.overall,
                  indust_size_ranked)
# Note: I didn't remove the h-index outlier because we are doing Spearman correlations, which are rank-ordered and so robust to outliers
demog_ncols <- ncol(corrdata)

# Add ?s of interest, which we will correlation w/ demographics above
corrdata$AGI_willhappen <- as.integer(str_replace_all(willAGIhappen_simp, c("wonthappen" = "0", "willhappen" = "1")))
corrdata$alignment_valid <- as.integer(str_replace_all(alignment_validity, c("invalid.other" = "0", "valid" = "1")))
corrdata$instrumental_valid <- as.integer(str_replace_all(instrum_validity, c("invalid" = "0", "valid" = "1")))
corrdata$workon_interestedOrYes <- as.integer(str_replace_all(workonthis_simp, c("No" = "0", "Interested.in.long.term.safety.but" = "1", "Yes" = "1")))
corrdata$heardofAIsafety <- as.integer(heardXalign_simp$Knew.AI.safety..best.guess.) #yes=1, no=0
corrdata$heardofAIalignment <- as.integer(heardXalign_simp$Knew.AI.alignment..best.guess.) #yes=1, no=0
corrdata$chgmind <- as.integer(str_replace_all(chgmindvect, c("No" = "0", "ambiguous" = "0", "Yes" = "1")))
corrdata$lastingeffects_yes <- rawdata$Q2..beliefs..y.1..n.0. #yes=1, no=0
corrdata$newactions_yes <- rawdata$Q3..actions..y.1..n.0. #yes=1, no=0
corrdata$align_instrum_bothValid <- as.integer((corrdata$alignment_valid + corrdata$instrumental_valid)==2)
corrdata$align_instrum_AGI_allValid <- as.integer(rowSums(corrdata[c("alignment_valid","instrumental_valid","AGI_willhappen")])==3)
corrdata$heardofsafetyandalignment <- as.integer((corrdata$heardofAIsafety + corrdata$heardofAIalignment)==2)

# Create the correlation matrix
corstats <- corr.test(corrdata[(demog_ncols+1):ncol(corrdata)],
                      corrdata[demog_ncols:2],
                      adjust = "none", method = "spearman")
# mycorrmat = cor(corrdata[(demog_ncols+1):ncol(corrdata)],corrdata[demog_ncols:2],method = "spearman",
#      		 use = "pairwise.complete.obs")
# Note, using the pairwise complete observations to deal w/ missing
# data should be done with caution. I think it's still what I want
# here, but keep in mind that ppl have warnings about it. This is a
# good explanation about why: https://bwlewis.github.io/covar/missing.html
# Also, here is a stackoverflow answer that mentions that
# "it isn't guaranteed to produce a positive-definite correlation matrix": https://stackoverflow.com/questions/19113181/removing-na-in-correlation-matrix

g <- ggcorrplot(corstats$r,tl.cex = 12, tl.srt = 60)
# g
#+ fig.height=8, fig.width=8
ggplotly_toggle(g)

# Rank order the correlations (so you can pick out the strongest X
# correlations, or all correlations above some value, as done in the
# nlp paper). Also, indicate the N and p values for each correlation
# so you know how seriously to take them.
mycorrmat_melt <- merge(melt(corstats$r,value.name = "rho"),
                        melt(corstats$n,value.name = "n"),
                        by = c("Var1","Var2"))
mycorrmat_melt <- merge(mycorrmat_melt,
                        melt(corstats$p,value.name = "p"),
                        by = c("Var1","Var2"))
#' Below are the top 20 Spearman correlations in the matrix above,
#' by ρ values.
cortbl <- head(mycorrmat_melt[order(abs(mycorrmat_melt$r),decreasing = T),],20)

#+ results='asis'
print(kable_styling(kable(cortbl,format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#' Also including all correlations with p<0.05 (interpret with
#' caution, of course. Wouldn't really be fair to call them
#' significant, given multiple comparisons).
mycorrmat_melt_p0.05 <- subset(mycorrmat_melt,p<0.05)
cortbl_sign <- mycorrmat_melt_p0.05[order(mycorrmat_melt_p0.05$p),]
#+ results='asis'
print(kable_styling(kable(cortbl_sign,format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#' A visualization of the correlations that were
#' the most 'significant' (highest few on table above)
pltlist <- list()
for (i in 1:8) {
  myy <- as.character(cortbl_sign$Var1[i])
  myx <- as.character(cortbl_sign$Var2[i])
  myplotdata <- data.frame(thisx = corrdata[,myx], thisy = factor(corrdata[,myy]))
  if (length(unique(myplotdata$thisx))<8) {
    myplotdata$thisx <- factor(myplotdata$thisx)
    g <- ggplot(myplotdata,aes(x=thisx, fill=thisy)) +
      geom_bar(stat = "count", position = "dodge") +
      theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
      labs(x = myx, fill = myy)
  } else {
    summdat <- data_summary(myplotdata, varname="thisx", groupnames="thisy")
    g <- ggplot(summdat,aes(x=thisy, y=thisx)) +
      geom_bar(stat = "identity") +
      geom_errorbar(aes(ymin=thisx-sem, ymax=thisx+sem),width=.2) +
      theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
      labs(x = myy, y = myx)
  }
  pltlist[[i]] <- g
}
#+ fig.height=8, fig.width=8
grid.arrange(grobs=pltlist,ncol=2)

#' Observations:
#
#' * People in vision are unlikely to have heard of AI safety while
#' people in RL are more likely to have heard of it.
#' * Researchers later in their careers (i.e. of higher rank),
#' those in the UK, and those in RL are more likely to have heard
#' of AI alignment.
#' * People who think the alignment and instrumental arguments are valid 
#' tend to be at better ranked universities (i.e. lower ranking) than those who don't.
#
#' ### Using Field2 Labels {#demographics-x-main-questions_using-field2-labels}
# Create the data with field2 labels instead of field1
## Pick out the indices of the field1 data to excise/replace it
indfirst <- which(names(corrdata)==names(areaAIdata)[1])
indlast <- which(names(corrdata)==names(areaAIdata)[ncol(areaAIdata)])
corrdata2 <- cbind(corrdata[1:(indfirst-1)],
                   field2_raw,
                   corrdata[(indlast+1):(ncol(corrdata))])

# Create the correlation matrix
demog_ncols2 <- demog_ncols-1 #one fewer column in field2 than field1
corstats <- corr.test(corrdata2[(demog_ncols2+1):ncol(corrdata2)],
                      corrdata2[demog_ncols2:2],
                      adjust = "none", method = "spearman")

# Plot correlation matrix
g <- ggcorrplot(corstats$r,tl.cex = 12, tl.srt = 60)
#+ fig.height=8, fig.width=8
ggplotly_toggle(g)

# Rank order the correlations
mycorrmat_melt <- merge(melt(corstats$r,value.name = "rho"),
                        melt(corstats$n,value.name = "n"),
                        by = c("Var1","Var2"))
mycorrmat_melt <- merge(mycorrmat_melt,
                        melt(corstats$p,value.name = "p"),
                        by = c("Var1","Var2"))
#' Below are the top 20 Spearman correlations in the matrix above,
#' by ρ values.
cortbl <- head(mycorrmat_melt[order(abs(mycorrmat_melt$r),decreasing = T),],20)

#+ results='asis'
print(kable_styling(kable(cortbl,format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#' Also including all correlations with p<0.05 (interpret with
#' caution, of course. Wouldn't really be fair to call them
#' significant, given multiple comparisons).
mycorrmat_melt_p0.05 <- subset(mycorrmat_melt,p<0.05)
cortbl_sign <- mycorrmat_melt_p0.05[order(mycorrmat_melt_p0.05$p),]
#+ results='asis'
print(kable_styling(kable(cortbl_sign,format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#' Let's visualize the top handful of correlations that were
#' the most 'significant' (highest few on table above)
pltlist <- list()
for (i in 1:8) {
  myy <- as.character(cortbl_sign$Var1[i])
  myx <- as.character(cortbl_sign$Var2[i])
  myplotdata <- data.frame(thisx = corrdata2[,myx], thisy = factor(corrdata2[,myy]))
  if (length(unique(myplotdata$thisx))<8) {
    myplotdata$thisx <- factor(myplotdata$thisx)
    g <- ggplot(myplotdata,aes(x=thisx, fill=thisy)) +
      geom_bar(stat = "count", position = "dodge") +
      theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
      labs(x = myx, fill = myy)
  } else {
    summdat <- data_summary(myplotdata, varname="thisx", groupnames="thisy")
    g <- ggplot(summdat,aes(x=thisy, y=thisx)) +
      geom_bar(stat = "identity") +
      geom_errorbar(aes(ymin=thisx-sem, ymax=thisx+sem),width=.2) +
      theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
      labs(x = myy, y = myx)
  }
  pltlist[[i]] <- g
}
#+ fig.height=12, fig.width=8
grid.arrange(grobs=pltlist,ncol=2)

#' Observations:
# 
#' * Of the p < 0.01 correlations, most are related to specific fields of AI. The remainder are:
#' * Thinking both the alignment problem + instrumental incentives arguments were valid 
#' (and also optionally thinking AGI would happen) correlated with being in a higher-ranked
#'  university (negative correlation with university ranking).
#' * Having heard of AI alignment was correlated with being in a more senior position 
#' (negative correlation with professional rank).
#
#' ## Main ?s X Main ?s {#main-questions-x-main-questions}
corstats2 <- corr.test(corrdata[(demog_ncols+1):(ncol(corrdata)-3)],
                       adjust = "none", method = "spearman")

g <- ggcorrplot(corstats2$r,tl.cex = 12, tl.srt = 60)

# #+ fig.height=8, fig.width=8
ggplotly_toggle(g)

#' Below are all Spearman correlations with p < 0.1.
# Since this matrix is symmetric, need to first exclude diagonal
# and duplicates
corstats2$r[!upper.tri(corstats2$r)] <-
  corstats2$n[!upper.tri(corstats2$r)] <-
  corstats2$p[!upper.tri(corstats2$r)] <- NA

# Rank order the correlations and indicate their N and p values
mycorrmat2_melt <- merge(melt(corstats2$r,value.name = "rho"),
                         melt(corstats2$n,value.name = "n"),
                         by = c("Var1","Var2"))
mycorrmat2_melt <- merge(mycorrmat2_melt,
                         melt(corstats2$p,value.name = "p"),
                         by = c("Var1","Var2"))

mycorrmat2_melt_p0.1 <- subset(mycorrmat2_melt,p<0.1)
cortbl2_sign <- mycorrmat2_melt_p0.1[order(mycorrmat2_melt_p0.1$p),]
#+ results='asis'
print(kable_styling(kable(cortbl2_sign,format = 'html',escape=F),bootstrap_options = c("hover","striped")))

#' Let's visualize the top handful of correlations (I plotted
#' each two ways, with x and y switched, to get the full picture).
pltlist <- list()
for (i in 1:9) {
  myy <- as.character(cortbl2_sign$Var1[i])
  myx <- as.character(cortbl2_sign$Var2[i])
  myplotdata <- data.frame(thisx = corrdata[,myx], thisy = factor(corrdata[,myy]))
  if (length(unique(myplotdata$thisx))<8) {
    myplotdata$thisx <- factor(myplotdata$thisx)
    g1 <- ggplot(myplotdata,aes(x=thisx, fill=thisy)) +
      geom_bar(stat = "count", position = "dodge") +
      theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
      labs(x = myx, fill = myy)
    g2 <- ggplot(myplotdata,aes(x=thisy, fill=thisx)) +
      geom_bar(stat = "count", position = "dodge") +
      theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
      labs(x = myy, fill = myx)
  } else {
    summdat <- data_summary(myplotdata, varname="thisx", groupnames="thisy")
    g1 <- ggplot(summdat,aes(x=thisy, y=thisx)) +
      geom_bar(stat = "identity") +
      geom_errorbar(aes(ymin=thisx-sem, ymax=thisx+sem),width=.2) +
      theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
      labs(x = myy, y = myx)
    summdat <- data_summary(myplotdata, varname="thisy", groupnames="thisx")
    g2 <- ggplot(summdat,aes(x=thisx, y=thisy)) +
      geom_bar(stat = "identity") +
      geom_errorbar(aes(ymin=thisx-sem, ymax=thisx+sem),width=.2) +
      theme(axis.text.x = element_text(angle = 50, hjust = 1)) +
      labs(x = myx, y = myy)
  }
  ind <- i*2-1
  pltlist[[ind]] <- g1
  pltlist[[ind+1]] <- g2
}
#+ fig.height=16, fig.width=8
grid.arrange(grobs=pltlist,ncol=2)

#' Observations:
#
#' * If you've heard of AI alignment, you've heard of AI safety. (This is
#' in fact almost definitionally so; the taggers basically did not tag
#' someone as knowing what AI alignment was without knowing what
#' AI safety was, since alignment is a subfield of safety.) If
#' you've heard of AI safety, there's about a 50/50 shot you've heard
#' of AI alignment as well, but if you haven't heard of AI safety,
#' you're very unlikely to have heard of AI alignment.
#' * People who said that they changed their minds during the interview
#' were more likely to report later that the interview had a lasting effect 
#' on their beliefs. Similarly, if they said they didn't change their mind,
#' they were less likely to report a lasting effect. 
#' * In this data, if you think the alignment argument is valid,
#' you probably think AGI will happen. If you think AGI will
#' happen, you're definitely more likely to think the alignment problem
#' argument is valid but it's not a given. It's almost like thinking
#' that AGI will happen is a prerequisite for thinking the alignment
#' problem argument is valid. 
#' Similar trends hold true for the instrumental incentives argument.
#' * Almost all of the people who said the interview caused them to
#' take new action(s) at work had never heard of AI alignment.
#' * None of the people who reported that the interview caused them 
#' to take a new action(s) at work had said they were interested in 
#' working on AI alignment research during the interview; see more 
#' detail <a href="#new-actions_work-on-this">here</a>.

#####

##### Code that generates field_comparison.csv ----
# Create a spreadsheet that shows the field1 and field2 labels
# for each subject next to each other
field2 <- combine_labels_adv(field2_raw,"; ","")
field1 <- combine_labels_adv(areaAIdata,"; ","")
bothfields <- cbind(field1, field2 = field2[names(field1)])
write.csv(bothfields,paste0(mydir,"field_comparison.csv"))
#####
