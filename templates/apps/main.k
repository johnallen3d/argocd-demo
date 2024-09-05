import argo_cd.v1alpha1 as argocd

_generate = lambda env: str, ref: str, secrets_provider: str -> argocd.Application {
    {
        kind = "Application"
        apiVersion = "argoproj.io/v1alpha1"
        metadata = {
            name = "argocd-demo-${env}-${secrets_provider}"
            namespace = "argocd"
        }
        spec = {
            project = "default"
            source = {
                repoURL = "https://github.com/johnallen3d/argocd-demo.git"
                targetRevision = ref
                path = "system/base"
                helm = {values = """
                      environment: ${env}
                      secrets_provider: ${secrets_provider}
                    """}
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
apps = {"${env}-${secrets_provider}": _generate(env, ref, secrets_provider) for env, ref in {
    "local" = "HEAD"
    "xcel-on-prem" = "HEAD"
} for secrets_provider in ["op", "aws"]}
