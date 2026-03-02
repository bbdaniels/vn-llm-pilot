//
// Table 1: Combined case scenarios and validation summary
//

use "${folder}/data/compiled-scores.dta" , clear

  // Condition metadata: case number, full name, category, total checklist items
  gen case_num = .
  gen str40 case_name = ""
  gen str12 category = ""
  gen items = .

  replace case_num = 1  if condition == "ast"
  replace case_num = 2  if condition == "pne"
  replace case_num = 3  if condition == "t2d"
  replace case_num = 4  if condition == "tb1"
  replace case_num = 5  if condition == "htn"
  replace case_num = 6  if condition == "hbc"
  replace case_num = 7  if condition == "hbp"
  replace case_num = 8  if condition == "hbv"
  replace case_num = 9  if condition == "hcv"
  replace case_num = 10 if condition == "arv"

  replace case_name = "Asthma"                     if condition == "ast"
  replace case_name = "Pneumonia"                   if condition == "pne"
  replace case_name = "Type 2 diabetes"             if condition == "t2d"
  replace case_name = "Pulmonary tuberculosis"      if condition == "tb1"
  replace case_name = "Hypertension"                if condition == "htn"
  replace case_name = "Hepatitis B (chronic)"       if condition == "hbc"
  replace case_name = "Hepatitis B (pregnancy)"     if condition == "hbp"
  replace case_name = "Hepatitis B (vaccination)"   if condition == "hbv"
  replace case_name = "Hepatitis C"                 if condition == "hcv"
  replace case_name = "HIV/antiretroviral therapy"  if condition == "arv"

  replace category = "General"   if inlist(condition, "ast", "pne", "t2d", "tb1", "htn")
  replace category = "Hepatitis" if inlist(condition, "hbc", "hbp", "hbv", "hcv", "arv")

  // Total items = case-specific + 19 common
  replace items = 62 if condition == "ast"
  replace items = 49 if condition == "pne"
  replace items = 58 if condition == "t2d"
  replace items = 58 if condition == "tb1"
  replace items = 56 if condition == "htn"
  replace items = 74 if condition == "hbc"
  replace items = 62 if condition == "hbp"
  replace items = 58 if condition == "hbv"
  replace items = 64 if condition == "hcv"
  replace items = 63 if condition == "arv"

  // Collapse to condition level
  preserve
  collapse (count) n=human_pct ///
    (mean) human_pct expert1 expert2 ///
    (first) case_num case_name category items ///
    , by(condition)

  sort case_num

  // Write LaTeX table
  tempname fh
  file open `fh' using "${folder}/manuscript/exhibits/T1.tex" , write replace

  // Table rows by condition
  local N = _N
  forvalues i = 1/`N' {
    local cn    = case_num[`i']
    local cname = case_name[`i']
    local cat   = category[`i']
    local nn    = n[`i']
    local it    = items[`i']
    local hp : di %4.1f human_pct[`i']
    local e1 : di %4.2f expert1[`i']
    local e2 : di %4.2f expert2[`i']

    file write `fh' ///
      `"`cn' & `cname' & `cat' & `nn' & `it' & `hp' & `e1' & `e2' \\"' _n
  }

  // Total row
  qui use "${folder}/data/compiled-scores.dta" , clear
  qui su human_pct
  local th : di %4.1f r(mean)
  local tn = r(N)
  qui su expert1
  local te1 : di %4.2f r(mean)
  qui su expert2
  local te2 : di %4.2f r(mean)

  file write `fh' _char(92) "midrule" _n
  file write `fh' ///
    `" & "' _char(92) "textit{Overall} & & `tn' & & `th' & `te1' & `te2' " _char(92) _char(92) _n
  file write `fh' _char(92) "bottomrule" _n

  file close `fh'

  restore

//
// Figure 2: Validation panel (expert ratings, LLM coding, MCQ vs human checklist)

use "${folder}/data/compiled-scores.dta" , clear

tw (lfitci human_pct expert1 , lc(black) lw(thick) alw(none)) ///
  (scatter human_pct expert1, m(X) jitter(5) mfc(black) mlc(black)) ///
   , legend(off) title("A: Expert Rating (Original Vietnamese)") ///
     ylab(0 "0%" 10 "10%" 20 "20%" 30 "30%" 40 "40%" 50 "50%", nogrid) xlab(,nogrid) ///
     ytit("Essential Diagnostics (Human Coded)") xtit("Expert Rating (1-5)")

     graph save "${folder}/temp/f2_1.gph" , replace

tw (lfitci human_pct expert2 , lc(black) lw(thick) alw(none)) ///
  (scatter human_pct expert2, m(X) jitter(5) mfc(black) mlc(black)) ///
  , legend(off) title("B: Expert Rating (Translated English)") ///
    ylab(0 "0%" 10 "10%" 20 "20%" 30 "30%" 40 "40%" 50 "50%", nogrid) xlab(,nogrid) ///
    ytit("Essential Diagnostics (Human Coded)") xtit("Expert Rating (1-5)")

    graph save "${folder}/temp/f2_2.gph" , replace

tw (lfitci human_pct claude_vn_pct , lc(black) lw(thick) alw(none)) ///
  (scatter human_pct claude_vn_pct, m(X) mfc(black) mlc(black)) ///
  , legend(off) title("C: Essential Diagnostics (Claude, Vietnamese)") ///
    ylab(0 "0%" 10 "10%" 20 "20%" 30 "30%" 40 "40%" 50 "50%", nogrid)  ///
    xlab(0 "0%" 20 "20%" 40 "40%", nogrid) ///
    ytit("Essential Diagnostics (Human Coded)") xtit("Essential Diagnostics (Claude Coded)")

    graph save "${folder}/temp/f2_3.gph" , replace

tw (lfitci human_pct claude_pct , lc(black) lw(thick) alw(none)) ///
  (scatter human_pct claude_pct, m(X) mfc(black) mlc(black)) ///
  , legend(off) title("D: Essential Diagnostics (Claude, English)") ///
    ylab(0 "0%" 10 "10%" 20 "20%" 30 "30%" 40 "40%" 50 "50%", nogrid)  ///
    xlab(0 "0%" 20 "20%" 40 "40%", nogrid) ///
    ytit("Essential Diagnostics (Human Coded)") xtit("Essential Diagnostics (Claude Coded)")

    graph save "${folder}/temp/f2_4.gph" , replace

graph combine ///
  "${folder}/temp/f2_1.gph" ///
  "${folder}/temp/f2_2.gph" ///
  "${folder}/temp/f2_3.gph" ///
  "${folder}/temp/f2_4.gph" ///
  ,  ysize(5) scale(0.6)

  graph export "${folder}/manuscript/exhibits/F2.pdf" , replace
  graph export "${folder}/output/fig_2.jpg" , replace width(2000)

  graph combine ///
    "${folder}/temp/f2_1.gph" ///
    "${folder}/temp/f2_2.gph" ///
    "${folder}/temp/f2_3.gph" ///
    "${folder}/temp/f2_4.gph" ///
    , scale(0.8)  r(1) ysize(3)

    graph export "${folder}/output/fig_poster.png" , replace width(10000)

//
// Figure 3: ROC curves (Claude confidence vs human gold standard)

use "${folder}/data/agreement-long.dta" , clear

  drop if human == .

  // Construct predicted probability of positive (score=1)
  // If LLM says 1 with confidence c: P(positive) = c
  // If LLM says 0 with confidence c: P(positive) = 1 - c
  gen llm_prob = llm * llm_conf + (1-llm) * (1-llm_conf) if llm_conf < .
  gen llm_vn_prob = llm_vn * llm_vn_conf + (1-llm_vn) * (1-llm_vn_conf) if llm_vn_conf < .

  // Scale to 0-100 integer for roctab
  gen llm_prob_i = round(llm_prob * 100)
  gen llm_vn_prob_i = round(llm_vn_prob * 100)

  // Panel A: English
  preserve
  drop if llm_prob_i == .

  qui roctab human llm_prob_i
  local auc_en : di %4.3f r(area)

  roctab human llm_prob_i , graph ///
    title("A: Claude (English)") ///
    subtitle("AUROC = `auc_en'") ///
    ytit("Sensitivity") xtit("1 - Specificity") ///
    xlab(, nogrid) ylab(, nogrid) ///
    legend(off) ysize(5)

  graph save "${folder}/temp/f3_1.gph" , replace
  restore

  // Panel B: Vietnamese
  preserve
  drop if llm_vn_prob_i == .

  qui roctab human llm_vn_prob_i
  local auc_vn : di %4.3f r(area)

  roctab human llm_vn_prob_i , graph ///
    title("B: Claude (Vietnamese)") ///
    subtitle("AUROC = `auc_vn'") ///
    ytit("Sensitivity") xtit("1 - Specificity") ///
    xlab(, nogrid) ylab(, nogrid) ///
    legend(off) ysize(5)

  graph save "${folder}/temp/f3_2.gph" , replace
  restore

  graph combine ///
    "${folder}/temp/f3_1.gph" ///
    "${folder}/temp/f3_2.gph" ///
    , ysize(5) scale(0.8)

    graph export "${folder}/manuscript/exhibits/F3.pdf" , replace
    graph export "${folder}/output/fig_3.jpg" , replace width(2000)

// End
