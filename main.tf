terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.17.0"
    }
  }
}

provider "aws" {
  profile = "default"
  region = "us-east-1"
}

# --- ECR ---

resource "aws_ecr_repository" "api" {
  name                 = "lambda-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# --- Build & push image ---

locals {
  repo_url = aws_ecr_repository.api.repository_url
}

resource "null_resource" "image" {
  triggers = {
    hash = md5(join("-", [for x in fileset("", "./code/{*.py,*.txt,Dockerfile}") : filemd5(x)]))
  }

  provisioner "local-exec" {
    command = <<EOF
      aws ecr get-login-password | docker login --username AWS --password-stdin ${local.repo_url}
      docker build --platform linux/amd64 -t ${local.repo_url}:latest ./code
      docker push ${local.repo_url}:latest
    EOF
  }
}

data "aws_ecr_image" "latest" {
  repository_name = aws_ecr_repository.api.name
  image_tag       = "latest"
  depends_on      = [null_resource.image]
}

# --- IAM Role ---

resource "aws_iam_role" "lambda" {
  name = "lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "lambda_policy"
  role   = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = [
          aws_dynamodb_table.sobreviventes.arn,
          aws_cloudwatch_log_group.api.arn,
          "${aws_cloudwatch_log_group.api.arn}:*"
        ]
      },
    ]
  })

  depends_on = [
    aws_dynamodb_table.sobreviventes,
    aws_cloudwatch_log_group.api
  ]
}

# --- CloudWatch ---

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/api"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_stream" "api" {
  name           = "api-log-stream"
  log_group_name = aws_cloudwatch_log_group.api.name
}

# --- Lambda ---

resource "aws_lambda_function" "api" {
  function_name    = "api"
  role             = aws_iam_role.lambda.arn
  image_uri        = "${aws_ecr_repository.api.repository_url}:latest"
  package_type     = "Image"
  source_code_hash = trimprefix(data.aws_ecr_image.latest.id, "sha256:")
  timeout          = 60

  environment {
    variables = {
      DYNAMODB_TABLE        = aws_dynamodb_table.sobreviventes.name
      S3_BUCKET             = aws_s3_bucket.titanic_bucket.bucket
      ENVIRONMENT           = "prd"
      CLOUDWATCH_LOG_GROUP  = aws_cloudwatch_log_group.api.name
      CLOUDWATCH_LOG_STREAM = aws_cloudwatch_log_stream.api.name
    }
  }

  depends_on = [
    null_resource.image,
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.api,
    aws_dynamodb_table.sobreviventes,
    aws_s3_bucket.titanic_bucket,
    aws_cloudwatch_log_group.api,
    aws_cloudwatch_log_stream.api
  ]
}

# --- Lambda Endpoint ---

resource "aws_lambda_function_url" "api" {
  function_name      = aws_lambda_function.api.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}

output "api_url" {
  value = aws_lambda_function_url.api.function_url
}

# --- Dynamo DB ---

resource "aws_dynamodb_table" "sobreviventes" {
  name           = "sobreviventes"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "sobreviventes"
  }
}

# --- S3 Bucket ---

resource "aws_s3_bucket" "titanic_bucket" {
  bucket = "vb-titanic-case"
}

# --- IAM Policy for S3 Access ---

data "aws_iam_policy_document" "lambda_s3_policy" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.titanic_bucket.arn,
      "${aws_s3_bucket.titanic_bucket.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name   = "lambda_s3_policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_s3_policy.json
}

# ----------------------------------------------------- API Gateway -------------------------------------------------------------

resource "aws_api_gateway_rest_api" "my_api" {
  name = "my-api"
  description = "My API Gateway"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# ---------- /sobreviventes ----------

# ------ Gateway Resources ---------

resource "aws_api_gateway_resource" "sobreviventes" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  parent_id   = aws_api_gateway_rest_api.my_api.root_resource_id
  path_part   = "sobreviventes"
}

resource "aws_api_gateway_resource" "survivor_id" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  parent_id   = aws_api_gateway_resource.sobreviventes.id
  path_part   = "{id}"
}

# ------ Gateway Method ---------

resource "aws_api_gateway_method" "get_survivor_by_id" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.survivor_id.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "proxy_sobreviventes" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.sobreviventes.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "post_sobreviventes" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.sobreviventes.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "delete_survivor_by_id" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.survivor_id.id
  http_method   = "DELETE"
  authorization = "NONE"
}

# ----------- Method Response ----------

resource "aws_api_gateway_method_response" "proxy_sobreviventes" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  resource_id = aws_api_gateway_resource.sobreviventes.id
  http_method = aws_api_gateway_method.proxy_sobreviventes.http_method
  status_code = "200"
}

resource "aws_api_gateway_method_response" "post_sobreviventes" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  resource_id = aws_api_gateway_resource.sobreviventes.id
  http_method = aws_api_gateway_method.post_sobreviventes.http_method
  status_code = "200"
}

resource "aws_api_gateway_method_response" "get_survivor_by_id" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  resource_id = aws_api_gateway_resource.survivor_id.id
  http_method = aws_api_gateway_method.get_survivor_by_id.http_method
  status_code = "200"
}

resource "aws_api_gateway_method_response" "delete_survivor_by_id" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  resource_id = aws_api_gateway_resource.survivor_id.id
  http_method = aws_api_gateway_method.delete_survivor_by_id.http_method
  status_code = "200"
}

# ----------- Integration ----------

resource "aws_api_gateway_integration" "sobreviventes_get" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.sobreviventes.id
  http_method             = aws_api_gateway_method.proxy_sobreviventes.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

resource "aws_api_gateway_integration" "sobreviventes_post" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.sobreviventes.id
  http_method             = aws_api_gateway_method.post_sobreviventes.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

resource "aws_api_gateway_integration" "get_survivor_by_id" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.survivor_id.id
  http_method             = aws_api_gateway_method.get_survivor_by_id.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

resource "aws_api_gateway_integration" "delete_survivor_by_id" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.survivor_id.id
  http_method             = aws_api_gateway_method.delete_survivor_by_id.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

# ------------- API Gateway Deployment -------------

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.sobreviventes_get,
    aws_api_gateway_integration.sobreviventes_post,
    aws_api_gateway_integration.get_survivor_by_id,
    aws_api_gateway_integration.delete_survivor_by_id
  ]
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  stage_name  = "dev"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.my_api.execution_arn}/*/*/*"
}