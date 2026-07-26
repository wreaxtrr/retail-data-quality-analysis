set search_path to retail;

create index if not exists idx_orders_invoice_date on orders(invoice_date);
create index if not exists idx_orders_customer_date on orders(customer_id, invoice_date);
create index if not exists idx_orders_country on orders(country);
create index if not exists idx_orders_cancelled on orders(is_cancelled);
create index if not exists idx_order_items_stock_code on order_items(stock_code);

analyze;
