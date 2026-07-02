#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..');
const miniRoot = path.join(repoRoot, 'psa-mini-program-new');
const pagesJsonPath = path.join(miniRoot, 'pages.json');

function fail(message) {
  console.error(`[mp-routes] ${message}`);
  process.exitCode = 1;
}

function normalizeRoute(route) {
  if (!route || typeof route !== 'string') {
    return null;
  }
  let normalized = route.trim();
  if (!normalized || normalized === '/') {
    return null;
  }
  if (/^(https?:)?\/\//.test(normalized)) {
    return null;
  }
  const queryIndex = normalized.indexOf('?');
  if (queryIndex >= 0) {
    normalized = normalized.slice(0, queryIndex);
  }
  const hashIndex = normalized.indexOf('#');
  if (hashIndex >= 0) {
    normalized = normalized.slice(0, hashIndex);
  }
  if (normalized.includes('${')) {
    return null;
  }
  normalized = normalized.replace(/^\/+/, '');
  return normalized || null;
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function addPage(routeSet, route) {
  const normalized = normalizeRoute(route);
  if (normalized) {
    routeSet.add(normalized);
  }
}

function collectRegisteredRoutes(pagesJson) {
  const routes = new Set();
  for (const page of pagesJson.pages || []) {
    addPage(routes, page.path);
  }
  for (const subPackage of pagesJson.subPackages || pagesJson.subpackages || []) {
    const root = (subPackage.root || '').replace(/^\/+|\/+$/g, '');
    for (const page of subPackage.pages || []) {
      addPage(routes, `${root}/${page.path}`);
    }
  }
  return routes;
}

function walk(dir, files = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === 'node_modules' || entry.name === 'unpackage' || entry.name === 'uni_modules') {
      continue;
    }
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(fullPath, files);
    } else if (/\.(vue|js|ts)$/.test(entry.name)) {
      files.push(fullPath);
    }
  }
  return files;
}

function collectReferencedRoutes(files) {
  const references = [];
  const callPattern = /uni\.(?:navigateTo|redirectTo|reLaunch|switchTab)\s*\(\s*\{[\s\S]{0,500}?url\s*:\s*(['"`])([^'"`]+)\1/g;

  for (const file of files) {
    const content = fs.readFileSync(file, 'utf8');
    let match;
    while ((match = callPattern.exec(content)) !== null) {
      const route = normalizeRoute(match[2]);
      if (!route || !route.startsWith('pages/')) {
        continue;
      }
      references.push({
        route,
        file: path.relative(repoRoot, file),
      });
    }
  }
  return references;
}

function main() {
  if (!fs.existsSync(pagesJsonPath)) {
    fail(`missing ${path.relative(repoRoot, pagesJsonPath)}`);
    return;
  }

  const pagesJson = readJson(pagesJsonPath);
  const registeredRoutes = collectRegisteredRoutes(pagesJson);

  for (const route of registeredRoutes) {
    const vueFile = path.join(miniRoot, `${route}.vue`);
    if (!fs.existsSync(vueFile)) {
      fail(`registered route has no .vue file: ${route}`);
    }
  }

  const sourceFiles = walk(miniRoot);
  const referencedRoutes = collectReferencedRoutes(sourceFiles);
  for (const reference of referencedRoutes) {
    if (!registeredRoutes.has(reference.route)) {
      fail(`unregistered route "${reference.route}" referenced in ${reference.file}`);
    }
  }

  if (process.exitCode) {
    return;
  }
  console.log(`[mp-routes] OK: ${registeredRoutes.size} registered routes, ${referencedRoutes.length} static navigation references checked.`);
}

main();
