from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import LinearRegression, LogisticRegression
from sklearn.metrics import roc_auc_score


ROOT = Path(__file__).resolve().parents[2]
CLEAN_ROOT = ROOT / "data" / "processed" / "NHANES"
OUT_ROOT = ROOT / "outputs" / "nhanes"


def yn(series: pd.Series) -> np.ndarray:
    return np.where(series == 1, 1, np.where(series == 2, 0, np.nan))


def zscore_frame(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    for col in out.columns:
        if col != "sex_male":
            out[col] = (out[col] - out[col].mean()) / out[col].std()
    return out


def prepare_bridge() -> tuple[pd.DataFrame, dict]:
    bridge = pd.read_csv(CLEAN_ROOT / "NHANES_bridge_1999_2004_BIA_DXA.csv.gz")
    bridge["age"] = np.nan
    bridge["sex"] = np.nan
    bridge["bia_ffm"] = np.nan
    bridge["bia_fat"] = np.nan
    bridge["dxa_lean"] = np.nan
    bridge["dxa_bmc"] = np.nan
    bridge["dxa_fat"] = np.nan

    for col in ["DEMO__RIDAGEYR", "DEMO_B__RIDAGEYR", "DEMO_C__RIDAGEYR"]:
        if col in bridge.columns:
            bridge["age"] = bridge["age"].fillna(bridge[col])
    for col in ["DEMO__RIAGENDR", "DEMO_B__RIAGENDR", "DEMO_C__RIAGENDR"]:
        if col in bridge.columns:
            bridge["sex"] = bridge["sex"].fillna(bridge[col])
    for col in ["BIX__BIDFFM", "BIX_B__BIDFFM", "BIX_C__BIDFFM"]:
        if col in bridge.columns:
            bridge["bia_ffm"] = bridge["bia_ffm"].fillna(bridge[col])
    for col in ["BIX__BIDFAT", "BIX_B__BIDFAT", "BIX_C__BIDFAT"]:
        if col in bridge.columns:
            bridge["bia_fat"] = bridge["bia_fat"].fillna(bridge[col])
    for col in ["DXX__DXDTOLE", "DXX_B__DXDTOLE", "DXX_C__DXDTOLE"]:
        if col in bridge.columns:
            bridge["dxa_lean"] = bridge["dxa_lean"].fillna(bridge[col])
    for col in ["DXX__DXDTOBMC", "DXX_B__DXDTOBMC", "DXX_C__DXDTOBMC"]:
        if col in bridge.columns:
            bridge["dxa_bmc"] = bridge["dxa_bmc"].fillna(bridge[col])
    for col in ["DXX__DXDTOFAT", "DXX_B__DXDTOFAT", "DXX_C__DXDTOFAT"]:
        if col in bridge.columns:
            bridge["dxa_fat"] = bridge["dxa_fat"].fillna(bridge[col])

    usable = bridge[
        ["nhanes_cycle", "age", "sex", "bia_ffm", "bia_fat", "dxa_lean", "dxa_bmc", "dxa_fat"]
    ].dropna()

    summary = {
        "n_complete": int(len(usable)),
        "age_min": float(usable["age"].min()),
        "age_max": float(usable["age"].max()),
        "corr_bia_ffm_dxa_lean": float(usable["bia_ffm"].corr(usable["dxa_lean"])),
        "corr_bia_fat_dxa_fat": float(usable["bia_fat"].corr(usable["dxa_fat"])),
        "corr_bia_ffm_dxa_bmc": float(usable["bia_ffm"].corr(usable["dxa_bmc"])),
    }
    return usable, summary


def prepare_outcome() -> pd.DataFrame:
    outcome = pd.read_csv(CLEAN_ROOT / "NHANES_2013_2014_outcome_bundle.csv.gz")
    outcome["age"] = outcome["DEMO_H__RIDAGEYR"]
    outcome["sex"] = outcome["DEMO_H__RIAGENDR"]
    outcome["sex_male"] = (outcome["sex"] == 1).astype(float)
    outcome["weight"] = outcome["BMX_H__BMXWT"]
    outcome["height"] = outcome["BMX_H__BMXHT"]
    outcome["dxa_lean"] = outcome["DXX_H__DXDTOLE"]
    outcome["dxa_bmc"] = outcome["DXX_H__DXDTOBMC"]
    outcome["dxa_fat"] = outcome["DXX_H__DXDTOFAT"]
    outcome["dxa_mbr"] = outcome["dxa_lean"] / outcome["dxa_bmc"]
    outcome["osta"] = 0.2 * (outcome["weight"] - outcome["age"])
    outcome["osta_risk"] = -outcome["osta"]
    outcome["hip_frax"] = np.where(
        outcome["DXXFRX_H__DXXPRVFX"] == 1,
        outcome["DXXFRX_H__DXXFRAX1"],
        np.where(outcome["DXXFRX_H__DXXPRVFX"] == 2, outcome["DXXFRX_H__DXXFRAX3"], np.nan),
    )
    outcome["major_frax"] = np.where(
        outcome["DXXFRX_H__DXXPRVFX"] == 1,
        outcome["DXXFRX_H__DXXFRAX2"],
        np.where(outcome["DXXFRX_H__DXXPRVFX"] == 2, outcome["DXXFRX_H__DXXFRAX4"], np.nan),
    )
    outcome["prev_fracture"] = yn(outcome["DXXFRX_H__DXXPRVFX"])
    outcome["vertebral_fx"] = np.where(
        outcome["DXXVFA_H__DXXVFAST"] == 2,
        1,
        np.where(outcome["DXXVFA_H__DXXVFAST"] == 1, 0, np.nan),
    )
    outcome["self_report_osteoporosis"] = yn(outcome["OSQ_H__OSQ060"])
    outcome["self_report_hip_fx"] = yn(outcome["OSQ_H__OSQ010A"])
    outcome["self_report_spine_fx"] = yn(outcome["OSQ_H__OSQ010C"])
    return outcome[outcome["age"] >= 40].copy()


def structure_tables(outcome: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for sex_val, sex_name in [(1, "male"), (2, "female")]:
        ss = outcome[
            (outcome["sex"] == sex_val)
            & outcome[["dxa_mbr", "dxa_lean", "dxa_bmc", "dxa_fat", "age", "weight"]].notna().all(axis=1)
        ].copy()
        ss["mbr_q"] = pd.qcut(ss["dxa_mbr"], 4, labels=["Q1", "Q2", "Q3", "Q4"])
        summary = (
            ss.groupby("mbr_q", observed=False)
            .agg(
                n=("SEQN", "size"),
                age_mean=("age", "mean"),
                lean_mean=("dxa_lean", "mean"),
                bmc_mean=("dxa_bmc", "mean"),
                fat_mean=("dxa_fat", "mean"),
                weight_mean=("weight", "mean"),
            )
            .reset_index()
        )
        summary.insert(0, "sex", sex_name)
        rows.append(summary)
    return pd.concat(rows, ignore_index=True)


def auc_tables(outcome: pd.DataFrame) -> pd.DataFrame:
    endpoints = [
        "self_report_osteoporosis",
        "prev_fracture",
        "self_report_hip_fx",
        "self_report_spine_fx",
        "vertebral_fx",
    ]
    rows = []
    for endpoint in endpoints:
        df = outcome[["dxa_mbr", "osta_risk", endpoint, "sex"]].dropna().copy()
        if df[endpoint].nunique() < 2:
            continue
        rows.append(
            {
                "endpoint": endpoint,
                "group": "all",
                "n": int(len(df)),
                "events": int(df[endpoint].sum()),
                "auc_mbr": float(roc_auc_score(df[endpoint], df["dxa_mbr"])),
                "auc_osta": float(roc_auc_score(df[endpoint], df["osta_risk"])),
            }
        )
        for sex_val, sex_name in [(1, "male"), (2, "female")]:
            ss = df[df["sex"] == sex_val]
            if len(ss) > 20 and ss[endpoint].nunique() == 2:
                rows.append(
                    {
                        "endpoint": endpoint,
                        "group": sex_name,
                        "n": int(len(ss)),
                        "events": int(ss[endpoint].sum()),
                        "auc_mbr": float(roc_auc_score(ss[endpoint], ss["dxa_mbr"])),
                        "auc_osta": float(roc_auc_score(ss[endpoint], ss["osta_risk"])),
                    }
                )
    return pd.DataFrame(rows)


def frax_tables(outcome: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for sex_val, sex_name in [(1, "male"), (2, "female")]:
        ss = outcome[
            (outcome["sex"] == sex_val) & outcome[["dxa_mbr", "hip_frax", "major_frax"]].notna().all(axis=1)
        ].copy()
        ss["mbr_q"] = pd.qcut(ss["dxa_mbr"], 4, labels=["Q1", "Q2", "Q3", "Q4"])
        summary = (
            ss.groupby("mbr_q", observed=False)
            .agg(n=("SEQN", "size"), hip_frax_mean=("hip_frax", "mean"), major_frax_mean=("major_frax", "mean"))
            .reset_index()
        )
        summary.insert(0, "sex", sex_name)
        rows.append(summary)
    return pd.concat(rows, ignore_index=True)


def model_tables(outcome: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    linear_rows = []
    logistic_rows = []

    linear_features = ["dxa_mbr", "age", "sex_male", "weight"]
    for outcome_name in ["hip_frax", "major_frax"]:
        df = outcome[(outcome[linear_features + [outcome_name]].notna().all(axis=1))].copy()
        X = zscore_frame(df[linear_features])
        model = LinearRegression().fit(X, df[outcome_name])
        linear_rows.append(
            {
                "outcome": outcome_name,
                "n": int(len(df)),
                "r2": float(model.score(X, df[outcome_name])),
                "coef_dxa_mbr": float(model.coef_[0]),
                "coef_age": float(model.coef_[1]),
                "coef_sex_male": float(model.coef_[2]),
                "coef_weight": float(model.coef_[3]),
            }
        )

    logistic_features = ["dxa_mbr", "age", "sex_male", "weight"]
    for outcome_name in ["self_report_osteoporosis", "prev_fracture", "vertebral_fx"]:
        df = outcome[(outcome[logistic_features + [outcome_name]].notna().all(axis=1))].copy()
        X = zscore_frame(df[logistic_features])
        model = LogisticRegression(max_iter=2000).fit(X, df[outcome_name])
        probs = model.predict_proba(X)[:, 1]
        logistic_rows.append(
            {
                "outcome": outcome_name,
                "n": int(len(df)),
                "events": int(df[outcome_name].sum()),
                "auc": float(roc_auc_score(df[outcome_name], probs)),
                "coef_dxa_mbr": float(model.coef_[0][0]),
                "coef_age": float(model.coef_[0][1]),
                "coef_sex_male": float(model.coef_[0][2]),
                "coef_weight": float(model.coef_[0][3]),
            }
        )

    return pd.DataFrame(linear_rows), pd.DataFrame(logistic_rows)


def incremental_tables(outcome: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    linear_rows = []
    logistic_rows = []

    base_features = ["age", "sex_male", "weight"]
    plus_features = ["age", "sex_male", "weight", "dxa_mbr"]

    for outcome_name in ["hip_frax", "major_frax"]:
        df = outcome[(outcome[plus_features + [outcome_name]].notna().all(axis=1))].copy()
        X_base = zscore_frame(df[base_features])
        X_plus = zscore_frame(df[plus_features])
        r2_base = LinearRegression().fit(X_base, df[outcome_name]).score(X_base, df[outcome_name])
        r2_plus = LinearRegression().fit(X_plus, df[outcome_name]).score(X_plus, df[outcome_name])
        linear_rows.append(
            {
                "outcome": outcome_name,
                "n": int(len(df)),
                "r2_base": float(r2_base),
                "r2_plus_mbr": float(r2_plus),
                "delta_r2": float(r2_plus - r2_base),
            }
        )

    for outcome_name in ["self_report_osteoporosis", "prev_fracture", "vertebral_fx"]:
        df = outcome[(outcome[plus_features + [outcome_name]].notna().all(axis=1))].copy()
        X_base = zscore_frame(df[base_features])
        X_plus = zscore_frame(df[plus_features])
        model_base = LogisticRegression(max_iter=2000).fit(X_base, df[outcome_name])
        model_plus = LogisticRegression(max_iter=2000).fit(X_plus, df[outcome_name])
        auc_base = roc_auc_score(df[outcome_name], model_base.predict_proba(X_base)[:, 1])
        auc_plus = roc_auc_score(df[outcome_name], model_plus.predict_proba(X_plus)[:, 1])
        logistic_rows.append(
            {
                "outcome": outcome_name,
                "n": int(len(df)),
                "auc_base": float(auc_base),
                "auc_plus_mbr": float(auc_plus),
                "delta_auc": float(auc_plus - auc_base),
            }
        )

    return pd.DataFrame(linear_rows), pd.DataFrame(logistic_rows)


def main() -> None:
    OUT_ROOT.mkdir(parents=True, exist_ok=True)

    bridge_usable, bridge_summary = prepare_bridge()
    outcome = prepare_outcome()
    structure = structure_tables(outcome)
    auc = auc_tables(outcome)
    frax = frax_tables(outcome)
    linear_models, logistic_models = model_tables(outcome)
    linear_increment, logistic_increment = incremental_tables(outcome)

    bridge_usable.to_csv(OUT_ROOT / "bridge_usable_subset.csv.gz", index=False, compression="gzip")
    structure.to_csv(OUT_ROOT / "dxa_mbr_structure_by_sex_quartile.csv", index=False)
    auc.to_csv(OUT_ROOT / "mbr_vs_osta_auc.csv", index=False)
    frax.to_csv(OUT_ROOT / "frax_by_sex_specific_mbr_quartile.csv", index=False)
    linear_models.to_csv(OUT_ROOT / "linear_models_adjusted_for_age_sex_weight.csv", index=False)
    logistic_models.to_csv(OUT_ROOT / "logistic_models_adjusted_for_age_sex_weight.csv", index=False)
    linear_increment.to_csv(OUT_ROOT / "incremental_value_linear.csv", index=False)
    logistic_increment.to_csv(OUT_ROOT / "incremental_value_logistic.csv", index=False)

    summary = {
        "bridge_summary": bridge_summary,
        "outcome_sample_age_min": float(outcome["age"].min()),
        "outcome_sample_age_max": float(outcome["age"].max()),
        "outcome_rows_age_40_plus": int(len(outcome)),
    }
    (OUT_ROOT / "consistency_summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()

