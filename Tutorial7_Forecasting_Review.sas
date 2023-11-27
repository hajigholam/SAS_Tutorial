/* REVIEW_ESM_ARIMAX_DynmicRegression_VARMAX_GARCH */

libname tutorial "/home/u63451183/Tutorial";
	
* RETAIL Data;
proc print data=sashelp.retail (obs=10);

* 0 Decomposition;
proc timeseries data=sashelp.retail outdecomp=retail_dec plots=(series decomp tc sc sa irregular);
	id date interval=qtr;
	var sales;
run;
* There are both trend and seasonal factors >> Non-Stationary;


/* 1 ESM */

* 1-1 Simple (single or Double): No Trend or Seasonality;
proc esm data=sashelp.RETAIL back=8 lead=8 plot=(corr errors modelforecasts) 
		outstat=work.outstat_single outfor=work.outfor_single;
		id DATE interval=qtr;
		forecast SALES / alpha=0.05 model=simple transform=none;
run;

* 1-2 Holt's (Linear or Damped): Trend;
proc esm data=sashelp.RETAIL back=8 lead=8 plot=(corr errors modelforecasts) 
		outstat=work.outstat_linear outfor=work.outfor_linear;
		id DATE interval=qtr;
		forecast SALES / alpha=0.05 model=linear transform=none;
run;

* 1-3 Seasonal (Additive or Multiplicative): Seasonal;
proc esm data=sashelp.RETAIL back=8 lead=8 plot=(corr errors modelforecasts) 
		outstat=work.outstat_addseasonal outfor=work.outfor_addseasonal;
		id DATE interval=qtr;
		forecast SALES / alpha=0.05 model=addseasonal transform=none;
run;

* 1-4 Winter's (Additive or Multiplicative): Trend & Seasonal;
proc esm data=sashelp.RETAIL back=8 lead=8 plot=(corr errors modelforecasts) 
		outstat=work.outstat_winters outfor=work.outfor_winters;
		id DATE interval=qtr;
		forecast SALES / alpha=0.05 model=winters transform=none;
run;


/* 2 ARIMA */
* Required Stationary, but RETAIL is not;

/* 2-1 ADF (Unit root) Test for Stationarity */
proc arima data=sashelp.retail;
			identify var=sales stationarity=(adf=0);

* Null Hypotheses: Single mean : NOT REJECTED
Zero Mean: non-stationary, no trend, constant mean
Single Mean: non-stationary, trend, no constant mean
Trend: non-stationary, trend, constant mean;

* ADF on FIRST DIFFERENCE;
proc arima data=sashelp.retail;
			identify var=sales(1) stationarity=(adf=0);
* H0 (Zero mean) is REJECTED >> FIRST DIFFERENCE is STATIONARY;

* 2-2 ACF (MA) and PACF (AR): High spikes;
* ARIMA(4,1,0);
proc arima data=sashelp.retail;
			identify var=sales(1);
			estimate p=(1 2 3 4);
			
* ARIMA(0,1,4);
proc arima data=sashelp.retail;
			identify var=sales(1);
			estimate q=(1 2 3 4);	
* Not good!

* 2-3 Automatically Identify ARIMA Order >> Not Suggested;			
proc arima data=sashelp.retail;
			identify var=sales(1) esacf scan minic;
			
* ARIMA(3,1,2) >> Higher AIC, WORSE;
proc arima data=sashelp.retail;
			identify var=sales(1);
			estimate p=3 q=2;			


/* 3 ARIMAX */

* Forecasting Quotes with TvAdverts;
data insurance;
	set tutorial.insurance;

proc sgscatter data=insurance;
   compare y=(quotes tvadverts)
           x=month / join;	

* Fitting a simple Reg;	
proc reg data=insurance;
	model quotes = tvadverts / r;
	output out=work.Reg_stats_r r=r_;	
	
* ACF plot of Residual from Reg.: Residuals are Autocorelated;
proc arima data=work.Reg_stats_r;
	identify var=r_;
* εt is autocorelated >> Not a white noise;

* STATIONARY test for Quotes: ADF;
proc arima data=insurance;
	identify var=quotes stationarity=(adf=0);
* H0 is not rejected >> Quotes is non-stationary

* STATIONARY test for the FIRST DIFFERENCE of y;
proc arima data=insurance;
	identify var=quotes(1) stationarity=(adf=0);
