
const express = require('express');
const router = express.Router();
const Dream = require('../models/Dream');
const ForumPost = require('../models/ForumPost');
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

    const allowedFields = [
      'title', 'date', 'mood', 'tags', 'people', 'place',
      'clarity', 'notes', 'isRecurring', 'wokeUp', 'dreamInfo', 'isShared',
    ];
    const updateData = {};
    allowedFields.forEach((field) => {
      if (req.body[field] !== undefined) {
        updateData[field] = req.body[field];
      }
    });

    const updatedDream = await Dream.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true, runValidators: true },
    );

    // Mantener sincronizado el post compartido del foro al editar el dream.
    if (updatedDream.isShared) {
      const forumUpdateFields = {};
      allowedFields
        .filter((field) => field !== 'isShared')
        .forEach((field) => {
          if (updateData[field] !== undefined) {
            forumUpdateFields[field] = updateData[field];
          }
        });

      if (Object.keys(forumUpdateFields).length > 0) {
        await ForumPost.findOneAndUpdate(
          { dreamId: updatedDream._id.toString(), userId: req.userId },
          forumUpdateFields,
          { runValidators: true },
        );
      }
    }

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
