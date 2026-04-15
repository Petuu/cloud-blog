variable "project_name" {
    description = "프로젝트 이름"
    type        = string
}

variable "cidr_block" {
    description = "VPC CIDR 블록"
    type        = string
    default     = "10.0.0.0/16"
}

variable "azs" {
    description = "사용할 가용영역 목록"
    type        = "list(string)
    default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "private_subnets" {
    description = "프라이빗 서브넷 CIDR 목록"
    type        = list(string)
    default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnets" {
    description = "퍼블릭 서브넷 CIDR 목록"
    type        = list(string)
    default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "tags" {
    description = "공통 태그"
    type        = map(string)
    default     = {}
}