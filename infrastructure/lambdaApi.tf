provider "aws" {
  region = "eu-central-1"
}

# Network

data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [var.root_vpc]
  }
}

data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.subnets.ids)
  id       = each.value
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = var.root_vpc
  service_name        = "com.amazonaws.eu-central-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in data.aws_subnet.default : s.id]
  security_group_ids  = [var.root_sg]
  private_dns_enabled = true
}

# GoLang Lambda

resource "aws_iam_role" "lambda_role" {
  name = "lambdaExecutionRole"
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

resource "aws_iam_policy" "lambda_secret_policy" {
  name = "lambdaSecretPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [aws_secretsmanager_secret.rds_proxy_secret.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_secret_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_secret_policy.arn
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
    subnet_ids         = [for s in data.aws_subnet.default : s.id]
    security_group_ids = [var.root_sg]
  }

  environment {
    variables = {
      DB_HOST       = aws_db_proxy.rds_proxy.endpoint
      DB_NAME       = aws_db_instance.postgres.db_name
      DB_SECRET_ARN = aws_secretsmanager_secret.rds_proxy_secret.arn
    }
  }
}

# API Gateway

resource "aws_api_gateway_rest_api" "api" {
  name        = "goLambdaAPI"
  description = "API Gateway for the Go Lambda"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.proxy.id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = true
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
  depends_on  = [aws_lambda_function.go_lambda]
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    lambda = aws_lambda_function.go_lambda.source_code_hash
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
  stage_name    = "prod"
}

resource "aws_api_gateway_api_key" "api_key" {
  name  = "defaultApiKey"
  value = "37fb385a-115a-4140-888d-0d47e552da04"
}

resource "aws_api_gateway_usage_plan" "ratelimit" {
  name = "defaultUsagePlan"

  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_stage.stage.stage_name
  }

  quota_settings {
    limit  = 10000
    period = "DAY"
  }

  throttle_settings {
    rate_limit  = 1
    burst_limit = 1
  }
}

resource "aws_api_gateway_usage_plan_key" "plan_key" {
  key_id        = aws_api_gateway_api_key.api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.ratelimit.id
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
  vpc_security_group_ids = [var.root_sg]
}

# RDS Proxy

resource "aws_secretsmanager_secret" "rds_proxy_secret" {
  name = "rds-proxy"
}

resource "aws_secretsmanager_secret_version" "rds_secret_value" {
  secret_id = aws_secretsmanager_secret.rds_proxy_secret.id
  secret_string = jsonencode({
    username = aws_db_instance.postgres.username
    password = aws_db_instance.postgres.password
  })
}

resource "aws_iam_role" "rds_proxy_role" {
  name = "rdsProxyRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "rds_proxy_policy" {
  name = "rdsProxyPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = [aws_secretsmanager_secret.rds_proxy_secret.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetRandomPassword",
          "secretsmanager:ListSecrets",
          "rds-db:Connect"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_proxy_attachment" {
  role       = aws_iam_role.rds_proxy_role.name
  policy_arn = aws_iam_policy.rds_proxy_policy.arn
}

resource "aws_db_proxy" "rds_proxy" {
  name                   = "rds-lambda-proxy"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  vpc_subnet_ids         = [for s in data.aws_subnet.default : s.id]
  vpc_security_group_ids = [var.root_sg]
  role_arn               = aws_iam_role.rds_proxy_role.arn

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.rds_proxy_secret.arn
  }
}

resource "aws_db_proxy_default_target_group" "rds_proxy_target_group" {
  db_proxy_name = aws_db_proxy.rds_proxy.name
}

resource "aws_db_proxy_target" "rds_proxy_target" {
  db_instance_identifier = aws_db_instance.postgres.identifier
  db_proxy_name          = aws_db_proxy.rds_proxy.name
  target_group_name      = aws_db_proxy_default_target_group.rds_proxy_target_group.name
}
