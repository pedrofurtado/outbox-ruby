require 'sinatra'
require 'sinatra/reloader'
require 'pg'
require 'sidekiq'
require 'sidekiq-cron'
require 'json'
require 'yaml'

configure do
  enable :reloader
end

Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://redis:6379/0' }
  config.on(:startup) do
    Sidekiq::Options[:cron_poll_interval] = 10
    Sidekiq::Cron::Job.load_from_hash! YAML.load_file('./schedule.yml')
  end
end

def pg_connect
  PG.connect(host: ENV['POSTGRES_HOST'], dbname: ENV['POSTGRES_DATABASE'], user: ENV['POSTGRES_USER'], password: ENV['POSTGRES_PASSWORD'])
end

class OutboxWorker
  include Sidekiq::Worker

  def perform
    puts "Start OutboxWorker"
    conn = pg_connect
    messages = conn.exec_params('SELECT * FROM outbox WHERE processed_at IS NULL ORDER BY id LIMIT 5').to_a

    messages.each do |message|
      puts "OutboxWorker: Processing message #{message['id']}"

      # Ensure idempotency - check if the message has already been processed
      if message['processed_at']
        puts "OutboxWorker: Message #{message['id']} already processed"
        next
      end

      # Process the message here (e.g., send the message to the appropriate destination)
      puts "OutboxWorker: Message #{message['id']} sent to RabbitMQ/Kafka/etc"

      # Mark the message as processed and record the processing time
      conn.exec_params(
        'UPDATE outbox SET processed_at = $1 WHERE id = $2',
        [Time.now, message['id']]
      )
      puts "OutboxWorker: Message #{message['id']} masked as processed"
    end
  rescue => e
    puts "OutboxWorker: Failure on processing ... #{e.message}"
    puts "OutboxWorker: Skipping job execution, please wait next run ..."
  end
end

get '/messages' do
  content_type :json
  result = pg_connect.exec_params('SELECT * FROM outbox ORDER BY id')
  status 201
  result.to_a.to_json
end

get '/pending-messages' do
  content_type :json
  result = pg_connect.exec_params('SELECT * FROM outbox WHERE processed_at IS NULL ORDER BY id')
  status 201
  result.to_a.to_json
end

post '/create-message' do
  content_type :json
  data = JSON.parse(request.body.read)

  message_type = data['message_type']
  message_body = data['message_body']

  conn = pg_connect
  result = conn.exec_params(
    'INSERT INTO outbox (message_type, message_body) VALUES ($1, $2) RETURNING id',
    [message_type, message_body]
  ).first

  status 201
  { message: 'Message created and enqueued for processing' }.to_json
end
