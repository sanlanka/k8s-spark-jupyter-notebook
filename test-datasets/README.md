# Test datasets

## `retail_sales.csv`

1000 retail order lines (Jan 2024 – Jun 2025), internally consistent so joins
and aggregations produce sensible results. Deterministic (seeded).

| Column           | Type    | Notes |
|------------------|---------|-------|
| `order_id`       | string  | Unique, `ORD-1000xx` |
| `order_date`     | date    | `YYYY-MM-DD`, sorted ascending |
| `customer_id`    | string  | 200 distinct customers → repeats across orders (good for joins/`groupBy`) |
| `customer_name`  | string  | Stable per `customer_id` |
| `region`         | string  | North/South/East/West — a property of the customer |
| `category`       | string  | Electronics, Home & Kitchen, Office, Sports, Books |
| `product`        | string  | Always belongs to its `category` |
| `quantity`       | int     | 1–10 |
| `unit_price`     | double  | Per-order price (jittered around a product base price) |
| `discount_pct`   | double  | 0.00–0.20 (mostly 0) |
| `total_amount`   | double  | `quantity * unit_price * (1 - discount_pct)` |
| `payment_method` | string  | Credit Card / Debit Card / PayPal / Cash |
| `is_returned`    | boolean | `true`/`false`; correlates slightly with discount |

### Load it in PySpark

```python
df = (spark.read
      .option("header", True)
      .option("inferSchema", True)
      .csv("retail_sales.csv"))     # or an absolute path inside the pod

# Revenue by region and category
(df.filter(~df.is_returned)
   .groupBy("region", "category")
   .sum("total_amount")
   .orderBy("region", "category")
   .show())
```
