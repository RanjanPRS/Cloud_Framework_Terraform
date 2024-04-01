resource "aws_vpc" "r1" {
    cidr_block = var.cidr
}

resource "aws_subnet" "r2" {
    vpc_id            = aws_vpc.r1.id
    cidr_block        = var.cidr_s1
    availability_zone = "ap-south-1a"
    map_public_ip_on_launch = true
}

resource "aws_subnet" "r3" {
    vpc_id            = aws_vpc.r1.id
    cidr_block        = var.cidr_s2
    availability_zone = "ap-south-1b"
    map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "r4" {
    vpc_id = aws_vpc.r1.id
}

resource "aws_route_table" "r5" {
    vpc_id = aws_vpc.r1.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.r4.id
    }
}

resource "aws_route_table_association" "r6" {
    subnet_id      = aws_subnet.r2.id
    route_table_id = aws_route_table.r5.id
}

resource "aws_route_table_association" "r7" {
    subnet_id      = aws_subnet.r3.id
    route_table_id = aws_route_table.r5.id
}

resource "aws_security_group" "r8" {
    name        = "websg"
    description = "Allow TLS inbound traffic"
    vpc_id      = aws_vpc.r1.id

    // Ingress rules
    ingress {
        description = "HTTP from VPC"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "SSH"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    // Egress rules
    egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    tags = {
        name = "Web-sg"
    }
}

resource "aws_s3_bucket" "r9" {
    bucket = "mycloudarch2024project"
}

resource "aws_instance" "r10" {
    ami                    = "ami-007020fd9c84e18c7"
    instance_type          = "t2.micro"
    vpc_security_group_ids = [aws_security_group.r8.id]
    subnet_id              = aws_subnet.r2.id
}

resource "aws_instance" "r11" {
    ami                    = "ami-007020fd9c84e18c7"
    instance_type          = "t2.micro"
    vpc_security_group_ids = [aws_security_group.r8.id]
    subnet_id              = aws_subnet.r3.id
    user_data              = base64encode(file("userdata1.sh"))
}

resource "aws_lb" "r12" {
    name               = "myalb"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.r8.id]
    subnets            = [aws_subnet.r2.id, aws_subnet.r3.id]

    tags = {
        name = "Web"
    }
}

resource "aws_lb_target_group" "r13" {
    name     = "myTG"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.r1.id

    health_check {
        path               = "/"
        port               = "traffic-port"
    }
}

resource "aws_lb_target_group_attachment" "r14" {
    target_group_arn = aws_lb_target_group.r13.arn
    target_id        = aws_instance.r10.id
    port             = 80
}

resource "aws_lb_target_group_attachment" "r15" {
    target_group_arn = aws_lb_target_group.r13.arn
    target_id        = aws_instance.r11.id
    port             = 80
}

resource "aws_lb_listener" "r16" {
    load_balancer_arn = aws_lb.r12.arn
    port              = 80
    protocol          = "HTTP"

    default_action {
        type             = "forward" // Specify the type of action, e.g., forward or fixed-response
        target_group_arn = aws_lb_target_group.r13.arn
    }
}

output "loadbalancerdns" {
    value = aws_lb.r12.dns_name
}
