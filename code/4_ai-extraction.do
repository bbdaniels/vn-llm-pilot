
use "${folder}/data/pilot.dta" , clear

qui count
  local N = `r(N)'
  forv k = 1/`N' {
    qui do "${folder}/code/X_openai-classification.do" `k'
    di "`k'/`N' done..."
  }

save "${folder}/data/pilot-coded.dta" , replace
