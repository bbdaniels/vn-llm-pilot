library(tidyverse)
install.packages("readxl")
library(readxl)

human <- read_excel("pilot-human.xlsx")
human <- human %>%
  rename_with(~ sub("^tb_", "tb1_", .x), starts_with("tb_"))

unique(human$cp_2)

human$cp_2 <- dplyr::recode(human$cp_2,
                            `1` = "ast",
                            `2` = "pne",
                            `3` = "t2d",
                            `4` = "tb1",
                            `5` = "htn",
                            `6` = "hbc",
                            `7` = "hbp",
                            `8` = "hbv",
                            `9` = "hcv",
                            `10` = "arv"
)

unique(human$cp_2)


human <- human %>%
  rename(
    condition = cp_2,
    name = cp_1
  )


llm <- read_excel("pilot-coded.xlsx")

redcap <- read_excel("/Users/stellazwj/Library/CloudStorage/OneDrive-HarvardUniversity/Daniels, Benjamin's files - Vietnam HMS-CPC/llm vignette/pilot-validation/redcap/pilot-24-redcap-score.xlsx")

thuy <- read_excel("/Users/stellazwj/Library/CloudStorage/OneDrive-HarvardUniversity/Daniels, Benjamin's files - Vietnam HMS-CPC/llm vignette/pilot-validation/data/AI MED Pilot_Expert Review_DrThuy.xlsx")

marwa <- read_excel("/Users/stellazwj/Library/CloudStorage/OneDrive-HarvardUniversity/Daniels, Benjamin's files - Vietnam HMS-CPC/llm vignette/pilot-validation/data/AI MED Pilot_Expert Review_DrMarwa.xlsx")




# llm_chat <- llm %>%
#   select(-matches("_t_|_m_|_con_"))

# Find common variables
common_vars <- intersect(names(human), names(llm))
human <- human[, common_vars]


# history
# Step 1. Extract all unique condition prefixes from your column names
prefixes <- unique(sub("_h_.*", "", grep("_h_", names(human), value = TRUE)))

# Step 2. Loop through each prefix and calculate scores
for (p in prefixes) {
  
  # find only true question columns (e.g. ast_h_1 ... ast_h_n)
  question_cols <- grep(paste0("^", p, "_h_[0-9]+$"), names(human), value = TRUE)
  
  # add the score + total
  human <- human %>%
    rowwise() %>%
    mutate(
      !!paste0(p, "_h_score") := sum(c_across(all_of(question_cols)) == 1, na.rm = TRUE),
      !!paste0(p, "_h_total") := length(question_cols)
    ) %>%
    ungroup()
}


prefixes <- unique(sub("_h_.*", "", grep("_h_", names(llm), value = TRUE)))

for (p in prefixes) {
  
  # find only true question columns (e.g. ast_h_1 ... ast_h_n)
  question_cols <- grep(paste0("^", p, "_h_[0-9]+$"), names(llm), value = TRUE)
  
  # add the score + total
  llm <- llm %>%
    rowwise() %>%
    mutate(
      !!paste0(p, "_h_score") := sum(c_across(all_of(question_cols)) == 1, na.rm = TRUE),
      !!paste0(p, "_h_total") := length(question_cols)
    ) %>%
    ungroup()
}



# clinical exam 
# 1. Condition-specific CE scores
prefixes <- unique(human$condition)

for (p in prefixes) {
  question_cols <- grep(paste0("^", p, "_ce_[0-9]+$"), names(human), value = TRUE)
  
  human <- human %>%
    rowwise() %>%
    mutate(
      !!paste0(p, "_ce_score") := sum(c_across(all_of(question_cols)) == 1, na.rm = TRUE),
      !!paste0(p, "_ce_total") := length(question_cols)
    ) %>%
    ungroup()
}

human <- human %>%
  mutate(
    ce_total = 7,
   ce_score = rowSums(select(., matches("^ce_[0-9]+$")) == 1, na.rm = TRUE)
  )

prefixes <- unique(llm$condition)

