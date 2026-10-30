------------------------------------------------------------------
 PROJECT: Retail Chain Profit Leakage & Demand Optimization
------------------------------------------------------------------
CREATE DATABASE RetailAnalytics
USE RetailAnalytics
-------------------------------------------------------------------
--Create Product_Master
/*Primary Key:
A column, or combination of columns, that uniquely identifies each record in a table.

SKU_ID alone â†’  not unique
SKU_ID + SKU_Name â†’  unique*/

CREATE TABLE Product_Master
(
SKU_ID VARCHAR(20),
SKU_Name VARCHAR(300),
Category VARCHAR(150),
Sub_Category VARCHAR(200),
Brand VARCHAR(100),
Tax_Percent DECIMAL(5,2),
Unit_Cost DECIMAL(12,2),
MRP DECIMAL(12,2),

PRIMARY KEY (SKU_ID)
)


--CREATE SALES_TRANSACTION TABLE

CREATE TABLE Sales_Transactions
(
    Sales_ID INT IDENTITY(1,1) PRIMARY KEY,

    Order_ID VARCHAR(50),
    Order_Date DATE,
    Store_ID VARCHAR(50),
    Customer_ID VARCHAR(50),
    SKU_ID VARCHAR(50),
    Quantity INT,
    Selling_Price DECIMAL(18,2),
    Discount_Amount DECIMAL(18,2),
    Promo_ID VARCHAR(50),
    Delivery_Type VARCHAR(50),
    Payment_Mode VARCHAR(50),
    Order_Status VARCHAR(50),

    Original_SKU_ID VARCHAR(50),
    SKU_Mapping_Status VARCHAR(20),
    Negative_Quantity_Flag VARCHAR(10),
    Original_Promo_ID VARCHAR(50),
    Promo_Mapping_Status VARCHAR(20),
    Original_Store_ID VARCHAR(50),
    Cancellation_Flag VARCHAR(10)
)

---Create Inventory_Daily
CREATE TABLE Inventory_Daily
(
    Date DATE,
    Store_ID VARCHAR(50),
    SKU_ID VARCHAR(50),
    Opening_Stock INT,
    Closing_Stock INT,
    Reorder_Level INT,
    Warehouse_Stock INT
)

--Create Returns
CREATE TABLE Returns
(
    Return_ID VARCHAR(50),
    Order_ID VARCHAR(50),
    SKU_ID VARCHAR(50),
    Return_Date DATE,
    Return_Reason VARCHAR(50),
    Refund_Amount DECIMAL(18,2),
    Return_Status VARCHAR(20),
    Sales_Mapping_Status VARCHAR(20),
    SKU_Mapping_Status VARCHAR(20),

    PRIMARY KEY (Return_ID, SKU_ID)
)

--Create Vendor_Supply TABLE
CREATE TABLE Vendor_Supply
(
    Vendor_Supply_ID INT IDENTITY(1,1) PRIMARY KEY,

    PO_ID VARCHAR(50),
    Vendor_ID VARCHAR(50),
    SKU_ID VARCHAR(50),
    Store_ID VARCHAR(50),
    PO_Date DATE,
    Expected_Delivery_Date DATE,
    Actual_Delivery_Date DATE,
    Supplied_Quantity INT,
    Procurement_Cost DECIMAL(18,2),
    Delay_Days INT,
    SLA_Status VARCHAR(20),
    Vendor_Record_Status VARCHAR(20),
    SKU_Mapping_Status VARCHAR(20)
)


--Create Promotions TABLE
CREATE TABLE Promotions
(
    Promo_ID VARCHAR(50),
    Promo_Type VARCHAR(50),
    Start_Date DATE,
    End_Date DATE,
    Target_Category VARCHAR(100),
    Promo_Budget DECIMAL(18,2),
    Promo_ID_Status VARCHAR(20)
)


---Create Customer_Master TABLE
CREATE TABLE Customer_Master
(
    Customer_ID VARCHAR(50),
    City VARCHAR(100),
    Signup_Date DATE,
    Customer_Type VARCHAR(20),
    Customer_Record_Status VARCHAR(20)
)

-------------------------------------------------------------------------------
--- Verify the SQL schema

SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME
-----------------------------------------------------------
---VERIFY LOADED DATASETS

SELECT COUNT(*) AS TOTALROW_COUNT FROM PRODUCT_MASTER
SELECT COUNT(*) AS Customer_Count FROM Customer_Master;
SELECT COUNT(*) AS TOTALROW_COUNT FROM Inventory_Daily
SELECT COUNT(*) AS TOTALROW_COUNT FROM Returns
SELECT COUNT(*) AS TOTALROW_COUNT FROM Vendor_Supply
SELECT COUNT(*) AS TOTALROW_COUNT FROM Sales_Transactions
SELECT COUNT(*) AS TOTALROW_COUNT FROM Promotions

--------------------------------------------------------------
--Basic SQL Validation
SELECT TABLE_NAME,COLUMN_NAME,DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN
(
    'Sales_Transactions',
    'Product_Master',
    'Inventory_Daily',
    'Returns',
    'Vendor_Supply',
    'Promotions',
    'Customer_Master'
)
ORDER BY TABLE_NAME, ORDINAL_POSITION

----Verify Identity Columns
SELECT TABLE_NAME,COLUMN_NAME,
    COLUMNPROPERTY(OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME),COLUMN_NAME,'IsIdentity') AS IsIdentity
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN
('Sales_Transactions','Vendor_Supply')
AND COLUMN_NAME IN
('Sales_ID','Vendor_Supply_ID')

