import argo_cd.v1alpha1 as argocd

_generate = lambda env: str, ref: str -> argocd.Application {
    {
        kind = "Application"
        apiVersion = "argoproj.io/v1alpha1"
        metadata = {
            name = "argocd-demo-${env}"
            namespace = "argocd"
        }
        spec = {
            project = "default"
            source = {
                repoURL = "https://github.com/johnallen3d/argocd-demo.git"
                targetRevision = ref
                path = "system/base"
                helm = {
                    valueFiles = [
                        "values.yaml"
                        "values-${env}.yaml"
                    ]
                    values = "environment: ${env}"
                }
            }
            destination = {
                server = "https://kubernetes.default.svc"
                namespace = "argocd"
            }
            syncPolicy = {
                automated = {
                    prune = True
                    selfHeal = True
                }
            }
        }
    }
}
environments = {str(env): _generate(env, ref) for env, ref in {"local" = "feature/external-secrets", "xcel-on-prem" = "HEAD"}}
