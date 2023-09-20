* ECO 6193/6593
* Fall 2023
* Assignment 1 / Devoir 1

* The cyclicality of aggregate labour-market variables in Canada, 1976-2021 /
* Les propriétés cyclicles des variables aggrégées du marché du travail canadien, 1976-2021


******
******


* 0. Some preliminary commands

clear 
set more off
capture log close


******
******


* 1. Open log file

log using Logfile, text replace


******
******


* 2. Import data and convert in dta files

* 2.1. Population, Employment Unemployment

* Cansim table 14100287: Labour Force Survey (LFS) data (.txt format)
import delimited CANSIM_14100287.txt, varnames(24) rowrange(25) clear 

* keep variables of interest (date + economic series of interest)
keep col0 col1 col2 col3 col6

* Label and rename variables
label var col0 "Monthly date (YYYY-MM)"
rename col0 date

label var col1 "Population (Persons); Both sexes; 15 years and over; Estimate; Seasonally adjusted"
rename col1 population 

label var col2 "Labour force (Persons); Both sexes; 15 years and over; Estimate; Seasonally adjusted"
rename col2 labour_force

label var col3 "Employment (Persons); Both sexes; 15 years and over; Estimate; Seasonally adjusted"
rename col3 employment

label var col6 "Unemployment (Persons); Both sexes; 15 years and over; Estimate; Seasonally adjusted"
rename col6 unemployment

* save a temporary dataset for merging data
save dataset_lfs, replace

**
**

* 2.2. Actual hours worked from CANSIM table 14100032
import delimited CANSIM_14100289.txt, varnames(6) rowrange(7) clear 


* Repeat commands from above
label var col0 "Monthly date (YYYY-MM)"
rename col0 date

label var col1 "Total actual hours worked, all industries; Estimate (Hours)"
rename col1 tot_hours

save dataset_hours, replace 

**
**

* 2.3. Gross domestic product from FRED, series NAEXKP01CAQ189S
import delimited NAEXKP01CAQ189S.csv, varnames(1) rowrange(2) clear 

label var date "Date (YYYY-MM-DD)"

label var naexkp01caq189s  "Gross Domestic Product by Expenditure in Constant Prices (source: OECD)"
rename naexkp01caq189s real_GDP

save dataset_GDP, replace


* 2.4. Total population
import delimited POPTOTCAA647NWDB.csv, varnames(1) rowrange(2) clear 

label var date "Date (YYYY-MM-DD)"

label var poptotcaa647nwdb  "Population (source: World Bank)"
rename poptotcaa647nwdb tot_population

* merge with GDP
merge 1:1 date using dataset_GDP
drop _merge

save dataset_GDP, replace


******
******


* 3. Merge data in one quarterly dataset

* Note: monthly and quarterly data require different treatment. 
* Start with monthly, then quarterly data

**
**

* 3.1 Convert date from monthly to quarterly

* Merge lfs data and hours
use dataset_lfs, clear
merge 1:1 date using dataset_hours
drop _merge

* Generate indicators
gen u_rate 	= unem / labour_force
gen u_pop 	= unem / population
gen emp_pop = emp / population
gen lf_pop 	= labour_force / population 

* Average hours in pop and per employed person
gen hours 		= tot_hours / population
gen hours_emp 	= tot_hours / employment


* Convert to quarterly data

* extract year and month
gen year = substr(date,1,4)
destring year, replace
gen month = substr(date,6,7)
destring month, replace

* gen quarter
gen quarter = ceil( month/3 )

* quarterly date
gen qdate = yq(year, quarter)
format qdate %tq


* alternativelly, use the function date( ) to convert the string date in a daily date format
* and then extract the quarter and year using quarter( ) and year( )

/*

rename date date_str 
gen date = date(date_str, "YM")
format date %td
gen year = year(date)
gen quarter = quarter(date)
gen qdate = yq(year, quarter)
format qdate %tq

*/

* collapse to compute quarterly averages
collapse tot_hours hours hours_emp emp_pop u_rate u_pop lf_pop population, by(qdate) 
rename qdate date
order date 

