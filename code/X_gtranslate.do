
cap prog drop gtranslate
prog def gtranslate

syntax anything, from(string asis) to(string asis)

gen `anything'_`to' = ""

qui count
local N = `r(N)'
forv k = 1/`N' {

  local text = `anything'[`k']
  local text = subinstr("`text'","'","",.)

  // Reminder: if rejected, run [gcloud init] in Terminal
  qui !curl -X POST ///
     -H "Authorization: Bearer YOUR_TOKEN_HERE" ///
     -H "x-goog-user-project: YOUR_PROJECT_ID" ///
     -H "Content-Type: application/json; charset=utf-8" ///
     -d '{ ///
       "sourceLanguageCode": "`from'", ///
       "targetLanguageCode": "`to'", ///
       "contents": ["`text'"], ///
       "mimeType": "text/plain" ///
     }' ///
     "https://translation.googleapis.com/v3/projects/YOUR_PROJECT_ID:translateText" ///
     --output "${folder}/temp/data.json"

  preserve
    import delimited using "${folder}/temp/data.json" , clear
    local x = v2[4]
    local x = subinstr(`"`x'"',`"""',"",.)
  restore

  replace `anything'_`to' = "`x'" in `k'

}

end

  //
