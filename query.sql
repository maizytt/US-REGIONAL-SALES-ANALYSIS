-- Connect database 
USE us_regional_sales;

-- ************* Revenue*****************
-- Calculate total order, total order quatity, total revenue, profit
SELECT COUNT(DISTINCT order_number) AS total_order, 
	   SUM(order_quantity) AS total_order_quatity,
       ROUND(SUM(order_quantity*(unit_price)*(1-discount_applied)),2) AS total_revenue,
       ROUND(SUM(order_quantity*(unit_price -unit_cost)*(1-discount_applied)),2) AS profit
FROM sales;

-- Average number of orders, average order quantity, and average revenue per year
SELECT 
    YEAR(order_date) AS year,
    COUNT(order_number) / COUNT(DISTINCT YEAR(order_date)) AS average_orders,
    AVG(order_quantity) AS average_order_quantity,
    AVG(order_quantity * unit_price * (1 - discount_applied)) AS average_revenue
FROM sales
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date);

-- Monthly revenue growth (%)
WITH MonthlyRevenue AS (
    SELECT 
        DATE_FORMAT(order_date, '%Y-%m') AS month,
        ROUND(SUM(order_quantity*(unit_price)*(1-discount_applied)),2) AS monthly_revenue
    FROM sales
    GROUP BY DATE_FORMAT(order_date, '%Y-%m')
)
SELECT 
    month,
    monthly_revenue,
    LAG(monthly_revenue) OVER (ORDER BY month) AS previous_month_revenue,
    ROUND((monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month)) / LAG(monthly_revenue) OVER (ORDER BY month) * 100,2) AS "revenue_growth_percentage(%)"
FROM MonthlyRevenue
ORDER BY month;

-- Monthly order growth (%)
WITH MonthlyOrder AS (
    SELECT 
        DATE_FORMAT(order_date, '%Y-%m') AS month,
        COUNT(DISTINCT order_number) AS monthly_order
    FROM sales
    GROUP BY DATE_FORMAT(order_date, '%Y-%m')
)
SELECT 
    month,
    monthly_order,
    LAG(monthly_order) OVER (ORDER BY month) AS previous_month_order,
    ROUND((monthly_order - LAG(monthly_order) OVER (ORDER BY month)) / LAG(monthly_order) OVER (ORDER BY month) * 100,2) AS "order_growth_percentage(%)"
FROM MonthlyOrder
ORDER BY month;

-- Number of orders by day of week and month of year
SELECT 
	DATE_FORMAT(order_date, '%Y-%m') AS month_of_year,
	CASE DAYOFWEEK(order_date)
		WHEN 1 THEN 'Sunday'
        WHEN 2 THEN 'Monday'
        WHEN 3 THEN 'Tueday'
        WHEN 4 THEN 'Wednesday'
        WHEN 5 THEN 'Thursday'
        WHEN 6 THEN 'Friday'
        WHEN 7 THEN 'Saturday'
	END AS day_of_week,
    COUNT(order_number) AS number_of_orders
FROM sales
GROUP BY month_of_year, day_of_week   
ORDER BY month_of_year;

-- ************ Regions **************
-- Revenue by region
SELECT r.region, 
	   ROUND(SUM(s.order_quantity*(s.unit_price)*(1-s.discount_applied)),2) AS revenue_region,
       ROUND(AVG(s.order_quantity*(s.unit_price)*(1-s.discount_applied)),2) AS avg_revenue_region
FROM sales s JOIN stores_locations sl ON s.store_id = sl.store_id
JOIN regions r ON r.state_code = sl.state_code
GROUP BY r.region
ORDER BY revenue_region DESC;

-- Revenue by states 
SELECT r.state, r.region, 
	   ROUND(SUM(s.order_quantity*(s.unit_price)*(1-s.discount_applied)),2) AS revenue_state,
       ROUND(AVG(s.order_quantity*(s.unit_price)*(1-s.discount_applied)),2) AS avg_revenue_state