---------------------------------------------------------------
--Mandatory SQL Task 1: Top 10 Profit-Leaking SKUs
/*We already know 1,990 sales records don't have a matching Product_Master SKU, so those records cannot give us a reliable Unit_Cost.
SQL arithmetic with NULL produces NULL.*/
---------------------------------------------------------------
SELECT P.SKU_ID, P.SKU_NAME, P.CATEGORY,
--TOTAL SALES BEFORE DISCOUNT
SUM(S.Quantity*S.Selling_Price) AS GROSS_SALES,
-- Total discount given
SUM(S.Discount_Amount) AS TOTAL_DISCOUNT,
-- SALES AFTER DISCOUNT
SUM(S.Quantity*S.Selling_Price-S.Discount_Amount) AS NET_SALES,
-- Cost of GOODS sold
SUM(S.Quantity*P.Unit_Cost) AS COGS,
 -- Profit after discount and product cost
 SUM((S.Quantity * S.Selling_Price)- S.Discount_Amount- (S.Quantity * P.Unit_Cost)) AS GROSS_PROFIT
FROM Sales_Transactions S
INNER JOIN Product_Master P
ON S.SKU_ID=P.SKU_ID
WHERE S.Order_Status = 'Delivered' AND S.Negative_Quantity_Flag <> 'Yes' AND s.Selling_Price IS NOT NULL
  AND p.Unit_Cost IS NOT NULL
GROUP BY  P.SKU_NAME,P.SKU_ID, P.Category
ORDER BY Gross_Profit ASC


-------------------------------------------------------------------
---Add return/refund impact FOR PROFITS need to account for the money refunded to customers.
-- Create the return totals by SKU

SELECT   SKU_ID, SUM(Refund_Amount) AS TOTAL_REFUND
FROM Returns
WHERE Return_Status = 'Approved'
GROUP BY SKU_ID
-----------------------------------------------------------------
-- NEXT â€” Combine Sales Profit + Returns
--SKU may look profitable from sales alone but become much less profitable after customers return the product.
WITH RETURN_BY_SKU AS
( 
SELECT SKU_ID, SUM(REFUND_AMOUNT) AS TOTAL_REFUND FROM Returns 
WHERE Return_Status='Approved'
group by SKU_ID
)

select S.SKU_ID, P.SKU_NAME,P.CATEGORY,
-- SALES BEFORE DISCOUNT
SUM(S.QUANTITY*S.SELLING_PRICE) AS GROSS_SALES,
--TOTAL DISCOUNT
SUM(S.Discount_Amount) AS TOTAL_DISCOUNT,
--SALES AFTER DISCOUNT
SUM((S.QUANTITY*S.SELLING_PRICE)-S.Discount_Amount) AS NET_SALES,
-- COST OF GOODS SOLD
SUM(S.QUANTITY*P.Unit_Cost) AS COGS,
-- PROFITS AFTER DISCOUNT AND COGS
SUM((S.Quantity*S.Selling_Price) - (S.Discount_Amount) - (S.Quantity*P.Unit_Cost)) AS GROSS_PROFITS,
COALESCE(R.TOTAL_REFUND,0) AS TOTAL_REFUND,
-- FINAL PROFIT AFTER DISCOUNT AND REFUND
  SUM((S.Quantity * S.Selling_Price) - S.Discount_Amount- (S.Quantity * P.Unit_Cost)) - COALESCE(R.TOTAL_REFUND, 0) AS NET_PROFIT
FROM Sales_Transactions S
INNER JOIN Product_Master P ON S.SKU_ID=P.SKU_ID
LEFT JOIN RETURN_BY_SKU R ON S.SKU_ID=R.SKU_ID 
WHERE S.Order_Status='Delivered'
and S.Negative_Quantity_Flag<>'YES' AND P.Unit_Cost > 0  and S.Selling_Price is not null
GROUP BY S.SKU_ID, P.SKU_NAME,P.CATEGORY,R.TOTAL_REFUND
ORDER BY NET_PROFIT ASC


/*very strong example of:  Good sales volume but negative profitability.
SKU00877- COGS is actually higher than the net sales. Refund = ₹7,544.42--> pushes it to: Net Profit = -₹9,935.97
SKU00766- It is selling nearly ₹70K.--> COGS almost consumes all net sales ₹59,526 -> Returns eliminate the remaining profit  ₹285 − ₹7,800 = -₹7,515
*/
-------------------------------------------------------------------------------------------------------------------

