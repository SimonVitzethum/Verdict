# Gabbro in one sitting

**This is not a language reference.** [`dokumente/SPRACHE.md`](dokumente/SPRACHE.md) is the
language and [`dokumente/SYNTAX.md`](dokumente/SYNTAX.md) is the grammar; both are complete
and neither will teach you what to type first.

This file answers one question:

> **What does a Gabbro function look like, and why does each clause stand there?**

It exists because that question was measured. Someone with the whole grammar and 63 examples
open needed **eight attempts to write „add two numbers"**. Seven refusals, every one of them
correct and clearly worded, and *not one of them taught the shape.* Five of those seven now
have a line under them that ends the attempt — and this file is the sixth answer.

---

## 1 — Five minutes

```
$ gabbro new hello
written  hello.gab
written  hello.bau

$ gabbro build hello.bau
built    hello
built 1 unit(s), 0 up to date, 0 refused -- 1 file(s) named by this manifest
NOT looked at: 0 `.gab` file(s) in this tree stand in no unit of this manifest (1 in the tree)
  the manifest is the reach -- a file no `unit` line names is not a file this build passed

$ ./target/hello/hello
Hi
```

`gabbro new` writes a source and a manifest that **check, build and run as they stand.** Every
clause in what it writes carries a comment saying why it is there, and the four that are
irreducible are marked. *Open that file beside this one.*

---

## 2 — The line at the bottom of every run

Run the checker and read the last four lines first:

```
$ gabbro check hello.gab
hello.gab: 2 items, 0 errors, 0 hints
  M1 saw 7 expressions, 0 of them without a type (100 % coverage)

Not checked in this run: 9 passes -- 0 open, 9 CARRIED (the rest is NAMED), 0 only partial
  2 D1/D2, 4 M3, 5 M2, 12 Sperren, 11 Phasen, 7 Paarung, 8 effects, 10 Gruppe, 9 costs
  register 4dd17209 -- the FULL text with `gabbro pruefe --paesse` or `gabbro paesse`
  it is a property of this BINARY, not of the file just checked -- and it did not shrink, it moved
```

**No other compiler tells you what it did not look at.** `0 errors` from a tool that only
reports what it found is a statement about the tool's attention, not about your program; this
one prints its blind spots beside its findings, every run, and `gabbro passes` prints the
register in full — the sentence each pass owes and whether it is built, partial, carried or
open.

Meet it here rather than discovering it later: **a green Gabbro run is a green run of the
passes that ran.**

### `0 errors, 0 hints` — and the second number is not the first

An **error** refuses the program: nothing is emitted, the exit code is `1`. A **hint** is a
finding that does not refuse — the checker has something to say and cannot call it wrong. The
one you will meet first is `E009`:

```
hint: [E009] the call effects of `main` are undecidable: `m::putchar` declares no `effects`
```

*That is not a stylistic remark.* It says a pass could not decide something about your
program, and the cure is always to give the checker what it was missing — here, an `effects`
clause on the `extern fn`. **Treat a hint as an error whose cause is on your side of the
line**, and the count will stay at zero on its own.

### And the two file kinds

A `.gab` file is source. A `.bau` file is a **manifest** — which sources form a unit, whether
that unit is a `program` or an `object`, which C compiler builds it, where the artefacts go.
`gabbro check` takes `.gab` paths; `gabbro build` takes the `.bau`.

---

## 3 — The shape

Every function is the same six parts, in this order:

```
      pub  fn  clamp(x : u32 in 0 .. 100) -> u32 in 0 .. 100
                 |     |                       |
      export   name  parameters, WITH RANGES   return type, with its range
          effects { pure }        <- what it touches.  OBLIGATORY
          costs   <= 4 ops        <- what it costs.    optional, and never guessed
      {
          ...                     <- the body
      }
```

**The ranges on the parameters are not decoration either** — section 6 is about what happens
when you leave them off, and leaving them off is the single most expensive habit a newcomer
can bring from C. *A first version of this diagram wrote `x : u32` and put the range only on
the return type; that is exactly the shape section 6 refuses, and a reader with nothing but
this file burned an attempt on it.*

Written out, and this checks:

```gabbro
module tutorial::shape {

pub fn clamp(x : u32 in 0 .. 100) -> u32 in 0 .. 100
    effects { pure }
    costs   <= 4 ops
{
    return x;
}

}
```

Four things about that block are worth more than the rest of this section:

* **`module` is optional.** It was measured: the same file without it checks, builds and
  runs. It is here because a unit graph is read out of `module` and `use` in the sources, and
  the day you have two files you will want it.
