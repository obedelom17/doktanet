export function neon() {
  return { query: async (text, params = []) => (await globalThis.__pg.query(text, params)).rows };
}
