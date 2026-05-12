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

8. Cannot update PostgreSQL StatefulSet in Kubernetes due to "immutable field" error when trying to change the storage class.

9. K8s resources stuck at "Terminating" state after deletion, preventing the creation of new resources with the same name.
   --> Temporary solution: manually delete the resources using `kubectl delete` with the `--force` and `--grace-period=0` flags.
   --> Temporary solution 2:

```bash
kubectl get namespace cicd -o json | jq '.spec.finalizers=[]' | kubectl replace --raw "/api/v1/namespaces/cicd/finalize" -f -
```

10. Local cluster behaves strangely because nodes are not labeled
    --> Solution: label nodes with "apps" for deploying microservices, "tools" for deploying tools like Jenkins and "system" for control plane.

```bash
kubectl label node ccluster-worker workload=tools
kubectl label node ccluster-worker2 workload=apps
kubectl label node ccluster-control-plane workload=system
kubectl taint node ccluster-worker workload=tools:NoSchedule
kubectl taint node ccluster-worker2 workload=apps:NoSchedule
```

11. Some public Helm charts use old versions of images that have been removed from Docker Hub, causing deployment failures.
    --> Solution: override the image repository and tag in the Helm values file to use a valid image. For example:

```yaml
keycloak:
  image:
    repository: keycloak/keycloak
    tag: 26.3.3-0
```

However, this causes another issue: image not valid for deployment (insecure)
--> Temporary solution: allow insecure images in the cluster by setting `global.allowInsecureImages` to true

12.

```
Error: UPGRADE FAILED: unable to continue with update: Namespace "cicd" in namespace "" exists and cannot be imported into the current release: invalid ownership metadata; label validation error: missing key "app.kubernetes.io/managed-by": must be set to "Helm"; annotation validation error: missing key "meta.helm.sh/release-name": must be set to "cicd"; annotation validation error: missing key "meta.helm.sh/release-namespace": must be set to "cicd"
```

Root cause: templates/namespace.yaml creates a namespace that is not managed by Helm.

13. Secrets may leak during pipeline execution.
    --> Solution
    - Ensure that secrets are not printed in the logs
    - Use value files, such as /tmp/values-XXXXXX.yaml (with umask 077, only runner can read file)

14. Jenkins cannot connect to the internet
    --> Root cause: Jenkins controller/init container had no proxy environment configuration, so plugin downloads fail in restricted egress environments.
    --> Solution:
    - Configure `secrets.jenkins.proxy.{httpProxy,httpsProxy,noProxy}` in `config/helm/cicd/values.yaml`. The chart now creates `secret/jenkins-proxy` and injects proxy env vars (`HTTP_PROXY`/`HTTPS_PROXY`/`NO_PROXY` + lowercase variants) into both Jenkins init and controller containers.
    - Configure Jenkins update center URLs to use a stable mirror that is accessible to avoid plugin installation failures.

15. To provision HTTPS domain to services, we need to create CRDs for cert-manager, which is a dependency of the ingress controller. However, applying CRDs via Helm causes issues with idempotency and upgradeability.
    --> Solution: apply cert-manager CRDs separately using `kubectl apply -f` before installing the Helm chart.

16. Sometimes I attempted to create k8s resource in two ways (e.g. `kubectl apply -f` and Helm), which causes issue with Helm
    --> Solution: avoid creating the same resource in multiple ways. If a resource is managed by Helm, do not create it manually using `kubectl apply -f`, and vice versa.
17. Storage class "standard" is not available in AKS
    --> Solution: use "default" or "managed-csi" storage class instead, which is available in AKS. Update `primary.persistence.storageClass` in `config/helm/cicd/values.yaml` to "default".