--Calculate Net Margin %
WITH RETURN_BY_SKU AS 
(
SELECT SKU_ID, SUM(Refund_Amount) AS TOTAL_REFUND FROM Returns
WHERE Return_Status='Approved'
group by SKU_ID
),
SKU_PROFIT AS
(
SELECT S.SKU_ID, P.SKU_NAME, P.Category,
-- SALES BEFORE DISCOUNT
SUM(S.Quantity*S.Selling_Price) AS GROSS_SALES,
-- TOTAL DISCOUNT
SUM(S.Discount_Amount) AS TOTAL_DISCOUNT,
-- SALES AFTER DISCOUNT
SUM((S.Quantity* S.Selling_Price) - S.DISCOUNT_AMOUNT) AS NET_SALES,
--COST OF GOODS SOLD
SUM(S.Quantity*P.Unit_Cost) AS COGS,
-- SALES AFTER DISCOUNT AND COGS
SUM((S.Quantity*S.Selling_Price) - (S.Discount_Amount) - (S.Quantity*P.Unit_Cost)) AS GROSS_PROFITS,
COALESCE (R.TOTAL_REFUND,0) AS TOTAL_REFUND,
 SUM((S.Quantity * S.Selling_Price)- S.Discount_Amount- (S.Quantity * P.Unit_Cost))- COALESCE(R.TOTAL_REFUND, 0) AS NET_PROFIT
FROM Sales_Transactions S
INNER JOIN Product_Master P ON S.SKU_ID=P.SKU_ID
LEFT JOIN RETURN_BY_SKU R ON S.SKU_ID=R. SKU_ID
WHERE S.Order_Status = 'Delivered' AND S.Negative_Quantity_Flag <> 'Yes' AND s.Selling_Price IS NOT NULL AND P.Unit_Cost > 0 
GROUP BY   S.SKU_ID, P.SKU_NAME,P.CATEGORY,R.TOTAL_REFUND
)
SELECT * , ROUND((NET_PROFIT/NULLIF(NET_SALES,0))*100,2) AS NET_MARGIN_PROFITS FROM SKU_PROFIT
ORDER BY NET_PROFIT
--------------------------------------------------------
---Top 10 profit leaking SKUs.
-- DURING VALIDATION WE FOUND 12 RECORDS IN PRODUCT_MASTER HAD MISSING UNIT_COST WHICH WOULD DISTORT PROFITS CALCULATION 
-- SO APPLIED CONDITION WHERE UNIT_COST>0
-- what are we doing: Sales-->join Product--> join Return_by_SKU CTE--> group bby sku_id,total_refund,etc
alter VIEW vw_Profit_Leakage
AS
WITH Return_By_SKU AS
(SELECT SKU_ID,SUM(Refund_Amount) AS TOTAL_REFUND
FROM Returns
WHERE Return_Status = 'Approved'
GROUP BY SKU_ID
)
SELECT P.SKU_ID,  P.SKU_NAME, P.CATEGORY,
SUM(S.Quantity * S.Selling_Price) AS GROSS_SALES,
SUM(S.Discount_Amount) AS TOTAL_DISCOUNT,
SUM((S.Quantity * S.Selling_Price)- S.Discount_Amount) AS NET_SALES,
SUM(S.Quantity * P.Unit_Cost) AS COGS,
SUM((S.Quantity * S.Selling_Price)- S.Discount_Amount- (S.Quantity * P.Unit_Cost)) AS GROSS_PROFIT,
COALESCE(R.TOTAL_REFUND, 0) AS TOTAL_REFUND,
SUM((S.Quantity * S.Selling_Price)- S.Discount_Amount- (S.Quantity * P.Unit_Cost))- COALESCE(R.TOTAL_REFUND, 0) AS NET_PROFIT,
ROUND((SUM((S.Quantity * S.Selling_Price)- S.Discount_Amount- (S.Quantity * P.Unit_Cost))
            - COALESCE(R.TOTAL_REFUND, 0))/NULLIF(SUM((S.Quantity * S.Selling_Price)- S.Discount_Amount),0)* 100,2) AS NET_MARGIN_PERCENT
FROM Sales_Transactions S
-- you need Unit_Cost, SKU_Name, Category from Product_Master SO INNER JOIN 
INNER JOIN Product_Master P ON S.SKU_ID = P.SKU_ID
-- IF SKU3 has NO returndata so NO total_refund then coalesce replace with 0. BUT with INNER JOIN Salesdata SKU3 would BE REMOVED. 
LEFT JOIN Return_By_SKU R ON S.SKU_ID = R.SKU_ID
WHERE S.Order_Status = 'Delivered' AND S.Negative_Quantity_Flag <> 'Yes' AND P.Unit_Cost > 0 AND s.Selling_Price IS NOT NULL
GROUP BY P.SKU_ID, P.SKU_NAME, P.CATEGORY, R.TOTAL_REFUND;



SELECT TOP 10 *
FROM vw_Profit_Leakage
ORDER BY NET_PROFIT ASC;


-- company wide profit bridge:
SELECT
    SUM(GROSS_SALES) AS TOTAL_GROSS_SALES,
    SUM(TOTAL_DISCOUNT) AS TOTAL_DISCOUNT,
    SUM(NET_SALES) AS TOTAL_NET_SALES,
    SUM(COGS) AS TOTAL_COGS,
    SUM(GROSS_PROFIT) AS TOTAL_GROSS_PROFIT,
    SUM(TOTAL_REFUND) AS TOTAL_REFUND,
    SUM(NET_PROFIT) AS TOTAL_NET_PROFIT,
    ROUND(SUM(TOTAL_DISCOUNT) / NULLIF(SUM(GROSS_SALES), 0) * 100, 2) AS DISCOUNT_RATE_PERCENT,
    ROUND(SUM(COGS) / NULLIF(SUM(NET_SALES), 0) * 100, 2) AS COGS_PERCENT_ofnetsales,
    ROUND(SUM(TOTAL_REFUND) / NULLIF(SUM(NET_SALES), 0) * 100, 2) AS REFUND_PERCENT_ofnetsales,
    ROUND(SUM(NET_PROFIT) / NULLIF(SUM(NET_SALES), 0) * 100, 2) AS NET_MARGIN_PERCENT_ofnetsales
FROM vw_Profit_Leakage;

------------------------------------------------------------------------
---- 2ND mandatory SQL task: Stores with Highest Discount Abuse mandatory SQL task.
/*We shouldn't simply rank by total discount because a large store naturally gives more discounts.
Discount Rate % = (Total Discount / Gross Sales) * 100
HOW MUCH the store is giving away its gross sales through discounts.
I HAVE APPLIED Discount-abuse store = DISCOUNT_RATE_PERCENT > 10%
*/

SELECT  s.STORE_ID, COUNT(*) AS returns_APPROVED,SUM(s.QUANTITY*s.SELLING_PRICE) AS GROSS_SALES,
SUM(s.Discount_Amount) AS TOTAL_DISCOUNT , 
  -- Sales after discount
SUM((s.Quantity * s.Selling_Price)- s.Discount_Amount) AS NET_SALES,
ROUND(SUM(s.Discount_Amount)/NULLIF(SUM(s.QUANTITY*s.SELLING_PRICE),0)* 100,2) AS DISCOUNT_RATE_PERCENT
FROM Sales_Transactions s left join Product_Master p on p.sku_id=s.sku_id
WHERE Order_Status = 'Delivered' AND Negative_Quantity_Flag <> 'Yes' and Selling_Price IS NOT NULL
GROUP BY s.STORE_ID
HAVING  (SUM(s.Discount_Amount)/ 
-- if grosssales=0 then to avoid crashing
NULLIF(SUM(s.Quantity * s.Selling_Price), 0)* 100 > 10)
ORDER BY DISCOUNT_RATE_PERCENT DESC

