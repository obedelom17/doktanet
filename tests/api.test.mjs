import { test, before } from 'node:test';
import assert from 'node:assert/strict';
import { freshDb, loadApi, makeClient } from './helpers.mjs';

const env = {
  JWT_SECRET: 'test-secret', PAY_SANDBOX: '1', PAY_WEBHOOK_SECRET: 'whsec', CRON_SECRET: 'cron',
  DATA_KEY: 'cle-donnees', RESEND_API_KEY: 'rk', MAIL_FROM: 'DoktaNet <no-reply@test.tg>', COMMISSION_PCT: '10',
};
let db, api;
const mails = [];
const realFetch = globalThis.fetch;

// Prochain créneau libre : demain, jour de semaine variable, 10:00 UTC.
const tomorrow = () => { const d = new Date(Date.now() + 86400000); return d; };
const slot = (d, h = 10) => new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), h)).toISOString();

const people = {};
async function signup(role, email, extra = {}) {
  const r = await api('POST', '/auth/register', { body: { role, email, password: 'Test1234!', full_name: `${role} ${email}`, phone: '+22890123456', consent: true, ...extra } });
  assert.equal(r.status, 200, JSON.stringify(r.data));
  return r.data.token;
}

before(async () => {
  db = await freshDb();
  const onRequest = await loadApi();
  api = makeClient(onRequest, env);
  globalThis.fetch = async (u, o) => {
    if (String(u).includes('api.resend.com')) { mails.push(JSON.parse(o.body)); return new Response('{}', { status: 200 }); }
    return realFetch(u, o);
  };
  people.pat = await signup('patient', 'pat@test.tg');
  people.doc = await signup('doctor', 'doc@test.tg', { order_number: 'OM-1', fee: 7000, specialty: 'Cardiologie' });
  people.adm = await signup('patient', 'adm@test.tg');
  await db.query(`update users set role='admin', status='active' where email='adm@test.tg'`);
  await db.query(`update users set status='active' where email='doc@test.tg'`);
  people.docId = (await db.query(`select id from users where email='doc@test.tg'`)).rows[0].id;
  people.patId = (await db.query(`select id from users where email='pat@test.tg'`)).rows[0].id;
  const wd = tomorrow().getUTCDay();
  const r = await api('PUT', '/doctor/availability', { token: people.doc, body: { slots: [{ weekday: wd, start: '09:00', end: '12:00' }] } });
  assert.equal(r.status, 200);
});

test('migration v2 appliquée (colonnes et tables)', async () => {
  const t = await db.query(`select to_regclass('public.reviews') a, to_regclass('public.notifications') b, to_regclass('public.patient_documents') c`);
  assert.ok(t.rows[0].a && t.rows[0].b && t.rows[0].c);
});

test('connexion : bon mot de passe, journal, jeton avec tv', async () => {
  const r = await api('POST', '/auth/login', { body: { email: 'PAT@test.tg', password: 'Test1234!' } });
  assert.equal(r.status, 200);
  assert.ok(r.data.token);
  const log = await db.query(`select 1 from audit_logs where action='login' and user_id=$1`, [people.patId]);
  assert.equal(log.rows.length, 1);
});

test('connexion : 5 échecs puis blocage 429, même avec le bon mot de passe', async () => {
  const c = makeClient(await loadApi(), env, '9.9.9.9');
  await signup('patient', 'brute@test.tg');
  for (let i = 0; i < 5; i++) assert.equal((await c('POST', '/auth/login', { body: { email: 'brute@test.tg', password: 'faux' } })).status, 401);
  assert.equal((await c('POST', '/auth/login', { body: { email: 'brute@test.tg', password: 'faux' } })).status, 429);
  assert.equal((await c('POST', '/auth/login', { body: { email: 'brute@test.tg', password: 'Test1234!' } })).status, 429);
});

test('inscription : email invalide et téléphone invalide refusés', async () => {
  assert.equal((await api('POST', '/auth/register', { body: { role: 'patient', email: 'pas-un-email', password: 'Test1234!', full_name: 'X', consent: true } })).status, 400);
  assert.equal((await api('POST', '/auth/register', { body: { role: 'patient', email: 'ok@test.tg', password: 'Test1234!', full_name: 'X', consent: true, phone: '12' } })).status, 400);
});

