#!/usr/bin/env python3
"""
classify.py -- Rubric-based clinical extraction using Claude CLI.

Reads pilot consultation transcripts from pilot.dta and a structured rubric
from rubric.json, then uses Claude (via the `claude` CLI) to score each
observation against all relevant rubric items in a single prompt.

Outputs:
  - data/pilot-coded.dta   (binary indicator columns, one per rubric item)
  - data/pilot-coded.json  (full results with evidence, for debugging)

Usage:
    python3 code/classify.py
"""

import json
import re
import subprocess
import sys
import time
from pathlib import Path

import pandas as pd

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

PROJECT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT / "data"
CODE_DIR = PROJECT / "code"

INPUT_DTA = DATA_DIR / "pilot.dta"
RUBRIC_JSON = CODE_DIR / "rubric.json"
OUTPUT_DTA = DATA_DIR / "pilot-coded.dta"
OUTPUT_JSON = DATA_DIR / "pilot-coded.json"

MODEL = "claude-haiku-4-5-20251001"
MAX_RETRIES = 1

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def load_rubric(path: Path) -> dict:
    """Load the rubric JSON file."""
    with open(path, "r") as f:
        return json.load(f)


def get_rubric_items(rubric: dict, condition: str) -> list[dict]:
    """Return the combined list of case-specific + common rubric items."""
    items = []
    if condition in rubric["cases"]:
        items.extend(rubric["cases"][condition]["items"])
    items.extend(rubric["common"]["items"])
    return items


def get_all_item_ids(rubric: dict) -> list[str]:
    """Return a sorted list of every unique rubric item id across all cases."""
    ids = set()
    for case_data in rubric["cases"].values():
        for item in case_data["items"]:
            ids.add(item["id"])
    for item in rubric["common"]["items"]:
        ids.add(item["id"])
    return sorted(ids)


def build_prompt(transcript: str, diagnosis: str, treatment: str,
                 rubric_items: list[dict]) -> str:
    """Build the classification prompt for a single observation."""

    items_json = json.dumps(rubric_items, indent=2)

    prompt = f"""\
You are evaluating a healthcare provider's clinical consultation transcript.
Your task is to determine whether the provider addressed each rubric item
during the consultation.

## CONSULTATION CONTEXT

**Transcript:**
{transcript}

**Provider's Diagnosis:** {diagnosis}

**Provider's Treatment Plan:** {treatment}

## RUBRIC ITEMS

For each item below, determine if the provider addressed it (score=1) or
did not address it (score=0). If scored=1, provide a brief quote from the
transcript as evidence. If scored=0, set evidence to null.

Each item has:
- "id": unique identifier
- "label": short description
- "action": what the provider should do (e.g., "ask about", "examine", "prescribe")
- "question": the specific question or action to look for

{items_json}

## RESPONSE FORMAT

Return a JSON array with this exact structure:
[
  {{"id": "item_id", "score": 0, "evidence": null}},
  {{"id": "item_id", "score": 1, "evidence": "brief quote from transcript"}}
]

Return ONLY valid JSON, no other text. The array must contain exactly \
{len(rubric_items)} entries, one per rubric item, in the same order as above."""

    return prompt


def strip_markdown_fencing(text: str) -> str:
    """Remove ```json ... ``` fencing if present."""
    text = text.strip()
    # Match ```json ... ``` or ``` ... ```
    m = re.match(r"^```(?:json)?\s*\n(.*)\n```\s*$", text, re.DOTALL)
    if m:
        return m.group(1).strip()
    return text


