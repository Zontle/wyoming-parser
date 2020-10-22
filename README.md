# Wyoming Parser

Repository hosting the instructions on how to parse the Wyoming Business
Registry DB export from the SOS website and how to import it into a PostgreSQL
database for further use via a Hasura Endpoint.

## Requirements

- [Docker](https://www.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)
- [PostgreSQL Database](https://www.postgresql.org/)
- awk (most unix-based systems have it pre-installed)

All scripts are inside `scripts` folder, and should be run from the base/main
root directory of this source code.

## Setup

1. Go to the [Wyoming Secretary of State Business
   Center](https://wyobiz.wyo.gov/Business/Database.aspx), and download the
   Business Entity Database inside the `sample` folder.

(A sample can be found inside the `sample` folder. It is expected
your folder is called `WY_Business_Data.zip`. You can simply replace your latest
zip inside that folder).

2. Extract the contents inside the `data` folder. This folder will be used
   inside a Docker container later to be imported using
[pgfutter](https://github.com/lukasmartinelli/pgfutter). If you are on a
unix-based OS, you can run `scripts/unzip_wy_db.sh` to unzip the contents in the
right folder. Your `data` folder will now look like this:

```
data
├── FILING.csv
├── FILING_ANNUAL_REPORT.csv
├── PARTY.csv
└── schema.pdf

0 directories, 4 files
```

3. The exported CSV files need some cleaning before they can be properly used.
   Importing them into your database as is, will create a wrong schema and/or
break `pgfutter`. In particularly, many entries have wrong numbers of columns
and/or are parsed poorly. To clean them up, run `scripts/clean_csv_files.sh`,
which will:

* Save all lines that do not match the total amount of columns per table
* Remove these lines from the CSV files into a new `$TABLE_CLEANED.csv` file.

4. After running having `$TABLE_CLEANED.csv` in your repository, it's time to
   spin our database and pgadmin4 to import the schema and database. Run `docker-compose
up db pgadmin4`, and go to your browser on `localhost:8889`. Provide the default login
credentials `admin@zontle.tech` and `password`. We need to now import our newly
created server so we se what we are doing.

To view our server inside `pgadmin4`, you need to create a new server. To do so,  right-click on the
`Servers` option in the sidebar and select `Create > Server`. You'll need to
provide Docker's host address, which is only known within the Docker network.
Run the following command to get it, should be something like `172.20.0.2`:

```bash
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -q --filter "ancestor=postgres:11")
``` 

If you click under the `Database > postgres > schemas`, you will only see a `public` empty one. Its
time to import our CSV files as actual database entries. To do so, we'll use
`pgfutter`.

5. We are ready to use `pgfutter`, which will create the
   schema and import our clean data from our csv files. We'll attach ourselves to
the `pgadmin4` instance to run it, as its already within our `bin` folder
mounted as a volume. To do so, run the following commands:

```bash
docker-compose exec db bash
cd /home
./bin/pgfutter --user postgres --pw password --schema wyoming csv -d "|" ./data/FILING_CLEANED.csv
./bin/pgfutter --user postgres --pw password --schema wyoming csv -d "|" ./data/PARTY_CLEANED.csv
./bin/pgfutter --user postgres --pw password --schema wyoming csv -d "|" ./data/FILING_ANNUAL_REPORT_CLEANED.csv
```

(Each `pgfutter` call might take some time depending on your computer).

After successfully running these commands, you will be able to see all the
entries into a new table called `wyoming`. You can then query and see data
directly from `pgadmin4`. Its time to spin our API!

6. To spin our API, we only need to run `docker-compose up graphql-engine`,
   which will spin a [Hasura](https://hasura.io/) instance that will connect to
our database. You can now go to `http://localhost:8080/console` and play with
the actual API.

To allow automatic import of data, go to `Data` and select `wyoming` under
`Current Postgres Schema` and thereafter `Import All` tables to expose your
database via Hasura's GraphQL Engine. You can now start querying the
Wyoming Business Registry as an Open API.

# Additional Notes

The current process was setup manual for the [Wyoming 2020
Hackathon](https://wyohackathon2020.devpost.com/). The database is roughly
updated every 2 weeks, so these steps need to be run on a bi-weekly basis.
However, a [GitHub Action](https://github.com/features/actions) can be created
to automate this by running `scripts/import.sh` on a cron-job basis by using
GitHub `on.schedule`
[API](https://docs.github.com/en/free-pro-team@latest/actions/reference/workflow-syntax-for-github-actions#onschedule) and provide the database dump in an external URL (e.g. AWS S3, Google Cloud Storage).

Please reach the secretary of state IT department (SOSAdminServices@wyo.gov) before creating an automated import script on their database, as mocking the download query might create a disruption of service, be confused as a DDOS attack, and/or block GitHub range of IPs.

