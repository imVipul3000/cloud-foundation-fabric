/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable "billing_account" {
  description = "Billing account id. If billing account is not part of the same org set `is_org_level` to `false`. To disable handling of billing IAM roles set `no_iam` to `true`."
  type = object({
    id           = string
    is_org_level = optional(bool, true)
    no_iam       = optional(bool, false)
  })
  nullable = false
}

variable "bootstrap_user" {
  description = "Email of the nominal user running this stage for the first time."
  type        = string
  default     = null
}

variable "cicd_repositories" {
  description = "CI/CD repository configuration. Identity providers reference keys in the `federated_identity_providers` variable. Set to null to disable, or set individual repositories to null if not needed."
  type = object({
    bootstrap = optional(object({
      name              = string
      type              = string
      branch            = optional(string)
      identity_provider = optional(string)
    }))
    resman = optional(object({
      name              = string
      type              = string
      branch            = optional(string)
      identity_provider = optional(string)
    }))
  })
  default = null
  validation {
    condition = alltrue([
      for k, v in coalesce(var.cicd_repositories, {}) :
      v == null || try(v.name, null) != null
    ])
    error_message = "Non-null repositories need a non-null name."
  }
  validation {
    condition = alltrue([
      for k, v in coalesce(var.cicd_repositories, {}) :
      v == null || (
        try(v.identity_provider, null) != null
        ||
        try(v.type, null) == "sourcerepo"
      )
    ])
    error_message = "Non-null repositories need a non-null provider unless type is 'sourcerepo'."
  }
  validation {
    condition = alltrue([
      for k, v in coalesce(var.cicd_repositories, {}) :
      v == null || (
        contains(["github", "gitlab", "sourcerepo"], coalesce(try(v.type, null), "null"))
      )
    ])
    error_message = "Invalid repository type, supported types: 'github' 'gitlab' or 'sourcerepo'."
  }
}

variable "custom_roles" {
  description = "Map of role names => list of permissions to additionally create at the organization level."
  type        = map(list(string))
  nullable    = false
  default     = {}
}

variable "essential_contacts" {
  description = "Email used for essential contacts, unset if null."
  type        = string
  default     = null
}

variable "factories_config" {
  description = "Configuration for the resource factories or external data."
  type = object({
    checklist_data    = optional(string)
    checklist_org_iam = optional(string)
    custom_roles      = optional(string, "data/custom-roles")
    org_policy        = optional(string, "data/org-policies")
  })
  nullable = false
  default  = {}
}

variable "fast_features" {
  description = "Selective control for top-level FAST features."
  type = object({
    data_platform   = optional(bool, false)
    gke             = optional(bool, false)
    project_factory = optional(bool, false)
    sandbox         = optional(bool, false)
    teams           = optional(bool, false)
  })
  default  = {}
  nullable = false
}

variable "group_iam" {
  description = "Organization-level authoritative IAM binding for groups, in {GROUP_EMAIL => [ROLES]} format. Group emails need to be static. Can be used in combination with the `iam` variable."
  type        = map(list(string))
  default     = {}
  nullable    = false
}

variable "groups" {
  # https://cloud.google.com/docs/enterprise/setup-checklist
  description = "Group names or IAM-format principals to grant organization-level permissions. If just the name is provided, the 'group:' principal and organization domain are interpolated."
  type = object({
    gcp-billing-admins      = optional(string, "gcp-billing-admins")
    gcp-devops              = optional(string, "gcp-devops")
    gcp-network-admins      = optional(string, "gcp-network-admins")
    gcp-organization-admins = optional(string, "gcp-organization-admins")
    gcp-security-admins     = optional(string, "gcp-security-admins")
    # aliased to gcp-devops as the checklist does not create it
    gcp-support = optional(string, "gcp-devops")
  })
  nullable = false
  default  = {}
}

variable "iam" {
  description = "Organization-level custom IAM settings in role => [principal] format."
  type        = map(list(string))
  nullable    = false
  default     = {}
}

variable "iam_bindings_additive" {
  description = "Organization-level custom additive IAM bindings. Keys are arbitrary."
  type = map(object({
    member = string
    role   = string
    condition = optional(object({
      expression  = string
      title       = string
      description = optional(string)
    }))
  }))
  nullable = false
  default  = {}
}

