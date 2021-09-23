*input datas;
Proc import Datafile="/folders/myfolders/STAT621/Players.csv"
    DBMS=CSV
	OUT=WORK.Players;
	GETNAMES=YES;
RUN;

Proc contents data=players;
run;

Proc import Datafile="/folders/myfolders/STAT621/player_data.csv"
    DBMS=CSV
	OUT=WORK.player_data;
	GETNAMES=YES;
RUN;

Proc contents data=player_data;
run;

Proc import Datafile="/folders/myfolders/STAT621/Seasons_Stats.csv"
    DBMS=CSV
	OUT=WORK.Seasons_Stats;
	GETNAMES=YES;
RUN;

Proc contents data=Seasons_Stats;
run;

proc print data = player_data (obs = 200);
	run;

proc print data = seasons_stats (obs = 200);
	run;
	
proc print data = players (obs = 200);
	run;
*tidy up, change formats and modify units;
**************************************************************************************************

******************************************Player_data file*****************************************;
Proc sort data=player_data;
 by name;
run;

Data Player_data1;
 set player_data;
 *set year to date format;
 Year_start=mdy(1,1,year_start);
 Year_end=mdy(1,1,year_end);
 birth_date=datepart(birth_date);
 format year_start year4. year_end year4. birth_date MMDDYY10.;
 *uniform the name variable to player;
 rename name=player;
 *spliting the height to feet and inch;
 feet=input(scan(height,1,"-"),f1.);
 inch=input(scan(height,2,"-"),f2.);
 Drop height;
Run;

Data Player_data2;
  set player_data1;
  * putting the height together, and calculate to cm;
  Height_cm= (feet*12+inch)*2.54;
  drop feet inch;
  *calculate the weight from lb to kg;
  weight_kg=round(weight*0.453592,0.01);
  Drop weight;
run;

***********************************************************************************************
******************************************players file*****************************************;
Proc sort data=players;
by player;
run;

Data Players1;
  set players;
  * var1 is the counting var with no meaning;
  drop var1;
  *format born from num to date;
  born=mdy(1,1,born);
  format born Year4.;
  rename height=height_cm weight=weight_kg;
run;


*****************************************************************************************************
******************************************seasons_stats file*****************************************;
proc sort data=seasons_stats;
by player;
run;
*deleting empty variables, observations, rename;
data seasons_stats1;
  set seasons_stats;
  *delete empty obs;
  if player="" then delete;
  *delete empty vars;
  drop var1 PER _3PAr ORB_ DRB_ TRB_ AST_ STL_ BLK_ TOV_ USG_ blanl blank2 DBPM BPM VORP _3P _3PA STL BLK 
  ORB DRB OBPM TOV _3P_;
  *get the names of var meanningful;
  rename year=season POS=position Tm=Team G=Games TS_=TrueShootingPercentage MP = MinutesPlayed GS = GamesStarted
         FTr=FreeThrowRate OWS=OffensiveWinShares DWS=DefensiveWinShares WS=WinShares WS_48=WinSharesPer48Min
         FG=FieldGoals FGA=FieldGoalAttempts FG_=FieldGoalPercentage _2P_=_2P_Percentage 
         eFG_=EffectiveFieldGoalPercentage FT=FreeThrows FTA=FreeThrowAttempts FT_=FreeThrowPercentage
         AST=Assists PF=PersonalFouls PTS=Points TRB=TotalRebounds;
run;

proc contents data=seasons_stats1;
run;

*deleted 67 obs (24691-24624), 53 to 26 vars;
*readded games started and minutes played variables

*formating;
data seasons_stats2;
 set seasons_stats1;
 *format seasons to date;
 season=mdy(1,1,season);
 format season year4.;
run;


********************************************************************************************************
**********************************merging table player_data and players*********************************;
Proc sort data=player_Data2;
 by player;
run;
Proc sort data=players1;
 by player;
run;

*join two tables 
create var play_name with players in both table
(there are incomplete names and names with * in player1),
the weight and the height in two tables are a little different,
fill in the college info;

Proc sql;
  create table Player_full as
   select players1.player as player1, 
         player_data2.player as player2,
     case when player2 contains player1
       then player2
       when player1 contains player2
       then player2
       when player1 is missing
       then player2
       else player1
       end as player_name,
     birth_date, born, birth_city, Birth_state, year_start, year_end, position,
   Case when players1.height_cm=.
        then player_data2.height_cm
        else players1.height_cm
        end as height_cm, 
   case when players1.weight_kg=.
        then player_data2.weight_kg
        else players1.weight_kg
        end as weight_kg,
    case when players1.collage=""
       then player_data2.college
       else players1.collage
       end as college
    from Players1 right join player_data2
    on players1.player= player_data2.player;
