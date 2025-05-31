from pyspark.sql import SparkSession

# Create Spark session (this will run inside the cluster)
spark = SparkSession.builder \
    .appName("KubernetesSparkJob") \
    .getOrCreate()

print("🚀 Spark job running in Kubernetes cluster!")
print(f"Spark version: {spark.version}")
print(f"Application ID: {spark.sparkContext.applicationId}")
print(f"Master: {spark.sparkContext.master}")

# Create some test data
print("\n📊 Creating test data...")
data = [
    ("Alice", 25, "Engineer"),
    ("Bob", 30, "Manager"), 
    ("Charlie", 35, "Analyst"),
    ("Diana", 28, "Designer"),
    ("Eve", 32, "Developer")
]

columns = ["name", "age", "role"]
df = spark.createDataFrame(data, columns)

print("Original data:")
df.show()

# Perform some operations
print("\n🔍 Filtering employees over 30:")
older_employees = df.filter(df.age > 30)
older_employees.show()

print("\n📈 Age statistics:")
df.describe("age").show()

print("\n👥 Group by role:")
df.groupBy("role").count().show()

# Test RDD operations
print("\n🔢 RDD operations:")
numbers = spark.sparkContext.parallelize(range(1, 11))
squares = numbers.map(lambda x: x * x)
sum_of_squares = squares.reduce(lambda a, b: a + b)
print(f"Sum of squares 1-10: {sum_of_squares}")

# Create a larger dataset to see distributed processing
print("\n🌐 Testing distributed processing:")
large_range = spark.sparkContext.parallelize(range(1, 1000000))
partitions = large_range.getNumPartitions()
total = large_range.sum()
print(f"Processed 1M numbers across {partitions} partitions, sum: {total}")

spark.stop()
print("✅ Spark job completed successfully!") 