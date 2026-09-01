# FulfillIQ — Complete Database Context Package

This documents the database we actually built and loaded in this conversation. It is intended to be pasted into another AI session **before asking that AI to generate SQL**.

Where something was not explicitly verified during the build, I mark it **UNKNOWN / NEEDS VERIFICATION** rather than guessing.

---

## 1. Database system and environment

| Item | Value |
| ---------------------------- | -------------------------------------- |
| Database system              | MySQL Community Server                 |
| **MySQL Server version**     | **8.0.46**                             |
| MySQL Workbench version      | 8.0.47                                 |
| MySQL Shell version          | 8.0.46                                 |
| Operating system             | Windows                                |
| Server configuration         | Local standalone development server    |
| Host                         | `localhost`                            |
| Port                         | `3306`                                 |
| Database/schema              | **`fulfilliq`**                        |
| Project user                 | `fulfilliq_user`                       |
| Workbench project connection | `FulfillIQ Local`                      |
| Character set                | `utf8mb4`                              |
| Database collation           | `utf8mb4_0900_ai_ci`                   |
| Authentication               | MySQL 8 strong-password authentication |
| Raw data source              | Brazilian Olist e-commerce CSV dataset |

The database was created with:

```
CREATE DATABASE IF NOT EXISTS fulfilliq
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;
```

### Confirm the exact running MySQL version

Although **8.0.46 was explicitly installed and configured**, another AI can verify the currently running server with:

```
SELECT VERSION();
```

or:

```
SELECT
    @@version AS mysql_version,
    @@version_comment AS version_comment;
```

---

## 2. SQL dialect and important environment behavior

SQL should be written specifically for **MySQL 8.0**, not PostgreSQL, SQL Server, SQLite, Oracle, or generic SQL.

MySQL 8 syntax/features available include things such as:

```
WITH ...
ROW_NUMBER() OVER (...)
LAG(...)
LEAD(...)
DATE(...)
DATE_FORMAT(...)
DATEDIFF(...)
TIMESTAMPDIFF(...)
CASE
COALESCE(...)
NULLIF(...)
```

The database uses:

```
utf8mb4
utf8mb4_0900_ai_ci
```

Because the tables were created without per-column collations, textual columns normally inherit the database/table default collation.

### SQL mode

We did **not** explicitly inspect or modify MySQL's `sql_mode`.

Therefore:

**UNKNOWN / NEEDS VERIFICATION**

Run:

```
SELECT @@SESSION.sql_mode;
SELECT @@GLOBAL.sql_mode;
```

This matters especially for `GROUP BY` behavior such as `ONLY_FULL_GROUP_BY`.

### Time zone

We did not explicitly configure MySQL's session time zone.

**UNKNOWN / NEEDS VERIFICATION**

Run:

```
SELECT
    @@SESSION.time_zone,
    @@GLOBAL.time_zone;
```

The source event fields themselves are stored as `DATETIME`, not `TIMESTAMP`.

---

## 3. Tables currently in `fulfilliq`

Nine raw tables were created and populated:

| Table | Purpose | Verified rows |
| -------------------------- | ---------------------------------------------------- | --------- |
| `raw_orders`               | Order-level lifecycle/status data                    | 99,441    |
| `raw_order_items`          | Individual products sold within orders               | 112,650   |
| `raw_sellers`              | Seller master/location data                          | 3,095     |
| `raw_customers`            | Order-customer and underlying customer identity data | 99,441    |
| `raw_products`             | Product attributes and category                      | 32,951    |
| `raw_payments`             | Payment transactions/methods for orders              | 103,886   |
| `raw_reviews`              | Customer review data                                 | 99,224    |
| `raw_category_translation` | Portuguese-to-English product-category mapping       | 71        |
| `raw_geolocation`          | ZIP-prefix geolocation observations                  | 1,000,163 |

Total raw rows across these tables:

**1,450,922 rows**

No analytical marts have been created yet.

---

## 4. Exact table schemas

## `raw_orders`

### Grain

**One row per `order_id`.**

### Columns

| Column | Type | Constraint | Meaning |
| ------------------------------- | ------------- | -------------- | ---------------------------------- |
| `order_id`                      | `VARCHAR(50)` | `NOT NULL`, PK | Unique order identifier            |
| `customer_id`                   | `VARCHAR(50)` | `NOT NULL`     | Order-specific customer identifier |
| `order_status`                  | `VARCHAR(30)` | nullable       | Order lifecycle status             |
| `order_purchase_timestamp`      | `DATETIME`    | nullable       | When order was placed              |
| `order_approved_at`             | `DATETIME`    | nullable       | When payment/order was approved    |
| `order_delivered_carrier_date`  | `DATETIME`    | nullable       | When order reached carrier         |
| `order_delivered_customer_date` | `DATETIME`    | nullable       | Actual customer delivery time      |
| `order_estimated_delivery_date` | `DATETIME`    | nullable       | Promised/estimated delivery time   |

### Primary key

