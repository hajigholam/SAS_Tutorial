/* Tutorial 6_8: VARMAX_GARCH */

libname tutorial "/home/u63451183/Tutorial";


/*-------------------------------------------*/
/*----            1 VARMAX               ----*/
/*-------------------------------------------*/

/* Intro: So far, all Univariate Reg./TS

-- Regression: y(t)=b0 + b1*x1(t) + b2*x2(t) + ... + bk*xk(t) + εt (contemporaneous relationship)
-- Dynamic Regression: having x as timeseries
-- ARIMA (p,d,q): y(t) = c + α1.y(t-1) + … + αp.y(t-p) + β1.ε(t-1) + … + βq.ε(t-q) + εt (univariate)
-- ARIMAX: Having a exogenous variables (x) into the ARIMA framework (dynamic regression with lagged variable)

- This session: Multivariate Reg./TS: Modelling multiple target variable at the same time (Do not confuse with multiple reg.!)

-- Vector Autoregressive (VAR): Extension of AR model into multivariate
-- VAR(1) bivariate : [y1(t)] = [c1] + [α11.y1(t-1)] + [α12.y2(t-1)] + ε1t
					  [y2(t)] = [c2] + [α21.y1(t-1)] + [α22.y2(t-1)] + ε2t

- Extensions:
--VARMA(1,1): Yt = C + A1.Y(t-1) + Et + B1.E(t-1)  Y=(y1,y2,...,yk) >> Upper cases denote vectors and matrice
--VARMA(p,q): Yt = C + Σ(i=1,p)Ai.Y(t-i) + Et + Σ(j=1,q)Bj.E(t-j)
--VARMAX

- VAR has more parameters to estimate than VARMA but is less computaionally intensive, so, more common */



* 1-0 Reading insurance.csv file from the folder path;
proc import datafile="/home/u63451183/Tutorial/insurance.csv" dbms=csv
			out=tutorial.insurance;
			
* 1-0 Plots of the two series;
proc sgplot data=tutorial.insurance;
 series x=Time y=quotes / legendlabel="quotes";
 series x=Time y=TVadverts / legendlabel="TVadverts";
 yaxis label="Time Series"; xaxis label="Time";


/*-------------------------------------------*/
/*----            1 VARMAX               ----*/
/*-------------------------------------------*/

* 1-1 Stationarity test ADF (unit root);
proc varmax data=tutorial.insurance ;
	id Time interval=month;
	model quotes tvadverts / dftest print=(roots);
run;
* Zero Mean H0 cannot be rejected >> both TS are non-stationary >> Differencing;

* 1-2 Fit VARMAX on differenced series (Select autoregressive orders automatically);		
proc varmax data=tutorial.insurance plots(only)=(residual);
	id Time interval=month;
	model quotes tvadverts / minic=(p=1) dftest print=(roots) dify=(1);
run;
* ADF test is good >> Stationary
* VMA(3) is good
* Residuals are white nooise

* 1-3 Forecasting with the suggested model;		
proc varmax data=tutorial.insurance ;
	id Time interval=month;
	model quotes tvadverts / minic=(p=1) print=(roots) dify=(1);
	   output out=forecasts lead=12;
run;

* 1-4 Forecasting with aribitrary model: VAR(1);		
proc varmax data=tutorial.insurance plots(only)=(residual);
	id Time interval=month;
	model quotes tvadverts / p=1 print=(roots) dify=(1);
	   output out=forecasts lead=12;
run;	 
* Not good!


/*-------------------------------------------*/
/*----            2 GARCH               ----*/
/*-------------------------------------------*/  

/* Intro: So far, focusing on the mean of a series and the modeling actual values of a target variable

-- Modeling Volatility (changes/variance/ etc.) of target variable

-- Unconditional variance: Var(x) = σ^2 Or E(x-E(x))^2 >> Constant
-- Conditional variance: Change based on piece of information or data

-- Error variance: One of the regression assumptions:
	- Homoscedasticity: The errors have the same variance throughout the sample >> Constant error variance
	- Heteroscedasticity: The error variance is not constant

-- Avoid or Model Heteroscedasticity:
	- Modeling changes is sometimes easier than modeling the actual value >> pattern in high and low volatility over time

-- ARCH(q) : Autoregressive Conditional Heteroscedasticity (nonconstant volatility related to prior periods)
		 [σ(t+1)]^2 = c + α1[r(t)]^2 + α1[r(t-1)]^2 + ... + αq[r(t-q)]^2 + εt
		 * σ ~ r ~ change ~ actual volatility of today
		 
-- G*ARCH(p*,q) : [σ(t+1)]^2 = c + α1[r(t)]^2 +  β1[σ^(t)]^2 + εt
									 Actual   +  Forecasted
 -Typically q=p=1 is enough.
 
-- AR() GARCH: εt error follows an Autoregressive process


* 2-0 Reading "Apple Stock Daily prices.csv" file from the folder path;
proc import datafile="/home/u63451183/Tutorial/Apple Stock Daily prices.csv" dbms=csv
			out=tutorial.apple;
			
* 2-1 Return caclulation;
*Calculating the log return for the close price: r(t) = logP(t) - logP(t-1);
data apple;
set tutorial.apple;
return_close = log(close) - log(lag(close));
Run;

			
* 2-1-0 Plots of close price and its return;
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
	output out=output1 cev=variance r=r_garch; *cev: estimated conditional error variance at each time period;
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

/* The GARCH model assumes conditional heteroscedasticity, with homoscedastic unconditional error variance.  
That is, the GARCH model assumes that the changes in variance are a function of the realizations of preceding errors  
 								and that these changes represent temporary and random departures from a constant unconditional variance. 
The form of heteroscedasticity in this data does not fully fit the GARCH model */
