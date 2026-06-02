# Apigee X Eval - Quick Provisioning via Terraform

## Getting Started

The easiest way to run this provisioning is by using Google Cloud Shell, which comes with Terraform and the `gcloud` CLI pre-installed.

1. Open the [Google Cloud Console](https://console.cloud.google.com/).
2. Activate Cloud Shell by clicking the `>_` (Activate Cloud Shell) icon in the top right corner.
3. Clone this repository and navigate into the directory:

```bash
git clone https://github.com/wongjoey/apigee-x-eval.git
cd apigee-x-eval
```

## Enable Google APIs
```bash
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
```bash
terraform init
```

## Terraform Plan
```bash
terraform plan -var="project_id=REPLACE_WITH_YOUR_GCP_PROJECT"
```
*(Optional: add `-var="region=YOUR_REGION"` to override the default).*

## Terraform Apply
```bash
terraform apply -var="project_id=REPLACE_WITH_YOUR_GCP_PROJECT"
```

This will take approx 45 minutes to complete.

## Troubleshooting

### Terraform resource already exists
If terraform returns that a resource already exists, you may need to import it into its state.
```bash
terraform import -var="project_id=REPLACE_WITH_YOUR_GCP_PROJECT" \
  google_apihub_api_hub_instance.apihub_instance \
  REPLACE_WITH_YOUR_GCP_PROJECT/us-central1/eval-api-hub
```
