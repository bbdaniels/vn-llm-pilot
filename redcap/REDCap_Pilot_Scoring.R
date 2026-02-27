
library(tidyverse)
library(openxlsx)


#Load Data
response <- read.xlsx("/Users/stellazwj/Library/CloudStorage/OneDrive-HarvardUniversity/Daniels, Benjamin's files - Vietnam HMS-CPC/llm vignette/pilot-validation/redcap/HCP Competency Assessment_REDCap DATA_23 staff_Aug 2025.xlsx", sheet = 1) 

answer_case1 <- read.xlsx("/Users/stellazwj/Library/CloudStorage/OneDrive-HarvardUniversity/Daniels, Benjamin's files - Vietnam HMS-CPC/llm vignette/pilot-validation/redcap/HCP Competency Assessment _ REDCap_Correct Answers.xlsx", sheet="Case 1")
answer_case2 <- read.xlsx("/Users/stellazwj/Library/CloudStorage/OneDrive-HarvardUniversity/Daniels, Benjamin's files - Vietnam HMS-CPC/llm vignette/pilot-validation/redcap/HCP Competency Assessment _ REDCap_Correct Answers.xlsx", sheet="Case 2")
answer_case3 <- read.xlsx("/Users/stellazwj/Library/CloudStorage/OneDrive-HarvardUniversity/Daniels, Benjamin's files - Vietnam HMS-CPC/llm vignette/pilot-validation/redcap/HCP Competency Assessment _ REDCap_Correct Answers.xlsx", sheet="Case 3")
answer_case4 <- read.xlsx("/Users/stellazwj/Library/CloudStorage/OneDrive-HarvardUniversity/Daniels, Benjamin's files - Vietnam HMS-CPC/llm vignette/pilot-validation/redcap/HCP Competency Assessment _ REDCap_Correct Answers.xlsx", sheet="Case 4")
answer_case5 <- read.xlsx("/Users/stellazwj/Library/CloudStorage/OneDrive-HarvardUniversity/Daniels, Benjamin's files - Vietnam HMS-CPC/llm vignette/pilot-validation/redcap/HCP Competency Assessment _ REDCap_Correct Answers.xlsx", sheet="Case 5")
answer_key <- bind_rows(
  lapply(list(answer_case1, answer_case2, answer_case3, answer_case4, answer_case5),
         \(df) df %>% mutate(across(everything(), as.character)))
)





#Pivot Responses 
response_long <- response %>%
  pivot_longer(cols = -field_id, names_to = "question", values_to = "answer", values_transform = list(answer = as.character))


combined <- response_long %>%
  left_join(answer_key, by = c("question" = "Variables"))



combined$`#` <- as.numeric(combined$`#`)


#check
combined <- combined %>%
  mutate(check = if_else(answer == Answer_1 | answer == Answer_2, 1, 0))


checked <- combined %>%
  mutate(
    check = case_when(
      is.na(Answer_1) & is.na(Answer_2) & is.na(Answer_3) ~ NA_real_,     
      answer == Answer_1 | answer == Answer_2 | answer == Answer_3~ 1 ,  
      TRUE ~ 0                                          
    )
  )




# scoring 
checked <- checked%>%
  mutate(case = case_when(
    `#` >= 12 & `#` <= 40  ~ "1hbc",
    `#` >= 42 & `#` <= 65  ~ "2hbp",
    `#` >= 67 & `#` <= 94  ~ "3hbv",
    `#` >= 96 & `#` <= 123 ~ "4hcv",
    `#` >= 125 & `#` <= 156 ~ "5arv"  ))


checked_long <- checked %>%
  mutate(question = str_replace(question, "___.*", "")) %>%
  group_by(field_id, case, question) %>%
  summarise(
    # strict score: 1 if all sub-options correct, else 0
    check = ifelse(all(check == 1, na.rm = TRUE), 1, 0),
    # keep first values of your other columns
    .groups = "drop"
  ) %>%
  filter(!is.na(case))

write.xlsx(checked_long, "pilot-24-redcap-checked-long.xlsx")


checked_wide <- checked_long %>%
  select(field_id, question, check) %>%
  pivot_wider(
    id_cols = field_id, 
    names_from = question,   
    values_from = check    
  )

write.xlsx(checked_wide, "pilot-24-redcap-checked-wide.xlsx")



checked_perc_correct <- checked_long %>%
  filter(!is.na(case)) %>%                     # drop rows with missing case
  group_by(case, field_id) %>%
  summarise(
    correct = sum(check == 1, na.rm = TRUE),   # count 1s
    total   = sum(check %in% c(0,1)),          # count only 0s and 1s
    perc_correct = correct / total * 100,
    .groups = "drop"
  )



write.xlsx(checked_perc_correct, "pilot-24-redcap-score.xlsx")




checked_perc_correct%>%
  group_by(case) %>%
  summarise(
    avg_perc_correct = mean(perc_correct, na.rm = TRUE),
    .groups = "drop"
  )







