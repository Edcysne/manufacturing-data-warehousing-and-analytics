# 1st Mistake

When bulking inserting the data, I completely forgot to create a new bronze layer table for development. This would be a major disaster in real life. Other mistake was not to do de dry-un technique, which i also need to learn more.

## Takeaways
- Always remember to build a database for development
- Learn more about dry-run and error handling in Python

# 2nd Mistake

When creating the silver layer I notice that the data coming from the excel files store breakdowns in full minutes. Today I've accessed Nemetris to configure the stoppages outputs and noticed that the breakdowns are stored as decimals, but when exporting to Excel the values are transformed to integers. For example, if the record is 3.45 minutes of breakdown, the database and excel will store only 3, and for 20 cases like that in the day we would miss 9 minutes of record. Compounding those misses during the week, it would have a significant (but negligible perhaps?) impact in the data visualization.

# 3rd Mistake

I think it would be better to add another dimension table on the modeling making the conversions of shit labels to real hours. Had to implement inside the gold layer fact_status_table_dev to be able to granulate enough the total downtimes. Used the following logic: 

morning -> 06:00-14:00 <br>
afternoon -> 14:00-22:00 <br>
evening -> 22:00-06:00 (wraps midnight)