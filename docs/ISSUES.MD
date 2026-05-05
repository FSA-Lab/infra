1. On provisioning Azure service via Terraform on GitHub Actions, state files of "backend" module don't persist.
2. Attempt to provision "backend" - blob storage for stage via Terraform on GitHub Actions, causing "chicken and egg" problem.
   --> Solution: deploy "backend" module separately, manually first. Do not include "backend" module in the main deployment pipeline.
