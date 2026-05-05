1. On provisioning Azure service via Terraform on GitHub Actions, state files of "backend" module don't persist.
2. Attempt to provision "backend" - blob storage for stage via Terraform on GitHub Actions, causing "chicken and egg" problem.
   --> Solution: deploy "backend" module separately, manually first. Do not include "backend" module in the main deployment pipeline.
3. Accidentally uploaded tfout files to GitHub repo, which contain sensitive information.
   --> Immediate action: remove tfout files from the repo and destroy the infrastructure to invalidate the tfout files.
   --> Solution: remove tfout files from the repo, and add them to .gitignore.
4. Need a way to access Azure via GitHub Actions
   --> Solution: create a service principal with "Contributor" role:

```
az ad sp create-for-rbac \
--name "gha-terraform" \
--role Contributor \
--scopes /subscriptions/<sub-id>
```
