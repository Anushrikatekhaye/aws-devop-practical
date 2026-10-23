data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${local.name}-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Session Manager access: no SSH keys or open port 22 required.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "app" {
  statement {
    sid       = "ReadDbSecret"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_secretsmanager_secret.db.arn]
  }

  statement {
    sid       = "ReadReleaseArtifacts"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.app.arn}/release/*"]
  }

  statement {
    sid       = "AppStorage"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.app.arn}/uploads/*"]
  }

  statement {
    sid       = "ListAppBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.app.arn]
  }
}

resource "aws_iam_role_policy" "app" {
  name   = "${local.name}-app-policy"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app.json
}

resource "aws_iam_instance_profile" "app" {
  name = "${local.name}-app-profile"
  role = aws_iam_role.app.name
}
