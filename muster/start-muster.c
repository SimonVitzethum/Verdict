/* laufzeit/start.c -- the hosted runtime driver for one concurrent unit.
 *
 * WHAT THIS IS. The emitter translates each `concurrent` member to a plain
 * `static void f(void)` and emits NO caller and NO `main` -- measured
 * 2026-09-15 on `beispiele/124-two-threads-private.gab` (`hauptA`, `hauptB`
 * exist, nobody calls them). This file is the missing half: it starts exactly
 * the declared roots, one thread each, and parks everything else in the idle
 * root. Together with the emitted unit it is a runnable program.
 *
 * WHY A .c FILE AND NOT EMITTED C. Thread creation is the runtime's, not the
 * program's: the goal theorem books it as assumption (d) `Laufzeit`
 * (`grammatik/Grammatik/Zielsatz/Spec.lean`), and `E.P.mitRuhe` is the model
 * of exactly this split -- the declared starts on their threads, the idle
 * root `none` on every other thread. A generator that printed `main` into the
 * unit would move a runtime fact into the program text.
 *
 * BUILD (from the tree root; the emitted file is a build artefact, not source):
 *
 *   target/debug/gabbro emit beispiele/124-two-threads-private.gab > .tmp/einheit124.c
 *   cc -std=c11 -O0 -Wall -Wextra -Werror -pthread -I .tmp \
 *      -DEINHEIT_INCLUDE='"einheit124.c"' -o .tmp/start124 laufzeit/start.c
 *   .tmp/start124            # exit 0, prints the observed values
 *
 * WHY `-DEINHEIT_INCLUDE`. The driver is one file for every unit; only the
 * included artefact and the ROOTS section below change per unit. A `#include`
 * (rather than a second translation unit) because the emitted roots are
 * `static`: a separate TU could not name them, and making them non-static
 * would widen the unit's interface for the driver's sake.
 */

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

/* -- The emitted unit -------------------------------------------------- */

#include EINHEIT_INCLUDE

/* -- Lock primitives: the emitter declares them, the runtime defines them.
 *
 * WHY HERE. The emitted C only ever says `void L_nimm(void);` -- a lock is a
 * runtime object (futex, ticket lock, interrupt mask), never program text.
 * On hosted POSIX that object is a mutex; on bare metal it would be the
 * ticket lock of NICHTINTERFERENZ.md section 10. The name on each side is the
 * contract between them, and it is checked by `cc`, not by care: a misspelt
 * name is an undefined reference, not a silent default.
 *
 * WHY A MUTEX AND NOT A SPINLOCK. The critical sections are whole Gabbro
 * bodies (`setze`), not single instructions; spinning under contention would
 * burn the core the lock holder needs. Blocking is the honest hosted shape.
 */
static pthread_mutex_t sperre_L = PTHREAD_MUTEX_INITIALIZER;

void L_nimm(void)
{
    int rc = pthread_mutex_lock(&sperre_L);
    if (rc != 0) {
        fprintf(stderr, "L_nimm: pthread_mutex_lock: %d\n", rc);
        abort();
    }
}

void L_gib(void)
{
    int rc = pthread_mutex_unlock(&sperre_L);
    if (rc != 0) {
        fprintf(stderr, "L_gib: pthread_mutex_unlock: %d\n", rc);
        abort();
    }
}

/* -- ROOTS: the declared starts of `beispiele/124-two-threads-private.gab`.
 *
 * Source line 84:  concurrent { hauptA, hauptB };
 *
 * WHY THIS SECTION EXISTS IN THIS FORM. The decisive property is measurable:
 * the driver starts EXACTLY the roots the unit declares -- not more, not
 * fewer, not in a different shape. The pin is mechanical and lives outside
 * this file: the probe extracts `concurrent { ... }` from the `.gab` source
 * and the `pthread_create` set from this file and compares the two lists
 * (see the report for the one-liner and its output). A new root in the source
 * without a new thread here -- or a thread here for a root the source dropped
 * -- fails that comparison. Reviewing this section means diffing two words.
 *
 * WHY ONE WRAPPER PER ROOT. `pthread_create` wants `void *(*)(void *)` and
 * the emitted roots are `void (*)(void)`; the wrapper is the adapter, and one
 * adapter per root keeps the root's NAME at the `pthread_create` call site,
 * which is what the probe reads.
 */
static void *faden_hauptA(void *u)
{
    (void)u; /* WHY: the thread gets no argument -- the declared starts of
              * this unit take none (`E.starts` carries each root's `Env`,
              * here empty). An argument slot that is always NULL would
              * suggest parameter passing that does not exist. */
    hauptA();
    return NULL;
}

