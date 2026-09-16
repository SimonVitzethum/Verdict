# Gabbro — the language

**Four mechanisms, two declaration rules, one library layer — and the constructs that make
kernels, drivers and programs fully expressible.**

The **notation** is in [`SYNTAX.md`](SYNTAX.md) (130 EBNF rules, closed, reachable, vocabulary
covers every terminal). The **proof architecture** in [`BEWEIS.md`](BEWEIS.md), the path in
[`PLAN.md`](PLAN.md).

> **This file was pulled together on 2026-08-14.** Before that it contained only the mechanisms;
> the specification and the three supplements lay beside it as files of their own. **That was
> filed wrongly: they are central parts of the language, not an appendix.** The text is taken
> over unchanged, including the corrections that arose while entering it —
> **structurally merged, not editorially smoothed.**

---


## 3. The core — four mechanisms and two declaration rules

### M1 — Range types

Integers carry their **value range**, and every operation must stay inside it. That is Ada's
trick, and **exactly it** found S1a/S1b — not "Ada is safer".

```gabbro
type SlotIdx  = u32 in 0 .. NSLOTS-1
type Refcount = u32 in 0 .. u32::max
type Zyklen   = u64 in 1 .. u64'max      -- Null ist ein Befund, kein Messwert
```

### M2 — Linear values, ghost ones too

A linear value **must** be consumed; a ghost one exists only in the proof and is deleted before
code generation (**no byte, no heap** — measured against Verus).

```gabbro
linear type Parked                 -- muss zugelassen werden
linear ghost type Held(CAPS)             -- Sperrbeleg, kostenlos
linear ghost type Duty(check)         -- eine unerfuellte Pruefzusage
```

### M3 — Address spaces and access rights on the pointer

A pointer carries **where** it points and **what** you may do with it. C has that as an
extension; here it is the default.

```gabbro
ptr<mmio, w>  gcmd            -- ein Lesen zum Zurueckschreiben ist nicht schreibbar
ptr<dma,  rw> puffer
ptr<code, x@ring3> sonde
```

Barriers belong to the address space, not to the architecture — `dsb sy` against `dmb ish` is no
longer a matter of style but follows from `mmio` against `normal`.

### M4 — No unchecked index, no unbounded loop

Indexing works only with evidence of membership; every loop names its descent measure.
`traverse` is the convenient notation for that, not a mechanism of its own.

### D1/D2 — the two declaration rules

* **Opaque new types without implicit conversion.** `Pa`, `Iova`, `Farben`, `MaskenBits` are
  different types — C's `typedef` is transparent, and that is the hole.
* **Complete layouts, no catch-all branch.** Every bit of a word is named, every enumeration is
  exhaustive.

### What C has and keeps

Functions, pointers, `struct`, fixed widths, control flow, function pointers, explicit conversion
between **compatible** types. **What falls away:** implicit conversion, `void*`, pointer
arithmetic without a basis, `goto`, catch-all branches, `union` as reinterpretation (M3 can do
that), preprocessor.

---

---

## 3b. The twenty fall out — as a library, not as syntax

**That is the test of the reduction.** If a line is left without a derivation, a mechanism is
missing.

| formerly "construct" | follows from | how |
|---|---|---|
| formerly *"unit"* (Pa/Iova/Farben) | **D1** | opaque new type |
| `arithmetic` (S1b) | **M1** | `Refcount` does not leave its range |
| `refusal`, `ground_set` | **D2** | exhaustive enumeration, no catch-all branch |
| `bitfield` (mark on bit 63) | **D2** | complete layout — the number field is occupied |
| `set` instead of a cardinal number | library | a field type over M1 |
| `derivation` | `const` evaluation | C has that too, only without a check |
| `slot_type` (constructor per slot) | **M2** + module boundary | opaque, one generator |
| `right` (reading ≠ writing) | **M3** | two pointer rights, not one line with two directions |
| `device`, register classes | **M3** + **D2** | `mmio` + `write_only` + complete layout |
| `barrier` domain | **M3** | follows from the address space |
| `placement` (`.user_text`) | **M3** | `code` space with `execute@ring3` |
| `region`, ownership | **M2** | a linear block is its region |
| `linear` (`Parked`) | **M2** | the mechanism itself |
| `state` (typestate, x2APIC) | **M2** | linear value whose type carries the state |
| `lock` / `held(L)` | **M2** | `linear ghost Held(L)` — **measured** against Verus that this carries |
| lock **order** ⇒ deadlock freedom | **M2 + M1** | the level is a range type, taking requires a strictly smaller level |
| `atomic` publication | **M2** | `release` hands over a ghost token, `acquire` takes it |
| formerly *"effect"* (Global/Depends) | **M2** | effects **are** ghost capabilities in the parameter |
| `traverse` (S1a) | **M4** | notation, not a mechanism |
| `format` / `table` | library | declarations over M1/M3/D2 |
| **`check`** | **M2** | **see below — the prettiest derivation** |

> **The typestate row is a DERIVATION, and it was proposed as a construct on 2026-09-01.**
> `PLAN-HARDWARE.md` §42 wanted a word `phase`, generalised over `table`, `ops`, `fn` and
> `reg`. Recomputed and refused (`messung/PHASENKONSTRUKT.md`): it lowers the vocabulary by
> **one** word, not four, and the *"one lowering theorem instead of four"* it promised is
> **zero instead of zero** — a ghost mark emits no C, so there is nothing for a lowering
> theorem to be about. *The row above already had it right: a linear value whose type carries
> the state. **M2**, not a construct.*

### The four old design rules — they are now DERIVATIONS, not rules

Rule 1 is **M4**, rule 2 is **M1 + M4**, rule 3 is **D2**, rule 4 is **D1 + D2**. They still
stand here because their **sites** are the evidence — each one is a paid-for mistake.

Each is phrased as the answer to a paid-for mistake. The constructs themselves are in the library
layer below; here stand the rules and their sites.

### 1. Total by construction — and "finite" is the WEAKEST promise

There is **no unbounded loop**, only traversals with `over`/`by`/`touches`.

> *Site:* `migration_candidate` runs a chain `while i != NIL` **without a step bound**, while
> the checker runs one over the same chain. Under the core lock a cycle there is a stopped
> core.

Termination alone buys little: a loop with a step bound **terminates** and can still index
outside the table — that is exactly **S1a**. The step bound from B-5.5 protects against
**cycles**, not against an index **outside**.

#### The counter rule — it stood in no document, and our own example corpus paid for it three times

> **Every counter needs a bound in the declaration *and* a check before the arithmetic.**

Both halves are needed, and **each alone is a trap**:

* **A `u64` without an upper bound cannot be incremented.** M1 knows no bound to compute
  against; `+ 1` stays formally inside the width and is substantively unbounded.
* **`in 0 .. GRENZE` alone is not enough** — `+ 1` reaches up to `GRENZE + 1`, and exactly there
  `M104` falls. The type names the range; it does not name that the *arithmetic* stays inside it.

The check belongs **before** the arithmetic, not after it. *That is the same cut «B29» hangs on*
— `refcount -= 1` with the null check **afterwards** is the inversion of this rule, and it has
survived five rebuilds in the measured tree (`MESSUNGEN.md`).

**Why this stands here and not as a style hint:** the checker already enforces the rule
(`M104`), but it was written down nowhere — the refusal justified itself. *A rule that exists
only as an error message is one nobody can read before writing.*

### 2. No pointers — only offsets, each against a length in scope

An offset without the length it holds against is not writable. The range check does not arise
from care but because there is no other way to phrase it.

> *Site:* `audit_cdt` checks `parent` against `nslots`, but then reads `first_child` and the
> sibling chain **unchecked**. With `panic = "abort"` the checker tears the node down with it —
> at exactly the anomaly it is supposed to report.

### 3. Refuse, never interpret

An unknown version, a set reserved field, a crooked length: **named refusal**, one code per
reason — not a shared malformation error.

> *Site:* A check read **one byte** of the kernel hash instead of comparing 512 bytes: false
> alarm on 1 in 256 builds, **blind on 255 of 256** genuine overwrites.

**This rule has a price, and it stands at `by unvisited`:** a mere step counter would cut a cycle
off **silently** instead of reporting it as a refusal — that would be interpretation. The
language thereby forces the expensive version (bitmap or generation stamp), see `traverse` below.

### 4. Fixed widths, spelled-out byte order

No `usize`, no host layout, no `#[repr]` trust. What stands on the wire stands in the descriptor.

> *Site:* `MASK_BITS` was not the colour count — on x86 (256 colours) accidentally right, on
> aarch64 (16) wrong. With 16 colours stripe 0 got **all** colours and the rest none, and because
> empty sets do not intersect, the self-test reported "disjoint".

---

### `check` is not a special form but a linear obligation

The construct with the 33 killed traps needs **no keyword of its own**:

* A `check` produces a `linear ghost Duty`. **Whoever does not consume it does not compile** —
  that is literally "a `check` that stands in no gate list is a mistake" (trap 17, and the
  `all_done()` hole 21 against 24), and it falls out of M2 instead of out of a special rule.
* The **speech test** is a second obligation that only a *failed* run consumes.
* The **lower bound** is M1: a measured quantity with `in 1 ..` cannot report zero.
* "The measured path writes the quantity itself" is a **write right** — M3.

**This keeps the thesis of this folder standing and makes it smaller:** the most valuable thing
is not a checking keyword but that **check obligations are the same linear values as resources.**

---

---

## Unsafe boot code — with PROOF that it never runs again afterwards

A kernel needs it: raw physical addresses before the MMU stands; multiboot structures; the core
handover. The demand is not "as little `unsafe` as possible" but **"`unsafe`, but demonstrably
expired"** — and that is strictly stronger than anything Rust can do today.

**It falls out of M2 without a new mechanism:**

```gabbro
linear ghost type BootPhase              -- genau EINE Instanz, beim Eintritt erzeugt

raw fn phys_write(p: Pa, w: u64) requires &BootPhase
raw fn mb_info_read(p: Pa) -> Info      requires &BootPhase

fn boot_end(t: BootPhase)               -- VERBRAUCHT die Marke; es gibt keine zweite
    effects { drops code<boot> }                  -- ... und bildet .boot im selben Zug ab
```

**Two levels, and the second is the actual gain:**

| | Statement | how |
|---|---|---|
| **static** | no `raw` function is callable after `boot_end` | the token is **linear**, not affine — it cannot be copied and cannot be restored. **Exactly this is what Rust cannot do** (affine) and Verus' `tracked` cannot either |
| **structural** | the code is **no longer there** afterwards | `boot_end` consumes the token **and** unmaps the `boot` code section — one event, not two. A stray jump there faults |
| **checkable** | the claim is falsifiable | probe after boot at a `.boot` address: **must** fault. That is `falsifier`, and without it "it is gone" would be a claim |

**That it is both levels is the point.** Static alone would mean "no caller" — and our own
register knows the counter-probe: **trap 47**, a kill switch for a safety property gets set and
never taken back. A property that hangs on nobody calling a function is a request. One whose code
is **unmapped** is an assurance.

- [ ] **This point is NOT derived from the base rate** — it comes from the requirement. The 100
      traps contain no instance "boot `unsafe` used later"; the closest relative is trap 47.
      **That belongs said**, otherwise a demanded property looks like a measured one.

---

---

## Race freedom — to be planned now, or never

**Data races fall out of M2 + M3** (ownership and access rights). That is the solved part, and
Rust can do it today.

**Protocol races do not — and those are the expensive ones.** The evidence stands in our own
register:

> **D0 was NOT a data race.** `spawn()` enqueued, `bind_pd()` came afterwards; every access was
> properly synchronised, no Rust `unsafe`, no missing atomic. The error was that a thread became
> **reachable** before it had authority. Rate **0,018 %**, ten days of searching, and **every**
> data-race checker in the world would have kept quiet.

| Class | Example from the register | falls out of |
|---|---|---|
| **Data race** | unprotected shared access | M2 + M3 — solved, in Rust too |
| **Visibility before completion** | **D0** (runnable before `bind_pd`) | **M2**, if the phase is a **linear value**: `Parked` → `admit`. That is exactly how D0 was actually fixed |
| **Lost wakeup** | **Z24** (one bit for four reasons) | **M2**: the waker consumes **exactly its** reason; enqueueing happens only on an empty set |
| **Publication without payload** | Loom did not see the payload (trap 33) | **M2**: `release` hands over a ghost token, `acquire` takes it |
| **Progress / starvation** | **D8** (exhausted thread) | **not at all.** No mechanism addresses liveness — that belongs spoken out |

**Why it has to go into the design now and not later:** if phases and lock tokens are linear
values, that stands in **every signature** that touches shared state. Introduced afterwards
means: every one of those signatures changes. That is the same lesson as "a rebuild that
introduces a new state must take along every site that judges about states" — there it was 61
call sites.

---

---

## What kernel logic demands besides — and where the trust collects

"All kernel logic expressible" is a completeness demand, and it has a list. M1–M4 do **not** cover
it alone.

| What | Answer | honest about it |
|---|---|---|
| **Deliberate non-termination** (idle loop, main loop) | `divergent fn` — **spoken out**, never by accident | M4 otherwise demands a descent measure; the exception must be named, not obtained by stealth |
| **Interruptibility** | an **effect**: `masks irqs` resp. its absence. A handler is not a call — it can run between any two statements | falls out of M2 if the IRQ mask is a linear token. Trap 93 (guard over the body) is exactly that |
| **Context switch** | language primitive `switch_to(from: &mut Context, to: &Context)` with a contract over the machine state | a stack switch is expressible in **no** structured language. That is the `state` transition at machine level — and it is **emitted**, not written |
| **Privileged instructions** (`mov cr3`, `wbinvd`, `sti`, `invlpg`, `tlbi`) | an **axiom layer**: per instruction one declared effect on the machine model | **Here the trust collects, and it is irreducible.** Every axiom is an `assume` — with `falsifier` where one is drivable |
| **Code as data** (the loader) | `code` space is reachable only through a **checking gate** (signature, layout) | Caprock already does that; what is new is that the way there is the **only** one |
| **Jump tables** (syscall dispatcher) | function pointers with a complete signature, table exhaustive (D2) | — |
| **Alignment and layout** | part of the type, not of the compiler | — |

#### In addition: the items M1–M4 do not touch at all

| What | why it does not come along for free |
|---|---|
| **Concurrency** | atomics, barriers — and "the caller holds the lock", which **neither SPARK nor Rust** can express. Regions + capabilities in the type system. The largest single item |
| **Volatile/MMIO** | four flavours as in SPARK (`Async_Readers`/`Writers`, `Effective_Reads`/`Writes`). Feasible, but language core |
| **Two address axes** | `Pa` and `Iova` kept apart, arithmetic on them — `index into` generalises to that, but is not the same |
| **Build and ABI** | multiboot header, sections, alignment, ELF32 descent. Not a language topic, but it has to exist — and it cost half a day a week |
| **No runtime system** | no allocator, no panic machinery, no unwinding |
| **FFI** | for HACL\*/EverCrypt — and every FFI boundary **breaks the guarantee** |
| **Observability** | this project lives on report lines. A language in which formatting is expensive is useless here |

**The honest sum: that is a general-purpose systems language** — a second project, and the core
thesis (closed domain ⇒ specification cheap) does **not** hold for it.

### Syscalls without assembler — the showcase example has the weakest coverage

Entry is assembler today for **one** reason: the CPU hands over control in a machine state that no
high-level language assures. Without assembler four things are needed in the language core: entry
functions with a **declared register imprint**; **register-bound values**; a **calling convention
of its own** (the interrupt-frame ABI); and **`iretq`/`eret` as a language construct** — a typed
transition into a saved context, i.e. the `state` transition applied to the machine state. That is
the class of **typed assembly languages** (TAL) and no invention.

> **It does not remove the trust, it RELOCATES it** — the instruction sequence is then produced by
> the compiler instead of by the human. The gain is real nonetheless: **one implementation instead
> of 153 sites that nobody ever checks individually.**

**And here the strongest word stands at the place with the weakest coverage** — the same form as
the two overreaches in `HISTORIE.md`, therefore explicitly:

* "One implementation, **checked once**" only carries if "checked" has a **checker**.
* **The downstream prover does not reach there.** Verus proves no inline-assembler semantics and
  no register imprints; Frama-C/WP over generated C all the less.
* A TAL type system would be the checker — then **Gabbro checks itself**, and the generator is
  unverified. Circular as long as nobody verifies it.

**The durable version is therefore weaker and still a gain:** the trusted surface **shrinks** from
153 sites to one emission site. That is a reduction, not an elimination, and it has **no
downstream prover**.

> **The honest sum: M1–M4 + axiom layer + three primitives** (`divergent`, `switch_to`, checking
> gate). The axiom layer is the largest unproven surface in the whole language — larger than the
> compiler — and it is **countable**: a ratchet over the set of axioms that may only fall.

### What does NOT fall out — and therefore stands honestly beside it

| | |
|---|---|
| **Contracts** (`requires`/`ensures` over declared predicates) | needed for trap 1/2 (condition across register boundaries). With that the line has migrated, as `README.md` predicted — and **general quantifiers over arithmetic expressions still stay outside** |
| **The entry (assembler)** | M1–M4 say nothing about register imprints. **New since the goal "C + iasm": it is part of the OUTPUT**, i.e. emitted from a description instead of written per site — trusted surface **one emission site instead of 161**. It is still not proven, and it kills **0** paid-for traps |
| **Progress** (starvation, D8) | no mechanism addresses it |

---

# The library layer — what a user writes

