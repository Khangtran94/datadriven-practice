(
  err_tracks
  .withColumn('error_category',
      F.when(F.lower(F.col('err_type')).like('%timeout%'),'timeout')
        .when(F.lower(F.col('err_type')).like('%memory%'),'memory')
        .otherwise('other'))
  .groupBy('error_category').agg(F.count("*").alias('track_count'))
)