FROM sales s JOIN stores_locations sl ON s.store_id = sl.store_id
JOIN regions r ON r.state_code = sl.state_code
GROUP BY  r.state, r.region
ORDER BY r.region, revenue_state DESC, avg_revenue_state DESC;

-- Information about which city, state, and region
SELECT sl.store_id, sl.city_name, sl.store_type AS city_type, sl.state_name, r.region,
	   ROUND(SUM(s.order_quantity*(s.unit_price)*(1-s.discount_applied)),2) AS revenue_store
FROM  stores_locations sl JOIN regions r ON r.state_code = sl.state_code
JOIN sales s ON s.store_id = sl.store_id
GROUP BY sl.store_id, sl.city_name, city_type, sl.state_name
ORDER BY sl.store_id;

-- Information of top 10 store have highest revenue
WITH StoreRevenue AS (
    SELECT
        sl.store_id,
        SUM(s.order_quantity * s.unit_price * (1 - s.discount_applied)) AS total_revenue
    FROM sales s JOIN stores_locations sl ON s.store_id = sl.store_id
    JOIN regions r ON sl.state_code = r.state_code
    GROUP BY r.region,  sl.city_name, sl.store_id
    ORDER BY total_revenue DESC
    LIMIT 10
)
SELECT *  FROM stores_locations 
WHERE store_id IN ( SELECT store_id FROM StoreRevenue);

-- Top 5 store have highest revenue by region
WITH StoreRevenue AS (
    SELECT
		r.region,
        sl.city_name,
        sl.store_id,
        SUM(s.order_quantity * s.unit_price * (1 - s.discount_applied)) AS total_revenue,
        ROW_NUMBER() OVER (PARTITION BY r.region ORDER BY SUM(s.order_quantity * s.unit_price * (1 - s.discount_applied)) DESC) AS revenue_rank
    FROM sales s JOIN stores_locations sl ON s.store_id = sl.store_id
    JOIN regions r ON sl.state_code = r.state_code
    GROUP BY r.region,  sl.city_name, sl.store_id
)
SELECT region, city_name, store_id, total_revenue
FROM StoreRevenue
WHERE revenue_rank <= 5
ORDER BY region, total_revenue DESC;

-- Find stores with revenue higher than the average revenue per year
WITH yearly_average_revenue AS (
    SELECT
        YEAR(order_date) AS year,
        AVG(s.order_quantity * s.unit_price * (1 - s.discount_applied)) AS avg_revenue
    FROM sales s
    WHERE s.order_date IS NOT NULL
    GROUP BY YEAR(order_date)
),
yearly_store_revenue AS (
    SELECT
        YEAR(s.order_date) AS year,
        s.store_id,
        sl.city_name,
        SUM(s.order_quantity * s.unit_price * (1 - s.discount_applied)) AS store_revenue
    FROM sales s
    JOIN stores_locations sl ON s.store_id = sl.store_id
    WHERE s.order_date IS NOT NULL
    GROUP BY YEAR(s.order_date), s.store_id, sl.city_name
)
SELECT
    ysr.year,
    ysr.store_id,
    ysr.city_name,
    ysr.store_revenue,
    yar.avg_revenue
FROM yearly_store_revenue ysr
JOIN yearly_average_revenue yar ON ysr.year = yar.year
WHERE ysr.store_revenue < yar.avg_revenue
ORDER BY ysr.year, ysr.store_revenue DESC;

-- ************ Sales Channels************
-- Total order, total order quatity, total revenue by sales channel
SELECT 
    s.sales_channel,
    COUNT(DISTINCT order_number) AS total_order, 
	SUM(order_quantity) AS total_order_quatity,
	ROUND(SUM(order_quantity*(unit_price)*(1-discount_applied)),2) AS total_revenue
FROM sales s
GROUP BY s.sales_channel
ORDER BY total_revenue DESC;

