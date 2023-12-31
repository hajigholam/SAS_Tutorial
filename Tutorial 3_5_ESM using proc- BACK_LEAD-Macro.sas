/* Tutorial 3_5: Exponential Smoothing Methods using PROC, BACK_LEAD, and MACROS */

/* reference: 
https://documentation.sas.com/doc/da/vfcdc/v_017/vfug/n1ub9ghx85o2o6n17zxkq5yo5de6.htm */

/* creating a new folder in your SAS called "tutorial" */

/* creating a library for this session */
libname tutorial "/home/u63451183/Tutorial";


/* 1 Exploring the data */
proc print data=sashelp.retail;
proc sgplot data=sashelp.retail;
series x=date y=sales;	


/* Exploring data in more detail: TS components */
data retail;
	set sashelp.retail;
				
proc timeseries data=retail out=retaileda plots=(series ts sc);
	id date interval=qtr;
	var sales;

/* Fitting ESM seasonal	 */
/* The forecast grasp the seasonal component well.
However, the trend quadratic trend curve seems to get flat in the forecast >> addwinters */
proc esm data=retail plot=(forecasts)
         outfor=outfor
         print=(estimates statistics summary)
         lead=16; 
   id date interval=qtr;
   forecast sales  / model=seasonal;
run;


/* 2 BACK_LEAD */

/* OUTPUT DATA: OUTFOR table: forecasted values  */
/* OUTPUT DATA:: OUTSTAT table: error values  */
ods noproctitle;
ods graphics / imagemap=on;

proc sort data=TUTORIAL.RETAIL out=Work.preProcessedData;
	by DATE;
run;

proc esm data=Work.preProcessedData back=8 lead=8 plot=(corr errors 
		modelforecasts) outstat=work.outstat_simple outfor=work.outfor_simple;
	id DATE interval=qtr;
	forecast SALES / alpha=0.05 model=simple transform=none;
run;

proc delete data=Work.preProcessedData;
run;



/* 2_1 Also, performance metric code from the previous tutorials to calculate the errors */
** filter Outfor dataset to have the predicted values for only the "test" data;
data predicted_test;
set Outfor_simple;
if _N_ > 50 then  output;
Run;

*** Performance metrics;
data errors; 			 *give an arbitrary name to the errors table;
set predicted_test; 	 *an arbitrary name for your predictions data that has been chosen by you when you were making predictions;
error_ =  actual - predict; *calculate the errors;
abs_error = abs(error_);	 *calculate the absolute value of the error;
squared_error = error_**2;	 *calculate the squared value of the error;
percentage_error = 100*error_/actual; *claculate the percentage error;
abs_percentage_error = abs(percentage_error); *claculate absolute percentage error;
run;

*Do a summation for all above errors ;
proc summary data=errors;
var abs_error squared_error abs_percentage_error;
output out=sum_errors sum=/autoname;  *give an arbitrary name to the summary table;
run;

data evaluation; 			*give an arbitrary name for the evaluation results;
set sum_errors; 
N = 8; 											*specify the number of observations in the Test_Data; 						
MAE = abs_error_Sum/N;		*Mean Absolute Error = Mean(Abs_error);
MSE = Squared_error_Sum/N; 	*Mean Squared Error = Mean(Squared_error);
RMSE = Sqrt(MSE);			*Root Mean Squared Error = SQRT(MSE);
MAPE = abs_percentage_error_Sum/N; *Mean Absolute Percentage Error= Mean(percentage error);
run;

proc print data=evaluation;      *print the evaluation results in the output;
Run;


/* 2_2 Repeat the process for all ESM to find the best MODEL */

/* 3 Forecast with the best model for unseen data */




/* 4 OPTIONAL exercise: cusomizing a macro */

/* Reference: SAS Viya for learner/courses/EMTSS/EMTSS01d03 */
data leadmonth;
	set tutorial.leadmonth;

proc timeseries data=leadmonth out=primarymonth plots=(series tc sc);
	id date interval=month;
	var primary / accumulate=total;

