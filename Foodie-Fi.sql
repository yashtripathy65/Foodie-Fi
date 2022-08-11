-- table descriptions
SELECT * FROM SUBSCRIPTIONS LIMIT 5;
SELECT * FROM PLANS LIMIT 5;
SELECT * FROM MONTHS LIMIT 5;


/*COUNT OF TOTAL CUSTOMRES FOODIE-FI EVER HAD*/
SELECT 
    COUNT(distinct CUSTOMER_ID) AS TOTAL_CUSTOMERS
FROM dbo.subscriptions;

select extract(month from start_date) from dbo.subscriptions limit 5;

-- MONTHLY DISTRIBUTION OF TRIAL PLANS

WITH TRIAL_PLAN AS
(
SELECT
    extract(MONTH FROM START_DATE) AS MONTH_NO,
    COUNT(*) AS NO_OF_TRIAL_PLANS
FROM subscriptions    
WHERE PLAN_ID = 0
GROUP BY  extract(MONTH FROM START_DATE)
ORDER BY MONTH_NO   
)
SELECT 
    M.MONTH_NAME,
    A.NO_OF_TRIAL_PLANS
FROM TRIAL_PLAN AS A
LEFT JOIN MONTHS AS M
ON A.MONTH_NO = M.MONTH_NO;    

-- plans started after the year 2020

select 
	p.plan_id,
    p.plan_name,
    count(*) as no_of_plans
from plans as p
left join subscriptions as s
on p.plan_id = s.plan_id
where extract(year from s.start_date) > '2020'
group by 1,2
order by 1;

-- customer count and percentage who have churned
select 
	count(*) as churned_customers,
    (select count(distinct customer_id) from subscriptions) as total_customers,
    round(100.0*(count(*)/(select count(distinct customer_id) from subscriptions)),2) as percentage_churned
from  subscriptions
where plan_id = 4 ;

-- customers who churned after trial
with churned_customers as
(
select 
	customer_id,
    plan_id,
    start_date,
    lag(plan_id,1) over (partition by customer_id order by start_date) as previous_plan
from subscriptions 
)
select 
	(select count(distinct customer_id) from subscriptions) as total_customers,
    count(customer_id) as churn,
    round(100*(count(customer_id)/(select count(distinct customer_id) from subscriptions)),2) as percentage_churned
from churned_customers
where plan_id = 4 and previous_plan = 0 ;

-- customers who bougt basic monthly after trial
with basic_monthly as
(
select 
	customer_id,
    plan_id,
    start_date,
    lag(plan_id,1) over (partition by customer_id order by start_date) as previous_plan
from subscriptions 
)
select 
	(select count(distinct customer_id) from subscriptions) as total_customers,
    count(customer_id) as basic_plan,
    round(100*(count(customer_id)/(select count(distinct customer_id) from subscriptions)),2) as percentage_basic
from basic_monthly
where plan_id = 1 and previous_plan = 0 ;

-- customers who bougt pro monthly after trial
with pro_monthly as
(
select 
	customer_id,
    plan_id,
    start_date,
    lag(plan_id,1) over (partition by customer_id order by start_date) as previous_plan
from subscriptions 
)
select 
	(select count(distinct customer_id) from subscriptions) as total_customers,
    count(customer_id) as pro_monthly_plan,
    round(100*(count(customer_id)/(select count(distinct customer_id) from subscriptions)),2) as percentage_pro_monthly
from pro_monthly
where plan_id = 2 and previous_plan = 0 ;


-- customers who bougt pro annual after trial
with pro_annual as
(
select 
	customer_id,
    plan_id,
    start_date,
    lag(plan_id,1) over (partition by customer_id order by start_date) as previous_plan
from subscriptions 
)
select 
	(select count(distinct customer_id) from subscriptions) as total_customers,
    count(customer_id) as pro_annual_plan,
    round(100*(count(customer_id)/(select count(distinct customer_id) from subscriptions)),2) as percentage_pro_annual
from pro_annual
where plan_id = 3 and previous_plan = 0 ;

-- number and percentage of customer plans after their initial free trial 
with next_plan_chosen as
(
select 
	customer_id,
    plan_id,
    start_date,
    lead(plan_id,1) over (partition by customer_id order by start_date) as next_plan
from subscriptions 
),
different_plans as
(
select 
	next_plan as plan_no,
    count(customer_id) as number_of_customers,
    round(100*(count(customer_id)/(select count(distinct customer_id) from subscriptions)),2) as percentage_customers
 from next_plan_chosen
 where plan_id = 0 and next_plan is not null
 group by 1
 order by 1
)
select 
	A.plan_no,
    B.plan_name,
    A.number_of_customers,
    A.percentage_customers
from different_plans as A
inner join plans as B
on A.plan_no = B.plan_id;    

-- avg time taken to join the pro annual plan
alter table subscriptions modify start_date date;

with avg_time as
(
select 
	customer_id,
    plan_id,
    start_date,
	lead(start_date,1) over (partition by customer_id order by start_date) as pro_plan
from subscriptions
where plan_id=0 or plan_id = 3
order by 1
)

select 
    round(avg(timestampdiff(day,start_date,pro_plan))) as time_interval
from avg_time
where pro_plan is not null and plan_id = 0
order by customer_id; 
-- Day wise distribution of time taken by customers to upgrade to pro_annual plan
with avg_time as
(
select 
	customer_id,
    plan_id,
    start_date,
	lead(start_date,1) over (partition by customer_id order by start_date) as pro_plan
from subscriptions
where plan_id=0 or plan_id = 3
order by 1
),
time_taken as 
 (
select 
	 *,
    timestampdiff(day,start_date,pro_plan) as time_interval
from avg_time
where pro_plan is not null and plan_id = 0
order by customer_id
)
select 
	case when time_interval >= 0   and time_interval < 30 then '0-30'
		 when time_interval >= 30  and time_interval < 60 then '30-60'
         when time_interval >= 60  and time_interval < 90 then '60-90'
         when time_interval >= 90  and time_interval < 120 then '90-120'
         when time_interval >= 120 and time_interval < 150 then '120-150'
         when time_interval >= 150 and time_interval < 180 then '150-180'
         when time_interval >= 180 and time_interval < 210 then '180-210'
         when time_interval >= 210 and time_interval < 240 then '210-240'
         when time_interval >= 240 and time_interval < 270 then '240-270'
         when time_interval >= 270 and time_interval < 300 then '270-300'
         when time_interval >= 300 and time_interval < 330 then '300-330'
         when time_interval >= 330 and time_interval < 360 then '330-360' end as time_taken_to_upgrade,
    count(*) as no_of_customers
from time_taken
group by 1
order by time_interval;   

-- total customers vs pro_annual customers
select
	count(distinct customer_id) as total_customers,
    (select count(distinct customer_id) from subscriptions where plan_id = 3) as pro_annual_customers
from subscriptions;
 

    


    