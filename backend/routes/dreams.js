
const express = require('express');
const router = express.Router();
const Dream = require('../models/Dream');
const auth = require('../middleware/auth');

// Obtener todos los sueños del usuario autenticado
router.get('/', auth, async (req, res) => {
  try {
    const dreams = await Dream.find({ userId: req.userId });
    res.json(dreams);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener los sueños' });
  }
});

// Crear un nuevo sueño (requiere autenticación)
router.post('/', auth, async (req, res) => {
  try {
    const dreamData = { ...req.body, userId: req.userId };
    const dream = new Dream(dreamData);
    await dream.save();
    res.status(201).json(dream);
  } catch (err) {
    console.error('Error al crear el sueño:', err);
    res.status(400).json({ error: 'Error al crear el sueño', details: err.message });
  }
});

// Actualizar un sueño
router.put('/:id', auth, async (req, res) => {
  try {
    const dream = await Dream.findById(req.params.id);
    if (!dream) return res.status(404).json({ error: 'Sueño no encontrado' });
    if (dream.userId.toString() !== req.userId) return res.status(403).json({ error: 'No autorizado' });
    const updatedDream = await Dream.findByIdAndUpdate(req.params.id, req.body, { new: true });
    res.json(updatedDream);
  } catch (err) {
    res.status(400).json({ error: 'Error al actualizar el sueño' });
  }
});

// Eliminar un sueño
router.delete('/:id', auth, async (req, res) => {
  try {
    const dream = await Dream.findById(req.params.id);
    if (!dream) return res.status(404).json({ error: 'Sueño no encontrado' });
    if (dream.userId.toString() !== req.userId) return res.status(403).json({ error: 'No autorizado' });
    await Dream.findByIdAndDelete(req.params.id);
    res.json({ message: 'Sueño eliminado' });
  } catch (err) {
    res.status(400).json({ error: 'Error al eliminar el sueño' });
  }
});

module.exports = router;
