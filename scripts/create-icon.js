const fs = require('fs');
const path = require('path');
const { Resvg } = require('@resvg/resvg-js');

const assetsDir = path.join(__dirname, '..', 'assets');
const svgPath = path.join(assetsDir, 'grafana_icon.svg');

fs.mkdirSync(assetsDir, { recursive: true });

if (!fs.existsSync(svgPath)) {
  throw new Error('Missing assets/grafana_icon.svg');
}

function toBlackTemplateSvg(buffer) {
  return buffer
    .toString()
    .replace(/<style[\s\S]*?<\/style>/, '')
    .replace(/<linearGradient[\s\S]*?<\/linearGradient>/g, '')
    .replace(/class="st0"/g, 'fill="#000000"');
}

const svg = Buffer.from(toBlackTemplateSvg(fs.readFileSync(svgPath)));

for (const size of [18, 36]) {
  const resvg = new Resvg(svg, {
    fitTo: { mode: 'width', value: size },
    background: 'transparent',
  });
  const png = resvg.render().asPng();
  const filename = size === 18 ? 'iconTemplate.png' : 'iconTemplate@2x.png';
  fs.writeFileSync(path.join(assetsDir, filename), png);
}
