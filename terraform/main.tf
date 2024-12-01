terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex",
      version = "0.133.0"
    }
  }
  required_version = "1.9.8"

  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket = "vszholobov-storage-for-serverless-shortener"
    region = "ru-central1-a"
    key    = "terraform-state/terraform.tfstate"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id = true
    # a necessary option when describing the backend for Terraform version 1.6.1 and older.
    skip_s3_checksum            = true
    # a necessary option when describing the backend for Terraform version 1.6.3 and older.
  }
}

provider "yandex" {
  cloud_id  = "b1g307q4r9prh7cdcts8"
  folder_id = "b1gv6p5rlgfl04l14iqs"
}

variable "function_zip_file" {
  type        = string
  description = "Path to function zip file"
}

resource "yandex_function" "qr-code-generator" {
  name        = "qr-code-generator"
  memory      = 128
  user_hash   = random_string.function_version.result
  concurrency = 2

  content {
    zip_filename = var.function_zip_file
  }
  service_account_id = data.yandex_iam_service_account.qr-coder.id
  mounts {
    name = "qrcodes"
    mode = "rw"
    object_storage {
      bucket = "vszholobov-storage-for-serverless-shortener"
      prefix = "qrcodes"
    }
  }

  entrypoint = "index.Handler"
  runtime    = "golang121"

  environment = {
    QR_FILE_PATH = "/function/storage/qrcodes"
  }
}

# public invocation access
resource "yandex_function_iam_binding" "qr-code-generator-binding" {
  function_id = yandex_function.qr-code-generator.id
  role        = "functions.functionInvoker"
  members = [
    "system:allUsers"
  ]
}

resource "random_string" "function_version" {
  length  = 10
  special = false
  upper   = false
}

data "yandex_iam_service_account" "qr-coder" {
  service_account_id = "ajear3vdc2uf616skngd"
}
