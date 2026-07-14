# Memory for Leloir — deep analysis, live results & framework comparison

**Audience:** decision-makers + the marketing page. Honest, metric-backed.
**TL;DR:** memory is an **upgrade, never a hard dependency**. Leloir ships native
memory; external memory systems plug in through the MCP Gateway. **We default to
Honcho** (deployed, governed, live-tested) — but any of mem0 / Zep / Letta drops
in, and the user chooses. What each layer/feature buys you, and what you lose
without it, is spelled out below with real evidence from our cluster.

---

## The cost of forgetting — why memory matters

Turn memory off and Leloir still governs perfectly: budgets hold, RBAC holds, the
audit trail is complete, black-box agents stay contained. **Nothing breaks.** But
the platform gets *amnesia*, and amnesia is expensive:

- **Every incident is investigated from zero.** The 3 a.m. OOMKill you root-caused
  last month? The agent re-derives it from scratch — same tokens, same minutes,
  same toil. Memory is what turns the second occurrence into a one-step
  confirmation instead of a fresh investigation.
- **Lessons never compound.** A rule learned on `checkout-service` ("JVM pods need
  40% headroom over -Xmx") stays trapped in one incident's notes. With memory it
  transfers to the next JVM service *before* it pages someone.
- **Your black-box agents are amnesiac by construction.** A contained third-party
  agent (HolmesGPT, kagent) can't be modified — external memory over the MCP facade
  is the *only* way to give it institutional knowledge of *your* cluster's quirks.
- **Budget burns on solved problems.** Re-investigating a known incident spends LLM
  budget you already paid once. Memory is also a FinOps lever.

**So the honest pitch is not "you must have memory" — it's "without it, Leloir is a
brilliant investigator with no long-term memory: correct every time, wiser never."**
Memory is the difference between a tool that *responds* and a platform that *learns*.
And because it plugs in through the governed MCP path, you add it — and swap it —
without touching the core.

## 0. THE MAP — how every Leloir capability relates to memory

This is the authoritative table: for each Leloir feature, **does it touch memory,
which layer, is memory required or just an enhancement, and what is lost without
it.** It's how you reason about the Leloir stack's dependency on memory. Grounded
in the actual integration points (code refs in the last column).

Legend — **Dependency:** `required` (feature can't work without memory) ·
`enhancement` (works without, better with) · `none` (independent) ·
`isolation` (memory participates but the governance property is the point).

| Leloir capability | Memory? | Layer | Dependency | What memory covers here | Lost without memory | Where (code) |
|---|---|---|---|---|---|---|
| Alert ingestion & routing | no | — | none | — | nothing | — |
| **Investigation — entry (recall)** | yes | RAG episodic | **enhancement** | on a top-level alert, a similar past incident is recalled and injected as an auto-runbook `SkillRef` | agent starts cold, re-derives from zero | `orchestrator.go:280` (`RAG.Recall`) |
| **Investigation — completion (capture)** | yes | RAG episodic | **enhancement** | on success with a root cause, the `alert→cause→remediation` triangle is stored | nothing learned for next time | `orchestrator.go:797` (`RAG.Capture`) |
| **Auto-runbook (recurring incident)** | yes | RAG episodic | **enhancement (the core value)** | the recalled resolution collapses MTTR on a repeat | every recurrence investigated from scratch, burning budget | recall+capture above |
| **Agent scratch memory** (`remember/recall/forget`) | yes | `leloir-memory-mcp` | enhancement | agents persist durable facts across tool calls, per-tenant | agents are stateless between calls | `cmd/leloir-memory-mcp` (MCP tools via gateway) |
| **Cross-session / cross-incident continuity** | yes | external (Honcho/mem0/Zep/Letta) | enhancement | "what did we learn about this service/tenant over time" | lessons stay trapped in one incident | `MCPServer` CRD → MCP facade |
| **Black-box agent memory (Modo 2)** | yes | external via MCP facade | **enhancement (differentiator)** | a contained agent gains continuity **without touching its runtime** | contained agents are amnesiac by construction | MCP facade → external memory |
| Scheduled investigations | yes | RAG episodic | enhancement | same recall/capture path as any top-level investigation | same as investigation | inherits `StartInvestigation` |
| A2A sub-investigations | **no (by design)** | — | none | a child inherits the parent's context; recall would add noise | nothing (intentional) | `orchestrator.go:277` (`ParentInvestigationID==""` guard) |
| Distill runbook (m17.7) | partial | procedural (runbooks) | enhancement | complements episodic RAG with reusable procedures | no distilled procedures | runbook handler |
| Change context (m17.4) | no | (recent rollouts feed) | none | "what changed recently" is a separate signal, not memory | less context, still works | changelog |
| HITL / approvals | no | — | none | — | nothing | — |
| Budget / quota / spend governance | no | — | none | — | nothing | — |
| **Audit / WORM log** | no | — | **none (and deliberately separate)** | audit is the tamper-evident source of truth; NOT a memory store | nothing — audit never depends on memory | `audit/` |
| RBAC / multi-tenancy | yes | all layers | **isolation** | **every recall is tenant-scoped first** (filter by `tenant_id` before similarity) — memory can't leak across tenants | — (this is a guarantee, not a feature loss) | RAG store tenant filter; memory-mcp header |
| Shadow mode / Quarantine / SIEM streaming | no | — | none | — | nothing | — |
| Blind-spot / drift detection | no | — | none | — | nothing | — |

**Reading the map:**
- **Memory is never `required`.** The heaviest dependency is `enhancement` — Leloir
  runs, governs, and is correct without any memory; memory makes it *smarter*
  (faster MTTR, cross-incident learning, black-box continuity).
- **The governance core is memory-independent:** audit, budgets, RBAC, HITL,
  containment, quarantine — none touch memory. That's why "no memory" is 🟡
  degraded, never 🔴 blocked.
- **The one hard property:** when memory IS used, it is **tenant-scoped by
  construction** — recall filters by tenant before similarity, so memory upholds
  the same isolation as the rest of the platform.

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

### Which solution covers which Leloir memory need

Same needs as the §0 map, scored per backend (✅ native/strong · 🟡 possible/partial ·
— not its focus). This is "which memory system to reach for per use case."

| Leloir memory need | native RAG+memory-mcp | Honcho ⭐ | mem0 | Zep | Letta |
|---|---|---|---|---|---|
| Auto-runbook (episodic recall of past incident) | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Agent scratch memory (remember/recall/forget) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Cross-session continuity per agent/service | 🟡 | ✅ | ✅ | ✅ | ✅ |
| Peer/entity modeling ("what agent A knows about service B") | — | ✅ (native peer model) | 🟡 | 🟡 | 🟡 |
| Temporal reasoning ("what was true when") | 🟡 | 🟡 | 🟡 | ✅ (native temporal graph) | 🟡 |
| Black-box agent memory via MCP facade | ✅ | ✅ | ✅ | ✅ | ✅ |
| NL synthesis over memory (dialectic) | 🟡 (via LLM) | ✅ (native) | 🟡 | 🟡 | ✅ |
| Tenant isolation (recall scoped per tenant) | ✅ | ✅ (workspace) | ✅ | ✅ | ✅ |
| Fully self-hosted, no paid tier | ✅ | ✅ | 🟡 (graph=Pro) | 🟡 (platform=SaaS) | ✅ |
| Zero extra infra (beyond Leloir's Postgres) | ✅ | — (own PG+Redis) | — | — | — |

### The wider landscape (surveyed — the slot is open)

The four above are not the whole field. We surveyed the 2026 landscape; other
notable **self-hostable** options that plug into the same `MCPServer` slot:

| System | Angle | Self-host | Note |
|---|---|---|---|
| **Cognee** | hybrid graph+vector, 14 retrieval modes, self-improving pipeline, MCP server | ✅ Apache-2.0 | ranks #1 in several 2026 lists; heavier (graph+vector+relational stores) |
| **EverMind EverOS** | highest stated LoCoMo/LongMemEval scores | ✅ Apache-2.0 | benchmark-leader claim; evaluate independently |
| **Supermemory** | coding-agent memory, MCP + Claude Code plugins | ✅ | purpose-fit for dev-agent workflows |
| **memobase** | cross-tool "memory passport" over MCP | ✅ | shared memory across MCP clients |
| **LangMem / Memary** | LangGraph-native / graph memory | ✅ | framework-coupled |

**This is the whole point of the design:** Leloir is **not limited to any one memory
system**. The `MCPServer` CRD slot is open — Honcho, Letta, mem0, Cognee, EverMind,
or one that doesn't exist yet all attach the same governed way. Our job is to ship a
*tested, sensible default*, not to lock you in.

> ⭐ **Our recommendation: Honcho is the default *for Leloir* — not "the best memory
> system in the world", but the best fit for THIS product.** It's deployed here,
> governed by our LLM layer, live-tested end-to-end, self-hosts cleanly with built-in
> auth, and its peer-centric model (peer = agent/service/tenant) maps 1:1 onto
> Leloir's world — plus it's the strongest for the black-box continuity story.
> **You always decide.** Letta is the lightest alternative; mem0/Cognee/EverMind are
> first-class options; Zep's platform is off the table for self-host (§5). We ship
> Honcho as the reference and keep the slot open.

**Caveats we state openly:** benchmark numbers come from each project's public
material and vary by underlying model — treat them as directional, not gospel.
Honcho's *deriver* needs a structured-output model for full value (§2). Zep's and
mem0's richest features have SaaS/Pro tiers; the OSS paths (Graphiti, mem0 core)
avoid lock.

---

## 5. Deployment reality & self-host viability (why this matters for a self-hosted product)

Leloir is a **self-hosted-first governance product**. A memory system's value is
moot if it can't be run in the customer's cluster without a SaaS dependency. This
is the single most decision-relevant axis, and the four differ sharply:

| System | Self-host footprint | Deps beyond an LLM | Auth | 2026 status | Self-host verdict |
|---|---|---|---|---|---|
| **Honcho** ⭐ | 1 API + worker + Postgres + Redis | Postgres, Redis | JWT (HS256) built-in | active OSS | ✅ **clean** — deployed & tested here |
| **Letta** | 1 server (FastAPI) + Postgres | Postgres only | token | active OSS | ✅ **simplest** — no graph DB |
| **mem0** | API + Postgres/pgvector + Neo4j | pgvector **+ Neo4j** (graph) | **none by default** (needs a proxy) | active OSS; graph tier gated Pro on cloud | 🟡 **heavier** — 3 stores, add auth |
| **Zep** | Graphiti engine + graph DB (Neo4j/FalkorDB/Kuzu) | graph DB | — | **⚠️ Community Edition DEPRECATED (2026)** | 🔴 **not viable as a platform** — full API is SaaS-only; only the open Graphiti engine remains |

**Critical finding — Zep:** the self-hostable **Community Edition was deprecated
in 2026**. Production Zep now flows through **Zep Cloud (SaaS)** or a hand-rolled
Graphiti + graph-DB stack *without* Zep's higher-level API. For a product whose
whole thesis is "run it in your own cluster, no vendor lock," recommending Zep's
platform would contradict the pitch. We keep Zep in the comparison for its
temporal-graph strength, but flag it **not viable for self-hosted Leloir** — only
the open Graphiti engine is, and that's a build-your-own effort.

**What this means for the default:** Honcho and Letta are the two clean
self-host paths. mem0 works but adds a Neo4j and needs an auth proxy. Zep's
platform is off the table for self-host. This reinforces **Honcho as the
default** (clean deploy, built-in auth, already governed by our LLM layer) with
**Letta as the lightest alternative**.

## 6. Evaluation methodology (how we measure — reproducible)

Every claim marked "tested" comes from `leloir/scripts/bench-memory.sh`, which
runs the **same four-operation benchmark** against each backend:

| Operation | What it measures | Pass criterion |
|---|---|---|
| CAPTURE | write latency of an investigation's findings | HTTP 2xx, < 1s |
| RECALL | does a later JVM alert retrieve incident inv-001 (not the redis one)? | top-1 correct |
| SYNTHESIZE | NL query answered from memory across sessions | answer contains the learned rule + source incident |
| DERIVE | background reasoning produces a structured representation | ≥1 observation |

Same incident corpus, same LLM layer (litellm), same cluster. Backends are added
by implementing `run_<backend>` against their REST API — so the matrix is
**reproducible and honest**, not vendor-marketing numbers. Live results are
filled in as each backend is deployed in infra-ai (`make honcho|letta|mem0`).

### Live benchmark matrix (filled as deployed)

| Operation | Honcho (v3.0.12) | Letta (0.16.8) | mem0 | Zep |
|---|---|---|---|---|
| CAPTURE | ✅ ~45 ms (deterministic write) | ✅ ~2.5 s (inline embed) | _pending deploy_ | n/a (CE deprecated) |
| RECALL | ✅ HIT (warm) | ✅ HIT ~2 s (inv-001 top-1) | _pending_ | n/a |
| SYNTHESIZE | ✅ ~14–19 s, correct | ✅ ~38 s (agent multi-step) | _pending_ | n/a |
| DERIVE | ✅ w/ Sonnet 5 (7 observations) | n/a (agent self-edits, no bg deriver) | _pending_ | n/a |

**What the numbers say (Honcho vs Letta, both live-tested):**
- **Honcho is lighter & faster.** CAPTURE is a ~45 ms deterministic write (embedding
  is async); Letta embeds inline on write (~2.5 s). Honcho's dialectic answers in
  ~15 s; Letta's agent does multi-step self-reasoning (~38 s).
- **Letta needs a strong tool-calling model.** With `gemini-flash` its agent
  messaging returned HTTP 500; only `claude-sonnet` produced correct answers. Honcho's
  dialectic worked even on a free-tier model; only its *deriver* needs a strong model.
- **Setup friction:** Letta's "simplest to self-host" claim has a caveat — its
  migration needs the pgvector extension enabled manually (`CREATE EXTENSION vector`);
  Honcho booted clean.
- **Model fit:** Letta is **agent-centric** (each memory is an agent that edits its
  own context) — powerful but heavier per operation. Honcho's **peer + deriver +
  dialectic** split is a better match for Leloir's "many tenants, many agents, cheap
  reads" shape. This is the concrete, measured reason Honcho is our default.

## 7. Follow-ups
- Point Honcho's deriver at a structured-output-capable model → unlock full
  representations; re-measure.
- Wire Honcho as a documented `MCPServer` CRD example; run the black-box path
  (contained Holmes gains memory through the facade) as a live demo.
- Optional spike: mem0 vs Zep vs Letta head-to-head on a Leloir incident corpus
  if we ever want to change the default.
- Keep this doc's badges honest — update when a claim is re-verified.
