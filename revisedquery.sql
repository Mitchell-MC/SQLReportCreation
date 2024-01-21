-- Initial Query to set up report table
USE wecloudrevenue;
CREATE TABLE IF NOT EXISTS report_table2 AS
SELECT 
    c.yr_wk_num AS Year_Week,
    ROUND(SUM(f.cost + f.datacost + f.revenue), 2) AS Gross,
    ROUND(SUM(f.revenue), 2) AS Net,
    ROUND(SUM(f.revenue) / SUM(f.cost + f.datacost + f.revenue) * 100, 2) AS Margin,
    ROUND(AVG(f.cost + f.datacost + f.revenue), 2) AS AVGD_Gross,
    ROUND(AVG(f.revenue), 2) AS AVGD_Net,
    ROUND((SUM(f.cost + f.datacost + f.revenue) - LAG(SUM(f.cost + f.datacost + f.revenue), 1) OVER (ORDER BY c.yr_wk_num)) / LAG(SUM(f.cost + f.datacost + f.revenue), 1) OVER (ORDER BY c.yr_wk_num) * 100, 0) AS PP_GROSS,
    ROUND((SUM(f.revenue) - LAG(SUM(f.revenue), 1) OVER (ORDER BY c.yr_wk_num)) / LAG(SUM(f.revenue), 1) OVER (ORDER BY c.yr_wk_num) * 100, 0) AS PP_Net
FROM
    fact_date_customer_campaign f
JOIN
    calendar c ON f.date = c.cal_dt
JOIN
    dim_customer dc ON f.customer_id = dc.customer_id
    -- Using simulated date instead of CURDATE() for scenario
WHERE
    c.cal_dt < DATE_SUB(DATE_SUB('2018-09-28', INTERVAL 1 YEAR), INTERVAL 1 DAY)
    AND dc.segment = 'Segment A'
GROUP BY
    c.yr_wk_num;


DELIMITER $$

DROP PROCEDURE IF EXISTS GenerateDailyReport2$$

CREATE PROCEDURE GenerateDailyReport2()
BEGIN
    DECLARE simulatedToday DATE;
    DECLARE startOfPreviousYear DATE;
    DECLARE sameDayPreviousYear DATE;
	-- In real scenario use CURDATE() instead of static date
    SET simulatedToday = '2018-10-30';
    SET startOfPreviousYear = MAKEDATE(YEAR(simulatedToday) - 1, 1);
    SET sameDayPreviousYear = MAKEDATE(YEAR(simulatedToday) - 1, DAYOFYEAR(simulatedToday));

    INSERT INTO wecloudrevenue.report_table2 (Year_Week, Gross, Net, Margin, AVGD_Gross, AVGD_Net, PP_GROSS, PP_Net)
	SELECT 
		c.yr_wk_num AS Year_Week,
		ROUND(SUM(f.cost + f.datacost + f.revenue), 2) AS Gross,
		ROUND(SUM(f.revenue), 2) AS Net,
		ROUND(SUM(f.revenue) / SUM(f.cost + f.datacost + f.revenue) * 100, 2) AS Margin,
		ROUND(AVG(f.cost + f.datacost + f.revenue), 2) AS AVGD_Gross,
		ROUND(AVG(f.revenue), 2) AS AVGD_Net,
		ROUND((SUM(f.cost + f.datacost + f.revenue) - LAG(SUM(f.cost + f.datacost + f.revenue), 1) OVER (ORDER BY c.yr_wk_num)) / LAG(SUM(f.cost + f.datacost + f.revenue), 1) OVER (ORDER BY c.yr_wk_num) * 100, 2) AS PP_GROSS,
		ROUND((SUM(f.revenue) - LAG(SUM(f.revenue), 1) OVER (ORDER BY c.yr_wk_num)) / LAG(SUM(f.revenue), 1) OVER (ORDER BY c.yr_wk_num) * 100, 2) AS PP_Net
	FROM
		fact_date_customer_campaign f
	JOIN
		calendar c ON f.date = c.cal_dt
	JOIN
		dim_customer dc ON f.customer_id = dc.customer_id
        -- USE f.date > previousUpdateDate AND f.date <= simulatedToday if report fails to run for sseveral days
	WHERE
		c.cal_dt = DATE_SUB(MAKEDATE(YEAR(simulatedToday) - 1, DAYOFYEAR(simulatedToday)), INTERVAL 1 DAY)
		AND dc.segment = 'Segment A'
	GROUP BY 
		c.yr_wk_num;
END$$

DELIMITER ;
CALL GenerateDailyReport2();
DROP EVENT IF EXISTS daily_report_event2;

CREATE EVENT IF NOT EXISTS daily_report_event2
ON SCHEDULE EVERY 1 DAY
STARTS '2018-09-24 05:00:00'
DO
  CALL GenerateDailyReport2();

-- Use the above to call the procedure outside of schedule