### 1. `format` — wire formats

Pure function at a boundary: bytes in, structure **or named refusal** out.

```gabbro
format ManifestEintrag @version 3 endian little {
    program_id  : u32
    entry_len   : u32   where == sizeof(Self)
    iface       : u32
    domain      : u8    in { Trusted = 0, Hardware = 1, User = 2 }
    _pad        : [u8; 3]  reserved
    code_hash   : [u8; 32]
    selector    : GeraeteSelektor
}
```

**Generates:** reader, writer, C `struct` with fixed widths, **one code per refusal reason**.
`where` is part of the format: the reader **never** delivers a structure that violates it.

**Open:** variable lengths (the hard 20 % of every parser generator, syntax missing) · version
evolution (does v3 also read v2 — refusal or migration?) · roundtrip `read(write(x)) == x` in the
differential test.

---

### 2. `table` — tables with invariants

**Careful: a different category from `format`.** A format is a function, a table is **mutated
state**. What Gabbro generates here is an open decision — see `README`, cut (a)/(b)/(c) — and **it
decides the value of the whole folder.**

```gabbro
table CapSpace {
    kapazitaet : const 80256

    slot {
        used   : bool
        object : index into objects
        parent : option index into slot
        first_child, next_sibling : option index into slot
        gen    : u32  wrapping        -- Umlauf ist AUSGESPROCHEN, s. Konstrukt 5
    }

    invariant kind_zeigt_zurueck cost O(n * kette) runs offline:
        forall s where s.parent = Some(p) => s in chain(p.first_child, next_sibling)
}
```

**`cost` and `runs` are obligatory, not decoration.** An invariant without a cost figure is not an
audit under the core lock but an outage — `colors.rs` holds **42 ticks** today and therefore
counts as a debt item. And **incremental** checking presupposes that the checker knows the delta
that **only the mutator** knows: **whoever wants invariants in the hot path has already chosen cut
(c).**

---

### 3. `traverse` — there are no loops

"Finite" is the **weakest** promise: a loop with a step bound terminates and can still index
outside the table. That is exactly **S1a**.

```gabbro
traverse geschwister of p
    over  chain(first_child, next_sibling) in slots
    by    unvisited                  -- Kosten: s. u.
    touches reads slots
{ if it == s { found } }
```

| Clause | kills |
|---|---|
| `over` | an index **outside the set is not formulable** (S1a) |
| `by` | termination — and **cycles**, if the progress is "not yet visited" |
| `touches` | foreign write accesses; `restrict` **only at the parameter boundaries** of generated functions |

**`by unvisited` has a price, and rule 3 enforces it:** a mere step counter only terminates — a
cycle would be **cut off silently** instead of being reported as the refusal `Zyklus`, and that
would be interpretation. So bitmap (~10 KB over 80 256 slots, O(n) reset) or generation stamp per
slot. **The cost figure belongs on `by` itself:** which structure, who resets it, what the reset
costs, whether it may live under the lock.

---

### 4. `state` — permitted transitions

Names the **admissible** transitions; everything else is not formulable. The I9 window
(`used = false` at `refcount = 1`) would with that no longer be an accident of ordering but a
non-existent transition.

**And the same mechanism carries one level deeper:** `iretq`/`eret` is a **typed transition into a
saved machine state** — the same construct, applied to registers instead of to fields. That is the
reason why "syscalls without assembler" would not be a foreign body.

---

### 5. Arithmetic with precondition

`refcount -= 1` needs **no construct of its own** — that came to light while writing down the
grammar and shrank the vocabulary by one word. **M1 handles it:**

```gabbro
type Refcount = u32 in 0 .. u32::max;    -- und dann genuegt:
c.objects[obj].refcount -= 1;            -- unter 0 ist NICHT TYPISIERBAR
```

The range type **is** the precondition; an underflow leaves it and is thereby not typable. A
`decrement … requires …` that used to stand here was a keyword for something M1 can already do.
**S1b is unformulable instead of findable afterwards. A wraparound nobody spoke out is a mistake;
one that carries `wrapping` is a design** — exactly the difference between S1b and the generations
on whose deliberate wraparound `resolve` rests.

---

### 6. `assume` / `falsifier` — hardware assumptions

No formalism covers "the VT-d unit honours `TE=1`". But the assumption can be **named** and made
**testable**:

```gabbro
assume vtd_te_wirkt
    "GCMD.TE schaltet die Uebersetzung scharf; DMA ohne Kontexteintrag wird danach
     als Fault gemeldet und nicht durchgelassen."
    falsifier probe_vtd_te
```

The pattern comes from Caprock: **a guardian checks the EXISTENCE of a reason, never its TRUTH** —
which is why the identity reasons there carry a falsifier.

**And since «B40» an assumption can name its machine:** `assume <name> arch x86_64 "…"`. The
clause is optional — a timer ticks everywhere — but a statement about caches, barriers or
register semantics is a statement about **one** architecture, and until 2026-08-31 `assume`
was the only item carrying such statements that could not say so. *`entry`, `entrust`, `boot`
and an `asm` body all could.*

> **What bought the clause was a conjunction, not a gap.** `dma_kohaerent` said two things
> under one name and one falsifier: cells are coherent **and** two volatile accesses become
> visible to the device in program order. The second does not follow from the first, and on
> AArch64 it is false in the commonest DMA configuration — `volatile` in C11 emits no barrier
> against normal memory there, so a descriptor write and a following doorbell write can be
> seen out of order without a `DSB`. **Its one falsifier runs on x86 and passes.**
>
> *One green probe discharged two obligations, and nobody ever checked the second.* That is
> the same reasoning `N024` makes for `counterprobe`, one layer up.

`A005` holds the clause against the unit: an `arch` no declaration here names is an assumption
that can never be in force, and it would still stand in the artefact under *proved under
A1…An*. The count of the remaining conjunctions — **17 of 34 texts mechanically flagged,
8 judged real** — stands in `messung/ANNAHMEKONJUNKTIONEN.md`, together with the seven that
are **not** split and why that is a debt and not a decision.

**Three classes, not two** — the third must never look like the first:

| Class | means |
|---|---|
| **falsified** | probe ran and held — a **sample**, not a proof |
| **not falsifiable** | no probe possible, **with a reason** (`pprobe` reports `SKIP` under KVM as a matter of course) |
| **not run** | open |

**CPU errata are exactly assumptions that almost always hold.** A passed probe checks *this*
machine, *this* configuration, *this* moment — the same class as "0 hits in 114 runs". The gain is
real nonetheless: **assumptions become countable and ratchetable**, and a proof whose assumption
set nobody knows is a proof without reach.

- [ ] The falsifier is code like any other and needs its **own speech test**: *can it fail at
      all?*

#### The assumption set belongs IN THE PRODUCT, not only in the source

"Countable and ratchetable" so far lives only where the descriptor lies. **The consumer of the
proof therefore does not know its reach.** So the compiler emits it along — machine-readable,
beside the C:

```
bewiesen unter: vtd_te_wirkt (falsifiziert 2026-08-13)
                x2apic_zweischritt (nicht falsifizierbar: kein x2APIC unter qemu64)
                smmu_stall_model (NICHT GEFAHREN)
```

Two conditions, both from paid-for mistakes:

* **A set of names, not a number.** A ratchet over a cardinal number bites against growth, not
  against **exchange** — and exchange feels like progress while rebuilding. That is exactly how
  `IDENTITY_DEBTS` once went wrong.
* **The class stands with it.** An assumption that was not run must not look in the product like a
  falsified one; that is the third class from above, carried one level further outward.

---

### 7. Effects (`Global`/`Depends` form)

Every operation names what it reads and writes. For that there is **one measurement on the
mechanism**: in the Caprock scheduler **63 of 63** data dependencies were proved with SPARK's
`Depends`, and "the Rust code everywhere reads exactly once into a copy" went from *read* to
*proved*. **The transferability to Gabbro is thereby assumed, not measured** — SPARK checks
existing code, Gabbro generates it.

---

### Appendix: `reason` — rule 3, syntactically

Not an eighth construct but "refuse, never interpret" in notation. It stands here because the
domain table carries "enumeration with refusal" as a pattern of its own.

```gabbro
reason MangelGrund {
    Keiner        = 0  "keine Ressource -- der Fehlschlag lag nicht an einem Vorrat"
    KernelStack   = 2  "EL0-Kernel-Stack"
    Seitentabelle = 6  "Speicher fuer eine Seitentabelle"
    GuardTabelle  = 13 "aufgeteilte Seitentabelle fuer die Guard-Page"

    exhaustive                 -- kein `_ => unbekannt`
}
```

`exhaustive` means: the generated C `switch` has **no** `default`, and a new value breaks
compilation. An enumeration with a catch-all branch accumulates unchecked values — the same trap
as a manifest field that is never redeemed and on the day of redemption carries nothing but wrong
values.

---

---

## The generator also emits the ANNOTATIONS — and that is a channel of its own

In this architecture the unverified generator outputs not only code but also the contracts the
prover checks. A generator that accidentally emits **weakened** contracts delivers a **green proof
over a weaker statement** — literally "a proof that proves the wished-for form".

| Mutation in the generator | who catches it |
|---|---|
| **Code** weakened, contract stays | the downstream **proof** falls |
| **Contract** weakened, code stays | proof stays green — only a **mutation probe on the annotation emission** |
| **both** weakened consistently | **no proof** — only the **differential test against the handwritten version** |

**Every construct below must therefore bring two things:** its emission *and* the mutation showing
that the emission gates. A construct without that mutation is a green line that gates nothing —
the same class as a negative test over a function nobody calls.

---


---

# Part I — The specification

## SPECIFICATION — Gabbro, complete

**Third version of the surface, first complete specification.** This document fixes syntax and the
load-bearing parts behind it (type rules, proof architecture, C lowering) so that a kernel,
drivers and programs — namely Caprock — are **fully** writable in Gabbro. It **decides** the nine
open design questions from `SYNTAX.md` and discharges the **19 hanging plumbing obligations in 11
classes** from `MESSUNGEN.md` with one construct each.

> **ENTERED 2026-08-14.** The grammar in [`SYNTAX.md`](SYNTAX.md) has been pulled up to this
> specification — **112 rules, 0 open, every one reachable from `program`, 170 terminals against
> 170 vocabulary words**, guardian green. **One correction while entering:** `obligation` was
> counted as the thirteenth word but is **not a source word** — it stands in the manifest, i.e. in
> the product. Twelve.

As of 2026-08-14. **No compiler reads this.** Accepting this document is not agreement but the
**repetition of the 74-obligation measurement** against this version: hanging plumbing must fall
from 19 to 0, otherwise the specification is refuted at the remaining sites.

---

### 0. The promise — and the non-promise

**Gabbro proves everything except logic.**

| | who | how |
|---|---|---|
| **Plumbing** — index, overflow, alias, frame, lock, race, termination, phase, leafness, publication | **Gabbro itself** | type rules M1–M4 and generated schemes. **No SMT, no solver, no heuristic** — "it compiles" is a function of the source, not of solver luck |
| **Logic** — *this* function does *the right thing* (`ensures` beyond the construction) | **the programmer**, in every language | Gabbro **emits** every open logic obligation into a machine-readable **obligation manifest** (§15). Nothing is silently lost |
| **Plumbing carried by logic** (third class, §8.3) | mixed | falls by construction, **but is booked as logic**, because its basis is a logic invariant |

The promise is **relative**: *memory-safe under A1…An* — the assumption set (axiom layer §12)
stands **in the product**, not in a footnote. The checker is **unverified**; the trust sits at
three named places: checker, syntax-directed lowering, one `iasm` emission site.

---

### 1. Principle

Gabbro is **C without its holes, plus two things**: range types (M1) and linear values, ghost ones
too (M2). Plus address spaces and rights on the pointer (M3), no unchecked indexing and no
undescribed loop (M4), opaque new types without implicit conversion (D1), complete layouts without
a catch-all branch (D2). Everything else is a **restriction** of C, not an extension.

The five decisions **E1–E5** hold unchanged: English keywords with German running text;
statement-oriented, assignment is not an expression; nothing is implicit; contracts before the
body in a fixed order; every declaration complete at exactly one place.

---

### 2. Lexis and vocabulary

Lexis unchanged (identifiers, numbers with `_`, `--` comments, ~~no floating point in the
core~~ **floating-point literals since «F1» (2026-08-18)**, strings only in `claim`, `reason`,
`assume`, `section`, `unfalsifiable`).

**The vocabulary is closed. This specification adds exactly twelve source words** — each one at an
obligation from the measurement, none from stock:

```
  embeds scale aligned          -- §5.3: PTE ist Zeiger UND Bitfeld (Wurzelproblem)
  walk levels leaf mappings     -- §5.4/§6: Seitentabellen und die achte Domäne
  held                          -- §11.2: Sperrhaltezeit als Zahl (repariert per_pass)
  next                          -- §8: continue; leave gab es schon
  accumulates merge             -- §11.4: Sammelwerte ohne CAS-Schleife
  -- obligation                 -- §15: KEIN Quellwort, es steht im MANIFEST (Erzeugnis)
  extern                        -- §14.4: C-Randfunktionen mit Vertrag
```

**Nothing** is struck; every word of the second version keeps its meaning, three get sharper
obligations (`forever`, `publishes`, `breaking`).

---

### 3. Types and ranges — M1, now with three flow rules

#### 3.1 Declarations (unchanged)

```ebnf
typedecl = [ "pub" ] [ "opaque" ] [ "linear" [ "ghost" ] ] [ "tagged" ]
           "type" ident [ "(" typelist ")" ] [ "=" typeexpr ] ";" ;
intty    = ( "u8"|"u16"|"u32"|"u64"|"i8"|"i16"|"i32"|"i64" ) [ "in" range ] ;
range    = expr ".." expr | expr "..<" expr ;
```

Every operation must stay inside the range of its result type; if `a + b` does not fit the target,
that is a **compile error, not a runtime check**. Division and remainder demand a denominator
whose range excludes zero.

#### 3.2 The three flow rules — closed, local, predictable

The counter-measurement (`MESSUNGEN.md`, revised: **255 subtractions, 102 flow-sensitive**) showed
that *one* rule is not enough and that `narrow` alone would become a ritual. There are now
**exactly three** rules. They are **syntax-directed, without fixpoint, without solver**: the
checker keeps a **fact set** per block that grows only at the three named places and **dies on
every write to a participating place**. Loops carry no facts inward (the invariant of the
traversal does that, §9).

> **Exception, and it is the only one — «H2.1», 2026-08-19.** A loop carries no fact **inward**;
> it may however **generate** one. A counter that is set to a constant before a bounded
> traversal and inside the body is *only* ever the target of `n += k` with a positive constant
> `k` is bounded by the domain: at each increment site `n ≤ c + (B−1)·k`, after the loop
> `n ≤ c + B·k`.
>
> **The difference between an exception and a hole lies in the direction.** Nothing that held
> *before* the loop holds inside it — that rule is untouched. What is new is a fact the loop's
> **own shape** yields: its declared domain bound plus the form of its body. *It is the
> induction variable, and it is the one place where the loop knows something a fact set cannot
> carry there.*
>
> Five conditions, each a refusal if it is missing: the counter is a **local** scalar, set from
> a constant before the loop · inside the body it is **only** the target of `n += k`, `k` a
> positive constant · the domain has a computable bound · the traversal is **not nested** in
> another loop (otherwise `B` multiplies, and the pass **stays silent**) · nothing takes its
> address (free in Gabbro — there is no address-of on locals — and stated anyway).
>
> **Measured before it was built:** 21 traversals in the corpus, **two** with a counter in the
> body. *A rule for two sites is little; it closes the last hand-written range obligation, and
> that is the point.*

| | Rule | Example |
|---|---|---|
| **V1** | a checked **range condition** narrows the range of the checked place in the branch after it | `if x >= 1 { … }` → `x : u32 in 1..max` |
| **V2** | a checked **relation between two places** becomes a branch fact; under the fact `a >= b`, `a - b` has type `0 .. a.max − b.min`, under `a > b` type `1 .. a.max − b.min`. Comparison facts only, directly checked places only | `if a >= b { let d = a - b; }` — **54 relational sites**, of the 102 flow-sensitive ones. *Until 2026-08-20 this cell said „the 102 sites", and 102 is the whole flow-sensitive population (V1+V2+V3); the relational half of it is 54* (`MESSUNGEN.md`:370) |
| **V3** | a `match` on a `tagged` type narrows in the branch to the variant including its payload | exhaustive, no catch-all branch |

> **ZWEITE VORBEDINGUNG an V1 und V2, aufgeschrieben 2026-08-20 — und der Pruefer tat bis
> dahin das Gegenteil.** Eine Verengung traegt nur, wenn die Stelle zwischen der Pruefung und
> der Verwendung **dieselbe bleibt**. Ein Geraeteregister bleibt sie nicht: es senkt zu
> `*(volatile T *)(basis + versatz)` ab, und `volatile` IST die Aussage *„das darf sich
> zwischen zwei Lesungen aendern."*
>
> ```gabbro
> if d.ST.IDX < 8 { return T.slots[d.ST.IDX].a; }   -- ZWEI Lesungen, eine Schranke
> ```
>
> **Bis zum 2026-08-20 gab V1 hier eine Schranke, und das Programm ging mit null Fehlern
> durch.** Das erzeugte C indizierte ein Feld mit acht Plaetzen mit einem Wert, den die
> Hardware zwischen den beiden Zeilen frei setzen darf. *`PFLICHTEN.md` fuehrte «B33» als
> „die V-Regeln verengen eine Registerstelle nicht" — der Ordner beschrieb, was gelten
> SOLLTE, und niemand hat den Pruefer gefragt.*
>
> **Die Regel:** eine Stelle, die durch ein `device`-Register fuehrt, traegt **keinen** Fakt
> — weder V1 noch V2, in keiner Schreibrichtung. Der Ausweg ist keine neue Grammatik,
> sondern die gewoehnliche Form:
>
> ```gabbro
> let i = d.ST.IDX;              -- EINMAL lesen; eine lokale Bindung ist nicht fluechtig
> if i < 8 { return T.slots[i].a; }
> ```
>
> *Und weil eine Regel, die eine Form erzwingt, die der Erzeuger nicht absenkt, ein Verbot
> ohne Tuer waere:* der Erzeuger liest seither die Wortbreite aus der `device`-Deklaration ab,
> und `let i = d.ST.IDX;` senkt ab (`gift/213`, `gift/214`).