static void *faden_hauptB(void *u)
{
    (void)u;
    hauptB();
    return NULL;
}

/* N_WURZELN is the count the probe checks against the source's list length:
 * adding a thread without bumping it breaks the join loop below loudly
 * (a thread never joined is a leak the next reader has to explain). */
#define N_WURZELN 2

/* -- The idle root: `none` of `E.P.mitRuhe`.
 *
 * WHY IT LOOPS FOREVER. The model's idle root body is `return` -- it writes
 * nothing -- but a HOSTED thread that returns from its start routine simply
 * ends, while a parked core must stay parked: on bare metal this loop is a
 * `wfi` wait, and a thread that fell out of it would run into whatever bytes
 * follow, which is exactly the "thread runs what nobody declared" shape (d)
 * forbids. Spinning here touches no Gabbro carrier (no table, no lock, no
 * global), so it is invisible to every leg of `Ziel`.
 *
 * WHY IT IS NEVER SPAWNED ON HOSTED. POSIX gives `main` no spare cores to
 * park: `main` spawns exactly the declared roots and joins them. The function
 * stands here so the shape exists in the artefact -- bare metal spawns one
 * per extra core -- and `__attribute__((unused))` says exactly that.
 */
static void *ruhe(void *u) __attribute__((unused));
static void *ruhe(void *u)
{
    (void)u;
    for (;;) {
        /* WHY `pause()` AND NOT AN EMPTY LOOP. An empty loop has no side
         * effect, so C11 lets the compiler assume it terminates -- and then
         * the function CAN return, which `-Werror=return-type` rightly
         * rejects. `pause()` blocks in the kernel until a signal that never
         * comes; it reads and writes no Gabbro carrier, so the promise
         * "does nothing and touches nothing" still holds. The bare-metal
         * spelling of this line is `wfi`. */
        pause();
    }
    /* Unreachable: the loop above never ends. It stands here because `cc`
     * cannot know that `pause()` never returns, and `-Werror=return-type`
     * is right to ask. */
    return NULL;
}

/* -- main: start exactly the roots, join them, report what the run did. ---- */

int main(void)
{
    /* WHY AN ARRAY AND NOT TWO VARIABLES. The join loop must cover exactly
     * the spawned set; an array sized by N_WURZELN makes "spawned but never
     * joined" a size mismatch instead of a forgotten line. */
    pthread_t faden[N_WURZELN];
    int rc;

    rc = pthread_create(&faden[0], NULL, faden_hauptA, NULL);
    if (rc != 0) {
        fprintf(stderr, "start: hauptA: %d\n", rc);
        return 2;
    }
    rc = pthread_create(&faden[1], NULL, faden_hauptB, NULL);
    if (rc != 0) {
        fprintf(stderr, "start: hauptB: %d\n", rc);
        return 2;
    }
    for (int i = 0; i < N_WURZELN; i++) {
        rc = pthread_join(faden[i], NULL);
        if (rc != 0) {
            fprintf(stderr, "join: thread %d: %d\n", i, rc);
            return 2;
        }
    }

    /* WHAT IS CHECKED, AND WHY EACH LINE IS SHAPED THIS WAY.
     *
     * konto[0] == konto[1] is the LOCK INVARIANT (source line 38). Its VALUE
     * is schedule-dependent -- whichever of `setze(30)` / `setze(70)` runs
     * last wins, both under the lock -- so the check asserts the invariant,
     * not a value. A check for one fixed value would fail on every schedule
     * that orders the threads the other way; the invariant is what the
     * language carries.
     *
     * privA / privB are written by exactly one thread each with no lock.
     * Their values are deterministic (7, 7 and 5): any deviation is a lost
     * write, i.e. a real defect, not a schedule.
     */
    unsigned konto0 = konto_speicher.slots[0].stand;
    unsigned konto1 = konto_speicher.slots[1].stand;
    unsigned pa0 = privA_speicher.slots[0].stand;
    unsigned pa1 = privA_speicher.slots[1].stand;
    unsigned pb0 = privB_speicher.slots[0].stand;

    printf("konto=%u konto=%u privA=%u privA=%u privB=%u\n",
        konto0, konto1, pa0, pa1, pb0);

    if (konto0 != konto1) {
        fprintf(stderr, "INVARIANT BROKEN: konto[0]=%u konto[1]=%u\n", konto0, konto1);
        return 1;
    }
    if (pa0 != 7 || pa1 != 7) {
        fprintf(stderr, "LOST WRITE: privA=%u,%u, want 7,7\n", pa0, pa1);
        return 1;
    }
    if (pb0 != 5) {
        fprintf(stderr, "LOST WRITE: privB=%u, want 5\n", pb0);
        return 1;
    }
    return 0;
}
