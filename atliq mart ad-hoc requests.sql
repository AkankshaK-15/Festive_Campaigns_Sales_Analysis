ALTER TABLE `retail_events_db`.`fact_events` 
CHANGE COLUMN `quantity_sold(after_promo)` `qty_sold_after_promo` INT NOT Null

ALTER TABLE `retail_events_db`.`fact_events` 
CHANGE COLUMN `quantity_sold(before_promo)` `qty_sold_before_promo` INT NOT Null


select distinct fe.product_code,
	   dp.product_name as High_value_products,
       fe.base_price
from fact_events fe
join dim_products dp
on fe.product_code = dp.product_code
where promo_type = 'BOGOF' and base_price > 500

------------------------------------------------------------------

select city,
       count(store_id) as No_of_stores
from dim_stores
group by city
order by No_of_stores desc

---------------------------------------------------------------------
with before_promo as
(
select campaign_id,
	   sum(base_price * qty_sold_before_promo) as revenue_before_promo
from fact_events
group by campaign_id
),
after_promo as
(
select campaign_id,
	   sum(case when promo_type = '33% OFF' then base_price*0.67*qty_sold_after_promo 
                when promo_type = '25% OFF' then base_price*0.75*qty_sold_after_promo 
                when promo_type = '50% OFF' then base_price*0.50*qty_sold_after_promo  
                when promo_type = '500 Cashback' then (base_price - 500)*qty_sold_after_promo  
                else base_price*qty_sold_after_promo 
			end ) as revenue_after_promo
from fact_events
group by campaign_id
)
select bp.campaign_id,
       round(bp.revenue_before_promo/1000000,1) as revenue_before_in_mln,
       round(ap.revenue_after_promo/1000000,1) as revenue_after_in_mln
from before_promo bp
join after_promo ap
using (campaign_id)

-----------------------------------------------------------------------------------------------------------------------
with sales as
(
select fe.campaign_id,
       dp.category,
	   sum(case when fe.promo_type = 'BOGOF'then fe.qty_sold_after_promo*2
                else fe.qty_sold_after_promo
			end) as sales_after_promo,
	   sum(fe.qty_sold_before_promo) as sales_before_promo
from fact_events fe
join dim_products dp
on fe.product_code = dp.product_code
group by dp.category,fe.campaign_id
)
select campaign_id,
       category,
       sales_before_promo,
       sales_after_promo,
       round((sales_after_promo - sales_before_promo)*100 / sales_before_promo,1) as incremental_sales_units_rate
from sales
order by campaign_id,incremental_sales_units_rate desc

------------------------------------------------------------------------------------------------------------------------
with before_rev as
(
select product_code,
       sum(base_price*qty_sold_before_promo) as rev_before
from fact_events 
group by product_code
),
after_rev as
(
select product_code,
       sum(case when promo_type = '33% OFF' then base_price*0.67*qty_sold_after_promo 
                when promo_type = '25% OFF' then base_price*0.75*qty_sold_after_promo 
                when promo_type = '50% OFF' then base_price*0.50*qty_sold_after_promo  
                when promo_type = '500 Cashback' then (base_price - 500)*qty_sold_after_promo  
                else base_price*qty_sold_after_promo 
			end ) as rev_after
from fact_events 
group by product_code
)
select br.product_code,
       dp.product_name,
       br.rev_before,
       ar.rev_after,
       round((ar.rev_after - br.rev_before)/1000000,1) as increase_in_rev_mln,
       round((rev_after - rev_before)*100/rev_before,1) as incremental_rev_rate
from before_rev br
join after_rev ar
on br.product_code = ar.product_code
join dim_products dp 
on dp.product_code = ar.product_code
order by incremental_rev_rate desc

       