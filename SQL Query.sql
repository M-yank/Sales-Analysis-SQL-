# Report For Croma (Customer) Transactions 

# Total Gross price & Required Fields
SELECT 
    	    s.date, 
            s.product_code, 
            p.product, 
            p.variant, 
            s.sold_quantity, 
            g.gross_price,
            ROUND(s.sold_quantity*g.gross_price,2) as gross_price_total
	FROM fact_sales_monthly s
	JOIN dim_product p
            ON s.product_code=p.product_code
	JOIN fact_gross_price g
            ON g.fiscal_year=get_fiscal_year(s.date)
    	AND g.product_code=s.product_code
	WHERE 
    	    customer_code=90002002 AND 
            get_fiscal_year(s.date)=2021     
	LIMIT 1000000;



#Total Sales Amount
SELECT 
            s.date, 
    	    SUM(ROUND(s.sold_quantity*g.gross_price,2)) as monthly_sales
	FROM fact_sales_monthly s
	JOIN fact_gross_price g
        ON g.fiscal_year=get_fiscal_year(s.date) AND g.product_code=s.product_code
	WHERE 
             customer_code=90002002
	GROUP BY date;
------------------------------------------------------------------------------------------------------------------------------------------------------------

# Creating a stored Procedure for Monthly  Gross Sales
CREATE DEFINER=`root`@`localhost` PROCEDURE `get_monthly_gross_sales_for_customer`(in_customer_codes TEXT)
BEGIN
SELECT 
                    s.date, 
                    SUM(ROUND(s.sold_quantity*g.gross_price,2)) as monthly_sales
        	FROM fact_sales_monthly s
        	JOIN fact_gross_price g
               	    ON g.fiscal_year=get_fiscal_year(s.date)
                    AND g.product_code=s.product_code
        	WHERE 
                    FIND_IN_SET(s.customer_code, in_customer_codes) > 0
        	GROUP BY s.date
        	#ORDER BY s.date DESC;
#END 

    
# Creating stored procedure for market badge (market badge. i.e. if total sold quantity > 5 million that market is considered "Gold" else "Silver"
CREATE DEFINER=`root`@`localhost` PROCEDURE `get_market_badge`(
        	IN in_market VARCHAR(45),
        	IN in_fiscal_year YEAR,
        	OUT out_level VARCHAR(45)
	)
BEGIN
             #DECLARE qty INT DEFAULT 0;
    
    	     # Default market is India
    	     IF in_market = "" THEN
              #    SET in_market="India";
             #END IF;
    
    	     # Retrieve total sold quantity for a given market in a given year
             SELECT 
                  SUM(s.sold_quantity) INTO qty
             FROM fact_sales_monthly s
             JOIN dim_customer c
             ON s.customer_code=c.customer_code
             WHERE 
                  get_fiscal_year(s.date)=in_fiscal_year AND
              #    c.market=in_market;
        
             # Determine Gold vs Silver status
             #IF qty > 5000000 THEN
               #   SET out_level = 'Gold';
            # ELSE
                #  SET out_level = 'Silver';
             #END IF;
	#END
    
   ------------------------------------------------------------------------------------------------------------------------------------------------------------ 

#Creating the view `sales_preinv_discount` and store all the data in like a virtual table
	CREATE  VIEW `sales_preinv_discount` AS
	SELECT 
    	    s.date, 
            s.fiscal_year,
            s.customer_code,
            c.market,
            s.product_code, 
            p.product, 
            p.variant, 
            s.sold_quantity, 
            g.gross_price as gross_price_per_item,
            ROUND(s.sold_quantity*g.gross_price,2) as gross_price_total,
            pre.pre_invoice_discount_pct
	FROM fact_sales_monthly s
	JOIN dim_customer c 
		ON s.customer_code = c.customer_code
	JOIN dim_product p
        	ON s.product_code=p.product_code
	JOIN fact_gross_price g
    		ON g.fiscal_year=s.fiscal_year
    		AND g.product_code=s.product_code
	JOIN fact_pre_invoice_deductions as pre
        	ON pre.customer_code = s.customer_code AND
    		pre.fiscal_year=s.fiscal_year

#Create a view for post invoice deductions: `sales_postinv_discount`
	CREATE VIEW `sales_postinv_discount` AS
	SELECT 
    	    s.date, s.fiscal_year,
            s.customer_code, s.market,
            s.product_code, s.product, s.variant,
            s.sold_quantity, s.gross_price_total,
            s.pre_invoice_discount_pct,
            (s.gross_price_total-s.pre_invoice_discount_pct*s.gross_price_total) as net_invoice_sales,
            (po.discounts_pct+po.other_deductions_pct) as post_invoice_discount_pct
	FROM sales_preinv_discount s
	JOIN fact_post_invoice_deductions po
		ON po.customer_code = s.customer_code AND
   		po.product_code = s.product_code AND
   		po.date = s.date;
        
        
#	creating the view `net_sales` which inbuiltly use/include all the previous created view and gives the final result
	CREATE VIEW `net_sales` AS
	SELECT 
            *, 
    	    net_invoice_sales*(1-post_invoice_discount_pct) as net_sales
	FROM gdb0041.sales_postinv_discount;







