const path = require('path');
const fs = require('fs');

// Safely load server/.env into process.env if present without overriding pre-set system environment variables
const envPath = path.join(__dirname, '..', '..', '.env');
if (fs.existsSync(envPath)) {
  try {
    const content = fs.readFileSync(envPath, 'utf8');
    const lines = content.split(/\r?\n/);
    let currentKey = null;
    let currentValue = null;
    let inMultiLine = false;

    for (const line of lines) {
      if (!inMultiLine) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith('#')) continue;
        const eqIdx = trimmed.indexOf('=');
        if (eqIdx !== -1) {
          const key = trimmed.substring(0, eqIdx).trim();
          let val = trimmed.substring(eqIdx + 1).trim();
          // Strip trailing comma if pasted from JSON (e.g. "key": "value",)
          if (val.endsWith(',')) {
            val = val.slice(0, -1).trim();
          }
          if ((val.startsWith('"') && !val.endsWith('"')) || (val.startsWith("'") && !val.endsWith("'")) || val === '"' || val === "'") {
            currentKey = key;
            currentValue = val.slice(1);
            inMultiLine = true;
          } else {
            if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
              val = val.slice(1, -1);
            }
            if (key && process.env[key] === undefined) {
              process.env[key] = val;
            }
          }
        }
      } else {
        let lineVal = line.trim();
        if (lineVal.endsWith(',')) {
          lineVal = lineVal.slice(0, -1).trim();
        }
        if (lineVal.endsWith('"') || lineVal.endsWith("'")) {
          currentValue += '\n' + lineVal.slice(0, -1);
          if (currentKey && process.env[currentKey] === undefined) {
            process.env[currentKey] = currentValue;
          }
          currentKey = null;
          currentValue = null;
          inMultiLine = false;
        } else {
          currentValue += '\n' + line;
        }
      }
    }
  } catch (_) {
    // Non-fatal if .env cannot be read
  }
}

module.exports = {
  PORT: process.env.PORT || 4000,
  HOST: process.env.HOST || '0.0.0.0',
  DATA_DIR: process.env.DATA_DIR || path.join(__dirname, '..', '..', 'data_storage'),
  NODE_ENV: process.env.NODE_ENV || 'development',
  TOKEN_SECRET: process.env.TOKEN_SECRET || 'kith_secure_dev_secret_2026_deterministic',
};
