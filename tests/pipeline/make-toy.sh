#!/usr/bin/env bash
# make-toy.sh [target-dir]   (default: ../pipeline-toy next to this repo)
# Creates a tiny Node CLI repo for the M6 dry run and copies this repo's pipeline into it.
# With --sync on an existing toy, only the pipeline files are refreshed.
set -eu
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
sync=0; [ "${1:-}" = "--sync" ] && { sync=1; shift; }
T="${1:-$ROOT/../pipeline-toy}"

copy_pipeline() {
  mkdir -p "$T/.claude"
  rm -rf "$T/.claude/agents" "$T/.claude/hooks" "$T/.claude/scripts" "$T/.claude/skills"
  cp -r "$ROOT/.claude/agents" "$ROOT/.claude/hooks" "$ROOT/.claude/scripts" "$T/.claude/"
  mkdir -p "$T/.claude/skills"
  for s in build-feature aligning-requirements writing-specs writing-tasks reviewing-plans reviewing-code checking-spec-conformance; do
    cp -r "$ROOT/.claude/skills/$s" "$T/.claude/skills/"
  done
  cp "$ROOT/.claude/settings.json" "$T/.claude/"
  # Small units so the toy plan must use sub-phases.
  printf 'TEST_CMD="npm test"\nMAX_UNIT_TASKS=2\nMAX_LOOPS=2\n' > "$T/.claude/pipeline.conf"
}

if [ $sync -eq 1 ]; then copy_pipeline; echo "synced pipeline into $T"; exit 0; fi
[ -e "$T" ] && { echo "$T exists; remove it or use --sync" >&2; exit 1; }
mkdir -p "$T/bin" "$T/src" "$T/test" "$T/scripts"
cat > "$T/package.json" <<'EOF'
{
  "name": "pipeline-toy",
  "version": "0.1.0",
  "private": true,
  "bin": { "greet": "bin/greet.js" },
  "scripts": { "test": "node --test" }
}
EOF
cat > "$T/src/greet.js" <<'EOF'
function greet(name) {
  return `Hello, ${name}`;
}

module.exports = { greet };
EOF
cat > "$T/bin/greet.js" <<'EOF'
#!/usr/bin/env node
const { greet } = require('../src/greet');

const args = process.argv.slice(2);
const i = args.indexOf('--name');
const name = i >= 0 && args[i + 1] ? args[i + 1] : 'world';
console.log(greet(name));
EOF
cat > "$T/test/greet.test.js" <<'EOF'
const test = require('node:test');
const assert = require('node:assert');
const { execFileSync } = require('node:child_process');
const path = require('node:path');
const { greet } = require('../src/greet');

const bin = path.join(__dirname, '..', 'bin', 'greet.js');
const run = (...args) => execFileSync(process.execPath, [bin, ...args], { encoding: 'utf8' });

test('greet formats the name', () => {
  assert.strictEqual(greet('Ada'), 'Hello, Ada');
});

test('cli defaults to world', () => {
  assert.strictEqual(run(), 'Hello, world\n');
});

test('cli takes --name', () => {
  assert.strictEqual(run('--name', 'Ada'), 'Hello, Ada\n');
});
EOF
# Seeds a defect that tests do not catch but a reviewer should (env leak to stderr).
cat > "$T/scripts/seed-defect.sh" <<'EOF'
#!/usr/bin/env bash
# Run during the dry run after an implementer finishes, before its review.
set -eu
cd "$(dirname "$0")/.."
printf '\nif (process.env.GREET_DEBUG) console.error(JSON.stringify(process.env));\n' >> bin/greet.js
echo "seeded: bin/greet.js now dumps the whole environment to stderr when GREET_DEBUG is set"
EOF
# Adds a failing test so the implementer's Stop hook has something to block on.
cat > "$T/scripts/seed-red.sh" <<'EOF'
#!/usr/bin/env bash
# Run while an implementer is working. Its Stop hook should block it until this is green.
set -eu
cd "$(dirname "$0")/.."
cat > test/zz-seeded.test.js <<'T'
const test = require('node:test');
const assert = require('node:assert');
const { greet } = require('../src/greet');
// Seeded for the dry run: greet must trim surrounding spaces from the name.
test('greet trims the name', () => {
  assert.strictEqual(greet('  Ada  '), 'Hello, Ada');
});
T
echo "seeded: test/zz-seeded.test.js fails until greet trims the name"
EOF
printf 'node_modules/\n' > "$T/.gitignore"
printf '* text=auto eol=lf\n' > "$T/.gitattributes"
copy_pipeline
cd "$T"
npm test >/dev/null 2>&1 && echo "toy tests green"
git init -q && git add -A && git commit -qm "chore: toy CLI and pipeline" && echo "toy repo ready at $T"
