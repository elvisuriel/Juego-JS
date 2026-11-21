// Copia el juego web a www/ para que Capacitor lo empaquete
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const out = path.join(root, 'www');

fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out);
for (const item of ['index.html', 'manifest.webmanifest', 'icon.png', 'src', 'assets']) {
  const from = path.join(root, item);
  if (fs.existsSync(from)) fs.cpSync(from, path.join(out, item), { recursive: true });
}
console.log('Juego copiado a www/');
