//
// Figure 2: Validation panel (expert ratings, LLM coding, MCQ vs human checklist)

use "${folder}/data/compiled-scores.dta" , clear

tw (lfitci expert1 human_pct , lc(black) lw(thick) alw(none)) ///
  (scatter expert1 human_pct, m(X) jitter(5) mfc(black) mlc(black)) ///
   , legend(off) title("A: Expert Rating (Original Vietnamese)") ///
     xlab(0 "0%" 10 "10%" 20 "20%" 30 "30%" 40 "40%" 50 "50%", nogrid) ylab(,nogrid) ///
     xtit("Essential Diagnostics (Human Coded)")

     graph save "${folder}/temp/f2_1.gph" , replace

tw (lfitci expert2 human_pct , lc(black) lw(thick) alw(none)) ///
  (scatter expert2 human_pct, m(X) jitter(5) mfc(black) mlc(black)) ///
  , legend(off) title("B: Expert Rating (Translated English)") ///
    xlab(0 "0%" 10 "10%" 20 "20%" 30 "30%" 40 "40%" 50 "50%", nogrid) ylab(,nogrid) ///
    xtit("Essential Diagnostics (Human Coded)")

    graph save "${folder}/temp/f2_2.gph" , replace

tw (lfitci claude_pct human_pct , lc(black) lw(thick) alw(none)) ///
  (scatter claude_pct human_pct, m(X) mfc(black) mlc(black)) ///
  , legend(off) title("C: Essential Diagnostics (Claude, English)") ///
    xlab(0 "0%" 10 "10%" 20 "20%" 30 "30%" 40 "40%" 50 "50%", nogrid)  ///
    ylab(0 "0%" 20 "20%" 40 "40%", nogrid) ///
    xtit("Essential Diagnostics (Human Coded)")

    graph save "${folder}/temp/f2_3.gph" , replace

tw (lfitci claude_vn_pct human_pct , lc(black) lw(thick) alw(none)) ///
  (scatter claude_vn_pct human_pct, m(X) mfc(black) mlc(black)) ///
  , legend(off) title("D: Essential Diagnostics (Claude, Vietnamese)") ///
    xlab(0 "0%" 10 "10%" 20 "20%" 30 "30%" 40 "40%" 50 "50%", nogrid)  ///
    ylab(0 "0%" 20 "20%" 40 "40%", nogrid) ///
    xtit("Essential Diagnostics (Human Coded)")

    graph save "${folder}/temp/f2_4.gph" , replace

graph combine ///
  "${folder}/temp/f2_1.gph" ///
  "${folder}/temp/f2_2.gph" ///
  "${folder}/temp/f2_3.gph" ///
  "${folder}/temp/f2_4.gph" ///
  ,  ysize(5) scale(0.7)

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
// Figure 3: Item-level sensitivity and specificity (Claude vs human)

use "${folder}/data/agreement-long.dta" , clear

  drop if human == .

  // Panel A: English
  gen g_00 = human == 0 & llm == 0
  gen g_01 = human == 0 & llm == 1
  gen g_10 = human == 1 & llm == 0
  gen g_11 = human == 1 & llm == 1

  preserve
  collapse (mean) g* , by(item)

  gen Sensitivity = g_11/(g_11+g_10)
  gen Specificity = g_00/(g_01+g_00)

  tw (scatter Specificity Sensitivity  , jitter(5) m(X) mlc(black)) ///
     (function 1-x , lc(black) lp(dash)) ///
     , legend(off) ytit("Item Specificity") xtit("Item Sensitivity") ///
       title("A: Claude (English)") ///
       xlab(, nogrid) ylab(,nogrid) ysize(5)

       graph save "${folder}/temp/f3_1.gph" , replace
  restore

  // Panel B: Vietnamese
  drop g_*
  gen g_00 = human == 0 & llm_vn == 0
  gen g_01 = human == 0 & llm_vn == 1
  gen g_10 = human == 1 & llm_vn == 0
  gen g_11 = human == 1 & llm_vn == 1

  collapse (mean) g* , by(item)

  gen Sensitivity = g_11/(g_11+g_10)
  gen Specificity = g_00/(g_01+g_00)

  tw (scatter Specificity Sensitivity  , jitter(5) m(X) mlc(black)) ///
     (function 1-x , lc(black) lp(dash)) ///
     , legend(off) ytit("Item Specificity") xtit("Item Sensitivity") ///
       title("B: Claude (Vietnamese)") ///
       xlab(, nogrid) ylab(,nogrid) ysize(5)

       graph save "${folder}/temp/f3_2.gph" , replace

  graph combine ///
    "${folder}/temp/f3_1.gph" ///
    "${folder}/temp/f3_2.gph" ///
    , ysize(5) scale(0.8)

    graph export "${folder}/manuscript/exhibits/F3.pdf" , replace
    graph export "${folder}/output/fig_3.jpg" , replace width(2000)

// End
