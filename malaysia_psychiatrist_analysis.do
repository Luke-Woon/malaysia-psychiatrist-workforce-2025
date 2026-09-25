********************************************************************************
* Study Title: Mapping Malaysia's Psychiatrist Workforce: A Cross-Sectional Study
* File Name: malaysia_psychiatrist_analysis.do
* Description: Data processing, descriptive statistics, state/district-level
*              economic evaluations, non-parametric testing, and CSV exports for R.
********************************************************************************
capture ssc install cv2
capture ssc install dunntest

clear all
set more off

* Define working directory (Modify path as appropriate)
global data_dir "."

// =============================================================================
// SECTION 1: DATA CLEANING & VARIABLE CODING
// =============================================================================

import excel "$data_dir/Psychiatrists_2025.xlsx", firstrow clear
replace district = proper(district)

* Gender coding (1 = Female, 0 = Male)
encode gender, gen(sex)
drop gender
gen gender = 1 if sex == 1
replace gender = 0 if sex == 2
label variable gender "Gender"
label define Gender 1 "Female" 0 "Male"
label values gender Gender

* Sector classification (Public vs. Private vs. Inactive)
label variable category "Category"
encode category, gen(cat)
recode cat (2=1 "Public") (4=1 "Public") (6=1 "Public") ///
           (3=0 "Private") (5=0 "Private") (1=3 "Inactive"), ///
           gen(sector) label(Sector)
label variable sector "Sector"

* Seniority calculation (Years since qualification)
gen seniority = 2025 - year
label variable seniority "Seniority (Years)"

* State standardization
rename state state_raw
replace state = proper(state_raw)
replace state = "W.P. Kuala Lumpur" if state == "Wilayah Persekutuan Kuala Lumpur"
replace state = "W.P. Putrajaya"    if state == "Wilayah Persekutuan Putrajaya"
replace state = "W.P. Labuan"       if state == "Wilayah Persekutuan Labuan"
encode state, gen(state)
label variable state "State"

* Qualification source grouping
label variable qualification "Qualification"
encode qualification, gen(grad)
recode grad (2=1 "Universities") (5=1 "Universities") (6=1 "Universities") ///
           (7=1 "Universities") (8=1 "Universities") (9=1 "Universities") ///
           (3=2 "MRCPsych") (1=3 "Others") (4=3 "Others"), ///
           gen(source) label(Source)
label variable source "Source"

drop mmc name place last add_1 add_2 district_raw state_raw category qualification
save "$data_dir/district_info.dta", replace

// =============================================================================
// SECTION 2: DESCRIPTIVE STATISTICS & TREND EXPORTS
// =============================================================================

use "$data_dir/district_info.dta", clear

* Fill missing state data for inactive specialists
decode state, gen(state_str)
replace state_str = "Inactive / Not Available" if state_str == "" | cat == 1
encode state_str, gen(state_table)
label variable state_table "State"

* Export updated Table 1
dtable i.gender i.grad i.source i.cat i.sector i.state_table, ///
    sample("Total (N)", statistic(frequency)) ///
    column(summary(n (%))) ///
    export("$data_dir/Table1_Descriptives.xlsx", replace)

* Seniority distribution across sectors
dtable seniority, by(sector) continuous(seniority, statistics(median q1 q3)) ///
    sformat("[%s -" q1) sformat("%s]" q3) nosample nformat(%9.2f) ///
    export("$data_dir/Table_Seniority.xlsx", replace)

* Collapse annual counts for ARIMA modeling in R
use "$data_dir/district_info.dta", clear
collapse (count) nsr, by(year)
tsset year
tsfill
replace nsr = 0 if nsr == .
export delimited "$data_dir/graduates.csv", replace

// =============================================================================
// SECTION 3: STATE-LEVEL DISPERSION & COEFFICIENT OF VARIATION (CV)
// =============================================================================