let apptId;
test('réservation : montant figé, notification au médecin, double réservation refusée', async () => {
  const d = tomorrow();
  const sl = (await api('GET', `/doctors/${people.docId}/slots?date=${d.toISOString().slice(0, 10)}`, { token: people.pat })).data.slots;
  assert.ok(sl.length >= 2, 'créneaux attendus');
  const r = await api('POST', '/appointments', { token: people.pat, body: { doctor_id: people.docId, starts_at: sl[0] } });
  assert.equal(r.status, 200, JSON.stringify(r.data));
  apptId = r.data.id;
  const row = (await db.query('select amount, payment_status from appointments where id=$1', [apptId])).rows[0];
  assert.equal(row.amount, 7000);
  assert.equal(row.payment_status, 'unpaid');
  const n = await api('GET', '/me/notifications', { token: people.doc });
  assert.ok(n.data.some((x) => x.title === 'Nouveau rendez-vous'));
  assert.ok(mails.some((m) => m.subject.includes('Nouveau rendez-vous')), 'email envoyé');
  const dup = await api('POST', '/appointments', { token: people.pat, body: { doctor_id: people.docId, starts_at: sl[0] } });
  assert.equal(dup.status, 409);
  people.slots = sl;
});

test('médecin inconnu ou inactif : 404', async () => {
  const r = await api('POST', '/appointments', { token: people.pat, body: { doctor_id: people.patId, starts_at: slot(tomorrow()) } });
  assert.equal(r.status, 404);
});

test('reprogrammation : créneau libre ok, créneau pris refusé, compteur', async () => {
  const r = await api('POST', `/appointments/${apptId}/reschedule`, { token: people.pat, body: { starts_at: people.slots[1] } });
  assert.equal(r.status, 200, JSON.stringify(r.data));
  const row = (await db.query('select starts_at, reschedule_count from appointments where id=$1', [apptId])).rows[0];
  assert.equal(new Date(row.starts_at).toISOString(), people.slots[1]);
  assert.equal(row.reschedule_count, 1);
  const bad = await api('POST', `/appointments/${apptId}/reschedule`, { token: people.pat, body: { starts_at: '2020-01-01T10:00:00.000Z' } });
  assert.equal(bad.status, 409);
  const other = await api('POST', `/appointments/${apptId}/reschedule`, { token: people.adm, body: { starts_at: people.slots[0] } });
  assert.ok([403, 404].includes(other.status));
});

test('paiement consultation (sandbox) puis REQUIRE_PAYMENT', async () => {
  const bad = await api('POST', `/appointments/${apptId}/pay`, { token: people.pat, body: { phone: '12' } });
  assert.equal(bad.status, 400);
  const ok = await api('POST', `/appointments/${apptId}/pay`, { token: people.pat, body: { phone: '90123456', provider: 'Flooz' } });
  assert.equal(ok.data.status, 'paid');
  assert.equal((await api('POST', `/appointments/${apptId}/pay`, { token: people.pat, body: { phone: '90123456' } })).status, 400);
  const c2 = makeClient(await loadApi(), { ...env, REQUIRE_PAYMENT: '1' });
  assert.equal((await c2('POST', `/appointments/${apptId}/room`, { token: people.pat })).status, 200);
});

