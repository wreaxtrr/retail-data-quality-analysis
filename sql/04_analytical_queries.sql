set search_path to retail;

-- 1. основные метрики
select
    count(*) as sales_rows,
    count(distinct invoice) as invoices,
    count(distinct customer_id) as customers,
    count(distinct stock_code) as products,
    round(sum(line_total), 2) as revenue,
    round(sum(line_total) / nullif(count(distinct invoice), 0), 2) as average_invoice
from v_sales;

-- 2. продажи по месяцам
select month, invoices, customers, revenue, average_invoice
from v_monthly_metrics
order by month;

-- 3. изменение выручки относительно прошлого месяца
with monthly as (
    select month, revenue
    from v_monthly_metrics),

metrics as (
    select month, revenue, lag(revenue) over (order by month) as previous_revenue
    from monthly)

select
    month,
    revenue,
    previous_revenue,
    round((revenue - previous_revenue) / nullif(previous_revenue, 0) * 100, 2) as revenue_growth_pct
from metrics
order by month;

-- 4. сравнение января-ноября 2010 и 2011
select
    extract(month from month)::int as month_number,
    max(revenue) filter (where extract(year from month) = 2010) as revenue_2010,
    max(revenue) filter (where extract(year from month) = 2011) as revenue_2011
from v_monthly_metrics
where extract(year from month) in (2010, 2011)
and extract(month from month) <= 11
group by 1
order by 1;

-- 5. доля повторных покупателей
with customer_orders as (
    select customer_id, count(distinct invoice) as orders_count
    from v_customer_sales
    group by customer_id)

select
    count(*) as customers,
    count(*) filter (where orders_count = 1) as one_time_customers,
    count(*) filter (where orders_count >= 2) as repeat_customers,
    round(100.0 * count(*) filter (where orders_count >= 2) / nullif(count(*), 0), 2) as repeat_customer_rate
from customer_orders;

-- 6. распределение покупателей по числу счетов
with customer_orders as (
    select customer_id, count(distinct invoice) as orders_count
    from v_customer_sales
    group by customer_id)

select
    case
        when orders_count = 1 then '1'
        when orders_count between 2 and 5 then '2-5'
        when orders_count between 6 and 10 then '6-10'
        else '>10'
    end as orders_group,
    count(*) as customers,
    round(100.0 * count(*) / sum(count(*)) over (), 2) as customer_share
from customer_orders
group by 1
order by min(orders_count);

-- 7. когортный retention
with customer_months as (
    select distinct customer_id, date_trunc('month', invoice_date)::date as order_month
    from v_customer_sales),

cohorts as (
    select customer_id, min(order_month) as cohort_month
    from customer_months
    group by customer_id),

activity as (
    select
        cm.customer_id,
        c.cohort_month,
        cm.order_month,
        (extract(year from age(cm.order_month, c.cohort_month)) * 12 + extract(month from age(cm.order_month, c.cohort_month)))::int as month_number
    from customer_months cm
    join cohorts c on c.customer_id = cm.customer_id),

cohort_sizes as (
    select cohort_month, count(*) as cohort_size
    from cohorts
    group by cohort_month),

retention as (
    select cohort_month, month_number, count(distinct customer_id) as active_customers
    from activity
    group by cohort_month, month_number)

select
    r.cohort_month,
    r.month_number,
    cs.cohort_size,
    r.active_customers,
    round(100.0 * r.active_customers / nullif(cs.cohort_size, 0), 2) as retention_rate
from retention r
join cohort_sizes cs on cs.cohort_month = r.cohort_month
where r.cohort_month >= date '2010-01-01'
and r.cohort_month <= date '2011-05-01'
and r.month_number between 1 and 6
order by r.cohort_month, r.month_number;

-- 8. RFM-сегментация
with analysis_date as (
    select max(invoice_date)::date + 1 as analysis_date
    from v_customer_sales),