----------------------------------------------------------------------------
---MANDATORY TASK 3: Category-wise Return Contribution to Loss
/*Which categories have the largest total approved refund amount?*/

-- Start with category wise return loss
SELECT P.CATEGORY ,
COUNT(*) AS returns_APPROVED,
SUM(R.Refund_Amount) AS TOTAL_RETURN_LOSS
FROM Product_Master P
INNER JOIN RETURNS R ON P.SKU_ID=R.SKU_ID
WHERE Return_Status='Approved' 
group BY P.Category
ORDER BY TOTAL_RETURN_LOSS DESC

---need one more metric: from total_return_loss what percentage of the return loss comes from each category?
-- example, 100 total return_loss/ dairy's loss 10--> 10% 
SELECT P.CATEGORY,
COUNT(*) AS TOTAL_RETURNS_APPROVED,
SUM(R.Refund_Amount) AS return_loss_by_category,
sum(SUM(R.Refund_Amount)) over() AS total_return_loss,
ROUND(SUM(R.Refund_Amount)/NULLIF((SELECT SUM(REFUND_AMOUNT) FROM RETURNS WHERE Return_Status='Approved'),0)*100,2) as RETURN_CONTRIBUTION_PERCENT
FROM RETURNS R
INNER JOIN Product_Master P ON P.SKU_ID=R.SKU_ID
WHERE Return_Status='Approved'
group BY P.Category
ORDER BY RETURN_CONTRIBUTION_PERCENT DESC


--Groceries IS TOP contributes 14.50% of the total approved return loss, with 218,419.32 in refunds.

--------------------------------------------------------------------------------------------------------------------------------------------

---Mandatory SQL task: Promotion-wise profitability ranking.
/*Which promotions generated profit, and which promotions resulted in poor profitability?

Incremental profit" mean here?

It means the additional profit generated because of the promotion, compared with what would have happened without the promotion.

-- Promo ROI % = Profit After Promotion Budget Ã· Promo Budget Ã— 100*/
--
WITH Non_Promoted_SKUs AS
( 
SELECT DISTINCT SKU_ID
FROM Sales_Transactions
    WHERE Promo_ID IS NULL AND Order_Status = 'Delivered' AND Negative_Quantity_Flag <> 'Yes'
)

SELECT COUNT(DISTINCT CASE WHEN S.Promo_ID IS NOT NULL THEN S.SKU_ID END) AS PROMOTED_SKUS,
COUNT(DISTINCT CASE WHEN S.Promo_ID IS NULL THEN S.SKU_ID END) AS NON_PROMOTED_SKUS,
COUNT(DISTINCT CASE WHEN S.Promo_ID IS NOT NULL AND N.SKU_ID IS NOT NULL THEN S.SKU_ID END) AS PROMOTED_SKUS_WITH_BASELINE
FROM Sales_Transactions S
LEFT JOIN Non_Promoted_SKUs N ON S.SKU_ID = N.SKU_ID
WHERE S.Order_Status = 'Delivered' AND S.Negative_Quantity_Flag <> 'Yes';

  --Calculate the baseline profit
  /*--Before calculating Promo ROI, What was the normal profit per unit for each SKU when there was no promotion?
  Promo ROI = incremental profit / promo budget but does not specify how to calculate the baseline
  SO I useD non-promoted sales of the same SKU as the baseline.*/

-- This query asks--> For every SKU, determine its normal sales quantity, selling price, unit cost, and normal profit per unit using non-promotional delivered sales.
SELECT S.SKU_ID,
-- How many units of this SKU were sold when there was no promotion ->gives us an idea of normal demand.
SUM(S.Quantity) AS NON_PROMO_QUANTITY,
-- Average selling price without promotion
AVG(S.Selling_Price) AS AVG_NON_PROMO_SellPRICE,
 -- Unit cost of the SKU
MAX(PM.Unit_Cost) AS UNIT_COST,
-- Average normal profit per unit
AVG(S.Selling_Price - PM.Unit_Cost) AS AVG_BASELINE_PROFIT
FROM Sales_Transactions S
INNER JOIN Product_Master PM ON S.SKU_ID = PM.SKU_ID
WHERE S.Promo_ID IS NULL AND S.Order_Status = 'Delivered' AND S.Negative_Quantity_Flag <> 'Yes' AND PM.Unit_Cost > 0 and s.Selling_Price is not null and s.sku_id='sku00865'
GROUP BY S.SKU_ID;