test('paiement hors sandbox : 503 sans fournisseur, PayGate simulé, webhook vérifié auprès de l\'opérateur', async () => {
  const mk = async (ref) => (await db.query(`insert into appointments(patient_id,doctor_id,starts_at,amount) values($1,$2,now() + interval '9 days',7000) returning id`, [people.patId, people.docId])).rows[0].id;
  const id = await mk();
  const noProv = makeClient(await loadApi(), { ...env, PAY_SANDBOX: '0' });
  assert.equal((await noProv('POST', `/appointments/${id}/pay`, { token: people.pat, body: { phone: '90123456' } })).status, 503);

  const calls = [];
  const prev = globalThis.fetch;
  let payStatus = 0, checkStatus = 0;
  globalThis.fetch = async (u, o) => {
    if (String(u).includes('paygateglobal.com/api/v1/pay')) { calls.push(JSON.parse(o.body)); return new Response(JSON.stringify({ status: payStatus }), { status: 200 }); }
    if (String(u).includes('paygateglobal.com/api/v2/status')) return new Response(JSON.stringify({ status: checkStatus }), { status: 200 });
    return prev(u, o);
  };
  try {
    const live = makeClient(await loadApi(), { ...env, PAY_SANDBOX: '0', PAYGATE_TOKEN: 'tok', PAY_WEBHOOK_SECRET: '' });
    payStatus = 4;
    assert.equal((await live('POST', `/appointments/${id}/pay`, { token: people.pat, body: { phone: '90123456' } })).status, 502);
    payStatus = 0;
    const r = await live('POST', `/appointments/${id}/pay`, { token: people.pat, body: { phone: '+228 90 12 34 56', provider: 'Flooz' } });
    assert.equal(r.status, 200, JSON.stringify(r.data));
    assert.equal(r.data.status, 'pending');
    assert.equal(calls.at(-1).network, 'FLOOZ');
    assert.equal(calls.at(-1).phone_number, '90123456');
    assert.equal(calls.at(-1).amount, 7000);
    assert.equal(calls.at(-1).identifier, r.data.ref);
    // Webhook sans secret : l'opérateur doit confirmer.
    checkStatus = 2;
    assert.equal((await live('POST', '/payments/webhook', { body: { identifier: r.data.ref } })).status, 200);
    assert.equal((await db.query('select payment_status from appointments where id=$1', [id])).rows[0].payment_status, 'pending');
    checkStatus = 0;
    assert.equal((await live('POST', '/payments/webhook', { body: { identifier: r.data.ref, amount: 7000 } })).status, 200);
    assert.equal((await db.query('select payment_status from appointments where id=$1', [id])).rows[0].payment_status, 'paid');
    // Webhook forgé pour une autre référence : rien ne change.
    assert.equal((await live('POST', '/payments/webhook', { body: { identifier: 'inconnue' } })).status, 404);
  } finally { globalThis.fetch = prev; }
});

test('webhook : secret invalide 403, montant incohérent 400, succès idempotent', async () => {
  await db.query(`insert into appointments(patient_id,doctor_id,starts_at,amount,payment_status,payment_ref) values($1,$2,now() + interval '3 days',5000,'pending','ref-123')`, [people.patId, people.docId]);
  const noKey = await makeClient(await loadApi(), { ...env, PAYGATE_TOKEN: undefined })('POST', '/payments/webhook', { body: { ref: 'ref-123', status: 'success', secret: 'mauvais' } });
  assert.equal(noKey.status, 403);
  assert.equal((await api('POST', '/payments/webhook', { body: { ref: 'ref-123', status: 'success', secret: 'whsec', amount: 1 } })).status, 400);
  assert.equal((await api('POST', '/payments/webhook', { body: { ref: 'ref-123', status: 'success', secret: 'whsec', amount: 5000 } })).status, 200);
  assert.equal((await db.query(`select payment_status from appointments where payment_ref='ref-123'`)).rows[0].payment_status, 'paid');
  assert.equal((await api('POST', '/payments/webhook', { headers: { 'x-webhook-secret': 'whsec' }, body: { ref: 'ref-123', status: 'failed' } })).status, 200);
  assert.equal((await db.query(`select payment_status from appointments where payment_ref='ref-123'`)).rows[0].payment_status, 'paid', 'un paiement confirmé ne régresse pas');
});

test('annulation d\'un rendez-vous payé : remboursement dû, admin le traite', async () => {
  const r = await api('POST', `/appointments/${apptId}/status`, { token: people.pat, body: { status: 'cancelled' } });
  assert.equal(r.status, 200);
  assert.equal((await db.query('select payment_status from appointments where id=$1', [apptId])).rows[0].payment_status, 'refund_due');
  const list = await api('GET', '/admin/refunds', { token: people.adm });
  assert.equal(list.status, 200);
  assert.ok(list.data.some((x) => x.id === apptId && x.payment_status === 'refund_due'));
  const st = await api('GET', '/admin/stats', { token: people.adm });
  assert.ok(st.data.refunds_due >= 1);
  assert.equal((await api('POST', `/admin/refunds/${apptId}/done`, { token: people.adm })).status, 200);
  assert.equal((await api('POST', `/admin/refunds/${apptId}/done`, { token: people.adm })).status, 404);
  assert.equal((await api('GET', '/admin/refunds', { token: people.pat })).status, 403);
  const aud = await api('GET', '/admin/audit', { token: people.adm });
  assert.ok(aud.data.some((x) => x.action === 'refund_done'));
});

