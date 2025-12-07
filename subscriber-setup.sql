-- ================================================
-- SQL Server Replication Subscriber Setup Script
-- ================================================
-- This script sets up the subscriber and creates a subscription

USE master;
GO

-- Create the subscription database
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

-- ================================================
-- Add Subscription
-- ================================================
-- Note: This script should be executed AFTER the publisher setup is complete
-- and the snapshot has been generated

USE ReplicationDB;
GO

-- Add the pull subscription
EXEC sp_addpullsubscription 
    @publisher = N'sqlpublisher',
    @publication = N'ProductPublication',
    @publisher_db = N'ReplicationDB',
    @independent_agent = N'True',
    @subscription_type = N'pull',
    @description = N'Pull subscription to ProductPublication',
    @update_mode = N'read only',
    @immediate_sync = 0;
GO

-- Add the pull subscription agent
EXEC sp_addpullsubscription_agent 
    @publisher = N'sqlpublisher',
    @publisher_db = N'ReplicationDB',
    @publication = N'ProductPublication',
    @distributor = N'sqlpublisher',
    @distributor_security_mode = 0,
    @distributor_login = N'sa',
    @distributor_password = N'YourStrong@Passw0rd',
    @enabled_for_syncmgr = N'False',
    @frequency_type = 64,
    @frequency_interval = 0,
    @frequency_relative_interval = 0,
    @frequency_recurrence_factor = 0,
    @frequency_subday = 0,
    @frequency_subday_interval = 0,
    @active_start_time_of_day = 0,
    @active_end_time_of_day = 235959,
    @active_start_date = 20000101,
    @active_end_date = 99991231,
    @alt_snapshot_folder = N'',
    @working_directory = N'',
    @job_login = NULL,
    @job_password = NULL,
    @publisher_security_mode = 0,
    @publisher_login = N'sa',
    @publisher_password = N'YourStrong@Passw0rd';
GO

PRINT 'Subscription created successfully on Subscriber.';
PRINT 'Subscriber setup completed!';
GO

-- Display subscription information
SELECT 
    srv.srvname AS Publisher,
    s.subscriber_db AS SubscriberDatabase,
    s.publication AS Publication,
    s.subscription_type AS SubscriptionType,
    s.sync_type AS SyncType,
    s.status AS Status,
    s.update_mode AS UpdateMode
FROM 
    dbo.MSsubscription_properties s
    INNER JOIN master.dbo.sysservers srv ON s.publisher_id = srv.srvid
WHERE 
    s.publication = N'ProductPublication';
GO
