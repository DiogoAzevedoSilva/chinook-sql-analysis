USE Chinook;

/* ============================================================
   CHINOOK DIGITAL MUSIC STORE — BUSINESS PERFORMANCE ANALYSIS
   ============================================================ */


/* ------------------------------------------------------------
   1. REVENUE ANALYSIS
   How is the business performing over time, and where
   geographically is revenue concentrated?
   ------------------------------------------------------------ */

# What is the monthly revenue trend over time?

SELECT 
	DATE_FORMAT(invoice.InvoiceDate, "%Y-%m") AS date_month,
	SUM(invoiceline.Quantity * invoiceline.UnitPrice) AS revenue
FROM invoiceline
JOIN invoice USING(InvoiceId)
GROUP BY date_month
ORDER BY date_month ASC;

-- Calculating revenue at invoice line level for granularity


# Find the running cumulative revenue over time

WITH monthly_revenue AS (
	SELECT
		DATE_FORMAT(InvoiceDate, "%Y-%m") AS date_month,
        SUM(Total) AS revenue
	FROM invoice
    GROUP BY date_month
)
SELECT
	date_month,
    revenue,
    SUM(revenue) OVER(ORDER BY date_month) AS cumulative_revenue
FROM monthly_revenue
ORDER BY date_month;


# Month over month revenue growth — calculate the % change in revenue from one month to the next

WITH monthly_revenue AS (
	SELECT 
		DATE_FORMAT(InvoiceDate, "%Y-%m") AS date_month,
        SUM(Total) AS revenue
	FROM invoice
    GROUP BY date_month
    ORDER BY date_month ASC
)
SELECT
	date_month,
    revenue,
    LAG(revenue) OVER(ORDER BY date_month) AS prev_month_revenue,
    revenue - LAG(revenue) OVER(ORDER BY date_month) AS abs_change,
    ROUND(
		(revenue - LAG(revenue) OVER(ORDER BY date_month))
        / LAG(revenue) OVER(ORDER BY date_month) * 100
	, 2) AS pct_change
FROM monthly_revenue
ORDER BY date_month;


# Identify the best month for sales for each year

WITH monthly_sales AS (
	SELECT
		DATE_FORMAT(InvoiceDate, "%Y") AS date_year,
        DATE_FORMAT(InvoiceDate, "%M") AS date_month,
        SUM(Total) AS revenue
	FROM invoice
    GROUP BY date_year, date_month
),
month_rank AS (
	SELECT 
		date_year,
        date_month,
        revenue,
        RANK() OVER(PARTITION BY date_year ORDER BY revenue DESC) AS rnk
	FROM monthly_sales
)
SELECT
	date_year,
    date_month,
    revenue
FROM month_rank
WHERE rnk = 1
ORDER BY date_year ASC;

-- 2021 appears to be an incomplete year in the dataset with uniform revenue across months,
-- suggesting it represents the store's launch period. From 2022 onwards a clear seasonal pattern emerges.


# What is the average order value per country?

-- Average spending per order
SELECT
	customer.Country,
    ROUND(AVG(invoice.Total), 2) AS avg_order
FROM invoice
JOIN customer USING(CustomerId)
GROUP BY Country
ORDER BY avg_order DESC;

-- Average order value is calculated per transaction. Countries with fewer but larger orders
-- may rank higher than countries with frequent small purchases.

-- Average spending per customer
WITH spending_per_customer AS (
	SELECT
		customer.CustomerId,
        customer.Country,
        SUM(invoice.Total) AS total_spending
	FROM invoice
	JOIN customer USING(customerId)
    GROUP BY customer.CustomerId, customer.Country
)
SELECT
	country,
    ROUND(AVG(total_spending), 2) AS avg_per_customer
FROM spending_per_customer
GROUP BY country
ORDER BY avg_per_customer DESC;


# Which cities generate the most revenue?

SELECT
	customer.City,
    customer.Country,
    SUM(invoice.Total) AS revenue
FROM invoice
JOIN customer USING(CustomerId)
GROUP BY customer.City, customer.Country
ORDER BY revenue DESC
LIMIT 10;


/* ------------------------------------------------------------
   2. CUSTOMER ANALYSIS
   Who are the customers, how do they behave, and which
   are at risk of churning?
   ------------------------------------------------------------ */

# Customer segmentation — classify customers as High, Medium, or Low spenders

-- Statistical description of spending distribution
SELECT
    MIN(total_spending) AS min_spending,
    MAX(total_spending) AS max_spending,
    AVG(total_spending) AS avg_spending,
    ROUND(AVG(total_spending) - STDDEV(total_spending), 2) AS one_std_below,
    ROUND(AVG(total_spending) + STDDEV(total_spending), 2) AS one_std_above
