-- ================================================
-- SQL Server レプリケーション Subscriber セットアップスクリプト
-- ================================================
-- このスクリプトは、Subscriber データベースとテーブルスキーマをセットアップします
-- プッシュサブスクリプションは Publisher から作成されます

USE master;
GO

-- サブスクリプションデータベースの作成
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'ReplicationDB')
BEGIN
    CREATE DATABASE ReplicationDB;
    PRINT 'ReplicationDB created on Subscriber successfully.';
END
ELSE
BEGIN
    PRINT 'ReplicationDB already exists on Subscriber.';
END
GO

USE ReplicationDB;
GO

-- Subscriber で Products テーブルのスキーマを作成
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Products') AND type in (N'U'))
BEGIN
    CREATE TABLE dbo.Products (
        ProductID INT IDENTITY(1,1) PRIMARY KEY,
        ProductName NVARCHAR(100) NOT NULL,
        Price DECIMAL(10, 2) NOT NULL,
        LastModified DATETIME DEFAULT GETDATE()
    );
    PRINT 'Products table created on Subscriber.';
END
ELSE
BEGIN
    PRINT 'Products table already exists on Subscriber.';
END
GO

PRINT 'Subscriber setup completed!';
PRINT 'Note: Push subscription will be created from the Publisher.';
GO
