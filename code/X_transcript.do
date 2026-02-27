
cap prog drop transcript
prog def transcript

syntax anything , [VARname(string asis)] [translate(string asis)] [dir(string asis)] [header(string asis)] [footer(string asis)]

// Loop over observations
qui count
forvalues i = 1/`r(N)' {
	local text = `anything'[`i']

	local text = subinstr(`"`text'"',"},{",char(10),.)
	local text = subinstr(`"`text'"',"[{","",.)
	local text = subinstr(`"`text'"',"}]","",.)
	local text = subinstr(`"`text'"',`""role":""',"",.)
	local text = subinstr(`"`text'"',`"","content":"',"",.)
	local text = subinstr(`"`text'"',"user",">>User:>>",.)
	local text = subinstr(`"`text'"',"assistant",">>LLM:>>",.)
	local text = subinstr(`"`text'"',">>",char(10),.)
	local text = subinstr(`"`text'"',"\n",char(10),.)
	local text = subinstr(`"`text'"',`"""',"",.)


	if "`varname'" != "" {
		cap gen `varname' = ""
		replace `varname' = `"`text'"' in `i'
	}

  /*
	if "`translate'" != "" {
		cap gen `translate' = ""
		gtrans `"`text'"'
		replace `varname' = `"`r(text)'"' in `i'
	}
	*/

	local name = name[`i']
	local case = condition[`i']

  if "`dir'" != "" {
		cap putpdf clear
		putpdf begin

		if "`header'" != "" {
			foreach word in `header' {
				local next = `word'[`i']
				putpdf paragraph
				putpdf text (`"`word': `next'"')
			}
		}

		  putpdf paragraph
		  putpdf text (`"`text'"')

		if "`footer'" != "" {
			foreach word in `footer' {
				local next = `word'[`i']
				putpdf paragraph
				putpdf text (`"`word': `next'"')
			}
		}


		putpdf save "`dir'/`case'_`name'.pdf" , replace
	}
}

end

// End of file
