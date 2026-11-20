// Static check of the mod's Lua files: unknown globals (e.g. a local that lost its import), upvalues per function, top-level locals.
// Usage (from the repository root): node tools\check.js .
const fs = require('fs'); const path = require('path');
const { analyze } = require('./analyze');
const dir = process.argv[2];
const origGlobals = new Set(['ac','ipairs','io','rgbm','os','string','tostring','pcall','math','ui','stringify','table','type','pairs','vec2','tonumber','JSON','bit','script','require','windowMain','windowConfig','windowDev']);
let bad = 0;
const skipDirs = new Set(['tools', 'node_modules', '.git', 'sounds', 'session-state']);
function walk(d) { return fs.readdirSync(d, { withFileTypes: true }).flatMap(e => e.isDirectory() ? (skipDirs.has(e.name) ? [] : walk(path.join(d, e.name))) : e.name.endsWith('.lua') ? [path.join(d, e.name)] : []); }
for (const file of walk(dir)) {
  let src = fs.readFileSync(file, 'latin1').replace(/\r\n/g, '\n');
  const { symbols, globals, fnInfo } = analyze(src);
  const unknown = [...new Set(globals.map(g => g.name).filter(n => !origGlobals.has(n)))];
  const maxUp = Math.max(0, ...fnInfo.map(f => f.upvalues.size));
  const rel = path.relative(dir, file);
  const flag = unknown.length || maxUp >= 60 || symbols.length >= 200;
  if (flag) bad++;
  console.log(`${flag ? 'FAIL' : 'ok  '} ${rel.padEnd(26)} locals=${String(symbols.length).padStart(3)} maxUpvalues=${String(maxUp).padStart(2)} ${unknown.length ? 'UNKNOWN GLOBALS: ' + unknown.map(n => n + '@' + globals.filter(g => g.name === n).map(g => g.line).join('/')).join(' ') : ''}`);
}
process.exit(bad ? 1 : 0);
