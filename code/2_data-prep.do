//
drop if name == "test"
drop if name == "demo"
  sort name

ren case_*_condition condition*
ren custom_system_chat* transcript*
ren patient_*_diagnosis diagnosis*
ren patient_*_treatment treatment*
ren duration_*1 duration*
ren patient_*_treatment_post treatment_post*

ren duration time_total

keep name time_total ///
  condition* transcript* diagnosis* treatment* duration* treatment_post*

reshape long condition transcript diagnosis treatment duration treatment_post ///
  , i(name) j(case)

drop if transcript == ""
  drop duration_?2

destring duration* time_total , replace
  foreach var of varlist duration* time_total {
    replace `var' = `var'/60
  }

lab var name "Provider ID"
lab var case "Case No"
lab var condition "Scenario"
lab var transcript "Transcript JSON"
lab var diagnosis "Provider Diagnosis"
lab var treatment "Provider Treatment"
lab var duration "Conversation to Treatment Time (min)"
lab var treatment_post "Treatment Given Diagnosis"
lab var time_total "Total Survey Time (min)"

transcript transcript , var(transcript_clean) dir(${folder}/transcripts-vn) header(name condition_eng) footer(diagnosis treatment treatment_post)

lab var transcript_clean "Transcript VN"

save "${folder}/data/pilot.dta" , replace



//
