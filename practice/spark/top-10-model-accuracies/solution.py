(
ml_models
  .select('model_id','mdl_name','accuracy')
  .orderBy(F.col('accuracy').desc(),'model_id')
  .limit(10)
)
