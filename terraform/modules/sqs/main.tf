resource "aws_sqs_queue" "eks_sqs" {
  region                    = var.region
  name                      = "eks_sqs"
  delay_seconds             = 90
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.eks_sqs_deadletter.arn
    maxReceiveCount     = 4
  })

  tags = {
    Environment = "production"
  }
}

resource "aws_sqs_queue" "eks_sqs_deadletter" {
  name   = "sqs_deadletter_queue"
  region = var.region
  sqs_managed_sse_enabled = true
}