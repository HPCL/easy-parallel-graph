# Test a connection with a database.
# If it doesn't exist, suggest a way to create it.

import psycopg2
# Check if database exists
conn_string = "dbname='demodb' user='demo_user' password='demo_pwd' host='brix.d.cs.uoregon.edu'"
try:
    conn = psycopg2.connect(conn_string)
except psycopg2.Error as ex:
    print("{}: {}".format(ex.__class__.__name__, ex))
    print("""
    Unable to connect to database. Try creating a database with the following:

    createdb -h localhost -p 5432 -O taudb -U demo_user epgdb

    You may want to create a new user so that people who aren't you can access your database.
    su; useradd demo_user; passwd demo_user; # Make password demo_pwd
    If you mess up, just do dropdb -h localhost -p 5432 -O taudb -U demo_user epgdb
    Afterwards, run taudb_configure using postgresql
    """)
else:
    print("Database connection established using\n{}".format(conn_string))
    conn.close()
