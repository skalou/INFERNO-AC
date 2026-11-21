// Shared Lua scope analysis for the INFERNO split tool.
const luaparse = require('luaparse');

function parse(src) {
  return luaparse.parse(src, { luaVersion: 'LuaJIT', ranges: true, locations: true, comments: false });
}

// Walks a chunk and resolves every identifier. Top-level locals of the chunk become symbols.
function analyze(src) {
  const ast = parse(src);
  const symbols = [];        // top-level locals
  const refs = [];           // { sym, range, stmt, fnDepth, assign }
  const globals = [];        // { name, range, stmt, fnDepth, assign }
  const fnInfo = [];         // per function: { line, upvalues:Set }

  let stmtIndex = -1;
  const top = { vars: new Map(), parent: null, fn: null, top: true };

  function lookup(scope, name) {
    for (let s = scope; s; s = s.parent) if (s.vars.has(name)) return { v: s.vars.get(name), scope: s };
    return null;
  }

  function declare(scope, node, kind, hasInit) {
    if (scope.top) {
      const sym = { id: symbols.length, name: node.name, stmt: stmtIndex, kind, hasInit, assigns: [], range: node.range, declNode: null };
      symbols.push(sym);
      scope.vars.set(node.name, { sym, fn: scope.fn });
    } else {
      scope.vars.set(node.name, { sym: null, fn: scope.fn });
    }
  }

  function ref(scope, id, fnDepth, assign) {
    const found = lookup(scope, id.name);
    if (found && found.v.sym) {
      refs.push({ sym: found.v.sym, range: id.range, stmt: stmtIndex, fnDepth, assign, line: id.loc.start.line });
      if (assign) found.v.sym.assigns.push({ stmt: stmtIndex, fnDepth, line: id.loc.start.line });
    } else if (!found) {
      globals.push({ name: id.name, range: id.range, stmt: stmtIndex, fnDepth, assign, line: id.loc.start.line });
    }
    // Upvalue accounting (LuaJIT limit: 60 per function).
    if (found && scope.fn && found.v.fn !== scope.fn) {
      for (let f = scope.fn; f && f !== found.v.fn; f = f.parentFn) f.upvalues.add(found.v);
    }
  }

  function block(body, scope, fnDepth) {
    for (const st of body) stmt(st, scope, fnDepth);
  }

  function func(node, scope, fnDepth) {
    const fn = { line: node.loc.start.line, upvalues: new Set(), parentFn: scope.fn, locals: 0 };
    fnInfo.push(fn);
    const inner = { vars: new Map(), parent: scope, fn, top: false };
    if (node.identifier && node.identifier.indexer === ':') declare(inner, { name: 'self' }, 'param');
    for (const p of node.parameters) if (p.type === 'Identifier') declare(inner, p, 'param');
    block(node.body, inner, fnDepth + 1);
  }

  function expr(e, scope, fnDepth) {
    if (!e) return;
    switch (e.type) {
      case 'Identifier': ref(scope, e, fnDepth, false); break;
      case 'MemberExpression': expr(e.base, scope, fnDepth); break;
      case 'IndexExpression': expr(e.base, scope, fnDepth); expr(e.index, scope, fnDepth); break;
      case 'CallExpression': expr(e.base, scope, fnDepth); e.arguments.forEach(a => expr(a, scope, fnDepth)); break;
      case 'TableCallExpression': expr(e.base, scope, fnDepth); expr(e.arguments, scope, fnDepth); break;
      case 'StringCallExpression': expr(e.base, scope, fnDepth); expr(e.argument, scope, fnDepth); break;
      case 'TableConstructorExpression':
        for (const f of e.fields) {
          if (f.type === 'TableKey') { expr(f.key, scope, fnDepth); expr(f.value, scope, fnDepth); }
          else expr(f.value, scope, fnDepth);
        }
        break;
      case 'BinaryExpression': case 'LogicalExpression': expr(e.left, scope, fnDepth); expr(e.right, scope, fnDepth); break;
      case 'UnaryExpression': expr(e.argument, scope, fnDepth); break;
      case 'FunctionDeclaration': func(e, scope, fnDepth); break;
      case 'StringLiteral': case 'NumericLiteral': case 'BooleanLiteral': case 'NilLiteral': case 'VarargLiteral': break;
      default: throw new Error('Unknown expression ' + e.type + ' at line ' + e.loc.start.line);
    }
  }

  function stmt(s, scope, fnDepth) {
    switch (s.type) {
      case 'LocalStatement':
        s.init.forEach(e => expr(e, scope, fnDepth));
        for (const v of s.variables) declare(scope, v, 'local', s.init.length > 0);
        break;
      case 'FunctionDeclaration':
        if (s.isLocal) { declare(scope, s.identifier, 'function', true); func(s, scope, fnDepth); }
        else {
          if (s.identifier.type === 'Identifier') ref(scope, s.identifier, fnDepth, true);
          else expr(s.identifier, scope, fnDepth);
          func(s, scope, fnDepth);
        }
        break;
      case 'AssignmentStatement':
        s.init.forEach(e => expr(e, scope, fnDepth));
        for (const v of s.variables) {
          if (v.type === 'Identifier') ref(scope, v, fnDepth, true);
          else expr(v, scope, fnDepth);
        }
        break;
      case 'CallStatement': expr(s.expression, scope, fnDepth); break;
      case 'ReturnStatement': s.arguments.forEach(e => expr(e, scope, fnDepth)); break;
      case 'IfStatement':
        for (const c of s.clauses) {
          if (c.condition) expr(c.condition, scope, fnDepth);
          block(c.body, { vars: new Map(), parent: scope, fn: scope.fn, top: false }, fnDepth);
        }
        break;
      case 'WhileStatement':
        expr(s.condition, scope, fnDepth);
        block(s.body, { vars: new Map(), parent: scope, fn: scope.fn, top: false }, fnDepth);
        break;
      case 'DoStatement': block(s.body, { vars: new Map(), parent: scope, fn: scope.fn, top: false }, fnDepth); break;
      case 'RepeatStatement': {
        const inner = { vars: new Map(), parent: scope, fn: scope.fn, top: false };
        block(s.body, inner, fnDepth); expr(s.condition, inner, fnDepth); break;
      }
      case 'ForNumericStatement': {
        expr(s.start, scope, fnDepth); expr(s.end, scope, fnDepth); expr(s.step, scope, fnDepth);
        const inner = { vars: new Map(), parent: scope, fn: scope.fn, top: false };
        declare(inner, s.variable, 'local'); block(s.body, inner, fnDepth); break;
      }
      case 'ForGenericStatement': {
        s.iterators.forEach(e => expr(e, scope, fnDepth));
        const inner = { vars: new Map(), parent: scope, fn: scope.fn, top: false };
        s.variables.forEach(v => declare(inner, v, 'local')); block(s.body, inner, fnDepth); break;
      }
      case 'BreakStatement': case 'GotoStatement': case 'LabelStatement': break;
      default: throw new Error('Unknown statement ' + s.type + ' at line ' + s.loc.start.line);
    }
  }

  ast.body.forEach((s, i) => { stmtIndex = i; stmt(s, top, 0); });
  return { ast, symbols, refs, globals, fnInfo };
}

// Short key for a top-level statement, used to assign statements to modules.
function stmtKey(s, src) {
  const text = node => src.slice(node.range[0], node.range[1]);
  switch (s.type) {
    case 'LocalStatement': return s.variables.map(v => v.name).join(',');
    case 'FunctionDeclaration': return text(s.identifier);
    case 'AssignmentStatement': return text(s.variables[0]) + '=';
    case 'CallStatement': return 'call:' + text(s.expression.base);
    default: return s.type + '@' + s.loc.start.line;
  }
}

module.exports = { parse, analyze, stmtKey };
