# Master Update Proposal

## Initial Project Description
This project aims to demonstrate best practices in software development and effective management of resources.

## Proposed Improvements
- Enhance performance metrics.
- Improve user interface for better user experience.
- Implement more efficient algorithms to handle data processing.

## SQL Server Replication Environment

This repository now includes a complete Docker-based environment for testing SQL Server replication (Publisher/Subscriber setup).

### Quick Start

To get started with the SQL Server replication environment:

1. **Start the environment:**
   ```bash
   docker-compose up -d
   ```

2. **Configure the Publisher:**
   ```bash
   docker cp publisher-setup.sql sqlpublisher:/var/opt/mssql/
   docker exec -it sqlpublisher /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -i /var/opt/mssql/publisher-setup.sql
   ```

3. **Configure the Subscriber:**
   ```bash
   docker cp subscriber-setup.sql sqlsubscriber:/var/opt/mssql/
   docker exec -it sqlsubscriber /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -i /var/opt/mssql/subscriber-setup.sql
   ```

4. **Test the replication:**
   ```bash
   # Insert data on Publisher
   docker exec -it sqlpublisher /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d ReplicationDB -Q "INSERT INTO Products (ProductName, Price) VALUES ('Webcam', 149.99);"
   
   # Verify on Subscriber
   docker exec -it sqlsubscriber /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d ReplicationDB -Q "SELECT * FROM Products;"
   ```

For detailed instructions, troubleshooting, and advanced usage, please refer to [REPLICATION-README.md](REPLICATION-README.md).

### Files Included

- **docker-compose.yml**: Configures Publisher and Subscriber SQL Server containers
- **publisher-setup.sql**: Sets up the publisher, distribution database, and publication
- **subscriber-setup.sql**: Sets up the subscriber and subscription
- **REPLICATION-README.md**: Comprehensive documentation with detailed setup instructions