const express = require('express');
const User = require('../models/User');
const Dream = require('../models/Dream');
const router = express.Router();

// GET /api/users - Get all users
router.get('/', async (req, res) => {
  try {
    const users = await User.find().select('_id username createdAt');
    
    // Contar sueños compartidos para cada usuario
    const usersWithDreamCount = await Promise.all(
      users.map(async (user) => {
        const dreamCount = await Dream.countDocuments({
          userId: user._id,
          isShared: true
        });
        return {
          _id: user._id,
          username: user.username,
          createdAt: user.createdAt,
          sharedDreamsCount: dreamCount
        };
      })
    );
    
    res.json(usersWithDreamCount);
  } catch (err) {
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

// GET /api/users/:userId - Get user data by ID
router.get('/:userId', async (req, res) => {
  try {
    const user = await User.findById(req.params.userId).select('username createdAt');
    if (!user) return res.status(404).json({ error: 'Usuario no encontrado' });
    
    const dreamCount = await Dream.countDocuments({
      userId: user._id,
      isShared: true
    });
    
    res.json({
      ...user.toObject(),
      sharedDreamsCount: dreamCount
    });
  } catch (err) {
    res.status(500).json({ error: 'Error en el servidor' });
  }
});

module.exports = router;
