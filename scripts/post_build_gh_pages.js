// Post-build steps for GitHub Pages (SPA routing + Jekyll bypass + absolute asset paths).
const fs = require('fs');
const path = require('path');
const { resolveCacheTag } = require('./resolve_cache_tag');

const outDir = path.join('build', 'web');
const ghBase = process.env.GITHUB_PAGES_BASE_HREF || '/snack-burger/';
const cacheTag = resolveCacheTag();

const sourceIndex = path.join('web', 'index.html');
const outIndex = path.join(outDir, 'index.html');

if (!fs.existsSync(outIndex)) {
  console.error('Missing build/web/index.html — run flutter build web first.');
  process.exit(1);
}

function injectCacheTag(html) {
  return html.replace(/__CACHE_TAG__/g, cacheTag);
}

if (fs.existsSync(sourceIndex)) {
  let html = fs.readFileSync(sourceIndex, 'utf8');
  html = html.replace(/\$FLUTTER_BASE_HREF/g, ghBase);
  html = injectCacheTag(html);
  fs.writeFileSync(outIndex, html, 'utf8');
  console.log(
    `GitHub Pages post-build: applied web/index.html (cache tag=${cacheTag})`,
  );
} else {
  console.warn('GitHub Pages post-build: missing web/index.html — using Flutter output');
}

const versionJsonPath = path.join(outDir, 'version.json');
if (fs.existsSync(versionJsonPath)) {
  try {
    const versionJson = JSON.parse(fs.readFileSync(versionJsonPath, 'utf8'));
    versionJson.deploy_tag = cacheTag;
    fs.writeFileSync(versionJsonPath, JSON.stringify(versionJson, null, 2));
    console.log(`GitHub Pages post-build: version.json deploy_tag=${cacheTag}`);
  } catch (error) {
    console.warn('GitHub Pages post-build: could not patch version.json', error);
  }
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
