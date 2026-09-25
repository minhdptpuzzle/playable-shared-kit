'use strict';
const fs = require('node:fs');
const path = require('node:path');

// Serialize Editor initialization (which writes shared engine/profile files),
// then release the next worker once this Editor enters the actual build.
function createStartupGate() {
  let tail = Promise.resolve();
  return async () => {
    const previous = tail;
    let release;
    tail = new Promise(resolve => { release = resolve; });
    await previous;
    return release;
  };
}

function assertFreshBuild(buildPath, config, startedAt) {
  const common = path.join(buildPath, 'super-html', 'common', `${config.name}_common_min.html`);
  const previousCommon = path.join(buildPath, 'common', `${config.name}_common_min.html`);
  const superHtml = path.join(buildPath, 'super-html');
  const candidates = [];
  if (fs.existsSync(common) || fs.existsSync(previousCommon)) {
    // Flattened output from a previous run cannot establish this run succeeded.
    candidates.push(common);
  } else if (fs.existsSync(superHtml)) {
    const visit = dir => {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) visit(full);
        else if (/\.(html|zip)$/i.test(entry.name)) candidates.push(full);
      }
    };
    visit(superHtml);
  } else {
    candidates.push(path.join(buildPath, config.outputName || config.platform || 'web-mobile', 'index.html'));
  }
  if (!candidates.length) throw new Error(`BUILD_OUTPUT_MISSING: ${buildPath}`);
  for (const file of candidates) {
    const stat = fs.existsSync(file) ? fs.statSync(file) : null;
    if (!stat || stat.size === 0 || stat.mtimeMs < startedAt) {
      throw new Error(`BUILD_OUTPUT_NOT_FRESH: ${file}. Editor exited without producing a new artifact.`);
    }
  }
}
module.exports = { createStartupGate, assertFreshBuild };
