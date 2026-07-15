# Chaos/Resilience experiments — AUTO-GENERADOS del knowledge-graph (2026-07-15 11:53 UTC)

> Del grafo, no a mano. Corren con chaos-k8s (ya existe) contra un tenant efímero.

## A. Degradación (matar un vendor del contrato → el core sobrevive)

| Experimento | Falla | Hipótesis | Aserción |
|---|---|---|---|
| degrade/alert-routing | matar `postgres-pgvector` (único vendor del contrato) | alert-routing degrada `hard-fail`; core-affected=True | agente NO cae off-radar; features core siguen |
| degrade/tenant-isolation | matar `postgres-pgvector` (único vendor del contrato) | tenant-isolation degrada `hard-fail`; core-affected=True | agente NO cae off-radar; features core siguen |
| degrade/budget-4layer | matar `envoy-ai-gw` (el contrato llm-openai-compat tiene otro vendor: ['litellm-operator']) | budget-4layer degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/budget-4layer | matar `litellm-operator` (el contrato llm-openai-compat tiene otro vendor: ['envoy-ai-gw']) | budget-4layer degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/budget-4layer | matar `postgres-pgvector` (único vendor del contrato) | budget-4layer degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/llm-metering-real | matar `envoy-ai-gw` (el contrato llm-openai-compat tiene otro vendor: ['litellm-operator']) | llm-metering-real degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/llm-metering-real | matar `litellm-operator` (el contrato llm-openai-compat tiene otro vendor: ['envoy-ai-gw']) | llm-metering-real degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/llm-metering-real | matar `alloy-prometheus` (único vendor del contrato) | llm-metering-real degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/perTenant-keys | matar `envoy-ai-gw` (el contrato llm-openai-compat tiene otro vendor: ['litellm-operator']) | perTenant-keys degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/perTenant-keys | matar `litellm-operator` (el contrato llm-openai-compat tiene otro vendor: ['envoy-ai-gw']) | perTenant-keys degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/hitl-approval | matar `postgres-pgvector` (único vendor del contrato) | hitl-approval degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/a2a-delegation | matar `postgres-pgvector` (único vendor del contrato) | a2a-delegation degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/tools-via-gateway | matar `postgres-pgvector` (único vendor del contrato) | tools-via-gateway degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/memory-rag | matar `postgres-pgvector` (único vendor del contrato) | memory-rag degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/memory-mcp | matar `postgres-pgvector` (único vendor del contrato) | memory-mcp degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/containment-egress | matar `cilium-spire` (único vendor del contrato) | containment-egress degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/containment-egress | matar `envoy-ai-gw` (el contrato llm-openai-compat tiene otro vendor: ['litellm-operator']) | containment-egress degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/containment-egress | matar `litellm-operator` (el contrato llm-openai-compat tiene otro vendor: ['envoy-ai-gw']) | containment-egress degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/hardening-mtls | matar `cilium-spire` (único vendor del contrato) | hardening-mtls degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/hardening-netpol | matar `cilium-spire` (único vendor del contrato) | hardening-netpol degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/skillsource | matar `postgres-pgvector` (único vendor del contrato) | skillsource degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/scheduled-inv | matar `postgres-pgvector` (único vendor del contrato) | scheduled-inv degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/shadow-mode | matar `postgres-pgvector` (único vendor del contrato) | shadow-mode degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/quarantine | matar `postgres-pgvector` (único vendor del contrato) | quarantine degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/audit-worm | matar `postgres-pgvector` (único vendor del contrato) | audit-worm degrada `hard-fail`; core-affected=True | agente NO cae off-radar; features core siguen |
| degrade/audit-siem | matar `siem-sink` (único vendor del contrato) | audit-siem degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/notifications | matar `chat-webhook` (único vendor del contrato) | notifications degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/metrics-dashboards | matar `alloy-prometheus` (único vendor del contrato) | metrics-dashboards degrada `feature-off`; core-affected=False | agente NO cae off-radar; features core siguen |
| degrade/scorecard-honesty | matar `postgres-pgvector` (único vendor del contrato) | scorecard-honesty degrada `unaffected`; core-affected=False | agente NO cae off-radar; features core siguen |

## B. Guardrails (inyectar el abuso → el guard ACTÚA)

| Experimento | Falla a inyectar | Aserción (la métrica) |
|---|---|---|
| guard/tenant-isolation | acceso cross-tenant | recall/audit scoped por tenant; cross-tenant = 404 (NO 403: no revelar existencia) |
| guard/budget-4layer | sobregasto de tokens/USD | BudgetExceededError al exceder tokens/USD/tool-calls |
| guard/hitl-approval | acción riesgosa sin aprobación | acción riesgosa → pending → resume approve/reject |
| guard/containment-egress | escape de un black-box (llamada cluster-scope) | egress-lock fuerza al gateway; cluster-scope = Forbidden |
| guard/hardening-mtls | tráfico sin encriptar al control plane | gateway→CP :8090 solo por mTLS SPIFFE |
| guard/hardening-netpol | ingress externo al listener interno | listener interno cerrado por CNP; ingress externo denegado |
| guard/shadow-mode | mutación real por un agente en shadow | acción interceptada; respuesta opaca; evento shadowed en audit |
| guard/quarantine | thrash/loop descontrolado de un agente | thrash → quarantine; auto-release por cooldown |

**Substrato:** cluster vivo + tenant efímero (Capa B). SOLO el que pasa la fase
chaos alcanza test-status=e2e-chaos → único camino a 'Completado' en STATUS.