quit;

*drop the dup vars;
data Player_final;
   set player_full;
   drop player1 player2 born;
   rename player_name=player;
   run;

*******************************************ADD VARIABLES NEEDED*****************************************

*calculate the vars needed;
data player_final1;
   set player_final;
   start_age=round(((year_start-birth_date-int(int((year_start-birth_date)/365)/4))/365),1);
   Career_length=int((year_end-year_start-int(int((year_end-year_start)/365)/4))/365);
   BMI=weight_kg/((Height_cm/100)**2);
   *add variable swing man;
   if length(position)=3 then do;
   Swing_man="Yes";
   end;
   if length(position)=1 then do;
   Swing_man="No";
   end;
   if position="" then do;
   Swing_man="NA";
   end;
run;
   
**********************************************ANALYSIS************************************************
*summarys;  
**********************************************START AGE***********************************************; 
Proc sort data=player_final1;
   by start_age;   
   run;
proc summary data=player_final1;
   var start_age;
   output out=startagesum min=min max=max median=median;
run;
*********************************************CAREER LENGTH*******************************************;
Proc sort data=player_final1;
   by career_length;   
   run;
proc summary data=player_final1;
   var career_length;
   output out=Careerlengthsum min=min max=max median=median mean=mean;
run;

*scatter plot;
ODS GRAPHICS on/ ANTIALIASMAX=4600; *the data exceed the max number of graphical element;
title 'Scatter Plot for Start age by Career_length';
proc SGPLOT data = player_final1;
        scatter x= Start_age y = Career_length ;
        xaxis Label ='Start Age';
        yaxis label = 'Career Length';
run;


proc print data = player_final1 (obs = 50);
	run;
	
data player_final1_edit;
	set player_final1;
	censor = 1;

proc freq data = player_final1;
	tables Career_length/ out= career_length_count;
	
	
	
proc lifetest data = player_final1_edit;
	time career_length*censor(0);

*proc lifetest data = player_final1;
*	time Career_length*

************************************************* BMI ************************************************;
Proc sort data=player_final1;
  by BMI;
  run;
proc summary data=player_final1;
   var BMI;
   output out=BMIsum min=min max=max median=median mean=mean;
run;   

*scatterplot for BMI;
title 'Scatter Plot for BMI by Career_length';
proc SGPLOT data = player_final1;
        scatter x= BMI y = Career_length ;
        xaxis Label ='BMI';
        yaxis label = 'Career Length';
run;

*******************college does not overlap frequently;
proc freq data=player_final1;
   table college;
   run;
   
************************************************* STATE *************************************************;
proc sort data=player_final1;
 by birth_state;
 run;
proc freq data=player_final1;
   table birth_state;
   run;

title 'Box Plot for career length by birth state';
   proc boxplot data=player_final1;
      plot career_length*birth_state /MAXPANELS=120;
        label birth_state ='Birth state';
        label career_length = 'career length';
   run;
   
************************************************* POSITION *************************************************;
proc sort data=player_final1;
 by position;
 run;
proc freq data=player_final1;
   table position;
   run;

title 'Box Plot for career length by position';
   proc boxplot data=player_final1;
      plot career_length*position /MAXPANELS=120;
        label position ='position';
        label career_length = 'career length';
   run;

data player_final1_edit;
	set player_final1;
	*if position = 'F' or position = 'G' or position = 'C';
	censor = 1;
	

*part that Sean did - starts from line 299 to 489. up to swing man code;

proc sort data = player_final1_edit;
	by player;
	
proc sort data = seasons_stats2;
	by player;
	
proc freq data = seasons_stats2 (obs = 50);
	by player;
	run;
	
data combined;
	merge player_final1_edit seasons_stats2;
	by player;
	
proc print data = combined (obs = 200);
run;

	



data player_stats_total;
	set seasons_stats2;
	group by player;
	run;
	



proc sort data = player_final1_edit;
	by player;
	
proc sort data = player_stats_total2;
	by player;
	

	



proc sql;
create table player_seasons_total as
 select player, season
  from seasons_stats2
   group by player;
quit;


	
proc sql;
  create table player_season_count as
  select player, count(season) as seasons
  from player_seasons_total
  group by player;
quit;

data combined3;
	merge player_final1_edit player_season_count;
	by player;
	
proc lifetest data = combined3;
	time seasons*Censor(0);
	run;
	
proc lifetest data = combined3;
	time career_length*Censor(0);
	run;
	
