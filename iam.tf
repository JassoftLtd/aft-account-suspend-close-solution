resource "aws_iam_role" "iam_for_account_suspend_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_policy" "lambda_assume_acc_close_policy" {
  name        = "acc-close-lambda-assume-policy"
  description = "acc-close-lambda-assume-policy"
  policy      = data.aws_iam_policy_document.lambda_assume_acc_close_policy.json
}


resource "aws_iam_role_policy_attachment" "assume_policy_attach_acc_close" {
  role       = aws_iam_role.iam_for_account_suspend_lambda.name
  policy_arn = aws_iam_policy.lambda_assume_acc_close_policy.arn
}


resource "aws_iam_role_policy" "dynamodb_lambda_policy" {
  name   = "lambda-dynamodb-policy"
  role   = aws_iam_role.iam_for_account_suspend_lambda.id
  policy = data.aws_iam_policy_document.dynamodb_lambda_policy.json
}