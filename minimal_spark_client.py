import os
import subprocess
import sys
from pathlib import Path

def find_spark_jars():
    """Find Spark JAR files from PySpark installation"""
    import pyspark
    pyspark_path = Path(pyspark.__file__).parent
    jars_path = pyspark_path / "jars"
    if jars_path.exists():
        return str(jars_path)
    return None

def setup_minimal_spark_env():
    """Set up minimal Spark environment using only PySpark JARs"""
    jars_path = find_spark_jars()
    if not jars_path:
        raise Exception("Could not find PySpark JARs")
    
    # Set minimal required environment variables
    os.environ["PYSPARK_SUBMIT_ARGS"] = f"--jars {jars_path}/* pyspark-shell"
    os.environ["SPARK_LOCAL_IP"] = "127.0.0.1"
    
    print(f"✅ Using PySpark JARs from: {jars_path}")

if __name__ == "__main__":
    print("🔧 Setting up minimal Spark environment...")
    setup_minimal_spark_env()
    
    print("🔌 Connecting to Kubernetes Spark cluster...")
    
    from pyspark.sql import SparkSession
    from pyspark.conf import SparkConf
    
    # Create Spark session that connects to remote cluster
    spark = SparkSession.builder \
        .appName("MinimalRemoteClient") \
        .master("spark://spark-master:7077") \
        .config("spark.executor.memory", "1g") \
        .config("spark.executor.cores", "1") \
        .config("spark.driver.host", "host.docker.internal") \
        .getOrCreate()
    
    print("✅ Connected!")
    print(f"Spark version: {spark.version}")
    print(f"Master: {spark.sparkContext.master}")
    
    # Simple test
    print("\n🧪 Testing connection...")
    data = [("Alice", 25), ("Bob", 30), ("Charlie", 35)]
    df = spark.createDataFrame(data, ["name", "age"])
    
    print("Sample data:")
    df.show()
    
    print("Count:", df.count())
    
    spark.stop()
    print("✅ Success! Remote Spark connection working.") 