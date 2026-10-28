app.post('/auth/verify-pin', auth, (req, res) => {
  const { pin } = req.body;
  const u = db.prepare('SELECT pin_hash FROM users WHERE id = ?').get(req.userId);
  if (!u) return fail(res, 'User not found', 404);
  if (!bcrypt.compareSync(pin || '', u.pin_hash)) return fail(res, 'Wrong PIN', 401);
  ok(res, { valid: true });
});