test('avis : uniquement après consultation, une seule fois, note moyenne', async () => {
  const d = tomorrow();
  const sl = (await api('GET', `/doctors/${people.docId}/slots?date=${d.toISOString().slice(0, 10)}`, { token: people.pat })).data.slots;
  const b = await api('POST', '/appointments', { token: people.pat, body: { doctor_id: people.docId, starts_at: sl[sl.length - 1] } });
  const id = b.data.id;
  assert.equal((await api('POST', `/appointments/${id}/review`, { token: people.pat, body: { rating: 5 } })).status, 400);
  await api('POST', `/appointments/${id}/status`, { token: people.doc, body: { status: 'done' } });
  assert.equal((await api('POST', `/appointments/${id}/review`, { token: people.pat, body: { rating: 9 } })).status, 400);
  assert.equal((await api('POST', `/appointments/${id}/review`, { token: people.pat, body: { rating: 4, comment: 'Très bien' } })).status, 200);
  assert.equal((await api('POST', `/appointments/${id}/review`, { token: people.pat, body: { rating: 5 } })).status, 409);
  const docs = await api('GET', '/doctors', { token: people.pat });
  const me = docs.data.find((x) => x.id === people.docId);
  assert.equal(me.rating, 4);
  assert.equal(me.review_count, 1);
  const rv = await api('GET', `/doctors/${people.docId}/reviews`, { token: people.pat });
  assert.equal(rv.data[0].comment, 'Très bien');
  const mine = await api('GET', '/appointments', { token: people.pat });
  assert.ok(mine.data.find((x) => x.id === id).reviewed);
  people.doneAppt = id;
});

test('messagerie : chiffrée en base, lisible via l\'API', async () => {
  const id = people.doneAppt;
  assert.equal((await api('POST', `/appointments/${id}/messages`, { token: people.pat, body: { content: 'Bonjour docteur' } })).status, 200);
  const raw = (await db.query('select content from appointment_messages where appointment_id=$1', [id])).rows[0].content;
  assert.ok(raw.startsWith('enc1:'));
  assert.ok(!raw.includes('Bonjour'));
  const got = await api('GET', `/appointments/${id}/messages`, { token: people.doc });
  assert.equal(got.data[0].content, 'Bonjour docteur');
});

test('documents : dépôt, chiffrement, accès patient, médecin lié, tiers refusé', async () => {
  const png = 'data:image/png;base64,iVBORw0KGgo=';
  assert.equal((await api('POST', '/me/documents', { token: people.pat, body: { name: 'x', file: 'data:text/html;base64,AAAA' } })).status, 400);
  assert.equal((await api('POST', '/me/documents', { token: people.pat, body: { name: 'x', file: 'data:image/png;base64,' + 'A'.repeat(1600000) } })).status, 400);
  const up = await api('POST', '/me/documents', { token: people.pat, body: { name: 'Analyse sang.png', file: png } });
  assert.equal(up.status, 200, JSON.stringify(up.data));
  const raw = (await db.query('select data from patient_documents where id=$1', [up.data.id])).rows[0].data;
  assert.ok(raw.startsWith('enc1:'));
  const list = await api('GET', '/me/documents', { token: people.pat });
  assert.equal(list.data.length, 1);
  assert.ok(!('data' in list.data[0]));
  const dl = await api('GET', `/documents/${up.data.id}`, { token: people.pat });
  assert.equal(dl.status, 200);
  assert.equal(dl.headers.get('content-type'), 'image/png');
  assert.equal(dl.headers.get('x-content-type-options'), 'nosniff');
  assert.deepEqual([...dl.data.subarray(0, 4)], [0x89, 0x50, 0x4e, 0x47]);
  assert.equal((await api('GET', `/documents/${up.data.id}`, { token: people.doc })).status, 200);
  assert.equal((await api('GET', `/doctor/patients/${people.patId}/documents`, { token: people.doc })).data.length, 1);
  const stranger = await signup('patient', 'stranger@test.tg');
  assert.equal((await api('GET', `/documents/${up.data.id}`, { token: stranger })).status, 403);
  assert.equal((await api('POST', `/me/documents/${up.data.id}/delete`, { token: stranger })).status, 200);
  assert.equal((await api('GET', '/me/documents', { token: people.pat })).data.length, 1, 'un tiers ne supprime pas le document');
  assert.equal((await api('POST', `/me/documents/${up.data.id}/delete`, { token: people.pat })).status, 200);
});