```
order_id
```

---

## 5. `raw_order_items`

### Grain

**One row per item sequence within an order.**

The unique row identifier is therefore:

```
(order_id, order_item_id)
```

### Columns

| Column | Type | Constraint | Meaning |
| --------------------------- | --------------- | ------------------- | --------------------------------- |
| `order_id`                  | `VARCHAR(50)`   | `NOT NULL`, PK part | Order containing item             |
| `order_item_id`             | `INT`           | `NOT NULL`, PK part | Item sequence number within order |
| `product_id`                | `VARCHAR(50)`   | `NOT NULL`          | Product sold                      |
| `seller_id`                 | `VARCHAR(50)`   | `NOT NULL`          | Seller fulfilling item            |
| `shipping_limit_date`       | `DATETIME`      | nullable            | Seller's shipping deadline        |
| `price`                     | `DECIMAL(12,2)` | nullable            | Item selling price                |
| `freight_value`             | `DECIMAL(12,2)` | nullable            | Freight/shipping value            |

### Primary key

```
(order_id, order_item_id)
```

`order_item_id` by itself is **not globally unique**.

---

## 6. `raw_sellers`

### Grain

**One row per seller.**

### Columns

| Column | Type | Constraint | Meaning |
| --------------------------- | -------------- | -------------- | ---------------------------- |
| `seller_id`                 | `VARCHAR(50)`  | `NOT NULL`, PK | Seller identifier            |
| `seller_zip_code_prefix`    | `VARCHAR(20)`  | nullable       | Seller ZIP-code prefix       |
| `seller_city`               | `VARCHAR(255)` | nullable       | Seller city                  |
| `seller_state`              | `CHAR(2)`      | nullable       | Brazilian state abbreviation |

### Primary key

```
seller_id
```

---

## 7. `raw_customers`

### Grain

**One row per `customer_id`.**

An important Olist-specific distinction exists between:

```
customer_id
```

and:

```
customer_unique_id
```

`customer_id` is tied to the order/customer record.

`customer_unique_id` represents the underlying customer and can appear across multiple orders.

### Columns

| Column | Type | Constraint | Meaning |
| --------------------------- | -------------- | -------------- | --------------------------------------- |
| `customer_id`               | `VARCHAR(50)`  | `NOT NULL`, PK | Order-specific customer ID              |
| `customer_unique_id`        | `VARCHAR(50)`  | nullable       | Persistent underlying customer identity |
| `customer_zip_code_prefix`  | `VARCHAR(20)`  | nullable       | Customer ZIP-code prefix                |
| `customer_city`             | `VARCHAR(255)` | nullable       | Customer city                           |
| `customer_state`            | `CHAR(2)`      | nullable       | Customer state                          |

### Primary key

```
customer_id
```

Do **not** use `customer_id` when the analytical question is specifically about unique human/customers across repeat orders. Use:

```
customer_unique_id
```

for that purpose.

---

## 8. `raw_products`

### Grain

**One row per product.**

### Columns

| Column | Type | Constraint | Meaning |
| ---------------------------- | -------------- | -------------- | ------------------------------------ |
| `product_id`                 | `VARCHAR(50)`  | `NOT NULL`, PK | Product identifier                   |
| `product_category_name`      | `VARCHAR(255)` | nullable       | Original Portuguese product category |
| `product_name_lenght`        | `INT`          | nullable       | Source product-name length           |
| `product_description_lenght` | `INT`          | nullable       | Source description length            |
| `product_photos_qty`         | `INT`          | nullable       | Number of product photos             |
| `product_weight_g`           | `INT`          | nullable       | Product weight in grams              |
| `product_length_cm`          | `INT`          | nullable       | Product length in centimeters        |
| `product_height_cm`          | `INT`          | nullable       | Product height in centimeters        |
| `product_width_cm`           | `INT`          | nullable       | Product width in centimeters         |

### Primary key

```
product_id
```

### Important spelling issue

The Olist source uses the misspelling:

```
lenght
```

not:

```
length
```

Therefore the actual database columns are:

```
product_name_lenght
product_description_lenght
```

An AI generating SQL must use those exact spellings.

---

## 9. `raw_payments`

### Grain

**One payment record/sequence within an order.**

An order can have multiple payment records.

### Columns

| Column | Type | Constraint | Meaning |
| --------------------------- | --------------- | ------------------- | ----------------------------- |
| `order_id`                  | `VARCHAR(50)`   | `NOT NULL`, PK part | Order identifier              |
| `payment_sequential`        | `INT`           | `NOT NULL`, PK part | Payment sequence within order |
| `payment_type`              | `VARCHAR(50)`   | nullable            | Payment method/type           |
| `payment_installments`      | `INT`           | nullable            | Number of installments        |
| `payment_value`             | `DECIMAL(12,2)` | nullable            | Payment amount                |

### Primary key

```
(order_id, payment_sequential)
```

Do not assume one payment row per order.

Verified:

```
103,886 payment rows
99,440 distinct order_ids
```

