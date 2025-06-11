output "log_group_names" {
  description = "CloudWatch log group names"
  value = {
    cluster = aws_cloudwatch_log_group.eks_cluster.name
    app     = aws_cloudwatch_log_group.app_logs.name
  }
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}