AWS Load Balancer Controller (ALB Ingress)

  The standard approach is to install the AWS Load Balancer Controller, which provisions ALBs from Kubernetes Ingress resources.

  ---
  1. Prerequisites

  - EKS cluster with OIDC provider enabled
  - IAM permissions for the controller

  # Enable OIDC provider (if not already done)
  eksctl utils associate-iam-oidc-provider \
    --cluster <cluster-name> \
    --region <region> \
    --approve

  ---
  2. Create IAM Policy & Service Account

  # Download the IAM policy
  curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

  # Create the policy
  aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

  # Create service account with IAM role
  eksctl create iamserviceaccount \
    --cluster=<cluster-name> \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --attach-policy-arn=arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
    --approve

  ---
  3. Install the Controller via Helm

  helm repo add eks https://aws.github.io/eks-charts
  helm repo update

  helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=<cluster-name> \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller

  ---
  4. Create an Ingress Resource

  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: my-app-ingress
    annotations:
      kubernetes.io/ingress.class: alb
      alb.ingress.kubernetes.io/scheme: internet-facing      # or internal
      alb.ingress.kubernetes.io/target-type: ip              # recommended for EKS
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
      alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:<region>:<account>:certificate/<id>
  spec:
    ingressClassName: alb
    rules:
      - host: myapp.example.com
        http:
          paths:
            - path: /
              pathType: Prefix
              backend:
                service:
                  name: my-app-service
                  port:
                    number: 80

  ---
  Key Annotations

  ┌───────────────────────────────────────────┬────────────────────────────┬─────────────────────────────────────────┐
  │                Annotation                 │           Values           │                 Purpose                 │
  ├───────────────────────────────────────────┼────────────────────────────┼─────────────────────────────────────────┤
  │ alb.ingress.kubernetes.io/scheme          │ internet-facing / internal │ Public or private ALB                   │
  ├───────────────────────────────────────────┼────────────────────────────┼─────────────────────────────────────────┤
  │ alb.ingress.kubernetes.io/target-type     │ ip / instance              │ ip routes directly to pods              │
  ├───────────────────────────────────────────┼────────────────────────────┼─────────────────────────────────────────┤
  │ alb.ingress.kubernetes.io/certificate-arn │ ACM ARN                    │ TLS termination                         │
  ├───────────────────────────────────────────┼────────────────────────────┼─────────────────────────────────────────┤
  │ alb.ingress.kubernetes.io/group.name      │ string                     │ Share one ALB across multiple Ingresses │
  ├───────────────────────────────────────────┼────────────────────────────┼─────────────────────────────────────────┤
  │ alb.ingress.kubernetes.io/subnets         │ subnet IDs                 │ Specify which subnets to use            │
  ├───────────────────────────────────────────┼────────────────────────────┼─────────────────────────────────────────┤
  │ alb.ingress.kubernetes.io/wafv2-acl-arn   │ WAF ACL ARN                │ Attach WAF                              │
  └───────────────────────────────────────────┴────────────────────────────┴─────────────────────────────────────────┘

  ---
  Shared ALB (IngressGroup) — cost-saving

  To share a single ALB across multiple services:

  annotations:
    alb.ingress.kubernetes.io/group.name: my-shared-alb

  Any Ingress with the same group.name gets merged into one ALB, saving cost.

  ---
  Tips

  - Use target-type: ip for better performance (bypasses kube-proxy)
  - Tag subnets correctly: kubernetes.io/role/elb: 1 (public) or kubernetes.io/role/internal-elb: 1 (private)
  - Use IngressClass instead of the deprecated annotation when possible
  - For HTTP→HTTPS redirect, add: alb.ingress.kubernetes.io/actions.ssl-redirect: ...