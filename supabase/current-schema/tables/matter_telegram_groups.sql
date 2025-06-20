CREATE TABLE workspace_telegram_groups (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  matter_id bigint REFERENCES matters(id) ON DELETE CASCADE,
  chat_id text NOT NULL,
  name text NOT NULL,
  notification_types text[] DEFAULT '{}',
  created_at timestamp with time zone DEFAULT timezone('utc', now())
);