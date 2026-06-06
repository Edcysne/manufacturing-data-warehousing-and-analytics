# 1st Mistake

When bulking inserting the data, I completely forgot to create a new bronze layer table for development. This would be a major disaster in real life. Other mistake was not to do de dry-un technique, which i also need to learn more.

## Takeaways
- Always remember to build a database for development
- Learn more about dry-run and error handling in Python

# 2nd Mistake

When creating the silver layer I notice that the data coming from the excel files store breakdowns in full minutes. Today I've accessed Nemetris to configure the stoppages outputs and noticed that the breakdowns are stored as decimals, but when exporting to Excel the values are transformed to integers. For example, if the record is 3.45 minutes of breakdown, the database and excel will store only 3, and for 20 cases like that in the day we would miss 9 minutes of record. Compounding those misses during the week, it would have a significant (but negligible perhaps?) impact in the data visualization.
