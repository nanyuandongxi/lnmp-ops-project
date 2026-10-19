<?php
/**
 * LNMP 环境测试页面
 * 用于验证 Nginx + PHP + MySQL 是否正常工作
 */

// 数据库连接配置
$db_host = 'mysql';
$db_port = 3306;
$db_name = 'lnmp_db';
$db_user = 'lnmp_user';
$db_pass = 'lnmp123456';

// 系统信息
$system_info = [
    'PHP版本' => phpversion(),
    '操作系统' => PHP_OS,
    '服务器软件' => $_SERVER['SERVER_SOFTWARE'] ?? 'N/A',
    '服务器时间' => date('Y-m-d H:i:s'),
    '内存使用' => round(memory_get_usage() / 1024 / 1024, 2) . ' MB',
];

// 测试数据库连接
$db_status = '未连接';
$db_users = [];
try {
    $pdo = new PDO("mysql:host={$db_host};port={$db_port};dbname={$db_name}", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $db_status = '连接成功';
    
    // 查询用户数据
    $stmt = $pdo->query("SELECT id, username, email, status FROM users");
    $db_users = $stmt->fetchAll(PDO::FETCH_ASSOC);
} catch (PDOException $e) {
    $db_status = '连接失败: ' . $e->getMessage();
}
?>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>LNMP 环境测试</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #4CAF50; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #4CAF50; color: white; }
        tr:hover { background: #f5f5f5; }
        .status-ok { color: #4CAF50; font-weight: bold; }
        .status-error { color: #f44336; font-weight: bold; }
        .info-box { background: #e8f5e9; padding: 15px; border-radius: 5px; margin: 15px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 LNMP 环境测试页面</h1>
        <div class="info-box">
            <p><strong>恭喜！</strong> LNMP 环境部署成功，Nginx 和 PHP 工作正常。</p>
        </div>

        <h2>📋 系统信息</h2>
        <table>
            <tr><th>项目</th><th>值</th></tr>
            <?php foreach ($system_info as $key => $value): ?>
            <tr><td><?= $key ?></td><td><?= $value ?></td></tr>
            <?php endforeach; ?>
        </table>

        <h2>🗄️ 数据库连接状态</h2>
        <p>MySQL 状态: <span class="<?= strpos($db_status, '成功') !== false ? 'status-ok' : 'status-error' ?>"><?= $db_status ?></span></p>

        <?php if (!empty($db_users)): ?>
        <h2>👥 用户数据</h2>
        <table>
            <tr><th>ID</th><th>用户名</th><th>邮箱</th><th>状态</th></tr>
            <?php foreach ($db_users as $user): ?>
            <tr>
                <td><?= $user['id'] ?></td>
                <td><?= htmlspecialchars($user['username']) ?></td>
                <td><?= htmlspecialchars($user['email']) ?></td>
                <td><?= $user['status'] ? '正常' : '禁用' ?></td>
            </tr>
            <?php endforeach; ?>
        </table>
        <?php endif; ?>
    </div>
</body>
</html>
