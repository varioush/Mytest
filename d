variable "block_ips" {
  type    = list(string)
  default = [
    "198.51.100.0/24",  # Org IP to block
    "198.51.100.45/32"  # Specific IP to block
  ]
}

variable "allow_ips" {
  type    = list(string)
  default = [
    "203.0.113.0/24",   # Allowed CIDR
    "198.51.100.45/32"  # <- If in both lists, it will be blocked due to priority
  ]
}

# Block IP Set
resource "aws_wafv2_ip_set" "block_ips" {
  name               = "block-ips"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.block_ips
}

# Allow IP Set
resource "aws_wafv2_ip_set" "allow_ips" {
  name               = "allow-ips"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.allow_ips
}

# Web ACL
resource "aws_wafv2_web_acl" "alb_acl" {
  name  = "alb-allow-block-acl"
  scope = "REGIONAL"

  # Default: Block all
  default_action {
    block {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "alb-allow-block-acl"
    sampled_requests_enabled   = true
  }

  # 1. Block List Rule (highest priority)
  rule {
    name     = "BlockList"
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
      metric_name                = "BlockList"
      sampled_requests_enabled   = true
    }
  }

  # 2. Allow List Rule
  rule {
    name     = "AllowList"
    priority = 2

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.allow_ips.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowList"
      sampled_requests_enabled   = true
    }
  }
}

# Associate WAF with ALB
resource "aws_wafv2_web_acl_association" "alb_assoc" {
  resource_arn = aws_lb.alb.arn
  web_acl_arn  = aws_wafv2_web_acl.alb_acl.arn
}
