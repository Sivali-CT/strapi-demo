# CMS
This is solely for demonstration purposes.
![Strapi](https://res.cloudinary.com/andinianst93/image/upload/v1703882779/Screenshot_from_2023-12-30_03-44-33_s5ftig.png)

This web application works in conjunction with Next 14 as frontend and Django Rest Framework for comments.

## K8s
### Step 1: Create PV
```bash
apiVersion: v1
kind: PersistentVolume
metadata:
  name: strapi-pv
  labels:
    type: strapi
spec:
  capacity:
    storage: 4Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/strapi_data"
```
### Step 2: Create Statefulsets for DB
```bash
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: strapi-db
  namespace: development
spec:
  selector:
    matchLabels:
      db: strapi-db 
  serviceName: "strapi-db"
  replicas: 1
  minReadySeconds: 10
  template:
    metadata:
      labels:
        db: strapi-db
    spec:
      terminationGracePeriodSeconds: 10
      nodeSelector:
        db: postgres
      containers:
      - name: strapi-db
        image: postgres:latest
        ports:
        - containerPort: 5432
          name: strapi-db
        env:
        - name: POSTGRES_USER 
          value: admin
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: strapi-db-secret
              key: password
        - name: POSTGRES_DB
          value: strapi
        - name: PGDATA
          value: /var/lib/postgresql/data
        volumeMounts:
        - name: strapi-pvc
          mountPath: /mnt/strapi_data
  volumeClaimTemplates:
  - metadata:
      name: strapi-pvc
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 2Gi


---
apiVersion: v1
kind: Service
metadata:
  name: strapi-db
  namespace: development
  labels:
    app: strapi-db
spec:
  ports:
    - port: 5432
      name: strapi-db
  clusterIP: None
  selector:
    db: strapi-db

```
### Step 3: Create Secret for the DB and for the Strapi App
```bash
k create secret generic strapi-secret -n development \
    --from-literal=HOST=0.0.0.0 \
    --from-literal=PORT=1337 \
    --from-literal=APP_KEYS=yourvalue \
    --from-literal=API_TOKEN_SALT=yourvalue \
    --from-literal=ADMIN_JWT_SECRET=yourvalue \
    --from-literal=TRANSFER_TOKEN_SALT=yourvalue \
    --from-literal=DATABASE_CLIENT=postgres \
    --from-literal=DATABASE_FILENAME=.tmp/data.db \
    --from-literal=DATABASE_HOST=strapi-db \
    --from-literal=DATABASE_PORT=5432 \
    --from-literal=DATABASE_NAME=yourvalue \
    --from-literal=DATABASE_USERNAME=yourvalue \
    --from-literal=DATABASE_PASSWORD=yourvalue \
    --from-literal=DATABASE_SSL_CERT_DAYS=820

k create secret generic strapi-db-secret -n development \
    --from-literal=password=yourvalue \
```

### Step 4: Create Deployment
```bash
apiVersion: apps/v1
kind: Deployment
metadata:
  name: strapi
  labels:
    app: strapi
  namespace: development
spec:
  replicas: 2
  selector:
    matchLabels:
      tier: backend
  template:
    metadata:
      labels:
        tier: backend
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: tier
                operator: In
                values:
                - backend
      containers:
      - name: strapi
        image: svlct/strapi-demo-blog-posts:v1
        ports:
        - containerPort: 1337
        envFrom:
        - secretRef:
            name: strapi-secret
        resources:
          requests:
            cpu: 200m
            memory: 2Gi
          limits:
            cpu: 400m
            memory: 4Gi

--- 
apiVersion: v1
kind: Service
metadata:
  name: strapi
  namespace: development
spec:
  selector:
    tier: backend
  ports:
    - protocol: TCP
      port: 1337
      targetPort: 1337
  type: ClusterIP

```