# Spark + Jupyter on Kubernetes

[![Star this repo](https://img.shields.io/github/stars/sanlanka/k8s-spark-jupyter-notebook?style=flat&logo=github&label=Star%20this%20repo&color=yellow)](https://github.com/sanlanka/k8s-spark-jupyter-notebook)
[![Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/slanka10)

If this saved you an afternoon of YAML, a ⭐ helps others find it — and
[coffee](https://buymeacoffee.com/slanka10) keeps it maintained.

[![Page views](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/sanlanka/k8s-spark-jupyter-notebook/traffic-stats/stats/views.json&cacheSeconds=300)](https://github.com/sanlanka/k8s-spark-jupyter-notebook/blob/traffic-stats/stats/SUMMARY.md)
[![Unique visitors](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/sanlanka/k8s-spark-jupyter-notebook/traffic-stats/stats/visitors.json&cacheSeconds=300)](https://github.com/sanlanka/k8s-spark-jupyter-notebook/blob/traffic-stats/stats/SUMMARY.md)
[![Clones](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/sanlanka/k8s-spark-jupyter-notebook/traffic-stats/stats/clones.json&cacheSeconds=300)](https://github.com/sanlanka/k8s-spark-jupyter-notebook/blob/traffic-stats/stats/SUMMARY.md)

A standalone **Apache Spark** cluster (master + worker) with **Delta Lake**, a
**Jupyter** notebook, and a **Spark Connect** server so any program on your
machine can use the cluster. Deployed with one command via **Skaffold** and a
small custom **Helm** chart.

Defaults: **Spark 4.1.0 · Python 3.12 · Delta Lake 4.2.0 · Java 17**, all
configurable in [`charts/spark/values.yaml`](charts/spark/values.yaml).

## Quick start

```bash
./spinup.sh
```

That's it. The script installs any missing tooling (kubectl, helm, skaffold),
builds the image, deploys everything, and holds the port-forwards:

| What                 | Where                                   |
|----------------------|-----------------------------------------|
| Jupyter              | **http://localhost:8888** (token: `spark123`) |
| Spark master UI      | **http://localhost:8080**               |
| Spark Connect        | **`sc://localhost:15002`** (any local program) |
| Jupyter driver UI    | http://localhost:4040 (while a session runs) |
| Spark Connect driver UI | http://localhost:4041                |

Press `Ctrl-C` to stop the port-forwards (the cluster keeps running). To remove
everything: `./teardown.sh` (add `--namespace` to delete the `api` namespace).

**Prerequisites:** Docker Desktop with Kubernetes enabled (or minikube). On
macOS the script auto-installs the CLI tools via Homebrew.

## Choose your versions

**All configuration lives in [`charts/spark/values.yaml`](charts/spark/values.yaml).**
Versions are in the `versions:` block at the top:

```yaml
versions:
  spark: "4.1.0"       # an apache/spark Docker Hub tag
  python: "3.12"       # any CPython minor that Spark supports (>= 3.10 for Spark 4.x)
  deltaSpark: "4.2.0"  # a Delta release built for that Spark minor
  java: "17"           # 17 or 21
```

Edit, then re-run `./spinup.sh`. It reads this block and passes the values to
the Docker build, so the master, workers, Spark Connect server and Jupyter all
get **one image with identical versions**. That matters: PySpark refuses to run
when the driver and executors use different Python minor versions.

- Keep the values **quoted** (`"3.10"` unquoted is the number `3.1` in YAML).
- Pick a Delta release that matches your Spark minor — see the
  [Delta compatibility table](https://docs.delta.io/latest/releases.html)
  (e.g. Delta 4.2.0 → Spark 4.1, Delta 4.0.x → Spark 4.0). The build fails fast
  if Delta can't be resolved for your Spark version.

The same file also sets worker count/cores/memory, the Jupyter token, the
Spark Connect server, and which folders are mounted into the pods.

## Use it from Jupyter

In a notebook, connect with a plain builder — the driver host, Python and Delta
are already wired up:

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("MyApp") \
    .master("spark://spark-master:7077") \
    .getOrCreate()

print(spark.version)                                         # 4.1.0
print(spark.sparkContext.parallelize(range(1, 101)).sum())   # 5050

# Delta Lake works with no extra config. Write to the shared warehouse folder
# (the repo's warehouse/ dir) — see "Writing output" below.
spark.range(5).write.format("delta").mode("overwrite").save("/opt/spark/work-dir/warehouse/my_delta")
spark.read.format("delta").load("/opt/spark/work-dir/warehouse/my_delta").show()
spark.range(3).write.format("delta").mode("overwrite").saveAsTable("my_table")   # -> warehouse/my_table
spark.stop()
```

## Use it from any local program (Spark Connect)

You can drive the cluster from **outside** Jupyter — a Python script, VS Code,
PyCharm, a local Jupyter, or a Scala/Go/Rust Spark Connect client. The chart
runs a [Spark Connect](https://spark.apache.org/docs/latest/spark-connect-overview.html)
server in the cluster and Skaffold forwards it to `localhost:15002`.

```bash
pip install "pyspark-client==4.1.0"    # match versions.spark; no Java needed
python remote_spark_client.py          # ready-made example in this repo
```

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder.remote("sc://localhost:15002").getOrCreate()
spark.range(1, 101).selectExpr("sum(id)").show()      # 5050, computed on the cluster
spark.read.option("header", True).csv("/opt/spark/work-dir/test-datasets/retail_sales.csv").show(5)
```

Things to know:
- **Why not just port-forward `spark://localhost:7077`?** In classic mode your
  local program becomes the Spark *driver*, and the cluster's executors must open
  connections *back* to it. A port-forward only goes one way (laptop → pod), so
  jobs hang forever. Spark Connect runs the driver inside the cluster and only
  needs the single forwarded port.
- **Python UDFs** run on the cluster's Python, so your local Python minor must
  match `versions.python` (3.12). DataFrame and SQL code works from any Python.
- **Paths** are resolved inside the cluster — use `/opt/spark/work-dir/...`
  (see [Reading data files](#reading-data-files) and [Writing output](#writing-output)).
- Spark Connect has no RDD/`sparkContext` API; use DataFrames/SQL.
- Inside the cluster (e.g. from Jupyter) the same server is `sc://spark-connect:15002`.
  A Python process can't mix the two: `spark.stop()` the classic session first
  (or use a separate notebook), otherwise PySpark raises `SESSION_ALREADY_EXIST`.
- Don't need it? Set `connect.enabled: false` in `values.yaml` to save a pod.

## Reading data files

The pods can't see your Mac's filesystem, so **files you want to read must live
in one of the exposed folders** — by default `notebooks/` and `test-datasets/`.
These are bind-mounted (via `spinup.sh`) as siblings at Jupyter's root *and* onto
the workers and Spark Connect server, so paths resolve identically everywhere
and the Jupyter file browser stays clean (no `charts/`, `docker/`, `.git`,
scripts). Drop CSVs in `test-datasets/` and use a path relative to your notebook:

```python
# from a notebook in notebooks/ :
df = (spark.read
      .option("header", True)
      .option("inferSchema", True)
      .csv("../test-datasets/retail_sales.csv"))
```

Path rules:
- The relative path is relative to **where your notebook lives** (Jupyter runs
  each kernel from the notebook's folder). Notebook in `notebooks/` →
  `../test-datasets/x.csv`; notebook at the repo root → `test-datasets/x.csv`.
- An absolute in-pod path always works too: `/opt/spark/work-dir/test-datasets/x.csv`
  (use this form from Spark Connect clients).
- A host path like `/Users/you/...` will **not** work — it doesn't exist in the pod.
- To expose another folder, add it to `hostMount.paths` in `charts/spark/values.yaml`.
- In cluster mode the **executors** read the file too; that's why the repo is
  mounted on the workers as well (same absolute path on every pod).
- This uses a `hostPath` mount and works on Docker Desktop / minikube (they share
  `/Users`). On a remote/multi-node cluster, use object storage (S3/GCS) or a
  PersistentVolume instead.

## Writing output

**Write to `/opt/spark/work-dir/warehouse/...`** (the repo's gitignored
`warehouse/` folder), never `/tmp` or another in-pod path. In cluster mode the
executors on the workers write the files while the driver (Jupyter or Spark
Connect) writes the Delta log and reads results back — each pod has its own
private `/tmp`, so the driver would find nothing (`FILE_NOT_EXIST`). The
warehouse folder is mounted on every pod and is the default
`spark.sql.warehouse.dir`, so `saveAsTable("t")` lands there too, and you can
see the output on your Mac. Change it with `hostMount.warehouse` in `values.yaml`.

## How it fits together

- **`charts/spark/values.yaml`** — the one place to configure everything:
  versions, worker size, Jupyter token, Spark Connect, mounted folders.
- **`skaffold.yaml`** — builds the image (versions passed as build args) and
  deploys the Helm chart; the `portForward` block does all forwarding.
- **`charts/spark/`** — the Helm chart: master, worker, Jupyter, Spark Connect.
- **`docker/spark/Dockerfile`** — a single image used by **every** pod, built
  from `apache/spark:<spark>-scala2.13-java<java>-ubuntu` plus the chosen Python
  (installed with [uv](https://docs.astral.sh/uv/)), the Delta Lake jars,
  JupyterLab, and cluster-wide `spark-defaults.conf` (Delta enabled; dynamic
  allocation + the worker's external shuffle service so Jupyter and Spark
  Connect share workers: idle apps give executors back after 60s, and Spark
  Connect is capped by `connect.maxExecutors`).
- **`remote_spark_client.py`** — example of using the cluster from your laptop.
- **`notebooks/`** — put your `.ipynb` files here.

### Images

All public, no Bitnami (Bitnami removed its free Docker Hub images in Aug 2025):

| Role                                  | Image                                      |
|---------------------------------------|--------------------------------------------|
| Master / worker / Spark Connect / Jupyter | built from `apache/spark` (Docker Hub) + Python + Delta + JupyterLab |

## Troubleshooting

```bash
kubectl get pods -n api
kubectl logs -l app=spark-master -n api      # look for "Registering worker"
kubectl logs -l app=jupyter-pyspark -n api
kubectl logs -l app=spark-connect -n api
```

- **Job hangs on "Initial job has not accepted any resources"** — the worker
  isn't registered, the driver isn't reachable, or the worker's cores are all
  taken by other apps. Check the master UI (localhost:8080): idle apps release
  executors after 60s; add cores/replicas in `values.yaml` if you need more.
- **`PYTHON_VERSION_MISMATCH`** — driver and executor Python differ. In-cluster
  that can't happen (one image); from a local Spark Connect client it means your
  local Python minor ≠ `versions.python` and you used a Python UDF.
- **`localhost:8888` (or 8080/15002) doesn't answer** — if that port is already
  in use on your machine (e.g. a local Jupyter), Skaffold forwards to the next
  free one. Check the `Port forwarding ... -> http://127.0.0.1:<port>` lines in
  the `spinup.sh` output.
- **Changed versions but nothing happened** — re-run `./spinup.sh`; the versions
  are build-time settings, so the image must be rebuilt.
- **Master crashes parsing `tcp://...:7077`** — a Kubernetes service-link env
  var collided with Spark's `SPARK_MASTER_PORT`. The chart disables that with
  `enableServiceLinks: false`.

## Scale

Edit `charts/spark/values.yaml` (`spark.worker.replicas`, `cores`, `memory`) and
re-run `./spinup.sh`.
