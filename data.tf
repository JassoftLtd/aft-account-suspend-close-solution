# Update Alternate SSO
data "aws_region" "aft_management_region" {}

data "aws_caller_identity" "aft_management_id" {}

data "aws_arn" "aft_to_ct_cross_account_role_arn" {
  arn = "arn:aws:iam::${var.ct_account_id}:role/${var.aft_to_ct_cross_account_role_name}"
}

data "aws_iam_policy" "AmazonSQSFullAccess" {
  name = "AmazonSQSFullAccess"
}

data "aws_iam_policy" "CloudWatchFullAccess" {
  name = "CloudWatchFullAccess"
}


data "archive_file" "aft_suspend_account" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/aft_suspend_account"
  output_path = "${path.module}/lambda/aft_suspend_account.zip"
}

data "aws_iam_policy_document" "dynamodb_lambda_policy" {
  statement {
    sid       = "AllowLambdaFunctionToCreateLogs"
    actions   = ["logs:*"]
    effect    = "Allow"
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    sid       = "AllowLambdaFunctionInvocation"
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = ["arn:aws:dynamodb:${data.aws_region.aft_management_region.name}:${data.aws_caller_identity.aft_management_id.account_id}:table/aft-request-audit/stream/*"]
  }

  statement {
    sid       = "AllowLambdaFunctionKMSAccess"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.aft_kms_key_arn]
  }

  statement {
    sid       = "AllowLambdaFunctionDDBAccess"
    effect    = "Allow"
    actions   = ["dynamodb:DescribeTable", "dynamodb:Query", "dynamodb:Scan"]
    resources = ["arn:aws:dynamodb:${data.aws_region.aft_management_region.name}:${data.aws_caller_identity.aft_management_id.account_id}:table/aft-request-metadata/index/emailIndex"]
  }

  statement {
    sid       = "APIAccessForDynamoDBStreams"
    effect    = "Allow"
    actions   = ["dynamodb:GetRecords", "dynamodb:GetShardIterator", "dynamodb:DescribeStream", "dynamodb:ListStreams"]
    resources = ["arn:aws:dynamodb:${data.aws_region.aft_management_region.name}:${data.aws_caller_identity.aft_management_id.account_id}:table/aft-request-audit/stream/*"]
  }
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    effect = "Allow"
    sid    = ""
  }
}

data "aws_iam_policy_document" "lambda_assume_acc_close_policy" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [data.aws_arn.aft_to_ct_cross_account_role_arn.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.aft_suspend_account_dlq.arn]
  }
}
