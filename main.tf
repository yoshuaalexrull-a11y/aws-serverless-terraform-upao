# --- VPC e Infraestructura de Red ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "vpc-image-processor-${var.environment}" }
}

# Subredes Públicas (Solo para el IGW y posibles puntos de entrada)
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "pub-sub-${count.index}-${var.environment}" }
}

# Subredes Privadas (Donde vivirán las Lambdas)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "priv-sub-${count.index}-${var.environment}" }
}

# --- VPC Endpoints (Ahorro de costos: Sin NAT Gateway) ---
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_vpc.main.main_route_table_id]
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# --- Almacenamiento y Colas ---
resource "aws_s3_bucket" "images" {
  bucket = "image-processor-${var.environment}-${var.account_suffix}"
}

resource "aws_sqs_queue" "dlq" {
  name = "image-processor-${var.environment}-dlq"
}

resource "aws_sqs_queue" "main_queue" {
  name = "image-processor-${var.environment}-queue"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

# --- Lambdas ---
resource "aws_lambda_function" "upload" {
  function_name = "upload-lambda-${var.environment}"
  role          = aws_iam_role.upload_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  filename      = "lambda/lambda_dummy.zip" 
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# --- API Gateway y CloudWatch Logs ---
resource "aws_apigatewayv2_api" "http_api" {
  name          = "image-api-${var.environment}"
  protocol_type = "HTTP"
}

resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name              = "/aws/apigateway/image-api-${var.environment}"
  retention_in_days = 14
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_logs.arn
    format          = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.upload.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "upload_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# --- Grupos de Seguridad (Security Groups) ---
resource "aws_security_group" "lambda_sg" {
  name        = "lambda-sg-${var.environment}"
  description = "SG para las Lambdas"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "vpce-sg-${var.environment}"
  description = "SG para VPC Endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
  }
}

# --- Rol de IAM Básico para Lambda ---
resource "aws_iam_role" "upload_role" {
  name = "upload-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.upload_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# =================================================================

# --- . Segunda Lambda (Crop) y su Rol IAM ---
resource "aws_iam_role" "crop_role" {
  name = "crop-lambda-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "crop_vpc_access" {
  role       = aws_iam_role.crop_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "crop_permissions" {
  name = "crop-s3-sqs-permissions-${var.environment}"
  role = aws_iam_role.crop_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetObject", "s3:PutObject"],
        Effect   = "Allow",
        Resource = "${aws_s3_bucket.images.arn}/*"
      },
      {
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
        Effect   = "Allow",
        Resource = aws_sqs_queue.main_queue.arn
      }
    ]
  })
}

resource "aws_lambda_function" "crop" {
  function_name = "crop-lambda-${var.environment}"
  role          = aws_iam_role.crop_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  filename      = "lambda/lambda_dummy.zip" # Reutilizamos tu zip de prueba
  memory_size   = 512
  timeout       = 60
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# --- . Eventos y Triggers (S3 -> SQS -> Lambda) ---

# Permiso para que S3 escriba en la cola SQS
resource "aws_sqs_queue_policy" "s3_to_sqs" {
  queue_url = aws_sqs_queue.main_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.main_queue.arn
      Condition = { ArnLike = { "aws:SourceArn" = aws_s3_bucket.images.arn } }
    }]
  })
}

# Notificación de S3 a SQS
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.images.id
  queue {
    queue_arn     = aws_sqs_queue.main_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
  }
  depends_on = [aws_sqs_queue_policy.s3_to_sqs]
}

# Trigger de SQS a Lambda (Crop)
resource "aws_lambda_event_source_mapping" "sqs_to_crop" {
  event_source_arn = aws_sqs_queue.main_queue.arn
  function_name    = aws_lambda_function.crop.arn
  batch_size       = 5
}

# --- . Alarmas de CloudWatch (DLQ) ---
resource "aws_cloudwatch_metric_alarm" "dlq_alarm" {
  alarm_name          = "dlq-messages-alarm-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alarma cuando hay mensajes en la DLQ"
  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }
}