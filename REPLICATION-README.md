# SQL Server Replication Environment using Docker Compose

This repository provides a complete local development environment for testing SQL Server replication using Docker Compose. The setup includes a Publisher and Subscriber configuration with transactional replication.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Detailed Setup Instructions](#detailed-setup-instructions)
- [Testing Replication](#testing-replication)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Prerequisites

Before you begin, ensure you have the following installed on your system:
- Docker (version 20.10 or later)
- Docker Compose (version 1.29 or later)
- A SQL client tool (SQL Server Management Studio, Azure Data Studio, or sqlcmd)

## Project Structure

```
.
├── docker-compose.yml           # Docker Compose configuration for Publisher and Subscriber
├── publisher-setup.sql          # SQL script to configure the Publisher
├── subscriber-setup.sql         # SQL script to configure the Subscriber
└── README.md                    # This file
```

## Quick Start

Follow these steps to quickly set up and test SQL Server replication:

```bash
# 1. Start the containers
docker-compose up -d

# 2. Wait for SQL Server containers to be ready (about 30-60 seconds)
docker-compose ps

# 3. Configure the Publisher
docker exec -it sqlpublisher /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -i /var/opt/mssql/publisher-setup.sql

# 4. Configure the Subscriber
docker exec -it sqlsubscriber /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -i /var/opt/mssql/subscriber-setup.sql

# 5. Test the replication (see Testing Replication section)
```

## Detailed Setup Instructions

### Step 1: Start the Docker Environment

Start both SQL Server containers using Docker Compose:

```bash
docker-compose up -d
```

This command will:
- Create a Docker network named `sql_repl_network`
- Start two SQL Server 2019 containers:
  - **sqlpublisher** (accessible on port 1433)
  - **sqlsubscriber** (accessible on port 1434)
- Enable SQL Server Agent on both instances (required for replication)

### Step 2: Verify Containers are Running

Check the status of the containers:

```bash
docker-compose ps
```

Wait until both containers show as "healthy". You can also check the logs:

```bash
# Check Publisher logs
docker-compose logs sqlpublisher

# Check Subscriber logs
docker-compose logs sqlsubscriber
```

### Step 3: Configure the Publisher

The `publisher-setup.sql` script will:
1. Create the `ReplicationDB` database
2. Create a sample `Products` table with test data
3. Configure the distribution database
4. Create a transactional publication named `ProductPublication`

Execute the script by copying it to the Publisher container and running it:

```bash
# Copy the SQL script to the Publisher container
docker cp publisher-setup.sql sqlpublisher:/var/opt/mssql/publisher-setup.sql

# Execute the script
docker exec -it sqlpublisher /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -i /var/opt/mssql/publisher-setup.sql
```

Alternatively, you can connect using your SQL client:
- Server: `localhost,1433`
- Username: `sa`
- Password: `YourStrong@Passw0rd`

Then open and execute `publisher-setup.sql`.

### Step 4: Generate the Snapshot

After configuring the Publisher, you need to generate a snapshot:

```bash
docker exec -it sqlpublisher /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -Q "EXEC sp_startpublication_snapshot @publication = N'ProductPublication';"
```

Wait a few seconds for the snapshot to be generated. You can check the status:

```bash
docker exec -it sqlpublisher /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -Q "SELECT * FROM distribution.dbo.MSsnapshot_agents;"
```

### Step 5: Configure the Subscriber

The `subscriber-setup.sql` script will:
1. Create the `ReplicationDB` database on the Subscriber
2. Add a pull subscription to the `ProductPublication`
3. Configure the subscription agent

Execute the script:

```bash
# Copy the SQL script to the Subscriber container
docker cp subscriber-setup.sql sqlsubscriber:/var/opt/mssql/subscriber-setup.sql

# Execute the script
docker exec -it sqlsubscriber /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -i /var/opt/mssql/subscriber-setup.sql
```

Alternatively, connect using your SQL client:
- Server: `localhost,1434`
- Username: `sa`
- Password: `YourStrong@Passw0rd`

Then open and execute `subscriber-setup.sql`.

### Step 6: Start the Subscription Agent

The pull subscription agent should start automatically through SQL Server Agent. You can verify it's running:

```bash
# Check if the subscription agent job exists and is running
docker exec -it sqlsubscriber /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d msdb -Q "SELECT name, enabled, date_created FROM sysjobs WHERE name LIKE '%ProductPublication%';"
```

If needed, you can manually start the pull subscription agent:

```bash
# Start the pull subscription agent
docker exec -it sqlsubscriber /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d ReplicationDB -Q "EXEC sp_start_job @job_name = (SELECT name FROM msdb.dbo.sysjobs WHERE name LIKE '%ProductPublication%');"
```

## Testing Replication

### Verify Initial Data Replication

1. **Check data on the Subscriber:**

```bash
# Connect to Subscriber and query the Products table
docker exec -it sqlsubscriber /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d ReplicationDB -Q "SELECT * FROM Products;"
```

You should see the same 5 products that were inserted on the Publisher.

### Test Real-Time Replication

1. **Insert a new product on the Publisher:**

```bash
docker exec -it sqlpublisher /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d ReplicationDB -Q "INSERT INTO Products (ProductName, Price) VALUES ('Webcam', 149.99);"
```

2. **Update an existing product on the Publisher:**

```bash
docker exec -it sqlpublisher /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d ReplicationDB -Q "UPDATE Products SET Price = 899.99 WHERE ProductName = 'Laptop';"
```

3. **Delete a product on the Publisher:**

```bash
docker exec -it sqlpublisher /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d ReplicationDB -Q "DELETE FROM Products WHERE ProductName = 'Mouse';"
```

4. **Verify changes on the Subscriber (wait a few seconds for replication):**

```bash
docker exec -it sqlsubscriber /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d ReplicationDB -Q "SELECT * FROM Products ORDER BY ProductID;"
```

The Subscriber should reflect all changes made on the Publisher.

### Monitor Replication Status

Check replication status and any errors:

```bash
# On Publisher - Check distribution database
docker exec -it sqlpublisher /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d distribution -Q "SELECT * FROM MSreplication_monitordata;"

# Check for replication errors
docker exec -it sqlpublisher /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d distribution -Q "SELECT * FROM MSrepl_errors ORDER BY time DESC;"
```

## Troubleshooting

### Common Issues

**1. Containers not starting:**
- Ensure Docker is running
- Check if ports 1433 and 1434 are available
- Review container logs: `docker-compose logs`

**2. SQL Server Agent not running:**
```bash
# Check SQL Server Agent status on Publisher
docker exec -it sqlpublisher /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -Q "SELECT CASE WHEN EXISTS(SELECT 1 FROM sys.dm_exec_sessions WHERE program_name LIKE 'SQLAgent%') THEN 'Running' ELSE 'Not Running' END AS AgentStatus;"

# If needed, verify agent jobs exist
docker exec -it sqlpublisher /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d msdb -Q "SELECT job_id, name, enabled FROM sysjobs WHERE name LIKE '%snapshot%' OR name LIKE '%repl%';"
```

**3. Replication not working:**
- Verify the snapshot was generated successfully
- Check SQL Server Agent jobs are running
- Review replication monitor for errors
- Ensure both containers can communicate on the `sql_repl_network`

**4. Connection issues between Publisher and Subscriber:**
```bash
# Test network connectivity
docker exec -it sqlsubscriber ping sqlpublisher
```

**5. View detailed replication errors:**
```bash
docker exec -it sqlpublisher /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -Q "EXEC sp_replmonitorhelppublication @publisher = N'sqlpublisher';"
```

### Reset and Start Over

If you need to completely reset the environment:

```bash
# Stop and remove containers, networks, and volumes
docker-compose down -v

# Start fresh
docker-compose up -d

# Re-run the setup scripts
```

## Cleanup

To stop and remove all containers, networks, and volumes:

```bash
# Stop and remove everything
docker-compose down -v

# Or just stop the containers (keeping data)
docker-compose stop
```

To remove just the containers but keep the volumes:

```bash
docker-compose down
```

## Additional Resources

- [SQL Server Replication Documentation](https://docs.microsoft.com/en-us/sql/relational-databases/replication/sql-server-replication)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [SQL Server on Docker](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-overview)

## Security Notes

⚠️ **Important:** This setup uses a simple password (`YourStrong@Passw0rd`) for demonstration purposes. In a production environment:
- Use strong, unique passwords
- Store passwords securely (e.g., using Docker secrets)
- Configure proper network security
- Enable SSL/TLS encryption for SQL Server connections
- Follow the principle of least privilege for SQL Server accounts

## License

This project is provided as-is for educational and development purposes.
