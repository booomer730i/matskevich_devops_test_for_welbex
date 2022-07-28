terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token     = "<OAuth>"
  cloud_id  = "cloud_id"
  folder_id = "/"
  zone      = "<зона доступности по умолчанию>"
}

resource "yandex_vpc_network" "default" {
  name        = "network-1"
  description = "devops_net"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet-1"
  description    = "null"
  v4_cidr_blocks = ["128.0.4.10/32"]
  zone           = "zone-1"
  network_id     = "yandex_vpc_network"
}

#this is a VM 
resource "yandex_compute_instance" "vm-1" {
  name = "terraform1"
  
  resources {
    cores  = 2
    memory = 2
  }

  metadata {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }
}

# this is setting up a L7 load balancer with SSL termination
resource "yandex_alb_target_group" "foo" {
  name           = "<target group name>"

  target {
    subnet_id    = "<subnet ID>"
    ip_address   = "<internal IP address of VM 1>"
  }
}


resource "yandex_alb_backend_group" "test-backend-group" {
  name                     = "<backend group name>"

  http_backend {
    name                   = "<backend name>"
    weight                 = 1
    port                   = 80
    target_group_ids       = ["<target group ID>"]
    load_balancing_config {
      panic_threshold      = 90
    }    
    healthcheck {
      timeout              = "10s"
      interval             = "2s"
      healthy_threshold    = 10
      unhealthy_threshold  = 15 
      http_healthcheck {
        path               = "/"
      }
    }
  }
}

resource "yandex_alb_http_router" "tf-router" {
  name   = "<HTTP router name>"
  labels = {
    tf-label    = "tf-label-value"
    empty-label = ""
  }
}

resource "yandex_alb_virtual_host" "my-virtual-host" {
  name           = "<virtual host name>"
  http_router_id = "${yandex_alb_http_router.tf-router.id}"
  route {
    name = "<route name>"
    http_route {
      http_route_action {
        backend_group_id = "<backend group ID>"
        timeout          = "3s"
      }
    }
  }
}

resource "yandex_alb_load_balancer" "test-balancer" {
  name        = "<L7 load balancer name>"
  network_id  = "<network ID>"

  allocation_policy {
    location {
      zone_id   = "<availability zone>"
      subnet_id = "<subnet ID>"
    }
  }

  listener {
    name = "<listener name>"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [ 9000 ]
    }
    http {
      handler {
        http_router_id = "<HTTP router ID>"
      }
    }
  }
}