* **`pub` is not decoration.** An entry without it lowers to a `static` function and the
  linker never sees it. The build refuses by name; the checker does not, because it is a
  build rule and not a language rule.
* **`effects` is obligatory.** Section 4.
* **`costs` is optional — and you never write that number out of your head.** `gabbro costs
  <file.gab>` computes what the body costs and prints it beside what the line promises.
  Section 5, and it is the one to read even if you skip the rest.

---

## 4 — `effects`, and it is not fail-open

```gabbro
module tutorial::effects {

-- `pure` means: reads nothing outside its parameters, writes nothing, takes no lock.
-- (It is called `twice` and not `double`, and section 9 says why.)
pub fn twice(x : u32 in 0 .. 100) -> u32 in 0 .. 200
    effects { pure }
    costs   <= 4 ops
{
    return x + x;
}

}
```

A function with no `effects` clause is **not** a function that does nothing. It is a refusal:

```
error: [E001] `twice` has no `effects` clause
  = SPRACHE.md §7: `effects` is obligatory and not fail-open
  = the omission was at once the strongest promise and the cheapest one to write
```

*That is the whole design in one line.* A clause that could be left out would mean the
strongest possible promise — **I touch nothing** — is also the cheapest thing to write, and a
promise nobody paid for is a promise nobody keeps.

### The two shapes that cost an attempt each

The measured session, having read `E001`, wrote these two before it wrote the third:

| typed | refused with | why |
|---|---|---|
| `effects {}` | `P014` *effect expected, `}` found* | **an empty list is not „no effects"**; the word for that is `pure` |
| `effects pure` | `P001` *`{` expected, `pure` found* | **`effects` takes a brace LIST**, even for one word |
| `effects { pure }` | — | this one |

Both refusals now carry the counter-proposal. **The list is one of nine words:**

```
reads   writes   locks   masks   allocs   consumes   publishes   diverges   pure
```

`reads` and `writes` name a *place* — a static, an atomic, a device register, a pointer
parameter, or a plain name for a sink that is not memory of this unit at all:

```gabbro
module tutorial::sink {

-- `output` is not declared anywhere. It names what lies behind the C function -- the effect
-- system is about WHAT IS TOUCHED, and the terminal is touched.
extern fn putchar(c : i32) -> i32 effects { writes output } costs <= 8 ops;

pub fn shout() -> i32 in 0 .. 1
    effects { writes output }
    costs   <= 40 ops
{
    putchar(33);
    return 0;
}

}
```

Two rules that will find you within the hour:

* **`extern fn` needs the clause too.** It is the declaration of something Gabbro cannot see;
  without a clause, every caller's effects become undecidable, and `E009` says so.
* **The caller's clause must cover the callee's.** The hull is computed out of the call
  graph, and you can read it: `gabbro effects <file.gab>` prints the effects it derived per
  function, and `gabbro abi --vergleich <file.gab>` puts the COMPUTED hull beside the WRITTEN
  clause and counts where the two differ.

---

## 5 — `costs`, and **the tool prints the number**

This is the sharpest thing in the tree, and nothing points at it:

```
$ gabbro costs hello.gab
== hello.gab ==
-- What the body COSTS, beside what the line PROMISES. Whoever writes a
-- promise copies down what stands here -- a `costs` line is a measurement,
-- not an estimate.
-- site	computed	promised	slack
main	24	40	16
-- 1 bodies computed, 0 open.
```

**`computed 24 · promised 40 · slack 16`.** The left column is what your body actually costs,
computed statically; the middle one is what you wrote. *Whoever wrote this tutorial guessed a
cost bound five times in one session while that command sat in the same binary.*

Write the function without a `costs` line, run `gabbro costs`, and copy the number down:

```
$ gabbro costs draft.gab
-- site	computed	promised	slack
sum	3	--	--
```

A promise that is too small is `K001`, and it is arithmetic and not opinion:

```
error: [K001] `sum` promises <= 4 ops, the body costs 6
  = 1 op = one Gabbro primitive; a call counts the declared costs of the callee
  = the number is computed statically -- lowering it means writing fewer operations,
    not promising more
```

Two consequences of *„a call counts the declared costs of the callee"*:

* A callee **without** a `costs` line makes the caller's promise uncheckable, and `K003`
  refuses it. If you promise, everything you call must promise.
* `costs` is a **bound**, not a budget. `slack 16` is fine, and a bound above the computed
  number is often the right call — it is headroom you chose. **What is never fine is a number
  nobody computed.** Run the tool, then decide the bound; the promise exists so that a body
  which grows past it says so at compile time instead of at three in the morning.

