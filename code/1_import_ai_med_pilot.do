* import_ai_med_pilot.do
*
* 	Imports and aggregates "HAIVN-StITCH  Patient Simulation  Mô phỏng bệnh nhân" (ID: ai_med_pilot) data.
*
*	Inputs:  "HAIVN-StITCH  Patient Simulation  Mô phỏng bệnh nhân_WIDE.csv"
*	Outputs: "HAIVN-StITCH  Patient Simulation  Mô phỏng bệnh nhân.dta"
*
*	Output by SurveyCTO September 2, 2025 5:58 PM.

* initialize Stata
clear all
set more off
set mem 100m

* initialize workflow-specific parameters
*	Set overwrite_old_data to 1 if you use the review and correction
*	workflow and allow un-approving of submissions. If you do this,
*	incoming data will overwrite old data, so you won't want to make
*	changes to data in your local .dta file (such changes can be
*	overwritten with each new import).
local overwrite_old_data 0

* initialize form-specific parameters
local csvfile "${folder}/raw/pilot-scto-data-export.xlsx"
local dtafile "${folder}/raw/pilot.dta"
local corrfile "${folder}/raw/pilot.csv"
local note_fields1 ""
local text_fields1 "deviceid devicephonenum device_info duration api_key system_prompt name language case_1_condition case_2_condition case_3_condition case_4_condition case_5_condition case_6_condition case_7_condition"
local text_fields2 "case_8_condition case_9_condition case_10_condition case_11_condition case_1_content case_2_content case_3_content case_4_content case_5_content case_6_content case_7_content case_8_content"
local text_fields3 "case_9_content case_10_content instructions_video_eng instructions_video_viet stamp_begin_11 custom_system_chat1 patient_1_diagnosis patient_1_treatment stamp_end_11 duration_11 stamp_begin_12"
local text_fields4 "case_1_condition_eng case_1_condition_viet patient_1_treatment_post stamp_end_12 duration_12 stamp_begin_21 custom_system_chat2 patient_2_diagnosis patient_2_treatment stamp_end_21 duration_21"
local text_fields5 "stamp_begin_22 case_2_condition_eng case_2_condition_viet patient_2_treatment_post stamp_end_22 duration_22 stamp_begin_31 custom_system_chat3 patient_3_diagnosis patient_3_treatment stamp_end_31"
local text_fields6 "duration_31 stamp_begin_32 case_3_condition_eng case_3_condition_viet patient_3_treatment_post stamp_end_32 duration_32 stamp_begin_41 custom_system_chat4 patient_4_diagnosis patient_4_treatment"
local text_fields7 "stamp_end_41 duration_41 stamp_begin_42 case_4_condition_eng case_4_condition_viet patient_4_treatment_post stamp_end_42 duration_42 stamp_begin_51 custom_system_chat5 patient_5_diagnosis"
local text_fields8 "patient_5_treatment stamp_end_51 duration_51 stamp_begin_52 case_5_condition_eng case_5_condition_viet patient_5_treatment_post stamp_end_52 duration_52 stamp_begin_61 custom_system_chat6"
local text_fields9 "patient_6_diagnosis patient_6_treatment stamp_end_61 duration_61 stamp_begin_62 case_6_condition_eng case_6_condition_viet patient_6_treatment_post stamp_end_62 duration_62 instanceid"
local date_fields1 ""
local datetime_fields1 "submissiondate starttime endtime"

disp
disp "Starting import of: `csvfile'"
disp

* import data from primary .csv file
import excel using "`csvfile'", first clear

* drop extra table-list columns
cap drop reserved_name_for_field_*
cap drop generated_table_list_lab*

