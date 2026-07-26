set search_path to retail;

select 'customers' as table_name, count(*) as rows_count from customers
union all select 'products', count(*) from products
union all select 'orders', count(*) from orders
union all select 'order_items', count(*) from order_items;

select count(*) as items_without_order
from order_items oi
left join orders o on o.invoice = oi.invoice
where o.invoice is null;

select count(*) as items_without_product
from order_items oi
left join products p on p.stock_code = oi.stock_code
where p.stock_code is null;

select count(*) as orders_without_known_customer
from orders o
left join customers c on c.customer_id = o.customer_id
where o.customer_id is not null and c.customer_id is null;

select count(*) as cancelled_flag_mismatch
from orders
where is_cancelled <> (upper(invoice) like 'C%');

select count(*) as line_total_mismatch
from order_items
where abs(line_total - quantity * price) > 0.01;

select count(*) as products_without_description
from products
where description is null;

select
    count(*) filter (where quantity < 0) as negative_quantity_rows,
    count(*) filter (where price = 0) as zero_price_rows,
    count(*) filter (where price < 0) as negative_price_rows
from order_items;

select count(*) as sales_rows
from v_sales;

select count(*) as customer_sales_rows
from v_customer_sales;

select
    min(invoice_date) as first_date,
    max(invoice_date) as last_date,
    count(distinct invoice) as invoices,
    count(distinct customer_id) as customers,
    count(distinct stock_code) as products,
    round(sum(line_total), 2) as revenue
from v_sales;
