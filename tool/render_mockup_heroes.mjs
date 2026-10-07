// Xuất hình hero của mockup (v47, 06/10) ra WebP cho Flutter.
//
// SVG trong mockup dùng feTurbulence / feDisplacementMap / feGaussianBlur,
// flutter_svg không vẽ được, nên phải để Chrome vẽ rồi chụp lại.
//
// Ảnh xuất ra là phần vẽ GỐC, chưa có lớp mờ hai mép (mask-image trong CSS).
// Lớp mờ đó do widget Flutter tự phủ (WrHeroHeader / WrReflectBand), để đổi
// độ mờ không phải xuất lại ảnh.
//
// Chạy:
//   npm i --prefix <thư-mục-tạm> puppeteer-core
//   NODE_PATH=<thư-mục-tạm>/node_modules node tool/render_mockup_heroes.mjs \
//     ~/Desktop/FileTam/workreflection/WorkReflection_Mockup_v47.html
//
// Biến môi trường CHROME_PATH (mặc định /usr/bin/google-chrome).

import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const require = createRequire(import.meta.url);
const puppeteer = require('puppeteer-core');

const mockup = process.argv[2];
if (!mockup) {
  console.error('Thiếu đường dẫn tới file mockup HTML.');
  process.exit(1);
}
const outDir = resolve('assets/images/hero');
mkdirSync(outDir, { recursive: true });

// Tỉ lệ 3x: đủ nét trên máy @3x. WebP chất lượng 90 giữ gradient mịn;
// nén PNG xuống 256 màu thì trời bị vỡ thành từng vòng.
const SCALE = 3;
const QUALITY = 90;

const browser = await puppeteer.launch({
  executablePath: process.env.CHROME_PATH || '/usr/bin/google-chrome',
  headless: true,
  args: ['--no-sandbox'],
});
const page = await browser.newPage();
await page.goto(pathToFileURL(resolve(mockup)).href, { waitUntil: 'load' });

// Lấy chuỗi SVG ngay từ các hàm của mockup, không chép tay.
const jobs = await page.evaluate(() => {
  const out = [];
  for (const p of ['morning', 'afternoon', 'evening', 'latenight']) {
    // eslint-disable-next-line no-undef
    out.push({ name: `city_${p}`, svg: cityHero(p) });
  }
  for (const k of ['understand', 'act', 'grow']) {
    // eslint-disable-next-line no-undef
    out.push({ name: `inner_${k}`, svg: HERO_ART[k] });
  }
  for (const m of ['happy', 'ok', 'stress', 'tired', 'foggy', 'outofsync']) {
    // eslint-disable-next-line no-undef
    const html = reflectBand(m);
    out.push({ name: `band_${m}`, svg: html.replace(/^[\s\S]*?(<svg)/, '$1').replace(/<\/div>\s*$/, '') });
  }
  return out;
});

for (const { name, svg } of jobs) {
  const vb = /viewBox="0 0 (\d+) (\d+)"/.exec(svg);
  const [w, h] = [Number(vb[1]), Number(vb[2])];
  const shot = await browser.newPage();
  await shot.setViewport({ width: w, height: h, deviceScaleFactor: SCALE });
  // Vẽ đúng khung viewBox; cắt "slice" để widget Flutter lo (BoxFit.cover).
  const fixed = svg.replace(/preserveAspectRatio="[^"]*"/, 'preserveAspectRatio="none"');
  await shot.setContent(
    `<html><body style="margin:0;background:transparent">` +
      `<div style="width:${w}px;height:${h}px">${fixed.replace('<svg', `<svg width="${w}" height="${h}"`)}</div>` +
      `</body></html>`,
  );
  await shot.screenshot({
    path: `${outDir}/${name}.webp`,
    type: 'webp',
    quality: QUALITY,
    omitBackground: true,
    clip: { x: 0, y: 0, width: w, height: h },
  });
  await shot.close();
  console.log(`${name}.webp  ${w * SCALE}×${h * SCALE}`);
}

await browser.close();
