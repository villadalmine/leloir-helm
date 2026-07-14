# Memory for Leloir — deep analysis, live results & framework comparison

**Audience:** decision-makers + the marketing page. Honest, metric-backed.
**TL;DR:** memory is an **upgrade, never a hard dependency**. Leloir ships native
memory; external memory systems plug in through the MCP Gateway. **We default to
Honcho** (deployed, governed, live-tested) — but any of mem0 / Zep / Letta drops
in, and the user chooses. What each layer/feature buys you, and what you lose
without it, is spelled out below with real evidence from our cluster.

---

## 1. How Leloir does memory

Two native layers (zero external deps beyond the Postgres Leloir already needs)
plus a plug-in slot:

| Layer | What it is | Value it adds | If removed |
|---|---|---|---|
| **`leloir-memory-mcp`** (spec-m18) | built-in MCP server; per-tenant `remember/recall/forget` | agents keep durable facts across calls, deterministically | 🟡 agents lose durable key/value recall |
| **RAG episodic** (spec-m22, pgvector) | captures `alert→cause→fix`, recalls by cosine similarity | **auto-runbook**: a similar future alert gets the past resolution injected | 🟡 no "we've seen this before" — every incident is investigated from scratch |
| **External memory** (Honcho/mem0/Zep/Letta) | plugs in via `MCPServer` CRD — governed like any tool | richer continuity, peer/user modeling, temporal reasoning | 🟢 **none** on the core — it's an upgrade |

**Why external memory matters most for black-box agents (Modo 2):** a contained
third-party agent (e.g. HolmesGPT) can't be modified. External memory over the
**MCP facade** is the *only* way to give it "what did we learn last time" —
without touching its runtime. That is a governance differentiator, not a
feature checkbox.

---

## 2. Honcho — live deep-dive (our reference choice)

Running **v3.0.12** on-cluster (API + Postgres + Redis + deriver worker), wired
to the governed litellm layer (so its own LLM spend is metered). Model:
**peer-centric** — a *peer* can be a human, an agent, a service, even an idea;
*sessions* are many-to-many with peers. This maps cleanly onto Leloir:

| Honcho primitive | Leloir concept |
|---|---|
| workspace | tenant |
| peer | agent / observed service |
| session | investigation |
| message | a finding / observation |

### What we tested live (real results, not claims)

Scenario: an SRE agent investigates `inv-001` — checkout-service OOMKilled,
root-caused to a JVM `-Xmx == pod-limit` misconfig, remediated, and a
generalizable rule captured ("pod limit must exceed -Xmx by ≥40%").

| Capability | Endpoint | Result | Needs |
|---|---|---|---|
| **Create/scope** (workspace/peers/sessions) | `POST /v3/...` | ✅ 201 | nothing (deterministic) |
| **Capture findings** | `.../messages` | ✅ 201, survived the v3.0.6→v3.0.12 upgrade (durable Postgres) | nothing |
| **Semantic search** | `POST /v3/.../search` | ✅ returns the exact stored finding for `"JVM memory headroom"` | an embedder |
| **Dialectic (NL query → answer from memory)** | `POST /v3/peers/{id}/chat` | ✅ 200 — synthesized correctly (verbatim below) | any chat model |
| **Deriver (background theory-of-mind representation)** | worker queue | ⚠️ produced **zero observations** — the model must support **structured output (`json_schema`)**; our free-tier alias does not | a structured-output-capable model |

