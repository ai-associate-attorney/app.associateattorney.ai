/* 
Features we want to support:

1. Each matter will have:
A. An email address associated with it so attorneys can send email to 19fl002753@associateattorney.ai and that email will be associated with the matter.
B. Goals -- for the structure see goals.sql
C. Tasks -- for the structure see tasks.sql
D. Events -- for the structure see events.sql
E. Files -- stored inside gitea git repository.

2. A matter can be archived but it cannot be deleted.

3. A matter has a name and description which can be edited by anyone with edit rights.
*/

COMMENT ON TABLE matters IS 'Matters can be archived but not deleted. Archiving requires both archived_by and archived_at to be set.';

CREATE TABLE matters (
    id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    title character varying NOT NULL,
    description text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    archived_by uuid REFERENCES auth.users(id),
    archived_at timestamp with time zone,
    created_by uuid REFERENCES auth.users(id) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT archive_consistency CHECK (
        (archived = false AND archived_by IS NULL AND archived_at IS NULL) OR
        (archived = true AND archived_by IS NOT NULL AND archived_at IS NOT NULL)
    )
);

-- Automatically add creator to matter_shares on matter creation
CREATE FUNCTION add_creator_share() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO matter_shares (matter_id, shared_with_user_id, access_type, created_by)
    VALUES (NEW.id, auth.uid(), 'edit', auth.uid());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_matter_created
    AFTER INSERT ON matters
    FOR EACH ROW
    EXECUTE FUNCTION add_creator_share();

-- Create indexes
CREATE INDEX matters_created_by_idx ON matters USING btree (created_by);
CREATE INDEX matters_archived_idx ON matters USING btree (archived);
CREATE INDEX matters_archived_by_idx ON matters USING btree (archived_by);

-- Enable Row Level Security
ALTER TABLE matters ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies
CREATE POLICY "Users can create matters" 
    ON matters FOR INSERT 
    WITH CHECK (true);  -- Creator will get access via trigger

CREATE POLICY "Users can view matters" 
    ON matters FOR SELECT 
    USING (id IN (
        SELECT matter_id 
        FROM matter_shares 
        WHERE shared_with_user_id = auth.uid()
    ));

CREATE POLICY "Users can update matters" 
    ON matters FOR UPDATE 
    USING (id IN (
        SELECT matter_id 
        FROM matter_shares 
        WHERE shared_with_user_id = auth.uid() 
        AND access_type = 'edit'
    ));