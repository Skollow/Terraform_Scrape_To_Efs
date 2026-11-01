locals {
  lambda_name      = "${var.project_name}-scraper"
  lambda_runtime   = "python3.12"
  lambda_src_dir   = "${path.module}/lambda"
  lambda_build_dir = "${path.module}/build/lambda"
  efs_mount_path   = "/mnt/efs"
}

# --- Packaging ---------------------------------------------------------------

# Installs requirements.txt (Linux wheels) plus the handler into build/lambda.
# Re-runs whenever anything under lambda/ changes.
resource "terraform_data" "lambda_build" {
  triggers_replace = {
    source_hash = sha256(join("", [for f in sort(fileset(local.lambda_src_dir, "**")) : filesha256("${local.lambda_src_dir}/${f}")]))
    runtime     = local.lambda_runtime
  }

  provisioner "local-exec" {
    working_dir = path.module
    command     = "${var.python_command} scripts/build_lambda.py ${trimprefix(local.lambda_runtime, "python")}"
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = local.lambda_build_dir
  output_path = "${path.module}/build/lambda.zip"

  depends_on = [terraform_data.lambda_build]
}

# --- IAM ---------------------------------------------------------------------

resource "aws_iam_role" "lambda" {
  name = "${local.lambda_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# CloudWatch Logs + the ENI permissions a VPC-attached Lambda needs.
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_efs" {
  name = "efs-access-point-rw"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
        ]
        Resource = aws_efs_file_system.main.arn
        Condition = {
          StringEquals = {
            "elasticfilesystem:AccessPointArn" = aws_efs_access_point.scraper.arn
          }
        }
      }
    ]
  })
}

# --- Function ----------------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.lambda_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "scraper" {
  function_name = local.lambda_name
  role          = aws_iam_role.lambda.arn
  runtime       = local.lambda_runtime
  architectures = ["x86_64"]
  handler       = "lambda_function.lambda_handler"
  timeout       = 30

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  # Private subnet only: outbound internet goes through the NAT gateway.
  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  file_system_config {
    arn              = aws_efs_access_point.scraper.arn
    local_mount_path = local.efs_mount_path
  }

  environment {
    variables = {
      MOUNT_PATH = local.efs_mount_path
      SOURCE_URL = var.source_url
    }
  }

  depends_on = [
    aws_efs_mount_target.private,
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_iam_role_policy.lambda_efs,
    aws_cloudwatch_log_group.lambda,
  ]
}

# --- Schedule ----------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "scraper_schedule" {
  name                = "${local.lambda_name}-schedule"
  description         = "Runs the scraper Lambda on a schedule"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "scraper" {
  rule = aws_cloudwatch_event_rule.scraper_schedule.name
  arn  = aws_lambda_function.scraper.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scraper.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scraper_schedule.arn
}
