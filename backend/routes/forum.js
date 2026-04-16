const express = require('express');
const router = express.Router();
const ForumPost = require('../models/ForumPost');
const User = require('../models/User');
const auth = require('../middleware/auth');
const { optionalAuth } = require('../middleware/auth');

// Obtener todos los posts del foro
router.get('/posts', optionalAuth, async (req, res) => {
  try {
    let posts = await ForumPost.find()
      .populate('userId', 'username')
      .sort({ createdAt: -1 });
    
    // Si hay autenticación, agregar flag de si el usuario actual ha likeado
    if (req.userId) {
      posts = posts.map(post => {
        const postObj = post.toObject ? post.toObject() : post;
        postObj.userHasLiked = post.likedBy.some(id => id.toString() === req.userId);
        return postObj;
      });
    }
    
    res.json(posts);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener los posts del foro' });
  }
});

// Obtener un post específico
router.get('/posts/:id', async (req, res) => {
  try {
    const post = await ForumPost.findById(req.params.id)
      .populate('userId', 'username')
      .populate('comments.userId', 'username');
    if (!post) return res.status(404).json({ error: 'Post no encontrado' });
    res.json(post);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener el post' });
  }
});

// Crear un nuevo post en el foro (requiere autenticación)
router.post('/posts', auth, async (req, res) => {
  try {
    // Asegurar que dreamId se guarde si viene en req.body
    const postData = { 
      ...req.body, 
      userId: req.userId,
      dreamId: req.body.dreamId || null  // Explícitamente guardar dreamId
    };
    const post = new ForumPost(postData);
    await post.save();
    await post.populate('userId', 'username');
    console.log('✓ Nuevo post del foro creado:', { 
      postId: post._id, 
      dreamId: post.dreamId,
      title: post.title 
    });
    res.status(201).json(post);
  } catch (err) {
    console.error('Error al crear el post del foro:', err);
    res.status(400).json({ error: 'Error al crear el post del foro', details: err.message });
  }
});

// Actualizar un post
router.put('/posts/:id', auth, async (req, res) => {
  try {
    const post = await ForumPost.findById(req.params.id);
    if (!post) return res.status(404).json({ error: 'Post no encontrado' });
    if (post.userId.toString() !== req.userId) return res.status(403).json({ error: 'No autorizado' });
    const updatedPost = await ForumPost.findByIdAndUpdate(req.params.id, req.body, { returnDocument: 'after' });
    res.json(updatedPost);
  } catch (err) {
    res.status(400).json({ error: 'Error al actualizar el post' });
  }
});

// Eliminar un post
router.delete('/posts/:id', auth, async (req, res) => {
  try {
    const post = await ForumPost.findById(req.params.id);
    if (!post) return res.status(404).json({ error: 'Post no encontrado' });
    if (post.userId.toString() !== req.userId) return res.status(403).json({ error: 'No autorizado' });
    await ForumPost.findByIdAndDelete(req.params.id);
    res.json({ message: 'Post eliminado' });
  } catch (err) {
    res.status(400).json({ error: 'Error al eliminar el post' });
  }
});

// Agregar un like a un post
router.post('/posts/:id/like', auth, async (req, res) => {
  try {
    const post = await ForumPost.findById(req.params.id);
    if (!post) return res.status(404).json({ error: 'Post no encontrado' });
    
    // Verificar si el usuario ya likeó el post
    if (post.likedBy.includes(req.userId)) {
      return res.status(400).json({ error: 'Ya likeaste este post' });
    }

    const updatedPost = await ForumPost.findByIdAndUpdate(
      req.params.id,
      { 
        $inc: { likes: 1 },
        $push: { likedBy: req.userId }
      },
      { returnDocument: 'after' }
    );
    res.json(updatedPost);
  } catch (err) {
    res.status(400).json({ error: 'Error al dar like al post' });
  }
});

// Quitar un like de un post
router.post('/posts/:id/unlike', auth, async (req, res) => {
  try {
    const post = await ForumPost.findById(req.params.id);
    if (!post) return res.status(404).json({ error: 'Post no encontrado' });
    
    // Verificar si el usuario likeó el post
    if (!post.likedBy.includes(req.userId)) {
      return res.status(400).json({ error: 'No has likeado este post' });
    }

    const updatedPost = await ForumPost.findByIdAndUpdate(
      req.params.id,
      { 
        $inc: { likes: -1 },
        $pull: { likedBy: req.userId }
      },
      { returnDocument: 'after' }
    );
    res.json(updatedPost);
  } catch (err) {
    res.status(400).json({ error: 'Error al quitar like del post' });
  }
});