-- The revenue for each sales channel by year
SELECT 
    YEAR(s.order_date) AS year,
    s.sales_channel,
    ROUND(SUM(order_quantity*(unit_price)*(1-discount_applied)),2) AS total_revenue
FROM sales s
GROUP BY  YEAR(s.order_date), s.sales_channel
ORDER BY year, total_revenue DESC;

-- The revenue for each sales channel by region
SELECT 
	r.region,
    s.sales_channel,
    ROUND(SUM(order_quantity*(unit_price)*(1-discount_applied)),2) AS total_revenue
FROM sales s
JOIN stores_locations sl ON s.store_id = sl.store_id
JOIN regions r ON sl.state_code = r.state_code
GROUP BY r.region, s.sales_channel
ORDER BY r.region, s.sales_channel, total_revenue DESC;

-- ************ Sales Teams ***************
-- The sales team works for each sales channel
SELECT 
    s.sales_channel,
    st.sales_team,
    COUNT(DISTINCT s.order_number) AS total_orders
FROM sales s
JOIN sales_teams st ON s.sales_team_id = st.sales_team_id
GROUP BY s.sales_channel, st.sales_team
ORDER BY s.sales_channel, total_orders DESC;

-- The information of sales teams and the list of store IDs they manage
SELECT 
    st.sales_team,
    r.region,
    GROUP_CONCAT(DISTINCT sl.store_id ORDER BY sl.store_id) AS stores_manage,
    COUNT(DISTINCT sl.store_id) AS number_of_stores
FROM sales_teams st
JOIN sales s ON st.sales_team_id = s.sales_team_id
JOIN stores_locations sl ON s.store_id = sl.store_id
JOIN regions r ON sl.state_code = r.state_code
GROUP BY st.sales_team, r.region
ORDER BY st.sales_team, r.region;

-- Revenue by sales teams
SELECT DISTINCT st.sales_team, st.region, 
	   ROUND(SUM(s.order_quantity*(s.unit_price)*(1-s.discount_applied)),2) AS revenue
FROM sales_teams st JOIN sales s ON s.sales_team_id = st.sales_team_id
GROUP BY  st.sales_team, st.region;

-- Information of top 5 sales team have highest revenue
SELECT DISTINCT st.sales_team, st.region, 
	   ROUND(SUM(s.order_quantity*(s.unit_price)*(1-s.discount_applied)),2) AS revenue
FROM sales_teams st JOIN sales s ON s.sales_team_id = st.sales_team_id
GROUP BY  st.sales_team, st.region;

-- The sales team that contributed the most in terms of revenue for each region and year
WITH sales_team_revenue AS (
    SELECT 
        st.sales_team,
        r.region,
        YEAR(s.order_date) AS year,
        SUM(s.order_quantity * s.unit_price * (1 - s.discount_applied)) AS total_revenue
    FROM sales s
    JOIN sales_teams st ON s.sales_team_id = st.sales_team_id
    JOIN stores_locations sl ON s.store_id = sl.store_id
    JOIN regions r ON sl.state_code = r.state_code
    WHERE s.order_date IS NOT NULL
    GROUP BY  YEAR(s.order_date), r.region, st.sales_team
),
max_revenue AS (
    SELECT 
        region,
        year,
        MAX(total_revenue) AS max_revenue
    FROM sales_team_revenue
    GROUP BY year, region
)
SELECT 
	str.year,
    str.region,
    str.sales_team,
    str.total_revenue
FROM sales_team_revenue str
JOIN max_revenue mr ON str.region = mr.region AND str.year = mr.year AND str.total_revenue = mr.max_revenue
ORDER BY str.year, str.region;

-- ***************Products****************
-- Retrieve the names and prices of all products
SELECT p.product_name, 
	   ROUND(MAX(s.unit_price),2) AS max_price, 
       ROUND(AVG(s.unit_price),2) AS agv_price,
       ROUND(MIN(s.unit_price),2) AS min_price