data player_career_length;
	set combined3;
	if bmi lt 18.5 then bmi_recode = 'Underweight';
	else if bmi ge 18.5 and bmi lt 25 then bmi_recode = 'Normal';
	else if bmi ge 25 and bmi lt 30 then bmi_recode = 'Overweight';
	else if bmi ge 30 then bmi_recode = 'Obese';
	run;

proc lifetest data = player_career_length;
	time seasons*censor(0);
	strata bmi_recode;
	
proc lifetest data = player_career_length;
	time career_length*censor(0);
	strata position;
	
proc print data = player_career_length (obs = 100);
run;
	
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = aneuploid METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype=linear confband=all alpha=0.05;
TIME dtime*censor(0);
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

data outsomething;
	set out2;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out3 conftype= loglog confband= all alpha=0.05;
TIME seasons*censor(0);
strata position;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

*data outsomething1 (keep = dtime EP_LCL EP_UCL);
*	set out3;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype= asinsqrt confband = all alpha=0.05;
TIME seasons*censor(0);
strata position;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata position;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata bmi_recode;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata start_age;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata swing_man;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata team;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

proc print data=seasons_stats2 (obs = 50);


proc sort data = seasons_stats2;
	by team;
proc freq data = seasons_stats2;
	by team;
data team_test;
	set seasons_stats2 (drop = player);
	
proc sort data = team_test;
	by team;

proc freq data = team_test;
tables team;

proc sql;
create table player_seasons_total2 as
 select player, count(season) as seasons, count(distinct team) as team_count
  from seasons_stats2
   group by player;
quit;
 
proc sql;
create table player_seasons_total3 as
 select player, seasons, team_count, case 
 when team_count > 1 then 'Yes'
 else 'No'
 end as multiple_teams
  from player_seasons_total2
   group by player;
quit;

proc freq data = player_seasons_total3;
	tables multiple_teams;
	
************************************************ SWING MAN *************************************************;
proc sort data=player_final1;
   by swing_man;
   run;
proc freq data=player_final1;
   table swing_man;
   run;

title 'Box Plot for career length by swing man';
   proc boxplot data=player_final1;
      plot career_length*swing_man /MAXPANELS=120;
        label swing_man ='swing man';
        label career_length = 'career length';
   run;

*********************************************** Seasons File ***********************************************;
*Points;
proc sort data=seasons_stats2;
   by points;
   run;

title 'Scatter Plot for points by season';
proc SGPLOT data = seasons_stats2;
        scatter x= season y = points ;
        xaxis Label ='season';
        yaxis label = 'points';
run;

proc print data = seasons_stats2 (obs = 200);
run;


***************************************************** AGE *****************************************************;
proc sort data=seasons_stats2;
   by AGE;
   run;
proc freq data=seasons_stats2;
   table Age;
   run;
title 'Box Plot for points by age';
   proc boxplot data=seasons_stats2;
      plot points*age /MAXPANELS=120;
        label age ='age';
        label points = 'points';
   run;
title 'Scatter Plot for points by AGE';
proc SGPLOT data = seasons_stats2;
        scatter x= Age y = points ;
        xaxis Label ='Age';
        yaxis label = 'points';
run;

************************************************** Position **************************************************;
proc sort data=seasons_stats2;
   by position;
   run;
proc freq data=seasons_stats2;
   table position;
   run;
title 'Box Plot for points by position';
   proc boxplot data=seasons_stats2;
      plot points*position /MAXPANELS=120;
        label position ='position';
        label points = 'points';
   run;
title 'Scatter Plot for points by position';
proc SGPLOT data = seasons_stats2;
        scatter x= position y = points ;
        xaxis Label ='position';
        yaxis label = 'points';
run;

**************************************************** TEAM ******************************************************;
proc sort data=seasons_stats2;
   by team;
   run;
proc freq data=seasons_stats2;
   table team;
   run;
title 'Box Plot for points by team';
   proc boxplot data=seasons_stats2;
      plot points*team /MAXPANELS=120;
        label team ='team';
        label points = 'points';
   run;
title 'Scatter Plot for points by team';
proc SGPLOT data = seasons_stats2;
        scatter x= team y = points ;
        xaxis Label ='team';
        yaxis label = 'points';
run;

**************************************************** GAMES ******************************************************;
proc sort data=seasons_stats2;
   by games;
   run;
proc freq data=seasons_stats2;
   table games;
   run;
title 'Box Plot for points by games';
   proc boxplot data=seasons_stats2;
      plot points*games /MAXPANELS=120;
        label games ='games';
        label points = 'points';
   run;
title 'Scatter Plot for points by games';
proc SGPLOT data = seasons_stats2;
        scatter x= games y = points ;
        xaxis Label ='games';
        yaxis label = 'points';
run;

