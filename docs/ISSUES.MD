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

5. Remote `tfstate` becomes locked after every GitHub Actions run, preventing subsequent runs from acquiring the lock and causing failures.
   --> Temporary solution: manually remove lease of the file in Azure Storage Explorer.

6. Don't know how to pass variables to terraform in GitHub Actions
   --> Solution: create environment variables in GitHub repo, and reference them in the workflow file. For example:

```
env:
  TF_VAR_ARM_CLIENT_ID: ${{ secrets.TF_VAR_ARM_CLIENT_ID }}
  TF_VAR_ARM_CLIENT_SECRET: ${{ secrets.TF_VAR_ARM_CLIENT_SECRET }}
  TF_VAR_APP_NAME: ${{ vars.APP_NAME }}
```

7. Despite adding terraform plugin cache configuration in the workflow file, the cache is not being utilized, leading to longer execution times.
   --> Solution: ensure that the plugin cache directory is correctly set up and that the workflow has permission to write to it.
