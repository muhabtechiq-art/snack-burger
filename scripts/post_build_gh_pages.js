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
console.log('GitHub Pages post-build: copied 404.html and wrote .nojekyll');
