provider "aws" {
  region = "eu-central-1"
}

# GoLang Lambda

resource "aws_iam_role" "lambda_role" {
  name = "lamba_execution_role"
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

resource "aws_iam_policy_attachment" "lambda_policy" {
  name       = "lambda_basic_policy_attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "go_lambda" {
  function_name    = "goLambdaFunction"
  role             = aws_iam_role.lambda_role.arn
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  architectures    = ["arm64"]
  filename         = "../lambda/lambda.zip"
  source_code_hash = filebase64sha256("../lambda/lambda.zip")

  vpc_config {
    subnet_ids         = ["subnet-0d4b5432b3eb3b0d6", "subnet-0ff2b125a02d89e5d", "subnet-0da3627c70638a215"]
    security_group_ids = ["sg-0c803703df1cc80fa"]
  }

  environment {
    variables = {
      DB_HOST     = aws_db_instance.postgres.address
      DB_NAME     = aws_db_instance.postgres.db_name
      DB_USER     = aws_db_instance.postgres.username
      DB_PASSWORD = aws_db_instance.postgres.password
    }
  }
}

# API Gateway

resource "aws_api_gateway_rest_api" "api" {
  name        = "GoLambdaAPI"
  description = "API Gateway for the Go Lambda"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.go_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on  = [aws_api_gateway_integration.lambda]
  rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
  stage_name    = "prod"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.go_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Postgres RDS

resource "aws_db_instance" "postgres" {
  identifier             = "estatdb"
  engine                 = "postgres"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 5
  storage_type           = "gp2"
  db_name                = "estat"
  username               = "rootUser"
  password               = var.rds_password
  publicly_accessible    = false
  skip_final_snapshot    = true
  vpc_security_group_ids = ["sg-0c803703df1cc80fa"]
}