---

## 10. `raw_reviews`

### Grain

**One source review record.**

Do not assume that either `review_id` or `order_id` is unique.

### Columns

| Column | Type | Constraint | Meaning |
| --------------------------- | ------------- | -------- | -------------------------------- |
| `review_id`                 | `VARCHAR(50)` | nullable | Review identifier                |
| `order_id`                  | `VARCHAR(50)` | nullable | Reviewed order                   |
| `review_score`              | `INT`         | nullable | Numeric review score             |
| `review_comment_title`      | `TEXT`        | nullable | Review title                     |
| `review_comment_message`    | `TEXT`        | nullable | Review free-text body            |
| `review_creation_date`      | `DATETIME`    | nullable | Review creation date             |
| `review_answer_timestamp`   | `DATETIME`    | nullable | Review response/answer timestamp |

### Primary key

**NONE**

This was deliberate.

Verified:

```
99,224 total rows
98,410 distinct review_id values
98,673 distinct order_id values
```

Therefore:

```
review_id is NOT unique in the raw data.
order_id is NOT unique in the raw data.
```

An AI must not assume one review per order.

---

## 11. `raw_category_translation`

### Grain

**One source category-translation row.**

### Columns

| Column | Type | Constraint | Meaning |
| ------------------------------- | -------------- | -------- | ------------------------ |
| `product_category_name`         | `VARCHAR(255)` | nullable | Portuguese category name |
| `product_category_name_english` | `VARCHAR(255)` | nullable | English translation      |

### Primary key

**NONE**

No unique constraint was created.

Intended relationship:

```
raw_products.product_category_name
    =
raw_category_translation.product_category_name
```

The loaded table has:

```
71 rows
```

---

## 12. `raw_geolocation`

### Grain

**One geolocation observation, not one ZIP code.**

Multiple rows exist for the same ZIP-code prefix.

Verified:

```
1,000,163 rows
19,015 distinct ZIP-code prefixes
```

Therefore direct joins against this table can multiply rows severely.

### Columns

| Column | Type | Constraint | Meaning |
| ----------------------------- | -------------- | -------- | --------------- |
| `geolocation_zip_code_prefix` | `VARCHAR(20)`  | nullable | ZIP-code prefix |
| `geolocation_lat`             | `DOUBLE`       | nullable | Latitude        |
| `geolocation_lng`             | `DOUBLE`       | nullable | Longitude       |
| `geolocation_city`            | `VARCHAR(255)` | nullable | City            |
| `geolocation_state`           | `CHAR(2)`      | nullable | State           |

### Primary key

**NONE**

The latitude/longitude fields were originally defined as:

```
DECIMAL(10,7)
```

then:

```
DECIMAL(20,17)
```

Both produced precision/truncation warnings.

The final schema was changed to:

```
DOUBLE
```

for both latitude and longitude.

---

## 13. Physical constraints actually created

## Primary keys

These are the only primary keys explicitly created:

```
raw_orders
    PRIMARY KEY (order_id)

raw_order_items
    PRIMARY KEY (order_id, order_item_id)

raw_sellers
    PRIMARY KEY (seller_id)

raw_customers
    PRIMARY KEY (customer_id)

raw_products
    PRIMARY KEY (product_id)

raw_payments
    PRIMARY KEY (order_id, payment_sequential)
```

No primary keys were created on:

```
raw_reviews
raw_category_translation
raw_geolocation
```

## Foreign keys

**No SQL** **`FOREIGN KEY`** **constraints were created.**

All cross-table relationships described below are **logical relationships based on the source model**, not database-enforced referential constraints.

## Unique constraints

No additional explicit `UNIQUE` constraints were created.

Primary keys are inherently unique.

## Indexes

No secondary indexes were explicitly created.

MySQL automatically creates indexes supporting the primary keys.

Therefore, for example:

```
raw_order_items.seller_id
raw_order_items.product_id
raw_orders.customer_id
```

do **not** currently have explicitly created secondary indexes from our database-building work.

If query performance later requires indexes, they should be added deliberately.

---

## 14. Logical foreign-key relationships and join keys

Although foreign-key constraints were not physically created, these are the intended relationships.

| Parent / dimension | Child / fact | Join |
| ---------------------------------- | ----------------- | ------------------------------------------------------------------------------------- |
| `raw_orders`                       | `raw_order_items` | `raw_orders.order_id = raw_order_items.order_id`                                      |
| `raw_orders`                       | `raw_payments`    | `raw_orders.order_id = raw_payments.order_id`                                         |
| `raw_orders`                       | `raw_reviews`     | `raw_orders.order_id = raw_reviews.order_id`                                          |
| `raw_customers`                    | `raw_orders`      | `raw_customers.customer_id = raw_orders.customer_id`                                  |
| `raw_sellers`                      | `raw_order_items` | `raw_sellers.seller_id = raw_order_items.seller_id`                                   |
| `raw_products`                     | `raw_order_items` | `raw_products.product_id = raw_order_items.product_id`                                |
| `raw_category_translation`         | `raw_products`    | `raw_category_translation.product_category_name = raw_products.product_category_name` |
| `raw_geolocation`                  | `raw_customers`   | ZIP-prefix relationship                                                               |
| `raw_geolocation`                  | `raw_sellers`     | ZIP-prefix relationship                                                               |