> **VORBEDINGUNG an V1 und V2, aufgeschrieben 2026-08-18 — sie war immer da und stand nirgends.**
>
> Die Verengung im `else`-Zweig setzt voraus, dass **die Negation einer Vergleichsbedingung
> selbst eine Vergleichsbedingung ist** — also eine **totale Ordnung ohne unvergleichbare
> Elemente**. Über ganzen Zahlen gibt `!(x < y)` das Faktum `x >= y`; das ist Trichotomie, und
> sie gilt dort.
>
> **Gleitkomma ist ihr erster Verletzer, nicht ihr einziger:** ist ein Operand NaN, sind *alle*
> Vergleiche falsch, und der `else`-Zweig gibt **nichts**. Vier Ausgänge statt drei. **Jeder
> partiell geordnete Träger, den die Sprache je bekäme, bräche dieselbe Maschinerie** — und
> `m1::fakten_aus(…, negiert = true)` ist genau die Stelle.
>
> *Die Regel ist damit sichtbar falsifizierbar, statt an ihrem ersten Gegenbeispiel zu
> zerbrechen.* Die praktische Folge, falls je ein solcher Träger käme, ist klein: **`else` gibt
> dort keinen Fakt, und wer Verengung will, schreibt beide Zweige positiv** —
> `if x < y … if x >= y … else /* unvergleichbar */`. **Vier Ausgänge sind schreibbar, sie sind
> nur nicht kostenlos.**

