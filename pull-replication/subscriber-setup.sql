-- ================================================
-- SQL Server レプリケーション Subscriber セットアップスクリプト（プルサブスクリプション用）
-- ================================================
-- このスクリプトは、Subscriber データベースを作成し、プルサブスクリプションを設定します

USE master;
GO

-- サブスクライバーデータベースの作成
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'ReplicationDB')
BEGIN
    CREATE DATABASE ReplicationDB;
    PRINT 'ReplicationDB created successfully on Subscriber.';
END
ELSE
BEGIN
    PRINT 'ReplicationDB already exists on Subscriber.';
END
GO

USE ReplicationDB;
GO

-- Products テーブルの作成（スキーマのみ）
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Products')
BEGIN
    CREATE TABLE Products (
        ProductID INT PRIMARY KEY IDENTITY(1,1),
        ProductName NVARCHAR(100) NOT NULL,
        Price DECIMAL(10, 2) NOT NULL,
        LastModified DATETIME DEFAULT GETDATE()
    );
    PRINT 'Products table created successfully on Subscriber.';
END
ELSE
BEGIN
    PRINT 'Products table already exists on Subscriber.';
END
GO

-- ================================================
-- プルサブスクリプションの設定
-- ================================================

-- Publisher へのリンクサーバーの作成（必要に応じて）
IF NOT EXISTS (SELECT * FROM sys.servers WHERE name = 'sqlpublisher')
BEGIN
    EXEC sp_addlinkedserver 
        @server = 'sqlpublisher',
        @srvproduct = '',
        @provider = 'SQLNCLI',
        @datasrc = 'sqlpublisher,1433';
    PRINT 'Linked server to Publisher created.';
END
ELSE
BEGIN
    PRINT 'Linked server to Publisher already exists.';
END
GO

-- プルサブスクリプションの追加
EXEC sp_addpullsubscription 
    @publisher = N'sqlpublisher',
    @publisher_db = N'ReplicationDB',
    @publication = N'ProductPublication',
    @independent_agent = N'true',
    @subscription_type = N'pull',
    @description = N'Pull subscription to ProductPublication',
    @update_mode = N'read only',
    @immediate_sync = 0;
GO

-- プルサブスクリプションエージェントの追加
EXEC sp_addpullsubscription_agent 
    @publisher = N'sqlpublisher',
    @publisher_db = N'ReplicationDB',
    @publication = N'ProductPublication',
    @distributor = N'sqlpublisher',
    @distributor_security_mode = 0,
    @distributor_login = N'sa',
    @distributor_password = N'YourStrong@Passw0rd',
    @enabled_for_syncmgr = N'false',
    @frequency_type = 64,
    @frequency_interval = 0,
    @frequency_relative_interval = 0,
    @frequency_recurrence_factor = 0,
    @frequency_subday = 0,
    @frequency_subday_interval = 0,
    @active_start_time_of_day = 0,
    @active_end_time_of_day = 235959,
    @active_start_date = 20000101,
    @active_end_date = 99991231;
GO

PRINT 'Pull subscription created successfully on Subscriber.';
PRINT 'Subscriber setup completed!';
GO
