output "ec2_public_ip" {
  description = "Public IP of the EC2 inspection host."
  value       = aws_instance.inspector.public_ip
}

output "ssh_command" {
  description = "SSH into the EC2 host (assumes the private key sits next to the public key)."
  value       = "ssh -i ${trimsuffix(var.ssh_public_key_path, ".pub")} ec2-user@${aws_instance.inspector.public_ip}"
}

output "efs_id" {
  description = "ID of the EFS file system."
  value       = aws_efs_file_system.main.id
}

output "lambda_function_name" {
  description = "Name of the scraper Lambda function."
  value       = aws_lambda_function.scraper.function_name
}