for (p in prefixes) {
  question_cols <- grep(paste0("^", p, "_ce_[0-9]+$"), names(llm), value = TRUE)
  
  llm <- llm %>%
    rowwise() %>%
    mutate(
      !!paste0(p, "_ce_score") := sum(c_across(all_of(question_cols)) == 1, na.rm = TRUE),
      !!paste0(p, "_ce_total") := length(question_cols)
    ) %>%
    ungroup()
}

llm <- llm %>%
  mutate(
    ce_total = 7,
    ce_score = rowSums(select(., matches("^ce_[0-9]+$")) == 1, na.rm = TRUE)
  )




# laboratory tests 
# Step 1. Extract all unique condition prefixes from your column names
prefixes <- unique(sub("_lt_.*", "", grep("_lt_", names(human), value = TRUE)))

# Step 2. Loop through each prefix and calculate scores
for (p in prefixes) {
  
  question_cols <- grep(paste0("^", p, "_lt_[0-9]+$"), names(human), value = TRUE)
  
  # add the score + total
  human <- human %>%
    rowwise() %>%
    mutate(
      !!paste0(p, "_lt_score") := sum(c_across(all_of(question_cols)) == 1, na.rm = TRUE),
      !!paste0(p, "_lt_total") := length(question_cols)
    ) %>%
    ungroup()
}


prefixes <- unique(sub("_lt_.*", "", grep("_lt_", names(llm), value = TRUE)))

for (p in prefixes) {
  
  question_cols <- grep(paste0("^", p, "_lt_[0-9]+$"), names(llm), value = TRUE)
  
  # add the score + total
  llm <- llm %>%
    rowwise() %>%
    mutate(
      !!paste0(p, "_lt_score") := sum(c_across(all_of(question_cols)) == 1, na.rm = TRUE),
      !!paste0(p, "_lt_total") := length(question_cols)
    ) %>%
    ungroup()
}




human_score <- human %>%
  select(
    name, condition,
    ends_with("_score"),
    ends_with("_total"),
    contains("_d")
  )


llm_score <- llm %>%
  select(
    duration, name, condition,
    ends_with("_score"),
    ends_with("_total"),
    contains("_d")
  )%>%
  select(-time_total)



human_summary_scores <- human_score %>%
  rowwise() %>%
  mutate(
    # 1. History
    h_score        = get(paste0(condition, "_h_score")),
    h_total        = get(paste0(condition, "_h_total")),
    h_perc_correct = ifelse(h_total > 0, h_score / h_total, NA_real_),
    
    # 2. Clinical exams (condition-specific + general CE)
    ce_score_cond   = get(paste0(condition, "_ce_score")),
    ce_total_cond   = get(paste0(condition, "_ce_total")),
    ce_score    = ce_score_cond + ce_score,
    ce_total    = ce_total_cond + ce_total,
    ce_perc_correct = ifelse(ce_total > 0, ce_score / ce_total, NA_real_),
    
    # 3. Lab tests
    lt_score        = get(paste0(condition, "_lt_score")),
    lt_total        = get(paste0(condition, "_lt_total")),
    lt_perc_correct = ifelse(lt_total > 0, lt_score / lt_total, NA_real_),
    
    # 4. Condition-specific _d_
    d_score = get(paste0(condition, "_d"))   # e.g. ast_d, pne_d, etc.
  ) %>%
  ungroup() %>%
  select(name, condition,
         h_score, h_total, h_perc_correct,
         ce_score, ce_total, ce_perc_correct,
         lt_score, lt_total, lt_perc_correct, d_score)


human_condition_summary <- human_summary_scores %>%
  group_by(condition) %>%
  summarise(
    # domain-specific averages (same as before)
    avg_h_perc_correct  = mean(h_perc_correct,  na.rm = TRUE),
    avg_ce_perc_correct = mean(ce_perc_correct, na.rm = TRUE),
    avg_lt_perc_correct = mean(lt_perc_correct, na.rm = TRUE),
    avg_d_correct       = mean(d_score == 1,    na.rm = TRUE),
    
    # weighted chat = (sum of scores) / (sum of totals)
    chat_perc_correct   = (sum(h_score, na.rm = TRUE) +
                             sum(ce_score, na.rm = TRUE) +
                             sum(lt_score, na.rm = TRUE)) /
      (sum(h_total, na.rm = TRUE) +
         sum(ce_total, na.rm = TRUE) +
         sum(lt_total, na.rm = TRUE)),
    .groups = "drop"
  )

