DROP TABLE IF EXISTS analysis_checkpoints;
ALTER TABLE messages DROP COLUMN IF EXISTS analysis_mode;
ALTER TABLE messages DROP COLUMN IF EXISTS extracted_entities;
ALTER TABLE messages DROP COLUMN IF EXISTS suggested_questions;
ALTER TABLE messages DROP COLUMN IF EXISTS citations;