test('notifications : compteur non lus puis lecture', async () => {
  const u = await api('GET', '/me/unread', { token: people.doc });
  assert.ok(u.data.notifications > 0);
  await api('POST', '/me/notifications/read', { token: people.doc });
  assert.equal((await api('GET', '/me/unread', { token: people.doc })).data.notifications, 0);
});

test('rappels : secret requis, une seule fois par rendez-vous', async () => {
  await db.query(`insert into appointments(patient_id,doctor_id,starts_at,amount) values($1,$2,now() + interval '5 hours',5000)`, [people.patId, people.docId]);
  assert.equal((await api('POST', '/cron/reminders', { headers: { 'x-cron-secret': 'faux' } })).status, 403);
  assert.equal((await api('POST', '/cron/reminders')).status, 403);
  const r1 = await api('POST', '/cron/reminders', { headers: { 'x-cron-secret': 'cron' } });
  assert.equal(r1.status, 200);
  assert.ok(r1.data.reminded >= 1);
  const r2 = await api('POST', '/cron/reminders', { headers: { 'x-cron-secret': 'cron' } });
  assert.equal(r2.data.reminded, 0);
});

test('mot de passe oublié : email, jeton à usage unique, sessions révoquées', async () => {
  mails.length = 0;
  const f = await api('POST', '/auth/forgot', { body: { email: 'pat@test.tg' } });
  assert.equal(f.status, 200);
  const mail = mails.find((m) => m.subject.includes('Réinitialisation'));
  assert.ok(mail, 'email de réinitialisation');
  const tok = /reset=([A-Za-z0-9_-]+)/.exec(mail.html)[1];
  const unknown = await api('POST', '/auth/forgot', { body: { email: 'inconnu@test.tg' } });
  assert.equal(unknown.status, 200, 'réponse identique pour un email inconnu');
  assert.equal((await api('POST', '/auth/reset', { body: { token: 'faux', password: 'Nouveau123!' } })).status, 400);
  assert.equal((await api('POST', '/auth/reset', { body: { token: tok, password: 'court' } })).status, 400);
  assert.equal((await api('POST', '/auth/reset', { body: { token: tok, password: 'Nouveau123!' } })).status, 200);
  assert.equal((await api('POST', '/auth/reset', { body: { token: tok, password: 'Autre12345!' } })).status, 400, 'jeton à usage unique');
  assert.equal((await api('GET', '/me', { token: people.pat })).status, 401, 'ancienne session révoquée');
  const l = await api('POST', '/auth/login', { body: { email: 'pat@test.tg', password: 'Nouveau123!' } });
  assert.equal(l.status, 200);
  people.pat = l.data.token;
});

test('mot de passe oublié : expiré après 1 h', async () => {
  mails.length = 0;
  await api('POST', '/auth/forgot', { body: { email: 'doc@test.tg' } });
  const tok = /reset=([A-Za-z0-9_-]+)/.exec(mails.at(-1).html)[1];
  await db.query(`update password_resets set expires_at = now() - interval '1 minute'`);
  assert.equal((await api('POST', '/auth/reset', { body: { token: tok, password: 'Nouveau123!' } })).status, 400);
});

test('changement de mot de passe : nouveau jeton, ancien invalide ; logout-all', async () => {
  const old = people.pat;
  const r = await api('POST', '/me/password', { token: old, body: { current: 'Nouveau123!', next: 'Encore12345!' } });
  assert.equal(r.status, 200);
  assert.ok(r.data.token);
  assert.equal((await api('GET', '/me', { token: old })).status, 401);
  assert.equal((await api('GET', '/me', { token: r.data.token })).status, 200);
  assert.equal((await api('POST', '/auth/logout-all', { token: r.data.token })).status, 200);
  assert.equal((await api('GET', '/me', { token: r.data.token })).status, 401);
  const l = await api('POST', '/auth/login', { body: { email: 'pat@test.tg', password: 'Encore12345!' } });
  people.pat = l.data.token;
});

