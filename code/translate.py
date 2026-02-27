#!/usr/bin/env python3
"""Translate Vietnamese medical text fields in pilot.dta to English using the Claude CLI."""

import subprocess
import pandas as pd
import pyreadstat
from pathlib import Path


# Fields to translate: (source_column, target_column)
FIELDS = [
    ("transcript_clean", "transcript_en"),
    ("diagnosis", "diagnosis_en"),
    ("treatment", "treatment_en"),
    ("treatment_post", "treatment_post_en"),
]

PROMPT_TEMPLATE = (
    "Translate the following Vietnamese medical text to English. "
    "Output ONLY the translation, no commentary:\n\n{text}"
)


def translate_text(text: str) -> str:
    """Translate Vietnamese text to English using the Claude CLI.

    Args:
        text: Vietnamese text to translate.

    Returns:
        English translation.

    Raises:
        RuntimeError: If the Claude CLI call fails.
    """
    prompt = PROMPT_TEMPLATE.format(text=text)
    result = subprocess.run(
        ["claude", "-p", "--model", "claude-haiku-4-5-20251001"],
        input=prompt,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Claude CLI failed (exit {result.returncode}): {result.stderr.strip()}"
        )
    return result.stdout.strip()


def translate_dataset(input_path: Path, output_path: Path) -> pd.DataFrame:
    """Read a Stata .dta file, translate Vietnamese fields, and save the result.

    Args:
        input_path: Path to the input .dta file.
        output_path: Path where the updated .dta file will be saved.

    Returns:
        The updated DataFrame.
    """
    df, meta = pyreadstat.read_dta(str(input_path))
    n = len(df)

    for src_col, tgt_col in FIELDS:
        if src_col not in df.columns:
            print(f"WARNING: column '{src_col}' not found in dataset -- skipping.")
            continue

        # Ensure the target column exists
        if tgt_col not in df.columns:
            df[tgt_col] = ""

        for i in range(n):
            text = df.at[i, src_col]

            # Skip empty / NaN values
            if pd.isna(text) or str(text).strip() == "":
                continue

            print(f"[{i + 1}/{n}] Translating {src_col}...")
            translation = translate_text(str(text))
            df.at[i, tgt_col] = translation

    # Write back to Stata format
    pyreadstat.write_dta(df, str(output_path))
    print(f"\nDone. Saved translated dataset to {output_path}")
    return df


def main() -> None:
    """Entry point for standalone execution."""
    project_root = Path(__file__).resolve().parent.parent
    data_path = project_root / "data" / "pilot.dta"
    translate_dataset(data_path, data_path)


if __name__ == "__main__":
    main()
