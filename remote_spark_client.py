"""Use the Kubernetes Spark cluster from ANY local program via Spark Connect.

Run ./spinup.sh first (it port-forwards the Spark Connect server to
localhost:15002), then from your laptop:

    pip install "pyspark-client==4.1.0"   # match versions.spark in charts/spark/values.yaml
    python remote_spark_client.py

pyspark-client is the thin, pure-Python Spark Connect client: no Java and no
local Spark needed. DataFrame / SQL work from any Python; Python UDFs run on the
cluster's Python, so they need your local Python minor to match versions.python
(3.12 by default).
"""

import os

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

remote = os.getenv("SPARK_REMOTE", "sc://localhost:15002")
print(f"Connecting to Spark Connect at {remote} ...")
spark = SparkSession.builder.remote(remote).getOrCreate()
print(f"Connected. Cluster Spark version: {spark.version}")

df = spark.createDataFrame(
    [(1, "Alice", 25), (2, "Bob", 30), (3, "Charlie", 35), (4, "Diana", 28)],
    ["id", "name", "age"],
)
df.filter(df.age > 28).show()
print("Average age:", df.agg(F.avg("age")).first()[0])

# Runs on the cluster's executors (spark.range is distributed).
print("Sum 1..100:", spark.range(1, 101).agg(F.sum("id")).first()[0])

# Delta Lake works out of the box (the cluster has the Delta jars + extensions).
# Write under the shared warehouse folder (repo's warehouse/), NOT /tmp: /tmp is
# private to each pod, so executors and the driver would see different files.
path = "/opt/spark/work-dir/warehouse/remote_client_delta"
spark.range(5).write.format("delta").mode("overwrite").save(path)
print("Delta rows:", spark.read.format("delta").load(path).count())

# Python UDFs execute on the cluster's Python — skip if the minor versions differ.
try:
    plus_one = F.udf(lambda x: x + 1, "long")
    print(
        "UDF result:", [r[0] for r in spark.range(3).select(plus_one("id")).collect()]
    )
except Exception as e:  # PYTHON_VERSION_MISMATCH when local Python != cluster Python
    print(
        f"Skipping UDF demo ({type(e).__name__}): local Python must match the cluster's."
    )

spark.stop()
print("Done — your local program just used the Kubernetes Spark cluster.")
