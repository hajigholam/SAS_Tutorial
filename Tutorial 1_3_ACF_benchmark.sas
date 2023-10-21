/* creating a new folder in your SAS called "tutorial" */
/* https://drive.google.com/file/d/1xImsApc8DC2N2V7qUWUGxcPG8DzRyGnx/view?usp=drive_link /*
/* insert "arrivals" data into the folder*/

/* creating a library for this session */
libname tutorial "/home/u63451183/Tutorial";

/* reading arrivals.csv file from the folder path  */
proc import datafile="/home/u63451183/Tutorial/arrivals.csv" dbms=csv
			out=tutorial.arrivals replace;
			
/* seeing data  */
proc print data=tutorial.arrivals;			

/* filtering country for NZ  */
data tutorial.arrivals_nz;
set tutorial.arrivals;
where country='NZ';

/* line plot  */
proc sgplot data=tutorial.arrivals_nz;
			series x=Date y=arrival;
			title 'line plot: arrival_nz';


/*  ACF plot_ identification stage_white-noise test  */
proc arima data=tutorial.arrivals_nz;
			identify var=arrival;
			title 'ACF plot: arrival_nz';
			

/*  Benchmark forecasting  */

/*  Holdout partitioning  */
proc print data=sashelp.retail;
			
data tutorial.train_data;
	set sashelp.retail;
	if _n_<=50 then output;

data tutorial.test_data;
	set sashelp.retail;
	if _n_>50 then output;
	
/* Benchmark forecasting: 1 Mean method  */
/* 1_1 calculate the mean of dependant variable in the train*/
proc means data=tutorial.train_data noprint;
		var sales;
		output out=tutorial.mean_table(keep=predicted_sales) mean=predicted_sales;

/* 1_2 calculate the mean of dependant variable in the train*/
data tutorial.train_data_mean;
	set tutorial.train_data;
	if _n_=1 then set tutorial.mean_table;
	risidual_sales=sales-predicted_sales;

/* 1_3 use the train mean as the predicted value in the test data*/	
data tutorial.test_data_mean;
	set tutorial.test_data;
	if _n_=1 then set tutorial.mean_table;
		
/* 1_4 white-noise check for risiduals*/
proc arima data=tutorial.train_data_mean;
			identify var=risidual_sales;
			title 'risidual ACF plot-mean method';
			
/* 1_5 performance metrics*/
data errors;
	set tutorial.test_data_mean;
	error_= Predicted_sales - sales;
	abs_error = abs(error_);
	squared_error = error_**2;
	percentage_error = 100*error_/sales;
	abs_percentage_error = abs(percentage_error);
	
proc summary data=errors;
var abs_error squared_error percentage_error abs_percentage_error;
output out=sum_errors sum=/autoname;

data evaluation_mean;
set sum_errors;
N=8;
MAE = abs_error_sum/N;
MSE = squared_error_sum/N;
RMSE = sqrt(MSE);
MAPE = abs_percentage_error_sum/N;

proc print data=evaluation_mean;

/* Benchmark forecasting: 2 Naive method  */
/* using the last value of the training set as the predicted value in the test set */
/* 2_1 Naive calculation */
data tutorial.train_data_naive;
	set tutorial.train_data;
	predicted_sales = lag(sales);
	risidual_sales = sales - predicted_sales;

data tutorial.last_value;
	set tutorial.train_data_naive;
	if _n_=50 then predicted_sales = sales;
	if _n_=50 then output;

data tutorial.test_data_naive;
	set tutorial.test_data;
	if _n_=1 then set tutorial.last_value(keep=predicted_sales);
	
/* 2_5 performance metrics*/
data errors;
	set tutorial.test_data_naive;
	error_= Predicted_sales - sales;
	abs_error = abs(error_);
	squared_error = error_**2;
	percentage_error = 100*error_/sales;
	abs_percentage_error = abs(percentage_error);
	
proc summary data=errors;
var abs_error squared_error percentage_error abs_percentage_error;
output out=sum_errors sum=/autoname;

data evaluation_naive;
set sum_errors;
N=8;
MAE = abs_error_sum/N;
MSE = squared_error_sum/N;
RMSE = sqrt(MSE);
MAPE = abs_percentage_error_sum/N;

proc print data=evaluation_naive;


/* Benchmark forecasting: 3 Seasonal Naive method  */
/* setting each forecast to be equal to the last observed value from the same season of the year (agg) */
/* 3_1 decomposition for finding the length of seasons*/
proc timeseries data=sashelp.retail 
plots=(series decomp tcc sc sa ic)
OUTDECOMP=DECOMPOSE;
id date interval=qtr;
var sales;
DECOMP tcc sc sa ic / MODE=MULT; 

/* 3_1 Seasonal Naive calculation m=4 */
data tutorial.train_data_snaive;
	set tutorial.train_data;
	predicted_sales = lag4(sales);
	risidual_sales = sales - predicted_sales;

data tutorial.last_m;
	set tutorial.train_data_naive;
	if _n_>= 47 then predicted_sales = sales;
	if _n_>= 47 then output;

/* 3_2 Seasonal Naive calculation */
* sorting last_m based on the seasoanlity variable (here, "MONTH" column);
proc sort data=tutorial.last_m out=tutorial.last_m_sorted;
by month;
run;
* sorting test_data based on the seasoanlity variable (here, "MONTH" column);
proc sort data=tutorial.Test_Data out=tutorial.Test_Data_sorted;
by month;
run;
* merge the Test_Data_sorted with the sorted last_m_sorted;
data tutorial.Test_Data_merged;
merge tutorial.last_m_sorted tutorial.Test_Data_sorted;
by month;
run;
* sort the predictions by the initial date/time index; 
proc sort data=tutorial.Test_Data_merged out=tutorial.Test_Data_snaive;
by date;
run;

	
/* 3_3 performance metrics*/
data errors;
	set tutorial.test_data_snaive;
	error_= Predicted_sales - sales;
	abs_error = abs(error_);
	squared_error = error_**2;
	percentage_error = 100*error_/sales;
	abs_percentage_error = abs(percentage_error);
	
proc summary data=errors;
var abs_error squared_error percentage_error abs_percentage_error;
output out=sum_errors sum=/autoname;

data evaluation_snaive;
set sum_errors;
N=8;
MAE = abs_error_sum/N;
MSE = squared_error_sum/N;
RMSE = sqrt(MSE);
MAPE = abs_percentage_error_sum/N;

proc print data=evaluation_snaive;


/* Benchmark forecasting: 3 Seasonal Naive method  */
/* setting each forecast to be equal to the last observed value from the same season of the year (agg) */
/* 3_1 decomposition for finding the length of seasons*/	