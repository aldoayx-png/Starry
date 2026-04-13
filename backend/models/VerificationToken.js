const mongoose = require('mongoose');

const VerificationTokenSchema = new mongoose.Schema({
  email: { type: String, required: true },
  password: { type: String, required: false },
  username: { type: String, required: true },
  code: { type: String, required: true }, // Código de 6 dígitos
  expiresAt: { type: Date, required: true },
  createdAt: { type: Date, default: Date.now, expires: 900 } // TTL de 15 minutos
});

module.exports = mongoose.model('VerificationToken', VerificationTokenSchema);
