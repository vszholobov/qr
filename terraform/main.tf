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
    bucket = "vszholobov-qr-coder-terraform-storage"
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

# qr generation function
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
      # bucket = local.bucket
      bucket = yandex_storage_bucket.vszholobov-qr-coder-storage.bucket
      prefix = "qrcodes"
    }
  }

  entrypoint = "index.Handler"
  runtime    = "golang121"

  environment = {
    QR_FILE_PATH = "/function/storage/qrcodes"
  }
}

# qr function public invocation access
resource "yandex_function_iam_binding" "qr-code-generator-binding" {
  function_id = yandex_function.qr-code-generator.id
  role        = "functions.functionInvoker"
  members = [
    "system:allUsers"
  ]
}

# qr function random version id
resource "random_string" "function_version" {
  length  = 10
  special = false
  upper   = false
}

# qr function gateway
resource "yandex_api_gateway" "qr-api-gateway" {
  name = "qr-api-gateway"
  spec = templatefile("${path.module}/api-gw-spec.yaml", {
    # bucket             = local.bucket,
    bucket             = yandex_storage_bucket.vszholobov-qr-coder-storage.bucket,
    service-account-id = data.yandex_iam_service_account.qr-coder.id,
    qr-function-id     = yandex_function.qr-code-generator.id
  })

  custom_domains {
    certificate_id = data.yandex_cm_certificate.vszholobov-le.id
    fqdn           = "qr.vszholobov.ru"
  }
}

resource "yandex_storage_bucket" "vszholobov-qr-coder-storage" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = "vszholobov-qr-coder-storage"
}

resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = data.yandex_iam_service_account.qr-coder.id
}

resource "yandex_storage_object" "static-index-page" {
  # bucket = local.bucket
  bucket = yandex_storage_bucket.vszholobov-qr-coder-storage.bucket
  key    = "index.html"
  source = "../static/index.html"
  acl = "public-read"
  content_type = "text/html"
}

resource "yandex_storage_object" "static-index-page-icon" {
  # bucket = local.bucket
  bucket = yandex_storage_bucket.vszholobov-qr-coder-storage.bucket
  key    = "qr.ico"
  source = "../static/qr.ico"
  acl = "public-read"
  content_type = "image/x-icon"
}

data "yandex_iam_service_account" "qr-coder" {
  service_account_id = "ajear3vdc2uf616skngd"
}

data "yandex_cm_certificate" "vszholobov-le" {
  certificate_id = "fpqu84n9e9fq12ol6bp3"
}
