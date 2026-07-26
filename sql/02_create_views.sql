set search_path to retail;

create or replace view v_sales as
select
    oi.order_item_id,
    o.invoice,
    o.customer_id,
    o.invoice_date,
    o.country,
    oi.stock_code,
    p.description,
    oi.quantity,
    oi.price,
    oi.line_total
from order_items oi
join orders o on o.invoice = oi.invoice
join products p on p.stock_code = oi.stock_code
where o.is_cancelled = false
and oi.quantity > 0
and oi.price > 0
and oi.stock_code not in ('M', 'POST', 'DOT', 'C2', 'D', 'BANK CHARGES', 'AMAZONFEE', 'B', 'CRUK', 'S', 'PADS', 'TEST001', 'TEST002');

create or replace view v_customer_sales as
select *
from v_sales
where customer_id is not null;

create or replace view v_invoice_summary as
select
    invoice,
    customer_id,
    min(invoice_date) as invoice_date,
    min(country) as country,
    sum(quantity) as items_count,
    round(sum(line_total), 2) as revenue
from v_sales
group by invoice, customer_id;

create or replace view v_monthly_metrics as
select
    date_trunc('month', invoice_date)::date as month,
    count(distinct invoice) as invoices,
    count(distinct customer_id) as customers,
    round(sum(line_total), 2) as revenue,
    round(sum(line_total) / nullif(count(distinct invoice), 0), 2) as average_invoice
from v_sales
group by 1;
