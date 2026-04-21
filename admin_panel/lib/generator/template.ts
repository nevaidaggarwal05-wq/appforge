// ═══════════════════════════════════════════════════════════════
// Flutter template bundler — reads the sibling `flutter_shell/`
// directory from disk, applies per-app substitutions, returns a
// Map<path, content> ready to be written into a ZIP.
//
// Coolify deployment note: the admin_panel container must include
// `flutter_shell/` at a sibling path (../flutter_shell from cwd) OR
// the FLUTTER_SHELL_PATH env var must point at it.
// ═══════════════════════════════════════════════════════════════

import { readdir, readFile } from 'fs/promises';
import path from 'path';

import type { App } from '@/lib/supabase/types';

const EXCLUDE_DIR_NAMES = new Set([
  '.dart_tool', 'build', '.pub-cache', 'Pods', '.symlinks',
  '.gradle', '.idea', '.vscode', 'node_modules', '.git',
]);

const EXCLUDE_FILES = new Set([
  '.DS_Store', 'pubspec.lock', 'key.properties', '.env', '.env.local',
]);

const EXCLUDE_EXT = new Set(['.jks', '.keystore']);

/** Also skipped because the route regenerates it per-app. */
const REGENERATED_FILES = new Set(['lib/app_config.dart']);

export function flutterShellRoot(): string {
  return process.env.FLUTTER_SHELL_PATH
    || path.resolve(process.cwd(), '..', 'flutter_shell');
}

/** Recursively read every file under `root` into a Map<relativePath, Buffer>. */
export async function walkFlutterShell(root: string): Promise<Map<string, Buffer>> {
  const out = new Map<string, Buffer>();

  async function walk(dir: string, rel: string): Promise<void> {
    const entries = await readdir(dir, { withFileTypes: true });
    for (const ent of entries) {
      const name = ent.name;
      if (EXCLUDE_DIR_NAMES.has(name) && ent.isDirectory()) continue;
      if (EXCLUDE_FILES.has(name)) continue;
      if (EXCLUDE_EXT.has(path.extname(name))) continue;

      const full = path.join(dir, name);
      const childRel = rel ? `${rel}/${name}` : name;

      if (REGENERATED_FILES.has(childRel)) continue;

      if (ent.isDirectory()) {
        await walk(full, childRel);
      } else if (ent.isFile()) {
        const buf = await readFile(full);
        out.set(childRel, buf);
      }
    }
  }

  await walk(root, '');
  return out;
}

/** Replace template placeholders with per-app values. May also RENAME paths
 *  (e.g. MainActivity.kt moves to match the new package). */
export function applySubstitutions(
  app: App,
  files: Map<string, Buffer>
): Map<string, Buffer> {
  const out = new Map<string, Buffer>();
  const pkg = app.package_name;
  const pkgPath = pkg.replace(/\./g, '/');
  const appHost = hostOf(app.app_url);
  const admob = app.admob_app_id || 'ca-app-pub-3940256099942544~3347511713';

  for (const [relPath, buf] of files) {
    let newPath = relPath;
    let content: Buffer | string = buf;

    // MainActivity.kt — rename directory to match new package + rewrite
    // `package` declaration.
    if (relPath === 'android/app/src/main/kotlin/com/template/app_template/MainActivity.kt') {
      newPath = `android/app/src/main/kotlin/${pkgPath}/MainActivity.kt`;
      content = buf.toString('utf8').replace(
        /^package\s+[\w.]+/m,
        `package ${pkg}`
      );
    }

    else if (relPath === 'android/app/build.gradle') {
      content = buf.toString('utf8')
        .replace(/namespace\s+"com\.template\.app_template"/, `namespace "${pkg}"`)
        .replace(/applicationId\s+"com\.template\.app_template"/, `applicationId "${pkg}"`)
        .replace(/versionCode\s+flutterVersionCode\.toInteger\(\)/, `versionCode ${app.version_code}`)
        .replace(/versionName\s+flutterVersionName/, `versionName "${app.version_name}"`);
    }

    else if (relPath === 'android/app/src/main/AndroidManifest.xml') {
      content = buf.toString('utf8')
        .replace(
          /android:value="ca-app-pub-3940256099942544~3347511713"/,
          `android:value="${admob}"`
        )
        .replace(
          /android:host="example\.com"/,
          `android:host="${appHost}"`
        );
    }

    else if (relPath === 'android/app/src/main/res/values/strings.xml') {
      content = buf.toString('utf8').replace(
        /<string name="app_name">[^<]*<\/string>/,
        `<string name="app_name">${escapeXml(app.name)}</string>`
      );
    }

    else if (relPath === 'docs/hosting/assetlinks_TEMPLATE.json') {
      content = buf.toString('utf8')
        .replace(/"com\.template\.app_template"/, `"${pkg}"`)
        .replace(
          /"REPLACE_WITH_YOUR_KEYSTORE_SHA256"/,
          `"${app.sha256_fingerprint || 'REPLACE_WITH_YOUR_KEYSTORE_SHA256'}"`
        );
    }

    out.set(
      newPath,
      typeof content === 'string' ? Buffer.from(content, 'utf8') : content
    );
  }

  return out;
}

function hostOf(url: string): string {
  try {
    return new URL(url).host || 'example.com';
  } catch {
    return 'example.com';
  }
}

function escapeXml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}
