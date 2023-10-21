/* creating a new folder in your SAS called "tutorial" */
/* https://drive.google.com/file/d/1xImsApc8DC2N2V7qUWUGxcPG8DzRyGnx/view?usp=drive_link /*


/* creating a library for this session */
libname tutorial "/home/u63451183/Tutorial";

/* 1 Linear Regression: Y(t)=B0 + B1*X1(t) + B2*X2(t) + ... + Bk*Xk(t) + E */
proc print data=sashelp.retail;

/* Add seasonn dummy */
data tutorial.retail;
set sashelp.retail;
trend = _N_;
if month=1 then Q1=1;
else Q1=0;
if month=4 then Q2=1;
else Q2=0;
if month=7 then Q3=1;
else Q3=0;

/* Train test split */
data tutorial.train_data;
set tutorial.retail;
if _n_ <= 50 then output;

data tutorial.test_data;
set tutorial.retail;
if _n_ > 50 then output;

/* Fitting regression: Tasks and Utilities */

ods noproctitle;
ods graphics / imagemap=on;

proc reg data=TUTORIAL.TRAIN_DATA alpha=0.05 plots(only)=(diagnostics(unpack) 
		residuals(unpack) observedbypredicted);
	model SALES=trend Q1 Q2 Q3 / r;
	output out=work.Reg_stats_model1 p=p_ lcl=lcl_ ucl=ucl_ r=r_ lclm=lclm_ uclm=uclm_;


/* 2 Residual Diagnostics: Normally distributed, zero mean, constant variance, uncorrelated */

/* Risiduals mean */
proc means data=reg_stats_model1 maxdec=3;
var r_;

/* Risiduals ACF:>> No autocorrelation hypothesis is rejected >> Residuals are correlated*/
proc arima data=reg_stats_model1;
identify var=r_;
title 'ACF plot Residual';


/* 3 Prediction Interval and Confidence Interval: 
CLM option adds confidence limits for the mean predicted values. CLI option adds confidence limits for the individual predicted values. */
proc sgplot data=sashelp.class;
  reg x=height y=weight / CLM CLI;
run;

proc sgplot data=work.Reg_stats_model1;
series x=date y=lcl_;
series x=date y=ucl_;
series x=date y=sales;
series x=date y=p_;
title 'Prediction Intervals'


/* 4 Fitting on test set */

ods noproctitle;
ods graphics / imagemap=on;

proc reg data=TUTORIAL.TEST_DATA alpha=0.05 plots(only)=(diagnostics(unpack) residuals(unpack) observedbypredicted);
  model SALES = trend Q1 Q2 Q3 / r;
  output out=work.Reg_stats_model1_test p=p_ lcl=lcl_ ucl=ucl_ r=r_ lclm=lclm_ uclm=uclm_;
run;

/* 5 Performance metrics */
data errors_reg1; 			    
set reg_stats_model1_test;     
error_ =  sales - p_;  	    
abs_error = abs(error_);	    
squared_error = error_**2;	    
percentage_error = 100*error_/sales;     	
abs_percentage_error = abs(percentage_error);  

proc summary data=errors_reg1;
var abs_error squared_error abs_percentage_error;
output out=sum_errors sum=/autoname;

data evaluation; 			
set sum_errors; 
N = 8; 											 						
MAE = abs_error_Sum/N;		*Mean Absolute Error = Mean(Abs_error);
MSE = Squared_error_Sum/N; 	*Mean Squared Error = Mean(Squared_error);
RMSE = Sqrt(MSE);			*Root Mean Squared Error = SQRT(MSE);
MAPE = abs_percentage_error_Sum/N; *Mean Absolute Percentage Error= Mean(percentage error);

proc print data=evaluation;

/* 6 Ex-post forecast: add missing values after the test set */