human_summary_scores <- human_summary_scores %>%
  mutate(
    chat_score        = h_score + ce_score + lt_score,
    chat_total        = h_total + ce_total + lt_total,
    chat_perc_correct = ifelse(chat_total > 0, chat_score / chat_total, NA_real_)
  )



llm_summary_scores <- llm_score %>%
  rowwise() %>%
  mutate(
    # 1. History
    h_score        = get(paste0(condition, "_h_score")),
    h_total        = get(paste0(condition, "_h_total")),
    h_perc_correct = ifelse(h_total > 0, h_score / h_total, NA_real_),
    
    # 2. Clinical exams (condition-specific + general CE)
    ce_score_cond   = get(paste0(condition, "_ce_score")),
    ce_total_cond   = get(paste0(condition, "_ce_total")),
    ce_score    = ce_score_cond + ce_score,
    ce_total    = ce_total_cond + ce_total,
    ce_perc_correct = ifelse(ce_total > 0, ce_score / ce_total, NA_real_),
    
    # 3. Lab tests
    lt_score        = get(paste0(condition, "_lt_score")),
    lt_total        = get(paste0(condition, "_lt_total")),
    lt_perc_correct = ifelse(lt_total > 0, lt_score / lt_total, NA_real_),
    
    # 4. Condition-specific _d_
    d_score = get(paste0(condition, "_d"))   # e.g. ast_d, pne_d, etc.
  ) %>%
  ungroup() %>%
  select(name, condition,
         h_score, h_total, h_perc_correct,
         ce_score, ce_total, ce_perc_correct,
         lt_score, lt_total, lt_perc_correct, d_score)


llm_condition_summary <- llm_summary_scores %>%
  group_by(condition) %>%
  summarise(
    # domain-specific averages (same as before)
    avg_h_perc_correct  = mean(h_perc_correct,  na.rm = TRUE),
    avg_ce_perc_correct = mean(ce_perc_correct, na.rm = TRUE),
    avg_lt_perc_correct = mean(lt_perc_correct, na.rm = TRUE),
    avg_d_correct       = mean(d_score == 1,    na.rm = TRUE),
    
    # weighted chat = (sum of scores) / (sum of totals)
    chat_perc_correct   = (sum(h_score, na.rm = TRUE) +
                             sum(ce_score, na.rm = TRUE) +
                             sum(lt_score, na.rm = TRUE)) /
      (sum(h_total, na.rm = TRUE) +
         sum(ce_total, na.rm = TRUE) +
         sum(lt_total, na.rm = TRUE)),
    .groups = "drop"
  )


llm_summary_scores <- llm_summary_scores %>%
  mutate(
    chat_score        = h_score + ce_score + lt_score,
    chat_total        = h_total + ce_total + lt_total,
    chat_perc_correct = ifelse(chat_total > 0, chat_score / chat_total, NA_real_)
  )



# Count total 1's in llm
llm_total_ones <- sum(llm_score == 1, na.rm = TRUE)

# Count total 1's in human
human_total_ones <- sum(human_score == 1, na.rm = TRUE)

llm_total_ones
human_total_ones



# Total 1s
human_total_ones <- sum(human == 1, na.rm = TRUE)
llm_total_ones   <- sum(llm == 1, na.rm = TRUE)

# Average denominators
colMeans(select(human_summary_scores, ends_with("_total")), na.rm = TRUE)
colMeans(select(llm_summary_scores,   ends_with("_total")), na.rm = TRUE)


redcap <- redcap %>%
  rename(
    redcap_perc_correct = perc_correct,
    redcap_case = case,
    name= field_id
  )

