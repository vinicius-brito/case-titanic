# --------- Provider ---------
provider "aws" {
  region = "us-east-1"
}

# --------- Definição Lambda Function ---------
resource "aws_lambda_function" "api_sobreviventes" {
  function_name = "api_sobreviventes"
  image_uri     = "021891584200.dkr.ecr.us-east-1.amazonaws.com/case_itau:v10"
  package_type  = "Image"
  role          = aws_iam_role.lambda_exec.arn
  timeout       = 15
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "api_gateway_role" {
  name = "api_gateway_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "api_gateway_cloudwatch_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_basic_execution" {
  role       = aws_iam_role.api_gateway_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch_logs_full_access" {
  role       = aws_iam_role.api_gateway_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch_logs" {
  role       = aws_iam_role.api_gateway_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_api_gateway_rest_api" "api" {
  name        = "case-itau-api"
  description = "Case Itau API Gateway"
}

resource "aws_api_gateway_resource" "resource_sobreviventes" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "sobreviventes"
}

resource "aws_api_gateway_method" "get_sobreviventes" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource_sobreviventes.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "post_sobreviventes" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource_sobreviventes.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "delete_sobreviventes" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource_sobreviventes.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "sobreviventes_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.resource_sobreviventes.id
  http_method             = "ANY"
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.api_sobreviventes.invoke_arn
}

resource "aws_lambda_permission" "api_gateway_sobreviventes" {
  statement_id  = "AllowAPIGatewayInvokeGetSobreviventes"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_sobreviventes.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/sobreviventes"
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  depends_on = [
    aws_api_gateway_integration.get_sobreviventes_integration,
    aws_api_gateway_integration.post_sobreviventes_integration,
    aws_api_gateway_integration.delete_sobreviventes_integration,
    aws_lambda_permission.api_gateway_get_sobreviventes,
    aws_lambda_permission.api_gateway_post_sobreviventes,
    aws_lambda_permission.api_gateway_delete_sobreviventes
  ]
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "dev"
  deployment_id = aws_api_gateway_deployment.deployment.id

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format          = jsonencode({
      requestId       = "$context.requestId",
      ip              = "$context.identity.sourceIp",
      caller          = "$context.identity.caller",
      user            = "$context.identity.user",
      requestTime     = "$context.requestTime",
      httpMethod      = "$context.httpMethod",
      resourcePath    = "$context.resourcePath",
      status          = "$context.status",
      protocol        = "$context.protocol",
      responseLength  = "$context.responseLength",
      requestBody     = "$context.requestBody",
      integrationRequestId = "$context.integration.requestId",
      integrationStatus = "$context.integration.status",
      integrationLatency = "$context.integration.latency",
      integrationError = "$context.integration.error"
    })
  }
}

resource "aws_api_gateway_method_settings" "method_settings" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name

  method_path = "*/*"

  settings {
    metrics_enabled     = true
    logging_level       = "INFO"
    data_trace_enabled  = true
  }
}

resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name = "/aws/api-gateway/${aws_api_gateway_rest_api.api.id}/dev"
  retention_in_days = 14
}