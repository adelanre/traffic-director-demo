## Create cluster
set -e

gcloud container clusters create traffic-director-cluster \
  --zone us-central1-a \
  --scopes=monitoring,logging-write,storage-ro,cloud-platform,gke-default \
  --enable-ip-alias

## Get Cluster
gcloud container clusters get-credentials traffic-director-cluster \
    --zone us-central1-a

echo ******** Clsuer Creation Done ***************
## Deploy

kubectl create namespace dev
kubectl apply -f app-dev.yaml
# wget -q -O - \
# https://storage.googleapis.com/traffic-director/demo/trafficdirector_service_sample.yaml \
# | kubectl apply -f -

kubectl get svc -n dev

echo ******** Deploy Creation Done ***************

## NEG
gcloud beta compute network-endpoint-groups list

echo .......

NEG_NAME=$(gcloud beta compute network-endpoint-groups list | grep service-test | awk '{print $1}')

#kubectl create namespace dev
kubectl apply -f sidecar-dev.yaml
# wget -q -O - \
# https://storage.googleapis.com/traffic-director/demo/trafficdirector_client_sample.yaml \
# | kubectl apply -f -

echo ******** NEG Creation Done ***************

## Trafic Director Setup
# Health Check
gcloud compute health-checks create http td-gke-health-check \
    --use-serving-port

# Backend
gcloud compute backend-services create td-gke-service \
    --global \
    --health-checks td-gke-health-check \
    --load-balancing-scheme INTERNAL_SELF_MANAGED

gcloud compute backend-services add-backend td-gke-service \
    --global \
    --network-endpoint-group ${NEG_NAME} \
    --network-endpoint-group-zone us-central1-a \
    --balancing-mode RATE \
    --max-rate-per-endpoint 15

# Routing rule
gcloud compute url-maps create td-gke-url-map \
   --default-service td-gke-service


gcloud compute url-maps add-path-matcher td-gke-url-map \
   --default-service td-gke-service \
   --path-matcher-name td-gke-path-matcher

gcloud compute url-maps add-host-rule td-gke-url-map \
   --hosts service-test \
   --path-matcher-name td-gke-path-matcher

gcloud compute target-http-proxies create td-gke-proxy \
   --url-map td-gke-url-map

gcloud compute forwarding-rules create td-gke-forwarding-rule \
  --global \
  --load-balancing-scheme=INTERNAL_SELF_MANAGED \
  --address=0.0.0.0 --address-region=us-central1 \
  --target-http-proxy=td-gke-proxy \
  --ports 80 --network default