human_clean <- human_summary_scores %>%
  mutate(human_chat_perc_checklist = round(chat_perc_correct * 100, 2)) %>%
  select(name, condition, human_chat_perc_checklist,d_score)


llm_clean <- llm_summary_scores %>%
  mutate(llm_chat_perc_checklist = round(chat_perc_correct * 100, 2)) %>%
  select(name, condition, llm_chat_perc_checklist)

rm(final)

final <- human_clean %>%
  inner_join(llm_clean, by = c("name", "condition"),
             suffix = c("_human", "_llm"))

final <- final %>%
  left_join(thuy %>% select(name, condition, expert1_chat = chat),
            by = c("name", "condition")) %>%
  left_join(marwa %>% select(name, condition, expert2_chat = chat),
            by = c("name", "condition"))


redcap <- redcap %>%
  mutate(condition = sub("^[0-9]+", "", redcap_case))

final <- final %>%
  left_join(
    redcap %>%
      mutate(redcap_perc_correct = round(redcap_perc_correct, 2)) %>%
      select(name, condition, redcap_perc_correct),
    by = c("name", "condition")
  )

final_condition_summary <- final %>%
  group_by(condition) %>%
  summarise(
    across(where(is.numeric), mean, na.rm = TRUE),
    .groups = "drop"
  )

redcap_condition_summary <- redcap %>%
  group_by(condition) %>%
  summarise(
    avg_redcap_perc_correct = mean(redcap_perc_correct, na.rm = TRUE),
    .groups = "drop"
  )

expert_chat <- thuy %>%
  select(name, condition, expert1_chat = chat) %>%
  inner_join(
    marwa %>% select(name, condition, expert2_chat = chat),
    by = c("name", "condition")
  )

expert_condition_summary <- expert_chat %>%
  group_by(condition) %>%
  summarise(
    avg_expert1_score = mean(expert1_chat, na.rm = TRUE),
    avg_expert2_score = mean(expert2_chat, na.rm = TRUE),
    .groups = "drop"
  )

install.packages("writexl")
library(writexl)

write_xlsx(
  list(
    All_Scores_Avg_byCondition = final_condition_summary,
    All_Scores = final,
    Human_Scores_byCondition = human_condition_summary,
    Human_Scores = human_summary_scores,
    LLM_Scores_byCondition = llm_condition_summary,
    LLM_Scores = llm_summary_scores,
    RedCap_byCondition =redcap_condition_summary,
    RedCap_Scores = redcap,
    Expert_Review_byCondition = expert_condition_summary,
    Expert_Review = expert_chat
  ),
  "pilot-compiled-scores.xlsx"
)



human_clean <- human_summary_scores %>%
  mutate(human_chat_perc_checklist = round(chat_perc_correct * 100, 2)) %>%
  select(name, condition, human_chat_perc_checklist,d_score)




human_clean <- human_clean %>%
  left_join(llm %>% select(name, condition, duration),
            by = c("name", "condition"))%>%
  mutate(duration = ifelse(duration > 30, NA, duration))

human_clean %>%
  group_by(condition) %>%
  summarise(mean_duration = mean(duration, na.rm = TRUE))


case_map <- c(
  "ast" = "Asthma",
  "pne" = "Pneumonia",
  "t2d" = "Type II Diabetes",
  "tb1"   = "Tuberculosis",
  "htn"  = "Hypertension",
  "hbc" = "Hepatitis B with Cirrhosis",
  "hbp"      = "Hepatitis B in Pregnancy",
  "hbv"           = "Hepatitis B Not Eligible for Treatment",
  "hcv"           = "Hepatitis C",
  "arv"           = "Hepatitis C for Patients on ARV"
)

# CI for a mean
mean_ci <- function(x, conf = 0.95) {
  x <- na.omit(x)
  n <- length(x)
  if (n < 2) return(c(NA, NA))
  m <- mean(x)
  se <- sd(x)/sqrt(n)
  moe <- qt((1 + conf)/2, df = n - 1) * se
  c(m - moe, m + moe)
}