---- Calculate Incremental Profit ------------
-- 1st calculate normal profit(i.e, without promotionsale)
WITH Baseline_Profit AS
(SELECT S.SKU_ID,
-- total profit from the SKU's non-promotional sales.
SUM((S.Quantity * S.Selling_Price) - S.Discount_Amount - (S.Quantity * PM.Unit_Cost) ) AS BASELINE_TOTAL_PROFIT,
-- Total normal quantity sold without promotion
SUM(S.Quantity) AS BASELINE_QUANTITY
FROM Sales_Transactions S
INNER JOIN Product_Master PM ON S.SKU_ID = PM.SKU_ID
WHERE S.Promo_ID IS NULL AND S.Order_Status = 'Delivered' AND S.Negative_Quantity_Flag <> 'Yes' AND PM.Unit_Cost > 0 AND S.Quantity > 0 and s.Selling_Price is not null
GROUP BY S.SKU_ID
),
-- this takes the previous result and converts total baseline profit into BaselineProfit_Per_Unit
Baseline_Per_Unit AS
(SELECT SKU_ID,
-- Normal profit earned per unit /*- EXAMPLE: Normal profit = ₹10,000, Normal quantity = 500 Then: ₹10,000 ÷ 500 = ₹20 normal profit per unit*/
BASELINE_TOTAL_PROFIT / NULLIF(BASELINE_QUANTITY, 0) AS BASELINE_PROFIT_PER_UNIT
FROM Baseline_Profit
)
-- here your query actually switches from baseline to how did each promotion performance.
SELECT S.Promo_ID,s.sku_id,
-- Total quantity sold under the each promotion
SUM(S.Quantity) AS PROMO_QUANTITY,
-- Actual profit generated during the promotion is running
SUM((S.Quantity * S.Selling_Price)- S.Discount_Amount- (S.Quantity * PM.Unit_Cost)) AS PROMO_PROFIT,
-- If these same profit_per_unit for every SKU sold, then how much profit would we have expected
/*Example: A SKU001 normal basline_profit is ₹20 per unit.
that SKU sells 1,000 quantities during promotion.
Expected baseline profit: 1,000 × ₹20 = ₹20,000*/
SUM(S.Quantity * B.BASELINE_PROFIT_PER_UNIT) AS BASELINE_EXPECTED_PROFIT,
-- Additional profit generated (during promotion) compared with baseline_expected_profit
SUM((S.Quantity * S.Selling_Price)- S.Discount_Amount- (S.Quantity * PM.Unit_Cost))-SUM(S.Quantity * B.BASELINE_PROFIT_PER_UNIT) AS INCREMENTAL_PROFIT
FROM Sales_Transactions S
INNER JOIN Product_Master PM ON S.SKU_ID = PM.SKU_ID
-- inner join because For every promotional sale, find the normal profit per unit of that same SKU.
INNER JOIN Baseline_Per_Unit B ON S.SKU_ID = B.SKU_ID
WHERE S.Promo_ID IS NOT NULL AND S.Order_Status = 'Delivered' AND S.Negative_Quantity_Flag <> 'Yes' AND PM.Unit_Cost > 0 AND S.Quantity > 0 and s.Selling_Price is not null
GROUP BY S.Promo_ID, s.sku_id
ORDER BY INCREMENTAL_PROFIT DESC;
/*EXAMPLE PR0181 specifically on SKU00865-->what we get:
SKU00865                       Normal basline_profit (12450)/unit = ₹108
Promotion                      PR00181
Quantity sold(at promotion)    6
Expected profit                ₹108 * 6 = 649
Actual promotional profit      ₹ 1595
Incremental profit             ₹ 1595 - 649 = 806
Positive incremental profit:   Promotion performed better than normal.
Negative incremental profit:   Promotion performed worse than normal.*/

-----Now we can finally calculate the Promo ROI required by the PDF: Promo ROI = Incremental Profit / Promo Budget
-- Calculate normal SKU profitability from non-promotional sales.
-- reult is one row per promotion.
alter VIEW vw_Promotion_ROI
AS
WITH Baseline_Profit AS
(
SELECT S.SKU_ID,
-- Total normal profit generated without promotion
SUM((S.Quantity * S.Selling_Price)- S.Discount_Amount - (S.Quantity * PM.Unit_Cost)) AS BASELINE_TOTAL_PROFIT,
-- Total normal quantity sold without promotion
SUM(S.Quantity) AS BASELINE_QUANTITY
FROM Sales_Transactions S
INNER JOIN Product_Master PM ON S.SKU_ID = PM.SKU_ID
WHERE S.Promo_ID IS NULL AND S.Order_Status = 'Delivered' AND S.Negative_Quantity_Flag <> 'Yes'AND PM.Unit_Cost > 0 AND S.Quantity > 0 and s.Selling_Price is not null
GROUP BY S.SKU_ID
),
-- normal profit per unit.
Baseline_Per_Unit AS
(
SELECT SKU_ID,
-- Normal profit earned per unit
BASELINE_TOTAL_PROFIT / NULLIF(BASELINE_QUANTITY, 0) AS BASELINE_PROFIT_PER_UNIT
FROM Baseline_Profit
)
SELECT S.Promo_ID,
-- Total quantity sold under the promotion
SUM(S.Quantity) AS PROMO_QUANTITY,
-- Actual profit generated during the promotion
SUM((S.Quantity * S.Selling_Price) - S.Discount_Amount - (S.Quantity * PM.Unit_Cost)) AS PROMO_PROFIT,
-- Expected profit if those units had performed at their normal SKU-level profitability.
SUM(S.Quantity * B.BASELINE_PROFIT_PER_UNIT) AS BASELINE_EXPECTED_PROFIT,
-- This is the economic benefit/loss caused by the promotion relative to normal performance.
SUM((S.Quantity * S.Selling_Price) - S.Discount_Amount- (S.Quantity * PM.Unit_Cost)) -
SUM(S.Quantity * B.BASELINE_PROFIT_PER_UNIT) AS INCREMENTAL_PROFIT,
-- Promotion budget
MAX(P.Promo_Budget) AS PROMO_BUDGET,
-- Promo ROI
ROUND((SUM((S.Quantity * S.Selling_Price) - S.Discount_Amount- (S.Quantity * PM.Unit_Cost))-SUM(S.Quantity * B.BASELINE_PROFIT_PER_UNIT))/ 
NULLIF(MAX(P.Promo_Budget), 0)* 100,2) AS PROMO_ROI_PERCENT
FROM Sales_Transactions S
INNER JOIN Product_Master PM ON S.SKU_ID = PM.SKU_ID
INNER JOIN Baseline_Per_Unit B ON S.SKU_ID = B.SKU_ID
-- Sales table tells you which promotion was used, the Promotions table gives you the Promo_Budget.
INNER JOIN Promotions P ON S.Promo_ID = P.Promo_ID
WHERE S.Promo_ID IS NOT NULL AND S.Order_Status = 'Delivered' AND S.Negative_Quantity_Flag <> 'Yes' AND PM.Unit_Cost > 0 AND S.Quantity > 0 and s.Selling_Price is not null
GROUP BY S.Promo_ID

