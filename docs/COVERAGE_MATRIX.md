<!-- AUTO-GENERADO por scripts/matrix-coverage.sh — NO editar a mano. 2026-07-15 08:17 UTC -->
# Coverage matrix — feature × dependencia × capa (MEASURED)

> Auto-generada el **2026-07-15 08:17 UTC** cruzando `deploy/capabilities.yaml` contra las
> dependencias VIVAS del cluster y los agentes gobernados medidos. Dice, por
> cada feature de CRD: qué infra necesita, en qué capa se prueba, y si está
> full-testeable AHORA. Regla: nada se afirma sin la dependencia presente.

**Dependencias vivas en esta corrida:** cilium=✅, spire=✅, litellm=✅, litellm-operator=✅, honcho=✅, otel=✅, prometheus=✅, external-sink=❌, chat-webhook=❌

**Resumen:** 21 testeable-live · 0 dep-ok sin agente · 2 blocked por dep ausente

| Feature | CRD / flag | Dependencia | Capa | Estado medido | Métrica (la aserción) |
|---|---|---|---|---|---|
| alert-routing | AlertRoute | none | A | ✅ testeable-live (5 agente/s) | alerta a investigacion creada + ruteada al agente correcto |
| tenant-isolation | Tenant | none | A | ✅ testeable-live (5 agente/s) | recall/audit scoped por tenant; cross-tenant = 403 |
| budget-4layer | TenantBudget | none | A | ✅ testeable-live (5 agente/s) | BudgetExceededError al exceder tokens/USD/tool-calls |
| llm-metering-real | TenantBudget-ModelProvider | litellm, otel | B | ✅ testeable-live (5 agente/s) | audit llm.call con real_model (no alias) + costo (G3) |
| perTenant-keys | AgentRegistration-llmKeyFrom | litellm-operator | B | ✅ testeable-live (1 agente/s) | virtual key del tenant provista cross-ns; metering per-key |
| hitl-approval | ApprovalPolicy | none | A | ✅ testeable-live (5 agente/s) | accion riesgosa a pending a resume approve/reject |
| a2a-delegation | AgentRegistration-canInvoke | none | A | ✅ testeable-live (5 agente/s) | canInvoke permite/deniega; depth+fanout capados |
| tools-via-gateway | MCPServer | none | A | ✅ testeable-live (5 agente/s) | tool call auditada en el gateway (WORM), caller_agent set |
| memory-rag | RAG-spec-m22 | none | A | ✅ testeable-live (5 agente/s) | auto-runbook: alerta repetida recupera resolucion previa |
| memory-mcp | MCPServer-memory | none | A | ✅ testeable-live (5 agente/s) | remember/recall/forget por tenant, aislado |
| memory-honcho | MCPServer-honcho | honcho, litellm | B | ✅ testeable-live (1 agente/s) | black-box recuerda por la fachada; recall HIT medido |
| containment-egress | AgentRegistration-containment | litellm, cilium | B | ✅ testeable-live (1 agente/s) | egress-lock fuerza al gateway; cluster-scope = Forbidden |
| hardening-mtls | chart-hardening-mtls | cilium, spire | B | ✅ testeable-live (5 agente/s) | gateway a CP :8090 solo por mTLS SPIFFE |
| hardening-netpol | chart-hardening-networkPolicies | cilium | B | ✅ testeable-live (5 agente/s) | listener interno cerrado por CNP; ingress externo denegado |
| skillsource | SkillSource | none | A | ✅ testeable-live (5 agente/s) | configmap/git a SkillRef inyectado al prompt (git fail-closed sin concesion) |
| scheduled-inv | ScheduledInvestigation | none | A | ✅ testeable-live (5 agente/s) | cron dispara investigacion por el mismo pipeline |
| shadow-mode | AgentRegistration-shadow | none | A | ✅ testeable-live (5 agente/s) | accion interceptada; respuesta opaca; evento shadowed en audit |
| quarantine | anomaly-quarantine | none | A | ✅ testeable-live (5 agente/s) | thrash a quarantine; auto-release por cooldown |
| audit-worm | audit | none | A | ✅ testeable-live (5 agente/s) | cada evento append-only; query por tenant/investigacion |
| audit-siem | audit-streaming | external-sink | B | ⛔ blocked (dep ausente: external-sink) | eventos forwarded al sink; fail-open si muerto |
| notifications | NotificationChannel | chat-webhook | B | ⛔ blocked (dep ausente: chat-webhook) | evento de ciclo de vida despachado; filtros por ruta/evento/outcome |
| metrics-dashboards | observability | prometheus | B | ✅ testeable-live (5 agente/s) | cada panel Grafana se popula con data real |
| scorecard-honesty | investigation | none | A | ✅ testeable-live (5 agente/s) | off-radar/coverage/drift reportados honesto (no fingido) |

## Cómo leerla

- **Capa A** (dependency=none): el core libre — testeable en CUALQUIER cluster (kind aislado). ES lo que instala el customer.
- **Capa B** (dep externa/Cilium): integración — sólo con la dep presente. En un cluster sin Cilium, `hardening-*` aparece ⛔ correctamente (el customer sin Cilium tampoco lo usa).
- **⛔ blocked ≠ roto:** es honestidad — la feature necesita una dep que este cluster no tiene. El mapa = OPTIONALITY_MATRIX.
