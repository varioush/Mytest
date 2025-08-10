resource "aws_wafv2_ip_set" "block_ips" {
  name               = "block-ips"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = ["198.51.100.0/24"]
}

resource "aws_wafv2_web_acl" "alb_acl" {
  name  = "alb-acl"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "BlockBadIPs"
    priority = 1
    action {
      block {}
    }
    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.block_ips.arn
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockBadIPs"
      sampled_requests_enabled   = true
    }
  }
}
