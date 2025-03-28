
resource "aws_sqs_queue" "aft_suspend_account_dlq" {
  name                       = "aft-suspend-account-dlq"
  delay_seconds              = 300
  max_message_size           = 2048
  message_retention_seconds  = 1209600
  visibility_timeout_seconds = 310
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true
}

resource "aws_lambda_code_signing_config" "this" {
  description = "Code signing config for AFT Lambda"

  allowed_publishers {
    signing_profile_version_arns = [
      aws_signer_signing_profile.this.arn,
    ]
  }

  policies {
    untrusted_artifact_on_deployment = "Warn"
  }
}

resource "aws_signer_signing_profile" "this" {
  name_prefix = "AwsLambdaCodeSigningAction"
  platform_id = "AWSLambda-SHA384-ECDSA"

  signature_validity_period {
    value = 5
    type  = "YEARS"
  }
}

resource "aws_lambda_function" "aft_suspend_account_ou_lambda" {
  filename                = data.archive_file.aft_suspend_account.output_path
  function_name           = "aft_suspend_account_ou"
  description             = "AFT account provisioning - Suspend Account from OU"
  role                    = aws_iam_role.iam_for_account_suspend_lambda.arn
  handler                 = "aft-suspend-account.lambda_handler"
  code_signing_config_arn = aws_lambda_code_signing_config.this.arn
  source_code_hash        = data.archive_file.aft_suspend_account.output_base64sha256
  runtime                 = "python3.9"
  kms_key_arn             = var.aft_kms_key_arn

  dead_letter_config {
    target_arn = aws_sqs_queue.aft_suspend_account_dlq.arn
  }
  dynamic "vpc_config" {
    for_each = var.aft_enable_vpc ? [1] : []

    content {
      subnet_ids         = var.private_subnets
      security_group_ids = [var.private_sg_id]
    }
  }

  environment {
    variables = {
      REGION              = data.aws_region.aft_management_region.name
      CROSS_ACC_ROLE_NAME = var.aft_to_ct_cross_account_role_name
      AFT_CT_ACCOUNT      = var.ct_account_id
      DESTINATIONOU       = var.ct_destination_ou
      ROOTOU_ID           = var.ct_root_ou_id
    }
  }
  timeout = 30
  tracing_config {
    mode = "Active"
  }
  reserved_concurrent_executions = 1
}

resource "aws_lambda_event_source_mapping" "lambda_dynamodb" {
  event_source_arn  = var.aft-request-audit-table-stream-arn
  function_name     = aws_lambda_function.aft_suspend_account_ou_lambda.arn
  starting_position = "LATEST"
}

resource "aws_cloudwatch_log_group" "aft_suspend_account_ou_lambda_log" {
  name              = "/aws/lambda/aft_suspend_account_ou_lambda_log"
  retention_in_days = var.cloudwatch_log_group_retention
  # kms_key_id        = var.aft_kms_key_arn
}
