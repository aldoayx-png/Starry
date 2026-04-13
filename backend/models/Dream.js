const mongoose = require('mongoose');

const DreamSchema = new mongoose.Schema({
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
  isShared: { type: Boolean, default: false },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
});

module.exports = mongoose.model('Dream', DreamSchema);
