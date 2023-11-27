/* SAS Base */

* DO NOT FORGET SEMICOLON at the END of EACH StATEMENT;

*-------------------------------------------*/
/*----       0-1 Global Stetements         ----*/
/*-------------------------------------------*/

* Library helps to avoid hardcode the path everytime reading atable.
Connecting to a data source;

libname tutorial "/home/u63451183/Tutorial";

title "title-text";
proc print data = sashelp.class;
footnote "footnote-text";
title; footnote; *clear what have been specified;
ods noproctitle; * clear proc titles;

* Difference between "work" and a costum library?
Data in work wil be deleted at the end of a session, but in a costum no.
Although the costum library will be deletd itself, it can be retrived by above statement;


*-------------------------------------------*/
/*----      0-2 Import (READ)        ----*/
/*-------------------------------------------*/

* 1-library with XLSX engine: read directly;
option validvarname=v7; * Replace spaces with underscores;
libname xlclass xlsx "/home/u63451183/xlclass/new.xlsx"; *need to write the file path Not folder;

proc contents data=xlclass.sheet1; * need to write the worksheet name NOT file;
libname xlclass clear;

*2-PROC IMPORT for UNSTRUCTURED DATA: create a copy;
proc import datafile="/home/u63451183/xlclass/new.xlsx" dbms=xlsx
			out=work.new;
			sheet=sheet1;
run;
* The sheet name must be specified;

/* PROC IMPORT for CSV  */;
proc import datafile="/home/u63451183/Tutorial/arrivals.csv" dbms=csv
			out=tutorial.arrivals replace; 
			guessingrows=max; *provide the number of rows to esamine columnn type;
* PROC IMPORT requires out;


*-------------------------------------------*/
/*----      0-3 Export (WRITE)        ----*/
/*-------------------------------------------*/

* 1 library;
libname xlclass xlsx "outpath/class.xlsx";

data xlclass.class; * write in the first sheet;
	set sashelp.class;
run;

* 2 PROC EXPORT;
proc export data=myclass_adult outfile="" dbms=csv ;
run;

* 3 ODS;
ods csvall file="output path/file.csv";
proc print data=sashelp.class;
run;
ods csvall close;

ods excel file="output path/file.xlsx" options(sheetname='Folan');
proc print data=sashelp.class;
run;
ods excel close;

ods pdf file="output path/file.xlsx" style=journal startpage=no;
proc print data=sashelp.class;
run;
ods pdf close;

/*-------------------------------------------*/
/*----           1 DATA STEP:          ----*/
/*-------------------------------------------*/

/* Read */
data myclass;
	set sashelp.class(rename=(sex=gender) drop=height weight); *multiple table with the same column >> CONCAT;
run;

/* add column, filter, drop, numeric/char./date function. */
data myclass;
	set sashelp.class;
	class_name = "myclass";
	fitness_avg = mean(weight, height); *sum, min, nmiss, n, range ;
	initial = substr(name,1,1); *upcase(char) lowcase(char) propcase(char,<delim>) cats(char1,char2);
	where age > 13;
	drop sex name;
	keep weight height;
	format height 4.1 weight 3.; *permenant;
	* today = today(); * day() mdy();
run;

/*-------------------------------------------*/
/*---- 1-2 Conditional Processing ----*/
/*-------------------------------------------*/
* if <> then <>; * cannot use multiple order after then;
data myclass;
	set sashelp.class;
	length category $ 9;
	if age < 12 or height < 60 or missing(age) then category="kid";
	else if age < 15 then category="teenager";
	else category="Big/Adult";
run;

* if <> then do <> end + MULTIPLE OUTPUT TABLE;
data myclass_kid myclass_teen myclass_adult;
	set sashelp.class;
	if age < 12 then do;
		output myclass_kid;
	end;
	else if age < 15 then do;
		output myclass_teen;
	end;
	else do;
		output myclass_adult;
	end;