What does **not** fall under V1–V3 needs `narrow place to range else { … }` — a statement with a
named exit, not a proof line. **The yardstick stays:** if `narrow` grows beyond the remainder of
the counter-measurement (**≤ 24 sites** in today's tree), the rule set has been chosen too small
and *that* is the refutation — not a further growth of rules in silence.

#### 3.3 New types and sums (unchanged)

`opaque` forbids conversion in both directions; `tagged` is the sum type and lowers to a C union
with a tag; `match` over it is exhaustive.

---

### 4. Linear and ghost values — M2

```gabbro
linear type Parked;                      -- echte Ressource: Bytes im Erzeugnis
linear ghost type Held(Lock);            -- Beleg: vor der Codeerzeugung gelöscht
linear ghost type BootPhase;
linear ghost type MayWrite(ThreadId, Pa);
linear ghost type Duty(check);
linear ghost type Member(domain);        -- Zugehörigkeitszeuge, nur erzeugt (§9.2)
```

**Linear means linear, not affine:** a linear value is consumed exactly once. Dropping it is a
compile error; `leave`/`return` from a scope holding linear values demands that they be named
(`leaves`). There is no copying (E3). Ghost values have **no lowering**: no byte, no heap, no
cycle.

> **2026-08-20: and a `linear type T;` WITHOUT a body is a token.** The first line above says
> *"real resource: bytes in the product"* — but a declaration with no fields never says how
> many. It lowers to one byte:
>
> ```c
> typedef struct { uint8_t nichts; } Angemeldet;
> ```
>
> **Nothing is guessed here.** This emitter refuses wherever several answers are plausible; a
> token with no fields does not have several — it has no fields. That a value in C needs an
> address and a size is a statement about C. *One byte is not the smallest plausible choice
> but the only one.*
>
> The ghost is erased, the token is not — **that is the whole difference between the two
> words**, and an emitter that lowered both the same way would make `ghost` decorative.

**Who may produce witnesses is closed:** `Held` only the `locks` block, `Member` only the
compiler's domain enumeration, `MayWrite` only the generated cap resolution, `Duty` only `check`,
`BootPhase` only the entry path. A hand-built token is thereby a **type error** — that is the
result measured against Verus ("self-built token: type error"), as a language rule.

---

### 5. Pointers, address spaces, embedded pointers — M3

#### 5.1 Spaces and rights (unchanged)

```ebnf
ptrty  = "ptr" "<" space "," rights ">" typeexpr ;
space  = "normal" | "mmio" | "dma" | "code" | "boot" | ident ;
rights = right { "+" right } ;
right  = "r" | "w" | "rw" | "x" | "own" [ "@" ident ] ;
```

The barrier follows from the **space**: a store to `dma` emits the publication barrier of the
target architecture, an `mmio` access is volatile and not reorderable. `own` is the ownership
right (release), which makes `Finalized` expressible without lifetimes.

> **`own` is the RELEASE OPERATION, not a note on the signature — decided 2026-08-20 (stage 5).**
>
> The question had a name and a price: `restrict.alleinzugriff` proves alias freedom under
> **H2a** (at most one pointer parameter per carrier type), and the one figure C really cannot
> know — **2,85** — sits at the case H2a excludes: *two* pointers of the same type. They may
> both carry `restrict` **iff two owning pointers cannot denote the same region**, and that is
> exactly what "release" means: the caller gives it up and keeps nothing.
>
> **The other reading was never viable.** A signature note is a clause without a reader, and
> this folder treats that as a defect — `own` was a synonym for `rw` until 2026-08-19, when
> `R004` gave it its first bite.
>
> **And the price is stated, not hidden:** under the release reading a caller may not use an
> owning place after passing it on. The residual assumption is named too — owning pointers
> that come from `extern fn` results are *foreign producers*, and `gabbro zeugnis` counts them
> as trust surface.
>
> *What is decided is not therefore built.* The corpus has **one** function with two pointers
> of the same carrier (`beispiele/07::wechseln`), and it carries no `own`. **Rule A** — no
> construct without a program that needed it — so `darf_restrict` keeps refusing, and the
> template register carries the premise with this address instead of a missing decision.

#### 5.2 Pointer arithmetic has exactly one form

`place[expr]` with an M1-bounded index, and `offset_into` in formats. Otherwise none.

#### 5.3 `embeds` — **the root problem: a PTE is pointer and bitfield at once**

```ebnf
field    = ident ":" fieldty [ "@" bitpos ] [ "offset_into" ident ]
           [ "where" pred ] [ "reserved" ] "," ;
fieldty  = typeexpr
         | typeexpr "embeds" "[" int ":" int "]" [ "scale" constexpr ] ;
```

An `embeds` field **carries a typed value inside a bit range**, scaled:

```gabbro
format Pte endian little {
    present  : bool @0,
    writable : bool @1,
    user     : bool @2,
    nx       : bool @63,
    pfn      : Pa embeds [51:12] scale 4096 where aligned(it, 4096),
}
```

Reading `pfn` delivers `Pa` (bits `[51:12] << 12`); writing demands the `where` condition —
`aligned(it, 4096)` is a built-in predicate over M1 (the low bits of the range are zero), **no
solver**. The lowering is mask-and-shift, computed at compile time. With that the 13-multi-bit-
field class from `vtd.rs` **and** the PTE class are **one** construct.

#### 5.4 `walk` — self-describing, multi-level tables

```ebnf
walkdecl = "walk" ident "levels" constexpr "{"
             "node" ":" array ","
             "down" ":" ident "when" pred ","
             "leaf" ":" pred ","
             { invariant }
           "}" ;
```

```gabbro
walk PageTable levels 4 {
    node : [Pte; 512],
    down : pfn when it.present && !leaf(it),
    leaf : it.present && (level == 0 || it.large),

    invariant wx_disjoint cost O(n) runs online :
        forall m in mappings of Self: !(m.writable && !m.nx);
}
```

`down` names the **embedded** field along which the descent goes; `levels` is a constant, so the
depth is M1-bounded and **the termination of the descent falls by construction** — no variant, no
lemma. From the declaration the compiler generates the enumeration, the traversal, the induction
scheme (§6) — and the mutation operations in cut (c) (§10.2).

---

### 6. Predicates — the line, with the eighth domain

```ebnf
quant  = ( "forall" | "exists" ) ident "in" domain ":" pred ;
domain = "slots" "of" place | "chain" "(" ident "," ident ")" "in" place
       | "descendants" "of" place | "queue" place | "fields" "of" path
       | "elems" "of" place | "threads"
       | "mappings" "of" place ;              (* NEU — erzeugt aus einer walk-Deklaration *)
```

**Eight domains, closed. Nesting at most two. `old(place)` only in `ensures`.**

**A domain binds the ADDRESS of an entry** — `slots of`, `elems of`, `descendants of`,
`ancestors of`, `queue` all bind an index or handle, and the element is `p[i]`. The name says
what is ranged over, not what the variable holds *(decided 2026-08-20; from an index one gets
the element, from an element not the index)*. **`mappings of` is the one exception** and the
next paragraph says why.

`mappings of` quantifies over all reachable leaf entries of a `walk` structure, including virtual
address and level — with that **W^X over the two-level page table** (`mmu.rs:1283`, the one
unformulable obligation of the measurement) becomes formulable. The domain is **generated from the
declaration**, not user-defined: the line stands.

> **And the number is `node length ^ levels`, not `levels × node length`** *(corrected
> 2026-08-20)*. For four levels of 512 entries that is **68 719 476 736**, not 2 048 — seven
> orders of magnitude, and the cost pass carried the smaller figure for three days. *It counted
> one descent PATH and called it the domain.*
>
> **The consequence is carried, not defined away:** a RUN-TIME traversal over `mappings of`
> can therefore hold no cost promise. That is true, and the other reading would have been a
> promise nobody keeps. The set reading is the one the domain was built for — **W^X is a
> statement about the set; over a path it is meaningless.**

Unchanged: no user-defined quantifier domains, no recursion in `spec fn`, no handwritten lemmas.
The one exception remains `by induction over <domain>` — it **names** the generated scheme
(predictability), it does not prove. If a property falls out of the eight domains, it is **not
formulable** — it migrates as a named `obligation` into the manifest (§15), not into a comment.

---

### 7. Functions, contracts, costs — E4

```ebnf
fndecl = [ "pub" ] [ "spec" | "impl" | "raw" | "divergent" | "prim" | "extern" ]
         "fn" ident "(" [ params ] ")" [ "->" typeexpr ]
         [ "requires"  predlist ]
         [ "ensures"   predlist ]
         [ "maintains" identlist ]
         [ "effects"   "{" efflist "}" ]        (* derived where a body settles it; demanded where none stands *)
         [ "costs"     "<=" expr "ops" ]        (* never demanded; `gabbro kosten` counts the body *)
         [ "by"        inductlist ]
         [ "section" string ] [ "arch" ident ] [ "when" constexpr ]
         ( block | "=" pred ";" | ";" ) ;
```

**`effects` is not fail-open.** Where the body settles the hull, an omitted
clause is derived and checked exactly like a written one; whoever touches
nothing derives `effects { pure }`. A written clause is the enforced bound:
the body must stay inside it. Where nothing settles — no body (`extern`,
`prim`), an unresolvable edge, a callee promising more than the deeds cover —
the omission is refused with the reason (`N305`). An omitted `costs` is never
refused: it is not a promise, so there is nothing to hold — what the body
costs is shown by `gabbro kosten`, and a written bound stays the bound the
body is held against (`K001`). Neither omission changes the meaning of a
program that writes its clauses.

**`costs` counts operations, and the unit is defined:** 1 op = one Gabbro primitive (assignment,
arithmetic operation, load, store; a call counts the declared `costs` of the callee; a traversal
counts body costs × domain bound; branches count the maximum). That is a **property of the
program** (D10), computed statically, not a time measurement — and it is the quantity in which
`per_pass`, `held` and `bounded` speak. There are no cycles in the language. A call through a
`syscall` counts its declared `costs` on top of the dispatch step (`1 + fa`, never zero); without
a countable promise the declaration is refused (`N322`).

> **Two sharpenings, both fallen due on 2026-08-14 while building pass 9 — and both are statements
> about the MODEL, not about the checker:**
>
> 1. **The four primitives are conclusive.** An `if`, a `match`, a `return`, a `leave` cost
>    **nothing** — they are none of the four. The *condition* of a branch costs, the branch does
>    not. And **what is fixed at compile time costs nothing at run time**: `GRENZE`, `4096`,
>    `NSLOTS * 8` are not loads.
> 2. **What stands after a branch that ALWAYS leaves lies on the other path.** With
>    `if x { return … }` followed by further code there are two paths, not one sum. Without this
>    rule every early return pays twice, and the number measures a path no run takes. *It is the
>    same syntactic question that M1 poses for the V1 negation.*
>
> **The first run of the pass checked both sides and found both wrong once:** first the pass
> computed too much (the sharpenings were missing), then three written `costs` numbers turned out
> to be guessed — among them a traversal over a whole table that costs **831 488** instead of the
> declared 4 096 ops. Both stand in [`MESSUNGEN.md`](MESSUNGEN.md).

---

### 8. Statements

#### 8.1 Stock

`let` (with `else (e) { … }` as the only error propagation: the branch diverges or returns),
assignment (not an expression), `if`, exhaustive `match`, `narrow … else`, `locks` block,
`return`.

##### «C3a», 2026-08-20: **a function that can fail says so — `-> T or R`**

`let x = f() else (e) { … }` stood in the grammar from the beginning and could not be
lowered. The emitter named the reason and refused:

> *"`-> u32` carries no error channel, and nothing binds a function to a `reason`. What `e`
> holds and how a call reports failure would both have to be invented here."*

**Both questions are answered at the declaration of the callee**, which is the one place an
answer can be checked:

```gabbro
reason HolFehler { Leer = 1 "die Quelle war leer"  Kaputt = 2 "unlesbar"  exhaustive }

extern fn hol() -> u32 or HolFehler effects { pure } costs <= 1 ops;
```

*No new word:* `or` is already in the vocabulary. The lowering is

```c
bool hol(uint32_t *_wert, HolFehler *_grund);
```

and three decisions sit in that line, each with a reason and none of them convenience:

1. **Success is the return value, not the value.** A sentinel inside the result would narrow
   the type — `option index into T` already does exactly that, and *twice the same thing in
   two ways is W7*.
2. **The reason leaves through its own out-parameter.** `reason` values are given by the
   human (this document's own example carries `Keiner = 0`), so there is no free word for
   "no error"; reserving one would retroactively constrain every existing declaration.
3. **`bool`, not `int`.** There are exactly two exits, and the grammar says no more.

Two rules hold the statement together, and each is the other's counter-probe — **both in the
CHECKER, not only in the emitter** («B24»: a rule that lives only on the emitter surface is
one most programs never touch):

* **`N028`** — a `let … else` over a function that declares no `or R`. The branch could never
  run and `e` names nothing. *The same class as `gates` without a gate function (`N020`) and
  `on_exceeded` without a name (`S007`).*
* **`N029`** — a call to a function that CAN fail, standing outside a `let … else`. The reason
  falls on the floor unseen — which is precisely the hidden control flow this construct exists
  to prevent.
* **`N034`** — a body of ITS OWN that declares `or R` and never returns a reason. The third
  tooth, and it was missing because until 2026-08-21 there was no way to write one:
  *every `-> T or R` in the corpus stood at an `extern fn`.* The emitter wrote `(void)_grund;`
  with the finding as a comment beside it; **the hole stood in the generated C and in no
  refusal.**

#### 8.1.1 The PRODUCER — `return R::F;` *(Stufe 7, 2026-08-21)*

`primary` knew no production for a reason value, so **no Gabbro function ever produced one**.
The channel had a declaration and no way to write it — «B9» a second time, and the movement
K100's second gate stands against: a promise with no redeemer.

```gabbro
impl fn platz_freigeben(g : ptr<normal, rw> Griffe, s : Platznr) -> Zaehler or Buchfehler … {
    if !g.slots[s].belegt { return Buchfehler::Unbelegt; }
    narrow g.slots[s].zaehler to 1 .. HOECHST else { return Buchfehler::Buchfuehrung; }
    …
}
```

**No new word and no new statement.** `return R::F;` is the failure exit, because a reason
value can never have the success type — that is the condition under which the saving is
allowed, and where it did not hold this folder pays for a silent misread instead.

```c
bool platz_freigeben(Griffe *restrict g, uint32_t s, uint32_t *_wert, Buchfehler *_grund) {
    if (!(g->slots[s].belegt)) { *_grund = Buchfehler_Unbelegt; return false; }
    …
    *_wert = g->slots[s].zaehler; return true;
}
```

**A reason goes through exactly two doors**, and both are checked:

| door | rule |
|---|---|
| `return` in a function that declares `or R` | **`M122`** — a different `R`, or none, is a refusal |
| a comparison against a reason of the SAME declaration | **`M124`** — everything else; the number in a `reason` line is there so a REPORT can name it |

And the consumer side got what it never had: **`e` carries a type.** Until 2026-08-21
`fehlername` stood in exactly ONE file of the checker — in the *emitter* — so `match e { … }`
fell with `M119`, *„`e` is declared nowhere"*. A clause with no reader. Over a reason a
`match` is now closed the same way `D005` closes one over a `tagged type`: **`M123`**.

> *That last rule closes a hole the producer itself opened.* Before Stufe 7 the question of
> which arms a `match e` must name was never due, because `e` did not exist. With the type it
> became due — and stood open for one run.

#### 8.2 `leave` and `next`

```ebnf
leavestmt = "leave" ident ";" ;
nextstmt  = "next"  ident ";" ;
```

Both target a **named** loop form. `leave` out of `forever` is permitted and is the orderly
shutdown: the `leaves` clause names the linear values that leave through the exit. There is no
`break`/`continue` without a name — with nested loops the target would otherwise be convention
instead of syntax.

#### 8.3 `breaking` — with a booking rule

```ebnf
breakstmt = "breaking" identlist block ;
```

Inside the block the invariant is **not available as a premise**: functions with `requires I` or
`maintains I` are not callable (effect-checked). At the end of the block I must be restored —
**by construction only if the block closes with a generated operation of the structure**;
otherwise the restoration is an **`obligation`** in the manifest. That is the third class
"plumbing carried by logic", as a rule: *if a plumbing obligation falls only via a logic
invariant, it is booked as logic.* Without this rule "falls by construction" becomes the
convenient booking — the `depleted_count` dispute is thereby decided.

##### 8.3.1 `I` has to BE something — `D013`, 2026-08-28

**Three promises hang on that name, and until 2026-08-28 none of them had a subject.** The
name was parsed, collected by `kbedingung.rs`, printed in its report and refused by `D009` —
and never looked up. Measured through the unchanged checker (W24):

```gabbro
breaking gibt_es_gar_nicht { e.slots[kern].caller = 1; }
-- 4 Items, 0 Fehler, 0 Hinweise
```

`D013` requires `I` to name an invariant this unit really declares — of a `table`, of a
`group`, of a `walk`, or a `spec fn`. **That is exactly the list `maintains` accepts**
(`m1.rs::sammle_spezifikationen`); a second list for the same notion is where the two clauses
would drift apart. *This is the fifth member of a class the folder already names — a clause
whose subject stands nowhere: `M133`, `N033`, `S007`, `N020`.*

> **And the missing rule and a WRONG one had one cause.** With no resolution `D009` attributed
> a break to *every* carrier declaring `ops`: a `breaking` on an invariant of `Endpoint`
> printed ``[D009] `breaking` lets `paarig in oeffnen` rest, and `Objekte` declares `ops` `` —
> about a table the block never touched. Narrowed the same day, and it was only possible once
> the name resolved.

**What `D013` does NOT check** is everything else §8.3 promises: that the invariant really
rests here, that the block restores it, that `requires I`/`maintains I` are blocked inside it.
*A `breaking` on the wrong-but-existing invariant still passes.* First clean corpus site:
`beispiele/53-zwei-orte.gab` — until that file `breaking` had **zero** clean sites and one
poison one. The weighing against the other candidate form stands in `messung/ZWEI-ORTE.md`.

---

### 9. Loops — three forms, all repaired

#### 9.1 Grammar

```ebnf
loopform = traverse | retry | forever ;

traverse = "traverse" ident [ "of" expr ]
           "over" domain
           "by" ( "unvisited" | "consuming" ) [ "decreases" expr ]
           [ "touches" efflist ]
           block ;

retry    = "retry" [ ident ] [ "until" pred ]
           "bounded" expr "ops"
           [ "progress" ident ]
           "on_exceeded" ident
           [ "effects" "{" efflist "}" ]
           block ;

forever  = "forever" [ ident ]
           "per_pass" "bounded" expr "ops"
           "on_exceeded" ident                   (* JETZT PFLICHT — D11 *)
           "effects" "{" efflist "}"
           [ "progress" ident ]
           [ "leaves" identlist ]
           block ;
```

#### 9.2 `by consuming` — with the witness order the fourth paper attempt demanded

The loop variable is a `linear ghost Member(domain)` that the body **must** consume (M2). **The
order is part of the domain, not of the call:** a domain that offers `by consuming` delivers its
witnesses in the **well-founded order generated by the structure** — for `descendants of` that is
*depth-descending* (children before parents), for `chain` the chain order, for `mappings of`
leaf-upward. The witness thereby carries not only membership but the assurance *"all successors in
the order are already consumed"* — and **that is exactly leafness at the moment of consumption**.
`delete_leaf(it)` demands this assurance as `requires`; it comes from the order, not from a
runtime check.

> **«B41b», 2026-08-20: the EDGE is now named, once, at the table.** The emitter raised the
> finding itself while lowering `descendants of c.slots[s]`: the domain does not say along
> which field it walks. `CapSpace` carries four candidates — `parent`, `first_child`,
> `next_sibling`, `prev_sibling` — and `chain(a, b) in <place>` shows the grammar has long
> known how to name one. *That was an asymmetry in the grammar, not missing emitter code.*
>
> ```gabbro
> table Kappenraum count NSLOTS {
>     tree { parent elter, child erstes_kind, sibling naechstes }
>     slot { … }
> }
> ```
>
> **The symmetry is established the other way round than `chain` does it.** `chain` names its
> fields at the traversal; a tree is traversed at many sites, and two sites could name
> different fields without anyone comparing them. The edge is a statement about the
> STRUCTURE — so it stands once, is checked once (`D006`–`D008`: the field exists, it is
> `option index into Self`, it points at its own table), and holds for every domain that
> needs it.
>
> **A subset is an answer.** `beispiele/18` declares only `parent`: its device topology knows
> no descent, and `descendants of` over it is then a named refusal, not a missing piece of
> emitter.
>
> *The four words `tree`, `parent`, `child`, `sibling` are CONTEXTUAL* — everywhere else,
> including as a slot field name, they remain identifiers.
>
> **And this paragraph's order is what makes the lowering possible.** *Depth-descending,
> children before parents* is post-order, and the emitted walk carries no stack — `child`
> down, `sibling` across, `parent` back. **That is why `tree` names all three and not only
> the two that go downwards:** a stack as deep as the tree is high would be `count` entries
> of kernel stack. Every edge is read BEFORE the body runs, because `by consuming` may
> destroy the node it is handed.

**Booking, honestly:** the correspondence "witness set empty ⇒ set empty" and the order
preservation under the generated mutation fall due **once per construct in the generator's
template** — amortised, not eliminated. The template belongs to the trust-critical surface (§0)
and stands in the obligation manifest as a closed item with a site.

#### 9.3 `forever` — lock waiting time, decided

**Lock waiting time does not count into `per_pass` — and must nevertheless not be unbounded.** The
resolution is compositional rather than inside the loop construct:

1. Every lock declares `held <= K ops` (§11.2). A `locks` block whose body costs exceed K is a
   compile error.
2. In `forever`/`retry` only a lock **with** a `held` figure is takeable. The ticket spinlock
   without a bound (`caprock-sync:821`) is thereby **not writable** in a service loop — the
   construct discharges the obligation instead of asserting it.
3. `per_pass bounded` counts the pass's own ops; the bound **may depend on pass inputs**
   (`per_pass bounded 64 + 12 * lenof(msg) ops`) — with that Ed25519 over a manifest is honestly
   describable instead of wrongly bounded.
4. The latency statement per waiting site is thereby derivable (higher-ranked holders hold ≤ the
   sum of their `held`) and is emitted as a number into the product — a **derived** quantity that
   nobody runs parallel to the truth.
5. **For locks taken shared, point 1 holds with a different number** (§11.2.1): `shared held`
   instead of `held`, checked as `K004`. The reason is no formality — point 4 computes with the
   hold time of *one* holder, and on the shared side the load-bearing quantity is the **writer
   waiting time under reader pressure**. *Until 2026-08-14 the cost pass computed only the
   exclusive case, and the latency formula with it* (`MESSUNGEN.md`, side finding N3).

`progress` stays: it names **who** ends the loop — an assumption with a falsifier; the watchdog is
the falsifier.

---

### 10. `format`, `table`, `walk` — the library layer with generated mutations

#### 10.1 `format` (stock, plus `embeds`)

Fixed set: fields with ranges, `where` conditions, `offset_into` against `lenof(Self)`, `endian`,
versions with **refusal instead of migration** (measured: 0 of 11 format changes were migrations).
The reader checks the buffer length **once at entry**; everything after that is proven accesses
without a runtime check. The writer is the inverse; `read(write(x)) == x` is obligatory in the
differential test.

#### 10.2 `table` — cut (c) is fixed

```ebnf
table    = "table" ident "{" { constdecl | slotdecl | invariant | opdecl } "}" ;
opdecl   = "ops" identlist ";" ;
```

`ops insert, remove, relabel, delete_leaf;` names the **generated mutations**. Per operation the
generator shows **once over the declaration** that every `online` invariant is preserved — not per
call site. A handwritten mutation on a `table` with `ops` is a compile error; a `table`
**without** `ops` is pure description with a generated checker (cut (a)) — both are the same
syntax, the difference is one line and therefore **visibly chosen** rather than creeping.

Invariants carry `cost O(…)` and `runs online | offline` (stock): `online` runs in the generated
mutation path and must fit into its `costs`; `offline` is diagnostics and runs in the check
harness.

##### 10.2.1 `breaking` is not a write right — the answer, stated (2026-08-20)

**`breaking I { … }` names the region in which invariant `I` rests** (§7). The question the
folder carried open was what that does to a carrier whose field says `by ops`, and the booking
answered it from reading the code: *a `breaking` opens the carrier again, instead of being a
compile error.* **Measured, it is the other way round.**

| | |
|---|---|
| a hand mutation inside a `breaking` block, table with `ops` | **`D001`** — the same compile error as outside it |
| the same on a field with `by ops` | **`D002` as well** — both bolts hold |
| what `breaking` *does* change | the **measurement**: the carrier drops out of the count *„K holds"* |

The descent is the reason: the K condition reads every sub-block of a statement, and a `breaking`
block is one. **What `breaking` moves is the K condition of the measurement protocol** — *„it
holds only if ALL mutations of the carrier are generated"* — and a region in which a statement
rests is exactly the region the argument *„the generator shows it once"* does not cover.

> **Two questions the folder had pulled together.** `breaking` says *„a statement rests here"*;
> `by ops` says *„this field belongs to the generated operations"*. If the first were a permission
> for the second, `by ops` would be a suggestion with a back door — and the whole K condition
> would rest on a clause anyone can step around by naming an invariant.

*Site: `beispiele/gift/226-breaking-oeffnet-den-traeger-nicht.gab`. Until that file, `breaking`
had **zero** corpus sites — a sentence about a construct at which nothing ever fell is a guess.*

#### 10.3 `device` (stock)

`class r|w|rw|w1c|rc`, `fields` with bit ranges, `bank … at expr stride … count …` (M1-bounded),
`mirrors … from …` once per device, `transition` over the **whole written word** including
`keeping` — RMW on `w` registers stays unformulable. New: `transition … publishes { place }`
(§11.3) for device publication.

---

### 11. Concurrency — four repairs

#### 11.1 `atomic` — declaration lean, payload at the store

```ebnf
atomicdecl = [ "pub" ] "atomic" ident ":" typeexpr
             [ "acquire" | "release" | "seq" | "relaxed" ] ";" ;
```

#### 11.2 `lock` — with hold time

```ebnf
lockdecl = "lock" ident "protects" "{" placelist "}"
           "rank" constexpr [ "held" "<=" constexpr "ops" ]
           [ "shared" "held" "<=" constexpr "ops" ] [ "masks" ident ] ";" ;
lockstmt = "locks" [ "shared" ] place block ;
```

`rank`: taking demands a strictly smaller rank (stock). `held` is the declared hold time in ops;
every `locks` block is checked against it (`K002`). Without `held` the lock is not takeable in
service loops (§9.3).

**And `constexpr` in that grammar line is now enforced (`K010`, 2026-08-20).** The word stood
there from the day the field existed and the parser took any expression — *a grammar promise in a
comment is not one*. Measured before the rule: `held <= 40 * eintraege ops` over a block holding
the lock for five operations gave **0 errors**, because a bound that is not constant fell out of
the pass's map, and with the map fell `K002`. *A promise that switches off the guardian it was
meant to feed is more expensive than none.*

> **The cost class tolerates symbols, the lock class does not, and that is not a convenience.**
> `costs <= 40 * n` is compared at the **smallest** assignment — there the promise is smallest and
> must hold exactly there (§7). `held` is a **latency** statement: how long another core waits at
> most. Latency lives at the **largest** assignment, and a symbol does not have one. A symbolic
> `held` is not a bound, it is a lock held for an unbounded time — and `rank`/`held`/`K002` are
> empty behind it.

##### 11.2.1 `locks shared` — the shared taking

**The first construct that came out of a measurement instead of out of a design.** The paper test
of 2026-08-14 (`MESSUNGEN.md`) was meant to confirm the candidate `locks ordered` and killed it
instead — zero test cases. In the process what stood on no list came to light: **the hottest lock
of a real kernel is a reader-writer lock, and the hot path is the shared side** — 33 reader
takings against 44 writer takings. `lock` and `locks` were conceived as exclusive; cap resolution,
the most-travelled path, was not writable.

The assurance is **a single one, and it is mechanical**:

> **Holding shared means: reading the protected places, not writing them.**

`protects { … }` names the places, the body names its write targets — the same comparison as
`E006`, no new proof concept. *That is the criterion `abi { … }` and `locks ordered` failed, and
this construct passes it.*

| Code | Refusal |
|---|---|
| `H001` | Write to a protected place under shared taking. **The load-bearing rule.** |
| `H002` | Taken shared without `shared held <= … ops` — see the number below. |
| `H003` | Upgrade: taking exclusively while the same lock is held shared. On a spinlock a deadlock, not a style error. |
| `H004` | `shared held` declared, but nowhere taken shared — *an assurance without a site at which it falls.* |
| `E007` | Declared **shared**, taken **exclusively**. The dangerous direction. |
| `H005` | Call of a function with `requires Held(…)` from a shared block. **Interim rule**, see below. |

**The direction is not symmetrical, and that is the core of `E007`.** Declaring exclusive covers
the shared taking — whoever holds more than he promises errs to the safe side. The other way round
it is a lie: the caller reads `locks shared`, computes with concurrency that does not exist, **and
bases his latency calculation on it**.

**The call boundary, and why a deliberately too-strict rule stands there.** `H001` sees only what
the block writes **itself**. If a shared block calls a function with `requires Held(N)`, **the
callee** writes with exclusive entitlement while **the caller** holds only shared — the same
violation, one frame further out. Without a rule the boundary would be not merely unchecked but
**permeable**: the witness exists, its strength is not checked.

The right check needs the **call graph** — the same one on which the call effects in pass 8
already hang today. Until then this holds:

> **A shared block calls no function with `requires Held(…)`. Full stop.**

That is **too strict** — it also forbids the harmless call over a different lock. The price stands
in the refusal. *A loud overstatement is cheaper than a silent exception: nobody goes looking
after the silent one* (`WERKZEUGKASTEN.md`, W4). With pass 8 it will be **replaced**, not loosened:
a shared witness will then cover exactly `requires Held-shared`, and the asymmetry stands one
level higher just as `E007` cuts it below.

**Two numbers, not one.** `held` was meant for **exclusive** holders. On the shared side the
computed quantity is a different one — not the hold time of a reader but the **writer waiting time
under reader pressure**. `shared held` is therefore an assurance of its own with a check of its
own (`K004`), not the same number under a different name.

#### 11.3 `publish` — the publication stands at the store

```ebnf
publishstmt = place "=" expr "publishes" ( placelist | "nothing" ) ";" ;
```

**Every store to an `atomic` and every store into a `dma` space is a `publishstmt`** — the payload
is named where it arises, with the indices visible there
(`FP_OWNER[core] = tid publishes { FP_STATES[tid] };` — the self-referential case is writable). A
**statement** as payload is reified as `ghost static` and published like a place
(`STALE_STEP = 2 publishes { ghost dead_in_senders };`). **Payload-free** accesses write
`publishes nothing`, and that is a word, not an empty list hole. *Payload-free, not "counter":
a one-shot latch carries no payload either, and the ordering sample drew two of them
(`messung/ORDNUNGSFINDER.md` §6).* Device publication (virtio `avail`) stands at the
`transition` of the device — the most safety-critical publication in the tree is thereby in the
model for the first time.

The declaration may additionally name a **superset**; then the compiler checks every store payload
against it. It does not have to — the obligation sits at the store.

#### 11.4 `accumulates` — without the forbidden loop

```ebnf
accdecl = "accumulates" ident ":" typeexpr "merge" ( "max"|"min"|"add"|"or"|"and" ) ";" ;
```

Lowering: **one cell per core** (`relaxed`), merged on reading over the NCORES-bounded loop. **No
CAS, no unbounded loop** — the contradiction "the compiler emits what the language forbids" is
thereby resolved, and the lowering is faster than the one it replaces. The merge set is closed
(commutative monoids).

---

### 12. Boot, machine, axioms (stock, made precise)

`linear ghost BootPhase`; `raw fn` demands it borrowed; `boot_end` consumes it **and** unmaps
`code<boot>` — one event, the probe at a `.boot` address is the falsifier. `prim fn … -> never`
for `switch_to`/`resume` (context switch as a primitive; a stack switch is expressible in no
structured language); `divergent fn` for spoken-out non-termination.

`assume`/`axiom` with the three classes (falsified / not falsifiable with a reason / **not run =
compile error**). The axiom layer is the largest unproven surface of the language and
**ratchetable**: if it grows in order to cover a language deficit, abort condition 5 bites.

**`iasm`** has exactly one emission site in the compiler. The entry path (register imprint,
`iretq`/`eret` as a transition over the machine state) has **no downstream prover** — the trust
shrinks from 161 sites to one site, it does not disappear. That is how it stands in the manifest.

---

### 13. `check` (stock)

Unchanged: `claim`, `measures` (the list **is** the report line), `gates`, `can_fail`, `floor`,
`counterprobe … expects`. The compiler produces `linear ghost Duty(check)`; the four compile
errors fall out of M1/M2/M3. `check` bodies and `offline` invariants compile only under
`when TESTBUILD` — in the shipped C they do not exist.

> **Built on 2026-08-28 («TB»), and until that day this line was a plan booked as stock.**
> `TESTBUILD` stood in zero lines of `crates/`; `Item::when` was parsed and read by nobody but
> the duplicate check, and `SYNTAX.md` claimed it lowered to `#if` — which the emitter never
> did either. **A gated item now produces no line of C in the shipping build**, and three
> refusals hold the form: `G001` (ungated code calls a gated function), `G002` (a `when`
> condition other than `TESTBUILD`), `G003` (`TESTBUILD` declared as a name).
> `gabbro emit --testbuild` opens the gate; its absence is the shipping build. Decision:
> `messung/BAUGATTER.md`. Corpus: `beispiele/52`, measured at **39 lines of C against 77**.
>
> *`offline` invariants are NOT gated* — they carry `cost … runs offline` at a `table`, which
> is a different clause with a different reader, and nothing in this build gates on it.

---

### 14. Lowering to C — high-performance because it proves instead of checking

#### 14.1 The principle

**Syntax-directed, not optimising.** Every construction has exactly one C form; optimisation is
the C compiler's business, and the lowering hands it the best it knows for that: `restrict` from
`effects`, `_Noreturn` from `never`, constant masks from `embeds`/`fields`, `switch` from `match`.

#### 14.2 The cost truth, checkable

**What is proven is not checked.** Ranges, indices, leafness, phases, tokens — all M1/M2 material
is **absent** in the C, not switched off. Runtime checks exist at exactly two places: at the
`format` entry (one length check per buffer) and in `narrow` (one branch). Ghost values,
`progress`, `costs`, contracts: **zero bytes**.

| Construct | C form | extra cost against handwriting |
|---|---|---|
| `intty in range` | bare C type | **0** — the range is proof, not check |
| `narrow … else` | one `if` | 0 against the `if` handwriting needs too |
| `tagged` + `match` | union+tag, `switch` | 0 |
| `traverse` | `for` without bound checks | 0; `by consuming` produces **no** visited store — the order is static |
| `format` reader | accesses after one length check | 0 against correct handwriting |
| `device`/`transition` | one volatile store, mask constant | 0 |
| `walk` descent | loop over `levels` (constant, unrollable) | 0 |
| `accumulates` | cell per core, relaxed | **negative** against the CAS version |
| `lock`/`locks` | the existing lock primitive | 0 |
| ghosts, contracts, `check` (shipping) | — | **0 bytes** |

**Checkable as acceptance:** per module generated C against handwritten C in the differential
benchmark; trigger if generated is slower than handwriting + measurement noise. That is the
phase-1 threshold, now phrased as a lowering property.

#### 14.3 Output form

One target: **C11 (freestanding) + `iasm`**, `-ffreestanding`-capable, no libc dependency in the
kernel. Deterministic: same source, same C, byte for byte. Names stable from `path`, so that the
product is diffable.

#### 14.4 The edge: `extern fn`

```gabbro
extern fn memcpy_fast(dst: ptr<normal, w> u8, src: ptr<normal, r> u8, n: usize)
    effects { writes dst, reads src }
    requires n <= lenof(dst), n <= lenof(src);
```

An `extern fn` is a C edge function: its contract is an **`assume` per declaration** and counts
into the axiom layer — the edge is thereby visible and ratchetable instead of silent.

---

### 15. The obligation manifest — logic is not lost

Per translation unit the compiler emits a manifest:

```
obligation revoke.functional      "ensures !exists k in descendants of s: k.used"   offen
obligation breaking.cdt_repair    "Wiederherstellung nach breaking in move_cap"      offen
assumption vtd_te_effective       falsifiziert(probe_vtd_te)
assumption x2apic_two_step        unfalsifizierbar("qemu64 hat kein x2APIC")
closed     consuming.schablone    "Ordnungserhaltung descendants, Erzeuger-Schablone" Fundstelle
```

**Three classes:** open logic obligations (the programmer or an external tool), the assumption set
(names with class, no cardinal number), closed amortised items with a site. "Memory-safe under
A1…An, functionally open at O1…Ok" is thereby a **sentence in the product**. The ratchet runs over
names; exchange is visible.

---

### 16. Caprock completeness — the map

| Area | carried by | via |
|---|---|---|
| Formats (part, fat, ELF, DTB, ABI, ACPI dmar, virtio descriptors) | `format` + `embeds` + `offset_into` + `chain` | §10.1 |
| CapSpace/CDT including revoke | `table … ops` + `by consuming` + `by induction over` | §10.2, §9.2 |
| Page tables, W^X, IOMMU roots | `walk` + `mappings of` + `embeds` | §5.4, §6 |
| Device drivers (VT-d, SMMUv3, virtio, x2APIC) | `device` + `transition publishes` + `bank` | §10.3, §11.3 |
| Scheduler/SMP (locks, phases, FP ownership) | `lock rank held` + `linear ghost` (Held, Parked→admit, MayWrite) + V2 | §11.2, §4, §3.2 |
| Service loops (virtio-blk, server) | `forever` with `on_exceeded`, input-dependent `per_pass`, `held` obligation | §9.3 |
| Boot, entry, context switch | `BootPhase`, `prim`, `iasm`, axiom layer | §12 |
| Check harness (**29,8 %**, not 15,7 — `messung/GEGENRECHNUNG.md` §8) | `check` under `when TESTBUILD` — **built 2026-08-28, «TB»** | §13 |
| Edge (memcpy, crypto kernels) | `extern fn` with contract as assumption | §14.4 |
| Conditional compilation (335 `cfg`) | `when` — **and since «TB» only on `TESTBUILD`.** The other 334 shapes are refused by `G002`, not carried. *The word was never carried at all: the emitter ignored it until 2026-08-28* | stock (narrowed) |

**What remains is logic** — `ensures` of the algorithmic bodies (IPC fastpath, scheduler choice,
revoke functionality), visible in the manifest. That is the promise from §0, literally.

---

### 17. What deliberately does not exist (extended)

Stock (`while`, `for`, `goto`, preprocessor, implicit conversion, `void*`, catch-all branch,
exceptions, inheritance, reflection, GC, floating point in the core, assignment as an expression,
forward declaration, self-hosting, user-defined quantifier domains, recursion in `spec fn`,
handwritten lemmas) — **plus, now named instead of forgotten:** `break`/`continue` without a
target (replaced by `leave`/`next` with a name), unnamed lock hold time in service loops, CAS
loops as a lowering detail, migration in format versions, cycles as a time unit.

---

### 18. The nine decisions, numbered

| # | Question | Decision |
|---|---|---|
| F1 | **54** relational preconditions *(of 102 flow-sensitive)* | **V2**, closed flow rule; `narrow` yardstick ≤ 24 |
| F2 | PTE = pointer AND bitfield | **`embeds [hi:lo] scale`**; root solved, not the domain |
| F3 | eighth domain (W^X) | **`mappings of`**, generated from `walk` |
| F4 | `per_pass` ritual | ops instead of cycles, `on_exceeded` obligatory, waiting time compositional via **`held`**, input-dependent bound |
| F5 | `publishes` at the wrong place | **store obligation** (`publishstmt`), declaration optional as a superset; devices via `transition publishes`; statements as `ghost static` |
| F6 | `accumulates` contradiction | **cell per core + merge**, no CAS |
| F7 | `break`/`continue` | **`leave`/`next`** with target name; named in the prohibition list |
| F8 | `breaking` | invariant blocked as a premise; restoration through a generated op **or** `obligation` — booking rule "carried by logic" |
| F9 | `depleted_count` dispute | third class, booked as logic (§8.3) |

---

### 19. Acceptance of this specification

1. **Repeat the 74-obligation measurement** against this version: hanging plumbing 19 → 0,
   otherwise refutation at the remaining sites (with class and site).
2. **The ten fragments** from the scratchpad into the folder, pulled onto this syntax, guardian
   green (reachability, terminal coverage, speech test in both directions).
3. **`narrow` count** on the tree: ≤ 24, otherwise V1–V3 is too small.
4. **Cost truth** (§14.2) per compiled module in the differential benchmark.
5. The counting rule stays: specification is **what stands in the source** and is deleted before
   code generation; generated material is output. Goal 0,5:1 for kernel code, 1:1 never exceeded
   for `format`; abort > 3:1 unchanged.


---

# Part II — Ordering, entry, boot

## SUPPLEMENT to the specification — the rest up to "logic only"

**Addendum to [`SPRACHE.md`](SPRACHE.md).** The balance sheet of the specification named three
holes: the **twelfth class** (ordering pairing, 2 231 sites declared instead of proven), the
**entry path** (syscalls/IRQs without a construct) and the **boot unreachability proof** (so far a
type rule plus a sentence of prose). This document closes them and then draws the honest remainder
list: what after everything still remains to be proven — and in which class.

As of 2026-08-14. **New words (closed, nine):**
`awaits entry regs out preserves clobbers stack dispatch vector`

> **CORRECTED while entering (2026-08-14):** the `timer` example wrote `preserves { all }`.
> **`all` is not a word of the vocabulary** — SUPPLEMENT 2 §7.1 demands the enumeration, because
> D2 means complete and not convenient. The sixteen registers now stand there.

---

### 1. The twelfth class: ordering is paired, not declared

**The shortfall:** `atomic … release` fixes an order, but that a `release` store and the
corresponding `acquire` load form a **pair** and that the order **reaches** the payload — nothing
checked that. By our own criterion that is plumbing (mentions only the machine) — and with 2 231
sites the largest uncovered item of the tree.

#### 1.1 `awaits` — the counterpart of `publishes`

```ebnf
awaitload = "let" ident "=" place "awaits" "{" placelist "}" ";" ;
```

The specification put the publication at the store (`FP_OWNER[core] = tid publishes
{ FP_STATES[tid] };`). **The supplement puts the reception at the load:**

```gabbro
let owner = FP_OWNER[core] awaits { FP_STATES[owner] };
if owner == my_tid {
    -- HIER ist FP_STATES[owner] lesbar: der Load hat die Sichtbarkeit erworben
}
```

**Three rules, all type rules, no memory-model solver:**

1. **Pairing obligation.** Every `awaits` load on an atomic demands that there be a `publishes`
   store on **the same** atomic with **the same** places (statically compared, name equality after
   index substitution). An `awaits` without a counterpart, a `publishes` without a receiver:
   compile error — orphaned halves are exactly the error class of the 872 sites in
   `threads/mod.rs`.
2. **Visibility is a branch fact** (V-rule family from the specification): only the checked branch
   that confirms the loaded value makes the expected places readable. Reading foreign-published
   places **without** acquired visibility is a compile error.
3. **Order follows from the pairing, not the other way round.** `publishes { … }` forces at least
   `release` at the store, `awaits` at least `acquire` at the load — the ordering words at the
   declaration are **derived and checked** instead of chosen. `relaxed` is writable only with
   `publishes nothing`/without `awaits` — the **payload-free** case. `seq` stays for algorithms
   that need a **global** order — and exactly those do not fall under the pairing:

> **The class is called PAYLOAD-FREE and not "counter", and the sample decided it**
> (2026-08-28, `messung/ORDNUNGSFINDER.md` §6). Two of the eleven sites it drew into that class
> are not counters at all but **one-shot latches** — `AGG_COHERENT` (`vtd.rs`:686) and
> `ECAM_BASE` (`pcie.rs`:81): a value determined once, stored, read, with no separate payload
> hanging off it. Under the literal reading of "counter" they are a fourth outcome, and a fourth
> outcome **refutes** this section; under its own test question (*"does it carry NO payload?"*)
> they are exactly this class. **A noun decided over two refutations, so the name now follows the
> question instead of one of its examples.** *No new word: `publishes nothing` already says it.*

**Nothing here notices that a pairing is MISSING, and that is the fourth rule** (`V009`, built
2026-08-28). The three above check a pairing somebody wrote down; whoever declares an ordering
case as payload-free gets silence instead of an error — *and a form that keeps silent says yes
for years.* `V009` refuses the one shape the sample found twice: an atomic that carries no
payload anywhere, whose value **gates a branch** behind which a foreign shared place is read.
What it does not find, and what the stronger cut would have cost (18 false alarms over the clean
corpus), is counted out in `messung/ORDNUNGSFINDER.md` §2.

**And the name comparison alone does not carry** (`V010`, same day). *A `release` of core 0
publishes the writes of core 0*, not the `fetch_max` of core 5 — so a payload whose writer lies
outside the publisher's call hull passes the static name comparison and orders nothing.

> **Boundary, named:** the pairing covers message passing (producer→consumer, ownership transfer,
> flags with payload) — by the site structure of the tree the dominant form. Algorithms whose
> correctness hangs on a global seq order over **several** atomics are writable with `seq`, but
> their correctness is **logic** and stands as an `obligation` in the manifest. The repeat
> measurement counts how many those are; the conjecture is "single digit", and it is marked as a
> conjecture.

**Lowering:** exactly the C11 atomics that stand there today — extra cost 0. The gain is not in the
product but in the fact that a missing `acquire` is **no longer writable**.

---

### 2. The entry path: `entry` — syscalls and IRQs from one declaration

#### 2.1 The construct

```ebnf
entrydecl = "entry" ident [ "vector" constexpr ] "arch" ident "{"
              "regs" "in"  "{" { ident ":" ident "," } "}"
              "regs" "out" "{" { ident ":" ident "," } "}"
              "preserves" "{" identlist "}"
              "clobbers"  "{" identlist "}"
              "stack" ident
              "dispatch" path ";"
            "}" ;
```

```gabbro
entry syscall arch x86_64 {
    regs in  { nr: rax, a0: rdi, a1: rsi, a2: rdx, a3: r10 }
    regs out { ret: rax }
    preserves { rbx, rbp, r12, r13, r14, r15, rsp_user }
    clobbers  { rcx, r11 }                      -- syscall/sysret-Realitaet
    stack KernelStack
    dispatch caprock::syscall::dispatch;
}

entry timer vector 0x20 arch x86_64 {
    regs in {} regs out {}
    preserves { rax, rbx, rcx, rdx, rsi, rdi, rbp, rsp,
                r8, r9, r10, r11, r12, r13, r14, r15 }
    clobbers  {}
    stack IrqStack
    dispatch caprock::irq::timer_tick;
}
```

**What falls by construction:** the register imprints are **complete** — every architecture
register is assigned to exactly one of the three sets, otherwise a compile error (D2 on
registers). The stack switch is the primitive no structured language expresses, here as a declared
line. `dispatch` points at an **ordinary Gabbro function** with a `tagged` syscall number,
M1-bounded, exhaustive `match` — from the first Gabbro line on M1–M4 hold, and the boundary
assembler/language is **one** declaration wide. `resume`/`iretq` is the typed way back (stock
§12).

**What does not fall, honest as before:** the entry path has **no downstream prover**. The
emission comes from the one `iasm` site; per `entry` and architecture a **probe** belongs in the
acceptance series (user registers byte-identical after return, `clobbers` really and exclusively
changed, kernel stack canary). Declared, emitted once, falsified — not proven. That is how it
stands in the manifest, class "entry".

#### 2.2 One origin, two products: the stub rule

From the **same** `entry` and `dispatch` declaration the compiler also generates **the userspace
stubs** (the calling side: load registers, `syscall`, type the result). ABI drift between kernel
and `programs/` — so far a pure matter of discipline — is thereby made **unwritable**: there is
only one source. The driver and program side (virtio-blk service loop) calls typed stubs with the
same contracts the kernel checks.

#### 2.3 FP/SIMD state

The kernel treats FP state as an **opaque save area**: `opaque type FpArea` with declared
size/alignment per architecture; `xsave`/`xrstor` (resp. FPSIMD saving on aarch64) are **axioms**
with an effect on `FpArea` and a drivable falsifier — the CVE-2018-3665 class (lazy-FP leak) is
thereby a `MayWrite`-like ownership question over `FpArea` plus an axiom, not a special path.

---

### 3. Boot unreachability — one theorem in three layers

**To be shown:** *After `boot_end` no `raw` code is reachable.* So far one type rule and one
falsifier sentence carried that. Now it is a named theorem with three layers, each with its trust
class — because "static only means: no caller" (trap 47) and one layer alone would be a request.

> **STATE, measured 2026-08-28 — and the finding was that `raw fn` had NO reader at all.**
> `grep -rn 'FnKlasse' crates/gabbro-check/src/` gave 22 sites, every one of them `Spec`,
> `Impl`, `Divergent` or `Konst`: `raw` parsed, was stored, and no rule attached to it. *A word
> that promises a discipline and is read by nobody reads like protection* — the same class as
> `@version`. **S1 and S2 are built since then** (`O008`/`O009` in `phasen.rs`, probes
> `beispiele/gift/299` and `/300`); **S3 followed the same evening** (`O010`–`O012`, probes
> `/341`–`/344`, decision in `messung/BOOT-S3.md`).
>
> **And W24 turned the S3 question around before it was answered.** The obvious form was
> written down and run through the **unchanged** checker: `!exists m in mappings of root : …`
> parses and types today, and `ensures` carries it with **0 errors** as soon as `effects`
> writes the walk. *What was missing was never the postcondition and never the parser* — it
> was the BINDING: `beispiele/07`'s old `boot_ende` passed with 0 errors because nothing said
> this function was the boot end. The literal sentence below fell on **one word**: `boot` is
> a vocabulary word and cannot stand in an expression.

| Layer | Rule | covers | trust class | **built** |
|---|---|---|---|---|
| **S1 — types** | every `raw fn` demands `&BootPhase`; `BootPhase` is linear, arises exactly once in the boot `entry`, is consumed by `boot_end`. After that **no call types** | every static call chain | checker (M2) | **`O008`** — the clause is demanded; *the token's phase order is `O001`–`O007`* |
| **S2 — references** | `raw fn` lies forcibly in `section ".boot"`; **taking the address of a `raw fn` is not writable** (no `fnptr` to `raw`, no jump table with `.boot` targets, no `ptr<code>` literal pointing there). Non-`raw` code in `.boot` is a compile error | every dynamic reachability via pointers | checker (M3/D2) | **`O009` for the half that bites**: `&f` on a `raw fn` is refused. *The `section ".boot"` placement is NOT enforced* — and `O009` sees only a name it can resolve in the same program |
| **S3 — hardware** | `boot_end` consumes the token **and** retires the address space, **one event**: `retires t from boot falsifier <probe>` — one clause carrying token, space and probe, none of the three writable alone. `O011` holds it against `consumes t`, `O012` demands the `walk` fact that says what is gone, `O010` refuses a token nobody retires. Probe: access to a `.boot` address after `boot_end` **must fault** | jumps S1/S2 does not see (misspeculation excepted, ROP onto dead but mapped bytes) | axiom layer + falsifier | **`O010`–`O012`** — for the half that is *formulable*. The other half (no mapping ⟹ unreachable) leaves the checker: `manifest.rs` books it as an assumption out of this clause, with the probe it names. *The section is `boot`, not `code<boot>`: that spelling is not a Gabbro space. And `m.section == boot` is unwritable twice over* — `boot` is a vocabulary word, and a page table entry **has no section field**; `.boot` is a link-time range, so the postcondition names the frame bounds |

**With that the theorem is not "proven in the checker" but cleanly decomposed:** S1+S2 are type
rules of the unverified checker, S3 is a hardware assumption with a drivable probe. The manifest
carries it as one entry with three part-assurances — stronger than Rust's `#[deprecated]`
discipline, stronger than Verus' affine `tracked` (the token is **linear**: restoring and copying
are type errors), and without "unsafe, but careful" standing anywhere.

---

### 4. The remainder list — what is left after everything

After specification + supplement this holds: **Caprock, drivers and system programs are fully
writable** (area catalogue §16 of the specification, plus entry, stubs, FP, ordering). For formal
verification what remains, separated by class — because "logic only" is honest only if the trust
items stand beside it:

#### 4.1 To be proven (the actual logic work)

| # | Item | Place |
|---|---|---|
| L1 | `ensures` of the algorithmic bodies: IPC fastpath, scheduler choice, revoke **functionality** | manifest, per function |
| L2 | seq-order algorithms beyond the pairing (§1, conjectured single-digit — to be counted) | manifest |
| L3 | `breaking` restorations without a generated closing operation | manifest (booking rule F8/F9) |
| L4 | the one known unformulable obligation | manifest, with site |

**That — and only that — must be proven by a human or an external tool.**

#### 4.2 Trust instead of proof (named, ratchetable, not a work item)

The unverified checker; the syntax-directed lowering; the one `iasm` emission site including the
`entry` probes; the axiom layer (privileged instructions, MMU model, `xsave`, `extern fn`); the
amortised generator templates (`by consuming` order, `table ops` invariant preservation).
Everything in the manifest with name and class — the ratchet runs over names.

#### 4.3 Without a mechanism (open, no construct claimed)

**D8 — progress and starvation.** `progress` names assumptions, proves no liveness. No construct
of these two documents changes that, and it stands here so that it is not read as done.

---

### 5. Acceptance of this supplement

1. **Extend the repeat measurement to 12 classes:** the 74 obligations plus an ordering sample
   (≥ 30 of the 2 231 sites, stratified by file) against §1 — every site is a pairing, a
   **payload-free** access or a named seq case; a fourth outcome refutes §1.
   **RUN 2026-08-28** (`messung/ORDNUNGSSTICHPROBE-BEFUND.md`): 39 sites, **0 fourth
   outcomes** — 6 pairings, 11 payload-free, 1 seq, 21 dropped as test scaffolding. *And the
   run found the hole this section did not have: nothing here FINDS a missing pairing.*
2. **One `entry` per architecture as a fragment** into the folder, held against the real
   syscall/sysret resp. SVC convention (the `clobbers` line is the touchstone).
3. **The boot theorem as three check lines** in the acceptance series: S1/S2 as a checker speech
   test (a call after `boot_end` must break compilation), S3 as a probe in the test kernel.
4. **Grammar unification**: specification + supplement hooked into the EBNF, both guardians
   (reachability from `program`, terminal coverage) green — this error class has been paid for
   twice.
5. Afterwards the contradiction run over the whole folder, as after the six rebuilds.


---

# Part III — RMW, visibility, entry addenda

## SUPPLEMENT 2 — the open items of the supplement, and the checker as a plan

**Addendum to [`SPRACHE.md`](SPRACHE.md) and [`SPRACHE.md`](SPRACHE.md).** The first supplement
left four open levels: holes in our own constructs (the largest: RMW), unrun measurements, matters
fundamentally unasserted, and the fact that not one line of checker exists. This document closes
the first level, names the second and third as a work list with an order — and lays down for the
checker a **plan with stages and gates** instead of a declaration of intent.

> **ENTERED and DERIVED (2026-08-14).** Acceptance point 2 of this document demands that the word
> count be taken **from the unified vocabulary table** instead of by hand (trap 80). The
> terminal-coverage guardian has counted: **17 new words** over both supplements —
> `awaits entry regs out preserves clobbers stack dispatch vector` (9, the count from
> ERGAENZUNG.md was **right**) plus
> `exchange update returns nested ist per cpu masked` (**8**, not 5).
> §3.2 itself already named seven and deliberately let the drift stand; **`masked` was missing on
> top of that.** With that the point is closed: **the number now comes from the table, not from
> somebody's head.**

As of 2026-08-14. **New words (derived, eight):** `exchange update returns nested ist per cpu masked`
**Correction to ERGAENZUNG.md:** `preserves { all }` used a word outside the vocabulary — the
document violated its own rule, and the terminal-coverage guardian would have found it had it been
run. `all` is **not** taken in; an entry enumerates its registers (D2 means complete, not
convenient). The timer example is to be corrected accordingly.

---

### 1. RMW — the third form of the pairing

**The hole:** `publishes` sits at the store, `awaits` at the load; `fetch_add`,
`compare_exchange`, ticket taking are **both in one instruction**. Without a third form the
ordering sample counts a fourth outcome and refutes §1 of the supplement at its own acceptance.

```ebnf
exchstmt = "let" ident "=" place "exchange" xform
           [ "publishes" ( placelist | "nothing" ) ]
           [ "awaits"    "{" placelist "}" ] ";" ;
xform    = "update" "(" ident ")" block          (* der Rumpf rechnet alt -> neu; rein, M1 *)
         | expr "when" pred "returns" ident ;    (* compare-exchange: neu when alt-Bedingung *)
```

```gabbro
-- Ticket nehmen: publiziert nichts, erwartet nichts — reiner Zaehler
let my = NEXT_TICKET exchange update(t) { t + 1 } publishes nothing;

-- Besitzuebernahme: CAS, der bei Erfolg Sichtbarkeit erwirbt UND weitergibt
let won = FP_OWNER[core] exchange my_tid when old == NOBODY returns old
          publishes { FP_STATES[my_tid] }
          awaits    { FP_STATES[old] };
if won == NOBODY { -- Erfolgzweig: awaits-Plaetze lesbar, publishes-Zusage aktiv
}
```

**Rules, all type rules:**

1. The `update` body is pure (`effects { pure }` implied), M1-typed — an overflow in the RMW is
   thereby a compile error, not a two-in-the-morning find.
2. `publishes` at the `exchange` forces at least release, `awaits` at least acquire, both together
   acq_rel — **derived**, as in supplement §1.3.
3. Visibility from `awaits` arises **only in the success branch** (V3-like over the `returns`
   result).
4. The pairing obligation holds over all three forms together: a `publishes` can be received by a
   load **or** an `exchange`; what is compared is the united set.

**Lowering:** `atomic_fetch_*` where the `update` body corresponds to a primitive (matched against
a closed pattern table: `t+1`, `t-1`, `t|m`, `t&m`, `max` via `accumulates`), otherwise the
**bounded** CAS loop: the language emits nothing it forbids (the `accumulates` lesson,
generalised).

> **«C4b», 2026-08-20: where the bound comes from is now written down.** This paragraph said
> *"emitted in the compiler as `retry bounded NCORES * K ops on_exceeded contention`, with K
> from the `held` calculation"* — and the emitter refused, with the right reason: **`NCORES`
> and the exit stood nowhere.** `NCORES` was the same undecided quantity as `accumulates`
> without `per cpu N`, and nothing named `contention`.
>
> They are now written at the construct, **in the same words a `retry` carries**:
>
> ```gabbro
> let alt = ZAEHLER exchange update(v)
>     bounded NKERNE * 4 ops
>     on_exceeded zu_viel_streit
> { if v < GRENZE { return v + 1; } return v; } publishes nothing;
> ```
>
> *It is the same loop with a CAS for a body; where two forms do the same thing they should be
> called the same.* No new word. Without the two clauses the refusal stands — an unbounded CAS
> loop is exactly what this language forbids.

---

### 2. Visibility across function boundaries: `Vis` becomes passable

**The hole:** visibility was a branch fact and died at the function boundary — if one function
checks the flag and another reads the payload (the usual cut), the correct program was not
writable.

**The solution is no new construct but the consistent application of M2:** the success branch of
an `awaits` load/`exchange` **produces** `linear ghost Vis(P)` per expected place. `Vis` is
passable like any ghost value (parameter, return), reading a foreign-published place demands
`&Vis(P)` borrowed, and the producer list from specification §4 is extended by `Vis`: **only** the
success branch produces it, a hand-built token is a type error. Consumption is not necessary
(visibility does not expire) — `Vis` is the one **affine** ghost value of the language, and that
it is affine instead of linear stands here as a decision with a reason, not as an oversight.

---

### 3. Entry — the five addenda

#### 3.1 The syscall that does not return (the microkernel's normal case)

`regs out` describes the way back **into the same thread**. `dispatch` may instead end in
`switch_to`/`resume` — then this holds: the entry has **two typed exits**, `returns` (regs out to
the caller) and `resume k` (full context from `k`; the `regs out` contract is moot, because the
complete register set comes from the target context). The `entry` declaration names both:

```gabbro
entry syscall arch x86_64 {
    regs in  { nr: rax, a0: rdi, a1: rsi, a2: rdx, a3: r10 }
    regs out { ret: rax }                  -- Ausgang 1: returns
    preserves { rbx, rbp, r12, r13, r14, r15, rsp_user }
    clobbers  { rcx, r11 }
    stack KernelStack
    dispatch caprock::syscall::dispatch;   -- -> Result | never (resume)
}
```

The dispatch return type `Result | never` makes the two exits visible in the type: `return` takes
exit 1, `resume` exit 2. The saved caller context is an ordinary `Context` value — whoever dropped
it would lose a thread, so `Context` is **linear**: `return` consumes it into the way back,
`resume` puts it into the scheduler's store. A forgotten thread is thereby a type error — the same
class as `Parked`.

#### 3.2 Stack per CPU, nesting, NMI

```ebnf
entryextra = [ "stack" ident [ "per" "cpu" ] [ "ist" constexpr ] ]
             [ "nested" ( "never" | "masked" | "bounded" constexpr ) ] ;
```

`stack KernelStack per cpu` makes the per-CPU stack a declaration (the selection is emitted by the
one `iasm` site out of `gs`/`tpidr`). `nested never` (syscall), `nested masked` (IRQ runs with
masked interrupts), `nested bounded 1` (one level change permitted) — the nesting depth is thereby
M1 material instead of convention. NMI and double fault take `ist n` (their own stack from the
interrupt stack table) and **may call only `raw`-free, lock-free code** (`effects` of the dispatch
target: no `locks`) — the classic NMI deadlock is not writable.

New words for that: `nested`, `ist`; `per` and `cpu` — hold on: **four**, plus `exchange update
returns` from §1 makes seven. The header line names five; that is exactly the drift the
terminal-coverage guardian catches, and it deliberately stays here as a reminder that the
**grammar unification must run before everything else** (§6, stage P1).

#### 3.3 `Result` encoding

A `regs out` register carries a `tagged` value only via a declared encoding:
`ret: rax = Result { Ok(v) -> v in 0 .. 0x7FFF_FFFF_FFFF_FFFF, Err(e) -> -(e as i64) }` — the
encoding stands at the `entry` declaration, stubs and dispatcher generate both sides from it. An
encoding that let the value ranges overlap is a compile error (D2).

#### 3.4 FP ownership, designed instead of sketched

`FpArea` is per thread, saved **eagerly** in the `switch_to` primitive (the lazy variant is the
CVE-2018-3665 trap and is not offered — a decision, not a gap). `MayUseFp(tid)` is a linear ghost
value at the thread; the `xsave`/`xrstor` axioms demand it borrowed. With that FP state is
ownership like any other, and the special path disappears.

#### 3.5 The edge of the boot theorem, named

S2 covers the Gabbro level. **Outside the language lie:** the early trampoline stretch
(physical→virtual, before the first Gabbro line) and the linker script (section boundaries,
`.boot` placement). Both migrate as **named assumptions** into the axiom layer
(`assume linker_boot_disjoint … falsifier probe_sections;` — the probe reads the linker map in the
check harness), so that the boot theorem has no silent edge.

---

### 4. The memory model as an axiom — so far tacit

`publishes`/`awaits`/`exchange` promise visibility **under the assumption** that the C11 mapping
carries on the target architecture. That stood nowhere. Now:

```gabbro
assume c11_release_acquire arch x86_64
    "release-Store / acquire-Load auf x86-64 (TSO): Absenkung auf mov genuegt"
    falsifier probe_mp_x86;          -- Message-Passing-Litmus, im Pruefgeruest gefahren
assume c11_release_acquire arch aarch64
    "stlr/ldar tragen release/acquire auf aarch64"
    falsifier probe_mp_aarch64;
```

**The machine used to live in the NAME** — `_x86`, `_aarch64` — and a name is not a clause:
nothing held it against the unit, and nothing kept a third architecture from writing a fourth
suffix. Since «B40» it stands in `arch`, where `A005` reads it. *Two spellings for one thing,
and only one of them had a reader — the same shape as `masks irqs` at a lock.*

The litmus probes (MP, SB, LB — the classic three) run in the check harness as `check` with
`counterprobe`. With that the memory model is **countably** part of the axiom layer instead of
implicit — and the promise from supplement §1 reads in full: *pairing correct under c11_*
assumptions.*

---

### 5. Fundamentally open — unchanged, so that nobody reads it as done

**D8** (progress/starvation): no mechanism, no construct claims one. **L4**: the one unformulable
obligation. **The generator templates** (`by consuming` order, `table ops`): named, not designed —
they are part of the checker plan (P4), not of this document.

---

### 6. The checker — a plan with stages and gates, not a declaration of intent

**Decisions of principle, in advance and with a reason:**

| | Decision | Reason |
|---|---|---|
| Host language | **Rust, `forbid(unsafe_code)`**, no proof-tool dependency | the checker is type rules, not a solver; the CSolver/Miri discipline is in place |
| Architecture | lexer → parser (from the **unified** EBNF, handwritten, no generator) → one core tree → **checking passes in a fixed order** (names, D1/D2, M1+V1–V3, M3, M2, M4/loops, pairing, **group**, effects, costs) → C emission | every rule of these three documents is exactly **one** pass or a named part of a pass — the specification is the pass list |

> **The list grew from nine to ten on 2026-08-16, and that stands here instead of in a module
> name.** *"The specification is the pass list"* says, read backwards: **a new pass is a change to
> the specification**, and it is booked at this line or not at all.
>
> **The tenth is *group*, and its need is measured, not designed.** The SWEEP of the connecting
> invariants (`MESSUNGEN.md`, 2026-08-16) found four invariants **between** two carriers each;
> three lie under one lock, the fourth (V4 — endpoint queue against thread state) over **two
> crates with two lock classes**. In the nine passes that has no place: pass 2 checks
> declarations, pass 8 the effect list of **one** function against its body — **neither of the two
> knows a compound.**
>
> *What is built is the **lock imprint** (`U001`–`U005`), not the invariant. The group names its
> carriers today, not its connecting statement.*
>
> **That last sentence held for one day and stands corrected here rather than quietly replaced.**
> Since 2026-08-16 `gruppe.rs` also carries the **move** (`U006`: no path leaves the body between
> the first and the last write) and the **connection statement as a form** (`U007`: a group
> invariant names at least two carriers, otherwise it belongs at the table). What is still
> unbuilt is the **preservation** — that the invariant holds under an operation is the prover's
> business and falls to S16/S17, not to this pass. *The difference between "the invariant is not
> built" and "the invariant is built as a form, not as preservation" is the whole finding; the
> first version of the sentence covered both with one word.*
| Lowering | syntax-directed, one construct → one C form, deterministic byte for byte | specification §14, unchanged |
| Self-application | **never** — the checker stays Rust (prohibition list: self-hosting) | a project that rebuilds its checker has none |
| Checking strategy | every pass with a speech test in both directions (poison falls, clean material passes) **plus a mutation probe on the emission** (code AND annotation) | the wished-for-form-proof lesson |

**The stages — each with a gate, each able to end the project:**

| Stage | Content | Gate (in advance, two-sided) |
|---|---|---|
| **P0** | **Repeat measurement on paper** against specification+supplements: 74 obligations + ordering sample (≥ 30, stratified) + `narrow` count | hanging plumbing **0**, ordering sample without a fourth outcome, `narrow` ≤ 24. **Every miss: first pull the construct up, NO checker code before that** |
| **P1** | **Grammar unification** (specification + both supplements into the EBNF), both guardians, contradiction run over the folder | guardians green; contradictions 0 open. The error class paid for twice — therefore **before** the first checker line |
| **P2** | **Lexer+parser** over all fragments of the folder | 100 % of the fragments parse; three poison fragments fail with a named refusal |
| **P3** | **M1+V1–V3 as the first checking pass**, against the `space.rs` fragment and the 102-site sample | the sample types without `narrow` inflation; speech test: `refcount -= 1` without a V fact **falls** |
| **P4** | **M2 (linear/ghost) + generator template** for `table ops`/`by consuming` — here the named item is designed and the template proofs are carried as closed manifest entries | S1a/S1b/Parked/D0 class fall as speech tests; the mutation probe on the template does **not** catch a consistently weakened mutation — so the differential test against `space.rs` (Rust) runs beside it, as booked in the specification |
| **P5** | **C emission** for the `space.rs` fragment, differential test + differential benchmark against the Rust version | byte-identical repetition; generated ≤ handwriting + noise; `read(write(x)) == x` for the formats involved |
| **P6** | Pairing pass + `entry` emission for **one** architecture, litmus and `entry` probes in the check harness | probes green on real hardware or KVM; the three boot check lines run |
| **P7** | **One Caprock module end to end** in production (candidate: `caprock-part` — small, format-heavy, a real consumer), strangler pattern, the Rust version stays beside it | acceptance series green, the module's metric measured and reported (goal 0,5:1, abort > 3:1) |

**The ordering rule that carries the whole plan:** P0 and P1 cost paper and scripts, no compiler
building — and they can refute V2, `awaits`, `embeds` and the grammar **individually**. Therefore:
**no checker line before gate P1.** The correction loop has run faster than the measurement loop
several times in this folder; this plan is built so that structurally that is no longer possible —
every stage consumes the result of the previous one, like a `Duty`.

**Effort:** no estimate — an invented one would be worse than none (the FULL-COVERAGE rule).
Instead the gates; and beside the plan stands the Caprock question no Gabbro document answers: A4,
Z24 and the A3 follow-up items are waiting, and this plan is more than paper only once P0 has been
run.

---

### 7. Acceptance of this second supplement

1. The `preserves { all }` example in ERGAENZUNG.md corrected (registers enumerated).
2. The word count in the header line resolved against §3.2 — from the unified vocabulary table,
   not by hand (trap 80: a number a human runs parallel to the truth).
3. P0 run **before** anything else from §6 begins.


---

# Part IV — Hardware assumptions and the boot path

## SUPPLEMENT 3 — hardware assumptions complete, and the boot path as language

**Addendum to [`SPRACHE.md`](SPRACHE.md), [`SPRACHE.md`](SPRACHE.md),
[`SPRACHE.md`](SPRACHE.md).** The axiom layer was a system with examples; here it is **counted
out** — not out of imagination but **measured against the branch `arch/x86_64` of Caprock**
(`kernel/src/arch/x86_64/`, `crates/caprock-hal/src/x86_64/`). And the unsafe boot code, so far a
theorem in three layers over a stretch of prose, becomes language: the real trampoline (`mod.rs`,
`_start` up to `x86_rust_entry`) is the template, line by line.

> **ENTERED 2026-08-14, with four re-checked numbers and one name correction.**
> Grammar: **119 rules, 0 open, 189 terminals against 189 vocabulary words**, both guardians
> green. The guardian counts **two** new words — the header line is right this time.
>
> **Re-checked against the branch, all four:**
> `int 0x80` stands literally in `crates/caprock-hal/src/x86_64/syscall.rs:23`, and the comment at
> `:4` expressly contrasts it with the `syscall`/`sysret` way — **the correction to ERGAENZUNG §2
> is right.** `ABI_TO_GPR` is `[usize; 7]` starting `RAX, RDI, RSI` (`exception.rs:73`). **Not a
> single `xsave`/`xrstor` in the tree** (7 `fxsave`, 6 `fxrstor`) — the `FpArea` sharpening is
> right. And the port item that A12 pulls out of the axiom layer is with **70 sites** (52
> `outb`/`outl`, 18 `inb`) **larger** than the count states.
>
> **One name correction while entering:** `via int 0x80` is not writable, because `int` is the
> **number class** in the lexis (`int = dec | hex | bin`). The mechanism is an identifier from a
> closed set, the vector comes from the existing `vector`:
> `entry syscall vector 0x80 via softint arch x86_64 { … }`. **No additional word.**

As of 2026-08-14. **New words (closed, two):** `port step`
(`via`, `boot`, `requires`, `ensures` are reused — a grammar extension is not a vocabulary
extension.)

---

### 0. The count — what the branch really touches

Privileged and ordered instructions in the x86_64 part, deduplicated (sites, not calls):

| Instruction | # | | Instruction | # | | Instruction | # |
|---|---|---|---|---|---|---|---|
| `outb`/`out` | 46+ | | `mov cr0` | 7 | | `sfence` | 2 |
| `hlt` | 35 | | `iretq` | 7 | | `rdtsc` | 2 |
| `cpuid` | 26 | | `lfence` | 7 | | `invlpg` | 2 |
| `inb` | 17 | | `mov cr3` | 6 | | `sysret` | 1 |
| `wrmsr` | 12 | | `lgdt` | 4 | | `swapgs` | 1 |
| `cli` | 12 | | `fxsave` | 4 | | `sti` | 1 |
| `rdmsr` | 11 | | `mov cr4` | 3 | | `pause`/`mfence`/`lidt`/`fxrstor` | 1 each |
| `ltr` | 10 | | `rdtscp` | 3 | | | |

MSRs: `EFER (0xC000_0080)`, `IA32_APIC_BASE`, `IA32_ARCH_CAPABILITIES`. CPUID leaves: 0, 1, 7.
Not yet on x86 (according to `bringup.rs`): SMP (INIT-SIPI-SIPI), PCID/per-VSpace, ring-3 PDs in
the kernel, loader, IOMMU activation — their axioms stand below as **pre-noted**, not as counted.

**Two corrections to our own supplements, out of the real code:**

1. **The syscall mechanism is `int 0x80`, not `syscall`/`sysret`.** Kernel threads raise
   `int 0x80` (IDT gate, DPL 3), because it lays the same trap frame as any interrupt — the
   dispatch stays uniform, and `rcx`/`r11` survive. ERGAENZUNG §2 took the `syscall` convention as
   given. The `entry` construct therefore gets the choice of mechanism:
   `entry syscall via int 0x80 …` | `via syscall` | `via svc` (aarch64) — **the `clobbers` set
   follows from the mechanism** and is checked instead of copied (int: none; syscall: `rcx, r11`).
   The real ABI from `syscall.rs`/`exception::ABI_TO_GPR`:
   `nr: rax, ep: rdi, m0: rsi, m1: rdx, m2: r10, m3: r8, tag: r9`, return in the same six.
2. **FP is `fxsave`/`fxrstor` (512-byte area), not `xsave`.** ERGAENZUNG-2 §3.4 is made precise:
   `FpArea` on this branch is the FXSAVE area; `xsave` is the extension **behind a feature
   witness** (§2).

---

### 1. The sixth address space: `port`

The count shows what the MMIO model overlooked: **port IO on x86 is an address space of its own**
(console `0x3F8`, PCI configuration `0xCF8`/`0xCFC`, PIC, PIT) — with its own instruction form
(`in`/`out`), its own width rule and without a mapping in the page machinery.

```gabbro
device SerialCom1 at port {
    reg DATA : u8 @0x3F8 class rw
    reg LSR  : u8 @0x3FD class r fields { THRE @5, DR @0 }
}
device PciConfig at port {
    reg ADDR : u32 @0xCF8 class w
    reg DATA : u32 @0xCFC class rw
}
```

`at port` lowers accesses to `in`/`out` instead of to volatile loads/stores; `class`, `fields`,
`transition`, `keeping` hold unchanged. On architectures without a port space a `port` device is
declarable only under `arch x86_64` (D2: no silent catch-all).

> **Both halves of that sentence are BUILT since 2026-09-02**, and both were broken until
> then: the emitter wrote a volatile load at `basis + offset` — the port number as a memory
> offset — and it took a port device with no `arch` at all. The lowering, what `in`/`out`
> demands that a load does not, and the forms that are refused by name instead are in
> `messung/ADRESSRAEUME.md` §10; `beispiele/65-port-space.gab` is the worked example.
> **A `bank` inside a port device is refused** — its base is read at run time and no clause
> bounds it inside sixteen bits — and that is the one part of *"hold unchanged"* above that
> does not. With that the largest site items of
the count (`outb`/`inb`) are **device language instead of axioms** — the axiom layer shrinks where
a construct carries, and that is exactly the direction the ratchet is supposed to run.

---

### 2. Feature witnesses: `Has(F)` — CPUID as generator

Runtime features (CPUID 0/1/7, `IA32_ARCH_CAPABILITIES`) are not `when` constants. They become
**witnesses**: the CPUID probe is the only generator of `ghost Has(Feature)` (affine, like `Vis` —
a capability does not expire), and every axiom whose instruction presupposes a feature demands the
witness borrowed:

```gabbro
axiom rdtscp() -> u64 requires Has(RDTSCP) effects { pure }  falsifier probe_tsc;
axiom xsave(a: ptr<normal, w> XsaveArea) requires Has(XSAVE), MayUseFp(tid)
      effects { writes a }                                    falsifier probe_fp_roundtrip;
```

An `rdtscp` without prior detection is thereby **not writable** — the #UD class (instruction on an
old CPU) becomes a compile error. The generator list (specification §4) is extended by `Has`: only
the generated CPUID probe produces it.