save dataset_lfs_hours_quarter, replace

**
**

* 3.2. Merge with quarterly GDP data

* data
use dataset_GDP, clear

* extract quarter and year
gen year = substr(date, 1,4)
destring year, replace
gen month = substr(date, 6,2)
destring month, replace
gen quarter = ceil( month/3)

* quaterly date
gen qdate = yq(year, quarter)
format qdate %tq

* cleanup a little bit
keep qdate tot_population real_GDP 
rename qdate date
order date 
sort date

* interpolate population from yearly to quarterly to compute GDP per capita
ipolate tot date, gen(tot_population_int)

* merge with labour-market variables
merge 1:1 date using dataset_lfs_hours_quarter
drop _merge

* Average productivity of labour
gen prod_labour = real_GDP / tot_hours

* compute GDP per capita
replace real = real/tot_population_int

* final cleanup
keep if tot_hours !=.
keep if real_GDP !=.
drop tot*
drop pop*


**
**

* 3.3. Final working variables

* Declare time series
tsset date, quarterly

* labels
label var u_rate    	"Unemployment rate"
label var u_pop 		"Unemployment-to-population ratio"
label var emp_pop   	"Employment-to-population ratio"
label var lf_pop    	"Labour force participation rate"
label var hours_emp 	"Average hours per employed persons"
label var hours	    	"Actual hours per capita"
label var real_GDP		"Real GDP per capita"
label var prod_labour   "Real output per worked hours"

* save dataset
save dataset, replace

* cleanup by erasing intermediate dataset
erase dataset_lfs.dta 
erase dataset_hours.dta
erase dataset_GDP.dta
erase dataset_lfs_hours_quarter.dta


******
******


* 4. Data preparation

foreach var of varlist real_GDP prod_labour hours hours_emp u_rate u_pop emp_pop lf_pop {


* 4.1. Trend and cycle

* Hodrick-Prescott filter with smoothing parameter 1600
tsfilter hp `var'_cycle = `var', smooth( 1600 ) trend( `var'_trend )

**
**

* 4.2. Log difference from trend
gen `var'_hat = log( `var' ) - log( `var'_trend )

}


******
******


* 5. Statistics

* exclude COVID times
gen date_num = date
gen COVID_times = (date_num > quarterly("2019q4","YQ"))

* Descriptive statistics
sum real_GDP_hat hours_hat hours_emp_hat emp*hat u_rate*hat u_pop*hat lf_*hat prod*hat if COVID_times == 0

* Correlations
corr real_GDP_hat hours_hat hours_emp_hat emp*hat u_rate*hat u_pop*hat lf_*hat prod*hat if COVID_times == 0


******
******

* 6. Graphs

* Period sample of interest
gen sp = hours_hat !=. & COVID_times == 0


* Main variable vs. GDP

tsline real_GDP_hat hours_hat if sp == 1

tsline real_GDP_hat hours_emp_hat if sp == 1

tsline real_GDP_hat emp*hat if sp == 1

tsline real_GDP_hat lf_pop*hat if sp == 1

tsline real_GDP_hat prod*hat if sp == 1


**
**

* Hours and its components

* hours per capita vs employment-pop and average hours
tsline hours_hat emp*hat if sp == 1

tsline hours_hat u_rate_hat if sp == 1

tsline hours_hat hours_emp_hat if sp == 1

tsline hours_hat emp*hat hours_emp_hat if sp == 1

* emmployment per capita vs (opposite of) unemployment rate
gen u_tilde = - ( u_rate - u_rate_trend ) 
tsline emp_pop_hat u_tilde if sp == 1

* hours per capital vs. unemployment and lfp rate
tsline hours_hat lf_pop*hat u_tilde if sp == 1


******
******

log close


/*
* Decomposition h = e.h
reg hours_hat hours_emp_hat emp_pop_hat
gen u_tilde = - ( u_rate - u_rate_trend ) 
reg hours_hat u_tilde hours_emp_hat lf_*hat 
 