*-------------------------------------------*/
/*----           1-3 DO LOOP               ----*/
/*-------------------------------------------*/;
*CONDITIONAL;
data myclass;
	set sashelp.class;
	next_age = age;
	do year = 1 to 3;
		next_age + 1;
		output ;
	end;
run;
	
* ITERATIVE;	
data myclass;
	set sashelp.class;
	do until (age < 14); * do while;
		next_age = age +1;
	end;
run;

data myclass;
	set sashelp.class;
	do year = 1 to 3 until ();
		...
	end;
run;
	
	
/*-------------------------------------------*/
/*---- 1-4 COMPILATION & Execution DATA STEP  ----*/
/*-------------------------------------------*/
* - COMPILATION:
* --1 check for error;
* --2 Program Data Vector (PDV): Columns name, type, length. ONLY flag the drop;

* - EXECUTAION:
* -- READ a row from INPUT to the PDV, then write into OUTPUT;
data myclass;
	set sashelp.class;
	putlog "PDV after SET statement";
	putlog _all_;

* - EXPLICIT OUTPUT: when used, NO IMPLICIT OUTPUT for you anymore!;
data myclass;
	set sashelp.class;
	keep name sex age year next_age;
	year=1;
	next_age = age + 1;
	output;
	year=2;
	next_age = age + 2;
	output;
run;

* - RETAIN or SUM;
data myclass;
	set sashelp.class;
	retain acc_weight 0;
	acc_weight = acc_weight + weight;
run;

data myclass;
	set sashelp.class;
	retain acc_weight 0;
	acc_weight + weight;
run;

	
* DROP & KEEP;
* - in SET statement: Not read into PDV >> Not available for processing
* - As a STATEMENT or OPTION: Read into PDV >> Avilable for processing

*-------------------------------------------*/
/*----           2 PROC STEP               ----*/
/*-------------------------------------------*/

*-------------------------------------------*/
/*----   2-1 EXPLORING & VALIDATING     ----*/
/*-------------------------------------------*/

/* PROC CONTENTS: DESCRIPTOR PORTION, meta data */;
proc contents data="/home/u63451183/Tutorial/insurance.sas7bdat";
*proc content data=tutorial.insurance;
run;

/* PROC PRINT: list all rows and columns */
title "Senior Students name";
proc print data=myclass (obs=10) label;
	var name age height;
	where age ~= 12 and name = 'Alfred'; * WHERE statement: filtering/subsetting rows;
	where name in ("Alfred", "John", "Edward")
	format age dollar10.2;
	label height="inch";
run;

* > GT, >= GE, ^= ~= NE ;
*where date < "ddmmmyyy"d ;
*where name not in ("Alfred","Mamad","Folan");
*where xxx is missing / is not missing / is null ;
*where age between 10 and 20 ;
*where name like "Amir" patter matching "Ami_" / "A%"

/*PROC MEANS: simple statistics for numeric columns: N, mean, STD, Min, Max */;
proc means data=myclass sum mean max min median maxdec=2;
	var height weight;
	label height="inch";
	class sex age;
	ways 0 1; * with and without applying the classification;
	ways 2; *Two-way output;
	output out=myclass_avg mean=avg_age;
run;

/*PROC UNIVARIATE: detail statitics for numeric columns*/;
proc univariate data=myclass;
	var age height weight;
run;
					
/*PROC FREQ: UNIQUE VALUES >> frequency */
proc freq data=sashelp.class order=freq nlevels;
	*format date monname.;
	tables height weight / plots=freqplot ; * Seperate tables;
	table heigt*weight; * Two-way table;
run;

/*PROC SORT: sorting anduplicate treatment */
proc sort data=myclass out=myclass_sorted;
	by name age;
run;

* Removing DUPLICATES;
proc sort data=myclass out=myclass_sorted_nodup nodupkey dupout=myclass_dup;
	by _ALL_;
run;

*-------------------------------------------*/
/*----       2-2 AFTER SORT        ----*/
/*-------------------------------------------*/;
proc sort data=sashelp.class out=myclass_sort_sex;	
	by sex age ;
run;

