# Rules are standalone resources (not inline blocks) so each one has a single,
# accurate description and inline/standalone rules never fight over the same SG.

# --- EC2 ---------------------------------------------------------------------

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2"
  description = "EC2 inspection host: SSH in from allowed_ssh_cidr, all outbound"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-ec2"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_ssh" {
  security_group_id = aws_security_group.ec2.id
  description       = "SSH from the operator CIDR"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.allowed_ssh_cidr
}

resource "aws_vpc_security_group_egress_rule" "ec2_all" {
  security_group_id = aws_security_group.ec2.id
  description       = "All outbound (package installs, NFS to EFS)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- Lambda ------------------------------------------------------------------

resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda"
  description = "Scraper Lambda: no inbound, all outbound"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-lambda"
  }
}

resource "aws_vpc_security_group_egress_rule" "lambda_all" {
  security_group_id = aws_security_group.lambda.id
  description       = "All outbound (HTTPS to the source API via NAT, NFS to EFS)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- EFS ---------------------------------------------------------------------

resource "aws_security_group" "efs" {
  name        = "${var.project_name}-efs"
  description = "EFS mount targets: NFS in from the EC2 and Lambda SGs only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-efs"
  }
}

resource "aws_vpc_security_group_ingress_rule" "efs_nfs_from_ec2" {
  security_group_id            = aws_security_group.efs.id
  description                  = "NFS from the EC2 instance"
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = aws_security_group.ec2.id
}

resource "aws_vpc_security_group_ingress_rule" "efs_nfs_from_lambda" {
  security_group_id            = aws_security_group.efs.id
  description                  = "NFS from the scraper Lambda"
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = aws_security_group.lambda.id
}