**Real dialectic answer** (query: *"What memory-sizing rule did we learn for JVM
services, and from which incident?"*):

> "For JVM-based services the pod's memory limit must be set to at least **40%
> higher than the JVM heap size (`-Xmx`)** … The rule was distilled from
> **incident inv-001** — checkout-service pods were repeatedly OOMKilled because
> their pod memory limit (512 MiB) exactly matched `-Xmx`, leaving no overhead
> for off-heap memory. The remediation raised the limit to 1 GiB and kept `-Xmx`
> at 640 MiB (≈60% headroom)."

That answer was **synthesized from stored memory across a different session** —
exactly the cross-incident continuity that's the point.

### Deriver working with a structured-output model (real output)

After pointing Honcho at **Claude Sonnet 5** (structured-output capable; free
models return "zero observations"), the background deriver produces a real
theory-of-mind representation. Verbatim excerpt from our cluster:

> `## Explicit Observations`
> `[…] sre-agent communicated a general rule that for JVM workloads, the`
> `pod_memory_limit must exceed the JVM -Xmx by at least 40 percent.`
> `[…] sre-agent identified the root cause of the OOMKills as a memory limit`
> `misconfiguration in the deployment that occurred on 2026-07-10.`
> `[…] sre-agent remedied the issue by raising the pod memory limit to 1Gi …`

7 structured observations extracted from the raw findings — that's the value the
deriver adds over a plain store.

### Honest operational notes (from the live run)
- **Deterministic layer is rock-solid** and needs only Postgres.
- **Dialectic works with any chat model** (ran on a free OpenRouter tier).
- **Deriver representations need a structured-output model** (`json_schema`).
  Free-tier models reject it → "zero observations". We use **Claude Sonnet 5**
  ($2/$10 per 1M — cheaper than 4.5's $3/$15). This is the one thing to configure
  for *full* value.
- **v3.0.12 changed its config schema** to a deeply-nested per-level structure;
  older env-var overrides silently fall back to its default `gpt-5.4-mini`
  (aliased in our litellm to Sonnet 5). Worth pinning explicitly per the new schema.
- **Cold-start:** semantic search + deriver are async — on a brand-new workspace,
  recall right after capture can miss (embeddings not indexed yet) and the first
  representation takes minutes. In real Leloir use this is a non-issue: capture
  happens at investigation-complete and recall on a *later* alert, so the async
  layers are always warm. Our warm-path manual runs pass all four operations.

### Observability (implemented)
- **No native Prometheus `/metrics` endpoint** (404) — a ServiceMonitor would have
  nothing to scrape. Honcho's observability is its **telemetry emitter**
  (CloudEvents over OTLP HTTP), off by default.
- **Enabled + verified live:** `TELEMETRY_ENABLED=true` +
  `TELEMETRY_ENDPOINT=http://alloy.monitoring.svc:4318` → Honcho emits to the
  cluster's **Grafana Alloy** collector (→ Prometheus/Tempo). Chart values
  `telemetry.{enabled,endpoint}` + role defaults; emitter confirmed started, no
  export errors.
- **Follow-up:** an Alloy pipeline to translate Honcho's CloudEvents envelope into
  Prometheus metrics / Tempo traces (collector-side config).

### Real benchmark harness
`leloir/scripts/bench-memory.sh` measures the four memory operations Leloir relies
on (CAPTURE / RECALL / SYNTHESIZE / DERIVE) against a backend, with real latency +
correctness, structured to add mem0/zep/letta. Live Honcho numbers (warm path):
CAPTURE ~45 ms, SYNTHESIZE ~14–19 s (dialectic, correct), DERIVE background with
Sonnet 5. Cold-start caveat applies (§ operational notes) — the harness reflects
that the async layers need warm-up, which real Leloir usage always has.

---

## 3. Real cases where memory makes the difference

Each case: the feature that adds the value, and **what is lost without it.**

**Case A — Recurring incident (auto-runbook).**
`checkout-service` OOMKills again next month. *With RAG episodic memory:* the
alert matches the past incident → the resolution is injected as an auto-runbook,
the agent confirms in one step, MTTR collapses. *Without it:* the agent
re-derives the root cause from zero, burning time and LLM budget on a solved
problem.

**Case B — Cross-service pattern (dialectic).**
A *different* JVM service starts OOMKilling. *With Honcho's dialectic:* the agent
asks "what's our JVM memory rule?" and gets the 40%-headroom rule distilled from
inv-001 — applies it proactively. *Without it:* the general rule stays trapped in
one incident's notes; the lesson doesn't transfer.

**Case C — Black-box agent gains a memory (the differentiator).**
A contained HolmesGPT (Modo 2) attaches Honcho as an `MCPServer`. *With it:* across
investigations it remembers this tenant's quirks ("this cluster's DNS flakes
under load") — continuity for an agent we can't modify. *Without it:* every
investigation starts cold; the black-box agent is amnesiac by construction.

**What you lose, by layer removed:**
- No RAG episodic → no auto-runbook (Case A). Governance unaffected.
- No external memory → no cross-incident/cross-agent synthesis (Cases B, C).
- No memory at all → 🟡 every investigation is correct but isolated; budgets,
  RBAC, audit, containment all still enforce. **Never 🔴 blocked.**

---

## 4. Framework comparison (metrics + recommendation)

> **Honesty note:** only **Honcho is deployed and live-tested on our cluster**
> (§2). mem0 / Zep / Letta are **NOT installed** — their rows below are
> **desk research** from each project's public material and benchmarks, not
> head-to-head measurements here. A real head-to-head would require deploying
> them on the same incident corpus (tracked as a follow-up).

All are **OSS and self-hostable** → no forced vendor lock. "Paid" columns are the
optional managed/enterprise tiers, not a requirement.

| System | Model | Long-memory benchmark | Community | Self-host | Paid lock risk | Fit for Leloir |
|---|---|---|---|---|---|---|
| **Honcho** ⭐ | peer-centric + deriver (theory-of-mind) + dialectic | ~90.4% LongMem (w/ Haiku 4.5 underneath) | growing | ✅ FastAPI+PG+Redis (**deployed here**) | low (fully OSS server) | **best** — peer model maps 1:1 to tenant/agent/investigation; live-tested |
| **mem0** | vector+graph+KV, auto-extraction | ~49% LongMemEval (GPT-4o) | largest (~47k★) | ✅ | **graph features gated to Pro** | good general default; watch the graph paywall |
| **Zep / Graphiti** | temporal knowledge graph (timestamps every fact) | **~63.8% LongMemEval** (best of these) | strong | ✅ Graphiti (engine) open | full **Zep platform is SaaS** (credits) | strong if temporal reasoning matters; keep to open Graphiti to avoid lock |
| **Letta (MemGPT)** | memory-OS (agent manages RAM/archival) | — | strong | ✅ fully OSS | low | most agent-autonomy; heavier mental model |

> ⭐ **Our recommendation: default to Honcho.** It's deployed, governed by our LLM
> layer, live-tested, and its peer-centric model is the cleanest fit for a
> multi-tenant, multi-agent governance product — plus it's the strongest for the
> black-box continuity story. **The user always decides**; mem0 / Zep / Letta drop
> into the same `MCPServer` slot. We ship Honcho as the reference and document the
> others as first-class alternatives.

**Caveats we state openly:** benchmark numbers come from each project's public
material and vary by underlying model — treat them as directional, not gospel.
Honcho's *deriver* needs a structured-output model for full value (§2). Zep's and
mem0's richest features have SaaS/Pro tiers; the OSS paths (Graphiti, mem0 core)
avoid lock.

---

## 5. Follow-ups
- Point Honcho's deriver at a structured-output-capable model → unlock full
  representations; re-measure.
- Wire Honcho as a documented `MCPServer` CRD example; run the black-box path
  (contained Holmes gains memory through the facade) as a live demo.
- Optional spike: mem0 vs Zep vs Letta head-to-head on a Leloir incident corpus
  if we ever want to change the default.
- Keep this doc's badges honest — update when a claim is re-verified.
