# Apigee X Eval - Quick Provisioning via Terraform

## Enable Google APIs
```
gcloud services enable compute.googleapis.com \
  apigee.googleapis.com \
  apihub.googleapis.com \
  cloudkms.googleapis.com \
  servicenetworking.googleapis.com \
  certificatemanager.googleapis.com \
  cloudresourcemanager.googleapis.com
```

## Configuration

Variables are defined in `variables.tf`. 

- `project_id` (Required): Your GCP Project ID.
- `region` (Optional): The GCP region for Apigee and network resources (default: `us-central1`).

You can override the defaults using a `terraform.tfvars` file or inline `-var` flags.

## Terraform Init
`terraform init`

## Terraform Plan
`terraform plan -var="project_id=REPLACE_WITH_YOUR_GCP_PROJECT"`
*(Optional: add `-var="region=YOUR_REGION"` to override the default).*

## Terraform Apply
`terraform apply -var="project_id=REPLACE_WITH_YOUR_GCP_PROJECT"`

This will take approx 45 minutes to complete.

## Troubleshooting

### Terraform resource already exists
If terraform returns that resource already exists you may need to import it into it's state.
```
terraform import -var="project_id=REPLACE_WITH_YOUR_GCP_PROJECT" \
  google_apihub_api_hub_instance.apihub_instance \
  REPLACE_WITH_YOUR_GCP_PROJECT/us-central1/eval-api-hub
```
