#!/bin/bash

# Variables
CLUSTER_NAME="emart-dev-app"
AWS_REGION="ap-south-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Setting up External Secrets with IRSA..."

# 1. Associate OIDC provider (if not already done)
echo "Associating OIDC provider..."
eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --approve

# 2. Create IAM policy for External Secrets
echo "Creating IAM policy..."
aws iam create-policy \
  --policy-name ExternalSecretsPolicy \
  --policy-document file://external-secrets-iam-policy.json 2>/dev/null || echo "Policy already exists"

# 3. Create IAM service account for External Secrets
echo "Creating IAM service account..."
eksctl create iamserviceaccount \
  --cluster $CLUSTER_NAME \
  --namespace external-secrets-system \
  --name external-secrets \
  --attach-policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/ExternalSecretsPolicy \
  --approve \
  --override-existing-serviceaccounts

# 4. Install External Secrets Operator
echo "Installing External Secrets Operator..."
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace \
  --set serviceAccount.create=false \
  --set serviceAccount.name=external-secrets

# 5. Apply ClusterSecretStore
echo "Applying ClusterSecretStore..."
kubectl apply -f cluster-secret-yaml

# 6. Apply External Secrets
echo "Applying ExternalSecret..."
kubectl apply -f external-secrets.yaml

echo "Setup complete! Checking status..."
kubectl get clustersecretstore aws-secrets
kubectl get externalsecret -n emart