### Exact geolocation join fields

Customer:

```
raw_customers.customer_zip_code_prefix
    =
raw_geolocation.geolocation_zip_code_prefix
```

Seller:

```
raw_sellers.seller_zip_code_prefix
    =
raw_geolocation.geolocation_zip_code_prefix
```

However, **do not directly join raw geolocation to customers or sellers unless row multiplication is intended**.

There are:

```
1,000,163 geolocation rows
19,015 distinct ZIP prefixes
```

so each ZIP prefix can have many geolocation observations.

For most analytical purposes, first create one geolocation row per ZIP prefix, for example through aggregation or another explicit deduplication rule.

---

## 15. Relationship cardinalities

## Orders → order items

```
raw_orders
    1
    ↓
    0..many
raw_order_items
```

One order can contain multiple item rows.

Verified:

```
112,650 item rows
98,666 distinct order IDs in order_items
```

Do not assume every order appears in `raw_order_items` without verifying.

---

## Order → payment

```
raw_orders
    1
    ↓
    0..many
raw_payments
```

An order can contain multiple payment records.

Verified:

```
103,886 payment rows
99,440 distinct order IDs
```

---

## Order → review

```
raw_orders
    1
    ↓
    0..many
raw_reviews
```

Do not assume exactly one review per order.

Verified:

```
99,224 review rows
98,673 distinct order IDs
```

---

## Product → order items

```
raw_products
    1
    ↓
    many
raw_order_items
```

A product may appear in many order-item rows.

---

## Seller → order items

```
raw_sellers
    1
    ↓
    many
raw_order_items
```

A seller may fulfill many item rows.

---

## Customer ID → order

`customer_id` is an order-specific Olist customer identifier.

At the technical `customer_id` level, the expected Olist relationship is effectively one customer-record row associated with an order.

For repeat-customer analysis, use:

```
customer_unique_id
```

A single:

```
customer_unique_id
```

can correspond to multiple `customer_id` values and therefore multiple orders.

---

## Product → category translation

Many products can share a single product category.

Logical join:

```
raw_products.product_category_name
=
raw_category_translation.product_category_name
```

No uniqueness constraint is enforced on the translation table.

---

## 16. Important identifiers

### `order_id`

Primary identifier for an order.

Used across:

```
raw_orders
raw_order_items
raw_payments
raw_reviews
```

---

### `order_item_id`

Sequence of an item **inside an order**.

Not globally unique.

Use:

```
(order_id, order_item_id)
```

as the full item-row identifier.

---

### `customer_id`

Order-specific customer record identifier.

Primary key of:

```
raw_customers
```

Join to:

```
raw_orders.customer_id
```

---

### `customer_unique_id`

Persistent customer identity used to recognize repeat customers.

Not the primary key.

Use this when asking questions such as:

```
How many unique customers?
How many customers purchased more than once?
Customer-level repeat behavior?
```

---

### `product_id`

Primary product identifier.

Join:

```
raw_order_items.product_id
→ raw_products.product_id
```

---

### `seller_id`

Primary seller identifier.

Join:

```
raw_order_items.seller_id
→ raw_sellers.seller_id
```

---

### `payment_sequential`

Payment sequence within one order.

Only unique in combination with:

```
order_id
```

---

### `review_id`

Review identifier, but **not unique in this raw data**.

Do not use it by itself as a guaranteed primary key.

---

## 17. Date and time fields

## Orders

```
order_purchase_timestamp
```

When the customer placed the order.

```
order_approved_at
```

When the order/payment was approved.

```
order_delivered_carrier_date
```

When the order was delivered/transferred to the carrier.

```
order_delivered_customer_date
```

Actual delivery to customer.

```
order_estimated_delivery_date
```

Promised/estimated delivery date.

These fields are useful for metrics such as:

```
approval lag
seller/carrier processing time
delivery duration
on-time delivery
late delivery
estimated-vs-actual delivery
```

---

## Order items

```
shipping_limit_date
```

Seller's shipping deadline for that item/order.

---

## Reviews

```
review_creation_date
review_answer_timestamp
```

Review lifecycle timestamps.

---

## 18. Important numeric measures

## Revenue / transactional measures

```
raw_order_items.price
    DECIMAL(12,2)
```

Product/item selling price.

```
raw_order_items.freight_value
    DECIMAL(12,2)
```

Freight value associated with item.

```
raw_payments.payment_value
    DECIMAL(12,2)
```

Payment amount.

Do not blindly sum `payment_value` after joining it directly to `raw_order_items`, because both tables can contain multiple rows per order. Such a join can multiply payment amounts.

