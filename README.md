# Chinook Digital Music Store — Business Performance Analysis

## Introduction

This project applies SQL to perform an end-to-end business performance analysis of the Chinook digital music store database. It was developed as part of a career transition into data analytics, with the goal of demonstrating proficiency in SQL across a range of complexity levels — from basic aggregations to window functions, CTEs, and self joins.

### Dataset

The Chinook database is a widely used open-source sample database modelling a digital music store, loosely inspired by the iTunes library structure. It contains 11 relational tables covering the full business domain: customers, employees, invoices, invoice lines, tracks, albums, artists, genres, media types, playlists, and playlist tracks. The dataset spans sales data across multiple years and geographies, making it well suited for time series analysis, customer segmentation, and product performance evaluation.

### Tools Used

- **Database:** MySQL
- **Query Interface:** MySQL Workbench
- **Dataset:** [Chinook Database](https://github.com/lerocha/chinook-database)

### Technical Skills Demonstrated

- Multi-table JOINs including self joins
- Aggregations with `GROUP BY` and `HAVING`
- Common Table Expressions (CTEs) for multi-step logic
- Window functions: `RANK()`, `SUM() OVER()`, `LAG()`
- Conditional aggregation with `CASE WHEN` inside `AVG()` and `SUM()`
- Date formatting and time series analysis
- Data quality investigation and limitation documentation

### A Note on the Dataset

Where the Chinook data revealed limitations — such as uniform purchase frequency across customers, or incomplete data for the earliest year — these are documented alongside the relevant queries. Identifying and contextualising data quality issues is treated as part of the analytical process, not an obstacle to it.

---

## Project Structure

```
chinook-analysis/
│
├── README.md                  ← this file
├── chinook_analysis.sql       ← all queries
│
└── results/                   ← screenshots of key query outputs
```

The analysis is organised into four business themes, each addressing a distinct area of the business.

---

## 1. Revenue Analysis

*How is the business performing over time, and where geographically is revenue concentrated?*

| Query | Key Technique |
|---|---|
| Monthly revenue trend over time | `DATE_FORMAT`, `GROUP BY` |
| Cumulative revenue over time | `SUM() OVER(ORDER BY)` |
| Month-over-month revenue growth | `LAG()` window function |
| Best month for sales per year | `RANK() OVER(PARTITION BY)`, multiple CTEs |
| Average order value per country | `AVG`, `JOIN` |
| Revenue by city and country | `GROUP BY` multiple columns |

**Key Findings:**

- Revenue is distributed across multiple geographies with the USA leading by total volume, but **Prague is the single highest-revenue city**, suggesting a concentration of high-value customers in one market rather than broad geographic distribution.
- **2021 appears to be an incomplete year** in the dataset, with near-uniform monthly revenue across all months. This likely represents the store's launch period. A clear seasonal pattern emerges from 2022 onwards.
- Month-over-month analysis reveals significant variance in growth rates, with some months showing sharp increases followed by corrections — consistent with a small customer base where individual large orders can skew monthly totals.

---

## 2. Customer Analysis

*Who are the customers, how do they behave, and which are at risk of churning?*

| Query | Key Technique |
|---|---|
| Customer segmentation by spending (High / Medium / Low) | `CASE WHEN`, CTE |
| Rank customers within each country by spending | `RANK() OVER(PARTITION BY)` |
| Most loyal customers by purchase frequency vs spending | Dual `RANK()` window functions |
| Customers with only a single purchase (churn risk) | `HAVING COUNT() = 1` |
| Customers by genre diversity (breadth of taste) | `COUNT(DISTINCT)`, CTE with `DISTINCT` |

**Key Findings:**

- Prior to segmentation, a statistical description of spending was run (`MIN`, `MAX`, `AVG`, `STDDEV`). Spending ranged from **$36.64 to $49.62 with low variance (std dev = $2.89)**, making standard deviation-based thresholds impractical — one standard deviation below the mean fell outside the actual data range. Thresholds were set empirically based on the observed distribution instead.
- Purchase frequency analysis revealed that **most customers have exactly 7 purchases**, making frequency-based loyalty ranking uninformative in this dataset. In a real-world dataset with greater variance, the dual-ranking approach (frequency vs spending) would be a powerful segmentation tool.
- Genre diversity analysis identifies customers with the broadest taste across genres — a useful signal for personalised recommendation strategies.

---

## 3. Product & Catalog Analysis

*What sells, what doesn't, and how efficiently is the catalog performing?*

| Query | Key Technique |
|---|---|
| Top 10 best-selling artists by revenue | Multi-table `JOIN`, `GROUP BY` |
| Each genre's percentage share of total revenue | `SUM() OVER()` for percentage calculation |
| Artist catalog efficiency (revenue per track) | CTE, `AVG`, `HAVING` filter |
| Album with most unique tracks purchased vs most total purchases | `DISTINCT`, two approaches compared |
| Tracks never purchased (dead catalog weight) | `LEFT JOIN` + `IS NULL` |
| Percentage of catalog never purchased | Nested CTEs, `CASE WHEN` inside `AVG()` |
| Genre pairs most commonly bought together | Self join, `a.genre_name < b.genre_name` |

**Key Findings:**

- **Iron Maiden leads revenue at $138.60**, nearly 32% more than second-placed U2 ($105.93), suggesting a dominant fanbase driving disproportionate sales.
- Notably, **"Lost" and "The Office" appear in the top 10 artists** — these are TV shows sold as video content alongside music. This is a data quality observation: the Chinook database includes non-music media, which should be filtered depending on the analytical context.
- Rock dominates genre revenue share, consistent with the catalog composition. Cross-sell analysis reveals which genre pairs are most frequently purchased together, which could inform playlist curation and recommendation logic.
- Artist catalog efficiency analysis (revenue per track, filtered to artists with 5+ purchased tracks) separates artists with large catalogs from those whose individual tracks consistently perform well — a more nuanced view of artist value than total revenue alone.

---

## 4. Sales Team Performance

*How is revenue distributed across the sales team, and which markets are they serving?*

| Query | Key Technique |
|---|---|
| Revenue contribution per sales representative | Indirect `JOIN` via `SupportRepId` |
| Customer rankings within each country | `RANK() OVER(PARTITION BY)` |

**Key Findings:**

- Revenue attribution to sales reps required identifying an indirect join path: `employee → customer → invoice`, via the `SupportRepId` foreign key on the customer table. This is a common pattern in real-world schemas where relationships are not always obvious from the table structure alone.
- Customer rankings within each country provide a basis for targeted account management — identifying the highest-value customers in each market for priority engagement.

---

## Key Findings Summary

| # | Finding |
|---|---|
| 1 | Iron Maiden is the top-grossing artist, generating $138.60 — 32% more than second-placed U2 |
| 2 | Prague is the highest-revenue city despite the USA leading by country, suggesting customer concentration |
| 3 | 2021 data appears incomplete, likely representing the store's launch period |
| 4 | Rock accounts for the largest share of genre revenue by a significant margin |
| 5 | A meaningful percentage of the catalog has never been purchased, representing dead catalog weight |
| 6 | TV show content (The Office, Lost) appears in top artist rankings — a data quality consideration |
| 7 | Customer spending is tightly clustered ($36.64–$49.62), limiting statistical segmentation approaches |

---

## SQL Concepts Reference

A summary of the key SQL concepts demonstrated in this project, for reference.

**Window Functions**
```sql
-- Rank within a group
RANK() OVER(PARTITION BY Country ORDER BY total_spending DESC)

-- Running cumulative total
SUM(revenue) OVER(ORDER BY date_month)

-- Percentage of total
revenue / SUM(revenue) OVER() * 100

-- Month-over-month change
LAG(revenue) OVER(ORDER BY date_month)
```

**Conditional Aggregation**
```sql
-- Count rows matching a condition
SUM(CASE WHEN condition THEN 1 ELSE 0 END)

-- Percentage of rows matching a condition
AVG(CASE WHEN condition THEN 1 ELSE 0 END) * 100
```

**Finding Unmatched Records**
```sql
-- Tracks never purchased
SELECT track.Name
FROM track
LEFT JOIN invoiceline USING(TrackId)
WHERE invoiceline.TrackId IS NULL
```

**Self Join for Pair Analysis**
```sql
-- Genre pairs bought together (a < b prevents duplicate pairs)
FROM invoice_genres a
JOIN invoice_genres b
    ON a.InvoiceId = b.InvoiceId
    AND a.genre_name < b.genre_name
```

---

*Analysis performed on the [Chinook Database](https://github.com/lerocha/chinook-database) using MySQL Workbench.*
