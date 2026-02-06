# Gateway API (Envoy Gateway)

This repo uses Envoy Gateway as the Gateway API controller to replace the
legacy nginx Ingress controller in the management cluster.

## What is installed

- Gateway API CRDs + Envoy Gateway controller (app: `envoy-gateway`).
- Gateway configuration and TLS cert (app: `gateway-api`).
- HTTPRoute resources for Argo CD, Argo Workflows, and Dex.

## TLS

A single certificate is issued in the `gateway` namespace and used by the
Gateway listener:

- `argocd.homelab.ntbc.io`
- `argoworkflows.homelab.ntbc.io`
- `dex.homelab.ntbc.io`

## Backend protocol

Argo CD and Argo Workflows are configured for HTTP behind the Gateway. TLS is
terminated at the Gateway.

## Removing ingress-nginx

After the Gateway is healthy and HTTPRoutes are attached, remove nginx Ingress:

```bash
kubectl --context admin@sidero delete namespace ingress-nginx
```

## Verification

Check that the Gateway is ready and routes are attached:

```bash
kubectl --context admin@sidero -n gateway get gateway
kubectl --context admin@sidero -n argocd get httproute
kubectl --context admin@sidero -n argo get httproute
kubectl --context admin@sidero -n dex get httproute
```
