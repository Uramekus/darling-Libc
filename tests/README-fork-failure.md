# Failed fork cleanup

Darling LibSystem's ordinary parent callback waits for a child check-in. Calling
it after __fork returns -1 can hang forever. The optional version-2 failure
callback lets LibSystem release prepare locks and run parent handlers without
waiting for a nonexistent child. The original fork errno is restored after
cleanup. Both libc and LibSystem need updating to enable the fix.

Version-1 providers and null failure callbacks retain the old parent callback.
New providers remain compatible with old consumers, but old consumers still
have the original failure behavior. Existing fields retain their offsets.

Run the actual-source control-flow and guarded-layout test on Linux:

```sh
ruby tests/fork-failure-callback.rb
```

It uses ASan/UBSan, verifies failure errno despite a clobbering callback, tests
parent/child success branches, and places a version-1 table immediately before
an inaccessible page to catch extension reads. Syscall results are controlled;
this is not an actual host fork test.

`fork-failure-guest.c` runs the real public fork entry point in a disposable
Darling stage where fork currently returns ENOSYS. It requires that failure
precondition (exit 77 otherwise), checks three consecutive failures, verifies
prepare/parent handler counts and preserved errno, and allocates after cleanup.
Use an external timeout: the unfixed LibSystem/libc pair hangs in the first
child-checkin wait. It does not inject or solve the underlying ENOSYS, and does
not establish successful guest fork behavior.

Validation used rebuilt fork.c linked with unchanged staged libc objects, plus
a full 21-object LibSystem rebuild using the new header. This is a fork-only
libc overlay, not a clean full-libc or parent build. Runtime testing was ARM64;
x86_64 runtime execution and failure injection for other errno values were not
performed. All architecture-independent consumer branches are host-tested.