FROM (
    SELECT
        customer.CustomerId,
        SUM(invoice.Total) AS total_spending
    FROM invoice
    JOIN customer USING(CustomerId)
    GROUP BY customer.CustomerId
) AS customer_spending;

/* Initial analysis showed spending ranged from $36.64 to $49.62 with low variance (std dev = $2.89),
 making statistical segmentation impractical. Thresholds were set based on the actual data distribution:
 Low → below $39 | Medium → $39 to $45 | High → above $45. */

WITH customer_spending AS (
	SELECT
		CONCAT(customer.FirstName, " ", customer.LastName) AS customer_name,
        SUM(invoice.Total) AS total_spending
	FROM invoice
    JOIN customer USING(CustomerId)
    GROUP BY customer.CustomerId, customer.FirstName, customer.LastName
)
SELECT
	customer_name,
    total_spending,
    CASE
		WHEN total_spending > 45 THEN "High"
        WHEN total_spending >= 39 THEN "Medium"
        ELSE "Low"
	END AS segment
FROM customer_spending
ORDER BY total_spending DESC;


# Rank customers within each country by their total spending

WITH customer_spending AS (
	SELECT 
		CONCAT(customer.FirstName, " ", customer.LastName) AS customer_name,
		customer.Country,
		SUM(invoice.Total) AS total_spending
	FROM invoice
	JOIN customer USING(CustomerId)
	GROUP BY customer.CustomerId, customer.Country, customer_name
)
SELECT
	customer_name,
    country,
    total_spending,
    RANK() OVER (PARTITION BY country ORDER BY total_spending DESC) AS rank_by_country
FROM customer_spending
ORDER BY Country, rank_by_country;


# Most loyal customers — rank customers by number of purchases vs spending amount
# Do big spenders also buy frequently?

WITH customer_purchases AS (
	SELECT
		CONCAT(customer.FirstName, " ", customer.LastName) AS customer_name,
        COUNT(invoice.InvoiceId) AS nb_purchases,
        SUM(invoice.Total) AS total_spent
	FROM invoice
    JOIN customer USING(CustomerId)
    GROUP BY customer.CustomerId, customer.FirstName, customer.LastName
)
SELECT
	customer_name,
    nb_purchases,
    RANK() OVER(ORDER BY nb_purchases DESC) AS nb_purchases_rank,
    total_spent,
    RANK() OVER(ORDER BY total_spent DESC) AS total_spent_rank
FROM customer_purchases
ORDER BY nb_purchases_rank;

/*In a real-world dataset customer purchase frequency would vary significantly, making this ranking
 comparison a powerful segmentation tool. The Chinook dataset is too uniform to demonstrate this —
 most customers have exactly 7 purchases — but the query logic is sound and would yield meaningful
 insights on production data. */


# Which customers have made only a single purchase? (churn risk analysis)

SELECT
	CONCAT(customer.FirstName, " ", customer.LastName) AS customer_name,
    COUNT(invoice.InvoiceId) AS nb_orders
FROM invoice
JOIN customer USING(CustomerId)
GROUP BY customer.CustomerId, customer.FirstName, customer.LastName
HAVING COUNT(invoice.InvoiceId) = 1;


# Which customers bought tracks from the most diverse range of genres?

WITH distinct_genres AS (
	SELECT DISTINCT
		customer.CustomerId,
		CONCAT(customer.FirstName, " ", customer.LastName) AS name,
		track.GenreId
	FROM invoice
	JOIN customer USING(CustomerId)
	JOIN invoiceline USING(InvoiceId)
	JOIN track USING(TrackId)
)
SELECT 
	name,
    COUNT(GenreId) AS nb_genres
FROM distinct_genres
GROUP BY name
ORDER BY nb_genres DESC
LIMIT 10;


/* ------------------------------------------------------------
   3. PRODUCT & CATALOG ANALYSIS
   What sells, what doesn't, and how efficiently
   is the catalog performing?
   ------------------------------------------------------------ */

# What are the top 10 best-selling artists, and how much revenue did each generate?

SELECT
	artist.Name AS artist,
	SUM(invoiceline.Quantity * invoiceline.UnitPrice) AS revenue
FROM invoiceline
JOIN track USING(TrackId)
JOIN album USING(AlbumId)
JOIN artist USING(ArtistId)
GROUP BY artist.Name
ORDER BY revenue DESC
LIMIT 10;


# Calculate each genre's percentage share of total revenue

WITH genre_revenue AS (
	SELECT 
		genre.Name AS genre,
		SUM(invoiceline.UnitPrice * invoiceline.Quantity) AS revenue
	FROM invoiceline
	JOIN track USING(TrackId)
	JOIN genre USING(GenreId)
	GROUP BY genre.name
)
SELECT 
	genre,
    revenue,
    ROUND(revenue / SUM(revenue) OVER() * 100, 2) AS percentage
