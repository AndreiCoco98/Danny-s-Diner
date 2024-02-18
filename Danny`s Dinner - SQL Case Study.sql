
--CREATE TABLE sales (
--  "customer_id" VARCHAR(1),
--  "order_date" DATE,
--  "product_id" INTEGER
--);

--INSERT INTO sales
--  ("customer_id", "order_date", "product_id")
--VALUES
--  ('A', '2021-01-01', '1'),
--  ('A', '2021-01-01', '2'),
--  ('A', '2021-01-07', '2'),
--  ('A', '2021-01-10', '3'),
--  ('A', '2021-01-11', '3'),
--  ('A', '2021-01-11', '3'),
--  ('B', '2021-01-01', '2'),
--  ('B', '2021-01-02', '2'),
--  ('B', '2021-01-04', '1'),
--  ('B', '2021-01-11', '1'),
--  ('B', '2021-01-16', '3'),
--  ('B', '2021-02-01', '3'),
--  ('C', '2021-01-01', '3'),
--  ('C', '2021-01-01', '3'),
--  ('C', '2021-01-07', '3');
 

--CREATE TABLE menu (
--  "product_id" INTEGER,
--  "product_name" VARCHAR(5),
--  "price" INTEGER
--);

--INSERT INTO menu
--  ("product_id", "product_name", "price")
--VALUES
--  ('1', 'sushi', '10'),
--  ('2', 'curry', '15'),
--  ('3', 'ramen', '12');
  

--CREATE TABLE members (
--  "customer_id" VARCHAR(1),
--  "join_date" DATE
--);

--INSERT INTO members
--  ("customer_id", "join_date")
--VALUES
--  ('A', '2021-01-07'),
--  ('B', '2021-01-09');

-- 1. What is the total amount each customer spent at the restaurant?

SELECT M.customer_id, SUM([price]) 
 FROM members M
 JOIN sales S
 ON S.customer_id = M.customer_id
 JOIN menu ME
 ON ME.product_id = S.product_id
 GROUP BY M.customer_id



 -- 2. How many days has each customer visited the restaurant?

 SELECT customer_id, COUNT(DAY(order_date)) as TotalDaysVisited
  FROM sales
  GROUP BY customer_id



-- 3. What was the first item from the menu purchased by each customer?

SELECT  customer_id , product_name
 FROM (
SELECT S.customer_id , M.product_name, ROW_NUMBER() OVER ( PARTITION BY customer_id ORDER BY order_date) as ranking_items
 FROM sales S
  JOIN menu M
   ON S.product_id = M.product_id
   ) as ranked
 WHERE ranking_items = 1



-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT M.product_name, COUNT(S.product_id) as TotalPurchased
 FROM sales S
  JOIN menu M
  ON S.product_id = M.product_id
  GROUP BY M.product_name
  ORDER BY TotalPurchased DESC
  OFFSET 0 ROWS
  FETCH NEXT 1 ROWS ONLY



-- 5. Which item was the most popular for each customer?

WITH RankedProducts AS (
    SELECT
        customer_id,
        product_name,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY cnt DESC) AS ranking
    FROM (
        SELECT
            S.customer_id,
            M.product_name,
            COUNT(*) AS cnt
        FROM
            sales S
            JOIN menu M ON S.product_id = M.product_id
        GROUP BY
            S.customer_id,
            M.product_name
    ) AS ProductCounts
)

SELECT
    customer_id,
    product_name
FROM
    RankedProducts
WHERE
    ranking = 1;



-- 6. Which item was purchased first by the customer after they became a member?

SELECT customer_id,join_date, order_date
FROM 
(
SELECT M.customer_id,M.join_date, S.order_date, ROW_NUMBER() OVER(PARTITION BY M.customer_id ORDER BY S.order_date) as ranking_items
 FROM members M
  JOIN sales S
 ON M.customer_id = S.customer_id
 WHERE M.join_date <= S.order_date
 ) as ranked
 WHERE ranking_items = 1



-- 7. Which item was purchased just before the customer became a member?

 SELECT customer_id, join_date, order_date
FROM (
    SELECT M.customer_id, M.join_date, S.order_date, ROW_NUMBER() OVER (PARTITION BY M.customer_id ORDER BY S.order_date DESC) AS ranking_items
    FROM members M
    JOIN sales S ON M.customer_id = S.customer_id
    WHERE M.join_date > S.order_date
) AS ranked
WHERE ranking_items = 1;



-- 8. What is the total items and amount spent for each member before they became a member?

SELECT customer_id, join_date, total_items, total_amount
FROM (
    SELECT M.customer_id, M.join_date, 
           SUM(1) AS total_items, 
           SUM(ME.price) AS total_amount, 
           ROW_NUMBER() OVER (PARTITION BY M.customer_id ORDER BY MIN(S.order_date)) AS ranking_items
    FROM members M
    JOIN sales S ON M.customer_id = S.customer_id
    JOIN menu ME ON ME.product_id = S.product_id
    WHERE M.join_date > S.order_date
    GROUP BY M.customer_id, M.join_date
) AS ranked
WHERE ranking_items = 1;



-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

SELECT S.customer_id, 
       SUM(price) as total_spent, 
	   SUM(CASE WHEN M.product_name = 'sushi' THEN price * 20 ELSE price * 10 END) as Points
 FROM sales S
 JOIN menu M
  ON M.product_id = S.product_id
  GROUP BY S.customer_id
  ORDER BY S.customer_id ASC, SUM(price) DESC



-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

   WITH CustomerPoints AS (
    SELECT 
        M.customer_id, 
        SUM(
            CASE 
                WHEN MONTH(S.order_date) = 1 AND DATEDIFF(DAY, M.join_date, S.order_date) <= 7 THEN price * 20 -- First week after joining
                WHEN MONTH(S.order_date) = 1 THEN price * 10 -- After & before joining into the membership
                ELSE 0
            END
        ) AS total_points
    FROM members M
    JOIN sales S 
	ON M.customer_id = S.customer_id
    JOIN menu ME 
	ON ME.product_id = S.product_id
    WHERE MONTH(S.order_date) = 1
    GROUP BY M.customer_id
)

SELECT 
    customer_id, 
    SUM(total_points) AS total_points
FROM CustomerPoints
GROUP BY  customer_id;
