-- Public functions

CREATE extension IF NOT EXISTS prefix;

BEGIN;

CREATE OR REPLACE FUNCTION set_modified () RETURNS "trigger" AS $$
BEGIN
	NEW.created = OLD.created;
	NEW.modified = now();
	NEW.created_by = OLD.created_by;
	NEW.modified_by = current_user;
	RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

-- djet schema

CREATE SCHEMA djet;

SET search_path TO djet, public;

CREATE TABLE feature (
	id						serial NOT NULL PRIMARY KEY,
	name					text NOT NULL UNIQUE,
	version					decimal,
	description				text,
	created					timestamp default now(),
	modified				timestamp,
	created_by 				text default current_user,
	modified_by 			text
);

COMMENT ON TABLE feature IS 'A feature is a collection of basetypes that forms or supports a set of functions or methods';
COMMENT ON COLUMN feature.name IS 'Feature Name';
COMMENT ON COLUMN feature.version IS 'Feature Version';
COMMENT ON COLUMN feature.description IS 'Feature Description';
COMMENT ON COLUMN feature.created_by IS 'The user (role) name that created the feature';
COMMENT ON COLUMN feature.modified_by IS 'The user (role) name that modified the feature last';

CREATE TRIGGER set_modified BEFORE UPDATE ON feature FOR EACH ROW EXECUTE PROCEDURE public.set_modified();

CREATE TABLE basetype (
	id					serial NOT NULL PRIMARY KEY,
	feature_id				int NOT NULL REFERENCES feature(id),
	name					text NOT NULL UNIQUE,
	title					text NOT NULL,
	parent					int[],
	datacolumns				jsonb NOT NULL default '[]',
	attributes 				jsonb NOT NULL default '{}',
	searchable				text[],
	handler					text,
	template				text,
	created					timestamptz default now(),
	modified				timestamptz,
	created_by 				text default current_user,
	modified_by 			text
);

COMMENT ON TABLE basetype IS 'Node Base Type';
COMMENT ON COLUMN basetype.feature_id IS 'References the feature table';
COMMENT ON COLUMN basetype.name IS 'Base Name - reference this in the app';
COMMENT ON COLUMN basetype.title IS 'Human readable title';
COMMENT ON COLUMN basetype.parent IS 'Array of allowed parent basetypes';
COMMENT ON COLUMN basetype.datacolumns IS 'The column definitions';
COMMENT ON COLUMN basetype.attributes IS 'Basetype specific information';
COMMENT ON COLUMN basetype.searchable IS 'The searchable columns';
COMMENT ON COLUMN basetype.handler IS 'The handler module';
COMMENT ON COLUMN basetype.template IS 'The template for this basetype';

CREATE TRIGGER set_modified BEFORE UPDATE ON basetype FOR EACH ROW EXECUTE PROCEDURE public.set_modified();

CREATE TABLE data (
	id					serial NOT NULL PRIMARY KEY,
	basetype_id				int NOT NULL REFERENCES basetype(id)
							ON DELETE restrict
							ON UPDATE restrict,
	name					text NOT NULL DEFAULT currval('djet.data_id_seq'::regclass),
	title					text NOT NULL,
	datacolumns				jsonb NOT NULL default '{}',
	acl						jsonb NOT NULL default '{}',
	fts						tsvector,
	created					timestamptz default now(),
	modified				timestamptz,
	created_by 				text default current_user,
	modified_by 			text
);

COMMENT ON TABLE data IS 'Data';
COMMENT ON COLUMN data.basetype_id IS 'The Basetype of the Data';
COMMENT ON COLUMN data.name IS 'The name';
COMMENT ON COLUMN data.title IS 'The Title';
COMMENT ON COLUMN data.datacolumns IS 'The actual column data';
COMMENT ON COLUMN data.fts IS 'Full Text Search column containing the content of the searchable columns';

CREATE TRIGGER set_modified BEFORE UPDATE ON data FOR EACH ROW EXECUTE PROCEDURE public.set_modified();

CREATE TABLE node (
	id					serial NOT NULL PRIMARY KEY,
	data_id					int REFERENCES data(id)
							ON DELETE cascade
							ON UPDATE cascade,
	parent_id				int REFERENCES node(id)
							ON DELETE cascade
							ON UPDATE cascade,
	part					text DEFAULT currval('djet.node_id_seq'::regclass),
	node_path				prefix_range,
	created					timestamptz default now(),
	modified				timestamptz,
	created_by 				text default current_user,
	modified_by 			text
);

COMMENT ON TABLE node IS 'Node';
COMMENT ON COLUMN node.data_id IS 'Pointer to the data row';
COMMENT ON COLUMN node.parent_id IS 'Parent of this uri';
COMMENT ON COLUMN node.part IS 'Path part';
COMMENT ON COLUMN node.node_path IS 'Global Path parts';

