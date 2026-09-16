# Gabbro — the syntax

**The source for the surface, and since 2026-09-09 the source for the proof.**
[`SPRACHE.md`](SPRACHE.md) says which mechanisms there are and why; [`BEWEIS.md`](BEWEIS.md),
what they are there for; here stands how one writes them down — **and what every spelling
has to carry so that it may be written at all.** What does not stand here is not writable.

Third version, 2026-09-09. The second version (2026-08-13 … 2026-09-05) is in the `git`
history of this file; nothing of its surface was removed, every production of it stands below.
What is new is that **every production carries its attributes** — the range at a number, the
bound at an index, the held witness at a guarded place, the write right at an assignment, the
consumed mark at a call, the rank at a `locks`, the stage at a phase mark, the class at a
register access, the pairing at a publication. A sentence of this grammar is a derivation whose
attributes are satisfied. With that reading the sentence at the head of the second version —

> **What every rule of this grammar has to achieve:** discharge one **plumbing** obligation by
> construction — index, overflow, alias, frame, lock, race, refinement. If one of them stays
> hanging on the programmer, that is **a refutation** at that point, not a blemish.
> **Logic** the programmer writes anyway, in every language.

— is no longer a demand on the rules but a **theorem about them**: the attributed grammar is a
typed inductive family in [`grammatik/Grammatik/Syntax.lean`](../grammatik/Grammatik/Syntax.lean),
its meaning a **total** function in `Semantik.lean`, and the outcome type of that function has
exactly two error constructors — `logik` (a clause the writer wrote does not hold) and
`hardware` (an assumption about the machine does not hold). `Satz.lean` states it as
`zwei_fehler`, and §16 below lists what the theorem does **not** say.

> **Marks in this file.** `NEW «SG-n»` is a production, attribute or word that the second
> version did not have. `CHANGED «SG-n»` is a production of the second version with an attribute
> it did not carry, or a stricter form. `SUGAR` is a spelling of the second version that stays
> writable and rewrites to the attributed form — nothing written against the second version
> becomes unwritable through a `SUGAR` mark. Unmarked productions are unchanged. Every
> production names the Lean constructor that carries it (`Lean:`), or says that it is
> declaration-level (`Deklaration`) or sugar. «SG-n» numbers continue the numbering of
> `PLAN-GRAMMATIK.md`.

---

## State — measured

| | second version | **this one** |
|---|---|---|
| defined EBNF rules | 132 | **177** measured (`pruefe-syntax.sh` EBNF branch: 177 defined, 0 open, 0 unreachable from `program`) — new since the second version: `endblock`, `endstmt`, `matcharm`, `stateassign`, `advstmt`, `countexpr`, `concurrentdecl` («SG-23»), `libcall`, `libregion` (lane E1); `syscalldecl`, `errmap`, `nonzero`, `uint` («SS-1», §12.1); `translatordecl` («E3», §7.2); `constwert`, `arraylit` (lane 111); `arena`, `allocstmt`, `resetstmt` («E4», §9.1); `profiledecl`, `requiresprofile`, `profileentry` («E6», §12.2); `carrier` (lane 140, §10); lane 88 widened the operator arms inside the same three expression rules (`<<%`, `+%`, `-%`, `+%|` saturating, `*%`); nothing removed |
| used but never defined | 0 | **0** (measured same run) |
| vocabulary words | 221 | **240 table words + 4 Sonderformen** measured (`pruefe-wortschatz.py`: 240 EBNF terminals against 240 table words, both readings) — new words since the second version: `owner` («SG-9»), `deadline` («SG-22»), `concurrent` («SG-23»), `syscall` + `abi` + `number` + `errors` + `kernel` («SS-1», §12.1, checked since lane S5, emission refused as `C001` until S6), `library` + `payload` («E2», §7.1), `translator` + `for` («E3», §7.2), `arena` + `capacity` + `alloc` + `reset` («E4», §9.1), `profile` + `rounding` + `fp_contract` + `memory_model` + `interrupt_routing` («E6», §12.2), `depends` (lane 140, §10) |
| productions without an attribute reading | all | **0** — every production names its constructor or its sugar |
| formalised in Lean | — | **the whole surface**: `Syntax.lean` 4 mutual families, `Semantik.lean` total with a trace, `Satz.lean` frame + trace in one induction, `Wettlauf.lean` race freedom over interleavings, `Zucker.lean` every sugar as a definition, `Ziel.lean` the goal as theorems over the grammar alone — 0 `sorry`, axioms `propext`/`Classical.choice`/`Quot.sound` only |
| **Guardian** | `pruefe-syntax.sh` — closure of the rules, reachability from `program`, terminals covered by the vocabulary | unchanged; the attribute comments are EBNF comments, so it reads the same grammar |

> **Partly run on 2026-09-09.** The EBNF-closure branch of `pruefe-syntax.sh`
> (161 rules, 0 open) and `pruefe-wortschatz.py` (221/221 both readings, speech
> test green) ran from this workstation; the full `pruefe-syntax.sh` (it builds
> with `cargo build --tests`), `pruefe-grammatiktafel.py` and the parser item of
> `PLAN-GRAMMATIK.md` §4 are still open. A number in this table that a guardian
> contradicts is wrong here, not there.

---

## Six decisions that fix everything else

| | Decision | Reason |
|---|---|---|
| **E1** | **English keywords, German running text, free identifiers** | Caprock's own practice. The vocabulary is a **closed table**; a swap costs the lexer |
| **E2** | **Statement-oriented, assignment is NOT an expression** | `if (x = y)` is not writable; the evaluation order stays visible |
| **E3** | **Nothing is implicit** — no conversion, no copy of a linear value, no catch-all branch, no default value | each of the four classes has a paid-for trap. The single exception is the widening of a range («SG-1»), and it is written as an attribute, not as a conversion |
| **E4** | **Contracts stand BEFORE the body, in a fixed order** | a tool that has to sort cannot say "`effects` is missing here" |
| **E5** | **Every declaration is complete at exactly one place** | no preprocessor, no forward declaration |
| **E6** | **Every attribute is part of the production** — NEW «SG-0» | a rule that a pass checks after the fact can be forgotten by the pass; a rule that is the shape of the derivation cannot. `GRAMMATIK-VOLLSTAENDIG-2026-09-08.md` §1.4 found an obligation that vanished on a rename; under E6 it has no place to vanish from |

> **`obligation` is NOT a source word.** It stands in the **obligation manifest**, i.e. in the
> **artefact**. The vocabulary here is that of the **source**.

> **Writing rule for these files:** `Backticks` denote **today's Gabbro syntax**. An
> abolished name stands *in italics in quotation marks* — it **is** no longer syntax.

---

## Vocabulary — closed, 243 words

```
  Struktur   module pub use type opaque linear ghost tagged const static fn
             spec impl raw divergent prim extern section arch when
  Vertraege  requires ensures maintains refines breaking effects costs where in
              exhaustive old narrow to induction order advances retires deadline
  Wirkungen  reads writes locks masks allocs consumes publishes diverges pure
  Ablauf     if else match traverse over by touches retry forever until
             bounded progress on_exceeded per_pass return let mut
             unvisited consuming leave leaves next ops result
             exchange update returns insert remove relabel
  Zeiger     ptr normal mmio dma code boot r w rw x own
  Bibliothek format table slot invariant reason state transition device reg
             class fields bank at stride count backed mirrors from depends owner
             assume falsifier unfalsifiable axiom lock protects rank group concurrent rcu observes reclaims
             check claim measures gates can_fail floor counterprobe expects
             endian little big reserved cost runs online offline
             library payload translator for
             profile rounding fp_contract memory_model interrupt_routing
             arena capacity alloc reset
             offset_into index into option chain wrapping
             atomic acquire release seq relaxed nothing accumulates merge decreases
             max min add or and held protects rank shared
             embeds scale walk levels node down leaf mappings
             entry entrust vector regs out preserves clobbers stack dispatch asm
             per cpu ist nested masked awaits port step via
  Fremdkoerper syscall abi number errors kernel
  Domaenen   slots of chain descendants ancestors queue elems fields threads
             reaches via tree parent child sibling observed occupied
  Typen      u8 u16 u32 u64 i8 i16 i32 i64 f32 f64 rounded finite bool never w1c rc
  Eingebaut  sizeof lenof aligned forall exists true false Self Some None
  Sonderform O @version Held TESTBUILD    (NOT vocabulary words -- see footnote G6)
```

**Everything else is an identifier.** A new word is a language change and needs an entry here.
**`owner` is the one new word of the third version** («SG-9», §9): it names the linear mark
that guards a table. The alternative — `protects` with a mark instead of a lock — would make
one word mean two things, the trap class `HISTORIE.md` books under `reserved`.

### And a word of the table is a keyword only where the grammar EXPECTS one

**Set 2026-09-05, `messung/WORTSTELLUNG.md`, unchanged.** At every position where the grammar
writes `ident`, every word of this table is a name. Three positions admit both a keyword
production and a name, and each is decided by the grammar and not by a list:

1. **the head of a `stmt`** — a word followed by `=` `+=` `-=` `&=` `|=` `.` `->` `[` `::` is a
   **place**, because no keyword statement may continue that way;
2. **`old` and `result`** — words inside a contract clause, names everywhere else;
3. **a named `typeexpr` and a named `space`** — the keyword arms stand above the name arm.

**Seventeen of the 243 are still not names** (recounted 2026-09-14, lane 188:
`instrumente/zaehle-wortschatz.py` reads 243 words, 17 reserved, 226 contextual;
`instrumente/pruefe-wortschatz.py` reads 240 EBNF terminals against 240 table words --
the three over are `r` `w` `x`, single letters both sides drop by construction).
Every one of the seventeen has **zero** declarator sites in 585 foreign files, and every
one names below the position that forces it -- a use-site occurrence always parses as
the keyword form, so a variable of that name could be bound and never read back:

```
  word       forcing position (keyword arm above the name path, parse.rs)
  sizeof     primary `sizeof(place)`                                          :2087
  lenof      primary `lenof(place)`                                           :2087
  aligned    primary `aligned(place, n)`                                      :2103
  forall     quantifier `forall(x in ...)`                                    :2712
  exists     quantifier `exists(x in ...)`                                    :2712
  true       boolean literal                                                  :2052
  false      boolean literal                                                  :2059
  Self       Self-path primary, `Self.slots[s]` place                        :1126 :2125
  Some       option constructor primary and pattern                          :1958 :3929
  None       option nil primary and pattern                                  :1958 :3929
  const      item head `const N : T = ...`, one word before `const fn`       :710 :713
  static     item head `static ...`                                           :714
  extern     function-class head `extern fn`                                 :2919
  if         statement head and if-expression                                :3532
  else       else-branch after `}`                                            :3663
  return     statement head `return expr ;`                                   :3594
  bool       type keyword arm above the named-type arm                       :1102
```

Ten head an expression or a predicate unconditionally; seven break the emitted C as an
ordinary local (`uint32_t <word> = 1; return <word>;` through
`cc -std=c11 -Wall -Wextra -Werror` -- `const` `static` `extern` `if` `else` `return`
`bool`, measured 2026-09-05). The Lean side pins the same seventeen in
`grammatik/Grammatik/Parser/WortStellung.lean` (`reserviertTafel`, with a theorem per
row above: the twelve place-refusals, the five expression heads, the seven C names).

Every word that arrived after 2026-09-05 arrived contextual -- `syscall` `abi` `number`
`errors` `kernel`, `arena` `capacity` `alloc` `reset`, `profile` `rounding` `fp_contract`
`memory_model` `interrupt_routing`, `translator` `for`, `payload`, `depends` -- and
`crates/gabbro-syntax/tests/wortschatz.rs` binds every one of the 243 as a parameter
and as a local, requiring clean exactly for the 226. No word freed since stands
unread: freeing one of the seventeen buys zero foreign sites and breaks either a read
or the C, so the residue is irreducible by measurement, not by taste.

---

## Lexis

```ebnf
ident      = ( letter | "_" ) { letter | digit | "_" } ;
letter     = "a" … "z" | "A" … "Z" | "ä" | "ö" | "ü" | "Ä" | "Ö" | "Ü" | "ß" ;
digit      = "0" … "9" ;
hexdigit   = digit | "a" … "f" | "A" … "F" ;
int        = dec | hex | bin ;
dec        = digit { digit | "_" } ;
hex        = "0x" hexdigit { hexdigit | "_" } ;
bin        = "0b" ( "0" | "1" ) { "0" | "1" | "_" } ;
float      = dec "." dec [ "e" [ "+" | "-" ] dec ] ;           (* «F» *)
(* Maximal munch: `..` eats first, so `1..5` is a range and `1.5` a float. `1.` is refused.
   Only lower-case `e` in the exponent; `0X`/`0B` are refused (`L004`) -- one spelling. *)
string     = quote { char } quote { quote { char } quote } ;   (* «B22» *)
char       = ? any character except quote and newline ? ;
quote      = ? the character U+0022 ? ;
newline    = ? end of line ? ;
comment    = "--" { char } newline ;
path       = pathseg { "::" pathseg } ;                        (* G5 *)
pathseg    = ident | "u8" | "u16" | "u32" | "u64" | "i8" | "i16" | "i32" | "i64"
           | uint | int | opname ;
(* `u64::max` -- both segments are vocabulary words. `opname` as a segment is the call form
   of a generated table operation (`T::insert`, `messung/OPS-RUFFORM.md`). *)
identlist  = ident { "," ident } ;
regbind    = ident ":" ident ;                                 (* G4 *)
```

**One comma rule for all lists:** separating comma between the entries, trailing comma
optional. **The `Sonderform` line (G6):** `O` (in `costexpr`), `@version` (in `format`), `Held`
(in `heldpred`) and `TESTBUILD` (in `buildgate`) are terminals of the grammar but not words of
the vocabulary — identifiers in a fixed position, counted and named by the guardian.

**The `Fremdkoerper` row (G6b):** `syscall`, `abi`, `number`, `errors` and `kernel` are
words of the vocabulary AND terminals the lexer knows (`kw.rs`, «SS-1»); the EBNF
side carries them through `syscalldecl`, and a `syscall` item has been checked
since lane S5 (`N063`-`N068`, `A005`/`A006`; emission refused as `C001` until the
lane-S6 stub lands). `entry syscall …` keeps parsing: the
entry name is an identifier, and `syscall` as a `ctx` word stays one there.

**The surface of Gabbro is English** (decided 2026-08-19): keywords, refusal messages, the
reports, the vocabulary table. German stays in the working documents of the folder, in source
comments and in every identifier a *user* chooses.

Strings only in `claim`, `reason`, `assume`, `retires … unfalsifiable`, `section` and `asm`.

*Lean:* the lexis has no constructor. A Lean term is a **tree**, and a tree has no tokens; the
map from the token stream to the tree is the parser, and `PLAN-GRAMMATIK.md` §4 says when it
exists. Nothing in the theorem depends on it.

---

## 1. Program, modules, constants

