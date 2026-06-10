// يُستخدم من post_build_gh_pages.js — معرّف نشر لكسر الكاش (ليس رقم إصدار التطبيق).
const { execSync } = require('child_process');

function resolveCacheTag() {
  const explicit = process.env.SNACK_BURGER_CACHE_TAG;
  if (explicit && String(explicit).trim()) {
    return String(explicit).trim();
  }

  const sha = process.env.GITHUB_SHA;
  if (sha && String(sha).trim()) {
    return String(sha).trim().slice(0, 7);
  }

  const runNumber = process.env.GITHUB_RUN_NUMBER;
  if (runNumber && String(runNumber).trim()) {
    return 'build-' + String(runNumber).trim();
  }

  try {
    return execSync('git rev-parse --short HEAD', { encoding: 'utf8' }).trim();
  } catch (_) {
    // ignore
  }

  return 'local-' + Date.now();
}

module.exports = { resolveCacheTag };