variable "iam_by_principals" {
  description = "Authoritative IAM binding in {PRINCIPAL => [ROLES]} format. Principals need to be statically defined to avoid cycle errors. Merged internally with the `iam` variable."
  type        = map(list(string))
  default     = {}
  nullable    = false
}

variable "locations" {
  description = "Optional locations for GCS, BigQuery, and logging buckets created here."
  type = object({
    bq      = optional(string, "EU")
    gcs     = optional(string, "EU")
    logging = optional(string, "global")
    pubsub  = optional(list(string), [])
  })
  nullable = false
  default  = {}
}

# See https://cloud.google.com/architecture/exporting-stackdriver-logging-for-security-and-access-analytics
# for additional logging filter examples
variable "log_sinks" {
  description = "Org-level log sinks, in name => {type, filter} format."
  type = map(object({
    filter = string
    type   = string
  }))
  default = {
    audit-logs = {
      filter = "logName:\"/logs/cloudaudit.googleapis.com%2Factivity\" OR logName:\"/logs/cloudaudit.googleapis.com%2Fsystem_event\" OR protoPayload.metadata.@type=\"type.googleapis.com/google.cloud.audit.TransparencyLog\""
      type   = "logging"
    }
    vpc-sc = {
      filter = "protoPayload.metadata.@type=\"type.googleapis.com/google.cloud.audit.VpcServiceControlAuditMetadata\""
      type   = "logging"
    }
    workspace-audit-logs = {
      filter = "logName:\"/logs/cloudaudit.googleapis.com%2Fdata_access\" and protoPayload.serviceName:\"login.googleapis.com\""
      type   = "logging"
    }
  }
  validation {
    condition = alltrue([
      for k, v in var.log_sinks :
      contains(["bigquery", "logging", "pubsub", "storage"], v.type)
    ])
    error_message = "Type must be one of 'bigquery', 'logging', 'pubsub', 'storage'."
  }
}

variable "org_policies_config" {
  description = "Organization policies customization."
  type = object({
    constraints = optional(object({
      allowed_policy_member_domains = optional(list(string), [])
    }), {})
    import_defaults = optional(bool, false)
    tag_name        = optional(string, "org-policies")
    tag_values = optional(map(object({
      description = optional(string, "Managed by the Terraform organization module.")
      iam         = optional(map(list(string)), {})
      id          = optional(string)
    })), {})
  })
  default = {}
}

variable "organization" {
  description = "Organization details."
  type = object({
    domain      = string
    id          = number
    customer_id = string
  })
}

variable "outputs_location" {
  description = "Enable writing provider, tfvars and CI/CD workflow files to local filesystem. Leave null to disable."
  type        = string
  default     = null
}

variable "prefix" {
  description = "Prefix used for resources that need unique names. Use 9 characters or less."
  type        = string
  validation {
    condition     = try(length(var.prefix), 0) < 10
    error_message = "Use a maximum of 9 characters for prefix."
  }
}

variable "project_parent_ids" {
  description = "Optional parents for projects created here in folders/nnnnnnn format. Null values will use the organization as parent."
  type = object({
    automation = string
    billing    = string
    logging    = string
  })
  default = {
    automation = null
    billing    = null
    logging    = null
  }
  nullable = false
}

variable "workforce_identity_providers" {
  description = "Workforce Identity Federation pools."
  type = map(object({
    attribute_condition = optional(string)
    issuer              = string
    display_name        = string
    description         = string
    disabled            = optional(bool, false)
    saml = optional(object({
      idp_metadata_xml = string
    }), null)
  }))
  default  = {}
  nullable = false
}

variable "workload_identity_providers" {
  description = "Workload Identity Federation pools. The `cicd_repositories` variable references keys here."
  type = map(object({
    attribute_condition = optional(string)
    issuer              = string
    custom_settings = optional(object({
      issuer_uri = optional(string)
      audiences  = optional(list(string), [])
      jwks_json  = optional(string)
    }), {})
  }))
  default  = {}
  nullable = false
  # TODO: fix validation
  # validation {
  #   condition     = var.federated_identity_providers.custom_settings == null
  #   error_message = "Custom settings cannot be null."
  # }
}
