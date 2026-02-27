
local text = transcript_clean[1]

local text = subinstr("`text'",char(10),"",.)
local text = subinstr("`text'","%"," percent",.)
local text = subinstr("`text'","'","",.)

  di "Translate the following to English: `text'"

  cap gen transcript_eng = ""

  !curl https://api.openai.com/v1/responses ///
    -H "Content-Type: application/json" ///
    -H "Authorization: Bearer YOUR_KEY_HERE" ///
    -d '{ ///
      "model": "gpt-5-nano", ///
      "input": "Translate the following to English: `text'" ///
    }' ///
    --output "${folder}/temp/data.json"

  preserve
    import delimited using "${folder}/temp/data.json" , clear
    local x = v2[28]
    local x = subinstr(`"`x'"',`"""',"",.)
    local x = subinstr(`"`x'"',`"\u2019"',"'",.)
    local x = subinstr(`"`x'"',`"\u00b0"',"°",.)

  restore

  replace transcript_eng = "`x'" in 1

}

  //
