resource "aws_appautoscaling_target" "worker" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.worker.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 0
  max_capacity       = var.max_tasks
}

resource "aws_appautoscaling_policy" "scale_out" {
  name               = "${var.name}-worker-scale-out"
  policy_type        = "StepScaling"
  service_namespace  = aws_appautoscaling_target.worker.service_namespace
  resource_id        = aws_appautoscaling_target.worker.resource_id
  scalable_dimension = aws_appautoscaling_target.worker.scalable_dimension

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      metric_interval_upper_bound = 20
      scaling_adjustment          = 1
    }

    step_adjustment {
      metric_interval_lower_bound = 20
      scaling_adjustment          = 2
    }
  }
}

resource "aws_appautoscaling_policy" "scale_in" {
  name               = "${var.name}-worker-scale-in"
  policy_type        = "StepScaling"
  service_namespace  = aws_appautoscaling_target.worker.service_namespace
  resource_id        = aws_appautoscaling_target.worker.resource_id
  scalable_dimension = aws_appautoscaling_target.worker.scalable_dimension

  step_scaling_policy_configuration {
    adjustment_type         = "ExactCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = 0
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "backlog" {
  alarm_name          = "${var.name}-worker-backlog"
  alarm_description   = "Jobs are waiting: add workers"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = var.queue_name }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_appautoscaling_policy.scale_out.arn]
}

resource "aws_cloudwatch_metric_alarm" "idle" {
  alarm_name          = "${var.name}-worker-idle"
  alarm_description   = "Queue empty and nothing in flight for 5 minutes: scale to zero"
  evaluation_periods  = 5
  threshold           = 0
  comparison_operator = "LessThanOrEqualToThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_appautoscaling_policy.scale_in.arn]

  metric_query {
    id          = "total"
    expression  = "visible + inflight"
    label       = "Messages visible + in flight"
    return_data = true
  }

  metric_query {
    id = "visible"
    metric {
      namespace   = "AWS/SQS"
      metric_name = "ApproximateNumberOfMessagesVisible"
      dimensions  = { QueueName = var.queue_name }
      period      = 60
      stat        = "Maximum"
    }
  }

  metric_query {
    id = "inflight"
    metric {
      namespace   = "AWS/SQS"
      metric_name = "ApproximateNumberOfMessagesNotVisible"
      dimensions  = { QueueName = var.queue_name }
      period      = 60
      stat        = "Maximum"
    }
  }
}
