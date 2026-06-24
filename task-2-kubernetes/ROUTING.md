# Routing Choice: Ingress vs Gateway API

I implemented **NGINX Ingress** because it is simple and enough for the current requirement: exposing `podinfo` using a host-based route such as `podinfo.local`.

1. **Ingress** is easy for basic HTTP routing, but advanced features usually depend on **controller-specific annotations**. For example, canary routing using NGINX-specific annotations. This means the routing logic and controller-specific configuration are usually kept in the same Ingress file, which does not provide strong separation between infrastructure/platform responsibilities and application routing responsibilities.

2. **Gateway API** improves this by separating responsibilities. The infrastructure or platform team can manage the `GatewayClass` and `Gateway`, while the application team can manage the `HTTPRoute`.

    - A `Gateway` includes **infrastructure-facing settings** such as the gateway class, listeners(protocol, port, hostname), TLS configuration.
    - An `HTTPRoute` includes **application-facing routing settings** such as hostnames, path matches, header matches, backend services, backend ports, and optional traffic weights for traffic splitting.
    
Gateway API is more expressive than Ingress because it supports structured features like header-based routing, traffic splitting, and cross-namespace route attachment without depending heavily on controller-specific annotations.
