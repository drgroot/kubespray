variable "name" {
  description = "Prefix for generated usernames; also identifies the Workspace."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,30}$", var.name))
    error_message = "name must start with a lowercase letter and contain at most 31 lowercase letters, digits, or underscores."
  }
}

variable "input" {
  description = "Logical KV v2 path to initialize, for example onprem/vendor/postgres."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+(/[^/]+)*$", var.input))
    error_message = "input must be a logical mount/secret path without leading, trailing, or repeated slashes."
  }
}

variable "properties" {
  description = "Comma-separated property names, in the same order as value-types and specialchars."
  type        = string

  validation {
    condition = (
      alltrue([for key in split(",", var.properties) : length(trimspace(key)) > 0]) &&
      length(distinct([for key in split(",", var.properties) : trimspace(key)])) == length(split(",", var.properties))
    )
    error_message = "properties must contain unique, nonempty comma-separated names."
  }
}

variable "value-types" {
  description = "Comma-separated username/password value types, one per property."
  type        = string

  validation {
    condition = (
      length(split(",", var.value-types)) == length(split(",", var.properties)) &&
      alltrue([for kind in split(",", var.value-types) : contains(["username", "password"], lower(trimspace(kind)))])
    )
    error_message = "value-types must provide username or password for every property."
  }
}

variable "specialchars" {
  description = "Comma-separated yes/no flags allowing special characters for each property."
  type        = string

  validation {
    condition = (
      length(split(",", var.specialchars)) == length(split(",", var.properties)) &&
      alltrue([for flag in split(",", var.specialchars) : contains(["yes", "no"], lower(trimspace(flag)))])
    )
    error_message = "specialchars must provide yes or no for every property."
  }
}

variable "output" {
  description = "Optional second logical KV v2 path to initialize with the selected input values; none disables it. Existing output properties are also preserved."
  type        = string
  default     = "none"

  validation {
    condition     = var.output == "none" || can(regex("^[^/]+/[^/]+(/[^/]+)*$", var.output))
    error_message = "output must be none or a logical mount/secret path."
  }
}