FROM genre_revenue
ORDER BY percentage DESC;


# Artist catalog efficiency — which artists have the highest revenue per track?

WITH track_revenue AS (
	SELECT 
		TrackId,
        SUM(UnitPrice * Quantity) AS revenue
	FROM invoiceline
    GROUP BY TrackId
)
SELECT
	artist.Name AS artist_name,
    COUNT(track.TrackId) AS tracks_in_catalog,
    SUM(track_revenue.revenue) AS total_revenue,
    ROUND(AVG(track_revenue.revenue), 2) AS avg_revenue_per_track
FROM track
JOIN track_revenue USING(TrackId)
JOIN album USING(AlbumId)
JOIN artist USING(ArtistId)
GROUP BY artist.ArtistId, artist.Name
HAVING COUNT(track.TrackId) >= 5
ORDER BY avg_revenue_per_track DESC
LIMIT 10;


# Which album has the highest number of tracks purchased? (vs just having many tracks)

-- Most unique tracks purchased
WITH distinct_purchases AS (
	SELECT DISTINCT
		album.Title AS album,
        invoiceline.TrackId 
	FROM invoiceline
    JOIN track USING(TrackId)
    JOIN album USING(AlbumId)
)
SELECT 
	album,
    COUNT(TrackId) AS tracks_purchased
FROM distinct_purchases
GROUP BY album
ORDER BY tracks_purchased DESC
LIMIT 1;

-- Most total purchases (includes repeat purchases of the same track)
SELECT 
	album.Title AS album,
    COUNT(invoiceline.TrackId) AS total_purchases
FROM invoiceline
JOIN track USING(TrackId)
JOIN album USING(AlbumId)
GROUP BY album.Title
ORDER BY total_purchases DESC
LIMIT 1;


# Which tracks have never been purchased?

SELECT
	track.Name
FROM track
LEFT JOIN invoiceline USING(TrackId)
WHERE invoiceline.TrackId IS NULL;


# What percentage of tracks in the catalog have never been purchased?

WITH never_purchased AS (
	SELECT
	    track.TrackId
	FROM track
	LEFT JOIN invoiceline USING(TrackId)
	WHERE invoiceline.TrackId IS NULL
),
totals AS (
	SELECT
		COUNT(*) AS total_tracks,
        (SELECT COUNT(*) FROM never_purchased) AS never_purchased_tracks
	FROM track
)
SELECT
	total_tracks,
    never_purchased_tracks,
    ROUND(never_purchased_tracks / total_tracks * 100, 2) AS pct_never_purchased
FROM totals;


# Cross-sell analysis — which pairs of genres are most commonly bought together in the same invoice?

WITH invoice_genres AS (
    SELECT DISTINCT
        invoice.InvoiceId,
        genre.Name AS genre_name
    FROM invoice
    JOIN invoiceline USING(InvoiceId)
    JOIN track USING(TrackId)
    JOIN genre USING(GenreId)
)
SELECT
    a.genre_name AS genre_1,
    b.genre_name AS genre_2,
    COUNT(*) AS times_bought_together
FROM invoice_genres a
JOIN invoice_genres b 
    ON a.InvoiceId = b.InvoiceId
    AND a.genre_name < b.genre_name
GROUP BY genre_1, genre_2
ORDER BY times_bought_together DESC
LIMIT 10;

-- Self join on the same CTE: a.genre_name < b.genre_name prevents duplicate pairs (Rock-Jazz and Jazz-Rock)


/* ------------------------------------------------------------
   4. SALES TEAM PERFORMANCE
   How is revenue distributed across the sales team,
   and which markets are they serving?
   ------------------------------------------------------------ */

# What is each sales rep's total revenue contribution?

SELECT
	CONCAT(employee.FirstName, " ", employee.LastName) AS sales_rep,
    SUM(invoice.Total) AS revenue
FROM invoice
JOIN customer USING(CustomerId)
JOIN employee ON customer.SupportRepId = employee.EmployeeId
GROUP BY employee.EmployeeId, sales_rep
ORDER BY revenue DESC;


# Rank customers within each country by their total spending

WITH customer_spending AS (
	SELECT 
		CONCAT(customer.FirstName, " ", customer.LastName) AS customer_name,
		customer.Country,
		SUM(invoice.Total) AS total_spending
	FROM invoice
	JOIN customer USING(CustomerId)
	GROUP BY customer.CustomerId, customer.Country, customer_name
)
SELECT
	customer_name,
    country,
    total_spending,
    RANK() OVER (PARTITION BY country ORDER BY total_spending DESC) AS rank_by_country
FROM customer_spending
ORDER BY Country, rank_by_country;


/* ============================================================
   END OF ANALYSIS
   ============================================================ */
