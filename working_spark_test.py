from pyspark.sql import SparkSession
import os

# Create Spark session with proper networking configuration
spark = SparkSession.builder \
    .appName("WorkingSparkTest") \
    .master("spark://spark-master:7077") \
    .config("spark.executor.memory", "512m") \
    .config("spark.executor.cores", "1") \
    .config("spark.cores.max", "1") \
    .config("spark.sql.adaptive.enabled", "true") \
    .config("spark.driver.host", os.getenv("SPARK_DRIVER_HOST", "localhost")) \
    .config("spark.driver.bindAddress", "0.0.0.0") \
    .getOrCreate()

print("✅ Connected to Spark cluster!")
print(f"Spark version: {spark.version}")
print(f"Master: {spark.sparkContext.master}")
print(f"Driver host: {spark.sparkContext.getConf().get('spark.driver.host')}")

# Test the DataFrame operation that was hanging
print("\n🧪 Testing DataFrame operations...")
data1 = [("Alice", 1), ("Bob", 2), ("Alice", 3)]
df1 = spark.createDataFrame(data1, ["name", "score"])

print("DataFrame created successfully!")
print("Showing data:")
df1.show()

print("\n📊 More operations:")
print(f"Row count: {df1.count()}")
df1.groupBy("name").sum("score").show()

spark.stop()
print("✅ All tests completed successfully!") 