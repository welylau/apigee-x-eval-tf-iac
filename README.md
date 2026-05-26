# Apigee X Eval - Quick Provisioning via Terraform

## Enable Google APIs
```
gcloud services enable compute.googleapis.com \
  apigee.googleapis.com \
  servicenetworking.googleapis.com \
  certificatemanager.googleapis.com \
  cloudresourcemanager.googleapis.com
```

## Terraform Init
`terraform init`

## Terraform Plan
`terraform plan -var="project_id=REPLACE_WITH_YOUR_GCP_ORG"`

## Terraform Apply
`terraform apply -var="project_id=REPLACE_WITH_YOUR_GCP_ORG"`

This will take approx 45 minutes to complete.
