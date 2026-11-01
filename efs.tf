resource "aws_efs_file_system" "main" {
  creation_token = "${var.project_name}-efs"
  encrypted      = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "${var.project_name}-efs"
  }
}

# One mount target per AZ: clients can only mount through a target in their own AZ.
resource "aws_efs_mount_target" "public" {
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "private" {
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = aws_subnet.private.id
  security_groups = [aws_security_group.efs.id]
}

# Shared entry point for Lambda and EC2: fixed POSIX identity (uid/gid 1000 =
# ec2-user on Amazon Linux) and a dedicated root directory.
resource "aws_efs_access_point" "scraper" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/scraper"

    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }

  tags = {
    Name = "${var.project_name}-scraper-ap"
  }
}