--- test view
SELECT *
FROM vw_Promotion_ROI
ORDER BY PROMO_ROI_PERCENT DESC;

------------------------------------------------------------------------------------------------------------------------
------ Mandatory SQL Task 5 Vendor Delay Heatmap Dataset
/*A heatmap needs two dimensions that we can place on the rows and columns.
view produces one row per Vendor_ID + Store_ID combination*/

CREATE VIEW vw_Vendor_Delay_Heatmap
AS
-- Total valid purchase orders for that vendor-store combination.
SELECT Vendor_ID, Store_ID,
-- Total purchase orders with valid delivery dates
COUNT(*) AS TOTAL_PO_COUNT,
-- Number of purchase orders delivered late
SUM(CASE WHEN Actual_Delivery_Date > Expected_Delivery_Date THEN 1 ELSE 0 END) AS LATE_PO_COUNT,
-- Calculates the average delay only among late POs.
ROUND(AVG( CASE WHEN Actual_Delivery_Date > Expected_Delivery_Date THEN Delay_Days END),2) AS AVG_DELAY_DAYS,
-- Percentage of purchase orders delivered late
ROUND(SUM(CASE WHEN Actual_Delivery_Date > Expected_Delivery_Date THEN 1 ELSE 0 END)* 100.0/ COUNT(*),2) AS SLA_BREACH_PERCENT
FROM Vendor_Supply
WHERE PO_Date IS NOT NULL AND Expected_Delivery_Date IS NOT NULL AND Actual_Delivery_Date IS NOT NULL
GROUP BY Vendor_ID, Store_ID
    

-- VERIFY THE VIEW
SELECT * FROM vw_Vendor_Delay_Heatmap
ORDER BY SLA_BREACH_PERCENT DESC

-------------------------------------------------------------------------------------------------------------------------------------------
--- Mandatory SQL Task 6  Stockout Frequency per SKU-Store.
/*How many different days did each SKU run out of stock at each store while customers were still demanding it?
Stockout Frequency = number of distinct dates on which a SKU-store experienced a stockout while demand existed. */

SELECT I.SKU_ID, I.Store_ID,
-- Number of distinct days when stock was zero
-- while delivered positive demand existed
COUNT(DISTINCT I.Date) AS STOCKOUT_DAYS
FROM Inventory_Daily I
WHERE I.Closing_Stock = 0
AND EXISTS
(
SELECT 1
FROM Sales_Transactions S
WHERE S.SKU_ID = I.SKU_ID
AND S.Store_ID = I.Store_ID
AND S.Order_Date = I.Date
-- Only completed sales represent actual demand
AND S.Order_Status = 'Delivered'
-- Exclude the known negative-quantity records
AND S.Negative_Quantity_Flag <> 'Yes'
-- Demand must be positive
AND S.Quantity > 0)
GROUP BY I.SKU_ID, I.Store_ID
ORDER BY STOCKOUT_DAYS DESC;

---- Stockout Loss Estimate -> How much potential sales were lost because of those stockouts?
-- Now this query gives the financial impact OF ABOVE QUERY

CREATE VIEW vw_Stockout_Loss
AS
SELECT I.SKU_ID, I.Store_ID, I.Date AS STOCKOUT_DATE,
SUM(S.Quantity) AS DEMAND_QUANTITY, AVG(S.Selling_Price) AS AVG_SELLING_PRICE,
SUM(S.Quantity * S.Selling_Price) AS POTENTIAL_LOST_SALES
FROM Inventory_Daily I
INNER JOIN Sales_Transactions S ON I.SKU_ID = S.SKU_ID AND I.Store_ID = S.Store_ID
    AND I.Date = S.Order_Date
WHERE I.Closing_Stock = 0 AND S.Order_Status = 'Delivered'
  AND S.Negative_Quantity_Flag <> 'Yes' AND S.Quantity > 0 AND S.Selling_Price IS NOT NULL
GROUP BY I.SKU_ID, I.Store_ID, I.Date

----- test it
SELECT * FROM vw_Stockout_Loss;

-------------------------------------------------------------------------------------------------------------------------------------------
------ Mandatory SQL Task 7: Customer Cohorts
/* A cohort is a group of customers who started purchasing during the same month.
M0 = customer's first purchase month
M1 = one month after first purchase
M2 = two months after first purchase
*/

SELECT Customer_ID, MIN( DATEFROMPARTS(YEAR(Order_Date),MONTH(Order_Date),1)) AS COHORT_MONTH
FROM Sales_Transactions
WHERE Order_Status = 'Delivered' AND Negative_Quantity_Flag <> 'Yes'
        AND Quantity > 0 AND Customer_ID IS NOT NULL AND Order_Date IS NOT NULL
GROUP BY Customer_ID;

---- Identify M0, M1 and M2 purchases
WITH Customer_Cohort AS
(
SELECT
Customer_ID, MIN(DATEFROMPARTS(YEAR(Order_Date),MONTH(Order_Date),1)
) AS COHORT_MONTH
FROM Sales_Transactions
WHERE Order_Status = 'Delivered' AND Negative_Quantity_Flag <> 'Yes'
      AND Quantity > 0 AND Customer_ID IS NOT NULL AND Order_Date IS NOT NULL
GROUP BY Customer_ID
),

Customer_Purchases AS
(
SELECT DISTINCT Customer_ID,DATEFROMPARTS( YEAR(Order_Date), MONTH(Order_Date),1) AS PURCHASE_MONTH
FROM Sales_Transactions
WHERE Order_Status = 'Delivered' AND Negative_Quantity_Flag <> 'Yes' AND Quantity > 0 AND Customer_ID IS NOT NULL
      AND Order_Date IS NOT NULL
)
SELECT C.Customer_ID, C.COHORT_MONTH, P.PURCHASE_MONTH,
DATEDIFF( MONTH,C.COHORT_MONTH,P.PURCHASE_MONTH) AS MONTH_NUMBER
FROM Customer_Cohort C
INNER JOIN Customer_Purchases P ON C.Customer_ID = P.Customer_ID
ORDER BY C.Customer_ID, P.PURCHASE_MONTH;

