// Post-build steps for GitHub Pages (SPA routing + Jekyll bypass + absolute asset paths).
const fs = require('fs');
const path = require('path');

const outDir = path.join('build', 'web');
const ghBase = process.env.GITHUB_PAGES_BASE_HREF || '/snack-burger/';

const sourceIndex = path.join('web', 'index.html');
const outIndex = path.join(outDir, 'index.html');

if (!fs.existsSync(outIndex)) {
  console.error('Missing build/web/index.html — run flutter build web first.');
  process.exit(1);
}

if (fs.existsSync(sourceIndex)) {
  let html = fs.readFileSync(sourceIndex, 'utf8');
  html = html.replace(/\$FLUTTER_BASE_HREF/g, ghBase);
  fs.writeFileSync(outIndex, html, 'utf8');
  console.log('GitHub Pages post-build: applied web/index.html (absolute /snack-burger/ paths)');
} else {
  console.warn('GitHub Pages post-build: missing web/index.html — using Flutter output');
}

fs.copyFileSync(outIndex, path.join(outDir, '404.html'));
fs.writeFileSync(path.join(outDir, '.nojekyll'), '');

// Service worker معطّل في index.html — احذف الملف المولّد لتفادي تسجيل نسخة قديمة.
const outSw = path.join(outDir, 'flutter_service_worker.js');
if (fs.existsSync(outSw)) {
  fs.unlinkSync(outSw);
  console.log('GitHub Pages post-build: removed flutter_service_worker.js');
}

console.log('GitHub Pages post-build: copied 404.html and wrote .nojekyll');