---

### 3. The assumption catalogue x86_64 — complete against the count

Every line: effect on the machine model, witness flow (M2 token), falsifier status.
**F** = probe drivable (QEMU/KVM, in the check harness), **U** = not falsifiable with a reason,
**V** = pre-noted (code does not exist yet).

| # | Axiom | Effect / token | Status |
|---|---|---|---|
| A1 | `write_cr3(p)` | changes the root, invalidates the non-global TLB; `consumes/mints ActiveTable(p)` | F: probe remaps, reads |
| A2 | `write_cr0(v)` | `PG` bit: `requires PaeSet, LmeSet, Cr3Set` → `mints Paging`; `WP` bit → `mints WriteProtect` | F: read-only write probe must fault |
| A3 | `write_cr4(v)` | `PAE` → `mints PaeSet`; forbidden transitions unformulable as missing tokens | F |
| A4 | `wrmsr_efer(v)` | `LME` → `mints LmeSet`; **setting `LME` while `PG=1` is unwritable for lack of a token** | F |
| A5 | `lgdt(d)` / `lidt(d)` / `ltr(s)` | loads descriptor tables; **the hardware writes accessed bits INTO the GDT** (see §5.3) | F: byte comparison before/after |
| A6 | `invlpg(va)` | invalidates one TLB entry; part of the unmap quiesce sequence | F: stale-TLB probe |
| A7 | `iretq(frame)` / `sysret` | typed transition (stock `resume`); `sysret` only `via syscall` | F: `entry` probes (E2 §5.2) |
| A8 | `int 0x80` | gate DPL 3 lays a complete trap frame; **no** clobbers | F: register-image probe |
| A9 | `cli`/`sti` | masks/unmasks; `mints/consumes IrqsOff` — `sti` without a token is unwritable | F |
| A10 | `hlt` | waits for an interrupt; only with a `progress` assumption in `forever` | F: watchdog |
| A11 | `pause` | spin hint, semantics-free | U: "no observable effect" |
| A12 | `in`/`out` (space `port`) | device effect per the `device` declaration; issued serially | F per device |
| A13 | `rdmsr`/`wrmsr` (APIC_BASE, ARCH_CAP) | one declared effect per MSR; an unknown MSR number is unwritable (D2) | F |
| A14 | `cpuid(leaf)` | pure; **the only generator of `Has(F)`** | F: cross-comparison of leaves 0/1/7 |
| A15 | `rdtsc`/`rdtscp` | monotone per core **not** guaranteed — only a measured value, never an order | U: "invariance is platform-less" — use as an order is a compile error |
| A16 | `fxsave`/`fxrstor` | 512-B area, `requires MayUseFp` | F: roundtrip probe |
| A17 | `clflush` + `sfence` | line written out; part of the DMA publication sequence in the `dma` space | F: device echo |
| A18 | `lfence`/`mfence` | ordering points beyond TSO (rdtsc serialisation, MMIO) | with A19 |
| A19 | TSO / C11 mapping | `c11_release_acquire_x86` (stock E2 §4) | F: litmus MP/SB/LB |
| A20 | `swapgs` | kernel GS base; only in the `entry` emission, `requires` entry context | F: GS probe |
| A21 | Multiboot1 contract | protected mode, `ebx` = info pointer, header in the first 8 KiB | F: the boot **is** the probe |
| A22 | Linker disjunction | `.boot*` ⟂ `.text/.rodata`; `[__text_start,__rodata_end)` immutable after boot | F: linker-map probe (E2 §3.5) |
| A23 | INIT-SIPI-SIPI, ICR | SMP start | **V** (the branch has no SMP) |
| A24 | PCID/`invpcid` | per-VSpace TLB | **V** |
| A25 | VT-d activation | `vtd.rs`/`dmar.rs` lie in the HAL; transitions are `device` language, the effectiveness (`vtd_te_effective`) stays an axiom | F, once activated |

