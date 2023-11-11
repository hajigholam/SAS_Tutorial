/* Tutorial 5_7: ARIMAX_DynamicRegression_TransferFunction_CCF */

libname tutorial "/home/u63451183/Tutorial";


/* Intro:

-- Regression: Y(t)=B0 + B1*X1(t) + B2*X2(t) + ... + Bk*Xk(t) + Et (contemporaneous relationship)

-- ARIMA (p,d,q): Y(t) = c + ϕ1.Y(t-1) + … + ϕp.Y(t-p) + θ1.E(t-1) + … + θq.E(t-q) + Et (univariate)

-- Dynamic Regression: having X as timeseries
-- ARIMAX: Having a exogenous variables (X) into the ARIMA framework (dynamic regression with lagged variable)
-- Regression with ARIMA errors: Imagine the error term in regression become a time series itself.

-- Use Case: Predicting a time series with other time series. Incorporating event variable.

-- Transfer Function : Extimation of how X affects Y? The relationship between X and Y is not contemporaneous anymore. 
					   ξ(L)Y(t) = γ + ω(L)X(t) + E(t) => Y(t) ~  [ω(L)/ξ(L)]X(t)
					   A ratio of polynomial in the backshift (lag) operatorφ

In ARIMAX/dynamic regression, if X shocks at time t, Y might be impacted at a subset of time t+n					

*/


/* Case Study: How world oil production affects US oil production */

/* 1 Exploring data */
data worldoil;
	set tutorial.worldoil;

proc sgscatter data=WorldOil;
   compare y=(USA Canada Mexico Venezuela Iraq OPEC OAPEC PersianGulf)
           x=Date / join;          
/* -- Identified issues: 
				        - Multi-Colinearity of OPEC OAPEC PersianGulf is evident in the plots 
				        - Two event point in the Dependent variable USA*/


/* -- Addressing Multi-Colinearity issue: Variance Inflation Factor > 10 */
proc reg data=WorldOil
         outest=EstFullModel;
   model USA=Canada Iraq Mexico OAPEC
             OPEC PersianGulf Venezuela / 
             vif;             
/* -- Other issues identified:
				   - Insignifant P-values
				   - High variance in residual plot. we'll get to them later!              */

/* -- Variable Selection: Pick one one variable at a time and fit models */
proc reg data=WorldOil
         outest=Est5VModel;
  OAPEC: model USA=Canada Iraq Mexico
                   OAPEC Venezuela /aic sbc edf ; 
                   
  PGulf: model USA=Canada Iraq Mexico
                   PersianGulf Venezuela /aic sbc edf ; 
                   
  OPEC:  model USA=Canada Iraq Mexico
                   OPEC Venezuela /aic sbc edf ; 

/* -- comparing the models : OPEC is selected among the correlated variables */
title  "Comparing Fits";
proc print data=Est5VModel noobs;
   var _MODEL_ _RMSE_ _RSQ_ _AIC_ _SBC_;
   format _RMSE_ 6.1 _RSQ_ 6.3 _AIC_ _SBC_ 7.1;


/*  2 ARIMAX: switching to arima from reg to assess the residual better */
proc arima data=WorldOil;
   identify var=USA crosscorr=(Canada Iraq Mexico OPEC Venezuela) noprint; 
   estimate input=(Canada Iraq Mexico OPEC Venezuela);
             
/* 2-1 ARIMAX(1,0,0) according to PACF plot */
proc arima data=WorldOil;
   identify var=USA crosscorr=(Canada Iraq Mexico OPEC Venezuela) noprint; 
   estimate p=1 input=(Canada Iraq Mexico OPEC Venezuela);    

/* 2-2 Removing Mexico Canada, and Venexuela due to insignificant P-value 
	   (better not to remove all at once!) */
proc arima data=WorldOil;
   identify var=USA crosscorr=(Iraq OPEC) noprint; 
   estimate p=1 input=(Iraq  OPEC);
   forecast id=date interval=month out=resids;    

/* -- Ouliers in residual polt has not been accomodated >> Event points! */
proc sgplot data=resids;
	series x=date y=residual;

/* -- finding the exact event variables: What happened in Sep.2005 & Sep.2008! */
proc print data=resids; 
   where residual<-500; 
   var residual Date; 


/* 3 Adding Event Variables */
data tutorial.WorldOil_event;
   set WorldOil;
   attrib Katrina length=3 label="Hurricane Katrina"
          Ike     length=3 label="Hurricane Ike";
   Katrina=("01AUG2005"d<=Date<="31AUG2005"d);
   Ike=("01SEP2008"d<=Date<="30SEP2008"d);

/* 3-1 Fitting the model with event variables */
proc arima data=WorldOil_event plots(unpack);
   identify var=USA 
            cross=(OPEC Iraq Katrina Ike);
	estimate p=1 input=(OPEC Iraq Katrina Ike);	
/* -- Another issue Identified: Katrina coefficient is positive! 
								>> check USA and Katrina CCF plot
								>> check USA and Ike CCf plot*/
								
/* 3-2 CCF Plot Interpretation for identifying the Transfer Function */


/* 4 Dynamic Regression and Transfer Function for lags */
proc arima data=WorldOil_event;
   	identify var=USA 
            cross=(OPEC Iraq Katrina Ike) noprint;
	estimate p=1 input=(Iraq OPEC 1$(2)/(1)Katrina Ike); 
	
	/* Transfer Function:
	.$ shift order
	Dnominator: smooth decay
	Dnominator order 1: smooth decay starts at first lag after shift
	Numerator order 2: Smooth decay interrupted at second lag after shift
	*/

/* 4-1 Fitting the line with the final model: */
proc arima data=WorldOil_event plots=all;
   	identify var=USA 
            cross=(OPEC Iraq Katrina Ike) noprint;
	estimate p=1 input=(Iraq OPEC 1$(2)/(1)Katrina Ike);
	forecast interval=month id=date out=resids2;
	
/* 4-2: Accomodating Ike dynamic for a better fit*/	
proc arima data=WorldOil_event plots=all;
   	identify var=USA 
            cross=(OPEC Iraq Katrina Ike) noprint;
	estimate p=1 input=(Iraq OPEC 1$(2)/(1)Katrina (1)Ike);
	forecast interval=month id=date out=resids2;
	
	
/* Reference: 
https://learn.sas.com/course/Models for Time Series and Sequential Data */