import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  signJwt, verifyJwt, hashPassword, checkPassword, b32enc, totp, totpCheck,
  timingSafeEq, encData, decData, sha256hex, randToken, DOC_RE, isRated, limited, validEmail, validPhone,
} from '../functions/_shared/util.js';

test('JWT : aller-retour et claims', async () => {
  const t = await signJwt({ sub: 'u1', tv: 3 }, 'secret');
  const c = await verifyJwt(t, 'secret');
  assert.equal(c.sub, 'u1');
  assert.equal(c.tv, 3);
});

test('JWT : signature falsifiée refusée', async () => {
  const t = await signJwt({ sub: 'u1' }, 'secret');
  assert.equal(await verifyJwt(t, 'autre-secret'), null);
  const [h, p, s] = t.split('.');
  const forged = `${h}.${Buffer.from(JSON.stringify({ sub: 'admin', exp: 9999999999 })).toString('base64url')}.${s}`;
  assert.equal(await verifyJwt(forged, 'secret'), null);
  assert.equal(await verifyJwt('nimporte.quoi', 'secret'), null);
});

test('mot de passe : hash salé et vérification', async () => {
  const h1 = await hashPassword('Test1234!');
  const h2 = await hashPassword('Test1234!');
  assert.notEqual(h1, h2);
  assert.equal(await checkPassword('Test1234!', h1), true);
  assert.equal(await checkPassword('test1234!', h1), false);
});

test('TOTP : vecteur RFC 6238 (SHA-1, t=59 s)', async () => {
  const secret = b32enc(new TextEncoder().encode('12345678901234567890'));
  assert.equal(await totp(secret, 59000), '287082');
  assert.equal(await totp(secret, 1111111109000), '081804');
});

test('TOTP : fenêtre de tolérance', async () => {
  const secret = b32enc(crypto.getRandomValues(new Uint8Array(20)));
  assert.equal(await totpCheck(secret, await totp(secret, Date.now())), true);
  assert.equal(await totpCheck(secret, '000000x'), false);
});

test('timingSafeEq', () => {
  assert.equal(timingSafeEq('abc', 'abc'), true);
  assert.equal(timingSafeEq('abc', 'abd'), false);
  assert.equal(timingSafeEq('abc', 'abcd'), false);
  assert.equal(timingSafeEq(undefined, ''), true);
});

test('chiffrement AES-GCM des données', async () => {
  const c = await encData('cle', 'Résultat : négatif');
  assert.ok(c.startsWith('enc1:'));
  assert.notEqual(c, await encData('cle', 'Résultat : négatif'));
  assert.equal(await decData('cle', c), 'Résultat : négatif');
  assert.equal(await decData('mauvaise', c), '[illisible]');
  assert.equal(await decData(undefined, c), '[chiffré]');
});

test('chiffrement : sans clé, texte clair conservé', async () => {
  assert.equal(await encData('', 'abc'), 'abc');
  assert.equal(await decData('', 'abc'), 'abc');
});

test('sha256 et jetons', async () => {
  assert.equal(await sha256hex('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  assert.notEqual(randToken(), randToken());
  assert.ok(randToken(32).length >= 40);
});

test('validations', () => {
  assert.ok(DOC_RE.test('data:image/png;base64,AAAA'));
  assert.ok(DOC_RE.test('data:application/pdf;base64,AAAA'));
  assert.ok(!DOC_RE.test('data:text/html;base64,AAAA'));
  assert.ok(!DOC_RE.test('data:image/svg+xml;base64,AAAA'));
  assert.ok(isRated(5) && isRated(1) && !isRated(0) && !isRated(6) && !isRated(3.5) && !isRated('4'));
  assert.ok(limited(5, 5) && !limited(4, 5));
  assert.ok(validEmail('a@b.tg') && !validEmail('a@b') && !validEmail('a b@c.d'));
  assert.ok(validPhone('+228 90 12 34 56') && !validPhone('12'));
});