--- Calculate M0, M1 and M2 repeat rates
WITH Cohort AS
(
SELECT Customer_ID, MIN(DATEFROMPARTS(YEAR(Order_Date), MONTH(Order_Date), 1)) AS Cohort_Month
FROM Sales_Transactions
WHERE Order_Status = 'Delivered' AND Negative_Quantity_Flag <> 'Yes' AND Quantity > 0
      AND Customer_ID IS NOT NULL AND Order_Date IS NOT NULL
GROUP BY Customer_ID
),
Purchases AS
(
SELECT DISTINCT S.Customer_ID, C.Cohort_Month, DATEDIFF( MONTH, C.Cohort_Month, DATEFROMPARTS(YEAR(S.Order_Date), MONTH(S.Order_Date), 1) ) AS Month_No
FROM Sales_Transactions S JOIN Cohort C
ON S.Customer_ID = C.Customer_ID
WHERE S.Order_Status = 'Delivered' AND S.Negative_Quantity_Flag <> 'Yes' AND S.Quantity > 0 AND S.Order_Date IS NOT NULL
)
SELECT Cohort_Month,
COUNT(DISTINCT CASE WHEN Month_No = 0 THEN Customer_ID END) AS M0,
COUNT(DISTINCT CASE WHEN Month_No = 1 THEN Customer_ID END) AS M1,
COUNT(DISTINCT CASE WHEN Month_No = 2 THEN Customer_ID END) AS M2,
ROUND(COUNT(DISTINCT CASE WHEN Month_No = 1 THEN Customer_ID END)
        * 100.0 /NULLIF(COUNT(DISTINCT CASE WHEN Month_No = 0 THEN Customer_ID END), 0),
        2 ) AS M1_Repeat_Rate,
ROUND(COUNT(DISTINCT CASE WHEN Month_No = 2 THEN Customer_ID END)
        * 100.0 / NULLIF(COUNT(DISTINCT CASE WHEN Month_No = 0 THEN Customer_ID END), 0),2) AS M2_Repeat_Rate
FROM Purchases
GROUP BY Cohort_Month
ORDER BY Cohort_Month;

----------------------------------------------------------------------------------------------------------------------

----- mandatory SQL Task 8 â€” RFM Scoring
/*RFM =

R â€” Recency: How recently did the customer purchase?
F â€” Frequency: How often did the customer purchase?
M â€” Monetary: How much did the customer spend?
*/
SELECT Customer_ID, DATEDIFF( DAY, MAX(Order_Date),
(
SELECT MAX(Order_Date)FROM Sales_Transactions
WHERE Order_Status = 'Delivered'AND Negative_Quantity_Flag <> 'Yes' AND Quantity > 0)
) AS RECENCY,
COUNT(DISTINCT Order_ID) AS FREQUENCY,
SUM((Quantity * Selling_Price) - Discount_Amount) AS MONETARY
FROM Sales_Transactions
WHERE Order_Status = 'Delivered' AND Negative_Quantity_Flag <> 'Yes' AND Quantity > 0 AND Customer_ID IS NOT NULL AND Order_Date IS NOT NULL
GROUP BY Customer_ID;

---- Convert RFM values into 1â€“5 scores
WITH RFM AS
(
SELECT Customer_ID, DATEDIFF( DAY, MAX(Order_Date),
( SELECT MAX(Order_Date) FROM Sales_Transactions
WHERE Order_Status = 'Delivered' AND Negative_Quantity_Flag <> 'Yes' AND Quantity > 0
)
) AS RECENCY,
COUNT(DISTINCT Order_ID) AS FREQUENCY,
SUM((Quantity * Selling_Price) - Discount_Amount) AS MONETARY
FROM Sales_Transactions
WHERE Order_Status = 'Delivered' AND Negative_Quantity_Flag <> 'Yes'
      AND Quantity > 0 AND Customer_ID IS NOT NULL AND Order_Date IS NOT NULL
      AND Selling_Price IS NOT NULL AND Discount_Amount IS NOT NULL
GROUP BY Customer_ID
),
RFM_Scored AS
(
SELECT *,
NTILE(5) OVER (ORDER BY RECENCY ASC) AS R_BUCKET,
NTILE(5) OVER (ORDER BY FREQUENCY ASC) AS F_SCORE,
NTILE(5) OVER (ORDER BY MONETARY ASC) AS M_SCORE
FROM RFM
)
SELECT Customer_ID, RECENCY, FREQUENCY,
    MONETARY, 6 - R_BUCKET AS R_SCORE, F_SCORE, M_SCORE,
    CONCAT(6 - R_BUCKET, F_SCORE, M_SCORE) AS RFM_SCORE,
    (6 - R_BUCKET) + F_SCORE + M_SCORE AS RFM_TOTAL
FROM RFM_Scored;

--------------------------------------------------------------------------------------
/*Fill Rate is defined as: supplied quantity / ordered quantity.
But your Vendor_Supply table contains Supplied_Quantity and does not contain Ordered_Quantity.

AND our Return Rate by VENDOR have no reliably calculable from the available source data because there is no direct Order_ID â†’ Vendor_ID relationship.
we should not invent an ordered quantity from sales data
*/

-----------------------------------------------------------------------------------------------------------------
---- Return Rate by Category:

/*We already calculated return loss contribution. Now we want to answer a different business question:

What percentage of delivered orders in each category resulted in an approved return?*/

