CREATE TABLE IF NOT EXISTS `car_sale_history` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `seller_identifier` VARCHAR(100) NOT NULL,
  `seller_name` VARCHAR(100) DEFAULT NULL,
  `buyer_identifier` VARCHAR(100) DEFAULT NULL,
  `buyer_name` VARCHAR(100) DEFAULT NULL,
  `plate` VARCHAR(32) NOT NULL,
  `vehicle_model` VARCHAR(64) NOT NULL,
  `price` INT NOT NULL,
  `status` ENUM('active', 'sold', 'cancelled') NOT NULL DEFAULT 'active',
  `cancel_reason` VARCHAR(100) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `completed_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_car_sale_plate` (`plate`),
  KEY `idx_car_sale_seller` (`seller_identifier`),
  KEY `idx_car_sale_status` (`status`),
  KEY `idx_car_sale_status_created` (`status`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `car_sale_active_locks` (
  `plate` VARCHAR(32) NOT NULL,
  `listing_id` INT DEFAULT NULL,
  `seller_identifier` VARCHAR(100) NOT NULL,
  `vehicle_net_id` INT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`plate`),
  KEY `idx_car_sale_lock_listing` (`listing_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `car_sale_transactions` (
  `token` VARCHAR(96) NOT NULL,
  `listing_id` INT NOT NULL,
  `plate` VARCHAR(32) NOT NULL,
  `seller_identifier` VARCHAR(100) NOT NULL,
  `buyer_identifier` VARCHAR(100) NOT NULL,
  `amount` INT NOT NULL,
  `status` VARCHAR(32) NOT NULL,
  `last_error` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`token`),
  KEY `idx_car_sale_transaction_status` (`status`, `updated_at`),
  KEY `idx_car_sale_transaction_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