---

## 6 — Ranges, and why `u32 + u32` does not fit in a `u32`

An integer in Gabbro carries its **range**, and every operation must stay inside the range of
its result type. That is Ada's trick, and it is why this is a compile error:

```
pub fn sum(a : u32, b : u32) -> u64 { return a + b; }

error: [M104] `u32 + u32` leaves the width of the result type
  = SYNTAX.md §4: if the result range does not fit, it is a compile error and not a wrap-around
```

**Read the second line twice.** In C this silently wraps. Here it does not compile.

And read the first line carefully, because the measured session did not: **the width that is
left is the width of the OPERANDS.** `a` and `b` are full-range `u32`, so their sum runs to
`8589934590`, which no `u32` holds. *Widening the return type changes nothing* — that attempt
was made, and it got the identical refusal back.

### The types, and their limits

You will need these numbers to write a range, and nothing else in the file states them:

| | signed | unsigned |
|---|---|---|
| 8 bits | `i8` −128 … 127 | `u8` 0 … 255 |
| 16 bits | `i16` −32 768 … 32 767 | `u16` 0 … 65 535 |
| 32 bits | `i32` −2 147 483 648 … 2 147 483 647 | `u32` 0 … 4 294 967 295 |
| 64 bits | `i64` −9 223 372 036 854 775 808 … 9 223 372 036 854 775 807 | `u64` 0 … 18 446 744 073 709 551 615 |

You do not have to type them out: **`u32::max` and `i64::max` are expressions**, and a
`const` is the readable way to name a bound you use twice.

### Three ways out

They are **alternatives chosen by where the knowledge lives**, not a ranking. (a) if the
caller can promise it, (b) if the result genuinely needs the room, (c) if nobody knows until
run time.

**(a) Say what the operands are** — when you can. You rarely mean *any* `u32`:

```gabbro
module tutorial::ranged {

pub fn sum(a : u32 in 0 .. 1000, b : u32 in 0 .. 1000) -> u32 in 0 .. 2000
    effects { pure }
    costs   <= 4 ops
{
    return a + b;
}

}
```

**(b) Widen the operands, not the result:**

```gabbro
module tutorial::widened {

pub fn sum(a : u32, b : u32) -> u64
    effects { pure }
    costs   <= 8 ops
{
    let x : u64 = a;
    let y : u64 = b;
    return x + y;
}

}
```

**(c) `narrow`, when the range is not known until run time** — because the values come from
outside and the parameters must stay unrestricted. Section 7 is that case, and **an
unrestricted parameter is not a mistake**; it is the honest signature for a value you did not
get to choose.

### One worked function, with the rest of the arithmetic

Nothing above needed a second operator or a parenthesis. Both exist, and they bind as they do
in C:

```gabbro
module tutorial::limits {

const HALF : u32 = 2147483647;

-- `lo` and `hi` are unrestricted -- they come from outside. `narrow` buys the range that
-- makes `lo + hi` fit, and `HALF + HALF` is 4 294 967 294, one under `u32::max`.
pub fn midpoint(lo : u32, hi : u32) -> u32
    effects { pure }
    costs   <= 8 ops
{
    narrow lo to 0 .. HALF else { return 0; }
    narrow hi to 0 .. HALF else { return 0; }
    return (lo + hi) / 2;
}

}
```

Two things in there that no earlier example shows: **a result whose range is NARROWER than
its declared type is fine** — `0 .. 2147483647` goes into a plain `u32` without a word, and
only *leaving* a range is an error — and `const` names a bound so that the two `narrow` lines
cannot drift apart.

### The range travels UP

A range on a parameter is a promise the **caller** has to keep, and the checker collects it:

```
error: [M101] argument `a` requires `u32 in 0 .. 1000`, the value has `u32`
  = what is missing is the proof that the value lies in 0 .. 1000; a check before it
    narrows the range (V1/V2), otherwise `narrow … to … else { … }`
```

So the obligation walks up the call chain until it reaches a place that *knows* — a literal, a
comparison already made, or a value that came in from outside. **At that place you write
`narrow`, and nowhere else.**

---

## 7 — `narrow`, the one runtime check that stays

Everything above is decided at compile time and costs nothing at run time. `narrow` is the
exception, and it is the only one:

```gabbro
module tutorial::narrowed {

pub fn clamp_sum(a : u32, b : u32) -> u32 in 0 .. 100
    effects { pure }
    costs   <= 8 ops
{
    narrow a to 0 .. 50 else { return 0; }
    narrow b to 0 .. 50 else { return 0; }
    return a + b;
}

}
```

