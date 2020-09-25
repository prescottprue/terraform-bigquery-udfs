# Terraform BigQuery User Defined Functions

**NOTE**: The future plan is to not use User Defined Functions, so this repo should be short lived.

## Running
**NOTE**: This can only be run locally on a machine which has `bq` command line tool installed (installed with `gcloud`). Since the machines we are using in Terraform cloud do not have this dependency we can't run this there.

1. Run terraform
  ```bash
  terraform apply
  ```
1. Answer with the project name of the dataset you would like to add the functions
1. Answer "yes" after reviewing the changes to apply them

## Why Are These Needed

Data in our BigQuery columns is deeply nested JSON strings. Currently our BigQuery views access deeply nested values by using javascript within User Defined Functions.

These functions must exist for our views to work.