FROM products p JOIN sales s ON s.product_id = p.product_id
GROUP BY p.product_name;
--  Top 5 products with the highest order quantity
SELECT 
    p.product_name,
    SUM(s.order_quantity) AS total_order_quantity
FROM sales s
JOIN products p ON s.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_order_quantity DESC
LIMIT 5;

-- Top 5 products with the highest revenue
SELECT 
    p.product_name,
    SUM(s.order_quantity * s.unit_price * (1 - s.discount_applied)) AS total_revenue
FROM sales s
JOIN products p ON s.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_revenue DESC
LIMIT 5;

-- The top 3 most purchased products by month for each year
WITH product_monthly_sales AS (
    SELECT 
		YEAR(s.order_date) AS year,
        MONTH(s.order_date) AS month,
        p.product_name,
        SUM(s.order_quantity) AS total_order_quantity,
        DENSE_RANK() OVER (PARTITION BY YEAR(s.order_date), MONTH(s.order_date) ORDER BY SUM(s.order_quantity) DESC) AS order_quatity_rank
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    WHERE s.order_date IS NOT NULL
    GROUP BY p.product_name, YEAR(s.order_date), MONTH(s.order_date)
)
SELECT 
	year,
    month,
    product_name,
    total_order_quantity
FROM product_monthly_sales
WHERE order_quatity_rank <= 3
ORDER BY year, month, order_quatity_rank;

-- The most frequently applied discount for each product
WITH DiscountFrequency AS (
    SELECT 
        s.product_id,
        p.product_name,
        s.discount_applied,
        COUNT(*) AS discount_count
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    GROUP BY s.product_id, p.product_name, s.discount_applied
),
MostFrequentDiscount AS (
    SELECT 
        product_id,
        product_name,
        discount_applied,
        discount_count,
        RANK() OVER (PARTITION BY product_id ORDER BY discount_count DESC) AS discount_rank
    FROM DiscountFrequency
)
SELECT 
    product_id,
    product_name,
    discount_applied,
    discount_count
FROM MostFrequentDiscount
WHERE 
    discount_rank = 1;


-- ************** Delivery Order ****************
-- The average time from order placement to delivery
SELECT AVG(DATEDIFF(delivery_date, order_date)) AS "average_delivery_time(day)"
FROM sales
WHERE delivery_date IS NOT NULL AND order_date IS NOT NULL;

-- The delivery time for each product
SELECT 
    p.product_name,
    MAX(DATEDIFF(s.delivery_date, s.order_date)) AS max_delivery_time,
    MIN(DATEDIFF(s.delivery_date, s.order_date)) AS min_delivery_time,
    ROUND(AVG(DATEDIFF(s.delivery_date, s.order_date)),2) AS average_delivery_time_days
FROM sales s
JOIN products p ON s.product_id = p.product_id
WHERE s.delivery_date IS NOT NULL AND s.order_date IS NOT NULL
GROUP BY p.product_id, p.product_name
ORDER BY max_delivery_time, min_delivery_time, average_delivery_time_days;

-- Calculate average delivery time by region
SELECT
    r.region,
    AVG(DATEDIFF(s.delivery_date, s.order_date)) AS average_delivery_time_days
FROM sales s
JOIN stores_locations sl ON s.store_id = sl.store_id
JOIN regions r ON sl.state_code = r.state_code
WHERE s.delivery_date IS NOT NULL AND s.order_date IS NOT NULL
GROUP BY r.region
ORDER BY average_delivery_time_days;

