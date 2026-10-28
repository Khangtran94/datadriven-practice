(
products
  .filter(F.col('price').isNotNull())
  .select('product_name','category','price','in_stock')
  .withColumn('availability',F.when(F.col('in_stock') == 0,'Out of Stock').otherwise('In Stock'))
  .select('product_name','category','price','availability')
  .orderBy('product_name')
)
