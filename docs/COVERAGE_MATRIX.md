<!-- AUTO-GENERADO por scripts/matrix-coverage.sh (v2, knowledge-graph). 2026-07-15 18:56 UTC -->
# Coverage matrix — feature × CONTRATO × substrato (MEASURED, agnóstico)

> Auto-generada el **2026-07-15 18:56 UTC** desde `deploy/knowledge-graph.yaml` cruzado con deps VIVAS +
> agentes gobernados. Modelo agnóstico: el feature requiere un CONTRATO; el vendor es
> intercambiable. `blocked` = ningún vendor del contrato vivo. Nada a mano.

**Contratos satisfechos:** agent-adapter=✅, mcp-transport=✅, llm-openai-compat=✅, gateway-api=✅, cni-netpol-mtls=✅, observability-otlp=✅, notification-sink=❌, audit-sink=❌, persistence=✅

**Resumen:** 21 testeable-live · 2 blocked por contrato/dep ausente

| Feature | Costura | Requiere contrato | Substrato | test-status | Estado medido | Métrica |
|---|---|---|---|---|---|---|
| alert-routing | Trigger | persistence | any | e2e-happy | ✅ live (5 agente/s gobernado/s) | alerta → investigación creada + ruteada al agente correcto |
| tenant-isolation | RBAC | persistence | any | e2e-chaos | ✅ live (5 agente/s gobernado/s) | recall/audit scoped por tenant; cross-tenant = 404 (NO 403: no revelar existencia) |
| budget-4layer | LLM | llm-openai-compat, persistence | any | e2e-happy | ✅ live (5 agente/s gobernado/s) | BudgetExceededError al exceder tokens/USD/tool-calls |
| llm-metering-real | LLM | llm-openai-compat, observability-otlp | standalone-cluster | e2e-happy | ✅ live (5 agente/s gobernado/s) | audit llm.call con real_model (no alias) + costo |
| perTenant-keys | LLM | llm-openai-compat | any | e2e-happy | ✅ live (5 agente/s gobernado/s) | virtual key del tenant provista cross-ns; metering per-key |
| hitl-approval | Tools | persistence | any | e2e-happy | ✅ live (5 agente/s gobernado/s) | acción riesgosa → pending → resume approve/reject |
| a2a-delegation | Trigger | agent-adapter, persistence | any | e2e-happy | ✅ live (5 agente/s gobernado/s) | canInvoke permite/deniega; depth+fanout capados; budget = min de 4 |
| tools-via-gateway | Tools | mcp-transport, persistence | any | e2e-happy | ✅ live (5 agente/s gobernado/s) | tool call auditada en el gateway (WORM), caller_agent set |
| memory-rag | Tools | persistence | any | e2e-happy | ✅ live (5 agente/s gobernado/s) | auto-runbook: alerta repetida recupera resolución previa |
| memory-mcp | Tools | mcp-transport, persistence | any | e2e-happy | ✅ live (5 agente/s gobernado/s) | remember/recall/forget por tenant, aislado |
| memory-honcho | Tools | mcp-transport | any | e2e-happy | ✅ live (5 agente/s gobernado/s) | black-box recuerda por la fachada; recall HIT medido |
| containment-egress | Tools | cni-netpol-mtls, llm-openai-compat | standalone-cluster | e2e-chaos | ✅ live (5 agente/s gobernado/s) | egress-lock fuerza al gateway; cluster-scope = Forbidden |
| hardening-mtls | RBAC | cni-netpol-mtls | standalone-cluster | unit | ✅ live (5 agente/s gobernado/s) | gateway→CP :8090 solo por mTLS SPIFFE |
| hardening-netpol | RBAC | cni-netpol-mtls | standalone-cluster | e2e-chaos | ✅ live (5 agente/s gobernado/s) | listener interno cerrado por CNP; ingress externo denegado |
| skillsource | Trigger | persistence | any | e2e-happy | ✅ live (5 agente/s gobernado/s) | configmap/git → SkillRef inyectado al prompt (git fail-closed sin concesión) |
| scheduled-inv | Trigger | persistence | any | unit | ✅ live (5 agente/s gobernado/s) | cron dispara investigación por el mismo pipeline |
| shadow-mode | Tools | mcp-transport, persistence | any | e2e-happy | ✅ live (5 agente/s gobernado/s) | acción interceptada; respuesta opaca; evento shadowed en audit |
| quarantine | Outcome | persistence | any | e2e-happy | ✅ live (5 agente/s gobernado/s) | thrash → quarantine; auto-release por cooldown |
| audit-worm | Outcome | persistence | any | e2e-happy | ✅ live (5 agente/s gobernado/s) | cada evento append-only; query por tenant/investigación |
| audit-siem | Outcome | audit-sink | external | not-tested | ⛔ blocked (falta: audit-sink, siem-sink) | eventos forwarded al sink; fail-open si muerto |
| notifications | Outcome | notification-sink | external | unit | ⛔ blocked (falta: notification-sink, chat-webhook) | evento de ciclo de vida despachado; filtros por ruta/evento/outcome |
| metrics-dashboards | Outcome | observability-otlp | standalone-cluster | e2e-happy | ✅ live (5 agente/s gobernado/s) | cada panel Grafana se popula con data real |
| scorecard-honesty | Outcome | persistence | any | e2e-happy | ✅ live (5 agente/s gobernado/s) | off-radar/coverage/drift reportados honesto (no fingido) |

## Cómo leerla

- **Requiere contrato** (no vendor): la costura agnóstica. Un contrato core (agent-adapter,
  mcp-transport) siempre está; uno con vendors externos (llm-openai-compat, cni-netpol-mtls)
  está satisfecho si ≥1 implementación vive → **si swapeás el vendor, la governance sigue.**
- **test-status** es el nivel REAL alcanzado (not-tested<unit<e2e-happy<e2e-chaos). 'Completado'
  en STATUS = e2e-chaos (el fallo se inyectó y el guard actuó). Hoy 0 en e2e-chaos → honesto.
