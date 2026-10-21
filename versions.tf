terraform {
  # 1.7+ = mock_provider in `terraform test`; 1.9 is what consumers already run.
  required_version = ">= 1.9"

  required_providers {
    google = {
      source = "hashicorp/google"
      # Lower bound = the oldest major we test against (the lab runs 7.x).
      # Upper bound = don't let an untested major (8.x) in silently.
      version = ">= 7.0, < 8.0"
    }
  }
}
