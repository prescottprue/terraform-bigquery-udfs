variable project_name {
  type = string
}

variable dataset_id {
  type = string
  default = "side_events"
}

# Setup User Defined Functions (UDFs) on dataset
# NOTE: Since these function are not defined on the dataset on the first run, views setup will fail
# TODO: [CORE-1468] Remove manual setup of these functions in favor of built in functions
locals {
  my_udf_definition = <<EOF
CREATE OR REPLACE FUNCTION `${var.project_name}.${var.dataset_id}.getInputsFromDocs`(docsStr STRING, templatesStr STRING)
RETURNS ARRAY<STRING> LANGUAGE js AS """
const templates = JSON.parse(templatesStr);
return JSON.parse(docsStr).reduce((acc, doc, ind) => {
  if (doc.pages) {
    const inputs = [];
    doc.pages.forEach((page) => {
      if (page.inputs) {
        Object.values(page.inputs).forEach((input) => {
          inputs.push({
            name: input && input.name,
            value: input && input.value,
            carReportingName: input && input.carReportingName
          });
        });
      }
    });
    const template = templates[ind];
    const internalVersion =
      template &&
      template.form &&
      template.form.form_version &&
      template.form.form_version.external &&
      template.form.form_version.external + '-' + template.updatedAt;
    const dataObj = {
      external_form_version:
        template && template.form && template.form.form_version,
      form_library: template && template.form && template.form.form_library,
      internal_form_version: internalVersion,
      inputs,
    };
    acc.push(JSON.stringify(dataObj));
  }
  return acc;
}, []);
""";
CREATE OR REPLACE FUNCTION `${var.project_name}.${var.dataset_id}.firstItem`(input ARRAY<STRING>)
RETURNS STRING LANGUAGE js AS """
return input[0]
""";
CREATE OR REPLACE FUNCTION `${var.project_name}.${var.dataset_id}.internalFormVersion`(input STRING)
RETURNS ARRAY<STRING> LANGUAGE js AS """
return JSON.parse(input)
  .filter((i) => i !== null && i.form && i.form.form_version && i.form.form_version.external && i.updatedAt)
  .map((item) => item.form.form_version.external + '-' + item.updatedAt)
""";
CREATE OR REPLACE FUNCTION `${var.project_name}.${var.dataset_id}.mapGetFormVersion`(input STRING, getPath STRING)
RETURNS ARRAY<STRING> LANGUAGE js AS """
return JSON.parse(input)
    .filter((i) => i !== null && i.form && i.form.form_version && i.form.form_version[getPath])
    .map((item) => item.form.form_version[getPath])
""";
CREATE OR REPLACE FUNCTION `${var.project_name}.${var.dataset_id}.mapGetForm`(input STRING, getPath STRING)
RETURNS ARRAY<STRING> LANGUAGE js AS """
return JSON.parse(input)
    .filter((i) => i !== null && i.form && i.form[getPath])
    .map((item) => item.form[getPath])
""";
EOF
}
resource "null_resource" "my_udf_resource" {
  triggers = {
    udf = local.my_udf_definition
  }
  provisioner "local-exec" {
    interpreter = ["bq", "query", "--use_legacy_sql=false", "--project_id=${var.project_name}"]
    command     = local.my_udf_definition
  }
}
