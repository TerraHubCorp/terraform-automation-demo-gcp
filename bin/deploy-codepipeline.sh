#!/usr/bin/env bash

gcloud --version > /dev/null 2>&1 || { echo >&2 'gcloud is missing. aborting...'; exit 1; }
jq --version > /dev/null 2>&1 || { echo >&2 'jq is missing. aborting...'; exit 1; }
npm --version > /dev/null 2>&1 || { echo >&2 'npm is missing. aborting...'; exit 1; }
export NODE_PATH="$(npm root -g)"

if [ -z "${BRANCH_FROM}" ]; then BRANCH_FROM = "dev"; fi
if [ -z "${BRANCH_TO}" ]; then BRANCH_TO = "dev"; fi
if [ "${BRANCH_TO}" != "dev" ]; then THUB_ENV="-e ${BRANCH_TO}"; fi
if [ "${THUB_STATE}" == "approved" ]; then THUB_APPLY="-a"; fi

git --version > /dev/null 2>&1 || { echo >&2 'git is missing. aborting...'; exit 1; }
git checkout $BRANCH_TO
git checkout $BRANCH_FROM
git clone https://github.com/TerraHubCorp/www.git && rm -rf ./www/.terrahub*

export GOOGLE_CLOUD_PROJECT="$(gcloud config list --format=json | jq -r '.core.project')"
if [ "${GOOGLE_CLOUD_PROJECT}" == "null" ]; then echo >&2 'gcloud core project is missing. aborting...'; exit 1; fi
export GOOGLE_APPLICATION_CREDENTIALS="${HOME}/.config/gcloud/${GOOGLE_CLOUD_PROJECT}.json"
echo $GOOGLE_APPLICATION_CREDENTIALS_CONTENT > ${GOOGLE_APPLICATION_CREDENTIALS}
gcloud auth activate-service-account --key-file ${GOOGLE_APPLICATION_CREDENTIALS}
BILLING_ID="$(gcloud beta billing accounts list --format=json | jq -r '.[0].name[16:]')"

terrahub --version > /dev/null 2>&1 || { echo >&2 'terrahub is missing. aborting...'; exit 1; }
terrahub configure -c template.locals.google_project_id="${GOOGLE_CLOUD_PROJECT}"
terrahub configure -c template.locals.google_billing_account="${BILLING_ID}"

# terrahub configure -c template.terraform.backend.gcs.bucket="data-lake-terrahub"
# terrahub configure -c component.template.terraform.backend -D -y -i "google_function"
# terrahub configure -c component.template.terraform.backend.gcs.prefix="terraform/terrahubcorp/demo-terraform-automation-gcp/google_function/terraform.tfstate" -i "google_function"
# terrahub configure -c component.template.terraform.backend -D -y -i "google_storage"
# terrahub configure -c component.template.terraform.backend.gcs.prefix="terraform/terrahubcorp/demo-terraform-automation-gcp/google_storage/terraform.tfstate" -i "google_storage"
# terrahub configure -c component.template.terraform.backend -D -y -i "iam_object_viewer"
# terrahub configure -c component.template.terraform.backend.gcs.prefix="terraform/terrahubcorp/demo-terraform-automation-gcp/iam_object_viewer/terraform.tfstate" -i "iam_object_viewer"
# terrahub configure -c component.template.terraform.backend -D -y -i "static_website"
# terrahub configure -c component.template.terraform.backend.gcs.prefix="terraform/terrahubcorp/demo-terraform-automation-gcp/static_website/terraform.tfstate" -i "static_website"
# terrahub configure -c component.template.data.terraform_remote_state.google_storage -D -y -i "google_function"
# terrahub configure -c component.template.data.terraform_remote_state.google_storage.backend="gcs" -i "google_function"
# terrahub configure -c component.template.data.terraform_remote_state.google_storage.config.bucket="data-lake-terrahub" -i "google_function"
# terrahub configure -c component.template.data.terraform_remote_state.google_storage.config.prefix="terraform/terrahubcorp/demo-terraform-automation-gcp/google_storage/terraform.tfstate" -i "google_function"

terrahub run -y -a -i google_storage,static_website \
&& terrahub build -i google_function,static_website \
&& terrahub run -y ${THUB_APPLY} ${THUB_ENV} \
&& terrahub run -y -d ${THUB_APPLY} ${THUB_ENV}