* Report in group;
title "Age frequency in each gender";
footnote "It is a test";
ods noproctitle;
proc freq data=myclass_sort_sex;
	by sex;
	table age;
run;

/* Grouping after sorting*/
proc print data=myclass_sort_sex;
	by sex;
	id name;
	var age sex weight;
	sum weight;
run;

/* FIRST.<> LAST.<> */
data myclass_sort_sex_count;
	set myclass_sort_sex;
	by sex;
	counter + 1;
	if first.sex =1 then counter=1;
run;

data myclass_acc_weight;
	set myclass_sort_sex;
	by sex;
	if first.sex then accweight=0;
	accweight + weight;
run;

/* MERGING */
proc sort data=sashelp.classfit
	out = classfit_sort;
	by name age;


Data class_merge;
	merge sashelp.class(in=inClass)
		  classfit_sort(in=inFitt);
	by name;
	drop ex:;
run;
	

/*-------------------------------------------*/
/*----           3 MACRO               ----*/
/*-------------------------------------------*/

%let myname=Amir;
%let myage=31;

proc print data=sashelp.class;
	where name="&myname" or age=&myage;
run;


/*-------------------------------------------*/
/*----             4 SQL               ----*/
/*-------------------------------------------*/
proc sql;
	drop table myclass_sql;
quit;

proc sql;
create table myclass_sql as
	select upcase(name) as name, age, sex as gender
		from sashelp.class
		where age >10
		order by age asc;
quit;

* Merge;
proc sql;
	select *
	from sashelp.class as c inner join sashelp.classfit as f
	on c.name = f.name;
quit;


/*-------------------------------------------*/
/*----             5 FUNCTION        ----*/
/*-------------------------------------------*/

/* NUMERIC & DATE */

* SUM(col1,col2, ...) MEAN()
* YEARS(SAS-date) MONTH(SAS-date) TODAY() MDY(SAS-date);
* DATEPART(ISO-time) TIMEPART(ISO-time);

data ibm;
	set sashelp.stocks;
	max_price = largest(1, of open close);
	mean_price=mean(open, close);
run;

data myclass;
	ID = rand("integer",100, 999);
	set sashelp.class;
run;
	
* CALL ROUTINE, SPECIFY columns:;
data ibm;
	set sashelp.stocks;
	call sortn (of open high low close);
run;

*IME FUNCTION;
data ibm;
	set sashelp.stocks;
	month = month(date);
run;

/* CHARACTER */
* SCAN(string, n <,delimiters>) COMPBL(string) COMPRESS(string;
* FIND(string, substring)
* TRANWRD(col source, col dest, replacement) >> find and replace;

/* CONVERTOR */
* INPUT(source, informat) >> char to num
* PUT(source, format) >> num to char;

data ibm;
	set sashelp.stocks;
	time1= input(date, ANYDTDTEw.);
	time2= put(time1, date9.);
	
run;

/* CONCAT: CATX() */
data myclass;
	set sashelp.class;
	ID = catx('', name, sex, age, 'present');
run;


/*-------------------------------------------*/
/*----             6 FORMAT        ----*/
/*-------------------------------------------*/

* FORMAT based on TYPE: format _numeric_ <> 
						format _character_ <>;

* CUSTOM;
proc format;
	value $abbr 'F'='Female'
				'M'='Male';
run;

proc print data=sashelp.class;
	format sex $abbr.;
run;

proc data ...;
	set ...;
	chdate = put(date_col, date9.);

/*-------------------------------------------*/
/*----          7 TABLE STRUCTURE        ----*/
/*-------------------------------------------*/
* WIDE to NARROW;
data myclass_narrow;
	set sashelp.class;
	keep name age sex measure value;
	length measure $ 6;
	measure = 'Height';
	value = height;
	output;
	measure = 'Weight';
	value = weight;
	output;
run;

*NARROW to WIDE;
proc transpose data=myclass_narrow out=myclass_wide(drop=_name_);
	id measure;
	var value;
	by name age sex;
run;

	