terraform {
  required_providers {
    opnsense = {
      version = "~> 0.16.1"
      source  = "browningluke/opnsense"
    }
  }
}

/* To use need to have the following environment variables set:
OPNSENSE_URI
OPNSENSE_API_KEY
OPNSENSE_API_SECRET
*/
provider "opnsense" {
  allow_insecure = true
}
