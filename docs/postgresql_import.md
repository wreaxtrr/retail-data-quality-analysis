# Загрузка CSV в PostgreSQL через DBeaver

Перед импортом выполнить `sql/01_create_schema.sql`.

CSV загружаются в таком порядке:

1. `customers.csv`
2. `products.csv`
3. `orders.csv`
4. `order_items.csv`

Порядок важен из-за внешних ключей.

В DBeaver:

1. правой кнопкой по таблице;
2. `Import Data`;
3. выбрать `CSV`;
4. выбрать нужный файл из `data/processed/`;
5. delimiter `,`;
6. header включен;
7. encoding `UTF-8`;
8. проверить mapping колонок;
9. запустить импорт.

Ожидаемые размеры после загрузки:

```text
customers: 5942
products: 5304
orders: 53628
order_items: 1055238
```

После импорта выполнить `02_create_views.sql`, `03_data_quality_checks.sql` и `05_indexes.sql`.

`04_analytical_queries.sql` содержит независимые аналитические запросы.