# CI for a proportion
prop_ci <- function(x, conf = 0.95) {
  x <- na.omit(x)
  n <- length(x)
  if (n == 0) return(c(NA, NA))
  p <- mean(x == 1)
  moe <- qnorm((1 + conf)/2) * sqrt(p * (1 - p)/n)
  c(p - moe, p + moe)
}

wilson_ci <- function(x, conf = 0.95) {
  x <- na.omit(x)
  n <- length(x)
  if (n == 0) return(c(NA, NA))
  
  p_hat <- mean(x == 1)  # sample proportion
  z <- qnorm((1 + conf)/2)
  
  denom <- 1 + z^2 / n
  center <- (p_hat + z^2 / (2*n)) / denom
  half_width <- (z / denom) * sqrt((p_hat * (1 - p_hat) / n) + (z^2 / (4 * n^2)))
  
  c(center - half_width, center + half_width)
}


summary_table <- human_clean %>%
  mutate(Case = recode(condition, !!!case_map)) %>%
  group_by(Case) %>%
}
    checklist_mean = mean(human_chat_perc_checklist, na.rm = TRUE),
    checklist_CI_low = mean_ci(human_chat_perc_checklist)[1],
    checklist_CI_high = mean_ci(human_chat_perc_checklist)[2],
    
    diagnosis_mean = mean(d_score == 1, na.rm = TRUE) * 100,
    diagnosis_CI_low = prop_ci(d_score)[1] * 100,
    diagnosis_CI_high = prop_ci(d_score)[2] * 100,
    
    duration_mean = mean(duration, na.rm = TRUE),
    duration_CI_low = mean_ci(duration)[1],
    duration_CI_high = mean_ci(duration)[2],
    
    .groups = "drop"
  )

summary_table <- human_clean %>%
  mutate(Case = recode(condition, !!!case_map)) %>%
  group_by(Case) %>%
  summarise(
    N = n_distinct(name),
    
    # Checklist is a proportion (0–1), so Wilson CI
    checklist_mean = mean(human_chat_perc_checklist, na.rm = TRUE),
    checklist_CI_low = wilson_ci(human_chat_perc_checklist)[1],
    checklist_CI_high = wilson_ci(human_chat_perc_checklist)[2],
    
    # Diagnosis is binary (0/1), so Wilson CI ×100
    diagnosis_mean = mean(d_score == 1, na.rm = TRUE) * 100,
    diagnosis_CI_low = wilson_ci(d_score)[1] * 100,
    diagnosis_CI_high = wilson_ci(d_score)[2] * 100,
    
    # Duration is continuous, so t-based mean CI
    duration_mean = mean(duration, na.rm = TRUE),
    duration_CI_low = mean_ci(duration)[1],
    duration_CI_high = mean_ci(duration)[2],
    
    .groups = "drop"
  )



summary_table_all <- human_clean %>%
  mutate(Case = recode(condition, !!!case_map)) %>%
  summarise(
    N = n_distinct(name),
    
    checklist_mean = mean(human_chat_perc_checklist, na.rm = TRUE),
    checklist_CI_low = wilson_ci(human_chat_perc_checklist)[1],
    checklist_CI_high = wilson_ci(human_chat_perc_checklist)[2],
    
    diagnosis_mean = mean(d_score == 1, na.rm = TRUE) * 100,
    diagnosis_CI_low = wilson_ci(d_score)[1] * 100,
    diagnosis_CI_high = wilson_ci(d_score)[2] * 100,
    
    duration_mean = mean(duration, na.rm = TRUE),
    duration_CI_low = wilson_ci(duration)[1],
    duration_CI_high = wilson_ci(duration)[2],
    
    .groups = "drop"
  )



library(dplyr)
library(gt)
library(stringr)

# Lancet decimal formatter
lancet_fmt <- function(x, digits = 1) {
  s <- format(round(x, digits), nsmall = digits)
  gsub("\\.", "·", s)
}

