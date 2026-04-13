const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const nodemailer = require('nodemailer');
const User = require('../models/User');
const VerificationToken = require('../models/VerificationToken');
const router = express.Router();

// Configurar nodemailer
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASSWORD
  },
  tls: {
    rejectUnauthorized: false
  }
});

// Función para generar código de verificación de 6 dígitos
function generateVerificationCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Función para enviar email de verificación con código
async function sendVerificationEmail(email, code, username) {
  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: email,
    subject: 'Código de verificación - Diario de Sueños',
    html: `
      <h2>¡Bienvenido a Diario de Sueños!</h2>
      <p>Hola ${username},</p>
      <p>Para completar tu registro, usa el siguiente código de verificación:</p>
      <p style="font-size: 32px; font-weight: bold; color: #8e2de2; letter-spacing: 5px; text-align: center;">
        ${code}
      </p>
      <p>Este código expira en 15 minutos.</p>
      <p>Si no solicitaste esta cuenta, ignora este email.</p>
    `
  };
  
  return transporter.sendMail(mailOptions);
}

router.post('/register', async (req, res) => {
  const { email, password, username } = req.body;
  try {
    // Verificar que no exista un usuario con ese email o username
    if (await User.findOne({ email })) return res.status(400).json({ error: 'Email ya registrado' });
    if (await User.findOne({ username })) return res.status(400).json({ error: 'Nombre de usuario ya registrado' });
    
    // Verificar que no haya un registro de verificación pendiente con ese email
    const existingRecord = await VerificationToken.findOne({ email });
    if (existingRecord) {
      await VerificationToken.deleteOne({ _id: existingRecord._id });
    }
    
    // Generar código de verificación
    const verificationCode = generateVerificationCode();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutos
    
    // Guardar los datos temporalmente (NO crear usuario aún)
    const tokenRecord = new VerificationToken({
      email,
      password,
      username,
      code: verificationCode,
      expiresAt
    });
    await tokenRecord.save();
    
    // Enviar email de verificación
    try {
      await sendVerificationEmail(email, verificationCode, username);
    } catch (emailError) {
      console.error('Error al enviar email:', emailError);
      await VerificationToken.deleteOne({ code: verificationCode });
      return res.status(500).json({ 
        error: 'No se pudo enviar el email de verificación. Intenta más tarde.'
      });
    }
    
    res.status(201).json({ 
      message: 'Se envió un código de verificación a tu correo. Introdúcelo en la app para completar el registro.',
      requiresVerification: true
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

// Ruta para verificar código
router.post('/verify-code', async (req, res) => {
  try {
    const { email, code } = req.body;
    if (!email || !code) {
      return res.status(400).json({ error: 'Email y código requeridos' });
    }

    // Buscar el registro de verificación
    const verificationRecord = await VerificationToken.findOne({
      email: email,
      code: code,
      expiresAt: { $gt: Date.now() }
    });

    if (!verificationRecord) {
      return res.status(400).json({ error: 'Código inválido o expirado' });
    }

    // Crear el usuario finalmente
    const user = new User({
      email: verificationRecord.email,
      password: verificationRecord.password,
      username: verificationRecord.username,
      emailVerified: true
    });
    
    await user.save();
    
    // Eliminar el registro de verificación
    await VerificationToken.deleteOne({ _id: verificationRecord._id });

    res.json({ 
      message: 'Email verificado correctamente. Tu cuenta ha sido creada. Ahora puedes iniciar sesión.',
      verified: true
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

// Ruta para reenviar código de verificación
router.post('/resend-verification', async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: 'Email requerido' });
    }

    // Verificar si el email ya está registrado y verificado
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ error: 'Este email ya está registrado y verificado' });
    }

    // Buscar el registro de verificación pendiente
    const verificationRecord = await VerificationToken.findOne({ email });
    if (!verificationRecord) {
      return res.status(404).json({ error: 'No hay un registro pendiente de verificación para este email' });
    }

    // Generar nuevo código
    const verificationCode = generateVerificationCode();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutos

    verificationRecord.code = verificationCode;
    verificationRecord.expiresAt = expiresAt;
    await verificationRecord.save();

    // Enviar email
    await sendVerificationEmail(email, verificationCode, verificationRecord.username);

    res.json({ message: 'Código de verificación reenviado' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const user = await User.findOne({ email });
    if (!user || !(await bcrypt.compare(password, user.password)))
      return res.status(400).json({ error: 'Credenciales incorrectas' });
    
    // Verificar si el email está verificado
    if (!user.emailVerified) {
      return res.status(403).json({ error: 'Por favor verifica tu email antes de iniciar sesión', requiresVerification: true });
    }
    
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '1d' });
    res.json({ token, userId: user._id });
  } catch (err) {
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

module.exports = router;