**The ratchet over this catalogue:** 22 counted + 3 pre-noted entries. Every new entry needs a
site and a status; if the catalogue grows without new hardware surface, abort condition 5 bites.
And the opposite direction is the success case: A12 has just moved the two largest instruction
items out of the axiom layer into the device language.

---

### 4. The mode ladder: forbidden transitions are missing tokens

The core of §3, lifted out because it generalises the x2APIC lesson: **the boot order
PAE → LME → CR3 → PG is not a prose prescription but a token flow** (M2). `write_cr0` with the PG
bit *demands* `PaeSet`, `LmeSet`, `Cr3Set`; whoever breaks the order does not have the token and
**does not compile**. The 32-bit part of the trampoline thereby becomes checkable although it lies
before the first "real" Gabbro line — because it is **generated** from a declaration:

---

### 5. The boot path as language — against the real trampoline

Template: `kernel/src/arch/x86_64/mod.rs` (`.multiboot` header, `_start` in `.code32`, page table
construction, CR ladder, `retf` → `long_mode`, `.bss` zeroing, `call x86_rust_entry`).

#### 5.1 The `boot` construct

```ebnf
bootdecl = "boot" ident "arch" ident "{"
             { "step" ( axiomcall | ident "=" constexpr ) ";" }
             "dispatch" path ";"
           "}" ;
```