summary_table_pretty <- summary_table %>%
  mutate(
    Perc_checklist = paste0(
      lancet_fmt(checklist_mean), " (",
      lancet_fmt(checklist_CI_low), "–",
      lancet_fmt(checklist_CI_high), ")"
    ),
    Correct_diagnosis = paste0(
      lancet_fmt(diagnosis_mean), "% (",
      lancet_fmt(diagnosis_CI_low), "–",
      lancet_fmt(diagnosis_CI_high), ")"
    ),
    Duration = paste0(
      lancet_fmt(duration_mean), " (",
      lancet_fmt(duration_CI_low), "–",
      lancet_fmt(duration_CI_high), ")"
    )
  ) %>%
  select(Case, N, Perc_checklist, Correct_diagnosis, Duration)

write.xlsx(summary_table_pretty, "validation-table2.xlsx", rowNames = FALSE)



table1_lancet <- summary_table_pretty %>%
  gt() %>%
  tab_header(
    title = md("**Table 2. Provider Performance by Case**")
  ) %>%
  cols_label(
    Case = "Case",
    N = "N (providers)",
    Perc_checklist = "Checklist Completion (%)",
    Correct_diagnosis = "Correct Diagnosis (%)",
    Duration = "Consultation Duration (min)"
  ) %>%
  tab_options(
    table.font.names = "Times New Roman",
    table.font.size = px(12),
    heading.align = "left"
  )

table1_lancet

case_order <- c(
  "Asthma",
  "Pneumonia",
  "Type II Diabetes",
  "Tuberculosis",
  "Hypertension",
  "Hepatitis B with Cirrhosis",
  "Hepatitis B in Pregnancy",
  "Hepatitis B Not Eligible for Treatment",
  "Hepatitis C",
  "Hepatitis C for Patients on ARV"
)

summary_table <- human_clean %>%
  mutate(Case = recode(condition, !!!case_map),
         Case = factor(Case, levels = case_order)) %>%   # 👈 force order
  group_by(Case) %>%
  summarise(
    N = n_distinct(name),
    
    checklist_mean = mean(human_chat_perc_checklist, na.rm = TRUE),
    checklist_CI_low = mean_ci(human_chat_perc_checklist)[1],
    checklist_CI_high = mean_ci(human_chat_perc_checklist)[2],
    
    diagnosis_mean = mean(d_score == 1, na.rm = TRUE) * 100,
    diagnosis_CI_low = prop_ci(d_score)[1] * 100,
    diagnosis_CI_high = prop_ci(d_score)[2] * 100,
    
    duration_mean = mean(duration, na.rm = TRUE),
    duration_CI_low = mean_ci(duration)[1],
    duration_CI_high = mean_ci(duration)[2],
    
    .groups = "drop"
  ) %>%
  arrange(Case) 


summary_table_pretty <- summary_table %>%
  mutate(
    Perc_checklist = paste0(
      lancet_fmt(checklist_mean), " (",
      lancet_fmt(checklist_CI_low), "–",
      lancet_fmt(checklist_CI_high), ")"
    ),
    Correct_diagnosis = paste0(
      lancet_fmt(diagnosis_mean), " (",
      lancet_fmt(diagnosis_CI_low), "–",
      lancet_fmt(diagnosis_CI_high), ")"
    ),
    Duration = paste0(
      lancet_fmt(duration_mean), " (",
      lancet_fmt(duration_CI_low), "–",
      lancet_fmt(duration_CI_high), ")"
    )
  ) %>%
  select(Case, N, Perc_checklist, Correct_diagnosis, Duration)


table2_lancet <- summary_table_pretty %>%
  gt() %>%
  tab_header(
    title = md("**Table 2. Summary of Provider Performance by Case**")
  ) %>%
  cols_label(
    Case = "Case",
    N = "N (providers)",
    Perc_checklist = "Completion of Essential Diagnostic Checklist (%)",
    Correct_diagnosis = "Correct Diagnosis (%)",
    Duration = "Diagnostic Duration (min)"
  ) %>%
  cols_align(
    align = "right",
    columns = everything()  
  ) %>%
  tab_options(
    table.font.names = "Times New Roman",
    table.font.size = px(12),
    heading.align = "left"
  )
table2_lancet


gtsave(table2_lancet, "validation-table2.png")
