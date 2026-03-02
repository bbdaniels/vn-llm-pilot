#!/usr/bin/env python3
"""compile.py -- Build compiled scores and item-level agreement from source data.

Reads:
  - data/pilot-coded.dta       (Claude-coded binary indicators)
  - data/pilot-human.xlsx      (Human-coded binary indicators)
  - data/pilot-compiled-scores.xlsx  (Expert ratings + MCQ scores)
  - code/rubric.json           (Item definitions per condition)

Outputs:
  - data/compiled-scores.dta   (Observation-level: human %, Claude %, expert, MCQ)
  - data/agreement-long.dta    (Item-level: human vs Claude for each obs)

Usage:
    python3 code/compile.py
"""

import json
import sys
from pathlib import Path

import pandas as pd

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

PROJECT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT / "data"
CODE_DIR = PROJECT / "code"

CLAUDE_DTA = DATA_DIR / "pilot-coded.dta"
CLAUDE_VN_DTA = DATA_DIR / "pilot-coded-vn.dta"
CLAUDE_CONF_DTA = DATA_DIR / "pilot-coded-conf.dta"
CLAUDE_CONF_VN_DTA = DATA_DIR / "pilot-coded-conf-vn.dta"
HUMAN_XLSX = DATA_DIR / "pilot-human.xlsx"
COMPILED_XLSX = DATA_DIR / "pilot-compiled-scores.xlsx"
RUBRIC_JSON = CODE_DIR / "rubric.json"

OUT_SCORES = DATA_DIR / "compiled-scores.dta"
OUT_AGREEMENT = DATA_DIR / "agreement-long.dta"

# ---------------------------------------------------------------------------
# Case number to condition mapping (from SurveyCTO case pool)
# ---------------------------------------------------------------------------

CASE_MAP = {
    1: "ast", 2: "pne", 3: "t2d", 4: "tb1", 5: "htn",
    6: "hbc", 7: "hbp", 8: "hbv", 9: "hcv", 10: "arv",
}

# Human data uses "tb_" prefix; rubric/Claude use "tb1_"
HUMAN_PREFIX_MAP = {"tb1": "tb"}


def load_rubric(path: Path) -> dict:
    with open(path) as f:
        return json.load(f)


def get_item_ids(rubric: dict, condition: str) -> list[str]:
    """Return list of rubric item IDs for a condition (case-specific + common)."""
    ids = []
    if condition in rubric["cases"]:
        ids.extend(item["id"] for item in rubric["cases"][condition]["items"])
    ids.extend(item["id"] for item in rubric["common"]["items"])
    return ids


def claude_to_human_id(item_id: str) -> str:
    """Map a rubric/Claude item ID to the corresponding human data column name."""
    for rubric_prefix, human_prefix in HUMAN_PREFIX_MAP.items():
        if item_id.startswith(rubric_prefix + "_"):
            return human_prefix + "_" + item_id[len(rubric_prefix) + 1:]
    return item_id


def compute_checklist_pct(row, item_ids: list[str], df_columns: set) -> float | None:
    """Compute % of checklist items scored 1, ignoring items not in the data."""
    valid_items = [iid for iid in item_ids if iid in df_columns]
    if not valid_items:
        return None
    total = 0
    scored = 0
    for iid in valid_items:
        val = row[iid]
        if pd.notna(val):
            total += 1
            if val == 1:
                scored += 1
        else:
            total += 1  # count NA as 0 (not addressed)
    return (scored / total) * 100 if total > 0 else None


