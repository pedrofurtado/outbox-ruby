CREATE TABLE IF NOT EXISTS outbox (
  id SERIAL PRIMARY KEY,
  message_type VARCHAR(255),
  message_body TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);
