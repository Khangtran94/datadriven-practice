(ad_impressions.groupBy("ad_campaign").agg(
    F.count("*").alias("impressions"),
    F.sum("revenue").alias("total_revenue"),
    F.sum("clicked").alias("clicks"))
    .withColumn("ctr",F.round(100.0 * F.col("clicks").cast("double") / F.col("impressions").cast("double"),1))
    .filter(F.col('impressions') > 5)
    .select('ad_campaign','impressions','total_revenue','ctr')
    .orderBy(F.col('ctr').desc()))
    