Below the `narrow`, `a` has the range `0 .. 50` and the checker knows it. The `else` arm runs
when it does not, and it must leave — return, `next`, `leave`. That is the C:

```c
uint32_t clamp_sum(uint32_t a, uint32_t b) {
    if (!(a <= 50)) {
        return 0;
    }
    if (!(b <= 50)) {
        return 0;
    }
    return a + b;
}
```

**Two `if`s, and they are the only runtime cost of the whole range system.** The ranged
version from section 6(a) emits this instead:

```c
uint32_t sum(uint32_t a, uint32_t b) {
    return a + b;
}
```

*Nothing.* The range was discharged at the call site, at compile time, by the caller.

### The two semicolons

`narrow … else { … }` is a statement with a block, and blocks in Gabbro follow one rule that
cost the measured session two attempts:

| typed | refused with |
|---|---|
| `narrow a to 0 .. 50 else { return 0 }` | `P001` — **the last statement in a block ends with `;` too** |
| `narrow a to 0 .. 50 else { return 0; };` | `P033` — **a form with a block carries NO trailing `;`** |
| `narrow a to 0 .. 50 else { return 0; }` | — |

The rule is the same for `if`, `match`, `traverse`, `retry`, `forever`, `breaking`, `locks`
and `let … else`: **semicolon inside, none after.**

---

## 8 — Now write „add two numbers"

Everything you need is above. The shape:

```gabbro
module tutorial::add_two {

pub fn sum(a : u32 in 0 .. 1000, b : u32 in 0 .. 1000) -> u32 in 0 .. 2000
    effects { pure }
    costs   <= 3 ops
{
    return a + b;
}

}
```

* `pub fn sum` — **not `add`.** See section 9.
* the parameter ranges, so that `a + b` fits (6a)
* `effects { pure }` — brace list, never empty (4)
* `costs <= 3 ops` — **`gabbro costs` on this body prints `computed 3`, and this line is that
  number.** Not a guess, and not the `4` that would look tidier (5)

---

## 9 — Words you cannot use as names

Gabbro's vocabulary is a **closed table of 221 words**, and the first thing a newcomer types
is in it:

```
error: [P002] `add` is a word of the vocabulary, not an identifier
  = SYNTAX.md: the vocabulary is a closed table -- everything else is an identifier
```

`add` is the accumulator kind in `accumulates … add`. So are `min`, `max`, `or`, `and`,
`merge`, `index`, `into`, `node`, `leaf`, `entry`, `scale`, `chain`, `atomic`, `shared` and
`walk` — all of them ordinary-looking words that a program wants for a function or a field.

**There is no way to escape a keyword.** Pick another name; the table is in
[`dokumente/SYNTAX.md`](dokumente/SYNTAX.md), and the refusal names the word it read.

### And there is a second table, which is C's

Gabbro does not mangle: the name you write **is** the name in the generated C. So C's own
vocabulary is closed to you as well — at the boundary, and only there:

```
error: [N041] `double` is a name C has already taken
  = the lowering goes to C, and this declaration becomes `double` in the generated unit
  = `double` is a keyword of C11 §6.4.1
  = the name is fine everywhere except at the boundary -- rename the declaration, and
    nothing else has to move
```

*This paragraph was written because `double` was the first name this tutorial reached for in
section 4.* The measured table of 558 names — C keywords, the standard library, and what
`cc -std=c11 -Wall -Wextra -Werror` reserves — is in
[`messung/C-NAMEN.md`](messung/C-NAMEN.md).

---

## 10 — Where to go next

| you want | read |
|---|---|
| the language, clause by clause | [`dokumente/SPRACHE.md`](dokumente/SPRACHE.md) |
| the grammar, as a grammar | [`dokumente/SYNTAX.md`](dokumente/SYNTAX.md) |
| what the checker checks, and what it does not | `gabbro passes --je-satz` |
| what a build looked at and what it skipped | [`dokumente/BAUSYSTEM.md`](dokumente/BAUSYSTEM.md) |
| 63 worked programs | `beispiele/` — and `beispiele/gift/` is 368 programs that must FAIL |
| what a translation rests on | `gabbro certificate <file.gab>` |
| what a human still owes | `gabbro obligations <file.gab>` |

**And the last two rows are the point of the language.** Gabbro is a systems language whose
compiler is required to say what it does not know. If you read only one more thing, read the
output of `gabbro passes` — it is a list of promises with their state, and it is shorter than
this file.
