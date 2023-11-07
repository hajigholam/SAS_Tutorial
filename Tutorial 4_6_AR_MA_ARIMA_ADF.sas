/* Tutorial 4_6: ARMA & ARIMA & ADF test*/

/* creating a new folder in your SAS called "tutorial" */

/* creating a library for this session */
libname tutorial "/home/u63451183/Tutorial";


/* 0 Stationary TimeSeries: No Trend, No Seasonality, No Cyclical variation 
>> Constant Mean and Variance (not function of t) >> Overall avg ~ subset avg */

/* Q: Stationary (Irregular) Variation vs WhiteNoise?   */
/* Epsilon is WhiteNoise: stationary, independently and identically normally distributed (iid) with mean zero, no memory
Irregular variation: stationary, not independently distributed, there are other components + WhiteNoise */

/* Q: Guess the convergence point of forecasting in a stationary time series? */

/* Point: different shock effect >> different length of memory: How long it takes to converge back
>> Model Specification */


/* 1 AR: variables are a function of their own lags
>>AR(p) : yt = C + ϕ1.yt-1 + … +  ϕp.yt-p + εt */

/* 1-1 How to find p (correlated lags)? ACF, Proximity effect: spurious significant spikes
>> PACF spikes >> AR model order*/
 

/* 2 MA: variables are a function of realizations of a white noise error sequence
>> MA(q) : yt = C + θ1.εt-1 + … + θq.εt-q + εt
>> The order of MA: the memory or persistence in the process. MA 1, shocks persist for one interval */

/* 2-1 How to find q (correlated lags)? ACF:  AR model order >> ACF significant spikes*/


proc arima data=tutorial.armaExamples; 
  *identify var=y1  nlag=12;
  	*estimate p=1;
 * identify var=y2  nlag=12;
  *estimate p=2;
 *identify var=y3  nlag=12;
  *identify var=y4  nlag=12;
  *estimate q=1;
  *identify var=y5  nlag=12;
  *	estimate q=2;
  *identify var=y6  nlag=12; 
  identify var=y7  nlag=12; /*   ? */
  identify var=y8  nlag=12; /*   White Noise */


/* 3 ARMA: combination of AR(p) and MA(q) models
>> yt = c + ϕ1.yt-1 + … + ϕp.yt-p + θ1.εt-1 + … + θq.εt-q+ εt*/

/* 3-1 Automatically Identify ARMA Order  */
proc arima data=tutorial.armaexamples; 
   identify var=Y7 nlag=12 esacf scan minic;
   
/* 3-2 Perform ARMA(1,1) model  */
proc arima data=tutorial.armaexamples; 
   identify var=Y7 nlag=12;
   estimate p=1 q=1;    


/* 4 ARIMA with Trend: Non-Stationary + Trend (Deterministic>>Time function vs Stochastic>>Differencing)  */

/* 4-1 Differencing and Integration */
/* First Difference: Yt - Y(t-1) = εt >> De-trend/de-Slope >> Stationary */


/* * 4-2 Determinsitic: Function of time */

proc timeseries data=tutorial.leadyear out=leadyr plots=(series corr);
	id date interval=year;
	var primary / accumulate=total;

/* Adding a new variable (Time) to accomodate the trend.
/* Extend the Time index and Date for future forecasts. */
data leadyr; 
   set leadyr end=eof; 
   Time+1; 
   output; 
   if (eof) then do future=1 to 20; 
      Primary=.; 
      Secondary=.; 
      Total=.; 
      Time+1; 
      Date=intnx("year",Date,1); 
      output; 
   end; 
   drop future;


proc arima data=LeadYr plots=all; 
   identify var=Primary nlag=12 crosscorr=(Time); 
   *estimate input=(Time) plot;  

   estimate input=(Time) p=1;      

   *estimate isnput=(Time) p=(2) ml; /* lag 2 only        */

   forecast lead=20 id=date interval=year;


* 4-3 Stochastic: differencing;

/* Applying first difference >> No trend >> Spikes >> it's not a white noise */
proc arima data=LeadYr plots=all; 
   identify var=Primary(1) nlag=12;

/* Spikes in lag1 of both ACF and PACF, but ACF is disappearing more rapidly >> MA */
proc arima data=LeadYr plots=all; 
   identify var=Primary(1) nlag=12 noprint;
	estimate q=1; run;
	forecast lead=20 id=date interval=year; 
run;


/* Both deterministic and Stochastic Approaches and the resulting models are defensible */


