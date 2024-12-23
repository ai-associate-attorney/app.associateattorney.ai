CREATE TABLE tasks (
  id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  title text NOT NULL,
  description text,
  status text NOT NULL,
  priority text NOT NULL,
  assignee uuid REFERENCES auth.users(id) NULL,
  due_date timestamp with time zone,
  matter_id bigint REFERENCES matters(id) NOT NULL,
  created_by uuid REFERENCES auth.users(id) NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  parent_task_id bigint REFERENCES tasks(id) ON DELETE CASCADE NULL,
  deleted boolean DEFAULT false NOT NULL,
  deleted_by uuid REFERENCES auth.users(id) NULL,
  deleted_at timestamp with time zone NULL,
  CONSTRAINT delete_consistency CHECK (
    (deleted = false AND deleted_by IS NULL AND deleted_at IS NULL) OR
    (deleted = true AND deleted_by IS NOT NULL AND deleted_at IS NOT NULL)
  )
);

-- Indexes for tasks
CREATE UNIQUE INDEX tasks_pkey ON public.tasks USING btree (id)
CREATE INDEX tasks_matter_id_idx ON public.tasks USING btree (matter_id)
CREATE INDEX tasks_created_by_idx ON public.tasks USING btree (created_by)
CREATE INDEX tasks_assignee_idx ON public.tasks USING btree (assignee)
CREATE INDEX tasks_parent_task_id_idx ON public.tasks USING btree (parent_task_id);

-- RLS for tasks
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Policies for tasks
CREATE POLICY "Users can view tasks" ON tasks
FOR SELECT USING (
  matter_id IN (
    SELECT matter_id 
    FROM matter_access 
    WHERE shared_with_user_id = auth.uid()
  )
);

CREATE POLICY "Users can update tasks" ON tasks
FOR UPDATE USING (
  matter_id IN (
    SELECT matter_id 
    FROM matter_access 
    WHERE shared_with_user_id = auth.uid() 
    AND access_type = 'edit'
  )
);

CREATE POLICY "Users can create tasks" ON tasks
FOR INSERT WITH CHECK (
  matter_id IN (
    SELECT matter_id 
    FROM matter_access 
    WHERE shared_with_user_id = auth.uid() 
    AND access_type = 'edit'
  )
);
