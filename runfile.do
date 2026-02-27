//

// Setup and folder path
clear
global folder "/Users/bbdaniels/Library/CloudStorage/OneDrive-HarvardUniversity/Vietnam HMS-CPC/llm vignette/pilot-validation"
/* DATA PREP DONE AND LOCKED TO SAVE API CALLS AND SLOW RUNTIMES
// Load data from raw SCTO files w modified SCTO do-template
qui do "${folder}/code/1_import_ai_med_pilot.do"

// Import programs for transcripts and translations
qui do "${folder}/code/X_transcript.do"
qui do "${folder}/code/X_gtranslate.do"

// Manual cleaning and export of raw data
do "${folder}/code/2_data-prep.do"

// Get English translation of transcript, treatment, and diagnosis
do "${folder}/code/3_english-translation.do"

// Import data sheet with translated transcripts and analyze w AI
do "${folder}/code/4_ai-extraction.do"
*/

// Import data sheet with AI extraction and begin data construction
do "${folder}/code/5_data-construction.do"


--






//
