from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Iterable

import pandas as pd


ROOT = Path(__file__).resolve().parents[2]
RAW_ROOT = ROOT / "data" / "raw"
CLEAN_ROOT = ROOT / "data" / "processed" / "NHANES"


def decode_bytes(value):
    if isinstance(value, bytes):
        for encoding in ("utf-8", "latin1", "cp1252"):
            try:
                return value.decode(encoding)
            except UnicodeDecodeError:
                continue
    return value


def clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    cleaned = df.copy()
    cleaned.columns = [str(col).strip() for col in cleaned.columns]
    for col in cleaned.select_dtypes(include=["object"]).columns:
        cleaned[col] = cleaned[col].map(decode_bytes)
    return cleaned


def md5_of(path: Path) -> str:
    digest = hashlib.md5()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def xpt_files(directory: Path) -> list[Path]:
    return sorted([p for p in directory.iterdir() if p.is_file() and p.suffix.lower() == ".xpt"])


def workbook_files(directory: Path) -> list[Path]:
    return sorted([p for p in directory.iterdir() if p.is_file() and p.suffix.lower() in {".xlsx", ".xls"}])


def prefixed_for_merge(df: pd.DataFrame, prefix: str) -> pd.DataFrame:
    renamed = {}
    for col in df.columns:
        if col != "SEQN":
            renamed[col] = f"{prefix}__{col}"
    return df.rename(columns=renamed)