CREATE TRIGGER set_modified BEFORE UPDATE ON node FOR EACH ROW EXECUTE PROCEDURE public.set_modified();

CREATE INDEX node_path_gist_idx ON node USING GIST (node_path);

--
-- data_node view
--

CREATE VIEW data_node AS
SELECT d.id data_id, d.basetype_id, d.name, d.title, d.datacolumns, d.acl, d.fts, d.created data_created, d.modified data_modified, d.created_by data_created_by, d.modified_by data_modified_by,
	n.id node_id, n.parent_id, n.part, n.node_path, n.created node_created, n.modified node_modified, n.created_by node_created_by, n.modified_by node_modified_by
FROM djet.data d
JOIN djet.node n ON d.id=n.data_id;

CREATE OR REPLACE FUNCTION data_node_insert() RETURNS trigger AS $$
DECLARE
	d_id INT;
	n_id INT;
	name text;
	part text;
	n RECORD;
BEGIN
	SELECT nextval('djet.data_id_seq') INTO d_id;
	SELECT nextval('djet.node_id_seq') INTO n_id;
	IF NEW.name IS NULL THEN
		name := d_id;
	ELSE
		name := NEW.name;
	END IF;
	IF NEW.part IS NULL THEN
		part := n_id;
	ELSE
		part := NEW.part;
	END IF;
	WITH new_data AS (
		INSERT INTO djet.data (basetype_id, name, title, datacolumns, acl, fts) VALUES (NEW.basetype_id, name, NEW.title, coalesce(NEW.datacolumns, '{}'), coalesce(NEW.acl, '{}'), NEW.fts) RETURNING id
	)
	INSERT INTO djet.node (id, data_id, parent_id, part, node_path) SELECT n_id, id, NEW.parent_id, part, NEW.node_path FROM new_data;
	SELECT * INTO n FROM djet.data_node WHERE node_id = n_id;
	RETURN n;
END;
$$ language plpgsql;

CREATE TRIGGER data_node_insert INSTEAD OF INSERT ON data_node FOR EACH ROW EXECUTE PROCEDURE djet.data_node_insert();

CREATE OR REPLACE FUNCTION data_node_update() RETURNS trigger AS $$
BEGIN
	UPDATE djet.data
		SET basetype_id=NEW.basetype_id, name=NEW.name, title=NEW.title, datacolumns=NEW.datacolumns, acl=NEW.acl, fts=NEW.fts
		WHERE id=OLD.data_id;
	UPDATE djet.node
		SET parent_id=NEW.parent_id, part=NEW.part, node_path=NEW.node_path
		WHERE id=OLD.node_id;
	RETURN NEW;
END;
$$ language plpgsql;

CREATE TRIGGER data_node_update INSTEAD OF UPDATE ON data_node FOR EACH ROW EXECUTE PROCEDURE djet.data_node_update();

CREATE OR REPLACE FUNCTION data_node_delete() RETURNS trigger AS $$
BEGIN
	DELETE FROM djet.data
		WHERE id=OLD.data_id;
	DELETE FROM djet.node
		WHERE id=OLD.node_id;
	RETURN NEW;
END;
$$ language plpgsql;

CREATE TRIGGER data_node_delete INSTEAD OF DELETE ON data_node FOR EACH ROW EXECUTE PROCEDURE djet.data_node_delete();

CREATE OR REPLACE FUNCTION get_calculated_node_path(param_id integer) RETURNS text AS
$$
	SELECT CASE
		WHEN s.parent_id IS NULL THEN s.part
		ELSE djet.get_calculated_node_path(s.parent_id) || '/' || s.part
	END
	FROM djet.node s
	WHERE s.id = $1;
$$
LANGUAGE sql;

--
-- Update the node path recursively down the tree
--

CREATE OR REPLACE FUNCTION trig_update_node_path() RETURNS trigger AS
$$
BEGIN
	IF TG_OP = 'UPDATE' THEN
		IF (COALESCE(OLD.parent_id,0) != COALESCE(NEW.parent_id,0) OR NEW.data_id != OLD.data_id OR NEW.part != OLD.part) THEN
			-- update all nodes that are children of this one including this one
			UPDATE djet.node SET node_path = djet.get_calculated_node_path(id)
				WHERE node_path <@ OLD.node_path;
		END IF;
	ELSIF TG_OP = 'INSERT' THEN
		UPDATE djet.node SET node_path = djet.get_calculated_node_path(NEW.id) WHERE node.id = NEW.id;
	END IF;
   RETURN NEW;
END
$$
LANGUAGE 'plpgsql' VOLATILE;

CREATE TRIGGER trig01_update_node_path
	AFTER INSERT OR UPDATE OF data_id, parent_id, part
	ON node
	FOR EACH ROW EXECUTE PROCEDURE trig_update_node_path();

COMMIT;
