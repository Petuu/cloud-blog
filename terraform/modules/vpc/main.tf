resource "aws_vpc" "main" {
    cidr_block              = var.cidr_block
    enable_dns_hostnames    = true
    enable_dns_support      = true


    tags    = merge(var.tags, {
        name    = "${var.project_name}-vpc"
    })
}


resource "aws_subnet" "public" {
    count               = length(var.azs)
    vpc_id              = aws_vpc.main.id
    cidr_block          = var.public_subnets[count.index]
    availability_zone = var.azs[count.index]

    map_public_ip_on_launch = true

    tags = merge(var.tags, {
        name = "${var.project_name}-public-${var.azs[count.index]}"
        "kubernetes.io/role/elb" = "1"
    })
}


resource "aws_subnet" "private" {
    count               = length(var.azs)
    vpc_id              = aws_vpc.main.id
    cidr_block          = var.private_subnets[count.index]
    availability_zone   = var.azs[count.index]


    tags = merge(var.tags, {
        name = "${var.project_name}-private-${var.azs[count.index]}"
        "kubernetes.io/role/internal-elb"   = "1"
    })
}


resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id


    tags = merge(var.tags, {
        name = "${var.project_name}-igw"
    })
}


resource "aws_eip" "nat" {
    domain = "vpc"


    tags = merge(var.tags, {
        name = "${var.project_name}-nat-eip"
    })
}


resource "aws_nat_gateway" "main" {
    allocation_id   = aws_eip.nat.id
    subnet_id       = aws_subnet.public[0].id


    tags = merge(var.tags, {
        name = "${var.project_name}-nat"
    })
}


resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id


    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main.id
    }

tags = merge(var.tags, {
    name = "${var.project_name}-public-rt"
})
}


resource "aws_route_table" "private" {
    vpc_id = aws_vpc.main.id


    route {
        cidr_block      = "0.0.0.0/0"
        nat_gateway_id  = aws_nat_gateway.main.id
    }


tags = merge(var.tags, {
    name    = "${var.project_name}-private-rt"
   })
}


resource "aws_route_table_association" "public" {
    count               = length(var.azs)
    subnet_id           = aws_subnet.public[count.index].id
    route_table_id      = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
    count               = length(var.azs)
    subnet_id           = aws_subnet.private[count.index].id
    route_table_id      = aws_route_table.private.id
}