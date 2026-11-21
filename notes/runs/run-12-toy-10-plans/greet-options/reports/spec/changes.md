Open-question answers and remaining P1 finding to apply to the spec.

1. Q-1 (json single greeting shape): use a bare string, `{"greeting": "Hello, world"}`.
2. Q-2 (unknown config keys): reject unknown keys as a usage error, exit 2.
3. Q-3 (shout + json): `--shout` upper-cases the greeting inside the JSON value too.

4. Remaining P1: TEST-008's banned list includes `readFile`, a substring of the required `readFileSync`, so the test as worded bans its own allowed call. Fix the wording so it bans whole method names only, not the substring.