SELECT P.Category,
COUNT(DISTINCT S.Order_ID) AS DELIVERED_ORDERS,
COUNT(DISTINCT CASE WHEN R.Return_Status = 'Approved' THEN R.Order_ID END ) AS APPROVED_RETURN_ORDERS,
ROUND( COUNT(DISTINCT CASE WHEN R.Return_Status = 'Approved' THEN R.Order_ID END ) * 100.0/ NULLIF(COUNT(DISTINCT S.Order_ID), 0),2 ) AS RETURN_RATE_PERCENT
FROM Sales_Transactions S
INNER JOIN Product_Master P ON S.SKU_ID = P.SKU_ID
LEFT JOIN Returns R ON S.Order_ID = R.Order_ID AND S.SKU_ID = R.SKU_ID
WHERE S.Order_Status = 'Delivered'
  AND S.Negative_Quantity_Flag <> 'Yes' AND S.Quantity > 0
GROUP BY P.Category
ORDER BY RETURN_RATE_PERCENT DESC;

-------------------------------------------------------------------------------------------------------------

-- View â€” for Power BI/Tableau:  vw_Return_Analysis

CREATE VIEW vw_Return_Analysis
AS
WITH Return_Loss AS
(
SELECT P.Category, COUNT(*) AS APPROVED_RETURN_COUNT, SUM(R.Refund_Amount) AS TOTAL_RETURN_LOSS
FROM Returns R
INNER JOIN Product_Master P ON R.SKU_ID = P.SKU_ID
WHERE R.Return_Status = 'Approved'
GROUP BY P.Category
),
Total_Return_Loss AS
(
SELECT
SUM(TOTAL_RETURN_LOSS) AS TOTAL_LOSS
FROM Return_Loss
),
Return_Rate AS
(
SELECT P.Category, COUNT(DISTINCT S.Order_ID) AS DELIVERED_ORDERS,
COUNT(DISTINCT CASE WHEN R.Return_Status = 'Approved' THEN R.Order_ID END ) AS APPROVED_RETURN_ORDERS
FROM Sales_Transactions S
INNER JOIN Product_Master P ON S.SKU_ID = P.SKU_ID
LEFT JOIN Returns R ON S.Order_ID = R.Order_ID AND S.SKU_ID = R.SKU_ID
WHERE S.Order_Status = 'Delivered' AND S.Negative_Quantity_Flag <> 'Yes' AND S.Quantity > 0
GROUP BY P.Category
)
SELECT L.Category, L.APPROVED_RETURN_COUNT, L.TOTAL_RETURN_LOSS,
ROUND( L.TOTAL_RETURN_LOSS * 100.0/ NULLIF(T.TOTAL_LOSS, 0),2) AS RETURN_LOSS_CONTRIBUTION_PERCENT,
R.DELIVERED_ORDERS, R.APPROVED_RETURN_ORDERS,
ROUND(R.APPROVED_RETURN_ORDERS * 100.0/ NULLIF(R.DELIVERED_ORDERS, 0),2) AS RETURN_RATE_PERCENT
FROM Return_Loss L
CROSS JOIN Total_Return_Loss T
INNER JOIN Return_Rate R ON L.Category = R.Category;
---m validate view
SELECT *
FROM vw_Return_Analysis
ORDER BY TOTAL_RETURN_LOSS DESC;

-------------------------------------------------------------------------------------------------------------

WITH MonthlySalesProfit AS
(
SELECT DATEFROMPARTS( YEAR(S.Order_Date), MONTH(S.Order_Date), 1) AS Profit_Month,
SUM((S.Quantity * S.Selling_Price) - S.Discount_Amount - (S.Quantity * P.Unit_Cost)) AS Gross_Profit
FROM Sales_Transactions S
INNER JOIN Product_Master P
ON S.SKU_ID = P.SKU_ID
WHERE S.Order_Status = 'Delivered' AND S.Negative_Quantity_Flag <> 'Yes' AND S.Quantity > 0 AND P.Unit_Cost > 0
GROUP BY DATEFROMPARTS(YEAR(S.Order_Date),MONTH(S.Order_Date),1)
),
MonthlyReturns AS
(  SELECT DATEFROMPARTS(YEAR(R.Return_Date),MONTH(R.Return_Date),1) AS Profit_Month,
SUM(R.Refund_Amount) AS Return_Loss
FROM Returns R WHERE R.Return_Status = 'Approved' AND R.Return_Date IS NOT NULL
GROUP BY DATEFROMPARTS(YEAR(R.Return_Date),MONTH(R.Return_Date),1)
)
SELECT S.Profit_Month, S.Gross_Profit, ISNULL(R.Return_Loss, 0) AS Return_Loss,
    S.Gross_Profit - ISNULL(R.Return_Loss, 0) AS Net_Profit
FROM MonthlySalesProfit S
LEFT JOIN MonthlyReturns R ON S.Profit_Month = R.Profit_Month
WHERE S.Profit_Month IS NOT NULL
ORDER BY S.Profit_Month;

---------------------------------------------------------------------------------
-- verify DOES FROM JULY REALLY THERE ARE LESS SALES?
SELECT DATEFROMPARTS( YEAR(Order_Date), MONTH(Order_Date), 1) AS Sales_Month,
COUNT(*) AS Transaction_Count, SUM(Quantity) AS Total_Quantity
FROM Sales_Transactions
WHERE Order_Date IS NOT NULL
GROUP BY DATEFROMPARTS( YEAR(Order_Date), MONTH(Order_Date),1)
ORDER BY Sales_Month


-----------------------------------------------------------------
-- check which vendor caused stockout?

SELECT Vendor_ID, SKU_ID, Store_ID, PO_Date, Expected_Delivery_Date,
    Actual_Delivery_Date, Supplied_Quantity, Delay_Days, SLA_Status
FROM Vendor_Supply
WHERE SKU_ID = 'SKU00081' AND Store_ID = 'CHE02'
ORDER BY Actual_Delivery_Date;