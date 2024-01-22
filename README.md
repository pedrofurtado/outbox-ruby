# Outbox pattern in ruby

Outbox pattern in Ruby. Just for fun.

```bash
# Run the application at http://localhost:9292
docker-compose up --build -d

# Check pages http://localhost:9292/messages and http://localhost:9292/pending-messages
curl http://localhost:9292/messages
curl http://localhost:9292/pending-messages

# Send a new message to outbox
curl -X POST -H "Content-Type: application/json" -d '{"message_type":"notification","message_body":"Hello, World!"}' http://localhost:9292/create-message
```
