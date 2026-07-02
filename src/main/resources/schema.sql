DROP TABLE IF EXISTS user_info;
CREATE TABLE user_info (
    id        BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id   VARCHAR(32)  NOT NULL,
    user_name VARCHAR(64)  NOT NULL,
    age       INT          NOT NULL,
    gender    VARCHAR(8)   NOT NULL
);

DROP TABLE IF EXISTS order_info;
CREATE TABLE order_info (
    id           BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id     VARCHAR(32)   NOT NULL,
    user_id      VARCHAR(32)   NOT NULL,
    status       VARCHAR(16)   NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    create_time  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS order_item;
CREATE TABLE order_item (
    id           BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id     VARCHAR(32)   NOT NULL,
    product_name VARCHAR(64)   NOT NULL,
    quantity     INT           NOT NULL,
    price        DECIMAL(10, 2) NOT NULL
);
