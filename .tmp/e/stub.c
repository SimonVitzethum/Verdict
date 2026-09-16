/* Scratch stub: what the emitter declares and never defines -- the lock primitives
   and the diverging exits. Hosted measurement shape (pthread), per BERICHT-bm9 §4. */
#include <pthread.h>
#include <stdlib.h>
static pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;
void VSPERRE_nimm(void) { pthread_mutex_lock(&m); }
void VSPERRE_gib(void)  { pthread_mutex_unlock(&m); }
_Noreturn void zaehler_streit(void) { abort(); }
_Noreturn void netz_streit(void) { abort(); }
_Noreturn void lauf_aufgegeben(void) { abort(); }
_Noreturn void treffer_aufgegeben(void) { abort(); }
_Noreturn void warte_aufgegeben(void) { abort(); }
