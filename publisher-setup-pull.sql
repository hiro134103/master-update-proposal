-- ================================================
-- SQL Server レプリケーション Publisher セットアップスクリプト（プルサブスクリプション用）
-- ================================================
-- このスクリプトは、Publisher、配布データベース、およびパブリケーションをセットアップします
-- サブスクリプションは各 Subscriber 側で設定します

USE master;
GO

-- サンプルデータベースの作成
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'ReplicationDB')
BEGIN
    CREATE DATABASE ReplicationDB;
    PRINT 'ReplicationDB created successfully.';
END
ELSE
BEGIN
    PRINT 'ReplicationDB already exists.';
END
GO

USE ReplicationDB;
GO

-- サンプルテーブルの作成
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Products')
BEGIN
    CREATE TABLE Products (
        ProductID INT PRIMARY KEY IDENTITY(1,1),
        ProductName NVARCHAR(100) NOT NULL,
        Price DECIMAL(10, 2) NOT NULL,
        LastModified DATETIME DEFAULT GETDATE()
    );
    PRINT 'Products table created successfully.';
END
ELSE
BEGIN
    PRINT 'Products table already exists.';
END
GO

-- サンプルデータの挿入
IF NOT EXISTS (SELECT * FROM Products)
BEGIN
    INSERT INTO Products (ProductName, Price) VALUES 
        ('Laptop', 999.99),
        ('Mouse', 25.50),
        ('Keyboard', 75.00),
        ('Monitor', 299.99),
        ('Headphones', 89.99);
    PRINT 'Sample data inserted into Products table.';
END
ELSE
BEGIN
    PRINT 'Products table already contains data.';
END
GO

-- ================================================
-- 配布データベースの設定
-- ================================================
USE master;
GO

-- ディストリビューターのインストール
EXEC sp_adddistributor @distributor = @@SERVERNAME, @password = N'YourStrong@Passw0rd';
GO

-- 配布データベースの作成
EXEC sp_adddistributiondb 
    @database = N'distribution',
    @security_mode = 1;
GO

-- Publisher がディストリビューターを使用するように設定
EXEC sp_adddistpublisher 
    @publisher = @@SERVERNAME,
    @distribution_db = N'distribution',
    @security_mode = 1,
    @working_directory = N'/var/opt/mssql/data',
    @trusted = N'false',
    @thirdparty_flag = 0,
    @publisher_type = N'MSSQLSERVER';
GO

PRINT 'Distribution database configured successfully.';
GO

-- ================================================
-- パブリケーションの作成
-- ================================================
USE ReplicationDB;
GO

-- データベースでトランザクションパブリケーションを有効化
EXEC sp_replicationdboption 
    @dbname = N'ReplicationDB',
    @optname = N'publish',
    @value = N'true';
GO

-- トランザクションパブリケーションの追加
EXEC sp_addpublication 
    @publication = N'ProductPublication',
    @description = N'Transactional publication of Products table',
    @sync_method = N'concurrent',
    @retention = 0,
    @allow_push = N'true',
    @allow_pull = N'true',
    @allow_anonymous = N'false',
    @enabled_for_internet = N'false',
    @snapshot_in_defaultfolder = N'true',
    @compress_snapshot = N'false',
    @ftp_port = 21,
    @allow_subscription_copy = N'false',
    @add_to_active_directory = N'false',
    @repl_freq = N'continuous',
    @status = N'active',
    @independent_agent = N'true',
    @immediate_sync = N'false',
    @allow_sync_tran = N'false',
    @allow_queued_tran = N'false',
    @allow_dts = N'false',
    @replicate_ddl = 1,
    @allow_initialize_from_backup = N'false',
    @enabled_for_p2p = N'false',
    @enabled_for_het_sub = N'false';
GO

-- スナップショットエージェントの追加
EXEC sp_addpublication_snapshot 
    @publication = N'ProductPublication',
    @frequency_type = 1,
    @frequency_interval = 1,
    @frequency_relative_interval = 1,
    @frequency_recurrence_factor = 0,
    @frequency_subday = 8,
    @frequency_subday_interval = 1,
    @active_start_time_of_day = 0,
    @active_end_time_of_day = 235959,
    @active_start_date = 0,
    @active_end_date = 0,
    @job_login = NULL,
    @job_password = NULL,
    @publisher_security_mode = 1;
GO

-- Products テーブルをアーティクルとして追加
EXEC sp_addarticle 
    @publication = N'ProductPublication',
    @article = N'Products',
    @source_owner = N'dbo',
    @source_object = N'Products',
    @type = N'logbased',
    @description = N'Products table article',
    @creation_script = NULL,
    @pre_creation_cmd = N'drop',
    @schema_option = 0x000000000803509F,
    @identityrangemanagementoption = N'manual',
    @destination_table = N'Products',
    @destination_owner = N'dbo',
    @status = 24,
    @vertical_partition = N'false',
    @ins_cmd = N'CALL sp_MSins_dboProducts',
    @del_cmd = N'CALL sp_MSdel_dboProducts',
    @upd_cmd = N'SCALL sp_MSupd_dboProducts';
GO

PRINT 'Publication "ProductPublication" created successfully.';
PRINT 'Publisher setup completed!';
PRINT 'Note: Pull subscriptions will be created from each Subscriber.';
GO

-- パブリケーション情報の表示
SELECT 
    name AS PublicationName,
    description AS Description,
    status AS Status,
    repl_freq AS ReplicationFrequency
FROM 
    dbo.syspublications;
GO
