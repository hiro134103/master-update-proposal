# SQL Server Replication Setup using Docker (Publisher/Subscriber)

## Prerequisites
- Docker installed on your machine
- Basic knowledge of Docker and SQL Server

## Step 1: Create Docker Network
```bash
docker network create sql_repl_network
```

## Step 2: Start Publisher
```bash
docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=YourStrong@Passw0rd' \
  --name sqlpublisher --network sql_repl_network -d \
  mcr.microsoft.com/mssql/server:2019-latest
```

## Step 3: Start Subscriber
```bash
docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=YourStrong@Passw0rd' \
  --name sqlsubscriber --network sql_repl_network -d \
  mcr.microsoft.com/mssql/server:2019-latest
```

## Step 4: Configure Publisher
1. Connect to the Publisher instance using SQL Server Management Studio (SSMS) or any SQL client.
2. Enable SQL Server Agent if not already enabled.
3. Create a publication.
   ```sql
   EXEC sp_addpublication @publication = N'YourPublicationName', 
                          @status = N'active', 
                          @allow_push = N'true', 
                          @allow_pull = N'true';
   ```

## Step 5: Configure Subscriber
1. Connect to the Subscriber instance.
2. Create a subscription to the publication.
   ```sql
   EXEC sp_addsubscription @publication = N'YourPublicationName',
                            @subscriber = N'sqlsubscriber',
                            @destination_db = N'YourDestinationDB';
   ```

## Conclusion
You now have a basic setup for SQL Server replication using Docker! Make sure to adjust configurations and passwords as per your requirements.
