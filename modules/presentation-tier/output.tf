output "bucket_name" {
  value = aws_s3_bucket.spa_bucket.bucket
}

output "distribution_id" {
  value = aws_cloudfront_distribution.spa_distribution.id
}

output "app_url" {
  value = "https://${aws_cloudfront_distribution.spa_distribution.domain_name}"
}