/* outfor table contains forecast, actual values, and confidence limits generated by ESM
lead=24 indicates the forecast will be generated 24 months into the future	 */
proc esm data=primarymonth plot=(forecasts)
         outfor=outfor 
         print=(estimates statistics summary)
         lead=24; 
   id Date interval=month;
   forecast primary  / model=seasonal;	
/* The forecast grasp the seasonal component well.
However, the trend quadratic trend curve seems to get flat in the forecast */


/*fit all the ESMs: RUN THE MACRO FIRST */

%AutoESM(leadmonth,ESMstats, primary, Date, month);

proc sort data=ESMstats out=rankedmodels; by RMSE; run;

proc print data=rankedmodels noobs;
   var Model AIC SBC MAPE RMSE;
run;



/*****************************************************************************************/
* Note, the macro code below needs to be run
		before calling the AutoESM macro above;
/*---------------------------------------------*\
 |  Macro: ModelESM                            |
 +---------------------------------------------+
 |  Used by AutoESM to find the best fitting   |
 |  Exponential Smoothing Model.               |
\*---------------------------------------------*/

%macro ModelESM(DSName,DSStat,OutStat,VarName,ModName,DateVar,Interval);
%if %sysfunc(exist(&DSName)) %then %do;
   %let TempData=%RandWorkData();
   proc esm data=&DSName
            out=&TempData 
            outstat=&OutStat
            lead=0;
		id &datevar interval=&interval;
      forecast &VarName / model=&ModName;
   run;
   data &OutStat;
      attrib Model length=$12 label="ESM Model";
      set &OutStat;
      Model="&ModName";
   run;
   proc append base=&DSStat data=&OutStat;
   run;
   
%end;
%else %do;
   %put ERROR: In macro ModelESM, cannot open &DSName;
%end;
%mend ModelESM;

/*---------------------------------------------*\
 |  Macro: AutoESM                            |
 +---------------------------------------------+
 |  Using trial-and-error, find the best       |
 |  fitting Exponential Smoothing Model.       |
 +---------------------------------------------+
 |  DSStat contains the output data set of     |
 |  goodness-of-fit statistics.                |
\*---------------------------------------------*/

%macro AutoESM(DSName,DSStat,VarName,DateVar,Interval);
%if %sysfunc(exist(&DSName)) %then %do;
   %let TempStat=%RandWorkData();
   %let TempOut=&TempStat.o;
   
   proc esm data=&DSName
            out=&TempOut 
            outstat=&TempStat
            lead=0;
		id &datevar interval=&interval;
      forecast &VarName / model=Simple;
   run;
   data &DSStat;
      attrib Model length=$12 label="ESM Model";
      set &TempStat;
      Model="Simple";
   run;
   %ModelESM(&DSName,&DSStat,&TempStat,&VarName,Double,&datevar,&Interval);
   %put ----  Double  -----------------------------------------;
   %ModelESM(&DSName,&DSStat,&TempStat,&VarName,Linear,&datevar,&Interval);
   %put ----  Linear  -----------------------------------------;
   %ModelESM(&DSName,&DSStat,&TempStat,&VarName,DampTrend,&datevar,&Interval);
   %put ----  DampTrend  --------------------------------------;
  %ModelESM(&DSName,&DSStat,&TempStat,&VarName,Seasonal,&datevar,&Interval);
   %put ----  Seasonal  ---------------------------------------;
   %ModelESM(&DSName,&DSStat,&TempStat,&VarName,Winters,&datevar,&Interval);
   %ModelESM(&DSName,&DSStat,&TempStat,&VarName,AddWinters,&datevar,&Interval);
   %end;
  
%else %do;
   %put ERROR: In macro AutoESM, cannot open &DSName;
%end;
%mend AutoESM;

%macro RandWorkData();
   work.r%sysfunc(round(10000000*%sysfunc(ranuni(0))))
%mend RandWorkData;


%modelesm(leadmonth,stat,outstat,primary,double,date,month);


/*****************************************************************************************/
	