customer_stats as (
    select
        s.customer_id,
        a.analysis_date - max(s.invoice_date)::date as recency,
        count(distinct s.invoice) as frequency,
        sum(s.line_total) as monetary
    from v_customer_sales s
    cross join analysis_date a
    group by s.customer_id, a.analysis_date),

quantiles as (
    select
        percentile_cont(0.25) within group (order by recency) as r25,
        percentile_cont(0.50) within group (order by recency) as r50,
        percentile_cont(0.75) within group (order by recency) as r75,
        percentile_cont(0.25) within group (order by frequency) as f25,
        percentile_cont(0.50) within group (order by frequency) as f50,
        percentile_cont(0.75) within group (order by frequency) as f75,
        percentile_cont(0.25) within group (order by monetary) as m25,
        percentile_cont(0.50) within group (order by monetary) as m50,
        percentile_cont(0.75) within group (order by monetary) as m75
    from customer_stats),

scores as (
    select
        s.*,
        case when recency <= r25 then 4 when recency <= r50 then 3 when recency <= r75 then 2 else 1 end as r_score,
        case when frequency <= f25 then 1 when frequency <= f50 then 2 when frequency <= f75 then 3 else 4 end as f_score,
        case when monetary <= m25 then 1 when monetary <= m50 then 2 when monetary <= m75 then 3 else 4 end as m_score
    from customer_stats s
    cross join quantiles),

segments as (
    select
        *,
        case
            when r_score = 4 and f_score = 4 then 'Champions'
            when r_score >= 3 and f_score >= 3 then 'Loyal customers'
            when r_score >= 3 and f_score = 2 then 'Potential loyalists'
            when r_score = 4 and f_score = 1 then 'New customers'
            when r_score = 3 and f_score = 1 then 'Promising'
            when r_score <= 2 and f_score >= 3 then 'At risk'
            else 'Hibernating'
        end as segment
    from scores)

select
    segment,
    count(*) as customers,
    round(sum(monetary), 2) as revenue,
    round(100.0 * sum(monetary) / sum(sum(monetary)) over (), 2) as revenue_share
from segments
group by segment
order by revenue desc;

-- 9. страны
select
    country,
    round(sum(line_total), 2) as revenue,
    count(distinct invoice) as invoices,
    count(distinct customer_id) as customers,
    round(sum(line_total) / nullif(count(distinct invoice), 0), 2) as average_invoice
from v_sales
group by country
order by revenue desc;

-- 10. товары по выручке
select
    stock_code,
    max(description) as description,
    sum(quantity) as quantity,
    round(sum(line_total), 2) as revenue,
    count(distinct invoice) as invoices
from v_sales
group by stock_code
order by revenue desc
limit 20;

-- 11. концентрация выручки в товарах
with product_revenue as (
    select stock_code, sum(line_total) as revenue
    from v_sales
    group by stock_code),

ranked as (
    select stock_code, revenue, row_number() over (order by revenue desc) as rn
    from product_revenue)

select
    round(100.0 * sum(revenue) filter (where rn <= 10) / sum(revenue), 2) as top_10_share,
    round(100.0 * sum(revenue) filter (where rn <= 100) / sum(revenue), 2) as top_100_share
from ranked;

-- 12. активность по дням недели
select
    trim(to_char(invoice_date, 'Day')) as weekday,
    extract(isodow from invoice_date)::int as weekday_number,
    count(distinct invoice) as invoices
from v_sales
group by 1, 2
order by 2;

-- 13. активность по часам
select
    extract(hour from invoice_date)::int as hour,
    count(distinct invoice) as invoices
from v_sales
group by 1
order by invoices desc, hour;

-- 14. доля выручки без customer_id
select
    case when customer_id is null then 'unknown customer' else 'known customer' end as customer_group,
    count(distinct invoice) as invoices,
    round(sum(line_total), 2) as revenue,
    round(100.0 * sum(line_total) / sum(sum(line_total)) over (), 2) as revenue_share
from v_sales
group by 1
order by revenue desc;