* H0 is rejected >> FIRST DIFFERENCE of y is STATIONARY;

* ARIMAX(0,1,0);
proc arima data=insurance;
	identify var=quotes(1) crosscorr=tvadverts;
	estimate input=(TVadverts);
* Good, almost white-noise residuals and No Remarkable spike, AIC=157;

* ARIMAX (2,1,0);
proc arima data=insurance;
	identify var=quotes(1) crosscorr=tvadverts;
	estimate p=2 input=(TVadverts);
* Better, significant effect, AIC=146;


* ARIMAX (2,1,0) with TRANSFER FUNCTION: Lag Operator;
	* Lag1 and Lag2 are selected based on CCF plot;
proc arima data=insurance plots=all;
	identify var=quotes(1) crosscorr=tvadverts;
	estimate p=2 input=((1 2) TVadverts);
* Better AIC=54;


* Incorporating Lags Manually;
data insurance_lag;
	set insurance;
	TVadverts_lag = lag1(TVadverts);

proc arima data=insurance_lag plots=all;
	identify var=quotes(1) crosscorr=(tvadverts tvadverts_lag);
	estimate p=2 input=(TVadverts TVadverts_lag);


/* 3 VARMAX */

* 3-1 Stationarity test ADF (unit root);
proc varmax data=tutorial.insurance ;
	model quotes tvadverts / dftest print=(roots);
run;
* Zero Mean H0 cannot be rejected >> both TSs are non-stationary >> Differencing;

* 3-2 Fit VARMAX on differenced series (Select autoregressive orders automatically);		
proc varmax data=tutorial.insurance plots(only)=(residual);
	model quotes tvadverts / minic=(p=1) dftest print=(roots) dify=(1);
run;
* ADF test is good >> Stationary
* VMA(3) is good
* Residuals are white nooise

* 3-3 Forecasting with the suggested model;		
proc varmax data=tutorial.insurance ;
	model quotes tvadverts / minic=(p=1) print=(roots) dify=(1);
	   output out=forecasts lead=6 back=6;
run;


/* 4 GARCH */
* 4-1 Return caclulation;
*Calculating the log return for the close price: r(t) = logP(t) - logP(t-1);
data apple;
set tutorial.apple;
return_close = log(close) - log(lag(close));
Run;

			
* 4-1-0 Plots of close price and its return;
proc sgplot data=apple;
   series y=Close x=Date/lineattrs=(color=blue);
run;
proc sgplot data=apple;
   series y=return_Close x=Date/lineattrs=(color=red);
Run;
	* return_close mean is 0 : rt = 0 + εt ;

* 2-2 Test for Heteroscedasticity. H0: Homoscedasticity;
proc autoreg data=apple;
	model close = /archtest;
	run;
	* close is heteroscedastic;

proc autoreg data=apple;
	model return_close = /archtest;
	run;
	* return_close is homoscedastic;
	
* 2-3 Fitting ARCH(1) : GARCH(0,1);
proc autoreg data=apple plots(only)=(acf pacf fitplot residual 
		standardresidual whitenoise residualhistogram);
	model return_Close = / garch=(q=1); 
	output out=output1 cev=variance r=r_garch; *cev: It estimates conditional error variance at each time period;
Run;

* 2-4 Fitting GARCH(1,1);
proc autoreg data=apple plots(only)=(acf pacf fitplot residual 
		standardresidual whitenoise residualhistogram);
	model return_Close = / garch=(q=1,p=1);
	output out=output2 cev=variance r=r_garch;
Run;

* 2-4 Fitting AR(1) ARCH(1);
proc autoreg data=apple plots(only)=(acf pacf fitplot residual 
		standardresidual whitenoise residualhistogram);
	model return_Close = / nlag=1 garch=(q=1,p=1);
	output out=output3 r=r_garch;
Run;
	*AR1 is not significant

* 2-5 Select Autoregressive order automatically for ARCH(1);
proc autoreg data=apple plots(only)=(acf pacf fitplot residual 
		standardresidual whitenoise residualhistogram);
	model return_Close = / nlag=1 backstep garch=(q=1,p=1);
	output out=output4 r=r_garch;
Run;

*** plots of the estimated conditional error variance for model #2;
proc sgplot data=output2;
Series y=variance x=Date/lineattrs=(color=red);
Run;