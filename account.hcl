# ---------------------------------------------------------------------------------------------------------------------
# ACCOUNT-LEVEL VARIABLES
# These variables apply to the entire AWS account.
# For single-account setup, this file is at the root level.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  account_name   = "fng"              # TODO: Change to your company/project name
  aws_account_id = "1802180418021804" # TODO: Change to your AWS Account ID

  # Optional: Add more account-level settings
  owner_email = "thuocnv1802@gmail.com"
  cost_center = "engineering"
}
