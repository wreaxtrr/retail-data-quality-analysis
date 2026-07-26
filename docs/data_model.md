# Модель данных

После очистки исходная транзакционная таблица разделена на четыре сущности.

```mermaid
erDiagram
    CUSTOMERS ||--o{ ORDERS : places
    ORDERS ||--|{ ORDER_ITEMS : contains
    PRODUCTS ||--o{ ORDER_ITEMS : included_in

    CUSTOMERS {
        int customer_id PK
    }

    PRODUCTS {
        varchar stock_code PK
        text description
    }

    ORDERS {
        varchar invoice PK
        int customer_id FK
        timestamp invoice_date
        varchar country
        boolean is_cancelled
    }

    ORDER_ITEMS {
        bigint order_item_id PK
        varchar invoice FK
        varchar stock_code FK
        int quantity
        numeric price
        numeric line_total
    }
```

## Решения по нормализации

`country` хранится в `orders`, а не в `customers`: в данных 13 покупателей встречаются более чем в одной стране.

Для 83 счетов позиции имеют несколько близких значений времени. Максимальная разница составляет 9 минут, поэтому временем счета считается минимальный `invoice_date`.

У 1 213 кодов товара встречается больше одного описания. Для справочника `products` выбирается наиболее часто встречающееся непустое описание.

355 кодов товара не имеют описания вообще. Такие товары остаются в справочнике с `NULL` в `description`, чтобы не нарушать связи с `order_items`.

`price` хранится в `order_items`, потому что цена товара может меняться между транзакциями.

`line_total` является производным полем (`quantity * price`). Оно сохранено для сверки результатов Python и SQL; при необходимости его можно вычислять на лету.
