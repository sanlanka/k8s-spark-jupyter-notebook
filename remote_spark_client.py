from pyspark.sql import SparkSession
from pyspark.conf import SparkConf
import os

# This approach connects to remote Spark cluster without needing local Spark
print("🔌 Connecting to Kubernetes Spark cluster...")

# Configure Spark to connect remotely 
conf = SparkConf()
conf.set("spark.app.name", "RemoteSparkClient")
conf.set("spark.master", "spark://localhost:7077")
conf.set("spark.executor.memory", "1g")
conf.set("spark.executor.cores", "1")
conf.set("spark.sql.adaptive.enabled", "true")
conf.set("spark.serializer", "org.apache.spark.serializer.KryoSerializer")

# Create Spark session with remote master
spark = SparkSession.builder.config(conf=conf).getOrCreate()

print("✅ Connected to Kubernetes Spark cluster!")
print(f"Spark version: {spark.version}")
print(f"Spark master: {spark.sparkContext.master}")
print(f"Application ID: {spark.sparkContext.applicationId}")

# Test with some data
print("\n🧪 Running test computation...")
data = [(1, "Alice", 25), (2, "Bob", 30), (3, "Charlie", 35), (4, "Diana", 28)]
columns = ["id", "name", "age"]

df = spark.createDataFrame(data, columns)
print("Original data:")
df.show()

# Perform some operations
print("Filtering age > 28:")
df.filter(df.age > 28).show()

print("Average age:")
avg_age = df.agg({"age": "avg"}).collect()[0][0]
print(f"Average age: {avg_age}")

# Test RDD operations
print("\n🔢 Testing RDD operations...")
numbers = spark.sparkContext.parallelize([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
squared = numbers.map(lambda x: x * x)
result = squared.collect()
print(f"Squares: {result}")

spark.stop()
print("✅ Test completed successfully! Your Kubernetes Spark cluster is working.") 