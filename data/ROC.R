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


common_vars <- intersect(names(human), names(llm))
human <- human[, common_vars]

common_vars <- intersect(names(human), names(llm))
llm <- llm[, common_vars]


llm <- llm %>% mutate(Source = "LLM")
human <- human %>% mutate(Source = "Human")


combined <- bind_rows(llm, human)

wide <- combined %>%
  pivot_wider(
    names_from = Source,
    values_from = -c(condition, name, Source),   # everything except keys
    names_glue = "{.value}_{Source}"
  )

# Identify all *_LLM columns
llm_cols <- grep("_LLM$", names(wide), value = TRUE)

# Loop over each LLM column, find its Human pair, and create agree column
for (col in llm_cols) {
  human_col <- sub("_LLM$", "_Human", col)
  agree_col <- sub("_LLM$", "_agree", col)
  
  wide[[agree_col]] <- ifelse(wide[[col]] == wide[[human_col]], 1, 0)
}


agreement_summary <- wide %>%
  select(ends_with("_agree")) %>%
  summarise(across(everything(), ~ mean(.x, na.rm = TRUE))) %>%
  pivot_longer(cols = everything(),
               names_to = "item",
               values_to = "percent_agreement") %>%
  mutate(
    item = str_remove(item, "_agree$"),          # clean names (e.g. ast_h_2)
    percent_agreement = round(percent_agreement * 100, 1) # convert to %
  )%>%
  filter(item != "duration")%>%
  filter(
    item != "duration",
    !str_detect(item, "_t_"),
    !str_detect(item, "_m_"),
    !str_detect(item, "_con_")
  )

long_table <- wide %>%
  mutate(provider = name) %>%   
  pivot_longer(
    cols = matches("(_LLM|_Human)$"),
    names_to = c("item", "Source"),
    names_pattern = "(.*)_(LLM|Human)",
    values_to = "value"
  ) %>%
  pivot_wider(
    names_from = Source,
    values_from = value
  ) %>%
  select(item, provider, Human, LLM)%>%
  filter(item != "duration")

write.csv(long_table, "agreement-long.csv", row.names = FALSE)

