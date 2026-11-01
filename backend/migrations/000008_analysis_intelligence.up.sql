-- MIGRATION 000008: ANALYSIS CHECKPOINTS & INTELLIGENCE
ALTER TABLE messages ADD COLUMN IF NOT EXISTS citations JSONB DEFAULT '[]';
ALTER TABLE messages ADD COLUMN IF NOT EXISTS suggested_questions JSONB DEFAULT '[]';
ALTER TABLE messages ADD COLUMN IF NOT EXISTS extracted_entities JSONB DEFAULT '{}';
ALTER TABLE messages ADD COLUMN IF NOT EXISTS analysis_mode VARCHAR(64) DEFAULT 'deep_analysis';

CREATE TABLE IF NOT EXISTS analysis_checkpoints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    generation_id UUID REFERENCES generations(id) ON DELETE CASCADE,
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mode VARCHAR(64) NOT NULL DEFAULT 'deep_analysis',
    completed_sections JSONB NOT NULL DEFAULT '[]',
    remaining_sections JSONB NOT NULL DEFAULT '[]',
    accumulated_content TEXT NOT NULL DEFAULT '',
    last_section_title VARCHAR(255),
    status VARCHAR(32) NOT NULL DEFAULT 'saved',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_analysis_checkpoints_conv ON analysis_checkpoints(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_analysis_checkpoints_gen ON analysis_checkpoints(generation_id);
