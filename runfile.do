//

// Setup and folder path
clear
global folder "/Users/bbdaniels/GitHub/vn-llm-pilot"

// Step 1: Import raw SCTO data
if 0 {
  qui do "${folder}/code/1_import_ai_med_pilot.do"
}

// Step 2: Clean and reshape
if 0 {
  qui do "${folder}/code/X_transcript.do"
  do "${folder}/code/2_data-prep.do"
}

// Step 3: Translate Vietnamese text to English (Python/Claude)
if 0 {
  !python3 "${folder}/code/translate.py"
}

// Step 4a: Classify transcripts against clinical rubric (English, Python/Claude)
if 0 {
  !python3 "${folder}/code/classify.py"
}

// Step 4b: Classify transcripts directly from Vietnamese (Python/Claude)
if 0 {
  !python3 "${folder}/code/classify_vn.py"
}

// Step 4c: Re-classify with confidence scores (for AUROC analysis)
if 0 {
  !python3 "${folder}/code/classify_conf.py"
  !python3 "${folder}/code/classify_conf_vn.py"
}

// Step 5: Compile scores (merge Claude + human + expert data)
if 0 {
  !python3 "${folder}/code/compile.py"
}

// Step 6: Data construction and analysis
if 1 {
  do "${folder}/code/5_data-construct.do"
}

//
