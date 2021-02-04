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
  if (doc.pages && Array.isArray(doc.pages)) {
    const inputs = {};
    doc.pages.forEach((page) => {
      if (page && page.inputs) {
        Object.values(page.inputs).forEach((input) => {
          if (input && ((input.reportingName !== '' && input.reportingName) || (input.type === 'radio' && input.value))) {
            if (input.type === 'radio' && input.options && input.value) {
              Object.keys(input.options).forEach((optionIdx) => {
                if (input.options[optionIdx].reportingName && input.options[optionIdx].reportingName !== '' && input.options[optionIdx].value) {
                  const optionReportingName = input.options[optionIdx].reportingName;
                  const optionReportingValue = input.options[optionIdx].value;
                  if (input.value === optionReportingValue) {
                    inputs[optionReportingName] = true;
                  }
                }
              });
            } else {
              inputs[input.reportingName] = input.value;
            }
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
      form_name: template && template.form && template.form.form_name,
      internal_form_version: internalVersion,
      inputs,
    };
    if (doc && !doc.archived && !doc.useDraft && template && template.form && template.form.isReadyForReporting && template.form.form_library === 'CAR') {
      acc.push(dataObj);
    }
  }
  return acc;
}, []);
return JSON.stringify({ docs: arrayRes })
""";
CREATE OR REPLACE FUNCTION `${var.project_name}.${var.dataset_id}.internalFormVersion`(docStr STRING, templatesStr STRING)
RETURNS STRING LANGUAGE js AS """
const docStrArr = JSON.parse(docStr)
const templatesStrArr = JSON.parse(templatesStr)
const doc = docStrArr && docStrArr[0]
const template = templatesStrArr && templatesStrArr[0]
return !doc.useDraft &&
      template.updatedAt &&
      template.form &&
      template.form.isReadyForReporting &&
      template.form.form_version &&
      template.form.form_version.external &&
      template.form.form_version.external + '-' + template.updatedAt || null
""";
CREATE OR REPLACE FUNCTION `${var.project_name}.${var.dataset_id}.mapGetFormVersion`(docStr STRING, templatesStr STRING, getPath STRING)
RETURNS STRING LANGUAGE js AS """
const docStrArr = JSON.parse(docStr)
const templatesStrArr = JSON.parse(templatesStr)
const doc = docStrArr && docStrArr[0]
const template = templatesStrArr && templatesStrArr[0]
return !doc.useDraft &&
      template.updatedAt &&
      template.form &&
      template.form.isReadyForReporting &&
      template.form.form_version &&
      template.form.form_version[getPath] || null
""";
CREATE OR REPLACE FUNCTION `${var.project_name}.${var.dataset_id}.mapGetForm`(docStr STRING, templatesStr STRING, getPath STRING)
RETURNS STRING LANGUAGE js AS """
const docStrArr = JSON.parse(docStr)
const templatesStrArr = JSON.parse(templatesStr)
const doc = docStrArr && docStrArr[0]
const template = templatesStrArr && templatesStrArr[0]
return !doc.useDraft && template.form && template.form.isReadyForReporting && template.form[getPath] || null
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