This is one of the most important grain issues another AI must understand.

---

## Payment measures

```
payment_installments INT
payment_sequential INT
```

---

## Review measure

```
review_score INT
```

---

## Product measures

```
product_photos_qty
product_weight_g
product_length_cm
product_height_cm
product_width_cm
```

---

## Geolocation measures

```
geolocation_lat DOUBLE
geolocation_lng DOUBLE
```

---

## 19. Important categorical fields

Frequently useful dimensions include:

```
raw_orders.order_status

raw_sellers.seller_city
raw_sellers.seller_state

raw_customers.customer_city
raw_customers.customer_state

raw_products.product_category_name

raw_category_translation.product_category_name_english

raw_payments.payment_type

raw_reviews.review_score
```

---

## 20. Source files and table mappings

| Original source | Database target |
| --------------------------------------- | -------------------------- |
| `olist_orders_dataset.csv`              | `raw_orders`               |
| `olist_order_items_dataset.csv`         | `raw_order_items`          |
| `olist_sellers_dataset.csv`             | `raw_sellers`              |
| `olist_customers_dataset.csv`           | `raw_customers`            |
| `olist_products_dataset.csv`            | `raw_products`             |
| `olist_order_payments_dataset.csv`      | `raw_payments`             |
| `olist_order_reviews_dataset.csv`       | `raw_reviews`              |
| `product_category_name_translation.csv` | `raw_category_translation` |
| `olist_geolocation_dataset.csv`         | `raw_geolocation`          |

The raw files were stored locally under:

```
C:/Users/Mark/Documents/fulfilliq/data_raw/
```

The reviews file additionally required a staging file:

```
C:/Users/Mark/Documents/fulfilliq/data_stage/olist_order_reviews_clean.tsv
```

---

## 21. Important import decisions and transformations

## Blank timestamps

The initial Workbench import of `raw_orders` failed because missing dates appeared in CSV as empty strings:

```
''
```

MySQL would not accept those as valid `DATETIME` values.

We therefore used expressions such as:

```
NULLIF(@value, '')
```

and:

```
STR_TO_DATE(
    NULLIF(@value, ''),
    '%Y-%m-%d %H:%i:%s'
)
```

Thus missing source timestamps were loaded as genuine SQL:

```
NULL
```

rather than empty strings.

---

## Bulk loading

Workbench's graphical import wizard was too slow/inflexible for much of the dataset.

We enabled:

```
local_infile = ON
```

on the MySQL server and configured the Workbench project connection with:

```
OPT_LOCAL_INFILE=1
```

We then used:

```
LOAD DATA LOCAL INFILE
```

for bulk loading.

### Persistence warning

`local_infile` was enabled with:

```
SET GLOBAL local_infile = ON;
```

That runtime setting may not survive a MySQL service restart unless it was separately persisted in server configuration.

To check:

```
SHOW GLOBAL VARIABLES LIKE 'local_infile';
```

This matters for future imports, but not normal `SELECT` queries.

---

## 22. Review-file data issue and staging transformation

`olist_order_reviews_dataset.csv` contained free-form review text with formatting that caused the simple MySQL import to misparse at least one row.

Initial symptoms included:

```
99,223 rows instead of 99,224
incorrect datetime warnings
row truncation
```

The Workbench wizard performed worse and loaded only:

```
279 rows
```

We therefore used **MySQL Shell Python mode** with Python's proper CSV parser.

The transformation:

-  parsed quoted CSV fields properly; 
-  replaced embedded carriage returns with spaces; 
-  replaced embedded newlines with spaces; 
-  replaced tabs with spaces; 
-  stripped surrounding whitespace; 
-  preserved the original CSV; 
-  created a clean tab-separated staging file. 

The staging process produced exactly:

```
99,224 rows
```

The cleaned TSV was then loaded into:

```
raw_reviews
```

### Consequence

`raw_reviews.review_comment_title` and `raw_reviews.review_comment_message` preserve the textual content, but their original embedded newlines/tabs were normalized to spaces.

Therefore this table is **analytically faithful but not byte-for-byte identical to the source review text formatting**.

---

## 23. Geolocation precision issue

Initial latitude/longitude definitions were:

```
DECIMAL(10,7)
```

This produced MySQL `1265 Data truncated` warnings.

We tried:

```
DECIMAL(20,17)
```

and still received truncation warnings.

The final schema was changed to:

```
geolocation_lat DOUBLE,
geolocation_lng DOUBLE
```

and the table was reloaded.

Final verified row counts:

```
1,000,163 total rows
19,015 distinct ZIP prefixes
```

The final screenshot did **not explicitly capture a post-import** **`SHOW WARNINGS`** **result after the** **`DOUBLE`** **conversion**.

Therefore:

**Final zero-warning status: UNKNOWN / NEEDS VERIFICATION**

The final data type and row count are confirmed.

---

## 24. Known data limitations

### Reviews contain duplicate identifiers

Verified:

