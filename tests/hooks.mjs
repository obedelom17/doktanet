// Redirige @neondatabase/serverless vers un shim PGlite (Postgres en mémoire) pour les tests.
import { pathToFileURL } from 'node:url';
import { resolve as pathResolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
export async function resolve(specifier, context, next) {
  if (specifier === '@neondatabase/serverless') {
    return { url: pathToFileURL(pathResolve(here, 'neon-shim.mjs')).href, shortCircuit: true };
  }
  return next(specifier, context);
}
