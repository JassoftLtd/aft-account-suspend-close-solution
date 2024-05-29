output "aft_suspend_account_ou_lambda_arn" {
  description = "Account Supend/Close Lambda ARN"
  value       = aws_lambda_function.aft_suspend_account_ou_lambda.arn
}