// Agregar un comentario a un post
router.post('/posts/:id/comment', auth, async (req, res) => {
  try {
    const { text } = req.body;
    if (!text) return res.status(400).json({ error: 'El comentario no puede estar vacío' });

    const user = await User.findById(req.userId);
    const comment = {
      userId: req.userId,
      username: user.username,
      text,
    };

    const post = await ForumPost.findByIdAndUpdate(
      req.params.id,
      { $push: { comments: comment } },
      { returnDocument: 'after' }
    );
    if (!post) return res.status(404).json({ error: 'Post no encontrado' });
    res.json(post);
  } catch (err) {
    res.status(400).json({ error: 'Error al agregar comentario' });
  }
});

// Editar un comentario en un post
router.put('/posts/:postId/comments/:commentId', auth, async (req, res) => {
  try {
    const { text } = req.body;
    if (!text) return res.status(400).json({ error: 'El comentario no puede estar vacío' });

    const post = await ForumPost.findById(req.params.postId);
    if (!post) return res.status(404).json({ error: 'Post no encontrado' });

    const comment = post.comments.id(req.params.commentId);
    if (!comment) return res.status(404).json({ error: 'Comentario no encontrado' });

    if (comment.userId.toString() !== req.userId) {
      return res.status(403).json({ error: 'No autorizado para editar este comentario' });
    }

    comment.text = text;
    await post.save();
    res.json(post);
  } catch (err) {
    res.status(400).json({ error: 'Error al editar comentario' });
  }
});

// Eliminar un comentario de un post
router.delete('/posts/:postId/comments/:commentId', auth, async (req, res) => {
  try {
    const post = await ForumPost.findById(req.params.postId);
    if (!post) return res.status(404).json({ error: 'Post no encontrado' });

    const comment = post.comments.id(req.params.commentId);
    if (!comment) return res.status(404).json({ error: 'Comentario no encontrado' });

    if (comment.userId.toString() !== req.userId) {
      return res.status(403).json({ error: 'No autorizado para eliminar este comentario' });
    }

    post.comments.id(req.params.commentId).deleteOne();
    await post.save();
    res.json(post);
  } catch (err) {
    res.status(400).json({ error: 'Error al eliminar comentario' });
  }
});

// ====== ENDPOINT PARA SINCRONIZACIÓN DE DREAMS COMPARTIDOS ======

// Actualizar post del foro por dreamId (usado cuando se edita el dream original)
router.put('/dreams/:dreamId', auth, async (req, res) => {
  try {
    console.log('🔄 Sincronizando dream:', {
      dreamId: req.params.dreamId,
      userId: req.userId,
      updateFields: Object.keys(req.body)
    });

    // Buscar el post del foro que tiene este dreamId
    let post = await ForumPost.findOne({ dreamId: req.params.dreamId });
    
    if (!post) {
      console.warn('⚠ Post no encontrado para dreamId:', req.params.dreamId);
      // Sugerir que quizás el post fue eliminado o no fue compartido
      return res.status(404).json({ 
        error: 'Post del foro no encontrado para este dream',
        message: 'El dream no ha sido compartido en el foro aún, o el post fue eliminado',
        dreamId: req.params.dreamId
      });
    }

    // Verificar que el usuario es el propietario del post
    if (post.userId.toString() !== req.userId) {
      console.warn('🚫 Usuario no autorizado intenta actualizar post:', {
        postUserId: post.userId.toString(),
        requestUserId: req.userId
      });
      return res.status(403).json({ error: 'No autorizado para actualizar este post' });
    }

    // Actualizar solo los campos de Dream que están permitidos
    const allowedFields = [
      'title', 'date', 'mood', 'tags', 'people', 'place', 
      'clarity', 'notes', 'isRecurring', 'wokeUp', 'dreamInfo'
    ];
    
    const updateData = {};
    allowedFields.forEach(field => {
      if (req.body[field] !== undefined) {
        updateData[field] = req.body[field];
      }
    });

    console.log('📝 Actualizando post con:', updateData);

    const updatedPost = await ForumPost.findByIdAndUpdate(
      post._id,
      updateData,
      { returnDocument: 'after' }
    ).populate('userId', 'username');

    console.log('✓ Post del foro sincronizado exitosamente');
    res.json(updatedPost);
  } catch (err) {
    console.error('❌ Error al sincronizar dream con foro:', err);
    res.status(500).json({ 
      error: 'Error al sincronizar con el foro', 
      details: err.message,
      dreamId: req.params.dreamId
    });
  }
});

// Obtener post del foro por dreamId
router.get('/dreams/:dreamId', optionalAuth, async (req, res) => {
  try {
    const post = await ForumPost.findOne({ dreamId: req.params.dreamId })
      .populate('userId', 'username')
      .populate('comments.userId', 'username');
    
    if (!post) {
      return res.status(404).json({ error: 'Post del foro no encontrado' });
    }

    // Si hay autenticación, agregar flag de si el usuario ha likeado
    if (req.userId) {
      const postObj = post.toObject ? post.toObject() : post;
      postObj.userHasLiked = post.likedBy.some(id => id.toString() === req.userId);
      return res.json(postObj);
    }

    res.json(post);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener el post del foro' });
  }
});

module.exports = router;
