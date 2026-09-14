ALTER TABLE secure_messages ADD COLUMN source_kind TEXT CHECK(source_kind IN ('web','cli','api','subscription'));
ALTER TABLE v2_messages ADD COLUMN source_kind TEXT CHECK(source_kind IN ('web','cli','api','subscription'));
