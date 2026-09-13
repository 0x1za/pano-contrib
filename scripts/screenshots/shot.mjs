// Drives the installed Chrome through puppeteer-core to retake the README
// screenshots from a running dev server. Usage: node shot.mjs BASE OUTDIR [EMAIL PASSWORD SURVEY_ID]
// The signed-in shots (mine, review, survey) need a moderator's email and password.
import puppeteer from 'puppeteer-core';
const [base, out, email, password, surveyId] = process.argv.slice(2);
const chrome = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const browser = await puppeteer.launch({ executablePath: chrome, headless: 'new', args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--hide-scrollbars'] });
const sleep = ms => new Promise(r => setTimeout(r, ms));
const settle = async page => { await sleep(3500); await page.evaluate(() => new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)))); };

const open = async (w, h) => {
  const page = await browser.newPage();
  await page.setViewport({ width: w, height: h, deviceScaleFactor: 2 });
  await page.evaluateOnNewDocument(() => { try { localStorage.setItem('pano.welcomed', '1'); localStorage.setItem('pano.basemap', 'map'); } catch {} });
  return page;
};
const shoot = async (page, name) => { await page.screenshot({ path: `${out}/${name}.png` }); console.log('wrote', name); };
const search = async (page, q) => {
  await page.evaluate(q => { const i = document.querySelector('input[name=q]'); i.value = q; i.form.requestSubmit(); }, q);
  await sleep(2500);
};
const signIn = async page => {
  await page.goto(`${base}/session/new`, { waitUntil: 'networkidle0' });
  await page.type('#email_address', email); await page.type('#password', password);
  await Promise.all([page.waitForNavigation({ waitUntil: 'networkidle0' }), page.click('input[type=submit]')]);
};

// 1. The map, desktop, city zoom.
let page = await open(1440, 900);
await page.goto(`${base}/`, { waitUntil: 'networkidle0', timeout: 60000 });
await settle(page);
await shoot(page, 'map');

// 2. An address card, then "I live here" in the side panel.
await search(page, 'LS1 1JC 2');
await settle(page);
await shoot(page, 'address');
await page.evaluate(() => document.querySelector('.maplibregl-popup a.btn')?.click());
await sleep(2500);
await shoot(page, 'panel');
await page.close();

// 3. The same on a phone: card, then the form as a bottom sheet.
page = await open(430, 932);
await page.goto(`${base}/`, { waitUntil: 'networkidle0', timeout: 60000 });
await settle(page);
await search(page, 'LS1 1JC 2');
await settle(page);
await shoot(page, 'phone-address');
await page.evaluate(() => document.querySelector('.maplibregl-popup a.btn')?.click());
await sleep(2500);
await shoot(page, 'phone-form');
await page.close();

if (email) {
  // 4. Your own contributions: pins on the map, the list in the panel.
  page = await open(1440, 900);
  await signIn(page);
  await page.goto(`${base}/`, { waitUntil: 'networkidle0', timeout: 60000 });
  await settle(page);
  await search(page, 'LS1 1JC');
  await settle(page);
  await page.evaluate(() => document.querySelector('.maplibregl-popup-close-button')?.click());
  await page.evaluate(() => document.querySelector('a.who')?.click());
  await sleep(2500);
  await shoot(page, 'mine');

  // 5. The review queue.
  await page.goto(`${base}/review`, { waitUntil: 'networkidle0' });
  await settle(page);
  await shoot(page, 'review');

  // 6. A field survey on a phone.
  if (surveyId) {
    const phone = await open(430, 932); // same browser context, so already signed in
    await phone.goto(`${base}/surveys/${surveyId}`, { waitUntil: 'networkidle0' });
    await sleep(1000);
    await phone.screenshot({ path: `${out}/survey.png`, fullPage: false }); console.log('wrote survey');
    await phone.close();
  }
  await page.close();
}
await browser.close();