```gabbro
boot multiboot1 arch x86_64 {
    step stack   = boot_stack_top;            -- esp laden
    step save_bootinfo(ebx);                   -- Multiboot-Zeiger retten
    step load_tables(BOOT_IDENTITY);           -- §5.2: VORBERECHNET, kein rep stosd
    step write_cr3(BOOT_IDENTITY.root);        -- mints Cr3Set
    step write_cr4(PAE);                       -- mints PaeSet
    step wrmsr_efer(LME);                      -- mints LmeSet
    step write_cr0(PG);                        -- requires alle drei -> mints Paging
    step load_gdt(GDT64); step far_return(CODE64);
    step zero_bss(__bss_start, __bss_end);     -- erzeugt, aus Linker-Symbolen
    dispatch caprock::x86_rust_entry;          -- erste Gabbro-Funktion; mints BootPhase
}
```

**The emitter is the same one `iasm` site** as with `entry`; the checker checks the token flow of
the ladder (§4) **before** the emission. After `dispatch` this holds: `BootPhase` exists, every
`raw fn` is reachable, and the three-layer theorem (E1 §3) takes over. The `hlt` catcher after the
return is `divergent` and is generated along with it.

#### 5.2 The boot page tables are data, not code

The real trampoline **builds** the identity mapping at run time (`rep stosd`, loop over 512 PD
entries). But the mapping is **constant**: 1 GiB identical, 2 MiB pages, `present|writable|PS`. In
Gabbro it is a `const` of the `walk` type, **computed at compile time** and placed in
`.boot.data` — `step load_tables` merely loads it. Fewer zone-0 instructions, and the mapping
itself is M1/`walk`-checked instead of handwritten bit arithmetic in 32-bit assembler. (Relocating
the physical base is link-time work: linker symbols are `extern` constants, A22.)

#### 5.3 The GDT lesson from the real code — as a placement rule

