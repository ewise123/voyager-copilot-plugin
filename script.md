# GitHub Copilot Live Demo Script — 15 Minutes

## The Story

You pull a real sprint task from Azure DevOps, and Copilot does it — start to finish. The audience watches it fetch the task, understand the requirements, read the existing codebase, and produce a real deliverable. No fake APIs, no toy examples. A real task, from their real sprint board, shipped live.

**Parent Story #416796:** *AUL Prep Data Contract*
> As a Data Engineer, I want a completed prep data contract for AUL so that I can complete the prep layer transformations.

**Task #416852:** Convert the existing AUL dcs contract to ODCS format
**Task #416853:** Validate naming conventions and data types on all fields

**What exists today:**
- `contracts/raw/aul.yaml` — raw AUL contract (12 tables, ~2500 lines)
- `contracts/prep/max.yaml` — prep contract to learn from (ODCS v3.1.0, 15 tables)
- `contracts/prep/warranty_admin.yaml` — another prep contract (ODCS v3.1.0, 19 tables, has `servers` block)
- `contracts/prep/revolos.yaml` — older prep contract (ODCS v3.0.2)
- No `contracts/prep/aul.yaml` exists yet — that's what Copilot will create

**Key conventions Copilot must pick up from existing prep contracts:**
- Table names get prefixed with source name and `_source` suffix (e.g., `aul_allsales_details_source`)
- Columns get `description` fields and `transformSourceObjects` pointing to raw (e.g., `raw.aul.allsales_details.column_name`)
- Physical types are simplified (raw: `varchar(256)` → prep: `string`)
- Header includes `kind`, `apiVersion: v3.1.0`, `servers` with Databricks CI/prod, `status: draft`

---

## Pre-Demo Setup

### VS Code Layout
- **Open files (tabs):** `contracts/raw/aul.yaml`, `contracts/prep/warranty_admin.yaml` — these give Copilot immediate context
- **Explorer sidebar:** Expanded to show `contracts/prep/` so audience sees there's no `aul.yaml` yet
- **Copilot Chat:** Open on the right side, cleared
- **Terminal:** One clean panel at the bottom
- **Close** everything else — no Python files, no `.projenrc.ts`, nothing distracting

### Font Size
- Ctrl+= to zoom until YAML is readable from the back of the room (16-18pt)

### Pre-flight Checks
```
[ ] ADO MCP server is running (Ctrl+Shift+P → "MCP: List Servers" → ado shows "Running")
[ ] Copilot is signed in (status bar icon)
[ ] Agent mode is available in the Copilot Chat mode dropdown
[ ] contracts/prep/aul.yaml does NOT exist (delete if you did a practice run)
[ ] No previous chat history in Copilot Chat (clear it)
[ ] Git status is clean
[ ] YAML schema validation is working (open warranty_admin.yaml — no red squiggles = good)
[ ] Network connectivity is solid (Copilot + ADO MCP both need internet)
[ ] Note which model you're using (mention it in wrap-up)
```

---

## Act 1 — The Pull (2-3 min)

### [0:00] Opening (30 sec)

> *"I'm going to do something you can try yourself after this session. I'm going to pull a real task from our sprint board in Azure DevOps and let Copilot do it — live, right here. No slides, no scripted demo."*

### [0:30] The Prompt

Make sure the Copilot Chat mode is set to **Agent**. Type:

```
Look up ADO work items 416852 and 416853 in the AIAccelerator project, and their parent story. Then start both tasks: create the AUL prep data contract by converting the raw contract at contracts/raw/aul.yaml into ODCS format, following the same conventions and structure as the existing prep contracts in contracts/prep/. Start with the first 3-4 tables to establish the pattern, and validate naming conventions and data types as you go.
```

**Press Enter.** Pause. Let the audience absorb what just happened — you typed a work item number and Copilot is now reaching into Azure DevOps.

### [0:45] Narrate the ADO Fetch

When Copilot calls the ADO MCP tools:

> *"Watch this — it's pulling the task from Azure DevOps right now. It's reading the task title, the parent story, the acceptance criteria. I didn't paste any of that in — it fetched it through an MCP connection."*

> *"Quick aside — the ADO integration is an MCP server. It's a nice-to-have, not a requirement. You don't need it to use Copilot. But it took about five minutes to set up and now Copilot can pull tasks, read stories, check sprint boards — all from chat. We can set this up for anyone who wants it."*

### [1:30] Narrate the Code Reading

When Copilot reads `contracts/raw/aul.yaml`:

> *"Now it's reading the raw AUL contract — 2,500 lines, 12 tables. It needs to understand every column, every data type."*

When it reads the existing prep contracts:

> *"And there — it found the existing prep contracts. It's reading warranty_admin and max to learn what a prep contract looks like. The naming convention, the ODCS structure, the server blocks, the transformSourceObjects pattern — it's learning all of that from your code, not from documentation I fed it."*

**Timing cue:** If the ADO fetch + reading phase takes longer than 3 minutes, don't worry — this is the impressive part. Let it work. The audience is watching AI read their sprint board and codebase.