```
99,224 rows
98,410 distinct review_id
98,673 distinct order_id
```

Do not assume:

```
review_id = unique row
```

and do not assume:

```
one order = one review
```

---

### Geolocation is not unique by ZIP prefix

Verified:

```
1,000,163 rows
19,015 distinct ZIP prefixes
```

Directly joining geolocation to customers/sellers will generally multiply rows.

---

### Different fact tables have different grains

For example:

```
raw_orders         → one row/order
raw_order_items    → many rows/order
raw_payments       → potentially many rows/order
raw_reviews        → potentially many rows/order
```

Therefore this is unsafe without controlling grain:

```
orders
JOIN order_items
JOIN payments
JOIN reviews
```

because item × payment × review combinations can multiply rows and inflate:

```
revenue
payment totals
counts
averages
```

Aggregate each many-side table to the required grain before combining when necessary.

---

### Missing values exist

Missing timestamps and other blank CSV values were intentionally loaded as:

```
NULL
```

Queries should therefore handle nullable fields appropriately.

---

### Raw category names are Portuguese

Use:

```
raw_category_translation
```

when English category names are required.

---

### No physical foreign keys

Cross-table integrity is not enforced by MySQL.

Logical relationships exist, but the database will not prevent orphan records.

---

### Referential-integrity/orphan QA

We prepared orphan-check queries during the build, but their final results were **not shown in this conversation**.

Therefore the statement:

> every child key has a matching parent

is **UNKNOWN / NEEDS VERIFICATION**.

Use the verification queries later in this package.

---

## 25. Current database state

Confirmed:

-  MySQL Server 8.0.46 installed. 
-  MySQL Workbench 8.0.47 installed. 
- `fulfilliq` database exists. 
- `fulfilliq_user` exists and successfully connects. 
-  All nine raw tables exist. 
-  All nine raw tables were populated. 
-  Consolidated row-count QA succeeded. 
- `raw_orders` has 99,441 rows. 
- `raw_order_items` has 112,650 rows. 
- `raw_sellers` has 3,095 rows. 
- `raw_customers` has 99,441 rows. 
- `raw_products` has 32,951 rows. 
- `raw_payments` has 103,886 rows. 
- `raw_reviews` has 99,224 rows. 
- `raw_category_translation` has 71 rows. 
- `raw_geolocation` has 1,000,163 rows. 

No analytical marts such as:

```
mart_seller_order
mart_seller_day
```

have been created yet.

Those should be created only when the project/business question requires them.

---

## 26. Useful verification SQL

## Server version

```
SELECT VERSION();
```

## Current database

```
SELECT DATABASE();
```

If needed:

```
USE fulfilliq;
```

---

## Database definition

```
SHOW CREATE DATABASE fulfilliq;
```

---

## Tables

```
USE fulfilliq;

SHOW TABLES;
```

---

## Column definitions

For one table:

```
DESCRIBE raw_orders;
```

For exact DDL:

```
SHOW CREATE TABLE raw_orders;
```

Repeat for any table.

---

## All columns at once

```
SELECT
    table_name,
    ordinal_position,
    column_name,
    column_type,
    is_nullable,
    column_key,
    column_default,
    extra
FROM information_schema.columns
WHERE table_schema = 'fulfilliq'
ORDER BY table_name, ordinal_position;
```

---

## Primary keys / constraints

```
SELECT
    table_name,
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'fulfilliq'
ORDER BY table_name, constraint_type;
```

---

## Key columns

```
SELECT
    table_name,
    constraint_name,
    column_name,
    ordinal_position,
    referenced_table_name,
    referenced_column_name
FROM information_schema.key_column_usage
WHERE table_schema = 'fulfilliq'
ORDER BY table_name, constraint_name, ordinal_position;
```

Because we did not create foreign keys, `referenced_table_name` should not show the logical relationships documented above unless the schema has subsequently been modified.

---

## Indexes

```
SELECT
    table_name,
    index_name,
    non_unique,
    seq_in_index,
    column_name
FROM information_schema.statistics
WHERE table_schema = 'fulfilliq'
ORDER BY table_name, index_name, seq_in_index;
```

Or individually:

```
SHOW INDEX FROM raw_order_items;
```

---

## Row counts

```
SELECT 'raw_orders' AS table_name, COUNT(*) AS rows_n
FROM raw_orders

UNION ALL
SELECT 'raw_order_items', COUNT(*) FROM raw_order_items

UNION ALL
SELECT 'raw_sellers', COUNT(*) FROM raw_sellers

UNION ALL
SELECT 'raw_customers', COUNT(*) FROM raw_customers

UNION ALL
SELECT 'raw_products', COUNT(*) FROM raw_products

UNION ALL
SELECT 'raw_payments', COUNT(*) FROM raw_payments

UNION ALL
SELECT 'raw_reviews', COUNT(*) FROM raw_reviews

UNION ALL
SELECT 'raw_category_translation', COUNT(*) FROM raw_category_translation

UNION ALL
SELECT 'raw_geolocation', COUNT(*) FROM raw_geolocation;
```