The branch documents a paid-for find: **on loading a segment register the CPU writes the accessed
bit into the descriptor** — the GDT must lie writable, otherwise #PF under `WP=1`, and an accessed
bit in `.rodata` would have made the code hash (A-1.3) alien to what runs. That is now axiom
**A5** plus a **placement rule**: the GDT/IDT/TSS declaration is a `format` in the `normal` space
with mandatory right `w`; a placement in an `r` section is a **compile error**. The trap is thereby
unwritable instead of well commented.

#### 5.4 Multiboot info is a `format`

The saved `ebx` pointer is classic **untrusted input**: `format Multiboot1Info` with a flags
field, a conditional memory plan (`mmap_length`/`mmap_addr` with an `offset_into` binding) and
named refusals (`reason MbAbsage { keine_mmap = 1 "…", … }`). The fallback `RAM_END_FALLBACK` from
`bringup.rs` becomes a named refusal branch instead of a silent constant.

#### 5.5 The complete boot theorem, extended

To the three layers (S1 types, S2 references, S3 mapping+probe) comes the fourth line the real
branch demands: **S0 — the zone before the first Gabbro function is generated, not written.** Its
content is the `boot` declaration; its trust is the one emission site plus the token ladder in the
checker; its falsifier is the boot itself (A21) plus the section probe (S3). **And S3 is extended
by the identity teardown:** after `mmu::init_primary` the 1 GiB identity mapping must fall too, not
only `.boot` — the postcondition reads in full:
`!exists m in mappings of kernel_root: m.section == boot || m.identity`.

---

### 6. Acceptance of this third supplement

1. **Catalogue against count:** every axiom A1–A22 has a site in the branch; every counted
   instruction has an axiom or a construct (A12!). An instruction without a line or a line without
   an instruction is an error of this supplement.
2. **The mode ladder as a speech test:** a `boot` block with `write_cr0(PG)` swapped in front of
   `wrmsr_efer(LME)` must break compilation (missing token), the real one must pass.
3. **`entry via int 0x80`** held against `exception::ABI_TO_GPR` — register list identical,
   otherwise §0.1 is copied wrongly.
4. **The precomputed boot tables** byte-identical against what today's trampoline builds at run
   time (a one-off dump probe in QEMU).
5. Inclusion in the repeat measurement P0: the boot stretch and the port-IO sites count too — the
   classes "entry" and "boot" must afterwards carry no hanging plumbing.


---

# Part V — Induction

## Induction — what it needs, and what it costs in usefulness

**2026-08-14.** Following on from the correction in [`BEWEIS.md`](BEWEIS.md): induction is not
impossible but forbidden by three design rules. **What would one need, and what does it cost?**

---

### Three levels, and only the first keeps the language

| | Level | the user writes | the line |
|---|---|---|---|
| **A** | **Generated schemes** — the induction principle follows from the `table` declaration | **nothing new** (or one line, see below) | **holds** |
| **B** | **Recursive `spec fn` with `decreases`** | one descent measure per recursive specification | **migrates** — the specification language gets termination obligations of its own |
| **C** | **Handwritten lemmas** with proof steps | proofs | **gone** — that is Verus/Dafny, and then the honest question would be: why not Verus |

---

### What level A technically needs — three things, two of them mechanical

**1. A well-founded relation out of the declaration.** A `table` with
`parent`/`first_child`/`next_sibling` suggests "is a descendant of". **But it is well-founded only
if the structure is acyclic — and that is the invariant one wants to prove.**

Resolution (standard, not new): the induction runs over a **measure** (number of descendants), and
the invariant is a **precondition**, not a result. So the declaration must **name** which invariant
carries the well-foundedness:

```gabbro
invariant acyclic cost O(n) runs offline: … ;
```

**2. Generate the scheme.** Mechanically, from the declaration — **the way Isabelle and Coq derive
one from a datatype declaration.** It is a **template** in the sense of L3, so it goes **once to
Isabelle** and **shrinks the trust base** instead of enlarging it. *(That is the reason level A
fits into the existing design instead of blowing it apart.)*

**3. APPLY the scheme — and here sits the whole difficulty.** Which scheme, at which variable, with
which generalisation? **That is a heuristic**, and heuristics are the place where automation fails.

---

### The price is not the line count but PREDICTABILITY

**That is the real answer to "how much harder in usefulness".**

If the compiler **guesses** the scheme, "it compiles" hangs on solver luck: **the same program
passes today and not tomorrow**, because a time limit falls differently. Gabbro's whole cut was
the opposite — **M1 to M4 are types, not solvers.**

> **And the crack is already there:** [`MESSUNGEN.md`](MESSUNGEN.md) measured that **M1 is a solver
> at four places**, and [`MESSUNGEN.md`](MESSUNGEN.md) that **54 relational cases** come on top.
> Induction with guessed application **widens** it.

#### The resolution: the scheme is NAMED, not guessed

```gabbro
ensures  descendants(s) is empty
    by   induction on descendants(s)
```

| | |
|---|---|
| **no lemma** | no proof steps, no proof body |
| **no recursive `spec fn`** | the line stays where it is |
| **no guessing** | the compiler chooses nothing; it applies what stands there |
| **falls predictably** | if the named scheme does not discharge the obligation, the error says **which** and **where** — not "unclear" |

**One new word** (`induction`), **one production**, **one line at the user — and only where
induction is necessary.**

---

### What it costs in usefulness, honestly quantified

| | Level A with `by induction on` |
|---|---|
| **Lines** | **1 per proof obligation that needs induction.** How many those are is **unmeasured** — the number comes from the same measurement that is due anyway as the falsifier of the L3 decision (classify 17 logic obligations) |
| **Concepts a user has to learn** | **one**: over which structure the induction runs. He does **not** have to know what an induction principle is — he names a domain he has declared anyway |
| **Predictability** | **preserved**, because named instead of guessed |
| **Trust base** | **shrinks** — the scheme is a template, goes once to Isabelle |
| **What does NOT exist** | induction over anything not declared as a structure; over user-defined recursive functions; over program runs |

**Level B costs more than one line:** whoever writes recursive `spec fn` writes specifications
**with a termination obligation of their own** — a different skill, and the failure modes get more
frequent. **Level C costs the identity of the language.**

---

### The ceiling shifts with it — but not up to Gold

With level A this is reachable: **safety hull + declared invariants + inductive properties over
declared structures.** That covers the measured case (`revoke`'s ordering lemma) and probably
`cdt_wellformed`.

**It does not cover** — and that is the remaining ceiling:

* properties over structures that are **not** declared (the machine state, a pointer-bitfield PTE),
* everything that quantifies over **runs** (liveness),
* functional correctness whose argument does **not** have the form of an induction over a declared
  structure.

- [ ] **The number is missing, and it decides everything:** how many of the 17 measured logic
      obligations would need `by induction on`, how many would manage without, how many would need
      level B or C? **A single case in the last column puts the ceiling back down.**


---

# Part VI — Hard step promises

## Hard promises in the code — and the one condition everything hangs on

**2026-08-14.** The question: can the language **demand promises** of the programmer, so that
induction is no longer guessed but **composed**?

**Answer: yes — but only if the enforced promise is a statement about ONE STEP.**

---

### Why induction is a heuristic today

A solver has to guess three things: **which** scheme, at **which** variable, with **which**
generalisation. `by induction over <domain>` takes the first off it. The other two remain — and
with them "it compiles" stays partly solver luck, which goes against the whole cut (M1–M4 are
types, not solvers).

---

### The decomposition that resolves it

| | Statement | needs induction? | checkable? |
|---|---|---|---|
| **Step promise** | *"`delete_leaf` removes exactly one node and preserves the linkage of the rest"* | **no** — a statement about **one** operation | **yes**, against the **generated** mutation |
| **Overall statement** | *"after `revoke` there are no descendants"* | **yes** | by **composition** of the step promises |

> **If the code MUST make the step promise, the scheme composes the overall statement instead of
> guessing it.** The generalisation is then the invariant (already there), the variable is the
> measure (declared), the scheme comes from the structure. **Nothing is left to guess.**

---

### The form: one line per GENERATED operation, not per call site

```gabbro
table CapSpace {
    slot { … }
    invariant cdt_wellformed  cost O(n) runs online : … ;

    ops insert, remove, relabel, delete_leaf;

    op delete_leaf shrinks descendants by 1 maintains cdt_wellformed;
    op insert      grows   descendants by 1 maintains cdt_wellformed;
    op relabel     keeps   descendants      maintains cdt_wellformed;
}
```

**Four operations, four lines.** Not four per proof obligation, not four per call site.

---

### The condition everything hangs on — and it is sharp

**An enforced promise is either checked or an axiom. There is no third.**

| Case | Consequence |
|---|---|
| **checked** | then it is an **obligation**. If its check itself needed induction, the thing would be **circular** |
| **unchecked** | then it is an **axiom per operation** — and the axiom layer grows from ~130 to one-per-operation. That is abort condition 5 |

**The way out is exactly locality:** a step promise is formulated over **one** operation, and the
operation is **generated** (cut (c)). **The generator knows what it emitted** — it checks the
promise against its own emission, without induction. Neither circular nor an axiom.

> **With that the design rule stands, and it is new:**
> **A promise the code MUST make may only be a statement about ONE step.
> Everything global is proof or axiom — never a promise.**

---

### What it costs

| | |
|---|---|
| **Lines** | **one per generated operation.** For `CapSpace` four. They count as specification (source, deleted before code generation) |
| **New words** | three: `op`, `shrinks`/`grows`/`keeps`, `by` (existing) |
| **Predictability** | **restored** — nothing is guessed, so "it compiles" no longer hangs on the solver |
| **Trust base** | **unchanged** — the promise is checked, not believed |

---

### What it does NOT do — otherwise it would be overreach number eighteen

**It does not raise the ceiling.** What stays reachable is: *properties that can be proven by
well-founded descent over a **declared** structure.* What does not have that form does not have it
with promises either:

* properties over **undeclared** structures (machine state),
* everything that quantifies over **runs** (liveness, D8),
* functional correctness whose argument is **not a descent** (the IPC fastpath: a statement about
  **values**, not about a shrinking set).

> **The gain is not height but certainty of arrival:** the ceiling is reached **automatically**
> instead of heuristically. That is less than the question hopes for — and more than the present
> state has.

- [ ] **The number is still missing, and it is the same one:** how many of the 17 measured logic
      obligations are **descent statements** (then this bites), how many are **value statements**
      (then not)? **Without that split this design too is a claim.**


---

# Part VII — The inversion of the question

## The inversion of the question — every "not possible" becomes "what must minimally stand there"

**2026-08-13.** Both paper tests asked *"is that possible?"* and reported holes. **The question was
wrong.** Gabbro is a very narrow language that is allowed to be hard; the right question reads:

> **What must the code MINIMALLY specify for it to work — and can that be lowered to C?**

Both are conditions. A clause that cannot be lowered is no answer.

**That holds for all of Gabbro, not only for loops.** Below stands the complete conversion of all
eighteen "not possible" findings from both reports.

---

### The case in which the inversion shows most clearly: loops

**Reported was:** *"CAS/wait loops: no solution. No descent measure, `divergent` is wrong."*

**That is true for `variant` and is the wrong question.** A wait loop is not measureless — it is
bounded by **conditions on its environment**, and those can be written down:

```gabbro
retry until slot_free(q)
    bounded    4096 attempts        -- oder: 2 ticks
    progress   assume holder_releases
    on_exceeded EP_FULL             -- benannte Absage, kein stiller Abbruch
    effects    { reads q }
{ }
```

| Clause | for what | lowering to C |
|---|---|---|
| `bounded` | termination — **a number, not a descent measure** | counting loop `for(i=0;i<N;i++)` |
| `progress` | **who** ends the loop: a liveness assumption with a falsifier | disappears (ghost) |
| `on_exceeded` | rule 3: the overrun is **named**, not interpreted | `break` into the error branch |

**Minimal: three lines.** And Caprock writes them **by hand** today at every bounded loop
(`cdt_step_limit`, `note_overrun`, `ERR_EP_FULL`) — the language makes obligatory what the project
does anyway, and catches the places where it was forgotten (`migration_candidate`).

**The ticket lock** is the same case: it terminates because the holder releases. That is an
assumption about the environment — so `assume` with a falsifier (the watchdog **is** the
falsifier), plus a bound whose overrun is a finding. **Not "unprovable" but "provable under a
named, falsifiable assumption".**

---

### The complete conversion

| # | reported as "not possible" | **what must minimally stand there** | lowering |
|---|---|---|---|
| 1 | CAS/wait loops | `bounded` + `progress assume` + `on_exceeded` — **3 lines** | counting loop + error branch |
| 2 | **ELF is not a `format`** (offset-based) | `e_phoff : u64 offset_into Self where + e_phentsize*e_phnum <= Self.len` — **1 attribute + 1 `where`** | range check |
| 3 | `caprock-fat` only half a `format` | `traverse over chain(fat, cluster) by unvisited` + refusal `Zyklus` — **2 lines** | loop + generation stamp |
| 4 | `move_cap` — node relabelling | generated mutation `relabel` with **1 `maintains`** | pointer rehanging |
| 5 | `install` — state without a name | `linear Uninstalled(Object)`, consumed only by `alloc_slot` — **1 type** | **disappears** |
| 6 | `Finalized<'a>` — no lifetimes | right `own` + `Duty` — **1 rights clause** | disappears |
| 7 | **fastpath authority** ("may this thread write here?") | `linear ghost MayWrite(t, f)`, produced by the cap resolution — **1 witness + 1 `requires`** | **disappears** |
| 8 | report harness needs formatting | **the `measures` list IS the report line** — 0 additional lines | generated `printf` |
| 9 | relation between two layouts (the lost `US`) | `maintains` **over two declarations**: splitting preserves the rights bits — **1 line** | none |
| 10 | no sum type (13 `ObjectKind` variants) | `tagged` — declaration | C union with a tag |
| 11 | **no `old`** | `ensures old(x) + 1 == x` — **1 keyword** | disappears |
| 12 | `maintains` knows no opening/closing | `breaking I { … }` — the scope in which the invariant rests is **named** | none |
| 13 | `fields` only single bits, no runtime offsets | bit range `FRO @[12:8]`; base `@ base + CAP.FRO*16`, M1-bounded | address arithmetic |
| 14 | 2 231 atomics, zero words | `atomic` + `publishes { … }` — **1 clause per atomic** | `_Atomic` + barrier |
| 15 | **`device` does not kill trap 4** | `transition` names **the whole written word**, not one bit — RMW thereby becomes unformulable | one `store` |
| 16 | `effects` is fail-open | `effects` **obligatory**; empty means pure and is **checked** — 0 lines for correct code | none |
| 17 | register bank at a runtime-computed base | parameterised `device Bank(base: Pa)` | address arithmetic |
| 18 | conditional compilation (335 `cfg` sites) | `when <const>` at the declaration | `#if` |

---

### The finding that arises while converting

**Six of the eighteen fall to THE SAME mechanism: the linear ghost witness (M2).** Numbers 5, 6, 7
— plus the boot phase, the virtio `used`/`avail` ownership and the `check` obligation.

> **Six independent sites for one mechanism are no longer a design wish but a finding.** And it is
> exactly the mechanism **no existing tool delivers**: Verus' `tracked` is affine, Rust is affine,
> SPARK's leak check hangs on an allocation.

**The second number: the median of the additional clause lies at one to two lines per site.** None
of them is a lemma, none a loop invariant — they are **declarations**. That is the difference that
matters for the metric.

---

### What that does NOT mean — otherwise it is overreach no. 14

* **The 2 : 1 measurement does not get better through it.** The lines called "minimal" here are
  exactly the ones the counter counts. What changes is their **character**: declaration instead of
  proof — and whether a solver discharges the obligations arising from them **without hints** is
  **unchecked**.
* **Paper, not compiler.** Eighteen conversions on paper are eighteen claims about lowerability.
  None of them has been compiled.
* **Two stay uncomfortable.** No. 12 (`breaking`) legalises a violation of an invariant — the price
  is that the scope in which nothing holds becomes visible instead of hidden. And no. 14 demands a
  clause at **2 231** sites; whether that carries is decided by no paper exercise.

---

### The consequence for the method

- [ ] **No check assignment asks "is that possible?" any more.** It asks: *"what must minimally
      stand there, and can it be lowered to C?"* A report that reports a hole without naming the
      minimal clause is incomplete — **it broke off the work at the point where it begins.**

---

## The cut for declared functions in domains (2026-08-16)

**The question «B41» posed:** may a domain run over a *declared function* —
`traverse … over chain via f` —, or is that **quantifier stock through the back door**, i.e. the
place at which the boundary between language and prover migrates?

**The precedent has stood in the language all along:** the `update` body of `exchange` is **pure,
M1-typed, over a value, without a quantifier** — and nobody has ever taken it for quantifier stock.

> **The cut: quantifier stock begins where the function appears in STATEMENTS instead of in
> DOMAIN GENERATION.**
>
> A function that **takes a value and delivers an `option` value without touching the world** is a
> *declared step*. It delivers witnesses. As soon as the same function stands in a `requires`, an
> `invariant` or an `ensures`, one quantifies over it — and **there, not earlier, does the line
> migrate.**

**What the cut costs and what it brings in:** it is a rule over the *use*, not over the
declaration — so the checker has to know both places. **It brings in:** the chain domain over an
edge function swallows `ancestors of` (the same edge, the other direction is a different `f`), and
three measured domain gaps become **one design line**.