* Load state population counts
import excel "$data_dir/population_district.xlsx", firstrow clear
keep if sex == "both" & age == "overall" & ethnicity == "overall"
gen year = yofd(date)
keep if year == 2024
keep district state population 
collapse (sum) population, by(state)
save "$data_dir/state_pop.dta", replace

* Merge with active psychiatrist counts
use "$data_dir/district_info.dta", clear
drop if cat == 1  // Exclude inactive
collapse (count) nsr, by(state)
rename state state_coded
decode state_coded, gen(state)
drop state_coded
merge m:1 state using "$data_dir/state_pop.dta"
drop _merge

* Klang Valley region integration
set obs `=_N + 1'
replace state = "Klang Valley" in L
replace population = 7363.3 + 2067.5 + 120.3 in L
replace nsr = 125 + 115 + 9 in L

gen capita = nsr / population * 100
save "$data_dir/state_capita.dta", replace

* Calculate Coefficient of Variation (CV) comparisons (2018 vs. 2025)
use "$data_dir/state_capita.dta", clear
drop if state == "Klang Valley"
encode state, gen(region)
gen cap_old = 1.09 if region == 1 
replace cap_old = 0.55 if region == 2
replace cap_old = 0.92 if region == 3
replace cap_old = 0.97 if region == 4
replace cap_old = 1.32 if region == 5
replace cap_old = 0.72 if region == 6
replace cap_old = 1.59 if region == 7
replace cap_old = 1.18 if region == 8
replace cap_old = 1.24 if region == 9
replace cap_old = 0.54 if region == 10
replace cap_old = 1.11 if region == 11
replace cap_old = 1.20 if region == 12
replace cap_old = 0.90 if region == 13
replace cap_old = 5.24 if region == 14
replace cap_old = 1.01 if region == 15
replace cap_old = 3.38 if region == 16

cv2 capita cap_old

* Export state density data for map rendering in R
use "$data_dir/district_info.dta", clear
drop if cat == 1 
collapse (count) nsr, by(state)
rename state state_coded
decode state_coded, gen(state)
drop state_coded
merge m:1 state using "$data_dir/state_pop.dta"
drop _merge

replace population = 9551.1 if inlist(state, "W.P. Kuala Lumpur", "W.P. Putrajaya", "Selangor")
replace nsr = 249 if inlist(state, "W.P. Kuala Lumpur", "W.P. Putrajaya", "Selangor")
gen capita = nsr / population * 100
keep state capita
rename state adm1_name
export delimited "$data_dir/state_map.csv", replace

// =============================================================================
// SECTION 4: DISTRICT-LEVEL SOCIOECONOMIC ANALYSIS
// =============================================================================

* Load district populations
import excel "$data_dir/population_district.xlsx", firstrow clear
keep if sex == "both" & age == "overall" & ethnicity == "overall"
gen year = yofd(date)
keep if year == 2024
keep district population
save "$data_dir/district_info.dta", replace

* Merge 2022 OpenDOSM economic parameters
import excel "$data_dir/economy_district.xlsx", firstrow clear
gen year = yofd(date)
keep if year == 2022
drop date year
merge 1:1 district using "$data_dir/district_info.dta"
drop _merge state
save "$data_dir/district_info.dta", replace

* Process active district-level psychiatrist counts
use "$data_dir/district_info.dta", clear
collapse (count) nsr (mean) gender sector seniority, by(district state)
merge 1:1 district using "$data_dir/district_info.dta"
drop _merge

replace nsr = 0 if nsr == .
gen capita = nsr / population * 100
gen psy = (nsr > 0)
label define yesno 1 "Yes" 0 "No"
label values psy yesno
save "$data_dir/district_combined.dta", replace

* Non-parametric Mann-Whitney U tests for economic comparisons
use "$data_dir/district_combined.dta", clear
swilk income_mean income_median poverty_absolute poverty_relative gini

ranksum income_mean, by(psy)
ranksum income_median, by(psy)
ranksum poverty_absolute, by(psy)
ranksum poverty_relative, by(psy)
ranksum gini, by(psy)

dtable income_mean income_median poverty_absolute poverty_relative gini, ///
    by(psy, tests) ///
    continuous(income_mean income_median poverty_absolute poverty_relative gini, ///
        statistics(median q1 q3)) ///
    nformat(%9.2f) sformat("[%s -" q1) sformat("%s]" q3) ///
    nosample column(summary(Median(IQR))) ///
    export("$data_dir/Table2_Revised.xlsx", replace)

* Spearman correlation matrix
spearman capita income_mean income_median poverty_absolute poverty_relative gini, stats(rho p)

* Income Quintile analysis & Kruskal-Wallis / Dunn's test
xtile mean_quintile = income_mean, nq(5)
label variable mean_quintile "Mean Income Quintile"

kwallis capita, by(mean_quintile)
dunntest capita, by(mean_quintile)

* Export district density data for map rendering in R
use "$data_dir/district_info.dta", clear
keep district population
* Standardize district names to administrative boundaries
replace district = "Batang Padang" if district == "Muallim"
replace district = "Beluran" if district == "Telupid"
replace district = "Betong" if district == "Pusa"
replace district = "Bintulu" if district == "Sebauh"
replace district = "Daro" if district == "Tanjung Manis"
replace district = "Gua Musang" if district == "Kecil Lojing"
replace district = "Hilir Perak" if district == "Bagan Datuk"
replace district = "Kapit" if district == "Bukit Mabong"
replace district = "Kuala Terengganu" if district == "Kuala Nerus"
replace district = "Larut Dan Matang" if district == "Selama"
replace district = "Marudi" if inlist(district, "Beluru", "Telang Usan")
replace district = "Miri" if district == "Subis"
replace district = "Saratok" if district == "Kabong"
replace district = "Serian" if district == "Tebedu"
replace district = "Tawau" if district == "Kalabakan"
collapse (sum) population, by(district)
save "$data_dir/district_revised.dta", replace

import excel "$data_dir/Psychiatrists_2025.xlsx", firstrow clear
drop if nsr == . | category == "Inactive"
replace district = proper(district)
keep district nsr
replace district = "Batang Padang" if district == "Muallim"
replace district = "Beluran" if district == "Telupid"
replace district = "Betong" if district == "Pusa"
replace district = "Bintulu" if district == "Sebauh"
replace district = "Daro" if district == "Tanjung Manis"
replace district = "Gua Musang" if district == "Kecil Lojing"
replace district = "Hilir Perak" if district == "Bagan Datuk"
replace district = "Kapit" if district == "Bukit Mabong"
replace district = "Kuala Terengganu" if district == "Kuala Nerus"
replace district = "Larut Dan Matang" if district == "Selama"
replace district = "Marudi" if inlist(district, "Beluru", "Telang Usan")
replace district = "Miri" if district == "Subis"
replace district = "Saratok" if district == "Kabong"
replace district = "Serian" if district == "Tebedu"
replace district = "Tawau" if district == "Kalabakan"
collapse (count) nsr, by(district)
merge m:1 district using "$data_dir/district_revised.dta"
drop _merge
replace nsr = 0 if nsr == .
gen capita = nsr / population * 100

* Map boundary naming alignment
replace district = "Kulaijaya" if district == "Kulai"
replace district = "Ledang" if district == "Tangkak"
replace district = "Manjung (Dinding)" if district == "Manjung"
replace district = "Meradong" if district == "Maradong"
replace district = "S.P. Tengah" if district == "Seberang Perai Tengah"
replace district = "S.P. Utara" if district == "Seberang Perai Utara"
replace district = "S.P.Selatan" if district == "Seberang Perai Selatan"
replace district = "Ulu Perak" if district == "Hulu Perak"
replace district = "WP. Kuala Lumpur" if district == "W.P. Kuala Lumpur"
rename district adm2_name
keep adm2_name capita
export delimited "$data_dir/district_map.csv", replace