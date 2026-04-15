output "vpc_id" {
    description = "VPC ID"
    value       = aws_vpc.main.id
}


output "public_subnet_ids" {
    description = "퍼블릭 서브넷 ID 목록"
    value       = aws_subnet.public[*].id
}


output "private_subnet_ids" {
    description = "프라이빗 서브넷 ID 목록"
    value       = aws_subnet.private[*].id
}