---

## Act 2 — The Build (6-8 min)

### [~2:30] Contract Generation Starts

When Copilot starts producing the file:

> *"Here it goes — it's generating the prep contract. Watch the structure."*

Mostly stay quiet and let the audience watch. Call out these moments:

**When the header appears:**

> *"See the header — `apiVersion: v3.1.0`, `kind: DataContract`, the servers block with Databricks CI and prod. It got that from the warranty_admin contract. I didn't tell it what servers to use."*

**When the first table appears with `_source` suffix:**

> *"There — `aul_allsales_details_source`. It added the `aul_` prefix and the `_source` suffix. That's the naming convention from our other prep contracts."*

**When `transformSourceObjects` appear:**

> *"Look at the `transformSourceObjects` — it's mapping each prep column back to its raw source. `raw.aul.allsales_details.address`. It built that lineage from reading the raw contract."*

**When physical types are simplified:**

> *"Notice the physical types — the raw contract had `varchar(256)`, `char(2)`, `decimal(12, 2)`. The prep contract has `string`, `string`, `decimal(12,2)`. It normalized the types to match what the other prep contracts do."*

### [~7:00] Validation Phase (Task #416853)

If Copilot does the validation as a second pass:

> *"Now it's doing the second task — validating naming conventions and data types. It's checking its own work against the patterns in the other prep contracts."*

If Copilot finds and fixes issues:

> *"It caught something — [describe what]. This is the self-correction loop. It generated the contract, reviewed it, and fixed the issue. That's two tasks done from one prompt."*

### [~9:00] The File Exists

Once the file is saved, click on `contracts/prep/aul.yaml` in the explorer.

> *"There it is. `contracts/prep/aul.yaml` — the first 3-4 tables of the prep contract. Let's look at it."*

Scroll through slowly. Point out:
- The header matches the ODCS format
- Tables are named with the `aul_..._source` convention
- Each column has descriptions and `transformSourceObjects`
- Data types are consistent with the other prep contracts

> *"I scoped it to the first few tables to validate the pattern. In practice, I'd continue with the rest in the same session — just say 'keep going with the remaining tables.' The pattern is established; the rest is repetition."*

### Schema Validation ("Green Checkmark" Moment)

> *"And look — no yellow or red squiggles. The VS Code YAML schema validation is checking this against the Open Data Contract Standard schema. It validates."*

If there ARE squiggles:

> *"We've got a couple of schema warnings — let's ask Copilot to fix them."*

Type in chat:
```
Fix the YAML schema validation warnings in contracts/prep/aul.yaml
```

---

## Act 3 — Practical Tips + Close (3-4 min)

### [~10:00] The MCP Moment

> *"Let me zoom out for a second. What you just watched: I typed a work item number. Copilot pulled the task from ADO, read 2,500 lines of YAML, learned the pattern from three other contracts, generated a new one, and validated it. That's a task that would take an engineer a couple hours to do carefully. And we did it with one prompt."*

> *"The ADO connection is an MCP server — Model Context Protocol. It's an open standard that lets Copilot talk to external tools. We have it connected to ADO, but you can connect it to databases, APIs, internal tools — anything that speaks MCP."*

### [~11:00] Quick Feature Callouts

Select a chunk of the generated YAML. In Copilot Chat:

```
/explain
```

> *"/explain works on any code or config. Useful when you inherit a 5,000-line data contract and need to understand what's in it."*

In chat:
```
@workspace Which prep contracts are using apiVersion v3.1.0 vs v3.0.2?
```

> *"@workspace searches your entire codebase. Quick way to audit consistency without grep."*

In chat:
```
@workspace What tables in the raw AUL contract don't have a corresponding table in the prep contract?
```

> *"That's a real question you'd ask during a data contract review. Copilot answers it from the code."*

### [~13:00] Wrap-Up

> *"Everything I showed you is available right now. Agent mode, MCP connections, @workspace, /explain — it's all in your VS Code today. The model I used is [state model]."*

> *"Three things you can try this afternoon:*
> 1. *Open any file and ask Copilot to /explain it*
> 2. *Use @workspace to ask a question about your codebase*
> 3. *Try agent mode on a small task — a config change, a test, a code review*

> *There's also custom instructions, different model choices, and we can set up the ADO MCP for anyone who wants it. We'll cover those in a follow-up. Questions?"*

---

## Wow Moment Callouts

### 1. "It Pulled the Task from ADO"
The moment Copilot fetches the work items — pause and let it land.

> *"I didn't paste in any requirements. I gave it a work item number and it pulled the task, the parent story, and the acceptance criteria from Azure DevOps. It knows what 'done' looks like because it read the story."*

### 2. "It Learned the Convention from Your Code"
When the first `aul_..._source` table name appears:

> *"I didn't tell it to add the `aul_` prefix or the `_source` suffix. It figured out that naming convention by reading your existing prep contracts. That's not generic AI knowledge — that's pattern matching on YOUR codebase."*

### 3. "The `transformSourceObjects` Lineage"
When the raw-to-prep column mappings appear:

> *"Each column traces back to its raw source — `raw.aul.allsales_details.address`. It built complete data lineage by cross-referencing the raw contract with the prep patterns. That's the kind of tedious, error-prone work that takes hours when done manually."*

---

## Backup Plans

### ADO MCP Fails to Connect
**Symptoms:** Timeout, auth error, MCP server not running.

**Immediate fix:** Skip the ADO fetch. Change the prompt to:

```
Create an AUL prep data contract at contracts/prep/aul.yaml by converting the raw contract at contracts/raw/aul.yaml into ODCS format. Follow the same conventions as the existing prep contracts in contracts/prep/. Start with the first 3-4 tables to establish the pattern, and validate naming conventions and data types as you go.
```

**Narrate:** *"The ADO integration isn't cooperating — sometimes VPN gets in the way. Let me give it the task directly. The MCP connection is a convenience, not a dependency."*

### Agent Mode Takes Too Long (>8 min on generation)
We scoped to 3-4 tables, so this is unlikely. But if it stalls:

**At the 8-minute mark:** Check progress.

If it's produced even 1-2 tables:
> *"Let me show you what it's built so far."*

Stop generation. Open whatever file exists. Even one well-formed table is enough to demonstrate the pattern matching.

If it finished the tables but is still going (doing all 12 despite the prompt):
> *"It decided to keep going — that's the agent being ambitious. Let me show you what it's done."*

Then jump to Act 3.

### Copilot Produces Wrong Structure
**Symptoms:** Missing `_source` suffix, wrong `transformSourceObjects` format, wrong API version.

**Fix in chat:**
```
The prep contract should follow the exact same structure as contracts/prep/warranty_admin.yaml. Table names need the aul_ prefix and _source suffix. Each column needs transformSourceObjects mapping to the raw source like raw.aul.<table>.<column>. Fix the contract.
```

### Schema Validation Shows Errors
If the ODCS schema validation highlights issues in the generated file, that's actually a demo opportunity:

> *"The schema validator caught some issues — let's have Copilot fix them."*

Paste the issue in chat. This shows the "Copilot + tooling" workflow.

### Nuclear Option: Everything Goes Wrong
If agent mode hangs or produces garbage:

1. Open `contracts/prep/warranty_admin.yaml` and `contracts/raw/aul.yaml` side by side
2. Do Act 3 features on the existing contracts (/explain, @workspace queries)
3. Say: *"Agent mode is powerful for generation tasks, but let me show you features you'll use daily."*
4. Demonstrate @workspace: *"@workspace what are the differences between the raw and prep contract formats?"*
5. Close with the same practical tips

---

## Timing Cheat Sheet

| Time | What's Happening | If Behind |
|------|-----------------|-----------|
| 0:00 | Opening line | 30 sec max |
| 0:30 | Type prompt | — |
| 0:45-1:30 | ADO fetch + narrate | If ADO fails, use backup prompt |
| 1:30-2:30 | Copilot reads contracts | Let it work |
| 2:30-9:00 | Generation + validation | If stuck at 8 min, show partial result |
| 9:00-10:00 | Review generated file | Keep to ~1 min |
| 10:00-10:30 | MCP/architecture reflection | — |
| 10:30-13:00 | /explain, @workspace demos | Drop one if behind |
| 13:00-15:00 | Wrap-up + questions | Hard stop at 15:00 |

---

## Dry-Run Checklist (Morning of Demo)

```
[ ] 1. ADO MCP is running:
      Ctrl+Shift+P → "MCP: List Servers" → ado = Running
      If not, restart it from the MCP panel

[ ] 2. Test ADO fetch manually:
      In Copilot Chat (Agent mode): "Look up ADO work item 416852 in AIAccelerator"
      Should return the task title

[ ] 3. YAML schema validation works:
      Open contracts/prep/warranty_admin.yaml
      No red squiggles = ODCS schema is loaded

[ ] 4. contracts/prep/aul.yaml does NOT exist:
      If you did a practice run, delete it:
        Remove-Item contracts\prep\aul.yaml -ErrorAction SilentlyContinue

[ ] 5. Git state is clean:
      git status — no uncommitted changes

[ ] 6. Copilot signed in + Agent mode available

[ ] 7. Model selection:
      Note which model is active — mention in wrap-up

[ ] 8. VS Code zoom level:
      Readable from back of room

[ ] 9. Only these tabs open:
      contracts/raw/aul.yaml
      contracts/prep/warranty_admin.yaml

[ ] 10. Terminal is clean:
       Clear all output

[ ] 11. Network test:
       Both Copilot and ADO MCP need connectivity

[ ] 12. Practice run timing:
       Do one full rehearsal. Time it. Target under 14 min.
       If generation takes too long, you know where to cut.

[ ] 13. Know the fallback prompt by heart:
       Without ADO: "Create an AUL prep data contract..."
       (See Backup Plans section)

[ ] 14. If you did a practice run and it went over time:
       Consider which @workspace questions to drop in Act 3
       The essential ones: /explain + one @workspace query
```
