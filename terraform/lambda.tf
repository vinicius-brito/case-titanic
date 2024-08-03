resource "aws_lambda_function" "api_sobreviventes" {
  function_name = "api_sobreviventes"
  image_uri     = "021891584200.dkr.ecr.us-east-1.amazonaws.com/case_itau:v10"
  package_type  = "Image"
  role          = aws_iam_role.lambda_exec.arn
  timeout       = 15
}

