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
RETURNS STRING LANGUAGE js AS """
const templates = JSON.parse(templatesStr);
const arrayRes = JSON.parse(docsStr).reduce((acc, doc, ind) => {
  if (doc.pages) {
    const inputs = [];
    doc.pages.forEach((page) => {
      if (page.inputs) {
        Object.values(page.inputs).forEach((input) => {
          if (input && (input.name || input.value || input.reportingName)) {
            inputs.push({
              name: input.name,
              value: input.value,
              reportingName: input.reportingName
            });
          }
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
        template && template.form && template.form.form_version && template.form.form_version.external,
      form_library: template && template.form && template.form.form_library,
      internal_form_version: internalVersion,
      inputs,
    };
    if (template && template.form && template.form.form_library === 'CAR') {
      acc.push(JSON.stringify(dataObj));
    }
  }
  return acc;
}, []);
return JSON.stringify({ docs: arrayRes })
""";
CREATE OR REPLACE FUNCTION `${var.project_name}.${var.dataset_id}.internalFormVersion`(input STRING)
RETURNS STRING LANGUAGE js AS """
const originalArr = JSON.parse(input)
const item = originalArr && originalArr[0]
return !item.useDraft &&
      item.updatedAt &&
      item.form &&
      item.form.form_version &&
      item.form.form_version.external &&
      item.form.form_version.external + '-' + item.updatedAt || null
""";
CREATE OR REPLACE FUNCTION `${var.project_name}.${var.dataset_id}.mapGetFormVersion`(input STRING, getPath STRING)
RETURNS STRING LANGUAGE js AS """
const originalArr = JSON.parse(input)
const item = originalArr && originalArr[0]
return !item.useDraft &&
      item.updatedAt &&
      item.form &&
      item.form.form_version &&
      item.form.form_version[getPath] || null
""";
CREATE OR REPLACE FUNCTION `${var.project_name}.${var.dataset_id}.mapGetForm`(input STRING, getPath STRING)
RETURNS STRING LANGUAGE js AS """
const originalArr = JSON.parse(input)
const item = originalArr && originalArr[0]
return !item.useDraft && item.form && item.form[getPath] || null
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

// 
