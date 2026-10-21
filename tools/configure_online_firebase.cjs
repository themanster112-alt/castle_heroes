// Uses the existing Firebase CLI login without printing credentials.
const path = require('node:path');
const fs = require('node:fs');
const auth = require(path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib/auth.js'));
const project = 'castle-heroes-online-20261021';
(async () => {
  const account = auth.getGlobalDefaultAccount();
  if (!account) throw new Error('Run firebase login first');
  const token = await auth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform']);
  async function request(url, method, body) {
    const response = await fetch(url, {method, headers: {Authorization: `Bearer ${token.access_token}`, 'Content-Type': 'application/json'}, body: JSON.stringify(body)});
    const result = await response.json();
    if (!response.ok) throw new Error(`${response.status}: ${JSON.stringify(result.error || result)}`);
    return result;
  }
  await request(`https://serviceusage.googleapis.com/v1/projects/${project}/services/identitytoolkit.googleapis.com:enable`, 'POST', {});
  await request(`https://serviceusage.googleapis.com/v1/projects/${project}/services/firestore.googleapis.com:enable`, 'POST', {});
  // Initialize Authentication once in the Firebase console on the free Spark plan.
  await request(`https://identitytoolkit.googleapis.com/v2/projects/${project}/config?updateMask=signIn.anonymous.enabled`, 'PATCH', {signIn: {anonymous: {enabled: true}}});
  console.log('Anonymous sign-in enabled.');
})().catch(error => { console.error(error.message); process.exitCode = 1; });
