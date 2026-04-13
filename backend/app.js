require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const authRoutes = require('./routes/auth');
const dreamsRoutes = require('./routes/dreams');
const profileRoutes = require('./routes/profile');
const forumRoutes = require('./routes/forum');
const usersRoutes = require('./routes/users');
const app = express();
const cors = require('cors');

app.use(express.json());
app.use(cors());
app.use('/api', authRoutes);
app.use('/api/dreams', dreamsRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/forum', forumRoutes);
app.use('/api/users', usersRoutes);

const PORT = process.env.PORT || 3000;

mongoose.connect(process.env.MONGODB_URI)
  .then(() => app.listen(PORT, () => console.log(`Servidor backend en puerto ${PORT}`)))
  .catch(err => console.error('Error de conexión:', err));
