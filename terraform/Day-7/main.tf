provider "aws" {
  region = "us-east-1"
}

provider "vault" {
  address = "http://54.175.23.71:8200"
  skip_child_token = true

  auth_login {
    path = "auth/approle/login"

    parameters = {
      role_id = "c20fd306-669d-f095-eebc-1467b5e8eda9"
      secret_id = "70e8136e-9105-7c6d-8c81-a56edc04b82b"
    }
  }
}

data "vault_kv_secret_v2" "example" {
  mount = "secrets" // change it according to your mount
  name  = "test-secret" // change it according to your secret
}

resource "aws_instance" "my_instance" {
  ami           = "ami-091138d0f0d41ff90"
  instance_type = "t2.micro"

  tags = {
    Name = "test"
    Secret = data.vault_kv_secret_v2.example.data["username"]
  }
}