```ebnf
program    = { item } ;
item       = [ buildgate ]
             ( moduledecl | usedecl | typedecl | constdecl | staticdecl | fndecl
             | format | table | arena | reason | state | device | assume | axiom | check
             | atomicdecl | lockdecl | rcudecl | gruppedecl | concurrentdecl | accdecl | walkdecl | entrydecl | entrustdecl
             | bootdecl | syscalldecl | translatordecl | profiledecl | requiresprofile ) ;
buildgate  = "when" "TESTBUILD" ;                              (* «TB» *)
(* The build gate: `gabbro emit --testbuild` opens it, its absence is the shipping build, and a
   gated item then produces NO line of C. `G001` holds the one direction that breaks (ungated
   code calling a gated function), `G002` refuses any other condition, `G003` refuses the name
   as a declaration. `TESTBUILD` is a G6 identifier in fixed position. *)
bootdecl   = "boot" ident "arch" ident "{"
               { bootstep }
               "dispatch" path ";"
             "}" ;
bootstep   = "step" ( call | ident "=" constexpr ) ";" ;
entrydecl  = "entry" ident [ "vector" constexpr ] [ "via" ident ] "arch" ident "{"
               "regs" "in"  "{" [ regbind { "," regbind } [ "," ] ] "}"
               "regs" "out" "{" [ regbind { "," regbind } [ "," ] ] "}"   (* G4 *)
               "preserves" "{" [ identlist ] "}"
               "clobbers"  "{" [ identlist ] "}"                (* G7: empty allowed *)
               entryextra
               "dispatch" path ";"
             "}" ;
entrustdecl = "entrust" ident "at" ident "arch" ident "{"
                "regs" "in" "{" [ regbind { "," regbind } [ "," ] ] "}"
                "stack"  ident
                "assume" ident ";"
              "}" ;
(* `entrust` -- the room whose CONTENT Gabbro does not know. Gabbro says nothing about the
   guest; what it says is the CONTRACT AT ENTRY. `at` takes a NAME (`N006`): a jump to a
   computed address is exactly what must not be nameable. `assume` is compulsory and must be
   falsifiable (`N004`/`N005`), the same rule as `progress`. *)
entryextra = "stack" ident [ "per" "cpu" ] [ "ist" constexpr ]
             [ "nested" ( "never" | "masked" | "bounded" constexpr ) ] ;
(* Checked since lane S5 («SS-1», §12.1): the user side of a
   system call. The checker holds the declaration against its own shape
   (`N063`-`N068`, `A005`/`A006`) and refuses the emission as `C001` until
   the lane-S6 stub lands;
   the grammar below is the surface the checker, the emitter ruling and the corpus
   example (§12.1) are written against. *)
syscalldecl = "syscall" ident "(" [ params ] ")" [ "->" typeexpr ] [ "or" ident ]
              "abi" ident "arch" ident "number" constexpr
              "regs" "in"  "{" [ regbind { "," regbind } [ "," ] ] "}"
              "regs" "out" "{" [ regbind { "," regbind } [ "," ] ] "}"
              "clobbers" "{" [ identlist ] "}"
              "errors"   "{" [ errmap { "," errmap } [ "," ] ] "}"
              [ "requires" predlist ]
              [ "ensures"  predlist ]
              "effects" "{" efflist "}"
              ( "assume" ident ( "falsifier" ident | "unfalsifiable" string ) ";"
              | "kernel" path ";" ) ;
errmap     = ident "=>" ident ;
accdecl    = "accumulates" ident ":" typeexpr
             "merge" ( "max" | "min" | "add" | "or" | "and" )
             [ "per" "cpu" constexpr ] ";" ;
(* `per cpu N` is the CELL COUNT, optional in the grammar and compulsory for lowering. The
   current core is a machine question, a foreign body (`gabbro_kern()`), not an expression. *)
moduledecl = [ "pub" ] "module" path "{" { item } "}" ;
usedecl    = [ "pub" ] "use" path ";" ;
constdecl  = [ "pub" ] "const" ident ":" typeexpr "=" constwert ";" ;
constexpr  = expr ;                    (* evaluable at translation time; no call of a function
                                          with effects, no place on `mut` *)
constwert  = constexpr | arraylit ;
(* CHANGED lane 111: a const-table literal. It stands ONLY as a `const`
   initializer of array type (`const T : [u32; N] = […]`); the general
   expression reader never reads `[`, so anywhere else it is `P011` by
   grammar shape. The checker holds it element-wise (`K190`-`K194`); the
   emitter writes one `static const` array.
   CHANGED lane 170: rows may nest (`const T : [[u32; 2]; 2] = [[1, 2],
   [3, 4]]`). An `expr` never reads `[`, so a leading `[` is unambiguously
   a row; the checker holds each row against its dimension (`N285`/`N286`)
   and the emitter writes one multi-dimensional `static const` array. *)
arraylit   = "[" [ ( arraylit | expr ) { "," ( arraylit | expr ) } [ "," ] ] "]" ;
staticdecl = [ "pub" ] "static" [ "mut" ] ident ":" typeexpr "=" expr
             [ "section" string ] [ "shared" ] ";"                  (* CHANGED «SG-21» *) ;
```

**Attributes and Lean.** Everything in this section is **declaration-level**: it fixes the
world before the first body and has no run-time meaning of its own.

| production | reading | Lean |
|---|---|---|
| `program`, `moduledecl`, `usedecl` | names are static; a module is a namespace, not a construct | `Deklaration` — one per translation unit |
| `constdecl` | a `const` is a **literal** at every use | `Expr.lit n : Expr Γ Λ (.int n n)` |
| `constdecl` of array type (`arraylit`, lane 111) | a const table is its **folded elements** at every use; the count is the declared one (`K191`), each element lies in the element type (`K194`) | no constructor — checker-evaluated (`konstanten.rs`); the certificate is the `List.all` predicate `konstZert` (`Konstanten.lean`) |
| `staticdecl` | a `static` is a **global carrier** with its guards (§11) | `D.Glob`, `D.gtyp`, `D.gbraucht` |
| `bootdecl`, `entrydecl`, `entrustdecl` | a foreign body with a contract: what enters, what leaves, what it clobbers | `D.Ax` — an axiom with `aparams`, `aerg`, `aschreibt` («SG-18») |
| `syscalldecl` (§12.1) | **checked since lane S5** — the user side of a system call: ABI binding, generated errno decoding, ghost OS state, assumption or kernel pairing | `D.Ax` with `sysabi` — number, register map, clobbers consumed by the emitter; the answer type is the `ok value | reason r` sum, `einpassen` holds the raw answer against it |
| `accdecl` | a global plus a **generated** assignment `A = merge(A, v)` | `D.Glob` + `Stmt.assignGlob` (SUGAR) |
| `buildgate` | a filter on the item list; the theorem is about the items that are there | none |

> **What `entry … dispatch` does NOT carry — named in §16.** The contract says what a foreign
> body may write; it does not say **when** it runs. A handler that interrupts a body holding a
> lock is a statement about two bodies at once, and the meaning in `Semantik.lean` is of one
> body at a time. `H013`/`H102` remain passes over the declaration, not attributes.

---

## 2. Types — M1, D1, D2

```ebnf
typedecl   = [ "pub" ] [ "opaque" ] [ "linear" [ "ghost" ] ] [ "tagged" ]
             "type" ident [ "(" typelist ")" ] [ markorder ] [ "=" typeexpr ] ";" ;
markorder  = "order" "{" identlist "}" ;
(* «B37»: the stages of a linear mark, in ONE declaration. `order` stands before the `=`
   because it is not a body: an order says which steps are admissible on the value. *)
typeexpr   = intty | floatty | boolty | nevertype | path | array | ptrty | structty | fnptr | variants
            | indexty ;
(* NO general `option T` («SG-26», §18): over `index into T` it is the
   carrier's index option («SG-4»); over any other `T` the writer spells the
   two-case `tagged` sum themselves — `match` over it is exhaustive by shape,
   so nothing is lost and no constructor is added for what a declaration
   already says. *)
indexty    = [ "option" ] "index" "into" ident ;
(* The GENERATED index type of a table: `0 ..< count`. It stands as a `typeexpr` because it
   must be nameable in a signature -- otherwise the bound would again be a hand-written type
   beside the table. *)
nevertype  = "never" ;                             (* return type of prim/divergent *)
intty      = ( "u8"|"u16"|"u32"|"u64"|"i8"|"i16"|"i32"|"i64" | uint | int ) [ "in" range ] ;
uint       = "u" nonzero ;                             (* 1 .. 64, storage is the next standard width *)
int        = "i" nonzero ;                             (* 1 .. 64, storage is the next standard width *)
nonzero    = "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" |
             "1" digit | "2" digit | "3" digit | "4" digit | "5" digit | "6" digit ;
(* CHANGED «SG-1»: in the core EVERY integer type carries its range. `u32` without `in` is
   SUGAR for `u32 in 0 .. u32::max`, `i32` for `i32 in i32::min .. i32::max`; a `wrapping`
   field (§9) is the one place where the width and not the range is the type.
   `uN`/`iN` (PLAN-BITS §1): SUGAR for the next standard storage width plus the exact
   range — `u13` is `u16 in 0 .. 8191`, `i37` is `i64 in -2^36 .. 2^36 - 1`;
   `u0`, `u65`, `i0` and wider are refused (`P008`). The eight standard words keep
   their full-width meaning exactly. The emitted C uses the storage width, never
   `_BitInt`; a packed table field of type `u13` occupies exactly 13 bits. *)
floatty    = ( "f32" | "f64" ) [ "in" frange ] ;                    (* «F» *)
frange     = fexpr ( ".." | "..=" | "..<" ) fexpr ;
fexpr      = float [ "rounded" ] | ident | int ;
(* «F» -- f32 and f64. `rounded` is COMPULSORY at a literal that is not exactly representable,
   and the only form there. `finite` stands only behind `narrow … to` and establishes
   not-NaN-ness. CHANGED «SG-17»: in the core a float type ALWAYS carries a range, and every
   value of it is finite and inside -- `f64` without `in` is SUGAR for the widest finite range
   of the width. *)
boolty     = "bool" ;
range      = expr ".." expr | expr "..<" expr ;
array      = "[" typeexpr ";" constexpr "]" ;
(* NO variable-length tail («SG-27», §18): a runtime length is a value the
   declaration does not know, and a bound the declaration does not know is a
   hand-threaded check at every access — manual plumbing. What is writable is
   `backed k` plus `narrow i to 0 ..< k` before the access (§9): one entry
   check, then every access carries the bound as an attribute. *)
structty   = "{" { field } "}" ;
field      = ident ":" fieldty [ "@" bitpos ] [ "offset_into" ( ident | "Self" ) ]
             [ "where" pred ] [ "reserved" ] "," ;
fieldty    = typeexpr
           | typeexpr "embeds" "[" int ":" int "]" [ "scale" constexpr ] ;
bitpos     = int | "[" int ":" int "]" ;
variants   = "{" ident [ "(" typeexpr ")" ] { "," ident [ "(" typeexpr ")" ] } "}" ;
fnptr      = "fn" "(" [ fnptrparams ] ")" [ "->" typeexpr ] fncontract ;
(* «B8»: a function pointer type CARRIES ITS CONTRACT, because at an indirect call there is no
   name to resolve -- what is known about the callee is the promise at the type. *)
(* Lane 177 -- REFINEMENT DIRECTION, and it is the content, not a convention: a function `f`
   assigned to or passed as this type owes `requires_type ⇒ requires_f` (CONTRAVARIANT --
   `f` accepts at least what the type promises callers may pass) and `ensures_f ⇒
   ensures_type` (COVARIANT -- `f` delivers at least what the type promises). The wrong
   direction is unsound and easy to build by accident: `beispiele/gift/957`-`958` fail if
   it swaps. Effects (`⊆`), costs (`<=`), arity and signature are decided by the checker
   (`M128`/`M142`); the two implications are the user's logic (kind `C`). *)
fncontract = [ "requires" predlist ] [ "ensures" predlist ]
             "effects" "{" efflist "}" "costs" "<=" expr "ops" ;
typelist   = typeexpr { "," typeexpr } ;
params     = ident ":" typeexpr { "," ident ":" typeexpr } ;
fnptrparams = fnptrparam { "," fnptrparam } ;
fnptrparam  = [ ident ":" ] typeexpr ;
(* The name in a pointer type is optional: all 11 pointer-type sites in Caprock write none. *)
```

```gabbro
opaque type Pa   = u64;
opaque type Iova = u64;
type SlotIdx  = u32 in 0 ..< NSLOTS;
type Refcount = u32 in 0 .. 0xFFFF_FFFF;
type Cycles   = u64 in 1 .. u64::max;

tagged type ObjectKind = { Untyped(Region), Endpoint(EpId), Frame(Pa), Cnode(SlotIdx) };

linear type Parked;
linear type Uninstalled(ObjectId);
linear ghost type Held(Lock);
linear ghost type BootPhase order { roh, mmu, geraete };
linear ghost type MayWrite(ThreadId, Pa);
linear ghost type Duty(farbtest);   -- the parameter is the NAME of a `check` declaration
```

**Attributes and Lean.**

| production | attribute | Lean |
|---|---|---|
| `intty` with `in lo .. hi` | a value **is** a number with its two bound proofs; a value outside its range is not constructible | `Ty.int lo hi`, `Wert D (.int lo hi) = Zahl lo hi` |
| `indexty` | `0 ..< count` of the named table; `option` adds `None` | `Ty.index n := .int 0 (n-1)`, `Ty.opt n`, value `Option (Zahl 0 (n-1))` — CHANGED «SG-4» (the second version's `option` had no range) |
| `floatty` with `in` | a value is a machine float **with proofs** that it is finite and inside the range | `Ty.fl lo hi`, `Gleit lo hi` («SG-17») |
| `boolty` | | `Ty.bool` |
| `nevertype` | the type without a value: a body `-> never` can derive **no** `return` | `Ty.never`, `Wert D .never = Empty` («SG-18») |
| `variants` (`tagged`) | a case index **and** its payload, no other shape | `Ty.sum cases`, value `Σ i, Nutzlast (cases.get i)` |
| `reason` values (§9) | one of `n` declared grounds | `Ty.grund n`, value `Fin n` |
| `fnptr` | the value is a function **of exactly this signature** — the proof travels with the value | `Ty.fnptr sig`, value `{f // D.sig f = sig}` («SG-8») |
| `ptrty` (§3) | a capability naming a declared carrier and a right | `Ty.ptr tab rw` |
| `linear type m [order]` | a resource in the context Λ, with a stage | `D.Marke`, `D.stufen`, `Res.marke m stufe` («SG-14») |
| `structty`, `array`, `path` to a type | a compound is a **table with `count 1`** (a record) or `count N` (an array): the field is a slot field, the element index an index type | `D.Tab` with `count`, `Feld`, `typ` — SUGAR over §9 |
| a record as a **VALUE** (`-> P`, `p : P`, `let x : P`, `P(a: …)` «B7») | **NO `Ty`, and that is named and priced, not an oversight.** The row above is the CARRIER lowering; it does not make a record a value. The list in this table is complete: there is no product former, so a result, a parameter or a `let` of record type has no form at all — `gabbro lean-g` refuses each by name (`LG002`) and says which carrier form does work (`ptr<normal, r> P`) | **none.** `OFFEN.md` `O15`: a `Ty.prod` was priced on 2026-09-15 and REFUSED — measured over all 113 corpus programs, it gains **zero**; what pays first is the `Endblock` binder (`O14` (2)) and the C side of aggregate values, which `Ty.sum` already owes |
| `opaque` | no operation but equality and passing — a range `n .. n`-free `int` with no arithmetic derivable *(by absence of a constructor, not by a rule)* | `Ty.int` without `add`/… at the use site; the pass `M1` today, the derivation tomorrow |
| `field … @ bitpos`, `embeds`, `offset_into`, `reserved`, `where` | layout is the EMITTER's; the value read is of the field's type and `where` is a check at the read (§9, `Block.pruefung`) | layout: none («SG-16», §16 (4)) |

---

## 3. Pointers and address spaces — M3

```ebnf
ptrty  = "ptr" "<" space "," rights ">" typeexpr ;
space  = "normal" | "mmio" | "dma" | "code" | "boot" | "port" | ident ;
rights = right { "+" right } ;
right  = "r" | "w" | "rw" | "x" | "own" [ "@" ident ] ;
```

**CHANGED «SG-8»: a pointer is the capability to name a declared carrier, and nothing else.**
The second version measured (2026-08-19/21) that `own` was *"read + write in three `matches!`
arms"*, that `zwei(r, r)` fell to nobody, and that in `udp-echo.gab` a write through `k`
made the answer read through `w` stale *"and nothing knows the two are one"*. The third
version answers the question at the type instead of at an alias analysis:

| | rule | Lean |
|---|---|---|
| **what a pointer points at** | a `ptr<space, right> T` is a value of type *"the carrier `T`, number `n`, with right `rw`"*. Its only producer is the name of a **declared** carrier (`&T`, §4); there is no address of an expression and no arithmetic on a pointer | `Ty.ptr n rw`; `Expr.ptrOf t n (ht : D.tabNr n = some t) rw` |
| **an access through a pointer** | `p->f`, `p[i].f` is **the same access as `T.slots[i].f`**, with the same guards: `Held(L)` for a `protects`-guarded carrier, the owner mark for an `owner`-guarded one (§9), and the index of the carrier's index type. A pointer is not a way past the guards | `Expr.durch p t ht f i hL` with `hL : darf D t Λ`; theorem `zeiger_hat_waechter` |
| **a write through a pointer** | needs the type `ptr<…, rw>` **and** the write right of the enclosing contract on `T` (`R002`/`R003` as shape) | `Stmt.assignDurch (p : Expr … (.ptr n true)) … (hw : V.schreibt t = true)`; theorem `zeiger_schreibt_mit_recht` |
| **two pointers to one carrier** | are two names for the same slots, and that is **harmless**: there is one world, an access reads the world, a write writes it — the stale-answer case of `udp-echo.gab` is a *value* stored in a variable, not a *view*. **A value copied out of a carrier is a copy**; the grammar has no reference to a value | no alias question arises in `World D`: theorem `exec_rahmen` holds for every alias |
| **`own`** | the owner **mark** of §9 (`table … owner m`): a parameter `ptr<…, own> T` is SUGAR for *"`T` is `owner m` and the callee `consumes m` … `allocs m`"* — the mark is borrowed for the call and comes back. Two `own` parameters of one carrier are then not derivable: the mark is one («SG-9») | `D.eigner`, `eigner_nie_erzeugt` |
| **`space`** | the barrier follows from the space; the space of a carrier is a declaration fact and the emitter's concern | none — a declaration attribute; `retires … from space` (§6) names it |
| **`x`** | code space; a pointer with `x` is a `fnptr` (§2) or an `entrust` target (§1) | `Ty.fnptr` |

> **Bytes — in the core since the evening of 2026-09-09 («SG-16»).** A byte carrier is a table
> whose field is `u8 in 0 .. 255`; `n` bytes from index `i` are ONE number in `0 .. 256ⁿ−1`
> (`Expr.leseBytes`, `Stmt.schreibBytes`), and the attribute at the read is the bound of the
> whole run: `hi(i) + n ≤ count`. A `format` over a byte carrier is a **view**: `offset_into`,
> `@bitpos`, `embeds … scale` are reads of this form (`Zucker.lean` §4, `bitfeld`, `embeds`),
> and **two views on the same bytes read the same world** — the second view of the second
> version's byte-view rule needs no event, because a view is not a copy: a write through one
> is visible through the other at the next read. What the rule feared — a stale *value* — is a
> variable, and a variable is a copy by the grammar. `udp-echo.gab`'s `w`/`k` case is now: `w`
> is a value read before the write; whoever reads it after the write reads the world.

### User memory — the seventh side and the validated copy

Section 3 closes the space alphabet at six sides and maps the whole concept
out of the grammar: the space of a carrier is a declaration fact and the
barrier follows from it. That reading holds for kernel carriers, whose bytes
no other party rewrites. It does not hold for bytes that live on the far side
of a user/kernel boundary, where a check of a range and the copy from that
range are two reads and the far side may rewrite the bytes between them. The
finding is measured in `messung/TOCTOU-ADRESSRAUM.md` with verdict GAP: no
user-memory region in the grammar or the world, no copy primitive binding
validation to copying, no shape refusing two reads of the same user bytes
with a check between them.

#### The two sides

Every boundary-crossing copy names which side each end lives on, and there
are exactly two sides: kernel memory and user memory. The side is a property
of the copy datum, not of the pointer type: a pointer names a declared
carrier, while a copy names a user address, a kernel address, a byte count,
and the direction the bytes move. A kernel step is then either pure,
carrying no copy, or it carries exactly one copy; a loop copying a range
piece by piece is one such step per piece, each checked.

#### The user region, declared

A user-memory region is declared by name and consists of a base address and
a length in bytes, both fixed at the declaration. A validated copy is then
a region, a copy, and a proof of the proposition that the whole accessed
interval lies inside it — inseparable by shape, because the check and the
copy name the same region, the same address, and the same length. Read back
off the shape, the checked pair of address and length is what is copied,
by construction.

#### The validated-copy rule

A validated copy runs as one copy through the checked handle: the checked
reading takes the copy's user address at check time, the copied reading
takes the same address at copy time. The rule states that the checked value
is the copied value — one snapshot, read once. The address part holds by
the handle alone; the value part holds under the single-copy-atomicity
premise (both snapshots agree at the checked address), named explicitly
and satisfiable, never vacuous. Without the premise the goal is unwritable:
a run whose snapshots differ exhibits the hazard. Lean:
`Grammatik/Adressraum.lean` (`Seite`, `UserRegion`, `Kopie`,
`GepruefteKopie`, `PruefDannKopie`, `ohneToctou`, `EinSnapshot`).

#### What stays future work

The region check still stands beside the run: the world is one flat mapping
with no side partition, and no statement transition discharges it. Missing
are a range check inside the run and a user partition in the world —
booked in §16.2 item 12.

---

## 4. Expressions — `expr`

```ebnf
expr       = orexpr ;
orexpr     = andexpr { "||" andexpr } ;
andexpr    = cmpexpr { "&&" cmpexpr } ;
cmpexpr    = bitexpr [ ( "==" | "!=" | "<" | "<=" | ">" | ">=" ) bitexpr ] ;
bitexpr    = addexpr { ( "&" | "|" | "^" | "<<" | ">>" | "<<%" ) addexpr } ;
addexpr    = mulexpr { ( "+" | "-" | "+%" | "-%" | "+|" ) mulexpr } ;
mulexpr    = unary { ( "*" | "/" | "%" | "*%" ) unary } ;
(* PLAN-BITS section 4 (lane 88): `+%`, `-%`, `*%`, `<<%` wrap and `+|` saturates;
   each rides at the precedence of its base operator. *)
unary      = [ "!" | "-" | "~" ] primary | fnvalue ;
(* `~a` is `a ^ <all bits of the declared width>` (`M137`); the operand is unsigned and
   carries a width. *)
fnvalue    = "&" path ;
(* «B8»: the PRODUCER of a function pointer. `&` expects a `path`, not an expression: there is
   no address of an expression in Gabbro. CHANGED «SG-8»: `&T` for a declared carrier `T` is
   also the producer of a `ptr` -- the one address there is. *)
primary    = int | "true" | "false" | place | call | paren | builtin | optionexpr
            | oldexpr | "result" | reasonval | countexpr ;   (* CHANGED «SG-24» *)
countexpr  = "count" ident "in" domain ":" pred ;
(* The number of entries of one table satisfying `pred` — over ONE table only
   (SUGAR «SG-24», §18: a call to the generated count function of the table,
   like `ops insert/remove` in §9 — `Block.bindCall` with its `requires`).
   A cross-table count is a `group` invariant («SG-10»), not a wider domain:
   whoever hand-maintains a count instead of stating it leaks manual plumbing. *)
reasonval  = ident "::" ident ;
(* The producer of a `reason` value: `return R::F;` IS the error return (`M122`); a ground
   compares only against a ground of the same declaration (`M124`). *)
optionexpr = "Some" "(" expr ")" | "None" ;
paren      = "(" expr ")" ;
call       = ( path | place ) "(" [ arglist ] ")" ;
(* «B8»: a call over a PLACE is an indirect call; the callee is not known at translation
   time, and what is known about it stands at the type of the place (`fnptr`). *)
arglist    = arg { "," arg } ;
arg        = [ ident ":" ] expr ;
(* «B7»: a labelled call is the record constructor -- `P(a: 1, b: true)`. There is NO braced
   record literal (`P037`): at 76 corpus sites a `{` follows an expression directly. G9: a
   `call` whose `path` names a type IS the conversion.
   Lane 167: a `call` whose single-segment `path` names a case of a `tagged` type IS the
   case construction -- `Variant(payload)`, `Variant()` -- and a bare `place` naming a
   nullary case IS the nullary construction (`Variant`). No new keyword and no new
   production: the parser cannot tell a case from a function, so the resolution stands
   in the checker (`Umgebung::variante`), where a function of the same name wins. *)
builtin    = ( "sizeof" | "lenof" ) "(" ( typeexpr | place ) ")"
           | "aligned" "(" expr "," constexpr ")" ;
oldexpr    = "old" "(" place ")" ;                 (* EXPRESSION, not predicate; only in ensures *)
place      = ident { placesuffix } ;
placesuffix= "." ident | "[" expr "]" | "->" ident ;
placelist  = place { "," place } ;
```

**Attributes — every operator names the range of its result** (CHANGED «SG-2», «SG-3»):

| spelling | attribute on the operands | range of the result | Lean |
|---|---|---|---|
| `a + b` | `a : lo₁..hi₁`, `b : lo₂..hi₂` | `lo₁+lo₂ .. hi₁+hi₂` | `Expr.add` |
| `a - b` | | `lo₁−hi₂ .. hi₁−lo₂` | `Expr.sub` |
| `-a` | | `−hi .. −lo` | `Expr.neg` |
| `a * b` | | the min and max of the four corners | `Expr.mul` |
| `a / b`, `a % b` over `0 ..` | **`a : 0 ..`, `b : 1 ..`**: over non-negative operands C's truncating division and integer division coincide, and `0 ≤ a/b ≤ hi₁`, `0 ≤ a%b ≤ hi₂−1` are theorems | `0 .. hi₁`, `0 .. hi₂−1` | `Expr.div h0 h1`, `Expr.rem` |
| `a / b`, `a % b` signed | **`b : 1 ..` or `b : .. −1`** — the divisor's range excludes zero (`M102` exactly); the quotient is C's truncating `tdiv`, and `\|a/b\| ≤ \|a\|`, `\|a%b\| < \|b\|` are theorems («SG-3», second sentence, evening of 2026-09-09) | `−M .. M` with `M = max \|lo₁\| \|hi₁\|`; `−(N−1) .. N−1` with `N = max \|lo₂\| \|hi₂\|` | `Expr.sdiv hb`, `Expr.srem hb`; theorem `sdivision_ohne_null` |
| `a & b` | both `0 ..` | `0 .. hi₁` | `Expr.band` |
| `a \| b`, `a ^ b`, `~a` | both `0 ..`, and the declared width `w` with `hi₁, hi₂ < 2^w` (`M137`) | `0 .. 2^w − 1` | `Expr.bor w`, `Expr.bxor w` |
| `a << b`, `a >> b` | both `0 ..` | `0 .. hi₁·2^hi₂`, `0 .. hi₁` | `Expr.shl`, `Expr.shr` |
| `a +% b`, `a -% b`, `a *% b` | both exactly `0 .. 2^N − 1`, unsigned, same width (`M153` otherwise, naming `+\|`); a literal operand takes the other's range when its value lies in it | `0 .. 2^N − 1` | `Zahl.addW/subW/mulW` |
| `a <<% b` | `a` exactly `0 .. 2^N − 1` unsigned, `b : 0 .. N − 1` | `0 .. 2^N − 1` | `Zahl.shlW` |
| `a +\| b` | one shared integer range `lo .. hi` (`M154` otherwise); a literal operand takes the other's range | `lo .. hi`, the sum clamped to it | `Zahl.addS` |
| `< <= == != > >=` on integers | | `bool` | `Expr.lt le eq` (the rest by `nicht`, swapped operands) |
| `< <=` on floats | both operands finite by type — the comparison is **total**, the NaN quadrant of «F» does not exist («SG-17») | `bool` | `Expr.fllt`, `Expr.flle` |
| `&& \|\| !` | | `bool` | `Expr.und oder nicht` |
| a narrower range at a wider place | `lo' ≤ lo ∧ hi ≤ hi'` — the ONE implicit widening («SG-1», E3) | `lo' .. hi'` | `Expr.weiter h1 h2` |
| `int` literal `n` | | `n .. n` | `Expr.lit n` |
| `true`, `false` | | `bool` | `Expr.wahr`, `Expr.falsch` |
| `place` = a local | | its type | `Expr.var x` |
| `place` = a `static`/`atomic` | **the guards of the global are in Λ** (`H007`, §11) | its type | `Expr.glob g (hL : gdarf D g Λ)` |
| `place` = `T.slots[i].f`, `r[i].f` | **`i : index into T`** (CHANGED «SG-4»: no other type reaches an index — a wider number reaches it through `narrow`, §7) **and the guards of `T` are in Λ** («SG-6a») | the field's type | `Expr.slot t f i hL` |
| `n` bytes at `i` of a byte carrier | `i : lo .. hi` with `0 ≤ lo` and `hi + n ≤ count`; guards of the carrier in Λ («SG-16») | `0 .. 256ⁿ − 1` | `Expr.leseBytes`; theorem `bytes_in_tabelle` |
| `place` = `p->f`, `p[i].f` | the same, through a pointer (§3) | | `Expr.durch` |
| `Some(e)`, `None` | `e : index into T` | `option index into T` | `Expr.some`, `Expr.none` |
| `x.is_some()` / match on `option` | | `bool` | `Expr.istSome` |
| `Variant(e)` (a `tagged` case) | the payload has the case's type; the case index is in range by shape | the sum type | `Expr.fall cs i nutz` |
| `Variant()` / bare `Variant` (a nullary `tagged` case, lane 167) | nothing to carry — the case index alone says which case it is | the sum type | `Expr.fall cs i` with the empty payload |
| `Variant(e)` refused (lane 167) | an unknown or ambiguous case (`N280`); a missing payload (`N281`); a payload on a nullary case (`N282`); a bare name over a payload case (`N283`); labels at a case (`N284`) — the payload RANGE stays `M101`'s, its SHAPE `M140`'s | — | — |
| `R::F` | | `reason R` | `Expr.grund n r` |
| `&f` | `f` has exactly the signature of the `fnptr` at the place | `fn(…)` | `Expr.fnref f n (h : D.sig f = n)` |
| `&T` | `T` is the declared carrier number `n` | `ptr<…> T` | `Expr.ptrOf` |
| `old(place)` | only in `ensures`: the value at entry — **under the guards of the place**, like the place | the place's type | `Expr.altGlob hL`, `Expr.altSlot hL` |
| `result` | only in `ensures`: the answer | the return type | the head variable of the `ensures` context (`ErgCtx`) |
| `sizeof`, `lenof`, `aligned` | translation-time numbers | `n .. n` | `Expr.lit` (SUGAR) |
| `[e₀, …]` as const initializer (lane 111) | each element folds (`K190` otherwise); the count is the declared one (`K191`); each element lies in the element type (`K194`) | the element type, per element | no constructor — checker-evaluated (`konstanten.rs`); the certificate is `konstZert` (`Konstanten.lean`) |
| a call in expression position | SUGAR for `let t = call; … t …` (§7) | | `Block.bindCall` |
| `x += e` etc. (§7) | SUGAR for `x = x + e` under the rules above | | `Expr.add` |

**M1 acts here and nowhere else:** every operation must stay within the range of its result
type — and now that is the **shape** of the derivation: `a + b` with `a, b : u32 in 0..1000`
*is* a `u32 in 0..2000`, and at a place of a narrower type there is no constructor to put it.
The M1 limit named in the second version — flow-sensitive narrowing — is answered as before:
`narrow x to 1..u32::max else { … }` (§7), a statement with a named exit.

*Lean:* `Expr : Ctx → List (Res D) → Ty → Type` (`Syntax.lean` §3); theorem `wert_total` (every
expression has a value of its type), `im_bereich` (a number is in its range), `gleit_endlich`
(a float is finite and in its range), `fnptr_passt` (a function pointer has its signature),
`division_hat_nenner` (a division had a positive denominator).

---

## 5. Predicates — `pred`. **Here lies the line**

```ebnf
pred       = orpred ;
orpred     = andpred { "||" andpred } ;
andpred    = notpred { "&&" notpred } ;
notpred    = [ "!" ] atompred [ "=>" pred ] ;
atompred   = cmpexpr | quant | member | reach | heldpred | "(" pred ")" ;
heldpred   = "Held" "(" ident [ "," "shared" ] ")" ;
quant      = ( "forall" | "exists" ) ident "in" domain ":" pred ;
domain     = "slots" "of" place                  (* the slots of a table *)
           | "chain" "(" ident "," ident ")" "in" place
           | "descendants" "of" place             (* runs on the `tree` edge of the table, «B41b» *)
           | "ancestors" "of" place               (* «B41»: the same edge, other direction *)
           | "queue" place
           | "fields" "of" path
           | "elems" "of" place                   (* «B12»: binds an INDEX into the array *)
           | "threads"
           | "mappings" "of" place ;              (* generated from a walk declaration *)
member     = expr "in" domain ;
reach      = place "reaches" place "via" ident ;
predlist   = pred { "," pred } ;
```

**A domain binds the ADDRESS of an entry** (decided 2026-08-20): `slots of`, `elems of`,
`descendants of`, `ancestors of` and `queue` bind an index; the element is then `p[i]`. The
single exception is `mappings of`, which binds the record the `walk` declaration generates.

**Eight domains, closed. Nesting at most two.** `old(place)` is permitted in `ensures` and
nowhere else. There are **no user-defined quantifier domains, no recursion in `spec fn`, no
hand-written lemmas**. Whoever needs more needs Verus or F\*. The one exception, and it is
NOT a lemma: `by induction over <domain>` **names** the scheme the compiler generated from
the `table` declaration.

**Attributes and Lean.** A predicate is an expression of type `bool` — the line between `pred`
and `expr` is a line of the **surface** (what may stand in a contract), not of the meaning:

| spelling | reading | Lean |
|---|---|---|
| `forall k in slots of T : p`, `elems of` | the binder has type `index into T`; the body runs over `0 ..< count`; **the guards of `T` are in Λ** — a quantifier reads the table | `Expr.forallSlots t body hL` |
| `exists k in slots of T : p` | | `Expr.existsSlots t body hL` |
| `a reaches b via f` | `f` is an `option index into Self` field of `T` (`T001`–`T003`); the chain is followed for at most `count` steps — more steps than slots repeat one | `Expr.reaches t f hf a b hL` |
| `descendants of s`, `ancestors of s`, `chain(a, b) in T` | SUGAR: `forall k in slots of T : (s reaches k via child) => …` and the mirror with `parent`; `chain` names its field at the site | `forallSlots` + `reaches` |
| `queue T`, `fields of T` | SUGAR over `slots of` and over the record's fields | `forallSlots` |
| `threads` | the domain of the scheduler table | `forallSlots` over the declared `Threads` table |
| `mappings of root` | the leaves of a `walk` (§9): a nested `traverse` per level, which is a nested `forallSlots` | `forallSlots` per level (SUGAR, «SG-16») |
| `Held(L)`, `Held(L, shared)` | **`Res.held L ∈ Λ`** — not a value, a fact about the derivation; `shared` is a second witness kind of the same lock (a `locks shared` block adds it) | the index `Λ` of every `Expr`/`Stmt`; theorem `slot_hat_waechter` |
| `p => q` | `!p \|\| q` | `Expr.oder (Expr.nicht p) q` |
| `e in domain` | `exists k in domain : k == e` | SUGAR |

> **The price is unquantified and probably the largest of the whole design:** there is no
> emergency exit. If a kernel property falls outside the eight domains, it is **not
> formulable** — not "expensive" but **not at all**. That does not change in the third version,
> and it is not a gap of the theorem: a property that cannot be written is not a clause, and
> the theorem is about clauses.

---

## 6. Functions and contracts — E4

```ebnf
fndecl   = [ "pub" ] [ "library" ] [ "spec" | "const" | "impl" | "raw" | "divergent" | "prim" | "extern" ]
           "fn" ident "(" [ params ] ")" [ "->" typeexpr ] [ "or" ident ]
           (* «C3a»: `or <reason>` -- the error channel, and it stands in the SIGNATURE. *)
           [ "payload" path ]
           (* «E2» (§7.1): only on a `library fn` (`P043` without it) -- the payload
              type, a table (a tree table is a table), held against the declared
              tables (`N060`). It stands behind the signature because it extends
              the call shape, not the contract. *)
           [ "refines"   path ]
           (* «P6a»: only at an `impl fn`; the path names a declared `spec fn` (`M130`/`M131`). *)
           [ "requires"  predlist ]
           [ "ensures"   predlist ]
           [ "maintains" identlist ]
           (* CHANGED «SG-10»: SUGAR. The obligation is DERIVED from `effects`: a function
              that writes a carrier of `invariant I` owes `I` at every `return`, whether it
              names it or not. `maintains I` documents; it can neither add nor lose an
              obligation. *)
           [ "advances"  ident "->" ident ]
           (* «B37»: which step this function takes on a mark with `order`. CHANGED «SG-14»:
              the mark is in Λ at stage `a`, the body leaves it at stage `b = a + 1`. *)
           [ "retires"   ident "from" space
             ( "falsifier" ident | "unfalsifiable" string ) ]    (* S3 *)
           (* ONE clause with three parts: the mark (the same that `effects` consumes, `O011`),
              the space, and the class of the assumption. CHANGED «SG-14»: the mark leaves Λ
              and the assumption is NAMED in the term. *)
            [ "effects"   "{" efflist "}" ]
            [ "costs"     "<=" expr "ops" ]
            [ "deadline"  "<=" expr "ops" "arch" ident
              ( "falsifier" ident | "unfalsifiable" string ) ]   (* NEW «SG-22» *)
            [ "decreases" expr ]                                 (* «K5.4» *)
           [ "by"        inductlist ]
           [ "section" string ] [ "arch" ident ] [ buildgate ]
           ( endblock | "=" pred ";" | "=" asmrumpf ";" | ";" ) ;
           (* CHANGED «SG-5»: the body of a `fn` is an `endblock` -- a block that does NOT fall
              off. A function with a return type ends in `return e;`, one without in `return;`
              or falls to the closing `}` which is SUGAR for `return;`. `"=" pred` only for
              `spec fn`. «E2» (§7.1): a `library fn` takes the `endblock` and nothing else
              (`P044`) -- it IS safe Gabbro, not a foreign promise. *)
asmrumpf = "asm" "{" { string }
             [ "in"  "{" asmops "}" ]
             [ "out" "{" asmops "}" ]
             [ "clobbers" "{" identlist "}" ] "}" ;
asmops   = asmop { "," asmop } ;
asmop    = ( ident | "result" ) ":" string ;
inductlist = induct { "," induct } ;
induct     = "induction" "over" domain ;      (* names the SCHEME -- no lemma, no proof step *)
efflist  = eff { "," eff } ;
eff      = "reads" place | "writes" place | "locks" [ "shared" ] place | "masks" ident
         | "allocs" ident | "consumes" place | "publishes" place | "diverges"
         | "pure" ;
(* CHANGED «SG-6» «SG-8»: `writes T` is the WRITE RIGHT on `T` in the body -- an assignment to
   a carrier not named here is not derivable; `consumes m` puts `m` into Λ at the head of the
   body, `allocs m` demands `m` in Λ at every `return`, and `return` demands multiset EQUALITY
   between Λ and the `allocs` list: linear, not affine. *)
```

**`effects` is NOT fail-open.** A function **without** `effects` over a body
derives it (lane 191: the derived hull is checked exactly like a written
line); whoever touches nothing derives `effects { pure }`. Without a body —
`extern`, `prim` — and where the derivation settles nothing, the omission is
a compile error with the reason (`E001`, `N305`).

**`decreases <expr>` — the descent measure of the RECURSION** («K5.4»): `costs` at a
recursive function is the promise of **one** pass, and the depth stands in the measure.
`K008`/`K009` check the necessary condition; **THAT it falls stays the prover's** — in the core
that is the outcome `logik (abstieg f)`: the meaning of a call at depth `n` is given `n` levels,
and a recursion that has not bottomed out at depth `n` for any `n` is exactly a measure that did
not fall.

**Attributes and Lean.**

| clause | reading | Lean |
|---|---|---|
| `fn f(params) -> T or R` | the **signature** `S`: parameter types, return type, `n` grounds, write rights, consumed and produced marks (with stages) | `Signatur`, `D.sigNr`, `D.sig f`, `vertragVon D f` |
| `requires p` | at every call of `f`, `p` holds — or the outcome is **`logik (vorbedingung f)`** | `Programm.requires f`; `rufAt` |
| `ensures p` | at every `return` of `f`, `p` holds over `result`, `old(…)` and the parameters — or **`logik (nachbedingung f)`** | `Programm.ensures f` in `ErgCtx`, `eval σ₀` with the entry world for `old` |
| `refines g` | `ensures` of `g` ⊆ `ensures` of `f` — a conjunction, not a second channel; a violation is `nachbedingung` | `Programm.ensures` (SUGAR) |
| `maintains I` | SUGAR (see the production) — the owed invariants are `schuldet f i` | `schuldet`, `rufAt` → `logik (invariante i)` |
| `advances a -> b` | the body's Λ starts with `marke m a` and the `advances` statement moves it (§7) | `Stmt.advances`, `Res.marke` |
| `retires m from s …` | the body consumes `m`; the assumption is named | `Stmt.retires m s h a` |
| `effects { writes T, consumes m, allocs m' }` | the contract `V` of the body | `Vertrag`, `RufPasst`, `Λ` |
| `costs <= n ops` | a **budget in the logic**: statically computed ops held against the declaration — §18 («SG-22») | `Budget.lean` `runOps_within` / `per_pass_respected` (no axioms); `held <=` and `bounded` are the same budget under the lock and loop names (`held_respected`, `bounded_respected` — defs only, no theorems); the deadline mapping is `Ziel.lean` `fristAlsAnnahme` (a definition — the existence theorem over it was withdrawn 2026-09-10 as vacuous) |
| `deadline <= n ops arch X falsifier p` | **by when in cycles on `X`** — a hardware outcome, not a second budget | `Hardware.fortschritt a` (the named `progress`-class assumption with its probe); §18 («SG-22») |
| `decreases e` | the recursion depth is a parameter of the meaning | `rufAt (fuel)` → `logik (abstieg f)` |
| `by induction over d` | names the scheme; no term | none |
| `spec fn … = pred` | a predicate helper: inlined at every use (`M130`) | SUGAR |
| `const fn` | a translation-time number: a literal at every use | `Expr.lit` (SUGAR) |
| `raw fn`, `prim fn`, `extern fn`, `= asm { … }` | a **foreign body**: its contract is all Gabbro knows; the body is the machine | `D.Ax` with `aparams`/`aerg`/`aschreibt`; `Stmt.axiomCall`, `Block.bindAxiom` («SG-18») |
| `-> never`, `divergent fn` | no `return` derivable; the only exits are `leave`/`next` of an enclosing loop, a `return R::F`, or a foreign body | `Ty.never`, theorem `never_leer` |
| `requires Held(L), …` | **the lock set is part of the contract**: the `Held` list of a signature names EXACTLY the locks held at every call — `∀ L, Held(L) ∈ Λ ↔ L ∈ haelt(S)` («SG-20», evening of 2026-09-09). Only so can a `locks` inside the callee stand above *everything* held (`H006` across call boundaries); a helper used under two lock sets is two signatures | `Signatur.haelt`, `RufPasst.hh`, `Signatur.anfang`, `Vertrag.ende` |
| a **call** `f(a, b);` | the callee's `writes` ⊆ the caller's, its `consumes` ⊆ Λ, its `Held` = the held set, and a callee with `or R` is callable only through `let … else` | `Stmt.call f args hp hr` with `hp : RufPasst`, `hr : gruende = 0`; theorem `ruf_hat_alles` |
| an **indirect call** `p(a, b);` | the same, against the signature at the **type** of `p` («SG-8») | `Stmt.callInd`, `Block.bindCallInd`; theorem `zeigerruf_hat_alles` |

```gabbro
spec fn cdt_wellformed(c: CapSpace) -> bool =
    forall s in slots of c: c.parent_chain(s) reaches Root via parent;

impl fn revoke(c: ptr<normal, rw> CapSpace, s: SlotIdx) -> Result
    ensures   !exists k in descendants of s: k.used
    maintains cdt_wellformed
    effects   { writes c.slots, locks CAPS }
    by        induction over descendants of s
{ … }

impl fn delete_leaf(c: ptr<normal, rw> CapSpace, s: SlotIdx) -> Result
    requires  Held(CAPS), c.slots[s].used, !exists k in slots of c: k.parent == s
    ensures   !c.slots[s].used, old(c.objects[o].refcount) == c.objects[o].refcount + 1
    maintains cdt_wellformed, refcount_matches
    effects   { writes c.slots, writes c.objects, locks CAPS }
    costs     <= 200 ops
{ … }
```

**`breaking`** names the region in which an invariant rests:

```ebnf
breakstmt = "breaking" identlist block ;
```

It must be restored at the end of the enclosing body; the region is **visible instead of
hidden**. *Lean:* `Stmt.breaking i body` — the name stands in the term (`D013`), and the
restoration is demanded at `return` like without `breaking` (`schuldet`): a `breaking` cannot
lose an obligation, it can only say where one rests.

---

## 7. Statements

```ebnf
block      = "{" { stmt } "}" ;
endblock   = "{" { stmt } endstmt "}" ;                          (* NEW «SG-5» *)
endstmt    = "return" [ expr ] ";" | "leave" ident ";" | "next" ident ";" ;
(* NO value on `leave` («SG-25», §18): the first match leaves through a
   variable bound before the loop — `assignVar` plus `leave`, read after the
   loop. The bound still comes from the domain; no cursor or bitmap is
   hand-threaded. *)
(* The block that does NOT fall off. The `else` of a `let … else`, of a `narrow`, of a
   register read and a `format` check ends here; the second version said (§7, line 1029) that
   the branch "must diverge or return" and never wrote it. `leave`/`next` only under a loop. A
   `return R::F;` is a `return expr;` whose expression is a ground. *)
stmt       = letstmt | allocstmt | resetstmt | assign | stateassign | ifstmt | matchstmt | loopform | breakstmt
           | narrowstmt | lockstmt | observestmt | leavestmt | nextstmt | publishstmt
           | awaitload | exchstmt | advstmt | "return" [ expr ] ";" | exprstmt
           | libcall ";" ;                                       (* lane E1: statement position *)
leavestmt  = "leave" ident ";" ;
nextstmt   = "next" ident ";" ;
advstmt    = "advances" ident "->" ident ";" ;                   (* NEW «SG-14» *)
(* The step on a phase mark, as a statement in the body that `advances` at the head
   promises. `O004`/`O006` (the body composes to its promise, every branch reaches the same
   stage) become the shape: Λ after the statement carries the mark at the next stage, and
   `return` compares Λ with the head. *)
awaitload  = "let" ident "=" place "awaits" "{" placelist "}" ";" ;
exchstmt   = "let" ident "=" place "exchange" xform
             [ "publishes" ( placelist | "nothing" ) ]
             [ "awaits" "{" placelist "}" ] ";" ;
xform      = "update" "(" ident ")"
             [ "bounded" expr "ops" ] [ "on_exceeded" ident ] block
           | expr "when" pred "returns" ident ;
(* «C4b»: the same two clauses as at `retry` -- a bounded CAS loop, and the writer says the
   bound and the exit. *)
letstmt    = "let" [ "mut" ] ident [ ":" typeexpr ] "=" expr ";"
           | "let" ident "=" ( call | place ) "else" "(" ident ")" endblock ;   (* «B14b»; CHANGED «SG-5»: endblock *)
           | "let" [ "mut" ] ident [ ":" typeexpr ] "=" libcall ";" ;   (* lane E1: binding position *)
assign     = place ( "=" | "+=" | "-=" | "&=" | "|=" ) expr ";" ;
stateassign = "transition" shiftplace ":" ident "->" ident ";" ;   (* NEW «SG-19» *)
(* The transition of a `state` field: `transition T.slots[i].s : Idle -> Busy;` names the
   declared transition -- the SAME construct and the same word as a device `transition`
   (§10), one level down, which is what the second version said of the two. That the field
   STANDS on `Idle` is the writer's logic (`logik vorzustand`); that `Idle -> Busy` is DECLARED
   is the shape. The second version wrote `state` transitions through `assign` and left the
   pre-state to a pass. `shiftplace` has no `->` suffix, and the two stage names are
   identifiers, not expressions -- so the arrow is never a pointer suffix. No new word. *)
exprstmt   = call ";" ;
ifstmt     = "if" expr block { "else" "if" expr block } [ "else" block ] ;
matchstmt  = "match" expr "{" { matcharm } "}" ;
matcharm   = ident [ "(" ident ")" ] "=>" block ;                 (* CHANGED «SG-5a» *)
(* ONE arm per case, in declaration order: exhaustiveness is the SHAPE of the arm list, not a
   check (`M123`). Over an `option`: `Some(k) => … None => …`, `k : index into T`. Over a
   `reason` with `n` grounds: `n` arms. *)
narrowstmt = "narrow" place "to" ( range | "finite" ) "else" endblock ;   (* CHANGED «SG-5» *)
(* «F»: `finite` establishes not-NaN-ness. CHANGED «SG-17»: in the core every float is finite
   by type, so `narrow x to finite` is `narrow x to <its whole range>` -- a range narrowing;
   the form stays for the corpus. *)
allocstmt  = "let" [ "mut" ] ident [ ":" typeexpr ] "=" "alloc" ident "(" expr ")"
             [ "else" block ] ";" ;                             (* «E4», §9.1 *)
(* Monotone allocation: `i` is the next free slot of the named arena, holding the value.
   The `else` runs when the arena is full; it is owed exactly when the static allocation
   count since the last reset may exceed the reservation (`N212`). A bare `alloc` stays an
   ordinary expression -- only a name followed by `(` gives the word its meaning. *)
resetstmt  = "reset" ident ";" ;                                (* «E4», §9.1 *)
(* A fresh generation of the named arena: the used counter goes back to zero, and every
   index bound before is stale afterwards (`N211`). `reset = 1;` stays an assignment --
   the head word decides, like at every other keyword statement. *)
```

**`match` is exhaustive** — there is no catch-all branch; a new variant breaks the
compilation. **Error propagation** is `let … else (e) { … }`: no hidden control flow, and the
`else` branch is an `endblock` — it cannot fall off, so the binding after it always has a value.

**Attributes and Lean.** The **resource context** Λ («SG-6») of a position is the multiset of
`Held(L)` witnesses and linear marks (with stage) in hand — not written, derived from the
enclosing `locks` blocks and the statements before the position:

```
Λ at the head of a body       = the `Held(L)` of the signature + the marks it consumes, at their stage
Λ after `f(…);`               = Λ − consumes(f) + allocs(f)
Λ inside `locks L { … }`      = Λ + Held(L)                       (the witness is not consumable)
Λ after `advances a -> b;`    = Λ − marke(m, a) + marke(m, b)
Λ after `retires`             = Λ − marke(m, s)
Λ at `return`                 ≡ the `Held` of the signature + the marks it allocs  (multiset EQUALITY)
```

| statement | attribute | outcome where one fails at run time | Lean |
|---|---|---|---|
| `x = e;` (local) | `e` has the type of `x` | — | `Stmt.assignVar` |
| `T.slots[i].f = e;` | `i : index into T`; guards of `T` in Λ; **`writes T` in the contract** | — | `Stmt.assignSlot t f i e hw hL`; theorem `zuweisung_hat_recht` |
| `p->f = e;` | the same, and `p : ptr<…, rw>` | — | `Stmt.assignDurch` |
| `G = e;` (static) | guards of `G` in Λ; `writes G` | — | `Stmt.assignGlob` |
| `transition T.slots[i].s : A -> B;` | `A -> B` declared at `state`; `B` in the field's range; `writes T`; guards | **`logik vorzustand`** if the field is not on `A` | `Stmt.uebergang`; theorem `uebergang_erklaert` |
| `x += e;` etc. | SUGAR for `x = x + e;` | — | `Expr.add` |
| `let x = e;` | binds; `mut` is a surface flag | — | `Block.bind e rest` |
| `let x = f(…);` | as a call; `f` has a return type and no `or` | — | `Block.bindCall` |
| `let x = p(…);` | indirect, against the type of `p` | — | `Block.bindCallInd` |
| `let x = f(…) else (e) endblock;` | `f` has `or R`; `e : reason R` in the `else`; the `else` does not fall off | — | `Block.bindCallElse f args he hp hr err rest` |
| `let x = axiom(…);` | the axiom's `writes` ⊆ the contract's | **`hardware (annahme a)`** if the answer is outside the declared type (every type has a decoding since 2026-09-15, finding G1: a sum is `marke + cases * last` (`cases` the number of cases), a float its binary64 bits, a pointer an address the loaded image names; `einpassen_voll`); a declared type WITHOUT a value (`-> never`, an empty range) admits no answer: the call does not return, named `HaltArt.nieZurueck` | `Block.bindAxiom` |
| `let x = R;` (register) | `R` has a readable class (§10); the value is held against the type AND against the register's declared promise (`requires` without `else`) | **`hardware (register r)`** if outside the type; **`hardware (geraet r)`** if the promise fails — the device assumption, named at the register | `Block.regLies r hk rest`, `D.rzusage`; theorem `register_lesbar` |
| `let x = R else (e) endblock;` | `R` carries `requires … else` (§10): the promise is checked on the binding | — (the `else` runs) | `Block.regLiesElse` |
| `let x = A awaits { p, q };` | `{ p, q }` is **exactly** the payload declared at `A` («SG-13») | **`hardware (sichtbarkeit A10)`** if the machine does not deliver the publication — the memory model, as an outcome | `Block.awaits g payload hp hL rest`, `Orakel.sichtbar`; theorem `awaits_paart` |
| `let x = A exchange update(v) { … } …;` | read, compute, write as **one** statement; `bounded`/`on_exceeded` as at `retry` | — | `Block.exchange g neu hw hL rest` |
| `A = e publishes { p, q };` | the declared payload; `writes A` | — | `Stmt.publish`; theorem `publish_paart` |
| `if c blk else blk` | | — | `Stmt.ite` |
| `match e { arms }` | one arm per case (see production) | — | `Stmt.onTag`, `Stmt.onOption`, `Stmt.onGrund`; `Arms`, `GrundArms` |
| `narrow x to lo .. hi else endblock` | the `else` does not fall off; after it `x : lo .. hi` | — | `Block.narrow e lo hi sonst rest` |
| `let i = alloc A (v) else blk` | `i : index into A` of the current generation; `v` has the element type; `writes A`; the `else` is owed past the reservation (`N212`) | — (the `else` runs when the arena is full) | **SUGAR since 2026-09-15**: `Block.arenaAlloc` (`grammatik/Grammatik/ArenaZucker.lean`) = `Block.narrow` on the `used` counter + `Stmt.assignSlot` + `Stmt.assignGlob`; theorems `arenaAlloc_unter_schranke`/`_an_schranke`, bridge `arenaAlloc_gdw_modell` to `Arena.alloc`. *The generation stays checker state (`N211`); the exporter does not build the form yet — `OFFEN.md` O14* |
| `reset A;` | `A` is a declared arena; `writes A` | — | **SUGAR since 2026-09-15**: `Stmt.arenaReset` = `Stmt.assignGlob zaehl 0`; theorem `arenaReset_stand`. The model function `Arena.reset` keeps the generation half: every older index is stale by typing |
| `narrow x to finite` / a float range | | — | `Block.gleitNarrow` |
| `let y = a op b;` on floats, `let y = 1.5 rounded;`, `let y = f64(n);` | the result **range is declared** (by the type of `y`); the machine computes | **`logik bereich`** if the result is outside or not finite — the program's own logic under the kernel IEEE model, which the user proves never happens (`hardware ieee` until 2026-09-15, `messung/URTEIL-OPUS-2026-09-15b.md` F1) | `Block.gleit`, `gleitLit`, `gleitVon` («SG-17») |
| `f(…);` | see §6 | `logik (vorbedingung f)` … from the callee | `Stmt.call`, `Stmt.callInd` |
| `axiom(…);` | | `hardware (annahme a)` | `Stmt.axiomCall` |
| `R = e;` (register) | `R` has a writable class (§10) | — (the device is outside the world) | `Stmt.regSchreib`; theorem `register_schreibbar` |
| `transition t { R.b : 0 -> 1 }` | `R` writable, its declared mirror `m` readable; one read of `m`, one write of `R` with the bits under the mask replaced | — | `Stmt.transition r hk m hm hl maske bits`; theorem `transition_hat_spiegel` |
| `T.slots[i].f = e` on `n` bytes | a byte-carrier write of `n` bytes at `i`, `hi(i) + n ≤ count`, `writes T`, guards | — | `Stmt.schreibBytes` |
| `locks L blk`, `observes D blk` | §11 | — | `Stmt.locks L hr body` |
| `breaking I blk` | §6 | — | `Stmt.breaking` |
| `advances a -> b;` | the mark is at `a` in Λ, `b = a+1 < stages` | — | `Stmt.advances m a h hs`; theorem `stufe_steigt` |
| `retires` (at the head, §6) | the mark at stage `s` in Λ | — | `Stmt.retires m s h a` |
| `return e;` | `e` has the return type; **Λ ≡ allocs** | `logik (nachbedingung f)`, `logik (invariante i)` at the call | `Stmt.ret`, `Endblock.ret`; theorem `rueckgabe_bilanziert` |
| `return R::F;` | the function has `or R` | — | `Stmt.retGrund`, `Endblock.retGrund` |
| `leave l;`, `next l;` | inside a loop (`l = true`) | — | `Stmt.leave`, `Stmt.next` |
| a `format` field's `where`, a `requires` at a read | the condition, or the named `else` (§9) | — | `Block.pruefung c sonst rest` |

*Lean:* `Stmt`, `Block` (falls off: outcome `ok`), `Endblock` (does not: outcome `EndAusgang`
has no `ok`), `Arms`, `GrundArms` — `Syntax.lean` §4. **Theorem `exec_rahmen`** (`Satz.lean`
§3): a body under contract `V` writes only what `V` names — for every program, every depth,
every world; the only premise is that the hardware keeps ITS `effects` (H1). The proof is a
structural induction over **all** of `Stmt`/`Block`/`Endblock`/`Arms`/`GrundArms`, each
constructor a case.

### Linear marks at run time: the stand

The context Λ says what the derivation holds; the STAND says what the run
holds. One stand per run: every linear mark is free or owned by exactly one
thread at exactly one stage. A mark step is one of three — create (only from
void, only below the stage count, never an `owner` mark: owner marks are never
produced, `eigner_nie_erzeugt`), advance (only in the hand of the same thread,
only to the next stage below the count), consume (only from the hand into the
void). There is no fourth step: no forging, no duplication, no handoff to
another thread.

| derivation (Λ, §7) | run (stand) |
|---|---|
| head Λ = `Held` + consumed marks | initial stand: all void (`Anfang`) |
| call: Λ − consumes + allocs | the callee's produced marks appear in its own hand |
| `advances a -> b;` | the same thread advances the same mark `a -> a+1` |
| `retires` | the owning thread consumes the mark into the void |
| `return`: Λ ≡ `Held` + allocs | every produced mark is owned, every consumed mark is gone |

Single-threadedness (W4) is the shape every mark step preserves: two events
naming stages `s`, `s'` of the SAME mark name the SAME thread — stages may
differ (advance changes the stage, never the owner), threads may not.
Lean: `Grammatik/Marken.lean` (`Stand`, `MarkenSchritt`, `Verlauf`,
`Einfaedig`); the projection into `Gesittet.marke_eindeutig` is the wiring
lane's work.

### Library calls — `@library#function ( args ) { region }` (lane E1)

A library call is a **run-time call** of `function` in `library`
(`PLAN-ERWEITUNG.md` §0b, §1, §6). It stands in statement position and in
binding position:

```ebnf
libcall    = "@" ident "#" ident "(" [ arglist ] ")" "{" libregion "}" ;
libregion  = ? brace-balanced token tree, captured without interpreting ? ;
```

`stmt` carries `libcall ";"`, `letstmt` carries `"=" libcall ";"`; `arglist`
is the ordinary argument list. The region is a brace-balanced token tree the
reader captures WITHOUT interpreting: the opening `{`, nested `{ … }` pairs,
the closing `}`. What the region MEANS — compiled at translation time into a
payload the call carries (`PLAN-ERWEITUNG.md` §0b) — runs since lane E5 as a
first cut (§7.3): an exact-length row of integer literals through the
identity translator. A call that resolves `lib` to a used module and
`function` to a declared `library fn` in it (§7.1) is checked like an
ordinary call — arguments, effects, `or R`, costs — and where the first cut
cannot translate it refused with `N069`, which names the translator that
WOULD run it (§7.2). A call
that resolves nowhere is refused with `N057`; the refusal is controlled —
never a crash and never a silent acceptance. In any other expression position
the reader refuses the `@` with `P011`.

```gabbro
@spirv#kernel(n) { dispatch 0 };
let code = @spirv#kernel(n) { dispatch 0 };
```

| spelling | attribute | Lean |
|---|---|---|
| `@lib#fn(args) { region };` | a run-time call; the region is captured uninterpreted; resolved calls outside the first cut refused with `N069`, unresolved with `N057` (§7.3 translates the rest) | no term — refused by `N057`/`N069` |
| `let x = @lib#fn(args) { region };` | binds; the call is a run-time call; translated or refused like the statement form | no term — refused by `N057`/`N069` |

### 7.1 `library fn` — the declaration with a payload type (lane E2)

**Specified, the words lexed, the declaration checked («E2»).** A library
module declares a run-time function with a contract and a PAYLOAD TYPE; the
example block is an excerpt (`…`), not a translation unit.

**The surface** — a `library fn` is an ordinary function with a body, every
clause in the fixed order of §6, and one extra clause behind the signature:

```gabbro
module gpu::spirv {
table KernelTab count 1 {
    slot {
        words : u32,
    }
}
…
pub library fn kernel(n : u32) -> u32 payload KernelTab
    requires n <= 1024
    ensures result == n
    effects { pure }
    costs <= 8 ops
{
    return n;
}
…
```

```gabbro
module app {
use gpu::spirv;
…
@spirv#kernel(n) { dispatch 0 };
…
}
```

**The checks** — each names what an ordinary declaration already carries,
plus the four things only a library declaration can fail:

* **payload** — the clause is mandatory on a `library fn` (`P043`); it names
  a declared table — a tree table is a table — resolved from the declaring
  module outward (`N060`). It stands behind the signature because it extends
  the call shape (what the translator fills), not the contract.
* **body** — a Gabbro block, nothing else (`P044`: no `;`, no `= pred ;`,
  no `= asm`). The transitive call hull holds no `extern`, `raw`, `prim`
  or `asm` (`N059`, `PLAN-ERWEITUNG.md` §0c) — structure, never prose
  comparison.
* **call** — `@lib#f` resolves `lib` like any name (own module, enclosing,
  root, `use` lines) and `f` to a `library fn` in it; arguments, effects
  (through the call graph), `or R` and costs are checked exactly like an
  ordinary call. Resolved calls are refused with `N069` until a
  translator RUNS them (declared since lane E3, §7.2; running them is lane
  E5); unresolved calls with `N057`.
* **no bypass** — a direct call to a `library fn` is refused (`N061`):
  without a region there is no payload.

*Lean:* a library call is an `Ax` whose parameter list is the ordinary
parameters with the payload appended — no new statement constructor.
Theorem `bibliotheksruf_ist_ax`
(`grammatik/Grammatik/Bibliothek.lean`): the typing and effect obligations
of such a call are exactly the `Stmt.axiomCall` premises for the serving
axiom, as an equivalence; witnessed on a one-table declaration with a
reached two-step run that moves memory
(`bibliotheksruf_ist_ax_zeuge`).

### 7.2 `translator` — the declaration from region to payload (lane E3)

**Specified, the words lexed, the declaration checked («E3»).** A library
declares, for each of its run-time functions, the *translator*: a total,
effect-free Gabbro function from the call region's AST (a tree table type,
`PLAN-ERWEITUNG.md` §2) to the function's payload type. Running it needs
the compile-time evaluator — **only the declaration and the typing are
built now** (`PLAN-ERWEITUNG.md` §6, lane E3). The region still is not
translated: a resolved call is still refused with `N069`, which now names
the translator that WOULD run.

**The surface** — one translator per library function, in the same module,
named after its own job and linked with `for`:

```ebnf
translatordecl = [ "pub" ] "translator" ident "for" ident "(" ident ":" typeexpr ")"
                 [ "->" typeexpr ]
                 (* The result names the served function's payload table;
                    absent or naming anything else it is `N204`. *)
                 [ "requires" predlist ] [ "ensures" predlist ]
                 [ "effects" "{" efflist "}" ]
                 (* `effects { pure }`, held by `N202`, not by the grammar:
                    a translator with effects must be REFUSED, not unwritable. *)
                 [ "costs" "<=" expr "ops" ]
                 [ "decreases" expr ]
                 (* The termination witness, held by `N203` for the same reason. *)
                 endblock ;
                 (* A Gabbro block, nothing else (`P044`) -- the translator IS
                    ordinary Gabbro checked by the ordinary checker. *)
```

```gabbro
module gpu::spirv {
table KernelTab count 1 {
    slot {
        words : u32,
    }
}
…
pub translator build for kernel(region : KernelTab) -> KernelTab
    effects { pure }
    costs <= 8 ops
    decreases region.words
{
    return region;
}
…
```

The example translates by identity: the region AST already stands in
payload form. A translator between two DIFFERENT tables needs
translation-time value construction -- building a fresh payload value
without a run-time effect -- and that is lane E5's compile-time
evaluator, not this lane: under the current checker a `pure` body cannot
construct a table value out of another table's (`M140` is nominal, and a
carrier read under `pure` is `E010`). What this lane checks is the
declaration and the typing; the calls stay refused until a translator
RUNS.

**The checks** — the body is an ordinary function body: types, contracts,
effects and costs are checked by the ordinary checker, and the transitive
call hull holds no `extern`, `raw`, `prim` or `asm` (`N059`,
`PLAN-ERWEITUNG.md` §0c). Five new refusals hold the five things only the
linkage can fail:

* **one translator** — every `library fn` with a payload type has exactly
  one translator in its module: none is `N200` on the function, a second
  one — and a translator naming no library function at all — is `N201` on
  the translator;
* **pure** — the translator's signature is `effects { pure }` (`N202` for
  anything else, including a missing clause);
* **total** — it carries a `decreases` clause (`N203` without one);
* **fitting** — its result type names the served function's payload table
  (`N204` for anything else, including a missing result).

| spelling | attribute | Lean |
|---|---|---|
| `translator build for kernel(region : RegionAst) -> KernelTab effects { pure } decreases e { … }` | a total, effect-free map from the region AST to the payload; checked like any function body; runs only at translation time (lane E5) | no new term — an ordinary pure function; the certificate (lane E5) checks its OUTPUT |

*Lean:* nothing new. A translator is an ordinary Gabbro function with a
`pure` contract and a termination witness; the translation certificate of
lane E5 checks the produced payload, never the translator.

### 7.3 The translation stage, first cut (lane E5)

**Checked, translated, and lowered.** Where the region is an exact-length
row of integer literals and the translator is the identity
(`return <region>;`, the region already standing in payload form), the
checker runs the translation at translation time: token `i` fills row `i`
of the payload table's single integer field, every value held against the
field range. The region fills the library function's LAST parameter, which
is a pointer at the payload table -- so the call passes one argument
short, the ordinary arguments held against the shortened signature like
any call's. The emitter passes the accepted payload as a `static const`
table argument (`&<fn>__nutzlast_*`, one table per call site, named by
call span). Anything else is refused, each fault in its own code:

| code | what falls | where it points |
|---|---|---|
| `N230` | the integer count misses the payload count (short or long) | the first homeless token, or the region where rows stay empty |
| `N231` | the translator body is not `return <region>;` | the translator |
| `N232` | a payload entry outside the field range | the offending region token |
| `N233` | the declaration fits no first cut: a payload table with anything but one integer field and a constant count, a library function with no payload pointer to fill, a call passing that pointer explicitly | the payload clause, the function, the bypassed argument |
| `N234` | the contract names the payload parameter -- no source value could ever discharge it | the contract predicate |

A region with any non-integer token stays `N069`: the region is captured,
not interpreted, exactly as before. The translator itself is never
verified -- the certificate is the payload's TYPING, every entry in its
field range as a `List.all` predicate (encoding N), closed by `decide`
(`grammatik/Grammatik/Uebersetzung.lean`, printed by
`uebersetzung::payload_certificate`).

```gabbro
module summe {
table SumTab count 4 {
    slot {
        v : u32 in 0 .. 100,
    }
}
library fn sum(t : ptr<normal, r> SumTab) -> u32 in 0 .. 400 payload SumTab
    ensures result <= 400
    effects { reads t.slots }
    costs <= 16 ops
{
    return t.slots[0].v + t.slots[1].v + t.slots[2].v + t.slots[3].v;
}
translator build for sum(region : SumTab) -> SumTab
    effects { pure }
    costs <= 8 ops
    decreases region.v
{
    return region;
}
impl fn hole_summe() -> u32 in 0 .. 400
    effects { reads SumTab.slots }
    costs <= 64 ops
{
    let s = @summe#sum() { 10 20 30 40 };
    return s;
}
}
```

| spelling | attribute | Lean |
|---|---|---|
| `@lib#fn(args) { 10 20 30 40 }` with an identity translator | translated at compile time; the payload is a well-typed value of the payload table; the call lowers with `&<payload>` | the payload typing, certified; the translator has no term |

*Lean:* the payload as a certificate, never the translator that filled
it -- `Uebersetzung.nutzlastZert` and the closed `sumPayload_zert`.

---

## 8. Loops — **three forms, and infinite is one of them**

**The rule is not "every loop ends" but: what a loop may do stands beside it.**

```ebnf
loopform   = traverse | retry | forever ;

traverse   = "traverse" ident [ "of" expr ]
             "over"  domain
             "by"    ( "unvisited" | "consuming" )
             [ "decreases" expr ]
             [ "touches" efflist ]
             [ "invariant" pred ]
             block ;

retry      = "retry" [ ident ] [ "until" pred ]
             "bounded"     expr "ops"
             [ "progress"  ident ]
             "on_exceeded" ( ident | endblock )                  (* CHANGED «SG-11» *)
             [ "effects" "{" efflist "}" ]
             [ "invariant" pred ]
             block ;
(* `on_exceeded ident` is SUGAR for `on_exceeded { ident(); return; }` -- the overrun is a
   named exit, and a named exit is an `endblock`. *)

forever    = "forever" [ ident ]
             "per_pass"  "bounded" expr "ops"
             "on_exceeded" ident
             "effects"   "{" efflist "}"
             "progress"  ident                                  (* CHANGED «SG-11»: COMPULSORY *)
             [ "leaves"    identlist ]
             [ "invariant" pred ]
             block ;
(* `progress` names WHO ends the loop -- an assumption with a falsifier. `UNFALSIFIZIERBAR.md`
   row 4 measured a wait loop with no `progress` as "writable, and no latch can ever close
   it" (`beispiele/66`:66). In the core a `forever` ends by `leave` or by the environment, and
   the environment's contribution IS the named assumption: outcome `hardware (fortschritt a)`.
   A loop that names nobody would have a third kind of end. *)
```

**`invariant pred` stands at all three, immediately before the block**; `M133` refuses one
that names nothing. `decreasing` fell on 2026-09-01: `decreases` at a loop is the same measure
over the passes that `decreases` at a `fn` is over the recursion, and it is a **witness** — it
says nothing about the run that `unvisited` does not.

| Form | ends? | what discharges the plumbing | outcome where a clause fails | Lean |
|---|---|---|---|---|
| **`traverse`** | yes, through the set | range **and** termination by the finite index set; `by consuming` additionally the removal as a generated `ops` operation | `logik schleife` if `invariant` fails at a pass boundary | `Stmt.traverse t inv body` — iterates `alleIndizes (count t)`; the binder is `index into T` |
| **`retry`** | yes, through `bounded` | termination as a **number**; the overrun is **named** | `logik schleife`; the overrun runs the `on_exceeded` block | `Stmt.retry n bis body ueberlauf` |
| **`forever`** | **no — and that is permitted** | every **pass** is bounded, the **frame** stands in `effects`, the end is named | `logik schleife`; **`hardware (fortschritt a)`** if the environment does not end it | `Stmt.forever a inv body` — the passes come from outside (H2) |

```gabbro
forever
    per_pass bounded 4096 ops
    on_exceeded watchdog_schlug_an
    effects  { reads READY, writes CURRENT, locks SCHEDS }
    progress timer_tick_arrives
{ … }
```

`leave` ends the loop, `next` the pass; inside the body `Λ` must be the same at every pass
boundary (`Block true Γ Λ Λ` in Lean — a loop body neither consumes nor allocates a mark,
which is `O006` as shape). `touches`/`effects` at a loop are a **sub-contract** of the
function's: SUGAR, the function's contract is what the theorem holds.

---

## 9. Tables, traversals, formats

```ebnf
table      = [ "pub" ] "table" ident [ "count" constexpr ] [ "backed" ident ]
             [ "owner" ident ]                                   (* NEW «SG-9» *)
             [ "shared" ]                                        (* CHANGED «SG-21»: no new word *)
             "{" { constdecl | slotdecl | invariant | opdecl | treedecl | occdecl } "}" ;
(* `shared`: the carrier is reachable from more than one thread (`H013` as a declaration).
   A shared carrier HAS a guard (`protects` or `owner`) -- a shared carrier without one is
   not declarable; an unshared one belongs to one thread (`per cpu`, a stack, boot). This is
   the premise `Wettlauf.lean` takes for its race theorem. *)
(* `owner m` names a `linear type m;` whose mark every access to the table must hold. A table
   without `owner` and without `protects` is accessible from anywhere -- which is what a
   `static` is today. The FIRST mark is minted once, by a single foreign body returning the
   mark without taking it (`extern fn erste() -> Marke`: a named assumption, like every
   foreign body); no signature (re)produces it (`D266`, the checker half of
   `eigner_nie_erzeugt`), it travels by linear handoff (`M2`: exactly once, never doubled),
   and every access to the table -- read or write -- holds it (`D267`, reads through the
   very walk `E010` reads). The single mint executes exactly once: one static site, outside
   every loop, in a root nothing calls, started at most once (`D268`). One mint, one
   execution, no copy -- so a second owner of the same slots cannot come into being. A mark
   with no minter, no mint execution, or a minter no guarded access exercises, keeps the
   `D026` refusal; a malformed producer falls under `D265`-`D268`. *)
treedecl   = "tree" "{" kante { "," kante } [ "," ] "}" ;
kante      = ( "parent" | "child" | "sibling" ) ident ;
(* «B41b»: the edge on which `descendants of` and `ancestors of` run -- ONCE at the table
   (`T001`-`T003`: the field exists, it is `option index into Self`, no edge twice). *)
occdecl    = "occupied" ident ";" ;
(* The field at which a slot is OCCUPIED (`D010`/`D011`) -- the premise `sigma s = Some sl` of
   `Table_Ops_Erhaltung.thy` as a declaration. *)
opdecl     = "ops" opname { "," opname } ";" ;
opname     = "insert" | "remove" | "relabel" ;
(* «NL.1»: the operation set is CLOSED. `T::insert(t, n [, p])`, `T::remove(t, s)` are
   ordinary calls; `relabel` gets no call form because it gets no body. *)
walkdecl   = "walk" ident "levels" constexpr "{"
               "node" ":" array ","
               "down" ":" ident "when" pred ","
               "leaf" ":" pred ","
               { invariant }
             "}" ;
slotdecl   = "slot" "{" [ slotfeld { "," slotfeld } [ "," ] ] "}" ;
slotfeld   = ident ":" slottype [ "by" "ops" ] ;
(* `by ops`: this field is written ONLY by the generated operations -- `refcount -= 1` by hand
   is not writable. CHANGED «SG-8»: as shape, the field's carrier is in the `writes` of the
   generated operations and of no other function. *)
arena      = [ "pub" ] "arena" ident "capacity" constexpr ".." constexpr "of" typeexpr ";" ;
(* «E4» (§9.1): a monotone region beside the table -- no body, no slots, no guards. Only
   `..` joins the bounds: both count elements, so `..<` would be a second spelling of
   `hi - 1`. *)
slottype   = typeexpr | intty "wrapping" ;
invariant  = "invariant" ident "cost" costexpr "runs" ( "online" | "offline" )
             [ "by" inductlist ] ":" pred ";" ;
costexpr   = "O" "(" expr ")" ;

format     = [ "pub" ] "format" ident [ "@version" int ] [ "endian" ( "little" | "big" ) ]
             "{" { field } "}" ;
reason     = "reason" ident "{" { ident "=" int string } [ "exhaustive" ] "}" ;
state      = "state" ident "{" { transition } "}" ;
```

**`count` is the ADDRESS SPACE, `backed` the MEMORY:** `count N` says how many places the type
knows; `backed k` names the VALUE up to which they are backed — `M103` holds every index
against the declared bound, and with `backed` that is `k`, reached by `narrow i to 0 ..< k`.

**`@version` — the REFUSAL, decided 2026-08-21.** Gabbro does not migrate between format
versions; two `format`s of one name in one scope fall to `N001`, and `@version` has no reader.

**Attributes and Lean.**

| declaration | reading | Lean |
|---|---|---|
| `table T count N { slot { f : τ } }` | a carrier with `N` slots; every access carries `i : index into T` and the guards of `T` | `D.Tab`, `D.count`, `D.Feld`, `D.typ`, `D.braucht` |
| `arena A capacity lo .. hi of T` | a monotone region: `lo` the reservation, `hi` the hard bound (`0 <= lo <= hi`, both constants — `N210`); `A[i]` reads `T`, `alloc` stores it, `reset` starts a fresh generation | `Arena k g`, `ArenaIdx g n`, `Marke g` (`grammatik/Grammatik/Arena.lean`); theorems `alloc_innerhalb_reserve`, `keine_fragmentierung`, `reset_used`. **In the SYNTAX since 2026-09-15**: `ArenaForm D` (`ArenaZucker.lean`) — a table of `count = hi` slots beside a global `used` counter, which is what the emitter writes |
| `owner m` | `marke m ∈ Λ` at every access — **refused as `D026` until the producer stands**: a declared `linear` mark (`D265`), exactly one foreign minter executed once (`D266`/`D268`), every access holding it (`D267`); the first mark is minted once and travels by handoff (`kbedingung.rs::eigner`, poison `gift/694`, producers `beispiele/114`/`115`, poisons `gift/932`-`935`) | `D.eigner`, `D.braucht` (`.inr (m, s)`) — **the one construction that makes memory safety a matter of Λ**: no owner, no access; one mint, one execution, no second owner |
| `backed k` | `narrow i to 0 ..< k` before the access — SUGAR over `narrow` | `Block.narrow` |
| `invariant I … : p` | `I` is owed by every function whose `effects` writes `T` («SG-10»); evaluated at every `return` of such a function — and **such a function holds the locks of every carrier of `I`** (`U003` as a declaration rule: `invarianten_gehalten`), because it reads them all at `return` | `D.Inv`, `D.traeger`, `Programm.invariante`, `schuldet` → `logik (invariante i)` |
| `owner m`, `shared` | a shared carrier has a guard; an unshared one belongs to one thread | `D.geteilt`, `D.geteilt_bewacht` («SG-21») |
| `ops insert, remove` | **generated functions** with `requires` (the slot is fresh, the parent reachable, `s` a leaf — `D012`) and `writes T`; called like any function | `D.Fn` with a `Signatur`; `Stmt.call` — SUGAR over §6 |
| `tree { parent p, child c }` | which field `reaches … via` and the domains use | `Expr.reaches t f hf` with `hf : typ t f = opt (count t)` |
| `occupied f` | the field the generated `ops` test | the generated `requires` |
| `wrapping` | a field whose width, not range, is the type: `+` on it is `(a + b) % 2^w` — SUGAR over `rem` with the width as denominator | `Expr.rem` with a literal `2^w` |
| `by ops` | the field is in the `writes` of the generated operations and of no other function | `D.sigNr … .schreibt` |
| `walk W levels n { node : [Pte; 512], down : f when p, leaf : q }` | `n` tables of `count 512`, one per level; `mappings of` is a `traverse` per level, nested `n` deep, filtered by `p`/`q` — SUGAR («SG-16») | `D.Tab` per level; `Stmt.traverse` nested; `Expr.forallSlots` nested |
| `format F endian e { field @bitpos where p, … }` | a **view** on a byte carrier: a field `@[hi:lo]` at offset `o` is `(bytes(o, n) >> lo) & mask`, `embeds … scale s` multiplies, `endian big` reverses the byte list, `offset_into` is the offset's bound at the read; **`where p` is a check at the field's read**: the condition, or the named `else` of the enclosing `let … else` | `Expr.leseBytes`, `Zucker.Expr.bitfeld/embeds`, `bytesZuZahlBig`; `Block.pruefung c sonst rest` («SG-16») |
| `reason R { A = 1 "…", B = 2 "…" }` | `n` grounds; the number is for the report, not the calculation (`M124`) | `Ty.grund n` |
| `state S { transition t { f : A -> B } }` | the declared transitions of a field; `transition T.slots[i].f : A -> B;` is derivable only for a declared pair | `D.erlaubt t f von nach`; `Stmt.uebergang` («SG-19») |

```gabbro
format Elf64 endian little {
    e_phoff     : u64 offset_into Self where e_phoff + e_phentsize * e_phnum <= lenof(Self),
    e_phentsize : u16 in 56 .. 56,
    e_phnum     : u16 in 0 .. 65535,
}
```

`offset_into Self` binds the offset to the buffer length; the `where` clause is the **only**
additional statement and is a `pruefung` at the read.

### 9.1 Arenas — a heap that is never unbounded («E4»)

**Specified, the words lexed, the declaration checked.** `PLAN-ERWEITUNG.md` §3 fixes the
owner's rule — *a heap is allowed but never unbounded: every region has an upper and a
lower bound* — and the arena is the monotone form: release only as a whole (`reset`),
no fragmentation, allocation fails only beyond the upper bound. The pool form (fixed
element size, per-element release) exists already: every `table T count N` with generated
`insert`/`remove`. The general bounded heap is not built until a concrete case forces it.

**The surface** — one declaration, two statements, one read:

```gabbro
arena Log capacity 2 .. 8 of u32;

impl fn nutzen() -> u32 effects { writes Log } costs <= 16 ops {
    let a = alloc Log (10);
    let b = alloc Log (20);
    let c = alloc Log (a + b) else {
        return 0;
    };
    reset Log;
    let d = alloc Log (c);
    return Log[d];
}
```

* The declaration holds the reservation `lo` and the hard bound `hi` (`N210`
  holds `0 <= lo <= hi` over constants) plus the element type. It emits a static
  array of `hi` elements beside a `used` counter — no heap allocation in the C.
* `let i = alloc A (v)` stores `v` in the next free slot and binds its index,
  typed `index into A` of the current generation. The `else` runs when the arena
  is full; it is owed exactly when the static allocation count since the last
  reset may exceed the reservation (`N212`) — counted like `costs`, joined with
  the maximum at branches, saturated across loops.
* `A[i]` reads. A place over an arena is exactly `A[i]`, and `i` is an index of
  `A` (`N214`); the slot is never written outside `alloc`.
* `reset A;` consumes the generation and starts a fresh one: the counter goes
  back to zero, and an index bound before is stale afterwards (`N211`).

*Lean:* the generation is a type index (`Arena k g`, `ArenaIdx g n`, `Marke g`
with a private constructor), so a stale index does not typecheck; `alloc`
succeeds exactly below the bound (`alloc_erfolg`/`alloc_fehlschlag`), the first
`lo` allocations after a reset never fail (`alloc_innerhalb_reserve`), and the
indices are contiguous (`keine_fragmentierung`). The checker's generation
counter and its static count are the shadow of those types over one body —
counted per function, like `costs` (a reservation shared across functions is
future work, not a silent promise).

---

## 10. Devices — and trap 4

```ebnf
device  = [ "pub" ] "device" ident [ "(" params ")" ] "at" space
          "{" [ mirrors ] { regdecl | bank | transition } "}" ;
mirrors = "mirrors" place "from" place ";" ;       (* ONCE per device, not per transition *)
bank    = "bank" ident "at" expr "stride" expr "count" expr "{" { regdecl } "}" ;
regdecl = "reg" ident ":" intty [ "wrapping" ] "@" expr
          "class" regklasse [ regphasen ]
          [ "fields" "{" [ regfeld { "," regfeld } [ "," ] ] "}" ]
          [ "requires" pred [ "else" ident "::" ident ] ]
          [ "depends" "{" [ carrier { "," carrier } [ "," ] ] "}" ] ;
(* «B26»: the `else` is the FALSIFIER; with it the READ is fallible and must stand in a
   `let … else` (`R011`). Why no fact is made of it: the register is volatile, and a hostile
   device may report anything. *)
(* Lane 140: `depends` names the device-state carriers the register's answer may rest on
   (§10, `D.rtraeger`). A bare carrier only (`N258` refuses `T.feld`); unknown names
   (`N255`) and declared non-carriers (`N257`) fall beside it. *)
regklasse = "r" | "w" | "rw" | "w1c" | "rc" ;
regphasen = "in" ident { "," regklasse "in" ident } ;
(* «B18»: a class per STAGE of a declared `order` (`R009`: every stage named exactly once).
   At the access the stage of the mark in Λ decides (`R005`/`R006`); where NO mark of this
   order is in scope, what EVERY stage allows holds. *)
regfeld = ident "@" bitpos [ "class" regklasse ] ;
carrier  = ident [ "." ident ] ;                    (* the head names the carrier; see §10 *)
transition = "transition" ident "{" transset "}"
             [ "requires" pred ] [ "effects" "{" efflist "}" ] ;
transset   = placeshift { "," placeshift } ;      (* SEVERAL places in ONE move *)
placeshift = shiftplace ":" expr "->" expr ;                   (* G3 *)
shiftplace = ident { "." ident | "[" expr "]" } ;
```

```gabbro
device Vtd(base: Pa) at mmio {
    reg GCMD : u32 @0x18 class w fields { TE @31, SRTP @30, IRE @25 }
    reg GSTS : u32 @0x1c class r  fields { TES @31, RTPS @30 }
    reg CAP  : u64 @0x08 class r  fields { FRO @[33:24], ND @[2:0] }

    bank FRR at CAP.FRO * 16 stride 16 count 256 { reg FR : u64 @0x8 class rw }

    mirrors GCMD from GSTS;          -- ONCE: all state bits come from GSTS

    transition arm_te { GCMD.TE: 0 -> 1 }
        requires GSTS.RTPS == 1
        effects  { writes GCMD }
}
```

**`mirrors` kills trap 4, and `class w` alone did not.** `transition scharf_te { GCMD.TE: 0
-> 1 }` lowers to **one read of the mirror and one write** — the `0 ->` half says *which* bit
the write replaces; every other bit comes from the mirror.

**Attributes and Lean — CHANGED «SG-15»: the class is an attribute of the access.**

| spelling | attribute | outcome | Lean |
|---|---|---|---|
| `reg R : τ @off class K` | a register of type `τ` and class `K` — **outside the world**: a device is not a carrier | | `D.Reg`, `D.rtyp`, `D.rklasse`, `Regklasse` |
| `let x = R;` | `K` is readable (`r`, `rw`, `w1c`, `rc`); the machine answers **raw**, the answer is held against `τ` | **`hardware (register r)`** if outside `τ` | `Block.regLies r hk rest`; `Orakel.regLies` |
| `let x = R else (e) endblock;` | additionally `R`'s `requires p` is checked **on the binding**; the `else` does not fall off | — | `Block.regLiesElse r hk zusage sonst rest` |
| `R = e;` | `K` is writable (`w`, `rw`, `w1c`) | — (the world is unchanged: the device is not in it) | `Stmt.regSchreib r hk e`; `Orakel.regSchreib` |
| `transition t { R.b : 0 -> 1 }` | `R` writable, `m = mirrors(R)` readable (a declaration fact, `D.spiegel`); ONE read of `m`, ONE write of `R`: `(m & ~mask) \| bits` | | `Stmt.transition` — core, not sugar («SG-15») |
| `class rw in setup, r in live` | the class is a function of the **stage** of the order mark in Λ: `hk` is `(rklasse r (stage of m in Λ)).lesbar` | | `D.rklasse` per stage — the core carries one class per register and the staged form is its `D` built per stage |
| `fields { b @31 class r }` | a field with its own class: a register per field — SUGAR | | `D.Reg` per field |
| `bank B at e stride s count n { reg … }` | `n` registers with an index of `index into B` — a table of registers | | `D.Reg` per index; the index is `Ty.index n` |
| `mirrors W from R` | the source of the carried bits — a declaration fact read by the `transition` sugar | | none |
| `requires p` at `reg` without `else` | **the device's promise, held at every read** — a value that breaks it is `hardware (geraet r)`: the assumption about the device, named at its register (turn 3 of 2026-09-09: "devices go through hardware assumptions") | `hardware (geraet r)` | `D.rzusage r`, `Block.regLies` |
| `reg R : τ @off class K … depends { C1, C2 }` | the device-state carriers the answer of `R` may rest on — tables or globals of this unit, bare names (`N258` refuses `T.feld`: a slot is not a carrier in the model); a function reading `R` holds by signature a lock guarding each carrier some function writes, or the carrier is written by none (`N256`) | `hardware (reglokal R)`, one manifest line per register with its carriers | `D.rtraeger r` |

**`depends` carries the device into the footprint (lane 140).** `ziel_ort_geraet` admits a
register read only under two premises the checker establishes per program. The first is
hardware: `RegLokal` — the answer of `R` depends on the carriers `D.rtraeger r` alone, so
two reads agree wherever those carriers agree. The second is a decidable program fact:
`fussOrtGB` — every such carrier is guarded by a lock the reading function holds BY
SIGNATURE, or is written by no function at all. `depends { … }` is where the declaration
names those carriers, and the manifest lists the assumption per register with them
(`hardware (reglokal R)`), beside the named `assume` items — it is a hardware assumption,
not a proof.

Three refusals hold the clause itself: `N255` (a name nothing declares), `N257` (a declared
item that is no carrier — a lock, a device, a register, a function), `N258` (a dotted
place: carrier granularity is the model's, and `GleichAuf` cannot see a slot). What the
clause does NOT buy: a reader that takes the guard only in a `locks` block is still
refused (`N256` holds `requires Held(L)`, never a block — the repaired machine has no
bare lock steps); writes to the carriers from another unit are outside the cut (the
unwritten disjunct reads this unit's declared `writes`); and a device whose answer moves
with no write to its carriers violates `RegLokal` itself, which no grammar establishes.

```gabbro
module abhaengigkeiten {

table Zustand count 4 {
    slot { bereit : u32, }
}

lock Sperre protects { Zustand } rank 0;

device Geraet(basis : u64) at mmio {
    reg ST : u32 @0x00 class r depends { Zustand }
}

-- The reader holds the guard BY SIGNATURE: `Sperre` protects `Zustand`, and
-- `Zustand` is written below, so the read of `ST` needs `requires Held(Sperre)`.
-- A lock taken only in a `locks` block does not count (`N256`).
impl fn lesen(d : Geraet) -> u32
    requires Held(Sperre)
    effects { reads d }
    costs <= 8 ops
{
    let stand = d.ST;
    return stand;
}

impl fn schreiben(i : index into Zustand, w : u32) -> u32
    requires Held(Sperre)
    effects { writes Zustand }
    costs <= 8 ops
{
    Zustand.slots[i].bereit = w;
    return 0;
}

}
```

> **Devices go through hardware assumptions — and every one is named.** A register is not in
> `World D`: its value is whatever the oracle answers, and a write does not change the world.
> That is *"a hostile device may report anything"* as semantics. What the grammar holds it to
> is the DECLARATION: the type (`hardware (register r)`), the promise (`hardware (geraet r)`),
> the mirror (`transition` reads it, by construction), the class (not derivable otherwise). The
> **order** in which the device sees two accesses is the one thing left to an `assume` with a
> falsifier (`dma_visibility_in_order`) — and it is left there because no grammar can see a
> bus.

---

## 11. Concurrency

```ebnf
atomicdecl  = [ "pub" ] "atomic" ident ":" typeexpr
              [ "publishes" nutzlast ]                          (* G1 *)
              [ "acquire" | "release" | "seq" | "relaxed" ]
              [ "observed" "by" ident ] ";" ;
(* «V9»: `observed by <assume>` -- the other side stands in SILICON; the assumption carries
   the pairing, with a falsifier (`N031`). *)
publishstmt = place "=" expr "publishes" nutzlast ";" ;
nutzlast   = "{" placelist "}" | "nothing" ;
lockdecl   = [ "pub" ] "lock" ident "protects" "{" placelist "}"
             "rank" constexpr [ "held" "<=" constexpr "ops" ]
             [ "shared" "held" "<=" constexpr "ops" ] [ "masks" ident ]
             [ "invariant" pred ] ";" ;
lockstmt   = "locks" [ "shared" ] place block ;
rcudecl    = "rcu" ident "protects" "{" placelist "}" [ "reclaims" place ] ";" ;
observestmt = "observes" ident block ;
gruppedecl = "group" ident "over" "{" ident { "," ident } [ "," ] "}"
             ( "{" { invariant } "}" | ";" ) ;
concurrentdecl = "concurrent" "{" path { "," path } [ "," ] "}" ";" ;
(* «SG-23»: the declared-concurrent bodies -- paths, not idents (dispatch roots or
   scheduler entry `fn`s); one member at least, trailing comma allowed like `group`. *)
```

```gabbro
lock CAPS protects { plaetze, cdt } rank 2 masks irqs;
atomic COLOR_DONE : bool publishes { color_report } release;
group Zustellung over { Endpunkte, Faeden } {
    invariant wartende_haben_grund cost O(n) runs offline :
        forall e in slots of Endpunkte :
            Faeden.slots[Endpunkte.slots[e].wartet].gruende > 0;
}
```

**Attributes and Lean — the race discipline as shape.**

| spelling | attribute | Lean |
|---|---|---|
| `lock L protects { T, G } rank n` | every access to `T`/`G` carries **`Held(L) ∈ Λ`** (`H007`); reads and writes alike («SG-6a») | `D.Lock`, `D.rang`, `D.braucht t = [.inl L]`, `darf` |
| `lock L protects { T, G } rank n invariant p` (lane 156) | **`p` reads only `T`/`G` and named constants** (`N275`/`N277`) and is a **pure** contract expression — no `old`, no `result`, no call, no `Held`, no quantifier (`N276`); every `locks L` body re-establishes it at release, and that duty is **recorded, not decided** (obligation kind `L`, like `ensures`) | `SperrInv` (`SperreSem.lean`): `orte L = [T, G]`, `inv L` the predicate over the snapshot; `gabbro lean-g` prints the family with the guard half of `SperrInvOk` by `decide` |
| `locks L blk` | **`rank(L) > rank(M)` for every `Held(M) ∈ Λ`** (`H006`) — CHANGED «SG-7»; the body's Λ is `Λ + Held(L)` and ends with it (the witness is not consumable); the lock is released at the closing `}` | `Stmt.locks L hr body` with `hr : ∀ M, Res.held M ∈ Λ → rang M < rang L`; theorem `sperre_steigt`, **`keine_verklemmung`**: two bodies each holding one lock and each deriving a `locks` on the other's do not exist — `rang L1 < rang L2 < rang L1` |
| `locks shared L blk` | a second witness kind on the same lock: `Held(L, shared)`; a write under it is not derivable | a second `D.Lock` value paired with `L` in `D` (SUGAR) |
| `held <= n ops`, `shared held <= n ops` | cost bounds — the emitter's, §16 (7) | none |
| `masks irqs` | the state the lock establishes; `H102` reads it against `via idt` entries — a statement about two bodies, §16 (1) | none (declaration fact) |
| `rcu D protects { T } reclaims p` | `observes D` is a **lock without rank** whose witness the reads of `T` require (`H009`); a write of `T` requires a real lock in addition (`H010`); `reclaims` names the return site, which must stand under the writer's lock and not in `observes` (`H011`/`H012`) — all four as `braucht` lists | `D.Lock` (rank `0`, never compared: `observes` derives no `locks` inside it) + `D.braucht`; the **grace period** is an `assume` |
| `observes D blk` | | `Stmt.locks` on the RCU lock (SUGAR) |
| `atomic A : τ publishes { p, q } release` | a global whose writes carry the payload; `V001`–`V004` (every publication has an `awaits` with the **same** set) as shape («SG-13») | `D.Glob`, `D.nutzlast g` |
| `A = e publishes { p, q };` | `{ p, q } = nutzlast(A)`; `writes A` | `Stmt.publish g e payload hp hw hL`; theorem `publish_paart` |
| `let x = A awaits { p, q };` | the same set | `Block.awaits`; theorem `awaits_paart`. The awaits-then-act gap (a load that rebinds clean and is never revalidated) is named in §16.2 item 10 |
| `let x = A exchange update(v) { … } …;` | read–compute–write as one statement | `Block.exchange` |
| `acquire` `release` `seq` `relaxed` | the memory order — **the meaning of the publication is the memory model**, assumption A10 (`assume c11_release_acquire_*`), §16 (2) | none |
| `observed by a` | the other side is the assumption `a` | `D.Annahme` |
| `group G over { T, U } { invariant I }` | `I` has carriers `T` and `U`: owed by every function that writes either («SG-10»); `U003` (a function writing two carriers holds all their locks) is the `braucht` of each access, `U005` (two ranks equal) is `keine_verklemmung`'s premise, `U006` (leaving between the writes) is `schuldet` at every `return` | `D.Inv` with `traeger = [T, U]` |
| `concurrent { f, g }` | the declared-concurrent bodies («SG-23»): pairwise non-interference over the transitive hulls — shared writes fall (`W001`), undeclared overlapping roots fall (`W002`), incomplete hulls refuse (`W003`) | `Nebeneinander` premise in `Wettlauf.lean` — what stands in no set never runs concurrently. The joint run of N declared bodies is `GemeinsamerLauf` (`InterferenzAllgemein.lean`): one world chain, each step in its own frame, every pair declared; lock-shared carriers carry an invariant each (`TraegerInv`), and `AllgemeinStabil` proves it: sequentially valid assertions survive to the last chain world (shared-side preservation per step assumed, entry validity at the chain head). Reads already overlap freely under W001 (only writes need the lock); the stable-reads shape below names why they stay stable |
| `accumulates` (§1) | a global plus a generated `merge` assignment; `per cpu N` is the cell table | SUGAR |

**What the discipline proves — over interleavings, since the evening of 2026-09-09.** Every
access to a carrier derives its guard, every `locks` derives its rank, every publication
derives its pairing — properties of one derivation. `Semantik.lean` now writes a **trace**: the
world carries every access with the static Λ of its site and the locks dynamically held, and
every `nimmt`/`gibt`. `Satz.lean` proves (`exec_spur`) that every event a body leaves behind
carries its guards, holds every lock its Λ names, takes no lock twice and none out of rank,
and that the trace stays consistent. `Wettlauf.lean` then takes **any interleaving** of such
traces and proves:

| theorem | statement | premise beyond the traces |
|---|---|---|
| `kein_wettlauf` | two accesses of different threads to one table are ordered by happens-before (program order, and `gibt L` before `nimmt L`) | (W3) a lock excludes: whoever takes `L` takes it while no other thread holds it — what a lock IS, the promise of the lock primitive (a foreign body); (W4) a mark is in one thread — linearity, no statement moves a mark across threads; (W5) an unshared carrier belongs to one thread — `shared` |
| `kein_wettlauf_global` | the same for a global, **or the global is `atomic`** — and then the machine orders it (A10, `hardware (sichtbarkeit)`) | the same |
| `keine_ueberkreuzung` | no thread takes `L2` holding `L1` while another takes `L1` holding `L2` — the wait chain a deadlock needs has no beginning | none: it is `keine_verklemmung` over runs |

**There is no third case.** A conflicting pair of accesses is either happens-before ordered, or
on an `atomic` — whose ordering is the memory model, a named hardware assumption. §16.2 (1) of
the morning is closed; what remains of it is the premise (W3), booked where the lock
primitive is booked.

### Per-form atomicity — which emitted forms are single accesses

Section 11 proves properties of derivations: every access derives its
guard, every publication derives its pairing. What it does not say is what
the emitted C lowers to on the machine — whether one Gabbro statement
becomes one memory access, which no concurrent observer can tear, or a
sequence of accesses, whose middle it can. That mapping was measured on
three corpus units at two optimisation levels and ruled. The rule: a form
is admitted as tear-free exactly when the inventory shows a single machine
memory access at both levels; admission is never free, and each admitted
row carries its price. A sequence form is refused as self-sufficient and
names the exact guarantee that redeems it.

Bounds, stated once for the whole table: every verdict below holds on
x86_64 with GCC 16.2.1 at optimisation levels -O0 and -O2, and
nowhere else is claimed. Only lock-prefixed instructions are atomic
read-modify-write in this table; a single non-locked read-modify-write
instruction is one instruction with two observable halves, a sequence in
consequence, not an atomic form.

Admitted — single access at both levels, with price:

| emitted C form | Gabbro source | machine shape, both levels | price of the admission |
|---|---|---|---|
| slot plain assign | plain assign to a slot field | single narrow store at -O0 and -O2 | aligned narrow store; one non-torn write, no ordering claim beyond it |
| shared global plain assign | plain assign to a static global | single 8-byte store at -O0 and -O2 | eight byte alignment; one non-torn write, no read-modify-write atomicity, no ordering |
| atomic compare-exchange | exchange with declared ordering | single locked compare-exchange at both levels | the declared ordering itself |
| release store and acquire load | publishes store and awaits load | single narrow store and load at both levels, no fence emitted | x86 total store order plus the compiler barrier; re-measure on any weakly ordered arch |
| lock take and release | locks block entry and exit | one call instruction per op at both levels | atomicity lives outside the unit: the body is foreign |

Refused — sequence at one or both levels, with consequence:

| emitted C form | Gabbro source | machine shape | guarantee needed | what breaks without it |
|---|---|---|---|---|
| slot compound assign | compound assign on a slot field | load, operate, store at -O0; single unlocked memory-operand instruction at -O2 | exclusive access; the atomic form is the upgrade path | lost update under concurrency |
| guarded compound assign | compound assign inside a guard | load, operate, store triple at both levels | exclusive access; the guard sits beside the sequence, never merges it | the same lost update; the guard refines when the sequence runs without merging it |
| relaxed merge-add | accumulates report path | load, add, store sequence at both levels | single-writer-per-cell | concurrent writes to one cell tear; mid-sequence reads see the middle |

Volatile register access carries no verdict (no measured unit emits a
volatile site; the `fluechtig` table row stays open, carried as an axiom
by name). Any later lane that cites a machine shape names the level, and
any port names the arch and re-measures the atomar rows.

### Stable reads — the read half beside the write half

A carrier that no declared-concurrent body writes is read-only shared
data, and every concurrent read of it is stable: the foreign frame never
touches it, so disjointness holds by absence of writes, not by lock. The
pair check refuses overlapping shared writes and lets shared reads
overlap freely — and the stability theorems say why: a foreign step in a
disjoint frame preserves every assertion that reads only its own frame.
The config-table shape is the standing instance (dispatch tables,
capability tables, calibration constants, filled before the concurrent
set starts and written by nobody inside it). What the shape costs is
stated beside it: the read-only claim is a whole-set claim, so adding a
writer anywhere in the set moves the carrier out of this subsection and
under a lock, an atomic, or a pairing rule. Lean:
`Grammatik/LesenStabil.lean` (`RequiresLiestIn`, `EnsuresLiestIn`,
`InvarianteLiestIn` via hull bridges; `LesenStabilKette` folds the
whole-set claim to the last world; `requiresStabil_kette`,
`ensuresStabil_kette`, `invarianteStabil_kette`).

Contract reads stay inside the frame: `requires`/`ensures`/`invariante`
evaluations read only their frame (`haengtAb_requires_bei_Lesen`,
`haengtAb_ensures_bei_Lesen`, `haengtAb_invariante_bei_Lesen`), and a
foreign step disjoint from it preserves the verdict on both sides. Lock-
shared carriers are excluded here by construction (ordered by
happens-before, not preserved by stability); the footprint direction for
abstract assertions stays a premise.

### `concurrent`, `effects`, `shared` — from declaration to computation

The three declarations that feed the closed-world check arrive computed,
not transcribed. `effects { writes T }` is the footprint source: per body,
filtered over the declared carrier domain, it IS `Bau.schreibtFn` — a
function without `effects` is already a compile error, so the source is
total. Direct calls (`f(…)`, `let x = f(…)`, `… else …`) are the edge
source: they ARE `Bau.ruft`, restricted to the declared function domain.
`concurrent { … }` members resolve to thread numbers over the entries and
ARE `Bau.neben`. What the computation drops (a call outside the domain, an
effect outside the carriers, a pair outside the entries, any indirect or
foreign call) the checker REFUSES — the fidelity shapes state exactly
that. Unknown carriers count as `shared`: the loud direction, demanding
the guard. Lean: `Grammatik/Extraktion.lean` (`bauAus`, `bauLaufSpiegel`,
`kantenTreue`, `fussTreue`, `paarTreue`, `paarVoll`); premises consumed:
`Geteilt.Bau`/`BauLauf`/`traegerBis`, `Nebeneinander` (`Wettlauf.lean` §6).

---

## 12. Hardware assumptions and axioms — **load-bearing, not trimming**

```ebnf
assume = "assume" ident [ "arch" ident ] string
         ( "falsifier" ident | "unfalsifiable" string ) ";" ;
axiom  = "axiom" ident "(" [ params ] ")" [ "->" typeexpr ]
         [ "requires" pred ]                                    (* G2 *)
         "effects" "{" efflist "}"
         ( "falsifier" ident | "unfalsifiable" string ) ";" ;
```

```gabbro
assume vtd_te_effective
    "GCMD.TE switches translation on; DMA without a context entry faults."
    falsifier probe_vtd_te;

assume dma_visibility_in_order arch x86_64
    "Two volatile accesses in program order become visible to the device in that order."
    falsifier probe_dma_order;

assume x2apic_two_step
    "EN and EXTD in one write is a forbidden transition."
    unfalsifiable "qemu64 has no x2APIC";

axiom write_cr3(p: Pa) effects { writes tlb, writes active_table } falsifier probe_cr3;
```

**`arch` at an assumption is OPTIONAL** («B40»): an assumption about a timer holds on every
machine this unit targets; one about caches, barriers or register semantics names one
architecture, and `A005` holds the name against a declared `arch`. **Three classes, and the
third does not exist syntactically:** *falsified*, *not falsifiable* (with a reason), *not
run* — the absence of both statements, a compile error.

**The assumption set is emitted into the artefact** ("proved under A1…An") as a **set of names
with a class**. The promise is relative, and that stands in the artefact instead of in a
footnote: *memory-safe under A1…An*.

**Attributes and Lean — this is where `hardware` comes from.**

| spelling | reading | Lean |
|---|---|---|
| `assume a "…" falsifier p` | a **named** assumption; the grammar makes sure it is named at every site that rests on it (`progress`, `retires`, `observed by`, `entrust … assume`) | `D.Annahme`; `Hardware.fortschritt a` |
| `axiom x(params) -> τ requires p effects { … } falsifier q` | a **foreign body**: the machine acts (H1, the `Orakel`), the answer is held against `τ`; `requires p` is a `pruefung` before the call (SUGAR); the axiom's `writes` ⊆ the caller's | `D.Ax`, `Orakel.wirkt`; `Stmt.axiomCall`, `Block.bindAxiom` → **`hardware (annahme a)`** |
| that an axiom writes **only** its `effects` | **an assumption, not a theorem** (`SYNTAX.md` v2:1646 booked it as A_n) — the premise `RahmenO` of `exec_rahmen` | `RahmenO O` |

> **The axiom layer is the largest unproved surface of the language** — larger than the
> compiler — and therefore countable and ratchetable. In the theorem it is exactly the
> parameter `O : Orakel D`, and `#print axioms` at the end of `Satz.lean` shows that nothing
> else was assumed.

### 12.1 `syscall` — the user side of a system call (checked since lane S5)

**Specified since «SS-1», checked since lane S5.** What
follows is the surface of `PLAN-SYSCALL.md` §1, written as grammar, named checks
and one example, so that the checker lane (S5), the emitter lane (S6) and the
corpus lane (S7) have a text to build against. Every `syscall`
item is held against its own shape -- register map, errno decoding, machine and
counterpart -- and the emission is refused as `C001` until the lane-S6 stub
lands. The example block is an excerpt (`…`), not a
translation unit.

**The checks** — each names the passes of §1 it mirrors (`G4`, `G7` at
`entrydecl`; `A005` at `assume`). The `syscalldecl` production whose lines
they point at stands in §1 beside `entrydecl`.

* **arch** — the `arch` after `abi` is held against a declared `arch`, as for
  `assume` (`A005`). A syscall for a machine no `arch` declares is refused.
  **x86_64 only** — `aarch64` stays sealed (`A006`).
* **register map** — `regs in` / `regs out` / `clobbers` carry the same checks
  as `entry` (`G4`, `G7` at `entrydecl`): the in-registers are pairwise
  distinct (`N063`), no out register is clobbered (`N064`), every parameter is
  bound exactly once (`N065`), and every named register is one of the sixteen
  x86_64 general registers (`N066`); `clobbers` may be empty.
* **error map** — `errors` is a total map from the errnos the contract admits
  to the declared reasons (`or R`): every admitted errno has exactly one arm,
  every target is a case of the declared channel (`N067`). The decoding is
  generated; an errno outside the table is `hardware (annahme a)` — the kernel
  answered outside its contract.
* **`assume … falsifier …` or `kernel <path>`** — with `kernel`, the call is
  paired with a Gabbro kernel's dispatch `entry` for the same `number` and no
  assumption is named (refused as `N068` until the pairing check lands); with
  `assume`, the per-call assumption is named with its falsifier, as for a
  device (`N004`/`N005` shape).

**Two places where the written example fixes the production's letter** (measured
at the build, lane S5): the §1 production line says `regbind` (`ident ":"
ident`, entry order) for both maps, but every written example — `PLAN-SYSCALL.md`
§1, the block below, the probes — writes `regs in { rdi = fd }` (register
first, `=`) and `regs out { rax }` (bare registers). What parses is what the
examples write, with `:` accepted beside `=` at `regs in`; a `regs out` pair
has no reading (the out value has no Gabbro-side name) and falls at the parser.

```gabbro
syscall write(fd : Fd, buf : ptr<normal, r> Bytes, len : u64 in 0 .. MAXLEN)
    -> u64 in 0 .. MAXLEN or IoError
    abi linux arch x86_64 number 1
    regs in  { rdi = fd, rsi = buf, rdx = len }
    regs out { rax }
    clobbers { rcx, r11 }
    errors   { EBADF => BadFd, EINTR => Interrupted, EAGAIN => WouldBlock }
    requires Open(fd)
    ensures  result <= len
    effects  { reads buf, writes os.fds }
    assume   linux_write_contract falsifier sonde_write;
…
```

*Lean:* a `syscall` declaration is an `Ax` with `sysabi` (number, register
map, clobbers — consumed only by the emitter); the answer type is the sum
`ok value | reason r`, filled by the generated errno decoding; `einpassen`
holds the raw answer against it. Ghost OS state (`os.fds`, …) is tables the
semantics treats like any carrier and the emitter omits.

### 12.2 `profile` — the one hardware profile, and what libraries require (lane E6)

**Specified and checked («E6», the checker half of `PLAN-ERWEITUNG.md`
§0c).** The main program declares the profile: the one set of hardware
assumptions the whole program runs under. A library does not assert
assumptions; it requires profile entries, by reference to the declared
assumption, never by a copy of its text. Linking refuses a library whose
requirements are not in the profile — consistency is a subset check
against one set, decidable and cheap.

```ebnf
profiledecl     = "profile" "{" { profileentry } "}" ";" ;
requiresprofile = "requires" "profile" "{" { profileentry } "}" ";" ;
profileentry    = ( "arch" | "rounding" | "fp_contract" | "memory_model"
                  | "interrupt_routing" ) ident ";"
                | "assume" ident ";" ;
```

```gabbro
assume gpu_progress
    "The GPU retires one work item per clock."
    falsifier sonde_gpu_tick;

module gpu::spirv {
…
requires profile {
    arch x86_64;
    fp_contract off;
    assume gpu_progress;
};
…
}

profile {
    arch x86_64;
    rounding nearest;
    fp_contract off;
    memory_model c11;
    assume gpu_progress;
};
```

**The checks** — each names what the declaration carries, plus the five
things only a profile can fail:

* **one profile** — at most one `profile` block per unit; the second falls
  (`N219`). Two profiles are two sets, and merging them silently would hide
  exactly the conflict below.
* **key agreement** — two keyed entries with one key and different values
  are refused at the block itself (`N215`), in `profile` and in `requires
  profile` alike. Duplicates with one value are silent: a set holds them
  once.
* **same name, same content** — an `assume <name>` entry references the
  declared assumption; where two declarations under that name carry
  different statements, the reference is ambiguous and falls (`N216`). A
  reference naming no declared assumption falls beside it (`N219`).
* **linking** — every requirement of every library stands in the program's
  profile with identical content (`N217`): a keyed requirement needs the
  key with the value, an `assume` requirement a profile reference to a
  declaration with the same name and content.
* **platform** — `fp_contract` other than `off` contradicts the float
  prelude, which binds `-ffp-contract=off` for every compiler
  (`PLAN-BITS.md` §5); an `arch` the unit never declares contradicts the
  declared machines (`N218`). Without declared machines nothing is
  refused — a unit with no machine named constrains no machine.

**The manifest** lists every keyed profile entry (with the
`-ffp-contract=off` flag where the profile says `fp_contract off`) and
every requirement with its library and the calls relying on it
(`gabbro annahmen`).

| spelling | attribute | Lean |
|---|---|---|
| `profile { … }` | the ONE assumption set of the program theorem | `Profil`, `Profil.gut`, `profil_modell` |
| `requires profile { … }` | the library's requirements as name references | `Bibliothek`, `Profil.bindet`, `bindung_fuegt_nichts_hinzu` |
| `arch x86_64;` etc. | a keyed mode assumption: key plus value | `AnnahmeEintrag.modus`, `istModus` |
| `assume a;` | the declared assumption, referenced, never copied | `AnnahmeEintrag.frei`, `anforderungEintrag` |

*Lean:* the program theorem takes one assumption set, the profile; a
library's set is required to be a subset, so linking adds no premise. For
keyed mode assumptions the profile induces its own model
(`modusVonProfil`). All in `grammatik/Grammatik/Profil.lean`, witnessed.

---

## 13. `check` — the linear checking obligation

```ebnf
check = "check" ident "{"
          "claim"        string
          "measures"     placelist
          "gates"        identlist
          "can_fail"     block
          [ "floor"      predlist ]
          [ "counterprobe" string "expects" ident ]
        "}" ;
```

The compiler generates a `linear ghost Duty(ident)`. **Four compile errors fall out of
M1/M2/M3, not out of special rules:** `gates` missing → the obligation is never consumed;
`can_fail` missing → likewise; a quantity under `measures` that the **measured path** writes →
write right; a one-sided threshold without `floor` → the quantity has no range. `expects` names
an **external** probe that belongs to exactly one obligation (`N024`). Since «TB» a `check` can
stand under `when TESTBUILD`.

*Lean:* a `check` is a **mark**: `D.Marke` `Duty`, produced by the `check` (a generated function
with `allocs Duty`), consumed by the functions `gates` names (`consumes Duty` in their
signature). That is the whole construct — the linear discipline of §6 («SG-6») does the rest,
and *"the obligation is never consumed"* is *"`return` with a mark in Λ that `allocs` does not
name"*: not derivable.

---

## 14. Boot phase, machine state, assembler

```gabbro
opaque type Pa = u64;
linear ghost type BootPhase order { roh, mmu, geraete };
type Context = { sp : u64, };

walk PageTable levels 4 {
    node : [Pte; 512],
    down : frame when it.present && !it.large,
    leaf : it.present && it.large,
}

format Pte endian little {
    present : bool @0,
    large   : bool @1,
    pte_low : u64 @[11:2]  reserved,
    frame   : u64 embeds [51:12] scale 4096,
    pte_hi  : u64 @[62:52] reserved,
    nx      : bool @63,
}

const BOOT_FRAME_LOW  : u64 = 0x1000;
const BOOT_FRAME_HIGH : u64 = 0x2000;

raw fn phys_write(p: Pa, w: u64) requires BootPhase effects { writes phys };

fn boot_end(t: BootPhase, root: PageTable)
    ensures !exists m in mappings of root :
        m.frame >= BOOT_FRAME_LOW && m.frame < BOOT_FRAME_HIGH
    retires t from boot falsifier probe_boot_unreachable
    effects { consumes t, writes root };

prim fn switch_to(von: ptr<normal,rw> Context, zu: ptr<normal,r> Context) -> never
    effects { writes kontext };
prim fn resume(k: ptr<normal,r> Context) -> never effects { reads k };
divergent fn idle() effects { diverges };
```

`boot_end` consumes the **linear** token **and** retires the boot space — **one clause**
(`O011`); what disappears is said as a `walk` fact and demanded (`O012`); that an address without
a mapping is **unreachable** is a statement about the MMU and the probe the clause names is the
falsifier.

**Attributes and Lean («SG-18»).**

| spelling | reading | Lean |
|---|---|---|
| `raw fn`, `prim fn`, `extern fn`, `= asm { … }`, `entry`, `entrust`, `boot` | a foreign body: contract known, body the machine | `D.Ax`; `Stmt.axiomCall` → `hardware (annahme a)` |
| `-> never` | no `return` derivable | `Ty.never` |
| `divergent fn … effects { diverges }` | a foreign body that does not return: the call has no continuation — the statement after it is not derivable (the call is the `endstmt`) | `Ty.never` as `aerg` |
| `requires BootPhase` at a `raw fn` | the mark in Λ at the call (`O010`: somebody must retire it) | `Signatur.konsumiert` … `produziert` (borrowed) |
| `retires t from boot falsifier p` | Λ loses `t`; `p` is named in the term | `Stmt.retires` |
| `advances roh -> mmu` | the stage moves | `Stmt.advances` |
| `mappings of root` in `ensures` | nested `forallSlots` over the four level tables | SUGAR («SG-16») |
| `walk … levels 4 { node : [Pte; 512] … }` | four tables of `count 512` | `D.Tab` per level |

---

## 15. What deliberately does not exist

`while` · `for` · `goto` · `union` as reinterpretation · preprocessor · implicit conversion
(the widening of a range is an **attribute**, «SG-1») · `void*` · pointer arithmetic · **the
address of an expression** · catch-all branch · exceptions · inheritance · reflection · GC ·
assignment as an expression · forward declaration · self-hosting · user-defined quantifier
domains · recursion in `spec fn` · hand-written lemmas · **the braced compound literal** (`P037`)
· **migration between format versions** · **signed division** («SG-3»: `narrow` to `0 ..`
first) · **a `forever` without `progress`** («SG-11») · **an `else` that falls off** («SG-5») ·
**a `state` write that is not a declared transition** («SG-19») · **a register access against
its class** («SG-15») · **a publication without its declared payload** («SG-13») · **a second
owner of a carrier** («SG-9»).

Every item in bold after the first is new in the third version, and each one is an
**absence of a constructor** in `Syntax.lean` — not a refusal a pass issues, but a term that
cannot be written. `Satz.lean` §4 shows one (`x / x`: `.div` demands `1 ≤ 0`).

---

## 16. What the theorem says — and what it does NOT cover even with this syntax

> **Restated 2026-09-13 over the repaired call machine G.** The goal is proved,
> and the binding premise map is `dokumente/SATZKARTE.md` §11. What follows is
> the same content in the language of this file: the theorems as they stand now,
> in words and as the Lean names (§16.1); the premise classes, with the surface
> construct or checker rule behind each decidable premise (§16.2); and what the
> theorems do not cover (§16.3). §16.4 maps the twelve items of the 2026-09-09
> list onto the new stand, so every older `§16 (n)` reference in §§1-15 keeps
> its target.

### 16.1 The theorems as they stand

**`ziel_ort_geraet`** (`grammatik/Grammatik/ZielOrtGeraet.lean`). Over machine G —
no bare lock steps, every memory step carrying `HeldGenau`, every live frame's
static holdings held by its thread (`rufG_haelt_statisch`, `RufHaeltG.lean`) and
two threads never holding one lock (`exklusivG`, `ZielOrt.lean`) — every machine
reachable from the start machine satisfies `vertragAmOrtG`: at every `eintritt`
event of every thread log the callee's `requires` holds with the logged actual
parameters at the logged entry world (`ReqAmEintritt`, `VertragOrtB.lean`), and
at every `rueck` event the `ensures` holds with the logged entry world as the
`old` side, the logged return world, and the actual parameters and result
(`EnsAmRueck`). Contracts hold at their place — entry and return, with the
actual values — nothing is quantified away. The older theorems are legs of it:
`ziel_ort` (the loop-free, oracle-free fragment) and `ziel_ort_voll` (loops,
exits, reasons, axioms, indirect calls through `KandOk`, no register reads) —
and `ziel_ort_voll` on a register-local oracle follows from the flagship
(`ziel_ort_voll_lokal`). The joint witness is `ziel_ort_geraet_zeuge`
(`ZielOrtGeraetZeuge.lean`): two threads, a device register read twice, every
premise jointly. Axioms: `propext`, `Classical.choice`, `Quot.sound` only.

**`rennfrei_g`** (`RennfreiG.lean`). On any reachable run, a step that changes a
guarded carrier holds every guard of that carrier before the step, and after the
step no other thread holds that guard — two threads writing one guarded carrier
are always ordered through the lock. The adjacent form `rennfrei_g_nah` says two
steps back to back by different threads never both change one guarded carrier.
Witness: `rennfrei_g_zeuge`, a reached writing step that moves memory on the one
table its function writes.

**`frame_schritte_beschraenkt` and `kosten_passt_deklaration`** (`KostenG.lean`).
On any run, a frame's own steps between its entry and its return are bounded by
a syntax-directed cost of its body — each call counting the callee's cost one
depth down (`rufTief`) or the callee's declared cost under the decidable check
`kostenPasst` over a closed function list. The Lean bound meets the checker's
number from above (`frame_schritte_pruefer`, per form, with the findings of the
file's §11). Counted are the frame's own thread steps; other threads' steps and
waiting time are not — see the scheduler assumption in §16.2.

**The single-body legs underneath.** `zwei_fehler` (`Satz.lean`): every outcome
of a body is control flow or `logik` or `hardware`, and the type has no further
constructor. `exec_rahmen`: a body under contract writes only what its contract
names, gives every lock back, and every access carries its guards in rank order.
`AllgemeinStabil` (`InterferenzAllgemein.lean`) proves what the joint model
consumes — context, coverage, per-thread frame dependence and chain-head entry
validity, every assertion at the last world. Frame-bound reader assertions
survive disjoint steps (`requiresStabil_kette`, `ensuresStabil_kette`,
`invarianteStabil_kette` in `LesenStabil.lean`): ordered writes stay writes,
preserved reads stay reads. The inversion theorems (`slot_hat_waechter`,
`zeiger_hat_waechter`, `bytes_in_tabelle`, `zuweisung_hat_recht`, `sdivision_ohne_null`,
`register_schreibbar`, `transition_hat_spiegel`, `uebergang_erklaert`, `publish_paart`,
`stufe_steigt`, …) say for each site what its derivation had to carry. `Zucker.lean` defines
every sugar as a term of the core, so it has no meaning of its own to get wrong.

| where the outcome comes from | outcome | class |
|---|---|---|
| `requires` of the callee false at the call | `logik (vorbedingung f)` | logic |
| `ensures` false at `return` | `logik (nachbedingung f)` | logic |
| an owed `invariant` false at `return` | `logik (invariante i)` | logic |
| a loop `invariant` false at a pass boundary | `logik schleife` | logic |
| the recursion does not bottom out (`decreases`) | `logik (abstieg f)` | logic |
| a `state` field is not on the pre-state of its transition | `logik vorzustand` | logic |
| an `axiom` or foreign body answers outside its declared type | `hardware (annahme a)` | hardware |
| a `forever … progress a` is not ended by the environment | `hardware (fortschritt a)` | hardware |
| a float result leaves its declared range or is not finite (the kernel IEEE model decides it; `hardware ieee` until 2026-09-15) | `logik bereich` | logic |
| a register answers outside its declared type | `hardware (register r)` | hardware |
| a register answers against its declared promise (`requires` at the `reg`) | `hardware (geraet r)` | hardware |
| an `awaits` does not see the publication it pairs with (the memory model) | `hardware (sichtbarkeit A10)` | hardware |

**And there is no thirteenth row.** Index out of range, overflow, division by zero (signed or
not), an unguarded access (direct, through a pointer, through a byte view, in a quantifier, in
`old(…)`), a missing write right, a dropped or duplicated mark, a lock taken out of rank or
twice, a callee that does not declare the held set, a non-exhaustive match, a fall-off
`else`, a call with the wrong signature, a write through a read-only pointer, a byte run past
its carrier, a register written against its class, a `transition` without its mirror, a
publication with the wrong payload, a phase step out of order, a shared carrier without a
guard, a data race on a guarded carrier, a crossing of the lock order — **none of these has
an outcome, because none of these has a term or a run.**

### 16.2 The premise classes — and what establishes each decidable premise

Classes: USER (the user's own logic), HARDWARE (a named assumption), DECIDABLE (a
Bool the checker computes, with its soundness theorem), START (a fact about the start
configuration), DATA (an object, not an obligation). Full map: `dokumente/SATZKARTE.md`
§11.2.

| premise | class | established by |
|---|---|---|
| `KoerperGutG` — one triple per function plus caller duty | USER | the `requires` / `ensures` / `invariant` / `decreases` clauses and the `state` pre-state (§§5–8); Lean legs `hoare_call` (`HoareRuf.lean`) and `rufG_treu` (`RufMaschineG.lean`). It quantifies over ALL frame-respecting register-local oracles, so the sequential proof must survive register answers that change between reads — locality may be assumed, stability may not. |
| `StartGut` — every start function's `requires` at the start world | USER (boot) | the boot assignment `init` against the entry contracts (`ZielOrt.lean`). |
| `GutO` — axiom answers inside declared frames, held locks and trace untouched | HARDWARE | the `effects` of every `axiom` / `raw` / `prim` / `extern` / `asm` body (§§1, 6, 14); the per-syscall instance from the kernel contract (`syscall_paarung`, `SyscallPaarung.lean`); the fixture instance `refO_gut` (`ReferenzB.lean`). |
| `RegLokal` — register answers from the register's device carriers, `awaits` visibility from the awaited global only | HARDWARE, named | the `device` / `reg` declarations with `mirrors`, class, and `requires` promises (§10); transfer `regLies_gleich` / `sichtbar_gleich` (`ZielOrtGeraetSem.lean`). |
| waiting — fair scheduling and a bounded hold time of every lock | HARDWARE assumption, named here and proved nowhere | the surface carries the hold bound (`lock L … held <= N ops`, §11; checker `K002`, `K004` for the shared form), but `Deklaration` has no hold field, so no waiting bound under fairness is stated (TARGET 4 open, `KostenG.lean` CUTS). |
| `programmImFragmentG = true` — every body in the widened `gOk` fragment | DECIDABLE | all forms including loops, exits, reasons, axioms; indirect calls only where `KandOk` holds (every function of the pointer's signature keeps its contract carriers in the caller's footprint); register reads only with their device carriers in the footprint. Soundness: `programmImFragmentG_ok`. Lean-decidable, not yet a checker rule — wiring it per program is emitter work. |
| `fussOrtGB = true` — every widened-footprint carrier guarded by a signature lock or written by none | DECIDABLE | the footprint covers direct callees' contract carriers and read registers' device carriers; surface: `effects { writes T }`, the `requires Held(L)` signature lock sets, `H007` guard-per-access, `W001` / `W002` concurrent-write refusal. Soundness: `fussOrtGB_ok`. The Bool itself is Lean-side. |
| `StartExklusiv` — no two start threads share a signature lock | START | the `concurrent` member list against the entry functions' held sets (§11); decidable for constant assignments (`audit_startExklusiv_const`, `AuditZiel.lean`); no checker rule yet. |
| `kostenPasst = true` — every body cost fits its `costs` declaration over a closed list | DECIDABLE | the `costs <= n ops`, `bounded`, `per_pass bounded` clauses (§§6, 8); checker `K001` (declared costs hold), `K006` / `K007` (loop bounds), `K008` / `K009` (recursion measure), `K005`; Lean `kosten_passt_deklaration` with correspondence `frame_schritte_pruefer`. |
| `hvoll`, `e0` — the member list is complete; the declaration has a carrier | DATA | a finite enumeration check; a declaration-shape datum (carrier-less programs are out — §16.3). |

### 16.3 What the three theorems do NOT cover

Every item is a CUTS of the cited file; the map is `dokumente/SATZKARTE.md` §11.3.

- **Fragment edge.** `ziel_ort` covers `kOk` bodies only; `ziel_ort_voll` adds loops, exits, reasons, axioms and indirect calls but no `regLies`, `regLiesElse` or `awaits`. The flagship admits those under `RegLokal` and `fussOrtGB`. Indirect calls stay restricted to `KandOk`. The unrepaired widening is provably false (`ziel_ort_register_falsch`); no analogous refutation is built for `awaits`.
- **Carrier-less declarations.** With no table, global or lock every world has the empty trace and the replay would need an unproved determinism lemma — out of all three (`e0`).
- **Locks-block-only readers.** Footprint carriers and device carriers need a guard held BY SIGNATURE, or no writer at all. A reader that takes the lock only in a `locks` block is not covered.
- **Non-local oracles.** Without `RegLokal` the flagship does not apply (`ziel_ort_voll` stays as proved and covers no registers or awaits). `RegLokal`'s visibility half is minimal — the awaited global only; answers depending on `publishes` payload globals are outside it. G has no asynchronous device step (`GeraetSchreibt` is a shape beside the run): a register whose answer changes between reads with no write to its carriers violates `RegLokal`.
- **Waiting, termination, time.** G steps are not checker ops and not cycles. TARGET 4 (a waiting bound under fairness from the `held` declarations) is not stated. Termination is not proved: a frame may stop stepping for good (an unfreed lock, an invisible payload, a spent `passes` budget, a failed leaf, `leave` / `next` in an `else` block) — then it takes fewer steps, never more. Stuck states are not violations: G does not step, and `VertragAmOrtG` covers only logged steps.
- **Converse adequacy.** Forward adequacy is existential, against the contract-ignoring handler `rufRumpf` — never the checking `rufAt`. Calls need `Tief` depth admission; indirect calls are not done; axioms and `bindAxiom` are not simulated; `ret` under `locks` is excluded. The converse covers the loop-free, error-channel-free, axiom-free, oracle-free fragment only.
- **Lock-free sharing.** Atomic globals (`AtomarAusgenommen`) and published payloads (`PaarungAusgenommen`) are allowed races by design and excluded from `SchreibRasse`. Unshared carriers are checker duty (`PCUnsharedSep`). No non-adjacent race with explicit release.
- **Witness shape.** The `voll` witness moves one thread under `true` contracts; the `geraet` witness has no device-driven change and no `awaits`; no witness interleaves inside a critical section (the lock forbids it).
- **User-copy hazard (§3).** The region check stands beside the run and the world has no user partition — check-then-copy across the user/kernel boundary has shapes but no discharge; the validated copy is proved under the named snapshot premise only.
- **The parser.** `Syntax.lean` is a tree and this file a token grammar; the map between them is translation validation T3 — an open item below.
- **Handler scheduling (§1).** When a handler runs stays a scheduling fact (a handler is a thread in the run model); `masks irqs` is a declaration the run's well-formedness may use.

### 16.4 Where the twelve items of the 2026-09-09 list stand now

| item | then | now |
|---|---|---|
| 1. interleavings | covered over traces | covered over G (`rennfrei_g`, §16.1); lock-free sharing explicitly out (§16.3) |
| 2. memory model | hardware outcome at `awaits` | unchanged, plus the visibility half of `RegLokal` (§16.2) |
| 3. devices | order proved, content assumed | unchanged; async device step out (§16.3) |
| 4. bytes | covered | unchanged (§§3, 9) |
| 5. signed arithmetic, float | covered, float range as hardware assumption | unchanged (§4) |
| 6. sugar | covered | unchanged |
| 7. contexts, cost, emitter, C | split: scheduling fact, logic budgets, hardware deadline, lowering contract | budgets now proved to bound frames (§16.1); waiting bound open (TARGET 4, §16.2); C side in §21 |
| 8. the parser | outside, mapped | open — translation validation T3, open item below |
| 9. the three parameters | `O`, `passes`, `fuel` — the hardware and the logic | `passes` is now the `forever` budget of G; `fuel` is `Tief` depth admission (§16.3) |
| 10. check-then-use | checker discipline plus named gaps | unchanged: narrow-then-use carried (`M147`), driver handoff carried (`H018`), payload order carried (`V006` / `V007`), boundary rows carried (`K005`, `K011` / `K012`, `N056`); awaits-then-act has no revalidation rule; concurrent siblings open |
| 11. preemption timing | excluded by decision | unchanged |
| 12. user-copy hazard | future work | unchanged (§16.3) |

---

## 17. What moves in the corpus when the third version replaces the second

Measured against the 70 clean examples by reading, not by running (item 8 above);
the fourth version adds `beispiele/71` (measured by running: checks clean,
lowers, `cc` accepts at `-O0`/`-O2`):

* `u32` without `in`, `f64` without `in` — everywhere — **SUGAR, nothing moves**;
* signed `/` or `%`, or a `/` with a signed numerator — **refused**; to be measured (W10);
* `forever` without `progress` — **one site**, `66-transport-rueckgabe.gab`:66;
* `let … else` / `narrow … else` whose block falls off — **refused**; the checker refuses these
  today (`M1`), so the corpus has none;
* `maintains` — **SUGAR**; an invariant a function writes under and does not `maintains` is
  now owed anyway (this is the point);
* `on_exceeded ident` — **SUGAR**;
* a `state` field written with `=` and a plain value — **refused**; written as `transition … : A -> B;`
  («SG-19»); to be counted;
* `owner` — **no site**; parses, refused as `D026` (the word did not exist
  before «SG-9»);
* `shared` at a `table`/`static` — **every carrier `H013` finds reachable from two contexts
  must say it**; to be counted from `H013`'s own output;
* `requires Held(L)` that does not name the whole held set at a call — **refused** («SG-20»);
  today `H005`/`H006` accept a callee that names fewer; to be counted;
* a register read outside `let`, a register written whose class is `r`/`rc` — **refused**;
  `R005`/`R006` refuse these today, so the corpus has none;
* `publishes { … }` with a set other than the declared — **refused**; `V001`–`V004` refuse
  these today.
* `count k in slots of T : p` — **`beispiele/71`** (with a parameter capture,
  `schwelle`); poison `gift/693` (`D025`, count over `threads`).
* `deadline <= n ops arch X falsifier p` — **`beispiele/71`** (with `arch
  x86_64` on the function); poison `gift/695` (`K011`, symbolic number),
  `gift/696` (`K012`, undeclared machine), `gift/697` (`N056`, probe without a
  verdict).
* `table T owner m` — **no site**; parses, refused as `D026` (poison
  `gift/694`) until the producer stands.
* a first match, a non-index option, a runtime-length tail — **nothing moves**;
  all three were already writable («SG-25»–«SG-27» name the idiom, they add no
  production).

---

## 18. Fourth version — time, order, and the last expressiveness (2026-09-09)

**What the third version still left on the writer that is not logic and not a
hardware measure.** Four agents measured it on the same day from four sides
(plumbing gaps, Lean independence, races/time, expressiveness); each item below
names its «SG-n», its Lean carrier, and what the writer still owes by hand.

**The goal, repeated so the additions can be checked against it:** whoever
verifies a Gabbro program proves **only** their own logic (`requires`,
`ensures`, `invariant`, `decreases`, a `state` pre-state) and their hardware
measures (`assume`/`axiom` with `falsifier`, `progress`, a register promise, the
memory model A10) — **and nothing else**. Everything else is carried by Gabbro
and CompCert, assuming Gabbro is formally verified. The Lean body that states
this independently of the current `.rs` code is
`grammatik/Grammatik/Ziel.lean`: it imports only the grammar, defines the
lowering contract to a closed C subset explicitly, and its `#print axioms`
shows nothing but `propext`/`Classical.choice`/`Quot.sound`.

| | production | writer still proves by hand | carried by | Lean |
|---|---|---|---|---|
| **«SG-22» time split** | `deadline <= n ops arch X falsifier p` at `fn` (NEW, §6) | the `ops` number, honestly and tightly, like `costs`; the falsifier probe for the cycles on `X` | the budget (`costs`, `held <=`, `bounded`, `per_pass … ops`) is logic checked against the declaration; a missed deadline is **`hardware (fortschritt a)`** — the named environment assumption, not a silent reinterpretation of `ops`. Structural checks: the number reads (`K011`), the machine is declared (`K012`, R16); the probe's shape, when it resolves in-unit, is held by `N056` (same tail as `retires`), an unresolved probe is a program next to the tree; `unfalsifiable` stays legal and marked, and the manifest carries `frist_<fn>_eingehalten` with the class; measured by `sonden/sonde_tick.c` (sample, R15/W10 — the Lean side names the mapping `fristAlsAnnahme` and proves nothing about time; `Fristlauf.lean` `fristlauf_erschöpfend` mirrors that mapping by shape and proves exhaustiveness — every run is `ok` or expiry) | `Hardware.fortschritt`; `Ziel.lean` `fristAlsAnnahme`; `Fristlauf.lean` `fristlauf_erschöpfend` |
| **«SG-23» payload order** | DOCUMENTED (already enforced): `A = e publishes {p,q};` after the writes of `{p,q}`, `let x = A awaits {p,q};` before their reads (same sets as «SG-13») | the logic of what is published | the **order** — enforced since 2026-08-19 by `V006`/`V007` in `paarung.rs` (write-after-publish, read-before-await, `if`-evasion closed 2026-08-20); this version names the rule in the grammar instead of leaving it checker-only | `Stmt.publish`, `Block.awaits` |
| **«SG-24» counting** | `count k in slots of T : p` as an expression (NEW, §4) | the predicate `p` | the traversal that counts it — SUGAR for a call to the table's **generated** count function, like `ops insert/remove` (§9): `Block.bindCall` with its `requires`; over **one** table only, a cross-table count is a `group` invariant, never a hand-maintained counter | `Block.bindCall` |
| **«SG-25» first match** | NO new syntax: bind the result into a variable before the loop, `leave` out, read it after | which match is first (the logic) | termination and the bound — still from the domain; `assignVar` plus `leave`, never a hand-threaded cursor or bitmap | `Stmt.assignVar`, `Stmt.leave` |
| **«SG-26» general option** | NO new syntax: over non-index `T` spell the two-case `tagged` sum; `match` over it is exhaustive by shape | the case split | the shape — over `index into T` it stays the carrier's index option (`Expr.some`/`none`); nothing is lost and no constructor is added for what a declaration already says | `Ty.sum`, `Arms` |
| **«SG-27» variable tails** | NO new syntax: `backed k` plus `narrow i to 0 ..< k` before the access (§9) | that the entry length check holds once | everything after: the bound as an attribute at every access (`leseBytes`/`schreibBytes` with the run's bound) — a runtime length the declaration does not know would be a hand-threaded check at every access, i.e. manual plumbing | `Expr.leseBytes`, `Block.narrow` |

**What deliberately stays a hardware assumption** (no new constructor, no new
proof duty): the lock primitive's exclusion (W3), the memory-model pairing A10
(`hardware (sichtbarkeit)`), the device bus order (`assume
dma_visibility_in_order` named at the `transition` site), IEEE rounding (`assume
ieee754_round_to_nearest_even`), RCU grace (`reclaims … after grace a` naming
its `assume`, same pattern as `retires … falsifier`), IRQ arrival (`progress`
plus probe), and the whole axiom layer. The C side is a **closed list of
forms** (`Ziel.lean` `CForm`: the 34 used-and-allowed forms, nothing else
without a ruling); the lowering ledger `Gabbro-op → C-statements` expands each
primitive boundedly, and quantitative CompCert preserves the `ops` count from C
to Asm. Wall-clock and cycles never enter the logic — they enter through
`deadline` and its falsifier.

**Maximal writability without leaking plumbing.** `count` (SUGAR over a generated
call), the first-match idiom, the `tagged`-spelled option, and `backed` +
`narrow` close the four cheapest expressiveness blockers (B1–B4 of the
expressiveness probe) — three of them were already writable and are now named
instead of inflated, one (`count`) gets its generated function like `ops`
before it. `deadline` and payload order close the two time/race remainders.
No new manual plumbing enters through any of them. What stays unwritable stays
unwritable on purpose: user-defined domains, recursion in `spec fn`,
hand-written lemmas, a TAL self-proof of the entry path, and the bus as seen
by the grammar (§15, §16.2).

### Expiry shapes — check at `t`, run at `t'`, expiry strictly between

A deadline names by when, in cycles on a named machine, with a probe that
can refute it. The Lean side gives that statement named shapes
(`Grammatik/Fristlauf.lean`): a check-use pair with carried order, a
deadline as named assumption plus probe, expiry as the strict betweenness
of check, moment and use, and an answer mapping expiry onto `Hardware.fortschritt`
(the `Ziel.lean` `fristAlsAnnahme` mapping, mirrored by shape). Time never
enters as wall-clock — a moment is a step index. Endpoint coincidence is
`ok`, not expiry; every run is `ok` or expiry, no third outcome. Each date
carries the fourfold linkage (clause, falsifier, manifest entry, register
row); sample `sonde_tick.c`, row 39 PROGRAM. Time stays a hardware outcome.

---

## Open items — as of 2026-09-13

- [x] **The guardians on this file** — measured: EBNF closure 176 defined rules, 0 open
      (`pruefe-syntax.sh` EBNF branch); vocabulary 239 terminals against 239 table words
      plus 4 Sonderformen, both readings (`pruefe-wortschatz.py`); guardian round in lane
      129 (E5), re-run in lane 142. The `cargo build --tests` tail of `pruefe-syntax.sh`
      and `pruefe-grammatiktafel.py` need a Rust toolchain and abort without one — a
      pre-existing environment limit, not a finding about the grammar.
- [ ] **The parser from this grammar into `Syntax.lean`** — open as translation validation
      T3 (`dokumente/PLAN-UEBERSETZUNGSVALIDIERUNG.md`): the token-to-tree map with a
      certificate, so Rust leaves the trusted base. Production-to-constructor table
      161 mapped-or-named in `messung/SYNTAX-PARSER-ENTWURF.md`. This is what turns 16.4
      (8) into a corpus measurement.
- [x] **A concurrent semantics** — `Wettlauf.lean`, evening of 2026-09-09; race freedom now
      proved over machine G as `rennfrei_g` (lane 130).
- [x] **A byte-addressed place** — `leseBytes`/`schreibBytes`, evening of 2026-09-09.
- [x] **The implementation in checker and emitter** — `PLAN-UMSETZUNG.md`
  (§1.4 rows `V006`/`V007`, `K`-`deadline`, `D`-`count`): `deadline` checks
  (`K011`/`K012`, `N056` for the probe, `frist_` manifest entry) and `count`
  checks (`D025`, result `0 ..= N`, costs, effects, locks, calls) plus the
  counter lowering in `emit.rs` — all green, `beispiele/71` lowers and `cc`
  accepts at `-O0`/`-O2`. `owner` parses and is refused as `D026`
  (poison `gift/694`); the producer story stands since lane 151 (`D265`-`D268`,
  producers `beispiele/114`/`115`, poisons `gift/932`-`935`), named at the
  clause and in §9.
- [x] **The `owner` producer** — the first mark is minted once, by a single
  foreign body returning the mark without taking it (a named assumption, like
  every foreign body); the single mint executes exactly once (one static site
  outside every loop, in a root nothing calls, started at most once --
  `D268`); it travels by linear handoff, and every access to the table, read
  or write, holds it (`D267`, reads through the `E010` walk). `D026` stays for
  the incomplete story (no minter, no mint execution, or a minter no guarded
  access exercises). What stays open: borrowing the mark back across a
  call (`consumes` plus `allocs` is refused: move-only this lane).
- [x] **`pruefe-syntax.sh` prose branch flagged `logik uebergang` (×3) — renamed.**
  The word was the Lean outcome constructor (`Logik.uebergang`), not the
  abolished keyword, but the guardian cannot see the difference and it is right
  not to try. The outcome is now `Logik.vorzustand` (the pre-state, PFLICHTEN.md
  «B26» — a word that was never a keyword): `Semantik.lean` ctor plus its two
  uses, three prose cells here. `Stmt.uebergang` and `uebergang_erklaert` stand
  — the guardian does not read dotted names, and the statement is not the
  outcome.
- [ ] The four marks of the second version stand: `narrow` count ≤ 24 sites; the 17 logic
      obligations against `by induction over`; cost truth per compiled module; the ten
      fragments on this syntax, guardians green.
- [ ] **The user-memory region check** — `grammatik/Grammatik/Adressraum.lean` proves the
      validated copy under the named snapshot premise, but the region check stands beside
      the run: no range check inside the run, no user partition in the world (§16.3). Until
      both stand, check-then-copy across the user/kernel boundary has shapes but no
      discharge.
- [ ] **The lock hold bound in the Lean model** — `held <= N ops` is surface (`lockdecl`,
      §11) and checker (`K002`, `K004`), but `Deklaration` carries no hold field, so no
      waiting bound under fairness is stated (`KostenG.lean` CUTS, TARGET 4 open). The
      scheduler assumption — fair scheduling and a bounded hold time of every lock — is
      named in §16.2 and proved nowhere.
- [ ] **What is not covered even after the definition — named, not forgotten:** the seam CPU ↔
      device has no mechanised model (16.4 (3)); the `iasm` entry path has no downstream prover
      (16.4 (7)); liveness and progress fall under no mechanism except the named assumption
      (`hardware (fortschritt a)`); the ghost-theory templates belong in Isabelle once.
      The full list is §16.3, with the premise map in `dokumente/SATZKARTE.md` §11.3.

---

## 19. Program composition — in what order the contracts stand

A program is a **body table**: one row per routine with its callees, its
optional `decreases` measure, and its loop identifiers — plus, per routine,
the environment entry that runs the body (`Runs`: where the body ends, the
environment answers with exactly that state and value). The claim is that
both environment premises of the safety theorem are theorems over this table:

| premise today | theorem after composition | induction |
|---|---|---|
| `UmgebungOK` (every declared callee keeps the world and answers per its signature) | `umgebung_ok_of_runs` | topological order where acyclic, measure where cyclic |
| `SchleifenOK` (every registered loop keeps the world and its scope) | `schleifen_ok_of_runsloop` | index list of the loop (`iterate`) |

**Acyclic part — no measure needed.** Where the call graph below a routine is
acyclic, callees precede their callers in a topological order and contracts
are proved innermost first: a leaf meets its duty directly, a caller closes
each call site with the already proved callee contract. The induction is over
the graph order, which is well founded because the fragment is finite and
acyclic.

**Cycles — `decreases` or refusal.** A cycle cannot use the order above: no
member precedes the others. Every member of a cycle must therefore carry a
`decreases` expression, and the induction is over the measure, not the graph —
the `RecursionCycleCarried` shape (`Coverage.lean`): where the environment
runs every body and every duty holds under the bounded contracts of all cycle
members, every member holds its contract. A cycle with a member edge that
carries no `decreases` is not composed; it is refused (`K008`/`K009` on the
checker side, an undischarged bounded duty on the model side).

**Loops — one pass per index.** A loop runs as a sequence of passes over an
index list (`iterate`); each pass preserves the world and the scope under the
invariant, `leave` ends the visitation early. Recursion through a loop body
nests the inductions in a fixed order: the measure induction outside, the
loop rule inside.

**Foreign bodies stay hypotheses.** `extern`, `asm`, and entrusted routines
have no row and hence no duty; their contracts remain hypotheses about the
environment, threaded through rather than closed.

Lean: `Grammatik/Komposition.lean` (shapes as `def`s, proofs later).

## 20. Fault outcomes — named, beside the semantics, not in it

Four faults have names: `index` (index out of range), `ueberlauf` (store
outside its declared width), `nenner` (zero denominator), `gestalt` (shape
mismatch). They live in a PARALLEL outcome (`ErgebnisF`: `wert` or `fehler`)
next to `Semantik.lean`, never inside it: `eval` stays total, `exec` keeps
its two error exits (`logik`, `hardware`), and no third exit is added to
`Ausgang`.

Why the parallel outcome never faults today — and that is the statement,
not a gap: a `slot` index has type `.index (count t)` and carries its range
proof with it; out-of-range is not writable. The fault arm is reachable
only through RAW data (`IndexFalle`: a table plus a bare `Int` with no
range proof) — exactly the place where the checker holds the range today.

Agreement shape: no fault implies `eval` agrees (`evalF_ok`, `evalF_stimmt`
as `Prop` definitions). Falsifier shapes are DATA, not proofs: an
out-of-range index reaches `fehler .index` by definition
(`indexFalleErgebnis`), every named case its own fault (`fehlerFallErgebnis`).

Cuts: no threading through `execStmt`/`execBlock` (propagation lemmas for
`evalAll`, step sequence, loop iteration are named, not built); `evalF`
delegates every call to `eval`; not wired into `Grammatik.lean`.
Lean: `Grammatik/Fehler.lean` (`Fehlerklasse`, `ErgebnisF`, `evalF`,
`evalF_ok`, `evalF_stimmt`, `IndexFalle`, `FehlerFall`).

## 21. The producer contract — what the emitter must uphold

§18 closed the C side as a list (`Ziel.lean` `CForm`: 19 named shapes).
A closed list is not a contract until somebody says what upholding it
takes, per run, in checkable form. That is this section. It claims no
verified emitter: every sentence below is specified in
`Grammatik/Erhaltung.lean` as a `Prop`-valued `def` — the SHAPE of a
later proof, not the proof. The five later sentences are named
`satz_korrespondenz`, `satz_alias`, `satz_kosten`, `satz_tafel`, and
their conjunction `satz_erzeugervertrag`.

### 21.1 Correspondence — one certificate per run (`BEWEIS.md` §4)

Each compilation run produces a coverage certificate: one row per
evaluation site, `CorrSite = gabbroSite × cSite × form`, collected in
`CorrCert`. The emitter earns trust when four shapes hold
(`satz_korrespondenz`):

1. **Completeness** (`corrComplete`) — every Gabbro evaluation site
   appears at least once.
2. **Order** (`corrOrdered`) — the C sites stand in the same order.
3. **Closure** (`corrClosed`) — every C form in the image is a decided
   row of the table in §21.4.
4. **No additional effect** (`corrNoExtra`) — no C site without a
   Gabbro preimage.

The recomputer is a second program with its own pattern, not the same
code called twice (`checkfat.py` lesson); what is accepted is the
mutation list, not the existence of the checker. A deliberately
displaced evaluation site must be noticed. The common-mode failure
(both tables from one text) is named, not closed; the witness pairs of
§21.5 are the only instrument against it.

### 21.2 Alias — no address arithmetic in the image

§2 row 2 promised the emission generates no pointer arithmetic, and the
census measured 491 sites of it (`d->basis + 8`, `v->bytes + 4`).
The row is rewritten by this section: the obligation is
`AliasObligation`, the list of address-arithmetic site ids in the
image, fulfilled (`aliasKept`, `satz_alias`) exactly when the list is
empty. Until then every entry is a named site, and the census number
stands as data (`ptrArithCensus = 491`), not as residual risk "none".
The two declaration shapes behind the count are named in the spec
(`ArithSource`: `basisPlus` over `volatile uint8_t *`, `bytesPlus`
over `uint8_t *`). The sibling slot `zeigerIndex` (156 sites) is NOT
covered by ruling `index` as named: `p[i]` IS `*(p+i)` by C's own
definition, and the table must say whether it means that too.

### 21.3 Cost — CerCo preserves, production is measured

The budget counts Gabbro-side steps (`costs`, `per_pass … ops`); what
happens to the number across lowering is a claim with a named carrier
(`CostCarrier`), and the carrier is data, not prose:

- `cerCo` — quantitative CompCert: the C count IS the Gabbro count
  (`costKept`). Preservation may be CLAIMED here, once the carrier stands.
- `produktion` — the production compiler: the count is MEASURED by
  witness pairs (`costMeasured`: `paare` pairs ran green; zero pairs is
  not a measurement), never proved.

The Gabbro-side leg is the bounded lowering (`senkungBegrenzt` over
`Absenkung`: one primitive becomes at most `proPrimitiv` C statements).
`satz_kosten` conjoins all three legs. Wall-clock and cycles never enter:
same boundary as `Ziel.lean` (§18 «SG-22») — a deadline is
`hardware (fortschritt a)` with its probe, not a second budget.

### 21.4 The ruling table — 19 named, 30 slots, one status field

Every row is an `EntscheidZiel`: either a named shape or a census slot,
each WITH a `RulingStatus` (`offen` | `aufListe preis` |
`ausErzeuger ersatz`). The status field is what makes 30 holes countable
instead of invisible; `entschieden` says when a row stopped being debt.

- The **19 named shapes** (`CForm`) stand admitted with the price of
  their semantics named. Two prices carry real trust and say so:
  `beschraenkt` exports the effects-promise into C's UB rules (priced
  option, never default), `fluechtig` is an axiom by name. These 19
  admissions are the TEMPLATE ruling, not 19 rulings.
- The **30 census slots** (`OffeneForm`: 7 used-and-forbidden, 19
  unnamed-and-uncovered, 4 generously covered) stand `offen`, with two
  exceptions that show the two ways out: `bedingt` carries the filled
  template (`bedingtEntscheid`: the generator writes
  `if (v > z) { z = v; }` — costs nothing at `-O0`/`-O2`/`-Os`,
  byte-identical at the top two), and the four generous readings plus
  the kept `unerreichbarBuiltin` site carry their admission price.
- `satz_tafel` (every row decided) is FALSE today — 29 slots still
  `offen` — and that is the point: the shape counts the debt. Ruling
  by taste is what produced a list with 30 holes; each of the 19
  unnamed forms is ruled one by one the way `?:` was, onto the list
  with the price of its semantics or out of the generator with the
  price of the change. Deciding `?:` alone does not close the class:
  `logUndOder` (23 sites) is the same conditional door, undecided,
  and the float row (`floatTyp`/`doubleTyp`, 26 sites) is a missing
  row, not a missing word.

### 21.5 Witness pairs — the instrument the table was missing

Every table entry gets an executable witness pair: a Gabbro fragment,
the expected C, the expected behaviour — run through the REAL C
compiler and compared. With that the entry's meaning is checkable
instead of hand-trusted, and an entry without a witness pair is
incomplete. `costMeasured` counts these pairs on the production leg.

### 21.6 The derivation certificate — validity as one equation

A certificate is a derivation term as plain data (`CertExpr` mirrors the
`Expr` constructors minus hypotheses; claimed ranges travel beside the
term). Validity is one equation: the printed claim pair equals exactly
what the table recomputes — decidable wherever the world is concrete, so
acceptance and rejection both close by decide. Soundness is the owned
direction: a valid certificate implies the judgment (`zeugnis_sound`,
`block_sound`). Forgery fails by construction: a mismatched print is
provably invalid, never merely refused. Covered: arithmetic with side
conditions (M102, SG-3, M137, width), reads (variables, globals, slots
with exact index types and recomputed guards), straight-line int blocks
with linear balance; CUT shapes for floats, options, sums, grounds,
quantifiers, `reaches`, pointer reads and `RufPasst`-carrying calls.
Lean: `Grammatik/Zeugnis.lean`. The printer stays trust base.

### 21.7 What this section does NOT move

- No verified emitter: the certificate is specified, the recomputer is
  a later program.
- No formal C semantics: meaning lives in the table entry plus its
  witness pair.
- `restrict` and `volatile` stay trust, priced and named.
- The 19 admissions are template, each still owes its `?:`-style
  ruling.

### 21.8 Ledger pointer

The per-cut status of this chapter (proved, shape, open across cuts C1, C2, C3, C6,
with deciding witness and recompute command) is booked in `messung/SYNTAX-EMITTER-ANHANG.md`.

### 21.9 Shared carriers carry assertions in invariant form only

Assertions over lock-shared carriers are admitted only in invariant
(resource-invariant) form: a contract clause that reads a shared carrier
must coincide with that carrier's declared invariant, and every other
shape over the same carrier stays unwritable. The reason is the
interference check it would otherwise owe per run: frame-locality is not
preservation, so only the invariant itself survives every foreign step by
construction (Lean: `InvariantForm` with `interferenceFree_of_invariantForm`
in `InterferenzAllgemein.lean` §20, bound at Ziel level by
`ziel_seqLogic_aus_spec_invariantForm`). Checker side the form check is
`D027` in `domaene.rs::aus_pred`, decided against the declared table
invariants and the declared `spec fn` names: a `requires`/`ensures` clause
of a shared-side function (a `locks shared` effect or a `Held(L, shared)`
witness in its contract) that reads a table carrier must call a declared
invariant -- or a `spec fn` stating one -- by name, and a restated predicate
is refused. Outside contract position -- loop invariants, `spec fn` bodies,
functions without a shared side -- non-invariant shapes stay own-logic debt
(remainder in `BEWEIS.md`).
