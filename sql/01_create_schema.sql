drop schema if exists retail cascade;
create schema retail;
set search_path to retail;

create table customers (
    customer_id integer primary key);

create table products (
    stock_code varchar(30) primary key,
    description text);

create table orders (
    invoice varchar(30) primary key,
    customer_id integer,
    invoice_date timestamp not null,
    country varchar(100) not null,
    is_cancelled boolean not null,
    foreign key (customer_id) references customers(customer_id));

create table order_items (
    order_item_id bigint primary key,
    invoice varchar(30) not null,
    stock_code varchar(30) not null,
    quantity integer not null,
    price numeric(18,4) not null,
    line_total numeric(18,4) not null,
    foreign key (invoice) references orders(invoice),
    foreign key (stock_code) references products(stock_code));
