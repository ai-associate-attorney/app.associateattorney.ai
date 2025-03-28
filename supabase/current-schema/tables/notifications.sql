    create table public.notifications (
      id uuid default uuid_generate_v4() primary key,
      user_id uuid references auth.users not null,
      actor_id uuid references auth.users,
      type text not null,
      data jsonb,
      read boolean default false,
      created_at timestamp with time zone default timezone('utc'::text, now()),
      message text
    );

    -- Create index for faster queries
    create index notifications_user_id_idx on public.notifications(user_id);

    -- Create a new migration file in supabase/migrations/[timestamp]_add_metadata_to_notifications.sql

    ALTER TABLE notifications 
    ADD COLUMN metadata JSONB DEFAULT NULL;

    COMMENT ON COLUMN notifications.metadata IS 'Additional data specific to the notification type';


    alter table notifications add column if not exists email_status varchar(50) default 'not_attempted';
    alter table notifications add column if not exists email_message text;
    alter table notifications add column if not exists last_email_attempt timestamptz;
    alter table notifications add column if not exists email_enabled boolean default false;
    alter table notifications add column if not exists retry_count int default 0;

    -- Policies for notifications
    CREATE POLICY "Users can create notifications" ON notifications
    AS PERMISSIVE
    FOR SELECT 
    TO authenticated 
    WITH CHECK (
      (true)
    );

   CREATE POLICY "Users can view own notifications only" ON notifications
    AS PERMISSIVE
    FOR SELECT 
    TO public
    USING (
      (user_id = auth.uid())
    );

    CREATE POLICY "Users can update their own notifications" ON notifications
    AS PERMISSIVE
    FOR UPDATE 
    TO public
    USING (
      (user_id = auth.uid())
    )
    WITH CHECK (
      (user_id = auth.uid())
    );