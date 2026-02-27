
insheet using "${folder}/scto/Preload-Vignette-Pilot.csv", names clear
  keep case_name case_name_eng
    ren case_name condition
    ren case_name_eng condition_eng
  tempfile cases
  save `cases'

use "${folder}/data/pilot.dta" , clear
  merge m:1 condition using `cases'
    drop _merge
    lab var condition_eng "Condition"


  gtranslate transcript_clean , from(vi) to(en)
    ren transcript_clean_en transcript_en
    lab var transcript_en "Transcript EN"

  gtranslate diagnosis , from(vi) to(en)
    lab var diagnosis_en "Diagnosis EN"

  gtranslate treatment , from(vi) to(en)
    lab var treatment_en "Treatment EN"

  gtranslate treatment_post , from(vi) to(en)
    lab var treatment_post_en "Treatment (Post) EN"

    save "${folder}/data/pilot.dta" , replace

  drop if case == .

  transcript transcript_en , dir(${folder}/transcripts-en/) ///
    header(name condition_eng) footer(diagnosis_en treatment_en treatment_post_en)

    save "${folder}/data/pilot.dta" , replace

  
// End of file
