/**
 * Injects the assembled plan-view SVG into the main chart HTML file.
 *
 * Usage: npx ts-node src/plan-view/inject-html.ts
 */
import * as fs from 'fs';
import * as path from 'path';
import { assemblePlanView } from './assemble';

const outDir = path.join(__dirname, '..', '..', 'output');
const htmlPath = path.join(outDir, 'apa-ils35r-jep.html');

if (!fs.existsSync(htmlPath)) {
  console.error(`HTML file not found: ${htmlPath}`);
  process.exit(1);
}

const html = fs.readFileSync(htmlPath, 'utf-8');
const svg = assemblePlanView();

// Replace the plan-view container contents
const marker = 'id="plan-view-container">';
const idx = html.indexOf(marker);
if (idx < 0) {
  console.error('Could not find plan-view-container in HTML');
  process.exit(1);
}

const afterMarker = idx + marker.length;
const closingDiv = html.indexOf('</div>', afterMarker);
if (closingDiv < 0) {
  console.error('Could not find closing </div> for plan-view-container');
  process.exit(1);
}

const newHtml =
  html.substring(0, afterMarker) +
  '\n    ' + svg.replace(/\n/g, '\n    ') + '\n  ' +
  html.substring(closingDiv);

fs.writeFileSync(htmlPath, newHtml);
console.log(`Injected plan-view SVG into ${htmlPath}`);
console.log(`HTML size: ${(Buffer.byteLength(newHtml) / 1024).toFixed(1)} KB`);
