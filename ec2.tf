resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = file(var.ssh_public_key_path)
}

# Small host for inspecting what the Lambda wrote; mounts the same access point at /mnt/efs.
resource "aws_instance" "inspector" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.main.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    dnf install -y amazon-efs-utils
    mkdir -p /mnt/efs
    echo "${aws_efs_file_system.main.id}:/ /mnt/efs efs _netdev,tls,accesspoint=${aws_efs_access_point.scraper.id} 0 0" >> /etc/fstab
    mount /mnt/efs
  EOF

  # The mount in user_data fails if the mount target isn't available yet.
  depends_on = [aws_efs_mount_target.public]

  tags = {
    Name = "${var.project_name}-inspector"
  }
}