* continue only if there's at least one row of data to import
if _N>0 {
	* drop note fields (since they don't contain any real data)
	forvalues i = 1/100 {
		if "`note_fields`i''" ~= "" {
			drop `note_fields`i''
		}
	}

	* format date and date/time fields
	forvalues i = 1/100 {
		if "`datetime_fields`i''" ~= "" {
			foreach dtvarlist in `datetime_fields`i'' {
				cap unab dtvarlist : `dtvarlist'
				if _rc==0 {
					foreach dtvar in `dtvarlist' {
						tempvar tempdtvar
						rename `dtvar' `tempdtvar'
						gen double `dtvar'=.
						cap replace `dtvar'=clock(`tempdtvar',"MDYhms",2025)
						* automatically try without seconds, just in case
						cap replace `dtvar'=clock(`tempdtvar',"MDYhm",2025) if `dtvar'==. & `tempdtvar'~=""
						format %tc `dtvar'
						drop `tempdtvar'
					}
				}
			}
		}
		if "`date_fields`i''" ~= "" {
			foreach dtvarlist in `date_fields`i'' {
				cap unab dtvarlist : `dtvarlist'
				if _rc==0 {
					foreach dtvar in `dtvarlist' {
						tempvar tempdtvar
						rename `dtvar' `tempdtvar'
						gen double `dtvar'=.
						cap replace `dtvar'=date(`tempdtvar',"MDY",2025)
						format %td `dtvar'
						drop `tempdtvar'
					}
				}
			}
		}
	}

	* ensure that text fields are always imported as strings (with "" for missing values)
	* (note that we treat "calculate" fields as text; you can destring later if you wish)
	tempvar ismissingvar
	quietly: gen `ismissingvar'=.
	forvalues i = 1/100 {
		if "`text_fields`i''" ~= "" {
			foreach svarlist in `text_fields`i'' {
				cap unab svarlist : `svarlist'
				if _rc==0 {
					foreach stringvar in `svarlist' {
						quietly: replace `ismissingvar'=.
						quietly: cap replace `ismissingvar'=1 if `stringvar'==.
						cap tostring `stringvar', format(%100.0g) replace
						cap replace `stringvar'="" if `ismissingvar'==1
					}
				}
			}
		}
	}
	quietly: drop `ismissingvar'


	* consolidate unique ID into "key" variable
	drop api_key
	ren KEY key
	ren instanceID instanceid
	replace key=instanceid if key==""
	drop instanceid


	* label variables
	label variable key "Unique submission ID"
	cap label variable submissiondate "Date/time submitted"
	cap label variable formdef_version "Form version used on device"
	cap label variable review_status "Review status"
	cap label variable review_comments "Comments made during review"
	cap label variable review_corrections "Corrections made during review"


	label variable consent "Consent"
	note consent: "Consent"
	label define consent 1 "-" 0 "-"
	label values consent consent

	label variable name "Name"
	note name: "Name"

	label variable language "Language"
	note language: "Language"

	label variable instructions_video_eng "-"
	note instructions_video_eng: "-"

	label variable instructions_video_viet "-"
	note instructions_video_viet: "-"

	label variable custom_system_chat1 "Patient 1 interaction"
	note custom_system_chat1: "Patient 1 interaction"

	label variable patient_1_diagnosis "Patient 1 preliminary diagnosis"
	note patient_1_diagnosis: "Patient 1 preliminary diagnosis"

	label variable patient_1_treatment "Patient 1 preliminary treatement"
	note patient_1_treatment: "Patient 1 preliminary treatement"

	label variable patient_1_treatment_post "Patient 1 final treatment"
	note patient_1_treatment_post: "Patient 1 final treatment"

	label variable custom_system_chat2 "Patient 2 interaction"
	note custom_system_chat2: "Patient 2 interaction"

	label variable patient_2_diagnosis "Patient 2 preliminary diagnosis"
	note patient_2_diagnosis: "Patient 2 preliminary diagnosis"

	label variable patient_2_treatment "Patient 2 preliminary treatement"
	note patient_2_treatment: "Patient 2 preliminary treatement"

	label variable patient_2_treatment_post "Patient 2 final treatment"
	note patient_2_treatment_post: "Patient 2 final treatment"

	label variable custom_system_chat3 "Patient 3 interaction"
	note custom_system_chat3: "Patient 3 interaction"

	label variable patient_3_diagnosis "Patient 3 preliminary diagnosis"
	note patient_3_diagnosis: "Patient 3 preliminary diagnosis"

	label variable patient_3_treatment "Patient 3 preliminary treatement"
	note patient_3_treatment: "Patient 3 preliminary treatement"

	label variable patient_3_treatment_post "Patient 3 final treatment"
	note patient_3_treatment_post: "Patient 3 final treatment"

	label variable custom_system_chat4 "Patient 4 interaction"
	note custom_system_chat4: "Patient 4 interaction"

	label variable patient_4_diagnosis "Patient 4 preliminary diagnosis"
	note patient_4_diagnosis: "Patient 4 preliminary diagnosis"

	label variable patient_4_treatment "Patient 4 preliminary treatement"
	note patient_4_treatment: "Patient 4 preliminary treatement"

	label variable patient_4_treatment_post "Patient 4 final treatment"
	note patient_4_treatment_post: "Patient 4 final treatment"

	label variable custom_system_chat5 "Patient 5 interaction"
	note custom_system_chat5: "Patient 5 interaction"

	label variable patient_5_diagnosis "Patient 5 preliminary diagnosis"
	note patient_5_diagnosis: "Patient 5 preliminary diagnosis"

	label variable patient_5_treatment "Patient 5 preliminary treatement"
	note patient_5_treatment: "Patient 5 preliminary treatement"

	label variable patient_5_treatment_post "Patient 5 final treatment"
	note patient_5_treatment_post: "Patient 5 final treatment"

	label variable custom_system_chat6 "Patient 6 interaction"
	note custom_system_chat6: "Patient 6 interaction"

	label variable patient_6_diagnosis "Patient 6 preliminary diagnosis"
	note patient_6_diagnosis: "Patient 6 preliminary diagnosis"

	label variable patient_6_treatment "Patient 6 preliminary treatement"
	note patient_6_treatment: "Patient 6 preliminary treatement"

	label variable patient_6_treatment_post "Patient 6 final treatment"
	note patient_6_treatment_post: "Patient 6 final treatment"






	* append old, previously-imported data (if any)
	cap confirm file "`dtafile'"
	if _rc == 0 {
		* mark all new data before merging with old data
		gen new_data_row=1

		* pull in old data
		append using "`dtafile'"

		* drop duplicates in favor of old, previously-imported data if overwrite_old_data is 0
		* (alternatively drop in favor of new data if overwrite_old_data is 1)
		sort key
		by key: gen num_for_key = _N
		drop if num_for_key > 1 & ((`overwrite_old_data' == 0 & new_data_row == 1) | (`overwrite_old_data' == 1 & new_data_row ~= 1))
		drop num_for_key

		* drop new-data flag
		drop new_data_row
	}

	* save data to Stata format
	save "`dtafile'", replace

	* show codebook and notes
	codebook
	notes list
}

disp
disp "Finished import of: `csvfile'"
disp

* OPTIONAL: LOCALLY-APPLIED STATA CORRECTIONS
*
* Rather than using SurveyCTO's review and correction workflow, the code below can apply a list of corrections
* listed in a local .csv file. Feel free to use, ignore, or delete this code.
*
*   Corrections file path and filename:  HAIVN-StITCH  Patient Simulation  Mô phỏng bệnh nhân_corrections.csv
*
*   Corrections file columns (in order): key, fieldname, value, notes

capture confirm file "`corrfile'"
if _rc==0 {
	disp
	disp "Starting application of corrections in: `corrfile'"
	disp

	* save primary data in memory
	preserve

	* load corrections
	insheet using "`corrfile'", names clear

	if _N>0 {
		* number all rows (with +1 offset so that it matches row numbers in Excel)
		gen rownum=_n+1

		* drop notes field (for information only)
		drop notes

		* make sure that all values are in string format to start
		gen origvalue=value
		tostring value, format(%100.0g) replace
		cap replace value="" if origvalue==.
		drop origvalue
		replace value=trim(value)

		* correct field names to match Stata field names (lowercase, drop -'s and .'s)
		replace fieldname=lower(subinstr(subinstr(fieldname,"-","",.),".","",.))

		* format date and date/time fields (taking account of possible wildcards for repeat groups)
		forvalues i = 1/100 {
			if "`datetime_fields`i''" ~= "" {
				foreach dtvar in `datetime_fields`i'' {
					* skip fields that aren't yet in the data
					cap unab dtvarignore : `dtvar'
					if _rc==0 {
						gen origvalue=value
						replace value=string(clock(value,"MDYhms",2025),"%25.0g") if strmatch(fieldname,"`dtvar'")
						* allow for cases where seconds haven't been specified
						replace value=string(clock(origvalue,"MDYhm",2025),"%25.0g") if strmatch(fieldname,"`dtvar'") & value=="." & origvalue~="."
						drop origvalue
					}
				}
			}
			if "`date_fields`i''" ~= "" {
				foreach dtvar in `date_fields`i'' {
					* skip fields that aren't yet in the data
					cap unab dtvarignore : `dtvar'
					if _rc==0 {
						replace value=string(clock(value,"MDY",2025),"%25.0g") if strmatch(fieldname,"`dtvar'")
					}
				}
			}
		}

		* write out a temp file with the commands necessary to apply each correction
		tempfile tempdo
		file open dofile using "`tempdo'", write replace
		local N = _N
		forvalues i = 1/`N' {
			local fieldnameval=fieldname[`i']
			local valueval=value[`i']
			local keyval=key[`i']
			local rownumval=rownum[`i']
			file write dofile `"cap replace `fieldnameval'="`valueval'" if key=="`keyval'""' _n
			file write dofile `"if _rc ~= 0 {"' _n
			if "`valueval'" == "" {
				file write dofile _tab `"cap replace `fieldnameval'=. if key=="`keyval'""' _n
			}
			else {
				file write dofile _tab `"cap replace `fieldnameval'=`valueval' if key=="`keyval'""' _n
			}
			file write dofile _tab `"if _rc ~= 0 {"' _n
			file write dofile _tab _tab `"disp"' _n
			file write dofile _tab _tab `"disp "CAN'T APPLY CORRECTION IN ROW #`rownumval'""' _n
			file write dofile _tab _tab `"disp"' _n
			file write dofile _tab `"}"' _n
			file write dofile `"}"' _n
		}
		file close dofile

		* restore primary data
		restore

		* execute the .do file to actually apply all corrections
		do "`tempdo'"

		* re-save data
		save "`dtafile'", replace
	}
	else {
		* restore primary data
		restore
	}

	disp
	disp "Finished applying corrections in: `corrfile'"
	disp
}
