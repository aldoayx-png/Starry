const mongoose = require('mongoose');

const ForumPostSchema = new mongoose.Schema(
  {
    dreamId: { type: String, index: true }, // ID del dream original en la colección dreams - con índice para búsquedas rápidas
    title: { type: String, required: true },
    date: { type: Date },
    mood: { type: String },
    tags: [{ type: String }],
    people: { type: String },
    place: { type: String },
    clarity: { type: Number },
    notes: { type: String },
    isRecurring: { type: Boolean, default: false },
    wokeUp: { type: Boolean, default: false },
    dreamInfo: { type: String },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    likes: { type: Number, default: 0 },
    likedBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    comments: [
      {
        userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        username: { type: String },
        text: { type: String },
        createdAt: { type: Date, default: Date.now },
      },
    ],
  },
  { timestamps: true }
);

module.exports = mongoose.model('ForumPost', ForumPostSchema);