def main():
    print("Loading rubric...")
    rubric = load_rubric(RUBRIC_JSON)

    print("Loading Claude-coded data (English)...")
    df_claude = pd.read_stata(str(CLAUDE_DTA))
    print(f"  {len(df_claude)} observations")

    print("Loading Claude-coded data (Vietnamese)...")
    df_claude_vn = pd.read_stata(str(CLAUDE_VN_DTA))
    print(f"  {len(df_claude_vn)} observations")

    # Load confidence-scored data (for AUROC)
    df_conf = None
    df_conf_vn = None
    if CLAUDE_CONF_DTA.exists():
        print("Loading Claude confidence data (English)...")
        df_conf = pd.read_stata(str(CLAUDE_CONF_DTA))
        print(f"  {len(df_conf)} observations")
    else:
        print("  (No confidence data for English -- skipping)")

    if CLAUDE_CONF_VN_DTA.exists():
        print("Loading Claude confidence data (Vietnamese)...")
        df_conf_vn = pd.read_stata(str(CLAUDE_CONF_VN_DTA))
        print(f"  {len(df_conf_vn)} observations")
    else:
        print("  (No confidence data for Vietnamese -- skipping)")

    conf_cols = set(df_conf.columns) if df_conf is not None else set()
    conf_vn_cols = set(df_conf_vn.columns) if df_conf_vn is not None else set()

    print("Loading human-coded data...")
    df_human = pd.read_excel(str(HUMAN_XLSX))
    print(f"  {len(df_human)} observations")

    print("Loading compiled scores (expert ratings + MCQ)...")
    df_compiled = pd.read_excel(str(COMPILED_XLSX), sheet_name="All_Scores")
    print(f"  {len(df_compiled)} observations")

    # Add condition to human data from case number mapping
    df_human = df_human.copy()
    df_human["name"] = df_human["cp_1"]
    df_human["condition"] = df_human["cp_2"].map(CASE_MAP)

    # Verify alignment: human and compiled should be row-aligned (both 130 obs)
    assert len(df_human) == len(df_compiled), \
        f"Row count mismatch: human={len(df_human)}, compiled={len(df_compiled)}"

    # ------------------------------------------------------------------
    # Build observation-level scores
    # ------------------------------------------------------------------
    print("\nComputing checklist percentages...")

    claude_cols = set(df_claude.columns)
    claude_vn_cols = set(df_claude_vn.columns)
    human_cols = set(df_human.columns)

    results = []
    agreement_rows = []

    for i in range(len(df_compiled)):
        name = df_compiled.at[i, "name"]
        condition = df_compiled.at[i, "condition"]

        if pd.isna(name) or str(name).strip() == "":
            continue

        # Get rubric items for this condition
        item_ids = get_item_ids(rubric, condition)

        # -- Claude checklist % --
        # Find matching row in Claude data by name + condition
        claude_match = df_claude[
            (df_claude["name"] == name) & (df_claude["condition"] == condition)
        ]
        claude_pct = None
        if len(claude_match) == 1:
            claude_row = claude_match.iloc[0]
            valid = [iid for iid in item_ids if iid in claude_cols]
            n_total = len(valid)
            n_scored = sum(1 for iid in valid
                          if pd.notna(claude_row[iid]) and claude_row[iid] == 1)
            claude_pct = (n_scored / n_total) * 100 if n_total > 0 else None

        # -- Claude (Vietnamese) checklist % --
        claude_vn_match = df_claude_vn[
            (df_claude_vn["name"] == name) & (df_claude_vn["condition"] == condition)
        ]
        claude_vn_pct = None
        if len(claude_vn_match) == 1:
            claude_vn_row = claude_vn_match.iloc[0]
            valid_vn = [iid for iid in item_ids if iid in claude_vn_cols]
            n_total_vn = len(valid_vn)
            n_scored_vn = sum(1 for iid in valid_vn
                              if pd.notna(claude_vn_row[iid]) and claude_vn_row[iid] == 1)
            claude_vn_pct = (n_scored_vn / n_total_vn) * 100 if n_total_vn > 0 else None

        # -- Human checklist % --
        human_row = df_human.iloc[i]
        human_item_map = {}  # rubric_id -> human_col
        for iid in item_ids:
            hid = claude_to_human_id(iid)
            if hid in human_cols:
                human_item_map[iid] = hid

        n_total_h = len(human_item_map)
        n_scored_h = sum(1 for iid, hid in human_item_map.items()
                         if pd.notna(human_row[hid]) and human_row[hid] == 1)
        human_pct = (n_scored_h / n_total_h) * 100 if n_total_h > 0 else None

        # -- Item-level agreement rows --
        if len(claude_match) == 1:
            claude_row = claude_match.iloc[0]
            claude_vn_row_a = (claude_vn_match.iloc[0]
                               if len(claude_vn_match) == 1 else None)

            # Match confidence data rows
            conf_row = None
            if df_conf is not None:
                conf_match = df_conf[
                    (df_conf["name"] == name) & (df_conf["condition"] == condition)
                ]
                if len(conf_match) == 1:
                    conf_row = conf_match.iloc[0]

            conf_vn_row = None
            if df_conf_vn is not None:
                conf_vn_match = df_conf_vn[
                    (df_conf_vn["name"] == name) & (df_conf_vn["condition"] == condition)
                ]
                if len(conf_vn_match) == 1:
                    conf_vn_row = conf_vn_match.iloc[0]

            for iid in item_ids:
                hid = claude_to_human_id(iid)
                human_val = None
                claude_val = None
                claude_vn_val = None
                llm_conf = None
                llm_vn_conf = None

                if hid in human_cols and pd.notna(human_row[hid]):
                    human_val = int(human_row[hid])
                if iid in claude_cols and pd.notna(claude_row[iid]):
                    claude_val = int(claude_row[iid])
                if (claude_vn_row_a is not None and iid in claude_vn_cols
                        and pd.notna(claude_vn_row_a[iid])):
                    claude_vn_val = int(claude_vn_row_a[iid])

                # Confidence scores
                conf_col = iid + "_conf"
                if (conf_row is not None and conf_col in conf_cols
                        and pd.notna(conf_row[conf_col])):
                    llm_conf = float(conf_row[conf_col])
                if (conf_vn_row is not None and conf_col in conf_vn_cols
                        and pd.notna(conf_vn_row[conf_col])):
                    llm_vn_conf = float(conf_vn_row[conf_col])

                agreement_rows.append({
                    "item": iid,
                    "provider": name,
                    "condition": condition,
                    "human": human_val,
                    "llm": claude_val,
                    "llm_vn": claude_vn_val,
                    "llm_conf": llm_conf,
                    "llm_vn_conf": llm_vn_conf,
                })

        results.append({
            "name": name,
            "condition": condition,
            "human_pct": human_pct,
            "claude_pct": claude_pct,
            "claude_vn_pct": claude_vn_pct,
            "expert1": df_compiled.at[i, "expert1_chat"],
            "expert2": df_compiled.at[i, "expert2_chat"],
            "mcq_pct": df_compiled.at[i, "redcap_perc_correct"],
        })

    # ------------------------------------------------------------------
    # Save observation-level scores
    # ------------------------------------------------------------------
    df_scores = pd.DataFrame(results)

    # Match count
    matched = df_scores["claude_pct"].notna().sum()
    print(f"  {matched}/{len(df_scores)} observations matched Claude data")

    print(f"\nSaving compiled scores to {OUT_SCORES}...")
    df_scores.to_stata(str(OUT_SCORES), write_index=False, version=118)

    # ------------------------------------------------------------------
    # Save item-level agreement
    # ------------------------------------------------------------------
    df_agree = pd.DataFrame(agreement_rows)
    print(f"Saving agreement data ({len(df_agree)} rows) to {OUT_AGREEMENT}...")
    df_agree.to_stata(str(OUT_AGREEMENT), write_index=False, version=118)

    # Summary stats
    print(f"\n--- Summary ---")
    print(f"Human checklist mean: {df_scores['human_pct'].mean():.1f}%")
    print(f"Claude (English) checklist mean: {df_scores['claude_pct'].mean():.1f}%")
    print(f"Claude (Vietnamese) checklist mean: {df_scores['claude_vn_pct'].mean():.1f}%")
    both = df_agree.dropna(subset=["human", "llm"])
    agree = (both["human"] == both["llm"]).mean()
    print(f"Item-level agreement: {agree:.1%}")
    print("Done.")


if __name__ == "__main__":
    main()
    sys.exit(0)
