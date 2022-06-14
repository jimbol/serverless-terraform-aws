/*
  The hosting module is used to create a hosting environment within S3 and Cloudfront.
  An existing and verified acm_certificate_arn is required for this module.
*/
locals {
  s3_origin_id = "s3_site_origin_id"
}

resource "aws_s3_bucket" "s3_hosting" {
  bucket = var.domain

  lifecycle {
    prevent_destroy = false
  }

  # Terraform wont delete an S3 bucket with contents unless you force_destroy
  force_destroy = true

  tags = {
    Name = "Serverless Terraform Hosting"
  }
}

resource "aws_s3_bucket_acl" "s3_hosting_access" {
  bucket = aws_s3_bucket.s3_hosting.id
  acl    = "public-read"
}

resource "aws_s3_bucket_website_configuration" "s3_website_config" {
  bucket = aws_s3_bucket.s3_hosting.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_policy" "s3_hosting_policy" {
  bucket = aws_s3_bucket.s3_hosting.id

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
      {
          "Sid": "PublicReadGetObject",
          "Effect": "Allow",
          "Principal": "*",
          "Action": [
             "s3:GetObject"
          ],
          "Resource": [
             "arn:aws:s3:::${aws_s3_bucket.s3_hosting.id}/*"
          ]
      }
    ]
}
POLICY
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.s3_hosting.website_endpoint
    origin_id   = local.s3_origin_id
    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  aliases = [var.domain]
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Cloudfront distribution for embedded web application"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = var.env
  }

  viewer_certificate {
    acm_certificate_arn = "arn:aws:acm:us-east-1:425010903010:certificate/bb98da90-79e9-43f9-80b2-0c60d70a916a"
    ssl_support_method  = "sni-only"
    cloudfront_default_certificate = false
  }
}

resource "aws_route53_record" "root" {
  zone_id = "Z02574524SEVSLHAGL6Q" # zone id of Route53
  name    = "serverlessterraform.com"
  type    = "A"

  alias {
    name                   = aws_s3_bucket.s3_hosting.website_domain
    zone_id                = aws_s3_bucket.s3_hosting.hosted_zone_id
    evaluate_target_health = true
  }
}
