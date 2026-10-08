# Apigee X Eval - Quick Provisioning via Terraform

## Getting Started

The easiest way to run this provisioning is by using Google Cloud Shell, which comes with Terraform and the `gcloud` CLI pre-installed.

1. Open the [Google Cloud Console](https://console.cloud.google.com/).
2. Activate Cloud Shell by clicking the `>_` (Activate Cloud Shell) icon in the top right corner.
3. Clone this repository and navigate into the directory:

```bash
git clone https://github.com/welylau/apigee-x-eval-tf-iac.git
cd apigee-x-eval-tf-iac
```

## Google APIs

The required Google APIs are now enabled **automatically by Terraform** (see section `0. ENABLE REQUIRED APIS` in `main.tf`), so no manual `gcloud services enable` step is needed:

- `compute.googleapis.com`
- `apigee.googleapis.com`
- `apihub.googleapis.com`
- `cloudkms.googleapis.com`
- `servicenetworking.googleapis.com`
- `certificatemanager.googleapis.com`
- `cloudresourcemanager.googleapis.com`

All other resources depend on these APIs, so they are always enabled first. The APIs are configured with `deletion_policy = "ABANDON"`, meaning `terraform destroy` will **not** disable them (to avoid breaking other workloads in the project).

> **Note:** Terraform enables APIs through the Service Usage API (`serviceusage.googleapis.com`), which is enabled by default on new projects. If it has been disabled, enable it first:
> ```bash
> gcloud services enable serviceusage.googleapis.com --project=REPLACE_WITH_YOUR_GCP_PROJECT
> ```

## Configuration

Variables are defined in `variables.tf`. 

- `project_id` (Required): Your GCP Project ID.
- `region` (Optional): The GCP region for Apigee, subnets, and API Hub (default: `asia-southeast1`).

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

After apply, the outputs `apigee_host` (`<LB_IP>.nip.io`) and `load_balancer_ip` are displayed. The Google-managed SSL certificate for `apigee_host` can take **15–60 minutes** to become `ACTIVE`; HTTPS calls may fail with TLS errors until then.

## Troubleshooting

### API Hub instance creation timeout
API Hub provisioning can take slightly longer than 20 minutes. The `google_apihub_api_hub_instance` resource in `main.tf` therefore sets a `45m` create/delete timeout. If you are on an older version of this script and see:

```
Error: Error waiting to create ApiHubInstance: ... timeout while waiting for state to become 'done: true' (last state: 'done: false', timeout: 20m0s)
```

the instance was most likely still created successfully but not recorded in the Terraform state. Follow the import steps below.

### Terraform resource already exists / not in state
If Terraform reports that a resource already exists (or a timeout left it out of state), import it.

1. Find the API Hub instance ID (it is server-generated, e.g. a UUID):
   ```bash
   gcloud apihub operations list \
     --location=REPLACE_WITH_YOUR_REGION \
     --project=REPLACE_WITH_YOUR_GCP_PROJECT \
     --format="value(metadata.target)"
   ```
   This returns a path like `projects/PROJECT/locations/REGION/apiHubInstances/INSTANCE_ID`.

2. Import it:
   ```bash
   terraform import -var="project_id=REPLACE_WITH_YOUR_GCP_PROJECT" \
     google_apihub_api_hub_instance.apihub_instance \
     projects/REPLACE_WITH_YOUR_GCP_PROJECT/locations/REPLACE_WITH_YOUR_REGION/apiHubInstances/INSTANCE_ID
   ```

3. Re-run `terraform plan`. The resource uses `lifecycle { ignore_changes = [api_hub_instance_id] }`, so the imported instance will **not** be force-replaced; you should only see a minor in-place update (labels/timeouts).
