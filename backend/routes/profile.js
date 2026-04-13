const express = require('express');
const bcrypt = require('bcryptjs');
const nodemailer = require('nodemailer');
const User = require('../models/User');
const Dream = require('../models/Dream');
const VerificationToken = require('../models/VerificationToken');
const auth = require('../middleware/auth');
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

// Función para enviar email de verificación para eliminación de cuenta
async function sendDeleteAccountEmail(email, code, username) {
  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: email,
    subject: 'Código de verificación - Eliminación de cuenta',
    html: `
      <h2>Eliminación de Cuenta</h2>
      <p>Hola ${username},</p>
      <p>Para eliminar tu cuenta, usa el siguiente código de verificación:</p>
      <p style="font-size: 32px; font-weight: bold; color: #d32f2f; letter-spacing: 5px; text-align: center;">
        ${code}
      </p>
      <p>Este código expira en 15 minutos.</p>
      <p><strong>⚠️ ADVERTENCIA: Esta acción es irreversible. Se eliminarán todos tus datos.</strong></p>
      <p>Si no solicitaste este cambio, ignora este email.</p>
    `
  };
  
  return transporter.sendMail(mailOptions);
}

// Función para enviar email de verificación para cambio de contraseña
async function sendPasswordChangeEmail(email, code, username) {
  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: email,
    subject: 'Código de verificación - Cambio de contraseña',
    html: `
      <h2>Cambio de Contraseña</h2>
      <p>Hola ${username},</p>
      <p>Para cambiar tu contraseña, usa el siguiente código de verificación:</p>
      <p style="font-size: 32px; font-weight: bold; color: #8e2de2; letter-spacing: 5px; text-align: center;">
        ${code}
      </p>
      <p>Este código expira en 15 minutos.</p>
      <p>Si no solicitaste este cambio, ignora este email.</p>
    `
  };
  
  return transporter.sendMail(mailOptions);
}

