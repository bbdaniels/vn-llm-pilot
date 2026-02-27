
local text = transcript_en[`1']
local diag = diagnosis_en[`1']
local treat = treatment_post_en[`1']

local text = "`text' USER DIAGNOSIS: `diag' USER TREATMENT: `treat'"
local case = condition[`1']

local text = subinstr("`text'",char(10),"",.)
local text = subinstr("`text'","%"," percent",.)
local text = subinstr("`text'","'","",.)

preserve
  import excel using "${folder}/code/4_ai-extraction.xlsx" , clear first
  keep if case == "`case'" | case == ""
  keep if name != ""

  qui count
  local nvars = `r(N)'
  forv i = 1/`nvars' {
    local a`i' = action[`i']
    local q`i' = question[`i']
    local l`i' = label[`i']
    local v`i' = name[`i']
  }

restore

forv i = 1/`nvars' {
  cap gen `v`i'' = .
  cap lab var `v`i'' "`l`i''"

  !curl https://api.openai.com/v1/responses ///
    -H "Content-Type: application/json" ///
    -H "Authorization: Bearer YOUR_KEY_HERE" ///
    -d '{ ///
      "model": "gpt-4.1-nano", ///
      "input": "In the following text, if the user was a doctor, did they specifically `a`i'' about `q`i''? Answer 1 if yes, 0 if no, and nothing more. TEXT: `text'" ///
    }' ///
    --output "${folder}/temp/data.json"

  preserve
    import delimited using "${folder}/temp/data.json" , clear
    local x = v2[23]
    local x = strpos(`"`x'"',"1") > 0
  restore

  replace `v`i'' = `x' in `1'

}

  //
