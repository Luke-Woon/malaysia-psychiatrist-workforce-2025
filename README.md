# Mapping Malaysia's Psychiatrist Workforce: A Cross-Sectional Study

This repository contains the analysis scripts and projection models for the study evaluating the distribution and workforce trajectories of specialist psychiatrists in Malaysia.

## Repository Structure
- `code/malaysia_psychiatrist_analysis.R`: R script for ARIMA time-series forecasting, in-sample accuracy metrics (RMSE/MAE/MASE), and subnational map rendering.
- `code/malaysia_psychiatrist_analysis.do`: Stata script for data cleaning, non-parametric tests (Mann-Whitney U, Spearman, Kruskal-Wallis/Dunn's), and table exports.
- `data/`: Excel summary data for projection workbook (`Figure5B_projections.xlsx`).

## Software Dependencies
- **R (>= 4.3.0):** `fpp2`, `sf`, `ggplot2`, `dplyr`, `labelled`
- **Stata (>= 18):** `cv2` (`ssc install cv2`), `dunntest` (`ssc install dunntest`)

## Data Sources
Secondary population and economic data are sourced from publicly accessible portals maintained by the Department of Statistics Malaysia (OpenDOSM) and administrative boundaries from UN OCHA FISS. Practitioner registries were derived from public registers of the Malaysian Medical Council (NSR / MeRITS). All direct individual identifiers have been permanently removed.