test('export des données : contient comptes, rendez-vous, sans secrets', async () => {
  const r = await api('GET', '/me/export', { token: people.pat });
  assert.equal(r.status, 200);
  assert.equal(r.data.account.email, 'pat@test.tg');
  assert.ok(r.data.appointments.length >= 2);
  assert.ok(r.data.messages_sent.some((m) => m.content === 'Bonjour docteur'));
  assert.ok(!JSON.stringify(r.data).includes('password_hash'));
  assert.ok(!JSON.stringify(r.data).includes('totp_secret'));
});

test('suppression de compte : mot de passe exigé, anonymisation, accès coupé', async () => {
  assert.equal((await api('POST', '/me/delete', { token: people.pat, body: { password: 'faux' } })).status, 401);
  assert.equal((await api('POST', '/me/delete', { token: people.adm, body: { password: 'Test1234!' } })).status, 403);
  const before = (await db.query(`select count(*)::int c from appointments where patient_id=$1 and status='scheduled'`, [people.patId])).rows[0].c;
  assert.ok(before >= 1);
  assert.equal((await api('POST', '/me/delete', { token: people.pat, body: { password: 'Encore12345!' } })).status, 200);
  const u = (await db.query('select email, full_name, status, phone from users where id=$1', [people.patId])).rows[0];
  assert.equal(u.status, 'deleted');
  assert.equal(u.full_name, 'Compte supprimé');
  assert.ok(u.email.endsWith('@deleted.invalid'));
  assert.equal(u.phone, null);
  assert.equal((await api('GET', '/me', { token: people.pat })).status, 401);
  assert.equal((await api('POST', '/auth/login', { body: { email: 'pat@test.tg', password: 'Encore12345!' } })).status, 401);
  const after = (await db.query(`select count(*)::int c from appointments where patient_id=$1 and status='scheduled'`, [people.patId])).rows[0].c;
  assert.equal(after, 0, 'rendez-vous à venir annulés');
  const msg = (await db.query(`select content from appointment_messages where sender_id=$1`, [people.patId])).rows[0];
  assert.equal(msg.content, '[message supprimé]');
  const n = await api('GET', '/me/notifications', { token: people.doc });
  assert.ok(n.data.some((x) => x.title === 'Rendez-vous annulé'));
});

test('flux existants non cassés : ordonnance, commande, signature', async () => {
  const pat2 = await signup('patient', 'pat2@test.tg');
  const ph = await signup('pharmacy', 'ph@test.tg', { pharmacy_name: 'Pharma', license_number: 'L1' });
  await db.query(`update users set status='active' where email='ph@test.tg'`);
  const pid = (await db.query(`select id from users where email='ph@test.tg'`)).rows[0].id;
  await db.query(`insert into pharmacy_stock(pharmacy_id,name,quantity,price) values($1,'Paracétamol',10,500)`, [pid]);
  const d = tomorrow();
  const sl = (await api('GET', `/doctors/${people.docId}/slots?date=${d.toISOString().slice(0, 10)}`, { token: pat2 })).data.slots;
  const ap = await api('POST', '/appointments', { token: pat2, body: { doctor_id: people.docId, starts_at: sl[0] } });
  const rx = await api('POST', '/prescriptions', { token: people.doc, body: { appointment_id: ap.data.id, items: [{ name: 'Paracétamol', dosage: '1g', duration: '3 j' }] } });
  assert.equal(rx.status, 200, JSON.stringify(rx.data));
  assert.equal((await api('GET', `/verify/${rx.data.code}`)).data.valid, true);
  const rxs = await api('GET', '/prescriptions', { token: pat2 });
  const order = await api('POST', '/orders', { token: pat2, body: { prescription_id: rxs.data[0].id, pharmacy_id: pid } });
  assert.equal(order.status, 200, JSON.stringify(order.data));
  const pay = await api('POST', `/orders/${order.data.id}/pay`, { token: pat2, body: { phone: '90123456' } });
  assert.equal(pay.data.status, 'paid');
  await api('POST', `/orders/${order.data.id}/status`, { token: ph, body: { status: 'ready' } });
  const notes = await api('GET', '/me/notifications', { token: pat2 });
  assert.ok(notes.data.some((x) => x.title === 'Nouvelle ordonnance'));
  assert.ok(notes.data.some((x) => x.title === 'Commande prête'));
});