---

## Logical referential-integrity checks

### Order items with no order

```
SELECT COUNT(*) AS orphan_rows
FROM raw_order_items oi
LEFT JOIN raw_orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;
```

### Items with no seller

```
SELECT COUNT(*) AS orphan_rows
FROM raw_order_items oi
LEFT JOIN raw_sellers s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;
```

### Items with no product

```
SELECT COUNT(*) AS orphan_rows
FROM raw_order_items oi
LEFT JOIN raw_products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;
```

### Orders with no customer record

```
SELECT COUNT(*) AS orphan_rows
FROM raw_orders o
LEFT JOIN raw_customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
```

### Payments referencing unknown orders

```
SELECT COUNT(*) AS orphan_rows
FROM raw_payments p
LEFT JOIN raw_orders o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL;
```

### Reviews referencing unknown orders

```
SELECT COUNT(*) AS orphan_rows
FROM raw_reviews r
LEFT JOIN raw_orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;
```

---

# AI SQL Query Context

The section below is the part to paste into another AI before giving it a business question.

```
DATABASE CONTEXT — FULFILLIQ

DATABASE ENGINE
MySQL Community Server 8.0.46
MySQL dialect: MySQL 8.0
Environment: local Windows MySQL Server
Host: localhost
Port: 3306
Database/schema: fulfilliq
Character set: utf8mb4
Collation: utf8mb4_0900_ai_ci

Do not generate PostgreSQL, SQL Server, SQLite, Oracle, or BigQuery syntax.
Use MySQL 8.0 syntax.

CURRENT DATABASE LAYER
Only raw Olist tables currently exist for analysis.
No mart_seller_order or mart_seller_day analytical marts have yet been created.

--------------------------------------------------
TABLE: raw_orders
GRAIN: one row per order_id

order_id VARCHAR(50) NOT NULL PRIMARY KEY
customer_id VARCHAR(50) NOT NULL
order_status VARCHAR(30)
order_purchase_timestamp DATETIME
order_approved_at DATETIME
order_delivered_carrier_date DATETIME
order_delivered_customer_date DATETIME
order_estimated_delivery_date DATETIME

Verified rows: 99,441

--------------------------------------------------
TABLE: raw_order_items
GRAIN: one item sequence within an order

order_id VARCHAR(50) NOT NULL
order_item_id INT NOT NULL
product_id VARCHAR(50) NOT NULL
seller_id VARCHAR(50) NOT NULL
shipping_limit_date DATETIME
price DECIMAL(12,2)
freight_value DECIMAL(12,2)

PRIMARY KEY (order_id, order_item_id)

Verified rows: 112,650
Verified distinct order_id: 98,666

order_item_id is only unique within an order.

--------------------------------------------------
TABLE: raw_sellers
GRAIN: one row per seller

seller_id VARCHAR(50) NOT NULL PRIMARY KEY
seller_zip_code_prefix VARCHAR(20)
seller_city VARCHAR(255)
seller_state CHAR(2)

Verified rows: 3,095

--------------------------------------------------
TABLE: raw_customers
GRAIN: one row per customer_id

customer_id VARCHAR(50) NOT NULL PRIMARY KEY
customer_unique_id VARCHAR(50)
customer_zip_code_prefix VARCHAR(20)
customer_city VARCHAR(255)
customer_state CHAR(2)

Verified rows: 99,441

IMPORTANT:
customer_id is the order-specific Olist customer identifier.
customer_unique_id represents the underlying persistent customer.
Use customer_unique_id for repeat-customer/person-level analysis.

--------------------------------------------------
TABLE: raw_products
GRAIN: one row per product

product_id VARCHAR(50) NOT NULL PRIMARY KEY
product_category_name VARCHAR(255)
product_name_lenght INT
product_description_lenght INT
product_photos_qty INT
product_weight_g INT
product_length_cm INT
product_height_cm INT
product_width_cm INT

Verified rows: 32,951

IMPORTANT:
The actual source/database spelling is:
product_name_lenght
product_description_lenght

Do NOT change "lenght" to "length" in SQL.

--------------------------------------------------
TABLE: raw_payments
GRAIN: one payment sequence within an order

order_id VARCHAR(50) NOT NULL
payment_sequential INT NOT NULL
payment_type VARCHAR(50)
payment_installments INT
payment_value DECIMAL(12,2)

PRIMARY KEY (order_id, payment_sequential)

Verified rows: 103,886
Verified distinct order_id: 99,440

An order may have multiple payment rows.

--------------------------------------------------
TABLE: raw_reviews
GRAIN: one source review record

review_id VARCHAR(50)
order_id VARCHAR(50)
review_score INT
review_comment_title TEXT
review_comment_message TEXT
review_creation_date DATETIME
review_answer_timestamp DATETIME

NO PRIMARY KEY.

Verified:
99,224 rows
98,410 distinct review_id
98,673 distinct order_id

Do NOT assume review_id is unique.
Do NOT assume one review per order.

Review free-text line breaks/tabs were normalized to spaces during staging.

--------------------------------------------------
TABLE: raw_category_translation
GRAIN: one category-translation source row

product_category_name VARCHAR(255)
product_category_name_english VARCHAR(255)

NO PRIMARY KEY.

Verified rows: 71

Join to products using:
raw_products.product_category_name =
raw_category_translation.product_category_name

--------------------------------------------------
TABLE: raw_geolocation
GRAIN: one geolocation observation, NOT one ZIP prefix

geolocation_zip_code_prefix VARCHAR(20)
geolocation_lat DOUBLE
geolocation_lng DOUBLE
geolocation_city VARCHAR(255)
geolocation_state CHAR(2)

NO PRIMARY KEY.

Verified:
1,000,163 rows
19,015 distinct geolocation_zip_code_prefix values

IMPORTANT:
There are many geolocation rows per ZIP prefix.
Do NOT directly join raw_geolocation to customers or sellers unless row multiplication is intended.
Normally aggregate/deduplicate raw_geolocation to one row per ZIP prefix first.

--------------------------------------------------
LOGICAL JOIN PATHS

Orders → Order Items
raw_orders.order_id =
raw_order_items.order_id
Relationship: one order to zero/many item rows

Orders → Customers
raw_orders.customer_id =
raw_customers.customer_id

Order Items → Sellers
raw_order_items.seller_id =
raw_sellers.seller_id
Relationship: many item rows to one seller

Order Items → Products
raw_order_items.product_id =
raw_products.product_id
Relationship: many item rows to one product

Orders → Payments
raw_orders.order_id =
raw_payments.order_id
Relationship: one order to zero/many payment rows

Orders → Reviews
raw_orders.order_id =
raw_reviews.order_id
Relationship: one order to zero/many review rows

Products → Category Translation
raw_products.product_category_name =
raw_category_translation.product_category_name

Customers → Geolocation
raw_customers.customer_zip_code_prefix =
raw_geolocation.geolocation_zip_code_prefix

Sellers → Geolocation
raw_sellers.seller_zip_code_prefix =
raw_geolocation.geolocation_zip_code_prefix

Geolocation must normally be reduced to one row per ZIP prefix before joining.

--------------------------------------------------
PHYSICAL CONSTRAINTS

Primary keys exist only on:

raw_orders(order_id)
raw_order_items(order_id, order_item_id)
raw_sellers(seller_id)
raw_customers(customer_id)
raw_products(product_id)
raw_payments(order_id, payment_sequential)

There are NO database-enforced FOREIGN KEY constraints.

There are NO additional explicitly created UNIQUE constraints.

There are NO explicitly created secondary indexes beyond indexes created automatically for primary keys.

--------------------------------------------------
IMPORTANT ANALYTICAL GRAIN WARNING

raw_orders is order grain.
raw_order_items is item grain.
raw_payments can contain multiple rows per order.
raw_reviews can contain multiple rows per order.
raw_geolocation contains many rows per ZIP prefix.

Never blindly join all of these many-side tables and then SUM price, freight_value, or payment_value.

Doing so may produce row multiplication and inflated metrics.

Aggregate each many-side table to the required analytical grain before combining it when necessary.

--------------------------------------------------
IMPORTANT FIELD MEANINGS

Order lifecycle:
order_purchase_timestamp = order placed
order_approved_at = approved
order_delivered_carrier_date = passed to carrier
order_delivered_customer_date = actual delivery
order_estimated_delivery_date = promised/estimated delivery

Order item:
shipping_limit_date = seller shipping deadline
price = item selling price
freight_value = freight value

Payment:
payment_type = payment method
payment_installments = installment count
payment_value = payment amount

Review:
review_score = review score

Product category:
product_category_name = Portuguese source category
product_category_name_english = English translation

Customer:
customer_id = order-specific customer record
customer_unique_id = persistent underlying customer identity

--------------------------------------------------
NULL / IMPORT BEHAVIOR

Missing CSV values, including missing DATETIME values, were converted to SQL NULL.

Use normal SQL NULL handling:
IS NULL
IS NOT NULL
COALESCE(...)
etc.

--------------------------------------------------
QUERY REQUIREMENT

Before generating SQL:

1. Determine the requested analytical grain.
2. Identify the relevant tables.
3. Respect one-to-many relationships.
4. Prevent row multiplication.
5. Use exact table and column names above.
6. Use MySQL 8.0 syntax.
7. Do not invent tables, columns, foreign keys, or marts that are not listed.
8. If the business question requires a definition that is ambiguous, state the assumption or ask for clarification before generating the final query.
```

That final block is now suitable to keep as the **standard database context preamble** for future FulfillIQ SQL requests. It gives another AI the physical schema, grains, join paths, actual MySQL dialect, known quirks, and—most importantly—the cardinality warnings needed to avoid producing SQL that runs but calculates the wrong answer.