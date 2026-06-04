// Post-build steps for GitHub Pages (SPA routing + Jekyll bypass).
const fs = require('fs');
const path = require('path');

const outDir = path.join('build', 'web');
const indexHtml = path.join(outDir, 'index.html');

if (!fs.existsSync(indexHtml)) {
  console.error('Missing build/web/index.html — run flutter build web first.');
  process.exit(1);
}

fs.copyFileSync(indexHtml, path.join(outDir, '404.html'));
fs.writeFileSync(path.join(outDir, '.nojekyll'), '');

const customSw = path.join('web', 'flutter_service_worker.js');
const outSw = path.join(outDir, 'flutter_service_worker.js');
if (fs.existsSync(customSw)) {
  fs.copyFileSync(customSw, outSw);
  console.log('GitHub Pages post-build: applied web/flutter_service_worker.js');
} else {
  console.warn('GitHub Pages post-build: missing web/flutter_service_worker.js');
}

console.log('GitHub Pages post-build: copied 404.html and wrote .nojekyll');
