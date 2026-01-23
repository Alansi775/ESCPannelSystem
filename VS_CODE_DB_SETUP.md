# ربط قاعدة البيانات في VS Code Extension

## البيانات الأساسية:

```
Name:                ESC Config Local
Connection Name:     esc_config_main
Group:               ESC Panel System
Scope:               User (or Workspace)
```

## إعدادات الاتصال:

```
Server Type:         MySQL
Host:                127.0.0.1
Port:                3306
Username:            root
Password:            root
Database:            esc_config
Socket Path:         /tmp/mysql.sock
```

## الخيارات:

```
Use Connection String:   ❌ NO
SSL:                     ❌ NO (للتطوير)
Event:                   ❌ NO
Trigger:                 ❌ NO
```

---

## خطوات الربط:

1. اضغط على **"+"** بجانب **"CONNECTIONS"**
2. اختر **"Create New Connection"**
3. املأ الحقول بالترتيب:

### الخطوة 1: البيانات الأساسية
- **Name**: `ESC Config Local`
- **Connection Name**: `esc_config_main`
- **Group**: `ESC Panel System`

### الخطوة 2: إعدادات الخادم
- **Server Type**: `MySQL` (من dropdown)
- **Host**: `127.0.0.1`
- **Port**: `3306`
- **Username**: `root`
- **Password**: `root`

### الخطوة 3: قاعدة البيانات
- **Database**: `esc_config`
- **Socket Path**: `/tmp/mysql.sock`

### الخطوة 4: الخيارات الإضافية
- ترك الكل على **OFF/NO**

---

## بعد الربط الناجح:

ستشوف في Extension:
```
ESC Config Local
├── users
│   ├── id
│   ├── email
│   ├── password
│   ├── name
│   ├── email_verified
│   └── ...
├── esc_configs
│   ├── id
│   ├── user_id
│   ├── name
│   ├── config_data (JSON)
│   └── ...
├── profiles
│   ├── id
│   ├── user_id
│   ├── profile_name
│   ├── config_data (JSON)
│   └── ...
└── esc_profiles
    ├── id
    ├── name
    ├── config_json
    └── ...
```

---

## اختبار الربط:

بعد الربط، اضغط على الـ database واختبر:

```sql
-- عرض كل الجداول
SHOW TABLES;

-- عرض عدد الـ users
SELECT COUNT(*) FROM users;

-- عرض كل الـ profiles
SELECT * FROM profiles;

-- عرض البيانات في esc_configs
SELECT * FROM esc_configs;
```

---

## لو لم تنجح المحاولة:

### خطأ: "Connection refused"
```bash
# تحقق من MySQL يشتغل
brew services list | grep mysql

# لو مطفوء:
sudo brew services start mysql
```

### خطأ: "Socket not found"
```bash
# جرب بدون Socket Path:
# اترك الحقل فارغ وستستخدم TCP/IP بدلاً منه
```

### خطأ: "Access denied for user 'root'"
```bash
# تحقق من كلمة المرور:
mysql -u root -p'root' -e "SELECT 1;"
```

---

## الملخص النهائي:

| الحقل | القيمة |
|---|---|
| **Name** | ESC Config Local |
| **Connection Name** | esc_config_main |
| **Server Type** | MySQL |
| **Host** | 127.0.0.1 |
| **Port** | 3306 |
| **Username** | root |
| **Password** | root |
| **Database** | esc_config |
| **Socket Path** | /tmp/mysql.sock |

