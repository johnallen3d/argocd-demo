# Notes

## Hello World Service

1. Create a Git repository:
   Create a new repository on GitHub or GitLab to store your Kubernetes manifests.

2. Create the application manifests:
   In your repository, create the following files:

   a. `deployment.yaml`:

   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: hello-world
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: hello-world
     template:
       metadata:
         labels:
           app: hello-world
       spec:
         containers:
           - name: hello-world
             image: nginxdemos/hello
             ports:
               - containerPort: 80
   ```

   b. `service.yaml`:

   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: hello-world
   spec:
     selector:
       app: hello-world
     ports:
       - port: 80
         targetPort: 80
   ```

   c. `ingress.yaml`:

   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: hello-world
     annotations:
       kubernetes.io/ingress.class: traefik
   spec:
     rules:
       - host: hello.localhost
         http:
           paths:
             - path: /
               pathType: Prefix
               backend:
                 service:
                   name: hello-world
                   port:
                     number: 80
   ```

3. Commit and push these files to your Git repository.

4. Create an ArgoCD application:
   Use the ArgoCD UI or CLI to create a new application:

   ```
   argocd app create hello-world \
     --repo https://github.com/yourusername/your-repo.git \
     --path . \
     --dest-server https://kubernetes.default.svc \
     --dest-namespace default
   ```

   Replace the repo URL with your actual repository URL.

5. Sync the application:
   In the ArgoCD UI, find your application and click "Sync", or use the CLI:

   ```
   argocd app sync hello-world
   ```

6. Update your local `/etc/hosts`:
   Add an entry for `hello.localhost` pointing to your k3s VM IP:

   ```
   sudo echo "<multipass-vm-ip> hello.localhost" >> /etc/hosts
   ```

7. Port forward your application:

   ```
   kubectl port-forward service/hello-world 8081:80
   ```

1. Access your application:
   Open a web browser and navigate to `http://hello.localhost:8081`. You should see the "Hello World" nginx demo page.





kubectl create namespace open-telemetry
argocd app create open-telemetry \
  --repo https://github.com/johnallen3d/argocd-demo.git \
  --path ./apps/opentelemetry/ \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace open-telemetry
