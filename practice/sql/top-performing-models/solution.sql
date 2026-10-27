(
  ml_models
  .filter(F.col('accuracy') >= 0.9)
  .orderBy(F.col('accuracy').desc())
)