-- Information of the order with the longest delivery time
WITH min_max_delivery_time AS(
	SELECT 
		MAX(DATEDIFF(s.delivery_date, s.order_date)) AS max_delivery_time,
		MIN(DATEDIFF(s.delivery_date, s.order_date)) AS min_delivery_time
	FROM sales s
	WHERE s.delivery_date IS NOT NULL AND s.order_date IS NOT NULL
)
SELECT 
	s.order_number,
	s.sales_channel,
	s.procured_date,
	s.order_date,
	s.ship_date,
	s.delivery_date,
	st.sales_team,
	s.customer_id,
	s.store_id,
	p.product_name,
	s.order_quantity,
	s.discount_applied,
	s.unit_price,
	DATEDIFF(s.delivery_date, s.order_date) AS delivery_time_days
FROM sales s 
JOIN products p ON p.product_id = s.product_id
JOIN sales_teams st ON st.sales_team_id = s.sales_team_id
JOIN min_max_delivery_time mm 
    ON DATEDIFF(s.delivery_date, s.order_date) = mm.max_delivery_time
    OR DATEDIFF(s.delivery_date, s.order_date) = mm.min_delivery_time
WHERE s.delivery_date IS NOT NULL AND s.order_date IS NOT NULL
ORDER BY delivery_time_days;								

-- ************** Customer ******************
-- Top 10 customers with the highest number of orders and contributing the most revenue
SELECT 
    c.customer_id,
    c.customer_name,
    COUNT(s.order_number) AS number_of_orders,
    ROUND(SUM(s.order_quantity * s.unit_price * (1 - s.discount_applied)),2) AS total_order_value
FROM sales s
JOIN customers c ON s.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name
ORDER BY  number_of_orders DESC, total_order_value DESC
LIMIT 10;

--  The top 10 longest-standing customers
SELECT 
    c.customer_id,
    c.customer_name,
    MIN(s.order_date) AS first_order_date,
    MAX(s.order_date) AS last_order_date
FROM sales s
JOIN customers c ON s.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name
ORDER BY first_order_date ASC
LIMIT 10;

-- The stores that the top 10 customers (who have contributed the most revenue) frequently purchase from
WITH TopCustomers AS (
    SELECT 
        s.customer_id,
        SUM(s.order_quantity * s.unit_price * (1 - s.discount_applied)) AS total_revenue
    FROM sales s
    GROUP BY s.customer_id
    ORDER BY total_revenue DESC
    LIMIT 10
),
CustomerStores AS (
    SELECT 
        s.customer_id,
        c.customer_name,
        s.store_id,
        sl.city_name,
        sl.state_name,
        r.region,
        SUM(s.order_quantity * s.unit_price * (1 - s.discount_applied)) AS total_revenue
    FROM sales s
    JOIN customers c ON s.customer_id = c.customer_id
    JOIN stores_locations sl ON s.store_id = sl.store_id
    JOIN regions r ON sl.state_code = r.state_code
    WHERE s.customer_id IN (SELECT customer_id FROM TopCustomers)
    GROUP BY s.customer_id, c.customer_name, s.store_id, sl.city_name, sl.state_name, r.region
    ORDER BY total_revenue DESC
)
SELECT 
    cs.customer_id,
    cs.customer_name,
    cs.store_id,
    cs.city_name,
    cs.state_name,
    cs.region,
    cs.total_revenue
FROM CustomerStores cs
ORDER BY cs.customer_id;

-- The top customer with the highest number of orders for each sales channel
WITH CustomerOrders AS (
    SELECT 
        s.sales_channel,
        s.customer_id,
        COUNT(s.order_number) AS total_orders
    FROM sales s
    GROUP BY s.sales_channel, s.customer_id
),
RankedCustomers AS (
    SELECT 
        co.sales_channel,
        co.customer_id,
        co.total_orders,
        DENSE_RANK() OVER (PARTITION BY co.sales_channel ORDER BY co.total_orders DESC) AS order_rank
    FROM CustomerOrders co
)
SELECT 
    rc.sales_channel,
    rc.customer_id,
    c.customer_name,
    rc.total_orders
FROM RankedCustomers rc
JOIN customers c ON rc.customer_id = c.customer_id
WHERE rc.order_rank = 1;