/* 5 Augmented Dickey Fuller Unit Root (ADF) test for Trend: Yt = 𝜙Y(t-1)+ μ[1-𝜙] + β[t-𝜙[1-t]] + εt

	Null: 𝜙 = 1  >> Non-Stationary Stochastic variation around unknown mean (Random-walk)
	Alternative: Zero mean β=0, (μ=0) |𝜙|<1 : Stationary variation around zero mean, 
				 Single mean β=0 𝜙|<1 :Stationary variation around non-zero mean, 
			 	 Trend: 
			 	 Trend-Stationary (Trend function solely on time)*/

proc arima data=LeadYr plots=all; 
   identify var=Primary nlag=12 stationarity=(adf=(0 1 2));



/* 6 ARIMA with Seasonality: Non-Stationary + Seasonality (Deterministic>>Dummy vs Stochastic>>Differencing)  */

	/* 6-1 Differencing and Integration */
	/* First Difference: Yt - Y(t-s) = εt >> de-Seasoning >> Stationary */


data Air1990_2000;
   set tutorial.usairlines
       (where=(Date<='31DEC2000'd));

/*----  Basic Diagnostics  ----*/
proc timeseries data=Air1990_2000
                out=temp
                outdecomp=decomp 
                plot=(series corr wn decomp tc sc )
                seasonality=12;
   id Date interval=month;
   var Passengers;
   decomp tcc sc / mode=mult;
run;

/*-------------------------------------------*/
/*----  6-1 Linear Trend + Seasonal Dummies  ----*/
/*-------------------------------------------*/

/* 6-1-1 add deterministic trend and seasonal dummy variables; */

data Air1990_2000;
   set Air1990_2000 end=lastobs;
   array Seas{*} MON1-MON11;
   retain Time 0 MON1-MON11 .;
   if (MON1=.) then do index=1 to 11;
      Seas[index]=0;
   end;
   Time+1;
   if (month(Date)<12) then do;
      Seas[month(Date)]=1;
      output;
      Seas[month(Date)]=0;
   end;
   else output;
   if (lastobs) then do;
      Passengers=.;
      do index=1 to 24;
         Time+1;
         Date=intnx("month",Date,1);
         if (month(Date)<12) then do;
            Seas[month(Date)]=1;
            output;
            Seas[month(Date)]=0;
         end;
         else output; 
      end;
   end;
   drop index; 
run;

/* 6-1-2 Run a regression with new variables  */
proc arima data=Air1990_2000 plots=all;
   identify var=Passengers
            cross=(Time
                   MON1 MON2 MON3 MON4 MON5 MON6
                   MON7 MON8 MON9 MON10 MON11) noprint;
   estimate input=(Time
                   MON1 MON2 MON3 MON4 MON5 MON6
                   MON7 MON8 MON9 MON10 MON11)
            method=ml;
run;


/* 6-1-3 Risidual are not white noise >> AR1 from PACF  */
proc arima data=Air1990_2000 plots=all;
   identify var=Passengers
            cross=(Time
                   MON1 MON2 MON3 MON4 MON5 MON6
                   MON7 MON8 MON9 MON10 MON11) noprint;
   estimate input=(Time
                   MON1 MON2 MON3 MON4 MON5 MON6
                   MON7 MON8 MON9 MON10 MON11)
            p=1
            method=ml
            outstat=work.stattsd; run;
            
/* 6-1-4 Do the forecasting             */
	forecast id=Date interval=month lead=24
            out=work.foretsd;


/*-------------------------------------------*/
/*----  6-2  Differencing lags ----*/
/*-------------------------------------------*/

proc arima data=Air1990_2000 plots=all;
   identify var =Passengers(1 12);
   estimate p=1 q=(1)(12) 
            method=ml
            outstat=statclassicp1; 
   forecast id=Date interval=month lead=24
            out=tutorial.fclassicp1;


* Which approach is best ?;

data Dif;
	set statclassicp1;
	if _stat_ in ('AIC' 'SBC' 'SSE') then do;
	output;
	end;
	rename _stat_ = dif_stat;
	label _stat_ = dif_stat;
	rename _value_ = dif_value;
	drop _type_;


data Det;
	set stattsd;
	if _stat_ in ('AIC' 'SBC' 'SSE') then do;
	output;
	end;
	rename _stat_ = det_stat;
	label _stat_ = det_stat;
	rename _value_=det_value;
	drop _type_;



data compare;
	merge dif det;


proc print data=compare; run;



proc arima data=Air1990_2000;
	identify var=passengers stationarity=(adf=(0 1 2 3));



proc arima data=Air1990_2000;
	identify var=passengers(1) stationarity=(adf=(0 1 2 3) dlag=12);


/* Reference: 
https://learn.sas.com/course/Models for Time Series and Sequential Data */