# OPA Gatekeeper 

- Gatekeeper runs OPA as an admission controller and can reject invalid resources before they are created
- This Rego checks every normal container and initContainer. It rejects anything missing: 
```yaml
resources:
  requests:
    cpu:
    memory:
  limits:
    cpu:
    memory:
```


## Install Gatekeeper
```sh
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --create-namespace \
  --wait

kubectl get pods -n gatekeeper-system

```

## Add policy files
```sh
cd policy/
# Deploy Rego ConstraintTemplate
kubectl apply -f 1_required-requests-limits-template.yaml 

# Deploy Constraint
kubectl apply -f 2_require-requests-limits.yaml

# Test 
kubectl apply -f 3_rejected_Pod.yaml

```