// GET /api/profile
router.get('/', auth, async (req, res) => {
  try {
    const user = await User.findById(req.userId).select('username email createdAt');
    if (!user) return res.status(404).json({ error: 'Usuario no encontrado' });
    res.json({ username: user.username, email: user.email, createdAt: user.createdAt });
  } catch (err) {
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

// GET /api/profile/stats
router.get('/stats', auth, async (req, res) => {
  try {
    const dreams = await Dream.find({ userId: req.userId }).sort({ date: -1 });
    
    // Sueños totales
    const totalDreams = dreams.length;
    
    // Calcular racha de días
    let streakDays = 0;
    if (dreams.length > 0) {
      const uniqueDates = [...new Set(dreams.map(d => {
        const date = new Date(d.date);
        return date.toISOString().split('T')[0];
      }))];
      uniqueDates.sort().reverse();
      
      // Obtener las fechas
      const today = new Date();
      const todayDate = new Date(today.getFullYear(), today.getMonth(), today.getDate());
      const lastDreamDate = new Date(uniqueDates[0]);
      
      // Calcular diferencia en días
      const diffTime = todayDate - lastDreamDate;
      const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));
      
      // Si la diferencia es 0 (hoy) o 1 (ayer), la racha sigue activa
      // Si es 2 o más días, la racha se resetea
      if (diffDays > 1) {
        streakDays = 0;
      } else {
        // Contar días consecutivos desde el último sueño
        let currentStreak = 1;
        for (let i = 1; i < uniqueDates.length; i++) {
          const prevDate = new Date(uniqueDates[i - 1]);
          const currDate = new Date(uniqueDates[i]);
          const diffTime = prevDate - currDate;
          const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));
          
          if (diffDays === 1) { // Exactamente 1 día de diferencia
            currentStreak++;
          } else {
            break;
          }
        }
        streakDays = currentStreak;
      }
    }
    
    // Contar sueños por etiqueta
    const tagCounts = {};
    dreams.forEach(dream => {
      if (dream.tags && Array.isArray(dream.tags)) {
        dream.tags.forEach(tag => {
          tagCounts[tag] = (tagCounts[tag] || 0) + 1;
        });
      }
    });
    
    // Calcular porcentaje de sueños recurrentes
    const recurringDreams = dreams.filter(dream => dream.isRecurring).length;
    const recurringPercentage = totalDreams > 0 ? (recurringDreams / totalDreams) * 100 : 0;
    
    // Calcular porcentaje de sueños donde se despertó
    const wokeUpDreams = dreams.filter(dream => dream.wokeUp).length;
    const wokeUpPercentage = totalDreams > 0 ? (wokeUpDreams / totalDreams) * 100 : 0;
    
    // Calcular claridad promedio
    const claritySum = dreams.reduce((sum, dream) => sum + (dream.clarity || 0), 0);
    const averageClarity = totalDreams > 0 ? claritySum / totalDreams : 0;
    
    res.json({
      totalDreams,
      streakDays,
      tagCounts,
      recurringPercentage,
      wokeUpPercentage,
      averageClarity
    });
  } catch (err) {
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

// PUT /api/profile/change-password - Change password (MUST BE BEFORE PUT /)
router.put('/change-password', auth, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Se requiere la contraseña actual y nueva' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'La contraseña debe tener al menos 6 caracteres' });
    }

    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    // Verificar contraseña actual
    const isMatch = await bcrypt.compare(currentPassword, user.password);
    if (!isMatch) {
      return res.status(400).json({ error: 'La contraseña actual es incorrecta' });
    }

    // Hash de la nueva contraseña
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    // Usar findByIdAndUpdate para evitar validación de todos los campos
    await User.findByIdAndUpdate(
      req.userId,
      { password: hashedPassword },
      { new: true }
    );

    res.json({ message: 'Contraseña actualizada correctamente' });
  } catch (err) {
    console.error('Error al cambiar contraseña:', err);
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

// PUT /api/profile - Update username
router.put('/', auth, async (req, res) => {
  try {
    const { username } = req.body;
    if (!username) {
      return res.status(400).json({ error: 'El nombre de usuario es requerido' });
    }

    // Verificar si el nuevo username ya existe
    const existingUser = await User.findOne({ username: username });
    if (existingUser && existingUser._id.toString() !== req.userId) {
      return res.status(400).json({ error: 'El nombre de usuario ya está en uso' });
    }

    const user = await User.findByIdAndUpdate(
      req.userId,
      { username },
      { new: true }
    ).select('username email createdAt');

    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    res.json({ username: user.username, email: user.email, createdAt: user.createdAt });
  } catch (err) {
    console.error('Error al actualizar el perfil:', err);
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

// GET /api/users/:userId - Get user data by ID
router.get('/users/:userId', async (req, res) => {
  try {
    const user = await User.findById(req.params.userId).select('username email');
    if (!user) return res.status(404).json({ error: 'Usuario no encontrado' });
    res.json(user);
  } catch (err) {
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

// DELETE /api/profile - Delete account
router.delete('/', auth, async (req, res) => {
  try {
    const { password } = req.body;
    
    if (!password) {
      return res.status(400).json({ error: 'Se requiere la contraseña para eliminar la cuenta' });
    }

    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    // Verificar contraseña
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ error: 'La contraseña es incorrecta' });
    }

    // Eliminar todos los sueños del usuario
    await Dream.deleteMany({ userId: req.userId });

    // Eliminar el usuario
    await User.findByIdAndDelete(req.userId);

    res.json({ message: 'Cuenta eliminada correctamente' });
  } catch (err) {
    console.error('Error al eliminar cuenta:', err);
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

// POST /api/profile/send-password-change-code - Send verification code for password change
router.post('/send-password-change-code', auth, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    // Generar código de verificación
    const verificationCode = generateVerificationCode();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutos

    // Eliminar código anterior si existe
    await VerificationToken.deleteOne({ email: user.email });

    // Guardar el código
    const tokenRecord = new VerificationToken({
      email: user.email,
      password: '',
      username: user.username,
      code: verificationCode,
      expiresAt
    });
    await tokenRecord.save();

    // Enviar email de verificación
    try {
      await sendPasswordChangeEmail(user.email, verificationCode, user.username);
    } catch (emailError) {
      console.error('Error al enviar email:', emailError);
      await VerificationToken.deleteOne({ code: verificationCode });
      return res.status(500).json({ error: 'No se pudo enviar el email de verificación' });
    }

    res.json({ message: 'Se envió un código de verificación a tu correo' });
  } catch (err) {
    console.error('Error al enviar código:', err);
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

// POST /api/profile/verify-password-change-code - Verify code for password change
router.post('/verify-password-change-code', auth, async (req, res) => {
  try {
    const { code } = req.body;
    if (!code) {
      return res.status(400).json({ error: 'El código es requerido' });
    }

    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    // Buscar el token de verificación
    const token = await VerificationToken.findOne({ email: user.email, code });
    if (!token) {
      return res.status(400).json({ error: 'Código inválido' });
    }

    // Verificar que no haya expirado
    if (new Date() > token.expiresAt) {
      await VerificationToken.deleteOne({ _id: token._id });
      return res.status(400).json({ error: 'El código ha expirado' });
    }

    // Eliminar el token después de verificar
    await VerificationToken.deleteOne({ _id: token._id });

    res.json({ message: 'Código verificado correctamente' });
  } catch (err) {
    console.error('Error al verificar código:', err);
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

// POST /api/profile/send-delete-account-code - Send verification code for account deletion
router.post('/send-delete-account-code', auth, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    // Generar código de verificación
    const verificationCode = generateVerificationCode();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutos

    // Eliminar código anterior si existe
    await VerificationToken.deleteOne({ email: user.email });

    // Guardar el código
    const tokenRecord = new VerificationToken({
      email: user.email,
      username: user.username,
      code: verificationCode,
      expiresAt
    });
    await tokenRecord.save();

    // Enviar email de verificación
    try {
      await sendDeleteAccountEmail(user.email, verificationCode, user.username);
    } catch (emailError) {
      console.error('Error al enviar email:', emailError);
      await VerificationToken.deleteOne({ code: verificationCode });
      return res.status(500).json({ error: 'No se pudo enviar el email de verificación' });
    }

    res.json({ message: 'Se envió un código de verificación a tu correo' });
  } catch (err) {
    console.error('Error al enviar código:', err);
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

// POST /api/profile/verify-delete-account-code - Verify code for account deletion
router.post('/verify-delete-account-code', auth, async (req, res) => {
  try {
    const { code } = req.body;
    if (!code) {
      return res.status(400).json({ error: 'El código es requerido' });
    }

    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    // Buscar el token de verificación
    const token = await VerificationToken.findOne({ email: user.email, code });
    if (!token) {
      return res.status(400).json({ error: 'Código inválido' });
    }

    // Verificar que no haya expirado
    if (new Date() > token.expiresAt) {
      await VerificationToken.deleteOne({ _id: token._id });
      return res.status(400).json({ error: 'El código ha expirado' });
    }

    // Eliminar el token después de verificar
    await VerificationToken.deleteOne({ _id: token._id });

    res.json({ message: 'Código verificado correctamente' });
  } catch (err) {
    console.error('Error al verificar código:', err);
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

module.exports = router;
