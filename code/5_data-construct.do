import excel "${folder}/data/pilot-compiled-scores.xlsx" , clear first sheet("All_Scores")

drop if name == ""
drop H

tw (lfitci expert1_chat human_chat_perc_checklist , lc(black) lw(thick) alw(none)) ///
  (scatter expert1_chat human_chat_perc_checklist, m(X) jitter(5) mfc(black) mlc(black)) ///
   , legend(off) title("A: Expert Rating (Original Vietnamese)") ///
     xlab(0 "0%" 10 "10%" 20 "20%" 30 "30%" 40 "40%" 50 "50%", nogrid) ylab(,nogrid) ///
     xtit("Essential Diagnostics (Human Coded)")

     graph save "${folder}/temp/f2_1.gph" , replace

tw (lfitci expert2_chat human_chat_perc_checklist , lc(black) lw(thick) alw(none)) ///
  (scatter expert2_chat human_chat_perc_checklist, m(X) jitter(5) mfc(black) mlc(black)) ///
  , legend(off) title("B: Expert Rating (Translated English)") ///
    xlab(0 "0%" 10 "10%" 20 "20%" 30 "30%" 40 "40%" 50 "50%", nogrid) ylab(,nogrid) ///
    xtit("Essential Diagnostics (Human Coded)")

    graph save "${folder}/temp/f2_2.gph" , replace

tw (lfitci llm_chat_perc_checklist human_chat_perc_checklist , lc(black) lw(thick) alw(none)) ///
  (scatter llm_chat_perc_checklist human_chat_perc_checklist if llm_chat_perc_checklist <40, m(X) mfc(black) mlc(black)) ///
  , legend(off) title("C: Essential Diagnostics (LLM Coded)") ///
    xlab(0 "0%" 10 "10%" 20 "20%" 30 "30%" 40 "40%" 50 "50%", nogrid)  ///
    ylab(0 "0%" 20 "20%" 40 "40%", nogrid) ///
    xtit("Essential Diagnostics (Human Coded)")

    graph save "${folder}/temp/f2_3.gph" , replace

tw (lfitci redcap_perc_correct human_chat_perc_checklist , lc(black) lw(thick) alw(none)) ///
  (scatter redcap_perc_correct human_chat_perc_checklist, m(X) mfc(black) mlc(black)) ///
  , legend(off) title("D: MCQ Score (Hepatitis Cases)") ///
    xlab(0 "0%" 10 "10%" 20 "20%" 30 "30%" 40 "40%" 50 "50%", nogrid) ///
    ylab(0 "0%" 20 "20%" 40 "40%" 60 "60%" 80 "80%" 100 "100%", nogrid) ///
    xtit("Essential Diagnostics (Human Coded)")

    graph save "${folder}/temp/f2_4.gph" , replace

graph combine ///
  "${folder}/temp/f2_1.gph" ///
  "${folder}/temp/f2_2.gph" ///
  "${folder}/temp/f2_3.gph" ///
  "${folder}/temp/f2_4.gph" ///
  ,  ysize(5) scale(0.7)

  graph export "${folder}/output/fig_2.jpg" , replace width(2000)

  graph combine ///
    "${folder}/temp/f2_1.gph" ///
    "${folder}/temp/f2_2.gph" ///
    "${folder}/temp/f2_3.gph" ///
    "${folder}/temp/f2_4.gph" ///
    , scale(0.8)  r(1) ysize(3)

    graph export "${folder}/output/fig_poster.png" , replace width(10000)

//

import delimited using "${folder}/data/agreement-long.csv" , clear varnames(1)

  destring human , replace force
  destring llm , replace force

  drop if human == .

  gen g_00 = human == 0 & llm == 0
  gen g_01 = human == 0 & llm == 1
  gen g_10 = human == 1 & llm == 0
  gen g_11 = human == 1 & llm == 1

  collapse (mean) g* , by(item)

  gen Sensitivity = g_11/(g_11+g_10)
  gen Specificity = g_00/(g_01+g_00)


  tw (scatter Specificity Sensitivity  , jitter(5) m(X) mlc(black)) ///
     (function 1-x , lc(black) lp(dash)) ///
     , legend(off) ytit("Item Specificity") xtit("Item Sensitivity") ///
       xlab(, nogrid) ylab(,nogrid) ysize(5)

       graph export "${folder}/output/fig_3.jpg" , replace width(2000)

/*
// Create IRT Scores
collapse (firstnm) *_h_* , by(name)

// Remove questions with no variation
foreach var of varlist *_h_* {
  su `var'
  if `r(Var)' ==  0 drop `var'
}

// Estimate IRT scores for diagnosis
irt 3pl *_h_*
  predict irt
*/

// End
