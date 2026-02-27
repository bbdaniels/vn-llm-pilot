//

cap prog drop gtrans
	prog def gtrans , rclass

	syntax anything
	preserve
		qui {
			local theText = subinstr(`anything'," ","%20",.)

			import delimited using ///
				"https://translation.googleapis.com/language/translate/v2?q=`theText'&target=en&key=YOUR_KEY_HERE" ///
				, clear

			keep v1
				keep if regexm(v1,"translated")
				replace v1 = substr(v1,strpos(v1,":")+1,.)
				replace v1 = subinstr(v1,`"""',"",.)
				replace v1 = trim(v1)
				local theNewText = v1 in 1

				return local text = "`theNewText'"
		}
	end

//
