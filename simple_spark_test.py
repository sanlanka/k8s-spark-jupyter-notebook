from pyspark.sql import SparkSession

# Connect to your Kubernetes Spark cluster
spark = SparkSession.builder \
    .appName("LocalToK8sSparkTest") \
    .master("spark://localhost:7077") \
    .config("spark.executor.memory", "1g") \
    .config("spark.executor.cores", "1") \
    .getOrCreate()

print("✅ Successfully connected to Kubernetes Spark cluster!")
print(f"Spark version: {spark.version}")
print(f"Spark master: {spark.sparkContext.master}")

# Simple test
data = [1, 2, 3, 4, 5]
rdd = spark.sparkContext.parallelize(data)
result = rdd.map(lambda x: x * 2).collect()
print(f"Test calculation result: {result}")

# Create a simple DataFrame test
df = spark.createDataFrame([(1, "Alice"), (2, "Bob"), (3, "Charlie")], ["id", "name"])
df.show()

spark.stop()
print("✅ Test completed successfully!") 