-- LNMP 项目数据库初始化脚本
-- 创建用户表
CREATE DATABASE IF NOT EXISTS lnmp_db DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE lnmp_db;

-- 用户表
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL,
    status TINYINT DEFAULT 1 COMMENT '1=正常, 0=禁用',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_username (username),
    INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 系统日志表
CREATE TABLE IF NOT EXISTS system_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    level VARCHAR(10) NOT NULL COMMENT 'INFO/WARN/ERROR',
    module VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_level (level),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 插入测试数据
INSERT INTO users (username, email, status) VALUES
('admin', 'admin@lnmp.local', 1),
('test_user', 'test@lnmp.local', 1),
('demo', 'demo@lnmp.local', 0);

INSERT INTO system_logs (level, module, message) VALUES
('INFO', 'system', 'System started successfully'),
('INFO', 'database', 'Database connection established'),
('WARN', 'security', 'Failed login attempt from 192.168.1.100'),
('ERROR', 'application', 'PHP Fatal error: Allowed memory size exhausted');

-- 创建只读用户（用于监控）
CREATE USER IF NOT EXISTS 'monitor'@'%' IDENTIFIED BY 'monitor123';
GRANT SELECT ON lnmp_db.* TO 'monitor'@'%';
FLUSH PRIVILEGES;
