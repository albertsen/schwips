CREATE TABLE `bottles` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`wine_id` integer NOT NULL,
	`bottle_size_ml` integer DEFAULT 750 NOT NULL,
	`location` text,
	`purchase_date` text,
	`purchase_price` real,
	`purchase_vendor` text,
	`current_value` real,
	`status` text DEFAULT 'in_stock' NOT NULL,
	`consumed_date` text,
	`personal_rating` integer,
	`created_at` integer DEFAULT (unixepoch()) NOT NULL,
	`updated_at` integer DEFAULT (unixepoch()) NOT NULL,
	FOREIGN KEY (`wine_id`) REFERENCES `wines`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE TABLE `grape_aliases` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`grape_id` integer NOT NULL,
	`alias` text NOT NULL,
	FOREIGN KEY (`grape_id`) REFERENCES `grapes`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE UNIQUE INDEX `grape_aliases_alias_unique` ON `grape_aliases` (`alias`);--> statement-breakpoint
CREATE TABLE `grapes` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`name` text NOT NULL,
	`color` text
);
--> statement-breakpoint
CREATE UNIQUE INDEX `grapes_name_unique` ON `grapes` (`name`);--> statement-breakpoint
CREATE TABLE `photos` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`wine_id` integer NOT NULL,
	`file_path` text NOT NULL,
	`is_primary` integer DEFAULT false NOT NULL,
	`created_at` integer DEFAULT (unixepoch()) NOT NULL,
	FOREIGN KEY (`wine_id`) REFERENCES `wines`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE TABLE `tasting_notes` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`bottle_id` integer NOT NULL,
	`tasted_on` text,
	`rating` integer,
	`note` text,
	`created_at` integer DEFAULT (unixepoch()) NOT NULL,
	FOREIGN KEY (`bottle_id`) REFERENCES `bottles`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE TABLE `wine_grapes` (
	`wine_id` integer NOT NULL,
	`grape_id` integer NOT NULL,
	`percentage` real,
	`label_name` text,
	PRIMARY KEY(`wine_id`, `grape_id`),
	FOREIGN KEY (`wine_id`) REFERENCES `wines`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`grape_id`) REFERENCES `grapes`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE TABLE `wines` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`producer` text NOT NULL,
	`name` text,
	`vintage` integer,
	`wine_type` text,
	`color` text,
	`sweetness` text,
	`quality_level` text,
	`region` text,
	`country` text,
	`appellation` text,
	`vineyard` text,
	`abv` real,
	`residual_sugar_gl` real,
	`acidity_gl` real,
	`drink_from` integer,
	`drink_until` integer,
	`description` text,
	`food_pairing` text,
	`serving_temp_c` text,
	`closure` text,
	`is_organic` integer,
	`is_vegan` integer,
	`external_links` text,
	`extra_data` text,
	`data_sources` text,
	`import_confidence` real,
	`wine_signature` text NOT NULL,
	`created_at` integer DEFAULT (unixepoch()) NOT NULL,
	`updated_at` integer DEFAULT (unixepoch()) NOT NULL
);
--> statement-breakpoint
CREATE INDEX `wines_signature_idx` ON `wines` (`wine_signature`);