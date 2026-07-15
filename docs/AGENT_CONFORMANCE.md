<!--
  Este archivo se REGENERA con `leloir/scripts/matrix-agents.sh --out ...` desde el
  scorecard VIVO del control plane. NO editar la tabla a mano. En el loop E2E
  (decisión T3) se regenera en cada corrida: input nuevo → pruebo → métricas →
  publico. El customer lo lee para ver, con métricas medidas, que cada agente
  soportado fue testeado y CÓMO lo gobierna Leloir.
-->
<!-- AUTO-GENERADO por scripts/matrix-agents.sh — NO editar a mano. Regenerado: 2026-07-15 08:07 UTC -->
# Agent conformance matrix — MEASURED

> Auto-generada desde el scorecard VIVO del control plane el **2026-07-15 08:07 UTC**. Cada
> fila es governance MEDIDA (no declarada): las 5 costuras que Leloir puede
> hacer BIND para ese agente. La misma lógica que la matriz de memoria, para
> los agentes que soportamos. Regla: nada acá se escribe a mano.

**Las 5 costuras (seams):** LLM (metering) · Tools (por el gateway) · RBAC · Trigger (ruteo) · Outcome (registrado).

| Agente | Cómo se integra | Tenant | LLM | Tools | RBAC | Trigger | Outcome | Coverage | Off-radar | Drift |
|---|---|---|---|---|---|---|---|---|---|---|
| **leloir-agent** | flagship (openaicompat) | `default` | enforced | gateway | gateway-creds | routed | recorded | 5/5 | ✅ no | 0 |
| **mode1-sre** | HolmesGPT SDK-native (mode 1) | `demo-mode1` | enforced | gateway | gateway-creds | routed | recorded | 5/5 | ✅ no | 0 |
| **mode2-holmes** | HolmesGPT contenido (mode 2, black-box) | `demo-mode2` | enforced | gateway | contained | routed | recorded | 5/5 | ✅ no | 0 |
| **mode3-agent** | guardrails nativos (mode 3) | `demo-mode3` | enforced | gateway | gateway-creds | routed | recorded | 5/5 | ✅ no | 0 |
| **mode4-opencode** | OpenCode (mode 4) | `demo-mode4` | enforced | gateway | gateway-creds | routed | recorded | 5/5 | ✅ no | 0 |
| **holmesgpt** | HolmesGPT (adapter nativo) | `default` | unmetered | none | observed | routed | recorded | 2/5 | 🔴 sí | 0 |

## Lectura (derivada de los datos medidos)

- **Gobernados 5/5 (5):** leloir-agent, mode1-sre, mode2-holmes, mode3-agent, mode4-opencode — los 5 seams BIND: LLM metrado, tools por el gateway (auditadas), RBAC sin ver creds, trigger ruteado, outcome+costo registrado.
- **Off-radar (1):** holmesgpt — al menos un seam es INOBSERVABLE. **Esto es honestidad, no un bug**: un agente crudo/compartido que no pasa por nuestros seams se REPORTA off-radar en vez de fingir que lo gobernamos (decisión G2). El contraste con su versión contenida (mode2) es la demo del valor.

**Blind-spots por agente (lo que declaramos que NO vemos):**

- `holmesgpt`: llm_spend: INVISIBLE — LLM calls don't pass through the broker and no OTEL is ingested; Leloir cannot see token usage, tool_calls: INVISIBLE — agent does not route through the MCP gateway/facade; it may invoke tools out of band, rbac: POSTURE-ONLY — Leloir does not inject or scope the agent's credentials; it relies on the agent's own K8s RBAC

---

## Cómo se regenera (no es un doc escrito a mano)

```bash
# contra el cluster (o in-cluster en CI):
LELOIR_URL=https://leloir.cluster.home leloir/scripts/matrix-agents.sh \
  --drive --out leloir-helm/docs/AGENT_CONFORMANCE.md
```

`--drive` dispara una investigación real por agente ruteado y captura el **modelo
LLM REAL** (no el alias) + costo — la misma trazabilidad per-call que exigimos en
todo el producto (decisión G3). Sin `--drive`, la matriz refleja el scorecard vivo
(governance medida, sin gastar tokens).

## Agentes soportados aún no desplegados en esta corrida

La matriz refleja lo que está VIVO (honesto, igual que la matriz de memoria). Los
adapters soportados que no estén registrados en la corrida no aparecen; se agregan
solos cuando se despliegan:
- **kagent** — vía A2A (`type:a2a`, standard, sin adapter per-vendor).
- **k8sgpt** — adapter de conformance.

Desplegarlos en el tenant de test efímero de la Capa B (decisión T6) los suma a la
próxima matriz automáticamente.
