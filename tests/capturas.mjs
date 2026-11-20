// Captura telas do app (build de emulador servido em 127.0.0.1:5050) para revisão visual.
// Uso: node capturas.mjs <pastaSaida> <conta> <rota> [<rota>...]  (prefixe a rota com "m:" para viewport mobile)
import { chromium } from 'playwright-core';

const [saida, conta, ...rotas] = process.argv.slice(2);
const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
const erros = [];
for (const r of rotas) {
  const mobile = r.startsWith('m:');
  const rota = mobile ? r.slice(2) : r;
  const ctx = await browser.newContext({ viewport: mobile ? { width: 390, height: 844 } : { width: 1366, height: 850 }, locale: 'pt-BR' });
  const page = await ctx.newPage();
  page.on('pageerror', (e) => erros.push(`${rota}: ${e.message}`));
  page.on('console', (m) => m.type() === 'error' && erros.push(`${rota}: ${m.text()}`));
  await page.goto(`http://127.0.0.1:5050/?demo=${conta}#/home`);
  await page.waitForTimeout(7000);
  await page.goto(`http://127.0.0.1:5050/?demo=${conta}#${rota}`);
  await page.waitForTimeout(4500);
  const nome = `${conta}_${(mobile ? 'm_' : '') + rota.replace(/[^a-z0-9]+/gi, '_')}.png`;
  await page.screenshot({ path: `${saida}/${nome}` });
  console.log(`${saida}/${nome}`);
  await ctx.close();
}
await browser.close();
if (erros.length) console.log('ERROS:\n' + erros.join('\n'));
