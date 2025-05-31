
# Spark + Jupyter on Kubernetes

This setup provides a complete Apache Spark cluster running in Kubernetes with a Jupyter notebook interface for interactive development.

> **📁 All Spark files are located in the `dfs/` directory**

## 🎯 What You Get

- **Apache Spark cluster** (master + worker nodes) in Kubernetes
- **Jupyter notebook** with PySpark pre-configured
- **Automatic connection** between Jupyter and Spark cluster
- **Web UI** access to monitor Spark jobs
- **No local Spark installation required**

## 📋 Prerequisites

- Kubernetes cluster (Docker Desktop, minikube, etc.)
- `kubectl` configured to access your cluster
- `helm` installed

## 🚀 Installation

### Step 1: Add Helm Repository
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### Step 2: Install Spark Cluster
```bash
helm install spark-cluster bitnami/spark -n api --create-namespace
```

### Step 3: Install Jupyter with PySpark
```bash
cd dfs/
kubectl apply -f jupyter-spark.yaml
```

### Step 4: Verify Installation
```bash
# Check all pods are running
kubectl get pods -n api

# Check services
kubectl get svc -n api
```

## 🔧 Usage

### Access Jupyter Notebook
1. Open your browser and go to: **http://localhost:8888**
2. Enter token: **`spark123`**
3. Create a new Python notebook

### Sample Spark Code in Jupyter
```python
from pyspark.sql import SparkSession

# Connect to Kubernetes Spark cluster
spark = SparkSession.builder \
    .appName("MySparkApp") \
    .master("spark://spark-cluster-master-svc:7077") \
    .config("spark.executor.memory", "1g") \
    .config("spark.executor.cores", "1") \
    .getOrCreate()

print(f"✅ Connected to Spark cluster!")
print(f"Spark version: {spark.version}")

# Create test data
data = [("Alice", 25), ("Bob", 30), ("Charlie", 35)]
df = spark.createDataFrame(data, ["name", "age"])
df.show()

# Stop session when done
spark.stop()
```

### Access Spark Web UI (Optional)
```bash
# Port-forward to access Spark Web UI
kubectl port-forward svc/spark-cluster-master-svc 8080:80 -n api &

# Then open: http://localhost:8080
```

## 📁 Files Description

All files are located in the `dfs/` directory:

- **`jupyter-spark.yaml`** - Kubernetes deployment for Jupyter notebook with PySpark
- **`submit_job.yaml`** - Example Kubernetes job for running Spark applications
- **`test_spark_in_jupyter.ipynb`** - Sample notebook for testing the connection
- **`simple_spark_test.py`** - Basic connection test script
- **`remote_spark_client.py`** - Remote connection example
- **`minimal_spark_client.py`** - Minimal setup example
- **`spark_job.py`** - Example Spark job script

## 🔍 Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n api
kubectl describe pod <pod-name> -n api
```

### Check Logs
```bash
# Jupyter logs
kubectl logs -l app=jupyter-pyspark -n api

# Spark master logs
kubectl logs spark-cluster-master-0 -n api

# Spark worker logs
kubectl logs spark-cluster-worker-0 -n api
```

### Restart Services
```bash
# Restart Jupyter
kubectl rollout restart deployment/jupyter-pyspark -n api

# Restart Spark cluster
helm upgrade spark-cluster bitnami/spark -n api
```

## 🧹 Cleanup

### Remove Everything
```bash
# Remove Jupyter
cd dfs/
kubectl delete -f jupyter-spark.yaml

# Remove Spark cluster
helm uninstall spark-cluster -n api

# Remove namespace (optional)
kubectl delete namespace api
```

### Remove Individual Components
```bash
# Remove only Jupyter
kubectl delete deployment jupyter-pyspark -n api
kubectl delete service jupyter-service -n api

# Remove only Spark cluster
helm uninstall spark-cluster -n api
```

## ⚙️ Configuration

### Customize Jupyter
Edit `dfs/jupyter-spark.yaml` to modify:
- **Token**: Change `JUPYTER_TOKEN` value
- **Resources**: Add resource limits/requests
- **Persistence**: Replace `emptyDir` with persistent volume

### Customize Spark Cluster
```bash
# View available configuration options
helm show values bitnami/spark

# Create custom values file
helm install spark-cluster bitnami/spark -n api -f custom-values.yaml
```

### Example Custom Values (custom-values.yaml)
```yaml
master:
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"

worker:
  replicaCount: 2
  resources:
    requests:
      memory: "2Gi"
      cpu: "1"
```

## 🔗 Useful Commands

```bash
# Check cluster status
kubectl get all -n api

# Scale workers
kubectl scale statefulset spark-cluster-worker --replicas=3 -n api

# Port forward Jupyter (if LoadBalancer doesn't work)
kubectl port-forward svc/jupyter-service 8888:8888 -n api

# Execute commands in Jupyter pod
kubectl exec -it <jupyter-pod-name> -n api -- bash

# View Spark configuration
kubectl exec spark-cluster-master-0 -n api -- cat /opt/bitnami/spark/conf/spark-defaults.conf
```

## 🎓 Next Steps

1. **Upload your data** to Jupyter's work directory
2. **Create notebooks** for your Spark applications
3. **Scale the cluster** by adding more worker nodes
4. **Add persistent storage** for data persistence
5. **Configure resource limits** based on your needs

## 💡 Tips

- Use the Jupyter interface for interactive development
- Monitor jobs via the Spark Web UI at http://localhost:8080
- Files in `/home/jovyan/work` persist within the Jupyter container
- For production workloads, consider using persistent volumes
- Scale workers based on your computation needs

## 🐛 Common Issues

**Jupyter pod stuck in ContainerCreating:**
- Check if Docker has enough resources allocated
- Verify network connectivity

**Can't connect to Spark master:**
- Ensure both master and worker pods are running
- Check service endpoints: `kubectl get endpoints -n api`

**Out of memory errors:**
- Increase executor memory in Spark configuration
- Scale up worker nodes or increase their memory allocation

---

**Happy Sparking! 🎉**