def call_claude(prompt: str, attempt: int = 0) -> list[dict] | None:
    """Call the Claude CLI and parse the JSON response.

    Returns the parsed list of score dicts, or None on failure.
    """
    try:
        result = subprocess.run(
            ["claude", "-p", "--model", MODEL],
            input=prompt,
            capture_output=True,
            text=True,
            timeout=300,
        )

        if result.returncode != 0:
            print(f"    WARNING: claude returned exit code {result.returncode}",
                  file=sys.stderr)
            if result.stderr:
                print(f"    stderr: {result.stderr[:500]}", file=sys.stderr)
            if attempt < MAX_RETRIES:
                print(f"    Retrying ({attempt + 1}/{MAX_RETRIES})...")
                time.sleep(2)
                return call_claude(prompt, attempt + 1)
            return None

        raw = result.stdout
        cleaned = strip_markdown_fencing(raw)
        scores = json.loads(cleaned)

        if not isinstance(scores, list):
            raise ValueError(f"Expected list, got {type(scores).__name__}")

        return scores

    except json.JSONDecodeError as e:
        print(f"    WARNING: JSON parse error: {e}", file=sys.stderr)
        if attempt < MAX_RETRIES:
            print(f"    Retrying ({attempt + 1}/{MAX_RETRIES})...")
            time.sleep(2)
            return call_claude(prompt, attempt + 1)
        return None

    except subprocess.TimeoutExpired:
        print("    WARNING: claude CLI timed out after 300s", file=sys.stderr)
        if attempt < MAX_RETRIES:
            print(f"    Retrying ({attempt + 1}/{MAX_RETRIES})...")
            time.sleep(2)
            return call_claude(prompt, attempt + 1)
        return None

    except Exception as e:
        print(f"    WARNING: Unexpected error: {e}", file=sys.stderr)
        if attempt < MAX_RETRIES:
            print(f"    Retrying ({attempt + 1}/{MAX_RETRIES})...")
            time.sleep(2)
            return call_claude(prompt, attempt + 1)
        return None


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    # Load data
    print(f"Loading data from {INPUT_DTA} ...")
    df = pd.read_stata(str(INPUT_DTA))
    N = len(df)
    print(f"  {N} observations loaded.")

    # Load rubric
    print(f"Loading rubric from {RUBRIC_JSON} ...")
    rubric = load_rubric(RUBRIC_JSON)
    all_item_ids = get_all_item_ids(rubric)
    print(f"  {len(all_item_ids)} unique rubric items across all cases.")

    # Initialize output columns (all NaN -- items only scored for matching cases)
    empty_cols = pd.DataFrame(
        {item_id: pd.array([pd.NA] * N, dtype="Int64") for item_id in all_item_ids}
    )
    df = pd.concat([df, empty_cols], axis=1)

    # Store full evidence results for JSON output
    all_evidence = []

    # Process each observation
    print(f"\nClassifying {N} observations...\n")

    for idx in range(N):
        row = df.iloc[idx]
        condition = str(row["condition"]).strip()
        obs_num = idx + 1

        print(f"[{obs_num}/{N}] Classifying {condition} observation "
              f"(name={row.get('name', '?')}, case={row.get('case', '?')}) ...")

        # Get text fields, handling NaN
        transcript = str(row["transcript_en"]) if pd.notna(row["transcript_en"]) else ""
        diagnosis = str(row["diagnosis_en"]) if pd.notna(row["diagnosis_en"]) else ""
        treatment = str(row["treatment_post_en"]) if pd.notna(row["treatment_post_en"]) else ""

        if not transcript.strip():
            print(f"    SKIPPING: empty transcript.")
            all_evidence.append({
                "index": idx,
                "condition": condition,
                "error": "empty transcript",
                "scores": []
            })
            continue

        # Build item list for this case
        items = get_rubric_items(rubric, condition)
        if not items:
            print(f"    SKIPPING: no rubric items for condition '{condition}'.")
            all_evidence.append({
                "index": idx,
                "condition": condition,
                "error": f"no rubric items for condition '{condition}'",
                "scores": []
            })
            continue

        # Build prompt and call Claude
        prompt = build_prompt(transcript, diagnosis, treatment, items)
        scores = call_claude(prompt)

        if scores is None:
            print(f"    FAILED: could not get valid response. Skipping.")
            all_evidence.append({
                "index": idx,
                "condition": condition,
                "error": "API call failed after retries",
                "scores": []
            })
            continue

        # Parse scores into DataFrame columns
        score_map = {s["id"]: s for s in scores if "id" in s}
        scored_count = 0
        for item in items:
            item_id = item["id"]
            if item_id in score_map:
                val = score_map[item_id].get("score", 0)
                # Ensure binary 0/1
                df.at[idx, item_id] = 1 if val == 1 else 0
                scored_count += 1
            else:
                # Item was in the prompt but not in the response
                df.at[idx, item_id] = 0

        ones = sum(1 for s in scores if s.get("score") == 1)
        print(f"    Done: {scored_count}/{len(items)} items scored, "
              f"{ones} positive.")

        all_evidence.append({
            "index": idx,
            "condition": condition,
            "name": str(row.get("name", "")),
            "case": str(row.get("case", "")),
            "n_items": len(items),
            "n_scored": scored_count,
            "n_positive": ones,
            "scores": scores
        })

    # ------------------------------------------------------------------
    # Convert indicator columns to numeric (they may be object/NA mix)
    # ------------------------------------------------------------------
    for item_id in all_item_ids:
        df[item_id] = pd.to_numeric(df[item_id], errors="coerce")

    # ------------------------------------------------------------------
    # Save outputs
    # ------------------------------------------------------------------
    print(f"\nSaving coded data to {OUTPUT_DTA} ...")
    # Stata requires string columns to not exceed 2045 chars for str type;
    # long strings are handled as strL. Pandas handles this automatically.
    df.to_stata(str(OUTPUT_DTA), write_index=False, version=118)
    print("  Done.")

    print(f"Saving evidence JSON to {OUTPUT_JSON} ...")
    with open(OUTPUT_JSON, "w") as f:
        json.dump(all_evidence, f, indent=2, ensure_ascii=False)
    print("  Done.")

    # Summary
    n_success = sum(1 for e in all_evidence if "error" not in e)
    n_fail = sum(1 for e in all_evidence if "error" in e)
    print(f"\nComplete: {n_success} classified, {n_fail} failed/skipped.")


if __name__ == "__main__":
    main()
    sys.exit(0)
