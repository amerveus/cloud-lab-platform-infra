variable "name" {
  type = string
}

variable "alert_email" {
  type      = string
  sensitive = true
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-lab-jobs-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "jobs" {
  name                       = "${var.name}-lab-jobs"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.jobs.arn]
  })
}

resource "aws_sns_topic" "notifications" {
  name = "${var.name}-notifications"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  alarm_name          = "${var.name}-lab-jobs-dlq-not-empty"
  alarm_description   = "A lab job failed 3 times and was moved to the DLQ"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.dlq.name }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.notifications.arn]
}

resource "aws_cloudwatch_metric_alarm" "backlog_age" {
  alarm_name          = "${var.name}-lab-jobs-backlog-age"
  alarm_description   = "Lab jobs have waited more than 5 minutes"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  dimensions          = { QueueName = aws_sqs_queue.jobs.name }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 300
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.notifications.arn]
}

output "queue_url" {
  value = aws_sqs_queue.jobs.url
}

output "queue_arn" {
  value = aws_sqs_queue.jobs.arn
}

output "queue_name" {
  value = aws_sqs_queue.jobs.name
}

output "dlq_url" {
  value = aws_sqs_queue.dlq.url
}

output "topic_arn" {
  value = aws_sns_topic.notifications.arn
}
