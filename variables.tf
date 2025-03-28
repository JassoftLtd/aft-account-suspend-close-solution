variable "cloudwatch_log_group_retention" {
  description = "Lambda CloudWatch log group retention period"
  type        = string
  default     = "0"
  validation {
    condition     = contains(["1", "3", "5", "7", "14", "30", "60", "90", "120", "150", "180", "365", "400", "545", "731", "1827", "3653", "0"], var.cloudwatch_log_group_retention)
    error_message = "Valid values for var: cloudwatch_log_group_retention are (1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653, and 0)."
  }
}

variable "aft_to_ct_cross_account_role_name" {
  type        = string
  description = "AFT Cross Account Role"
  default     = "AFTCrossAccountRole"
}

variable "ct_account_id" {
  type        = string
  description = "AFT Account ID"
  default     = ""
}

variable "ct_destination_ou" {
  type        = string
  description = "Destination OU into which Account will be moved"
  default     = ""
}

variable "ct_root_ou_id" {
  type        = string
  description = "CT Account Root OU ID"
  default     = ""
}

variable "aft-request-audit-table-stream-arn" {
  type        = string
  description = "DynamoDB table aft-request-audit table stream ARN"
  default     = ""
}

variable "aft_kms_key_arn" {
  type        = string
  description = "AFT KMS arn"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private Subnets"
  default     = []
}

variable "private_sg_id" {
  type        = string
  description = "Private Subnet Security Group"
  default     = ""
}

variable "aft_enable_vpc" {
  type = bool
}