def write_csv(df: pd.DataFrame, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(path, index=False, compression="gzip")


def process_nhanes_cycle(cycle_dir: Path, summary: dict) -> None:
    cycle_out = CLEAN_ROOT / cycle_dir.name
    cycle_out.mkdir(parents=True, exist_ok=True)

    manifests = []
    columns_manifest = []
    dataframes = {}

    for xpt_path in xpt_files(cycle_dir):
        df = pd.read_sas(xpt_path, format="xport")
        df = clean_dataframe(df)
        dataframes[xpt_path.stem] = df

        out_csv = cycle_out / f"{xpt_path.stem}.csv.gz"
        write_csv(df, out_csv)

        manifests.append(
            {
                "dataset": xpt_path.stem,
                "source_file": xpt_path.name,
                "rows": int(len(df)),
                "columns": int(len(df.columns)),
                "has_seqn": "SEQN" in df.columns,
                "source_md5": md5_of(xpt_path),
                "cleaned_file": out_csv.name,
            }
        )
        for idx, column in enumerate(df.columns, start=1):
            columns_manifest.append(
                {
                    "dataset": xpt_path.stem,
                    "position": idx,
                    "column_name": column,
                    "dtype": str(df[column].dtype),
                }
            )

    pd.DataFrame(manifests).to_csv(cycle_out / "dataset_manifest.csv", index=False)
    pd.DataFrame(columns_manifest).to_csv(cycle_out / "columns_manifest.csv", index=False)

    merged = None
    mergeable = []
    for name, df in dataframes.items():
        if "SEQN" not in df.columns:
            continue
        mergeable.append(name)
        current = prefixed_for_merge(df, name)
        merged = current if merged is None else merged.merge(current, on="SEQN", how="outer")

    if merged is not None:
        write_csv(merged, cycle_out / "merged_all_prefixed.csv.gz")

    summary["nhanes_cycles"].append(
        {
            "cycle": cycle_dir.name,
            "datasets": sorted(dataframes.keys()),
            "mergeable_on_seqn": sorted(mergeable),
        }
    )


def build_bridge_dataset(summary: dict) -> None:
    bridge_specs = [
        ("NHANES_1999_2000", ["DEMO", "BMX", "BIX", "DXX"]),
        ("NHANES_2001_2002", ["DEMO_B", "BMX_B", "BIX_B", "DXX_B"]),
        ("NHANES_2003_2004", ["DEMO_C", "BMX_C", "BIX_C", "DXX_C"]),
    ]
    bridge_frames = []

    for cycle_name, stems in bridge_specs:
        cycle_dir = CLEAN_ROOT / cycle_name
        if not cycle_dir.exists():
            continue

        merged = None
        used = []
        for stem in stems:
            csv_path = cycle_dir / f"{stem}.csv.gz"
            if not csv_path.exists():
                continue
            df = pd.read_csv(csv_path)
            if "SEQN" not in df.columns:
                continue
            used.append(stem)
            current = prefixed_for_merge(df, stem)
            merged = current if merged is None else merged.merge(current, on="SEQN", how="outer")

        if merged is not None:
            merged.insert(0, "nhanes_cycle", cycle_name)
            bridge_frames.append(merged)
            summary["bridge_cycles"].append({"cycle": cycle_name, "datasets": used})

    if bridge_frames:
        bridge = pd.concat(bridge_frames, ignore_index=True, sort=False)
        write_csv(bridge, CLEAN_ROOT / "NHANES_bridge_1999_2004_BIA_DXA.csv.gz")


def build_outcome_dataset(summary: dict) -> None:
    stems = ["DEMO_H", "BMX_H", "DXX_H", "DXXFEM_H", "DXXSPN_H", "DXXVFA_H", "DXXFRX_H", "OSQ_H"]
    cycle_dir = CLEAN_ROOT / "NHANES_2013_2014"
    if not cycle_dir.exists():
        return

    merged = None
    used = []
    for stem in stems:
        csv_path = cycle_dir / f"{stem}.csv.gz"
        if not csv_path.exists():
            continue
        df = pd.read_csv(csv_path)
        if "SEQN" not in df.columns:
            continue
        used.append(stem)
        current = prefixed_for_merge(df, stem)
        merged = current if merged is None else merged.merge(current, on="SEQN", how="outer")

    if merged is not None:
        write_csv(merged, CLEAN_ROOT / "NHANES_2013_2014_outcome_bundle.csv.gz")
        summary["outcome_bundle"] = {"cycle": "NHANES_2013_2014", "datasets": used}


def process_figshare_dataset(source_dir: Path, summary: dict) -> None:
    if not source_dir.exists():
        return

    out_dir = CLEAN_ROOT / source_dir.name
    out_dir.mkdir(parents=True, exist_ok=True)
    workbook_manifest = []
    sheet_manifest = []

    for workbook in workbook_files(source_dir):
        workbook_manifest.append(
            {
                "file_name": workbook.name,
                "size_bytes": workbook.stat().st_size,
                "md5": md5_of(workbook),
            }
        )
        excel = pd.ExcelFile(workbook)
        for sheet_name in excel.sheet_names:
            df = pd.read_excel(workbook, sheet_name=sheet_name)
            df = clean_dataframe(df)
            safe_sheet = "".join(ch if ch.isalnum() or ch in ("-", "_") else "_" for ch in sheet_name).strip("_")
            out_name = f"{workbook.stem}__{safe_sheet or 'Sheet'}.csv.gz"
            write_csv(df, out_dir / out_name)
            sheet_manifest.append(
                {
                    "workbook": workbook.name,
                    "sheet_name": sheet_name,
                    "rows": int(len(df)),
                    "columns": int(len(df.columns)),
                    "cleaned_file": out_name,
                }
            )

    if workbook_manifest:
        pd.DataFrame(workbook_manifest).to_csv(out_dir / "workbook_manifest.csv", index=False)
        pd.DataFrame(sheet_manifest).to_csv(out_dir / "sheet_manifest.csv", index=False)
        summary["figshare_datasets"].append(
            {"dataset": source_dir.name, "workbooks": [item["file_name"] for item in workbook_manifest]}
        )


def main() -> None:
    CLEAN_ROOT.mkdir(parents=True, exist_ok=True)
    summary = {
        "generated_at": pd.Timestamp.now(tz="Asia/Shanghai").isoformat(),
        "nhanes_cycles": [],
        "bridge_cycles": [],
        "figshare_datasets": [],
    }

    for cycle_dir in sorted(RAW_ROOT.glob("NHANES_*")):
        if cycle_dir.is_dir():
            process_nhanes_cycle(cycle_dir, summary)

    build_bridge_dataset(summary)
    build_outcome_dataset(summary)
    # Optional example for additional open datasets can be added here.

    (CLEAN_ROOT / "processing_summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()

